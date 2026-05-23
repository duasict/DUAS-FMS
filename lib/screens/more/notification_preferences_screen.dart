import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';

/// Keys used throughout the app to gate notification delivery.
class NotifPrefs {
  static const kConcurrence      = 'notif_concurrence';
  static const kLicense          = 'notif_license';
  static const kMissionAssigned  = 'notif_mission_assigned';

  static Future<bool> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true; // default ON
  }

  static Future<void> set(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _concurrence     = true;
  bool _license         = true;
  bool _missionAssigned = true;
  bool _loaded          = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await NotifPrefs.get(NotifPrefs.kConcurrence);
    final l = await NotifPrefs.get(NotifPrefs.kLicense);
    final m = await NotifPrefs.get(NotifPrefs.kMissionAssigned);
    if (mounted) {
      setState(() {
        _concurrence     = c;
        _license         = l;
        _missionAssigned = m;
        _loaded          = true;
      });
    }
  }

  Future<void> _toggle(String key, bool value) async {
    await NotifPrefs.set(key, value);
    setState(() {
      if (key == NotifPrefs.kConcurrence)     _concurrence     = value;
      if (key == NotifPrefs.kLicense)         _license         = value;
      if (key == NotifPrefs.kMissionAssigned) _missionAssigned = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: _loaded
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                _banner(context),
                const SizedBox(height: 20),
                _sectionLabel(context, 'ALERT CHANNELS'),
                const SizedBox(height: 8),
                _toggleTile(
                  context,
                  icon: Icons.verified_user_outlined,
                  iconColor: AppColors.primary,
                  title: 'CRP Concurrence Alerts',
                  subtitle: 'Notified when a mission needs CRP approval '
                      'or when a concurrence decision arrives via P2P.',
                  value: _concurrence,
                  onChanged: (v) => _toggle(NotifPrefs.kConcurrence, v),
                ),
                _toggleTile(
                  context,
                  icon: Icons.badge_outlined,
                  iconColor: AppColors.warning,
                  title: 'License Expiry Alerts',
                  subtitle: 'Reminded 30 days before your CAAP pilot '
                      'license expires so you can re-verify in time.',
                  value: _license,
                  onChanged: (v) => _toggle(NotifPrefs.kLicense, v),
                ),
                _toggleTile(
                  context,
                  icon: Icons.assignment_ind_outlined,
                  iconColor: AppColors.success,
                  title: 'Mission Assignment Alerts',
                  subtitle: 'Notified when you are assigned to a new '
                      'mission as RPIC, VO, GCS Operator, or Technical Crew.',
                  value: _missionAssigned,
                  onChanged: (v) => _toggle(NotifPrefs.kMissionAssigned, v),
                ),
                const SizedBox(height: 24),
                _sectionLabel(context, 'NOTE'),
                const SizedBox(height: 8),
                _infoCard(
                  context,
                  'Disabling a channel only suppresses in-app push banners. '
                  'All alerts are still recorded in the Alerts tab and can be '
                  'reviewed at any time.',
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }

  Widget _banner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(Icons.notifications_active_outlined,
            color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Notifications keep your crew informed about mission approvals '
            'and license status in real time.',
            style: TextStyle(
                color: context.colors.textSecondary, fontSize: 12.5),
          ),
        ),
      ]),
    );
  }

  Widget _toggleTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
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
                color: context.colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(subtitle,
              style:
                  TextStyle(color: context.colors.textMuted, fontSize: 11)),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
          activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
          inactiveThumbColor: AppColors.primaryLight,
          inactiveTrackColor:
              AppColors.primaryLight.withValues(alpha: 0.2),
        ),
        onTap: () => onChanged(!value),
        isThreeLine: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),
    );
  }

  Widget _infoCard(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Text(text,
          style:
              TextStyle(color: context.colors.textSecondary, fontSize: 12)),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          text,
          style: TextStyle(
            color: context.colors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );
}
