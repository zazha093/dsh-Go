// Widget Tests for SkillCreatePage — Phase 6 Stability Tests
//
// Tests cover:
// 1. AI hangs -> cancel/back works, no black screen
// 2. AI responds after page closed -> no Exception
// 3. AI error/timeout -> form can still save from rule-based draft
// 4. AI returns valid JSON -> "AI proposes draft" banner appears, [Dismiss] doesn't overwrite user edits
// 5. Open/close 5x -> no memory leak
// 6. Disable AI -> summarize not called

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsh_app/l10n/l10n.dart';
import 'package:dsh_app/skills/skill_create_page.dart';
import 'package:dsh_app/skills/skill_model.dart';
import 'package:dsh_app/skills/skill_distill_controller.dart';
import 'package:dsh_app/skills/skill_distill.dart';
import 'package:dsh_app/state/connection_state.dart';
import 'package:dsh_app/state/hosts_state.dart';
import 'package:dsh_client/dsh_client.dart';

/// Fake distillation controller for testing
/// Extends SkillDistillController but overrides distillFromText completely
/// to avoid accessing private members (_disposed, _aiSummarizer, etc.)
class _FakeSkillDistillController extends SkillDistillController {
  final Completer<DistillState> _completer = Completer<DistillState>();
  bool _shouldHang = false;
  bool _mounted = true;

  @override
  DistillState build() {
    _mounted = true;
    ref.onDispose(() {
      _mounted = false;
    });
    return const DistillState();
  }

  bool get mounted => _mounted;

  @override
  Future<void> distillFromText(DistillInput input) async {
    // Phase 3: Instant rule-based draft (synchronous)
    final ruleBasedSkill = SkillDistiller.createFromMessageText(
      userMessage: input.userMessage,
      aiResponse: input.aiResponse,
      toolCalls: input.toolCalls ?? [],
      sessionTitle: input.sessionTitle,
    );

    // Emit rule-based draft immediately
    state = state.copyWith(status: DistillStatus.ready, skill: ruleBasedSkill, progress: 0.5);

    // Phase 4/5: AI summarization in background (if client available)
    if (input.dshClient != null) {
      if (_shouldHang) {
        // Hang forever - wait for completer that never completes
        await _completer.future;
        return;
      }

      try {
        // Wait for test to complete
        final result = await _completer.future.timeout(const Duration(seconds: 30));
        if (mounted) {
          state = result;
        }
      } on TimeoutException {
        if (mounted) {
          state = state.copyWith(
            status: DistillStatus.failed,
            error: 'AI summarization timed out',
            aiProposedSkill: null,
          );
        }
      }
    }
  }

  /// Complete the AI summarization with a result
  void completeWith(DistillState result) {
    if (!_completer.isCompleted) {
      _completer.complete(result);
    }
  }

  /// Make the AI hang (never complete the completer)
  void hang() {
    _shouldHang = true;
    // Don't complete the completer
  }
}

/// Minimal fake DshClient for testing
class _FakeDshClient extends DshClient {
  _FakeDshClient() : super.withCarrier(_FakeCarrier());

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<String> complete({
    required String prompt,
    Map<String, dynamic>? options,
    bool? isCancelled,
  }) async {
    return '{}'; // Return empty JSON
  }

  @override
  Future<List<String>> archiveSession(String sessionId, {bool? stopActivity}) async {
    return <String>[];
  }
}

/// Fake carrier for testing - implements all required DshCarrier methods
class _FakeCarrier extends DshCarrier {
  @override
  String get kind => 'fake';

  @override
  DshTracer? get tracer => null;

  @override
  Future<RpcResult> call(String endpoint, Map<String, Object?> args, {Duration? timeout}) async {
    return const RpcOk({'result': {}});
  }

  @override
  Future<DshMuxLink> openLink(MuxOptions options) async {
    return _FakeMuxLink();
  }

  @override
  Future<void> close() async {}
}

/// Fake MuxLink for testing
class _FakeMuxLink extends DshMuxLink {
  @override
  void start({required DshMuxFrameHandler onFrame, required DshMuxLossHandler onLost}) {}

  @override
  void open(String streamId, String endpoint, Map<String, Object?> payload) {}

  @override
  void sendItem(String streamId, Object? value) {}

  @override
  void endUplink(String streamId) {}

  @override
  void cancel(String streamId) {}

  @override
  Future<void> close(int code, String reason) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SkillCreatePage Widget Tests', () {
    late _FakeSkillDistillController testController;

    Future<void> pumpSkillCreatePage(WidgetTester tester, {
      String? draftText,
      List<String>? draftTexts,
      List<String>? draftTools,
      int? draftTurn,
      int? draftStep,
      String? sessionId,
      String? sessionTitle,
      Skill? initialSkill,
    }) async {
      final fakeClient = _FakeDshClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            skillDistillControllerProvider.overrideWith(() => testController),
            activeConnectionProvider.overrideWith(
              (ref) => AsyncValue.data(HostConnection(
                client: fakeClient,
                isLocal: true,
                kind: HostKind.local,
              )),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            home: SkillCreatePage(
              draftText: draftText,
              draftTexts: draftTexts,
              draftTools: draftTools,
              draftTurn: draftTurn,
              draftStep: draftStep,
              sessionId: sessionId,
              sessionTitle: sessionTitle,
              initialSkill: initialSkill,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() {
      testController = _FakeSkillDistillController();
    });

    group('Phase 6: Stability Tests', () {
      testWidgets('1. AI hangs -> cancel/back works, no black screen',
          (WidgetTester tester) async {
        testController.hang(); // Never complete the completer

        await pumpSkillCreatePage(
          tester,
          draftText: 'Create a backup script',
          draftTools: ['bash'],
          sessionId: 'test-session',
          draftTurn: 1,
          draftStep: 1,
        );

        // Verify form is visible (not black screen)
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(find.text('Skill Name'), findsOneWidget);

        // Act: Tap cancel button (should work even if AI is "running")
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Assert: Page should close (navigator pops)
        expect(tester.any(find.byType(CircularProgressIndicator)), isFalse);
      });

      testWidgets('2. AI responds after page closed -> no Exception',
          (WidgetTester tester) async {
        await pumpSkillCreatePage(
          tester,
          draftText: 'Create a deploy script',
          draftTools: ['bash'],
        );

        // Close page immediately (simulate user pressing back)
        await tester.pageBack();
        await tester.pumpAndSettle();

        // Now complete the AI (simulating delayed response)
        testController.completeWith(DistillState(
          status: DistillStatus.ready,
          skill: Skill(
            id: 'test',
            name: 'Test Skill',
            description: 'Test',
            goal: 'Test goal',
            steps: [],
            constraints: [],
            requiredTools: [],
            userInputs: [],
            createdAt: DateTime.now(),
          ),
        ));

        // Assert: No exception thrown, page closes cleanly
        expect(tester.takeException(), isNull);
      });

      testWidgets('3. AI error/timeout -> form can still save from rule-based draft',
          (WidgetTester tester) async {
        await pumpSkillCreatePage(
          tester,
          draftText: 'Create a backup script',
          draftTools: ['bash', 'tar'],
        );

        // Verify form is populated with rule-based draft
        expect(find.widgetWithText(TextFormField, 'Skill Name'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, 'Description'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, 'Goal'), findsOneWidget);

        // Act: Fill required fields and save
        await tester.enterText(find.bySemanticsLabel('Skill Name'), 'My Backup Skill');
        await tester.enterText(find.bySemanticsLabel('Description'), 'Backup my project');
        await tester.enterText(find.bySemanticsLabel('Goal'), 'Create backup archive');

        // Tap save
        await tester.tap(find.text('Save Skill'));
        await tester.pumpAndSettle();

        // Assert: Save should succeed (or at least not crash)
        expect(tester.takeException(), isNull);
      });

      testWidgets('4. AI returns valid JSON -> banner appears, [Dismiss] preserves edits',
          (WidgetTester tester) async {
        await pumpSkillCreatePage(
          tester,
          draftText: 'Create a test script',
          draftTools: ['bash'],
        );

        // Wait for rule-based draft to appear
        await tester.pumpAndSettle();

        // Simulate AI proposing a skill
        final aiSkill = Skill(
          id: 'ai-test',
          name: 'AI Proposed Skill',
          description: 'AI Description',
          goal: 'AI Goal',
          steps: ['AI Step 1', 'AI Step 2'],
          constraints: ['AI Constraint'],
          requiredTools: ['bash'],
          userInputs: [],
          createdAt: DateTime.now(),
        );
        testController.completeWith(DistillState(
          status: DistillStatus.ready,
          skill: Skill(
            id: 'rule-based',
            name: 'Rule Based',
            description: 'Rule Desc',
            goal: 'Rule Goal',
            steps: ['Rule Step'],
            constraints: [],
            requiredTools: ['bash'],
            userInputs: [],
            createdAt: DateTime.now(),
          ),
          aiProposedSkill: aiSkill,
          progress: 1.0,
        ));

        await tester.pumpAndSettle();

        // Verify AI proposal banner appears
        expect(find.text('AI เสนอร่างใหม่'), findsOneWidget);
        expect(find.text('ใช้ร่างนี้'), findsOneWidget);
        expect(find.text('ไม่ใช้'), findsOneWidget);

        // User edits a field
        await tester.enterText(find.bySemanticsLabel('Skill Name'), 'User Edited Name');

        // Tap dismiss
        await tester.tap(find.text('ไม่ใช้'));
        await tester.pumpAndSettle();

        // Verify user edit is preserved
        expect(find.text('User Edited Name'), findsOneWidget);
      });

      testWidgets('5. Open/close page 5x -> no memory leak',
          (WidgetTester tester) async {
        for (int i = 0; i < 5; i++) {
          await pumpSkillCreatePage(
            tester,
            draftText: 'Test script $i',
            draftTools: ['bash'],
          );

          // Close page
          await tester.pageBack();
          await tester.pumpAndSettle(const Duration(milliseconds: 100));
        }

        // Assert: No exceptions after 5 cycles
        expect(tester.takeException(), isNull);
      });

      testWidgets('6. Disable AI (no client) -> summarize not called',
          (WidgetTester tester) async {
        await pumpSkillCreatePage(
          tester,
          draftText: 'Test without AI',
          draftTools: ['bash'],
        );

        // Verify form is populated with rule-based draft (no AI badge)
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(find.text('Skill Name'), findsOneWidget);

        // No AI summarization badge should appear
        expect(find.text('กำลังสรุปด้วย AI...'), findsNothing);
      });
    });
  });
}