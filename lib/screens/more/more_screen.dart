import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../providers/user_profile_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../aircraft/aircraft_screen.dart';
import '../battery/battery_history_screen.dart';
import '../incidents/incident_history_screen.dart';
import '../license/license_verification_screen.dart';
import '../login_screen.dart';
import '../maintenance/maintenance_history_screen.dart';
import '../reports/fleet_summary_screen.dart';
import 'about_screen.dart';
import 'crew_management_screen.dart';
import 'data_storage_screen.dart';
import 'help_documentation_screen.dart';
import 'notification_preferences_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileProvider>().profile;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // User card — tappable, goes to profile
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.border),
              ),
              child: Row(children: [
                // Avatar
                _Avatar(photoPath: profile.photoPath, size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                        if (profile.displayTitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            profile.displayTitle,
                            style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 12),
                          ),
                        ],
                        if (profile.email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            profile.email,
                            style: TextStyle(
                                color: context.colors.textMuted, fontSize: 11),
                          ),
                        ],
                        if (profile.licenseNumber.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.badge_outlined,
                                size: 11,
                                color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              profile.licenseNumber,
                              style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                  fontFamily: 'monospace'),
                            ),
                          ]),
                        ],
                      ]),
                ),
                Icon(Icons.chevron_right,
                    color: context.colors.textMuted, size: 18),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          const _SectionLabel(label: 'ACCOUNT'),
          _NavTile(
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: 'Edit your personal information',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          _LicenseVerificationTile(profile: profile),
          if (profile.role == 'crp')
            _NavTile(
              icon: Icons.manage_accounts_outlined,
              title: 'Crew Management',
              subtitle: 'Manage roles and org members',
              iconColor: AppColors.accent,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const CrewManagementScreen())),
            ),
          const SizedBox(height: 8),
          const _SectionLabel(label: 'APP'),
          _NavTile(
            icon: Icons.air,
            title: 'Aircraft Fleet',
            subtitle: 'Manage and register aircraft',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AircraftScreen())),
          ),
          _NavTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Appearance and app preferences',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          _NavTile(
            icon: Icons.notifications_outlined,
            title: 'Notification Preferences',
            subtitle: 'Manage alert settings',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const NotificationPreferencesScreen())),
          ),
          _NavTile(
            icon: Icons.storage_outlined,
            title: 'Data & Storage',
            subtitle: 'Local storage and sync settings',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const DataStorageScreen())),
          ),
          const SizedBox(height: 8),
          const _SectionLabel(label: 'RECORDS'),
          _NavTile(
            icon: Icons.build_outlined,
            title: 'Maintenance Log',
            subtitle: 'View history and log airframe maintenance',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MaintenanceHistoryScreen())),
          ),
          _NavTile(
            icon: Icons.battery_charging_full,
            title: 'Battery Log',
            subtitle: 'View history and track battery cycles',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BatteryHistoryScreen())),
          ),
          _NavTile(
            icon: Icons.warning_amber_outlined,
            title: 'Incident Report',
            subtitle: 'View history and file CAAP reports',
            iconColor: AppColors.warning,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const IncidentHistoryScreen())),
          ),
          if (profile.role == 'crp')
            _NavTile(
              icon: Icons.bar_chart_outlined,
              title: 'Fleet Summary',
              subtitle: 'Aggregate stats and PDF export',
              iconColor: AppColors.success,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const FleetSummaryScreen())),
            ),
          const SizedBox(height: 8),
          const _SectionLabel(label: 'SUPPORT'),
          _NavTile(
            icon: Icons.help_outline,
            title: 'Help & Documentation',
            subtitle: 'UAS SOP and app guide',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const HelpDocumentationScreen())),
          ),
          _NavTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'UAS FMS v1.0.0',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
          const SizedBox(height: 8),
          const _SectionLabel(label: 'SESSION'),
          _NavTile(
            icon: Icons.logout,
            title: 'Log Out',
            subtitle: 'Sign out of your account',
            iconColor: AppColors.danger,
            textColor: AppColors.danger,
            showChevron: false,
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text('Log Out',
            style: TextStyle(color: context.colors.textPrimary)),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: context.colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseService.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photoPath;
  final double size;
  const _Avatar({required this.photoPath, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.15),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        image: photoPath != null
            ? DecorationImage(
                image: FileImage(File(photoPath!)), fit: BoxFit.cover)
            : null,
      ),
      child: photoPath == null
          ? Icon(Icons.person, color: AppColors.primaryLight, size: size * 0.5)
          : null,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Text(
        label,
        style: TextStyle(
          color: context.colors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color? textColor;
  final bool showChevron;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = AppColors.primaryLight,
    this.textColor,
    this.showChevron = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        title: Text(title,
            style: TextStyle(
                color: textColor ?? context.colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle,
            style: TextStyle(color: context.colors.textMuted, fontSize: 11)),
        trailing: showChevron
            ? Icon(Icons.chevron_right,
                color: context.colors.textMuted, size: 18)
            : null,
        onTap: onTap,
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
    );
  }
}

// ── License Verification tile — shows dynamic verified/expired/unverified state
class _LicenseVerificationTile extends StatelessWidget {
  final UserProfile profile;
  const _LicenseVerificationTile({required this.profile});

  @override
  Widget build(BuildContext context) {
    final verified = profile.licenseVerified;
    final expired = profile.isLicenseExpired;
    final expiringSoon = profile.isLicenseExpiringSoon;

    IconData icon;
    Color iconColor;
    String subtitle;

    if (verified && !expired) {
      icon = expiringSoon ? Icons.warning_amber_outlined : Icons.verified_outlined;
      iconColor = expiringSoon ? AppColors.warning : AppColors.success;
      subtitle = expiringSoon
          ? 'License expiring soon — re-verify'
          : 'Verified · ${profile.licenseNumber}';
    } else if (verified && expired) {
      icon = Icons.error_outline;
      iconColor = AppColors.danger;
      subtitle = 'License EXPIRED — re-verify to restore PIC status';
    } else {
      icon = Icons.badge_outlined;
      iconColor = AppColors.primaryLight;
      subtitle = 'Scan your CAAP license to receive PIC status';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: verified && !expired
              ? expiringSoon
                  ? AppColors.warning.withValues(alpha: 0.4)
                  : AppColors.success.withValues(alpha: 0.3)
              : verified && expired
                  ? AppColors.danger.withValues(alpha: 0.4)
                  : context.colors.border,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        title: Text(
          'License Verification',
          style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500),
        ),
        subtitle: Text(subtitle,
            style: TextStyle(
                color: verified && expired
                    ? AppColors.danger
                    : expiringSoon
                        ? AppColors.warning
                        : context.colors.textMuted,
                fontSize: 11)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (verified && !expired && !expiringSoon)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('PIC',
                  style: TextStyle(
                      color: AppColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              color: context.colors.textMuted, size: 18),
        ]),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const LicenseVerificationScreen()),
        ),
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
    );
  }
}
