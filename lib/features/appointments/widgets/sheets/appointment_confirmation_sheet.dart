import 'package:flutter/material.dart'; 
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../models/user.dart';
import '../../../../core/utils/app_date_formatter.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';

class AppointmentConfirmationSheet extends StatefulWidget {
  final UserModel? host;
  final List<UserModel> invitees;
  final String title;
  final DateTime startAt;
  final int duration;
  final bool isHijri;
  final int hijriAdjustment;
  final String region;
  final String building;
  final bool hasConflict;
  
  const AppointmentConfirmationSheet({
    super.key,
    required this.host,
    required this.invitees,
    required this.title,
    required this.startAt,
    required this.duration,
    required this.isHijri,
    this.hijriAdjustment = 0,
    required this.region,
    required this.building,
    this.hasConflict = false,
  });

  @override
  State<AppointmentConfirmationSheet> createState() => _AppointmentConfirmationSheetState();
}

class _AppointmentConfirmationSheetState extends State<AppointmentConfirmationSheet> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isSuccess = false;
  
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 600),
    );
     _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onConfirm() async {
    setState(() => _isLoading = true);
    
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
       setState(() {
         _isLoading = false;
         _isSuccess = true;
       });
       _controller.forward();
       
       await Future.delayed(const Duration(milliseconds: 1000));
       if (mounted) {
         Navigator.pop(context, true); 
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
       return _buildSuccessView();
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).languageCode;
    
    final timeStr = DateFormat('h:mm', locale).format(widget.startAt.toLocal());
    
    final hour = widget.startAt.toLocal().hour;
    String periodText = context.l10n.morning;
    if (hour >= 12 && hour < 24) {
       if (hour >= 18) periodText = context.l10n.night; 
       else periodText = context.l10n.evening; 
    } else {
       if (hour < 4) periodText = context.l10n.night; 
       else periodText = context.l10n.morning;
    }

    String dateStr;
    if (widget.isHijri) {
       DateTime adjustedDate = widget.startAt.toLocal();
       if (widget.hijriAdjustment != 0) {
          adjustedDate = adjustedDate.add(Duration(days: widget.hijriAdjustment));
       }
       
       final h = HijriCalendar.fromDate(adjustedDate);
       dateStr = locale == 'ar'
           ? '${h.hDay} ${h.longMonthName} ${h.hYear}'
           : '${h.hYear}/${h.hMonth}/${h.hDay}';
    } else {
       dateStr = DateFormat('EEEE d MMMM yyyy', locale).format(widget.startAt.toLocal());
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final apptDay = DateTime(widget.startAt.year, widget.startAt.month, widget.startAt.day);
    final diffDays = apptDay.difference(today).inDays;
    
    String timeHint = '';
    if (diffDays == 0) timeHint = context.l10n.today;
    else if (diffDays == 1) timeHint = context.l10n.tomorrow;
    else if (diffDays == 2) timeHint = context.l10n.afterTomorrow;
    else if (diffDays > 0) timeHint = context.l10n.afterDays(diffDays);
    else if (diffDays == -1) timeHint = context.l10n.yesterday;
    else if (diffDays < 0) timeHint = context.l10n.sinceDays(diffDays.abs());

    if (timeHint.isNotEmpty) {
      if (locale == 'ar') {
        timeHint = AppDateFormatter.toEasternArabicDigits(timeHint);
      }
      dateStr = '$dateStr ($timeHint)';
    }

    if (locale == 'ar') {
      dateStr = AppDateFormatter.toEasternArabicDigits(dateStr);
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
         mainAxisSize: MainAxisSize.min,
         children: [
            SizedBox(
              height: 70,
              child: _buildStackedAvatars(),
            ),
            
            const SizedBox(height: 16),
            
            Text(
               widget.invitees.isNotEmpty ? context.l10n.aboutToCreateWith : context.l10n.aboutToCreate,
               style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13),
            ),
            
            if (widget.invitees.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                 widget.invitees.length == 1 
                    ? (widget.invitees.first.name ?? widget.invitees.first.username ?? context.l10n.guest)
                    : context.l10n.participantsCount(widget.invitees.length),
                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextPrimary(context)),
              ),
            ],
            
            const SizedBox(height: 24),
            
            if (widget.hasConflict) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                       const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               context.l10n.conflictAlert,
                               style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                             ),
                             Text(
                               context.l10n.conflictMessage,
                               style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                             ),
                           ],
                         ),
                       ),
                    ],
                  ),
                ),
            ],

            Container(
               width: double.infinity,
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                 color: isDark ? Colors.grey.shade800 : AppColors.lightBackground, 
                 borderRadius: BorderRadius.circular(16),
                 border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
               ),
               child: Column(
                 children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                         fontWeight: FontWeight.bold,
                         fontSize: 16,
                         color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          '$timeStr $periodText',
                          style: TextStyle(
                             fontWeight: FontWeight.w800, 
                             fontSize: 15,
                             color: AppColors.getTextPrimary(context), 
                          ),
                        ),
                      ],
                    ),
                    if (widget.region.isNotEmpty || widget.building.isNotEmpty) ...[
                       const SizedBox(height: 16),
                       Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${widget.region}${widget.region.isNotEmpty && widget.building.isNotEmpty ? '، ' : ''}${widget.building}',
                                style: TextStyle(
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, 
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                       ),
                    ],
                 ],
               ),
            ),
            
            const SizedBox(height: 32),
            
            if (_isLoading)
               const CircularProgressIndicator(color: AppColors.primary)
            else
               Row(
                 children: [
                    Expanded(
                       child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                          ),
                          child: Text(context.l10n.review, style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, fontWeight: FontWeight.bold)),
                       ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                       child: ElevatedButton(
                          onPressed: _onConfirm,
                           style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(context.l10n.confirm, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                       ),
                    ),
                 ],
               ),
         ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
       decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
           ScaleTransition(
             scale: _scaleAnimation,
             child: Container(
               width: 80,
               height: 80,
               decoration: const BoxDecoration(
                 color: AppColors.success, 
                 shape: BoxShape.circle,
               ),
               child: const Icon(Icons.check, color: Colors.white, size: 48),
             ),
           ),
           const SizedBox(height: 24),
           Text(
             context.l10n.invitationSentSuccessfully,
             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
           ),
        ],
      ),
    );
  }


  Widget _buildStackedAvatars() {
    final List<UserModel?> participants = [widget.host, ...widget.invitees];
    const double avatarSize = 65.0;
    const double overlap = 20.0; 

    return Center(
      child: SizedBox(
        width: participants.length * (avatarSize - overlap) + overlap,
        child: Stack(
          children: List.generate(participants.length, (index) {
            final displayIndex = participants.length - 1 - index;
            return Positioned(
              left: displayIndex * (avatarSize - overlap),
              child: _buildParticipantAvatar(
                participants[displayIndex], 
                isHost: displayIndex == 0,
                size: avatarSize,
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildParticipantAvatar(UserModel? user, {bool isHost = false, double size = 60}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isHost ? AppColors.primary : (isDark ? Colors.grey.shade900 : Colors.white), 
          width: 3
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: user?.hasAvatar == true
            ? Image.network(user!.getAvatarUrl('https://sijilli.pockethost.io')!, fit: BoxFit.cover)
            : Container(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                child: Icon(Icons.person, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400, size: size * 0.5)
              ),
      ),
    );
  }
}
