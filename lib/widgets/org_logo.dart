import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/org_settings_provider.dart';
import '../theme/app_theme.dart';

/// Displays the organisation's custom logo if one has been set, or falls back
/// to the default drone icon.  Reads [OrgSettingsProvider.logoPath] from the
/// widget tree unless [logoPathOverride] is supplied (used in the setup screen
/// preview before the new logo has been saved).
class OrgLogo extends StatelessWidget {
  final double size;
  final bool circular;
  final String? logoPathOverride;

  const OrgLogo({
    super.key,
    this.size = 44,
    this.circular = false,
    this.logoPathOverride,
  });

  @override
  Widget build(BuildContext context) {
    final path =
        logoPathOverride ?? context.watch<OrgSettingsProvider>().logoPath;

    if (path.isNotEmpty) {
      final file = File(path);
      final radius = circular
          ? BorderRadius.circular(size / 2)
          : BorderRadius.circular(size * 0.18);

      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, _) => _fallback(ctx),
        ),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    final radius = circular
        ? size / 2
        : size * 0.18;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Icon(Icons.air, color: AppColors.primary, size: size * 0.5),
    );
  }
}
