import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/equipment_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bar_title.dart';
import 'equipment_locker_form_screen.dart';

class EquipmentLockerScreen extends StatefulWidget {
  const EquipmentLockerScreen({super.key});

  @override
  State<EquipmentLockerScreen> createState() => _EquipmentLockerScreenState();
}

class _EquipmentLockerScreenState extends State<EquipmentLockerScreen> {
  List<EquipmentItem> _items = [];
  bool _isLoading = true;
  String _filterType = 'all';

  static const _types = [
    ('all',            'All'),
    ('battery',        'Batteries'),
    ('charger',        'Chargers'),
    ('ground_support', 'Ground Support'),
    ('ppe',            'PPE'),
    ('tool',           'Tools'),
    ('other',          'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DatabaseHelper.instance.getEquipment();
    if (mounted) {
      setState(() {
        _items = rows.map(EquipmentItem.fromMap).toList();
        _isLoading = false;
      });
    }
  }

  List<EquipmentItem> get _filtered => _filterType == 'all'
      ? _items
      : _items.where((e) => e.type == _filterType).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitle(
            title: 'Equipment Locker', subtitle: 'Manage flight equipment inventory'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _TypeFilter(
            selected: _filterType,
            types: _types,
            onChanged: (t) => setState(() => _filterType = t),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _filtered.isEmpty
              ? _emptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _EquipmentCard(
                    item: _filtered[i],
                    onTap: () => _openForm(_filtered[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _openForm(null),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Equipment', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inventory_2_outlined, size: 56, color: context.colors.textMuted),
        const SizedBox(height: 12),
        Text(
          _filterType == 'all' ? 'No equipment registered' : 'No ${_types.firstWhere((t) => t.$1 == _filterType).$2} found',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text('Tap + Add Equipment to register items.',
            style: TextStyle(color: context.colors.textMuted, fontSize: 13)),
      ]),
    );
  }

  Future<void> _openForm(EquipmentItem? item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EquipmentLockerFormScreen(item: item)),
    );
    if (mounted) _load();
  }
}

// ─── Type filter chip row ──────────────────────────────────────────────────

class _TypeFilter extends StatelessWidget {
  final String selected;
  final List<(String, String)> types;
  final ValueChanged<String> onChanged;
  const _TypeFilter({required this.selected, required this.types, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: types.map((t) {
          final active = selected == t.$1;
          return GestureDetector(
            onTap: () => onChanged(t.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.primary.withValues(alpha: 0.15) : context.colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? AppColors.primary : context.colors.border,
                  width: active ? 1.5 : 1,
                ),
              ),
              child: Text(
                t.$2,
                style: TextStyle(
                  color: active ? AppColors.primary : context.colors.textSecondary,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Equipment card ────────────────────────────────────────────────────────

class _EquipmentCard extends StatelessWidget {
  final EquipmentItem item;
  final VoidCallback onTap;
  const _EquipmentCard({required this.item, required this.onTap});

  Color _typeColor() {
    switch (item.type) {
      case 'battery':        return AppColors.success;
      case 'charger':        return AppColors.info;
      case 'ground_support': return AppColors.warning;
      case 'ppe':            return const Color(0xFFCE93D8);
      case 'tool':           return const Color(0xFFFF9E50);
      default:               return AppColors.primaryLight;
    }
  }

  IconData _typeIcon() {
    switch (item.type) {
      case 'battery':        return Icons.battery_full_outlined;
      case 'charger':        return Icons.electrical_services_outlined;
      case 'ground_support': return Icons.handyman_outlined;
      case 'ppe':            return Icons.security_outlined;
      case 'tool':           return Icons.build_outlined;
      default:               return Icons.inventory_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor();
    final condColor = item.condition == 'serviceable'
        ? AppColors.success
        : item.condition == 'unserviceable'
            ? AppColors.warning
            : AppColors.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_typeIcon(), color: color, size: 20),
        ),
        title: Row(children: [
          Expanded(
            child: Text(item.name,
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: condColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(item.conditionLabel,
                style: TextStyle(
                    color: condColor, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 2),
          Text(
            [
              item.equipmentCode.isNotEmpty ? item.equipmentCode : null,
              item.serialNumber.isNotEmpty ? 'S/N: ${item.serialNumber}' : null,
              item.isBattery && item.batteryType.isNotEmpty
                  ? '${item.batteryType}  ${item.capacityMah > 0 ? '${item.capacityMah} mAh' : ''}'
                  : null,
            ].whereType<String>().join('  ·  '),
            style: TextStyle(color: context.colors.textMuted, fontSize: 11),
          ),
          if (item.model.isNotEmpty || item.manufacturer.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              [item.manufacturer, item.model].where((s) => s.isNotEmpty).join(' '),
              style: TextStyle(color: context.colors.textMuted, fontSize: 11),
            ),
          ],
        ]),
        trailing: Icon(Icons.chevron_right, color: context.colors.textMuted, size: 18),
        onTap: onTap,
      ),
    );
  }
}
