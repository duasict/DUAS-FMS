import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../providers/app_provider.dart';
import 'base_checklist_screen.dart';
import '../flight_log/flight_log_screen.dart';

class PostflightChecklistScreen extends StatelessWidget {
  final int missionId;
  final String missionTitle;
  const PostflightChecklistScreen(
      {super.key, required this.missionId, required this.missionTitle});

  static const _defs = [
    ('A. AIRCRAFT & PAYLOAD', 'Aircraft secured, power off'),
    ('A. AIRCRAFT & PAYLOAD', 'Visual inspection: airframe damage'),
    ('A. AIRCRAFT & PAYLOAD', 'Visual inspection: propeller'),
    ('A. AIRCRAFT & PAYLOAD', 'Visual inspection: motor'),
    ('A. AIRCRAFT & PAYLOAD', 'Visual inspection: gimbal alignment'),
    ('A. AIRCRAFT & PAYLOAD', 'Battery cooled and logged'),
    ('A. AIRCRAFT & PAYLOAD',
        'Battery discharged to 3.8 V/cell within 24 hrs'),
    ('A. AIRCRAFT & PAYLOAD', 'Flight Data downloaded'),
    ('A. AIRCRAFT & PAYLOAD',
        'Data offloaded: photos/videos verified and complete'),
    ('B. DOCUMENTATION', 'Flight Log (Annex D) completed'),
    ('B. DOCUMENTATION', 'Anomalies logged (e.g., link drop, wind shear)'),
    ('B. DOCUMENTATION', 'Debrief conducted (RPIC, VO)'),
    ('C. MAINTENANCE ACTIONS', 'Propellers inspected/replaced'),
    ('C. MAINTENANCE ACTIONS', 'Motors/ESCs checked for heat/dust'),
    ('C. MAINTENANCE ACTIONS', 'Airframe stress points examined'),
    ('C. MAINTENANCE ACTIONS',
        'Next maintenance due: ______ hrs / __________ date'),
  ];

  @override
  Widget build(BuildContext context) {
    return BaseChecklistScreen(
      missionId: missionId,
      missionTitle: missionTitle,
      defs: _defs,
      checklistType: 'postflight',
      stepIndex: 2,
      submitLabel: 'Submit & Proceed to Flight Log',
      onSubmitComplete: (ctx, id, title) async {
        final provider = ctx.read<AppProvider>();
        final mission = await DatabaseHelper.instance.getMissionById(id);
        if (mission != null) {
          mission.hasPostflightComplete = true;
          await provider.updateMission(mission);
        }
        if (!ctx.mounted) return;
        Navigator.of(ctx).push(MaterialPageRoute(
          builder: (_) => FlightLogScreen(missionId: id, missionTitle: title),
        ));
      },
    );
  }
}
