# 🔧 قالب خدمة جديدة

## 🎯 قالب خدمة أساسية

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';

/// وصف الخدمة وما تفعله
class [ServiceName]Service {
  static final [ServiceName]Service _instance = [ServiceName]Service._internal();
  factory [ServiceName]Service() => _instance;
  [ServiceName]Service._internal();

  // Dependencies
  final PocketBaseService _pocketBase = PocketBaseService();
  final CacheService _cache = CacheService();

  // State
  bool _isInitialized = false;
  final StreamController<[DataType]> _dataController = StreamController.broadcast();

  // Getters
  bool get isInitialized => _isInitialized;
  Stream<[DataType]> get dataStream => _dataController.stream;

  /// تهيئة الخدمة
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔄 تهيئة خدمة [ServiceName]...');
      
      // منطق التهيئة
      await _loadInitialData();
      
      _isInitialized = true;
      debugPrint('✅ تم تهيئة خدمة [ServiceName] بنجاح');
    } catch (e) {
      debugPrint('❌ خطأ في تهيئة خدمة [ServiceName]: $e');
      rethrow;
    }
  }

  /// جلب البيانات
  Future<List<[DataType]>> getData({
    int page = 1,
    int limit = 20,
    String? filter,
  }) async {
    try {
      debugPrint('🔍 جلب البيانات - صفحة: $page');

      // محاولة التحميل من الكاش أولاً
      final cacheKey = 'data_${page}_${limit}_${filter ?? 'all'}';
      final cachedData = await _cache.get<List<[DataType]>>(cacheKey);
      
      if (cachedData != null) {
        debugPrint('📱 تم تحميل البيانات من الكاش');
        return cachedData;
      }

      // التحميل من الخادم
      final response = await _pocketBase.collection('[collection_name]').getList(
        page: page,
        perPage: limit,
        filter: filter,
      );

      final data = response.items
          .map((item) => [DataType].fromJson(item.toJson()))
          .toList();

      // حفظ في الكاش
      await _cache.set(cacheKey, data, duration: const Duration(minutes: 5));

      debugPrint('✅ تم جلب ${data.length} عنصر من الخادم');
      return data;
    } catch (e) {
      debugPrint('❌ خطأ في جلب البيانات: $e');
      throw ServiceException('فشل في جلب البيانات: $e');
    }
  }

  /// إنشاء عنصر جديد
  Future<[DataType]> create([DataType] item) async {
    try {
      debugPrint('➕ إنشاء عنصر جديد...');

      final response = await _pocketBase.collection('[collection_name]').create(
        body: item.toJson(),
      );

      final newItem = [DataType].fromJson(response.toJson());

      // تحديث الكاش
      await _invalidateCache();

      // إشعار المستمعين
      _dataController.add(newItem);

      debugPrint('✅ تم إنشاء العنصر بنجاح');
      return newItem;
    } catch (e) {
      debugPrint('❌ خطأ في إنشاء العنصر: $e');
      throw ServiceException('فشل في إنشاء العنصر: $e');
    }
  }

  /// تحديث عنصر
  Future<[DataType]> update(String id, Map<String, dynamic> data) async {
    try {
      debugPrint('🔄 تحديث العنصر: $id');

      final response = await _pocketBase.collection('[collection_name]').update(
        id,
        body: data,
      );

      final updatedItem = [DataType].fromJson(response.toJson());

      // تحديث الكاش
      await _invalidateCache();

      debugPrint('✅ تم تحديث العنصر بنجاح');
      return updatedItem;
    } catch (e) {
      debugPrint('❌ خطأ في تحديث العنصر: $e');
      throw ServiceException('فشل في تحديث العنصر: $e');
    }
  }

  /// حذف عنصر
  Future<void> delete(String id) async {
    try {
      debugPrint('🗑️ حذف العنصر: $id');

      await _pocketBase.collection('[collection_name]').delete(id);

      // تحديث الكاش
      await _invalidateCache();

      debugPrint('✅ تم حذف العنصر بنجاح');
    } catch (e) {
      debugPrint('❌ خطأ في حذف العنصر: $e');
      throw ServiceException('فشل في حذف العنصر: $e');
    }
  }

  /// البحث
  Future<List<[DataType]>> search(String query) async {
    try {
      debugPrint('🔍 البحث عن: $query');

      final normalizedQuery = ArabicSearchUtils.normalize(query);
      final filter = 'title~"$normalizedQuery" || description~"$normalizedQuery"';

      return await getData(filter: filter);
    } catch (e) {
      debugPrint('❌ خطأ في البحث: $e');
      throw ServiceException('فشل في البحث: $e');
    }
  }

  /// تحميل البيانات الأولية
  Future<void> _loadInitialData() async {
    // منطق تحميل البيانات الأولية
  }

  /// إلغاء صحة الكاش
  Future<void> _invalidateCache() async {
    await _cache.clearPattern('data_*');
  }

  /// تنظيف الموارد
  void dispose() {
    _dataController.close();
  }
}

/// استثناء خاص بالخدمة
class ServiceException implements Exception {
  final String message;
  const ServiceException(this.message);

  @override
  String toString() => 'ServiceException: $message';
}
```

## 🎯 قالب خدمة مع Real-time

```dart
class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  final PocketBaseService _pocketBase = PocketBaseService();
  final Map<String, StreamSubscription> _subscriptions = {};

  /// الاشتراك في التحديثات المباشرة
  Stream<RealtimeEvent<[DataType]>> subscribe(String collection) {
    final controller = StreamController<RealtimeEvent<[DataType]>>.broadcast();

    _pocketBase.collection(collection).subscribe('*', (e) {
      final event = RealtimeEvent<[DataType]>(
        action: e.action,
        record: [DataType].fromJson(e.record?.toJson() ?? {}),
      );
      controller.add(event);
    });

    return controller.stream;
  }

  /// إلغاء الاشتراك
  void unsubscribe(String collection) {
    _pocketBase.collection(collection).unsubscribe();
  }

  /// تنظيف جميع الاشتراكات
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}

class RealtimeEvent<T> {
  final String action; // 'create', 'update', 'delete'
  final T record;

  const RealtimeEvent({
    required this.action,
    required this.record,
  });
}
```

## 📝 قائمة التحقق

- [ ] نمط Singleton
- [ ] معالجة الأخطاء الشاملة
- [ ] تسجيل العمليات (logging)
- [ ] استخدام الكاش عند الإمكان
- [ ] دعم Real-time عند الحاجة
- [ ] تنظيف الموارد
- [ ] اختبارات شاملة
- [ ] توثيق واضح
- [ ] معالجة حالات الشبكة
- [ ] دعم إلغاء العمليات