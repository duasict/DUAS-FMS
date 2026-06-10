import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import 'base_checklist_screen.dart';
import 'preflight_checklist_screen.dart';
import '../flight_log/flight_log_screen.dart';

class PostflightChecklistScreen extends StatelessWidget {
  final int missionId;
  final String missionTitle;
  /// 1-based flight number within this mission.
  final int flightNum;

  const PostflightChecklistScreen({
    super.key,
    required this.missionId,
    required this.missionTitle,
    this.flightNum = 1,
  });

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
      stepIndex: 4,
      steps: AppConstants.executionChecklistSteps,
      submitLabel: 'Submit Post-flight',
      onSubmitComplete: (ctx, id, title) async {
        final provider = ctx.read<AppProvider>();
        final mission = await DatabaseHelper.instance.getMissionById(id);
        if (mission != null) {
          mission.hasPostflightComplete = true;
          await provider.updateMission(mission);
        }
        if (!ctx.mounted) return;

        final anotherFlight = await showDialog<bool>(
          context: ctx,
          barrierDismissible: false,
          barrierColor: Colors.black38,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: dialogCtx.colors.card,
            title: Row(children: [
              const Icon(Icons.flight, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                'Flight $flightNum Complete',
                style: TextStyle(
                  color: dialogCtx.colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
            content: Text(
              'Do you want to start another flight for this mission?',
              style: TextStyle(
                color: dialogCtx.colors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: Text(
                  'No, proceed to Flight Log',
                  style: TextStyle(color: dialogCtx.colors.textMuted),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(dialogCtx, true),
                icon: const Icon(Icons.flight_takeoff, size: 16),
                label: const Text('Yes, another flight'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );

        if (!ctx.mounted) return;

        if (anotherFlight == true) {
          Navigator.of(ctx).push(MaterialPageRoute(
            builder: (_) => PreflightChecklistScreen(
              missionId: id,
              missionTitle: title,
              flightNum: flightNum + 1,
            ),
          ));
        } else {
          Navigator.of(ctx).push(MaterialPageRoute(
            builder: (_) => FlightLogScreen(missionId: id, missionTitle: title),
          ));
        }
      },
    );
  }
}
