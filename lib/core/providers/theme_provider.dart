import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import '../services/location_service.dart';

class ThemeProvider extends ChangeNotifier {
  // 'Tajawal' = خط التجوال افتراضي للمشترك الجديد
  String _fontFamily = 'Tajawal';
  static const String keyFontFamily = 'font_family';
  
  // Theme Mode
  String _currentTheme = 'auto'; // Default to auto (System/Sunset)
  static const String keyThemeMode = 'theme_mode';
  bool _isNight = false; // For Auto Mode status

  String get fontFamily => _fontFamily;
  String get currentTheme => _currentTheme;

  // Helper for MaterialApp
  ThemeMode get materialThemeMode {
    if (_currentTheme == 'light') return ThemeMode.light;
    if (_currentTheme == 'dark') return ThemeMode.dark;
    // Auto (Sunset based)
    return _isNight ? ThemeMode.dark : ThemeMode.light;
  }

  final List<String> availableFonts = [
    'Default',
    'Manal High',
    'Manal Bold',
    'Tajawal',
    'Amiri',
    'Al Amiri',
  ];

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontFamily = prefs.getString(keyFontFamily) ?? 'Tajawal';
    _currentTheme = prefs.getString(keyThemeMode) ?? 'auto';
    
    // Automatically check sunset if auto
    if (_currentTheme == 'auto') {
      await _checkSunset();
    }
    
    notifyListeners();
  }
  
  Future<void> _checkSunset() async {
    try {
       // Quick check based on last known or default location
       // In a real app we might want to listen to location updates, 
       // but for theme switching, a one-time check on start/resume is usually 90% enough.
       final locService = LocationService();
       final locData = await locService.getApproximateLocation(); // cached or Riyadh
       final coords = locData.toCoordinates();
       
       updateSunsetStatus(coords);
    } catch (e) {
      print('Theme Sunset Check Error: $e');
    }
  }
  
  void updateSunsetStatus(Coordinates coords) {
     if (_currentTheme != 'auto') return;

     final params = CalculationMethod.umm_al_qura.getParameters();
     final now = DateTime.now();
     final date = DateComponents.from(now);
     final prayerTimes = PrayerTimes(coords, date, params);
     
     final maghrib = prayerTimes.maghrib;
     final sunrise = prayerTimes.sunrise;
     
     // Logic: Night if before Sunrise OR after Maghrib
     bool isNightNow = now.isBefore(sunrise) || now.isAfter(maghrib);
     
     if (_isNight != isNightNow) {
       _isNight = isNightNow;
       notifyListeners();
     }
  }

  Future<void> setFontFamily(String font) async {
    if (!availableFonts.contains(font)) return;
    
    _fontFamily = font;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyFontFamily, font);
  }
  
  Future<void> setThemeMode(String mode) async {
    if (!['light', 'dark', 'auto'].contains(mode)) return;
    
    _currentTheme = mode;
    if (mode == 'auto') {
      _checkSunset();
    }
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyThemeMode, mode);
  }

  TextTheme getCustomTextTheme(TextTheme base) {
    try {
      switch (_fontFamily) {
        case 'Manal High':
          return base.apply(fontFamily: 'Manal_High');
        case 'Manal Bold':
          return base.apply(fontFamily: 'Manal_Bold');
        case 'Tajawal':
          return GoogleFonts.tajawalTextTheme(base);
        case 'Amiri':
          return GoogleFonts.amiriTextTheme(base);
        case 'Al Amiri':
          return GoogleFonts.amiriQuranTextTheme(base);
        default:
          if (kIsWeb) {
            return base.apply(fontFamily: 'system-ui');
          }
          return base;
      }
    } catch (e) {
      debugPrint('⚠️ Error loading custom font: $e. Using base theme.');
      return base;
    }
  }

  static TextStyle getTextStyleForFont(String fontName, TextStyle baseStyle) {
    if (fontName == 'Default' || fontName.isEmpty) {
      return baseStyle.copyWith(fontFamily: null);
    }
    if (fontName == 'Manal High') {
      return baseStyle.copyWith(fontFamily: 'Manal_High');
    }
    if (fontName == 'Manal Bold') {
      return baseStyle.copyWith(fontFamily: 'Manal_Bold');
    }
    String googleFontName = fontName;
    if (fontName == 'Al Amiri') {
      googleFontName = 'Amiri Quran';
    }
    try {
      return GoogleFonts.getFont(
        googleFontName,
        textStyle: baseStyle,
      );
    } catch (e) {
      debugPrint('⚠️ Error loading Google Font $googleFontName: $e');
      return baseStyle;
    }
  }
}
