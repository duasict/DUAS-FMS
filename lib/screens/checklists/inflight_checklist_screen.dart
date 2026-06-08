import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../models/mission_flight.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_constants.dart';
import '../../theme/app_theme.dart';
import 'base_checklist_screen.dart';
import 'checklist_widgets.dart';
import 'postflight_checklist_screen.dart';

class InflightChecklistScreen extends StatelessWidget {
  final int missionId;
  final String missionTitle;
  /// 1-based flight number within this mission.
  final int flightNum;

  const InflightChecklistScreen({
    super.key,
    required this.missionId,
    required this.missionTitle,
    this.flightNum = 1,
  });

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
      stepIndex: 3,
      steps: AppConstants.executionChecklistSteps,
      submitLabel: 'Submit & Confirm Landing',
      onSubmitComplete: (ctx, id, title) async {
        final provider = ctx.read<AppProvider>();
        final mission = await DatabaseHelper.instance.getMissionById(id);
        if (mission != null) {
          mission.hasInflightComplete = true;
          await provider.updateMission(mission);
        }
        if (!ctx.mounted) return;

        final landingTime = await showTimeConfirmationDialog(
          ctx,
          title: 'Confirm Landing  (Flight $flightNum)',
          confirmLabel: 'Confirm Landing',
          icon: Icons.flight_land,
          color: AppColors.primary,
        );
        if (!ctx.mounted) return;

        final gps = await captureGps();

        final existing =
            await DatabaseHelper.instance.getMissionFlightByNum(id, flightNum);
        if (existing != null) {
          existing.landingTime = landingTime ?? '';
          existing.landingLat = gps.lat;
          existing.landingLon = gps.lon;
          await DatabaseHelper.instance.updateMissionFlight(existing);
        } else {
          // Edge case: no takeoff row yet — create one with landing data only.
          await DatabaseHelper.instance.insertMissionFlight(MissionFlight(
            missionId: id,
            flightNum: flightNum,
            landingTime: landingTime ?? '',
            landingLat: gps.lat,
            landingLon: gps.lon,
          ));
        }

        if (!ctx.mounted) return;
        Navigator.of(ctx).push(MaterialPageRoute(
          builder: (_) => PostflightChecklistScreen(
            missionId: id,
            missionTitle: title,
            flightNum: flightNum,
          ),
        ));
      },
    );
  }
}
