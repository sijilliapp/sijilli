import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/tag.dart';
import '../providers/tag_provider.dart';
import '../../../../core/constants/app_colors.dart';
import 'tag_chip.dart';

class TagSelectorSheet extends StatefulWidget {
  final List<String> initialSelectedTagIds;
  final Function(List<String> selectedTagIds, List<Tag> selectedTags) onSelectionChanged;

  const TagSelectorSheet({
    super.key,
    required this.initialSelectedTagIds,
    required this.onSelectionChanged,
  });

  static void show(
    BuildContext context, {
    required List<String> initialSelectedTagIds,
    required Function(List<String> selectedTagIds, List<Tag> selectedTags) onSelectionChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TagSelectorSheet(
        initialSelectedTagIds: initialSelectedTagIds,
        onSelectionChanged: onSelectionChanged,
      ),
    );
  }

  @override
  State<TagSelectorSheet> createState() => _TagSelectorSheetState();
}

class _TagSelectorSheetState extends State<TagSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  
  late List<String> _selectedTagIds;
  
  // Custom tag creation states
  bool _isCreatingNew = false;
  String _selectedColorHex = '6B7280'; // Default gray

  // Curated premium tag colors list
  final List<String> _premiumColors = [
    '6B7280', // Gray (Standard)
    '4F46E5', // Indigo
    '10B981', // Mint Green
    'F59E0B', // Sunset Orange
    'EF4444', // Crimson Red
    '06B6D4', // Ocean Cyan
    'EC4899', // Rose Pink
    '8B5CF6', // Purple
    '6366F1', // Lavender
  ];

  @override
  void initState() {
    super.initState();
    _selectedTagIds = List<String>.from(widget.initialSelectedTagIds);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleTagSelection(Tag tag) {
    setState(() {
      if (_selectedTagIds.contains(tag.id)) {
        _selectedTagIds.remove(tag.id);
      } else {
        _selectedTagIds.add(tag.id);
      }
    });
    _notifyChanges();
  }

  void _notifyChanges() {
    final tagProvider = context.read<TagProvider>();
    final selectedTags = tagProvider.tags.where((t) => _selectedTagIds.contains(t.id)).toList();
    widget.onSelectionChanged(_selectedTagIds, selectedTags);
  }

  Future<void> _createNewTag() async {
    final tagName = _searchController.text.trim();
    if (tagName.isEmpty) return;

    final tagProvider = context.read<TagProvider>();
    final newTag = await tagProvider.addTag(tagName, _selectedColorHex);
    
    if (newTag != null) {
      setState(() {
        _selectedTagIds.add(newTag.id);
        _searchController.clear();
        _isCreatingNew = false;
      });
      _notifyChanges();
    }
  }

  void _showEditTagDialog(Tag tag) {
    final nameController = TextEditingController(text: tag.name);
    String selectedColorHex = tag.colorHex;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (statefulCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('تعديل التصنيف'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم التصنيف',
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'اختر لون الكبسولة:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: List.generate(_premiumColors.length, (index) {
                          final colorHex = _premiumColors[index];
                          final color = Color(int.parse('FF$colorHex', radix: 16));
                          final isColorSelected = selectedColorHex == colorHex;

                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                selectedColorHex = colorHex;
                              });
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isColorSelected
                                    ? Border.all(
                                        color: isDark ? Colors.white : Colors.black87,
                                        width: 2.3,
                                      )
                                    : null,
                              ),
                              child: isColorSelected
                                  ? Icon(
                                      Icons.check,
                                      size: 16,
                                      color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                    )
                                  : null,
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newName = nameController.text.trim();
                    if (newName.isNotEmpty) {
                      final tagProvider = dialogCtx.read<TagProvider>();
                      final updated = await tagProvider.updateTag(tag.id, newName, selectedColorHex);
                      if (updated != null && mounted) {
                        _notifyChanges();
                      }
                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('حفظ التعديلات'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Consumer<TagProvider>(
      builder: (context, tagProvider, _) {
        final filteredTags = tagProvider.tags.where((t) => 
          t.name.toLowerCase().contains(_searchQuery.toLowerCase())
        ).toList();

        final tagExists = tagProvider.tags.any((t) => 
          t.name.trim().toLowerCase() == _searchQuery.toLowerCase()
        );

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bottom sheet drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Header title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'تصنيف المقال 🏷️',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (tagProvider.isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Search Input Field
              TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'ابحث عن تصنيف أو اكتب وسم جديد...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),

              // Create tag option if it doesn't exist
              if (_searchQuery.isNotEmpty && !tagExists) ...[
                Card(
                  elevation: 0,
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontSize: 13,
                                  ),
                                  children: [
                                    const TextSpan(text: 'هل تريد إنشاء الوسم الجديد: '),
                                    TextSpan(
                                      text: '"$_searchQuery"',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                    const TextSpan(text: ' ؟'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        
                        // Color Picker
                        const Text(
                          'اختر لون الكبسولة:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 32,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _premiumColors.length,
                            itemBuilder: (context, index) {
                              final colorHex = _premiumColors[index];
                              final color = Color(int.parse('FF$colorHex', radix: 16));
                              final isColorSelected = _selectedColorHex == colorHex;

                              return Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedColorHex = colorHex;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: isColorSelected
                                          ? Border.all(
                                              color: isDark ? Colors.white : Colors.black87,
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                    child: isColorSelected
                                        ? Icon(
                                            Icons.check,
                                            size: 16,
                                            color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Confirm button
                        ElevatedButton.icon(
                          onPressed: _createNewTag,
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('إنشاء وإضافة الوسم'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // List of Tags
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: tagProvider.tags.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.label_off_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text(
                                'لا توجد أوسام حالياً.\nاكتب في الأعلى لإنشاء وسمك الأول 🏷️',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : filteredTags.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24.0),
                              child: Text('لا توجد نتائج مطابقة لبحثك.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filteredTags.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                            itemBuilder: (context, index) {
                              final tag = filteredTags[index];
                              final isSelected = _selectedTagIds.contains(tag.id);

                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (_) => _toggleTagSelection(tag),
                                title: Row(
                                  children: [
                                    TagChip(tag: tag),
                                  ],
                                ),
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppColors.primary,
                                controlAffinity: ListTileControlAffinity.leading,
                                secondary: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                                      onPressed: () => _showEditTagDialog(tag),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (dialogContext) => AlertDialog(
                                            title: const Text('حذف الوسم'),
                                            content: Text('هل أنت متأكد من حذف الوسم "${tag.name}"؟ سيتم إزالته من جميع مقالاتك أيضاً.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(dialogContext, false),
                                                child: const Text('إلغاء'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(dialogContext, true),
                                                child: const Text('حذف', style: TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await tagProvider.deleteTag(tag.id);
                                          setState(() {
                                            _selectedTagIds.remove(tag.id);
                                          });
                                          _notifyChanges();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 16),
              
              // Done close button
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white24 : Colors.grey.shade100,
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('تم الموافقة والحفظ', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
