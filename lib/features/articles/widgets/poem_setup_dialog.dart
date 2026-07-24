import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class PoemSetupDialog extends StatefulWidget {
  const PoemSetupDialog({super.key});

  @override
  State<PoemSetupDialog> createState() => _PoemSetupDialogState();
}

class _PoemSetupDialogState extends State<PoemSetupDialog> {
  bool _hasTitle = false;
  final TextEditingController _titleController = TextEditingController();
  
  String _poemType = 'classical'; // 'classical', 'quatrain', 'quintain', 'free'
  String _poetLocation = 'none'; // 'none', 'top', 'bottom'
  final TextEditingController _poetNameController = TextEditingController();
  
  bool _hasSeparators = true;

  @override
  void dispose() {
    _titleController.dispose();
    _poetNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      title: const Row(
        children: [
          Text('📜 ', style: TextStyle(fontSize: 24)),
          Text(
            'إعداد قالب القصيدة',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. هل يوجد عنوان للقصيدة؟
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
                title: const Text(
                  'هل يوجد عنوان للقصيدة؟',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                value: _hasTitle,
                onChanged: (val) => setState(() => _hasTitle = val),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'أدخل عنوان القصيدة...',
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                crossFadeState: _hasTitle ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
              const Divider(),
              // 2. نوع القصيدة
              const Text(
                'نوع القصيدة / القالب الفني:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _poemType,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: 'classical', child: Text('عمودية (شطرين: صدر وعجز)')),
                  DropdownMenuItem(value: 'quatrain', child: Text('رباعية (مجموعات ٤ أشطر)')),
                  DropdownMenuItem(value: 'quintain', child: Text('خماسية (مجموعات ٥ أشطر)')),
                  DropdownMenuItem(value: 'free', child: Text('حرة / تفعيلة (سطر تلو الآخر)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _poemType = val);
                },
              ),
              const SizedBox(height: 12),
              const Divider(),
              // 3. اسم الشاعر وموقعه
              const Text(
                'اسم الشاعر وموقعه:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _poetLocation,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('لا يوجد اسم شاعر')),
                  DropdownMenuItem(value: 'top', child: Text('في الأعلى (قبل الأبيات)')),
                  DropdownMenuItem(value: 'bottom', child: Text('في الأسفل (توقيع يسار)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _poetLocation = val);
                },
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: TextField(
                    controller: _poetNameController,
                    decoration: InputDecoration(
                      hintText: 'أدخل اسم الشاعر...',
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                crossFadeState: _poetLocation != 'none' ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
              const Divider(),
              // 4. هل هناك فواصل؟
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
                title: const Text(
                  'إضافة فواصل بين الأبيات؟ (* * *)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                value: _hasSeparators,
                onChanged: (val) => setState(() => _hasSeparators = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'إلغاء',
            style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pop(context, {
              'hasTitle': _hasTitle,
              'titleText': _titleController.text,
              'poetName': _poetNameController.text,
              'poetLocation': _poetLocation,
              'poemType': _poemType,
              'hasSeparators': _hasSeparators,
            });
          },
          child: const Text('إدراج القالب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
