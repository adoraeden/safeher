import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/safety_marker.dart';
import '../../models/incident_report.dart';
import '../../services/demo_safety_markers.dart';
import '../../services/incident_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/safeher_map.dart';

class SafetyMapScreen extends StatefulWidget {
  const SafetyMapScreen({super.key});

  @override
  State<SafetyMapScreen> createState() => _SafetyMapScreenState();
}

class _SafetyMapScreenState extends State<SafetyMapScreen> {
  final _mapController = MapController();
  final _incidentService = IncidentService();
  LatLng? _currentLocation;
  List<SafetyMarker> _demoMarkers = [];
  String _activeFilter = 'all';
  bool _isLoading = true;
  String? _error;

  static const _filters = [
    ('all', 'All', Icons.apps),
    ('police', 'Police', Icons.local_police_outlined),
    ('hospital', 'Hospitals', Icons.local_hospital_outlined),
    ('shelter', 'Shelters', Icons.home_outlined),
    ('incident', 'Reported', Icons.warning_amber_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are turned off.');

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission permanently denied — enable it in settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition();
      final location = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _currentLocation = location;
        _demoMarkers = DemoSafetyMarkers.around(
          position.latitude,
          position.longitude,
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _recenter() {
    final loc = _currentLocation;
    if (loc == null) return;
    try {
      _mapController.move(loc, 15);
    } catch (_) {}
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'police':
        return AppColors.primaryLight;
      case 'hospital':
        return AppColors.success;
      case 'shelter':
        return AppColors.accent;
      case 'incident':
        return AppColors.dangerLight;
      default:
        return AppColors.warning;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'police':
        return Icons.local_police_outlined;
      case 'hospital':
        return Icons.local_hospital_outlined;
      case 'shelter':
        return Icons.home_outlined;
      case 'incident':
        return Icons.warning_amber_outlined;
      default:
        return Icons.info_outline;
    }
  }

  void _showDemoMarkerDetail(SafetyMarker marker) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconForType(marker.type),
                  color: _colorForType(marker.type),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    marker.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              marker.description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (marker.phone != null)
              ElevatedButton.icon(
                onPressed: () => launchUrl(Uri.parse('tel:${marker.phone}')),
                icon: const Icon(Icons.call, size: 16),
                label: Text('Call ${marker.phone}'),
              ),
          ],
        ),
      ),
    );
  }

  void _showIncidentDetail(IncidentReport report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_outlined,
                  color: AppColors.dangerLight,
                ),
                const SizedBox(width: 8),
                Text(
                  report.type.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              report.description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reported ${report.timestamp.day}/${report.timestamp.month} ${report.timestamp.hour.toString().padLeft(2, '0')}:${report.timestamp.minute.toString().padLeft(2, '0')} — community submitted',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Map')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(
              message: _error!,
              onRetry: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadLocation();
              },
            )
          : StreamBuilder<List<IncidentReport>>(
              stream: _incidentService.watchAllReports(),
              builder: (context, incidentSnapshot) {
                final incidents = (incidentSnapshot.data ?? [])
                    .where((r) => r.lat != null && r.lng != null)
                    .toList();

                final visibleDemo =
                    _activeFilter == 'all' || _activeFilter == 'incident'
                    ? (_activeFilter == 'incident'
                          ? <SafetyMarker>[]
                          : _demoMarkers)
                    : _demoMarkers
                          .where((m) => m.type == _activeFilter)
                          .toList();

                final visibleIncidents =
                    (_activeFilter == 'all' || _activeFilter == 'incident')
                    ? incidents
                    : <IncidentReport>[];

                int countFor(String key) {
                  switch (key) {
                    case 'all':
                      return _demoMarkers.length + incidents.length;
                    case 'incident':
                      return incidents.length;
                    default:
                      return _demoMarkers.where((m) => m.type == key).length;
                  }
                }

                return Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentLocation!,
                        initialZoom: 15,
                      ),
                      children: [
                        const SafeHerTileLayer(),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _currentLocation!,
                              width: 48,
                              height: 48,
                              child: const MyLocationDot(),
                            ),
                            ...visibleDemo.map(
                              (marker) => Marker(
                                point: LatLng(marker.lat, marker.lng),
                                width: 40,
                                height: 40,
                                child: GestureDetector(
                                  onTap: () => _showDemoMarkerDetail(marker),
                                  child: MapPinBadge(
                                    color: _colorForType(marker.type),
                                    icon: _iconForType(marker.type),
                                  ),
                                ),
                              ),
                            ),
                            ...visibleIncidents.map(
                              (report) => Marker(
                                point: LatLng(report.lat!, report.lng!),
                                width: 40,
                                height: 40,
                                child: GestureDetector(
                                  onTap: () => _showIncidentDetail(report),
                                  child: const MapPinBadge(
                                    color: AppColors.dangerLight,
                                    icon: Icons.warning_amber_outlined,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SafeHerAttribution(),
                      ],
                    ),
                    Positioned(
                      top: AppSpacing.sm,
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: 40,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          scrollDirection: Axis.horizontal,
                          itemCount: _filters.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final f = _filters[index];
                            final isActive = _activeFilter == f.$1;
                            return ChoiceChip(
                              showCheckmark: false,
                              elevation: 3,
                              avatar: Icon(
                                f.$3,
                                size: 16,
                                color: isActive
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                              label: Text(
                                '${f.$2} (${countFor(f.$1)})',
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: isActive,
                              onSelected: (_) =>
                                  setState(() => _activeFilter = f.$1),
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surface,
                              side: const BorderSide(color: AppColors.border),
                              labelStyle: TextStyle(
                                color: isActive
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      right: AppSpacing.md,
                      bottom: 78,
                      child: FloatingActionButton.small(
                        heroTag: 'safety_map_recenter',
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.primaryLight,
                        onPressed: _recenter,
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                    Positioned(
                      bottom: 28,
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'Police/hospital/shelter pins are demo data. Red "Reported" pins are real community submissions.',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
