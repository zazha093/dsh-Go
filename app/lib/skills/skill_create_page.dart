// Personal Skills UI — create page (also used for distilling from sessions)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/connection_state.dart';
import '../ui/common/risk_notice.dart';
import '../ui/theme/app_icons.dart' as app_icons;
import '../ui/theme/theme.dart';
import 'skill_model.dart';
import 'skill_provider.dart';
import 'skill_distill.dart';
import 'widgets/form_field.dart';
import 'widgets/section_title.dart';
import 'widgets/user_inputs_editor.dart';

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
      final client = ref.read(activeConnectionProvider).value?.client;
      if (client == null) {
        throw StateError('No active connection available for distillation');
      }
      final skill = await SkillDistiller.distillFromSession(
        client: client,
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
        SkillFormField(
          label: l10n.skillsName,
          hint: l10n.skillsNameHint,
          controller: _nameController,
          validator: (v) => v?.trim().isEmpty == true ? l10n.skillsNameHint : null,
        ),
        const SizedBox(height: 16),

        // Description
        SkillFormField(
          label: l10n.skillsDescription,
          hint: l10n.skillsDescriptionHint,
          controller: _descriptionController,
          maxLines: 2,
          validator: (v) => v?.trim().isEmpty == true ? l10n.skillsDescriptionHint : null,
        ),
        const SizedBox(height: 16),

        // Goal
        SkillFormField(
          label: l10n.skillsGoal,
          hint: l10n.skillsGoalHint,
          controller: _goalController,
          maxLines: 2,
          validator: (v) => v?.trim().isEmpty == true ? l10n.skillsGoalHint : null,
        ),
        const SizedBox(height: 16),

        // Steps
        SkillFormField(
          label: l10n.skillsSteps,
          hint: l10n.skillsStepsHint,
          controller: _stepsController,
          maxLines: 5,
          validator: (v) => v?.trim().isEmpty == true ? l10n.skillsStepsHint : null,
        ),
        const SizedBox(height: 16),

        // Constraints
        SkillFormField(
          label: l10n.skillsConstraints,
          hint: l10n.skillsConstraintsHint,
          controller: _constraintsController,
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        // Required Tools
        SkillFormField(
          label: l10n.skillsRequiredTools,
          hint: l10n.skillsRequiredToolsHint,
          controller: _toolsController,
        ),
        const SizedBox(height: 16),

        // User Inputs
        SkillSectionTitle(title: l10n.skillsUserInputs),
        SkillUserInputsEditor(
          userInputs: _userInputs,
          formKeys: _inputFormKeys,
          onChanged: () => setState(() {}),
          onAddInput: () async {
            final newInput = await showAddSkillInputDialog(context);
            if (newInput != null && mounted) {
              setState(() {
                _userInputs.add(newInput);
                _inputFormKeys.add(GlobalKey<FormState>());
              });
            }
          },
          onDeleteInput: (index) => setState(() {
            _userInputs.removeAt(index);
            _inputFormKeys.removeAt(index);
          }),
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
          SkillSectionTitle(title: l10n.skillsDistillFormula),
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
    final l10n = context.l10n;
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