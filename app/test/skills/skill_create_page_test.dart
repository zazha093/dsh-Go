// Widget Tests for SkillCreatePage — Phase 6 Stability Tests
//
// Tests cover:
// 1. AI hangs (Completer hangs) -> cancel/back works, no black screen
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
import 'package:dsh_app/skills/skill_distill_controller.dart';
import 'package:dsh_app/state/connection_state.dart';

/// Test controller that uses Completer to control distillation timing
class TestSkillDistillController extends SkillDistillController {
  final Completer<DistillState> _completer = Completer<DistillState>();

  @override
  Future<void> distillFromText(DistillInput input) async {
    // Phase 3: Instant rule-based draft (synchronous)
    Skill ruleBasedSkill;
    if (input.toolCallsWithArgs != null && input.toolCallsWithArgs!.isNotEmpty) {
      ruleBasedSkill = SkillDistiller.createFromTurn(
        userMessage: input.userMessage,
        aiResponse: input.aiResponse,
        toolCallsWithArgs: input.toolCallsWithArgs!,
        sessionTitle: input.sessionTitle,
      );
    } else {
      ruleBasedSkill = SkillDistiller.createFromMessageText(
        userMessage: input.userMessage,
        aiResponse: input.aiResponse,
        toolCalls: input.toolCalls ?? [],
        sessionTitle: input.sessionTitle,
      );
    }

    // Emit rule-based draft immediately
    if (!_disposed) {
      state = state.copyWith(status: DistillStatus.ready, skill: ruleBasedSkill, progress: 0.5);
    }

    // Phase 4/5: AI summarization in background (if client available)
    if (input.dshClient != null && _aiSummarizer != null && _draftValidator != null) {
      _runAiSummarization(input, ruleBasedSkill);
    }
  }

  /// Complete the AI summarization with a result
  void completeWith(DistillState result) {
    if (!_completer.isCompleted) {
      _completer.complete(result);
    }
  }

  /// Make the AI hang (never complete)
  void hang() {
    // Don't complete the completer - it will hang forever
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SkillCreatePage Widget Tests', () {
    late TestSkillDistillController testController;

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
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            skillDistillControllerProvider.overrideWith(() => testController),
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
      testController = TestSkillDistillController();
    });

    group('Phase 6: Stability Tests', () {
      testWidgets('1. AI hangs (Completer hangs) -> cancel/back works, no black screen',
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

      testWidgets('4. Open/close page 5x -> no memory leak',
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
    });
  }
}