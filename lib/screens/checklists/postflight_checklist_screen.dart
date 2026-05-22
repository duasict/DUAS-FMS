import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/checklist_item.dart';
import '../../database/database_helper.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/checklist_tile.dart';
import 'checklist_widgets.dart';
import '../flight_log/flight_log_screen.dart';

class PostflightChecklistScreen extends StatefulWidget {
  final int missionId;
  final String missionTitle;
  const PostflightChecklistScreen(
      {super.key, required this.missionId, required this.missionTitle});

  @override
  State<PostflightChecklistScreen> createState() =>
      _PostflightChecklistScreenState();
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

class _PostflightChecklistScreenState
    extends State<PostflightChecklistScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  static const _defs = [
    ('A. AIRCRAFT & PAYLOAD', 'Aircraft secured, power off'),
    ('A. AIRCRAFT & PAYLOAD', 'Visual inspection: airframe damage'),
    ('A. AIRCRAFT & PAYLOAD', 'Visual inspection: propeller'),
    ('A. AIRCRAFT & PAYLOAD', 'Visual inspection: motor'),
    ('A. AIRCRAFT & PAYLOAD', 'Visual inspection: gimbal alignment'),
    ('A. AIRCRAFT & PAYLOAD', 'Battery cooled and logged'),
    ('A. AIRCRAFT & PAYLOAD',
        'Battery discharged to 3.8 V/cell within 24 hrs'),
    ('A. AIRCRAFT & PAYLOAD', 'Flight Data downloaded'),
    ('A. AIRCRAFT & PAYLOAD',
        'Data offloaded: photos/videos verified and complete'),
    ('B. DOCUMENTATION', 'Flight Log (Annex D) completed'),
    ('B. DOCUMENTATION',
        'Anomalies logged (e.g., link drop, wind shear)'),
    ('B. DOCUMENTATION', 'Debrief conducted (RPIC, VO)'),
    ('C. MAINTENANCE ACTIONS', 'Propellers inspected/replaced'),
    ('C. MAINTENANCE ACTIONS', 'Motors/ESCs checked for heat/dust'),
    ('C. MAINTENANCE ACTIONS', 'Airframe stress points examined'),
    ('C. MAINTENANCE ACTIONS',
        'Next maintenance due: ______ hrs / __________ date'),
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
        .getChecklistItems(widget.missionId, 'postflight');
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
        checklistType: 'postflight',
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
      mission.hasPostflightComplete = true;
      await provider.updateMission(mission);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => FlightLogScreen(
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
        title: const Text('Post-flight Checklist'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ChecklistProgressBar(current: 2),
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
        label: 'Submit & Proceed to Flight Log',
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
