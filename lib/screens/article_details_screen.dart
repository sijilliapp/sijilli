import 'package:flutter/material.dart';
import '../models/article_model.dart';
import '../services/auth_service.dart';

class ArticleDetailsScreen extends StatefulWidget {
  final ArticleModel article;

  const ArticleDetailsScreen({super.key, required this.article});

  @override
  State<ArticleDetailsScreen> createState() => _ArticleDetailsScreenState();
}

class _ArticleDetailsScreenState extends State<ArticleDetailsScreen> {
  final AuthService _authService = AuthService();
  late TextEditingController _contentController;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.article.content);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  bool get _isMyArticle => widget.article.authorId == _authService.currentUser?.id;

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      await _authService.pb.collection('articles').update(
        widget.article.id,
        body: {
          'content': _contentController.text.trim(),
        },
      );

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ التعديلات'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteArticle() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المقال'),
        content: const Text('هل تريد حذف هذا المقال؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _authService.pb.collection('articles').delete(widget.article.id);

      if (mounted) {
        Navigator.pop(context, true); // true = deleted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف المقال'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _isEditing ? 'تعديل المقال' : 'المقال',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            if (_isMyArticle && !_isEditing)
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFF2196F3)),
                onPressed: () => setState(() => _isEditing = true),
              ),
            if (_isMyArticle && !_isEditing)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _deleteArticle,
              ),
            if (_isEditing)
              if (_isSaving)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: _saveChanges,
                  child: const Text('حفظ'),
                ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: _isEditing
              ? TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                )
              : SingleChildScrollView(
                  child: Text(
                    widget.article.content,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                  ),
                ),
        ),
      ),
    );
  }
}
