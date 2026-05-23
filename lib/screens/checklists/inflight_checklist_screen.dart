import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../providers/app_provider.dart';
import 'base_checklist_screen.dart';
import 'postflight_checklist_screen.dart';

class InflightChecklistScreen extends StatelessWidget {
  final int missionId;
  final String missionTitle;
  const InflightChecklistScreen(
      {super.key, required this.missionId, required this.missionTitle});

  static const _defs = [
    ('A. LAUNCH CHECKLIST', 'GCS final telemetry OK (GPS 3D, AHRS stable)'),
    ('A. LAUNCH CHECKLIST', 'Takeoff clearance given by RPIC'),
    ('A. LAUNCH CHECKLIST', 'VO confirms VLOS maintained'),
    ('B. EN ROUTE CHECKLIST', 'Telemetry Link Stable; Link strength ≥60%'),
    ('B. EN ROUTE CHECKLIST', 'Flight path followed'),
    ('B. EN ROUTE CHECKLIST', 'Altitude within plan (±10 m)'),
    ('B. EN ROUTE CHECKLIST', 'Battery ≥30% (VTOL) / ≥20% (Quad)'),
    ('B. EN ROUTE CHECKLIST', 'VO continuously scanning airspace'),
    ('B. EN ROUTE CHECKLIST',
        'Payload recording (video/photo count increasing)'),
    ('B. EN ROUTE CHECKLIST',
        'Weather stable (no sudden gusts/visibility loss)'),
    ('C. CONTINGENCY CHECKLIST', 'RTH triggered (if link loss >20 sec)'),
    ('C. CONTINGENCY CHECKLIST',
        'Manual takeover executed (if ATTI mode required)'),
    ('C. CONTINGENCY CHECKLIST',
        'Emergency landing initiated (if battery <20%)'),
  ];

  @override
  Widget build(BuildContext context) {
    return BaseChecklistScreen(
      missionId: missionId,
      missionTitle: missionTitle,
      defs: _defs,
      checklistType: 'inflight',
      stepIndex: 1,
      submitLabel: 'Submit & Proceed to Post-flight Checklist',
      onSubmitComplete: (ctx, id, title) async {
        final provider = ctx.read<AppProvider>();
        final mission = await DatabaseHelper.instance.getMissionById(id);
        if (mission != null) {
          mission.hasInflightComplete = true;
          await provider.updateMission(mission);
        }
        if (!ctx.mounted) return;
        Navigator.of(ctx).push(MaterialPageRoute(
          builder: (_) =>
              PostflightChecklistScreen(missionId: id, missionTitle: title),
        ));
      },
    );
  }
}
