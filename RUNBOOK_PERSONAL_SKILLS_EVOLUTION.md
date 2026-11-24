# RUNBOOK: Personal Skills Evolution — Complete Reference

**Project:** dsh-Go (Flutter Android App)
**Branch:** `feat/fix-skill-crash`
**Created:** 2026-11-23
**Status:** Planning Phase — Ready for Phase 1A

---

## 🎯 OVERALL GOAL

Evolve Personal Skills from simple text-based workflows into a structured, executable skill system with:
- **3 Skill Types:** Knowledge / Workflow / Executable
- **Safe Migration:** v1 → v2 with backup/rollback
- **Execution Engine:** Tool execution via DshClient Agent prompt (proven via PoC)
- **Incremental Delivery:** 6 Stages with Gates, each independently verifiable

---

## 📐 ARCHITECTURE DECISIONS (Finalized)

### Skill Types (Kind)
| Kind | Purpose | Required Fields | Runnable |
|------|---------|-----------------|----------|
| `knowledge` | Reference, best practices, rules | goal, description, constraints | ❌ No |
| `workflow` | Human-guided steps with context | steps (text), userInputs, requiredTools | ✅ Human follows |
| `executable` | Structured, tool-bound, validated | executableSteps, parameters, errorHandling | ✅ Engine runs |

### Migration Strategy
- **v1 skills → kind: 'workflow'** (NOT executable — they're text instructions)
- **New Key:** `personal_skills_v2`
- **Backup Key:** `personal_skills_backup_v1` (created BEFORE migration)
- **Rollback:** Only guaranteed DURING migration (backup exists)
- **After Success:** Backup deleted → v2 authoritative

### Execution Model
- **No Direct Tool RPC** in DshClient — tools invoked via Agent prompt
- **Default Context:** New session per skill run (`createSession(cwd)`)
- **PoC Required:** Stage 4 must prove real tool call → result → approval → cancellation

### Step Model (MVP)
```dart
enum StepMode { tool, agent }  // Only these two for MVP
class SkillStep {
  final String id;
  final String description;
  final StepMode mode;
  final String? tool;           // 'bash', 'edit', 'web_fetch'
  final Map<String, dynamic> args;  // With ${param} placeholders
  final int order;
}
```

---

## 🚀 PHASE BREAKDOWN

### STAGE 1: Foundation (5 Sub-stages, Sequential Gates)

#### **PHASE 1A: Model + Serialization** ⏳ READY TO START

**Goal:** Add v2 fields to Skill model, ensure serialization round-trip, v1→v2 migration logic in-memory

**Files to Modify:**
1. `app/lib/skills/skill_model.dart` — Core changes
2. `app/test/skills/skill_model_test.dart` — NEW FILE

**Detailed Changes — skill_model.dart:**
```dart
// ADD to Skill class:
final String kind;                    // 'knowledge' | 'workflow' | 'executable'
final int schemaVersion;              // 2
final SkillProvenance provenance;

// ADD new classes:
class SkillProvenance {
  final String type;                  // 'manual' | 'distilled' | 'migrated' | 'imported'
  final String? sourceSessionId;
  final String? sourceMessageId;
  final DateTime createdAt;
  final Map<String, dynamic> evidence; // observed vs inferred markers
  
  static SkillProvenance migrated(String originalId) => ...
  static SkillProvenance distilled(String sessionId, String messageId) => ...
  static SkillProvenance manual() => ...
}

class SkillErrorHandling {
  final String onError;               // 'stop' | 'continue' | 'retry'
  final int maxRetries;
  final Duration retryDelay;
  final List<String> retryableErrors;
}

// UPDATE fromJson/toJson:
// - kind defaults to 'workflow' for backward compat
// - schemaVersion = 2
// - provenance required
// - executableSteps, parameters, errorHandling nullable (only for executable kind)

// ADD migration helper (in-memory, used by storage):
static Skill migrateV1toV2(Skill v1) => v1.copyWith(
  kind: 'workflow',
  schemaVersion: 2,
  provenance: SkillProvenance.migrated(v1.id),
  executableSteps: null,
  parameters: null,
  errorHandling: null,
);
```

**Detailed Changes — skill_model_test.dart (NEW):**
```dart
group('Skill v2 Serialization', () {
  test('v2 round-trip preserves all fields', () { ... });
  test('v1 JSON → v2 object → v2 JSON (migration)', () { ... });
  test('kind validation: only 3 allowed values', () { ... });
  test('executableSkills require executableSteps', () { ... });
  test('workflowSkills allow null executableSteps', () { ... });
  test('knowledgeSkills allow null steps', () { ... });
  test('provenance types serialize correctly', () { ... });
  test('SkillErrorHandling serialization', () { ... });
});
```

**Commands to Run:**
```bash
cd /root/workspace/dsh-Go
dart test app/test/skills/skill_model_test.dart
dart analyze --no-fatal-infos
```

**Gate 1A Criteria:**
- [ ] All unit tests pass
- [ ] `dart analyze` clean on skill_model.dart and test
- [ ] No new warnings/errors

---

#### **PHASE 1B: Storage + Migration + Backup/Recovery**

**Goal:** Persistent storage v2, staged migration with backup, rollback during migration

**Files to Modify:**
1. `app/lib/skills/skill_storage.dart` — Storage logic
2. `app/test/skills/skill_storage_test.dart` — NEW FILE

**Storage Keys:**
```dart
const _v1 = 'personal_skills_v1';
const _v2 = 'personal_skills_v2';
const _backup = 'personal_skills_backup_v1';
```

**Migration Logic (skill_storage.dart):**
```dart
Future<List<Skill>> loadSkills() async {
  final prefs = await SharedPreferences.getInstance();
  
  // 1. v2 exists → load v2
  if (prefs.containsKey(_v2)) {
    return decodeV2(prefs.getString(_v2)!);
  }
  
  // 2. v1 exists → BEGIN MIGRATION
  if (prefs.containsKey(_v1)) {
    final v1Json = prefs.getString(_v1)!;
    final v1Skills = decodeV1(v1Json);
    
    // BACKUP FIRST (critical)
    await prefs.setString(_backup, v1Json);
    
    // Migrate in memory
    final v2Skills = v1Skills.map(Skill.migrateV1toV2).toList();
    
    // Write v2
    await prefs.setString(_v2, jsonEncode(v2Skills.map(v2ToJson).toList()));
    
    // SUCCESS: Remove backup
    await prefs.remove(_backup);
    return v2Skills;
  }
  return [];
}

// saveAllSkills writes to _v2 only
Future<void> saveAllSkills(List<Skill> skills) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_v2, jsonEncode(skills.map(v2ToJson).toList()));
}
```

**Recovery Logic:**
| Scenario | Data Present | Action |
|----------|--------------|--------|
| App killed during migration | `_backup` exists, `_v2` missing | Restore `_backup` → `_v1` on next load |
| Migration complete, v2 corrupt | `_v2` corrupt, `_backup` gone | **Data loss** — load empty (documented) |
| User downgrades app | `_v1` may exist | Load `_v1` if present |
| Fresh install | No keys | Empty |

**Tests (skill_storage_test.dart):**
```dart
group('SkillStorage v2', () {
  test('loadSkills: v2 key exists → returns v2 skills', () { ... });
  test('loadSkills: v1 only → migrates, writes v2, removes backup', () { ... });
  test('loadSkills: migration interrupted → backup restores v1', () { 
    // Simulate: write backup, kill before v2 write, next load restores
  });
  test('saveAllSkills: writes v2, readable by loadSkills', () { ... });
  test('v2 corrupt → loadSkills returns empty (no backup)', () { ... });
});
```

**Device Test (Manual):**
1. Install v1 APK → create 3 skills
2. Upgrade to v2 APK → open SkillsPage → 3 skills, kind=workflow
3. Force-stop during migration → restart → skills restored from backup
4. Delete v2 key manually → app loads empty (expected)

**Commands:**
```bash
dart test app/test/skills/skill_storage_test.dart
dart analyze --no-fatal-infos
# Device test manual
```

**Gate 1B Criteria:**
- [ ] All storage tests pass
- [ ] `dart analyze` clean
- [ ] Device migration: v1→v2 ✅, rollback during migrate ✅, v2 corrupt → empty ✅

---

#### **PHASE 1C: Provider Integration**

**Goal:** Riverpod Provider works with v2 skills

**Files:**
- `app/lib/skills/skill_provider.dart` — Update SkillsState, SkillsController

**Changes:**
- SkillsState holds `List<Skill>` (v2)
- SkillsController methods (add, update, delete, toggleHidden) work with v2 fields
- skillProvider family returns correct v2 skill
- No breaking changes to existing API

**Commands:**
```bash
dart test app/test/skills/skill_provider_test.dart  # if exists
dart analyze --no-fatal-infos
```

**Manual Verify:**
- Add skill → persists
- Update skill → persists
- Delete skill → removed
- SkillDetailPage shows kind, schemaVersion, provenance

**Gate 1C Criteria:**
- [ ] CRUD works end-to-end
- [ ] Provider tests pass
- [ ] Analyze clean

---

#### **PHASE 1D: Distiller v2 Output**

**Goal:** Distiller creates v2 skills (`kind: 'workflow'`)

**Files:**
- `app/lib/skills/skill_distill.dart` — Update createFromMessageText, distillFromSession

**Changes:**
```dart
// createFromMessageText returns:
Skill(
  kind: 'workflow',           // Default for message-based skills
  schemaVersion: 2,
  provenance: SkillProvenance.distilled(sessionId, messageId),
  // ... other fields
)

// distillFromSession returns:
Skill(
  kind: 'workflow',           // Or 'executable' if toolCalls extracted
  schemaVersion: 2,
  provenance: SkillProvenance.distilled(sessionId, messageId),
  executableSteps: toolCalls?.map(toSkillStep).toList(),  // Future
)
```

**Commands:**
```bash
dart test app/test/skills/skill_distill_test.dart  # if exists
dart analyze --no-fatal-infos
```

**Manual Verify:**
- Single message save → SkillCreatePage shows draft, kind=workflow
- Multi-select save → merged text, kind=workflow

**Gate 1D Criteria:**
- [ ] Distiller outputs v2
- [ ] Analyze clean
- [ ] Both save flows work

---

#### **PHASE 1E: Capture Compatibility**

**Goal:** Verify existing save flows work (no code changes)

**Manual Verify Checklist:**
- [ ] Assistant message → long press → "Save as Skill" → SkillCreatePage opens with draftText
- [ ] Composer capsule bar → "Save from Selected" → pick 3 messages → SkillCreatePage opens with merged text

**Gate 1E Criteria:**
- [ ] Both flows work
- [ ] No regressions

---

### STAGE 2: Intelligent Capture

**Goal:** Extract real `toolCalls` from transcript → populate `draftTools` for SkillCreatePage

**Files:**
- `app/lib/chat/assistant_message.dart` — Single message save: read `AssistantChatItem.toolCalls`
- `app/lib/composer/composer_capsules.dart` — Multi-select: merge `toolCalls` from selected messages
- `app/lib/skills/skill_distill.dart` — `createFromMessageText` accepts `draftTools: List<String>`

**Implementation:**
```dart
// assistant_message.dart: onSaveAsSkill()
final toolCalls = chatItem.toolCalls?.map((tc) => tc.name).toList() ?? [];
Navigator.push(SkillCreatePage(draftText: text, draftTools: toolCalls));

// composer_capsules.dart: onSaveFromSelected()
final allTools = selectedMessages
    .expand((m) => m.toolCalls?.map((tc) => tc.name) ?? [])
    .toSet()
    .toList();
Navigator.push(SkillCreatePage(draftText: mergedText, draftTools: allTools));

// skill_distill.dart: createFromMessageText(draftTools: [...])
requiredTools = draftTools.isNotEmpty ? draftTools : ['bash', 'edit'];
```

**Gate 2 Criteria:**
- [ ] Single save: `draftTools` populated from message's toolCalls
- [ ] Multi-select: merged unique tool names
- [ ] Distiller uses `draftTools` → `requiredTools`
- [ ] Analyze clean

---

### STAGE 3: Skill Studio UI

**Goal:** Full skill creation/edit UI in SkillCreatePage

**Files:**
- `app/lib/skills/skill_create_page.dart` — Main form
- `app/lib/skills/widgets/` — New widgets (see below)

**New Widgets to Create:**
| Widget | Purpose |
|--------|---------|
| `KindSelector` | 3 radio buttons: Knowledge / Workflow / Executable |
| `StepEditor` | ListView with reorder, add, edit, delete |
| `StepModePicker` | Dropdown: Tool / Agent (per step) |
| `ToolBindingDropdown` | Tool list: bash, edit, web_fetch, read, write, search, present |
| `ParameterBindingUI` | Map `${param}` → step arg field |
| `DryRunPreviewButton` | Shows validation result (no execution) |

**Form Validation per Kind:**
| Kind | Required Fields |
|------|-----------------|
| Knowledge | name, goal, description, constraints |
| Workflow | name, goal, steps (text), userInputs |
| Executable | name, goal, executableSteps (with toolBinding), parameters, errorHandling |

**Gate 3 Criteria:**
- [ ] Can create all 3 kinds
- [ ] Step editor: add/edit/delete/reorder works
- [ ] Tool mode: tool dropdown + args with `${param}`
- [ ] Parameter binding: shows bound steps
- [ ] Dry-run preview: validates params, tools, permissions (no execution)
- [ ] Analyze clean

---

### STAGE 4: Execution PoC (CRITICAL GATE)

**Goal:** Prove real tool execution via Agent prompt — **throwaway code**

**File:** `app/test/skills/tool_execution_poc_test.dart` (NEW — separate from main)

**PoC Implementation:**
```dart
// Uses DshClient directly (no ChatController)
class ToolExecutionPoC {
  final DshClient client;
  
  Future<PoCResult> run() async {
    // 1. Create isolated session
    final session = await client.createSession(cwd: '/tmp/skill_poc');
    
    // 2. Prompt tool execution
    final requestId = await client.prompt(session.sessionId, 'Run: bash "echo hello"');
    
    // 3. Watch events via client.history() or stream
    final toolCall = await waitForToolCall(session.sessionId, requestId);
    assert(toolCall.name == 'bash');
    
    // 4. Handle approval if needed
    if (toolCall.requiresApproval) {
      final approval = await waitForApproval(session.sessionId, toolCall.callId);
      await client.respondApproval(approval, ApprovalDecision.allowOnce);
    }
    
    // 5. Get tool result
    final toolResult = await waitForToolResult(session.sessionId, toolCall.callId);
    assert(!toolResult.isError);
    assert(toolResult.output.contains('hello'));
    
    // 6. Test cancellation
    await client.cancel(session.sessionId);
    
    // 7. Test timeout (prompt with long-running command)
    await testTimeout(session.sessionId);
    
    return PoCResult(success: true);
  }
}
```

**Event Watching:** Use `client.history(sessionId, throughSeq)` polling or stream subscription

**Success Criteria (ALL MUST PASS):**
- [ ] Tool invoked via Agent prompt
- [ ] Tool result captured (not Agent text)
- [ ] Approval flow works
- [ ] Cancellation stops execution
- [ ] Timeout enforced

**IF ANY FAILS → STOP, REDESIGN ARCHITECTURE**

---

### STAGE 5: Full Execution

**Goal:** Production SkillExecutionController

**Files:**
- `app/lib/skills/skill_execution_controller.dart` (NEW — Riverpod Notifier)
- `app/lib/skills/skill_executor.dart` (NEW — Thin adapter)
- `app/lib/skills/parameter_resolver.dart` (NEW — `${param}` substitution)
- `app/lib/skills/step_runner.dart` (NEW — Tool/Agent mode runners)

**State Machine:**
```
Pending → Running → WaitingApproval → WaitingInput → Running → Completed/Failed/Cancelled
                ↘️ Retrying (maxRetries from errorHandling)
```

**Key Components:**
```dart
// ParameterResolver: simple ${param} → value substitution (no template engine)
Map<String, dynamic> resolveArgs(Map<String, dynamic> args, Map<String, String> params) {
  return args.map((k, v) => MapEntry(k, _substitute(v, params)));
}

// StepRunner.tool: builds prompt "Run: {tool} {jsonArgs}", calls client.prompt(), handles approval
// StepRunner.agent: sends prompt template with resolved params, returns agent response

// SkillExecutionController: manages lifecycle, streams progress, writes audit log to SharedPreferences
```

**Gate 5 Criteria:**
- [ ] Tool mode: executes via Agent, handles approval, returns result
- [ ] Agent mode: sends prompt, gets response
- [ ] Parameter resolution works
- [ ] Cancellation works mid-execution
- [ ] Retry per errorHandling config
- [ ] Audit log persisted
- [ ] Analyze clean

---

### STAGE 6: Intelligence & Evolution

**Goal:** Learning from runs, portability

**Files:**
- `app/lib/skills/skill_history.dart` (NEW — RunRecord model + storage)
- `app/lib/skills/improvement_proposal.dart` (NEW — Proposal model)
- `app/lib/skills/skill_import_export.dart` (NEW — JSON import/export)

**Models:**
```dart
class SkillRunRecord {
  final String skillId;
  final DateTime startedAt, endedAt;
  final SkillRunStatus status;
  final List<StepResult> stepResults;
  final Map<String, String> paramsUsed;
  final String? error;
}

class ImprovementProposal {
  final String skillId;
  final String proposedBy;  // 'system' | 'user'
  final SkillDiff diff;     // What changes
  final String rationale;   // Why (based on run history)
  final ProposalStatus status; // pending | accepted | rejected
}
```

**Features:**
- Auto-propose after N failed runs (analyze error patterns)
- User accepts → creates new skill version (immutable canonical + new version)
- Export/Import: JSON with full v2 schema + provenance
- Sub-skills: executableSteps can reference other skill IDs (composition)

**Gate 6 Criteria:**
- [ ] Run history recorded per execution
- [ ] Proposals generated from failure patterns
- [ ] Version diff/rollback works
- [ ] Export/Import round-trip preserves all fields
- [ ] Sub-skill execution works
- [ ] Analyze clean

---

## 🔧 COMMON COMMANDS

### Start Every Session
```bash
cd /root/workspace/dsh-Go
git status
git log --oneline -5
git checkout feat/fix-skill-crash
git branch --show-current  # Must show feat/fix-skill-crash
```

### Test Commands
```bash
# Phase 1A
dart test app/test/skills/skill_model_test.dart
dart analyze --no-fatal-infos

# Phase 1B
dart test app/test/skills/skill_storage_test.dart
dart analyze --no-fatal-infos

# Phase 1C
dart test app/test/skills/skill_provider_test.dart
dart analyze --no-fatal-infos

# Phase 1D
dart test app/test/skills/skill_distill_test.dart
dart analyze --no-fatal-infos

# Phase 2
dart test app/test/skills/skill_distill_test.dart  # draftTools integration
dart analyze --no-fatal-infos

# Phase 3
dart test app/test/skills/skill_create_page_test.dart  # if created
dart analyze --no-fatal-infos

# Phase 4
dart test app/test/skills/tool_execution_poc_test.dart
dart analyze --no-fatal-infos

# Phase 5
dart test app/test/skills/skill_execution_controller_test.dart
dart test app/test/skills/step_runner_test.dart
dart analyze --no-fatal-infos

# Phase 6
dart test app/test/skills/skill_history_test.dart
dart test app/test/skills/skill_import_export_test.dart
dart analyze --no-fatal-infos
```

### Git Rules
```bash
# NEVER:
git add .
git push --force
git commit -am

# ALWAYS:
git add <specific-files>
git commit -m "fork-only: <description>"
git push origin feat/fix-skill-crash
```

---

## 📋 REPORT TEMPLATE (After Each Phase)

```
Phase X DONE
- Tests: [X passed / X failed]
- Analyze: [clean / X issues]
- Device test: [✅ passed / ❌ failed / N/A]
- Files changed: [list]
- Notes: [any issues/blockers]
รอ approve ไป Phase X+1
```

---

## 🚨 BLOCKER TEMPLATE (If Stuck > 3 Attempts)

```
Phase X BLOCKED
- Issue: [description]
- Tried: [what was attempted]
- Error log: [paste actual error]
- Need: [decision/info needed from user]
```

---

## 📁 FILE INVENTORY

### Existing Files (to modify)
| File | Phase |
|------|-------|
| `app/lib/skills/skill_model.dart` | 1A |
| `app/lib/skills/skill_storage.dart` | 1B |
| `app/lib/skills/skill_provider.dart` | 1C |
| `app/lib/skills/skill_distill.dart` | 1D |
| `app/lib/skills/skill_create_page.dart` | 3 |
| `app/lib/skills/skill_detail_page.dart` | 3 |
| `app/lib/skills/skills_page.dart` | 3 |
| `app/lib/chat/assistant_message.dart` | 2, 1E |
| `app/lib/composer/composer_capsules.dart` | 2, 1E |

### New Files (to create)
| File | Phase |
|------|-------|
| `app/test/skills/skill_model_test.dart` | 1A |
| `app/test/skills/skill_storage_test.dart` | 1B |
| `app/test/skills/skill_provider_test.dart` | 1C (if needed) |
| `app/test/skills/skill_distill_test.dart` | 1D (if needed) |
| `app/lib/skills/widgets/kind_selector.dart` | 3 |
| `app/lib/skills/widgets/step_editor.dart` | 3 |
| `app/lib/skills/widgets/step_mode_picker.dart` | 3 |
| `app/lib/skills/widgets/tool_binding_dropdown.dart` | 3 |
| `app/lib/skills/widgets/parameter_binding_ui.dart` | 3 |
| `app/lib/skills/widgets/dry_run_preview.dart` | 3 |
| `app/test/skills/tool_execution_poc_test.dart` | 4 |
| `app/lib/skills/skill_execution_controller.dart` | 5 |
| `app/lib/skills/skill_executor.dart` | 5 |
| `app/lib/skills/parameter_resolver.dart` | 5 |
| `app/lib/skills/step_runner.dart` | 5 |
| `app/lib/skills/skill_history.dart` | 6 |
| `app/lib/skills/improvement_proposal.dart` | 6 |
| `app/lib/skills/skill_import_export.dart` | 6 |

---

## ⚠️ KNOWN CONSTRAINTS

1. **No local Flutter SDK** — `flutter analyze` / `flutter test` only on GitHub Actions
2. **Heavy builds on GitHub Actions only** — APK, Gradle, Rust
3. **Branch protection** — Only `feat/fix-skill-crash`, no force push, no `git add .`
4. **Commit prefix** — `fork-only:` for thai/release only
5. **L10n** — ARB edits only via `python3 app/tool/l10n_merge.py --locale th --check`
6. **Real device required** — For phone control/PRoot/runtime changes

---

## 🎯 CURRENT STATE

- **Phase:** 1A (Ready to start)
- **Branch:** feat/fix-skill-crash
- **Last Commit:** Check `git log --oneline -1`
- **Blockers:** None — awaiting approval to start Phase 1A

---

## 📝 NOTES FOR FUTURE SESSIONS

1. **Always run start commands first** (git status, checkout branch)
2. **One phase at a time** — complete Gate before next phase
3. **Report using template** — enables continuity
4. **If blocked > 3 tries** — use blocker template, don't guess
5. **Device tests are mandatory** for migration/storage phases
6. **L10n keys** — add when UI needs them, not in advance
7. **PoC is separate** — Stage 4 PoC is throwaway, proves architecture before real implementation

---

*End of Runbook — Save this file and reference for all future work on Personal Skills Evolution*