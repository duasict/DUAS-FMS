import 'package:flutter/material.dart';
import '../models/mission.dart';
import '../theme/app_theme.dart';

class MissionCard extends StatelessWidget {
  final Mission mission;
  final VoidCallback onTap;

  const MissionCard({super.key, required this.mission, required this.onTap});

  Color _statusColor(BuildContext context) {
    switch (mission.status) {
      case 'completed':
        return AppColors.success;
      case 'planning':
        return AppColors.primary;
      case 'in_progress':
        return AppColors.accent;
      case 'cancelled':
        return context.colors.textMuted;
      default:
        return context.colors.textMuted;
    }
  }

  IconData get _aircraftIcon =>
      mission.aircraftType == 'vtol' ? Icons.airplanemode_active : Icons.air;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    mission.missionId,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (mission.crpConcurrenceRequired)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.4)),
                    ),
                    child: const Text('CRP CONCURRENCE',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        )),
                  ),
                _StatusBadge(
                    label: mission.statusLabel,
                    color: _statusColor(context)),
              ]),
              const SizedBox(height: 6),
              Text(
                mission.title,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.calendar_today,
                    size: 13, color: context.colors.textMuted),
                const SizedBox(width: 4),
                Text(
                  '${mission.date}  ${mission.timeStr}',
                  style:
                      TextStyle(color: context.colors.textSecondary, fontSize: 12),
                ),
                const Spacer(),
                Icon(_aircraftIcon, size: 13, color: context.colors.textMuted),
                const SizedBox(width: 4),
                Text(
                  mission.aircraftName,
                  style:
                      TextStyle(color: context.colors.textSecondary, fontSize: 12),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.location_on,
                    size: 13, color: context.colors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    mission.location,
                    style: TextStyle(
                        color: context.colors.textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              if (mission.isCompleted && mission.duration != null) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.check_circle,
                      size: 14, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'Completed · ${mission.formattedDuration}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
