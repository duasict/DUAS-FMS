import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../providers/org_settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bar_title.dart';
import '../../widgets/org_logo.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version     = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) {
        setState(() {
          _version     = i.version;
          _buildNumber = i.buildNumber;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgSettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(title: 'About', subtitle: 'DUAS FMS v1.0.0')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
        children: [
          // ── Logo block ──────────────────────────────────────────────────
          Center(
            child: Column(children: [
              OrgLogo(size: 80, circular: false),
              const SizedBox(height: 16),
              Text(
                org.appName,
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                org.tagline,
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              if (_version.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    'v$_version (build $_buildNumber)',
                    style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ]),
          ),

          const SizedBox(height: 32),

          // ── Compliance ──────────────────────────────────────────────────
          _sectionLabel(context, 'COMPLIANCE & STANDARDS'),
          const SizedBox(height: 8),
          _infoRow(context,
              icon: Icons.gavel_outlined,
              iconColor: AppColors.primary,
              label: 'Primary Standard',
              value: 'CAAP SARPs for RPAS Operations'),
          _infoRow(context,
              icon: Icons.public_outlined,
              iconColor: AppColors.primaryLight,
              label: 'International Reference',
              value: 'ICAO Annex 2 — Rules of the Air'),
          _infoRow(context,
              icon: Icons.assignment_outlined,
              iconColor: AppColors.accent,
              label: 'Reporting Framework',
              value: 'CAAP Incident & Accident Reporting'),

          const SizedBox(height: 24),

          // ── App info ────────────────────────────────────────────────────
          _sectionLabel(context, 'APPLICATION'),
          const SizedBox(height: 8),
          _infoRow(context,
              icon: Icons.storage_outlined,
              iconColor: AppColors.success,
              label: 'Data Storage',
              value: 'SQLite (offline-first) + Supabase (cloud sync)'),
          _infoRow(context,
              icon: Icons.security_outlined,
              iconColor: AppColors.success,
              label: 'Auth & Security',
              value: 'Supabase Auth — org-isolated Row-Level Security'),
          _infoRow(context,
              icon: Icons.code_outlined,
              iconColor: AppColors.primaryLight,
              label: 'Platform',
              value: 'Flutter — iOS & Android'),

          const SizedBox(height: 24),

          // ── Intended use ────────────────────────────────────────────────
          _sectionLabel(context, 'INTENDED USE'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
            ),
            child: Text(
              '${org.appName} is intended for use by certified UAS operators '
              'and their crews operating under CAAP-regulated airspace. '
              'The application assists with pre-flight planning, risk '
              'assessment, crew management, and post-flight documentation '
              'but does not replace the operator\'s responsibility to comply '
              'with all applicable aviation regulations.',
              style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12.5,
                  height: 1.6),
            ),
          ),

          const SizedBox(height: 24),

          // ── Legal ───────────────────────────────────────────────────────
          _sectionLabel(context, 'LEGAL'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '© ${DateTime.now().year} ${org.orgName}. '
                    'All rights reserved.',
                    style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This software is proprietary. Unauthorized distribution '
                    'or reproduction is prohibited. All flight data remains '
                    'the property of the operating organization.',
                    style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                        height: 1.55),
                  ),
                ]),
          ),

          const SizedBox(height: 24),

          // ── Build metadata ──────────────────────────────────────────────
          Center(
            child: Text(
              '${org.appName}'
              '${_version.isNotEmpty ? ' v$_version · Build $_buildNumber' : ''}\n'
              'CAAP SARPs · ICAO Annex 2',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 11,
                  height: 1.6),
            ),
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

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
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
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        color: context.colors.textPrimary, fontSize: 13)),
              ]),
        ),
      ]),
    );
  }
}
