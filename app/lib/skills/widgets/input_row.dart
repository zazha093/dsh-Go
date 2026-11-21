// Personal Skills UI — input row widget

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../ui/theme/app_icons.dart' as app_icons;
import '../../ui/theme/theme.dart';
import '../skill_model.dart';
import 'input_info_chip.dart';

/// A row displaying a skill input with delete action
class SkillInputRow extends ConsumerWidget {
  const SkillInputRow({
    super.key,
    required this.input,
    required this.formKey,
    required this.index,
    required this.onDelete,
  });

  final SkillInput input;
  final GlobalKey<FormState> formKey;
  final int index;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${index + 1}. ${input.label}',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (!input.required)
                  Chip(
                    label: Text(l10n.skillsInputOptional, style: theme.textTheme.labelSmall),
                    backgroundColor: colors.surfaceContainerHighest,
                  ),
                IconButton(
                  icon: Icon(app_icons.AppIcons.delete, color: colors.error),
                  onPressed: () => _confirmDelete(context),
                  tooltip: l10n.skillsDelete,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                SkillInputInfoChip(label: 'Key', value: input.key),
                SkillInputInfoChip(label: 'Hint', value: input.hint),
                SkillInputInfoChip(label: 'Type', value: input.type.name),
                if (input.type == SkillInputType.select && input.options != null)
                  SkillInputInfoChip(label: 'Options', value: input.options!.join(', ')),
                if (input.defaultValue != null && input.defaultValue!.isNotEmpty)
                  SkillInputInfoChip(label: 'Default', value: input.defaultValue!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.skillsDelete),
        content: Text(l10n.skillsDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.skillsCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.skillsDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onDelete();
    }
  }
}