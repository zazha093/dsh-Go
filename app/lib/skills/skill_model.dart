// Personal Skills feature — local-only, distilled from completed sessions
// No cloud, no accounts, no sync. Stored in SharedPreferences on device.

/// A personal skill distilled from a completed session.
///
/// Skills are formulas for one task: they know the goal, the method, the
/// constraints, what tools they need, and what the user must provide.
/// They are created from successful sessions and can be invoked later.
class Skill {
  const Skill({
    required this.id,
    required this.name,
    required this.description,
    required this.goal,
    required this.steps,
    required this.constraints,
    required this.requiredTools,
    required this.userInputs,
    required this.createdAt,
    this.updatedAt,
    this.lastUsedAt,
    this.useCount = 0,
    this.successCount = 0,
    this.category = SkillCategory.other,
    this.hidden = false,
    this.hiddenAt,
    this.sourceSessionId,
    this.sourceSessionTitle,
    this.version = 1,
    this.requiredPersona,
    this.lastRunStatus = SkillRunStatus.never,
    // v2 fields
    this.kind = 'workflow',
    this.schemaVersion = 2,
    this.provenance,
    this.executableSteps,
    this.parameters,
    this.errorHandling,
  });

  /// Unique identifier (UUID v4)
  final String id;

  /// User-facing name (e.g., "Daily Briefing", "Code Review")
  final String name;

  /// One-sentence description of what this skill does
  final String description;

  /// The objective this skill achieves
  final String goal;

  /// Step-by-step instructions
  final List<String> steps;

  /// What the skill must not do
  final List<String> constraints;

  /// Tools this skill needs (e.g., ["bash", "edit", "web_fetch"])
  final List<String> requiredTools;

  /// What the user must provide when running this skill
  final List<SkillInput> userInputs;

  /// When this skill was created
  final DateTime createdAt;

  /// When this skill was last updated (null if never)
  final DateTime? updatedAt;

  /// When this skill was last used (null if never)
  final DateTime? lastUsedAt;

  /// Total number of times this skill has been invoked
  final int useCount;

  /// Number of successful invocations
  final int successCount;

  /// Category for filtering
  final SkillCategory category;

  /// Whether this skill is hidden (auto-hidden after 14 days no use or repeated failures)
  final bool hidden;

  /// When this skill was hidden (null if not hidden)
  final DateTime? hiddenAt;

  /// The session ID this skill was distilled from (for traceability)
  final String? sourceSessionId;

  /// The session title this skill was distilled from
  final String? sourceSessionTitle;

  /// Version of the formula (increments on user-confirmed updates)
  final int version;

  /// Optional persona required to run this skill (e.g., "code reviewer", "devops engineer")
  final String? requiredPersona;

  /// Status of the last run
  final SkillRunStatus lastRunStatus;

  // ===== V2 FIELDS =====
  /// Skill kind: 'knowledge' | 'workflow' | 'executable'
  final String kind;

  /// Schema version (2 for v2)
  final int schemaVersion;

  /// Provenance information (how this skill was created)
  final SkillProvenance? provenance;

  /// Executable steps with tool bindings (only for executable kind)
  final List<SkillStep>? executableSteps;

  /// Parameters for parameterized execution (only for executable kind)
  final List<SkillParameter>? parameters;

  /// Error handling configuration (only for executable kind)
  final SkillErrorHandling? errorHandling;

  /// Success rate as percentage (0-100)
  int get successRate => useCount == 0 ? 0 : ((successCount / useCount) * 100).round();

  /// Whether this skill should be auto-hidden (14 days no use OR 3+ consecutive failures)
  bool get shouldAutoHide {
    if (hidden) return false;
    final now = DateTime.now();
    // 14 days of no use
    if (lastUsedAt == null) {
      if (now.difference(createdAt).inDays >= 14) return true;
    } else if (now.difference(lastUsedAt!).inDays >= 14) {
      return true;
    }
    // 3+ consecutive failures (useCount - successCount >= 3 and last 3 were failures)
    if (useCount >= 3 && successCount == 0) return true;
    return false;
  }

  /// Create a copy with updated fields
  Skill copyWith({
    String? id,
    String? name,
    String? description,
    String? goal,
    List<String>? steps,
    List<String>? constraints,
    List<String>? requiredTools,
    List<SkillInput>? userInputs,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
    int? useCount,
    int? successCount,
    SkillCategory? category,
    bool? hidden,
    DateTime? hiddenAt,
    String? sourceSessionId,
    String? sourceSessionTitle,
    int? version,
    String? requiredPersona,
    SkillRunStatus? lastRunStatus,
    // v2 fields
    String? kind,
    int? schemaVersion,
    SkillProvenance? provenance,
    List<SkillStep>? executableSteps,
    List<SkillParameter>? parameters,
    SkillErrorHandling? errorHandling,
  }) {
    return Skill(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      goal: goal ?? this.goal,
      steps: steps ?? this.steps,
      constraints: constraints ?? this.constraints,
      requiredTools: requiredTools ?? this.requiredTools,
      userInputs: userInputs ?? this.userInputs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      useCount: useCount ?? this.useCount,
      successCount: successCount ?? this.successCount,
      category: category ?? this.category,
      hidden: hidden ?? this.hidden,
      hiddenAt: hiddenAt ?? this.hiddenAt,
      sourceSessionId: sourceSessionId ?? this.sourceSessionId,
      sourceSessionTitle: sourceSessionTitle ?? this.sourceSessionTitle,
      version: version ?? this.version,
      requiredPersona: requiredPersona ?? this.requiredPersona,
      lastRunStatus: lastRunStatus ?? this.lastRunStatus,
      // v2 fields
      kind: kind ?? this.kind,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      provenance: provenance ?? this.provenance,
      executableSteps: executableSteps ?? this.executableSteps,
      parameters: parameters ?? this.parameters,
      errorHandling: errorHandling ?? this.errorHandling,
    );
  }

  /// Serialize to JSON for storage
  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'goal': goal,
      'steps': steps,
      'constraints': constraints,
      'requiredTools': requiredTools,
      'userInputs': userInputs.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'lastUsedAt': lastUsedAt?.toIso8601String(),
      'useCount': useCount,
      'successCount': successCount,
      'category': category.name,
      'hidden': hidden,
      'hiddenAt': hiddenAt?.toIso8601String(),
      'sourceSessionId': sourceSessionId,
      'sourceSessionTitle': sourceSessionTitle,
      'version': version,
      'requiredPersona': requiredPersona,
      'lastRunStatus': lastRunStatus.name,
      // v2 fields
      'kind': kind,
      'schemaVersion': schemaVersion,
      'provenance': provenance?.toJson(),
      'executableSteps': executableSteps?.map((e) => e.toJson()).toList(),
      'parameters': parameters?.map((e) => e.toJson()).toList(),
      'errorHandling': errorHandling?.toJson(),
    };
  }

  /// Deserialize from JSON
  factory Skill.fromJson(Map<String, Object?> json) {
    // Handle legacy data gracefully - use safe casting with defaults
    final rawRequiredPersona = json['requiredPersona'];
    final rawLastRunStatus = json['lastRunStatus'];
    // v2 fields with defaults for backward compatibility
    final rawKind = json['kind'];
    final rawSchemaVersion = json['schemaVersion'];
    final rawProvenance = json['provenance'];
    final rawExecutableSteps = json['executableSteps'];
    final rawParameters = json['parameters'];
    final rawErrorHandling = json['errorHandling'];
    
    return Skill(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      goal: json['goal'] as String,
      steps: (json['steps'] as List?)?.cast<String>() ?? [],
      constraints: (json['constraints'] as List?)?.cast<String>() ?? [],
      requiredTools: (json['requiredTools'] as List?)?.cast<String>() ?? [],
      userInputs: (json['userInputs'] as List?)
          ?.map((e) => SkillInput.fromJson(e as Map<String, Object?>))
          .toList() ?? [],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.tryParse(json['lastUsedAt'] as String)
          : null,
      useCount: json['useCount'] as int? ?? 0,
      successCount: json['successCount'] as int? ?? 0,
      category: SkillCategory.values.byName(json['category'] as String? ?? 'other'),
      hidden: json['hidden'] as bool? ?? false,
      hiddenAt: json['hiddenAt'] != null
          ? DateTime.tryParse(json['hiddenAt'] as String)
          : null,
      sourceSessionId: json['sourceSessionId'] as String?,
      sourceSessionTitle: json['sourceSessionTitle'] as String?,
      version: json['version'] as int? ?? 1,
      requiredPersona: rawRequiredPersona as String?,
      lastRunStatus: rawLastRunStatus != null
          ? SkillRunStatus.values.byName(rawLastRunStatus as String)
          : SkillRunStatus.never,
      // v2 fields with defaults for v1 compatibility
      kind: rawKind as String? ?? 'workflow',
      schemaVersion: rawSchemaVersion as int? ?? 2,
      provenance: rawProvenance != null
          ? SkillProvenance.fromJson(rawProvenance as Map<String, Object?>)
          : null,
      executableSteps: rawExecutableSteps != null
          ? (rawExecutableSteps as List)
              .map((e) => SkillStep.fromJson(e as Map<String, Object?>))
              .toList()
          : null,
      parameters: rawParameters != null
          ? (rawParameters as List)
              .map((e) => SkillParameter.fromJson(e as Map<String, Object?>))
              .toList()
          : null,
      errorHandling: rawErrorHandling != null
          ? SkillErrorHandling.fromJson(rawErrorHandling as Map<String, Object?>)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Skill && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Skill(id: $id, name: $name, version: $version)';
}

/// Status of the last skill run
enum SkillRunStatus {
  never,
  success,
  failure,
  running,
}

/// An input that the user must provide when running a skill.
class SkillInput {
  const SkillInput({
    required this.key,
    required this.label,
    required this.hint,
    this.type = SkillInputType.text,
    this.required = true,
    this.defaultValue,
    this.options,
  });

  /// Unique key for this input (used in the formula)
  final String key;

  /// User-facing label
  final String label;

  /// Hint/placeholder text
  final String hint;

  /// Type of input
  final SkillInputType type;

  /// Whether this input is required
  final bool required;

  /// Default value (optional)
  final String? defaultValue;

  /// Options for select type (optional)
  final List<String>? options;

  Map<String, Object?> toJson() {
    return {
      'key': key,
      'label': label,
      'hint': hint,
      'type': type.name,
      'required': required,
      'defaultValue': defaultValue,
      'options': options,
    };
  }

  factory SkillInput.fromJson(Map<String, Object?> json) {
    return SkillInput(
      key: json['key'] as String,
      label: json['label'] as String,
      hint: json['hint'] as String,
      type: SkillInputType.values.byName(json['type'] as String),
      required: json['required'] as bool,
      defaultValue: json['defaultValue'] as String?,
      options: json['options'] != null
          ? (json['options'] as List).cast<String>()
          : null,
    );
  }
}

/// Type of skill input
enum SkillInputType {
  text,
  number,
  select,
  boolean,
  multiline,
}

/// Category for skill filtering
enum SkillCategory {
  productivity,
  development,
  automation,
  analysis,
  other,
}

/// Skill invocation result
class SkillResult {
  const SkillResult({
    required this.success,
    this.output,
    this.error,
    this.duration,
    this.stepsCompleted = 0,
    this.totalSteps = 0,
  });

  final bool success;
  final String? output;
  final String? error;
  final Duration? duration;
  final int stepsCompleted;
  final int totalSteps;

  factory SkillResult.success({
    String? output,
    Duration? duration,
    int stepsCompleted = 0,
    int totalSteps = 0,
  }) {
    return SkillResult(
      success: true,
      output: output,
      duration: duration,
      stepsCompleted: stepsCompleted,
      totalSteps: totalSteps,
    );
  }

  factory SkillResult.failure({
    required String error,
    Duration? duration,
    int stepsCompleted = 0,
    int totalSteps = 0,
  }) {
    return SkillResult(
      success: false,
      error: error,
      duration: duration,
      stepsCompleted: stepsCompleted,
      totalSteps: totalSteps,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'success': success,
      'output': output,
      'error': error,
      'duration': duration?.inMilliseconds,
      'stepsCompleted': stepsCompleted,
      'totalSteps': totalSteps,
    };
  }

  factory SkillResult.fromJson(Map<String, Object?> json) {
    return SkillResult(
      success: json['success'] as bool,
      output: json['output'] as String?,
      error: json['error'] as String?,
      duration: json['duration'] != null
          ? Duration(milliseconds: json['duration'] as int)
          : null,
      stepsCompleted: json['stepsCompleted'] as int? ?? 0,
      totalSteps: json['totalSteps'] as int? ?? 0,
    );
  }
}

/// ===== V2 CLASSES =====

/// Provenance information — how this skill was created
class SkillProvenance {
  const SkillProvenance({
    required this.type,
    this.sourceSessionId,
    this.sourceMessageId,
    required this.createdAt,
    this.evidence = const {},
  });

  /// 'manual' | 'distilled' | 'migrated' | 'imported'
  final String type;

  /// Session this skill was distilled from
  final String? sourceSessionId;

  /// Specific message in the session
  final String? sourceMessageId;

  /// When this skill was created
  final DateTime createdAt;

  /// Evidence markers: observed vs inferred
  final Map<String, dynamic> evidence;

  Map<String, Object?> toJson() {
    return {
      'type': type,
      'sourceSessionId': sourceSessionId,
      'sourceMessageId': sourceMessageId,
      'createdAt': createdAt.toIso8601String(),
      'evidence': evidence,
    };
  }

  factory SkillProvenance.fromJson(Map<String, Object?> json) {
    return SkillProvenance(
      type: json['type'] as String,
      sourceSessionId: json['sourceSessionId'] as String?,
      sourceMessageId: json['sourceMessageId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      evidence: json['evidence'] as Map<String, dynamic>? ?? {},
    );
  }

  static SkillProvenance migrated(String originalId) => SkillProvenance(
    type: 'migrated',
    sourceSessionId: originalId,
    createdAt: DateTime.now(),
    evidence: {'migratedFrom': originalId},
  );

  static SkillProvenance distilled(String sessionId, String messageId) => SkillProvenance(
    type: 'distilled',
    sourceSessionId: sessionId,
    sourceMessageId: messageId,
    createdAt: DateTime.now(),
    evidence: {'distilledFrom': {'session': sessionId, 'message': messageId}},
  );

  static SkillProvenance manual() => SkillProvenance(
    type: 'manual',
    createdAt: DateTime.now(),
    evidence: {},
  );

  static SkillProvenance imported(String sourceId) => SkillProvenance(
    type: 'imported',
    sourceSessionId: sourceId,
    createdAt: DateTime.now(),
    evidence: {'importedFrom': sourceId},
  );

  SkillProvenance copyWith({
    String? type,
    String? sourceSessionId,
    String? sourceMessageId,
    DateTime? createdAt,
    Map<String, dynamic>? evidence,
  }) {
    return SkillProvenance(
      type: type ?? this.type,
      sourceSessionId: sourceSessionId ?? this.sourceSessionId,
      sourceMessageId: sourceMessageId ?? this.sourceMessageId,
      createdAt: createdAt ?? this.createdAt,
      evidence: evidence ?? this.evidence,
    );
  }
}

/// Error handling configuration for executable skills
class SkillErrorHandling {
  const SkillErrorHandling({
    this.onError = 'stop',
    this.maxRetries = 0,
    this.retryDelay = const Duration(seconds: 5),
    this.retryableErrors = const [],
  });

  /// 'stop' | 'continue' | 'retry'
  final String onError;

  final int maxRetries;

  final Duration retryDelay;

  /// List of error patterns that are retryable
  final List<String> retryableErrors;

  Map<String, Object?> toJson() {
    return {
      'onError': onError,
      'maxRetries': maxRetries,
      'retryDelay': retryDelay.inMilliseconds,
      'retryableErrors': retryableErrors,
    };
  }

  factory SkillErrorHandling.fromJson(Map<String, Object?> json) {
    return SkillErrorHandling(
      onError: json['onError'] as String? ?? 'stop',
      maxRetries: json['maxRetries'] as int? ?? 0,
      retryDelay: Duration(milliseconds: json['retryDelay'] as int? ?? 5000),
      retryableErrors: (json['retryableErrors'] as List?)?.cast<String>() ?? [],
    );
  }

  SkillErrorHandling copyWith({
    String? onError,
    int? maxRetries,
    Duration? retryDelay,
    List<String>? retryableErrors,
  }) {
    return SkillErrorHandling(
      onError: onError ?? this.onError,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelay: retryDelay ?? this.retryDelay,
      retryableErrors: retryableErrors ?? this.retryableErrors,
    );
  }
}

/// A single executable step with tool binding
class SkillStep {
  const SkillStep({
    required this.id,
    required this.description,
    required this.mode,
    this.tool,
    this.args = const {},
    this.order = 0,
  });

  /// Unique step ID
  final String id;

  /// Human-readable description
  final String description;

  /// 'tool' | 'agent'
  final String mode;

  /// Tool name for tool mode (e.g., 'bash', 'edit', 'web_fetch')
  final String? tool;

  /// Arguments with ${param} placeholders
  final Map<String, dynamic> args;

  /// Execution order
  final int order;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'description': description,
      'mode': mode,
      'tool': tool,
      'args': args,
      'order': order,
    };
  }

  factory SkillStep.fromJson(Map<String, Object?> json) {
    return SkillStep(
      id: json['id'] as String,
      description: json['description'] as String,
      mode: json['mode'] as String? ?? 'tool',
      tool: json['tool'] as String?,
      args: json['args'] as Map<String, dynamic>? ?? {},
      order: json['order'] as int? ?? 0,
    );
  }

  SkillStep copyWith({
    String? id,
    String? description,
    String? mode,
    String? tool,
    Map<String, dynamic>? args,
    int? order,
  }) {
    return SkillStep(
      id: id ?? this.id,
      description: description ?? this.description,
      mode: mode ?? this.mode,
      tool: tool ?? this.tool,
      args: args ?? this.args,
      order: order ?? this.order,
    );
  }
}

/// Parameter definition for executable skills
class SkillParameter {
  const SkillParameter({
    required this.key,
    required this.label,
    required this.type,
    this.required = true,
    this.defaultValue,
    this.options,
    this.bindToStep,
    this.bindToTool,
    this.template,
  });

  /// Parameter key (used in ${param} placeholders)
  final String key;

  /// User-facing label
  final String label;

  /// 'text' | 'number' | 'select' | 'boolean' | 'multiline'
  final String type;

  /// Whether this parameter is required
  final bool required;

  /// Default value
  final String? defaultValue;

  /// Options for select type
  final List<String>? options;

  /// Step ID this parameter binds to
  final String? bindToStep;

  /// Tool name this parameter binds to
  final String? bindToTool;

  /// Template string with ${param} placeholders
  final String? template;

  Map<String, Object?> toJson() {
    return {
      'key': key,
      'label': label,
      'type': type,
      'required': required,
      'defaultValue': defaultValue,
      'options': options,
      'bindToStep': bindToStep,
      'bindToTool': bindToTool,
      'template': template,
    };
  }

  factory SkillParameter.fromJson(Map<String, Object?> json) {
    return SkillParameter(
      key: json['key'] as String,
      label: json['label'] as String,
      type: json['type'] as String? ?? 'text',
      required: json['required'] as bool? ?? true,
      defaultValue: json['defaultValue'] as String?,
      options: json['options'] != null
          ? (json['options'] as List).cast<String>()
          : null,
      bindToStep: json['bindToStep'] as String?,
      bindToTool: json['bindToTool'] as String?,
      template: json['template'] as String?,
    );
  }

  SkillParameter copyWith({
    String? key,
    String? label,
    String? type,
    bool? required,
    String? defaultValue,
    List<String>? options,
    String? bindToStep,
    String? bindToTool,
    String? template,
  }) {
    return SkillParameter(
      key: key ?? this.key,
      label: label ?? this.label,
      type: type ?? this.type,
      required: required ?? this.required,
      defaultValue: defaultValue ?? this.defaultValue,
      options: options ?? this.options,
      bindToStep: bindToStep ?? this.bindToStep,
      bindToTool: bindToTool ?? this.bindToTool,
      template: template ?? this.template,
    );
  }
}

/// Migration helper: v1 skill → v2 skill (in-memory, used by storage)
extension SkillMigration on Skill {
  Skill migrateToV2() => copyWith(
    kind: 'workflow',
    schemaVersion: 2,
    provenance: SkillProvenance.migrated(id),
    executableSteps: null,
    parameters: null,
    errorHandling: null,
  );
}