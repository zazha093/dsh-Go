// Parameter Binding UI — map ${param} to step arg fields
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../skill_model.dart';
import 'form_field.dart';

/// Widget to bind parameters to step arguments
class ParameterBindingUI extends ConsumerWidget {
  const ParameterBindingUI({
    super.key,
    required this.parameters,
    required this.onParametersChanged,
    this.enabled = true,
  });

  final List<SkillParameter> parameters;
  final ValueChanged<List<SkillParameter>> onParametersChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (parameters.isEmpty) {
      return _EmptyState(
        label: l10n.skillsParameterBindingEmpty,
        onAdd: enabled ? (ctx) => _showAddParameterDialog(ctx) : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.skillsParameterBinding,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (enabled)
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => _showAddParameterDialog(context),
                tooltip: l10n.skillsParameterAdd,
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...parameters.asMap().entries.map((entry) {
          final index = entry.key;
          final param = entry.value;
          return _ParameterRow(
            index: index,
            param: param,
            onChanged: (newParam) {
              final newParams = List<SkillParameter>.from(parameters);
              newParams[index] = newParam;
              onParametersChanged(newParams);
            },
            onDelete: enabled ? () {
              final newParams = List<SkillParameter>.from(parameters);
              newParams.removeAt(index);
              onParametersChanged(newParams);
            } : null,
            enabled: enabled,
            onAdd: enabled ? (ctx) => _showAddParameterDialog(ctx) : null,
          );
        }),
      ],
    );
  }

  void _showAddParameterDialog(BuildContext context) {
    // TODO: Implement add parameter dialog
    // This would be a dialog to create a new SkillParameter
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.skillsParameterAddNotImplemented)),
    );
  }
}

class _ParameterRow extends StatelessWidget {
  const _ParameterRow({
    required this.index,
    required this.param,
    required this.onChanged,
    this.onDelete,
    this.enabled = true,
    this.onAdd,
  });

  final int index;
  final SkillParameter param;
  final ValueChanged<SkillParameter> onChanged;
  final VoidCallback? onDelete;
  final bool enabled;
  final Function(BuildContext)? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
                  '${index + 1}. ${param.key}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (enabled && onDelete != null)
                  IconButton(
                    icon: Icon(Icons.delete, color: colors.error, size: 20),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SkillFormField(
                    label: 'Label',
                    hint: 'Enter label for this parameter',
                    initialValue: param.label,
                    onChanged: (v) => onChanged(param.copyWith(label: v)),
                    enabled: enabled,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SkillFormField(
                    label: 'Key',
                    hint: 'Enter key (used in \${key} placeholders)',
                    initialValue: param.key,
                    onChanged: (v) => onChanged(param.copyWith(key: v)),
                    enabled: enabled,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: param.type,
                    decoration: InputDecoration(
                      labelText: 'Type',
                      border: const OutlineInputBorder(),
                      enabled: enabled,
                    ),
                    items: SkillInputType.values.map((t) => DropdownMenuItem(
                      value: t.name,
                      child: Text(t.name),
                    )).toList(),
                    onChanged: enabled ? (v) => onChanged(param.copyWith(type: v!)) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SwitchListTile(
                    title: Text('Required'),
                    value: param.required,
                    onChanged: enabled ? (v) => onChanged(param.copyWith(required: v)) : null,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SkillFormField(
              label: 'Default Value',
              hint: 'Optional default value',
              initialValue: param.defaultValue,
              onChanged: (v) => onChanged(param.copyWith(defaultValue: v.isEmpty ? null : v)),
              enabled: enabled,
            ),
            const SizedBox(height: 12),
            SkillFormField(
              label: 'Bind to Step',
              hint: 'Step ID this parameter binds to',
              initialValue: param.bindToStep,
              onChanged: (v) => onChanged(param.copyWith(bindToStep: v.isEmpty ? null : v)),
              enabled: enabled,
            ),
            const SizedBox(height: 12),
            SkillFormField(
              label: 'Bind to Tool',
              hint: 'Tool name this parameter binds to',
              initialValue: param.bindToTool,
              onChanged: (v) => onChanged(param.copyWith(bindToTool: v.isEmpty ? null : v)),
              enabled: enabled,
            ),
            const SizedBox(height: 12),
            SkillFormField(
              label: 'Template',
              hint: 'e.g., deploy --env \${environment}',
              initialValue: param.template,
              onChanged: (v) => onChanged(param.copyWith(template: v.isEmpty ? null : v)),
              enabled: enabled,
            ),
            if (!enabled) ...[
              const SizedBox(height: 8),
              Text(
                'Parameters are read-only for knowledge skills',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.label,
    this.onAdd,
  });

  final String label;
  final Function(BuildContext)? onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.assignment, size: 48, color: colors.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (onAdd != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.skillsParameterAdd),
              onPressed: () => onAdd!(context),
            ),
          ],
        ],
      ),
    );
  }
}