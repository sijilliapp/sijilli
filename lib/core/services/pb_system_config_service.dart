import 'package:pocketbase/pocketbase.dart';
import './pocketbase_client.dart';

/// ⚙️ خدمة جلب إعدادات النظام من قاعدة البيانات (Remote Config)
class PbSystemConfigService {
  PocketBase get _pb => PocketBaseClient.instance.pb;
  static const String collectionName = 'app_config';

  /// جلب كافة الإعدادات الحالية من جدول الإعدادات
  Future<Map<String, RecordModel>> fetchAllConfigs() async {
    try {
      final records = await _pb.collection(collectionName).getFullList(
        sort: '-created',
      );
      
      // تحويل القائمة إلى Map مفتاحها هو الـ key لسهولة الوصول
      return {
        for (var record in records) record.getStringValue('key'): record
      };
    } catch (e) {
      print('⚠️ Failed to fetch system configs: $e');
      return {};
    }
  }

  /// الحصول على قيمة منطقية (Boolean) بناءً على المفتاح
  bool? getBool(Map<String, RecordModel> configs, String key) {
    return configs[key]?.getBoolValue('value_bool');
  }

  /// الحصول على قيمة رقمية بناءً على المفتاح
  double? getNumber(Map<String, RecordModel> configs, String key) {
    return configs[key]?.getDoubleValue('value_number');
  }

  /// الحصول على نص بناءً على المفتاح
  String? getString(Map<String, RecordModel> configs, String key) {
    return configs[key]?.getStringValue('value_string');
  }
}
