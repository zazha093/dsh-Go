// Personal Skills UI — user inputs editor widget

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsh_app/l10n/l10n.dart';
import 'package:dsh_app/ui/common/app_icons.dart' as app_icons;
import 'package:dsh_app/ui/theme/theme.dart';
import 'package:dsh_app/skills/skill_model.dart';
import 'input_row.dart';
import 'input_dialog_field.dart';
import 'section_title.dart';

/// Editor for skill user inputs
class SkillUserInputsEditor extends ConsumerStatefulWidget {
  const SkillUserInputsEditor({
    super.key,
    required this.userInputs,
    required this.formKeys,
    required this.onChanged,
    required this.onAddInput,
    required this.onDeleteInput,
  });

  final List<SkillInput> userInputs;
  final List<GlobalKey<FormState>> formKeys;
  final VoidCallback onChanged;
  final VoidCallback onAddInput;
  final ValueChanged<int> onDeleteInput;

  @override
  ConsumerState<SkillUserInputsEditor> createState() => _SkillUserInputsEditorState();
}

class _SkillUserInputsEditorState extends ConsumerState<SkillUserInputsEditor> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;

    if (widget.userInputs.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.skillsUserInputsHint,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: widget.onAddInput,
            icon: Icon(app_icons.AppIcons.add),
            label: Text(l10n.skillsUserInputs),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.userInputs.asMap().entries.map((entry) {
          final index = entry.key;
          final input = entry.value;
          final formKey = widget.formKeys[index];
          return SkillInputRow(
            key: ValueKey(input.key),
            input: input,
            formKey: formKey,
            index: index,
            onDelete: () => widget.onDeleteInput(index),
          );
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.onAddInput,
          icon: Icon(app_icons.AppIcons.add),
          label: Text(l10n.skillsUserInputs),
        ),
      ],
    );
  }
}

/// Dialog for adding a new skill input
Future<SkillInput?> showAddSkillInputDialog(BuildContext context) async {
  final l10n = context.l10n;
  final theme = Theme.of(context);
  final keyController = TextEditingController();
  final labelController = TextEditingController();
  final hintController = TextEditingController();
  SkillInputType selectedType = SkillInputType.text;
  bool required = true;
  String? defaultValue;
  List<String> options = [];

  return showDialog<SkillInput>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l10n.skillsUserInputs),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkillInputDialogField(
                label: l10n.skillsUserInputs.replaceAll('s', ''), // "User Input"
                hint: 'e.g., target_host',
                controller: TextEditingController(),
                onChanged: (v) => keyController.text = v,
                validator: (v) => v?.trim().isEmpty == true ? 'Key is required' : null,
              ),
              const SizedBox(height: 16),
              SkillInputDialogField(
                label: l10n.skillsUserInputs.replaceAll('s', ''),
                hint: 'e.g., Target Host',
                controller: TextEditingController(),
                onChanged: (v) => labelController.text = v,
                validator: (v) => v?.trim().isEmpty == true ? 'Label is required' : null,
              ),
              const SizedBox(height: 16),
              SkillInputDialogField(
                label: l10n.skillsInputOptional.replaceAll('(', '').replaceAll(')', ''),
                hint: 'e.g., production, staging, localhost',
                controller: hintController,
                onChanged: (v) => hintController.text = v,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<SkillInputType>(
                value: selectedType,
                decoration: InputDecoration(
                  labelText: 'Type',
                  border: const OutlineInputBorder(),
                ),
                items: SkillInputType.values.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type.name),
                )).toList(),
                onChanged: (v) => setState(() => selectedType = v!),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: Text(l10n.skillsUserInputs.replaceAll('s', '').replaceAll('(', '').replaceAll(')', '') + ' Required'),
                value: required,
                onChanged: (v) => setState(() => required = v ?? true),
              ),
              if (selectedType == SkillInputType.select) ...[
                const SizedBox(height: 16),
                SkillInputDialogField(
                  label: 'Options (comma separated)',
                  hint: 'option1, option2, option3',
                  controller: TextEditingController(),
                  onChanged: (v) => options = v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.skillsCancel),
          ),
          FilledButton(
            onPressed: () {
              final newInput = SkillInput(
                key: keyController.text.trim(),
                label: labelController.text.trim(),
                hint: hintController.text.trim(),
                type: selectedType,
                required: required,
                defaultValue: defaultValue,
                options: selectedType == SkillInputType.select ? options : null,
              );
              if (newInput.key.isNotEmpty && newInput.label.isNotEmpty) {
                Navigator.pop(context, newInput);
              }
            },
            child: Text(l10n.skillsSave),
          ),
        ],
      ),
    );
  );
}