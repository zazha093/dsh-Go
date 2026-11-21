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
    };
  }

  /// Deserialize from JSON
  factory Skill.fromJson(Map<String, Object?> json) {
    return Skill(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      goal: json['goal'] as String,
      steps: (json['steps'] as List).cast<String>(),
      constraints: (json['constraints'] as List).cast<String>(),
      requiredTools: (json['requiredTools'] as List).cast<String>(),
      userInputs: (json['userInputs'] as List)
          .map((e) => SkillInput.fromJson(e as Map<String, Object?>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String)
          : null,
      useCount: json['useCount'] as int,
      successCount: json['successCount'] as int,
      category: SkillCategory.values.byName(json['category'] as String),
      hidden: json['hidden'] as bool,
      hiddenAt: json['hiddenAt'] != null
          ? DateTime.parse(json['hiddenAt'] as String)
          : null,
      sourceSessionId: json['sourceSessionId'] as String?,
      sourceSessionTitle: json['sourceSessionTitle'] as String?,
      version: json['version'] as int,
      requiredPersona: json['requiredPersona'] as String?,
      lastRunStatus: json['lastRunStatus'] != null
          ? SkillRunStatus.values.byName(json['lastRunStatus'] as String)
          : SkillRunStatus.never,
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
}