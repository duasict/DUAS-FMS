import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mission_card.dart';
import '../mission_details/mission_details_screen.dart';
import 'mission_create_screen.dart';

class MissionsScreen extends StatelessWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Missions'),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primaryLight,
            unselectedLabelColor: context.colors.textMuted,
            tabs: [
              Tab(text: 'Approved / Upcoming'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MissionList(filter: 'upcoming'),
            _MissionList(filter: 'completed'),
          ],
        ),
        floatingActionButton: context
                    .watch<UserProfileProvider>()
                    .profile
                    .role ==
                'crp'
            ? FloatingActionButton.extended(
                onPressed: () {
                  final provider = context.read<AppProvider>();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MissionCreateScreen()),
                  ).then((_) => provider.refreshMissions());
                },
                icon: const Icon(Icons.add, size: 20),
                label: const Text('New Mission'),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              )
            : null,
      ),
    );
  }
}

class _MissionList extends StatelessWidget {
  final String filter;
  const _MissionList({required this.filter});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final missions = filter == 'upcoming'
        ? provider.upcomingMissions
        : provider.completedMissions;

    if (provider.isLoading) {
      return Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (missions.isEmpty) {
      final isCrp = context
              .watch<UserProfileProvider>()
              .profile
              .role ==
          'crp';
      final emptyMsg = filter == 'upcoming'
          ? (isCrp
              ? 'No upcoming missions.\nTap + to create one.'
              : 'No missions assigned to you yet.')
          : 'No completed missions yet.';

      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                filter == 'upcoming'
                    ? Icons.flight_takeoff_outlined
                    : Icons.check_circle_outline,
                color: context.colors.textMuted,
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                emptyMsg,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: context.colors.card,
      onRefresh: provider.refreshMissions,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        itemCount: missions.length,
        itemBuilder: (ctx, i) => MissionCard(
          mission: missions[i],
          onTap: () {
            Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) =>
                    MissionDetailsScreen(missionId: missions[i].id!),
              ),
            ).then((_) => provider.refreshMissions());
          },
        ),
      ),
    );
  }
}
