import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../models/aircraft.dart';
import '../../models/crew_member.dart';
import '../../models/mission.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../mission_details/mission_details_screen.dart';

class MissionCreateScreen extends StatefulWidget {
  const MissionCreateScreen({super.key});

  @override
  State<MissionCreateScreen> createState() => _MissionCreateScreenState();
}

class _MissionCreateScreenState extends State<MissionCreateScreen> {
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _objectiveCtrl = TextEditingController();
  final _hazardRiskCtrl = TextEditingController();
  final _approvedByCtrl = TextEditingController();
  final _rpicCtrl = TextEditingController();
  final _voCtrl = TextEditingController();

  String _generatedId = '';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 6, minute: 0);
  String _environment = 'Rural / Agricultural';
  String _riskLevel = 'low';
  int? _selectedAircraftId;
  String _selectedAircraftName = '';
  String _selectedAircraftType = 'multi-rotor';

  final List<TextEditingController> _extraNameCtrls = [];
  final List<TextEditingController> _extraRoleCtrls = [];

  List<Aircraft> _aircraft = [];
  bool _isLoading = true;
  bool _isSaving = false;

  static const _environments = [
    'Rural / Agricultural',
    'Urban / Infrastructure',
    'Mountainous / Remote',
    'Coastal / Maritime',
    'Industrial / Commercial',
    'Training Area',
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ac = await DatabaseHelper.instance.getAircraft();
    final id = await DatabaseHelper.instance.nextMissionId();
    if (!mounted) return;
    setState(() {
      _aircraft = ac;
      _generatedId = id;
      if (ac.isNotEmpty) {
        _selectedAircraftId = ac.first.id;
        _selectedAircraftName = ac.first.name;
        _selectedAircraftType = ac.first.type;
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _objectiveCtrl.dispose();
    _hazardRiskCtrl.dispose();
    _approvedByCtrl.dispose();
    _rpicCtrl.dispose();
    _voCtrl.dispose();
    for (final c in _extraNameCtrls) { c.dispose(); }
    for (final c in _extraRoleCtrls) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx)
                .colorScheme
                .copyWith(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx)
                .colorScheme
                .copyWith(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (t != null) setState(() => _time = t);
  }

  void _addCrewRow() {
    setState(() {
      _extraNameCtrls.add(TextEditingController());
      _extraRoleCtrls.add(TextEditingController(text: 'Tech'));
    });
  }

  void _removeCrewRow(int i) {
    setState(() {
      _extraNameCtrls[i].dispose();
      _extraRoleCtrls[i].dispose();
      _extraNameCtrls.removeAt(i);
      _extraRoleCtrls.removeAt(i);
    });
  }

  String get _timeStr =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  String get _dateStr =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty ||
        _locationCtrl.text.trim().isEmpty ||
        _objectiveCtrl.text.trim().isEmpty ||
        _hazardRiskCtrl.text.trim().isEmpty ||
        _approvedByCtrl.text.trim().isEmpty ||
        _rpicCtrl.text.trim().isEmpty ||
        _voCtrl.text.trim().isEmpty ||
        _selectedAircraftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill in all required fields.'),
            backgroundColor: AppColors.danger),
      );
      return;
    }

    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    final provider = context.read<AppProvider>();

    final mission = Mission(
      missionId: _generatedId,
      title: _titleCtrl.text.trim(),
      status: 'approved',
      date: _dateStr,
      timeStr: _timeStr,
      location: _locationCtrl.text.trim(),
      environment: _environment,
      objective: _objectiveCtrl.text.trim(),
      aircraftId: _selectedAircraftId,
      aircraftName: _selectedAircraftName,
      aircraftType: _selectedAircraftType,
      hazardRisk: _hazardRiskCtrl.text.trim(),
      riskLevel: _riskLevel,
      approvedBy: _approvedByCtrl.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );

    final missionDbId = await DatabaseHelper.instance.insertMission(mission);

    final crew = <Map<String, String>>[
      {'name': _rpicCtrl.text.trim(), 'role': 'RPIC'},
      {'name': _voCtrl.text.trim(), 'role': 'VO/GCS'},
    ];
    for (var i = 0; i < _extraNameCtrls.length; i++) {
      final name = _extraNameCtrls[i].text.trim();
      if (name.isNotEmpty) {
        crew.add({
          'name': name,
          'role': _extraRoleCtrls[i].text.trim().isEmpty
              ? 'Tech'
              : _extraRoleCtrls[i].text.trim(),
        });
      }
    }
    for (final m in crew) {
      await DatabaseHelper.instance.insertCrewMember(
          CrewMember(missionId: missionDbId, name: m['name']!, role: m['role']!));
    }

    await provider.refreshMissions();
    if (!mounted) return;
    setState(() => _isSaving = false);
    navigator.pushReplacement(
      MaterialPageRoute(
          builder: (_) => MissionDetailsScreen(missionId: missionDbId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Mission')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                _sectionHeader(Icons.info_outline, 'Mission Details'),
                _readonlyField('Mission ID', _generatedId,
                    icon: Icons.tag, mono: true),
                const SizedBox(height: 12),
                _inputField(_titleCtrl, 'Mission Title *',
                    hint: 'e.g. Coastal Survey — Manila Bay'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: _readonlyField('Date *', _dateStr,
                          icon: Icons.calendar_today),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickTime,
                      child: _readonlyField('Time *', _timeStr,
                          icon: Icons.schedule),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                _inputField(_locationCtrl, 'Location *',
                    hint: 'e.g. Davao City, Mindanao'),
                const SizedBox(height: 12),
                _dropdownField(
                  label: 'Environment *',
                  value: _environment,
                  items: _environments,
                  onChanged: (v) => setState(() => _environment = v!),
                ),
                SizedBox(height: 12),
                _inputField(_objectiveCtrl, 'Mission Objective *',
                    hint: 'Describe the mission objective...', maxLines: 3),
                SizedBox(height: 20),
                _sectionHeader(Icons.air, 'Aircraft'),
                if (_aircraft.isEmpty)
                  _infoTile(
                      Icons.warning_amber_outlined, 'No aircraft in database.')
                else
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: DropdownButton<int>(
                      value: _selectedAircraftId,
                      isExpanded: true,
                      underline: SizedBox(),
                      dropdownColor: context.colors.card,
                      style: TextStyle(
                          color: context.colors.textPrimary, fontSize: 14),
                      items: _aircraft.map((a) {
                        return DropdownMenuItem<int>(
                          value: a.id,
                          child: Text(
                              '${a.name}  (${a.type == 'vtol' ? 'VTOL' : 'Multi-rotor'})'),
                        );
                      }).toList(),
                      onChanged: (id) {
                        final ac = _aircraft.firstWhere((a) => a.id == id);
                        setState(() {
                          _selectedAircraftId = id;
                          _selectedAircraftName = ac.name;
                          _selectedAircraftType = ac.type;
                        });
                      },
                    ),
                  ),
                SizedBox(height: 20),
                _sectionHeader(Icons.warning_amber_outlined, 'Hazard & Risk'),
                _inputField(_hazardRiskCtrl, 'Hazard Risk Description *',
                    hint:
                        'Describe environmental hazards, airspace risks...',
                    maxLines: 3),
                SizedBox(height: 12),
                Text('Risk Level *',
                    style: TextStyle(
                        color: context.colors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _riskChip('Low', 'low', AppColors.success),
                    const SizedBox(width: 8),
                    _riskChip('Medium', 'medium', AppColors.warning),
                    const SizedBox(width: 8),
                    _riskChip('High', 'high', AppColors.danger),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionHeader(Icons.verified_outlined, 'Approval'),
                _inputField(_approvedByCtrl, 'Approved By *',
                    hint: 'e.g. Maj. Juan dela Cruz'),
                const SizedBox(height: 20),
                _sectionHeader(Icons.people_outline, 'Crew Assignment'),
                _crewField(_rpicCtrl, 'RPIC (Required) *',
                    role: 'Remote Pilot in Command'),
                SizedBox(height: 10),
                _crewField(_voCtrl, 'VO / GCS Operator (Required) *',
                    role: 'Visual Observer / GCS'),
                SizedBox(height: 10),
                ..._extraCrewRows(),
                TextButton.icon(
                  onPressed: _addCrewRow,
                  icon: Icon(Icons.add, size: 16),
                  label: Text('Add Crew Member'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryLight),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border(top: BorderSide(color: context.colors.border)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _submit,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check, size: 18),
              label: Text(_isSaving ? 'Creating...' : 'Create Mission'),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _extraCrewRows() {
    return List.generate(_extraNameCtrls.length, (i) {
      return Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _extraNameCtrls[i],
                style: TextStyle(
                    color: context.colors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Name',
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: context.colors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: context.colors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: AppColors.primary, width: 2)),
                  filled: true,
                  fillColor: context.colors.surface,
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _extraRoleCtrls[i],
                style: TextStyle(
                    color: context.colors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Role',
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: context.colors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: context.colors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: AppColors.primary, width: 2)),
                  filled: true,
                  fillColor: context.colors.surface,
                ),
              ),
            ),
            IconButton(
              onPressed: () => _removeCrewRow(i),
              icon: Icon(Icons.remove_circle_outline,
                  color: AppColors.danger, size: 20),
            ),
          ],
        ),
      );
    });
  }

  Widget _riskChip(String label, String value, Color color) {
    final selected = _riskLevel == value;
    return GestureDetector(
      onTap: () => setState(() => _riskLevel = value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : context.colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.6)
                  : context.colors.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? color : context.colors.textSecondary,
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(children: [
        Icon(icon, size: 15, color: AppColors.accent),
        SizedBox(width: 7),
        Text(title.toUpperCase(),
            style: TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      ]),
    );
  }

  Widget _inputField(TextEditingController ctrl, String label,
      {String? hint, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style:
          TextStyle(color: context.colors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }

  Widget _readonlyField(String label, String value,
      {IconData? icon, bool mono = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: context.colors.textMuted),
          SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: context.colors.textMuted, fontSize: 10)),
              SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 13,
                      fontFamily: mono ? 'monospace' : null,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: SizedBox(),
        dropdownColor: context.colors.card,
        style:
            TextStyle(color: context.colors.textPrimary, fontSize: 13),
        hint: Text(label,
            style: TextStyle(
                color: context.colors.textSecondary, fontSize: 12)),
        items: items
            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _crewField(TextEditingController ctrl, String label,
      {required String role}) {
    return Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person, size: 16,
            color: AppColors.primaryLight),
      ),
      SizedBox(width: 10),
      Expanded(
        child: TextField(
          controller: ctrl,
          style: TextStyle(
              color: context.colors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            labelText: label,
            hintText: role,
          ),
        ),
      ),
    ]);
  }

  Widget _infoTile(IconData icon, String msg) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: context.colors.textMuted),
        SizedBox(width: 10),
        Text(msg,
            style: TextStyle(
                color: context.colors.textSecondary, fontSize: 13)),
      ]),
    );
  }
}
