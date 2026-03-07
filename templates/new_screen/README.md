# 📱 قالب شاشة جديدة

## 🎯 قالب أساسي

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class [ScreenName]Screen extends StatelessWidget {
  const [ScreenName]Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<[Provider]Provider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: _buildAppBar(),
          body: _buildBody(provider),
          floatingActionButton: _buildFAB(),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(AppStrings.[screenTitle]),
      backgroundColor: AppColors.primary,
    );
  }

  Widget _buildBody([Provider]Provider provider) {
    if (provider.isLoading) {
      return const LoadingWidget();
    }

    if (provider.hasError) {
      return ErrorWidget(
        message: provider.errorMessage,
        onRetry: provider.retry,
      );
    }

    return const [MainContent]Widget();
  }

  Widget? _buildFAB() {
    return FloatingActionButton(
      onPressed: () {
        // Action
      },
      child: const Icon(Icons.add),
    );
  }
}
```

## 📝 قائمة التحقق

- [ ] استيراد المكتبات المطلوبة
- [ ] استخدام Consumer للحالة
- [ ] تقسيم build إلى دوال صغيرة
- [ ] معالجة حالات التحميل والخطأ
- [ ] استخدام الثوابت للنصوص والألوان
- [ ] إضافة التعليقات العربية
- [ ] اختبار على أجهزة مختلفة