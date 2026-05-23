import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../providers/app_provider.dart';
import 'base_checklist_screen.dart';
import 'inflight_checklist_screen.dart';

class PreflightChecklistScreen extends StatelessWidget {
  final int missionId;
  final String missionTitle;
  const PreflightChecklistScreen(
      {super.key, required this.missionId, required this.missionTitle});

  static const _defs = [
    ('A. MISSION & CREW', 'Flight Plan approved (Ch 3.4)'),
    ('A. MISSION & CREW', 'RPIC assigned and briefed (Annex I signed)'),
    ('A. MISSION & CREW', 'VO assigned (if required; no RPL needed)'),
    ('A. MISSION & CREW',
        'Maintenance Head present (if post-maintenance/new platform)'),
    ('A. MISSION & CREW',
        'Crew fitness confirmed (no fatigue, illness, impairment)'),
    ('B. AIRCRAFT & PAYLOAD',
        'Visual inspection: airframe, arms, motors, props (no cracks/damage)'),
    ('B. AIRCRAFT & PAYLOAD',
        'Propellers: no chips/warping; torque verified (MR: 0.8 Nm, VFW: 1.2 Nm)'),
    ('B. AIRCRAFT & PAYLOAD',
        'Battery: ≥95% charge, ≥3.8 V/cell, no swelling, cycle count logged'),
    ('B. AIRCRAFT & PAYLOAD',
        'Payload: mounted securely, gimbal free-moving, power on'),
    ('B. AIRCRAFT & PAYLOAD', 'Airworthiness tag: Serviceable (per Annex E)'),
    ('C. GCS & COMMUNICATION',
        'GCS powered, OS/firmware updated, QBase/Mission Planner loaded'),
    ('C. GCS & COMMUNICATION',
        'RC transmitter calibrated, sticks centered, failsafe triggers tested'),
    ('C. GCS & COMMUNICATION',
        'Link test: RSSI ≥70%, latency <100 ms, CSL encrypted (if equipped)'),
    ('C. GCS & COMMUNICATION',
        'Compass & IMU calibrated (green status in GCS)'),
    ('C. GCS & COMMUNICATION',
        'RTH altitude set: ≥120 m AGL (Multi-rotor), ≥200 m AGL (VTOL)'),
    ('D. ENVIRONMENT & SAFETY', 'NOTAMs checked (no activity in ops area)'),
    ('D. ENVIRONMENT & SAFETY',
        'Weather: wind ≤12 m/s (MR), ≤16 m/s (VFW), no rain/fog'),
    ('D. ENVIRONMENT & SAFETY',
        'VLOS zone confirmed: clear, ≥500 m radius, no obstacles'),
    ('D. ENVIRONMENT & SAFETY', 'Emergency landing zones identified'),
    ('D. ENVIRONMENT & SAFETY',
        'Manned aircraft activity monitored (VO positioned)'),
  ];

  @override
  Widget build(BuildContext context) {
    return BaseChecklistScreen(
      missionId: missionId,
      missionTitle: missionTitle,
      defs: _defs,
      checklistType: 'preflight',
      stepIndex: 0,
      submitLabel: 'Submit & Proceed to In-flight Checklist',
      onSubmitComplete: (ctx, id, title) async {
        final provider = ctx.read<AppProvider>();
        final mission = await DatabaseHelper.instance.getMissionById(id);
        if (mission != null) {
          mission.hasPreflightComplete = true;
          await provider.updateMission(mission);
        }
        if (!ctx.mounted) return;
        Navigator.of(ctx).push(MaterialPageRoute(
          builder: (_) =>
              InflightChecklistScreen(missionId: id, missionTitle: title),
        ));
      },
    );
  }
}
