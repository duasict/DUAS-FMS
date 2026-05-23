import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../models/hira_row.dart';
import '../../providers/app_provider.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../checklists/checklist_widgets.dart';
import '../equipment_checklist/equipment_checklist_screen.dart';
import '../mission_approval/mission_approval_screen.dart';
import '../shared/mission_flow_widgets.dart';

class HiraScreen extends StatefulWidget {
  final int missionId;
  final String missionTitle;
  const HiraScreen(
      {super.key, required this.missionId, required this.missionTitle});

  @override
  State<HiraScreen> createState() => _HiraScreenState();
}

class _RowEntry {
  int? dbId;
  final TextEditingController hazardCtrl;
  final TextEditingController mitigationCtrl;
  int likelihood;
  int impact;
  int residualRisk;

  _RowEntry({this.dbId})
      : hazardCtrl = TextEditingController(),
        mitigationCtrl = TextEditingController(),
        likelihood = 1,
        impact = 1,
        residualRisk = 1;

  int get risk => likelihood * impact;

  Color get riskColor {
    final r = risk;
    if (r <= 4) return AppColors.success;
    if (r <= 8) return AppColors.warning;
    return AppColors.danger;
  }

  String get riskLabel {
    final r = risk;
    if (r <= 4) return 'Low';
    if (r <= 8) return 'Medium';
    return 'High';
  }

  void dispose() {
    hazardCtrl.dispose();
    mitigationCtrl.dispose();
  }
}

class _HiraScreenState extends State<HiraScreen> {
  final List<_RowEntry> _rows = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await DatabaseHelper.instance
        .getHiraRowsByMissionId(widget.missionId);
    if (saved.isEmpty) {
      _rows.add(_RowEntry());
    } else {
      for (final r in saved) {
        final e = _RowEntry(dbId: r.id);
        e.hazardCtrl.text = r.hazard;
        e.mitigationCtrl.text = r.mitigation;
        e.likelihood = r.likelihood;
        e.impact = r.impact;
        e.residualRisk = r.residualRisk;
        _rows.add(e);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() => _rows.add(_RowEntry()));
  }

  void _removeRow(int i) {
    setState(() {
      _rows[i].dispose();
      _rows.removeAt(i);
    });
  }

  bool get _hasHighRisk => _rows.any((r) => r.risk >= 9);

  Future<void> _submit() async {
    for (final r in _rows) {
      if (r.hazardCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('All hazard fields must be filled in.'),
            backgroundColor: AppColors.danger));
        return;
      }
    }

    setState(() => _isSaving = true);
    final provider = context.read<AppProvider>();
    final navigator = Navigator.of(context);

    final hiraRows = _rows
        .map((e) => HiraRow(
              missionId: widget.missionId,
              hazard: e.hazardCtrl.text.trim(),
              likelihood: e.likelihood,
              impact: e.impact,
              mitigation: e.mitigationCtrl.text.trim(),
              residualRisk: e.residualRisk,
            ))
        .toList();

    await DatabaseHelper.instance.saveHiraRows(widget.missionId, hiraRows);

    final mission =
        await DatabaseHelper.instance.getMissionById(widget.missionId);
    if (mission != null) {
      mission.hasHiraComplete = true;
      mission.crpConcurrenceRequired = _hasHighRisk;
      await provider.updateMission(mission);
      if (_hasHighRisk) {
        await NotificationService.showConcurrenceRequest(
            widget.missionTitle, mission.title);
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    // High-risk: MissionApprovalScreen._approve() already pushes
    // EquipmentChecklistScreen — so we just go there first.
    // Low-risk: skip approval and go straight to equipment checklist.
    if (_hasHighRisk) {
      navigator.push(MaterialPageRoute(
        builder: (_) => MissionApprovalScreen(missionId: widget.missionId),
      ));
    } else {
      navigator.push(MaterialPageRoute(
        builder: (_) => EquipmentChecklistScreen(
          missionId: widget.missionId,
          missionTitle: widget.missionTitle,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HIRA & Risk Assessment'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child:
                MissionStepIndicator(step: 2, label: 'HIRA & Risk Assessment'),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 120),
              children: [
                ChecklistMissionBanner(title: widget.missionTitle),
                const SizedBox(height: 10),
                _RiskMatrixKey(),
                if (_hasHighRisk) ...[
                  const SizedBox(height: 8),
                  _HighRiskBanner(),
                ],
                const SizedBox(height: 12),
                ..._buildRows(),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Hazard Row'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryLight),
                ),
              ],
            ),
      bottomNavigationBar: MissionActionBar(
        label: _hasHighRisk
            ? 'Save & Request CRP Approval'
            : 'Save & Continue to Equipment Checklist',
        isSaving: _isSaving,
        onAction: _submit,
      ),
    );
  }

  List<Widget> _buildRows() {
    return List.generate(_rows.length, (i) {
      final row = _rows[i];
      return AnimatedBuilder(
        animation: Listenable.merge([row.hazardCtrl, row.mitigationCtrl]),
        builder: (_, _) => _HiraRowCard(
          index: i,
          entry: row,
          onDelete: _rows.length > 1 ? () => _removeRow(i) : null,
          onChanged: () => setState(() {}),
        ),
      );
    });
  }
}

class _HiraRowCard extends StatelessWidget {
  final int index;
  final _RowEntry entry;
  final VoidCallback? onDelete;
  final VoidCallback onChanged;

  const _HiraRowCard({
    required this.index,
    required this.entry,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final risk = entry.risk;
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: risk >= 9
                ? AppColors.danger.withValues(alpha: 0.5)
                : context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('Hazard #${index + 1}',
                style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
          Spacer(),
          if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.delete_outline,
                  size: 18, color: AppColors.danger),
            ),
        ]),
        SizedBox(height: 8),
        _label(context, 'Hazard / Threat'),
        SizedBox(height: 4),
        TextField(
          controller: entry.hazardCtrl,
          style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
          decoration:
              const InputDecoration(hintText: 'Describe the hazard...'),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(context, 'Likelihood (1–5)'),
                  const SizedBox(height: 4),
                  _RatingSelector(
                    value: entry.likelihood,
                    onChanged: (v) {
                      entry.likelihood = v;
                      onChanged();
                    },
                  ),
                ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(context, 'Impact (1–5)'),
                  const SizedBox(height: 4),
                  _RatingSelector(
                    value: entry.impact,
                    onChanged: (v) {
                      entry.impact = v;
                      onChanged();
                    },
                  ),
                ]),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            _label(context, 'Risk'),
            const SizedBox(height: 4),
            Container(
              width: 44,
              height: 36,
              decoration: BoxDecoration(
                color: entry.riskColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: entry.riskColor.withValues(alpha: 0.5)),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$risk',
                        style: TextStyle(
                            color: entry.riskColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    Text(entry.riskLabel,
                        style: TextStyle(
                            color: entry.riskColor,
                            fontSize: 7,
                            fontWeight: FontWeight.w600)),
                  ]),
            ),
          ]),
        ]),
        SizedBox(height: 10),
        _label(context, 'Mitigation Measures'),
        SizedBox(height: 4),
        TextField(
          controller: entry.mitigationCtrl,
          maxLines: 2,
          style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
          decoration: const InputDecoration(
              hintText: 'Describe control measures...'),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _label(context, 'Residual Risk (1–5)'),
                SizedBox(height: 4),
                _RatingSelector(
                  value: entry.residualRisk,
                  onChanged: (v) {
                    entry.residualRisk = v;
                    onChanged();
                  },
                  activeColor: entry.riskColor,
                ),
              ])),
        ]),
      ]),
    );
  }

  Widget _label(BuildContext context, String text) => Text(text,
      style: TextStyle(color: context.colors.textSecondary, fontSize: 11));
}

class _RatingSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final Color? activeColor;
  const _RatingSelector(
      {required this.value, required this.onChanged, this.activeColor});

  @override
  Widget build(BuildContext context) {
    final active = activeColor ?? AppColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final v = i + 1;
        final sel = v == value;
        return GestureDetector(
          onTap: () => onChanged(v),
          child: Container(
            margin: EdgeInsets.only(right: 4),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color:
                  sel ? active.withValues(alpha: 0.15) : context.colors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: sel
                      ? active.withValues(alpha: 0.7)
                      : context.colors.border),
            ),
            child: Center(
              child: Text('$v',
                  style: TextStyle(
                      color: sel ? active : context.colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        );
      }),
    );
  }
}

class _RiskMatrixKey extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('RISK MATRIX KEY  (Risk = Likelihood × Impact)',
            style: TextStyle(
                color: context.colors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        SizedBox(height: 8),
        Row(children: [
          _keyBadge('1–4', 'Low', AppColors.success),
          SizedBox(width: 8),
          _keyBadge('5–8', 'Medium', AppColors.warning),
          SizedBox(width: 8),
          _keyBadge('9–25', 'High', AppColors.danger),
        ]),
        SizedBox(height: 6),
        Text(
            'Low: Proceed  •  Medium: RPIC approves  •  High: CRP/SO approval required',
            style: TextStyle(color: context.colors.textMuted, fontSize: 10)),
      ]),
    );
  }

  Widget _keyBadge(String range, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(range,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 10)),
      ]),
    );
  }
}

class _HighRiskBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: const Row(children: [
        Icon(Icons.warning, color: AppColors.danger, size: 16),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'HIGH RISK detected — CRP / Senior Officer approval required before proceeding.',
            style: TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}
