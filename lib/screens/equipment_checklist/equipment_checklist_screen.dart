import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../models/checklist_item.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../widgets/checklist_tile.dart';
import '../checklists/checklist_widgets.dart';
import '../fit_to_fly/fit_to_fly_screen.dart';

class EquipmentChecklistScreen extends StatefulWidget {
  final int missionId;
  final String missionTitle;
  const EquipmentChecklistScreen(
      {super.key, required this.missionId, required this.missionTitle});

  @override
  State<EquipmentChecklistScreen> createState() =>
      _EquipmentChecklistScreenState();
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

class _EquipmentChecklistScreenState extends State<EquipmentChecklistScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  static const _defs = [
    ('A. LI-ION BATTERIES', 'Battery cells ≥3.8V/cell, no swelling or damage'),
    ('A. LI-ION BATTERIES', 'Charge level: ≥95% for deployment'),
    ('A. LI-ION BATTERIES', 'Cycle count logged in maintenance record'),
    ('A. LI-ION BATTERIES', 'Battery storage bag / fireproof case ready'),
    ('B. PROPELLERS', 'Propellers inspected: no cracks, chips, or warping'),
    ('C. GCS & RADIOS', 'GCS/tablet powered and connected'),
    ('C. GCS & RADIOS', 'RC transmitter charged, bound, and calibrated'),
    ('C. GCS & RADIOS', 'Communication radios checked and operational'),
    ('C. GCS & RADIOS', 'Backup communication device available'),
    ('D. UAS/RPAS', 'Airframe: no visible damage, all arms secured'),
    ('D. UAS/RPAS', 'Motors: spin freely, no unusual sounds'),
    ('D. UAS/RPAS', 'Gimbal: powered, level, and free-moving'),
    ('D. UAS/RPAS', 'SD card / storage media inserted and formatted'),
    ('D. UAS/RPAS', 'GPS/GNSS antenna: clear of obstructions'),
    ('D. UAS/RPAS', 'Airworthiness tag (Annex E): Serviceable'),
  ];

  late final List<_Item> _items;

  @override
  void initState() {
    super.initState();
    _items = _defs.map((d) => _Item(section: d.$1, text: d.$2)).toList();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final saved = await DatabaseHelper.instance
        .getChecklistItems(widget.missionId, 'equipment');
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
        checklistType: 'equipment',
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
      mission.hasEquipmentComplete = true;
      await provider.updateMission(mission);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    navigator.push(MaterialPageRoute(
      builder: (_) => FitToFlyScreen(
        missionId: widget.missionId,
        missionTitle: widget.missionTitle,
      ),
    ));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipment Checklist'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ChecklistProgressBar(
                current: 0, steps: AppConstants.executionChecklistSteps),
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
        label: 'Submit & Proceed to Fit-to-Fly',
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
      final sectionItems = _items.where((i) => i.section == section).toList();
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
