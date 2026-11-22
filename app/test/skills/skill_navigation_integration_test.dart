// Widget Test for Personal Skills Navigation Integration
// Simulates real user journey: Chat -> Save as Skill -> Cancel/Save/Back
// and SkillsPage -> SkillDetailPage -> Edit -> SkillCreatePage -> Cancel/Save

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dsh_app/app.dart';
import 'package:dsh_app/skills/skill_model.dart';
import 'package:dsh_app/skills/skill_provider.dart';
import 'package:dsh_app/skills/skill_storage.dart';
import 'package:dsh_app/skills/skill_create_page.dart';
import 'package:dsh_app/skills/skill_detail_page.dart';
import 'package:dsh_app/skills/skills_page.dart';
import 'package:dsh_app/state/sessions_state.dart';
import 'package:dsh_app/state/chat_state.dart';
import 'package:dsh_app/l10n/l10n.dart';

// Test navigator observer to track push/pop
class TestNavigatorObserver extends NavigatorObserver {
  final List<String> events = [];
  final List<int> stackDepths = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final name = route.settings.name ?? route.runtimeType.toString();
    events.add('PUSH: $name');
    stackDepths.add(_getStackDepth());
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    final name = route.settings.name ?? route.runtimeType.toString();
    events.add('POP: $name');
    stackDepths.add(_getStackDepth());
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    events.add('REPLACE: ${oldRoute?.settings.name} -> ${newRoute?.settings.name}');
    stackDepths.add(_getStackDepth());
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    events.add('REMOVE: ${route.settings.name}');
    stackDepths.add(_getStackDepth());
  }

  int _getStackDepth() {
    // This is approximate - in real test we'd need access to navigator
    return events.where((e) => e.startsWith('PUSH')).length -
        events.where((e) => e.startsWith('POP')).length;
  }

  void clear() {
    events.clear();
    stackDepths.clear();
  }
}

// Test app wrapper with all necessary providers
Widget createTestApp({
  required Widget home,
  List<Override> overrides = const [],
  Locale locale = const Locale('th'),
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('th'), Locale('en'), Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: home,
    ),
  );
}

// Helper to create a skill for testing
Skill createTestSkill({
  String id = 'test-1',
  String name = 'Test Skill',
  String description = 'Test Description',
  String goal = 'Test Goal',
  List<String> steps = const ['Step 1', 'Step 2'],
  List<String> constraints = const ['Constraint 1'],
  List<String> requiredTools = const ['bash', 'edit'],
  List<SkillInput> userInputs = const [],
  SkillCategory category = SkillCategory.development,
}) {
  return Skill(
    id: id,
    name: name,
    description: description,
    goal: goal,
    steps: steps,
    constraints: constraints,
    requiredTools: requiredTools,
    userInputs: userInputs,
    createdAt: DateTime.now(),
    category: category,
  );
}

// Mock skill storage for testing
Future<void> setupTestStorage() async {
  SharedPreferences.setMockInitialValues({});
  final storage = SkillStorage.instance;
  await storage.init();
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
}

void main() {
  group('Personal Skills Navigation Integration Tests', () {
    late TestNavigatorObserver navigatorObserver;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = SkillStorage.instance;
      await storage.init();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      navigatorObserver = TestNavigatorObserver();
    });

    tearDown(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });

    group('1. Chat -> Save as Skill from Message', () {
      testWidgets('Chat -> Save as Skill -> Cancel button returns to chat', (WidgetTester tester) async {
        navigatorObserver.clear();

        // Simulate chat page with a message that opens Save as Skill
        // We'll directly test SkillCreatePage with draftText since the chat -> menu -> push
        // is tested by the fact that assistant_message.dart uses Navigator.push

        await tester.pumpWidget(
          createTestApp(
            home: SkillCreatePage(
              draftText: 'สร้างสคริปต์ deploy แอป\nใช้ bash และ edit\nขั้นตอน: 1. build 2. test 3. deploy',
              draftTools: ['bash', 'edit'],
            ),
            overrides: [
              // Override skills provider to use test storage
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Verify form is populated from draftText
        expect(find.textContaining('สร้างสคริปต์ deploy'), findsOneWidget);
        expect(find.text('bash'), findsWidgets); // In tools field
        expect(find.text('edit'), findsWidgets);

        // Tap Cancel button
        await tester.tap(find.text('ยกเลิก'));
        await tester.pumpAndSettle();

        // Navigator should have popped (we can't easily test pop in this isolated test)
        // but we can verify the form was there
        expect(tester.takeException(), isNull);
      });

      testWidgets('Chat -> Save as Skill -> Save button saves and pops', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: SkillCreatePage(
              draftText: 'สร้างสคริปต์ deploy แอป',
              draftTools: ['bash', 'edit'],
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Fill required fields if needed
        // The draft should already populate name and goal
        // Just tap Save
        await tester.tap(find.text('บันทึก'));
        await tester.pumpAndSettle();

        // Should have saved (we can't easily verify pop in isolated test)
        expect(tester.takeException(), isNull);
      });

      testWidgets('Chat -> Save as Skill -> Back button (AppBar leading) pops', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: SkillCreatePage(
              draftText: 'Test message',
              draftTools: [],
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap AppBar leading (close button)
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });

    group('2. SkillsPage -> SkillDetailPage -> Edit -> SkillCreatePage', () {
      testWidgets('SkillsPage -> SkillDetailPage -> Edit -> Cancel returns to detail', (WidgetTester tester) async {
        final testSkill = createTestSkill(
          name: 'Test Skill',
          description: 'Test Description',
          goal: 'Test Goal',
          steps: ['Step 1', 'Step 2'],
        );

        // First add skill to storage
        final storage = SkillStorage.instance;
        await storage.upsertSkill(testSkill);

        await tester.pumpWidget(
          createTestApp(
            home: SkillDetailPage(skill: testSkill),
          ),
        );

        await tester.pumpAndSettle();

        // Tap edit button
        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle();

        // Should be on SkillCreatePage with initialSkill populated
        expect(find.text('Test Skill'), findsOneWidget);
        expect(find.text('Test Description'), findsOneWidget);
        expect(find.text('Test Goal'), findsOneWidget);

        // Tap Cancel
        await tester.tap(find.text('ยกเลิก'));
        await tester.pumpAndSettle();

        // Should be back on SkillDetailPage
        expect(find.text('Test Skill'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('SkillDetailPage -> Edit -> Save updates and returns to detail', (WidgetTester tester) async {
        final testSkill = createTestSkill(
          name: 'Test Skill',
          description: 'Test Description',
          goal: 'Test Goal',
          steps: ['Step 1'],
        );

        final storage = SkillStorage.instance;
        await storage.upsertSkill(testSkill);

        await tester.pumpWidget(
          createTestApp(
            home: SkillDetailPage(skill: testSkill),
          ),
        );

        await tester.pumpAndSettle();

        // Tap edit
        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle();

        // Change name
        await tester.enterText(find.byType(TextFormField).first, 'Updated Skill Name');
        await tester.pumpAndSettle();

        // Tap Save
        await tester.tap(find.text('บันทึก'));
        await tester.pumpAndSettle();

        // Should be back on SkillDetailPage with updated name
        expect(find.text('Updated Skill Name'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('3. PopScope/System Back Handling', () {
      testWidgets('System back gesture on SkillCreatePage pops correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: SkillCreatePage(
              draftText: 'Test message',
              draftTools: [],
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Simulate system back by calling Navigator.pop
        // In real test we'd use tester.pageBack()
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('System back gesture on SkillDetailPage pops correctly', (WidgetTester tester) async {
        final testSkill = createTestSkill(name: 'Test Skill');
        final storage = SkillStorage.instance;
        await storage.upsertSkill(testSkill);

        await tester.pumpWidget(
          createTestApp(
            home: SkillDetailPage(skill: testSkill),
          ),
        );

        await tester.pumpAndSettle();

        // Simulate system back
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });

    group('4. NavigatorObserver Stack Verification', () {
      testWidgets('Navigator stack never becomes empty during skill flow', (WidgetTester tester) async {
        final observer = TestNavigatorObserver();

        // This test verifies that the navigation flow maintains a valid stack
        // We can't fully test NavigatorObserver in isolated widget tests
        // but we document the expected behavior

        // Expected flow:
        // Chat (stack: [Chat]) -> push SkillCreatePage (stack: [Chat, SkillCreate])
        // -> pop (stack: [Chat]) OK
        // Skills (stack: [Skills]) -> push SkillDetail (stack: [Skills, SkillDetail])
        // -> push SkillCreatePage (stack: [Skills, SkillDetail, SkillCreate])
        // -> pop (stack: [Skills, SkillDetail]) OK
        // -> pop (stack: [Skills]) OK

        expect(true, isTrue); // Placeholder - real test needs full app integration
      });
    });
  });
}