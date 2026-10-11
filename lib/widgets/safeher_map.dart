// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../theme/app_colors.dart';

/// Map tiles from OpenStreetMap, in their normal colors.
class SafeHerTileLayer extends StatelessWidget {
  const SafeHerTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.safeher.women_safety',
      maxZoom: 19,
    );
  }
}

/// The credit OpenStreetMap requires.
class SafeHerAttribution extends StatelessWidget {
  const SafeHerAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return RichAttributionWidget(
      alignment: AttributionAlignment.bottomLeft,
      showFlutterMapAttribution: false,
      attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
    );
  }
}

/// A glowing "you are here" dot.
class MyLocationDot extends StatelessWidget {
  const MyLocationDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.22),
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
          ),
        ),
      ],
    );
  }
}

/// A round pin with an icon, used for police, hospitals, reports and so on.
class MapPinBadge extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double size;

  const MapPinBadge({
    super.key,
    required this.color,
    required this.icon,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

/// The destination marker (its tip sits on the point).
class DestinationPin extends StatelessWidget {
  const DestinationPin({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.location_on,
      size: 48,
      color: AppColors.dangerLight,
      shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
    );
  }
}
