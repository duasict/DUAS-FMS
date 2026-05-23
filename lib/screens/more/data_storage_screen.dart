import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';

class DataStorageScreen extends StatefulWidget {
  const DataStorageScreen({super.key});

  @override
  State<DataStorageScreen> createState() => _DataStorageScreenState();
}

class _DataStorageScreenState extends State<DataStorageScreen> {
  int     _unsyncedCount = 0;
  bool    _isOnline      = false;
  bool    _isSyncing     = false;
  String  _lastSyncMsg   = 'Not synced this session';
  bool    _loaded        = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final count   = await SyncService.getUnsyncedCount();
    final results = await Connectivity().checkConnectivity();
    final online  = results.any(
        (r) => r == ConnectivityResult.wifi || r == ConnectivityResult.mobile);
    if (mounted) {
      setState(() {
        _unsyncedCount = count;
        _isOnline      = online;
        _loaded        = true;
      });
    }
  }

  Future<void> _sync() async {
    setState(() => _isSyncing = true);
    final ok = await SyncService.syncToCloud();
    await _refresh();
    if (mounted) {
      setState(() {
        _isSyncing   = false;
        _lastSyncMsg = ok
            ? 'Synced successfully — ${_now()}'
            : 'Sync failed — check connection and credentials';
      });
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text('Clear Local Cache',
            style: TextStyle(color: context.colors.textPrimary)),
        content: Text(
          'This permanently deletes all locally stored missions, logs, '
          'and records that have NOT been synced to Supabase.\n\n'
          'Already-synced data will NOT be affected.',
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: context.colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseHelper.instance.markAllSynced(); // marks unsynced as synced (no hard delete)
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unsynced records marked as cleared.')),
      );
    }
  }

  String _now() {
    final t = DateTime.now();
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')} '
        '${t.day}/${t.month}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data & Storage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          )
        ],
      ),
      body: _loaded
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                _statusCard(context),
                const SizedBox(height: 20),
                _sectionLabel(context, 'SYNC'),
                const SizedBox(height: 8),
                _syncCard(context),
                const SizedBox(height: 20),
                _sectionLabel(context, 'LOCAL DATABASE'),
                const SizedBox(height: 8),
                _infoTile(context,
                    icon: Icons.storage_outlined,
                    label: 'Engine',
                    value: 'SQLite v6 (sqflite)'),
                _infoTile(context,
                    icon: Icons.cloud_off_outlined,
                    label: 'Offline Support',
                    value: 'Full — all data stored locally first'),
                _infoTile(context,
                    icon: Icons.sync_outlined,
                    label: 'Cloud Target',
                    value: 'Supabase PostgreSQL (upsert on sync)'),
                const SizedBox(height: 20),
                _sectionLabel(context, 'DANGER ZONE'),
                const SizedBox(height: 8),
                _dangerCard(context),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }

  Widget _statusCard(BuildContext context) {
    final hasUnsynced = _unsyncedCount > 0;
    final statusColor = _isOnline
        ? (hasUnsynced ? AppColors.warning : AppColors.success)
        : context.colors.textMuted;
    final statusText = !_isOnline
        ? 'Offline — changes saved locally'
        : hasUnsynced
            ? '$_unsyncedCount record${_unsyncedCount == 1 ? '' : 's'} pending sync'
            : 'All records synced';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isOnline
                ? (hasUnsynced
                    ? Icons.cloud_upload_outlined
                    : Icons.cloud_done_outlined)
                : Icons.cloud_off_outlined,
            color: statusColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(statusText,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(_lastSyncMsg,
                style: TextStyle(
                    color: context.colors.textMuted, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  Widget _syncCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Manual Cloud Sync',
          style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Pushes all unsynced missions, maintenance logs, battery logs, '
          'and incident reports to Supabase. Requires an active connection '
          'and a signed-in account.',
          style:
              TextStyle(color: context.colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_isSyncing || !_isOnline) ? null : _sync,
            icon: _isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(_isSyncing
                ? 'Syncing…'
                : _isOnline
                    ? 'Sync to Cloud'
                    : 'Offline — cannot sync'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _dangerCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Text('Clear Unsynced Records',
              style: TextStyle(
                  color: AppColors.danger,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Text(
          'Marks all locally pending records as cleared. Only use this if '
          'you are certain the data is no longer needed. This action cannot '
          'be undone.',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _unsyncedCount == 0 ? null : _clearCache,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(_unsyncedCount == 0
                ? 'Nothing to clear'
                : 'Clear $_unsyncedCount unsynced record${_unsyncedCount == 1 ? '' : 's'}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _infoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: AppColors.primaryLight, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        color: context.colors.textPrimary, fontSize: 13)),
              ]),
        ),
      ]),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          text,
          style: TextStyle(
            color: context.colors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );
}
