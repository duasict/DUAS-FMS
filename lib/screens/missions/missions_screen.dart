import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/mission.dart';
import '../../providers/app_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mission_card.dart';
import '../../widgets/skeleton_loader.dart';
import '../mission_details/mission_details_screen.dart';
import 'mission_create_screen.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  final _searchCtrl = TextEditingController();
  String _query = '';

  // Sub-filter inside the "Upcoming" tab: null = All, or 'planning' / 'in_progress'
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      // Clear status filter when switching away from Upcoming tab
      if (_tabCtrl.indexIsChanging && _tabCtrl.index != 0) {
        setState(() => _statusFilter = null);
      } else {
        setState(() {}); // rebuild to show/hide chips
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUpcomingTab = _tabCtrl.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Missions'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(isUpcomingTab ? 116 : 88),
          child: Column(children: [
            // ── Search bar ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
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
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 0, horizontal: 12),
                    filled: true,
                    fillColor: context.colors.surface,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            // ── Tabs ──────────────────────────────────────────────────
            TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primaryLight,
              unselectedLabelColor: context.colors.textMuted,
              tabs: const [
                Tab(text: 'Upcoming'),
                Tab(text: 'Completed'),
              ],
            ),
            // ── Status filter chips (Upcoming tab only) ───────────────
            if (isUpcomingTab)
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _statusFilter == null,
                      onTap: () => setState(() => _statusFilter = null),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Planning',
                      selected: _statusFilter == 'planning',
                      onTap: () => setState(() => _statusFilter = 'planning'),
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'In Progress',
                      selected: _statusFilter == 'in_progress',
                      onTap: () =>
                          setState(() => _statusFilter = 'in_progress'),
                      color: AppColors.accent,
                    ),
                  ],
                ),
              ),
          ]),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _MissionList(
              filter: 'upcoming',
              query: _query,
              statusFilter: _statusFilter),
          _MissionList(
              filter: 'completed', query: _query, statusFilter: null),
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
    );
  }
}

// ── Status filter chip widget ─────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.primaryLight,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : context.colors.border,
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : context.colors.textMuted,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Mission list ──────────────────────────────────────────────────────────────

class _MissionList extends StatefulWidget {
  final String filter;
  final String query;
  final String? statusFilter;

  const _MissionList({
    required this.filter,
    required this.query,
    required this.statusFilter,
  });

  @override
  State<_MissionList> createState() => _MissionListState();
}

class _MissionListState extends State<_MissionList> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 300) {
      context.read<AppProvider>().loadMoreMissions();
    }
  }

  List<Mission> _applyFilters(List<Mission> missions) {
    var result = missions;
    // Status sub-filter (upcoming tab only)
    if (widget.statusFilter != null) {
      result =
          result.where((m) => m.status == widget.statusFilter).toList();
    }
    // Text search
    if (widget.query.isNotEmpty) {
      result = result.where((m) {
        return m.title.toLowerCase().contains(widget.query) ||
            m.missionId.toLowerCase().contains(widget.query) ||
            m.location.toLowerCase().contains(widget.query);
      }).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final all = widget.filter == 'upcoming'
        ? provider.upcomingMissions
        : provider.completedMissions;
    final missions = _applyFilters(all);

    if (provider.isLoading) {
      return const SkeletonMissionList();
    }

    if (missions.isEmpty) {
      final isCrp =
          context.watch<UserProfileProvider>().profile.role == 'crp';

      final String emptyMsg;
      final IconData emptyIcon;

      if (widget.query.isNotEmpty) {
        emptyMsg = 'No missions match "${widget.query}".';
        emptyIcon = Icons.search_off_outlined;
      } else if (widget.statusFilter != null) {
        final label =
            widget.statusFilter == 'planning' ? 'Planning' : 'In Progress';
        emptyMsg = 'No $label missions.';
        emptyIcon = Icons.filter_list_off;
      } else if (widget.filter == 'upcoming') {
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
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        itemCount: missions.length + (provider.hasMoreMissions ? 1 : 0),
        itemBuilder: (ctx, i) {
          // "Loading more" indicator at the end of the list
          if (i == missions.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            );
          }
          return MissionCard(
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
          );
        },
      ),
    );
  }
}
