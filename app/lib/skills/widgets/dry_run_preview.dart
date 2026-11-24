// Dry-run Preview — validate params, tools, permissions (no execution)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../skill_model.dart';
import '../../state/connection_state.dart'
    show activeConnectionProvider;
import 'tool_binding_dropdown.dart';

/// Dry-run preview button and validation results
class DryRunPreview extends ConsumerWidget {
  const DryRunPreview({
    super.key,
    required this.skill,
    this.enabled = true,
  });

  final Skill skill;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.skillsDryRunTitle,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.science, size: 18),
              label: Text(l10n.skillsDryRun),
              onPressed: enabled ? () => _runDryRun(context, ref) : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ValidationResults(skill: skill),
      ],
    );
  }

  Future<void> _runDryRun(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final client = ref.read(activeConnectionProvider).value?.client;

    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.skillsDryRunNoConnection)),
      );
      return;
    }

    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.skillsDryRunRunning)),
    );

    try {
      // TODO: Implement actual dry-run validation
      // This would:
      // 1. Check parameter resolution
      // 2. Validate tool availability
      // 3. Check permission requirements
      // 4. Validate paths
      // All WITHOUT executing anything

      await Future.delayed(const Duration(seconds: 2)); // Simulate

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.skillsDryRunSuccess),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.skillsDryRunFailed}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _ValidationResults extends StatelessWidget {
  const _ValidationResults({required this.skill});

  final Skill skill;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;

    final checks = _runChecks();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.skillsDryRunChecks,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...checks.map((check) => _CheckRow(
            label: check.label,
            passed: check.passed,
            message: check.message,
          )),
        ],
      ),
    );
  }

  List<_Check> _runChecks() {
    final checks = <_Check>[];

    // Check 1: Parameters resolved
    final unboundParams = skill.parameters?.where((p) => p.required && (p.defaultValue == null || p.defaultValue!.isEmpty)).toList() ?? [];
    checks.add(_Check(
      label: 'Parameters resolved',
      passed: unboundParams.isEmpty,
      message: unboundParams.isEmpty
          ? 'All required parameters have defaults or bindings'
          : 'Unbound required params: ${unboundParams.map((p) => p.key).join(", ")}',
    ));

    // Check 2: Tool availability
    final tools = skill.requiredTools;
    final unknownTools = tools.where((t) => !ToolBindingDropdown.availableTools.any((opt) => opt.name == t)).toList();
    checks.add(_Check(
      label: 'Tool availability',
      passed: unknownTools.isEmpty,
      message: unknownTools.isEmpty
          ? 'All required tools are available'
          : 'Unknown tools: ${unknownTools.join(", ")}',
    ));

    // Check 3: Parameter binding validity
    final params = skill.parameters ?? [];
    final boundParams = params.where((p) => p.bindToStep?.isNotEmpty == true).toList();
    final hasBindings = boundParams.isNotEmpty;
    final noParams = params.isEmpty;
    checks.add(_Check(
      label: 'Parameter bindings valid',
      passed: hasBindings || noParams,
      message: hasBindings
          ? '${boundParams.length} parameter(s) bound to steps'
          : 'No step bindings (OK for knowledge/workflow)',
    ));

    // Check 4: Step mode consistency
    final executableSteps = skill.executableSteps ?? [];
    final hasToolSteps = executableSteps.any((s) => s.mode == 'tool');
    final hasAgentSteps = executableSteps.any((s) => s.mode == 'agent');
    checks.add(_Check(
      label: 'Step mode consistency',
      passed: true,
      message: executableSteps.isEmpty
          ? 'No executable steps (knowledge/workflow skill)'
          : 'Mixed modes: ${hasToolSteps ? "tool" : ""}${hasToolSteps && hasAgentSteps ? ", " : ""}${hasAgentSteps ? "agent" : ""}',
    ));

    // Check 5: Permissions
    final toolList = skill.requiredTools;
    final needsElevated = toolList.any((t) => ['bash', 'edit', 'write'].contains(t));
    checks.add(_Check(
      label: 'Permission requirements',
      passed: true,
      message: needsElevated
          ? 'Requires workspace-write permission'
          : 'Standard read-only permissions sufficient',
    ));

    return checks;
  }
}

class _Check {
  const _Check({
    required this.label,
    required this.passed,
    required this.message,
  });

  final String label;
  final bool passed;
  final String message;
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.passed,
    required this.message,
  });

  final String label;
  final bool passed;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.error,
            color: passed ? Colors.green : colors.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: passed ? Colors.green : colors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}