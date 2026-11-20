// Personal Skills provider — Riverpod state management

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'skill_model.dart';
import 'skill_storage.dart';

/// Provider for the skill storage instance
final skillStorageProvider = Provider<SkillStorage>((ref) {
  return SkillStorage.instance;
});

/// State for the skills list
class SkillsState {
  const SkillsState({
    this.skills = const [],
    this.hiddenSkills = const [],
    this.isLoading = false,
    this.error,
    this.selectedCategory = SkillCategoryFilter.all,
    this.searchQuery = '',
    this.showHidden = false,
  });

  final List<Skill> skills;
  final List<Skill> hiddenSkills;
  final bool isLoading;
  final String? error;
  final SkillCategoryFilter selectedCategory;
  final String searchQuery;
  final bool showHidden;

  /// Get filtered skills based on current filters
  List<Skill> get filteredSkills {
    var filtered = skills;

    // Apply category filter
    if (selectedCategory != SkillCategoryFilter.all) {
      final category = switch (selectedCategory) {
        SkillCategoryFilter.productivity => SkillCategory.productivity,
        SkillCategoryFilter.development => SkillCategory.development,
        SkillCategoryFilter.automation => SkillCategory.automation,
        SkillCategoryFilter.analysis => SkillCategory.analysis,
        SkillCategoryFilter.other => SkillCategory.other,
        SkillCategoryFilter.all => null,
      };
      if (category != null) {
        filtered = filtered.where((s) => s.category == category).toList();
      }
    }

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((s) =>
          s.name.toLowerCase().contains(query) ||
          s.description.toLowerCase().contains(query) ||
          s.goal.toLowerCase().contains(query)).toList();
    }

    // Apply hidden filter
    if (!showHidden) {
      filtered = filtered.where((s) => !s.hidden).toList();
    }

    return filtered;
  }

  SkillsState copyWith({
    List<Skill>? skills,
    List<Skill>? hiddenSkills,
    bool? isLoading,
    String? error,
    SkillCategoryFilter? selectedCategory,
    String? searchQuery,
    bool? showHidden,
  }) {
    return SkillsState(
      skills: skills ?? this.skills,
      hiddenSkills: hiddenSkills ?? this.hiddenSkills,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      showHidden: showHidden ?? this.showHidden,
    );
  }
}

/// Category filter including "All"
enum SkillCategoryFilter {
  all,
  productivity,
  development,
  automation,
  analysis,
  other,
}

/// Provider for the skills list state
final skillsProvider = NotifierProvider<SkillsController, SkillsState>(() {
  return SkillsController();
});

/// Controller for skills state
class SkillsController extends Notifier<SkillsState> {
  SkillStorage get _storage => ref.read(skillStorageProvider);

  @override
  SkillsState build() {
    _load();
    return const SkillsState();
  }

  /// Load skills from storage
  Future<void> _load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Run auto-hide check
      await _storage.autoHideSkills();

      final allSkills = _storage.getAllSkills();
      final visible = allSkills.where((s) => !s.hidden).toList();
      final hidden = allSkills.where((s) => s.hidden).toList();

      state = state.copyWith(
        skills: visible,
        hiddenSkills: hidden,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh skills from storage
  Future<void> refresh() async {
    await _load();
  }

  /// Create a new skill
  Future<Skill> createSkill(Skill skill) async {
    try {
      // Check for name conflict
      if (_storage.skillNameExists(skill.name)) {
        throw Exception('A skill with this name already exists');
      }
      await _storage.upsertSkill(skill);
      await refresh();
      return skill;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Update an existing skill
  Future<void> updateSkill(Skill skill) async {
    try {
      // Check for name conflict (excluding this skill)
      if (_storage.skillNameExists(skill.name, excludeId: skill.id)) {
        throw Exception('A skill with this name already exists');
      }
      await _storage.upsertSkill(skill);
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Delete a skill
  Future<void> deleteSkill(String id) async {
    try {
      await _storage.deleteSkill(id);
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Hide a skill
  Future<void> hideSkill(String id) async {
    try {
      await _storage.hideSkill(id);
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Restore a hidden skill
  Future<void> restoreSkill(String id) async {
    try {
      await _storage.restoreSkill(id);
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Update skill after successful invocation
  Future<void> recordSuccess(String id) async {
    final skill = _storage.getSkill(id);
    if (skill != null) {
      await _storage.upsertSkill(skill.copyWith(
        lastUsedAt: DateTime.now(),
        useCount: skill.useCount + 1,
        successCount: skill.successCount + 1,
      ));
      await refresh();
    }
  }

  /// Update skill after failed invocation
  Future<void> recordFailure(String id) async {
    final skill = _storage.getSkill(id);
    if (skill != null) {
      await _storage.upsertSkill(skill.copyWith(
        lastUsedAt: DateTime.now(),
        useCount: skill.useCount + 1,
      ));
      await refresh();
    }
  }

  /// Record a skill invocation with full result
  Future<void> recordInvocation(String id, SkillResult result) async {
    await _storage.recordInvocation(id, result);
    if (result.success) {
      await recordSuccess(id);
    } else {
      await recordFailure(id);
    }
  }

  /// Set category filter
  void setCategory(SkillCategoryFilter category) {
    state = state.copyWith(selectedCategory: category);
  }

  /// Set search query
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Toggle show hidden
  void toggleShowHidden() {
    state = state.copyWith(showHidden: !state.showHidden);
  }

  /// Export all skills
  String exportSkills() {
    return _storage.exportSkills();
  }

  /// Import skills
  Future<int> importSkills(String jsonString, {bool overwrite = false}) async {
    final count = await _storage.importSkills(jsonString, overwrite: overwrite);
    await refresh();
    return count;
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for a single skill by ID
final skillProvider = Provider.family<Skill?, String>((ref, id) {
  final storage = ref.watch(skillStorageProvider);
  return storage.getSkill(id);
});