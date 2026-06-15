import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../models/equipment_item.dart';
import '../../utils/app_constants.dart';
import '../../models/checklist_item.dart';
import '../../models/crew_member.dart';
import '../../models/mission.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bar_title.dart';
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

class _FitToFlyScreenState extends State<FitToFlyScreen> {
  // Section A controllers
  final _dateCtrl        = TextEditingController();
  final _timeCtrl        = TextEditingController();
  final _locationCtrl    = TextEditingController();
  final _missionTypeCtrl = TextEditingController();
  final _rpaModelCtrl    = TextEditingController();
  final _serialCtrl      = TextEditingController();
  final _payloadCtrl     = TextEditingController();
  final _picCtrl         = TextEditingController();

  bool _isLoading = true;
  bool _isSaving  = false;

  // Timestamp
  String _timeStarted = '';

  // Battery slots
  int _batteriesNeeded = 1;
  List<EquipmentItem> _availableBatteries = [];
  List<int?> _selectedBatteryIds = [null];

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

  late final List<ChecklistEntry> _sectionB;

  @override
  void initState() {
    super.initState();
    _sectionB =
        _sectionBDefs.map((d) => ChecklistEntry(section: d.$1, text: d.$2)).toList();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final db = DatabaseHelper.instance;

    final results = await Future.wait([
      db.getMissionById(widget.missionId),
      db.getCrewForMission(widget.missionId),
      db.getFitToFlyRecord(widget.missionId),
      db.getChecklistItems(widget.missionId, 'fittofly'),
      db.getChecklistTimestamp(widget.missionId, 'fittofly'),
      db.getMissionEquipment(widget.missionId),
      db.getFitToFlyBatteries(widget.missionId),
    ]);

    final mission      = results[0] as Mission?;
    final crew         = results[1] as List<CrewMember>;
    final savedRecord  = results[2] as Map<String, dynamic>?;
    final savedItems   = results[3] as List<ChecklistItem>;
    final ts           = results[4] as Map<String, dynamic>?;
    final missionEquip = results[5] as List<Map<String, dynamic>>;
    final savedSlots   = results[6] as List<Map<String, dynamic>>;

    if (mission != null) {
      _dateCtrl.text     = mission.date;
      _timeCtrl.text     = mission.timeStr;
      _locationCtrl.text = mission.location;
      _rpaModelCtrl.text = mission.aircraftName;
      if (mission.aircraftId != null) {
        final aircraft = await db.getAircraftById(mission.aircraftId!);
        if (aircraft != null) _batteriesNeeded = aircraft.batteriesNeeded;
      }
    }

    final rpic = crew.firstWhere(
      (c) => c.role.toLowerCase() == 'rpic',
      orElse: () => CrewMember(missionId: widget.missionId, name: '', role: ''),
    );
    if (rpic.name.isNotEmpty) _picCtrl.text = rpic.name;

    if (savedRecord != null) {
      _dateCtrl.text        = savedRecord['record_date'] ?? _dateCtrl.text;
      _timeCtrl.text        = savedRecord['record_time'] ?? _timeCtrl.text;
      _locationCtrl.text    = savedRecord['location'] ?? _locationCtrl.text;
      _missionTypeCtrl.text = savedRecord['mission_type'] ?? '';
      _rpaModelCtrl.text    = savedRecord['rpa_model'] ?? _rpaModelCtrl.text;
      _serialCtrl.text      = savedRecord['serial_number'] ?? '';
      _payloadCtrl.text     = savedRecord['payload'] ?? '';
      _picCtrl.text         = savedRecord['pic'] ?? _picCtrl.text;
    }

    if (savedItems.isNotEmpty) {
      for (var i = 0; i < savedItems.length && i < _sectionB.length; i++) {
        _sectionB[i].status = savedItems[i].status;
        _sectionB[i].remark = savedItems[i].remark;
      }
    }

    final savedStart = ts?['time_started'] as String? ?? '';
    if (savedStart.isNotEmpty) {
      _timeStarted = savedStart;
    } else {
      final now = DateTime.now();
      _timeStarted =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }

    _availableBatteries = missionEquip
        .where((e) => e['type'] == 'battery')
        .map(EquipmentItem.fromMap)
        .toList();
    if (_availableBatteries.isEmpty) {
      final all = await db.getEquipmentByType('battery');
      _availableBatteries = all.map(EquipmentItem.fromMap).toList();
    }

    _selectedBatteryIds = List.filled(_batteriesNeeded, null);
    for (final slot in savedSlots) {
      final idx = slot['slot_index'] as int? ?? 0;
      if (idx < _batteriesNeeded) {
        _selectedBatteryIds[idx] = slot['equipment_id'] as int?;
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

  int get _checkedCount => _sectionB.where((i) => i.status != 0).length;

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    final provider = context.read<AppProvider>();
    final navigator = Navigator.of(context);

    final now = DateTime.now();
    final timeCompleted =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final slots = [
      for (var i = 0; i < _selectedBatteryIds.length; i++)
        {'slot_index': i, 'equipment_id': _selectedBatteryIds[i], 'battery_label': ''},
    ];

    final dbItems = _sectionB.asMap().entries.map((e) => ChecklistItem(
      missionId: widget.missionId,
      checklistType: 'fittofly',
      section: e.value.section,
      itemIndex: e.key,
      itemText: e.value.text,
      status: e.value.status,
      remark: e.value.remark,
    )).toList();

    await Future.wait([
      DatabaseHelper.instance.saveChecklistTimestamp(
        widget.missionId, 'fittofly',
        timeStarted: _timeStarted,
        timeCompleted: timeCompleted,
      ),
      DatabaseHelper.instance.saveFitToFlyRecord({
        'mission_id':    widget.missionId,
        'record_date':   _dateCtrl.text.trim(),
        'record_time':   _timeCtrl.text.trim(),
        'location':      _locationCtrl.text.trim(),
        'mission_type':  _missionTypeCtrl.text.trim(),
        'rpa_model':     _rpaModelCtrl.text.trim(),
        'serial_number': _serialCtrl.text.trim(),
        'payload':       _payloadCtrl.text.trim(),
        'pic':           _picCtrl.text.trim(),
      }),
      DatabaseHelper.instance.saveFitToFlyBatteries(widget.missionId, slots),
      DatabaseHelper.instance.saveChecklistItems(dbItems),
    ]);

    final mission = await DatabaseHelper.instance.getMissionById(widget.missionId);
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
        title: const AppBarTitle(
            title: 'Fit-to-Fly Clearance', subtitle: 'Pre-mission crew fitness'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: ChecklistProgressBar(
                current: 1, steps: AppConstants.executionChecklistSteps),
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
                const SizedBox(height: 8),
                _TimestampBadge(timeStarted: _timeStarted),
                const SizedBox(height: 12),
                _sectionACard(),
                const SizedBox(height: 8),
                _batterySelectionCard(),
                const SizedBox(height: 4),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.assignment_outlined, size: 14, color: context.colors.textMuted),
          const SizedBox(width: 7),
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
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _field(_rpaModelCtrl, 'RPA Model')),
          const SizedBox(width: 10),
          Expanded(child: _field(_serialCtrl, 'Serial Number')),
        ]),
        const SizedBox(height: 10),
        _field(_payloadCtrl, 'Payload Installed',
            hint: 'e.g. Multispectral, RGB Camera, LiDAR'),
        const SizedBox(height: 10),
        _field(_picCtrl, 'PIC — Pilot in Command'),
      ]),
    );
  }

  Widget _batterySelectionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.battery_charging_full, size: 14, color: AppColors.success),
          const SizedBox(width: 7),
          Text('BATTERY ASSIGNMENT — $_batteriesNeeded ${_batteriesNeeded == 1 ? 'SLOT' : 'SLOTS'}',
              style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 12),
        if (_availableBatteries.isEmpty)
          Text(
            'No batteries in locker. Add batteries via More → Equipment Locker.',
            style: TextStyle(color: context.colors.textMuted, fontSize: 12),
          )
        else
          ...List.generate(_batteriesNeeded, (i) => _batterySlotDropdown(i)),
      ]),
    );
  }

  Widget _batterySlotDropdown(int slotIndex) {
    return Padding(
      padding: EdgeInsets.only(bottom: slotIndex < _batteriesNeeded - 1 ? 10 : 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Battery ${slotIndex + 1}',
                style: TextStyle(color: context.colors.textMuted, fontSize: 10)),
          ),
          DropdownButton<int?>(
            value: _selectedBatteryIds[slotIndex],
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: context.colors.card,
            style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text('None selected',
                    style: TextStyle(color: context.colors.textSecondary)),
              ),
              ..._availableBatteries.map((b) => DropdownMenuItem(
                    value: b.id,
                    child: Text(
                      '${b.equipmentCode}  ${b.name}'
                      '${b.capacityMah > 0 ? '  (${b.capacityMah} mAh)' : ''}',
                    ),
                  )),
            ],
            onChanged: (v) => setState(() => _selectedBatteryIds[slotIndex] = v),
          ),
        ]),
      ),
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
    final sectionIndices = <String, List<int>>{};
    for (var i = 0; i < _sectionB.length; i++) {
      (sectionIndices[_sectionB[i].section] ??= []).add(i);
    }
    final widgets = <Widget>[];
    widgets.add(const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(Icons.checklist_outlined, size: 14, color: AppColors.accent),
        SizedBox(width: 7),
        Text('SECTION B — PRE-FLIGHT CONDITION CHECK',
            style: TextStyle(
                color: AppColors.accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      ]),
    ));
    for (final entry in sectionIndices.entries) {
      widgets.add(ChecklistSectionHeader(label: entry.key));
      for (final idx in entry.value) {
        widgets.add(ChecklistTile(
          text: _sectionB[idx].text,
          status: _sectionB[idx].status,
          remark: _sectionB[idx].remark,
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

class _TimestampBadge extends StatelessWidget {
  final String timeStarted;
  const _TimestampBadge({required this.timeStarted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.access_time_outlined, size: 13, color: AppColors.primary),
        const SizedBox(width: 7),
        Text('Started: $timeStarted',
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
