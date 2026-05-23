import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class DeleteAccountProgressDialog extends StatefulWidget {
  final Future<bool> Function(Function(String)) onDelete;

  const DeleteAccountProgressDialog({super.key, required this.onDelete});

  @override
  State<DeleteAccountProgressDialog> createState() => _DeleteAccountProgressDialogState();
}

class _DeleteAccountProgressDialogState extends State<DeleteAccountProgressDialog> {
  bool _isDeleting = false;
  bool? _success;
  
  final List<Map<String, dynamic>> _steps = [
    {'id': 'friendship', 'label': 'تنظيف علاقات الصداقة', 'status': 'waiting'},
    {'id': 'invitations', 'label': 'حذف الدعوات والطلبات', 'status': 'waiting'},
    {'id': 'notifications', 'label': 'مسح سجل التنبيهات', 'status': 'waiting'},
    {'id': 'appointments', 'label': 'إزالة المواعيد والارتباطات', 'status': 'waiting'},
    {'id': 'reports', 'label': 'تنظيف سجلات البلاغات', 'status': 'waiting'},
    {'id': 'user', 'label': 'إغلاق الحساب نهائياً', 'status': 'waiting'},
  ];

  @override
  void initState() {
    super.initState();
    _startDeletion();
  }

  Future<void> _startDeletion() async {
    setState(() {
      _isDeleting = true;
      _steps[0]['status'] = 'processing';
    });
    
    try {
      final result = await widget.onDelete((stepId) {
        if (mounted) {
          setState(() {
            final index = _steps.indexWhere((s) => s['id'] == stepId);
            if (index != -1) {
              _steps[index]['status'] = 'done';
              if (index + 1 < _steps.length) {
                _steps[index + 1]['status'] = 'processing';
              }
            }
          });
        }
      });
      
      if (mounted) {
        setState(() {
          _success = result;
          _isDeleting = false;
          if (result) {
            for (var step in _steps) {
              step['status'] = 'done';
            }
          }
        });
        
        if (result) {
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _success = false;
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _success != null,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _success == false ? AppColors.error.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _success == true 
                  ? Icons.check_circle_outline 
                  : (_success == false ? Icons.error_outline : Icons.delete_sweep_outlined),
                size: 48,
                color: _success == false ? AppColors.error : AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _success == true ? 'تم الحذف بنجاح' : (_success == false ? 'فشل الحذف' : 'جارٍ حذف الحساب'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _success == true 
                ? 'تم مسح كافة بياناتك، سيتم توجيهك الآن...' 
                : (_success == false ? 'حدث خطأ أثناء التنظيف، يرجى المحاولة لاحقاً' : 'يرجى عدم إغلاق التطبيق أثناء العملية'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            ..._steps.map((step) => _buildStepRow(step)),
            const SizedBox(height: 24),
            if (_success == false)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('إغلاق'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(Map<String, dynamic> step) {
    bool isDone = step['status'] == 'done' || _success == true;
    bool isWaiting = step['status'] == 'waiting' && _success == null;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          _success == null && isWaiting && _isDeleting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              )
            : Icon(
                isDone ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: isDone ? AppColors.success : Colors.grey.shade400,
              ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              step['label'],
              style: TextStyle(
                fontSize: 14,
                color: isDone ? Colors.black87 : Colors.grey.shade500,
                decoration: _success == false && !isDone ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
