// 📍 lib/core/services/location_service.dart
// 🌍 خدمة تحديد الموقع (GPS + IP Fallback)

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:adhan/adhan.dart'; // For Coordinates class

/// نموذج بيانات الموقع الجغرافي
class GeoLocationData {
  final double latitude;
  final double longitude;
  final String? country;
  final String? city;
  final bool isFromIp; // هل تم جلبه عن طريق IP؟

  GeoLocationData({
    required this.latitude,
    required this.longitude,
    this.country,
    this.city,
    required this.isFromIp,
  });

  Coordinates toCoordinates() => Coordinates(latitude, longitude);

  @override
  String toString() => 'Lat: $latitude, Lon: $longitude, Country: $country, City: $city, IP: $isFromIp';
}

class LocationService {
  // Singleton pattern if needed, but static methods or simple instance is fine
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final Dio _dio = Dio();

  /// محاولة الحصول على أفضل موقع متاح (GPS أولاً، ثم IP)
  Future<GeoLocationData> getCurrentLocation() async {
    // 1. محاولة GPS (دقة عالية)
    try {
      // التحقق من الخدمة
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          // استخدام دقة منخفضة (10كم) كما هو مطلوب لتوفير البطارية والسرعة
          // "100km square" implies roughly 10km radius is fine
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 5),
            ),
          );
          
          return GeoLocationData(
            latitude: position.latitude,
            longitude: position.longitude,
            isFromIp: false,
            // GPS doesn't give country name easily without geocoding, 
            // but we can fetch it separately if critical, or rely on IP for country name
            country: null, 
          );
        }
      }
    } catch (e) {
      print('⚠️ GPS Location failed: $e');
    }

    // 2. Fallback to IP Geolocation (دقة منخفضة - مدينة/دولة)
    print('ℹ️ Falling back to IP Geolocation...');
    return await getApproximateLocation();
  }


  /// جلب الموقع التقريبي عبر IP (بدون أذونات GPS)
  Future<GeoLocationData> getApproximateLocation() async {
    try {
      // استخدام ip-api.com
      final response = await _dio.get('http://ip-api.com/json');
      
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final data = response.data;
        return GeoLocationData(
          latitude: (data['lat'] as num).toDouble(),
          longitude: (data['lon'] as num).toDouble(),
          country: data['country'],
          city: data['city'],
          isFromIp: true,
        );
      }
    } catch (e) {
      print('❌ IP Location failed: $e');
    }

    // 3. Fallback نهائي (الرياض - السعودية)
    return GeoLocationData(
      latitude: 24.7136,
      longitude: 46.6753,
      country: 'Saudi Arabia',
      city: 'Riyadh',
      isFromIp: true, 
    );
  }
}
