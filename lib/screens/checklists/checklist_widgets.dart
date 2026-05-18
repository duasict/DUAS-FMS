import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ChecklistProgressBar extends StatelessWidget {
  final int current;
  final List<String>? steps;
  const ChecklistProgressBar({super.key, required this.current, this.steps});

  static const _defaultSteps = ['Pre-flight', 'In-flight', 'Post-flight', 'Log'];

  @override
  Widget build(BuildContext context) {
    final stepList = steps ?? _defaultSteps;
    return Row(
      children: List.generate(stepList.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
              child: Divider(thickness: 1, color: context.colors.border));
        }
        final idx = i ~/ 2;
        final done = idx < current;
        final active = idx == current;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: done
                    ? AppColors.success.withValues(alpha: 0.15)
                    : active
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done
                      ? AppColors.success
                      : active
                          ? AppColors.primary
                          : context.colors.border,
                  width: 1.5,
                ),
              ),
              child: Icon(
                done ? Icons.check : Icons.circle,
                size: 10,
                color: done
                    ? AppColors.success
                    : active
                        ? AppColors.primary
                        : context.colors.textMuted,
              ),
            ),
            SizedBox(width: 4),
            Text(
              stepList[idx],
              style: TextStyle(
                color: done
                    ? AppColors.success
                    : active
                        ? AppColors.primaryLight
                        : context.colors.textMuted,
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class ChecklistMissionBanner extends StatelessWidget {
  final String title;
  const ChecklistMissionBanner({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.flight, size: 15, color: context.colors.textMuted),
          SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class ChecklistSectionHeader extends StatelessWidget {
  final String label;
  const ChecklistSectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class ChecklistSubmitBar extends StatelessWidget {
  final String label;
  final int checked;
  final int total;
  final bool isSaving;
  final VoidCallback onSubmit;

  const ChecklistSubmitBar({
    super.key,
    required this.label,
    required this.checked,
    required this.total,
    required this.isSaving,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('$checked of $total items responded',
                    style: TextStyle(
                        color: context.colors.textSecondary, fontSize: 12)),
                const Spacer(),
                if (checked < total)
                  Text('${total - checked} remaining',
                      style: const TextStyle(
                          color: AppColors.warning, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : onSubmit,
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.arrow_forward, size: 18),
                label: Text(isSaving ? 'Saving...' : label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
