import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../models/aircraft.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';

class AircraftFormScreen extends StatefulWidget {
  final Aircraft? aircraft;
  const AircraftFormScreen({super.key, this.aircraft});

  @override
  State<AircraftFormScreen> createState() => _AircraftFormScreenState();
}

class _AircraftFormScreenState extends State<AircraftFormScreen> {
  final _nameCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _mtowCtrl = TextEditingController();

  String _type = 'multi-rotor';
  String _status = 'serviceable';
  bool _isSaving = false;

  bool get _isEdit => widget.aircraft != null;

  static const _types = ['multi-rotor', 'vtol'];
  static const _typeLabels = ['Multi-rotor', 'VTOL Fixed-Wing'];

  static const _statuses = [
    'serviceable',
    'under_maintenance',
    'unserviceable',
  ];
  static const _statusLabels = [
    'Serviceable',
    'Under Maintenance',
    'Unserviceable',
  ];

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final a = widget.aircraft!;
      _nameCtrl.text = a.name;
      _modelCtrl.text = a.model;
      _serialCtrl.text = a.serialNumber;
      _mtowCtrl.text = a.mtow.toString();
      _type = a.type;
      _status = a.status;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _modelCtrl.dispose();
    _serialCtrl.dispose();
    _mtowCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _modelCtrl.text.trim().isEmpty ||
        _serialCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Name, model, and serial number are required.'),
          backgroundColor: AppColors.danger));
      return;
    }

    final mtow = double.tryParse(_mtowCtrl.text.trim()) ?? 0;

    setState(() => _isSaving = true);
    final db = DatabaseHelper.instance;
    final provider = context.read<AppProvider>();
    final navigator = Navigator.of(context);

    final a = Aircraft(
      id: widget.aircraft?.id,
      name: _nameCtrl.text.trim(),
      type: _type,
      model: _modelCtrl.text.trim(),
      serialNumber: _serialCtrl.text.trim(),
      mtow: mtow,
      status: _status,
    );

    if (_isEdit) {
      await db.updateAircraft(a);
    } else {
      await db.insertAircraft(a);
    }

    await provider.refreshAircraft();

    if (!mounted) return;
    setState(() => _isSaving = false);
    navigator.pop();
  }

  Future<void> _delete() async {
    final provider = context.read<AppProvider>();
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.card,
        title: Text('Delete Aircraft',
            style: TextStyle(color: ctx.colors.textPrimary)),
        content: Text(
          'Remove ${widget.aircraft!.name} from the fleet? This cannot be undone.',
          style: TextStyle(color: ctx.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: ctx.colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    await DatabaseHelper.instance.deleteAircraft(widget.aircraft!.id!);
    await provider.refreshAircraft();

    if (!mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Aircraft' : 'New Aircraft'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              tooltip: 'Delete',
              onPressed: _isSaving ? null : _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          _sectionLabel('IDENTIFICATION'),
          const SizedBox(height: 10),
          _field(
            controller: _nameCtrl,
            label: 'Display Name',
            hint: 'e.g. DJI Matrice 350 RTK',
            icon: Icons.label_outline,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _modelCtrl,
            label: 'Model',
            hint: 'e.g. M350 RTK',
            icon: Icons.memory_outlined,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _serialCtrl,
            label: 'Serial Number',
            hint: 'e.g. 1ZNBJ9F0023ABC',
            icon: Icons.qr_code_outlined,
            highlighted: true,
          ),
          const SizedBox(height: 24),
          _sectionLabel('SPECIFICATIONS'),
          const SizedBox(height: 10),
          _dropdownField(
            label: 'Aircraft Type',
            icon: Icons.airplanemode_active_outlined,
            value: _type,
            items: _types,
            labels: _typeLabels,
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 14),
          _field(
            controller: _mtowCtrl,
            label: 'MTOW (kg)',
            hint: 'e.g. 6.47',
            icon: Icons.monitor_weight_outlined,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),
          _sectionLabel('STATUS'),
          const SizedBox(height: 10),
          _statusSelector(),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      _isEdit ? 'Save Changes' : 'Register Aircraft',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          color: context.colors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool highlighted = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon,
            size: 18,
            color: highlighted ? AppColors.primary : context.colors.textMuted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: highlighted
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : context.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        filled: true,
        fillColor: highlighted
            ? AppColors.primary.withValues(alpha: 0.04)
            : context.colors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required List<String> labels,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(children: [
        Icon(icon, size: 18, color: context.colors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: context.colors.card,
              style:
                  TextStyle(color: context.colors.textPrimary, fontSize: 14),
              hint: Text(label,
                  style:
                      TextStyle(color: context.colors.textMuted, fontSize: 14)),
              items: List.generate(
                items.length,
                (i) => DropdownMenuItem(
                    value: items[i], child: Text(labels[i])),
              ),
              onChanged: onChanged,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _statusSelector() {
    return Row(
      children: List.generate(_statuses.length, (i) {
        final s = _statuses[i];
        final selected = _status == s;
        final color = s == 'serviceable'
            ? AppColors.success
            : s == 'under_maintenance'
                ? AppColors.warning
                : AppColors.danger;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _status = s),
            child: Container(
              margin: EdgeInsets.only(right: i < _statuses.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.15)
                    : context.colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: selected
                        ? color.withValues(alpha: 0.6)
                        : context.colors.border,
                    width: selected ? 1.5 : 1),
              ),
              child: Column(children: [
                Icon(
                  s == 'serviceable'
                      ? Icons.check_circle_outline
                      : s == 'under_maintenance'
                          ? Icons.build_outlined
                          : Icons.cancel_outlined,
                  color: selected ? color : context.colors.textMuted,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  _statusLabels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: selected ? color : context.colors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }
}
