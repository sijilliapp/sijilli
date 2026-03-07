// 📍 lib/features/add/screens/add_event_screen.dart
// ➕ شاشة إضافة موعد جديد - مُحسنة ومقسمة

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/services/autocomplete_service.dart';
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
import '../../../core/utils/app_pickers.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

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
  const _AddEventScreenContent({super.key, this.initialAppointment, this.initialGuest});

  @override
  State<_AddEventScreenContent> createState() => _AddEventScreenContentState();
}

class _AddEventScreenContentState extends State<_AddEventScreenContent> {
  final _formKey = GlobalKey<FormState>();
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
    _titleFocusNode.addListener(_onTitleFocusChanged);
    _locationFocusNode.addListener(_onLocationFocusChanged);
    _buildingFocusNode.addListener(_onBuildingFocusChanged);
    
    final appt = widget.initialAppointment;
    
    _titleController = TextEditingController(text: appt?.title);
    _titleController.addListener(_onTitleChanged);
    
    _locationController = TextEditingController(text: appt?.region);
    _locationController.addListener(_onLocationChanged);
    
    _buildingController = TextEditingController(text: appt?.building);
    _buildingController.addListener(_onBuildingChanged);
    
    _streamLinkController = TextEditingController(text: appt?.streamLink);

    WidgetsBinding.instance.addPostFrameCallback((_) {
       final addEventProvider = context.read<AddEventProvider>();
       final appointmentProvider = context.read<AppointmentProvider>();
       // Collect history for Location Learning
       final history = [
         ...appointmentProvider.appointments,
         ...appointmentProvider.archivedAppointments,
       ];
       
       final auth = context.read<AuthProvider>();
       
       addEventProvider.init(widget.initialAppointment, history, currentUser: auth.user);
       addEventProvider.initLocations(history);
       
       if (widget.initialGuest != null) {
          addEventProvider.addInvitee(widget.initialGuest!);
       }
       
       // Trigger initial suggestion calculation
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
    context.read<AddEventProvider>().updateRegionSuggestions(_locationController.text);
    // Also update building suggestions if region changes (it might reset or change context)
    if (_isBuildingFocused) {
       context.read<AddEventProvider>().updateBuildingSuggestions(_locationController.text, _buildingController.text);
    }
  }

  void _onBuildingChanged() {
    context.read<AddEventProvider>().updateBuildingSuggestions(_locationController.text, _buildingController.text);
  }

  void _onRegionSelected(String region) {
    _locationController.text = region;
    // Move focus to building? Or just fill?
    // User often wants flow. Let's move to building.
    _buildingFocusNode.requestFocus();
    _locationController.selection = TextSelection.collapsed(offset: region.length);
  }

  void _onBuildingSelected(String building) {
    _buildingController.text = building;
    _buildingController.selection = TextSelection.collapsed(offset: building.length);
    // Maybe hide keyboard or just stay? Default stay.
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AddEventProvider>();

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
            style: TextStyle(color: provider.isSaving ? Colors.grey : AppColors.primary.withOpacity(0.7)),
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
    final durationOptions = [
      {'label': context.l10n.duration15m, 'value': 15},
      {'label': context.l10n.duration30m, 'value': 30},
      {'label': context.l10n.duration45m, 'value': 45},
      {'label': context.l10n.duration1h, 'value': 60},
      {'label': context.l10n.duration2h, 'value': 120},
      {'label': context.l10n.duration3h, 'value': 180},
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
        padding: const EdgeInsets.all(AppDimens.space),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                final name = auth.user?.name ?? auth.user?.username ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
                
                // Location Props
                locationFocusNode: _locationFocusNode,
                isLocationFocused: _isLocationFocused,
                buildingFocusNode: _buildingFocusNode,
                isBuildingFocused: _isBuildingFocused,
                regionSuggestions: provider.regionSuggestions,
                buildingSuggestions: provider.buildingSuggestions,
                onRegionSelected: _onRegionSelected,
                onBuildingSelected: _onBuildingSelected,
              ), 
              
            const SizedBox(height: AppDimens.space),
            
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
            
            const SizedBox(height: 8),

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
            
            const SizedBox(height: 16),
            
            InviteesWidget(
              invitees: provider.selectedUsers.map((u) => u.name.isNotEmpty ? u.name : u.username).toList(),
              onAddInvitees: () => _openInviteesSelector(provider),
              isFirstComeFirstServed: provider.isFirstComeFirstServed,
              onFirstComeChanged: provider.toggleFirstComeFirstServed,
              onRemoveInvitee: provider.removeInvitee,
            ),

            const SizedBox(height: 16),

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
            
            const SizedBox(height: 16),
            
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
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    showModalBottomSheet(
      context: context,
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
    
    // Check Time (Critical)
    // Assuming 'All Day' (duration 0) might not need specific time, but usually we need at least a date.
    if (provider.selectedDate == null) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(context.l10n.pleaseSelectDate), backgroundColor: AppColors.error));
       return;
    }
    
    // If not 'All Day', we typically need a specific time.
    // If selectedTime is null, prompt user.
    if (provider.selectedTime == null && provider.duration != 0) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(context.l10n.pleaseSelectTime), backgroundColor: AppColors.error));
       return;
    }

    if (_formKey.currentState?.validate() ?? false) {
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
  }

  void _showSuccessMessage() {
    if (widget.initialAppointment != null && Navigator.canPop(context)) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.pop(context);
      });
    } else {
      _performClearSilent();
    }
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
    _locationController.clear();
    _buildingController.clear();
    _streamLinkController.clear();
    context.read<AddEventProvider>().clearForm();
  }
}
