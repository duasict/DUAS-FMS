import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../services/org_settings_service.dart';
import '../../services/pdf_generator_service.dart';
import '../../theme/app_theme.dart';
import 'incident_report_screen.dart';

class IncidentHistoryScreen extends StatefulWidget {
  const IncidentHistoryScreen({super.key});

  @override
  State<IncidentHistoryScreen> createState() => _IncidentHistoryScreenState();
}

class _IncidentHistoryScreenState extends State<IncidentHistoryScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  int? _exportingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reports = await DatabaseHelper.instance.getIncidentReports();
    if (mounted) {
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportRow(Map<String, dynamic> report) async {
    final rowId = report['id'] as int?;
    setState(() => _exportingId = rowId);
    try {
      final org = await OrgSettingsService.load();
      final bytes =
          await PdfGeneratorService.generateIncidentReport(null, report, org);
      final date = (report['incident_date'] as String? ?? '').replaceAll('-', '');
      final type = (report['incident_type'] as String? ?? 'incident')
          .replaceAll('_', '-');
      await PdfGeneratorService.share(bytes, 'A11-Incident-$type-$date.pdf');
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

  Color _severityColor(String s) {
    switch (s) {
      case 'moderate': return AppColors.warning;
      case 'serious':  return AppColors.danger;
      case 'fatal':    return AppColors.dangerDark;
      default:         return AppColors.success;
    }
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'accident':          return Icons.car_crash_outlined;
      case 'equipment_failure': return Icons.build_circle_outlined;
      case 'weather':           return Icons.thunderstorm_outlined;
      case 'near_miss':         return Icons.warning_amber_outlined;
      default:                  return Icons.report_outlined;
    }
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'near_miss':         return 'Near Miss';
      case 'accident':          return 'Accident';
      case 'equipment_failure': return 'Equipment Failure';
      case 'weather':           return 'Weather';
      default:                  return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Reports'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _reports.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48, color: context.colors.textMuted),
                        const SizedBox(height: 16),
                        Text('No incident reports on record.',
                            style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 15)),
                        const SizedBox(height: 8),
                        Text('Tap + to file a report.',
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
                    itemCount: _reports.length,
                    itemBuilder: (_, i) {
                      final r = _reports[i];
                      return _ReportCard(
                        report: r,
                        typeLabel: _typeLabel(r['incident_type'] as String? ?? 'other'),
                        typeIcon: _typeIcon(r['incident_type'] as String? ?? 'other'),
                        severityColor: _severityColor(r['severity'] as String? ?? 'minor'),
                        isExporting: _exportingId == r['id'],
                        onExport: () => _exportRow(r),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const IncidentReportScreen()),
          );
          _load();
        },
        icon: const Icon(Icons.add, size: 20),
        label: const Text('New Report'),
        backgroundColor: AppColors.warning,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final String typeLabel;
  final IconData typeIcon;
  final Color severityColor;
  final bool isExporting;
  final VoidCallback onExport;

  const _ReportCard({
    required this.report,
    required this.typeLabel,
    required this.typeIcon,
    required this.severityColor,
    required this.isExporting,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final date = report['incident_date'] as String? ?? '';
    final time = report['incident_time'] as String? ?? '';
    final location = report['location'] as String? ?? '';
    final severity = report['severity'] as String? ?? 'minor';
    final description = report['description'] as String? ?? '';
    final reportedToCaap = (report['reported_to_caap'] as int?) == 1;
    final caapRef = report['caap_reference'] as String?;

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
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(typeIcon, size: 16, color: severityColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(typeLabel,
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              Text(time.isNotEmpty ? '$date  $time' : date,
                  style: TextStyle(
                      color: context.colors.textSecondary, fontSize: 11)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(severity,
                style: TextStyle(
                    color: severityColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          isExporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.warning))
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined,
                      size: 20, color: AppColors.warning),
                  tooltip: 'Export A-11 PDF',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onExport,
                ),
        ]),
        if (location.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.location_on_outlined, size: 12, color: context.colors.textMuted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(location,
                  style: TextStyle(
                      color: context.colors.textMuted, fontSize: 11)),
            ),
          ]),
        ],
        if (description.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Divider(height: 1),
          const SizedBox(height: 6),
          Text(description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                  height: 1.4)),
        ],
        if (reportedToCaap) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.assignment_turned_in_outlined,
                size: 12, color: AppColors.success),
            const SizedBox(width: 4),
            Text(
              caapRef != null && caapRef.isNotEmpty
                  ? 'Reported to CAAP — Ref: $caapRef'
                  : 'Reported to CAAP',
              style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
          ]),
        ],
      ]),
    );
  }
}
