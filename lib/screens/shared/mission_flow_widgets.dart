import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Step indicator pill shown in AppBar bottom for the 9-step mission flow.
class MissionStepIndicator extends StatelessWidget {
  final int step;
  final String label;
  const MissionStepIndicator(
      {super.key, required this.step, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Text(
          'Step $step of 9',
          style: TextStyle(
              color: AppColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w700),
        ),
      ),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]);
  }
}

/// Titled card with icon header and divider — used in form/summary screens.
class MissionFlowCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const MissionFlowCard(
      {super.key, required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: context.colors.textMuted),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

/// Single full-width action button bar — for non-checklist mission flow screens.
class MissionActionBar extends StatelessWidget {
  final String label;
  final bool isSaving;
  /// Null disables the button (e.g. when CRP has rejected the mission).
  final VoidCallback? onAction;
  const MissionActionBar(
      {super.key,
      required this.label,
      required this.isSaving,
      required this.onAction});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.border)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: isSaving ? null : onAction,
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
      ),
    );
  }
}
