import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../models/incident_report.dart';
import '../../services/incident_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../map/safety_map_screen.dart';

class ReportIncidentScreen extends StatefulWidget {
  final IncidentService? incidentService;
  final LatLng? initialLocation;

  const ReportIncidentScreen({
    super.key,
    this.incidentService,
    this.initialLocation,
  });

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _notesController = TextEditingController();
  late final IncidentService _incidentService;
  final _mapController = MapController();

  // Category & Hazard Type
  String _selectedCategory = 'personal_safety';
  String _selectedType = 'harassment';

  // Structured Options
  String _selectedSeverity = 'medium';
  bool _isActive = true;
  DateTime _occurredAt = DateTime.now();
  bool _isHappenedNow = true;

  // Location handling
  bool _includeLocation = true;
  LatLng? _selectedLocation;
  bool _isLoadingGps = false;
  String? _locationStatus;

  // Screen submission state
  bool _isSubmitting = false;
  String? _errorMessage;
  IncidentReport? _submittedReport;

  // Category definitions with specific hazard types
  static const List<Map<String, dynamic>> _categories = [
    {
      'key': 'personal_safety',
      'label': 'Personal Safety',
      'icon': Icons.shield_outlined,
      'types': [
        {'key': 'harassment', 'label': 'Harassment / Catcalling'},
        {'key': 'stalking', 'label': 'Stalking / Following'},
        {'key': 'assault', 'label': 'Physical Threat / Assault'},
        {'key': 'verbal_abuse', 'label': 'Verbal Abuse / Intimidation'},
      ],
    },
    {
      'key': 'infrastructure',
      'label': 'Environment & Lighting',
      'icon': Icons.lightbulb_outline,
      'types': [
        {'key': 'poor_lighting', 'label': 'Poor / Broken Streetlights'},
        {'key': 'isolated_path', 'label': 'Deserted / Isolated Pathway'},
        {'key': 'unsafe_structure', 'label': 'Damaged / Dangerous Walkway'},
        {'key': 'deserted_transit', 'label': 'Unsafe / Empty Transit Stop'},
      ],
    },
    {
      'key': 'suspicious_activity',
      'label': 'Suspicious Activity',
      'icon': Icons.visibility_outlined,
      'types': [
        {'key': 'suspicious_person', 'label': 'Suspicious Person / Loitering'},
        {'key': 'suspicious_vehicle', 'label': 'Suspicious Vehicle'},
        {'key': 'unattended_item', 'label': 'Unattended Suspicious Bag/Item'},
      ],
    },
    {
      'key': 'commute_hazard',
      'label': 'Transit & Commute',
      'icon': Icons.directions_bus_outlined,
      'types': [
        {'key': 'unsafe_cab', 'label': 'Unsafe Taxi / Cab Driver'},
        {'key': 'hostile_crowd', 'label': 'Hostile Crowd / Dispute'},
        {'key': 'blocked_route', 'label': 'Blocked Route / Trap'},
      ],
    },
    {
      'key': 'other',
      'label': 'Other Hazards',
      'icon': Icons.warning_amber_outlined,
      'types': [
        {'key': 'general_hazard', 'label': 'General Safety Concern'},
        {'key': 'disturbance', 'label': 'Public Disturbance'},
        {'key': 'other', 'label': 'Other Issue'},
      ],
    },
  ];

  static const List<Map<String, dynamic>> _severities = [
    {
      'key': 'low',
      'label': 'Low',
      'sub': 'Caution advised',
      'color': AppColors.success,
      'icon': Icons.info_outline,
    },
    {
      'key': 'medium',
      'label': 'Medium',
      'sub': 'Moderate risk',
      'color': AppColors.warning,
      'icon': Icons.warning_amber_outlined,
    },
    {
      'key': 'high',
      'label': 'High',
      'sub': 'Dangerous',
      'color': AppColors.dangerLight,
      'icon': Icons.error_outline,
    },
    {
      'key': 'critical',
      'label': 'Critical',
      'sub': 'Immediate threat',
      'color': AppColors.danger,
      'icon': Icons.dangerous_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _incidentService = widget.incidentService ?? IncidentService();
    _selectedLocation =
        widget.initialLocation ?? const LatLng(12.9716, 77.5946);
    _fetchInitialLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialLocation() async {
    setState(() {
      _isLoadingGps = true;
      _locationStatus = 'Detecting current GPS location...';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = 'Location services disabled. Tap map to place pin.';
          _selectedLocation ??= const LatLng(12.9716, 77.5946);
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        if (mounted) {
          final latLng = LatLng(position.latitude, position.longitude);
          setState(() {
            _selectedLocation = latLng;
            _locationStatus = 'GPS location acquired (tap map to adjust).';
          });
          try {
            _mapController.move(latLng, 15.0);
          } catch (_) {}
        }
      } else {
        if (mounted) {
          setState(() {
            _locationStatus =
                'Location permission denied. Tap map to select location.';
            _selectedLocation ??= const LatLng(12.9716, 77.5946);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationStatus = 'Could not get GPS. Tap map to place pin.';
          _selectedLocation ??= const LatLng(12.9716, 77.5946);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingGps = false);
      }
    }
  }

  Future<void> _selectCustomDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_occurredAt),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.primary,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null && mounted) {
        final combined = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        setState(() {
          _occurredAt = combined;
          _isHappenedNow = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[dt.month - 1];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$month ${dt.day}, ${dt.year} at $hour:$minute $period';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_includeLocation && _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap the map to place the hazard location pin.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final lat = _includeLocation ? _selectedLocation?.latitude : null;
    final lng = _includeLocation ? _selectedLocation?.longitude : null;
    final description = _descriptionController.text.trim();
    final locationName = _locationNameController.text.trim();
    final notes = _notesController.text.trim();
    final occurred = _isHappenedNow ? DateTime.now() : _occurredAt;

    try {
      await _incidentService.submitReport(
        category: _selectedCategory,
        type: _selectedType,
        description: description,
        severity: _selectedSeverity,
        isActive: _isActive,
        occurredAt: occurred,
        lat: lat,
        lng: lng,
        locationName: locationName.isEmpty ? null : locationName,
        additionalNotes: notes.isEmpty ? null : notes,
      );

      final completedReport = IncidentReport(
        id: 'new',
        category: _selectedCategory,
        type: _selectedType,
        description: description,
        severity: _selectedSeverity,
        isActive: _isActive,
        occurredAt: occurred,
        lat: lat,
        lng: lng,
        locationName: locationName.isEmpty ? null : locationName,
        additionalNotes: notes.isEmpty ? null : notes,
        timestamp: DateTime.now(),
        reporterId: '',
      );

      if (mounted) {
        setState(() {
          _submittedReport = completedReport;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  List<Map<String, String>> _availableTypesForCategory() {
    final cat = _categories.firstWhere(
      (c) => c['key'] == _selectedCategory,
      orElse: () => _categories.first,
    );
    return (cat['types'] as List).cast<Map<String, String>>();
  }

  @override
  Widget build(BuildContext context) {
    if (_submittedReport != null) {
      return _buildSuccessView();
    }

    final types = _availableTypesForCategory();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Hazard'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: AppColors.primaryLight,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Community Hazard Alert',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Reports alert nearby women and update the community safety map. Your personal identity is never made public.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                _buildErrorCard(),
              ],

              const SizedBox(height: AppSpacing.xl),

              // 1. Hazard Category
              _buildSectionHeader(
                title: 'Hazard Category',
                subtitle: 'Choose the general category of the danger',
                icon: Icons.category_outlined,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat['key'];
                  final icon = cat['icon'] as IconData;
                  final label = cat['label'] as String;
                  return ChoiceChip(
                    avatar: Icon(
                      icon,
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                    label: Text(label),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primaryLight
                          : AppColors.border,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = cat['key'] as String;
                          final newTypes = _availableTypesForCategory();
                          _selectedType = newTypes.first['key']!;
                        });
                      }
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: AppSpacing.lg),

              // 2. Specific Hazard Type
              _buildSectionHeader(
                title: 'Specific Hazard Type',
                subtitle: 'Select the exact issue observed',
                icon: Icons.label_outline,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: types.map((t) {
                  final isSelected = _selectedType == t['key'];
                  return ChoiceChip(
                    label: Text(t['label']!),
                    selected: isSelected,
                    selectedColor: AppColors.primaryLight.withValues(alpha: 0.25),
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primaryLight
                          : AppColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedType = t['key']!);
                      }
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: AppSpacing.xl),

              // 3. Severity Level
              _buildSectionHeader(
                title: 'Severity Level',
                subtitle: 'How urgent or dangerous is this hazard?',
                icon: Icons.speed_outlined,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: _severities.map((s) {
                  final isSelected = _selectedSeverity == s['key'];
                  final color = s['color'] as Color;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        onTap: () => setState(() => _selectedSeverity = s['key']),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                            horizontal: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.2)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: isSelected ? color : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                s['icon'] as IconData,
                                size: 20,
                                color: color,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s['label'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s['sub'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isSelected
                                      ? Colors.white70
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppSpacing.xl),

              // 4. Hazard Location (Select & Confirm on Map)
              _buildSectionHeader(
                title: 'Hazard Location',
                subtitle: 'Pinpoint and confirm where the hazard occurred',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: AppSpacing.sm),
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      title: const Text(
                        'Include hazard location',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: const Text(
                        'Allows nearby women to be alerted and shows on map',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      value: _includeLocation,
                      onChanged: (v) => setState(() => _includeLocation = v),
                    ),
                    if (_includeLocation) ...[
                      const Divider(height: 1, color: AppColors.border),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _locationStatus ?? 'Tap map to place pin',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _isLoadingGps
                                      ? null
                                      : _fetchInitialLocation,
                                  icon: _isLoadingGps
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : const Icon(Icons.my_location, size: 14),
                                  label: const Text(
                                    'GPS',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            // Map widget
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              child: Container(
                                height: 210,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.borderStrong,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    FlutterMap(
                                      mapController: _mapController,
                                      options: MapOptions(
                                        initialCenter: _selectedLocation ??
                                            const LatLng(12.9716, 77.5946),
                                        initialZoom: 15.0,
                                        onTap: (tapPosition, point) {
                                          setState(() {
                                            _selectedLocation = point;
                                            _locationStatus =
                                                'Pin placed at: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
                                          });
                                        },
                                      ),
                                      children: [
                                        TileLayer(
                                          urlTemplate:
                                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                          userAgentPackageName:
                                              'com.safeher.women_safety',
                                        ),
                                        if (_selectedLocation != null)
                                          MarkerLayer(
                                            markers: [
                                              Marker(
                                                point: _selectedLocation!,
                                                width: 50,
                                                height: 50,
                                                child: Column(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.danger,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: Colors.white,
                                                          width: 2,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: AppColors
                                                                .danger
                                                                .withValues(
                                                                    alpha: 0.5),
                                                            blurRadius: 8,
                                                            spreadRadius: 2,
                                                          ),
                                                        ],
                                                      ),
                                                      child: const Icon(
                                                        Icons.warning_rounded,
                                                        color: Colors.white,
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    Positioned(
                                      bottom: 8,
                                      left: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.background
                                              .withValues(alpha: 0.85),
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.sm),
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.touch_app_outlined,
                                              size: 14,
                                              color: AppColors.primaryLight,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _selectedLocation != null
                                                    ? 'Lat: ${_selectedLocation!.latitude.toStringAsFixed(4)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(4)} (Tap map to move)'
                                                    : 'Tap anywhere on map to position hazard pin',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextFormField(
                              controller: _locationNameController,
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.place_outlined, size: 18),
                                hintText:
                                    'Landmark / Specific area (e.g. Near Metro Gate 3)',
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

              const SizedBox(height: AppSpacing.xl),

              // 5. Written Description
              _buildSectionHeader(
                title: 'Written Description',
                subtitle: 'Describe the hazard clearly for others',
                icon: Icons.description_outlined,
                isRequired: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                style: const TextStyle(fontSize: 13, height: 1.4),
                decoration: const InputDecoration(
                  hintText:
                      'Provide factual details: What is happening? Who or what poses a danger? Why is this spot unsafe?',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please describe the hazard.';
                  }
                  if (v.trim().length < 10) {
                    return 'Please provide more detail (at least 10 characters).';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppSpacing.xl),

              // 6. Date & Time of Occurrence
              _buildSectionHeader(
                title: 'When did this happen?',
                subtitle: 'Record accurate timing for community analysis',
                icon: Icons.schedule_outlined,
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() {
                              _isHappenedNow = true;
                              _occurredAt = DateTime.now();
                            }),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                                horizontal: AppSpacing.md,
                              ),
                              decoration: BoxDecoration(
                                color: _isHappenedNow
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : AppColors.background,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                  color: _isHappenedNow
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.bolt,
                                    size: 16,
                                    color: _isHappenedNow
                                        ? AppColors.primaryLight
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Happened Just Now',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _isHappenedNow
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: _isHappenedNow
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: InkWell(
                            onTap: _selectCustomDateTime,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                                horizontal: AppSpacing.md,
                              ),
                              decoration: BoxDecoration(
                                color: !_isHappenedNow
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : AppColors.background,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                  color: !_isHappenedNow
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.edit_calendar_outlined,
                                    size: 16,
                                    color: !_isHappenedNow
                                        ? AppColors.primaryLight
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Earlier Time',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: !_isHappenedNow
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: !_isHappenedNow
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Recorded time: ${_formatDateTime(_isHappenedNow ? DateTime.now() : _occurredAt)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // 7. Active Status
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Hazard is currently active',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: const Text(
                      'Turn off if the threat has passed or resolved',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // 8. Additional Notes
              _buildSectionHeader(
                title: 'Additional Notes & Advice',
                subtitle: 'Helpful tips for avoiding the danger (optional)',
                icon: Icons.notes_outlined,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                style: const TextStyle(fontSize: 13, height: 1.4),
                decoration: const InputDecoration(
                  hintText:
                      'e.g. Use the main avenue instead; brightly lit pharmacy open nearby...',
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Photo/Evidence note (explaining architectural constraint gracefully)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.photo_camera_outlined,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Photo evidence upload is disabled in local mode. Please describe physical or visual identifiers in the notes above.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: _isSubmitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Submitting Report...',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.send_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Submit Hazard Report',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primaryLight),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: AppColors.dangerLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.dangerLight, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Submission Failed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dangerLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _errorMessage = null),
            icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    final report = _submittedReport!;
    final categoryItem = _categories.firstWhere(
      (c) => c['key'] == report.category,
      orElse: () => _categories.first,
    );
    final types = (categoryItem['types'] as List).cast<Map<String, String>>();
    final typeItem = types.firstWhere(
      (t) => t['key'] == report.type,
      orElse: () => {'label': report.type},
    );

    final severityItem = _severities.firstWhere(
      (s) => s['key'] == report.severity,
      orElse: () => _severities[1],
    );
    final severityColor = severityItem['color'] as Color;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Submitted'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 64,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Thank You for Reporting',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Your report has been logged and published to help keep community members informed and safe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'REPORT SUMMARY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Divider(height: 20, color: AppColors.border),
                  _summaryRow(
                    label: 'Category',
                    value: categoryItem['label'] as String,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _summaryRow(
                    label: 'Hazard Type',
                    value: typeItem['label'] ?? report.type,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Severity',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: severityColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: severityColor),
                        ),
                        child: Text(
                          severityItem['label'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: severityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _summaryRow(
                    label: 'Status',
                    value: report.isActive ? 'Currently Active' : 'Resolved / Past',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _summaryRow(
                    label: 'Time',
                    value: _formatDateTime(report.occurredAt ?? report.timestamp),
                  ),
                  if (report.lat != null && report.lng != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _summaryRow(
                      label: 'Location',
                      value:
                          '${report.lat!.toStringAsFixed(4)}, ${report.lng!.toStringAsFixed(4)}',
                    ),
                  ],
                  if (report.locationName != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _summaryRow(
                      label: 'Landmark',
                      value: report.locationName!,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  _summaryRow(
                    label: 'Description',
                    value: report.description,
                  ),
                  if (report.additionalNotes != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _summaryRow(
                      label: 'Notes',
                      value: report.additionalNotes!,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Navigation Buttons
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SafetyMapScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('View on Safety Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.borderStrong),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: const Text(
                  'Back to Dashboard',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
