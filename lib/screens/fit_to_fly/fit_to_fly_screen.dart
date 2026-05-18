import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../utils/app_constants.dart';
import '../../models/checklist_item.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/checklist_tile.dart';
import '../checklists/checklist_widgets.dart';
import '../checklists/preflight_checklist_screen.dart';

class FitToFlyScreen extends StatefulWidget {
  final int missionId;
  final String missionTitle;
  const FitToFlyScreen(
      {super.key, required this.missionId, required this.missionTitle});

  @override
  State<FitToFlyScreen> createState() => _FitToFlyScreenState();
}

class _SectionBItem {
  final String section;
  final String text;
  int status;
  String remark;
  _SectionBItem({required this.section, required this.text})
      : status = 0,
        remark = '';
}

class _FitToFlyScreenState extends State<FitToFlyScreen> {
  // Section A controllers
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _missionTypeCtrl = TextEditingController();
  final _rpaModelCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _payloadCtrl = TextEditingController();
  final _picCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  static const _sectionBDefs = [
    ('A. AIRCRAFT CONDITION',
        'Airframe integrity confirmed (no cracks, dents, or loose components)'),
    ('A. AIRCRAFT CONDITION', 'All fasteners tightened and secured'),
    ('A. AIRCRAFT CONDITION', 'Landing gear checked and operational'),
    ('B. PROPULSION SYSTEM',
        'Motors and ESCs inspected (no heat damage, loose wires)'),
    ('B. PROPULSION SYSTEM',
        'Propellers torqued to spec and firmly attached'),
    ('C. POWER SYSTEM',
        'Main battery charged ≥95%, voltage within spec'),
    ('C. POWER SYSTEM',
        'Backup battery (if equipped) charged and tested'),
    ('D. PAYLOAD CHECK',
        'Payload securely mounted, cables routed correctly'),
    ('D. PAYLOAD CHECK',
        'Payload powered on and functional (video feed active)'),
    ('E. CONTROLLER & COMMUNICATION',
        'RC transmitter charged and bound to aircraft'),
    ('E. CONTROLLER & COMMUNICATION',
        'GCS/tablet connected, mission plan uploaded and verified'),
    ('E. CONTROLLER & COMMUNICATION',
        'Telemetry and data links tested (RSSI ≥70%)'),
    ('F. NAVIGATION & SENSORS',
        'GPS lock confirmed (≥8 satellites, HDOP ≤2.0)'),
    ('F. NAVIGATION & SENSORS', 'Compass calibrated, no interference'),
    ('F. NAVIGATION & SENSORS', 'Barometer and IMU stable in GCS'),
  ];

  late final List<_SectionBItem> _sectionB;

  @override
  void initState() {
    super.initState();
    _sectionB =
        _sectionBDefs.map((d) => _SectionBItem(section: d.$1, text: d.$2)).toList();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final mission =
        await DatabaseHelper.instance.getMissionById(widget.missionId);
    if (mission != null) {
      _dateCtrl.text = mission.date;
      _timeCtrl.text = mission.timeStr;
      _locationCtrl.text = mission.location;
      _rpaModelCtrl.text = mission.aircraftName;
      final rpic = mission.crew.where((c) => c.role == 'RPIC').firstOrNull;
      if (rpic != null) _picCtrl.text = rpic.name;
    }

    final savedRecord =
        await DatabaseHelper.instance.getFitToFlyRecord(widget.missionId);
    if (savedRecord != null) {
      _dateCtrl.text = savedRecord['record_date'] ?? _dateCtrl.text;
      _timeCtrl.text = savedRecord['record_time'] ?? _timeCtrl.text;
      _locationCtrl.text = savedRecord['location'] ?? _locationCtrl.text;
      _missionTypeCtrl.text = savedRecord['mission_type'] ?? '';
      _rpaModelCtrl.text = savedRecord['rpa_model'] ?? _rpaModelCtrl.text;
      _serialCtrl.text = savedRecord['serial_number'] ?? '';
      _payloadCtrl.text = savedRecord['payload'] ?? '';
      _picCtrl.text = savedRecord['pic'] ?? _picCtrl.text;
    }

    final savedItems = await DatabaseHelper.instance
        .getChecklistItems(widget.missionId, 'fittofly');
    if (savedItems.isNotEmpty) {
      for (var i = 0; i < savedItems.length && i < _sectionB.length; i++) {
        _sectionB[i].status = savedItems[i].status;
        _sectionB[i].remark = savedItems[i].remark;
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _locationCtrl.dispose();
    _missionTypeCtrl.dispose();
    _rpaModelCtrl.dispose();
    _serialCtrl.dispose();
    _payloadCtrl.dispose();
    _picCtrl.dispose();
    super.dispose();
  }

  int get _checkedCount =>
      _sectionB.where((i) => i.status != 0).length;

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    final provider = context.read<AppProvider>();
    final navigator = Navigator.of(context);

    await DatabaseHelper.instance.saveFitToFlyRecord({
      'mission_id': widget.missionId,
      'record_date': _dateCtrl.text.trim(),
      'record_time': _timeCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'mission_type': _missionTypeCtrl.text.trim(),
      'rpa_model': _rpaModelCtrl.text.trim(),
      'serial_number': _serialCtrl.text.trim(),
      'payload': _payloadCtrl.text.trim(),
      'pic': _picCtrl.text.trim(),
    });

    final dbItems = _sectionB.asMap().entries.map((e) {
      return ChecklistItem(
        missionId: widget.missionId,
        checklistType: 'fittofly',
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
      mission.hasFitToFlyComplete = true;
      await provider.updateMission(mission);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    navigator.push(MaterialPageRoute(
      builder: (_) => PreflightChecklistScreen(
        missionId: widget.missionId,
        missionTitle: widget.missionTitle,
      ),
    ));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fit-to-Fly Clearance'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ChecklistProgressBar(current: 1, steps: AppConstants.executionChecklistSteps),
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
                _sectionACard(),
                SizedBox(height: 4),
                ..._buildSectionB(),
              ],
            ),
      bottomNavigationBar: ChecklistSubmitBar(
        label: 'Confirm Fit-to-Fly & Proceed to Pre-flight',
        checked: _checkedCount,
        total: _sectionB.length,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  Widget _sectionACard() {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.assignment_outlined,
              size: 14, color: context.colors.textMuted),
          SizedBox(width: 7),
          Text('SECTION A — FLIGHT RECORD',
              style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _field(_dateCtrl, 'Date')),
          const SizedBox(width: 10),
          Expanded(child: _field(_timeCtrl, 'Time')),
        ]),
        const SizedBox(height: 10),
        _field(_locationCtrl, 'Location'),
        const SizedBox(height: 10),
        _field(_missionTypeCtrl, 'Mission Type',
            hint: 'e.g. Survey, Inspection, SAR, Agriculture'),
        SizedBox(height: 10),
        Row(children: [
          Expanded(child: _field(_rpaModelCtrl, 'RPA Model')),
          SizedBox(width: 10),
          Expanded(child: _field(_serialCtrl, 'Serial Number')),
        ]),
        SizedBox(height: 10),
        _field(_payloadCtrl, 'Payload Installed',
            hint: 'e.g. Multispectral, RGB Camera, LiDAR'),
        SizedBox(height: 10),
        _field(_picCtrl, 'PIC — Person in Command'),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {String? hint}) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  List<Widget> _buildSectionB() {
    final sections = <String>[];
    for (final item in _sectionB) {
      if (!sections.contains(item.section)) sections.add(item.section);
    }
    final widgets = <Widget>[];
    widgets.add(const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(Icons.checklist_outlined,
            size: 14, color: AppColors.accent),
        SizedBox(width: 7),
        Text('SECTION B — PRE-FLIGHT CONDITION CHECK',
            style: TextStyle(
                color: AppColors.accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      ]),
    ));
    for (final section in sections) {
      widgets.add(ChecklistSectionHeader(label: section));
      final sectionItems =
          _sectionB.where((i) => i.section == section).toList();
      for (final item in sectionItems) {
        final idx = _sectionB.indexOf(item);
        widgets.add(ChecklistTile(
          text: item.text,
          status: item.status,
          remark: item.remark,
          onChanged: (s, r) => setState(() {
            _sectionB[idx].status = s;
            _sectionB[idx].remark = r;
          }),
        ));
      }
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }
}
