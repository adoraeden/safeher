import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/route_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class RouteCheckScreen extends StatefulWidget {
  const RouteCheckScreen({super.key});

  @override
  State<RouteCheckScreen> createState() => _RouteCheckScreenState();
}

class _RouteCheckScreenState extends State<RouteCheckScreen> {
  final _routeService = RouteService();
  final _destinationController = TextEditingController();
  RoutePoint? _currentLocation;
  RouteCheckResult? _result;
  bool _isLoadingLocation = true;
  bool _isChecking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are turned off.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is needed for route checking.');
      }
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = RoutePoint(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _checkRoute() async {
    if (_currentLocation == null || _destinationController.text.trim().isEmpty)
      return;
    setState(() {
      _isChecking = true;
      _error = null;
      _result = null;
    });
    try {
      final destination = await _routeService.geocodeAddress(
        _destinationController.text.trim(),
      );
      if (destination == null)
        throw Exception(
          'Could not find that destination. Try a more specific address.',
        );
      final result = await _routeService.checkRoute(
        from: _currentLocation!,
        to: destination,
      );
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isChecking = false);
    }
  }

  Color _noteColor(int count) {
    if (count == 0) return AppColors.success;
    if (count <= 2) return AppColors.warning;
    return AppColors.dangerLight;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Check')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Checks reported community incidents along a walking route. Safety information only — never a guarantee a route is safe.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _destinationController,
                        decoration: const InputDecoration(
                          hintText: 'Destination address',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                        onSubmitted: (_) => _checkRoute(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(
                      onPressed: (_isLoadingLocation || _isChecking)
                          ? null
                          : _checkRoute,
                      child: _isChecking
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Check'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.dangerLight,
                ),
              ),
            ),
          Expanded(
            child: _isLoadingLocation
                ? const Center(child: CircularProgressIndicator())
                : _currentLocation == null
                ? const Center(
                    child: Text(
                      'Location unavailable',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(
                            _currentLocation!.lat,
                            _currentLocation!.lng,
                          ),
                          initialZoom: 14,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.safeher.women_safety',
                          ),
                          if (_result != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _result!.path
                                      .map((p) => LatLng(p.lat, p.lng))
                                      .toList(),
                                  strokeWidth: 4,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  _currentLocation!.lat,
                                  _currentLocation!.lng,
                                ),
                                width: 36,
                                height: 36,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.navigation,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                              if (_result != null && _result!.path.isNotEmpty)
                                Marker(
                                  point: LatLng(
                                    _result!.path.last.lat,
                                    _result!.path.last.lng,
                                  ),
                                  width: 36,
                                  height: 36,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.dangerLight,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.flag,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (_result != null)
                        Positioned(
                          bottom: AppSpacing.md,
                          left: AppSpacing.md,
                          right: AppSpacing.md,
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: _noteColor(
                                        _result!.nearbyReportCount,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _result!.safetyNote,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _noteColor(
                                            _result!.nearbyReportCount,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${(_result!.distanceMeters / 1000).toStringAsFixed(1)} km · ~${(_result!.durationSeconds / 60).round()} min walk · ${_result!.nearbyReportCount} nearby report${_result!.nearbyReportCount == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
