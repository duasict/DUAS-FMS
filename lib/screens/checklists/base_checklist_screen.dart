import 'package:flutter/material.dart';
import '../../models/checklist_item.dart';
import '../../database/database_helper.dart';
import '../../theme/app_theme.dart';
import '../../widgets/checklist_tile.dart';
import 'checklist_widgets.dart';

/// A single checklist item held in memory while the screen is open.
class _Item {
  final String section;
  final String text;
  int status;
  String remark;
  _Item({required this.section, required this.text})
      : status = 0,
        remark = '';
}

/// Shared base for Pre-flight, In-flight, and Post-flight checklist screens.
///
/// [defs]              — list of (section, itemText) tuples
/// [checklistType]     — SQLite key: 'preflight' | 'inflight' | 'postflight'
/// [stepIndex]         — 0-based index for ChecklistProgressBar
/// [submitLabel]       — text shown on the submit button
/// [onSubmitComplete]  — called after DB save; receives (missionId, missionTitle)
///                       and is responsible for navigation + mission flag update
class BaseChecklistScreen extends StatefulWidget {
  final int missionId;
  final String missionTitle;
  final List<(String, String)> defs;
  final String checklistType;
  final int stepIndex;
  final String submitLabel;
  final Future<void> Function(
      BuildContext context, int missionId, String missionTitle) onSubmitComplete;

  const BaseChecklistScreen({
    super.key,
    required this.missionId,
    required this.missionTitle,
    required this.defs,
    required this.checklistType,
    required this.stepIndex,
    required this.submitLabel,
    required this.onSubmitComplete,
  });

  @override
  State<BaseChecklistScreen> createState() => _BaseChecklistScreenState();
}

class _BaseChecklistScreenState extends State<BaseChecklistScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  late final List<_Item> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.defs
        .map((d) => _Item(section: d.$1, text: d.$2))
        .toList();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final saved = await DatabaseHelper.instance
        .getChecklistItems(widget.missionId, widget.checklistType);
    if (saved.isNotEmpty) {
      for (var i = 0; i < saved.length && i < _items.length; i++) {
        _items[i].status = saved[i].status;
        _items[i].remark = saved[i].remark;
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  int get _checkedCount => _items.where((i) => i.status != 0).length;

  Future<void> _submit() async {
    setState(() => _isSaving = true);

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
        title: Text(_titleFor(widget.checklistType)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ChecklistProgressBar(current: widget.stepIndex),
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
                const SizedBox(height: 12),
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
    final sections = <String>[];
    for (final item in _items) {
      if (!sections.contains(item.section)) sections.add(item.section);
    }
    final widgets = <Widget>[];
    for (final section in sections) {
      widgets.add(ChecklistSectionHeader(label: section));
      final sectionItems = _items.where((i) => i.section == section).toList();
      for (final item in sectionItems) {
        final idx = _items.indexOf(item);
        widgets.add(ChecklistTile(
          text: item.text,
          status: item.status,
          remark: item.remark,
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

  String _titleFor(String type) {
    switch (type) {
      case 'preflight':  return 'Pre-flight Checklist';
      case 'inflight':   return 'In-flight Checklist';
      case 'postflight': return 'Post-flight Checklist';
      default:           return 'Checklist';
    }
  }
}
