import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';

/// Captures the device's current GPS position after checklist confirmation.
/// Returns null lat/lon silently if location is unavailable or denied.
Future<({double? lat, double? lon})> captureGps() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return (lat: null, lon: null);
    }
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return (lat: null, lon: null);
    }
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return (lat: pos.latitude, lon: pos.longitude);
  } catch (_) {
    return (lat: null, lon: null);
  }
}

/// Shows a full-screen-blocking dialog prompting the user to confirm a
/// timestamped event (take-off or landing).
///
/// Returns the current time as `'HH:MM'` if the user confirms, or `null` if
/// they tap Skip.
Future<String?> showTimeConfirmationDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required IconData icon,
  required Color color,
}) async {
  final now     = DateTime.now();
  final timeStr = '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}';

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: ctx.colors.card,
      title: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                color: ctx.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Current time',
            style: TextStyle(
                color: ctx.colors.textSecondary, fontSize: 13)),
        const SizedBox(height: 10),
        Text(timeStr,
            style: TextStyle(
                color: color,
                fontSize: 48,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                fontFeatures: const [FontFeature.tabularFigures()])),
        Text('UTC+8',
            style: TextStyle(
                color: ctx.colors.textMuted, fontSize: 11)),
        const SizedBox(height: 14),
        Text(
          'This time will be recorded in the flight log.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: ctx.colors.textSecondary, fontSize: 12, height: 1.4),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Skip',
              style: TextStyle(color: ctx.colors.textMuted)),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: Icon(icon, size: 16),
          label: Text(confirmLabel),
          style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: Colors.white),
        ),
      ],
    ),
  );

  return confirmed == true ? timeStr : null;
}

// ─────────────────────────────────────────────────────────────────────────────
//  ChecklistEntry
//
//  Mutable in-memory state for one checklist item.  Shared by BaseChecklistScreen
//  and FitToFlyScreen so neither needs its own duplicate private class.
// ─────────────────────────────────────────────────────────────────────────────
class ChecklistEntry {
  final String section;
  final String text;
  int status;
  String remark;
  ChecklistEntry({required this.section, required this.text})
      : status = 0,
        remark = '';
}

// ─────────────────────────────────────────────────────────────────────────────
//  ChecklistProgressBar
//
//  Renders a horizontal step-indicator that is overflow-safe for any number
//  of steps. Each step indicator (circle + label) is wrapped in Flexible so
//  it can shrink proportionally. The text uses overflow:ellipsis as a last
//  resort. Dividers between steps use Expanded with a fixed flex weight.
// ─────────────────────────────────────────────────────────────────────────────
class ChecklistProgressBar extends StatelessWidget {
  final int current;
  final List<String>? steps;
  const ChecklistProgressBar({super.key, required this.current, this.steps});

  static const _defaultSteps = ['Pre-flight', 'In-flight', 'Post-flight', 'Log'];

  @override
  Widget build(BuildContext context) {
    final stepList = steps ?? _defaultSteps;
    // Vertical layout: circle above, label below, centered.
    // Connector lines are padded to align with circle mid-points (10 px top
    // offset = half the 20 px circle height).
    return SizedBox(
      height: 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(stepList.length * 2 - 1, (i) {
          if (i.isOdd) {
            final leftDone = (i ~/ 2) < current;
            return Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(top: 9.5),
                child: Container(
                  height: 1.5,
                  color: leftDone
                      ? AppColors.success.withValues(alpha: 0.5)
                      : context.colors.border,
                ),
              ),
            );
          }

          final idx = i ~/ 2;
          final done = idx < current;
          final active = idx == current;

          final circleColor = done
              ? AppColors.success
              : active
                  ? AppColors.primary
                  : context.colors.border;
          final circleFill = done
              ? AppColors.success.withValues(alpha: 0.12)
              : active
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : Colors.transparent;
          final labelColor = done
              ? AppColors.success
              : active
                  ? AppColors.primaryLight
                  : context.colors.textMuted;

          return Expanded(
            flex: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: circleFill,
                    shape: BoxShape.circle,
                    border: Border.all(color: circleColor, width: 1.5),
                  ),
                  child: Icon(
                    done ? Icons.check : Icons.circle,
                    size: 10,
                    color: circleColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  stepList[idx],
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 9,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ChecklistMissionBanner
// ─────────────────────────────────────────────────────────────────────────────
class ChecklistMissionBanner extends StatelessWidget {
  final String title;
  const ChecklistMissionBanner({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.flight, size: 15, color: context.colors.textMuted),
          const SizedBox(width: 8),
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

// ─────────────────────────────────────────────────────────────────────────────
//  ChecklistSectionHeader
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
//  ChecklistSubmitBar
// ─────────────────────────────────────────────────────────────────────────────
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
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    '$checked of $total items responded',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.colors.textSecondary, fontSize: 12),
                  ),
                ),
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
                label: Text(
                  isSaving ? 'Saving...' : label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
