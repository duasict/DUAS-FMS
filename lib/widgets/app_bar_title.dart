import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppBarTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const AppBarTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: context.colors.textSecondary,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
