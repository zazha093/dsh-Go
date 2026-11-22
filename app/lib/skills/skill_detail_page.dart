// Personal Skills UI — detail page

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/chat_state.dart';
import '../state/sessions_state.dart';
import '../ui/theme/app_icons.dart' as app_icons;
import 'skill_model.dart';
import 'skill_provider.dart';
import 'skill_create_page.dart';

/// Detail page for a skill (view/edit)
class SkillDetailPage extends ConsumerStatefulWidget {
  const SkillDetailPage({super.key, required this.skill});

  final Skill skill;

  @override
  ConsumerState<SkillDetailPage> createState() => _SkillDetailPageState();
}

class _SkillDetailPageState extends ConsumerState<SkillDetailPage> {
  late Skill _skill;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _skill = widget.skill;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(_skill.name),
        actions: [
          if (_skill.hidden)
            IconButton(
              icon: const Icon(app_icons.AppIcons.showSecret),
              onPressed: () => _restoreSkill(),
              tooltip: l10n.skillsRestore,
            )
          else
            IconButton(
              icon: const Icon(app_icons.AppIcons.hideSecret),
              onPressed: () => _hideSkill(),
              tooltip: l10n.skillsHide,
            ),
          IconButton(
            icon: const Icon(app_icons.AppIcons.edit),
            onPressed: () => setState(() => _isEditing = true),
            tooltip: l10n.skillsEdit,
          ),
          PopupMenuButton<String>(
            icon: const Icon(app_icons.AppIcons.moreVertical),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'duplicate',
                child: Text(l10n.skillsCreate), // Reusing as "Duplicate"
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(l10n.skillsDelete, style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: _isEditing ? _buildEditForm() : _buildDetailView(),
    );
  }

  Widget _buildDetailView() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with category and stats
          Row(
            children: [
              _CategoryBadge(category: _skill.category),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_skill.hidden)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l10n.skillsHidden,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (_skill.sourceSessionTitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'From: ${_skill.sourceSessionTitle}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Description
          _SectionTitle(title: l10n.skillsDescription),
          Text(_skill.description, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),

          // Goal
          _SectionTitle(title: l10n.skillsGoal),
          Text(_skill.goal, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),

          // Steps
          _SectionTitle(title: l10n.skillsSteps),
          ..._skill.steps.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.key + 1}. ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                    Expanded(child: Text(entry.value, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              )),
          const SizedBox(height: 16),

          // Constraints
          if (_skill.constraints.isNotEmpty) ...[
            _SectionTitle(title: l10n.skillsConstraints),
            ..._skill.constraints.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(app_icons.AppIcons.blocked, size: 16, color: colors.error),
                      const SizedBox(width: 8),
                      Expanded(child: Text(c, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
          ],

          // Required Tools
          _SectionTitle(title: l10n.skillsRequiredTools),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skill.requiredTools.map((tool) => Chip(
                  label: Text(tool),
                  avatar: Icon(_toolIcon(tool), size: 16),
                )).toList(),
          ),
          const SizedBox(height: 16),

          // User Inputs
          if (_skill.userInputs.isNotEmpty) ...[
            _SectionTitle(title: l10n.skillsUserInputs),
            ..._skill.userInputs.map((input) => _InputRow(input: input)),
            const SizedBox(height: 16),
          ],

          // Stats
          _SectionTitle(title: 'Statistics'),
          _StatRow(
            label: l10n.skillsUseCount.replaceFirst('{count}', _skill.useCount.toString()),
            value: '${_skill.successRate}%',
            icon: app_icons.AppIcons.recurring,
          ),
          _StatRow(
            label: l10n.skillsSuccessRate.replaceFirst('{rate}', _skill.successRate.toString()),
            value: '${_skill.successCount}/${_skill.useCount}',
            icon: app_icons.AppIcons.completed,
          ),
          _StatRow(
            label: _skill.lastUsedAt != null
                ? l10n.skillsLastUsed.replaceFirst('{date}', _formatDate(_skill.lastUsedAt!))
                : l10n.skillsNeverUsed,
            value: _skill.version.toString(),
            icon: app_icons.AppIcons.scheduled,
          ),
          _StatRow(
            label: 'Version',
            value: _skill.version.toString(),
            icon: app_icons.AppIcons.bookmark,
          ),
          const SizedBox(height: 24),

          // Run button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _runSkill,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(app_icons.AppIcons.play),
              label: Text(_isLoading ? l10n.skillsInvoking : l10n.skillsInvoke),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final nameController = TextEditingController(text: _skill.name);
    final descriptionController = TextEditingController(text: _skill.description);
    final goalController = TextEditingController(text: _skill.goal);
    final stepsController = TextEditingController(text: _skill.steps.join('\n'));
    final constraintsController = TextEditingController(text: _skill.constraints.join('\n'));
    final toolsController = TextEditingController(text: _skill.requiredTools.join(', '));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: l10n.skillsName),
          TextField(
            controller: nameController,
            decoration: InputDecoration(hintText: l10n.skillsNameHint),
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: l10n.skillsDescription),
          TextField(
            controller: descriptionController,
            decoration: InputDecoration(hintText: l10n.skillsDescriptionHint),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: l10n.skillsGoal),
          TextField(
            controller: goalController,
            decoration: InputDecoration(hintText: l10n.skillsGoalHint),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: l10n.skillsSteps),
          TextField(
            controller: stepsController,
            decoration: InputDecoration(hintText: l10n.skillsStepsHint),
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: l10n.skillsConstraints),
          TextField(
            controller: constraintsController,
            decoration: InputDecoration(hintText: l10n.skillsConstraintsHint),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: l10n.skillsRequiredTools),
          TextField(
            controller: toolsController,
            decoration: InputDecoration(hintText: l10n.skillsRequiredToolsHint),
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
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _isEditing = false),
                  child: Text(l10n.skillsCancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => _saveSkill(
                    nameController.text,
                    descriptionController.text,
                    goalController.text,
                    stepsController.text.split('\n').where((s) => s.trim().isNotEmpty).toList(),
                    constraintsController.text.split('\n').where((s) => s.trim().isNotEmpty).toList(),
                    toolsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                  ),
                  child: Text(l10n.skillsSave),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveSkill(
    String name,
    String description,
    String goal,
    List<String> steps,
    List<String> constraints,
    List<String> tools,
  ) async {
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.skillsNameHint)),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final updated = _skill.copyWith(
        name: name.trim(),
        description: description.trim(),
        goal: goal.trim(),
        steps: steps,
        constraints: constraints,
        requiredTools: tools,
        updatedAt: DateTime.now(),
        version: _skill.version + 1,
      );
      await ref.read(skillsProvider.notifier).updateSkill(updated);
      if (mounted) {
        setState(() {
          _skill = updated;
          _isEditing = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _hideSkill() async {
    await ref.read(skillsProvider.notifier).hideSkill(_skill.id);
    if (mounted) {
      setState(() => _skill = _skill.copyWith(hidden: true, hiddenAt: DateTime.now()));
    }
  }

  Future<void> _restoreSkill() async {
    await ref.read(skillsProvider.notifier).restoreSkill(_skill.id);
    if (mounted) {
      setState(() => _skill = _skill.copyWith(hidden: false, hiddenAt: null));
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'duplicate':
        _duplicateSkill();
        break;
      case 'delete':
        _confirmDelete();
        break;
    }
  }

  void _duplicateSkill() {
    final duplicated = _skill.copyWith(
      id: '', // Will be generated
      name: '${_skill.name} (copy)',
      createdAt: DateTime.now(),
      updatedAt: null,
      lastUsedAt: null,
      useCount: 0,
      successCount: 0,
      version: 1,
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SkillCreatePage(initialSkill: duplicated)),
    );
  }

  Future<void> _confirmDelete() async {
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
      await ref.read(skillsProvider.notifier).deleteSkill(_skill.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _runSkill() async {
    final l10n = context.l10n;

    // Check if we have a current session to run in
    final currentSessionId = ref.read(currentSessionProvider);
    if (currentSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.skillsRunError.replaceFirst('{error}', 'No active session'))),
      );
      return;
    }

    // If skill has required user inputs, prompt for them first
    Map<String, String>? userInputs;
    if (_skill.userInputs.isNotEmpty) {
      userInputs = await _promptForInputs();
      if (userInputs == null) return; // User cancelled
    }

    // Build the skill execution prompt with user inputs
    final prompt = _buildSkillPrompt(_skill, userInputs: userInputs);

    setState(() => _isLoading = true);

    try {
      // Send the skill prompt to the current chat session
      final chatController = ref.read(chatProvider(currentSessionId).notifier);
      final success = await chatController.send(prompt);

      if (success) {
        // Record successful invocation
        await ref.read(skillsProvider.notifier).recordSuccess(_skill.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.skillsRunSuccess)),
          );
          // Prompt to update formula if user wants to refine it
          await _promptUpdateFormula();
        }
      } else {
        // Record failed invocation
        await ref.read(skillsProvider.notifier).recordFailure(_skill.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.skillsRunError.replaceFirst('{error}', 'Failed to send'))),
          );
        }
      }
    } catch (e) {
      await ref.read(skillsProvider.notifier).recordFailure(_skill.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.skillsRunError.replaceFirst('{error}', e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Build the prompt to send to the chat to execute this skill
  String _buildSkillPrompt(Skill skill, {Map<String, String>? userInputs}) {
    final buffer = StringBuffer();
    buffer.writeln('🤖 **Running Personal Skill: ${skill.name}**');
    buffer.writeln('');
    buffer.writeln('**Goal:** ${skill.goal}');
    buffer.writeln('');

    if (skill.userInputs.isNotEmpty) {
      buffer.writeln('**Required Inputs:**');
      for (final input in skill.userInputs) {
        final value = userInputs?[input.key];
        if (value != null && value.isNotEmpty) {
          buffer.writeln('- ${input.label} (${input.key}): $value');
        } else {
          buffer.writeln('- ${input.label} (${input.key}): ${input.hint} *(not provided)*');
        }
      }
      buffer.writeln('');
    }

    buffer.writeln('**Steps to Execute:**');
    for (int i = 0; i < skill.steps.length; i++) {
      buffer.writeln('${i + 1}. ${skill.steps[i]}');
    }
    buffer.writeln('');

    if (skill.constraints.isNotEmpty) {
      buffer.writeln('**Constraints:**');
      for (final constraint in skill.constraints) {
        buffer.writeln('- $constraint');
      }
      buffer.writeln('');
    }

    buffer.writeln('**Required Tools:** ${skill.requiredTools.join(', ')}');
    buffer.writeln('');
    buffer.writeln('---');
    buffer.writeln('Please execute this skill step by step. Ask for clarification if any step is unclear.');

    return buffer.toString();
  }

  /// Prompt user to update the skill formula after a successful run
  Future<void> _promptUpdateFormula() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.skillsUpdateAvailable),
        content: Text(l10n.skillsUpdateConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.skillsCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.skillsUpdate),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Navigate to SkillCreatePage with current skill for editing
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SkillCreatePage(initialSkill: _skill),
        ),
      );
    }
  }

  /// Prompt user for required inputs
  Future<Map<String, String>?> _promptForInputs() async {
    final l10n = context.l10n;
    final controllers = <String, TextEditingController>{};

    for (final input in _skill.userInputs) {
      controllers[input.key] = TextEditingController(text: input.defaultValue ?? '');
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.skillsInputPrompt.replaceFirst('{inputs}', _skill.userInputs.map((i) => i.label).join(', '))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _skill.userInputs.map((input) {
              final controller = controllers[input.key]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: input.label,
                    hintText: input.hint,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: input.type == SkillInputType.multiline ? 3 : 1,
                  keyboardType: input.type == SkillInputType.number
                      ? TextInputType.number
                      : TextInputType.text,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.skillsCancel),
          ),
          FilledButton(
            onPressed: () {
              final result = <String, String>{};
              for (final input in _skill.userInputs) {
                result[input.key] = controllers[input.key]!.text;
              }
              Navigator.pop(context, result);
            },
            child: Text(l10n.skillsSave),
          ),
        ],
      ),
    );

    return result;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  IconData _toolIcon(String tool) {
    switch (tool) {
      case 'bash':
        return app_icons.AppIcons.terminal;
      case 'edit':
      case 'str_replace_editor':
        return app_icons.AppIcons.edit;
      case 'web_fetch':
        return app_icons.AppIcons.web;
      case 'web_search':
        return app_icons.AppIcons.search;
      case 'write':
        return app_icons.AppIcons.write;
      default:
        return app_icons.AppIcons.tool;
    }
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

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({required this.input});

  final SkillInput input;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            input.required ? app_icons.AppIcons.completed : app_icons.AppIcons.radioOff,
            size: 18,
            color: colors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      input.label,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (!input.required) ...[
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.skillsInputOptional,
                        style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
                Text(input.hint, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final SkillCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final (label, color) = switch (category) {
      SkillCategory.productivity => ('📈', colors.primary),
      SkillCategory.development => ('💻', colors.secondary),
      SkillCategory.automation => ('⚙️', colors.tertiary),
      SkillCategory.analysis => ('📊', Colors.green),
      SkillCategory.other => ('📦', colors.outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}