import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/models/appointment.dart';
import 'package:sijilli/features/auth/providers/auth_provider.dart';
import 'package:sijilli/features/appointments/services/pb_appointment_service.dart';
import 'package:sijilli/features/appointments/providers/appointment_provider.dart';
import 'package:sijilli/features/appointments/providers/category_provider.dart';
import 'package:sijilli/features/add/screens/add_event_screen.dart';
import 'package:intl/intl.dart';
import 'package:sijilli/core/utils/app_date_formatter.dart';
import 'package:adhan/adhan.dart'; // For Sunset Calculation
import 'package:hijri/hijri_calendar.dart'; // For robust Hijri
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:uuid/uuid.dart';

// Refactored Components
import 'components/appointment_header.dart';
import 'components/appointment_date_time_card.dart';
import 'components/appointment_privacy_toggle.dart';
import 'components/appointment_action_buttons.dart';
import 'components/appointment_category_selector.dart';
import 'components/appointment_notes_section.dart';
import 'components/appointment_participants_list.dart';
import '../atomic/user_invitee_sheet.dart';

class AppointmentDetailsSheet extends StatefulWidget {
  final Appointment appointment;

  const AppointmentDetailsSheet({super.key, required this.appointment});

  @override
  State<AppointmentDetailsSheet> createState() => _AppointmentDetailsSheetState();
}

class _AppointmentDetailsSheetState extends State<AppointmentDetailsSheet> {
  late Appointment _appointment;
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  // Calculated Values
  late String _dayName;
  late String _datesLine;
  late String _timeLine;
  String? _sunsetTime;
  String? _durationText;
  
  // State
  late String _selectedPrivacy;
  AppointmentCategory? _selectedCategories;
  bool _isLinkActionLoading = false;
  
  // All Day Specifics
  String? _startDay;
  String? _startGreg;
  String? _startHijri;
  String? _endDay;
  String? _endGreg;
  String? _endHijri;

  @override
  void initState() {
    super.initState();
    _appointment = widget.appointment;
    _selectedPrivacy = widget.appointment.viewerRecord?.privacy ?? 'private';
    _selectedCategories = widget.appointment.viewerRecord?.categories;
    // _calculateData will be called in didChangeDependencies to support live updates
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 🔔 LISTEN to AuthProvider changes (e.g. Hijri Adjustment)
    // This ensures the sheet updates immediately when the user changes settings or global adjustment happens.
    final auth = Provider.of<AuthProvider>(context, listen: true);
    _calculateData(auth);
  }
  void _calculateData(AuthProvider auth) {
    final locale = Localizations.localeOf(context).languageCode;

    // 1. Duration Text
    if (_appointment.isAllDay) {
      _durationText = context.l10n.durationAllDay;
    } else {
      _durationText = AppDateFormatter.formatDuration(Duration(minutes: _appointment.duration), locale, context.l10n);
    }

    // 2. Sunset Time
    if (_appointment.sunset != null && _appointment.sunset!.isNotEmpty) {
      _sunsetTime = _appointment.sunset;
      if (locale == 'ar') _sunsetTime = AppDateFormatter.toEasternArabicDigits(_sunsetTime!);
    } else {
      final coords = Coordinates(24.7136, 46.6753); 
      final params = CalculationMethod.umm_al_qura.getParameters();
      final prayerTimes = PrayerTimes.today(coords, params);
      
      final maghrib = prayerTimes.maghrib;
      final h = maghrib.hour > 12 ? maghrib.hour - 12 : (maghrib.hour == 0 ? 12 : maghrib.hour);
      final m = maghrib.minute.toString().padLeft(2, '0');
      final tp = maghrib.hour >= 12 ? context.l10n.pm : context.l10n.am;
      _sunsetTime = '$h:$m $tp'; 
      if (locale == 'ar') _sunsetTime = AppDateFormatter.toEasternArabicDigits(_sunsetTime!);
    }

    // 3. Date & Time Logic
    // PRD: The appointment dates and reality always reflect the Page Owner's calendar context.
    final int adjustment = _appointment.contextAdjustment;

    // A. ALL DAY LOGIC
    if (_appointment.isAllDay) {
        final rawStart = _appointment.startAt.toLocal();
        final rawEnd = rawStart.add(Duration(minutes: _appointment.duration));
        final visualEnd = rawEnd.subtract(const Duration(seconds: 1));

        // rawStart is physically true for both Hijri and Gregorian types.
        // We shift forward by host adjustment to get what the host's Hijri calendar dictates.
        final DateTime startGreg = rawStart;
        final DateTime endGreg = visualEnd;
        final DateTime startHijriBase = rawStart.add(Duration(days: adjustment));
        final DateTime endHijriBase = visualEnd.add(Duration(days: adjustment));

        // Start
        _startDay = DateFormat('EEEE', locale).format(startGreg);
        _startGreg = DateFormat('d MMMM yyyy', locale).format(startGreg);
        final hStart = HijriCalendar.fromDate(startHijriBase);
        _startHijri = locale == 'ar'
            ? '${hStart.hDay} ${hStart.longMonthName} ${hStart.hYear}'
            : '${hStart.hYear}/${hStart.hMonth}/${hStart.hDay}';

        // End
        _endDay = DateFormat('EEEE', locale).format(endGreg);
        _endGreg = DateFormat('d MMMM yyyy', locale).format(endGreg);
        final hEnd = HijriCalendar.fromDate(endHijriBase);
        _endHijri = locale == 'ar'
            ? '${hEnd.hDay} ${hEnd.longMonthName} ${hEnd.hYear}'
            : '${hEnd.hYear}/${hEnd.hMonth}/${hEnd.hDay}';

        // Localize Digits
        if (locale == 'ar') {
          _startGreg = AppDateFormatter.toEasternArabicDigits(_startGreg!);
          _startHijri = AppDateFormatter.toEasternArabicDigits(_startHijri!);
          _endGreg = AppDateFormatter.toEasternArabicDigits(_endGreg!);
          _endHijri = AppDateFormatter.toEasternArabicDigits(_endHijri!);
        }
        
        // Fallbacks for required fields (wont be shown)
        _dayName = ''; 
        _datesLine = '';
        _timeLine = ''; 

    } else {
       // B. STANDARD LOGIC
       _startDay = null; _startGreg = null; _startHijri = null;
       _endDay = null; _endGreg = null; _endHijri = null;

       final dateStrategy = AppDateFormatter.formatAppointmentDateStrategy(_appointment, adjustment, locale);
       _dayName = dateStrategy.dayName;
       _datesLine = '${dateStrategy.primaryDate} - ${dateStrategy.secondaryDate}';
       if (locale == 'ar') _datesLine = AppDateFormatter.toEasternArabicDigits(_datesLine);

       _timeLine = AppDateFormatter.formatTime12h(_appointment.fullDateTime, locale);
       if (locale == 'ar') _timeLine = AppDateFormatter.toEasternArabicDigits(_timeLine);
    }
  }

  bool get _isHost {
     final auth = Provider.of<AuthProvider>(context, listen: false);
     final currentUserId = auth.user?.id;
     final isHost = _appointment.hostId == currentUserId;
     print('🔍 [_isHost Check] apptHost=${_appointment.hostId}, currentUserId=$currentUserId, result=$isHost');
     return isHost;
  }

  bool get _isAdmin {
     final auth = Provider.of<AuthProvider>(context, listen: false);
     return auth.user?.isAdmin ?? false;
  }

  @override
  Widget build(BuildContext context) {
    const double initialSize = 0.65; 
    const double minSize = 0.5;
    const double maxSize = 0.95;

    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      expand: false, 
      controller: _sheetController,
      builder: (context, scrollController) {
        return Material(
          color: AppColors.getCardBackground(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXXL)),
          elevation: 10,
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.getBorder(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppDimens.padding),
                  children: [
                    // --- 1. Top Section ---
                    
                    AppointmentHeader(
                      title: _appointment.title,
                      smartLocation: _appointment.smartLocation,
                      hasLocation: _appointment.hasLocation,
                      coordinates: _appointment.locationCoordinates,
                    ),

                    const SizedBox(height: AppDimens.spaceL),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimens.padding),
                      child: AppointmentDateTimeCard(
                        dayName: _dayName,
                        datesLine: _datesLine,
                        timeLine: _timeLine,
                        isAllDay: _appointment.isAllDay,
                        startDay: _startDay,
                        startGreg: _startGreg,
                        startHijri: _startHijri,
                        endDay: _endDay,
                        endGreg: _endGreg,
                        endHijri: _endHijri,
                      ),
                    ),

                    const SizedBox(height: AppDimens.spaceL),

                    AppointmentPrivacyToggle(
                      selectedPrivacy: _selectedPrivacy,
                      onPrivacyChanged: (val) {
                        setState(() => _selectedPrivacy = val);
                        context.read<AppointmentProvider>().updateInvitationSettings(
                          widget.appointment.id,
                          privacy: _selectedPrivacy,
                          categories: _selectedCategories,
                        );
                        Navigator.pop(context);
                      },
                    ),



                    if (_isHost || _isAdmin || _appointment.viewerRecord != null) ...[
                      AppointmentActionButtons(
                        isArchived: _appointment.isArchived,
                        onClone: () {
                           Navigator.pop(context);
                           Navigator.push(
                             context, 
                             MaterialPageRoute(builder: (_) => AddEventScreen(initialAppointment: _appointment))
                           );
                        },
                        onArchive: () {
                           final provider = context.read<AppointmentProvider>();
                           if (_appointment.isArchived) {
                             provider.unarchiveInvitation(_appointment.id);
                           } else {
                             provider.archiveInvitation(_appointment.id);
                           }
                           Navigator.pop(context);
                        },
                        onDelete: _showDeleteDialog,
                      ),
                      const SizedBox(height: AppDimens.spaceL),
                    ],
                    Divider(color: AppColors.getBorder(context)),
                    const SizedBox(height: AppDimens.spaceL),

                    // --- 2. Bottom Section ---

                    AppointmentCategorySelector(
                      appointment: _appointment,
                      selectedCategory: _selectedCategories,
                      onCategoryChanged: (cat) {
                         setState(() => _selectedCategories = cat);
                         context.read<AppointmentProvider>().updateInvitationSettings(
                           widget.appointment.id,
                           privacy: _selectedPrivacy,
                           categories: cat,
                         );
                      },
                      onAddCategory: () => _showAddCategoryDialog(context),
                    ),

                    const SizedBox(height: AppDimens.spaceL),

                    AppointmentNotesSection(
                      appointment: _appointment,
                      isHost: _isHost,
                      sunsetTime: _sunsetTime,
                      durationText: _durationText,
                      onEdit: (field, value) => _editField(field, value),
                    ),

                    const SizedBox(height: AppDimens.spaceL),

                     AppointmentParticipantsList(
                      appointmentId: _appointment.id,
                      isHost: _isHost,
                      hostId: _appointment.hostId,
                      hostName: _appointment.hostName,
                      hostAvatar: _appointment.hostAvatar,
                      participants: _appointment.participants,
                      isPast: _appointment.isPast,
                      createdAt: _appointment.createdAt,
                      viewerStatus: _appointment.viewerRecord?.status,
                    ),

                    const SizedBox(height: 40),

                    // K. Main Action Button (Bottom)
                    if (_isHost) ...[
                      Builder(
                        builder: (context) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    print('🔘 [زر الاستضافة] تم الضغط');
                                    _openInviteSheet();
                                  }, 
                                  icon: const Icon(Icons.person_add_alt_1, size: 20),
                                  label: Text(context.l10n.detailsHostGuests, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_appointment.inviteToken != null) ...[
                                if (_appointment.inviteLinkActive) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            final inviteLink = 'https://sijilli.com/join?token=${_appointment.inviteToken}';
                                            Clipboard.setData(ClipboardData(text: inviteLink));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  context.l10n.localeName == 'ar' ? 'تم نسخ الرابط!' : 'Link copied!',
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.copy, size: 16),
                                          label: Text(context.l10n.localeName == 'ar' ? 'نسخ رابط الدعوة' : 'Copy Invite Link'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _isLinkActionLoading ? null : () async {
                                            setState(() => _isLinkActionLoading = true);
                                            final success = await context.read<AppointmentProvider>().updateInviteLinkStatus(_appointment.id, false);
                                            if (success) {
                                              setState(() {
                                                _appointment = _appointment.copyWith(inviteLinkActive: false);
                                              });
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      context.l10n.localeName == 'ar' ? 'تم تعطيل الرابط بنجاح!' : 'Link disabled successfully!',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                            if (mounted) {
                                              setState(() => _isLinkActionLoading = false);
                                            }
                                          },
                                          icon: _isLinkActionLoading 
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                                                )
                                              : const Icon(Icons.link_off, size: 16, color: AppColors.error),
                                          label: Text(
                                            context.l10n.localeName == 'ar' ? 'تعطيل الرابط' : 'Disable Link',
                                            style: const TextStyle(color: AppColors.error),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: AppColors.error),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _isLinkActionLoading ? null : () async {
                                        setState(() => _isLinkActionLoading = true);
                                        final success = await context.read<AppointmentProvider>().updateInviteLinkStatus(_appointment.id, true);
                                        if (success) {
                                          setState(() {
                                            _appointment = _appointment.copyWith(inviteLinkActive: true);
                                          });
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  context.l10n.localeName == 'ar' ? 'تم تفعيل رابط الدعوة!' : 'Invite link enabled!',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                        if (mounted) {
                                          setState(() => _isLinkActionLoading = false);
                                        }
                                      },
                                      icon: _isLinkActionLoading 
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                            )
                                          : const Icon(Icons.link, size: 18, color: AppColors.primary),
                                      label: Text(
                                        context.l10n.localeName == 'ar' ? 'تفعيل رابط الاستضافة الموقّف' : 'Enable Invitation Link',
                                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppColors.primary),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ] else ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _isLinkActionLoading ? null : () async {
                                      setState(() => _isLinkActionLoading = true);
                                      final token = const Uuid().v4();
                                      final success = await context.read<AppointmentProvider>().updateInviteLinkStatus(_appointment.id, true, inviteToken: token);
                                      if (success) {
                                        setState(() {
                                          _appointment = _appointment.copyWith(inviteToken: token, inviteLinkActive: true);
                                        });
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                context.l10n.localeName == 'ar' ? 'تم توليد وتفعيل رابط الاستضافة!' : 'Invite link generated and enabled!',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                      if (mounted) {
                                        setState(() => _isLinkActionLoading = false);
                                      }
                                    },
                                    icon: _isLinkActionLoading 
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                          )
                                        : const Icon(Icons.link_outlined, size: 18, color: AppColors.primary),
                                    label: Text(
                                      context.l10n.localeName == 'ar' ? 'توليد رابط استضافة مؤقت' : 'Generate Temporary Invite Link',
                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: AppColors.primary),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        }
                      ),
                    ] else ...[
                      Builder(
                        builder: (context) {
                          // Check Host Status
                          final hostParticipant = _appointment.participants?.firstWhere(
                            (p) => p.userId == _appointment.hostId, 
                            orElse: () => Invitation(id: '', appointmentId: '', userId: '', status: InvitationStatus.accepted)
                          );
                          
                          final isHostCancelled = hostParticipant?.status == InvitationStatus.deletedAfterAccept;
                          
                          if (isHostCancelled) {
                             return SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: null, // Disabled
                                  icon: const Icon(Icons.block, color: AppColors.textSecondary),
                                  label: Text(context.l10n.detailsAppointmentCancelled, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.background, 
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    elevation: 0,
                                    disabledBackgroundColor: AppColors.background,
                                  ),
                                ),
                             );
                          }
                          return const SizedBox.shrink();
                        }
                      ),
                    ],

                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final hasAnyAcceptedGuest = _appointment.participants?.any((p) => p.userId != _appointment.hostId && p.status == InvitationStatus.accepted) ?? false;
        final showHostWarning = _isHost && !hasAnyAcceptedGuest;

        final String titleText;
        final String confirmText;
        final String actionButtonText;

        if (showHostWarning) {
          titleText = ctx.l10n.detailsDeleteTitleHost;
          confirmText = ctx.l10n.detailsDeleteConfirmHost;
          actionButtonText = ctx.l10n.detailsCancelAppointment;
        } else {
          final isAr = ctx.l10n.localeName == 'ar';
          titleText = isAr ? 'حذف الموعد' : 'Delete Appointment';
          confirmText = isAr 
              ? 'هذا قرار نهائي، سوف يؤدي إلى حذف سجل الموعد من صفحتك الشخصية.\nهل أنت متأكد؟'
              : 'This is a final decision, it will lead to deleting the appointment record from your personal page.\nAre you sure?';
          actionButtonText = isAr ? 'حذف' : ctx.l10n.delete;
        }

        return AlertDialog(
          title: Text(titleText),
          content: Text(confirmText),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: Text(ctx.l10n.detailsUndo),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning, 
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                context.read<AppointmentProvider>().deleteInvitation(_appointment.id);
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Close details sheet
              },
              child: Text(actionButtonText),
            ),
          ],
        );
      }
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.detailsNewCategory),
        content: TextField(
          controller: controller, 
          decoration: InputDecoration(hintText: context.l10n.detailsCategoryHint),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final newCat = await context.read<CategoryProvider>().addCategory(controller.text);
                if (newCat != null) {
                  if (mounted) {
                    setState(() => _selectedCategories = newCat);
                    context.read<AppointmentProvider>().updateInvitationSettings(
                      widget.appointment.id,
                      privacy: _selectedPrivacy,
                      categories: newCat,
                    );
                  }
                }
                Navigator.pop(ctx);
              }
            },
            child: Text(context.l10n.add),
          ),
        ],
      ),
    );
  }

  void _editField(String field, String? currentValue) {
    final controller = TextEditingController(text: currentValue);
    String label = '';
    if (field == 'description') label = context.l10n.detailsGeneralNote;
    else if (field == 'personalNote') label = context.l10n.detailsPersonalNote;
    else label = context.l10n.detailsLink;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getCardBackground(ctx),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.l10n.edit} $label',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: context.l10n.detailsEnterHere(label),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLines: field.contains('Note') || field == 'description' ? 5 : 1,
                  autofocus: true,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(context.l10n.cancel),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final newValue = controller.text.trim();
                        if (newValue != currentValue) {
                            try {
                              if (field == 'personalNote') {
                                await context.read<AppointmentProvider>().updateInvitationSettings(
                                  _appointment.id,
                                  personalNote: newValue,
                                  privacy: _selectedPrivacy, 
                                  categories: _selectedCategories,
                                );
                                setState(() {
                                   final updatedInv = _appointment.currentUserInvitation?.copyWith(personalNote: newValue);
                                   _appointment = _appointment.copyWith(currentUserInvitation: updatedInv);
                                });
                              } else {
                                await PbAppointmentService().updateAppointment(
                                  _appointment.id, 
                                  { 
                                     if (field == 'description') 'description': newValue,
                                     if (field == 'streamLink') 'stream_link': newValue,
                                  }
                                );
                                setState(() {
                                   _appointment = _appointment.copyWith(
                                      description: field == 'description' ? newValue : null,
                                      streamLink: field == 'streamLink' ? newValue : null,
                                   );
                                });
                              }
                              if (mounted) Navigator.pop(ctx);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.detailsUpdateFailed(e.toString()))));
                            }
                        } else {
                           Navigator.pop(ctx);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(context.l10n.save, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openInviteSheet() {
    print('🚀 [_openInviteSheet] جاري الفتح للموعد: ${_appointment.id}');
    try {
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          print('📦 [قائمة الدعوة] جاري بناء واجهة اختيار المستخدمين');
          return UserInviteeSheet(
            appointment: _appointment,
            onUserSelected: (user) async {
              print('👤 [قائمة الدعوة] تم اختيار المستخدم: ${user.id}');
              Navigator.pop(context);
              try {
                if (user.id.startsWith('phone_')) {
                  await context.read<AppointmentProvider>().inviteGuestByPhone(_appointment.id, user.phone!, user.name);
                } else {
                  await context.read<AppointmentProvider>().inviteGuest(_appointment.id, user);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.detailsInviteSent(user.name ?? user.username)),
                      backgroundColor: AppColors.success,
                    )
                  );
                }
              } catch (e) {
                print('‼️ [قائمة الدعوة] خطأ: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.detailsInviteFailed(e.toString())),
                      backgroundColor: AppColors.error,
                    )
                  );
                }
              }
            },
          );
        },
      );
    } catch (e) {
      print('‼️ [_openInviteSheet] خطأ فادح: $e');
    }
  }
}
