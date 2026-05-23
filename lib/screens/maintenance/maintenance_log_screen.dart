import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/aircraft.dart';
import '../../services/org_settings_service.dart';
import '../../services/pdf_generator_service.dart';
import '../../theme/app_theme.dart';

class MaintenanceLogScreen extends StatefulWidget {
  const MaintenanceLogScreen({super.key});

  @override
  State<MaintenanceLogScreen> createState() => _MaintenanceLogScreenState();
}

class _MaintenanceLogScreenState extends State<MaintenanceLogScreen> {
  final _descriptionCtrl = TextEditingController();
  final _partsCtrl = TextEditingController();
  final _flightHoursCtrl = TextEditingController();
  final _signedByCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _nextHoursCtrl = TextEditingController();

  List<Aircraft> _aircraft = [];
  int? _selectedAircraftId;
  DateTime? _maintenanceDate;
  DateTime? _nextMaintenanceDate;
  String _maintenanceType = 'scheduled';
  String _airworthinessStatus = 'serviceable';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isExporting = false;  // true while generating A-9 PDF

  static const _maintenanceTypes = [
    'scheduled', 'unscheduled', 'post-incident', 'inspection',
  ];
  static const _airworthinessStatuses = [
    'serviceable', 'under_maintenance', 'unserviceable',
  ];

  @override
  void initState() {
    super.initState();
    _loadAircraft();
  }

  Future<void> _loadAircraft() async {
    final ac = await DatabaseHelper.instance.getAircraft();
    if (mounted) {
      setState(() {
        _aircraft = ac;
        if (ac.isNotEmpty) _selectedAircraftId = ac.first.id;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _partsCtrl.dispose();
    _flightHoursCtrl.dispose();
    _signedByCtrl.dispose();
    _remarksCtrl.dispose();
    _nextHoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isNext}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isNext) {
          _nextMaintenanceDate = picked;
        } else {
          _maintenanceDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Tap to select';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (_maintenanceDate == null ||
        _descriptionCtrl.text.trim().isEmpty ||
        _signedByCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Date, Description, and Signed By are required.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    await DatabaseHelper.instance.insertMaintenanceLog({
      'aircraft_id': _selectedAircraftId,
      'maintenance_date': _formatDate(_maintenanceDate),
      'maintenance_type': _maintenanceType,
      'description': _descriptionCtrl.text.trim(),
      'parts_replaced': _partsCtrl.text.trim(),
      'flight_hours': double.tryParse(_flightHoursCtrl.text),
      'next_maintenance_date': _nextMaintenanceDate != null ? _formatDate(_nextMaintenanceDate) : null,
      'next_maintenance_hours': double.tryParse(_nextHoursCtrl.text),
      'airworthiness_status': _airworthinessStatus,
      'signed_by': _signedByCtrl.text.trim(),
      'remarks': _remarksCtrl.text.trim(),
      'organization_id': '',
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    });

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Maintenance log saved.'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  // ── Export Annex A-9 PDF ────────────────────────────────────────────────────

  Future<void> _exportA9() async {
    if (_selectedAircraftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an aircraft to export its log.')),
      );
      return;
    }
    setState(() => _isExporting = true);
    try {
      final allLogs = await DatabaseHelper.instance.getMaintenanceLogs();
      final logs = allLogs
          .where((l) => l['aircraft_id'] == _selectedAircraftId)
          .toList();
      final aircraft =
          _aircraft.firstWhere((a) => a.id == _selectedAircraftId);
      final org = await OrgSettingsService.load();
      final bytes = await PdfGeneratorService.generateMaintenanceLog(
        aircraft.name,
        aircraft.serialNumber,
        logs,
        org,
      );
      final safeName = aircraft.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
      await PdfGeneratorService.share(bytes, 'A9-MaintenanceLog-$safeName.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Log'),
        actions: [
          if (_isExporting)
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
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Export Annex A-9 PDF',
              onPressed: _isLoading ? null : _exportA9,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                _section('AIRCRAFT', Icons.air, [
                  if (_aircraft.isEmpty)
                    _infoTile('No aircraft registered. Add one in the More tab.')
                  else
                    _dropdown<int>(
                      label: 'Aircraft',
                      value: _selectedAircraftId,
                      items: _aircraft.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                      onChanged: (v) => setState(() => _selectedAircraftId = v),
                    ),
                ]),
                _section('MAINTENANCE DETAILS', Icons.build_outlined, [
                  _dateTile('Maintenance Date *', _maintenanceDate, onTap: () => _pickDate(isNext: false)),
                  const SizedBox(height: 10),
                  _dropdownStr(
                    label: 'Maintenance Type',
                    value: _maintenanceType,
                    items: _maintenanceTypes,
                    onChanged: (v) => setState(() => _maintenanceType = v!),
                  ),
                  const SizedBox(height: 10),
                  _field(_descriptionCtrl, 'Description *', maxLines: 3),
                  const SizedBox(height: 10),
                  _field(_partsCtrl, 'Parts Replaced (optional)'),
                  const SizedBox(height: 10),
                  _field(_flightHoursCtrl, 'Flight Hours at Maintenance', hint: '0.0', keyboardType: TextInputType.number),
                ]),
                _section('AIRWORTHINESS', Icons.verified_outlined, [
                  _dropdownStr(
                    label: 'Airworthiness Status After',
                    value: _airworthinessStatus,
                    items: _airworthinessStatuses,
                    onChanged: (v) => setState(() => _airworthinessStatus = v!),
                  ),
                ]),
                _section('NEXT MAINTENANCE', Icons.schedule_outlined, [
                  _dateTile('Next Maintenance Date (optional)', _nextMaintenanceDate, onTap: () => _pickDate(isNext: true)),
                  const SizedBox(height: 10),
                  _field(_nextHoursCtrl, 'Next Maintenance Hours (optional)', hint: '0.0', keyboardType: TextInputType.number),
                ]),
                _section('SIGN-OFF', Icons.draw_outlined, [
                  _field(_signedByCtrl, 'Signed By *'),
                  const SizedBox(height: 10),
                  _field(_remarksCtrl, 'Remarks (optional)', maxLines: 2),
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
                  : const Icon(Icons.save_outlined, size: 20),
              label: Text(_isSaving ? 'Saving...' : 'Save Maintenance Log'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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

  Widget _field(TextEditingController ctrl, String label, {String? hint, int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
      decoration: InputDecoration(labelText: label, hintText: hint, isDense: true),
    );
  }

  Widget _dateTile(String label, DateTime? date, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.colors.border),
        ),
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

  Widget _dropdown<T>({required String label, required T? value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.colors.border)),
      child: DropdownButton<T>(
        value: value, isExpanded: true, underline: const SizedBox(),
        dropdownColor: context.colors.card,
        style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
        items: items, onChanged: onChanged,
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

  Widget _infoTile(String msg) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Text(msg, style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
    );
  }
}
