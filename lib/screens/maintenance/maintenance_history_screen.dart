import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/aircraft.dart';
import '../../services/org_settings_service.dart';
import '../../services/pdf_generator_service.dart';
import '../../theme/app_theme.dart';
import 'maintenance_log_screen.dart';

class MaintenanceHistoryScreen extends StatefulWidget {
  const MaintenanceHistoryScreen({super.key});

  @override
  State<MaintenanceHistoryScreen> createState() =>
      _MaintenanceHistoryScreenState();
}

class _MaintenanceHistoryScreenState extends State<MaintenanceHistoryScreen> {
  List<Map<String, dynamic>> _logs = [];
  List<Aircraft> _aircraft = [];
  bool _isLoading = true;
  int? _exportingId; // row id currently being exported

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await DatabaseHelper.instance.getMaintenanceLogs();
    final aircraft = await DatabaseHelper.instance.getAircraft();
    if (mounted) {
      setState(() {
        _logs = logs;
        _aircraft = aircraft;
        _isLoading = false;
      });
    }
  }

  String _aircraftName(int? id) {
    if (id == null) return '—';
    try {
      return _aircraft.firstWhere((a) => a.id == id).name;
    } catch (_) {
      return 'Aircraft #$id';
    }
  }

  String _aircraftSerial(int? id) {
    if (id == null) return '';
    try {
      return _aircraft.firstWhere((a) => a.id == id).serialNumber;
    } catch (_) {
      return '';
    }
  }

  Future<void> _exportRow(Map<String, dynamic> log) async {
    final rowId = log['id'] as int?;
    setState(() => _exportingId = rowId);
    try {
      final aircraftName = _aircraftName(log['aircraft_id'] as int?);
      final serial = _aircraftSerial(log['aircraft_id'] as int?);
      final org = await OrgSettingsService.load();
      final bytes = await PdfGeneratorService.generateMaintenanceLog(
        aircraftName,
        serial,
        [log],
        org,
      );
      final date = (log['maintenance_date'] as String? ?? '').replaceAll('-', '');
      final safeName = aircraftName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
      if (!mounted) return;
      await PdfGeneratorService.showPdfActions(
          context, bytes, 'A9-Maint-$safeName-$date.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _exportingId = null);
    }
  }

  Future<void> _exportAll() async {
    setState(() => _exportingId = -1);
    try {
      final org = await OrgSettingsService.load();
      final bytes = await PdfGeneratorService.generateMaintenanceLog(
        'All Aircraft',
        '',
        _logs,
        org,
      );
      if (!mounted) return;
      await PdfGeneratorService.showPdfActions(
          context, bytes, 'A9-MaintenanceLogs-All.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _exportingId = null);
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'unscheduled':  return AppColors.warning;
      case 'post-incident': return AppColors.danger;
      case 'inspection':   return AppColors.accent;
      default:             return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Log'),
        actions: [
          if (_logs.isNotEmpty)
            _exportingId == -1
                ? const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primaryLight),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: 'Export all as A-9 PDF',
                    onPressed: _exportAll,
                  ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _logs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.build_outlined,
                            size: 48, color: context.colors.textMuted),
                        const SizedBox(height: 16),
                        Text('No maintenance logs yet.',
                            style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 15)),
                        const SizedBox(height: 8),
                        Text('Tap + to add the first entry.',
                            style: TextStyle(
                                color: context.colors.textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: context.colors.card,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
                    itemCount: _logs.length,
                    itemBuilder: (_, i) => _LogCard(
                      log: _logs[i],
                      aircraftName: _aircraftName(_logs[i]['aircraft_id'] as int?),
                      typeColor: _typeColor(
                          _logs[i]['maintenance_type'] as String? ?? 'scheduled'),
                      isExporting: _exportingId == _logs[i]['id'],
                      onExport: () => _exportRow(_logs[i]),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MaintenanceLogScreen()),
          );
          _load();
        },
        icon: const Icon(Icons.add, size: 20),
        label: const Text('New Log'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final String aircraftName;
  final Color typeColor;
  final bool isExporting;
  final VoidCallback onExport;

  const _LogCard({
    required this.log,
    required this.aircraftName,
    required this.typeColor,
    required this.isExporting,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final type = log['maintenance_type'] as String? ?? 'scheduled';
    final date = log['maintenance_date'] as String? ?? '';
    final description = log['description'] as String? ?? '';
    final signedBy = log['signed_by'] as String? ?? '';
    final airworthiness = log['airworthiness_status'] as String? ?? '';
    final nextDate = log['next_maintenance_date'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(date,
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(aircraftName,
                  style: TextStyle(
                      color: context.colors.textSecondary, fontSize: 12)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(type,
                style: TextStyle(
                    color: typeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          isExporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary))
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined,
                      size: 20, color: AppColors.primary),
                  tooltip: 'Export this record',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onExport,
                ),
        ]),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 8),
        if (description.isNotEmpty) ...[
          Text(description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                  height: 1.4)),
          const SizedBox(height: 6),
        ],
        Row(children: [
          Icon(Icons.verified_outlined, size: 12, color: context.colors.textMuted),
          const SizedBox(width: 4),
          Text(airworthiness,
              style: TextStyle(
                  color: context.colors.textMuted, fontSize: 11)),
          const Spacer(),
          if (signedBy.isNotEmpty) ...[
            Icon(Icons.draw_outlined, size: 12, color: context.colors.textMuted),
            const SizedBox(width: 4),
            Text(signedBy,
                style: TextStyle(
                    color: context.colors.textMuted, fontSize: 11)),
          ],
        ]),
        if (nextDate != null && nextDate.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.schedule_outlined, size: 12, color: AppColors.warning),
            const SizedBox(width: 4),
            Text('Next: $nextDate',
                style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ]),
        ],
      ]),
    );
  }
}
