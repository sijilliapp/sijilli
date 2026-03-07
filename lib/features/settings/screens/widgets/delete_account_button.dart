import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/auth_wrapper.dart';
import '../../../auth/providers/auth_provider.dart';

class DeleteAccountButton extends StatelessWidget {
  const DeleteAccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _showDeleteAccountDialog(context),
        icon: const Icon(Icons.delete_forever, color: AppColors.error),
        label: const Text(
          'حذف الحساب نهائياً',
          style: TextStyle(
            color: AppColors.error,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.error,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الحساب', style: TextStyle(color: AppColors.error)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل أنت متأكد من رغبتك في حذف حسابك؟'),
            SizedBox(height: 12),
            Text(
              'هذا الإجراء نهائي ولا يمكن التراجع عنه. سيتم حذف جميع بياناتك ومواعيدك وصورك.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close Alert Dialog
              
              final provider = Provider.of<AuthProvider>(context, listen: false); // Use Widget Context
              
              // Show loading
              showDialog(
                context: context, // Use Widget Context
                barrierDismissible: false,
                builder: (loadingContext) => const Center(child: CircularProgressIndicator()),
              );
              
              // 1. Delete account
              final success = await provider.deleteAccount(performLogout: false);
              
              if (context.mounted) { // Check Widget Context (Stable)
                Navigator.of(context, rootNavigator: true).pop(); // Close Loading Dialog
                
                if (success) {
                  // 2. Show Success Feedback
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف الحساب بنجاح'),
                      backgroundColor: AppColors.success,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  
                  // 3. Wait for user to see message
                  await Future.delayed(const Duration(seconds: 2));
                  
                  if (context.mounted) {
                    // 4. Perform logout and navigate
                    await provider.logout();
                    
                    if (context.mounted) {
                       Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthWrapper()), 
                        (route) => false,
                      );
                    }
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.errorMessage ?? 'فشل حذف الحساب'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
  }
}
