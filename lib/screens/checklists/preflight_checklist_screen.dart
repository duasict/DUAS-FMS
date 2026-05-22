import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/checklist_item.dart';
import '../../database/database_helper.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/checklist_tile.dart';
import 'checklist_widgets.dart';
import 'inflight_checklist_screen.dart';

class PreflightChecklistScreen extends StatefulWidget {
  final int missionId;
  final String missionTitle;
  const PreflightChecklistScreen(
      {super.key, required this.missionId, required this.missionTitle});

  @override
  State<PreflightChecklistScreen> createState() =>
      _PreflightChecklistScreenState();
}

class _Item {
  final String section;
  final String text;
  int status;
  String remark;
  _Item({required this.section, required this.text})
      : status = 0,
        remark = '';
}

class _PreflightChecklistScreenState
    extends State<PreflightChecklistScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  static const _defs = [
    ('A. MISSION & CREW', 'Flight Plan approved (Ch 3.4)'),
    ('A. MISSION & CREW', 'RPIC assigned and briefed (Annex I signed)'),
    ('A. MISSION & CREW', 'VO assigned (if required; no RPL needed)'),
    ('A. MISSION & CREW',
        'Maintenance Head present (if post-maintenance/new platform)'),
    ('A. MISSION & CREW',
        'Crew fitness confirmed (no fatigue, illness, impairment)'),
    ('B. AIRCRAFT & PAYLOAD',
        'Visual inspection: airframe, arms, motors, props (no cracks/damage)'),
    ('B. AIRCRAFT & PAYLOAD',
        'Propellers: no chips/warping; torque verified (MR: 0.8 Nm, VFW: 1.2 Nm)'),
    ('B. AIRCRAFT & PAYLOAD',
        'Battery: ≥95% charge, ≥3.8 V/cell, no swelling, cycle count logged'),
    ('B. AIRCRAFT & PAYLOAD',
        'Payload: mounted securely, gimbal free-moving, power on'),
    ('B. AIRCRAFT & PAYLOAD',
        'Airworthiness tag: Serviceable (per Annex E)'),
    ('C. GCS & COMMUNICATION',
        'GCS powered, OS/firmware updated, QBase/Mission Planner loaded'),
    ('C. GCS & COMMUNICATION',
        'RC transmitter calibrated, sticks centered, failsafe triggers tested'),
    ('C. GCS & COMMUNICATION',
        'Link test: RSSI ≥70%, latency <100 ms, CSL encrypted (if equipped)'),
    ('C. GCS & COMMUNICATION',
        'Compass & IMU calibrated (green status in GCS)'),
    ('C. GCS & COMMUNICATION',
        'RTH altitude set: ≥120 m AGL (Multi-rotor), ≥200 m AGL (VTOL)'),
    ('D. ENVIRONMENT & SAFETY',
        'NOTAMs checked (no activity in ops area)'),
    ('D. ENVIRONMENT & SAFETY',
        'Weather: wind ≤12 m/s (MR), ≤16 m/s (VFW), no rain/fog'),
    ('D. ENVIRONMENT & SAFETY',
        'VLOS zone confirmed: clear, ≥500 m radius, no obstacles'),
    ('D. ENVIRONMENT & SAFETY', 'Emergency landing zones identified'),
    ('D. ENVIRONMENT & SAFETY',
        'Manned aircraft activity monitored (VO positioned)'),
  ];

  late final List<_Item> _items;

  @override
  void initState() {
    super.initState();
    _items =
        _defs.map((d) => _Item(section: d.$1, text: d.$2)).toList();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final saved = await DatabaseHelper.instance
        .getChecklistItems(widget.missionId, 'preflight');
    if (saved.isNotEmpty) {
      for (var i = 0; i < saved.length && i < _items.length; i++) {
        _items[i].status = saved[i].status;
        _items[i].remark = saved[i].remark;
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  int get _checkedCount => _items.where((i) => i.status != 0).length;

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    final provider = context.read<AppProvider>();
    final navigator = Navigator.of(context);

    final dbItems = _items.asMap().entries.map((e) {
      return ChecklistItem(
        missionId: widget.missionId,
        checklistType: 'preflight',
        section: e.value.section,
        itemIndex: e.key,
        itemText: e.value.text,
        status: e.value.status,
        remark: e.value.remark,
      );
    }).toList();

    await DatabaseHelper.instance.saveChecklistItems(dbItems);

    final mission =
        await DatabaseHelper.instance.getMissionById(widget.missionId);
    if (mission != null) {
      mission.hasPreflightComplete = true;
      await provider.updateMission(mission);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => InflightChecklistScreen(
          missionId: widget.missionId,
          missionTitle: widget.missionTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-flight Checklist'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ChecklistProgressBar(current: 0),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
              children: [
                ChecklistMissionBanner(title: widget.missionTitle),
                const SizedBox(height: 12),
                ..._buildSections(),
              ],
            ),
      bottomNavigationBar: ChecklistSubmitBar(
        label: 'Submit & Proceed to In-flight Checklist',
        checked: _checkedCount,
        total: _items.length,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  List<Widget> _buildSections() {
    final sections = <String>[];
    for (final item in _items) {
      if (!sections.contains(item.section)) sections.add(item.section);
    }
    final widgets = <Widget>[];
    for (final section in sections) {
      widgets.add(ChecklistSectionHeader(label: section));
      final sectionItems =
          _items.where((i) => i.section == section).toList();
      for (final item in sectionItems) {
        final idx = _items.indexOf(item);
        widgets.add(ChecklistTile(
          text: item.text,
          status: item.status,
          remark: item.remark,
          onChanged: (s, r) => setState(() {
            _items[idx].status = s;
            _items[idx].remark = r;
          }),
        ));
      }
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }
}
