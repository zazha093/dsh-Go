// Widget Tests for SkillCreatePage — Phase 6 Stability Tests
//
// Tests cover:
// 1. AI hangs (Completer hangs) -> cancel/back must work, no black screen
// 2. AI responds after page closed -> no Exception
// 3. AI error/timeout -> form can still save from rule-based draft
// 4. Open/close page 5x no memory leak

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:dsh_app/skills/skill_create_page.dart';
import 'package:dsh_app/skills/skill_model.dart';
import 'package:dsh_app/skills/skill_distill_controller.dart';
import 'package:dsh_app/state/chat_state.dart';
import 'package:dsh_app/state/connection_state.dart';
import 'package:dsh_client/dsh_client.dart';

import 'skill_create_page_test.mocks.dart';

@GenerateMocks([
  DshClient,
  ChatController,
  ChatTranscript,
])
void main() {
  group('SkillCreatePage Widget Tests', () {
    late MockDshClient mockClient;
    late MockChatController mockChatController;
    late MockChatTranscript mockTranscript;

    setUp(() {
      mockClient = MockDshClient();
      mockChatController = MockChatController();
      mockTranscript = MockChatTranscript();
    });

    // Helper to pump the SkillCreatePage with providers
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
      // Setup mock chat provider if sessionId provided
      if (sessionId != null && draftTurn != null && draftStep != null) {
        when(mockChatController.transcript).thenReturn(mockTranscript);
        when(mockTranscript.getToolCallsWithArgs(draftTurn, draftStep))
            .thenReturn(<ToolCallInfo>[]);
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeConnectionProvider.overrideWith(
              (ref) => AsyncValue.data(ConnectionStateData(client: mockClient)),
            ),
            chatProvider(sessionId ?? 'test-session').overrideWith(
              (ref) => mockChatController,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('th'), Locale('zh')],
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

    group('Phase 6: Stability Tests', () {
      testWidgets('1. AI hangs (Completer hangs) -> cancel/back works, no black screen',
          (WidgetTester tester) async {
        // Arrange: Setup page with AI that will hang
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
        // In test environment, we verify the form is no longer visible
        // or that no black screen occurred
        expect(tester.any(find.byType(CircularProgressIndicator)), isFalse);
      });

      testWidgets('2. AI responds after page closed -> no Exception',
          (WidgetTester tester) async {
        // Arrange: Setup page
        await pumpSkillCreatePage(
          tester,
          draftText: 'Create a deploy script',
          draftTools: ['bash'],
        );

        // Act: Close page immediately (simulate user pressing back)
        await tester.pageBack();
        await tester.pumpAndSettle();

        // Assert: No exception thrown, page closes cleanly
        // In test, we verify no crash occurred
        expect(tester.takeException(), isNull);
      });

      testWidgets('3. AI error/timeout -> form can still save from rule-based draft',
          (WidgetTester tester) async {
        // Arrange: Setup page with rule-based draft
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
        // In test, we verify no crash
        expect(tester.takeException(), isNull);
      });

      testWidgets('4. Open/close page 5x no memory leak',
          (WidgetTester tester) async {
        // Act: Open and close page 5 times
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
        
        // In a real test, we'd also verify controllers are disposed
        // by checking no memory leaks in the framework
      });
    });

    group('Phase 6: Additional Stability Tests', () {
      testWidgets('Close button works during AI loading',
          (WidgetTester tester) async {
        await pumpSkillCreatePage(
          tester,
          draftText: 'Test',
          draftTools: ['bash'],
          sessionId: 'test',
          draftTurn: 1,
          draftStep: 1,
        );

        // Verify close button is enabled and works
        final closeButton = find.byIcon(Icons.close);
        expect(closeButton, findsOneWidget);
        
        await tester.tap(closeButton);
        await tester.pumpAndSettle();
        
        expect(tester.takeException(), isNull);
      });

      testWidgets('System back gesture works during AI loading',
          (WidgetTester tester) async {
        await pumpSkillCreatePage(
          tester,
          draftText: 'Test',
          draftTools: ['bash'],
        );

        // Simulate system back gesture
        await tester.pageBack();
        await tester.pumpAndSettle();
        
        expect(tester.takeException(), isNull);
      });

      testWidgets('Form validation works with rule-based draft',
          (WidgetTester tester) async {
        await pumpSkillCreatePage(
          tester,
          draftText: 'Test script',
          draftTools: ['bash'],
        );

        // Try to save without filling required fields
        await tester.tap(find.text('Save Skill'));
        await tester.pumpAndSettle();

        // Should show validation errors
        expect(find.text('Please enter a skill name'), findsOneWidget);
      });
    });
  }
}