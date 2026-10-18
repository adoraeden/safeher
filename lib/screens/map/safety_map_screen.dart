import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/safety_marker.dart';
import '../../models/incident_report.dart';
import '../../services/incident_service.dart';
import '../../services/nearby_places_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/geo_utils.dart';
import '../../widgets/safeher_map.dart';

class SafetyMapScreen extends StatefulWidget {
  const SafetyMapScreen({super.key});

  @override
  State<SafetyMapScreen> createState() => _SafetyMapScreenState();
}

class _SafetyMapScreenState extends State<SafetyMapScreen> {
  final _mapController = MapController();
  final _incidentService = IncidentService();
  final _placesService = NearbyPlacesService();

  LatLng? _currentLocation;
  List<SafetyMarker> _places = [];
  bool _placesLoading = false;
  String? _placesError;
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
        _isLoading = false;
      });
      _loadPlaces();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPlaces() async {
    final loc = _currentLocation;
    if (loc == null) return;
    setState(() {
      _placesLoading = true;
      _placesError = null;
    });
    try {
      final places = await _placesService.fetchNearby(
        loc.latitude,
        loc.longitude,
      );
      if (!mounted) return;
      setState(() {
        _places = places;
        _placesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _placesError = e.toString().replaceFirst('Exception: ', '');
        _placesLoading = false;
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

  String _distanceText(SafetyMarker m) {
    final loc = _currentLocation;
    if (loc == null) return '';
    final meters = haversineMeters(loc.latitude, loc.longitude, m.lat, m.lng);
    return meters < 1000
        ? '${meters.round()} m away'
        : '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  Future<void> _openDirections(SafetyMarker m) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${m.lat},${m.lng}&travelmode=walking',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open directions.')),
        );
      }
    }
  }

  void _showPlaceDetail(SafetyMarker marker) {
    final phone = marker.phone;
    final cleanPhone = phone?.replaceAll(RegExp(r'[^0-9+]'), '');
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
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
              const SizedBox(height: 4),
              Text(
                _distanceText(marker),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryLight,
                ),
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
              if (phone != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Phone: $phone',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  if (cleanPhone != null && cleanPhone.isNotEmpty) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            launchUrl(Uri(scheme: 'tel', path: cleanPhone)),
                        icon: const Icon(Icons.call, size: 16),
                        label: const Text('Call'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openDirections(marker),
                      icon: const Icon(Icons.directions_walk, size: 16),
                      label: const Text('Directions'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'From OpenStreetMap. Details may be out of date. In an emergency call 112.',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
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

  Widget _buildStatusCard() {
    Widget content;
    if (_placesLoading) {
      content = const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Finding nearby police stations, hospitals and shelters...',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    } else if (_placesError != null) {
      content = Row(
        children: [
          Expanded(
            child: Text(
              _placesError!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.dangerLight,
              ),
            ),
          ),
          TextButton(onPressed: _loadPlaces, child: const Text('Retry')),
        ],
      );
    } else {
      content = Text(
        _places.isEmpty
            ? 'No police stations, hospitals or shelters were found nearby in OpenStreetMap. In an emergency call 112.'
            : 'Places are from OpenStreetMap and may be out of date. Red "Reported" pins are community reports. Emergency: 112.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: content,
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

                final visiblePlaces =
                    _activeFilter == 'all' || _activeFilter == 'incident'
                    ? (_activeFilter == 'incident' ? <SafetyMarker>[] : _places)
                    : _places.where((m) => m.type == _activeFilter).toList();

                final visibleIncidents =
                    (_activeFilter == 'all' || _activeFilter == 'incident')
                    ? incidents
                    : <IncidentReport>[];

                int countFor(String key) {
                  switch (key) {
                    case 'all':
                      return _places.length + incidents.length;
                    case 'incident':
                      return incidents.length;
                    default:
                      return _places.where((m) => m.type == key).length;
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
                            ...visiblePlaces.map(
                              (marker) => Marker(
                                point: LatLng(marker.lat, marker.lng),
                                width: 40,
                                height: 40,
                                child: GestureDetector(
                                  onTap: () => _showPlaceDetail(marker),
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
                      bottom: 96,
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
                      child: _buildStatusCard(),
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
