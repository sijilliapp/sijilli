import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import '../services/location_service.dart';

class ThemeProvider extends ChangeNotifier {
  // 'Tajawal' = خط التجوال افتراضي للمشترك الجديد
  String _fontFamily = 'Default';
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
    'Tajawal',
    'Tajawal Medium',
    'Tajawal Bold',
    'Amiri',
  ];

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontFamily = prefs.getString(keyFontFamily) ?? 'Default';
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
      print('Failed to calculate sunset for auto theme: $e');
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
    if (_fontFamily == font) return;
    _fontFamily = font;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyFontFamily, font);
  }
  
  Future<void> setThemeMode(String mode) async {
    if (_currentTheme == mode) return;
    _currentTheme = mode;
    
    if (mode == 'auto') {
      await _checkSunset();
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
        case 'Tajawal':
          return GoogleFonts.tajawalTextTheme(base);
        case 'Tajawal Medium':
          final defaultTheme = GoogleFonts.tajawalTextTheme(base);
          return defaultTheme.copyWith(
            bodyLarge: defaultTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            bodyMedium: defaultTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            bodySmall: defaultTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            titleLarge: defaultTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            titleMedium: defaultTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            titleSmall: defaultTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            labelLarge: defaultTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
            labelMedium: defaultTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
            labelSmall: defaultTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500),
          );
        case 'Tajawal Bold':
          final defaultTheme = GoogleFonts.tajawalTextTheme(base);
          return defaultTheme.copyWith(
            bodyLarge: defaultTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            bodyMedium: defaultTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            bodySmall: defaultTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            titleLarge: defaultTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            titleMedium: defaultTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            titleSmall: defaultTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            labelLarge: defaultTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            labelMedium: defaultTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            labelSmall: defaultTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          );
        case 'Amiri':
          return GoogleFonts.amiriTextTheme(base);
        default:
          if (kIsWeb) {
            return base.apply(fontFamily: 'system-ui');
          }
          return base.apply(fontFamily: 'sans-serif');
      }
    } catch (e) {
      debugPrint('⚠️ Error loading custom font: $e. Using base theme.');
      return base;
    }
  }

  static TextStyle getTextStyleForFont(String fontName, TextStyle baseStyle) {
    if (fontName == 'Default' || fontName.isEmpty) {
      if (kIsWeb) {
        return baseStyle.copyWith(fontFamily: 'system-ui');
      }
      return baseStyle.copyWith(fontFamily: 'sans-serif');
    }
    if (fontName == 'Manal High') {
      return baseStyle.copyWith(fontFamily: 'Manal_High');
    }
    if (fontName == 'Tajawal Medium') {
      try {
        return GoogleFonts.getFont(
          'Tajawal',
          textStyle: baseStyle.copyWith(
            fontWeight: baseStyle.fontWeight == FontWeight.bold ? FontWeight.w700 : FontWeight.w500,
          ),
        );
      } catch (e) {
        return baseStyle;
      }
    }
    if (fontName == 'Tajawal Bold') {
      try {
        return GoogleFonts.getFont(
          'Tajawal',
          textStyle: baseStyle.copyWith(
            fontWeight: baseStyle.fontWeight == FontWeight.bold ? FontWeight.w900 : FontWeight.w700,
          ),
        );
      } catch (e) {
        return baseStyle;
      }
    }
    try {
      return GoogleFonts.getFont(
        fontName,
        textStyle: baseStyle,
      );
    } catch (e) {
      debugPrint('⚠️ Error loading Google Font $fontName: $e');
      return baseStyle;
    }
  }
}
