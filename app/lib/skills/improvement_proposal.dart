// Improvement Proposal — auto-propose skill improvements based on run history
//
// Analyzes skill execution history and proposes improvements to parameters,
// steps, or error handling based on failure patterns.

import 'skill_history.dart' as skill_history;

/// Type of improvement proposal.
enum ImprovementType {
  /// Adjust parameter default values based on common usage.
  parameterDefault,
  /// Add a new step to handle a common failure scenario.
  addStep,
  /// Modify step arguments to avoid common errors.
  adjustArguments,
  /// Add error handling for a specific failure pattern.
  addErrorHandling,
  /// Remove unused or problematic step.
  removeStep,
  /// Change step mode (tool ↔ agent).
  changeStepMode,
}

/// Status of an improvement proposal.
enum ProposalStatus {
  pending,
  accepted,
  rejected,
  superseded,
}

/// An improvement proposal generated from run history analysis.
class ImprovementProposal {
  ImprovementProposal({
    required this.id,
    required this.skillId,
    required this.type,
    required this.description,
    required this.proposedChanges,
    required this.createdAt,
    required this.evidence,
    this.status = ProposalStatus.pending,
    this.appliedAt,
    this.resultingSkillVersion,
  });

  /// Unique proposal ID.
  final String id;

  /// Skill this proposal applies to.
  final String skillId;

  /// Type of improvement.
  final ImprovementType type;

  /// Human-readable description.
  final String description;

  /// Proposed changes as a JSON-serializable map.
  final Map<String, dynamic> proposedChanges;

  /// When this proposal was created.
  final DateTime createdAt;

  /// Evidence from run history supporting this proposal.
  final List<String> evidence;

  /// Current status.
  ProposalStatus status;

  /// When the proposal was accepted/rejected.
  DateTime? appliedAt;

  /// Skill version after applying this proposal.
  int? resultingSkillVersion;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'skillId': skillId,
      'type': type.name,
      'description': description,
      'proposedChanges': proposedChanges,
      'createdAt': createdAt.toIso8601String(),
      'evidence': evidence,
      'status': status.name,
      'appliedAt': appliedAt?.toIso8601String(),
      'resultingSkillVersion': resultingSkillVersion,
    };
  }

  factory ImprovementProposal.fromJson(Map<String, Object?> json) {
    return ImprovementProposal(
      id: json['id'] as String,
      skillId: json['skillId'] as String,
      type: ImprovementType.values.byName(json['type'] as String),
      description: json['description'] as String,
      proposedChanges: json['proposedChanges'] as Map<String, dynamic>,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      evidence: (json['evidence'] as List?)?.cast<String>() ?? [],
      status: ProposalStatus.values.byName(json['status'] as String? ?? 'pending'),
      appliedAt: json['appliedAt'] != null
          ? DateTime.tryParse(json['appliedAt'] as String)
          : null,
      resultingSkillVersion: json['resultingSkillVersion'] as int?,
    );
  }

  ImprovementProposal copyWith({
    String? id,
    String? skillId,
    ImprovementType? type,
    String? description,
    Map<String, dynamic>? proposedChanges,
    DateTime? createdAt,
    List<String>? evidence,
    ProposalStatus? status,
    DateTime? appliedAt,
    int? resultingSkillVersion,
  }) {
    return ImprovementProposal(
      id: id ?? this.id,
      skillId: skillId ?? this.skillId,
      type: type ?? this.type,
      description: description ?? this.description,
      proposedChanges: proposedChanges ?? this.proposedChanges,
      createdAt: createdAt ?? this.createdAt,
      evidence: evidence ?? this.evidence,
      status: status ?? this.status,
      appliedAt: appliedAt ?? this.appliedAt,
      resultingSkillVersion: resultingSkillVersion ?? this.resultingSkillVersion,
    );
  }
}

/// Service for analyzing skill history and generating improvement proposals.
class ImprovementProposalEngine {
  ImprovementProposalEngine(this._history);

  final skill_history.SkillHistory _history;

  /// Analyze skill history and generate improvement proposals.
  Future<List<ImprovementProposal>> generateProposals(String skillId) async {
    final history = await _history.getHistory(skillId);
    if (history.isEmpty) return [];

    final proposals = <ImprovementProposal>[];

    // Analyze failure patterns
    final failures = history.where((r) => r.status == skill_history.SkillRunStatus.failed).toList();
    if (failures.isNotEmpty) {
      proposals.addAll(_analyzeFailures(skillId, failures));
    }

    // Analyze parameter usage patterns
    proposals.addAll(_analyzeParameterUsage(skillId, history));

    // Analyze step performance
    proposals.addAll(_analyzeStepPerformance(skillId, history));

    return proposals;
  }

  List<ImprovementProposal> _analyzeFailures(String skillId, List<skill_history.SkillRunRecord> failures) {
    final proposals = <ImprovementProposal>[];

    // Group failures by error type
    final errorGroups = <String, List<skill_history.SkillRunRecord>>{};
    for (final failure in failures) {
      final errorKey = failure.error ?? 'unknown';
      errorGroups.putIfAbsent(errorKey, () => []).add(failure);
    }

    for (final entry in errorGroups.entries) {
      final error = entry.key;
      final occurrences = entry.value;

      if (occurrences.length >= 3) {
        // Frequent error - propose error handling
        proposals.add(ImprovementProposal(
          id: _generateId(),
          skillId: skillId,
          type: ImprovementType.addErrorHandling,
          description: 'Add error handling for recurring error: $error',
          proposedChanges: {
            'type': 'addErrorHandling',
            'errorPattern': error,
            'suggestedAction': 'Add try-catch with fallback for this error type',
          },
          createdAt: DateTime.now(),
          evidence: occurrences.map((r) => r.id).toList(),
        ));
      }
    }

    return proposals;
  }

  List<ImprovementProposal> _analyzeParameterUsage(String skillId, List<skill_history.SkillRunRecord> history) {
    // TODO: Analyze which parameters are commonly overridden vs using defaults
    return [];
  }

  List<ImprovementProposal> _analyzeStepPerformance(String skillId, List<skill_history.SkillRunRecord> history) {
    // TODO: Analyze step duration, failure rates per step
    return [];
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
        (DateTime.now().microsecond % 1000).toRadixString(36);
  }
}