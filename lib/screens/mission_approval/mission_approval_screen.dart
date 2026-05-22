import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/flight_plan.dart';
import '../../models/hira_row.dart';
import '../../models/mission.dart';
import '../../theme/app_theme.dart';
import '../equipment_checklist/equipment_checklist_screen.dart';
import '../shared/mission_flow_widgets.dart';

class MissionApprovalScreen extends StatefulWidget {
  final int missionId;
  const MissionApprovalScreen({super.key, required this.missionId});

  @override
  State<MissionApprovalScreen> createState() => _MissionApprovalScreenState();
}

class _MissionApprovalScreenState extends State<MissionApprovalScreen> {
  Mission? _mission;
  FlightPlan? _flightPlan;
  List<HiraRow> _hiraRows = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await DatabaseHelper.instance.getMissionById(widget.missionId);
    final fp = await DatabaseHelper.instance
        .getFlightPlanByMissionId(widget.missionId);
    final hr = await DatabaseHelper.instance
        .getHiraRowsByMissionId(widget.missionId);
    if (mounted) {
      setState(() {
        _mission = m;
        _flightPlan = fp;
        _hiraRows = hr;
        _isLoading = false;
      });
    }
  }

  Future<void> _approve() async {
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);

    if (!mounted) return;
    setState(() => _isSaving = false);
    navigator.push(MaterialPageRoute(
      builder: (_) => EquipmentChecklistScreen(
        missionId: widget.missionId,
        missionTitle: _mission?.title ?? '',
      ),
    ));
  }

  int get _highestRisk => _hiraRows.isEmpty
      ? 0
      : _hiraRows.map((r) => r.risk).reduce((a, b) => a > b ? a : b);

  Color _riskColor(int r) {
    if (r <= 4) return AppColors.success;
    if (r <= 8) return AppColors.warning;
    return AppColors.danger;
  }

  String _riskLabel(int r) {
    if (r <= 4) return 'Low';
    if (r <= 8) return 'Medium';
    return 'High';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mission Approval')),
        body: const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final m = _mission!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mission Approval'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: MissionStepIndicator(
                step: 3, label: 'Mission Approval & Briefing'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          _approvalHeader(m),
          const SizedBox(height: 10),
          _missionInfoCard(m),
          if (_flightPlan != null) _flightPlanCard(_flightPlan!),
          _hiraCard(),
          _crewBriefingCard(m),
          if (_highestRisk >= 9) _highRiskAlert(),
        ],
      ),
      bottomNavigationBar: MissionActionBar(
        label: 'All crew briefed — Proceed to Equipment Check',
        isSaving: _isSaving,
        onAction: _approve,
      ),
    );
  }

  Widget _approvalHeader(Mission m) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.verified_outlined, color: AppColors.primary, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('MISSION APPROVAL & CREW BRIEFING',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(m.missionId,
                style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 13,
                    fontFamily: 'monospace')),
          ]),
        ),
      ]),
    );
  }

  Widget _missionInfoCard(Mission m) {
    return MissionFlowCard(
      icon: Icons.info_outline,
      title: 'Mission Information',
      child: Column(children: [
        _row(Icons.label_outline, 'Title', m.title),
        _row(Icons.calendar_today, 'Date & Time', '${m.date}   ${m.timeStr}'),
        _row(Icons.location_on_outlined, 'Location', m.location),
        _row(Icons.air, 'Aircraft', '${m.aircraftName} (${m.aircraftType})'),
        _row(Icons.terrain, 'Environment', m.environment),
        if (m.crpAdvisoryNotes.isNotEmpty)
          _row(Icons.notes_outlined, 'CRP Advisory', m.crpAdvisoryNotes),
      ]),
    );
  }

  Widget _flightPlanCard(FlightPlan fp) {
    return MissionFlowCard(
      icon: Icons.map_outlined,
      title: 'Flight Plan Summary',
      child: Column(children: [
        _row(Icons.location_searching, 'Area', fp.areaOfOperation),
        if (fp.windSpeed != null)
          _row(Icons.air, 'Wind', '${fp.windSpeed} m/s'),
        if (fp.visibility != null)
          _row(Icons.visibility_outlined, 'Visibility', '${fp.visibility} km'),
        if (fp.airspaceClass.isNotEmpty)
          _row(Icons.flight_outlined, 'Airspace Class', fp.airspaceClass),
        if (fp.notams.isNotEmpty)
          _row(Icons.warning_amber_outlined, 'NOTAMs', fp.notams),
        if (fp.contingencyPlan.isNotEmpty)
          _row(Icons.alt_route_outlined, 'Contingency', fp.contingencyPlan),
      ]),
    );
  }

  Widget _hiraCard() {
    if (_hiraRows.isEmpty) {
      return MissionFlowCard(
        icon: Icons.warning_amber_outlined,
        title: 'HIRA Summary',
        child: Text('No HIRA rows recorded.',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
      );
    }

    return MissionFlowCard(
      icon: Icons.warning_amber_outlined,
      title: 'HIRA Summary  —  Overall Risk: ${_riskLabel(_highestRisk)}',
      child: Column(
        children: _hiraRows.map((r) {
          return Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _riskColor(r.risk).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _riskColor(r.risk).withValues(alpha: 0.3)),
            ),
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.hazard,
                          style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      if (r.mitigation.isNotEmpty) ...[
                        SizedBox(height: 2),
                        Text('Mitigation: ${r.mitigation}',
                            style: TextStyle(
                                color: context.colors.textSecondary, fontSize: 11)),
                      ],
                    ]),
              ),
              const SizedBox(width: 8),
              Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _riskColor(r.risk).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${r.risk} — ${_riskLabel(r.risk)}',
                      style: TextStyle(
                          color: _riskColor(r.risk),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _crewBriefingCard(Mission m) {
    final briefings = <Map<String, String>>[
      for (final c in m.crew)
        {'name': c.name, 'role': _roleLabel(c.role), 'brief': _roleBrief(c.role)},
    ];

    return MissionFlowCard(
      icon: Icons.people_outline,
      title: 'Crew Briefing',
      child: Column(
        children: briefings.map((b) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person,
                    size: 16, color: AppColors.primaryLight),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(b['name']!,
                      style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(b['role']!,
                      style: TextStyle(
                          color: AppColors.accent, fontSize: 11)),
                  SizedBox(height: 2),
                  Text(b['brief']!,
                      style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 11,
                          height: 1.4)),
                ]),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _highRiskAlert() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: const Row(children: [
        Icon(Icons.warning, color: AppColors.danger, size: 18),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'HIGH RISK mission — ensure CRP / Senior Officer has reviewed and approved before proceeding.',
            style: TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 13, color: context.colors.textMuted),
        SizedBox(width: 8),
        SizedBox(
            width: 90,
            child: Text('$label:',
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 12))),
        Expanded(
            child: Text(value,
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500))),
      ]),
    );
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'rpic':  return 'RPIC — Remote Pilot in Command';
      case 'vo':    return 'VO — Visual Observer';
      case 'gcs':   return 'GCS Operator';
      case 'tech':  return 'Technical Crew Member';
      default:      return role.toUpperCase();
    }
  }

  String _roleBrief(String role) {
    switch (role.toUpperCase()) {
      case 'RPIC':
        return 'Responsible for pre-flight authorization, mission execution, and all emergency decisions. Maintains situational awareness throughout.';
      case 'VO':
      case 'VO/GCS':
        return 'Maintain continuous visual line-of-sight with the aircraft. Monitor airspace for conflicts. Report anomalies to RPIC immediately.';
      case 'GCS':
        return 'Operate ground control station. Monitor telemetry, battery, and data links. Coordinate with RPIC on all GCS observations.';
      case 'TECH':
        return 'Technical Crew Member — responsible for equipment preparation, airframe maintenance checks, and data offload after the mission.';
      default:
        return 'Follow RPIC instructions. Maintain communication discipline. Report any safety concerns immediately.';
    }
  }
}
