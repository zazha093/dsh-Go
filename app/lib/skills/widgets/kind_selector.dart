// Kind Selector — choose between Knowledge, Workflow, Executable
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../skill_model.dart';
import 'section_title.dart';
import '../../ui/theme/app_icons.dart' as app_icons;
import '../../ui/theme/motion.dart';

/// Kind selector with three options: Knowledge, Workflow, Executable
class KindSelector extends ConsumerWidget {
  const KindSelector({
    super.key,
    required this.selectedKind,
    required this.onKindChanged,
    this.enabled = true,
  });

  final String selectedKind;
  final ValueChanged<String> onKindChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final kinds = [
      _KindOption(
        kind: 'knowledge',
        label: l10n.skillsKindKnowledge,
        description: l10n.skillsKindKnowledgeDesc,
        icon: app_icons.AppIcons.skill,
        color: colors.primary,
      ),
      _KindOption(
        kind: 'workflow',
        label: l10n.skillsKindWorkflow,
        description: l10n.skillsKindWorkflowDesc,
        icon: app_icons.AppIcons.workflow,
        color: colors.secondary,
      ),
      _KindOption(
        kind: 'executable',
        label: l10n.skillsKindExecutable,
        description: l10n.skillsKindExecutableDesc,
        icon: app_icons.AppIcons.playVideo,
        color: colors.tertiary,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkillSectionTitle(title: l10n.skillsKind),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: kinds.map((option) => _KindCard(
            option: option,
            isSelected: selectedKind == option.kind,
            enabled: enabled,
            onTap: enabled ? () => onKindChanged(option.kind) : null,
          )).toList(),
        ),
      ],
    );
  }
}

class _KindOption {
  const _KindOption({
    required this.kind,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String kind;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
}

class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.option,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final _KindOption option;
  final bool isSelected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox(
      width: 100,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: isSelected,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.quick),
          curve: AppMotion.std,
          child: Material(
            color: isSelected ? option.color.withValues(alpha: 0.15) : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? option.color : colors.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        option.icon,
                        size: 32,
                        color: isSelected ? option.color : colors.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        option.label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isSelected ? option.color : colors.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}