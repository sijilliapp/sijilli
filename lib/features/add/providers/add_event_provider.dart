import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:adhan/adhan.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/autocomplete_service.dart';
import '../../../models/appointment.dart';
import '../../../models/user.dart';
import '../../appointments/providers/appointment_provider.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/article.dart';
import '../../appointments/services/pb_appointment_service.dart';

import '../../../core/services/appointment_draft_service.dart';
import '../../../core/utils/arabic_search.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum AddEventMode { simple, advanced }

class AddEventProvider extends ChangeNotifier {
  final AutocompleteService _autocompleteService = AutocompleteService();
  final LocationService _locationService = LocationService();
  final AppointmentDraftService _draftService = AppointmentDraftService();

  // Add Event Mode (Simple vs Advanced)
  AddEventMode _mode = AddEventMode.simple;
  AddEventMode get mode => _mode;

  Future<void> loadSavedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString('preferred_add_event_mode');
      if (modeStr == 'advanced') {
        _mode = AddEventMode.advanced;
      } else {
        _mode = AddEventMode.simple;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setMode(AddEventMode newMode) async {
    if (_mode == newMode) return;
    _mode = newMode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('preferred_add_event_mode', newMode == AddEventMode.advanced ? 'advanced' : 'simple');
    } catch (_) {}
  }

  // Location Learning
  // Region -> Map<Building, Frequency>
  final Map<String, Map<String, int>> _learnedLocations = {};
  List<String> _regionSuggestions = [];
  List<String> _buildingSuggestions = [];

   List<String> get regionSuggestions => _regionSuggestions;
  List<String> get buildingSuggestions => _buildingSuggestions;

  // Persistent Fields (for Drafts)
  String _title = '';
  String _location = '';
  String _building = '';
  String _coordinates = '';
  String _description = '';

  String get draftTitle => _title;
  String get draftLocation => _location;
  String get draftBuilding => _building;
  String get draftCoordinates => _coordinates;
  String get draftDescription => _description;


  // State
  bool _isSaving = false;
  String _privacy = 'followers';
  String _lastSelectedPrivacy = 'followers'; // 🌟 Cached last selected privacy
  bool _isHijri = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _duration = 45;
  DateTime? _selectedEndDate;
  final List<UserModel> _selectedUsers = [];
  Coordinates? _userCoordinates;
  double _hijriAdjustment = 0; // Added for Provider logic
  bool _pinAddress = false;

  // Recurrence
  bool _isRecurring = false;
  String _recurrenceType = 'daily';
  int _recurrenceCount = 3;

  // First Come First Served
  bool _isFirstComeFirstServed = false;

  // Invitation Link
  bool _generateInviteLink = false;
  String? _generatedInviteToken;
  String? _highlightedAppointmentId;

  bool get generateInviteLink => _generateInviteLink;
  String? get generatedInviteToken => _generatedInviteToken;
  String? get highlightedAppointmentId => _highlightedAppointmentId;

  void clearHighlight() {
    _highlightedAppointmentId = null;
  }

  /// الحصول على قائمة الأوقات الأكثر استخداماً من سجلات accepted المقبولة للمستخدم الحالي مرتبة حسب التكرار
  List<TimeOfDay> get frequentTimes {
    final defaultTimes = const [
      TimeOfDay(hour: 15, minute: 30), // 3:30 عصراً
      TimeOfDay(hour: 17, minute: 0),  // 5:00 عصراً
      TimeOfDay(hour: 20, minute: 0),  // 8:00 مساءً
      TimeOfDay(hour: 21, minute: 0),  // 9:00 مساءً
      TimeOfDay(hour: 10, minute: 0),  // 10:00 صباحاً
      TimeOfDay(hour: 13, minute: 30), // 1:30 ظهراً
    ];

    // تصفية السجلات ليؤخذ فقط من المواعيد المقبولة accepted للمستخدم
    final acceptedHistory = _history.where((appt) {
      if (appt.isCancelled || appt.isDeleted) return false;
      if (appt.hostInvitation?.status == 'trash' || appt.hostInvitation?.status == 'cancelled') return false;
      if (appt.currentUserInvitation != null) {
        return appt.currentUserInvitation!.status == 'accepted';
      }
      return true;
    }).toList();

    if (acceptedHistory.isEmpty) {
      return defaultTimes;
    }

    final Map<String, int> counts = {};
    final Map<String, TimeOfDay> timesMap = {};

    for (final appt in acceptedHistory) {
      final tod = TimeOfDay(hour: appt.startAt.hour, minute: appt.startAt.minute);
      final key = '${tod.hour}:${tod.minute}';
      counts[key] = (counts[key] ?? 0) + 1;
      timesMap[key] = tod;
    }

    final sortedKeys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    final List<TimeOfDay> sortedTimes = sortedKeys.map((key) => timesMap[key]!).toList();

    for (final def in defaultTimes) {
      final key = '${def.hour}:${def.minute}';
      if (!counts.containsKey(key)) {
        sortedTimes.add(def);
      }
    }

    return sortedTimes;
  }

  // Conflict Detection
  List<Appointment> _history = [];
  bool _hasConflict = false;
  bool _ignoreConflictCheck = false;
  String? _editingId;

  // Suggestions
  List<String> _suggestions = [];
  List<PivotMatch> _pivotSuggestions = [];
  EventDate? _lastAutoMatch;

  // Getters
  bool get isSaving => _isSaving;
  String get privacy => _privacy;
  bool get isHijri => _isHijri;
  DateTime? get selectedDate => _selectedDate;
  TimeOfDay? get selectedTime => _selectedTime;
  int get duration => _duration;
  DateTime? get selectedEndDate => _selectedEndDate;
  List<UserModel> get selectedUsers => List.unmodifiable(_selectedUsers);
  Coordinates? get userCoordinates => _userCoordinates;
  double get hijriAdjustment => _hijriAdjustment;
  
  bool get isRecurring => _isRecurring;
  String get recurrenceType => _recurrenceType;
  int get recurrenceCount => _recurrenceCount;
  
  bool get isFirstComeFirstServed => _isFirstComeFirstServed;
  
  List<String> get suggestions => _suggestions;
  List<PivotMatch> get pivotSuggestions => _pivotSuggestions;
  bool get hasConflict => _hasConflict;
  bool get pinAddress => _pinAddress;

  // Calculated Getters (Moved from UI)
  TimeOfDay? get sunsetTime {
    if (_selectedDate == null) return null;
    final myCoordinates = _userCoordinates ?? Coordinates(24.7136, 46.6753); // Default Riyadh
    final params = CalculationMethod.umm_al_qura.getParameters();
    final dateComponents = DateComponents.from(_selectedDate!);
    final prayerTimes = PrayerTimes(myCoordinates, dateComponents, params);
    return TimeOfDay.fromDateTime(prayerTimes.maghrib);
  }

  TimeOfDay? get dhuhrTime {
    if (_selectedDate == null) return null;
    final myCoordinates = _userCoordinates ?? Coordinates(24.7136, 46.6753); // Default Riyadh
    final params = CalculationMethod.umm_al_qura.getParameters();
    final dateComponents = DateComponents.from(_selectedDate!);
    final prayerTimes = PrayerTimes(myCoordinates, dateComponents, params);
    return TimeOfDay.fromDateTime(prayerTimes.dhuhr);
  }

  TimeOfDay? get sunriseTime {
    if (_selectedDate == null) return null;
    final myCoordinates = _userCoordinates ?? Coordinates(24.7136, 46.6753); // Default Riyadh
    final params = CalculationMethod.umm_al_qura.getParameters();
    final dateComponents = DateComponents.from(_selectedDate!);
    final prayerTimes = PrayerTimes(myCoordinates, dateComponents, params);
    return TimeOfDay.fromDateTime(prayerTimes.sunrise);
  }

  String getEndDisplay(AppLocalizations l10n) {
    if (_selectedDate == null) return '---';
    
    // 1. All Day / Multi Day
    if (_duration == 0) {
      if (_isHijri) {
        return l10n.durationAllDay; 
      }
      
      final endDate = _selectedEndDate ?? _selectedDate!;
      final diffDays = endDate.difference(_selectedDate!).inDays;
      
      final locale = l10n.localeName;
      final dateStr = DateFormat('dd MMMM yyyy', locale).format(endDate);

      if (diffDays > 0) {
        return '$dateStr (${l10n.daysLeft(diffDays + 1)})';
      }
      return dateStr;
    }

    // 2. Specific Time
    if (_selectedTime == null) return '---';
    
    final startAt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final endAt = startAt.add(Duration(minutes: _duration));
    final locale = l10n.localeName;
    final timeStr = AppDateFormatter.formatTime12h(endAt, locale); 
    
    if (_isHijri) {
      HijriCalendar.setLocal(locale);
      try {
        final h = HijriCalendar.fromDate(endAt.add(Duration(days: _hijriAdjustment.toInt())));
        return '${h.toFormat("dd MMMM yyyy")} | $timeStr';
      } catch (e) {
        return '${DateFormat('dd MMMM yyyy', locale).format(endAt)} | $timeStr';
      }
    } else {
      return '${DateFormat('dd MMMM yyyy', locale).format(endAt)} | $timeStr';
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Initialization
  Future<void> init(Appointment? initialAppointment, List<Appointment> history, {UserModel? currentUser}) async {
    // Clear previous singleton state to avoid cross-user data leaks and duplicate frequency indexing
    _autocompleteService.clearLearnedData();

    // Extract titles for Word Buffet
    final allTitles = history.map((e) => e.title).where((t) => t.isNotEmpty).toList();
    _autocompleteService.learn(allTitles);
    
    // Learn Frequent Dates
    _autocompleteService.learnDates(history);
    
    if (currentUser != null) {
      _hijriAdjustment = currentUser.hijriAdjustment?.toDouble() ?? 0;
    }

    _history = history;
    _editingId = initialAppointment?.id;
    _lastSelectedPrivacy = await _loadLastPrivacy();

    if (initialAppointment != null) {
      _selectedDate = initialAppointment.date;
      _selectedTime = TimeOfDay.fromDateTime(initialAppointment.fullDateTime);
      
      // Fix: If duration is >= 24h (1440 mins) and multiple of 1440, treat as All Day (0)
      if (initialAppointment.duration >= 1440 && initialAppointment.duration % 1440 == 0) {
        _duration = 0;
      } else {
        _duration = initialAppointment.duration;
      }
      
      _selectedEndDate = initialAppointment.fullDateTime.add(Duration(minutes: initialAppointment.duration));
      
      // 1. Privacy — من نسخة المستضيف الشخصية فقط، لا من appointments.privacy
      _privacy = initialAppointment.currentUserInvitation?.privacy ?? 'private';
      
      // 2. Date Type
      if (initialAppointment.dateType == 'hijri') {
        _isHijri = true;
      }
      
      // 3. Recurrence
      if (initialAppointment.recurrenceType != null && initialAppointment.recurrenceType != 'none') {
        _isRecurring = true;
        _recurrenceType = initialAppointment.recurrenceType!;
        _recurrenceCount = initialAppointment.recurrenceCount ?? 1;
      }

      // 4. Participants (Guests)
      // Populate selectedUsers if participants exist and are not current user
      if (initialAppointment.participants != null) {
         _selectedUsers.clear();
         for (final inv in initialAppointment.participants!) {
           if (inv.user != null) {
             // Exclude Self (Host/Me)
             if (currentUser != null && inv.user!.id == currentUser.id) continue;
             
             // Avoid Duplicates
             if (!_selectedUsers.any((u) => u.id == inv.user!.id)) {
                _selectedUsers.add(inv.user!);
             }
           }
         }
      }

      // Note: Other fields
      _location = initialAppointment.region ?? '';
      _building = initialAppointment.building ?? '';
      _coordinates = initialAppointment.coordinates ?? '';
      _description = initialAppointment.description ?? '';
    } else {
      _selectedEndDate = _selectedDate;
      _generateInviteLink = false;
      _generatedInviteToken = null;
      await _loadDraft();
      if (_privacy == 'followers' && _lastSelectedPrivacy != 'followers') {
        _privacy = _lastSelectedPrivacy;
      }
      final box = await Hive.openBox('appointment_drafts');
      _pinAddress = box.get('pin_address', defaultValue: false);
      if (_pinAddress && _location.isEmpty && _building.isEmpty) {
        _location = box.get('pinned_location', defaultValue: '');
        _building = box.get('pinned_building', defaultValue: '');
        _coordinates = box.get('pinned_coordinates', defaultValue: '');
      }
    }
    
    _getUserLocation();
    
    // Initialize Suggestions with empty query (Zero-Keyboard)
    initLocations(history); // Build the location frequency map from history
    onTitleChanged(_title);
    updateRegionSuggestions(_location);
    updateBuildingSuggestions(_location, _building);
    
    // Safety check before notify
    if (!_disposed) {
      _updateConflictStatus();
      notifyListeners();
    }
  }

  /// Re-syncs the autocomplete engine with fresh history without resetting current form state.
  void refreshHistory(List<Appointment> history) {
    if (history.isEmpty) return; // Wait for real data
    
    // Refresh Title Autocomplete
    _autocompleteService.clearLearnedData();
    final allTitles = history.map((e) => e.title).where((t) => t.isNotEmpty).toList();
    _autocompleteService.learn(allTitles);
    _autocompleteService.learnDates(history);
    
    // Refresh Location Autocomplete
    initLocations(history);
    
    _history = history;
    _updateConflictStatus();
    
    // Trigger update for currently focused field if any
    onTitleChanged(_title);
    updateRegionSuggestions(_location);
    updateBuildingSuggestions(_location, _building);
  }

  // --- Draft Persistence ---

  Future<void> _loadDraft() async {
    final draft = await _draftService.loadDraft();
    if (draft == null) {
      _privacy = _lastSelectedPrivacy;
      return;
    }

    try {
      _title = draft['title'] ?? '';
      _location = draft['location'] ?? '';
      _building = draft['building'] ?? '';
      _coordinates = draft['coordinates'] ?? '';
      _description = draft['description'] ?? '';
      
      _privacy = draft['privacy'] ?? _lastSelectedPrivacy;
      _isHijri = draft['isHijri'] ?? false;
      
      if (draft['selectedDate'] != null) {
        _selectedDate = DateTime.parse(draft['selectedDate']);
      }
      
      if (draft['selectedTime'] != null) {
        final t = draft['selectedTime'] as Map;
        _selectedTime = TimeOfDay(hour: t['hour'], minute: t['minute']);
      }
      
      _duration = draft['duration'] ?? 45;
      
      if (draft['selectedEndDate'] != null) {
        _selectedEndDate = DateTime.parse(draft['selectedEndDate']);
      }
      
      _isRecurring = draft['isRecurring'] ?? false;
      _recurrenceType = draft['recurrenceType'] ?? 'daily';
      _recurrenceCount = draft['recurrenceCount'] ?? 3;
      _isFirstComeFirstServed = draft['isFirstComeFirstServed'] ?? false;

      if (draft['selectedUsers'] != null) {
        _selectedUsers.clear();
        for (var u in (draft['selectedUsers'] as List)) {
          _selectedUsers.add(UserModel.fromJson(Map<String, dynamic>.from(u)));
        }
      }

      notifyListeners();
    } catch (e) {
      print('Error loading draft: $e');
    }
  }

  void _saveDraft() {
    // Basic debounce / throttle not needed for Hive usually, but good to keep simple.
    _draftService.saveDraft({
      'title': _title,
      'location': _location,
      'building': _building,
      'coordinates': _coordinates,
      'description': _description,
      'privacy': _privacy,
      'isHijri': _isHijri,
      'selectedDate': _selectedDate?.toIso8601String(),
      'selectedTime': _selectedTime != null ? {'hour': _selectedTime!.hour, 'minute': _selectedTime!.minute} : null,
      'duration': _duration,
      'selectedEndDate': _selectedEndDate?.toIso8601String(),
      'isRecurring': _isRecurring,
      'recurrenceType': _recurrenceType,
      'recurrenceCount': _recurrenceCount,
      'isFirstComeFirstServed': _isFirstComeFirstServed,
      'selectedUsers': _selectedUsers.map((u) => u.toJson()).toList(),
    });
  }

  Future<void> _getUserLocation() async {
    try {
      final locationData = await _locationService.getApproximateLocation();
      if (_disposed) return;
      _userCoordinates = locationData.toCoordinates();
      notifyListeners();
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _saveLastPrivacy(String value) async {
    final box = await Hive.openBox('appointment_drafts');
    await box.put('last_selected_privacy', value);
  }

  Future<String> _loadLastPrivacy() async {
    final box = await Hive.openBox('appointment_drafts');
    return box.get('last_selected_privacy', defaultValue: 'followers');
  }

  // Logic Methods
  void setPrivacy(String value) {
    _privacy = value; 
    _lastSelectedPrivacy = value;
    _saveLastPrivacy(value);
    _saveDraft();
    notifyListeners();
  }

  void setLocation(String value) {
    _location = value;
    _saveDraft();
    notifyListeners();
  }

  void setBuilding(String value) {
    _building = value;
    _saveDraft();
    notifyListeners();
  }

  void setCoordinates(String value) {
    _coordinates = value;
    _saveDraft();
    notifyListeners();
  }

  Future<void> setPinAddress(bool value) async {
    _pinAddress = value;
    final box = await Hive.openBox('appointment_drafts');
    await box.put('pin_address', value);
    if (value) {
      await box.put('pinned_location', _location);
      await box.put('pinned_building', _building);
      await box.put('pinned_coordinates', _coordinates);
    } else {
      await box.delete('pinned_location');
      await box.delete('pinned_building');
      await box.delete('pinned_coordinates');
    }
    notifyListeners();
  }

  Future<void> updatePinnedAddressIfNeeded() async {
    if (_pinAddress) {
      final box = await Hive.openBox('appointment_drafts');
      await box.put('pinned_location', _location);
      await box.put('pinned_building', _building);
      await box.put('pinned_coordinates', _coordinates);
    }
  }

  void _updateConflictStatus() {
    final bool isAllDay = _duration == 0;
    if (_ignoreConflictCheck || _selectedDate == null || (!isAllDay && _selectedTime == null) || _duration < 0) {
      _hasConflict = false;
      return;
    }

    final newStart = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      isAllDay ? 0 : (_selectedTime?.hour ?? 0),
      isAllDay ? 0 : (_selectedTime?.minute ?? 0),
    );

    int finalNewDuration = _duration;
    if (isAllDay) {
       // "All Day" logic
       int dayCount = 1;
       if (!_isHijri) {
          dayCount = (_selectedEndDate?.difference(_selectedDate!).inDays ?? 0) + 1;
       }
       finalNewDuration = (dayCount >= 1) ? dayCount * 1440 : 1440;
    }

    final newRanges = _getAppointmentOccurrences(
      startAt: newStart,
      recurrenceType: _isRecurring ? _recurrenceType : null,
      recurrenceCount: _isRecurring ? _recurrenceCount : 1,
      recurrenceIndex: 1,
      duration: finalNewDuration,
      dateType: _isHijri ? 'hijri' : 'gregorian',
    );

    final conflicts = _history.where((a) {
      if (a.id == _editingId) return false;
      
      // Ignore cancelled or deleted (global or personal trash)
      if (a.isCancelled || a.isUserDeleted) return false;
      
      // Ignore declined (rejected) and deletedAfterAccept
      if (a.viewerRecord?.status == InvitationStatus.declined || 
          a.viewerRecord?.status == InvitationStatus.deletedAfterAccept) {
        return false;
      }

      // Get occurrence ranges for this existing appointment
      final existingRanges = _getAppointmentOccurrences(
        startAt: a.startAt,
        recurrenceType: a.recurrenceType,
        recurrenceCount: a.recurrenceCount ?? 1,
        recurrenceIndex: a.recurrenceIndex ?? 1,
        duration: a.duration,
        dateType: a.dateType,
      );

      // Check if any range of the new appointment overlaps with any range of this existing appointment
      for (final newRange in newRanges) {
        for (final extRange in existingRanges) {
          if (newRange.start.isBefore(extRange.end) && extRange.start.isBefore(newRange.end)) {
            return true; // Overlap detected!
          }
        }
      }

      return false;
    });

    _hasConflict = conflicts.isNotEmpty;
  }

  List<DateTimeRange> _getAppointmentOccurrences({
    required DateTime startAt,
    required String? recurrenceType,
    required int recurrenceCount,
    required int recurrenceIndex,
    required int duration,
    required String dateType,
  }) {
    final List<DateTimeRange> ranges = [];
    
    // The current occurrence (which starts at startAt)
    DateTime currentLocalStart = startAt.toLocal();
    int currentDuration = duration;
    if (currentDuration == 0) {
      currentDuration = 1440;
    }

    ranges.add(DateTimeRange(
      start: currentLocalStart,
      end: currentLocalStart.add(Duration(minutes: currentDuration)),
    ));

    // If it's not a recurring event, or count <= index, return just this one
    if (recurrenceType == null || recurrenceType == 'none' || recurrenceCount <= recurrenceIndex) {
      return ranges;
    }

    int remaining = recurrenceCount - recurrenceIndex;
    
    // We compute the next occurrences sequentially
    for (int i = 0; i < remaining; i++) {
      currentLocalStart = _calculateNextDateLocal(currentLocalStart, recurrenceType, dateType);
      ranges.add(DateTimeRange(
        start: currentLocalStart,
        end: currentLocalStart.add(Duration(minutes: currentDuration)),
      ));
    }

    return ranges;
  }

  DateTime _calculateNextDateLocal(DateTime currentLocal, String recurrenceType, String dateType) {
    if (dateType == 'hijri') {
       HijriCalendar.setLocal('ar');
       final h = HijriCalendar.fromDate(currentLocal);
       int hYear = h.hYear;
       int hMonth = h.hMonth;
       int hDay = h.hDay;

       if (recurrenceType == 'daily') {
          return currentLocal.add(const Duration(days: 1));
       } else if (recurrenceType == 'weekly') {
          return currentLocal.add(const Duration(days: 7));
       } else if (recurrenceType == 'monthly') {
          hMonth++;
          if (hMonth > 12) {
             hMonth = 1;
             hYear++;
          }
       } else if (recurrenceType == 'annual') {
          hYear++;
       }

       final hCalc = HijriCalendar();
       hCalc.hYear = hYear;
       hCalc.hMonth = hMonth;
       hCalc.hDay = hDay;
       
       DateTime next;
       if (hCalc.isValid()) {
         next = hCalc.hijriToGregorian(hYear, hMonth, hDay);
       } else {
          next = hCalc.hijriToGregorian(hYear, hMonth, 29);
       }
       
       // Preserve the exact wall-clock time
       return DateTime(
         next.year, next.month, next.day,
         currentLocal.hour, currentLocal.minute, currentLocal.second
       );

    } else {
      switch (recurrenceType) {
        case 'daily':
          return currentLocal.add(const Duration(days: 1));
        case 'weekly':
          return currentLocal.add(const Duration(days: 7));
        case 'monthly':
          int nextMonth = currentLocal.month + 1;
          int nextYear = currentLocal.year;
          if (nextMonth > 12) {
            nextMonth = 1;
            nextYear++;
          }
          final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
          final nextDay = currentLocal.day > lastDayOfNextMonth ? lastDayOfNextMonth : currentLocal.day;
          return DateTime(nextYear, nextMonth, nextDay, currentLocal.hour, currentLocal.minute);
          
        case 'annual':
           int nextYear = currentLocal.year + 1;
           if (currentLocal.month == 2 && currentLocal.day == 29) {
             return DateTime(nextYear, 2, 28, currentLocal.hour, currentLocal.minute);
           }
           return DateTime(nextYear, currentLocal.month, currentLocal.day, currentLocal.hour, currentLocal.minute);
        default:
          return currentLocal.add(const Duration(days: 1));
      }
    }
  }


  void setIsHijri(bool value) {
    _isHijri = value;
    if (value) {
      _selectedEndDate = _selectedDate;
    }
    if (!_canRecur()) _isRecurring = false;
    _saveDraft();
    notifyListeners();
  }

  void setDate(DateTime date) {
    _selectedDate = date;
    if (_selectedEndDate == null || _selectedEndDate!.isBefore(date)) {
      _selectedEndDate = date;
    }
    if (!_canRecur()) _isRecurring = false;
    _updateConflictStatus();
    _saveDraft();
    notifyListeners();
  }

  void setTime(TimeOfDay time) {
    _selectedTime = time;
    _updateConflictStatus();
    _saveDraft();
    notifyListeners();
  }

  void setDuration(int value) {
    _duration = value;
    if (!_canRecur()) _isRecurring = false;
    _updateConflictStatus();
    _saveDraft();
    notifyListeners();
  }

  void setEndDate(DateTime date) {
    _selectedEndDate = date;
    if (!_canRecur()) _isRecurring = false;
    _updateConflictStatus();
    _saveDraft();
    notifyListeners();
  }

  bool _canRecur() {
    if (_duration != 0) return _duration <= 1440;
    final start = _selectedDate ?? DateTime.now();
    final end = _selectedEndDate ?? start;
    final days = end.difference(start).inDays + 1;
    return days <= 1;
  }

  void toggleRecurrence(bool value) {
    if (value && !_canRecur()) return;
    _isRecurring = value;
    _saveDraft();
    notifyListeners();
  }

  void setRecurrenceType(String type) {
    _recurrenceType = type;
    _saveDraft();
    notifyListeners();
  }

  void setRecurrenceCount(int count) {
    _recurrenceCount = count;
    _saveDraft();
    notifyListeners();
  }

  void toggleFirstComeFirstServed(bool value) {
    _isFirstComeFirstServed = value;
    _saveDraft();
    notifyListeners();
  }

  void setGenerateInviteLink(bool value) {
    _generateInviteLink = value;
    notifyListeners();
  }

  void addInvitee(UserModel user) {
    if (!_selectedUsers.any((u) => u.id == user.id)) {
      _selectedUsers.add(user);
      _saveDraft();
      notifyListeners();
    }
  }

  void removeInvitee(int index) {
    _selectedUsers.removeAt(index);
    if (_selectedUsers.length < 2) {
      _isFirstComeFirstServed = false;
    }
    _saveDraft();
    notifyListeners();
  }

  void onDescriptionChanged(String text) {
    _description = text;
    _saveDraft();
    notifyListeners();
  }

  // Suggestions Logic
  void onTitleChanged(String text) {
    _title = text;
    _suggestions = _autocompleteService.getSuggestions(text);
    _pivotSuggestions = _autocompleteService.getPivotSuggestions(text);
    
    final match = _autocompleteService.checkForDateMatch(text);
    
    if (match != null) {
      if (match != _lastAutoMatch) {
         _applySmartDate(match);
      }
    } else {
      _lastAutoMatch = null;
    }
    _saveDraft();
    notifyListeners();
  }

  void _applySmartDate(EventDate match) {
    DateTime now = DateTime.now();
    DateTime targetDate;
    bool isHijri = match.isHijri;

    if (match.weekday != null) {
       int daysToAdd = (match.weekday! - now.weekday + 7) % 7;
       if (daysToAdd == 0) daysToAdd = 7;
       targetDate = now.add(Duration(days: daysToAdd));
       isHijri = false; 
    } else {
       // Safety: Ensure month and day are present if weekday is not
       if (match.month == null || match.day == null) return;

       if (match.isHijri) {
         HijriCalendar.setLocal('ar');
         final hNow = HijriCalendar.now();
         int targetYear = hNow.hYear;
         
         // If the month/day has already passed in the current Hijri year, move to next year
         if (match.month! < hNow.hMonth || (match.month! == hNow.hMonth && match.day! < hNow.hDay)) {
           targetYear++;
         }

         final hTarget = HijriCalendar();
         try {
           targetDate = hTarget.hijriToGregorian(targetYear, match.month!, match.day!);
         } catch (e) {
           return; // Invalid date
         }
         
         // Fix: Inverse adjust so the Picker displays the correct Hijri date
         if (_hijriAdjustment != 0) {
            targetDate = targetDate.subtract(Duration(days: _hijriAdjustment.toInt()));
         }
       } else {
         // Gregorian Date
         int targetYear = now.year;
         DateTime potentialDate = DateTime(targetYear, match.month!, match.day!);
         
         // If the date has already passed today, move to next year
         final today = DateTime(now.year, now.month, now.day);
         if (potentialDate.isBefore(today)) {
           targetYear++;
           potentialDate = DateTime(targetYear, match.month!, match.day!);
         }
         targetDate = potentialDate;
       }
    }
    
    _lastAutoMatch = match;
    _selectedDate = targetDate;
    _isHijri = isHijri;
    _selectedEndDate = targetDate;
    
    _saveDraft();
  }

  // Helper for UI to trigger smart date check manually (e.g. on word selection)
  void checkDateMatch(String text) {
    final dateMatch = _autocompleteService.checkForDateMatch(text.trim());
    if (dateMatch != null) {
      _applySmartDate(dateMatch);
      notifyListeners();
    }
  }

  // --- Location Autocomplete Logic ---

  void initLocations(List<Appointment> history) {
    _learnedLocations.clear();
    
    for (var appt in history) {
      // Normalize region for better clustering while keeping original case for display
      final rawRegion = appt.region?.trim() ?? '';
      if (rawRegion.isEmpty) continue;

      // Find if we already have this region in any case
      String region = rawRegion;
      final existingKey = _learnedLocations.keys.firstWhere(
        (k) => k.toLowerCase() == rawRegion.toLowerCase(),
        orElse: () => '',
      );
      if (existingKey.isNotEmpty) {
        region = existingKey; // Use existing casing
      }

      final building = appt.building?.trim() ?? '';

      if (!_learnedLocations.containsKey(region)) {
        _learnedLocations[region] = {};
      }
      
      if (building.isNotEmpty) {
        _learnedLocations[region]![building] = (_learnedLocations[region]![building] ?? 0) + 1;
      } else {
        _learnedLocations[region]![''] = (_learnedLocations[region]![''] ?? 0) + 1;
      }
    }
  }

  void updateRegionSuggestions(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    
    // Get all regions and their total frequency
    final regionCounts = <String, int>{};
    _learnedLocations.forEach((region, buildings) {
       int total = 0;
       buildings.values.forEach((v) => total += v);
       regionCounts[region] = total;
    });

    final allRegions = regionCounts.keys.toList();
    
    if (query.isEmpty) {
      // Show top 10 most frequent
      allRegions.sort((a, b) => regionCounts[b]!.compareTo(regionCounts[a]!));
      _regionSuggestions = allRegions.take(10).toList();
    } else {
      // Filter using centralized smartMatch (prefix matching on any word + normalization)
      final matches = allRegions.where((r) => ArabicSearch.smartMatch(r, query)).toList();
      matches.sort((a, b) => regionCounts[b]!.compareTo(regionCounts[a]!));
      _regionSuggestions = matches.take(10).toList();
    }
    notifyListeners();
  }

  void updateBuildingSuggestions(String region, String query) {
    final targetRegion = region.trim().toLowerCase(); 
    
    Map<String, int>? buildingsMap;
    
    // Case-insensitive region lookup
    final matchedKey = _learnedLocations.keys.firstWhere(
      (k) => k.toLowerCase() == targetRegion,
      orElse: () => '',
    );

    if (matchedKey.isNotEmpty) {
      buildingsMap = _learnedLocations[matchedKey];
    } else {
      _buildingSuggestions = [];
      notifyListeners();
      return;
    }

    final normalizedQuery = query.trim().toLowerCase();
    final allBuildings = buildingsMap!.keys.where((k) => k.isNotEmpty).toList();

    if (query.isEmpty) {
       // Frequency Sort
       allBuildings.sort((a, b) => buildingsMap![b]!.compareTo(buildingsMap[a]!));
       _buildingSuggestions = allBuildings.take(10).toList();
    } else {
       // Filter using centralized smartMatch (prefix matching on any word + normalization)
       final matches = allBuildings.where((b) => ArabicSearch.smartMatch(b, query)).toList();
       matches.sort((a, b) => buildingsMap![b]!.compareTo(buildingsMap[a]!));
       _buildingSuggestions = matches.take(10).toList();
    }
    notifyListeners();
  }

  String? lookupCoordinates(String region, String building) {
    final reg = region.trim().toLowerCase();
    final bld = building.trim().toLowerCase();
    for (final appt in _history) {
      final apptReg = appt.region?.trim().toLowerCase() ?? '';
      final apptBld = appt.cleanBuilding.trim().toLowerCase();
      
      final matchesRegion = reg.isEmpty || apptReg == reg;
      final matchesBuilding = apptBld == bld;
      
      if (matchesRegion && matchesBuilding && appt.coordinates != null && appt.coordinates!.isNotEmpty) {
        return appt.coordinates;
      }
    }
    return null;
  }

  // Form Actions
  void clearForm() {
    _selectedDate = DateTime.now();
    _selectedTime = null;
    _duration = 45;
    _selectedEndDate = DateTime.now();
    _selectedUsers.clear();
    _isRecurring = false;
    _isSaving = false;
    _privacy = _lastSelectedPrivacy;
    _title = '';
    
    // Reload pinned location if active
    if (_pinAddress) {
      // Synchronously access because box is already open
      final box = Hive.box('appointment_drafts');
      _location = box.get('pinned_location', defaultValue: '');
      _building = box.get('pinned_building', defaultValue: '');
      _coordinates = box.get('pinned_coordinates', defaultValue: '');
    } else {
      _location = '';
      _building = '';
      _coordinates = '';
    }

    _description = '';
    _suggestions = [];
    _pivotSuggestions = [];
    _draftService.clearDraft();
    _ignoreConflictCheck = false; 
    _hasConflict = false;
    notifyListeners();
  }

  bool hasFormData(String title, String location, String building) {
    return title.isNotEmpty || 
           location.isNotEmpty || 
           building.isNotEmpty ||
           _selectedDate != null || 
           _selectedTime != null ||
           _selectedUsers.isNotEmpty;
  }

  // Save Event
  Future<String?> saveEvent({
    required String title,
    required String location,
    required String building,
    required String description,
    required UserModel currentUser,
    required AppointmentProvider appointmentProvider,
    required String locale,
    required int dailyLimit,
    String? inviteTitle,
    String? inviteMessage,
  }) async {
    // ⚠️ Check Daily Limit
    if (_editingId == null) {
      final todayCount = await PbAppointmentService().getCreatedTodayCount(currentUser.id);
      if (todayCount >= dailyLimit) {
        return 'لقد تجاوزت الحد اليومي لإنشاء المواعيد المسموح به لرتبتك ($dailyLimit مواعيد يومياً).';
      }
    }

    // Validation
    if (_selectedDate == null || (_duration != 0 && _selectedTime == null)) {
      return 'Please select date and time';
    }

    // Combine Date and Time
    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      (_duration == 0) ? 0 : (_selectedTime?.hour ?? 0),
      (_duration == 0) ? 0 : (_selectedTime?.minute ?? 0),
    );

    // Duration Adjustment
    int finalDuration = _duration;
    int dayCount = 1;
    if (_duration == 0) {
       // "All Day" logic
       if (!_isHijri) {
          dayCount = (_selectedEndDate?.difference(_selectedDate!).inDays ?? 0) + 1;
       }
       // If dayCount is 1, duration is 1440 (24h). If >1, it is dayCount * 1440.
       finalDuration = (dayCount >= 1) ? dayCount * 1440 : 1440;
    }

    // Hijri Calculation
    // For now, keep 'ar' for internal numerical calculation consistency
    HijriCalendar.setLocal('ar');
    
    final adjustment = currentUser.hijriAdjustment?.toInt() ?? 0;
    
    DateTime finalHijriDate = dateTime;
    if (adjustment != 0) {
      finalHijriDate = finalHijriDate.add(Duration(days: adjustment));
    }
    
    final hijri = HijriCalendar.fromDate(finalHijriDate);
    
    final hijriDateString = '${hijri.hYear}-${hijri.hMonth.toString().padLeft(2,'0')}-${hijri.hDay.toString().padLeft(2,'0')}';

    // Calculate Sunset String
    String? sunsetStr;
    final sTime = sunsetTime;

    if (sTime != null) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, sTime.hour, sTime.minute);
      final tp = locale == 'ar' ? (sTime.hour >= 12 ? 'م' : 'ص') : (sTime.hour >= 12 ? 'PM' : 'AM');
      sunsetStr = '${sTime.hour % 12 == 0 ? 12 : sTime.hour % 12}:${sTime.minute.toString().padLeft(2, '0')} $tp';
      if (locale == 'ar') sunsetStr = AppDateFormatter.toEasternArabicDigits(sunsetStr);
    }

    String? inviteToken;
    if (_generateInviteLink && _selectedUsers.isEmpty) {
      inviteToken = const Uuid().v4();
      _generatedInviteToken = inviteToken;
    } else {
      _generatedInviteToken = null;
    }

    final newAppt = Appointment.newAppointment(
      title: title,
      hostId: currentUser.id,
      date: dateTime,
      time: _duration == 0 ? '00:00' : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
      duration: finalDuration,
      region: location.isNotEmpty ? location : null,
      building: building.isNotEmpty ? building : null,
      coordinates: _coordinates.isNotEmpty ? _coordinates : null,
      privacy: _privacy,
      dateType: _isHijri ? 'hijri' : 'gregorian',
      hijriDate: hijriDateString,
      hijriMonth: hijri.hMonth,
      recurrenceType: _isRecurring ? _recurrenceType : null,
      recurrenceCount: _isRecurring ? _recurrenceCount : 1,
      recurrenceIndex: _isRecurring ? 1 : null,
      isFirstComeFirstServed: _isFirstComeFirstServed,
      streamLink: null,
      description: description.isNotEmpty ? description : null,
      sunset: sunsetStr,
      inviteToken: inviteToken,
      inviteLinkActive: inviteToken != null,
    );

    _isSaving = true;
    if (!_disposed) notifyListeners();

    try {
      _ignoreConflictCheck = true; // Set early to prevent flicker during createAppointment rebuilds
      final createdAppt = await appointmentProvider.createAppointment(
        newAppt, 
        invitees: _selectedUsers,
        inviteTitle: inviteTitle,
        inviteMessage: inviteMessage,
      );
      _highlightedAppointmentId = createdAppt.id;

      // Learn Immediately for Autocomplete
      _autocompleteService.learnSequence(title);
      if (location.isNotEmpty) {
        if (!_learnedLocations.containsKey(location)) {
           _learnedLocations[location] = {};
        }
        _learnedLocations[location]![building] = (_learnedLocations[location]![building] ?? 0) + 1;
      }

      if (_pinAddress) {
        final box = await Hive.openBox('appointment_drafts');
        await box.put('pinned_location', location);
        await box.put('pinned_building', building);
        await box.put('pinned_coordinates', _coordinates);
      }

      _draftService.clearDraft();
      _ignoreConflictCheck = true;
      _hasConflict = false;
      return null;
    } catch (e) {
      _ignoreConflictCheck = false;
      return e.toString();
    } finally {
      if (!_disposed) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }
}
