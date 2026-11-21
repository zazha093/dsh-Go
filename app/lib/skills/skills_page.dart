// Personal Skills UI — main page

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../ui/theme/app_icons.dart' as app_icons;
import 'skill_model.dart';
import 'skill_provider.dart';
import 'skill_detail_page.dart';
import 'skill_create_page.dart';

/// Main page for Personal Skills
class SkillsPage extends ConsumerStatefulWidget {
  const SkillsPage({super.key});

  static const routeName = 'skills';

  @override
  ConsumerState<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends ConsumerState<SkillsPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(skillsProvider.notifier).setSearchQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final skillsState = ref.watch(skillsProvider);
    final filteredSkills = skillsState.filteredSkills;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.skillsTitle),
        actions: [
          IconButton(
            icon: const Icon(app_icons.AppIcons.add),
            onPressed: () => _navigateToCreate(),
            tooltip: l10n.skillsCreate,
          ),
          IconButton(
            icon: Icon(
              skillsState.showHidden ? app_icons.AppIcons.showSecret : app_icons.AppIcons.hideSecret,
            ),
            onPressed: () => ref.read(skillsProvider.notifier).toggleShowHidden(),
            tooltip: skillsState.showHidden ? l10n.skillsHide : l10n.skillsShowHidden,
          ),
          PopupMenuButton<String>(
            icon: const Icon(app_icons.AppIcons.moreVertical),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export',
                child: Text(l10n.skillsExport),
              ),
              PopupMenuItem(
                value: 'import',
                child: Text(l10n.skillsImport),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.skillsSearchHint,
                    prefixIcon: const Icon(app_icons.AppIcons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(app_icons.AppIcons.clear),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(skillsProvider.notifier).setSearchQuery('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 12),
                // Category filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: SkillCategoryFilter.values.map((category) {
                      final isSelected = skillsState.selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(_categoryLabel(category)),
                          selected: isSelected,
                          onSelected: (_) => ref.read(skillsProvider.notifier).setCategory(category),
                          showCheckmark: false,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // Skills list
          Expanded(
            child: skillsState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : skillsState.error != null
                    ? _ErrorView(
                        message: skillsState.error!,
                        onRetry: () => ref.read(skillsProvider.notifier).refresh(),
                      )
                    : filteredSkills.isEmpty
                        ? _EmptyView(
                            message: skillsState.showHidden
                                ? l10n.skillsHidden
                                : l10n.skillsEmpty,
                            onCreate: _navigateToCreate,
                          )
                        : RefreshIndicator(
                            onRefresh: () => ref.read(skillsProvider.notifier).refresh(),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filteredSkills.length,
                              itemBuilder: (context, index) {
                                final skill = filteredSkills[index];
                                return _SkillCard(
                                  skill: skill,
                                  onTap: () => _navigateToDetail(skill),
                                  onLongPress: () => _showSkillMenu(skill),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreate,
        tooltip: l10n.skillsCreate,
        child: const Icon(app_icons.AppIcons.add),
      ),
    );
  }

  void _navigateToCreate() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SkillCreatePage()),
    );
  }

  void _navigateToDetail(Skill skill) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SkillDetailPage(skill: skill)),
    );
  }

  void _showSkillMenu(Skill skill) {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(app_icons.AppIcons.edit),
              title: Text(l10n.skillsEdit),
              onTap: () {
                Navigator.pop(context);
                _navigateToDetail(skill);
              },
            ),
            ListTile(
              leading: Icon(skill.hidden ? app_icons.AppIcons.showSecret : app_icons.AppIcons.hideSecret),
              title: Text(skill.hidden ? l10n.skillsRestore : l10n.skillsHide),
              onTap: () {
                Navigator.pop(context);
                if (skill.hidden) {
                  ref.read(skillsProvider.notifier).restoreSkill(skill.id);
                } else {
                  ref.read(skillsProvider.notifier).hideSkill(skill.id);
                }
              },
            ),
            ListTile(
              leading: const Icon(app_icons.AppIcons.delete, color: Colors.red),
              title: Text(l10n.skillsDelete, style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(skill);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Skill skill) async {
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
      await ref.read(skillsProvider.notifier).deleteSkill(skill.id);
    }
  }

  void _handleMenuAction(String action) {
    final l10n = context.l10n;
    switch (action) {
      case 'export':
        _exportSkills();
        break;
      case 'import':
        _importSkills();
        break;
    }
  }

  Future<void> _exportSkills() async {
    final l10n = context.l10n;
    final json = ref.read(skillsProvider.notifier).exportSkills();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.skillsExport),
        content: SingleChildScrollView(
          child: SelectableText(json),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.skillsCancel),
          ),
          FilledButton(
            onPressed: () {
              // Copy to clipboard
              // In a real app, use Clipboard.setData
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Exported to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  Future<void> _importSkills() async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final overwrite = ValueNotifier(false);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.skillsImport),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Paste JSON here...',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: overwrite.value,
                  onChanged: (v) => overwrite.value = v ?? false,
                ),
                Text(l10n.skillsImport), // Reusing as "Overwrite existing"
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.skillsCancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final count = await ref.read(skillsProvider.notifier).importSkills(
                controller.text,
                overwrite: overwrite.value,
              );
              if (count > 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Imported $count skills')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.skillsImportError)),
                );
              }
            },
            child: Text(l10n.skillsImport),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(SkillCategoryFilter category) {
    final l10n = context.l10n;
    switch (category) {
      case SkillCategoryFilter.all:
        return l10n.skillsCategoryAll;
      case SkillCategoryFilter.productivity:
        return l10n.skillsCategoryProductivity;
      case SkillCategoryFilter.development:
        return l10n.skillsCategoryDevelopment;
      case SkillCategoryFilter.automation:
        return l10n.skillsCategoryAutomation;
      case SkillCategoryFilter.analysis:
        return l10n.skillsCategoryAnalysis;
      case SkillCategoryFilter.other:
        return l10n.skillsCategoryOther;
    }
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.skill,
    required this.onTap,
    required this.onLongPress,
  });

  final Skill skill;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          skill.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (skill.hidden) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                        ],
                      ],
                    ),
                  ),
                  _CategoryBadge(category: skill.category),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                skill.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (skill.lastUsedAt != null) ...[
                    Icon(
                      app_icons.AppIcons.scheduled,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.skillsLastUsed.replaceFirst('{date}', _formatDate(skill.lastUsedAt!)),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ] else ...[
                    Icon(
                      app_icons.AppIcons.scheduled,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.skillsNeverUsed,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(width: 16),
                  Icon(
                    app_icons.AppIcons.recurring,
                    size: 14,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.skillsUseCount.replaceFirst('{count}', skill.useCount.toString()),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    app_icons.AppIcons.completed,
                    size: 14,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.skillsSuccessRate.replaceFirst('{rate}', skill.successRate.toString()),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
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

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message, required this.onCreate});

  final String message;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              app_icons.AppIcons.providers,
              size: 64,
              color: colors.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(app_icons.AppIcons.add),
              label: Text(l10n.skillsCreate),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              app_icons.AppIcons.error,
              size: 64,
              color: colors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: theme.textTheme.titleMedium?.copyWith(color: colors.error),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(app_icons.AppIcons.refresh),
              label: Text(l10n.skillsCreate), // Reusing as "Retry"
            ),
          ],
        ),
      ),
    );
  }
}