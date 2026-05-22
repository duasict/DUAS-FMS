import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/checklist_item.dart';
import '../../database/database_helper.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/checklist_tile.dart';
import 'checklist_widgets.dart';
import 'postflight_checklist_screen.dart';

class InflightChecklistScreen extends StatefulWidget {
  final int missionId;
  final String missionTitle;
  const InflightChecklistScreen(
      {super.key, required this.missionId, required this.missionTitle});

  @override
  State<InflightChecklistScreen> createState() =>
      _InflightChecklistScreenState();
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

class _InflightChecklistScreenState extends State<InflightChecklistScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  static const _defs = [
    ('A. LAUNCH CHECKLIST',
        'GCS final telemetry OK (GPS 3D, AHRS stable)'),
    ('A. LAUNCH CHECKLIST', 'Takeoff clearance given by RPIC'),
    ('A. LAUNCH CHECKLIST', 'VO confirms VLOS maintained'),
    ('B. EN ROUTE CHECKLIST',
        'Telemetry Link Stable; Link strength ≥60%'),
    ('B. EN ROUTE CHECKLIST', 'Flight path followed'),
    ('B. EN ROUTE CHECKLIST', 'Altitude within plan (±10 m)'),
    ('B. EN ROUTE CHECKLIST',
        'Battery ≥30% (VTOL) / ≥20% (Quad)'),
    ('B. EN ROUTE CHECKLIST', 'VO continuously scanning airspace'),
    ('B. EN ROUTE CHECKLIST',
        'Payload recording (video/photo count increasing)'),
    ('B. EN ROUTE CHECKLIST',
        'Weather stable (no sudden gusts/visibility loss)'),
    ('C. CONTINGENCY CHECKLIST',
        'RTH triggered (if link loss >20 sec)'),
    ('C. CONTINGENCY CHECKLIST',
        'Manual takeover executed (if ATTI mode required)'),
    ('C. CONTINGENCY CHECKLIST',
        'Emergency landing initiated (if battery <20%)'),
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
        .getChecklistItems(widget.missionId, 'inflight');
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
        checklistType: 'inflight',
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
      mission.hasInflightComplete = true;
      await provider.updateMission(mission);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => PostflightChecklistScreen(
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
        title: const Text('In-flight Checklist'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ChecklistProgressBar(current: 1),
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
        label: 'Submit & Proceed to Post-flight Checklist',
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
