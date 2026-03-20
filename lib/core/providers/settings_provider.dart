import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String keyMagneticScroll = 'magnetic_scroll_enabled';
  
  bool _isMagneticScrollEnabled = true;

  bool get isMagneticScrollEnabled => _isMagneticScrollEnabled;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isMagneticScrollEnabled = prefs.getBool(keyMagneticScroll) ?? true;
    notifyListeners();
  }

  Future<void> setMagneticScrollEnabled(bool enabled) async {
    if (_isMagneticScrollEnabled == enabled) return;
    
    _isMagneticScrollEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyMagneticScroll, enabled);
  }
}
