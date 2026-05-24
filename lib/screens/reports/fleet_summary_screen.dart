import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../models/mission.dart';
import '../../providers/user_profile_provider.dart';
import '../../services/org_settings_service.dart';
import '../../services/pdf_generator_service.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  FleetSummaryScreen  (CRP-only)
//
//  Lets the user pick a date range, shows aggregate stats, and exports a
//  Fleet Summary PDF via PdfGeneratorService.generateFleetSummary().
// ─────────────────────────────────────────────────────────────────────────────

class FleetSummaryScreen extends StatefulWidget {
  const FleetSummaryScreen({super.key});

  @override
  State<FleetSummaryScreen> createState() => _FleetSummaryScreenState();
}

class _FleetSummaryScreenState extends State<FleetSummaryScreen> {
  // Date range — defaults to the last 30 days
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to   = DateTime.now();

  bool _isLoading = false;
  bool _isExporting = false;

  // Computed stats (loaded after range selection)
  _Stats? _stats;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  // ── Date pickers ─────────────────────────────────────────────────────────

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: _to,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _from = picked);
      _compute();
    }
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from,
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _to = picked);
      _compute();
    }
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  Future<void> _compute() async {
    setState(() { _isLoading = true; _stats = null; });

    final db = DatabaseHelper.instance;
    final allMissions    = await db.getMissions();
    final allMaintenance = await db.getMaintenanceLogs();
    final allBattery     = await db.getBatteryLogs();
    final allIncidents   = await db.getIncidentReports();

    // Filter by date range (use mission.date string 'YYYY-MM-DD')
    final fromStr = _fmtDate(_from);
    final toStr   = _fmtDate(_to);

    final missions = allMissions
        .where((m) => m.date.compareTo(fromStr) >= 0 && m.date.compareTo(toStr) <= 0)
        .toList();

    final maintenance = allMaintenance.where((r) {
      final d = r['maintenance_date'] as String? ?? '';
      return d.compareTo(fromStr) >= 0 && d.compareTo(toStr) <= 0;
    }).toList();

    final battery = allBattery.where((r) {
      final d = r['log_date'] as String? ?? '';
      return d.compareTo(fromStr) >= 0 && d.compareTo(toStr) <= 0;
    }).toList();

    final incidents = allIncidents.where((r) {
      final d = r['incident_date'] as String? ?? '';
      return d.compareTo(fromStr) >= 0 && d.compareTo(toStr) <= 0;
    }).toList();

    final totalMin =
        missions.fold<int>(0, (s, m) => s + (m.duration ?? 0));

    if (mounted) {
      setState(() {
        _stats = _Stats(
          missions: missions,
          maintenance: maintenance,
          battery: battery,
          incidents: incidents,
          totalFlightHours: totalMin / 60.0,
          completed: missions.where((m) => m.status == 'completed').length,
          highRisk: missions.where((m) => m.crpConcurrenceRequired).length,
          degradedBattery: battery
              .where((b) =>
                  b['status'] == 'degraded' ||
                  b['status'] == 'retired' ||
                  b['status'] == 'replace')
              .length,
          openIncidents: incidents
              .where((i) => (i['corrective_actions'] as String? ?? '').isEmpty)
              .length,
        );
        _isLoading = false;
      });
    }
  }

  // ── PDF export ────────────────────────────────────────────────────────────

  Future<void> _export() async {
    final s = _stats;
    if (s == null) return;
    setState(() => _isExporting = true);
    try {
      final org = await OrgSettingsService.load();
      final label = '${_fmtDisplay(_from)} – ${_fmtDisplay(_to)}';
      final bytes = await PdfGeneratorService.generateFleetSummary(
        org: org,
        rangeLabel: label,
        missions: s.missions,
        flightLogs: const [],    // flight log details are embedded in missions
        maintenance: s.maintenance,
        batteryLogs: s.battery,
        incidents: s.incidents,
      );
      if (!mounted) return;
      await PdfGeneratorService.showPdfActions(
          context, bytes, 'FleetSummary-$label.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtDisplay(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isCrp = context.watch<UserProfileProvider>().profile.role == 'crp';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Summary'),
        actions: [
          if (_isExporting)
            const Padding(
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
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Export PDF',
              onPressed: (!isCrp || _isLoading || _stats == null)
                  ? null
                  : _export,
            ),
        ],
      ),
      body: Column(children: [
        // ── Date range picker strip ─────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(children: [
            Expanded(child: _DateChip(
              label: 'From',
              date: _fmtDisplay(_from),
              onTap: _pickFrom,
            )),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.arrow_forward,
                  size: 14, color: context.colors.textMuted),
            ),
            Expanded(child: _DateChip(
              label: 'To',
              date: _fmtDisplay(_to),
              onTap: _pickTo,
            )),
          ]),
        ),

        const SizedBox(height: 14),

        // ── Stats body ──────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary))
              : _stats == null
                  ? const SizedBox.shrink()
                  : _buildStats(_stats!),
        ),
      ]),
    );
  }

  Widget _buildStats(_Stats s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        _StatCard(
          icon: Icons.flight_takeoff,
          color: AppColors.primary,
          title: 'Missions',
          items: [
            _Item('Total', '${s.missions.length}'),
            _Item('Completed', '${s.completed}', color: AppColors.success),
            _Item('High-Risk', '${s.highRisk}', color: AppColors.warning),
          ],
        ),
        _StatCard(
          icon: Icons.access_time,
          color: AppColors.accent,
          title: 'Flight Time',
          items: [
            _Item('Total Hours',
                '${s.totalFlightHours.toStringAsFixed(1)} hrs'),
          ],
        ),
        _StatCard(
          icon: Icons.build_outlined,
          color: AppColors.primaryLight,
          title: 'Maintenance',
          items: [
            _Item('Log Entries', '${s.maintenance.length}'),
          ],
        ),
        _StatCard(
          icon: Icons.battery_charging_full,
          color: s.degradedBattery > 0 ? AppColors.danger : AppColors.success,
          title: 'Battery Health',
          items: [
            _Item('Log Entries', '${s.battery.length}'),
            _Item('Degraded / Replace', '${s.degradedBattery}',
                color: s.degradedBattery > 0 ? AppColors.danger : null),
          ],
        ),
        _StatCard(
          icon: Icons.warning_amber_outlined,
          color: s.openIncidents > 0 ? AppColors.danger : AppColors.success,
          title: 'Safety & Incidents',
          items: [
            _Item('Total Reports', '${s.incidents.length}'),
            _Item('Open (no corrective action)', '${s.openIncidents}',
                color: s.openIncidents > 0 ? AppColors.danger : null),
          ],
        ),
      ],
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _Stats {
  final List<Mission> missions;
  final List<Map<String, dynamic>> maintenance;
  final List<Map<String, dynamic>> battery;
  final List<Map<String, dynamic>> incidents;
  final double totalFlightHours;
  final int completed;
  final int highRisk;
  final int degradedBattery;
  final int openIncidents;

  const _Stats({
    required this.missions,
    required this.maintenance,
    required this.battery,
    required this.incidents,
    required this.totalFlightHours,
    required this.completed,
    required this.highRisk,
    required this.degradedBattery,
    required this.openIncidents,
  });
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  final String label;
  final String date;
  final VoidCallback onTap;
  const _DateChip({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(date,
              style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _Item {
  final String label;
  final String value;
  final Color? color;
  const _Item(this.label, this.value, {this.color});
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<_Item> items;
  const _StatCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
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
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(
                    child: Text(item.label,
                        style: TextStyle(
                            color: context.colors.textSecondary, fontSize: 13))),
                Text(item.value,
                    style: TextStyle(
                        color: item.color ?? context.colors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ]),
            )),
      ]),
    );
  }
}
