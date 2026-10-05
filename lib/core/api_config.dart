import 'package:flutter/foundation.dart';

import 'dart:io' show Platform;

class ApiConfig {
  ApiConfig._();

  // Your PC's IPv4 from `ipconfig` — update this if your LAN IP changes.
  // Run `ipconfig` on Windows and look for "IPv4 Address" under your WiFi adapter.
  static const String lanIp = '192.168.1.202';
  static const int port = 5000;

  static String get baseUrl {
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
}
