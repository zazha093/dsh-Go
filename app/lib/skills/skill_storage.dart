// Personal Skills storage — local-only using SharedPreferences
// No cloud, no accounts, no sync.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'skill_model.dart';

/// Storage key for skills list
const _skillsStorageKey = 'personal_skills_v1';

/// Storage key for skill invocation history
const _skillHistoryKey = 'personal_skills_history_v1';

/// Maximum history entries to keep
const _maxHistoryEntries = 1000;

/// Local storage for personal skills using SharedPreferences.
class SkillStorage {
  SkillStorage._();

  static final SkillStorage instance = SkillStorage._();

  SharedPreferences? _prefs;

  /// Initialize the storage (call once at app startup)
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get all skills (visible + hidden)
  List<Skill> getAllSkills() {
    if (_prefs == null) return [];
    final jsonString = _prefs!.getString(_skillsStorageKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => Skill.fromJson(e as Map<String, Object?>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get visible (non-hidden) skills
  List<Skill> getVisibleSkills() {
    return getAllSkills().where((s) => !s.hidden).toList();
  }

  /// Get hidden skills
  List<Skill> getHiddenSkills() {
    return getAllSkills().where((s) => s.hidden).toList();
  }

  /// Get a skill by ID
  Skill? getSkill(String id) {
    return getAllSkills().firstWhereOrNull((s) => s.id == id);
  }

  /// Save all skills (replaces entire list)
  Future<void> saveAllSkills(List<Skill> skills) async {
    if (_prefs == null) return;
    final jsonString = jsonEncode(skills.map((s) => s.toJson()).toList());
    await _prefs!.setString(_skillsStorageKey, jsonString);
  }

  /// Add or update a single skill
  Future<void> upsertSkill(Skill skill) async {
    final skills = getAllSkills();
    final index = skills.indexWhere((s) => s.id == skill.id);
    if (index >= 0) {
      skills[index] = skill;
    } else {
      skills.add(skill);
    }
    await saveAllSkills(skills);
  }

  /// Delete a skill by ID
  Future<void> deleteSkill(String id) async {
    final skills = getAllSkills().where((s) => s.id != id).toList();
    await saveAllSkills(skills);
    // Also clean up history for this skill
    await _cleanupHistory(id);
  }

  /// Hide a skill
  Future<void> hideSkill(String id) async {
    final skill = getSkill(id);
    if (skill != null) {
      await upsertSkill(skill.copyWith(
        hidden: true,
        hiddenAt: DateTime.now(),
      ));
    }
  }

  /// Restore a hidden skill
  Future<void> restoreSkill(String id) async {
    final skill = getSkill(id);
    if (skill != null) {
      await upsertSkill(skill.copyWith(
        hidden: false,
        hiddenAt: null,
      ));
    }
  }

  /// Record a skill invocation (for usage tracking)
  Future<void> recordInvocation(String skillId, SkillResult result) async {
    if (_prefs == null) return;
    final history = _getHistory();
    history.add({
      'skillId': skillId,
      'timestamp': DateTime.now().toIso8601String(),
      'success': result.success,
      'error': result.error,
      'durationMs': result.duration?.inMilliseconds,
      'stepsCompleted': result.stepsCompleted,
      'totalSteps': result.totalSteps,
    });
    // Trim to max entries
    if (history.length > _maxHistoryEntries) {
      history.removeRange(0, history.length - _maxHistoryEntries);
    }
    await _saveHistory(history);
  }

  /// Get invocation history for a skill
  List<Map<String, Object?>> getHistory(String skillId) {
    final history = _getHistory();
    return history.where((e) => e['skillId'] == skillId).toList();
  }

  /// Get all invocation history
  List<Map<String, Object?>> getAllHistory() {
    return _getHistory();
  }

  /// Check if a skill name already exists (case-insensitive)
  bool skillNameExists(String name, {String? excludeId}) {
    final skills = getAllSkills();
    final lowerName = name.toLowerCase();
    return skills.any((s) =>
        s.name.toLowerCase() == lowerName && (excludeId == null || s.id != excludeId));
  }

  /// Auto-hide skills that meet the criteria (14 days no use or repeated failures)
  Future<int> autoHideSkills() async {
    final skills = getAllSkills();
    int hiddenCount = 0;
    for (final skill in skills) {
      if (!skill.hidden && skill.shouldAutoHide) {
        await hideSkill(skill.id);
        hiddenCount++;
      }
    }
    return hiddenCount;
  }

  /// Export skills to JSON string
  String exportSkills() {
    final skills = getAllSkills();
    return const JsonEncoder.withIndent('  ').convert(skills.map((s) => s.toJson()).toList());
  }

  /// Import skills from JSON string
  Future<int> importSkills(String jsonString, {bool overwrite = false}) async {
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      final imported = decoded.map((e) => Skill.fromJson(e as Map<String, Object?>)).toList();
      final existing = getAllSkills();
      int importedCount = 0;

      for (final skill in imported) {
        final existingIndex = existing.indexWhere((s) => s.id == skill.id);
        if (existingIndex >= 0) {
          if (overwrite) {
            existing[existingIndex] = skill;
            importedCount++;
          }
        } else {
          // Check for name conflict
          if (skillNameExists(skill.name)) {
            // Generate unique name
            var newName = skill.name;
            var counter = 2;
            while (skillNameExists(newName)) {
              newName = '${skill.name} ($counter)';
              counter++;
            }
            existing.add(skill.copyWith(name: newName));
          } else {
            existing.add(skill);
          }
          importedCount++;
        }
      }
      await saveAllSkills(existing);
      return importedCount;
    } catch (_) {
      return 0;
    }
  }

  List<Map<String, Object?>> _getHistory() {
    if (_prefs == null) return [];
    final jsonString = _prefs!.getString(_skillHistoryKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => e as Map<String, Object?>).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveHistory(List<Map<String, Object?>> history) async {
    if (_prefs == null) return;
    final jsonString = jsonEncode(history);
    await _prefs!.setString(_skillHistoryKey, jsonString);
  }

  Future<void> _cleanupHistory(String skillId) async {
    final history = _getHistory().where((e) => e['skillId'] != skillId).toList();
    await _saveHistory(history);
  }
}

/// Extension for firstWhereOrNull
extension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}