import 'package:flutter/material.dart';
import '../../models/checklist_item.dart';
import '../../database/database_helper.dart';
import '../../theme/app_theme.dart';
import '../../widgets/checklist_tile.dart';
import 'checklist_widgets.dart';

/// Shared base for Equipment, Pre-flight, In-flight, and Post-flight screens.
///
/// [defs]              — list of (section, itemText) tuples
/// [checklistType]     — SQLite key: 'equipment' | 'preflight' | 'inflight' | 'postflight'
/// [stepIndex]         — 0-based index for ChecklistProgressBar
/// [steps]             — optional step labels; defaults to the 4-step flight steps
/// [submitLabel]       — text shown on the submit button
/// [captureTimestamps] — when true, records time_started on load and time_completed on submit
/// [extraSections]     — optional builder for additional widgets prepended before checklist sections
/// [onSubmitComplete]  — called after DB save; receives (context, missionId, missionTitle)
///                       and is responsible for the mission flag update and navigation
class BaseChecklistScreen extends StatefulWidget {
  final int missionId;
  final String missionTitle;
  final List<(String, String)> defs;
  final String checklistType;
  final int stepIndex;
  final List<String>? steps;
  final String submitLabel;
  final bool captureTimestamps;
  final List<Widget> Function()? extraSections;
  final Future<void> Function(
      BuildContext context, int missionId, String missionTitle) onSubmitComplete;

  const BaseChecklistScreen({
    super.key,
    required this.missionId,
    required this.missionTitle,
    required this.defs,
    required this.checklistType,
    required this.stepIndex,
    this.steps,
    required this.submitLabel,
    this.captureTimestamps = false,
    this.extraSections,
    required this.onSubmitComplete,
  });

  @override
  State<BaseChecklistScreen> createState() => _BaseChecklistScreenState();
}

class _BaseChecklistScreenState extends State<BaseChecklistScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  late final List<ChecklistEntry> _items;
  String _timeStarted = '';

  @override
  void initState() {
    super.initState();
    _items = widget.defs
        .map((d) => ChecklistEntry(section: d.$1, text: d.$2))
        .toList();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final db = DatabaseHelper.instance;
    final saved = await db.getChecklistItems(widget.missionId, widget.checklistType);
    if (saved.isNotEmpty) {
      for (var i = 0; i < saved.length && i < _items.length; i++) {
        _items[i].status = saved[i].status;
        _items[i].remark = saved[i].remark;
      }
    }

    if (widget.captureTimestamps) {
      final existing = await db.getChecklistTimestamp(widget.missionId, widget.checklistType);
      final savedStart = existing?['time_started'] as String? ?? '';
      if (savedStart.isNotEmpty) {
        _timeStarted = savedStart;
      } else {
        final now = DateTime.now();
        _timeStarted =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  int get _checkedCount => _items.where((i) => i.status != 0).length;

  Future<void> _submit() async {
    setState(() => _isSaving = true);

    if (widget.captureTimestamps) {
      final now = DateTime.now();
      final timeCompleted =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await DatabaseHelper.instance.saveChecklistTimestamp(
        widget.missionId, widget.checklistType,
        timeStarted: _timeStarted,
        timeCompleted: timeCompleted,
      );
    }

    final dbItems = _items.asMap().entries.map((e) {
      return ChecklistItem(
        missionId: widget.missionId,
        checklistType: widget.checklistType,
        section: e.value.section,
        itemIndex: e.key,
        itemText: e.value.text,
        status: e.value.status,
        remark: e.value.remark,
      );
    }).toList();

    await DatabaseHelper.instance.saveChecklistItems(dbItems);

    if (!mounted) return;
    setState(() => _isSaving = false);

    // Let the caller update the mission flag and navigate.
    // Context use is guarded by the mounted check directly above.
    // ignore: use_build_context_synchronously
    await widget.onSubmitComplete(context, widget.missionId, widget.missionTitle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_titleFor(widget.checklistType)),
            Text(
              _subtitleFor(widget.checklistType),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: context.colors.textSecondary,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: ChecklistProgressBar(
                current: widget.stepIndex, steps: widget.steps),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
              children: [
                ChecklistMissionBanner(title: widget.missionTitle),
                if (widget.captureTimestamps && _timeStarted.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _TimestampBanner(timeStarted: _timeStarted),
                ],
                const SizedBox(height: 12),
                if (widget.extraSections != null) ...widget.extraSections!(),
                ..._buildSections(),
              ],
            ),
      bottomNavigationBar: ChecklistSubmitBar(
        label: widget.submitLabel,
        checked: _checkedCount,
        total: _items.length,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  List<Widget> _buildSections() {
    // Build a section→[indices] map in O(N) — avoids O(N²) indexOf calls.
    final sectionIndices = <String, List<int>>{};
    for (var i = 0; i < _items.length; i++) {
      (sectionIndices[_items[i].section] ??= []).add(i);
    }

    final widgets = <Widget>[];
    for (final entry in sectionIndices.entries) {
      widgets.add(ChecklistSectionHeader(label: entry.key));
      for (final idx in entry.value) {
        widgets.add(ChecklistTile(
          text: _items[idx].text,
          status: _items[idx].status,
          remark: _items[idx].remark,
          onChanged: (s, r) => setState(() {
            _items[idx].status = s;
            _items[idx].remark = r;
          }),
        ));
      }
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  static const _checklistMeta = {
    'equipment':  ('Equipment Checklist',       'Pre-mission equipment verification'),
    'preflight':  ('Pre-flight Checklist',      'Annex A pre-flight compliance'),
    'inflight':   ('In-flight Checklist',       'Annex A in-flight monitoring'),
    'postflight': ('Post-flight Checklist',     'Annex A post-flight compliance'),
  };

  String _titleFor(String type) => _checklistMeta[type]?.$1 ?? 'Checklist';

  String _subtitleFor(String type) => _checklistMeta[type]?.$2 ?? 'Annex A compliance checklist';
}

class _TimestampBanner extends StatelessWidget {
  final String timeStarted;
  const _TimestampBanner({required this.timeStarted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(Icons.access_time_outlined, size: 13, color: AppColors.primary),
        const SizedBox(width: 7),
        Text('Started: $timeStarted',
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
