// Step Mode Picker — Tool / Agent mode selector per step
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

/// Step execution mode
enum StepMode { tool, agent }

/// Dropdown to pick step mode (Tool / Agent)
class StepModePicker extends StatelessWidget {
  const StepModePicker({
    super.key,
    required this.mode,
    required this.onModeChanged,
    this.enabled = true,
    this.label = 'Mode',
  });

  final StepMode mode;
  final ValueChanged<StepMode> onModeChanged;
  final bool enabled;
  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        enabled: enabled,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<StepMode>(
          value: mode,
          isExpanded: true,
          disabledHint: Text(
            mode == StepMode.tool ? l10n.skillsStepModeTool : l10n.skillsStepModeAgent,
          ),
          onChanged: enabled ? (v) => onModeChanged(v!) : null,
          items: [
            DropdownMenuItem(
              value: StepMode.tool,
              child: Row(
                children: [
                  Icon(Icons.build, size: 20, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(l10n.skillsStepModeTool),
                ],
              ),
            ),
            DropdownMenuItem(
              value: StepMode.agent,
              child: Row(
                children: [
                  Icon(Icons.psychology, size: 20, color: colors.secondary),
                  const SizedBox(width: 8),
                  Text(l10n.skillsStepModeAgent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}