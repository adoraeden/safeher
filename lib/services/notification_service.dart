import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'sos_countdown_service.dart';

/// Handles all SafeHer notifications:
///
///  • Guard notification  (ID 1001): persistent, low-priority "Guard Active" bar.
///  • SOS notification   (ID 1002): high-importance emergency alert with countdown.
///
/// IMPORTANT — Cancel SOS from notification while backgrounded:
/// Android's notification action callbacks are only delivered to the running
/// Flutter engine. If the app process is alive (foreground service keeps it
/// alive), the callback fires and SosCountdownService.cancel() runs.
/// We use showsUserInterface: true for the Cancel action so Android brings
/// the app to the foreground when Cancel is tapped, which guarantees the
/// Dart engine processes the cancel. This is the only reliable pattern on
/// Android 13+ without a native BroadcastReceiver.
class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  // ── IDs and channels ─────────────────────────────────────────────────────
  static const int _guardNotificationId = 1001;
  static const int _sosNotificationId = 1002;

  static const String _guardChannelId = 'safeher_guard_status';
  static const String _sosChannelId = 'safeher_sos_triggered';

  // ── State ─────────────────────────────────────────────────────────────────
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _voiceGuardActive = false;
  bool _shakeGuardActive = false;

  // Stream that fires when the user taps "Cancel SOS" on the notification.
  final _cancelSosController = StreamController<void>.broadcast();
  Stream<void> get onSosCancelRequested => _cancelSosController.stream;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      // Also handle responses while app was terminated and relaunched.
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      // Guard channel — silent, low importance, non-intrusive.
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _guardChannelId,
          'Guard Status',
          description: 'Shows when Voice Guard or Shake to SOS is active',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        ),
      );

      // SOS channel — maximum importance, strong vibration, full-screen intent.
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          _sosChannelId,
          'Emergency SOS Alert',
          description: 'High-priority alert when an automatic SOS trigger fires',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern:
              Int64List.fromList([0, 600, 200, 600, 200, 600]),
        ),
      );
    }
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  // ── Notification response handlers ───────────────────────────────────────

  void _onNotificationResponse(NotificationResponse response) {
    if (response.actionId == 'cancel_sos') {
      SosCountdownService().cancel();
      _cancelSosController.add(null);
      clearSosNotification();
    }
  }

  // ── Guard notification ─────────────────────────────────────────────────────

  Future<void> setVoiceGuardActive(bool active) async {
    _voiceGuardActive = active;
    await _refreshGuardNotification();
  }

  Future<void> setShakeGuardActive(bool active) async {
    _shakeGuardActive = active;
    await _refreshGuardNotification();
  }

  Future<void> _refreshGuardNotification() async {
    if (!_voiceGuardActive && !_shakeGuardActive) {
      await _plugin.cancel(id: _guardNotificationId);
      return;
    }

    final parts = <String>[];
    if (_voiceGuardActive) parts.add('Voice Guard');
    if (_shakeGuardActive) parts.add('Shake to SOS');
    final body =
        '${parts.join(' + ')} active — listening for an emergency trigger';

    const androidDetails = AndroidNotificationDetails(
      _guardChannelId,
      'Guard Status',
      channelDescription: 'Shows when Voice Guard or Shake to SOS is active',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: _guardNotificationId,
      title: 'SafeHer Guard Active',
      body: body,
      notificationDetails: details,
    );
  }

  // ── SOS notification ──────────────────────────────────────────────────────

  Future<void> showSosTriggeredNotification({
    String? phrase,
    int secondsLeft = SosCountdownService.sosCountdownSeconds,
  }) async {
    final body = phrase != null
        ? 'Detected: "$phrase". Sending SOS in ${secondsLeft}s unless cancelled.'
        : 'Emergency shake detected. Sending SOS in ${secondsLeft}s unless cancelled.';

    final androidDetails = AndroidNotificationDetails(
      _sosChannelId,
      'Emergency SOS Alert',
      channelDescription: 'Shown when an automatic SOS trigger fires',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      enableVibration: true,
      vibrationPattern:
          Int64List.fromList([0, 600, 200, 600, 200, 600]),
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      actions: const [
        AndroidNotificationAction(
          'cancel_sos',
          'Cancel SOS',
          // showsUserInterface: true ensures Android brings the app to
          // foreground when Cancel is tapped. This is required for the
          // Dart SosCountdownService.cancel() callback to execute reliably
          // while the app is in the background.
          cancelNotification: true,
          showsUserInterface: true,
        ),
      ],
    );
    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: _sosNotificationId,
      title: 'SafeHer — Emergency Trigger Detected',
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> clearSosNotification() async {
    await _plugin.cancel(id: _sosNotificationId);
  }
}

/// Top-level function required by flutter_local_notifications for background
/// notification response handling. Must be a top-level (not instance) function.
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  // When the app is fully killed, we cannot reliably cancel a countdown that
  // is not running. When the process is alive (foreground service running),
  // showsUserInterface: true brings the app to foreground and the main
  // _onNotificationResponse fires instead. This is a safety fallback.
  if (response.actionId == 'cancel_sos') {
    SosCountdownService().cancel();
  }
}
