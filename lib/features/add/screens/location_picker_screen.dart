import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'package:sijilli/core/constants/app_colors.dart';
import 'package:sijilli/core/constants/app_dimens.dart';
import 'package:sijilli/core/extensions/context_l10n.dart';
import 'package:geolocator/geolocator.dart';

class LocationPickerResult {
  final double latitude;
  final double longitude;
  final String region;
  final String building;

  LocationPickerResult({
    required this.latitude,
    required this.longitude,
    required this.region,
    required this.building,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final Dio _dio = Dio();

  LatLng _currentCenter = const LatLng(24.7136, 46.6753); // Default Riyadh
  bool _isLoadingSearch = false;
  List<dynamic> _searchResults = [];
  String _selectedAddressName = '';
  String _selectedCityName = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _currentCenter = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _locateUser();
      });
    }
  }

  Future<void> _locateUser() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.localeName == 'ar'
                    ? 'خدمات الموقع معطلة. يرجى تفعيلها.'
                    : 'Location services are disabled. Please enable them.',
              ),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.l10n.localeName == 'ar'
                      ? 'تم رفض إذن الموقع.'
                      : 'Location permission was denied.',
                ),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.localeName == 'ar'
                    ? 'إذن الموقع مرفوض دائماً. يرجى تفعيله من الإعدادات.'
                    : 'Location permissions are permanently denied.',
              ),
            ),
          );
        }
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
      } catch (e) {
        debugPrint('Geolocator.getCurrentPosition failed: $e');
        
        // Fallback 1: try last known position
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (err) {
          debugPrint('Geolocator.getLastKnownPosition failed: $err');
        }
        
        // Fallback 2: try with lower accuracy
        if (position == null) {
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: Duration(seconds: 4),
              ),
            );
          } catch (err) {
            debugPrint('Low accuracy getCurrentPosition failed: $err');
          }
        }
      }

      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.localeName == 'ar'
                    ? 'فشل تحديد الموقع الحالي. يرجى التأكد من تفعيل الـ GPS وموقع المحاكي.'
                    : 'Failed to determine location. Please verify GPS and simulator location settings.',
              ),
            ),
          );
        }
        return;
      }

      final target = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentCenter = target;
      });
      _mapController.move(target, 16.0);
      _reverseGeocode(target);
    } catch (e) {
      debugPrint('Locate user failed: $e');
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isLoadingSearch = true;
      _searchResults = [];
    });

    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 5,
          'addressdetails': 1,
        },
        options: Options(
          headers: {
            'User-Agent': 'SijilliApp/1.0',
          },
        ),
      );

      if (response.statusCode == 200 && response.data is List) {
        setState(() {
          _searchResults = response.data;
        });
      }
    } catch (e) {
      debugPrint('Search failed: $e');
    } finally {
      setState(() {
        _isLoadingSearch = false;
      });
    }
  }

  Future<void> _reverseGeocode(LatLng position) async {
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': position.latitude,
          'lon': position.longitude,
          'format': 'json',
          'addressdetails': 1,
        },
        options: Options(
          headers: {
            'User-Agent': 'SijilliApp/1.0',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final address = response.data['address'] as Map<String, dynamic>?;
        final displayName = response.data['display_name'] as String? ?? '';
        
        String building = '';
        String region = '';

        if (address != null) {
          building = address['amenity'] ?? 
                     address['building'] ?? 
                     address['shop'] ?? 
                     address['office'] ?? 
                     address['road'] ?? 
                     '';
          region = address['suburb'] ?? 
                   address['city'] ?? 
                   address['town'] ?? 
                   address['state'] ?? 
                   '';
        }

        if (building.isEmpty) {
          final parts = displayName.split(',');
          building = parts.isNotEmpty ? parts.first.trim() : '';
        }

        setState(() {
          _selectedAddressName = building;
          _selectedCityName = region;
        });
      }
    } catch (e) {
      debugPrint('Reverse geocode failed: $e');
    }
  }

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      setState(() {
        _currentCenter = camera.center;
      });
    }
  }

  void _onMapMoveEnd(MapCamera camera) {
    _reverseGeocode(camera.center);
  }

  void _selectSearchResult(dynamic result) {
    final lat = double.parse(result['lat'].toString());
    final lon = double.parse(result['lon'].toString());
    final target = LatLng(lat, lon);

    final address = result['address'] as Map<String, dynamic>?;
    
    String building = '';
    String region = '';

    if (address != null) {
      building = address['amenity'] ?? 
                 address['building'] ?? 
                 address['shop'] ?? 
                 address['office'] ?? 
                 address['road'] ?? 
                 '';
      region = address['suburb'] ?? 
               address['city'] ?? 
               address['town'] ?? 
               address['state'] ?? 
               '';
    }

    if (building.isEmpty) {
      final displayName = result['display_name'] as String? ?? '';
      final parts = displayName.split(',');
      building = parts.isNotEmpty ? parts.first.trim() : '';
    }

    setState(() {
      _currentCenter = target;
      _selectedAddressName = building;
      _selectedCityName = region;
      _searchResults = [];
      _searchController.text = '';
    });

    _mapController.move(target, 16.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.localeName == 'ar' ? 'تحديد الموقع' : 'Select Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(
                context,
                LocationPickerResult(
                  latitude: _currentCenter.latitude,
                  longitude: _currentCenter.longitude,
                  region: _selectedCityName,
                  building: _selectedAddressName,
                ),
              );
            },
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 14.0,
              onPositionChanged: _onMapMoved,
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  _onMapMoveEnd(event.camera);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                tileProvider: NetworkTileProvider(
                  headers: {
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                  },
                ),
              ),
            ],
          ),
          
          // Center Marker
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 40),
              child: const Icon(
                Icons.location_on,
                size: 45,
                color: AppColors.primary,
              ),
            ),
          ),

          // Search Bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.l10n.localeName == 'ar' ? 'بحث عن مكان...' : 'Search for a place...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: _isLoadingSearch
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: _searchLocation,
                  ),
                ),
                
                // Search Results
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade900 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          title: Text(
                            result['display_name'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // My Location Button
          Positioned(
            bottom: 190,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'locate_user_fab',
              mini: true,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: _locateUser,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Bottom Info Card
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F0F0F) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _selectedAddressName.isNotEmpty
                        ? _selectedAddressName
                        : (context.l10n.localeName == 'ar' ? 'حدد موقعاً يدوياً' : 'Pin a location manually'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_selectedCityName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _selectedCityName,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        LocationPickerResult(
                          latitude: _currentCenter.latitude,
                          longitude: _currentCenter.longitude,
                          region: _selectedCityName,
                          building: _selectedAddressName,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      context.l10n.localeName == 'ar' ? 'تأكيد الموقع' : 'Confirm Location',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
