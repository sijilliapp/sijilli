import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/features/game/providers/nerve_game_provider.dart';
import 'package:sijilli/models/nerve_score.dart';

class NerveGameSheet extends StatefulWidget {
  const NerveGameSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      isDismissible: false,
      builder: (context) => const NerveGameSheet(),
    );
  }

  @override
  State<NerveGameSheet> createState() => _NerveGameSheetState();
}

class _NerveGameSheetState extends State<NerveGameSheet> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      lowerBound: 0.9,
      upperBound: 1.1,
    )..repeat(reverse: true);

    // تهيئة الجلسة فور الفتح
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NerveGameProvider>().startNewSession();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NerveGameProvider>();
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppColors.getBorder(context)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: 24 + viewInsets.bottom,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handlebar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Game States Router
            switch (provider.state) {
              NerveGameState.idle => _buildIdleState(context, provider),
              NerveGameState.countdown => _buildCountdownState(context, provider),
              NerveGameState.playing => _buildPlayingState(context, provider),
              NerveGameState.completed => _buildCompletedState(context, provider),
              NerveGameState.submitting => _buildSubmittingState(context),
              NerveGameState.finished => _buildFinishedState(context, provider),
            },
          ],
        ),
      ),
    );
  }

  // 1. واجهة البدء
  Widget _buildIdleState(BuildContext context, NerveGameProvider provider) {
    return Column(
      children: [
        const Icon(Icons.flash_on, size: 64, color: Colors.amber),
        const SizedBox(height: 16),
        const Text(
          'تحدّي الأعصاب اليومي ⚡',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'اضغط على الزر العملاق 10 مرات متتالية بأسرع ما يمكن!\nلديك 3 محاولات كحد أقصى، وسنقوم بحفظ وإرسال أفضل توقيت تحققه فقط إلى قائمة التحدي اليومية.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.getTextSecondary(context),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              provider.startCountdown();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
            child: const Text(
              'استعد وابدأ التحدي! 🏁',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  // 2. واجهة العد التنازلي
  Widget _buildCountdownState(BuildContext context, NerveGameProvider provider) {
    return ScaleTransition(
      scale: _pulseController,
      child: Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          '${provider.countdownValue}',
          style: const TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.w900,
            color: Colors.amber,
          ),
        ),
      ),
    );
  }

  // 3. واجهة اللعب النشط
  Widget _buildPlayingState(BuildContext context, NerveGameProvider provider) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'المحاولة: ${provider.attemptIndex} / 3',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'النقرات: ${provider.tapCount} / 10',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // مؤقت الوقت
        Text(
          '${provider.elapsedSeconds.toStringAsFixed(3)}s',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 40),

        // زر النقر العملاق التفاعلي
        GestureDetector(
          onTapDown: (_) {
            HapticFeedback.lightImpact();
            provider.tap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            height: 180,
            width: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8),
                  AppColors.primary.withValues(alpha: 0.4),
                ],
                stops: const [0.4, 0.7, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app, size: 48, color: Colors.white),
                SizedBox(height: 8),
                Text(
                  'اضغط! 🔥',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // 4. واجهة النتائج المؤقتة للمحاولات
  Widget _buildCompletedState(BuildContext context, NerveGameProvider provider) {
    final hasMoreAttempts = provider.attemptIndex < 3;

    return Column(
      children: [
        const Icon(Icons.stars, size: 64, color: Colors.amber),
        const SizedBox(height: 16),
        const Text(
          'انتهت المحاولة! 🎉',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'توقيت هذه المحاولة: ${provider.currentAttemptScore?.toStringAsFixed(3)} ثانية',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'أفضل توقيت حالي في الجلسة: ${provider.bestScoreOfSession?.toStringAsFixed(3)} ثانية',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'أنهيت المحاولة ${provider.attemptIndex} من 3 محاولات متاحة.',
          style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 13),
        ),
        const SizedBox(height: 32),

        // أزرار التحكم
        if (hasMoreAttempts) ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                provider.nextAttempt();
              },
              icon: const Icon(Icons.replay),
              label: const Text('المحاولة التالية 🔄', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                await provider.submitBestScore();
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('إرسال أفضل نتيجة وإنهاء التحدي 💾'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.success,
                side: const BorderSide(color: AppColors.success),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ] else ...[
          // لم يتبق محاولات
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                await provider.submitBestScore();
              },
              icon: const Icon(Icons.emoji_events),
              label: const Text('تسجيل النتيجة وإنهاء التحدي 🏆', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  // 5. واجهة الحفظ والانتظار
  Widget _buildSubmittingState(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40.0),
      child: Column(
        children: [
          CircularProgressIndicator(strokeWidth: 3),
          SizedBox(height: 24),
          Text(
            'جاري إرسال نتيجتك وتحديث قائمة التحدي اليومية...',
            style: TextStyle(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 6. واجهة لوحة الشرف والانتهاء
  Widget _buildFinishedState(BuildContext context, NerveGameProvider provider) {
    return Column(
      children: [
        const Icon(Icons.emoji_events, size: 56, color: Colors.amber),
        const SizedBox(height: 12),
        const Text(
          'نتائج التحدي اليومي ⏱️',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'أفضل نتيجتك المسجلة: ${provider.bestScoreOfSession?.toStringAsFixed(3)} ثانية',
          style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 20),

        // قائمة المتصدرين
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          child: provider.isLoadingLeaderboard
              ? const Center(child: CircularProgressIndicator())
              : provider.leaderboard.isEmpty
                  ? const Center(child: Text('لا توجد نتائج مسجلة لليوم بعد.'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: provider.leaderboard.length,
                      itemBuilder: (context, index) {
                        final score = provider.leaderboard[index];
                        return _buildLeaderboardTile(context, score, index);
                      },
                    ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('إغلاق ورجوع', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardTile(BuildContext context, NerveScore score, int index) {
    final isTop3 = index < 3;
    final medal = switch (index) {
      0 => '🥇',
      1 => '🥈',
      2 => '🥉',
      _ => '${index + 1}',
    };

    final userName = score.user?.name ?? 'مستخدم';
    final userAvatar = score.user?.avatar;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isTop3 
            ? AppColors.primary.withValues(alpha: 0.08) 
            : AppColors.getCardBackground(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTop3 
              ? AppColors.primary.withValues(alpha: 0.3) 
              : AppColors.getBorder(context),
        ),
      ),
      child: Row(
        children: [
          // الرتبة / الميدالية
          SizedBox(
            width: 32,
            child: Text(
              medal,
              style: TextStyle(
                fontSize: isTop3 ? 20 : 14,
                fontWeight: isTop3 ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),

          // الصورة الرمزية
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[700],
            backgroundImage: userAvatar != null && userAvatar.isNotEmpty
                ? NetworkImage(userAvatar)
                : null,
            child: userAvatar == null || userAvatar.isEmpty
                ? const Icon(Icons.person, size: 18, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),

          // اسم المتسابق
          Expanded(
            child: Text(
              userName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // توقيت النتيجة
          Text(
            '${score.timeSeconds.toStringAsFixed(3)}s',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.amber,
              fontFamily: 'monospace',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
