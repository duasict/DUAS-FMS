import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          _sectionLabel(context, 'APPEARANCE'),
          const SizedBox(height: 8),
          _ThemeToggleTile(),
          const SizedBox(height: 20),
          _sectionLabel(context, 'ABOUT'),
          const SizedBox(height: 8),
          _infoTile(
            context,
            icon: Icons.info_outline,
            title: 'App Version',
            value: 'UAS FMS v1.0.0',
          ),
          _infoTile(
            context,
            icon: Icons.gavel_outlined,
            title: 'Compliance',
            value: 'CAAP SARPs  ·  ICAO Annex 2',
          ),
          _infoTile(
            context,
            icon: Icons.shield_outlined,
            title: 'Data Storage',
            value: 'Local SQLite — no cloud sync required',
          ),
        ],
      ),
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

  Widget _infoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryLight, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    color: context.colors.textMuted, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}

class _ThemeToggleTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            color: AppColors.primaryLight,
            size: 18,
          ),
        ),
        title: Text(
          'Dark Mode',
          style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          isDark ? 'Currently using dark theme' : 'Currently using light theme',
          style: TextStyle(color: context.colors.textMuted, fontSize: 11),
        ),
        trailing: Switch(
          value: isDark,
          onChanged: (_) => context.read<ThemeProvider>().toggle(),
          activeThumbColor: AppColors.primary,
          activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
          inactiveThumbColor: AppColors.primaryLight,
          inactiveTrackColor: AppColors.primaryLight.withValues(alpha: 0.2),
        ),
        onTap: () => context.read<ThemeProvider>().toggle(),
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
    );
  }
}
