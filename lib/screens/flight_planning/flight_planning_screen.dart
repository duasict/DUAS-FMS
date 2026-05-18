import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../models/flight_plan.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../checklists/checklist_widgets.dart';
import '../hira/hira_screen.dart';
import '../shared/mission_flow_widgets.dart';

class FlightPlanningScreen extends StatefulWidget {
  final int missionId;
  final String missionTitle;
  const FlightPlanningScreen(
      {super.key, required this.missionId, required this.missionTitle});

  @override
  State<FlightPlanningScreen> createState() => _FlightPlanningScreenState();
}

class _FlightPlanningScreenState extends State<FlightPlanningScreen> {
  final _areaCtrl = TextEditingController();
  final _windCtrl = TextEditingController();
  final _visCtrl = TextEditingController();
  final _forecastCtrl = TextEditingController();
  final _notamsCtrl = TextEditingController();
  final _restrictionsCtrl = TextEditingController();
  final _objectivesCtrl = TextEditingController();
  final _contingencyCtrl = TextEditingController();

  String _airspaceClass = 'G (Uncontrolled)';
  bool _isLoading = true;
  bool _isSaving = false;

  static const _airspaceClasses = [
    'A', 'B', 'C', 'D', 'E', 'G (Uncontrolled)', 'Restricted', 'Danger',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final existing = await DatabaseHelper.instance
        .getFlightPlanByMissionId(widget.missionId);
    if (existing != null && mounted) {
      _areaCtrl.text = existing.areaOfOperation;
      _windCtrl.text = existing.windSpeed?.toString() ?? '';
      _visCtrl.text = existing.visibility?.toString() ?? '';
      _forecastCtrl.text = existing.weatherForecast;
      _airspaceClass = existing.airspaceClass.isNotEmpty
          ? existing.airspaceClass
          : _airspaceClass;
      _notamsCtrl.text = existing.notams;
      _restrictionsCtrl.text = existing.airspaceRestrictions;
      _objectivesCtrl.text = existing.missionObjectives;
      _contingencyCtrl.text = existing.contingencyPlan;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _areaCtrl.dispose();
    _windCtrl.dispose();
    _visCtrl.dispose();
    _forecastCtrl.dispose();
    _notamsCtrl.dispose();
    _restrictionsCtrl.dispose();
    _objectivesCtrl.dispose();
    _contingencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_areaCtrl.text.trim().isEmpty ||
        _objectivesCtrl.text.trim().isEmpty ||
        _contingencyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Area of operation, objectives and contingency plan are required.'),
          backgroundColor: AppColors.danger));
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<AppProvider>();
    final navigator = Navigator.of(context);

    final fp = FlightPlan(
      missionId: widget.missionId,
      areaOfOperation: _areaCtrl.text.trim(),
      windSpeed: double.tryParse(_windCtrl.text.trim()),
      visibility: double.tryParse(_visCtrl.text.trim()),
      weatherForecast: _forecastCtrl.text.trim(),
      airspaceClass: _airspaceClass,
      notams: _notamsCtrl.text.trim(),
      airspaceRestrictions: _restrictionsCtrl.text.trim(),
      missionObjectives: _objectivesCtrl.text.trim(),
      contingencyPlan: _contingencyCtrl.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );

    await DatabaseHelper.instance.saveFlightPlan(fp);

    final mission =
        await DatabaseHelper.instance.getMissionById(widget.missionId);
    if (mission != null) {
      mission.hasFlightPlanComplete = true;
      await provider.updateMission(mission);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    navigator.push(MaterialPageRoute(
      builder: (_) => HiraScreen(
          missionId: widget.missionId, missionTitle: widget.missionTitle),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flight Planning'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: MissionStepIndicator(step: 1, label: 'Flight Planning'),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                ChecklistMissionBanner(title: widget.missionTitle),
                const SizedBox(height: 16),
                MissionFlowCard(
                  icon: Icons.map_outlined,
                  title: 'Area of Operation',
                  child: _field(_areaCtrl,
                      'Describe the operational area, boundaries, and key landmarks...',
                      maxLines: 4),
                ),
                MissionFlowCard(
                  icon: Icons.cloud_outlined,
                  title: 'Weather Check',
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                          child: _field(_windCtrl, 'Wind speed (m/s)',
                              keyboardType: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _field(_visCtrl, 'Visibility (km)',
                              keyboardType: TextInputType.number)),
                    ]),
                    const SizedBox(height: 10),
                    _field(_forecastCtrl,
                        'Weather forecast / conditions (PAGASA, Windy, etc.)...'),
                  ]),
                ),
                MissionFlowCard(
                  icon: Icons.flight_outlined,
                  title: 'Airspace Check',
                  child: Column(children: [
                    _dropLabel('Airspace Class'),
                    const SizedBox(height: 6),
                    _dropdown(
                      value: _airspaceClass,
                      items: _airspaceClasses,
                      onChanged: (v) => setState(() => _airspaceClass = v!),
                    ),
                    const SizedBox(height: 10),
                    _field(_notamsCtrl,
                        'NOTAMs — list any active notices to airmen...'),
                    const SizedBox(height: 10),
                    _field(_restrictionsCtrl,
                        'Airspace restrictions, TFRs, controlled zones...'),
                  ]),
                ),
                MissionFlowCard(
                  icon: Icons.flag_outlined,
                  title: 'Mission Objectives',
                  child: _field(
                      _objectivesCtrl,
                      'Detail specific mission objectives, deliverables, and success criteria...',
                      maxLines: 4),
                ),
                MissionFlowCard(
                  icon: Icons.alt_route_outlined,
                  title: 'Contingency Plan',
                  child: _field(
                      _contingencyCtrl,
                      'Describe RTH procedures, abort criteria, emergency landing zones, lost-link actions...',
                      maxLines: 4),
                ),
              ],
            ),
      bottomNavigationBar: MissionActionBar(
        label: 'Save & Continue to HIRA',
        isSaving: _isSaving,
        onAction: _submit,
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
      decoration: InputDecoration(hintText: hint, alignLabelWithHint: true),
    );
  }

  Widget _dropLabel(String label) => Align(
        alignment: Alignment.centerLeft,
        child: Text(label,
            style: TextStyle(
                color: context.colors.textSecondary, fontSize: 12)),
      );

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: SizedBox(),
        dropdownColor: context.colors.card,
        style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
        items: items
            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
