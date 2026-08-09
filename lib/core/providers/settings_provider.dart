import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String keyMagneticScroll = 'magnetic_scroll_enabled';
  static const String keyArticleFontFamily = 'article_font_family';
  static const String keyShowLocationInfo = 'show_location_info';
  static const String keyJustifyArticles = 'justify_articles';
  
  bool _isMagneticScrollEnabled = false;
  String _articleFontFamily = 'Tajawal';
  bool _showLocationInfo = true;
  bool _justifyArticles = false;

  bool get isMagneticScrollEnabled => _isMagneticScrollEnabled;
  String get articleFontFamily => _articleFontFamily;
  bool get showLocationInfo => _showLocationInfo;
  bool get justifyArticles => _justifyArticles;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isMagneticScrollEnabled = prefs.getBool(keyMagneticScroll) ?? false;
    _articleFontFamily = prefs.getString(keyArticleFontFamily) ?? 'Tajawal';
    _showLocationInfo = prefs.getBool(keyShowLocationInfo) ?? true;
    _justifyArticles = prefs.getBool(keyJustifyArticles) ?? false;
    notifyListeners();
  }

  Future<void> setMagneticScrollEnabled(bool enabled) async {
    if (_isMagneticScrollEnabled == enabled) return;
    
    _isMagneticScrollEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyMagneticScroll, enabled);
  }

  Future<void> setArticleFontFamily(String font) async {
    if (_articleFontFamily == font) return;

    _articleFontFamily = font;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyArticleFontFamily, font);
  }

  Future<void> setShowLocationInfo(bool enabled) async {
    if (_showLocationInfo == enabled) return;

    _showLocationInfo = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyShowLocationInfo, enabled);
  }

  Future<void> setJustifyArticles(bool justify) async {
    if (_justifyArticles == justify) return;

    _justifyArticles = justify;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyJustifyArticles, justify);
  }

  Future<void> clearSettings() async {
    _isMagneticScrollEnabled = false;
    _articleFontFamily = 'Tajawal';
    _showLocationInfo = true;
    _justifyArticles = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyMagneticScroll);
      await prefs.remove(keyArticleFontFamily);
      await prefs.remove(keyShowLocationInfo);
      await prefs.remove(keyJustifyArticles);
    } catch (_) {}
  }
}
