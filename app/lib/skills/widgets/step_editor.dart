// Step Editor — reorderable step list with mode picker, tool binding, parameter binding
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../skill_model.dart';
import 'step_mode_picker.dart';
import 'tool_binding_dropdown.dart';
import 'parameter_binding_ui.dart';

/// Step editor with reorderable list, mode picker, tool binding, parameter binding
class StepEditor extends ConsumerWidget {
  const StepEditor({
    super.key,
    required this.steps,
    required this.onStepsChanged,
    required this.parameters,
    required this.onParametersChanged,
    this.enabled = true,
    this.kind = 'workflow',
  });

  final List<SkillStep> steps;
  final ValueChanged<List<SkillStep>> onStepsChanged;
  final List<SkillParameter> parameters;
  final ValueChanged<List<SkillParameter>> onParametersChanged;
  final bool enabled;
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final isExecutable = kind == 'executable';

    if (!enabled || !isExecutable) {
      return _ReadOnlySteps(steps: steps);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.skillsStepsExecutable,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              onPressed: _addStep,
              tooltip: l10n.skillsStepAdd,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (steps.isEmpty)
          _EmptyState(
            label: l10n.skillsStepEditorEmpty,
            onAdd: _addStep,
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: steps.length,
            onReorder: _reorderSteps,
            itemBuilder: (context, index) => _StepTile(
              key: ValueKey(steps[index].id),
              index: index,
              step: steps[index],
              onChanged: (newStep) {
                final newSteps = List<SkillStep>.from(steps);
                newSteps[index] = newStep;
                onStepsChanged(newSteps);
              },
              onDelete: () => _deleteStep(index),
              parameters: parameters,
              onParametersChanged: onParametersChanged,
            ),
          ),
      ],
    );
  }

  void _addStep() {
    final newStep = SkillStep(
      id: DateTime.now().millisecondsSinceEpoch.toRadixString(36),
      description: '',
      mode: 'tool',
      tool: 'bash',
      args: {},
      order: steps.length,
    );
    final newSteps = List<SkillStep>.from(steps)..add(newStep);
    onStepsChanged(newSteps);
  }

  void _reorderSteps(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    final newSteps = List<SkillStep>.from(steps);
    final step = newSteps.removeAt(oldIndex);
    newSteps.insert(newIndex, step);
    // Update order
    for (int i = 0; i < newSteps.length; i++) {
      newSteps[i] = newSteps[i].copyWith(order: i);
    }
    onStepsChanged(newSteps);
  }

  void _deleteStep(int index) {
    final newSteps = List<SkillStep>.from(steps)..removeAt(index);
    // Update order
    for (int i = 0; i < newSteps.length; i++) {
      newSteps[i] = newSteps[i].copyWith(order: i);
    }
    onStepsChanged(newSteps);
  }
}

class _ReadOnlySteps extends StatelessWidget {
  const _ReadOnlySteps({required this.steps});

  final List<SkillStep> steps;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (steps.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(Icons.list_alt, size: 48, color: colors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              l10n.skillsStepEditorEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Executable steps not available for this skill kind',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        return _ReadOnlyStepTile(index: index, step: step);
      }).toList(),
    );
  }
}

class _ReadOnlyStepTile extends StatelessWidget {
  const _ReadOnlyStepTile({required this.index, required this.step});

  final int index;
  final SkillStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          child: Text('${index + 1}', style: TextStyle(color: colors.onPrimaryContainer)),
        ),
        title: Text(step.description.isEmpty ? '(empty)' : step.description),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(step.mode),
                  backgroundColor: step.mode == 'tool' ? Colors.blue.shade100 : Colors.purple.shade100,
                  labelStyle: const TextStyle(fontSize: 11),
                ),
                if (step.tool != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(step.tool!),
                    backgroundColor: Colors.green.shade100,
                    labelStyle: const TextStyle(fontSize: 11),
                  ),
                ],
              ],
            ),
            if (step.args.isNotEmpty)
              Text('Args: ${step.args.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.step,
    required this.onChanged,
    required this.onDelete,
    required this.parameters,
    required this.onParametersChanged,
  });

  final int index;
  final SkillStep step;
  final ValueChanged<SkillStep> onChanged;
  final VoidCallback onDelete;
  final List<SkillParameter> parameters;
  final ValueChanged<List<SkillParameter>> onParametersChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      key: ValueKey(step.id),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${index + 1}.',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SkillFormField(
                    label: 'Description',
                    hint: 'Enter step description',
                    initialValue: step.description,
                    onChanged: (v) => onChanged(step.copyWith(description: v)),
                    enabled: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StepModePicker(
                    mode: step.mode == 'agent' ? StepMode.agent : StepMode.tool,
                    onModeChanged: (m) => onChanged(step.copyWith(mode: m == StepMode.agent ? 'agent' : 'tool')),
                    enabled: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ToolBindingDropdown(
                    tool: step.tool,
                    onToolChanged: (t) => onChanged(step.copyWith(tool: t)),
                    enabled: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ParameterBindingUI(
              parameters: parameters,
              onParametersChanged: onParametersChanged,
              enabled: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.label,
    required this.onAdd,
  });

  final String label;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
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
          Icon(Icons.add_task, size: 48, color: colors.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Step'),
          ),
        ],
      ),
    );
  }
}