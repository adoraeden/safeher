import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class ApiConfig {
  ApiConfig._();

  // Your PC's IPv4 from `ipconfig`
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

