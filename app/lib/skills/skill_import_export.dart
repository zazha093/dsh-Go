// Skill Import/Export — JSON serialization and deserialization for skill portability
//
// Supports exporting skills to JSON files and importing them back,
// with full v2 schema support including provenance, executable steps,
// parameters, and error handling.

import 'dart:convert';
import 'dart:io';

import 'skill_model.dart';
import 'skill_history.dart';

/// Service for exporting and importing skills to/from JSON.
class SkillImportExport {
  final SkillHistory _history;

  SkillImportExport(this._history);

  /// Export a single skill to a JSON file.
  Future<void> exportSkillToFile(String skillId, File file) async {
    final history = SkillHistory.instance;
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
    final history = SkillHistory.instance;
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

    final jsonString = const JsonEncoder.withIndent('  ').convert({
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'skills': skills,
    });
    await file.writeAsString(jsonString);
  }

  /// Export all skills to a JSON file.
  Future<void> exportAllSkillsToFile(File file) async {
    final history = SkillHistory.instance;
    await history.init();

    final allSkills = history.getAllHistory();
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
    final history = SkillHistory.instance;
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
        final skill = Skill.fromJson(skillData as Map<String, dynamic>);
        await _importSkill(skill, overwrite: overwrite);
        importedCount++;
      } catch (e) {
        // Log error but continue with other skills
        print('Failed to import skill: $e');
      }
    }

    return importedCount;
  }

  Future<void> _importSkill(Skill skill, {bool overwrite = false}) async {
    final history = SkillHistory.instance;
    final existing = history.getSkill(skill.id);

    if (existing != null && !overwrite) {
      throw StateError('Skill with id ${skill.id} already exists. Use overwrite=true to replace.');
    }

    if (overwrite && existing != null) {
      // Preserve history but update skill
      await SkillHistory.instance.updateRecord(SkillRunRecord(
        id: 'import-${DateTime.now().millisecondsSinceEpoch}',
        skillId: skill.id,
        startedAt: DateTime.now(),
        status: SkillRunStatus.completed,
        output: 'Imported skill v${skill.version}',
        duration: Duration.zero,
      ));
    }

    await SkillHistory.instance.upsertSkill(skill);
  }

  /// Export skill execution history for a specific skill.
  Future<void> exportSkillHistoryToFile(String skillId, File file) async {
    final history = SkillHistory.instance;
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
    final history = SkillHistory.instance;
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
        final record = SkillRunRecord.fromJson(recordData as Map<String, dynamic>);
        await _importHistoryRecord(record, overwrite: overwrite);
        importedCount++;
      } catch (e) {
        print('Failed to import history record: $e');
      }
    }

    return importedCount;
  }

  Future<void> _importHistoryRecord(SkillRunRecord record, {bool overwrite = false}) async {
    final history = SkillHistory.instance;
    final existing = history.getSkill(record.skillId);

    if (existing == null) {
      // Skill doesn't exist, create a minimal skill record
      // This is a best-effort import for history without full skill definition
      return;
    }

    if (overwrite) {
      final existingRecords = _getAllRecords();
      final index = _getAllRecords().indexWhere((r) => r.id == record.id);
      if (index >= 0) {
        final records = _getAllRecords();
        records[index] = record;
      } else {
        _getAllRecords().add(record);
      }
      _saveAllRecords(_getAllRecords());
    } else {
      final existingRecords = _getAllRecords();
      if (!existingRecords.any((r) => r.id == record.id)) {
        _getAllRecords().add(record);
        _saveAllRecords(_getAllRecords());
      }
    }
  }

  List<SkillRunRecord> _getAllRecords() {
    // Access SkillHistory private method via reflection or add public method
    // For now, return empty list - would need SkillHistory to expose this
    return [];
  }

  void _saveAllRecords(List<SkillRunRecord> records) {
    // Would need SkillHistory to expose this
  }
}