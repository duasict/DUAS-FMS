import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../models/mission.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MissionEditScreen
//
//  Allows a CRP to edit a mission's content fields while its status is
//  'planning'. Aircraft and crew are shown read-only — change those by
//  cancelling and recreating the mission.
//
//  Only editable when status == 'planning'; the screen is not reachable
//  otherwise (the Edit button is hidden in MissionDetailsScreen).
// ─────────────────────────────────────────────────────────────────────────────

class MissionEditScreen extends StatefulWidget {
  final Mission mission;
  const MissionEditScreen({super.key, required this.mission});

  @override
  State<MissionEditScreen> createState() => _MissionEditScreenState();
}

class _MissionEditScreenState extends State<MissionEditScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _objectiveCtrl;
  late final TextEditingController _crpNotesCtrl;

  late DateTime _date;
  late TimeOfDay _time;
  late String _environment;
  late bool _crpConcurrenceRequired;

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
    final m = widget.mission;

    _titleCtrl   = TextEditingController(text: m.title);
    _locationCtrl = TextEditingController(text: m.location);
    _objectiveCtrl = TextEditingController(text: m.objective);
    _crpNotesCtrl  = TextEditingController(text: m.crpAdvisoryNotes);

    // Parse stored date string (YYYY-MM-DD)
    final parts = m.date.split('-');
    _date = parts.length == 3
        ? DateTime(
            int.tryParse(parts[0]) ?? DateTime.now().year,
            int.tryParse(parts[1]) ?? 1,
            int.tryParse(parts[2]) ?? 1,
          )
        : DateTime.now();

    // Parse stored time string (HH:MM)
    final tParts = m.timeStr.split(':');
    _time = tParts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(tParts[0]) ?? 0,
            minute: int.tryParse(tParts[1]) ?? 0,
          )
        : const TimeOfDay(hour: 6, minute: 0);

    // Clamp stored environment to known list
    _environment = _environments.contains(m.environment)
        ? m.environment
        : _environments.first;

    _crpConcurrenceRequired = m.crpConcurrenceRequired;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _objectiveCtrl.dispose();
    _crpNotesCtrl.dispose();
    super.dispose();
  }

  // ── Pickers ───────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _dateStr =>
      '${_date.year}-'
      '${_date.month.toString().padLeft(2, '0')}-'
      '${_date.day.toString().padLeft(2, '0')}';

  String get _timeStr =>
      '${_time.hour.toString().padLeft(2, '0')}:'
      '${_time.minute.toString().padLeft(2, '0')}';

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final title    = _titleCtrl.text.trim();
    final location = _locationCtrl.text.trim();
    final objective = _objectiveCtrl.text.trim();

    if (title.isEmpty || location.isEmpty || objective.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Title, location, and objective are required.'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }

    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    final provider  = context.read<AppProvider>();

    // Apply edits to a copy so original is unchanged on failure
    final updated = widget.mission
      ..title                  = title
      ..date                   = _dateStr
      ..timeStr                = _timeStr
      ..location               = location
      ..environment            = _environment
      ..objective              = objective
      ..crpAdvisoryNotes       = _crpNotesCtrl.text.trim()
      ..crpConcurrenceRequired = _crpConcurrenceRequired
      ..isSynced               = false; // mark dirty for next sync

    await DatabaseHelper.instance.updateMission(updated);
    await provider.refreshMissions();

    if (!mounted) return;
    setState(() => _isSaving = false);
    navigator.pop(true); // pop with `true` so caller knows to reload
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit  ${widget.mission.missionId}',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
        ),
        actions: [
          if (_isSaving)
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
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          // ── Read-only ID chip ───────────────────────────────────────
          _readonlyField('Mission ID', widget.mission.missionId,
              icon: Icons.tag, mono: true),
          const SizedBox(height: 18),

          // ── Editable fields ─────────────────────────────────────────
          _sectionHeader(Icons.info_outline, 'Mission Details'),
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
          const SizedBox(height: 18),

          // ── Read-only aircraft ──────────────────────────────────────
          _sectionHeader(Icons.air, 'Aircraft (read-only)'),
          _readonlyField('Platform', widget.mission.aircraftName,
              icon: Icons.air),
          const SizedBox(height: 18),

          // ── CRP Settings ────────────────────────────────────────────
          _sectionHeader(Icons.verified_user_outlined, 'CRP Settings'),
          _inputField(_crpNotesCtrl, 'CRP Advisory Notes',
              hint: 'Optional notes for the crew...',
              maxLines: 2),
          const SizedBox(height: 12),
          _toggleRow(
            'Require CRP Concurrence',
            'Mission needs CRP approval before execution',
            _crpConcurrenceRequired,
            (v) => setState(() => _crpConcurrenceRequired = v),
          ),
          const SizedBox(height: 24),

          // ── Save button (also in app bar) ───────────────────────────
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Private widget helpers ────────────────────────────────────────────────

  Widget _sectionHeader(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 14, color: AppColors.primaryLight),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: AppColors.primaryLight,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      ]),
    );
  }

  Widget _readonlyField(String label, String value,
      {IconData? icon, bool mono = false}) {
    return Builder(builder: (context) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: context.colors.textMuted),
              const SizedBox(width: 6),
            ],
            Text(value,
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                    fontFamily: mono ? 'monospace' : null)),
          ]),
        ]),
      );
    });
  }

  Widget _inputField(
    TextEditingController ctrl,
    String label, {
    String hint = '',
    int maxLines = 1,
  }) {
    return Builder(builder: (context) {
      return TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle:
              TextStyle(color: context.colors.textMuted, fontSize: 12),
          hintStyle:
              TextStyle(color: context.colors.textMuted, fontSize: 12),
          filled: true,
          fillColor: context.colors.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: context.colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
    });
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Builder(builder: (context) {
      return DropdownButtonFormField<String>(
        initialValue: value,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
        style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
        dropdownColor: context.colors.card,
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(color: context.colors.textMuted, fontSize: 12),
          filled: true,
          fillColor: context.colors.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: context.colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
    });
  }

  Widget _toggleRow(
      String title, String subtitle, bool value, void Function(bool) onChanged) {
    return Builder(builder: (context) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: context.colors.textMuted, fontSize: 11)),
                ]),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ]),
      );
    });
  }
}
