import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../theme/app_theme.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final _locationCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _immediateActionsCtrl = TextEditingController();
  final _fiveWhysCtrl = TextEditingController();
  final _correctiveActionsCtrl = TextEditingController();
  final _caapRefCtrl = TextEditingController();

  DateTime? _incidentDate;
  TimeOfDay? _incidentTime;
  String _incidentType = 'near_miss';
  String _severity = 'minor';
  bool _reportedToCaap = false;
  bool _isSaving = false;

  static const _incidentTypes = [
    'near_miss', 'accident', 'equipment_failure', 'weather', 'other',
  ];
  static const _severities = ['minor', 'moderate', 'serious', 'fatal'];

  @override
  void dispose() {
    _locationCtrl.dispose();
    _descriptionCtrl.dispose();
    _immediateActionsCtrl.dispose();
    _fiveWhysCtrl.dispose();
    _correctiveActionsCtrl.dispose();
    _caapRefCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _incidentDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _incidentTime = picked);
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Tap to select';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(TimeOfDay? t) {
    if (t == null) return 'Tap to select (optional)';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (_incidentDate == null ||
        _locationCtrl.text.trim().isEmpty ||
        _descriptionCtrl.text.trim().isEmpty ||
        _immediateActionsCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Date, Location, Description, and Immediate Actions are required.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    await DatabaseHelper.instance.insertIncidentReport({
      'incident_date': _formatDate(_incidentDate),
      'incident_time': _incidentTime != null ? _formatTime(_incidentTime) : null,
      'location': _locationCtrl.text.trim(),
      'incident_type': _incidentType,
      'severity': _severity,
      'description': _descriptionCtrl.text.trim(),
      'immediate_actions': _immediateActionsCtrl.text.trim(),
      'five_whys': _fiveWhysCtrl.text.trim(),
      'corrective_actions': _correctiveActionsCtrl.text.trim(),
      'reported_to_caap': _reportedToCaap ? 1 : 0,
      'caap_reference': _reportedToCaap ? _caapRefCtrl.text.trim() : null,
      'organization_id': '',
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    });

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Incident report filed.'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incident Report')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          _section('INCIDENT DETAILS', Icons.warning_amber_outlined, [
            _dateTile('Incident Date *', _incidentDate, onTap: _pickDate),
            const SizedBox(height: 10),
            _timeTile('Incident Time (optional)', _incidentTime, onTap: _pickTime),
            const SizedBox(height: 10),
            _field(_locationCtrl, 'Location *', hint: 'Where did the incident occur?'),
          ]),
          _section('CLASSIFICATION', Icons.category_outlined, [
            _dropdownStr(
              label: 'Incident Type',
              value: _incidentType,
              items: _incidentTypes,
              onChanged: (v) => setState(() => _incidentType = v!),
            ),
            const SizedBox(height: 10),
            _dropdownStr(
              label: 'Severity',
              value: _severity,
              items: _severities,
              onChanged: (v) => setState(() => _severity = v!),
            ),
          ]),
          _section('DESCRIPTION & ACTIONS', Icons.description_outlined, [
            _field(_descriptionCtrl, 'Description *', maxLines: 4,
                hint: 'Describe what happened in detail...'),
            const SizedBox(height: 10),
            _field(_immediateActionsCtrl, 'Immediate Actions Taken *', maxLines: 3,
                hint: 'What was done immediately after the incident?'),
          ]),
          _section('ROOT CAUSE ANALYSIS', Icons.manage_search_outlined, [
            _field(_fiveWhysCtrl, '5 Whys / Root Cause (optional)', maxLines: 3,
                hint: 'Why did this happen? Drill down to the root cause...'),
            const SizedBox(height: 10),
            _field(_correctiveActionsCtrl, 'Corrective Actions (optional)', maxLines: 3,
                hint: 'What measures prevent recurrence?'),
          ]),
          _section('CAAP REPORTING', Icons.gavel_outlined, [
            Row(children: [
              Switch(
                value: _reportedToCaap,
                onChanged: (v) => setState(() => _reportedToCaap = v),
                activeThumbColor: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Reported to CAAP',
                style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
              )),
            ]),
            if (_reportedToCaap) ...[
              const SizedBox(height: 10),
              _field(_caapRefCtrl, 'CAAP Reference Number', hint: 'e.g. CAAP-2025-001'),
            ],
          ]),
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
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_outlined, size: 20),
              label: Text(_isSaving ? 'Filing...' : 'File Incident Report'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 13, color: context.colors.textMuted),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(color: context.colors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {String? hint, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
      decoration: InputDecoration(labelText: label, hintText: hint, isDense: true, alignLabelWithHint: maxLines > 1),
    );
  }

  Widget _dateTile(String label, DateTime? date, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.colors.border)),
        child: Row(children: [
          Icon(Icons.calendar_today, size: 14, color: context.colors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: context.colors.textMuted, fontSize: 10)),
            const SizedBox(height: 2),
            Text(_formatDate(date), style: TextStyle(color: date != null ? context.colors.textPrimary : context.colors.textSecondary, fontSize: 13)),
          ])),
        ]),
      ),
    );
  }

  Widget _timeTile(String label, TimeOfDay? time, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.colors.border)),
        child: Row(children: [
          Icon(Icons.schedule, size: 14, color: context.colors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: context.colors.textMuted, fontSize: 10)),
            const SizedBox(height: 2),
            Text(_formatTime(time), style: TextStyle(color: time != null ? context.colors.textPrimary : context.colors.textSecondary, fontSize: 13)),
          ])),
        ]),
      ),
    );
  }

  Widget _dropdownStr({required String label, required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.colors.border)),
      child: DropdownButton<String>(
        value: value, isExpanded: true, underline: const SizedBox(),
        dropdownColor: context.colors.card,
        style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
        items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
