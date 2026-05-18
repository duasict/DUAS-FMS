import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ChecklistTile extends StatefulWidget {
  final String text;
  final int status; // 0=unchecked, 1=pass, 2=fail
  final String remark;
  final bool readOnly;
  final void Function(int status, String remark)? onChanged;

  const ChecklistTile({
    super.key,
    required this.text,
    required this.status,
    this.remark = '',
    this.readOnly = false,
    this.onChanged,
  });

  @override
  State<ChecklistTile> createState() => _ChecklistTileState();
}

class _ChecklistTileState extends State<ChecklistTile> {
  late int _status;
  late TextEditingController _remarkCtrl;
  bool _remarkExpanded = false;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _remarkCtrl = TextEditingController(text: widget.remark);
    _remarkExpanded = widget.remark.isNotEmpty;
  }

  @override
  void dispose() {
    _remarkCtrl.dispose();
    super.dispose();
  }

  void _setStatus(int s) {
    if (widget.readOnly) return;
    setState(() => _status = _status == s ? 0 : s);
    widget.onChanged?.call(_status, _remarkCtrl.text);
  }

  void _onRemarkChanged(String val) {
    widget.onChanged?.call(_status, val);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: _statusBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _statusBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status indicator dot
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      color: _status == 2
                          ? AppColors.danger
                          : context.colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!widget.readOnly) ...[
                  _ActionButton(
                    icon: Icons.check,
                    active: _status == 1,
                    activeColor: AppColors.success,
                    onTap: () => _setStatus(1),
                  ),
                  SizedBox(width: 6),
                  _ActionButton(
                    icon: Icons.close,
                    active: _status == 2,
                    activeColor: AppColors.danger,
                    onTap: () => _setStatus(2),
                  ),
                  SizedBox(width: 6),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _remarkExpanded = !_remarkExpanded),
                    child: Icon(
                      _remarkExpanded
                          ? Icons.chat_bubble
                          : Icons.chat_bubble_outline,
                      size: 18,
                      color: _remarkCtrl.text.isNotEmpty
                          ? AppColors.accent
                          : context.colors.textMuted,
                    ),
                  ),
                ] else ...[
                  _ReadOnlyBadge(status: _status),
                ],
              ],
            ),
          ),
          if (widget.readOnly && widget.remark.isNotEmpty)
            _RemarkDisplay(remark: widget.remark),
          if (!widget.readOnly && _remarkExpanded)
            Padding(
              padding: EdgeInsets.fromLTRB(28, 0, 12, 10),
              child: TextField(
                controller: _remarkCtrl,
                onChanged: _onRemarkChanged,
                style: TextStyle(
                    color: context.colors.textPrimary, fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Add remark...',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                maxLines: 2,
                minLines: 1,
              ),
            ),
        ],
      ),
    );
  }

  Color get _statusBg {
    switch (_status) {
      case 1:
        return AppColors.success.withValues(alpha:0.05);
      case 2:
        return AppColors.danger.withValues(alpha:0.05);
      default:
        return context.colors.surface;
    }
  }

  Color get _statusBorder {
    switch (_status) {
      case 1:
        return AppColors.success.withValues(alpha:0.3);
      case 2:
        return AppColors.danger.withValues(alpha:0.3);
      default:
        return context.colors.border;
    }
  }

  Color get _dotColor {
    switch (_status) {
      case 1:
        return AppColors.success;
      case 2:
        return AppColors.danger;
      default:
        return context.colors.textMuted;
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha:0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: active ? activeColor : context.colors.border, width: 1),
        ),
        child: Icon(icon, size: 16,
            color: active ? activeColor : context.colors.textMuted),
      ),
    );
  }
}

class _ReadOnlyBadge extends StatelessWidget {
  final int status;
  const _ReadOnlyBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == 0) return const SizedBox.shrink();
    final isPassed = status == 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: (isPassed ? AppColors.success : AppColors.danger)
            .withValues(alpha:0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isPassed ? 'PASS' : 'FAIL',
        style: TextStyle(
          color: isPassed ? AppColors.success : AppColors.danger,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RemarkDisplay extends StatelessWidget {
  final String remark;
  const _RemarkDisplay({required this.remark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(28, 0, 12, 8),
      child: Row(
        children: [
          Icon(Icons.chat_bubble,
              size: 12, color: context.colors.textMuted),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              remark,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
