// Personal Skills UI — create page (also used for distilling from sessions)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../ui/common/app_icons.dart';
import '../ui/common/risk_notice.dart';
import '../ui/theme/app_icons.dart' as app_icons;
import '../ui/theme/theme.dart';
import 'skill_model.dart';
import 'skill_provider.dart';
import 'skill_distill.dart';

/// Create page for a new skill (or distilling from session)
class SkillCreatePage extends ConsumerStatefulWidget {
  const SkillCreatePage({super.key, this.initialSkill, this.sessionId, this.sessionTitle});

  /// Pre-filled skill (for duplication)
  final Skill? initialSkill;

  /// Session to distill from (if distilling)
  final String? sessionId;

  /// Session title (if distilling)
  final String? sessionTitle;

  @override
  ConsumerState<SkillCreatePage> createState() => _SkillCreatePageState();
}

class _SkillCreatePageState extends ConsumerState<SkillCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _goalController = TextEditingController();
  final _stepsController = TextEditingController();
  final _constraintsController = TextEditingController();
  final _toolsController = TextEditingController();

  // User inputs editor state
  final List<SkillInput> _userInputs = [];
  final List<GlobalKey<FormState>> _inputFormKeys = [];

  bool _isLoading = false;
  bool _isDistilling = false;
  Skill? _distilledSkill;
  String? _distillError;

  @override
  void initState() {
    super.initState();
    if (widget.initialSkill != null) {
      _fillForm(widget.initialSkill!);
    } else if (widget.sessionId != null) {
      // Auto-start distillation
      _distillFromSession();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _goalController.dispose();
    _stepsController.dispose();
    _constraintsController.dispose();
    _toolsController.dispose();
    super.dispose();
  }

  void _fillForm(Skill skill) {
    _nameController.text = skill.name;
    _descriptionController.text = skill.description;
    _goalController.text = skill.goal;
    _stepsController.text = skill.steps.join('\n');
    _constraintsController.text = skill.constraints.join('\n');
    _toolsController.text = skill.requiredTools.join(', ');
    _userInputs.clear();
    _userInputs.addAll(skill.userInputs);
    _inputFormKeys.clear();
    _inputFormKeys.addAll(List.generate(skill.userInputs.length, (_) => GlobalKey<FormState>()));
  }

  Future<void> _distillFromSession() async {
    if (widget.sessionId == null) return;

    setState(() {
      _isDistilling = true;
      _distillError = null;
    });

    try {
      // TODO: Implement actual distillation from session history
      // For now, create a template based on session
      final skill = await SkillDistiller.distillFromSession(
        sessionId: widget.sessionId!,
        sessionTitle: widget.sessionTitle ?? 'Unknown Session',
      );
      if (mounted) {
        setState(() {
          _distilledSkill = skill;
          _fillForm(skill);
          _isDistilling = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.skillsDistillSuccess.replaceFirst('{name}', skill.name))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDistilling = false;
          _distillError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final isDistilling = _isDistilling || _distilledSkill != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialSkill != null
            ? l10n.skillsCreate // Duplicate
            : widget.sessionId != null
                ? l10n.skillsDistillTitle
                : l10n.skillsCreate),
        leading: IconButton(
          icon: const Icon(app_icons.AppIcons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.sessionId != null && _distilledSkill == null) ...[
                // Distillation in progress
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          l10n.skillsDistillDescription,
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        if (_distillError != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _distillError!,
                            style: theme.textTheme.bodyMedium?.copyWith(color: colors.error),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _distillFromSession,
                            child: Text(l10n.skillsDistill), // Retry
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Normal form
                _buildForm(),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.skillsCancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saveSkill,
                        child: Text(widget.initialSkill != null
                            ? l10n.skillsSave
                            : widget.sessionId != null
                                ? l10n.skillsDistillSave
                                : l10n.skillsSave),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildForm() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name
        _FormField(
          label: l10n.skillsName,
          hint: l10n.skillsNameHint,
          controller: _nameController,
          validator: (v) => v?.trim().isEmpty == true ? l10n.skillsNameHint : null,
        ),
        const SizedBox(height: 16),

        // Description
        _FormField(
          label: l10n.skillsDescription,
          hint: l10n.skillsDescriptionHint,
          controller: _descriptionController,
          maxLines: 2,
          validator: (v) => v?.trim().isEmpty == true ? l10n.skillsDescriptionHint : null,
        ),
        const SizedBox(height: 16),

        // Goal
        _FormField(
          label: l10n.skillsGoal,
          hint: l10n.skillsGoalHint,
          controller: _goalController,
          maxLines: 2,
          validator: (v) => v?.trim().isEmpty == true ? l10n.skillsGoalHint : null,
        ),
        const SizedBox(height: 16),

        // Steps
        _FormField(
          label: l10n.skillsSteps,
          hint: l10n.skillsStepsHint,
          controller: _stepsController,
          maxLines: 5,
          validator: (v) => v?.trim().isEmpty == true ? l10n.skillsStepsHint : null,
        ),
        const SizedBox(height: 16),

        // Constraints
        _FormField(
          label: l10n.skillsConstraints,
          hint: l10n.skillsConstraintsHint,
          controller: _constraintsController,
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        // Required Tools
        _FormField(
          label: l10n.skillsRequiredTools,
          hint: l10n.skillsRequiredToolsHint,
          controller: _toolsController,
        ),
        const SizedBox(height: 16),

        // User Inputs
        _SectionTitle(title: l10n.skillsUserInputs),
        _UserInputsEditor(
          userInputs: _userInputs,
          formKeys: _inputFormKeys,
          onChanged: () => setState(() {}),
          onAddInput: () => _showAddInputDialog(context),
          onDeleteInput: (index) => setState(() {
            _userInputs.removeAt(index);
            _inputFormKeys.removeAt(index);
          }),
          l10n: l10n,
        ),
        const SizedBox(height: 16),

        // Warning about secrets
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(app_icons.AppIcons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.skillsSecretsWarning,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Distilled preview (if available)
        if (_distilledSkill != null) ...[
          _SectionTitle(title: l10n.skillsDistillFormula),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name: ${_distilledSkill!.name}', style: theme.textTheme.bodySmall),
                Text('Goal: ${_distilledSkill!.goal}', style: theme.textTheme.bodySmall),
                Text('Steps: ${_distilledSkill!.steps.length}', style: theme.textTheme.bodySmall),
                Text('Tools: ${_distilledSkill!.requiredTools.join(', ')}', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Future<void> _saveSkill() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate each input form
    for (final formKey in _inputFormKeys) {
      if (formKey.currentState != null && !formKey.currentState!.validate()) {
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final skill = Skill(
        id: widget.initialSkill?.id ?? _generateId(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        goal: _goalController.text.trim(),
        steps: _stepsController.text.split('\n').where((s) => s.trim().isNotEmpty).toList(),
        constraints: _constraintsController.text.split('\n').where((s) => s.trim().isNotEmpty).toList(),
        requiredTools: _toolsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        userInputs: List.from(_userInputs),
        createdAt: widget.initialSkill?.createdAt ?? DateTime.now(),
        updatedAt: widget.initialSkill != null ? DateTime.now() : null,
        category: _inferCategory(),
        sourceSessionId: widget.sessionId,
        sourceSessionTitle: widget.sessionTitle,
        version: widget.initialSkill?.version ?? 1,
      );

      if (widget.initialSkill != null) {
        await ref.read(skillsProvider.notifier).updateSkill(skill);
      } else {
        await ref.read(skillsProvider.notifier).createSkill(skill);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.skillsDistillSuccess.replaceFirst('{name}', skill.name))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  SkillCategory _inferCategory() {
    final tools = _toolsController.text.toLowerCase();
    final name = _nameController.text.toLowerCase();
    final desc = _descriptionController.text.toLowerCase();

    if (tools.contains('bash') || tools.contains('edit') || tools.contains('write') || name.contains('code') || name.contains('develop')) {
      return SkillCategory.development;
    }
    if (tools.contains('web_fetch') || tools.contains('web_search') || name.contains('auto') || name.contains('script')) {
      return SkillCategory.automation;
    }
    if (name.contains('analy') || name.contains('report') || name.contains('summar')) {
      return SkillCategory.analysis;
    }
    if (name.contains('product') || name.contains('todo') || name.contains('note') || name.contains('brief')) {
      return SkillCategory.productivity;
    }
    return SkillCategory.other;
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
        (DateTime.now().microsecond % 1000).toRadixString(36);
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.validator,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

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

/// User inputs editor widget for SkillCreatePage
class _UserInputsEditor extends StatelessWidget {
  const _UserInputsEditor({
    required this.userInputs,
    required this.formKeys,
    required this.onChanged,
    required this.onAddInput,
    required this.onDeleteInput,
    required this.l10n,
  });

  final List<SkillInput> userInputs;
  final List<GlobalKey<FormState>> formKeys;
  final VoidCallback onChanged;
  final VoidCallback onAddInput;
  final ValueChanged<int> onDeleteInput;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (userInputs.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.skillsUserInputsHint,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onAddInput,
            icon: const Icon(app_icons.AppIcons.add),
            label: Text(l10n.skillsUserInputs),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...userInputs.asMap().entries.map((entry) {
          final index = entry.key;
          final input = entry.value;
          final formKey = formKeys[index];
          return _InputRow(
            key: ValueKey(input.key),
            input: input,
            formKey: formKey,
            index: index,
            onDelete: () => onDeleteInput(index),
            l10n: l10n,
          );
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _showAddInputDialog(context),
          icon: const Icon(app_icons.AppIcons.add),
          label: Text(l10n.skillsUserInputs),
        ),
      ],
    );
  }

  void _showAddInputDialog(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final keyController = TextEditingController();
    final labelController = TextEditingController();
    final hintController = TextEditingController();
    SkillInputType selectedType = SkillInputType.text;
    bool required = true;
    String? defaultValue;
    List<String> options = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.skillsUserInputs),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _InputDialogField(
                  label: l10n.skillsUserInputs.replaceAll('s', ''), // "User Input"
                  hint: 'e.g., target_host',
                  controller: TextEditingController(),
                  onChanged: (v) => keyController.text = v,
                  validator: (v) => v?.trim().isEmpty == true ? 'Key is required' : null,
                ),
                const SizedBox(height: 16),
                _InputDialogField(
                  label: l10n.skillsUserInputs.replaceAll('s', ''),
                  hint: 'e.g., Target Host',
                  controller: TextEditingController(),
                  onChanged: (v) => labelController.text = v,
                  validator: (v) => v?.trim().isEmpty == true ? 'Label is required' : null,
                ),
                const SizedBox(height: 16),
                _InputDialogField(
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
                  title: Text(l10n.skillsUserInputs.replaceAll('s', '').replace('(', '').replace(')', '') + ' Required'),
                  value: required,
                  onChanged: (v) => setState(() => required = v ?? true),
                ),
                if (selectedType == SkillInputType.select) ...[
                  const SizedBox(height: 16),
                  _InputDialogField(
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
                  // The parent will handle adding the input
                  Navigator.pop(context, newInput);
                }
              },
              child: Text(l10n.skillsSave),
            ),
          ],
        ),
      );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.input,
    required this.formKey,
    required this.index,
    required this.onDelete,
    required this.l10n,
  });

  final SkillInput input;
  final GlobalKey<FormState> formKey;
  final int index;
  final VoidCallback onDelete;
  final AppLocalizations l10n;

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
                _InputInfoChip(label: 'Key', value: input.key),
                _InputInfoChip(label: 'Hint', value: input.hint),
                _InputInfoChip(label: 'Type', value: input.type.name),
                if (input.type == SkillInputType.select && input.options != null)
                  _InputInfoChip(label: 'Options', value: input.options!.join(', ')),
                if (input.defaultValue != null && input.defaultValue!.isNotEmpty)
                  _InputInfoChip(label: 'Default', value: input.defaultValue!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final l10n = context.l10n;
    showDialog(
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
      ).then((confirmed) {
        if (confirmed == true) {
          // The parent will handle the deletion via callback
        }
      });
  }
}

class _InputInfoChip extends StatelessWidget {
  const _InputInfoChip({required this.label, required this.value});

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

class _InputDialogField extends StatelessWidget {
  const _InputDialogField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

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

class _InputInfoChip extends StatelessWidget {
  const _InputInfoChip({required this.label, required this.value});

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

class _InputDialogField extends StatelessWidget {
  const _InputDialogField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

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