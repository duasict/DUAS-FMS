import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/mission.dart';
import '../../models/crew_member.dart';
import '../../database/database_helper.dart';
import '../../providers/app_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../theme/app_theme.dart';
import '../checklists/inflight_checklist_screen.dart';
import '../checklists/postflight_checklist_screen.dart';
import '../checklists/preflight_checklist_screen.dart';
import '../equipment_checklist/equipment_checklist_screen.dart';
import '../fit_to_fly/fit_to_fly_screen.dart';
import '../flight_log/flight_log_screen.dart';
import '../flight_planning/flight_planning_screen.dart';
import '../hira/hira_screen.dart';
import '../reports/mission_reports_screen.dart';

class MissionDetailsScreen extends StatefulWidget {
  final int missionId;
  const MissionDetailsScreen({super.key, required this.missionId});

  @override
  State<MissionDetailsScreen> createState() => _MissionDetailsScreenState();
}

class _MissionDetailsScreenState extends State<MissionDetailsScreen> {
  Mission? _mission;
  Map<String, dynamic>? _latestBatteryLog;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await DatabaseHelper.instance.getMissionById(widget.missionId);
    Map<String, dynamic>? battLog;
    if (m?.aircraftId != null) {
      battLog = await DatabaseHelper.instance
          .getLatestBatteryLogByAircraft(m!.aircraftId!);
    }
    if (mounted) {
      setState(() {
        _mission = m;
        _latestBatteryLog = battLog;
        _isLoading = false;
      });
    }
  }

  void _navigateToStep(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _load());
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

    _navigateToStep(next);
  }

  /// Tap on a completed step to navigate directly back to it.
  /// Navigation is locked once post-flight is done (user remark #7).
  void _navigateToCompletedStep(Widget screen) {
    final m = _mission!;
    if (m.isPostFlightDone) return; // locked
    _navigateToStep(screen);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed':  return AppColors.success;
      case 'planning':   return AppColors.primary;
      case 'in_progress':return AppColors.accent;
      case 'cancelled':  return AppColors.danger;
      default:           return context.colors.textMuted;
    }
  }

  Future<void> _cancelMission() async {
    final m = _mission;
    if (m == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.colors.card,
        title: Text('Cancel Mission',
            style: TextStyle(color: ctx.colors.textPrimary)),
        content: Text(
          'Cancel "${m.title}"?\n\n'
          'The mission will be marked as Cancelled and removed from '
          'the active list. This cannot be undone.',
          style: TextStyle(color: ctx.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Mission',
                style: TextStyle(color: ctx.colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Cancel Mission'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    m.status = 'cancelled';
    await context.read<AppProvider>().updateMission(m);
    await _load();
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

    final isCrp = context.watch<UserProfileProvider>().profile.role == 'crp';
    final canCancel = isCrp && !m.isCompleted && !m.isCancelled;

    return Scaffold(
      appBar: AppBar(
        title: Text(m.missionId,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
        actions: [
          Container(
            margin: EdgeInsets.only(right: canCancel ? 4 : 14),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          if (canCancel)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: context.colors.textSecondary),
              color: context.colors.card,
              onSelected: (v) { if (v == 'cancel') _cancelMission(); },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'cancel',
                  child: Row(children: [
                    const Icon(Icons.cancel_outlined,
                        color: AppColors.danger, size: 18),
                    const SizedBox(width: 10),
                    Text('Cancel Mission',
                        style: TextStyle(
                            color: AppColors.danger, fontSize: 14)),
                  ]),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          const SizedBox(height: 14),

          // CRP concurrence banner
          if (m.crpConcurrenceRequired)
            _ConcurrenceBanner(status: m.crpConcurrenceStatus),
          if (m.crpAdvisoryNotes.isNotEmpty)
            _CrpAdvisoryCard(notes: m.crpAdvisoryNotes),

          // Pre-flight battery health alert
          if (m.aircraftId != null)
            _BatteryAlertCard(batteryLog: _latestBatteryLog),

          _headerCard(m),
          const SizedBox(height: 10),

          _SectionCard(
            icon: Icons.info_outline,
            title: 'Mission Info',
            children: [
              _Row(Icons.calendar_today, 'Date',
                  '${m.date}   ${m.timeStr}'),
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
                padding: const EdgeInsets.only(top: 4),
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
                  m.aircraftType == 'vtol'
                      ? 'VTOL Fixed-Wing'
                      : 'Multi-rotor'),
            ],
          ),

          if (m.crew.isNotEmpty)
            _SectionCard(
              icon: Icons.people_outline,
              title: 'Crew Members',
              children: m.crew.map((c) => _CrewTile(member: c)).toList(),
            ),

          if (m.isCompleted) ...[
            const SizedBox(height: 4),
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
      padding: const EdgeInsets.all(16),
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
        _ChecklistProgressRow(
          mission: m,
          onStepTap: _navigateToCompletedStep,
        ),
      ]),
    );
  }
}

// ── CRP Concurrence Banner ────────────────────────────────────────────────────

class _ConcurrenceBanner extends StatelessWidget {
  /// '' or 'pending' = awaiting approval  |  'approved'  |  'rejected'
  final String status;
  const _ConcurrenceBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';

    final Color bg;
    final Color border;
    final Color fg;
    final IconData icon;
    final String headline;
    final String body;

    if (isApproved) {
      bg = AppColors.success.withValues(alpha: 0.08);
      border = AppColors.success.withValues(alpha: 0.4);
      fg = AppColors.success;
      icon = Icons.verified_outlined;
      headline = 'CRP APPROVED';
      body = 'CRP concurrence has been granted. Proceed with operations.';
    } else if (isRejected) {
      bg = AppColors.danger.withValues(alpha: 0.12);
      border = AppColors.danger.withValues(alpha: 0.6);
      fg = AppColors.danger;
      icon = Icons.cancel_outlined;
      headline = 'CRP REJECTED';
      body = 'This mission was rejected by the CRP. Revise or cancel before proceeding.';
    } else {
      bg = AppColors.warning.withValues(alpha: 0.08);
      border = AppColors.warning.withValues(alpha: 0.4);
      fg = AppColors.warning;
      icon = Icons.pending_actions_outlined;
      headline = 'CRP CONCURRENCE REQUIRED';
      body = 'HIGH RISK — awaiting CRP approval before operations. HIRA residual risk ≥ 9.';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: fg, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(headline,
                style: TextStyle(
                    color: fg,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8)),
            const SizedBox(height: 3),
            Text(body,
                style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}

// ── CRP Advisory Notes Card ───────────────────────────────────────────────────

class _CrpAdvisoryCard extends StatelessWidget {
  final String notes;
  const _CrpAdvisoryCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.notes, color: AppColors.accent, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const Text('CRP ADVISORY',
                style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(notes,
                style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                    height: 1.5)),
          ]),
        ),
      ]),
    );
  }
}

// ── Progress Row ──────────────────────────────────────────────────────────────

class _ChecklistProgressRow extends StatelessWidget {
  final Mission mission;
  final void Function(Widget screen) onStepTap;
  const _ChecklistProgressRow(
      {required this.mission, required this.onStepTap});

  @override
  Widget build(BuildContext context) {
    final m = mission;
    final id = m.id!;
    final title = m.title;
    final locked = m.isPostFlightDone;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _groupLabel(context, 'PRE-DEPLOYMENT'),
      const SizedBox(height: 6),
      Row(children: [
        _ProgressStep(
          label: 'Flight Plan',
          done: m.hasFlightPlanComplete,
          onTap: m.hasFlightPlanComplete && !locked
              ? () => onStepTap(FlightPlanningScreen(
                  missionId: id, missionTitle: title))
              : null,
        ),
        _ProgressArrow(),
        _ProgressStep(
          label: 'HIRA',
          done: m.hasHiraComplete,
          onTap: m.hasHiraComplete && !locked
              ? () => onStepTap(HiraScreen(missionId: id, missionTitle: title))
              : null,
        ),
        _ProgressArrow(),
        _ProgressStep(
          label: 'Equipment',
          done: m.hasEquipmentComplete,
          onTap: m.hasEquipmentComplete && !locked
              ? () => onStepTap(EquipmentChecklistScreen(
                  missionId: id, missionTitle: title))
              : null,
        ),
        _ProgressArrow(),
        _ProgressStep(
          label: 'Fit-to-Fly',
          done: m.hasFitToFlyComplete,
          onTap: m.hasFitToFlyComplete && !locked
              ? () => onStepTap(
                  FitToFlyScreen(missionId: id, missionTitle: title))
              : null,
        ),
      ]),
      const SizedBox(height: 10),
      _groupLabel(context, 'EXECUTION'),
      const SizedBox(height: 6),
      Row(children: [
        _ProgressStep(
          label: 'Pre-flight',
          done: m.hasPreflightComplete,
          onTap: m.hasPreflightComplete && !locked
              ? () => onStepTap(PreflightChecklistScreen(
                  missionId: id, missionTitle: title))
              : null,
        ),
        _ProgressArrow(),
        _ProgressStep(
          label: 'In-flight',
          done: m.hasInflightComplete,
          onTap: m.hasInflightComplete && !locked
              ? () => onStepTap(InflightChecklistScreen(
                  missionId: id, missionTitle: title))
              : null,
        ),
        _ProgressArrow(),
        _ProgressStep(
          label: 'Post-flight',
          done: m.hasPostflightComplete,
          onTap: m.hasPostflightComplete
              ? () => onStepTap(PostflightChecklistScreen(
                  missionId: id, missionTitle: title))
              : null,
        ),
        _ProgressArrow(),
        _ProgressStep(
          label: 'Flight Log',
          done: m.hasFlightlogComplete,
          onTap: m.hasFlightlogComplete
              ? () => onStepTap(
                  FlightLogScreen(missionId: id, missionTitle: title))
              : null,
        ),
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

// ── Widgets ───────────────────────────────────────────────────────────────────

class _ProgressStep extends StatelessWidget {
  final String label;
  final bool done;
  final VoidCallback? onTap;
  const _ProgressStep(
      {required this.label, required this.done, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
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
              color:
                  done ? AppColors.success : context.colors.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: done ? AppColors.success : context.colors.textMuted,
              fontSize: 8,
              fontWeight: done ? FontWeight.w600 : FontWeight.w400,
              decoration: (done && onTap != null)
                  ? TextDecoration.underline
                  : null,
              decorationColor: AppColors.success,
            ),
          ),
        ]),
      ),
    );
  }
}

class _ProgressArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Icon(Icons.chevron_right,
          size: 12, color: context.colors.textMuted),
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
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: context.colors.textMuted),
          const SizedBox(width: 7),
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
        const Divider(height: 1),
        const SizedBox(height: 10),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: context.colors.textMuted),
        const SizedBox(width: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person,
              size: 16, color: AppColors.primaryLight),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(member.name,
              style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: context.colors.border),
          ),
          child: Text(member.role.toUpperCase(),
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
        border:
            Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Column(children: [
        const Icon(Icons.check_circle, color: AppColors.success, size: 40),
        const SizedBox(height: 10),
        const Text(
          'MISSION COMPLETE',
          style: TextStyle(
            color: AppColors.success,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        if (mission.duration != null) ...[
          const SizedBox(height: 4),
          Text(
            'Total flight duration: ${mission.formattedDuration}',
            style: TextStyle(
                color: context.colors.textSecondary, fontSize: 13),
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
    if (mission.isCancelled) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel_outlined, color: AppColors.danger, size: 18),
                SizedBox(width: 8),
                Text('Mission Cancelled',
                    style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
    }

    if (mission.isCompleted) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MissionReportsScreen(mission: mission),
                ),
              ),
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
    if (!m.hasEquipmentComplete) return Icons.inventory_2_outlined;
    if (!m.hasFitToFlyComplete) return Icons.checklist_outlined;
    if (!m.hasPreflightComplete) return Icons.checklist;
    if (!m.hasInflightComplete) return Icons.flight;
    if (!m.hasPostflightComplete) return Icons.flight_land;
    if (!m.hasFlightlogComplete) return Icons.book_outlined;
    return Icons.check;
  }
}

// ── Pre-flight Battery Health Alert ─────────────────────────────────────────

class _BatteryAlertCard extends StatelessWidget {
  final Map<String, dynamic>? batteryLog;
  const _BatteryAlertCard({required this.batteryLog});

  @override
  Widget build(BuildContext context) {
    final String status = batteryLog?['status'] as String? ?? '';
    final String battId = batteryLog?['battery_id'] as String? ?? '';
    final String logDate = batteryLog?['log_date'] as String? ?? '';

    if (status.isEmpty || status == 'good') return const SizedBox.shrink();

    final bool isReplace = status == 'replace' || status == 'retired';
    final Color color = isReplace ? AppColors.danger : AppColors.warning;
    final IconData icon = isReplace
        ? Icons.battery_alert
        : Icons.battery_charging_full_outlined;
    final String headline = isReplace
        ? 'BATTERY REQUIRES REPLACEMENT'
        : 'BATTERY DEGRADED — MONITOR CAREFULLY';
    final String detail = battId.isNotEmpty
        ? 'Battery $battId — last checked $logDate'
        : 'Last log: $logDate';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              headline,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8),
            ),
            const SizedBox(height: 3),
            Text(
              detail,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.4),
            ),
          ]),
        ),
      ]),
    );
  }
}
