import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/mission.dart';
import '../models/aircraft.dart';
import '../models/alert_model.dart';
import '../database/database_helper.dart';
import '../services/sync_service.dart';

class AppProvider extends ChangeNotifier {
  List<Mission> _missions = [];
  List<Aircraft> _aircraft = [];
  List<AlertModel> _alerts = [];
  Map<String, dynamic> _stats = {};

  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isOnline = false;
  int _unsyncedCount = 0;

  StreamSubscription? _connectivitySub;

  List<Mission> get missions => _missions;
  List<Aircraft> get aircraft => _aircraft;
  List<AlertModel> get alerts => _alerts;
  Map<String, dynamic> get stats => _stats;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  int get unsyncedCount => _unsyncedCount;
  bool get hasUnsyncedData => _unsyncedCount > 0;

  List<Mission> get upcomingMissions => _missions
      .where((m) => m.status == 'approved' || m.status == 'in_progress')
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  List<Mission> get completedMissions =>
      _missions.where((m) => m.isCompleted).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  int get unreadAlertCount => _alerts.where((a) => !a.isRead).length;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _isOnline = await SyncService.isConnected();
    _connectivitySub =
        SyncService.connectivityStream.listen((results) async {
      final wasOnline = _isOnline;
      _isOnline = results.any((r) =>
          r == ConnectivityResult.wifi || r == ConnectivityResult.mobile);
      if (!wasOnline && _isOnline && _unsyncedCount > 0) {
        await syncData();
      }
      notifyListeners();
    });

    await _loadAll();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadAll() async {
    final db = DatabaseHelper.instance;
    _missions = await db.getMissions();
    _aircraft = await db.getAircraft();
    _alerts = await db.getAlerts();
    _stats = await db.getStats();
    _unsyncedCount = await db.getUnsyncedCount();
  }

  Future<void> refresh() async {
    await _loadAll();
    notifyListeners();
  }

  Future<void> refreshAircraft() async {
    _aircraft = await DatabaseHelper.instance.getAircraft();
    _stats = await DatabaseHelper.instance.getStats();
    notifyListeners();
  }

  Future<void> refreshMissions() async {
    _missions = await DatabaseHelper.instance.getMissions();
    _stats = await DatabaseHelper.instance.getStats();
    _unsyncedCount = await DatabaseHelper.instance.getUnsyncedCount();
    notifyListeners();
  }

  Future<void> refreshAlerts() async {
    _alerts = await DatabaseHelper.instance.getAlerts();
    _unsyncedCount = await DatabaseHelper.instance.getUnsyncedCount();
    notifyListeners();
  }

  Future<void> markAlertRead(int id) async {
    await DatabaseHelper.instance.markAlertRead(id);
    await refreshAlerts();
  }

  Future<void> updateMission(Mission mission) async {
    await DatabaseHelper.instance.updateMission(mission);
    await refreshMissions();
  }

  Future<void> syncData() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    final success = await SyncService.syncToCloud();
    if (success) {
      _unsyncedCount = 0;
      await _loadAll();
    }

    _isSyncing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
