import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:adhan/adhan.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/autocomplete_service.dart';
import '../../../models/appointment.dart';
import '../../../models/user.dart';
import '../../appointments/providers/appointment_provider.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../l10n/app_localizations.dart';

import '../../../core/services/appointment_draft_service.dart';

class AddEventProvider extends ChangeNotifier {
  final AutocompleteService _autocompleteService = AutocompleteService();
  final LocationService _locationService = LocationService();
  final AppointmentDraftService _draftService = AppointmentDraftService();

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
  String _streamLink = '';

  String get draftTitle => _title;
  String get draftLocation => _location;
  String get draftBuilding => _building;
  String get draftStreamLink => _streamLink;


  // State
  bool _isSaving = false;
  String _privacy = 'public';
  bool _isHijri = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _duration = 45;
  DateTime? _selectedEndDate;
  final List<UserModel> _selectedUsers = [];
  Coordinates? _userCoordinates;
  double _hijriAdjustment = 0; // Added for Provider logic

  // Recurrence
  bool _isRecurring = false;
  String _recurrenceType = 'daily';
  int _recurrenceCount = 3;

  // First Come First Served
  bool _isFirstComeFirstServed = false;

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
    final timeStr = DateFormat('h:mm a', locale).format(endAt); 
    
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
      
      // 1. Privacy
      _privacy = initialAppointment.currentUserInvitation?.privacy ?? initialAppointment.privacy;
      
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
    } else {
      _selectedEndDate = _selectedDate;
      await _loadDraft();
    }
    
    _getUserLocation();
    
    // Initialize Suggestions with empty query (Zero-Keyboard)
    initLocations(history); // Build the location frequency map from history
    onTitleChanged(_title);
    updateRegionSuggestions(_location);
    updateBuildingSuggestions(_location, _building);
    
    // Safety check before notify
    if (!_disposed) {
      notifyListeners();
    }
  }

  // --- Draft Persistence ---

  Future<void> _loadDraft() async {
    final draft = await _draftService.loadDraft();
    if (draft == null) return;

    try {
      _title = draft['title'] ?? '';
      _location = draft['location'] ?? '';
      _building = draft['building'] ?? '';
      _streamLink = draft['streamLink'] ?? '';
      _privacy = draft['privacy'] ?? 'public';
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
      'streamLink': _streamLink,
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

  // Logic Methods
  void setPrivacy(String value) {
    _privacy = value; 
    _saveDraft();
    notifyListeners();
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
    _saveDraft();
    notifyListeners();
  }

  void setTime(TimeOfDay time) {
    _selectedTime = time;
    _saveDraft();
    notifyListeners();
  }

  void setDuration(int value) {
    _duration = value;
    if (!_canRecur()) _isRecurring = false;
    _saveDraft();
    notifyListeners();
  }

  void setEndDate(DateTime date) {
    _selectedEndDate = date;
    if (!_canRecur()) _isRecurring = false;
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

  void addInvitee(UserModel user) {
    if (!_selectedUsers.any((u) => u.id == user.id)) {
      _selectedUsers.add(user);
      _saveDraft();
      notifyListeners();
    }
  }

  void removeInvitee(int index) {
    _selectedUsers.removeAt(index);
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
       if (match.isHijri) {
         HijriCalendar.setLocal('ar');
         final hNow = HijriCalendar.now();
         int targetYear = hNow.hYear;
         // Note: User requested "Current Year" strictly.
         // We do NOT increment year even if date passed.
         
         final hTarget = HijriCalendar();
         hTarget.hYear = targetYear;
         hTarget.hMonth = match.month!;
         hTarget.hDay = match.day!;
         targetDate = hTarget.hijriToGregorian(targetYear, match.month!, match.day!);
         
         // Fix: Inverse adjust so the Picker displays the correct Hijri date
         if (_hijriAdjustment != 0) {
            targetDate = targetDate.subtract(Duration(days: _hijriAdjustment.toInt()));
         }
       } else {
         // Gregorian Date (Current Year)
         int targetYear = now.year;
         targetDate = DateTime(targetYear, match.month!, match.day!);
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
    
    // Sort logic: Just frequency for now? Or Recency?
    // Implementing Frequency Map
    for (var appt in history) {
      final region = appt.region?.trim() ?? '';
      final building = appt.building?.trim() ?? '';

      if (region.isEmpty) continue;

      if (!_learnedLocations.containsKey(region)) {
        _learnedLocations[region] = {};
      }
      
      if (building.isNotEmpty) {
        _learnedLocations[region]![building] = (_learnedLocations[region]![building] ?? 0) + 1;
      } else {
        // Ensure region exists even with no building
        // We can track region frequency by checking sum of buildings? 
        // Or store a special key for region-only usage?
        // Let's increment a generic counter or empty key
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
    
    if (normalizedQuery.isEmpty) {
      // Show top 10 most frequent
      allRegions.sort((a, b) => regionCounts[b]!.compareTo(regionCounts[a]!));
      _regionSuggestions = allRegions.take(10).toList();
    } else {
      // Filter by prefix/contains
      final matches = allRegions.where((r) => r.toLowerCase().contains(normalizedQuery)).toList();
      matches.sort((a, b) => regionCounts[b]!.compareTo(regionCounts[a]!));
      _regionSuggestions = matches.take(10).toList();
    }
    notifyListeners();
  }

  void updateBuildingSuggestions(String region, String query) {
    final targetRegion = region.trim(); // Case sensitive match usually desired for keys?
                                      // Or find key ignoring case.
    
    // Find exact key match for simplicity first
    // In real world, we might iterate keys.
    Map<String, int>? buildingsMap;
    
    // Try exact match
    if (_learnedLocations.containsKey(targetRegion)) {
      buildingsMap = _learnedLocations[targetRegion];
    } else {
      // Try loose match if exact fails?
      // For now strict hierarchy as per requirement.
      _buildingSuggestions = [];
      notifyListeners();
      return;
    }

    final normalizedQuery = query.trim().toLowerCase();
    final allBuildings = buildingsMap!.keys.where((k) => k.isNotEmpty).toList();

    if (normalizedQuery.isEmpty) {
       // Frequency Sort
       allBuildings.sort((a, b) => buildingsMap![b]!.compareTo(buildingsMap[a]!));
       _buildingSuggestions = allBuildings.take(10).toList();
    } else {
       final matches = allBuildings.where((b) => b.toLowerCase().contains(normalizedQuery)).toList();
       matches.sort((a, b) => buildingsMap![b]!.compareTo(buildingsMap[a]!));
       _buildingSuggestions = matches.take(10).toList();
    }
    notifyListeners();
  }

  // Form Actions
  void clearForm() {
    // We only reset state.
    // We only reset state.
    _selectedDate = DateTime.now();
    _selectedTime = null;
    _duration = 45;
    _selectedEndDate = DateTime.now();
    _selectedUsers.clear();
    _isRecurring = false;
    _isSaving = false;
    _privacy = 'public';
    _title = '';
    _location = '';
    _building = '';
    _streamLink = '';
    _draftService.clearDraft();
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
    required String streamLink,
    required UserModel currentUser,
    required AppointmentProvider appointmentProvider,
    required String locale,
    String? inviteTitle,
    String? inviteMessage,
  }) async {
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

    final newAppt = Appointment.newAppointment(
      title: title,
      hostId: currentUser.id,
      date: dateTime,
      time: _duration == 0 ? '00:00' : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
      duration: finalDuration,
      region: location.isNotEmpty ? location : null,
      building: building.isNotEmpty ? building : null,
      privacy: _privacy,
      dateType: _isHijri ? 'hijri' : 'gregorian',
      hijriDate: hijriDateString,
      hijriMonth: hijri.hMonth,
      recurrenceType: _isRecurring ? _recurrenceType : null,
      recurrenceCount: _isRecurring ? _recurrenceCount : 1,
      recurrenceIndex: _isRecurring ? 1 : null,
      isFirstComeFirstServed: _isFirstComeFirstServed,
      streamLink: streamLink.isNotEmpty ? streamLink : null,
      sunset: sunsetStr,
    );

    _isSaving = true;
    if (!_disposed) notifyListeners();

    try {
      final List<String> inviteeIds = _selectedUsers.map((u) => u.id).toList().cast<String>();
      await appointmentProvider.createAppointment(
        newAppt, 
        inviteeIds: inviteeIds,
        inviteTitle: inviteTitle,
        inviteMessage: inviteMessage,
      );

      // Learn Immediately for Autocomplete
      _autocompleteService.learnSequence(title);
      if (location.isNotEmpty) {
        if (!_learnedLocations.containsKey(location)) {
           _learnedLocations[location] = {};
        }
        if (building.isNotEmpty) {
          _learnedLocations[location]![building] = (_learnedLocations[location]![building] ?? 0) + 1;
        } else {
          _learnedLocations[location]![''] = (_learnedLocations[location]![''] ?? 0) + 1;
        }
      }

      _draftService.clearDraft();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      if (!_disposed) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }
}
