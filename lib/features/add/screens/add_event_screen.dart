// 📍 lib/features/add/screens/add_event_screen.dart
// ➕ شاشة إضافة موعد جديد - مُحسنة ومقسمة

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/appointment.dart';
import '../../auth/providers/auth_provider.dart';
import '../../appointments/providers/appointment_provider.dart';
import '../providers/add_event_provider.dart';
import '../widgets/event_form_widget.dart';
import '../widgets/unified_date_picker.dart';
import '../widgets/invitees_widget.dart';
import '../../appointments/widgets/atomic/user_invitee_sheet.dart';
import '../../../models/user.dart';
import '../../../core/constants/app_dimens.dart';
import '../widgets/add_event_widgets.dart';
import '../../appointments/widgets/sheets/appointment_confirmation_sheet.dart';
import '../../main/screens/main_screen.dart';
import '../../../core/utils/app_pickers.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import '../../../core/services/autocomplete_service.dart';
import 'location_picker_screen.dart';
import '../utils/smart_parser.dart';

class AddEventScreen extends StatelessWidget {
  final Appointment? initialAppointment;
  final UserModel? initialGuest;
  const AddEventScreen({super.key, this.initialAppointment, this.initialGuest});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AddEventProvider(),
      child: _AddEventScreenContent(initialAppointment: initialAppointment, initialGuest: initialGuest),
    );
  }
}

class _AddEventScreenContent extends StatefulWidget {
  final Appointment? initialAppointment;
  final UserModel? initialGuest;
  const _AddEventScreenContent({this.initialAppointment, this.initialGuest});

  @override
  State<_AddEventScreenContent> createState() => _AddEventScreenContentState();
}

class _AddEventScreenContentState extends State<_AddEventScreenContent> {
  final _formKey = GlobalKey<FormState>();
  late final ScrollController _scrollController;
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _buildingController;
  late final TextEditingController _streamLinkController;
  
  // Focus Nodes
  final FocusNode _titleFocusNode = FocusNode();
  bool _isTitleFocused = false;
  
  final FocusNode _locationFocusNode = FocusNode();
  bool _isLocationFocused = false;
  
  final FocusNode _buildingFocusNode = FocusNode();
  bool _isBuildingFocused = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _titleFocusNode.addListener(_onTitleFocusChanged);
    _locationFocusNode.addListener(_onLocationFocusChanged);
    _buildingFocusNode.addListener(_onBuildingFocusChanged);
    
    final appt = widget.initialAppointment;
    
    _titleController = TextEditingController(text: appt?.title);
    _titleController.addListener(_onTitleChanged);
    
    _locationController = TextEditingController(text: appt?.region);
    _locationController.addListener(_onLocationChanged);
    
    _buildingController = TextEditingController(text: appt?.cleanBuilding);
    _buildingController.addListener(_onBuildingChanged);
    
    _streamLinkController = TextEditingController(text: appt?.streamLink);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
       final addEventProvider = context.read<AddEventProvider>();
       final appointmentProvider = context.read<AppointmentProvider>();
       // Collect history for Location Learning
       final history = [
         ...appointmentProvider.appointments,
         ...appointmentProvider.archivedAppointments,
       ];
       
       final auth = context.read<AuthProvider>();
       
       await addEventProvider.init(widget.initialAppointment, history, currentUser: auth.user);
       addEventProvider.initLocations(history);
       
       if (widget.initialGuest != null) {
          addEventProvider.addInvitee(widget.initialGuest!);
       }
       
       // --- Restoring Draft to Controllers ---
       if (widget.initialAppointment == null) {
          if (addEventProvider.draftTitle.isNotEmpty) {
            _titleController.text = addEventProvider.draftTitle;
          }
          if (addEventProvider.draftLocation.isNotEmpty) {
            _locationController.text = addEventProvider.draftLocation;
          }
          if (addEventProvider.draftBuilding.isNotEmpty) {
            _buildingController.text = addEventProvider.draftBuilding;
          }
          if (addEventProvider.draftStreamLink.isNotEmpty) {
            _streamLinkController.text = addEventProvider.draftStreamLink;
          }
       }

       // Trigger suggestion calculation (after title is potentially restored)
       addEventProvider.onTitleChanged(_titleController.text);
    });
  }

  void _onTitleFocusChanged() {
    if (_titleFocusNode.hasFocus) {
       setState(() => _isTitleFocused = true);
    } else {
       Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_titleFocusNode.hasFocus) {
             setState(() => _isTitleFocused = false);
          }
       });
    }
  }

  void _onTitleChanged() {
    final text = _titleController.text;
    context.read<AddEventProvider>().onTitleChanged(text);
  }

  void _onWordSelected(String word) {
    final text = _titleController.text;
    String newText;
    
    if (text.isNotEmpty && !text.endsWith(' ')) {
      final lastSpaceIndex = text.lastIndexOf(' ');
      if (lastSpaceIndex == -1) {
        newText = '$word ';
      } else {
        newText = '${text.substring(0, lastSpaceIndex + 1)}$word ';
      }
    } else {
      newText = '$text$word ';
    }
    
    _titleController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    
    _titleFocusNode.requestFocus();
    context.read<AddEventProvider>().checkDateMatch(newText.trim());
  }

  void _onPivotSelected(PivotMatch match) {
    _titleController.value = TextEditingValue(
      text: match.fullTitle,
      selection: TextSelection.collapsed(offset: match.fullTitle.length),
    );
    _titleFocusNode.requestFocus();
    context.read<AddEventProvider>().onTitleChanged(match.fullTitle);
    context.read<AddEventProvider>().checkDateMatch(match.fullTitle);
  }

  void _onLocationFocusChanged() {
    if (_locationFocusNode.hasFocus) {
      setState(() => _isLocationFocused = true);
      context.read<AddEventProvider>().updateRegionSuggestions(_locationController.text);
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_locationFocusNode.hasFocus) {
          setState(() => _isLocationFocused = false);
        }
      });
    }
  }

  void _onBuildingFocusChanged() {
    if (_buildingFocusNode.hasFocus) {
      setState(() => _isBuildingFocused = true);
      context.read<AddEventProvider>().updateBuildingSuggestions(_locationController.text, _buildingController.text);
    } else {
       Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_buildingFocusNode.hasFocus) {
          setState(() => _isBuildingFocused = false);
        }
      });
    }
  }

  void _onLocationChanged() {
    final text = _locationController.text;
    context.read<AddEventProvider>().setLocation(text);
    context.read<AddEventProvider>().updateRegionSuggestions(text);
    // Also update building suggestions if region changes (it might reset or change context)
    if (_isBuildingFocused) {
       context.read<AddEventProvider>().updateBuildingSuggestions(text, _buildingController.text);
    }
  }

  void _onBuildingChanged() {
    final text = _buildingController.text;
    context.read<AddEventProvider>().setBuilding(text);
    context.read<AddEventProvider>().updateBuildingSuggestions(_locationController.text, text);
  }

  void _onSmartParse() async {
    String text = '';
    bool fromClipboard = false;
    
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null && clipboardData.text != null && clipboardData.text!.trim().isNotEmpty) {
        text = clipboardData.text!.trim();
        if (text.length > 120) {
          text = text.substring(0, 120);
        }
        fromClipboard = true;
      }
    } catch (e) {
      print('Clipboard error: $e');
    }

    if (text.isEmpty) {
      text = _titleController.text.trim();
    }

    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى نسخ نص الدعوة إلى الحافظة أو كتابته في حقل الموضوع أولاً!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final parsed = ArabicSmartParser.parse(text);
    
    // تحديث قيم حقول الإدخال
    _titleController.text = parsed.title;
    context.read<AddEventProvider>().onTitleChanged(parsed.title);

    if (parsed.region != null && parsed.region!.isNotEmpty) {
      _locationController.text = parsed.region!;
      context.read<AddEventProvider>().setLocation(parsed.region!);
    }

    if (parsed.building != null && parsed.building!.isNotEmpty) {
      _buildingController.text = parsed.building!;
      context.read<AddEventProvider>().setBuilding(parsed.building!);
    }

    if (parsed.time != null && parsed.time!.isNotEmpty) {
      final parts = parsed.time!.split(':');
      if (parts.length == 2) {
        int hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        
        if (parsed.timePeriod != null) {
          if (parsed.timePeriod == 'م') {
            if (hour < 12) hour += 12;
          } else if (parsed.timePeriod == 'ص') {
            if (hour == 12) hour = 0;
          }
        }
        final parsedTime = TimeOfDay(hour: hour, minute: minute);
        context.read<AddEventProvider>().setTime(parsedTime);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(fromClipboard 
              ? 'تم تفكيك النص من الحافظة (أول ١٢٠ حرف) وتوزيع البيانات!' 
              : 'تم تفكيك نص الموضوع وتوزيع البيانات!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onRegionSelected(String region) {
    _locationController.text = region;
    context.read<AddEventProvider>().setLocation(region);
    // Move focus to building? Or just fill?
    // User often wants flow. Let's move to building.
    _buildingFocusNode.requestFocus();
    _locationController.selection = TextSelection.collapsed(offset: region.length);
  }

  void _onBuildingSelected(String building) {
    _buildingController.text = building;
    context.read<AddEventProvider>().setBuilding(building);
    _buildingController.selection = TextSelection.collapsed(offset: building.length);
    // Maybe hide keyboard or just stay? Default stay.
  }

  Future<void> _openLocationPicker(AddEventProvider provider) async {
    double? initialLat;
    double? initialLon;
    final coordsText = provider.draftCoordinates;
    if (coordsText.isNotEmpty) {
      final coords = coordsText.split(',');
      if (coords.length == 2) {
        initialLat = double.tryParse(coords[0]);
        initialLon = double.tryParse(coords[1]);
      }
    } else {
      final buildingText = _buildingController.text;
      final parts = buildingText.split('|');
      if (parts.length > 1) {
        final coords = parts.last.trim().split(',');
        if (coords.length == 2) {
          initialLat = double.tryParse(coords[0]);
          initialLon = double.tryParse(coords[1]);
        }
      }
    }

    final LocationPickerResult? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLatitude: initialLat,
          initialLongitude: initialLon,
        ),
      ),
    );

    if (result != null && mounted) {
      _locationController.removeListener(_onLocationChanged);
      _buildingController.removeListener(_onBuildingChanged);

      // Only populate region/location if currently empty and map result has a value
      if (_locationController.text.trim().isEmpty && result.region.isNotEmpty) {
        _locationController.text = result.region;
        provider.setLocation(result.region);
      }
      
      // Only populate building if currently empty and map result has a value
      if (_buildingController.text.trim().isEmpty && result.building.isNotEmpty) {
        _buildingController.text = result.building;
        provider.setBuilding(result.building);
      }
      
      provider.setCoordinates('${result.latitude},${result.longitude}');

      _locationController.addListener(_onLocationChanged);
      _buildingController.addListener(_onBuildingChanged);
    }
  }

  @override
  void dispose() {
    _titleFocusNode.removeListener(_onTitleFocusChanged);
    _locationFocusNode.removeListener(_onLocationFocusChanged);
    _buildingFocusNode.removeListener(_onBuildingFocusChanged);
    
    _titleFocusNode.dispose();
    _locationFocusNode.dispose();
    _buildingFocusNode.dispose();
    
    _titleController.dispose();
    _locationController.dispose();
    _buildingController.dispose();
    _streamLinkController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int _lastHistoryCount = -1;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AddEventProvider>();
    
    // Listen for history changes to keep the "Personal Autocomplete" engine synced
    final apptProvider = context.watch<AppointmentProvider>();
    final history = [...apptProvider.appointments, ...apptProvider.archivedAppointments];
    
    // Safety sync: Ensure provider has latest history if it was initialized empty or changed
    if (history.length != _lastHistoryCount) {
      _lastHistoryCount = history.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          provider.refreshHistory(history);
        }
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(provider),
      body: _buildBody(provider),
    );
  }

  PreferredSizeWidget _buildAppBar(AddEventProvider provider) {
    return AppBar(
      title: Text(widget.initialAppointment != null ? context.l10n.editAppointment : context.l10n.createAppointment),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: Theme.of(context).brightness == Brightness.dark ? Brightness.dark : Brightness.light,
      ),
      automaticallyImplyLeading: true, 
      actions: [
        TextButton(
          onPressed: provider.isSaving ? null : _clearForm, 
          child: Text(
            context.l10n.clear,
            style: TextStyle(color: provider.isSaving ? Colors.grey : AppColors.primary.withValues(alpha: 0.7)),
          ),
        ),
        provider.isSaving 
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                   width: 20, 
                   height: 20, 
                   child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)
                ),
              )
            : TextButton(
                onPressed: _saveEvent,
                child: Text(
                  context.l10n.save,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildBody(AddEventProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final durationOptions = [
      {'label': context.l10n.duration15m, 'value': 15},
      {'label': context.l10n.duration30m, 'value': 30},
      {'label': context.l10n.duration45m, 'value': 45},
      {'label': context.l10n.duration1h, 'value': 60},
      {'label': context.l10n.duration2h, 'value': 120},
      {'label': context.l10n.duration3h, 'value': 180},
      {'label': context.l10n.duration6h, 'value': 360},
      {'label': context.l10n.duration12h, 'value': 720},
      {'label': context.l10n.durationAllDay, 'value': 0},
    ];

    final recurrenceOptions = [
      {'label': context.l10n.recurrenceDaily, 'value': 'daily'},
      {'label': context.l10n.recurrenceWeekly, 'value': 'weekly'},
      {'label': context.l10n.recurrenceMonthly, 'value': 'monthly'},
      {'label': context.l10n.recurrenceAnnual, 'value': 'annual'},
    ];

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.space, vertical: AppDimens.spaceXS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                final name = auth.user?.name ?? auth.user?.username ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${context.l10n.you}: $name',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),

            EventFormWidget(
                titleController: _titleController,
                titleFocusNode: _titleFocusNode,
                isTitleFocused: _isTitleFocused,
                locationController: _locationController,
                buildingController: _buildingController,
                streamLinkController: _streamLinkController,
                privacy: provider.privacy,
                onPrivacyChanged: provider.setPrivacy,
                titleValidator: (val) => val == null || val.trim().isEmpty ? context.l10n.fieldRequired : null,
                suggestions: provider.suggestions,
                onWordSelected: _onWordSelected,
                pivotSuggestions: provider.pivotSuggestions,
                onPivotSelected: _onPivotSelected,
                onSmartParse: _onSmartParse,
                
                // Location Props
                locationFocusNode: _locationFocusNode,
                isLocationFocused: _isLocationFocused,
                buildingFocusNode: _buildingFocusNode,
                isBuildingFocused: _isBuildingFocused,
                regionSuggestions: provider.regionSuggestions,
                buildingSuggestions: provider.buildingSuggestions,
                onRegionSelected: _onRegionSelected,
                onBuildingSelected: _onBuildingSelected,
                pinAddress: provider.pinAddress,
                onPinAddressChanged: (val) => provider.setPinAddress(val),
                onOpenLocationPicker: () => _openLocationPicker(provider),
              ), 
            
            const SizedBox(height: AppDimens.spaceXXS),
            
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return Column(
                  children: [
                    UnifiedDatePicker(
                      initialDate: provider.selectedDate ?? DateTime.now(),
                      initialMode: provider.isHijri,
                      hijriAdjustment: (auth.user?.hijriAdjustment ?? 0).toInt(),
                      onDateChanged: provider.setDate,
                      onModeChanged: provider.setIsHijri,
                    ),
                    PrayerTimesRow(
                      sunriseTime: provider.sunriseTime,
                      dhuhrTime: provider.dhuhrTime,
                      sunsetTime: provider.sunsetTime,
                    ),
                  ],
                );
              },
            ),
            
            const SizedBox(height: AppDimens.spaceXXS),

            DateTimeSection(
              isHijri: provider.isHijri,
              duration: provider.duration,
              selectedTime: provider.selectedTime,
              onSelectTime: _selectTime,
              durationOptions: durationOptions,
              onDurationChanged: provider.setDuration,
              endDisplay: provider.getEndDisplay(context.l10n),
              onSelectEndDate: () => _selectEndDate(provider),
            ),
            
            if (provider.hasConflict) ...[
              const SizedBox(height: AppDimens.spaceXXS),
              _buildConflictAlert(),
            ],
            
            const SizedBox(height: AppDimens.spaceXS),
            
            InviteesWidget(
              invitees: provider.selectedUsers,
              onAddInvitees: () => _openInviteesSelector(provider),
              isFirstComeFirstServed: provider.isFirstComeFirstServed,
              onFirstComeChanged: provider.toggleFirstComeFirstServed,
              onRemoveInvitee: provider.removeInvitee,
            ),

            if (provider.selectedUsers.isEmpty) ...[
              const SizedBox(height: AppDimens.spaceXS),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.grey.shade800 
                      : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.localeName == 'ar' 
                              ? 'رابط دعوة لضيف غير مسجل' 
                              : 'Invite link for unregistered guest',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.localeName == 'ar' 
                              ? 'سيتم توليد رابط مؤقت لمشاركته مع ضيفك' 
                              : 'A temporary link will be generated to share with your guest',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.grey.shade400 
                                : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: provider.generateInviteLink,
                      onChanged: provider.setGenerateInviteLink,
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppDimens.spaceXS),

            // Recurrence
            if (provider.duration < 1440) 
            RecurrenceSection(
              isRecurring: provider.isRecurring,
              onToggle: provider.toggleRecurrence,
              recurrenceType: provider.recurrenceType,
              recurrenceCount: provider.recurrenceCount,
              recurrenceOptions: recurrenceOptions,
              onTypeChanged: provider.setRecurrenceType,
              onCountChanged: provider.setRecurrenceCount,
            ),
            
            const SizedBox(height: AppDimens.spaceXS),
            
            // Link Field (Moved to Bottom)
            // Import CustomTextField if not available in this file scope (It might come from imports or EventFormWidget exports)
            // AddEventScreen imports EventFormWidget but CustomTextField is in core/widgets.
            // Wait, AddEventScreen does NOT import CustomTextField directly in the snippet I saw.
            // It imports `../widgets/event_form_widget.dart`.
            // I need to import CustomTextField in AddEventScreen or use fully qualified.
            // Actually it is `../../../core/widgets/custom_text_field.dart`.
            // I will check imports at the top.
            // Assuming I need to add import. But first let's place the code.
            
             // رابط البث
            // Link Field Moved to EventFormWidget

            const SizedBox(height: AppDimens.spaceXS),

            // Save and Clear Buttons stacked vertically at the bottom of the page
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: provider.isSaving ? null : _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: provider.isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          context.l10n.save,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: provider.isSaving ? null : _clearForm,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                    side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    context.l10n.clear,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32), // Bottom padding
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime() async {
    final time = await AppPickers.showStyledTimePicker(context);
    if (time != null && mounted) {
      context.read<AddEventProvider>().setTime(time);
    }
  }

  Future<void> _selectEndDate(AddEventProvider provider) async {
    if (provider.isHijri) return; 
    
    final picked = await AppPickers.showStyledDatePicker(
      context: context,
      initialDate: provider.selectedEndDate ?? provider.selectedDate ?? DateTime.now(),
      firstDate: provider.selectedDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    
    if (picked != null) {
      provider.setEndDate(picked);
    }
  }



  void _openInviteesSelector(AddEventProvider provider) {
    if (provider.selectedUsers.length >= 5) return;
    
    // Create temp appointment strictly for display in sheet if needed
    final tempAppt = Appointment(
      id: '',
      title: _titleController.text,
      hostId: context.read<AuthProvider>().user?.id ?? '',
      startAt: provider.selectedDate?.toUtc() ?? DateTime.now().toUtc(),
      duration: provider.duration,
      date: provider.selectedDate ?? DateTime.now(),
      time: '${provider.selectedTime?.hour}:${provider.selectedTime?.minute}',
      participants: provider.selectedUsers.map((u) => Invitation(
        id: '', 
        appointmentId: '', 
        userId: u.id, 
        status: InvitationStatus.pending,
        user: u
      )).toList(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserInviteeSheet(
        appointment: tempAppt,
        onUserSelected: (user) {
           // We can check duplicate here or in provider. Provider handles it gracefully.
           // However to show snackbar we might need to check return value or check list.
           if (provider.selectedUsers.any((u) => u.id == user.id)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.userAlreadyAdded)),
              );
           } else {
              provider.addInvitee(user);
              Navigator.pop(context);
           }
        },
      ),
    );
  }

  Future<void> _saveEvent() async {
    // 1. Explicit Check for Required Attributes (beyond Form fields)
    final provider = context.read<AddEventProvider>();
    
    // Check Date
    if (provider.selectedDate == null) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(context.l10n.pleaseSelectDate), backgroundColor: AppColors.error));
       _scrollController.animateTo(
         180.0,
         duration: const Duration(milliseconds: 300),
         curve: Curves.easeOut,
       );
       return;
    }
    
    // Check Time
    if (provider.selectedTime == null && provider.duration != 0) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(context.l10n.pleaseSelectTime), backgroundColor: AppColors.error));
       _scrollController.animateTo(
         240.0,
         duration: const Duration(milliseconds: 300),
         curve: Curves.easeOut,
       );
       return;
    }

    // Validate form fields, and scroll to title if empty
    if (!(_formKey.currentState?.validate() ?? false)) {
       if (_titleController.text.trim().isEmpty) {
         _titleFocusNode.requestFocus();
         _scrollController.animateTo(
           0,
           duration: const Duration(milliseconds: 300),
           curve: Curves.easeOut,
         );
       }
       return;
    }

    final auth = context.read<AuthProvider>();
    final apptProvider = context.read<AppointmentProvider>();
    
    if (auth.user == null) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.pleaseLoginFirst)));
       return;
    }

    final host = auth.user;
    
    DateTime startAt;
    if (provider.selectedTime != null) {
      startAt = DateTime(
         provider.selectedDate!.year,
         provider.selectedDate!.month,
         provider.selectedDate!.day,
         provider.selectedTime!.hour,
         provider.selectedTime!.minute,
      );
    } else {
      startAt = provider.selectedDate ?? DateTime.now();
    }

    // 1.5 Check for Conflicts
    bool hasConflict = false;
    if (provider.duration > 0) {
        final conflicts = apptProvider.getConflictingAppointments(
          startAt, 
          provider.duration,
          excludeId: widget.initialAppointment?.id // Don't conflict with self
        );
        hasConflict = conflicts.isNotEmpty;
    }

    // 2. Show Confirmation Sheet
     final bool confirmed = await showModalBottomSheet<bool>(
       context: context,
       isScrollControlled: true,
       backgroundColor: Colors.transparent,
       builder: (context) => AppointmentConfirmationSheet(
         host: host,
         invitees: provider.selectedUsers,
         title: _titleController.text,
         startAt: startAt,
         duration: provider.duration,
         isHijri: provider.isHijri,
         hijriAdjustment: provider.hijriAdjustment.toInt(),
         region: _locationController.text,
         building: _buildingController.text,
         hasConflict: hasConflict,
         privacy: provider.privacy,
       ),
     ) ?? false;

    if (!confirmed) return;

    // 3. Proceed to Save
    final error = await provider.saveEvent(
      title: _titleController.text,
      location: _locationController.text,
      building: _buildingController.text,
      streamLink: _streamLinkController.text,
      currentUser: auth.user!,
      appointmentProvider: apptProvider,
      locale: context.l10n.localeName,
      inviteTitle: context.l10n.newInvitation,
      inviteMessage: context.l10n.invitedYouTo(
        auth.user?.name ?? auth.user?.username ?? context.l10n.user,
        _titleController.text
      ),
    );
    
    if (error != null) {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.error));
       }
    } else {
      if (mounted) _showSuccessMessage();
    }
  }

  void _showSuccessMessage() {
    final provider = context.read<AddEventProvider>();
    final token = provider.generatedInviteToken;
    
    if (token != null) {
      _showInviteLinkDialog(token);
    } else {
      if (widget.initialAppointment != null && Navigator.canPop(context)) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        _performClearSilent();
        context.findAncestorStateOfType<MainScreenState>()?.setIndex(0);
      }
    }
  }

  void _showInviteLinkDialog(String token) {
    final inviteLink = 'https://sijilli.com/join?token=$token';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.share, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                context.l10n.localeName == 'ar' ? 'رابط دعوة الضيف' : 'Guest Invite Link',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.localeName == 'ar' 
                  ? 'تم إنشاء الموعد بنجاح! شارك هذا الرابط المؤقت مع ضيفك ليقوم بالتسجيل وقبول الدعوة مباشرة:' 
                  : 'Appointment created successfully! Share this temporary link with your guest to sign up and accept the invitation:',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        inviteLink,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20, color: AppColors.primary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: inviteLink));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n.localeName == 'ar' ? 'تم نسخ الرابط!' : 'Link copied!',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _performClearSilent();
                context.findAncestorStateOfType<MainScreenState>()?.setIndex(0);
              },
              child: Text(
                context.l10n.localeName == 'ar' ? 'إغلاق ومتابعة' : 'Close & Continue',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _clearForm() {
    final provider = context.read<AddEventProvider>();
    if (provider.hasFormData(_titleController.text, _locationController.text, _buildingController.text)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.clearFormTitle),
          content: Text(context.l10n.clearFormConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _performClear();
              },
              child: Text(
                context.l10n.clear,
                style: const TextStyle(color: AppColors.warning),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _performClear() {
    _performClearSilent();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.formClearedSuccessfully),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _performClearSilent() {
    _titleController.clear();
    _streamLinkController.clear();
    
    // Temporarily remove listeners to prevent updating provider with empty values on clear
    _locationController.removeListener(_onLocationChanged);
    _buildingController.removeListener(_onBuildingChanged);
    
    final provider = context.read<AddEventProvider>();
    provider.clearForm();
    
    _locationController.text = provider.draftLocation;
    _buildingController.text = provider.draftBuilding;
    
    // Re-attach listeners
    _locationController.addListener(_onLocationChanged);
    _buildingController.addListener(_onBuildingChanged);
  }

  Widget _buildConflictAlert() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.conflictAlert,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  context.l10n.conflictMessage,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.orange.shade200 : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
