import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pb_system_config_service.dart';

/// 🌐 مزود البيانات لإعدادات النظام العامة (Remote Config)
class GlobalConfigProvider extends ChangeNotifier {
  final PbSystemConfigService _configService = PbSystemConfigService();
  
  // قاموس الإعدادات المجلوبة من القاعدة
  Map<String, RecordModel> _configs = {};
  // قاموس الإعدادات المحفوظة محلياً كاحتياط (Cache)
  Map<String, dynamic> _localCache = {};
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  /// هل التسجيل مفتوح؟ (القيمة الافتراضية true)
  bool get isRegistrationEnabled {
    return _getBool('registrations_enabled') ?? true;
  }
  
  /// هل ميزة البحث عن المستخدمين مفعلة؟ (القيمة الافتراضية true)
  bool get isUserSearchEnabled {
    return _getBool('user_search_enabled') ?? true;
  }

  /// هل لعبة تحدي الأعصاب مفعلة؟ (القيمة الافتراضية false لضمان الأمان في حال حدوث خلل)
  bool get isNerveGameEnabled {
    return _getBool('nerve_game_enabled') ?? false;
  }

  /// الحد الأقصى لحروف المقال
  int get articleMaxChars {
    return _getNumber('article_max_chars')?.toInt() ?? 5000;
  }

  /// الحد الأقصى لعدد الملفات الصوتية في المقال الواحد
  int get audioMaxFiles {
    return _getNumber('audio_max_files')?.toInt() ?? 5;
  }

  /// الحد الأقصى لحجم الملف الصوتي الواحد بالميجابايت
  int get audioMaxSizeMb {
    return _getNumber('audio_max_size_mb')?.toInt() ?? 5;
  }

  /// الحد الأقصى للمجموع الكلي لسعة الملفات الصوتية بالميجابايت
  int get audioTotalCapacityMb {
    return _getNumber('audio_total_capacity_mb')?.toInt() ?? 25;
  }

  /// الحد الأقصى لعدد الضيوف للمستخدم العادي
  int get limitGuestsUser {
    return _getNumber('limit_guests_user')?.toInt() ?? 1;
  }

  /// الحد الأقصى لعدد الضيوف للكاتب
  int get limitGuestsWriter {
    return _getNumber('limit_guests_writer')?.toInt() ?? 5;
  }

  /// الحد الأقصى لعدد الضيوف للمؤسسة
  int get limitGuestsOrg {
    return _getNumber('limit_guests_org')?.toInt() ?? 15;
  }

  /// صلاحيات تدوين المواعيد
  bool get permCreateApptUser => _getBool('perm_create_appt_user') ?? true;
  bool get permCreateApptWriter => _getBool('perm_create_appt_writer') ?? true;
  bool get permCreateApptOrg => _getBool('perm_create_appt_org') ?? true;

  /// صلاحيات تدوين المقالات
  bool get permCreateArticleUser => _getBool('perm_create_article_user') ?? false;
  bool get permCreateArticleWriter => _getBool('perm_create_article_writer') ?? true;
  bool get permCreateArticleOrg => _getBool('perm_create_article_org') ?? true;

  /// صلاحيات التعليقات
  bool get permCommentsUser => _getBool('perm_comments_user') ?? true;
  bool get permCommentsWriter => _getBool('perm_comments_writer') ?? true;
  bool get permCommentsOrg => _getBool('perm_comments_org') ?? true;

  // دالة فحص القدرة على تدوين موعد
  bool canCreateAppointment(dynamic user) {
    if (user == null) return false;
    if (user.role == 'admin') return true;
    if (user.role == 'writer') return permCreateApptWriter;
    if (user.role == 'organization') return permCreateApptOrg;
    return permCreateApptUser;
  }

  // دالة فحص القدرة على تدوين مقال
  bool canCreateArticle(dynamic user) {
    if (user == null) return false;
    if (user.role == 'admin') return true;
    if (user.role == 'writer') return permCreateArticleWriter;
    if (user.role == 'organization') return permCreateArticleOrg;
    return permCreateArticleUser;
  }

  // دالة فحص الحد الأقصى للضيوف
  int maxGuestsCount(dynamic user) {
    if (user == null) return 0;
    if (user.role == 'admin') return 9999;
    if (user.role == 'writer') return limitGuestsWriter;
    if (user.role == 'organization') return limitGuestsOrg;
    return limitGuestsUser;
  }

  // دالة فحص الصلاحية للتعليق
  bool canComment(dynamic user) {
    if (user == null) return false;
    if (user.role == 'admin') return true;
    if (user.role == 'writer') return permCommentsWriter;
    if (user.role == 'organization') return permCommentsOrg;
    return permCommentsUser;
  }

  /// الحصول على بريد التواصل
  String get contactEmail {
    return _getString('contact_email') ?? 'sijilliapp@gmail.com';
  }

  /// الحصول على رقم واتساب التواصل
  String get contactWhatsApp {
    return _getString('contact_whatsapp') ?? '+97339477742';
  }

  /// جلب الإعدادات من المحرك (PocketBase)
  Future<void> fetchConfig() async {
    _isLoading = true;
    notifyListeners();

    // 1. تحميل الكاش المحلي كبداية سريعة واحتياطية
    await _loadFromLocalCache();

    try {
      // 2. جلب الإعدادات الحديثة من السيرفر
      final fetched = await _configService.fetchAllConfigs();
      if (fetched.isNotEmpty) {
        _configs = fetched;
        // 3. تحديث الكاش المحلي بالقيم الجديدة
        await _saveToLocalCache();
      }
    } catch (e) {
      debugPrint('❌ Error syncing global config: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// الحصول على قيمة منطقية من الإعدادات (مع دعم الكاش)
  bool? _getBool(String key) {
    if (_configs.containsKey(key)) {
      return _configService.getBool(_configs, key);
    }
    final val = _localCache[key];
    if (val is bool) return val;
    return null;
  }

  /// الحصول على رقم من الإعدادات (مع دعم الكاش)
  double? _getNumber(String key) {
    if (_configs.containsKey(key)) {
      return _configService.getNumber(_configs, key);
    }
    final val = _localCache[key];
    if (val is num) return val.toDouble();
    return null;
  }

  /// الحصول على نص من الإعدادات (مع دعم الكاش)
  String? _getString(String key) {
    if (_configs.containsKey(key)) {
      return _configService.getString(_configs, key);
    }
    return _localCache[key]?.toString();
  }

  /// الحصول على رقم من الإعدادات
  double getNumber(String key, {double defaultValue = 0}) {
    return _getNumber(key) ?? defaultValue;
  }

  /// الحصول على نص من الإعدادات
  String getString(String key, {String defaultValue = ''}) {
    return _getString(key) ?? defaultValue;
  }

  /// الحصول على القاموس الديناميكي لتصحيح الأخطاء الشائعة
  Map<String, String> get spellingFixes {
    final rawJson = getString('spelling_fixes', defaultValue: '{}');
    try {
      final decoded = json.decode(rawJson);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
      }
    } catch (e) {
      debugPrint('❌ Error parsing spelling_fixes config: $e');
    }
    return {};
  }

  /// تحميل الإعدادات المخزنة محلياً من SharedPreferences
  Future<void> _loadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_global_config');
      if (cachedJson != null) {
        final decoded = json.decode(cachedJson);
        if (decoded is Map<String, dynamic>) {
          _localCache = decoded;
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading global config cache: $e');
    }
  }

  /// حفظ الإعدادات المستلمة من السحابة في SharedPreferences
  Future<void> _saveToLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> dataToCache = {};
      
      _configs.forEach((key, record) {
        // نقوم باستخراج القيمة الفعلية المخزنة في السجل السحابي وحفظها
        final valBool = record.getBoolValue('value_bool');
        final valNum = record.getDoubleValue('value_number');
        final valStr = record.getStringValue('value_string');
        
        if (valBool != null) {
          dataToCache[key] = valBool;
        } else if (valNum != null && valNum != 0) {
          dataToCache[key] = valNum;
        } else if (valStr != null && valStr.isNotEmpty) {
          dataToCache[key] = valStr;
        }
      });
      
      if (dataToCache.isNotEmpty) {
        await prefs.setString('cached_global_config', json.encode(dataToCache));
      }
    } catch (e) {
      debugPrint('❌ Error saving global config cache: $e');
    }
  }
}
