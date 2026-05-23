import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../services/org_settings_service.dart';
import '../../services/pdf_generator_service.dart';
import '../../theme/app_theme.dart';
import 'battery_log_screen.dart';

class BatteryHistoryScreen extends StatefulWidget {
  const BatteryHistoryScreen({super.key});

  @override
  State<BatteryHistoryScreen> createState() => _BatteryHistoryScreenState();
}

class _BatteryHistoryScreenState extends State<BatteryHistoryScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  int? _exportingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await DatabaseHelper.instance.getBatteryLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportRow(Map<String, dynamic> log) async {
    final rowId = log['id'] as int?;
    setState(() => _exportingId = rowId);
    try {
      final battId = log['battery_id'] as String? ?? 'Battery';
      final org = await OrgSettingsService.load();
      final bytes =
          await PdfGeneratorService.generateBatteryLog(battId, [log], org);
      final safeId = battId.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
      final date = (log['log_date'] as String? ?? '').replaceAll('-', '');
      await PdfGeneratorService.share(bytes, 'A10-Battery-$safeId-$date.pdf');
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
      final bytes = await PdfGeneratorService.generateBatteryLog(
          'All Batteries', _logs, org);
      await PdfGeneratorService.share(bytes, 'A10-BatteryLogs-All.pdf');
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

  Color _statusColor(String s) {
    switch (s) {
      case 'degraded': return AppColors.warning;
      case 'retired':  return AppColors.danger;
      default:         return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Battery Log'),
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
                    tooltip: 'Export all as A-10 PDF',
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
                        Icon(Icons.battery_charging_full,
                            size: 48, color: context.colors.textMuted),
                        const SizedBox(height: 16),
                        Text('No battery logs yet.',
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
                    itemBuilder: (_, i) => _BatteryCard(
                      log: _logs[i],
                      statusColor:
                          _statusColor(_logs[i]['status'] as String? ?? 'good'),
                      isExporting: _exportingId == _logs[i]['id'],
                      onExport: () => _exportRow(_logs[i]),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BatteryLogScreen()),
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

class _BatteryCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final Color statusColor;
  final bool isExporting;
  final VoidCallback onExport;

  const _BatteryCard({
    required this.log,
    required this.statusColor,
    required this.isExporting,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final battId = log['battery_id'] as String? ?? '—';
    final date = log['log_date'] as String? ?? '';
    final status = log['status'] as String? ?? 'good';
    final cycles = log['charge_cycles'];
    final vBefore = log['voltage_before'];
    final vAfter = log['voltage_after'];
    final chargeMin = log['charge_time_min'];
    final remarks = log['remarks'] as String? ?? '';

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
              Text(battId,
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(date,
                  style: TextStyle(
                      color: context.colors.textSecondary, fontSize: 12)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(status,
                style: TextStyle(
                    color: statusColor,
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
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            if (cycles != null)
              _Stat(label: 'Cycles', value: '$cycles'),
            if (vBefore != null)
              _Stat(label: 'V Before', value: '${vBefore}V'),
            if (vAfter != null)
              _Stat(label: 'V After', value: '${vAfter}V'),
            if (chargeMin != null)
              _Stat(label: 'Charge', value: '$chargeMin min'),
          ],
        ),
        if (remarks.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(remarks,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 11,
                  height: 1.4)),
        ],
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(color: context.colors.textMuted, fontSize: 10)),
      Text(value,
          style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    ]);
  }
}
