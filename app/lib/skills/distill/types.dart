// Shared types for skill distillation

import 'package:dsh_client/dsh_client.dart';

/// State for the distillation process
@immutable
class DistillState {
  const DistillState({
    this.status = DistillStatus.idle,
    this.skill,
    this.aiProposedSkill,
    this.error,
    this.progress = 0.0,
  });

  final DistillStatus status;
  final Skill? skill;              // Rule-based draft (instant)
  final Skill? aiProposedSkill;    // AI-validated proposal (async)
  final String? error;
  final double progress;

  DistillState copyWith({
    DistillStatus? status,
    Skill? skill,
    Skill? aiProposedSkill,
    String? error,
    double? progress,
  }) {
    return DistillState(
      status: status ?? this.status,
      skill: skill ?? this.skill,
      aiProposedSkill: aiProposedSkill ?? this.aiProposedSkill,
      error: error ?? this.error,
      progress: progress ?? this.progress,
    );
  }
}

enum DistillStatus { idle, running, ready, failed, cancelled }

/// Input for distillation
@immutable
class DistillInput {
  const DistillInput({
    required this.userMessage,
    this.aiResponse,
    this.toolCalls,
    this.toolCallsWithArgs,
    required this.sessionTitle,
    this.dshClient, // Optional: for AI summarization
  });

  final String userMessage;
  final String? aiResponse;
  final List<String>? toolCalls;
  final List<ToolCallInfo>? toolCallsWithArgs;
  final String sessionTitle;
  final DshClient? dshClient;
}