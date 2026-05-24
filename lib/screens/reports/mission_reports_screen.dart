import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/checklist_item.dart';
import '../../models/flight_log.dart';
import '../../models/flight_plan.dart';
import '../../models/hira_row.dart';
import '../../models/mission.dart';
import '../../services/org_settings_service.dart';
import '../../services/pdf_generator_service.dart';
import '../../theme/app_theme.dart';

class MissionReportsScreen extends StatefulWidget {
  final Mission mission;
  const MissionReportsScreen({super.key, required this.mission});

  @override
  State<MissionReportsScreen> createState() =>
      _MissionReportsScreenState();
}

class _MissionReportsScreenState
    extends State<MissionReportsScreen> {
  // ── Loaded data ────────────────────────────────────────────────────────────
  FlightPlan? _flightPlan;
  List<HiraRow> _hiraRows = [];
  List<ChecklistItem> _equipmentItems = [];
  Map<String, dynamic>? _fitToFly;
  List<ChecklistItem> _preflightItems = [];
  List<ChecklistItem> _inflightItems = [];
  List<ChecklistItem> _postflightItems = [];
  FlightLog? _flightLog;
  List<Map<String, dynamic>> _missionIncidents = [];
  OrgSettings _org = OrgSettings.defaults;

  bool _loaded = false;
  String? _generating; // form ref currently generating ('A-1', etc.)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final id = widget.mission.id!;

    final results = await Future.wait([
      db.getFlightPlanByMissionId(id),
      db.getHiraRowsByMissionId(id),
      db.getChecklistItems(id, 'equipment'),
      db.getFitToFlyRecord(id),
      db.getChecklistItems(id, 'preflight'),
      db.getChecklistItems(id, 'inflight'),
      db.getChecklistItems(id, 'postflight'),
      db.getFlightLogByMissionId(id),
      db.getIncidentsByMissionId(id),   // filtered at DB level — no client-side scan
      OrgSettingsService.load(),
    ]);

    if (!mounted) return;
    setState(() {
      _flightPlan       = results[0] as FlightPlan?;
      _hiraRows         = results[1] as List<HiraRow>;
      _equipmentItems   = results[2] as List<ChecklistItem>;
      _fitToFly         = results[3] as Map<String, dynamic>?;
      _preflightItems   = results[4] as List<ChecklistItem>;
      _inflightItems    = results[5] as List<ChecklistItem>;
      _postflightItems  = results[6] as List<ChecklistItem>;
      _flightLog        = results[7] as FlightLog?;
      _missionIncidents = results[8] as List<Map<String, dynamic>>;
      _org              = results[9] as OrgSettings;
      _loaded = true;
    });
  }

  // ── Download individual forms ─────────────────────────────────────────────

  Future<void> _run(String formRef, Future<void> Function() task) async {
    if (_generating != null) return;
    setState(() => _generating = formRef);
    try {
      await task();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate $formRef: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = null);
    }
  }

  String _filename(String ref, String label) =>
      '${widget.mission.missionId}-$ref-${label.replaceAll(' ', '')}.pdf';

  Future<void> _downloadA1() => _run('A-1', () async {
        final b = await PdfGeneratorService.generateFlightPlan(
            widget.mission, _flightPlan, _hiraRows, _org);
        await PdfGeneratorService.share(b, _filename('A1', 'FlightPlan'));
      });

  Future<void> _downloadA2() => _run('A-2', () async {
        final b = await PdfGeneratorService.generateHira(
            widget.mission, _hiraRows, _org);
        await PdfGeneratorService.share(b, _filename('A2', 'HIRA'));
      });

  Future<void> _downloadA3() => _run('A-3', () async {
        final b = await PdfGeneratorService.generateEquipmentChecklist(
            widget.mission, _equipmentItems, _org);
        await PdfGeneratorService.share(
            b, _filename('A3', 'EquipmentChecklist'));
      });

  Future<void> _downloadA4() => _run('A-4', () async {
        final b = await PdfGeneratorService.generateFitToFly(
            widget.mission, _fitToFly, _org);
        await PdfGeneratorService.share(
            b, _filename('A4', 'FitToFly'));
      });

  Future<void> _downloadA5() => _run('A-5', () async {
        final b = await PdfGeneratorService.generatePreflightChecklist(
            widget.mission, _preflightItems, _org);
        await PdfGeneratorService.share(
            b, _filename('A5', 'PreflightChecklist'));
      });

  Future<void> _downloadA6() => _run('A-6', () async {
        final b = await PdfGeneratorService.generateInflightChecklist(
            widget.mission, _inflightItems, _org);
        await PdfGeneratorService.share(
            b, _filename('A6', 'InflightChecklist'));
      });

  Future<void> _downloadA7() => _run('A-7', () async {
        final b = await PdfGeneratorService.generatePostflightChecklist(
            widget.mission, _postflightItems, _org);
        await PdfGeneratorService.share(
            b, _filename('A7', 'PostflightChecklist'));
      });

  Future<void> _downloadA8() => _run('A-8', () async {
        final b = await PdfGeneratorService.generateFlightLog(
            widget.mission, _flightLog, _org);
        await PdfGeneratorService.share(b, _filename('A8', 'FlightLog'));
      });

  Future<void> _downloadA11(Map<String, dynamic> report) =>
      _run('A-11', () async {
        final b = await PdfGeneratorService.generateIncidentReport(
            widget.mission, report, _org);
        await PdfGeneratorService.share(
            b, _filename('A11', 'IncidentReport'));
      });

  Future<void> _downloadAll() => _run('ALL', () async {
        final m = widget.mission;
        final futures = <Future<void>>[];
        if (_flightPlan != null || m.hasFlightPlanComplete) {
          futures.add(PdfGeneratorService.generateFlightPlan(
                  m, _flightPlan, _hiraRows, _org)
              .then((b) => PdfGeneratorService.share(
                  b, _filename('A1', 'FlightPlan'))));
        }
        if (_hiraRows.isNotEmpty || m.hasHiraComplete) {
          futures.add(PdfGeneratorService.generateHira(m, _hiraRows, _org)
              .then((b) =>
                  PdfGeneratorService.share(b, _filename('A2', 'HIRA'))));
        }
        if (m.hasEquipmentComplete) {
          futures.add(PdfGeneratorService.generateEquipmentChecklist(
                  m, _equipmentItems, _org)
              .then((b) => PdfGeneratorService.share(
                  b, _filename('A3', 'EquipmentChecklist'))));
        }
        if (m.hasFitToFlyComplete) {
          futures.add(
              PdfGeneratorService.generateFitToFly(m, _fitToFly, _org)
                  .then((b) => PdfGeneratorService.share(
                      b, _filename('A4', 'FitToFly'))));
        }
        if (m.hasPreflightComplete) {
          futures.add(PdfGeneratorService.generatePreflightChecklist(
                  m, _preflightItems, _org)
              .then((b) => PdfGeneratorService.share(
                  b, _filename('A5', 'PreflightChecklist'))));
        }
        if (m.hasInflightComplete) {
          futures.add(PdfGeneratorService.generateInflightChecklist(
                  m, _inflightItems, _org)
              .then((b) => PdfGeneratorService.share(
                  b, _filename('A6', 'InflightChecklist'))));
        }
        if (m.hasPostflightComplete) {
          futures.add(PdfGeneratorService.generatePostflightChecklist(
                  m, _postflightItems, _org)
              .then((b) => PdfGeneratorService.share(
                  b, _filename('A7', 'PostflightChecklist'))));
        }
        if (m.hasFlightlogComplete) {
          futures.add(
              PdfGeneratorService.generateFlightLog(m, _flightLog, _org)
                  .then((b) => PdfGeneratorService.share(
                      b, _filename('A8', 'FlightLog'))));
        }
        // Run sequentially to avoid multiple share sheets at once
        for (final f in futures) {
          await f;
        }
      });

  // ── Availability helpers ──────────────────────────────────────────────────

  bool get _anyAvailable {
    final m = widget.mission;
    return m.hasFlightPlanComplete ||
        m.hasHiraComplete ||
        m.hasEquipmentComplete ||
        m.hasFitToFlyComplete ||
        m.hasPreflightComplete ||
        m.hasInflightComplete ||
        m.hasPostflightComplete ||
        m.hasFlightlogComplete ||
        _missionIncidents.isNotEmpty;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final m = widget.mission;

    return Scaffold(
      appBar: AppBar(
        title: Text('${m.missionId} — Reports'),
        actions: [
          if (_loaded && _anyAvailable && _generating == null)
            TextButton.icon(
              onPressed: _downloadAll,
              icon: const Icon(Icons.download_for_offline_outlined,
                  size: 18),
              label: const Text('All'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryLight,
              ),
            ),
          if (_generating != null)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary))
          : ListView(
              padding:
                  const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                // Mission summary card
                _missionCard(m),
                const SizedBox(height: 20),

                // Mission documents section
                _sectionLabel(context, 'MISSION DOCUMENTS'),
                const SizedBox(height: 8),
                _formTile(
                  context,
                  ref: 'A-1',
                  title: 'Flight Plan Record',
                  subtitle: 'Area of operation, crew, weather, contingency plan',
                  icon: Icons.map_outlined,
                  iconColor: AppColors.primary,
                  available: m.hasFlightPlanComplete,
                  onDownload: _downloadA1,
                ),
                _formTile(
                  context,
                  ref: 'A-2',
                  title: 'HIRA — Risk Assessment',
                  subtitle: 'Hazard identification, likelihood × impact matrix',
                  icon: Icons.warning_amber_outlined,
                  iconColor: AppColors.warning,
                  available: m.hasHiraComplete,
                  onDownload: _downloadA2,
                ),
                _formTile(
                  context,
                  ref: 'A-3',
                  title: 'Equipment Handling Checklist',
                  subtitle: 'Batteries, propellers, GCS, UAS pre-flight equipment',
                  icon: Icons.inventory_2_outlined,
                  iconColor: AppColors.accent,
                  available: m.hasEquipmentComplete,
                  onDownload: _downloadA3,
                ),
                _formTile(
                  context,
                  ref: 'A-4',
                  title: 'Fit-to-Fly Declaration',
                  subtitle: 'Airworthiness release signed by maintenance and RPIC',
                  icon: Icons.verified_outlined,
                  iconColor: AppColors.success,
                  available: m.hasFitToFlyComplete,
                  onDownload: _downloadA4,
                ),
                _formTile(
                  context,
                  ref: 'A-5',
                  title: 'Pre-Flight Checklist',
                  subtitle: 'Mission & crew, aircraft, GCS, environment — 4 sections',
                  icon: Icons.checklist_outlined,
                  iconColor: AppColors.primary,
                  available: m.hasPreflightComplete,
                  onDownload: _downloadA5,
                ),
                _formTile(
                  context,
                  ref: 'A-6',
                  title: 'In-Flight Checklist',
                  subtitle: 'Launch, en route, contingency phases',
                  icon: Icons.flight,
                  iconColor: AppColors.accent,
                  available: m.hasInflightComplete,
                  onDownload: _downloadA6,
                ),
                _formTile(
                  context,
                  ref: 'A-7',
                  title: 'Post-Flight Checklist',
                  subtitle: 'Aircraft inspection, documentation, maintenance actions',
                  icon: Icons.flight_land_outlined,
                  iconColor: AppColors.primary,
                  available: m.hasPostflightComplete,
                  onDownload: _downloadA7,
                ),
                _formTile(
                  context,
                  ref: 'A-8',
                  title: 'Flight Log',
                  subtitle: 'Full flight record with durations, weather, data captured',
                  icon: Icons.book_outlined,
                  iconColor: AppColors.success,
                  available: m.hasFlightlogComplete,
                  onDownload: _downloadA8,
                ),

                if (_missionIncidents.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _sectionLabel(context, 'INCIDENT REPORTS'),
                  const SizedBox(height: 8),
                  ..._missionIncidents.asMap().entries.map((e) {
                    final idx = e.key;
                    final r = e.value;
                    final type =
                        r['incident_type'] as String? ?? 'Incident';
                    final severity = (r['severity'] as String? ?? 'minor')
                        .toUpperCase();
                    return _formTile(
                      context,
                      ref: 'A-11',
                      title:
                          'Incident Report ${_missionIncidents.length > 1 ? '#${idx + 1}' : ''}',
                      subtitle: '$type  ·  Severity: $severity',
                      icon: Icons.report_outlined,
                      iconColor: AppColors.danger,
                      available: true,
                      onDownload: () => _downloadA11(r),
                    );
                  }),
                ],

                const SizedBox(height: 20),
                _infoBanner(context),
              ],
            ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _missionCard(Mission m) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          m.title,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.tag, size: 13, color: context.colors.textMuted),
          const SizedBox(width: 4),
          Text(m.missionId,
              style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                  fontFamily: 'monospace')),
          const SizedBox(width: 14),
          Icon(Icons.calendar_today,
              size: 13, color: context.colors.textMuted),
          const SizedBox(width: 4),
          Text(m.date,
              style: TextStyle(
                  color: context.colors.textSecondary, fontSize: 12)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.location_on_outlined,
              size: 13, color: context.colors.textMuted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(m.location,
                style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 10),
        // Step completion indicators
        Wrap(spacing: 6, runSpacing: 6, children: [
          _stepChip('A-1', m.hasFlightPlanComplete),
          _stepChip('A-2', m.hasHiraComplete),
          _stepChip('A-3', m.hasEquipmentComplete),
          _stepChip('A-4', m.hasFitToFlyComplete),
          _stepChip('A-5', m.hasPreflightComplete),
          _stepChip('A-6', m.hasInflightComplete),
          _stepChip('A-7', m.hasPostflightComplete),
          _stepChip('A-8', m.hasFlightlogComplete),
        ]),
      ]),
    );
  }

  Widget _stepChip(String label, bool done) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: done
            ? AppColors.success.withValues(alpha: 0.12)
            : context.colors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: done
              ? AppColors.success.withValues(alpha: 0.4)
              : context.colors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: done ? AppColors.success : context.colors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _formTile(
    BuildContext context, {
    required String ref,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool available,
    required VoidCallback onDownload,
  }) {
    final isGenerating = _generating == ref || _generating == 'ALL';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: available
              ? context.colors.border
              : context.colors.border.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: available
                    ? iconColor.withValues(alpha: 0.1)
                    : context.colors.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(children: [
                Icon(
                  icon,
                  color: available
                      ? iconColor
                      : context.colors.textMuted,
                  size: 16,
                ),
                const SizedBox(height: 2),
                Text(
                  ref,
                  style: TextStyle(
                    color: available
                        ? iconColor
                        : context.colors.textMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),
          ],
        ),
        title: Text(
          title,
          style: TextStyle(
            color: available
                ? context.colors.textPrimary
                : context.colors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: TextStyle(
                color: context.colors.textMuted, fontSize: 10.5),
          ),
        ),
        trailing: available
            ? isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : IconButton(
                    icon: const Icon(Icons.download_outlined),
                    color: AppColors.primary,
                    iconSize: 22,
                    tooltip: 'Download $ref',
                    onPressed: _generating == null ? onDownload : null,
                  )
            : Tooltip(
                message: 'Complete this step to unlock',
                child: Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: context.colors.textMuted
                      .withValues(alpha: 0.5),
                ),
              ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 4),
        isThreeLine: false,
      ),
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

  Widget _infoBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline,
            size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'PDFs follow the DUAS Operations Manual Annex A format '
            '(Rev. 2.0). Forms are populated from the data entered '
            'during each mission step. Completed forms can be shared '
            'directly to cloud storage, email, or printed.',
            style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 11.5,
                height: 1.5),
          ),
        ),
      ]),
    );
  }
}
