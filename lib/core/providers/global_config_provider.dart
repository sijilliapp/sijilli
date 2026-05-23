import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/pb_system_config_service.dart';

/// 🌐 مزود البيانات لإعدادات النظام العامة (Remote Config)
class GlobalConfigProvider extends ChangeNotifier {
  final PbSystemConfigService _configService = PbSystemConfigService();
  
  // قاموس الإعدادات المجلوبة من القاعدة
  Map<String, RecordModel> _configs = {};
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  /// هل التسجيل مفتوح؟ (القيمة الافتراضية true)
  bool get isRegistrationEnabled {
    return _configService.getBool(_configs, 'registrations_enabled') ?? true;
  }
  
  /// هل ميزة البحث عن المستخدمين مفعلة؟ (القيمة الافتراضية true)
  bool get isUserSearchEnabled {
    return _configService.getBool(_configs, 'user_search_enabled') ?? true;
  }

  /// الحد الأقصى لحروف المقال
  int get articleMaxChars {
    return _configService.getNumber(_configs, 'article_max_chars')?.toInt() ?? 5000;
  }

  /// الحصول على بريد التواصل
  String get contactEmail {
    return _configService.getString(_configs, 'contact_email') ?? 'sijilliapp@gmail.com';
  }

  /// الحصول على رقم واتساب التواصل
  String get contactWhatsApp {
    return _configService.getString(_configs, 'contact_whatsapp') ?? '+97339477742';
  }

  /// جلب الإعدادات من المحرك (PocketBase)
  Future<void> fetchConfig() async {
    _isLoading = true;
    notifyListeners();

    try {
      _configs = await _configService.fetchAllConfigs();
    } catch (e) {
      debugPrint('❌ Error syncing global config: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// الحصول على رقم من الإعدادات
  double getNumber(String key, {double defaultValue = 0}) {
    return _configService.getNumber(_configs, key) ?? defaultValue;
  }

  /// الحصول على نص من الإعدادات
  String getString(String key, {String defaultValue = ''}) {
    return _configService.getString(_configs, key) ?? defaultValue;
  }
}
