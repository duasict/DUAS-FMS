import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../screens/more/notification_preferences_screen.dart';

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
    if (!await NotifPrefs.get(NotifPrefs.kConcurrence)) return;
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
    if (!await NotifPrefs.get(NotifPrefs.kConcurrence)) return;
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
    if (!await NotifPrefs.get(NotifPrefs.kLicense)) return;
    await _show(
      id: name.hashCode,
      title: 'License Expiring Soon',
      body:
          '$name — your CAAP license expires in $daysLeft days. Re-verify to keep PIC status.',
      channelId: 'license',
      channelName: 'License Alerts',
    );
  }

  static Future<void> showMissionAssigned(
      String missionRef, String missionTitle, String role) async {
    if (!await NotifPrefs.get(NotifPrefs.kMissionAssigned)) return;
    await _show(
      id: '$missionRef-assign'.hashCode,
      title: 'Mission Assignment — $missionRef',
      body: 'You are assigned to "$missionTitle" as ${_roleLabelFor(role)}.',
      channelId: 'mission',
      channelName: 'Mission Assignments',
    );
  }

  static String _roleLabelFor(String role) {
    switch (role) {
      case 'rpic': return 'RPIC (Remote Pilot in Command)';
      case 'pic':  return 'Pilot in Command';
      case 'vo':   return 'Visual Observer';
      case 'gcs':  return 'GCS Operator';
      case 'tech': return 'Technical Crew Member';
      case 'crp':  return 'Chief Remote Pilot';
      default:     return role.toUpperCase();
    }
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
