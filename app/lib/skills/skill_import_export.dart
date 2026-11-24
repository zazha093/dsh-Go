// Skill Import/Export — JSON serialization and deserialization for skill portability
//
// Supports exporting skills to JSON files and importing them back,
// with full v2 schema support including provenance, executable steps,
// parameters, and error handling.

import 'dart:convert';
import 'dart:io';

import 'skill_model.dart' as skill_model;
import 'skill_history.dart' as skill_history;

/// Service for exporting and importing skills to/from JSON.
class SkillImportExport {
  SkillImportExport();

  /// Export a single skill to a JSON file.
  Future<void> exportSkillToFile(String skillId, File file) async {
    final history = skill_history.SkillHistory.instance;
    await history.init();

    final record = history.getSkill(skillId);
    if (record == null) {
      throw ArgumentError('Skill not found: $skillId');
    }

    // Build export object with full v2 schema
    final exportData = {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'skill': record.toJson(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    await file.writeAsString(jsonString);
  }

  /// Export multiple skills to a JSON file.
  Future<void> exportSkillsToFile(List<String> skillIds, File file) async {
    final history = skill_history.SkillHistory.instance;
    await history.init();

    final skills = <Map<String, Object?>>[];
    for (final id in skillIds) {
      final record = history.getSkill(id);
      if (record != null) {
        skills.add(record.toJson());
      }
    }

    final exportData = {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'skills': skills,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    await file.writeAsString(jsonString);
  }

  /// Export all skills to a JSON file.
  Future<void> exportAllSkillsToFile(File file) async {
    final history = skill_history.SkillHistory.instance;
    await history.init();

    final allSkills = await history.getAllHistory();
    final skills = allSkills.map((r) => r.toJson()).toList();

    final exportData = {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'skills': skills,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    await file.writeAsString(jsonString);
  }

  /// Import skills from a JSON file.
  ///
  /// Returns the number of skills successfully imported.
  Future<int> importSkillsFromFile(File file, {bool overwrite = false}) async {
    final history = skill_history.SkillHistory.instance;
    await history.init();

    final jsonString = await file.readAsString();
    final Map<String, dynamic> data = jsonDecode(jsonString);

    // Validate version
    final version = data['version'] as int?;
    if (version != 2) {
      throw FormatException('Unsupported export version: $version. Expected version 2.');
    }

    final skillsData = data['skills'] as List<dynamic>? ?? [];
    int importedCount = 0;

    for (final skillData in skillsData) {
      try {
        final skill = skill_model.Skill.fromJson(skillData as Map<String, dynamic>);
        await _importSkill(skill, overwrite: overwrite);
        importedCount++;
      } catch (e) {
        // Log error but continue with other skills
        // ignore: avoid_print
        print('Failed to import skill: $e');
      }
    }

    return importedCount;
  }

  Future<void> _importSkill(skill_model.Skill skill, {bool overwrite = false}) async {
    final history = skill_history.SkillHistory.instance;
    final existing = history.getSkill(skill.id);

    if (existing != null && !overwrite) {
      throw StateError('Skill with id ${skill.id} already exists. Use overwrite=true to replace.');
    }

    if (overwrite && existing != null) {
      // Preserve history but update skill
      await skill_history.SkillHistory.instance.updateRecord(skill_history.SkillRunRecord(
        id: 'import-${DateTime.now().millisecondsSinceEpoch}',
        skillId: skill.id,
        startedAt: DateTime.now(),
        status: skill_history.SkillRunStatus.completed,
        output: 'Imported skill v${skill.version}',
        duration: Duration.zero,
      ));
    }

    await skill_history.SkillHistory.instance.upsertSkill(skill);
  }

  /// Export skill execution history for a specific skill.
  Future<void> exportSkillHistoryToFile(String skillId, File file) async {
    final history = skill_history.SkillHistory.instance;
    await history.init();

    final records = await history.getHistory(skillId);
    final exportData = {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'skillId': skillId,
      'records': records.map((r) => r.toJson()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    await file.writeAsString(jsonString);
  }

  /// Import skill execution history from a JSON file.
  Future<int> importSkillHistoryFromFile(File file, {bool overwrite = false}) async {
    final history = skill_history.SkillHistory.instance;
    await history.init();

    final jsonString = await file.readAsString();
    final Map<String, dynamic> data = jsonDecode(jsonString);

    // Validate version
    final version = data['version'] as int?;
    if (version != 2) {
      throw FormatException('Unsupported export version: $version. Expected version 2.');
    }

    final recordsData = data['records'] as List<dynamic>? ?? [];
    int importedCount = 0;

    for (final recordData in recordsData) {
      try {
        final record = skill_history.SkillRunRecord.fromJson(recordData as Map<String, dynamic>);
        await _importHistoryRecord(record, overwrite: overwrite);
        importedCount++;
      } catch (e) {
        // ignore: avoid_print
        print('Failed to import history record: $e');
      }
    }

    return importedCount;
  }

  Future<void> _importHistoryRecord(skill_history.SkillRunRecord record, {bool overwrite = false}) async {
    final history = skill_history.SkillHistory.instance;
    final existing = history.getSkill(record.skillId);

    if (existing == null) {
      // Skill doesn't exist, create a minimal skill record
      // This is a best-effort import for history without full skill definition
      return;
    }

    if (overwrite) {
      final existingRecords = history.getAllRecords();
      final index = existingRecords.indexWhere((r) => r.id == record.id);
      if (index >= 0) {
        existingRecords[index] = record;
      } else {
        existingRecords.add(record);
      }
      history.saveAllRecords(existingRecords);
    } else {
      final existingRecords = history.getAllRecords();
      if (!existingRecords.any((r) => r.id == record.id)) {
        existingRecords.add(record);
        history.saveAllRecords(existingRecords);
      }
    }
  }
}