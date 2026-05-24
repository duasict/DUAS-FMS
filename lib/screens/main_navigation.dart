import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../providers/app_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import 'alerts/alerts_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'missions/missions_screen.dart';
import 'more/more_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    DashboardScreen(),
    MissionsScreen(),
    AlertsScreen(),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-sync the user's Supabase profile whenever the app returns to the
  /// foreground.  Only updates fields that can change remotely (name, role,
  /// org); device-only fields (photoPath, license scan data) are preserved.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) { _syncProfileOnResume(); }
  }

  Future<void> _syncProfileOnResume() async {
    if (!SupabaseService.isSignedIn) return;
    if (!await SyncService.isConnected()) return;

    final userId = SupabaseService.currentUser?.id ?? '';
    if (userId.isEmpty) return;

    try {
      final remote = await SupabaseService.fetchProfile(userId);
      if (remote == null || !mounted) return;

      final profileProvider = context.read<UserProfileProvider>();
      final existing = profileProvider.profile;

      bool remoteBool(String key, bool fallback) {
        final v = remote[key];
        if (v is bool) return v;
        if (v is int) return v == 1;
        return fallback;
      }

      final remoteRole = remote['role'] as String? ?? existing.role;
      final remoteOrg  = remote['organization_id'] as String? ?? existing.organizationId;
      final remoteName = (remote['name'] as String?)?.isNotEmpty == true
          ? remote['name'] as String
          : existing.name;
      final remoteLicenseVerified =
          remoteBool('license_verified', existing.licenseVerified);
      final remoteFaceVerified =
          remoteBool('face_verified', existing.faceVerified);

      // Skip the DB write if nothing changed
      if (remoteRole == existing.role &&
          remoteOrg == existing.organizationId &&
          remoteName == existing.name &&
          remoteLicenseVerified == existing.licenseVerified &&
          remoteFaceVerified == existing.faceVerified) {
        return;
      }

      final updated = existing.copyWith(
        name: remoteName,
        role: remoteRole,
        organizationId: remoteOrg,
        licenseVerified: remoteLicenseVerified,
        faceVerified: remoteFaceVerified,
      );

      await DatabaseHelper.instance.saveUserProfile(updated);
      if (mounted) await profileProvider.load();
    } catch (_) {
      // Non-fatal background sync — silently ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<AppProvider>().unreadAlertCount;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.colors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.flight_outlined),
              activeIcon: Icon(Icons.flight),
              label: 'Missions',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.notifications_outlined),
              ),
              activeIcon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.notifications),
              ),
              label: 'Alerts',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz_rounded),
              activeIcon: Icon(Icons.more_horiz_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
