import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String keyMagneticScroll = 'magnetic_scroll_enabled';
  static const String keyArticleFontFamily = 'article_font_family';
  static const String keyShowLocationInfo = 'show_location_info';
  
  bool _isMagneticScrollEnabled = true;
  String _articleFontFamily = 'Default';
  bool _showLocationInfo = true;

  bool get isMagneticScrollEnabled => _isMagneticScrollEnabled;
  String get articleFontFamily => _articleFontFamily;
  bool get showLocationInfo => _showLocationInfo;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isMagneticScrollEnabled = prefs.getBool(keyMagneticScroll) ?? true;
    _articleFontFamily = prefs.getString(keyArticleFontFamily) ?? 'Default';
    _showLocationInfo = prefs.getBool(keyShowLocationInfo) ?? true;
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

  Future<void> clearSettings() async {
    _isMagneticScrollEnabled = true;
    _articleFontFamily = 'Default';
    _showLocationInfo = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyMagneticScroll);
      await prefs.remove(keyArticleFontFamily);
      await prefs.remove(keyShowLocationInfo);
    } catch (_) {}
  }
}
