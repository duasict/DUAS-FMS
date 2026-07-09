import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../database/database_helper.dart';
import '../../models/equipment_item.dart';
import '../../theme/app_theme.dart';

class EquipmentLockerFormScreen extends StatefulWidget {
  final EquipmentItem? item;
  const EquipmentLockerFormScreen({super.key, this.item});

  @override
  State<EquipmentLockerFormScreen> createState() => _EquipmentLockerFormScreenState();
}

class _EquipmentLockerFormScreenState extends State<EquipmentLockerFormScreen> {
  final _nameCtrl         = TextEditingController();
  final _serialCtrl       = TextEditingController();
  final _modelCtrl        = TextEditingController();
  final _manufacturerCtrl = TextEditingController();
  final _descCtrl         = TextEditingController();
  final _capacityCtrl     = TextEditingController();
  final _locationCtrl     = TextEditingController();
  final _purchaseDateCtrl = TextEditingController();
  final _notesCtrl        = TextEditingController();

  String _type      = 'battery';
  String _battType  = '4S';
  String _condition = 'serviceable';
  bool   _isSaving  = false;

  bool get _isEdit => widget.item != null;

  static const _types = [
    ('battery',        'Battery'),
    ('charger',        'Charger'),
    ('ground_support', 'Ground Support'),
    ('ppe',            'PPE'),
    ('tool',           'Tool'),
    ('other',          'Other'),
  ];

  static const _batteryTypes = [
    '1S','2S','3S','4S','5S','6S','8S','10S','12S','14S',
  ];

  static const _conditions = [
    ('serviceable',   'Serviceable'),
    ('unserviceable', 'Unserviceable'),
    ('retired',       'Retired'),
  ];

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final e = widget.item!;
      _nameCtrl.text         = e.name;
      _serialCtrl.text       = e.serialNumber;
      _modelCtrl.text        = e.model;
      _manufacturerCtrl.text = e.manufacturer;
      _descCtrl.text         = e.description;
      _capacityCtrl.text     = e.capacityMah > 0 ? e.capacityMah.toString() : '';
      _locationCtrl.text     = e.storageLocation;
      _purchaseDateCtrl.text = e.purchaseDate;
      _notesCtrl.text        = e.notes;
      _type      = e.type;
      _battType  = e.batteryType.isNotEmpty ? e.batteryType : '4S';
      _condition = e.condition;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _serialCtrl.dispose();
    _modelCtrl.dispose();
    _manufacturerCtrl.dispose();
    _descCtrl.dispose();
    _capacityCtrl.dispose();
    _locationCtrl.dispose();
    _purchaseDateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Item name is required.'),
          backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _isSaving = true);

    final db    = DatabaseHelper.instance;
    final now   = DateTime.now().toIso8601String();
    final profile = await db.getUserProfile();
    final orgId   = profile?.organizationId ?? '';

    final code = _isEdit
        ? widget.item!.equipmentCode
        : await db.generateEquipmentCode(_type);

    final data = {
      'equipment_code': code,
      'name':           _nameCtrl.text.trim(),
      'type':           _type,
      'serial_number':  _serialCtrl.text.trim(),
      'model':          _modelCtrl.text.trim(),
      'manufacturer':   _manufacturerCtrl.text.trim(),
      'description':    _descCtrl.text.trim(),
      'battery_type':   _type == 'battery' ? _battType : '',
      'capacity_mah':   _type == 'battery' ? (int.tryParse(_capacityCtrl.text) ?? 0) : 0,
      'condition':      _condition,
      'quantity':       1,
      'storage_location': _locationCtrl.text.trim(),
      'purchase_date':  _purchaseDateCtrl.text.trim(),
      'notes':          _notesCtrl.text.trim(),
      'organization_id': orgId,
      if (!_isEdit) 'created_at': now,
      'is_synced':      0,
    };

    if (_isEdit) {
      await db.updateEquipment({'id': widget.item!.id, ...data});
    } else {
      await db.insertEquipment(data);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.card,
        title: Text('Delete Equipment',
            style: TextStyle(color: ctx.colors.textPrimary)),
        content: Text(
          'Remove "${widget.item!.name}" from the locker?',
          style: TextStyle(color: ctx.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ctx.colors.textMuted)),
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
    await DatabaseHelper.instance.deleteEquipment(widget.item!.id!);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(_isEdit ? 'Edit Equipment' : 'Add Equipment'),
          Text(
            _isEdit ? 'Update item details' : 'Register a new item',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400,
                color: context.colors.textSecondary),
          ),
        ]),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: _isSaving ? null : _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          _label('EQUIPMENT TYPE'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _types.map((t) {
              final sel = _type == t.$1;
              return GestureDetector(
                onTap: () => setState(() => _type = t.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary.withValues(alpha: 0.12) : context.colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? AppColors.primary : context.colors.border,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Text(t.$2,
                      style: TextStyle(
                          color: sel ? AppColors.primary : context.colors.textSecondary,
                          fontSize: 13,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _label('IDENTIFICATION'),
          const SizedBox(height: 10),
          _field(_nameCtrl, 'Item Name *', hint: _type == 'battery' ? 'e.g. Flight Battery A' : 'e.g. LiPo Charger'),
          const SizedBox(height: 14),
          _field(_serialCtrl, 'Serial Number', hint: 'e.g. SN-12345'),
          const SizedBox(height: 14),
          _field(_modelCtrl, 'Model', hint: 'e.g. T40 Smart Battery'),
          const SizedBox(height: 14),
          _field(_manufacturerCtrl, 'Manufacturer', hint: 'e.g. DJI'),
          if (_type == 'battery') ...[
            const SizedBox(height: 24),
            _label('BATTERY SPECIFICATIONS'),
            const SizedBox(height: 10),
            _dropdownContainer(
              label: 'Cell Configuration',
              child: DropdownButton<String>(
                value: _battType,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: context.colors.card,
                style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
                items: _batteryTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) { if (v != null) setState(() => _battType = v); },
              ),
            ),
            const SizedBox(height: 14),
            _field(
              _capacityCtrl, 'Capacity (mAh)',
              hint: 'e.g. 30000',
              keyboard: const TextInputType.numberWithOptions(),
              formatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
          const SizedBox(height: 24),
          _label('DETAILS'),
          const SizedBox(height: 10),
          _field(_descCtrl, 'Description', hint: 'Optional notes about this item', maxLines: 2),
          const SizedBox(height: 14),
          _field(_locationCtrl, 'Storage Location', hint: 'e.g. Storage Room B, Shelf 3'),
          const SizedBox(height: 14),
          _field(_purchaseDateCtrl, 'Purchase Date', hint: 'YYYY-MM-DD'),
          const SizedBox(height: 24),
          _label('CONDITION'),
          const SizedBox(height: 10),
          Row(children: _conditions.asMap().entries.map((e) {
            final i = e.key;
            final cond = e.value;
            final sel = _condition == cond.$1;
            final color = cond.$1 == 'serviceable'
                ? AppColors.success
                : cond.$1 == 'unserviceable'
                    ? AppColors.warning
                    : AppColors.danger;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _condition = cond.$1),
                child: Container(
                  margin: EdgeInsets.only(right: i < _conditions.length - 1 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? color.withValues(alpha: 0.12) : context.colors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: sel ? color.withValues(alpha: 0.6) : context.colors.border,
                        width: sel ? 1.5 : 1),
                  ),
                  child: Text(cond.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: sel ? color : context.colors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            );
          }).toList()),
          const SizedBox(height: 24),
          _label('ADDITIONAL NOTES'),
          const SizedBox(height: 10),
          _field(_notesCtrl, 'Notes (optional)', hint: 'Any additional information', maxLines: 3),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isEdit ? 'Save Changes' : 'Add to Locker',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(color: context.colors.textMuted, fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 1.1));

  Widget _field(TextEditingController ctrl, String label,
      {String? hint, int maxLines = 1, TextInputType? keyboard,
       List<TextInputFormatter>? formatters}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
      inputFormatters: formatters,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        filled: true,
        fillColor: context.colors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _dropdownContainer({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(label, style: TextStyle(color: context.colors.textMuted, fontSize: 10)),
        ),
        child,
      ]),
    );
  }
}
