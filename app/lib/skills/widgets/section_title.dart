// Personal Skills UI — section title widget

import 'package:flutter/material.dart';

/// A section title with consistent styling
class SkillSectionTitle extends StatelessWidget {
  const SkillSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}