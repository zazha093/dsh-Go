// Personal Skills UI — create page (also used for distilling from sessions)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/connection_state.dart';
import '../ui/theme/app_icons.dart' as app_icons;
import 'skill_model.dart';
import 'skill_provider.dart';
import 'skill_distill.dart';
import 'widgets/form_field.dart';
import 'widgets/section_title.dart';
import 'widgets/user_inputs_editor.dart';
import 'widgets/kind_selector.dart';
import 'widgets/step_editor.dart';
import 'widgets/parameter_binding_ui.dart';
import 'widgets/dry_run_preview.dart';

/// Create page for a new skill (or distilling from session, or from selected message)
class SkillCreatePage extends ConsumerStatefulWidget {
  const SkillCreatePage({
    super.key,
    this.initialSkill,
    this.sessionId,
    this.sessionTitle,
    this.draftText,
    this.draftTools,
  });

  /// Pre-filled skill (for duplication)
  final Skill? initialSkill;

  /// Session to distill from (if distilling)
  final String? sessionId;

  /// Session title (if distilling)
  final String? sessionTitle;

  /// Draft text from selected message (for "Save as Skill from This Message")
  final String? draftText;

  /// Tool names from the selected message's tool calls
  final List<String>? draftTools;

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

  // New v2 fields
  String _kind = 'workflow';
  List<SkillStep> _executableSteps = [];
  List<SkillParameter> _parameters = [];

  // User inputs editor state
  final List<SkillInput> _userInputs = [];
  final List<GlobalKey<FormState>> _inputFormKeys = [];

  bool _isLoading = false;
  bool _isPopping = false;
  Skill? _distilledSkill;
  String? _distillError;

  @override
  void initState() {
    super.initState();
    if (widget.initialSkill != null) {
      _fillForm(widget.initialSkill!);
    } else if (widget.draftText != null) {
      // Create draft from selected message text
      _createDraftFromText();
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

    // v2 fields
    _kind = skill.kind;
    _executableSteps = skill.executableSteps ?? [];
    _parameters = skill.parameters ?? [];
  }

  /// Create a draft skill from selected message text using regex-based extraction
  void _createDraftFromText() {
    final text = widget.draftText ?? '';
    final tools = widget.draftTools ?? [];
    final locale = Localizations.localeOf(context).languageCode; // e.g., 'th', 'en', 'zh'

    // Use the new regex-based extraction (no AI)
    final draftSkill = SkillDistiller.createFromMessageText(
      userMessage: text,
      aiResponse: null, // No AI response available for selected message
      toolCalls: tools,
      sessionTitle: 'From message',
      locale: locale,
    );

    _fillForm(draftSkill);

    // Show a snackbar to indicate draft was created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.skillsDistillSuccess.replaceFirst('{name}', draftSkill.name))),
        );
      }
    });
  }

  Future<void> _distillFromSession() async {
    if (widget.sessionId == null) return;
    if (!mounted) return;

    setState(() {
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
      if (!mounted) return;
      setState(() {
        _distilledSkill = skill;
        _fillForm(skill);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.skillsDistillSuccess.replaceFirst('{name}', skill.name))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _distillError = e.toString();
      });
    }
  }

  // Phase 3 widget change handlers
  void _onKindChanged(String kind) {
    setState(() {
      _kind = kind;
      // Clear executable steps if switching away from executable
      if (kind != 'executable') {
        _executableSteps = [];
      }
    });
  }

  void _onStepsChanged(List<SkillStep> steps) {
    setState(() {
      _executableSteps = steps;
    });
  }

  void _onParametersChanged(List<SkillParameter> params) {
    setState(() {
      _parameters = params;
    });
  }

  /// Single exit point for all pop paths — prevents double pop during animation.
  void _safePop<T extends Object?>([T? result]) {
    if (_isPopping || !mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return; // Already popping or not top route
    _isPopping = true;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return PopScope(
      canPop: !_isLoading, // Prevent popping while loading
      onPopInvokedWithResult: (didPop, result) {
        // Always dismiss keyboard before/when popping
        FocusManager.instance.primaryFocus?.unfocus();
        // If blocked by canPop, notify user
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.skillsSaving)),
          );
        }
        // No manual pop here - let the framework handle it via canPop
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.initialSkill != null
              ? l10n.skillsCreate // Duplicate
              : widget.sessionId != null
                  ? l10n.skillsDistillTitle
                  : l10n.skillsCreate),
          leading: IconButton(
            icon: const Icon(app_icons.AppIcons.close),
            onPressed: _isLoading ? null : () => _safePop(),
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
                          onPressed: _isLoading ? null : () => _safePop(),
                          child: Text(l10n.skillsCancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isLoading ? null : _saveSkill,
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
        // Kind Selector
        KindSelector(
          selectedKind: _kind,
          onKindChanged: _onKindChanged,
        ),
        const SizedBox(height: 16),

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

        // Steps (text) - shown for knowledge/workflow
        if (_kind != 'executable') ...[
          SkillFormField(
            label: l10n.skillsSteps,
            hint: l10n.skillsStepsHint,
            controller: _stepsController,
            maxLines: 5,
            validator: (v) => v?.trim().isEmpty == true ? l10n.skillsStepsHint : null,
          ),
          const SizedBox(height: 16),
        ],

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

        // Executable Steps (for executable kind)
        if (_kind == 'executable') ...[
          StepEditor(
            steps: _executableSteps,
            onStepsChanged: _onStepsChanged,
            parameters: _parameters,
            onParametersChanged: _onParametersChanged,
            kind: _kind,
          ),
          const SizedBox(height: 16),
        ],

        // Constraints (text)
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

        // Parameter Binding (for executable kind)
        if (_kind == 'executable') ...[
          ParameterBindingUI(
            parameters: _parameters,
            onParametersChanged: _onParametersChanged,
          ),
          const SizedBox(height: 16),
        ],

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

        // Dry Run Preview (for executable kind)
        if (_kind == 'executable') ...[
          DryRunPreview(
            skill: Skill(
              id: 'draft',
              name: _nameController.text.trim().isEmpty ? 'Draft' : _nameController.text.trim(),
              description: _descriptionController.text.trim(),
              goal: _goalController.text.trim(),
              steps: _kind == 'executable' ? [] : _stepsController.text.split('\n').where((s) => s.trim().isNotEmpty).toList(),
              constraints: _constraintsController.text.split('\n').where((s) => s.trim().isNotEmpty).toList(),
              requiredTools: _toolsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
              userInputs: _userInputs,
              createdAt: DateTime.now(),
              category: _inferCategory(),
              kind: _kind,
              schemaVersion: 2,
              executableSteps: _executableSteps,
              parameters: _parameters,
            ),
          ),
          const SizedBox(height: 16),
        ],

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

    if (!mounted) return;
    if (_isLoading || _isPopping) return;
    setState(() => _isLoading = true);

    try {
      final skill = Skill(
        id: widget.initialSkill?.id ?? _generateId(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        goal: _goalController.text.trim(),
        steps: _kind == 'executable' ? [] : _stepsController.text.split('\n').where((s) => s.trim().isNotEmpty).toList(),
        constraints: _constraintsController.text.split('\n').where((s) => s.trim().isNotEmpty).toList(),
        requiredTools: _toolsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        userInputs: List.from(_userInputs),
        createdAt: widget.initialSkill?.createdAt ?? DateTime.now(),
        updatedAt: widget.initialSkill != null ? DateTime.now() : null,
        category: _inferCategory(),
        sourceSessionId: widget.sessionId,
        sourceSessionTitle: widget.sessionTitle,
        version: widget.initialSkill?.version ?? 1,
        // v2 fields
        kind: _kind,
        schemaVersion: 2,
        executableSteps: _kind == 'executable' ? _executableSteps : null,
        parameters: _kind == 'executable' ? _parameters : null,
        errorHandling: _kind == 'executable' ? SkillErrorHandling() : null,
      );

      if (widget.initialSkill != null) {
        await ref.read(skillsProvider.notifier).updateSkill(skill);
      } else {
        await ref.read(skillsProvider.notifier).createSkill(skill);
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      _safePop(skill); // Pop with result; caller shows snackbar
      // Show snackbar after pop (messenger is still valid)
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.skillsDistillSuccess.replaceFirst('{name}', skill.name))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted && !_isPopping) setState(() => _isLoading = false);
    }
  }

  SkillCategory _inferCategory() {
    final tools = _toolsController.text.toLowerCase();
    final name = _nameController.text.toLowerCase();

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