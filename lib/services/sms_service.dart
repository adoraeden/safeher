import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Sends SMS messages straight from the app (no SMS app screen).
class SmsService {
  static const MethodChannel _channel = MethodChannel(
    'com.safeher.women_safety/sms',
  );

  static String cleanPhone(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9+]'), '');

  /// True if SMS permission is already allowed. Never shows a popup.
  Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } catch (e) {
      debugPrint('[SmsService] hasPermission failed: $e');
      return false;
    }
  }

  /// Shows the Android permission popup if needed. Only call this while the
  /// app is on screen.
  Future<bool> ensurePermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (e) {
      debugPrint('[SmsService] requestPermission failed: $e');
      return false;
    }
  }

  /// True means the phone accepted the message for sending. It does not
  /// guarantee delivery.
  Future<bool> send(String phone, String message) async {
    final clean = cleanPhone(phone);
    if (clean.isEmpty) return false;
    try {
      final ok = await _channel
          .invokeMethod<bool>('send', {'phone': clean, 'message': message})
          .timeout(const Duration(seconds: 10), onTimeout: () => false);
      return ok ?? false;
    } catch (e) {
      debugPrint('[SmsService] send failed: $e');
      return false;
    }
  }
}
