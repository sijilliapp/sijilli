import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import '../services/location_service.dart';

class ThemeProvider extends ChangeNotifier {
  String _fontFamily = kIsWeb ? 'Tajawal' : 'Default';
  static const String keyFontFamily = 'font_family';
  
  // Theme Mode
  String _currentTheme = 'light'; // light, dark, auto
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
    'Cairo',
    'Almarai',
    'Tajawal',
    'IBM Plex Sans Arabic',
    'Lalezar',
    'Scheherazade New',
  ];

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontFamily = prefs.getString(keyFontFamily) ?? (kIsWeb ? 'Tajawal' : 'Default');
    _currentTheme = prefs.getString(keyThemeMode) ?? 'light';
    
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
    switch (_fontFamily) {
      case 'Cairo':
        return GoogleFonts.cairoTextTheme(base);
      case 'Almarai':
        return GoogleFonts.almaraiTextTheme(base);
      case 'Tajawal':
        return GoogleFonts.tajawalTextTheme(base);
      case 'IBM Plex Sans Arabic':
        return GoogleFonts.ibmPlexSansArabicTextTheme(base);
      case 'Scheherazade New':
        // Scheherazade New is thin by default, we apply BOLD globally for it
        var theme = GoogleFonts.scheherazadeNewTextTheme(base);
        return theme.copyWith(
          displayLarge: theme.displayLarge?.copyWith(fontWeight: FontWeight.bold),
          displayMedium: theme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
          displaySmall: theme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
          headlineLarge: theme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
          headlineMedium: theme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          headlineSmall: theme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          titleLarge: theme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          titleMedium: theme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          titleSmall: theme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          bodyLarge: theme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          bodyMedium: theme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          bodySmall: theme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          labelLarge: theme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          labelMedium: theme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
          labelSmall: theme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
        );
      default:
        // Use system default font (San Francisco on iOS, Roboto on Android)
        return base;
    }
  }
}
