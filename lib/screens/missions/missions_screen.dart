import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/mission.dart';
import '../../providers/app_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mission_card.dart';
import '../mission_details/mission_details_screen.dart';
import 'mission_create_screen.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Missions'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(96),
            child: Column(children: [
              // ── Search bar ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                    style: TextStyle(
                        color: context.colors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by title or mission ID…',
                      hintStyle: TextStyle(
                          color: context.colors.textMuted, fontSize: 13),
                      prefixIcon: Icon(Icons.search,
                          size: 18, color: context.colors.textMuted),
                      suffixIcon: _query.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                              child: Icon(Icons.close,
                                  size: 16, color: context.colors.textMuted),
                            )
                          : null,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      filled: true,
                      fillColor: context.colors.surface,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: context.colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
              // ── Tabs ────────────────────────────────────────────────
              TabBar(
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primaryLight,
                unselectedLabelColor: context.colors.textMuted,
                tabs: const [
                  Tab(text: 'Approved / Upcoming'),
                  Tab(text: 'Completed'),
                ],
              ),
            ]),
          ),
        ),
        body: TabBarView(
          children: [
            _MissionList(filter: 'upcoming', query: _query),
            _MissionList(filter: 'completed', query: _query),
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
  final String query;
  const _MissionList({required this.filter, required this.query});

  List<Mission> _applySearch(List<Mission> missions) {
    if (query.isEmpty) return missions;
    return missions.where((m) {
      return m.title.toLowerCase().contains(query) ||
          m.missionId.toLowerCase().contains(query) ||
          m.location.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final all = filter == 'upcoming'
        ? provider.upcomingMissions
        : provider.completedMissions;
    final missions = _applySearch(all);

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

      final String emptyMsg;
      final IconData emptyIcon;

      if (query.isNotEmpty) {
        emptyMsg = 'No missions match "$query".';
        emptyIcon = Icons.search_off_outlined;
      } else if (filter == 'upcoming') {
        emptyMsg = isCrp
            ? 'No upcoming missions.\nTap + to create one.'
            : 'No missions assigned to you yet.';
        emptyIcon = Icons.flight_takeoff_outlined;
      } else {
        emptyMsg = 'No completed missions yet.';
        emptyIcon = Icons.check_circle_outline;
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(emptyIcon, color: context.colors.textMuted, size: 48),
              const SizedBox(height: 16),
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
