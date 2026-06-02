import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/services/pocketbase_client.dart';
import 'package:sijilli/features/auth/providers/auth_provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../models/article.dart';
import '../../../models/comment.dart';
import '../providers/article_provider.dart';

class CommentSection extends StatefulWidget {
  final Article article;

  const CommentSection({
    super.key,
    required this.article,
  });

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitting = false;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_updateCharCount);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ArticleProvider>().fetchComments(widget.article.id);
    });
  }

  @override
  void dispose() {
    _commentController.removeListener(_updateCharCount);
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateCharCount() {
    setState(() {
      _charCount = _commentController.text.trim().length;
    });
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || text.length > 500) return;

    final authProvider = context.read<AuthProvider>();
    if (authProvider.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول لتتمكن من التعليق')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final success = await context.read<ArticleProvider>().addComment(
      articleId: widget.article.id,
      content: text,
      authorId: widget.article.authorId,
      articleTitle: widget.article.title,
      commenterName: authProvider.user!.name ?? 'مستخدم سجلي',
    );

    setState(() {
      _isSubmitting = false;
    });

    if (success != null) {
      _commentController.clear();
      _focusNode.unfocus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت إضافة تعليقك بنجاح 💬'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('عذراً، فشل نشر التعليق. يرجى المحاولة لاحقاً')),
        );
      }
    }
  }

  Future<void> _confirmDeleteComment(Comment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف التعليق', textAlign: TextAlign.right),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذا التعليق؟ لا يمكن التراجع عن هذا الإجراء.', textAlign: TextAlign.right),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<ArticleProvider>().deleteComment(widget.article.id, comment.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف التعليق بنجاح')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final currentUserId = context.watch<AuthProvider>().user?.id;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // مقبض السحب العلوي (Drag Handle)
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // الهيدر
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.forum_outlined, color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            'التعليقات',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Consumer<ArticleProvider>(
                            builder: (context, provider, _) {
                              final comments = provider.getCommentsForArticle(widget.article.id);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${comments.length}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1),

                // محتوى القائمة
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                      minHeight: 150,
                    ),
                    child: Consumer<ArticleProvider>(
                      builder: (context, provider, _) {
                        if (provider.isCommentsLoading) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final comments = provider.getCommentsForArticle(widget.article.id);

                        if (comments.isEmpty) {
                          return Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(40.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 56,
                                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'كن أول من يثري النقاش بكتابة تعليق حضاري وراقٍ',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          itemCount: comments.length,
                          separatorBuilder: (context, index) => const Divider(height: 24, indent: 48),
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            final isCommentOwner = currentUserId == comment.userId;
                            final isArticleOwner = currentUserId == widget.article.authorId;
                            final canDelete = isCommentOwner || isArticleOwner;
                            final commentUser = comment.user;
                            final hasAvatar = commentUser?.getAvatarUrl(PocketBaseClient.instance.pb.baseURL) != null;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // صورة كاتب التعليق الشخصية
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                  backgroundImage: hasAvatar
                                      ? NetworkImage(commentUser!.getAvatarUrl(PocketBaseClient.instance.pb.baseURL)!)
                                      : null,
                                  child: !hasAvatar
                                      ? Text(
                                          (commentUser?.name ?? 'م').substring(0, 1).toUpperCase(),
                                          style: TextStyle(
                                            color: isDark ? Colors.white70 : Colors.black87,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                
                                // تفاصيل التعليق
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // اسم الكاتب والحساب والمعرف الزمني
                                      Row(
                                        children: [
                                          Expanded(
                                            child: RichText(
                                              overflow: TextOverflow.ellipsis,
                                              text: TextSpan(
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                                ),
                                                children: [
                                                  TextSpan(
                                                    text: commentUser?.name ?? 'مستخدم سجلي',
                                                    style: const TextStyle(fontWeight: FontWeight.normal),
                                                  ),
                                                  if (commentUser?.username != null)
                                                    TextSpan(
                                                      text: ' @${commentUser!.username}',
                                                      style: TextStyle(
                                                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            timeago.format(comment.createdAt, locale: 'ar'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      
                                      // نص التعليق
                                      Text(
                                        comment.content,
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.4,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // خيار حذف التعليق
                                if (canDelete) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                    onPressed: () => _confirmDeleteComment(comment),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'حذف التعليق',
                                  ),
                                ],
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),

                const Divider(height: 1),

                // قسم إدخال التعليق
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // حقل الكتابة
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _commentController,
                              focusNode: _focusNode,
                              maxLines: 4,
                              minLines: 1,
                              maxLength: 500,
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null, // سنقوم ببناء عداد خاص
                              decoration: InputDecoration(
                                hintText: currentUserId != null ? 'اكتب تعليقاً حضارياً ومفيداً...' : 'يجب تسجيل الدخول لتتمكن من التعليق',
                                enabled: currentUserId != null,
                                fillColor: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: AppColors.primary.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              style: const TextStyle(fontSize: 14),
                            ),
                            
                            // عداد الحروف والتحذير
                            if (currentUserId != null && _charCount > 0) ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  '$_charCount / 500',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _charCount > 480 
                                        ? AppColors.error 
                                        : (isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // زر الإرسال
                      if (currentUserId != null)
                        _isSubmitting
                            ? const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.send_rounded),
                                color: AppColors.primary,
                                disabledColor: isDark ? Colors.white24 : Colors.grey.shade300,
                                onPressed: (_charCount > 0 && _charCount <= 500) ? _submitComment : null,
                              ),
                    ],
                  ),
                ),
                // مسافة أمان لـ iOS Home Indicator
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
