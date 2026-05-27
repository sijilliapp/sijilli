import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String keyMagneticScroll = 'magnetic_scroll_enabled';
  static const String keyUseTraditionalArabic = 'use_traditional_arabic';
  
  bool _isMagneticScrollEnabled = true;
  bool _useTraditionalArabic = false;

  bool get isMagneticScrollEnabled => _isMagneticScrollEnabled;
  bool get useTraditionalArabic => _useTraditionalArabic;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isMagneticScrollEnabled = prefs.getBool(keyMagneticScroll) ?? true;
    _useTraditionalArabic = prefs.getBool(keyUseTraditionalArabic) ?? false;
    notifyListeners();
  }

  Future<void> setMagneticScrollEnabled(bool enabled) async {
    if (_isMagneticScrollEnabled == enabled) return;
    
    _isMagneticScrollEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyMagneticScroll, enabled);
  }

  Future<void> setUseTraditionalArabic(bool enabled) async {
    if (_useTraditionalArabic == enabled) return;

    _useTraditionalArabic = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyUseTraditionalArabic, enabled);
  }
}
