import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../database/database_helper.dart';
import '../../models/aircraft.dart';
import '../../services/org_settings_service.dart';
import '../../services/pdf_generator_service.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bar_title.dart';

class BatteryLogScreen extends StatefulWidget {
  const BatteryLogScreen({super.key});

  @override
  State<BatteryLogScreen> createState() => _BatteryLogScreenState();
}

class _BatteryLogScreenState extends State<BatteryLogScreen> {
  final _batteryIdCtrl = TextEditingController();
  final _voltageAfterCtrl = TextEditingController();
  final _chargeTimeCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  List<TextEditingController> _cellCtrls = [];
  String _batteryType = '4S';
  int? _cyclePreview;

  List<Aircraft> _aircraft = [];
  int? _selectedAircraftId;
  DateTime? _logDate;
  String _status = 'good';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isExporting = false;

  static const _batteryTypes = ['1S', '2S', '3S', '4S', '6S', '8S', '10S', '12S', '14S'];
  static const _statuses = ['good', 'degraded', 'retired'];

  @override
  void initState() {
    super.initState();
    _cellCtrls = List.generate(_cellCountFor(_batteryType), (_) => TextEditingController());
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
    _voltageAfterCtrl.dispose();
    _chargeTimeCtrl.dispose();
    _remarksCtrl.dispose();
    for (final c in _cellCtrls) { c.dispose(); }
    super.dispose();
  }

  int _cellCountFor(String type) => int.tryParse(type.replaceAll('S', '')) ?? 1;

  double get _totalVoltage =>
      _cellCtrls.fold(0.0, (sum, c) => sum + (double.tryParse(c.text) ?? 0.0));

  void _onTypeChanged(String type) {
    final newCount = _cellCountFor(type);
    final old = List<TextEditingController>.from(_cellCtrls);
    setState(() {
      _batteryType = type;
      _cellCtrls = List.generate(
        newCount,
        (i) => i < old.length ? old[i] : TextEditingController(),
      );
    });
    old.skip(newCount).forEach((c) => c.dispose());
  }

  Future<void> _updateCyclePreview(String batteryId) async {
    final trimmed = batteryId.trim();
    if (trimmed.isEmpty) {
      if (mounted) setState(() => _cyclePreview = null);
      return;
    }
    final count = await DatabaseHelper.instance.getBatteryLogCycleCount(trimmed);
    // Guard: discard result if the field changed while we were awaiting
    if (!mounted || _batteryIdCtrl.text.trim() != trimmed) return;
    setState(() => _cyclePreview = count + 1);
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

    // Capture form state synchronously before any await so a second tap
    // while awaiting cannot produce a duplicate insert.
    final batteryId = _batteryIdCtrl.text.trim();
    final cellVoltages =
        _cellCtrls.map((c) => double.tryParse(c.text) ?? 0.0).toList();
    final voltageBefore = cellVoltages.fold(0.0, (sum, v) => sum + v);
    setState(() => _isSaving = true);

    final profileFut = DatabaseHelper.instance.getUserProfile();
    final cycleFut = DatabaseHelper.instance.getBatteryLogCycleCount(batteryId);
    final orgId = (await profileFut)?.organizationId ?? '';
    final cycleCount = await cycleFut + 1;
    await DatabaseHelper.instance.insertBatteryLog({
      'battery_id': batteryId,
      'battery_type': _batteryType,
      'aircraft_id': _selectedAircraftId,
      'log_date': _formatDate(_logDate),
      'charge_cycles': cycleCount,
      'cell_voltages': jsonEncode(cellVoltages),
      'voltage_before': voltageBefore > 0 ? voltageBefore : null,
      'voltage_after': double.tryParse(_voltageAfterCtrl.text),
      'charge_time_min': int.tryParse(_chargeTimeCtrl.text),
      'status': _status,
      'remarks': _remarksCtrl.text.trim(),
      'organization_id': orgId,
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    });

    if (!mounted) return;
    setState(() => _isSaving = false);
    await _showSaveResult();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _showSaveResult() async {
    final online = await SyncService.isConnected();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(online
            ? 'Saved — syncing to cloud in background'
            : 'Saved locally — syncs when online'),
        backgroundColor: online ? AppColors.success : AppColors.warning,
        duration: const Duration(seconds: 3),
      ),
    );
    if (online) SyncService.syncToCloud().catchError((_) => false);
  }

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
      if (!mounted) return;
      await PdfGeneratorService.showPdfActions(
          context, bytes, 'A10-BatteryLog-$safeId.pdf');
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
        title: const AppBarTitle(
            title: 'Battery Log', subtitle: 'Log a charge session'),
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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                _section('BATTERY IDENTIFICATION', Icons.battery_full_outlined, [
                  TextField(
                    controller: _batteryIdCtrl,
                    style: TextStyle(
                        color: context.colors.textPrimary, fontSize: 13),
                    onChanged: _updateCyclePreview,
                    decoration: const InputDecoration(
                      labelText: 'Battery ID *',
                      hintText: 'e.g. BAT-001',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _labeledDropdown(
                    label: 'Battery Type',
                    child: DropdownButton<String>(
                      value: _batteryType,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: context.colors.card,
                      style: TextStyle(
                          color: context.colors.textPrimary, fontSize: 13),
                      items: _batteryTypes
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(
                                    '$t  (${_cellCountFor(t)} ${_cellCountFor(t) == 1 ? 'cell' : 'cells'})'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) _onTypeChanged(v);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_aircraft.isEmpty)
                    _infoTile('No aircraft registered. Add one in the More tab.')
                  else
                    _labeledDropdown(
                      label: 'Aircraft (optional)',
                      child: DropdownButton<int?>(
                        value: _selectedAircraftId,
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: context.colors.card,
                        style: TextStyle(
                            color: context.colors.textPrimary, fontSize: 13),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text('None',
                                style: TextStyle(
                                    color: context.colors.textSecondary)),
                          ),
                          ..._aircraft.map((a) =>
                              DropdownMenuItem(value: a.id, child: Text(a.name))),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedAircraftId = v),
                      ),
                    ),
                ]),
                _section('CHARGING LOG', Icons.bolt_outlined, [
                  _dateTile('Log Date *', _logDate, onTap: _pickDate),
                  const SizedBox(height: 10),
                  _cycleInfoTile(),
                  const SizedBox(height: 14),
                  _buildCellGrid(),
                  const SizedBox(height: 10),
                  _field(_voltageAfterCtrl, 'Voltage After Charging (V)',
                      hint: '0.00',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: 10),
                  _field(_chargeTimeCtrl, 'Charge Time (min)',
                      hint: '0', keyboardType: TextInputType.number),
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
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 20),
              label: Text(_isSaving ? 'Saving...' : 'Save Battery Log'),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cycleInfoTile() {
    final battId = _batteryIdCtrl.text.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(Icons.battery_charging_full, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('CHARGE CYCLE',
                style: TextStyle(
                    color: AppColors.primary.withValues(alpha: 0.7),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text(
              _cyclePreview != null
                  ? 'Cycle #$_cyclePreview for "$battId"'
                  : battId.isEmpty
                      ? 'Enter Battery ID above to track cycles'
                      : 'Counting...',
              style: TextStyle(
                color: _cyclePreview != null
                    ? AppColors.primary
                    : context.colors.textSecondary,
                fontSize: 13,
                fontWeight: _cyclePreview != null
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCellGrid() {
    final count = _cellCtrls.length;
    if (count == 0) return const SizedBox.shrink();
    final total = _totalVoltage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(
            'CELL VOLTAGES  —  BEFORE CHARGING',
            style: TextStyle(
                color: context.colors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6),
          ),
          const Spacer(),
          Text(
            '$count cells',
            style: TextStyle(color: context.colors.textMuted, fontSize: 10),
          ),
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (_, constraints) {
            final cellWidth = (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                count,
                (i) => SizedBox(width: cellWidth, child: _cellInput(i)),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: total > 0
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : context.colors.border),
          ),
          child: Row(children: [
            Text('Total starting voltage',
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 12)),
            const Spacer(),
            Text(
              total > 0 ? '${total.toStringAsFixed(2)} V' : '— V',
              style: TextStyle(
                color: total > 0 ? AppColors.primary : context.colors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _cellInput(int i) {
    return TextField(
      controller: _cellCtrls[i],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: (_) => setState(() {}),
      style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: 'Cell ${i + 1}',
        hintText: '0.00',
        isDense: true,
        suffixText: 'V',
        suffixStyle: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _labeledDropdown({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(label,
                style: TextStyle(
                    color: context.colors.textMuted, fontSize: 10)),
          ),
          child,
        ],
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
          Text(title,
              style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {String? hint, int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
      decoration:
          InputDecoration(labelText: label, hintText: hint, isDense: true),
    );
  }

  Widget _dateTile(String label, DateTime? date,
      {required VoidCallback onTap}) {
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
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: TextStyle(
                      color: context.colors.textMuted, fontSize: 10)),
              const SizedBox(height: 2),
              Text(_formatDate(date),
                  style: TextStyle(
                      color: date != null
                          ? context.colors.textPrimary
                          : context.colors.textSecondary,
                      fontSize: 13)),
            ]),
          ),
        ]),
      ),
    );
  }

  String _toLabel(String s) => s
      .split(RegExp(r'[_\-]'))
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Widget _dropdownStr({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.colors.border)),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: context.colors.card,
        style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
        items: items
            .map((s) =>
                DropdownMenuItem(value: s, child: Text(_toLabel(s))))
            .toList(),
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
          border: Border.all(color: context.colors.border)),
      child: Text(msg,
          style:
              TextStyle(color: context.colors.textSecondary, fontSize: 12)),
    );
  }
}
