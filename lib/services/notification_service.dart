import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  static Future<void> showConcurrenceRequest(
      String missionRef, String missionTitle) async {
    await _show(
      id: missionRef.hashCode,
      title: 'CRP Concurrence Required',
      body: '$missionRef — $missionTitle requires your approval before operations.',
      channelId: 'concurrence',
      channelName: 'Concurrence Requests',
    );
  }

  static Future<void> showConcurrenceResult(
      String missionRef, String status) async {
    await _show(
      id: missionRef.hashCode + 1,
      title: 'Concurrence ${status == 'approved' ? 'Approved ✔' : 'Rejected ✖'}',
      body: 'Mission $missionRef has been $status.',
      channelId: 'concurrence',
      channelName: 'Concurrence Requests',
    );
  }

  static Future<void> showLicenseExpiry(
      String name, int daysLeft) async {
    await _show(
      id: name.hashCode,
      title: 'License Expiring Soon',
      body:
          '$name — your CAAP license expires in $daysLeft days. Re-verify to keep PIC status.',
      channelId: 'license',
      channelName: 'License Alerts',
    );
  }

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> cancelAll() => _plugin.cancelAll();
}
