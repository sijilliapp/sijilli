# 🎨 قالب إضافة ميزة جديدة

## 📋 الخطوات

1. **إنشاء مجلد الميزة**
   ```
   lib/features/[feature_name]/
   ├── screens/
   ├── widgets/
   ├── providers/
   └── services/
   ```

2. **إنشاء الملفات الأساسية**
   - `screens/[feature_name]_screen.dart`
   - `providers/[feature_name]_provider.dart`
   - `services/[feature_name]_service.dart`

3. **إضافة التوجيه**
   - تحديث `routes/route_names.dart`
   - تحديث `routes/app_router.dart`

4. **إضافة النصوص**
   - تحديث `core/constants/app_strings.dart`

5. **إضافة الاختبارات**
   - `test/features/[feature_name]/`

## 🎯 مثال: ميزة الملاحظات

```dart
// lib/features/notes/screens/notes_screen.dart
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(title: Text(AppStrings.notes)),
          body: provider.isLoading 
              ? const LoadingWidget()
              : const NotesList(),
        );
      },
    );
  }
}
```