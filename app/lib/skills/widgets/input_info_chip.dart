// Personal Skills UI — input info chip widget

import 'package:flutter/material.dart';

/// A chip showing key-value information for a skill input
class SkillInputInfoChip extends StatelessWidget {
  const SkillInputInfoChip({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      label: Text('$label: $value', style: theme.textTheme.labelSmall),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      visualDensity: VisualDensity.compact,
    );
  }
}