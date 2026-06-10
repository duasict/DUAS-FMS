import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  static final _cardRadius = BorderRadius.circular(12);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      borderRadius: _cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: _cardRadius,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? color.withValues(alpha: 0.12) : bgColor,
            borderRadius: _cardRadius,
            border: Border.all(color: color, width: 2.0),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? color.withValues(alpha: 0.22)
                          : Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    value,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              if (onTap != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(Icons.arrow_forward_ios,
                      size: 11, color: color.withValues(alpha: 0.65)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
