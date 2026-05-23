import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/org_settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/mission_card.dart';
import '../mission_details/mission_details_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final orgTagline = context.watch<OrgSettingsProvider>().tagline;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(orgTagline,
                style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          if (provider.isSyncing)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accent),
              ),
            )
          else
            IconButton(
              icon: Icon(
                provider.isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: provider.isOnline
                    ? AppColors.success
                    : context.colors.textMuted,
                size: 22,
              ),
              tooltip: provider.isOnline ? 'Online' : 'Offline',
              onPressed: provider.isOnline
                  ? () => provider.syncData()
                  : null,
            ),
          SizedBox(width: 4),
        ],
      ),
      body: provider.isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: context.colors.card,
              onRefresh: provider.refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  // Sync banner
                  _SyncBanner(provider: provider),

                  // Stats grid
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.15,
                    children: [
                      StatCard(
                        label: 'Total Missions',
                        value:
                            '${provider.stats['missions'] ?? 0}',
                        icon: Icons.flight_takeoff,
                        color: AppColors.primary,
                      ),
                      StatCard(
                        label: 'Aircraft',
                        value:
                            '${provider.stats['aircraft'] ?? 0}',
                        icon: Icons.air,
                        color: AppColors.accent,
                      ),
                      StatCard(
                        label: 'Pending Concurrences',
                        value:
                            '${provider.stats['pendingConcurrences'] ?? 0}',
                        icon: Icons.pending_actions,
                        color: AppColors.warning,
                      ),
                      StatCard(
                        label: 'Total Flight Hours',
                        value:
                            '${provider.stats['totalFlightHours'] ?? 0}h',
                        icon: Icons.timer_outlined,
                        color: AppColors.success,
                      ),
                    ],
                  ),

                  // Upcoming missions header
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        'UPCOMING MISSIONS',
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Spacer(),
                      Text(
                        '${provider.upcomingMissions.length} scheduled',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (provider.upcomingMissions.isEmpty)
                    _EmptyState(
                      icon: Icons.flight_land,
                      message: 'No upcoming missions scheduled.',
                    )
                  else
                    ...provider.upcomingMissions.map(
                      (m) => MissionCard(
                        mission: m,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MissionDetailsScreen(missionId: m.id!),
                            ),
                          ).then((_) => provider.refreshMissions());
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  final AppProvider provider;
  const _SyncBanner({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.isSyncing) {
      return _BannerTile(
        icon: Icons.sync,
        iconColor: AppColors.accent,
        message: 'Syncing data to cloud...',
        bgColor: AppColors.accent.withValues(alpha: 0.08),
        borderColor: AppColors.accent.withValues(alpha: 0.3),
        trailing: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.accent),
        ),
      );
    }
    if (provider.hasUnsyncedData) {
      return _BannerTile(
        icon: Icons.cloud_upload_outlined,
        iconColor: AppColors.warning,
        message:
            '${provider.unsyncedCount} record(s) saved locally, not yet synced.',
        subMessage: provider.isOnline
            ? 'Tap to sync now.'
            : 'Connect to internet to sync.',
        bgColor: AppColors.warning.withValues(alpha: 0.08),
        borderColor: AppColors.warning.withValues(alpha: 0.3),
        onTap: provider.isOnline ? () => provider.syncData() : null,
      );
    }
    if (provider.isOnline) {
      return _BannerTile(
        icon: Icons.cloud_done,
        iconColor: AppColors.success,
        message: 'All data synced to cloud.',
        bgColor: AppColors.success.withValues(alpha: 0.06),
        borderColor: AppColors.success.withValues(alpha: 0.25),
      );
    }
    return _BannerTile(
      icon: Icons.cloud_off,
      iconColor: context.colors.textMuted,
      message: 'Offline — data saved locally.',
      bgColor: context.colors.surface,
      borderColor: context.colors.border,
    );
  }
}

class _BannerTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String message;
  final String? subMessage;
  final Color bgColor;
  final Color borderColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _BannerTile({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.subMessage,
    required this.bgColor,
    required this.borderColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 16),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message,
                      style: TextStyle(
                          color: iconColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  if (subMessage != null)
                    Text(subMessage!,
                        style: TextStyle(
                            color: context.colors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            ?trailing,
            if (onTap != null && trailing == null)
              Icon(Icons.chevron_right,
                  color: context.colors.textMuted, size: 16),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: context.colors.textMuted, size: 40),
          SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: context.colors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}
