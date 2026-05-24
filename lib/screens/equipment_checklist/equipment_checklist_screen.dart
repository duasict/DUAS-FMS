import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_constants.dart';
import '../checklists/base_checklist_screen.dart';
import '../fit_to_fly/fit_to_fly_screen.dart';

class EquipmentChecklistScreen extends StatelessWidget {
  final int missionId;
  final String missionTitle;
  const EquipmentChecklistScreen(
      {super.key, required this.missionId, required this.missionTitle});

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
  Widget build(BuildContext context) {
    return BaseChecklistScreen(
      missionId: missionId,
      missionTitle: missionTitle,
      defs: _defs,
      checklistType: 'equipment',
      stepIndex: 0,
      steps: AppConstants.executionChecklistSteps,
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
