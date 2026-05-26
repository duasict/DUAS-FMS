import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/mission.dart';
import '../models/aircraft.dart';
import '../models/alert_model.dart';
import '../database/database_helper.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
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

  // ── Pagination ──────────────────────────────────────────────────────────────
  static const _pageSize = 20;
  bool _hasMoreMissions = false;
  bool get hasMoreMissions => _hasMoreMissions;
  // Guard flag: prevents the scroll listener from firing concurrent DB reads
  // that would compute the same OFFSET and append duplicate mission rows.
  bool _isLoadingMore = false;

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
      .where((m) => m.status == 'planning' || m.status == 'in_progress')
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  List<Mission> get completedMissions =>
      _missions.where((m) => m.isCompleted).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  int get unreadAlertCount => _alerts.where((a) => !a.isRead).length;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
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
    } catch (e, st) {
      debugPrint('[AppProvider] initialize error: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAll() async {
    final db      = DatabaseHelper.instance;
    final profile = await db.getUserProfile();
    // Load first page; subsequent pages via loadMoreMissions()
    final firstPage = await db.getMissionsForUserPaged(
      profile?.name ?? '',
      profile?.role == 'crp',
      userId: profile?.supabaseId ?? '',
      limit: _pageSize,
      offset: 0,
    );
    _missions         = firstPage;
    _hasMoreMissions  = firstPage.length >= _pageSize;
    _aircraft         = await db.getAircraft();
    _alerts           = await db.getAlerts();
    _stats            = await db.getStats();
    _unsyncedCount    = await db.getUnsyncedCount();
  }

  Future<void> refresh() async {
    await _loadAll();
    notifyListeners();
  }

  Future<void> refreshAircraft() async {
    _aircraft = await DatabaseHelper.instance.getAircraft();
    _stats    = await DatabaseHelper.instance.getStats();
    notifyListeners();
  }

  Future<void> refreshMissions() async {
    final db      = DatabaseHelper.instance;
    final profile = await db.getUserProfile();
    // On explicit refresh: reload all previously-loaded pages in one go so
    // any edited / newly-created mission appears immediately.
    final count   = _missions.length < _pageSize ? _pageSize : _missions.length;
    final reloaded = await db.getMissionsForUserPaged(
      profile?.name ?? '',
      profile?.role == 'crp',
      userId: profile?.supabaseId ?? '',
      limit: count,
      offset: 0,
    );
    _missions      = reloaded;
    // Re-evaluate whether more pages exist
    _hasMoreMissions = reloaded.length >= count;
    _stats         = await db.getStats();
    _unsyncedCount = await db.getUnsyncedCount();
    notifyListeners();
  }

  Future<void> refreshAlerts() async {
    final db = DatabaseHelper.instance;

    // CRP users: pull any newly-posted concurrence requests from Supabase and
    // create local alert records so they appear without a full sync cycle.
    if (_isOnline && SupabaseService.isSignedIn) {
      final profile = await db.getUserProfile();
      if (profile != null && profile.role == 'crp' && profile.organizationId.isNotEmpty) {
        try {
          final pending = await SupabaseService.fetchPendingConcurrences(
              profile.organizationId);
          for (final row in pending) {
            final ref   = row['mission_ref'] as String? ?? '';
            final title = row['title']       as String? ?? '';
            if (ref.isEmpty) continue;
            final newId = await db.upsertConcurrenceAlert(
              missionRef:   ref,
              missionTitle: title,
            );
            // Fire a local notification only for alerts that were just inserted
            if (newId != -1) {
              await NotificationService.showConcurrenceRequest(ref, title);
            }
          }
        } catch (_) {
          // Non-fatal — fall through to local alerts
        }
      }
    }

    _alerts        = await db.getAlerts();
    _unsyncedCount = await db.getUnsyncedCount();
    notifyListeners();
  }

  Future<void> markAlertRead(int id) async {
    await DatabaseHelper.instance.markAlertRead(id);
    await refreshAlerts();
  }

  /// Validates the status transition (if status changed) then persists.
  /// Returns an error message string on rejection, or null on success.
  Future<String?> updateMission(Mission mission) async {
    if (mission.id != null) {
      final current =
          await DatabaseHelper.instance.getMissionById(mission.id!);
      if (current != null && current.status != mission.status) {
        if (!Mission.canTransition(current.status, mission.status)) {
          return 'Cannot change status from '
              '"${current.statusLabel}" to "${mission.statusLabel}".';
        }
      }
    }
    await DatabaseHelper.instance.updateMission(mission);
    await refreshMissions();
    return null;
  }

  /// Appends the next page of missions (DB LIMIT/OFFSET).
  /// No-op if [hasMoreMissions] is false or a load is already in flight
  /// (prevents the scroll listener from issuing concurrent reads at the same
  /// OFFSET, which would append duplicate rows).
  Future<void> loadMoreMissions() async {
    if (!_hasMoreMissions || _isLoadingMore) return;
    _isLoadingMore = true;
    try {
      final db = DatabaseHelper.instance;
      final profile = await db.getUserProfile();
      final more = await db.getMissionsForUserPaged(
        profile?.name ?? '',
        profile?.role == 'crp',
        userId: profile?.supabaseId ?? '',
        limit: _pageSize,
        offset: _missions.length,
      );
      if (more.isEmpty) {
        _hasMoreMissions = false;
        notifyListeners();
        return;
      }
      _missions = [..._missions, ...more];
      _hasMoreMissions = more.length >= _pageSize;
      notifyListeners();
    } finally {
      _isLoadingMore = false;
    }
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
