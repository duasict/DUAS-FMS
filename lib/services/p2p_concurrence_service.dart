import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import '../database/database_helper.dart';
import 'notification_service.dart';

class P2pConcurrenceService {
  static HttpServer? _server;
  static int _missionId = -1;
  static String _missionRef = '';
  static String _missionTitle = '';

  /// Start the local HTTP server for a given mission.
  /// Returns the device IP address so it can be shown as a URL, or null on failure.
  static Future<String?> startServer({
    required int missionId,
    required String missionRef,
    required String missionTitle,
  }) async {
    _missionId = missionId;
    _missionRef = missionRef;
    _missionTitle = missionTitle;

    final router = Router()
      ..get('/', _handleRoot)
      ..get('/missions', _handleGetMissions)
      ..get('/concurrence', _handleGet)
      ..post('/concurrence/approve', _handleApprove)
      ..post('/concurrence/reject', _handleReject);

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);

    try {
      _server = await io.serve(handler, InternetAddress.anyIPv4, 7788);
      // Return device IP so it can be displayed as a QR/URL
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLinkLocal: false);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
      return '0.0.0.0';
    } catch (_) {
      return null;
    }
  }

  static Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
  }

  static bool get isRunning => _server != null;

  static Response _handleRoot(Request req) {
    return Response.ok(
      _html('DUAS FMS P2P',
          '<p>Routes:<br>'
          '&bull; <a href="/missions">GET /missions</a> — JSON list of all missions<br>'
          '&bull; <a href="/concurrence">GET /concurrence</a> — review active mission</p>'),
      headers: {'content-type': 'text/html'},
    );
  }

  /// Returns a JSON array of all missions visible to the current user.
  /// Intended for CRP-side tooling / offline sync over the LAN.
  static Future<Response> _handleGetMissions(Request req) async {
    try {
      final db      = DatabaseHelper.instance;
      final profile = await db.getUserProfile();
      final missions = await db.getMissionsForUser(
        profile?.name ?? '',
        profile?.role == 'crp',
        userId: profile?.supabaseId ?? '',
      );
      final payload = missions.map((m) => {
        'id':                      m.id,
        'mission_id':              m.missionId,
        'title':                   m.title,
        'status':                  m.status,
        'date':                    m.date,
        'time':                    m.timeStr,
        'location':                m.location,
        'environment':             m.environment,
        'aircraft':                m.aircraftName,
        'aircraft_type':           m.aircraftType,
        'duration_min':            m.duration,
        'crp_concurrence_required': m.crpConcurrenceRequired,
        'crp_concurrence_status':  m.crpConcurrenceStatus,
        'crew': m.crew.map((c) => {'name': c.name, 'role': c.role}).toList(),
      }).toList();
      return Response.ok(
        jsonEncode(payload),
        headers: {
          'content-type': 'application/json',
          'access-control-allow-origin': '*',
        },
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': '$e'}),
          headers: {'content-type': 'application/json'});
    }
  }

  static Future<Response> _handleGet(Request req) async {
    final mission = await DatabaseHelper.instance.getMissionById(_missionId);
    if (mission == null) return Response.notFound('Mission not found');
    final hira =
        await DatabaseHelper.instance.getHiraRowsByMissionId(_missionId);
    final hiraHtml = hira
        .map((r) =>
            '<tr><td>${r.hazard}</td><td>${r.likelihood}</td><td>${r.impact}</td>'
            '<td>${r.likelihood * r.impact}</td><td>${r.mitigation}</td></tr>')
        .join();
    final body = '''
      <h2>$_missionRef — ${mission.title}</h2>
      <p><b>Location:</b> ${mission.location} | <b>Date:</b> ${mission.date} ${mission.timeStr}</p>
      <h3>HIRA Summary</h3>
      <table border="1" cellpadding="4">
        <tr><th>Hazard</th><th>L</th><th>I</th><th>Risk</th><th>Mitigation</th></tr>
        $hiraHtml
      </table>
      <br/>
      <form method="post" action="/concurrence/approve" style="display:inline">
        <button style="background:#4CAF50;color:white;padding:12px 32px;font-size:16px">&#x2714; APPROVE</button>
      </form>
      &nbsp;&nbsp;
      <form method="post" action="/concurrence/reject" style="display:inline">
        <button style="background:#f44336;color:white;padding:12px 32px;font-size:16px">&#x2716; REJECT</button>
      </form>
    ''';
    return Response.ok(_html('Concurrence Review', body),
        headers: {'content-type': 'text/html'});
  }

  static Future<Response> _handleApprove(Request req) async {
    await _writeConcurrence('approved');
    return Response.ok(
      _html('Approved',
          '<h2 style="color:green">&#x2714; Mission APPROVED</h2><p>You may close this page.</p>'),
      headers: {'content-type': 'text/html'},
    );
  }

  static Future<Response> _handleReject(Request req) async {
    await _writeConcurrence('rejected');
    return Response.ok(
      _html('Rejected',
          '<h2 style="color:red">&#x2716; Mission REJECTED</h2><p>You may close this page.</p>'),
      headers: {'content-type': 'text/html'},
    );
  }

  static Future<void> _writeConcurrence(String status) async {
    final db = await DatabaseHelper.instance.database;

    // Persist the decision on the mission record so the banner updates
    await db.update(
      'missions',
      {'crp_concurrence_status': status},
      where: 'id = ?',
      whereArgs: [_missionId],
    );

    // Insert alert so the crew is notified
    await db.insert('alerts', {
      'type': 'concurrence',
      'title': 'CRP Concurrence — ${status.toUpperCase()}',
      'message': 'Mission $_missionRef has been $status by CRP via P2P.',
      'status': status,
      'mission_id': _missionId,
      'mission_title': _missionTitle,
      'is_read': 0,
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    });
    await NotificationService.showConcurrenceResult(_missionRef, status);
  }

  static String _html(String title, String body) => '''
<!DOCTYPE html><html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>$title</title>
<style>body{font-family:sans-serif;padding:20px;max-width:600px;margin:auto}</style>
</head><body><h1>DUAS FMS</h1>$body</body></html>''';
}
