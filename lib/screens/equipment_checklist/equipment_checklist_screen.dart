import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../models/equipment_item.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../checklists/base_checklist_screen.dart';
import '../checklists/checklist_widgets.dart';
import '../fit_to_fly/fit_to_fly_screen.dart';

class EquipmentChecklistScreen extends StatefulWidget {
  final int missionId;
  final String missionTitle;
  const EquipmentChecklistScreen(
      {super.key, required this.missionId, required this.missionTitle});

  @override
  State<EquipmentChecklistScreen> createState() =>
      _EquipmentChecklistScreenState();
}

class _EquipmentChecklistScreenState extends State<EquipmentChecklistScreen> {
  List<EquipmentItem> _allEquipment = [];
  final Set<int> _selectedIds = {};

  static const _defs = [
    ('A. LI-ION BATTERIES', 'Battery cells ≥3.8V/cell, no swelling or damage'),
    ('A. LI-ION BATTERIES', 'Charge level: ≥95% for deployment'),
    ('A. LI-ION BATTERIES', 'Cycle count logged in maintenance record'),
    ('A. LI-ION BATTERIES', 'Battery storage bag / fireproof case ready'),
    ('B. PROPELLERS', 'Propellers inspected: no cracks, chips, or warping'),
    ('C. GCS & RADIOS', 'GCS/tablet powered and connected'),
    ('C. GCS & RADIOS', 'RC transmitter charged, bound, and calibrated'),
    ('C. GCS & RADIOS', 'Communication radios checked and operational'),
    ('C. GCS & RADIOS', 'Backup communication device available'),
    ('D. UAS/RPAS', 'Airframe: no visible damage, all arms secured'),
    ('D. UAS/RPAS', 'Motors: spin freely, no unusual sounds'),
    ('D. UAS/RPAS', 'Gimbal: powered, level, and free-moving'),
    ('D. UAS/RPAS', 'SD card / storage media inserted and formatted'),
    ('D. UAS/RPAS', 'GPS/GNSS antenna: clear of obstructions'),
    ('D. UAS/RPAS', 'Airworthiness tag (Annex E): Serviceable'),
  ];

  @override
  void initState() {
    super.initState();
    _loadEquipment();
  }

  Future<void> _loadEquipment() async {
    final db = DatabaseHelper.instance;
    final rows = await db.getEquipment();
    final existing = await db.getMissionEquipment(widget.missionId);
    final existingIds = existing.map((e) => e['equipment_id'] as int).toSet();
    if (mounted) {
      setState(() {
        _allEquipment = rows.map(EquipmentItem.fromMap).toList();
        _selectedIds.addAll(existingIds);
      });
    }
  }

  Future<void> _toggle(int id) async {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
    await DatabaseHelper.instance.saveMissionEquipment(
      widget.missionId,
      _selectedIds.map((eid) => {'equipment_id': eid}).toList(),
    );
  }

  List<Widget> _buildEquipmentSection() {
    return [
      ChecklistSectionHeader(label: 'E. EQUIPMENT USED'),
      if (_allEquipment.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colors.border),
            ),
            child: Text(
              'No equipment in locker. Add items via More → Equipment Locker.',
              style: TextStyle(color: context.colors.textMuted, fontSize: 12),
            ),
          ),
        )
      else
        ..._allEquipment.map((item) => _EquipmentCheckTile(
              item: item,
              selected: _selectedIds.contains(item.id),
              onToggle: () => _toggle(item.id!),
            )),
      const SizedBox(height: 8),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BaseChecklistScreen(
      missionId: widget.missionId,
      missionTitle: widget.missionTitle,
      defs: _defs,
      checklistType: 'equipment',
      stepIndex: 0,
      steps: AppConstants.executionChecklistSteps,
      captureTimestamps: true,
      extraSections: _buildEquipmentSection,
      submitLabel: 'Submit & Proceed to Fit-to-Fly',
      onSubmitComplete: (ctx, id, title) async {
        final provider = ctx.read<AppProvider>();
        final mission = await DatabaseHelper.instance.getMissionById(id);
        if (mission != null) {
          mission.hasEquipmentComplete = true;
          await provider.updateMission(mission);
        }
        if (!ctx.mounted) return;
        Navigator.of(ctx).push(MaterialPageRoute(
          builder: (_) => FitToFlyScreen(missionId: id, missionTitle: title),
        ));
      },
    );
  }
}

class _EquipmentCheckTile extends StatelessWidget {
  final EquipmentItem item;
  final bool selected;
  final VoidCallback onToggle;
  const _EquipmentCheckTile(
      {required this.item, required this.selected, required this.onToggle});

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

  @override
  Widget build(BuildContext context) {
    final color = _typeColor();
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.07)
              : context.colors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.4)
                : context.colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? AppColors.primary
                  : context.colors.surface,
              border: Border.all(
                color: selected ? AppColors.primary : context.colors.border,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(item.typeLabel,
                style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name,
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              if (item.equipmentCode.isNotEmpty || item.serialNumber.isNotEmpty)
                Text(
                  [
                    if (item.equipmentCode.isNotEmpty) item.equipmentCode,
                    if (item.serialNumber.isNotEmpty) 'S/N: ${item.serialNumber}',
                  ].join('  ·  '),
                  style: TextStyle(color: context.colors.textMuted, fontSize: 10),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
