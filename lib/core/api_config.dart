import 'package:flutter/foundation.dart';

import 'dart:io' show Platform;

class ApiConfig {
  ApiConfig._();

  // If you deploy the backend to a cloud hosting service (e.g., Render, Railway),
  // set productionUrl here (e.g. 'https://safeher-api.onrender.com').
  // When set, this HTTPS URL is prioritized so the app works without the laptop running.
  static const String productionUrl =
      'https://safeher-backend-okan.onrender.com';

  // Your PC's IPv4 from `ipconfig` — update this if your LAN IP changes.
  // Run `ipconfig` on Windows and look for "IPv4 Address" under your WiFi adapter.
  static const String lanIp = '192.168.1.202';
  static const int port = 5000;

  static String get baseUrl {
    if (productionUrl.trim().isNotEmpty) {
      return productionUrl.trim();
    }
    if (kIsWeb) {
      return 'http://localhost:$port';
    }
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        return 'http://127.0.0.1:$port';
      }
      // Android: use LAN IP so the app works over WiFi without adb reverse.
      // Make sure your phone and PC are on the same WiFi network.
      if (Platform.isAndroid) {
        return 'http://$lanIp:$port';
      }
      if (Platform.isIOS) {
        return 'http://$lanIp:$port';
      }
    } catch (_) {
      // Fallback if Platform is not available
    }
    return 'http://$lanIp:$port';
  }

  /// Alternative candidate URLs to try if the primary network URL fails
  /// (e.g., adb reverse over USB or Android emulator loopback).
  static List<String> get candidateBaseUrls {
    if (productionUrl.trim().isNotEmpty) {
      return [productionUrl.trim()];
    }
    final primary = baseUrl;
    final candidates = <String>[];

    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          // If adb reverse is active, 127.0.0.1 works instantly over USB cable
          candidates.add('http://127.0.0.1:$port');
          if (!candidates.contains(primary)) {
            candidates.add(primary);
          }
          if (!candidates.contains('http://10.0.2.2:$port')) {
            candidates.add('http://10.0.2.2:$port');
          }
          return candidates;
        }
      } catch (_) {}
    }

    if (!candidates.contains(primary)) {
      candidates.add(primary);
    }
    return candidates;
  }
}
