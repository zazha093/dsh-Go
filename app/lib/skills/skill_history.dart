// Skill History — audit log and run record storage
//
// Records skill execution history for audit trail, analytics, and improvement proposals.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'skill_model.dart';

/// Storage key for skill execution history.
const _skillHistoryKey = 'personal_skills_history_v1';

/// Maximum total history entries across all skills.
const _maxTotalHistoryEntries = 1000;

/// Record of a single skill execution.
class SkillRunRecord {
  const SkillRunRecord({
    required this.id,
    required this.skillId,
    required this.startedAt,
    this.endedAt,
    required this.status,
    this.output,
    this.error,
    this.duration,
    this.stepsCompleted = 0,
    this.totalSteps = 0,
    this.stepResults = const [],
    this.parametersUsed = const {},
    this.userId,
  });

  /// Unique record ID.
  final String id;

  /// Skill that was executed.
  final String skillId;

  /// When execution started.
  final DateTime startedAt;

  /// When execution ended (null if running).
  final DateTime? endedAt;

  /// Execution status.
  final SkillRunStatus status;

  /// Final output (if successful).
  final String? output;

  /// Error message (if failed).
  final String? error;

  /// Total execution duration.
  final Duration? duration;

  /// Number of steps completed.
  final int stepsCompleted;

  /// Total steps in skill.
  final int totalSteps;

  /// Per-step results.
  final List<SkillResult> stepResults;

  /// Parameters used for this execution.
  final Map<String, String> parametersUsed;

  /// User identifier (optional).
  final String? userId;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'skillId': skillId,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'status': status.name,
      'output': output,
      'error': error,
      'duration': duration?.inMilliseconds,
      'stepsCompleted': stepsCompleted,
      'totalSteps': totalSteps,
      'stepResults': stepResults.map((r) => r.toJson()).toList(),
      'parametersUsed': parametersUsed,
      'userId': userId,
    };
  }

  factory SkillRunRecord.fromJson(Map<String, Object?> json) {
    return SkillRunRecord(
      id: json['id'] as String,
      skillId: json['skillId'] as String,
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime.now(),
      endedAt: json['endedAt'] != null
          ? DateTime.tryParse(json['endedAt'] as String)
          : null,
      status: SkillRunStatus.values.byName(json['status'] as String? ?? 'pending'),
      output: json['output'] as String?,
      error: json['error'] as String?,
      duration: json['duration'] != null
          ? Duration(milliseconds: json['duration'] as int)
          : null,
      stepsCompleted: json['stepsCompleted'] as int? ?? 0,
      totalSteps: json['totalSteps'] as int? ?? 0,
      stepResults: (json['stepResults'] as List?)
              ?.map((e) => SkillResult.fromJson(e as Map<String, Object?>))
              .toList() ??
          [],
      parametersUsed: (json['parametersUsed'] as Map?)
              ?.map((k, v) => MapEntry(k as String, v as String)) ??
          {},
      userId: json['userId'] as String?,
    );
  }

  SkillRunRecord copyWith({
    String? id,
    String? skillId,
    DateTime? startedAt,
    DateTime? endedAt,
    SkillRunStatus? status,
    String? output,
    String? error,
    Duration? duration,
    int? stepsCompleted,
    int? totalSteps,
    List<SkillResult>? stepResults,
    Map<String, String>? parametersUsed,
    String? userId,
  }) {
    return SkillRunRecord(
      id: id ?? this.id,
      skillId: skillId ?? this.skillId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      output: output ?? this.output,
      error: error ?? this.error,
      duration: duration ?? this.duration,
      stepsCompleted: stepsCompleted ?? this.stepsCompleted,
      totalSteps: totalSteps ?? this.totalSteps,
      stepResults: stepResults ?? this.stepResults,
      parametersUsed: parametersUsed ?? this.parametersUsed,
      userId: userId ?? this.userId,
    );
  }
}

/// Status of a skill run.
enum SkillRunStatus {
  pending,
  running,
  waitingApproval,
  waitingInput,
  completed,
  failed,
  cancelled,
}

/// Local storage for skill execution history using SharedPreferences.
class SkillHistory {
  SkillHistory._();

  static final SkillHistory instance = SkillHistory._();

  SharedPreferences? _prefs;

  /// Initialize the history storage (call once at app startup).
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get a skill by ID.
  Skill? getSkill(String skillId) {
    // This would need to be implemented based on how skills are stored
    // For now, return null as skills are stored separately
    return null;
  }

  /// Upsert a skill (insert or update).
  Future<void> upsertSkill(Skill skill) async {
    // This would need to be implemented based on how skills are stored
    // For now, this is a placeholder
  }

  /// Record a skill execution start.
  Future<SkillRunRecord> recordStart({
    required String skillId,
    Map<String, String> parameters = const {},
    String? userId,
  }) async {
    if (_prefs == null) await init();

    final record = SkillRunRecord(
      id: _generateId(),
      skillId: skillId,
      startedAt: DateTime.now(),
      status: SkillRunStatus.running,
      parametersUsed: parameters,
      userId: userId,
    );

    _appendRecord(record);
    return record;
  }

  /// Update a skill execution record with progress/completion.
  Future<void> updateRecord(SkillRunRecord record) async {
    if (_prefs == null) await init();

    final records = _getAllRecords();
    final index = records.indexWhere((r) => r.id == record.id);
    if (index >= 0) {
      records[index] = record;
    } else {
      records.add(record);
    }
    _saveAllRecords(records);
  }

  /// Complete a skill execution (success/failure/cancelled).
  Future<void> completeRecord({
    required String recordId,
    required SkillRunStatus status,
    String? output,
    String? error,
    Duration? duration,
    int? stepsCompleted,
    int? totalSteps,
    List<SkillResult>? stepResults,
  }) async {
    if (_prefs == null) await init();

    final records = _getAllRecords();
    final index = records.indexWhere((r) => r.id == recordId);
    if (index >= 0) {
      final record = records[index];
      final updated = record.copyWith(
        status: status,
        endedAt: DateTime.now(),
        output: output,
        error: error,
        duration: duration,
        stepsCompleted: stepsCompleted ?? record.stepsCompleted,
        totalSteps: totalSteps ?? record.totalSteps,
        stepResults: stepResults ?? record.stepResults,
      );
      records[index] = updated;
      _saveAllRecords(records);
    }
  }

  /// Get execution history for a specific skill.
  Future<List<SkillRunRecord>> getHistory(String skillId) async {
    if (_prefs == null) await init();

    final records = _getAllRecords();
    return records
        .where((r) => r.skillId == skillId)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  /// Get all execution history across all skills.
  Future<List<SkillRunRecord>> getAllHistory() async {
    if (_prefs == null) await init();
    final records = _getAllRecords();
    records.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return records;
  }

  /// Get recent executions across all skills.
  Future<List<SkillRunRecord>> getRecentHistory({int limit = 50}) async {
    final history = await getAllHistory();
    return history.take(limit).toList();
  }

  /// Get execution statistics for a skill.
  Future<SkillExecutionStats> getStats(String skillId) async {
    final history = await getHistory(skillId);
    if (history.isEmpty) {
      return SkillExecutionStats(
        skillId: skillId,
        totalRuns: 0,
        successfulRuns: 0,
        failedRuns: 0,
        cancelledRuns: 0,
        avgDuration: Duration.zero,
        successRate: 0.0,
      );
    }

    final durations = history
        .where((r) => r.duration != null)
        .map((r) => r.duration!.inMilliseconds)
        .toList();
    final avgDuration = durations.isEmpty
        ? Duration.zero
        : Duration(milliseconds: (durations.reduce((a, b) => a + b) / durations.length).round());

    return SkillExecutionStats(
      skillId: skillId,
      totalRuns: history.length,
      successfulRuns: history.where((r) => r.status == SkillRunStatus.completed).length,
      failedRuns: history.where((r) => r.status == SkillRunStatus.failed).length,
      cancelledRuns: history.where((r) => r.status == SkillRunStatus.cancelled).length,
      avgDuration: avgDuration,
      successRate: history.isEmpty ? 0.0 : history.where((r) => r.status == SkillRunStatus.completed).length / history.length,
    );
  }

  /// Clean up old history entries beyond the limit.
  Future<void> pruneOldEntries() async {
    if (_prefs == null) await init();

    final records = _getAllRecords();
    if (records.length <= _maxTotalHistoryEntries) return;

    records.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final pruned = records.take(_maxTotalHistoryEntries).toList();
    _saveAllRecords(pruned);
  }

  /// Export history to JSON string.
  String exportHistory() {
    // This would need async, so use a separate method
    throw UnimplementedError('Use exportHistoryAsync instead');
  }

  Future<String> exportHistoryAsync() async {
    final records = _getAllRecords();
    return const JsonEncoder.withIndent('  ')
        .convert(records.map((r) => r.toJson()).toList());
  }

  /// Import history from JSON string.
  Future<int> importHistory(String jsonString, {bool overwrite = false}) async {
    if (_prefs == null) await init();

    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      final imported = decoded.map((e) => SkillRunRecord.fromJson(e as Map<String, Object?>)).toList();

      final existing = _getAllRecords();
      final existingIds = existing.map((r) => r.id).toSet();

      int importedCount = 0;
      for (final record in imported) {
        if (existingIds.contains(record.id)) {
          if (overwrite) {
            final index = _getAllRecords().indexWhere((r) => r.id == record.id);
            if (index >= 0) {
              final records = _getAllRecords();
              records[index] = record;
              importedCount++;
            }
          }
        } else {
          if (!existingIds.contains(record.id)) {
            existing.add(record);
            importedCount++;
          }
        }
      }

      _saveAllRecords(_getAllRecords());
      await pruneOldEntries();

      return importedCount;
    } catch (_) {
      return 0;
    }
  }

  List<SkillRunRecord> _getAllRecords() {
    if (_prefs == null) return [];
    final jsonString = _prefs!.getString(_skillHistoryKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => SkillRunRecord.fromJson(e as Map<String, Object?>)).toList();
    } catch (_) {
      return [];
    }
  }

  void _saveAllRecords(List<SkillRunRecord> records) {
    if (_prefs == null) return;
    final jsonString = jsonEncode(records.map((r) => r.toJson()).toList());
    _prefs!.setString(_skillHistoryKey, jsonString);
  }

  void _appendRecord(SkillRunRecord record) {
    final records = _getAllRecords();
    records.add(record);
    _saveAllRecords(records);
    pruneOldEntries();
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
        (DateTime.now().microsecond % 1000).toRadixString(36);
  }

  /// Public wrapper for getting all records.
  List<SkillRunRecord> getAllRecords() => _getAllRecords();

  /// Public wrapper for saving all records.
  void saveAllRecords(List<SkillRunRecord> records) => _saveAllRecords(records);
}

/// Statistics for skill execution.
class SkillExecutionStats {
  const SkillExecutionStats({
    required this.skillId,
    required this.totalRuns,
    required this.successfulRuns,
    required this.failedRuns,
    required this.cancelledRuns,
    required this.avgDuration,
    required this.successRate,
  });

  final String skillId;
  final int totalRuns;
  final int successfulRuns;
  final int failedRuns;
  final int cancelledRuns;
  final Duration avgDuration;
  final double successRate;

  Map<String, Object?> toJson() {
    return {
      'skillId': skillId,
      'totalRuns': totalRuns,
      'successfulRuns': successfulRuns,
      'failedRuns': failedRuns,
      'cancelledRuns': cancelledRuns,
      'avgDurationMs': avgDuration.inMilliseconds,
      'successRate': successRate,
    };
  }
}