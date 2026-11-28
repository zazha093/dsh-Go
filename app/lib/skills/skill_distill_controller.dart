// Skill Distillation Controller — manages AI summarization with cancellation and safety

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsh_client/dsh_client.dart';

import 'distill/types.dart';
import 'skill_distill.dart';
import 'skill_model.dart';
import '../fork/ai_summarizer.dart';
import '../fork/draft_validator.dart';

/// Simple cancellation token for in-flight operations
class CancelToken {
  final Completer<void> _completer = Completer<void>();
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (!_cancelled) {
      _cancelled = true;
      _completer.complete();
    }
  }

  Future<void> get future => _completer.future;

  void throwIfCancelled() {
    if (_cancelled) {
      throw CancelledException('Operation cancelled');
    }
  }
}

/// Exception thrown when operation is cancelled
class CancelledException implements Exception {
  final String message;
  const CancelledException(this.message);
  
  @override
  String toString() => 'CancelledException: $message';
}

/// Controller for skill distillation with AI summarization support
class SkillDistillController extends AutoDisposeNotifier<DistillState> {
  // Cancellation token for in-flight AI requests
  CancelToken? _cancelToken;
  
  // Track if controller is disposed
  bool _isDisposed = false;

  @override
  DistillState build() {
    // Listen for disposal
    ref.onDispose(() {
      _isDisposed = true;
      _cancelToken?.cancel();
      _cancelToken = null;
    });

    return const DistillState();
  }

  /// Start distillation from text (message or turn-based)
  /// Returns the rule-based draft instantly, then runs AI summarization in background
  Future<void> distillFromText(DistillInput input) async {
    // Cancel any in-flight request
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    // Check if already disposed before starting
    if (_isDisposed) return;

    // 1. Generate rule-based draft INSTANTLY (synchronous)
    final ruleBasedSkill = _generateRuleBasedDraft(input);
    
    // Check disposed/mounted before state update
    if (_isDisposed) return;
    state = state.copyWith(
      status: DistillStatus.running,
      skill: ruleBasedSkill,
      aiProposedSkill: null,
      error: null,
      progress: 0.1,
    );

    // 2. If no DshClient, skip AI and mark as ready with rule-based only
    if (input.dshClient == null) {
      if (_isDisposed) return;
      state = state.copyWith(
        status: DistillStatus.ready,
        progress: 1.0,
      );
      return;
    }

    // 3. Run AI summarization with timeout and cancellation
    try {
      if (_isDisposed) return;
      state = state.copyWith(progress: 0.3);

      final aiSummarizer = AiSummarizer(
        client: input.dshClient!,
        config: AiSummarizerConfig(
          locale: _detectLocale(input.userMessage),
        ),
      );

      final result = await aiSummarizer.summarize(
        userMessage: input.userMessage,
        aiResponse: input.aiResponse,
        toolCallsWithArgs: input.toolCallsWithArgs ?? [],
        sessionTitle: input.sessionTitle,
      ).timeout(const Duration(seconds: 25), onTimeout: () {
        throw TimeoutException('AI summarization timed out');
      });
      
      // Check cancelled after await
      if (_cancelToken!.isCancelled || _isDisposed) return;

      // 4. Validate AI result field-by-field with rule-based fallback
      final validator = DraftValidator(locale: _detectLocale(input.userMessage));
      final validatedSkill = validator.validate(result.skill, ruleBasedSkill);
      
      if (_isDisposed) return;
      state = state.copyWith(
        status: DistillStatus.ready,
        aiProposedSkill: validatedSkill,
        progress: 1.0,
      );
    } on CancelledException {
      // User cancelled - silent discard
      if (_isDisposed) return;
      state = state.copyWith(
        status: DistillStatus.cancelled,
        aiProposedSkill: null,
        progress: 0.0,
      );
    } on TimeoutException {
      // AI timeout - keep rule-based, mark as ready
      if (_isDisposed) return;
      state = state.copyWith(
        status: DistillStatus.ready,
        aiProposedSkill: null,
        error: 'AI summarization timed out, using rule-based draft',
        progress: 1.0,
      );
    } catch (e) {
      // Other errors - keep rule-based, mark as ready with error
      if (_isDisposed) return;
      state = state.copyWith(
        status: DistillStatus.ready,
        aiProposedSkill: null,
        error: 'AI summarization failed: $e',
        progress: 1.0,
      );
    }
  }

  /// Generate rule-based draft synchronously (instant)
  Skill _generateRuleBasedDraft(DistillInput input) {
    if (input.toolCallsWithArgs != null && input.toolCallsWithArgs!.isNotEmpty) {
      return SkillDistiller.createFromTurn(
        userMessage: input.userMessage,
        aiResponse: input.aiResponse,
        toolCallsWithArgs: input.toolCallsWithArgs!,
        sessionTitle: input.sessionTitle,
      );
    } else {
      return SkillDistiller.createFromMessageText(
        userMessage: input.userMessage,
        aiResponse: input.aiResponse,
        toolCalls: input.toolCalls,
        sessionTitle: input.sessionTitle,
      );
    }
  }

  /// Detect locale from text (simple heuristic)
  String _detectLocale(String text) {
    final thaiRegex = RegExp(r'[\u0E00-\u0E7F]');
    final chineseRegex = RegExp(r'[\u4e00-\u9fff]');
    
    int thaiCount = thaiRegex.allMatches(text).length;
    int chineseCount = chineseRegex.allMatches(text).length;
    int total = text.length;
    
    if (thaiCount > total * 0.1) return 'th';
    if (chineseCount > total * 0.1) return 'zh';
    return 'en';
  }

  /// Cancel any in-flight distillation
  void cancel() {
    _cancelToken?.cancel();
    _cancelToken = null;
    
    if (!_isDisposed) {
      state = state.copyWith(
        status: DistillStatus.cancelled,
        aiProposedSkill: null,
        progress: 0.0,
      );
    }
  }
}

/// Provider for the distillation controller
final skillDistillControllerProvider = NotifierProvider.autoDispose<SkillDistillController, DistillState>(
  SkillDistillController.new,
);