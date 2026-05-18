import 'package:flutter/material.dart';
import '../../models/mission.dart';
import '../../models/crew_member.dart';
import '../../database/database_helper.dart';
import '../../theme/app_theme.dart';
import '../checklists/inflight_checklist_screen.dart';
import '../checklists/postflight_checklist_screen.dart';
import '../checklists/preflight_checklist_screen.dart';
import '../equipment_checklist/equipment_checklist_screen.dart';
import '../fit_to_fly/fit_to_fly_screen.dart';
import '../flight_log/flight_log_screen.dart';
import '../flight_planning/flight_planning_screen.dart';
import '../hira/hira_screen.dart';
import '../mission_approval/mission_approval_screen.dart';

class MissionDetailsScreen extends StatefulWidget {
  final int missionId;
  const MissionDetailsScreen({super.key, required this.missionId});

  @override
  State<MissionDetailsScreen> createState() => _MissionDetailsScreenState();
}

class _MissionDetailsScreenState extends State<MissionDetailsScreen> {
  Mission? _mission;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await DatabaseHelper.instance.getMissionById(widget.missionId);
    if (mounted) setState(() { _mission = m; _isLoading = false; });
  }

  void _navigateToNextStep() {
    final m = _mission!;
    final id = m.id!;
    final title = m.title;

    Widget next;
    if (!m.hasFlightPlanComplete) {
      next = FlightPlanningScreen(missionId: id, missionTitle: title);
    } else if (!m.hasHiraComplete) {
      next = HiraScreen(missionId: id, missionTitle: title);
    } else if (!m.hasApprovalComplete) {
      next = MissionApprovalScreen(missionId: id);
    } else if (!m.hasEquipmentComplete) {
      next = EquipmentChecklistScreen(missionId: id, missionTitle: title);
    } else if (!m.hasFitToFlyComplete) {
      next = FitToFlyScreen(missionId: id, missionTitle: title);
    } else if (!m.hasPreflightComplete) {
      next = PreflightChecklistScreen(missionId: id, missionTitle: title);
    } else if (!m.hasInflightComplete) {
      next = InflightChecklistScreen(missionId: id, missionTitle: title);
    } else if (!m.hasPostflightComplete) {
      next = PostflightChecklistScreen(missionId: id, missionTitle: title);
    } else if (!m.hasFlightlogComplete) {
      next = FlightLogScreen(missionId: id, missionTitle: title);
    } else {
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => next))
        .then((_) => _load());
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed': return AppColors.success;
      case 'approved': return AppColors.primary;
      default: return AppColors.accent;
    }
  }

  Color _riskColor(String r) {
    switch (r) {
      case 'high': return AppColors.danger;
      case 'medium': return AppColors.warning;
      default: return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final m = _mission!;

    return Scaffold(
      appBar: AppBar(
        title: Text(m.missionId,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(m.status).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _statusColor(m.status).withValues(alpha: 0.4)),
            ),
            child: Text(
              m.statusLabel.toUpperCase(),
              style: TextStyle(
                color: _statusColor(m.status),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          const SizedBox(height: 14),
          _headerCard(m),
          const SizedBox(height: 10),
          _SectionCard(
            icon: Icons.info_outline,
            title: 'Mission Info',
            children: [
              _Row(Icons.calendar_today, 'Date', '${m.date}   ${m.timeStr}'),
              _Row(Icons.location_on_outlined, 'Location', m.location),
              if (m.latitude != null && m.longitude != null)
                _Row(Icons.my_location, 'Coordinates',
                    '${m.latitude!.toStringAsFixed(4)}°N, ${m.longitude!.toStringAsFixed(4)}°E'),
              _Row(Icons.terrain, 'Environment', m.environment),
            ],
          ),
          _SectionCard(
            icon: Icons.flag_outlined,
            title: 'Mission Objective',
            children: [
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(m.objective,
                    style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 13,
                        height: 1.6)),
              ),
            ],
          ),
          _SectionCard(
            icon: Icons.air,
            title: 'Aircraft Used',
            children: [
              _Row(Icons.label_outline, 'Platform', m.aircraftName),
              _Row(
                  m.aircraftType == 'vtol'
                      ? Icons.airplanemode_active
                      : Icons.air,
                  'Type',
                  m.aircraftType == 'vtol' ? 'VTOL Fixed-Wing' : 'Multi-rotor'),
            ],
          ),
          _SectionCard(
            icon: Icons.warning_amber_outlined,
            title: 'Hazard Risk Assessment',
            children: [
              Padding(
                padding: EdgeInsets.only(top: 4, bottom: 10),
                child: Text(m.hazardRisk,
                    style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 13,
                        height: 1.6)),
              ),
              Row(children: [
                Text('Risk Level:',
                    style: TextStyle(
                        color: context.colors.textSecondary, fontSize: 13)),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _riskColor(m.riskLevel).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: _riskColor(m.riskLevel).withValues(alpha: 0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      m.riskLevel == 'high'
                          ? Icons.warning
                          : m.riskLevel == 'medium'
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                      color: _riskColor(m.riskLevel),
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      m.riskLevel.toUpperCase(),
                      style: TextStyle(
                        color: _riskColor(m.riskLevel),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ]),
                ),
              ]),
            ],
          ),
          if (m.crew.isNotEmpty)
            _SectionCard(
              icon: Icons.people_outline,
              title: 'Crew Members',
              children: m.crew.map((c) => _CrewTile(member: c)).toList(),
            ),
          _SectionCard(
            icon: Icons.verified_outlined,
            title: 'Concurrence Approval',
            children: [
              _Row(Icons.person_outline, 'Approved By', m.approvedBy),
            ],
          ),
          if (m.isCompleted) ...[
            SizedBox(height: 4),
            _CompletionCard(mission: m),
          ],
        ],
      ),
      bottomNavigationBar: _BottomAction(
        mission: m,
        onContinue: _navigateToNextStep,
      ),
    );
  }

  Widget _headerCard(Mission m) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          m.title,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        _ChecklistProgressRow(mission: m),
      ]),
    );
  }
}

class _ChecklistProgressRow extends StatelessWidget {
  final Mission mission;
  const _ChecklistProgressRow({required this.mission});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _groupLabel(context, 'PRE-DEPLOYMENT'),
      const SizedBox(height: 6),
      Row(children: [
        _ProgressStep(label: 'Flight Plan', done: mission.hasFlightPlanComplete),
        _ProgressArrow(),
        _ProgressStep(label: 'HIRA', done: mission.hasHiraComplete),
        _ProgressArrow(),
        _ProgressStep(label: 'Approval', done: mission.hasApprovalComplete),
        _ProgressArrow(),
        _ProgressStep(label: 'Equipment', done: mission.hasEquipmentComplete),
        _ProgressArrow(),
        _ProgressStep(label: 'Fit-to-Fly', done: mission.hasFitToFlyComplete),
      ]),
      SizedBox(height: 10),
      _groupLabel(context, 'EXECUTION'),
      SizedBox(height: 6),
      Row(children: [
        _ProgressStep(label: 'Pre-flight', done: mission.hasPreflightComplete),
        _ProgressArrow(),
        _ProgressStep(label: 'In-flight', done: mission.hasInflightComplete),
        _ProgressArrow(),
        _ProgressStep(label: 'Post-flight', done: mission.hasPostflightComplete),
        _ProgressArrow(),
        _ProgressStep(label: 'Flight Log', done: mission.hasFlightlogComplete),
      ]),
    ]);
  }

  Widget _groupLabel(BuildContext context, String text) => Text(
        text,
        style: TextStyle(
            color: context.colors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8),
      );
}

class _ProgressStep extends StatelessWidget {
  final String label;
  final bool done;
  const _ProgressStep({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: done
                ? AppColors.success.withValues(alpha: 0.15)
                : context.colors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: done ? AppColors.success : context.colors.border,
              width: 1.5,
            ),
          ),
          child: Icon(
            done ? Icons.check : Icons.circle_outlined,
            size: 11,
            color: done ? AppColors.success : context.colors.textMuted,
          ),
        ),
        SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: done ? AppColors.success : context.colors.textMuted,
            fontSize: 8,
            fontWeight: done ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ]),
    );
  }
}

class _ProgressArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Icon(Icons.chevron_right, size: 12, color: context.colors.textMuted),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _SectionCard(
      {required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 5),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: context.colors.textMuted),
          SizedBox(width: 7),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: context.colors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Divider(height: 1),
        SizedBox(height: 10),
        ...children,
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: context.colors.textMuted),
        SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text('$label:',
              style: TextStyle(
                  color: context.colors.textSecondary, fontSize: 12)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

class _CrewTile extends StatelessWidget {
  final CrewMember member;
  const _CrewTile({required this.member});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person,
              size: 16, color: AppColors.primaryLight),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(member.name,
              style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: context.colors.border),
          ),
          child: Text(member.role,
              style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  final Mission mission;
  const _CompletionCard({required this.mission});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Column(children: [
        Icon(Icons.check_circle, color: AppColors.success, size: 40),
        SizedBox(height: 10),
        Text(
          'MISSION COMPLETE',
          style: TextStyle(
            color: AppColors.success,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        if (mission.duration != null) ...[
          SizedBox(height: 4),
          Text(
            'Total flight duration: ${mission.formattedDuration}',
            style:
                TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
        ],
      ]),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final Mission mission;
  final VoidCallback onContinue;
  const _BottomAction({required this.mission, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    if (mission.isCompleted) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('View Flight Report'),
            ),
          ),
        ),
      );
    }

    final label = _nextStepLabel(mission);
    if (label.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: onContinue,
            icon: Icon(_nextStepIcon(mission), size: 18),
            label: Text(label),
          ),
        ),
      ),
    );
  }

  String _nextStepLabel(Mission m) {
    if (!m.hasFlightPlanComplete) return 'Start Flight Planning';
    if (!m.hasHiraComplete) return 'Continue to HIRA Assessment';
    if (!m.hasApprovalComplete) return 'Continue to Mission Approval';
    if (!m.hasEquipmentComplete) return 'Continue to Equipment Check';
    if (!m.hasFitToFlyComplete) return 'Continue to Fit-to-Fly';
    if (!m.hasPreflightComplete) return 'Continue to Pre-flight Checklist';
    if (!m.hasInflightComplete) return 'Continue to In-flight Checklist';
    if (!m.hasPostflightComplete) return 'Continue to Post-flight Checklist';
    if (!m.hasFlightlogComplete) return 'Continue to Flight Log';
    return '';
  }

  IconData _nextStepIcon(Mission m) {
    if (!m.hasFlightPlanComplete) return Icons.map_outlined;
    if (!m.hasHiraComplete) return Icons.warning_amber_outlined;
    if (!m.hasApprovalComplete) return Icons.verified_outlined;
    if (!m.hasEquipmentComplete) return Icons.inventory_2_outlined;
    if (!m.hasFitToFlyComplete) return Icons.checklist_outlined;
    if (!m.hasPreflightComplete) return Icons.checklist;
    if (!m.hasInflightComplete) return Icons.flight;
    if (!m.hasPostflightComplete) return Icons.flight_land;
    if (!m.hasFlightlogComplete) return Icons.book_outlined;
    return Icons.check;
  }
}
