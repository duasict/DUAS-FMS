import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/aircraft.dart';
import '../../services/org_settings_service.dart';
import '../../services/pdf_generator_service.dart';
import '../../theme/app_theme.dart';

class BatteryLogScreen extends StatefulWidget {
  const BatteryLogScreen({super.key});

  @override
  State<BatteryLogScreen> createState() => _BatteryLogScreenState();
}

class _BatteryLogScreenState extends State<BatteryLogScreen> {
  final _batteryIdCtrl = TextEditingController();
  final _chargeCyclesCtrl = TextEditingController();
  final _voltageBeforeCtrl = TextEditingController();
  final _voltageAfterCtrl = TextEditingController();
  final _chargeTimeCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  List<Aircraft> _aircraft = [];
  int? _selectedAircraftId;
  DateTime? _logDate;
  String _status = 'good';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isExporting = false;  // true while generating A-10 PDF

  static const _statuses = ['good', 'degraded', 'retired'];

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
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _batteryIdCtrl.dispose();
    _chargeCyclesCtrl.dispose();
    _voltageBeforeCtrl.dispose();
    _voltageAfterCtrl.dispose();
    _chargeTimeCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _logDate = picked);
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Tap to select';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (_batteryIdCtrl.text.trim().isEmpty || _logDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Battery ID and Log Date are required.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    await DatabaseHelper.instance.insertBatteryLog({
      'battery_id': _batteryIdCtrl.text.trim(),
      'aircraft_id': _selectedAircraftId,
      'log_date': _formatDate(_logDate),
      'charge_cycles': int.tryParse(_chargeCyclesCtrl.text),
      'voltage_before': double.tryParse(_voltageBeforeCtrl.text),
      'voltage_after': double.tryParse(_voltageAfterCtrl.text),
      'charge_time_min': int.tryParse(_chargeTimeCtrl.text),
      'status': _status,
      'remarks': _remarksCtrl.text.trim(),
      'organization_id': '',
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    });

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Battery log saved.'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  // ── Export Annex A-10 PDF ───────────────────────────────────────────────────

  Future<void> _exportA10() async {
    final battId = _batteryIdCtrl.text.trim();
    setState(() => _isExporting = true);
    try {
      final allLogs = await DatabaseHelper.instance.getBatteryLogs();
      final logs = battId.isEmpty
          ? allLogs
          : allLogs.where((l) => l['battery_id'] == battId).toList();
      final label = battId.isEmpty ? 'All Batteries' : battId;
      final org = await OrgSettingsService.load();
      final bytes =
          await PdfGeneratorService.generateBatteryLog(label, logs, org);
      final safeId = label.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
      await PdfGeneratorService.share(bytes, 'A10-BatteryLog-$safeId.pdf');
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
        title: const Text('Battery Log'),
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
              tooltip: 'Export Annex A-10 PDF',
              onPressed: _isLoading ? null : _exportA10,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                _section('BATTERY IDENTIFICATION', Icons.battery_charging_full, [
                  _field(_batteryIdCtrl, 'Battery ID *', hint: 'e.g. BAT-001'),
                  const SizedBox(height: 10),
                  if (_aircraft.isEmpty)
                    _infoTile('No aircraft registered.')
                  else
                    _dropdown<int>(
                      label: 'Aircraft (optional)',
                      value: _selectedAircraftId,
                      items: [
                        DropdownMenuItem(value: null, child: Text('None', style: TextStyle(color: context.colors.textSecondary))),
                        ..._aircraft.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                      ],
                      onChanged: (v) => setState(() => _selectedAircraftId = v),
                    ),
                ]),
                _section('LOG DETAILS', Icons.event_note_outlined, [
                  _dateTile('Log Date *', _logDate, onTap: _pickDate),
                  const SizedBox(height: 10),
                  _field(_chargeCyclesCtrl, 'Charge Cycles', hint: '0', keyboardType: TextInputType.number),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field(_voltageBeforeCtrl, 'Voltage Before (V)', hint: '0.0', keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: _field(_voltageAfterCtrl, 'Voltage After (V)', hint: '0.0', keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 10),
                  _field(_chargeTimeCtrl, 'Charge Time (min)', hint: '0', keyboardType: TextInputType.number),
                ]),
                _section('STATUS', Icons.info_outline, [
                  _dropdownStr(
                    label: 'Battery Status',
                    value: _status,
                    items: _statuses,
                    onChanged: (v) => setState(() => _status = v!),
                  ),
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
              label: Text(_isSaving ? 'Saving...' : 'Save Battery Log'),
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
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.colors.border)),
      child: Text(msg, style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
    );
  }
}
