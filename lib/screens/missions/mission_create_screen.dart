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
  final _crpNotesCtrl = TextEditingController();

  // Fixed crew slots
  final _rpicCtrl = TextEditingController();     // required RPIC
  final _voGcsCtrl = TextEditingController();    // required VO or GCS

  // Extra crew (tech / additional VO)
  final List<TextEditingController> _extraNameCtrls = [];
  final List<String> _extraRoles = [];

  String _voGcsRole = 'vo'; // vo | gcs

  String _generatedId = '';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 6, minute: 0);
  String _environment = 'Rural / Agricultural';
  int? _selectedAircraftId;
  String _selectedAircraftName = '';
  String _selectedAircraftType = 'multi-rotor';

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

  static const _extraRoleOptions = ['vo', 'gcs', 'tech'];

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
    _crpNotesCtrl.dispose();
    _rpicCtrl.dispose();
    _voGcsCtrl.dispose();
    for (final c in _extraNameCtrls) {
      c.dispose();
    }
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
            colorScheme:
                Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary)),
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
            colorScheme:
                Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (t != null) setState(() => _time = t);
  }

  void _addCrewRow() {
    setState(() {
      _extraNameCtrls.add(TextEditingController());
      _extraRoles.add('tech');
    });
  }

  void _removeCrewRow(int i) {
    setState(() {
      _extraNameCtrls[i].dispose();
      _extraNameCtrls.removeAt(i);
      _extraRoles.removeAt(i);
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
        _rpicCtrl.text.trim().isEmpty ||
        _voGcsCtrl.text.trim().isEmpty ||
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
      status: 'planning',
      date: _dateStr,
      timeStr: _timeStr,
      location: _locationCtrl.text.trim(),
      environment: _environment,
      objective: _objectiveCtrl.text.trim(),
      aircraftId: _selectedAircraftId,
      aircraftName: _selectedAircraftName,
      aircraftType: _selectedAircraftType,
      crpAdvisoryNotes: _crpNotesCtrl.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );

    final missionDbId = await DatabaseHelper.instance.insertMission(mission);

    // Crew: 1 RPIC (required) + 1 VO or GCS (required) + extras
    final crew = <Map<String, String>>[
      {'name': _rpicCtrl.text.trim(), 'role': 'rpic'},
      {'name': _voGcsCtrl.text.trim(), 'role': _voGcsRole},
    ];
    for (var i = 0; i < _extraNameCtrls.length; i++) {
      final name = _extraNameCtrls[i].text.trim();
      if (name.isNotEmpty) {
        crew.add({'name': name, 'role': _extraRoles[i]});
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
                // ── Mission Details ──────────────────────────────────────
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
                const SizedBox(height: 12),
                _inputField(_objectiveCtrl, 'Mission Objective *',
                    hint: 'Describe the mission objective...',
                    maxLines: 3),

                // ── Aircraft ─────────────────────────────────────────────
                const SizedBox(height: 20),
                _sectionHeader(Icons.air, 'Aircraft'),
                if (_aircraft.isEmpty)
                  _infoTile(Icons.warning_amber_outlined,
                      'No aircraft in database. Add one in the More tab.')
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: DropdownButton<int>(
                      value: _selectedAircraftId,
                      isExpanded: true,
                      underline: const SizedBox(),
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

                // ── Crew Assignment ──────────────────────────────────────
                const SizedBox(height: 20),
                _sectionHeader(Icons.people_outline, 'Crew Assignment'),
                _infoTile(
                  Icons.info_outline,
                  'Crew rule: exactly 1 RPIC (required) + at least 1 VO or GCS (required).',
                  color: AppColors.accent,
                ),
                const SizedBox(height: 10),

                // RPIC row
                _crewRow(
                  controller: _rpicCtrl,
                  label: 'RPIC — Remote Pilot in Command *',
                  roleDisplay: 'RPIC',
                  roleColor: AppColors.primary,
                ),
                const SizedBox(height: 10),

                // VO / GCS row with role toggle
                _voGcsRow(),

                const SizedBox(height: 10),
                ..._extraCrewRows(),
                TextButton.icon(
                  onPressed: _addCrewRow,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Crew Member'),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.primaryLight),
                ),

                // ── CRP Advisory Notes (optional) ────────────────────────
                const SizedBox(height: 20),
                _sectionHeader(Icons.notes_outlined, 'CRP Advisory Notes'),
                _inputField(_crpNotesCtrl, 'Advisory Notes (optional)',
                    hint:
                        'Operational guidance, cautions, or clearances from CRP...',
                    maxLines: 3),
              ],
            ),
      bottomNavigationBar: SafeArea(
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

  // ── VO/GCS row with role selector ─────────────────────────────────────────
  Widget _voGcsRow() {
    return Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.visibility_outlined,
            size: 16, color: AppColors.accent),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: TextField(
          controller: _voGcsCtrl,
          style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            labelText: _voGcsRole == 'vo'
                ? 'Visual Observer (VO) *'
                : 'GCS Operator *',
            hintText: 'Full name',
          ),
        ),
      ),
      const SizedBox(width: 8),
      // Role toggle VO / GCS
      Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _roleToggleBtn('VO', 'vo'),
          Container(
              width: 0.5,
              height: 32,
              color: context.colors.border),
          _roleToggleBtn('GCS', 'gcs'),
        ]),
      ),
    ]);
  }

  Widget _roleToggleBtn(String label, String value) {
    final selected = _voGcsRole == value;
    return GestureDetector(
      onTap: () => setState(() => _voGcsRole = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.accent : context.colors.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  List<Widget> _extraCrewRows() {
    return List.generate(_extraNameCtrls.length, (i) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.colors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.border),
            ),
            child: Icon(Icons.person, size: 16, color: context.colors.textMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _extraNameCtrls[i],
              style:
                  TextStyle(color: context.colors.textPrimary, fontSize: 13),
              decoration: const InputDecoration(labelText: 'Name'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.border),
              ),
              child: DropdownButton<String>(
                value: _extraRoles[i],
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: context.colors.card,
                style: TextStyle(
                    color: context.colors.textPrimary, fontSize: 12),
                items: _extraRoleOptions.map((r) {
                  return DropdownMenuItem<String>(
                    value: r,
                    child: Text(r.toUpperCase()),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _extraRoles[i] = v!),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _removeCrewRow(i),
            icon: const Icon(Icons.remove_circle_outline,
                color: AppColors.danger, size: 20),
          ),
        ]),
      );
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _crewRow({
    required TextEditingController controller,
    required String label,
    required String roleDisplay,
    required Color roleColor,
  }) {
    return Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: roleColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person, size: 16, color: roleColor),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: TextField(
          controller: controller,
          style:
              TextStyle(color: context.colors.textPrimary, fontSize: 13),
          decoration: InputDecoration(labelText: label),
        ),
      ),
    ]);
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(children: [
        Icon(icon, size: 15, color: AppColors.accent),
        const SizedBox(width: 7),
        Text(title.toUpperCase(),
            style: const TextStyle(
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
      style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: context.colors.textMuted),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: context.colors.textMuted, fontSize: 10)),
              const SizedBox(height: 2),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: context.colors.card,
        style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
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

  Widget _infoTile(IconData icon, String msg, {Color? color}) {
    final c = color ?? context.colors.textMuted;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 10),
        Expanded(
          child: Text(msg,
              style: TextStyle(color: c, fontSize: 12, height: 1.4)),
        ),
      ]),
    );
  }
}
