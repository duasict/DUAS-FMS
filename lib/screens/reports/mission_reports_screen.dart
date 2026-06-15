import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/checklist_item.dart';
import '../../models/crew_member.dart';
import '../../models/flight_log.dart';
import '../../models/flight_plan.dart';
import '../../models/hira_row.dart';
import '../../models/mission.dart';
import '../../models/user_profile.dart';
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
  List<CrewMember> _crew = [];
  UserProfile? _localProfile;
  List<Map<String, dynamic>> _documents = [];
  OrgSettings _org = OrgSettings.defaults;

  bool _loaded = false;
  String? _generating; // form ref currently generating ('A-1', etc.)

  // ── Selection mode ─────────────────────────────────────────────────────────
  bool _selectMode = false;
  final Set<String> _selectedForms = {};

  // ── Coverage area ──────────────────────────────────────────────────────────
  double get _coverageAreaHa {
    final geoJson = _flightPlan?.coverageAreaGeoJson;
    if (geoJson == null) return 0;
    try {
      final d = jsonDecode(geoJson) as Map<String, dynamic>;
      final type = d['type'] as String?;
      List<dynamic> coords;
      if (type == 'Polygon') {
        coords = (d['coordinates'] as List).first as List;
      } else if (type == 'Feature') {
        coords = ((d['geometry'] as Map)['coordinates'] as List).first as List;
      } else {
        return 0;
      }
      const R = 6371000.0;
      double area = 0;
      for (int i = 0; i < coords.length; i++) {
        final j = (i + 1) % coords.length;
        final lonI = (coords[i][0] as num).toDouble() * pi / 180;
        final latI = (coords[i][1] as num).toDouble() * pi / 180;
        final lonJ = (coords[j][0] as num).toDouble() * pi / 180;
        final latJ = (coords[j][1] as num).toDouble() * pi / 180;
        area += (lonJ - lonI) * (2 + sin(latI) + sin(latJ));
      }
      return (area.abs() * R * R / 2) / 10000;
    } catch (_) {
      return 0;
    }
  }

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
      db.getIncidentsByMissionId(id),
      OrgSettingsService.load(),
      db.getCrewForMission(id),
      db.getUserProfile(),
      db.getMissionDocuments(id),
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
      _crew             = results[10] as List<CrewMember>;
      _localProfile     = results[11] as UserProfile?;
      _documents        = results[12] as List<Map<String, dynamic>>;
      _loaded = true;
    });
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (!_selectMode) _selectedForms.clear();
    });
  }

  void _toggleForm(String ref) {
    setState(() {
      if (_selectedForms.contains(ref)) {
        _selectedForms.remove(ref);
      } else {
        _selectedForms.add(ref);
      }
    });
  }

  Future<void> _downloadZip() => _run('ZIP', () async {
        final m = widget.mission;
        final entries = <String, Future<Uint8List>>{};

        if (_selectedForms.contains('A-1') &&
            (_flightPlan != null || m.hasFlightPlanComplete)) {
          entries[_filename('A1', 'FlightPlan')] =
              PdfGeneratorService.generateFlightPlan(
                  m, _flightPlan, _hiraRows, _org);
        }
        if (_selectedForms.contains('A-2') && m.hasHiraComplete) {
          entries[_filename('A2', 'HIRA')] =
              PdfGeneratorService.generateHira(m, _hiraRows, _org);
        }
        if (_selectedForms.contains('A-3') && m.hasEquipmentComplete) {
          entries[_filename('A3', 'EquipmentChecklist')] =
              PdfGeneratorService.generateEquipmentChecklist(
                  m, _equipmentItems, _org);
        }
        if (_selectedForms.contains('A-4') && m.hasFitToFlyComplete) {
          entries[_filename('A4', 'FitToFly')] =
              PdfGeneratorService.generateFitToFly(m, _fitToFly, _org);
        }
        if (_selectedForms.contains('A-5') && m.hasPreflightComplete) {
          entries[_filename('A5', 'PreflightChecklist')] =
              PdfGeneratorService.generatePreflightChecklist(
                  m, _preflightItems, _org);
        }
        if (_selectedForms.contains('A-6') && m.hasInflightComplete) {
          entries[_filename('A6', 'InflightChecklist')] =
              PdfGeneratorService.generateInflightChecklist(
                  m, _inflightItems, _org);
        }
        if (_selectedForms.contains('A-7') && m.hasPostflightComplete) {
          entries[_filename('A7', 'PostflightChecklist')] =
              PdfGeneratorService.generatePostflightChecklist(
                  m, _postflightItems, _org);
        }
        if (_selectedForms.contains('A-8') && m.hasFlightlogComplete) {
          entries[_filename('A8', 'FlightLog')] =
              PdfGeneratorService.generateFlightLog(m, _flightLog, _org);
        }

        if (entries.isEmpty) return;

        final resolved = await Future.wait(
            entries.entries.map((e) => e.value.then((b) => MapEntry(e.key, b))));

        final archive = Archive();
        for (final e in resolved) {
          archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
        }
        final zipBytes = ZipEncoder().encode(archive);
        if (zipBytes == null) return;

        final zipName = '${m.missionId}-Reports.zip';
        final path = await PdfGeneratorService.saveToDevice(
            Uint8List.fromList(zipBytes), zipName);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ZIP saved: $path'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ));
        setState(() {
          _selectMode = false;
          _selectedForms.clear();
        });
      });

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
        if (!mounted) return;
        await PdfGeneratorService.showPdfActions(
            context, b, _filename('A1', 'FlightPlan'));
      });

  Future<void> _downloadA2() => _run('A-2', () async {
        final b = await PdfGeneratorService.generateHira(
            widget.mission, _hiraRows, _org);
        if (!mounted) return;
        await PdfGeneratorService.showPdfActions(
            context, b, _filename('A2', 'HIRA'));
      });

  Future<void> _downloadA3() => _run('A-3', () async {
        final b = await PdfGeneratorService.generateEquipmentChecklist(
            widget.mission, _equipmentItems, _org);
        if (!mounted) return;
        await PdfGeneratorService.showPdfActions(
            context, b, _filename('A3', 'EquipmentChecklist'));
      });

  Future<void> _downloadA4() => _run('A-4', () async {
        final b = await PdfGeneratorService.generateFitToFly(
            widget.mission, _fitToFly, _org);
        if (!mounted) return;
        await PdfGeneratorService.showPdfActions(
            context, b, _filename('A4', 'FitToFly'));
      });

  Future<void> _downloadA5() => _run('A-5', () async {
        final b = await PdfGeneratorService.generatePreflightChecklist(
            widget.mission, _preflightItems, _org);
        if (!mounted) return;
        await PdfGeneratorService.showPdfActions(
            context, b, _filename('A5', 'PreflightChecklist'));
      });

  Future<void> _downloadA6() => _run('A-6', () async {
        final b = await PdfGeneratorService.generateInflightChecklist(
            widget.mission, _inflightItems, _org);
        if (!mounted) return;
        await PdfGeneratorService.showPdfActions(
            context, b, _filename('A6', 'InflightChecklist'));
      });

  Future<void> _downloadA7() => _run('A-7', () async {
        final b = await PdfGeneratorService.generatePostflightChecklist(
            widget.mission, _postflightItems, _org);
        if (!mounted) return;
        await PdfGeneratorService.showPdfActions(
            context, b, _filename('A7', 'PostflightChecklist'));
      });

  Future<void> _downloadA8() => _run('A-8', () async {
        final b = await PdfGeneratorService.generateFlightLog(
            widget.mission, _flightLog, _org);
        if (!mounted) return;
        await PdfGeneratorService.showPdfActions(
            context, b, _filename('A8', 'FlightLog'));
      });

  Future<void> _downloadA11(Map<String, dynamic> report) =>
      _run('A-11', () async {
        final b = await PdfGeneratorService.generateIncidentReport(
            widget.mission, report, _org);
        if (!mounted) return;
        await PdfGeneratorService.showPdfActions(
            context, b, _filename('A11', 'IncidentReport'));
      });

  /// Downloads all available forms directly to the device (no per-file
  /// sheet) and shows a single summary snackbar when done.
  Future<void> _downloadAll() => _run('ALL', () async {
        final m = widget.mission;
        final tasks = <MapEntry<Future<Uint8List>, String>>[];

        if (_flightPlan != null || m.hasFlightPlanComplete) {
          tasks.add(MapEntry(
              PdfGeneratorService.generateFlightPlan(
                  m, _flightPlan, _hiraRows, _org),
              _filename('A1', 'FlightPlan')));
        }
        if (_hiraRows.isNotEmpty || m.hasHiraComplete) {
          tasks.add(MapEntry(
              PdfGeneratorService.generateHira(m, _hiraRows, _org),
              _filename('A2', 'HIRA')));
        }
        if (m.hasEquipmentComplete) {
          tasks.add(MapEntry(
              PdfGeneratorService.generateEquipmentChecklist(
                  m, _equipmentItems, _org),
              _filename('A3', 'EquipmentChecklist')));
        }
        if (m.hasFitToFlyComplete) {
          tasks.add(MapEntry(
              PdfGeneratorService.generateFitToFly(m, _fitToFly, _org),
              _filename('A4', 'FitToFly')));
        }
        if (m.hasPreflightComplete) {
          tasks.add(MapEntry(
              PdfGeneratorService.generatePreflightChecklist(
                  m, _preflightItems, _org),
              _filename('A5', 'PreflightChecklist')));
        }
        if (m.hasInflightComplete) {
          tasks.add(MapEntry(
              PdfGeneratorService.generateInflightChecklist(
                  m, _inflightItems, _org),
              _filename('A6', 'InflightChecklist')));
        }
        if (m.hasPostflightComplete) {
          tasks.add(MapEntry(
              PdfGeneratorService.generatePostflightChecklist(
                  m, _postflightItems, _org),
              _filename('A7', 'PostflightChecklist')));
        }
        if (m.hasFlightlogComplete) {
          tasks.add(MapEntry(
              PdfGeneratorService.generateFlightLog(m, _flightLog, _org),
              _filename('A8', 'FlightLog')));
        }

        // Generate + save all in parallel; a single failure propagates to _run().
        await Future.wait(tasks.map((e) =>
            e.key.then((b) => PdfGeneratorService.saveToDevice(b, e.value))));

        if (!mounted) return;
        final n = tasks.length;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('$n PDF${n == 1 ? '' : 's'} saved to FMS_Reports/'),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 5),
        ));
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${m.missionId} — Reports'),
            Text(
              _selectMode
                  ? '${_selectedForms.length} selected'
                  : 'Documents & compliance reports',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: context.colors.textSecondary,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        actions: [
          if (_generating != null)
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
          else if (_loaded && _anyAvailable) ...[
            if (_selectMode)
              TextButton(
                onPressed: _toggleSelectMode,
                child: Text('Cancel',
                    style: TextStyle(color: context.colors.textSecondary)),
              )
            else ...[
              IconButton(
                icon: const Icon(Icons.checklist_rtl_outlined),
                tooltip: 'Select to ZIP',
                onPressed: _toggleSelectMode,
              ),
              TextButton.icon(
                onPressed: _downloadAll,
                icon: const Icon(Icons.download_for_offline_outlined, size: 18),
                label: const Text('All'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryLight),
              ),
            ],
          ],
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                _missionCard(m),
                if (_documents.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionLabel(context, 'SUBMITTED DOCUMENTS'),
                  const SizedBox(height: 8),
                  _submittedDocsTile(context),
                ],
                const SizedBox(height: 20),
                _sectionLabel(context, 'MISSION DOCUMENTS'),
                const SizedBox(height: 8),
                _formTile(context, ref: 'A-1',
                  title: 'Flight Plan Record',
                  subtitle: 'Area of operation, crew, weather, contingency plan',
                  icon: Icons.map_outlined, iconColor: AppColors.primary,
                  available: m.hasFlightPlanComplete, onDownload: _downloadA1),
                _formTile(context, ref: 'A-2',
                  title: 'HIRA — Risk Assessment',
                  subtitle: 'Hazard identification, likelihood × impact matrix',
                  icon: Icons.warning_amber_outlined, iconColor: AppColors.warning,
                  available: m.hasHiraComplete, onDownload: _downloadA2),
                _formTile(context, ref: 'A-3',
                  title: 'Equipment Handling Checklist',
                  subtitle: 'Batteries, propellers, GCS, UAS pre-flight equipment',
                  icon: Icons.inventory_2_outlined, iconColor: AppColors.accent,
                  available: m.hasEquipmentComplete, onDownload: _downloadA3),
                _formTile(context, ref: 'A-4',
                  title: 'Fit-to-Fly Declaration',
                  subtitle: 'Airworthiness release signed by maintenance and RPIC',
                  icon: Icons.verified_outlined, iconColor: AppColors.success,
                  available: m.hasFitToFlyComplete, onDownload: _downloadA4),
                _formTile(context, ref: 'A-5',
                  title: 'Pre-Flight Checklist',
                  subtitle: 'Mission & crew, aircraft, GCS, environment — 4 sections',
                  icon: Icons.checklist_outlined, iconColor: AppColors.primary,
                  available: m.hasPreflightComplete, onDownload: _downloadA5),
                _formTile(context, ref: 'A-6',
                  title: 'In-Flight Checklist',
                  subtitle: 'Launch, en route, contingency phases',
                  icon: Icons.flight, iconColor: AppColors.accent,
                  available: m.hasInflightComplete, onDownload: _downloadA6),
                _formTile(context, ref: 'A-7',
                  title: 'Post-Flight Checklist',
                  subtitle: 'Aircraft inspection, documentation, maintenance actions',
                  icon: Icons.flight_land_outlined, iconColor: AppColors.primary,
                  available: m.hasPostflightComplete, onDownload: _downloadA7),
                _formTile(context, ref: 'A-8',
                  title: 'Flight Log',
                  subtitle: 'Full flight record with durations, weather, data captured',
                  icon: Icons.book_outlined, iconColor: AppColors.success,
                  available: m.hasFlightlogComplete, onDownload: _downloadA8),
                if (_missionIncidents.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _sectionLabel(context, 'INCIDENT REPORTS'),
                  const SizedBox(height: 8),
                  ..._missionIncidents.asMap().entries.map((e) {
                    final idx = e.key;
                    final r = e.value;
                    return _formTile(context,
                      ref: 'A-11',
                      title: 'Incident Report${_missionIncidents.length > 1 ? ' #${idx + 1}' : ''}',
                      subtitle: '${r['incident_type'] ?? 'Incident'}  ·  Severity: ${(r['severity'] as String? ?? 'minor').toUpperCase()}',
                      icon: Icons.report_outlined, iconColor: AppColors.danger,
                      available: true, onDownload: () => _downloadA11(r),
                      selectable: false);
                  }),
                ],
                const SizedBox(height: 20),
                _infoBanner(context),
              ],
            ),
      bottomNavigationBar: _selectMode
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border(top: BorderSide(color: context.colors.border)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _selectedForms.isEmpty || _generating != null
                        ? null
                        : _downloadZip,
                    icon: _generating == 'ZIP'
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.folder_zip_outlined, size: 20),
                    label: Text(_selectedForms.isEmpty
                        ? 'Select forms to ZIP'
                        : 'Download ${_selectedForms.length} as ZIP'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _missionCard(Mission m) {
    final ha = _coverageAreaHa;
    final areaStr = ha > 0
        ? ha >= 100
            ? '${(ha / 100).toStringAsFixed(2)} km²'
            : '${ha.toStringAsFixed(2)} ha'
        : null;
    final rpic = _crew.where((c) => c.role.toLowerCase() == 'rpic').firstOrNull;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.title,
            style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
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
          Icon(Icons.calendar_today, size: 13, color: context.colors.textMuted),
          const SizedBox(width: 4),
          Text(m.date,
              style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.location_on_outlined, size: 13, color: context.colors.textMuted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(m.location,
                style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
          ),
        ]),
        if (rpic != null || areaStr != null) ...[
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(children: [
            if (rpic != null) ...[
              Icon(Icons.person_outline, size: 13, color: context.colors.textMuted),
              const SizedBox(width: 4),
              Text('RPIC: ',
                  style: TextStyle(color: context.colors.textMuted, fontSize: 11)),
              Expanded(
                child: Text(rpic.name,
                    style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
              GestureDetector(
                onTap: () => _showRpicLicense(rpic),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.badge_outlined, size: 11, color: AppColors.accent),
                    SizedBox(width: 3),
                    Text('License',
                        style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ],
            if (areaStr != null) ...[
              if (rpic != null) const SizedBox(width: 14),
              Icon(Icons.crop_free, size: 13, color: context.colors.textMuted),
              const SizedBox(width: 4),
              Text(areaStr,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ]),
        ],
        const SizedBox(height: 10),
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

  void _showRpicLicense(CrewMember rpic) {
    final isSelf = _localProfile != null &&
        rpic.userId != null &&
        _localProfile!.supabaseId == rpic.userId;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.card,
        title: Row(children: [
          const Icon(Icons.badge_outlined, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('RPIC License — ${rpic.name}',
                style: TextStyle(
                    color: ctx.colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        content: isSelf && _localProfile!.licenseNumber.isNotEmpty
            ? Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                _licenseRow(ctx, 'License No.', _localProfile!.licenseNumber),
                const SizedBox(height: 8),
                _licenseRow(ctx, 'Expiry', _localProfile!.licenseExpiryDate ?? '—'),
                const SizedBox(height: 8),
                _licenseRow(ctx, 'Status',
                    _localProfile!.licenseVerified ? 'Verified ✓' : 'Unverified'),
              ])
            : Text('License on file. Accessible on the crew member\'s device.',
                style: TextStyle(color: ctx.colors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _licenseRow(BuildContext ctx, String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 90,
        child: Text('$label:',
            style: TextStyle(color: ctx.colors.textMuted, fontSize: 12)),
      ),
      Expanded(
        child: Text(value,
            style: TextStyle(
                color: ctx.colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace')),
      ),
    ]);
  }

  Widget _submittedDocsTile(BuildContext context) {
    const typeLabels = {
      'travel_order': 'Travel Order',
      'site_permission': 'Site Permission',
      'property_owner': 'Property Owner',
    };
    const typeIcons = {
      'travel_order': Icons.description_outlined,
      'site_permission': Icons.verified_outlined,
      'property_owner': Icons.house_outlined,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _documents.map((doc) {
          final type = doc['document_type'] as String? ?? '';
          final permType = doc['permission_type'] as String? ?? '';
          final path = doc['file_path'] as String? ?? '';
          final name = path.isNotEmpty
              ? path.split('/').last.split('\\').last
              : '—';
          final isPdf = name.toLowerCase().endsWith('.pdf');
          final label = typeLabels[type] ?? type;
          final icon = typeIcons[type] ?? Icons.insert_drive_file_outlined;
          final subtitle = (type == 'site_permission' && permType.isNotEmpty)
              ? permType
              : null;
          return Padding(
            padding: EdgeInsets.only(
                bottom: doc == _documents.last ? 0 : 10),
            child: Row(children: [
              Icon(icon, size: 15, color: context.colors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(subtitle != null ? '$label — $subtitle' : label,
                      style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  Text(name,
                      style: TextStyle(
                          color: context.colors.textMuted, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ]),
              ),
              Icon(
                  isPdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  size: 13,
                  color:
                      isPdf ? AppColors.danger : context.colors.textMuted),
            ]),
          );
        }).toList(),
      ),
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
    bool selectable = true,
  }) {
    final isGenerating = _generating == ref || _generating == 'ALL';
    final isSelected = _selectedForms.contains(ref);
    final inSelectMode = _selectMode && selectable && available;

    return GestureDetector(
      onTap: inSelectMode ? () => _toggleForm(ref) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.07)
              : context.colors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.4)
                : available
                    ? context.colors.border
                    : context.colors.border.withValues(alpha: 0.4),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: ListTile(
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (inSelectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.primary : context.colors.surface,
                      border: Border.all(
                          color: isSelected ? AppColors.primary : context.colors.border),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                ),
              Container(
                width: 38,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: available ? iconColor.withValues(alpha: 0.1) : context.colors.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(children: [
                  Icon(icon,
                      color: available ? iconColor : context.colors.textMuted,
                      size: 16),
                  const SizedBox(height: 2),
                  Text(ref,
                      style: TextStyle(
                          color: available ? iconColor : context.colors.textMuted,
                          fontSize: 8,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
          ),
          title: Text(title,
              style: TextStyle(
                  color: available ? context.colors.textPrimary : context.colors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subtitle,
                style: TextStyle(color: context.colors.textMuted, fontSize: 10.5)),
          ),
          trailing: inSelectMode
              ? null
              : available
                  ? isGenerating
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary))
                      : IconButton(
                          icon: const Icon(Icons.download_outlined),
                          color: AppColors.primary,
                          iconSize: 22,
                          tooltip: 'Download $ref',
                          onPressed: _generating == null ? onDownload : null)
                  : Tooltip(
                      message: 'Complete this step to unlock',
                      child: Icon(Icons.lock_outline,
                          size: 18,
                          color: context.colors.textMuted.withValues(alpha: 0.5))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          isThreeLine: false,
        ),
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
            'PDFs follow the ${_org.orgName} Operations Manual Annex A '
            'format (Rev. 2.0). Forms are populated from the data entered '
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
