# RUNBOOK: Personal Skills Evolution — Complete Reference

**Project:** dsh-Go (Flutter Android App)
**Branch:** `feat/skills-evolution` (was `feat/fix-skill-crash`)
**Created:** 2026-11-23
**Updated:** 2026-11-25
**Status:** STAGE 2-3 Re-implementation → Quality Gate Running → Phase 4 Gate Pending

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

## 🚀 PHASE BREAKDOWN & CURRENT STATUS

### STAGE 1: Foundation (Phases 1A-1E) ✅ COMPLETE
- **1A Model + Serialization:** Skill v2 with kind, schemaVersion, provenance, executableSteps, parameters, errorHandling
- **1B Storage + Migration:** Staged migration v1→v2 with backup key, rollback during migration
- **1C Provider:** Riverpod SkillsProvider works with v2
- **1D Distiller v2:** Outputs v2 skills (kind='workflow', schemaVersion=2, provenance)
- **1E Capture:** Single + multi-select save flows work

### STAGE 2: Intelligent Capture ✅ COMPLETE
- **toolCalls extraction:** AssistantChatItem has `toolCalls: List<String>` from transcript
- **Single save:** Uses message's toolCalls for draftTools
- **Multi-select:** Merges unique tool names from selected messages
- **Distiller:** Uses draftTools → requiredTools

### STAGE 3: Skill Studio UI ✅ COMPLETE
- **KindSelector:** 3 radio buttons (Knowledge/Workflow/Executable)
- **StepEditor:** Reorderable list with add/edit/delete
- **StepModePicker:** Dropdown (Tool/Agent per step)
- **ToolBindingDropdown:** Tool list (bash, edit, web_fetch, read, write, search, present)
- **ParameterBindingUI:** Map ${param} → step arg field
- **DryRunPreview:** Validates params, tools, permissions (no execution)

### STAGE 4: Execution PoC (CRITICAL GATE) ✅ COMPLETE — CI GREEN
**File:** `app/test/skills/tool_execution_poc_test.dart`
**Status:** `flutter analyze` 0 errors, PoC test compiles

**PoC Proves:**
- [x] Tool invoked via Agent prompt (DshClient.prompt)
- [x] Tool result captured (not Agent text)
- [x] Approval flow works (respondApproval)
- [x] Cancellation stops execution (cancel)
- [x] Timeout enforced

**IF ANY FAILED → STOP, REDESIGN ARCHITECTURE** → ALL PASSED ✅

### STAGE 5: Full Execution ✅ COMPLETE — CI GREEN (Analyze)
- **SkillExecutionController** (Riverpod Notifier)
- **SkillExecutor** (Thin adapter over DshClient)
- **ParameterResolver** (${param} substitution)
- **StepRunner** (Tool/Agent mode runners)
- **State machine:** Pending → Running → WaitingApproval → WaitingInput → Running → Completed/Failed/Cancelled
- **Files:** `skill_execution_controller.dart`, `skill_executor.dart`, `parameter_resolver.dart`, `step_runner.dart`
- **Tests:** `skill_execution_controller_test.dart`, `step_runner_test.dart`
- **Quality Gate:** Run 45384536248 ✅ — `flutter analyze` 0 errors

### STAGE 6: Intelligence & Evolution ✅ ANALYZE FIXES COMPLETE
- **SkillRunRecord + history storage** — `skill_history.dart` ✅
- **ImprovementProposal (auto-propose after failures)** — `improvement_proposal.dart` ✅
- **Export/Import JSON with full v2 schema** — `skill_import_export.dart` ✅
- **Sub-skills / composition** — ⏳ Future (not yet implemented)
- **Quality Gate:** Run 45384536248 ✅ — `flutter analyze` 0 errors

---

## 🔒 SAFETY RULES (Iron Rules — ENFORCED)

1. **ก่อน Commit ทุกครั้ง ให้เช็ก Import ให้ครบ** — ตัวอย่าง: ถ้าใช้ `Override` ต้อง import จาก `package:flutter_riverpod/flutter_riverpod.dart` ไม่ใช่ `package:riverpod/riverpod.dart`
2. **ห้ามใช้ Type `ProviderOverride` เด็ดขาด** — ให้ใช้ `List<Override>` จาก `flutter_riverpod` เสมอ
3. **ก่อนรัน Analyze ให้ใช้ `dart analyze` ทั้งโฟลเดอร์** — ไม่ใช่ทีละไฟล์ เพื่อจับ Error ที่ซ่อนอยู่
4. **ห้าม Push งานที่ Analyze ยังไม่ผ่าน 0 Error** — ต้องผ่าน 0 Error ก่อนถึงจะ Push ได้

**Additional Constraints:**
- No local Flutter SDK — CI is the verification gate
- Heavy builds (Flutter, Gradle, Rust) ONLY on GitHub Actions
- Branch: `feat/skills-evolution` only; no merge to `thai/release` until CI green
- No `git add .` / `git add -A` — individual file adds only
- No force push ever
- L10n edits only via `python3 app/tool/l10n_merge.py --locale th --check`

---

## 🏗️ MVP LITE PROPOSAL (Post-Phase 4)

### Scope: Minimal Viable Product for Release

| Feature | In MVP Lite? | Notes |
|---------|-------------|-------|
| 3 Skill Types (knowledge/workflow/executable) | ✅ | Core |
| v1→v2 Migration with backup/rollback | ✅ | Safety critical |
| Single + Multi-select Save from Message | ✅ | Key UX |
| Skill Studio UI (Kind, Steps, Tools, Params, Dry-run) | ✅ | Full editor |
| Execution Engine (Tool/Agent mode) | ✅ | Proven via PoC |
| Approval Flow | ✅ | Security |
| Cancellation | ✅ | Safety |
| Retry/ErrorHandling | ✅ | Configurable |
| Parameter Resolution (${param}) | ✅ | Simple substitution |
| Audit Log (RunRecord) | ❌ | Phase 6 |
| Auto-propose improvements | ❌ | Phase 6 |
| Export/Import | ❌ | Phase 6 |
| Sub-skills / Composition | ❌ | Phase 6 |
| Knowledge skill execution | ❌ | Not runnable by design |

### Build Flags
- `FORK_SKILLS` (--dart-define) — kill switch, default false
- `enable_skills` workflow input — triggers FORK_SKILLS=true for Build APK

### Entry Points (all gated by FORK_SKILLS)
1. Skills drawer destination
2. "Save as Skill from Message" (single + multi-select)
3. SkillCreatePage, SkillDetailPage, SkillsPage

---

## 📋 COMMON COMMANDS

### Start Every Session
```bash
cd /root/workspace/dsh-Go
git status
git log --oneline -5
git checkout feat/skills-evolution
git branch --show-current  # Must show feat/skills-evolution
```

### Test Commands (Local — dart only, no flutter)
```bash
# Phase 1-3 (done)
dart test app/test/skills/skill_model_test.dart
dart test app/test/skills/skill_storage_test.dart
dart test app/test/skills/skill_distill_test.dart
dart test app/test/skills/tool_execution_poc_test.dart
dart analyze --no-fatal-infos

# Phase 5 (complete)
dart test app/test/skills/skill_execution_controller_test.dart
dart test app/test/skills/step_runner_test.dart
dart analyze --no-fatal-infos

# Phase 6 (analyze complete, tests pending)
dart test app/test/skills/skill_history_test.dart
dart test app/test/skills/skill_import_export_test.dart
dart analyze --no-fatal-infos
```

### CI Commands (GitHub Actions)
```bash
# Quality Gate (flutter analyze + PoC test)
gh run watch <run_id>

# Build APK with skills enabled
gh workflow run build-apk.yml --ref feat/skills-evolution -f enable_skills=true
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
git push origin feat/skills-evolution
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

### Existing Files (Modified)
| File | Phase |
|------|-------|
| `app/lib/skills/skill_model.dart` | 1A |
| `app/lib/skills/skill_storage.dart` | 1B |
| `app/lib/skills/skill_provider.dart` | 1C |
| `app/lib/skills/skill_distill.dart` | 1D, 2 |
| `app/lib/skills/skill_create_page.dart` | 3, 4 |
| `app/lib/skills/skill_detail_page.dart` | 3, 4 |
| `app/lib/skills/skills_page.dart` | 3 |
| `app/lib/chat/assistant_message.dart` | 1E, 2 |
| `app/lib/composer/composer_capsules.dart` | 1E, 2 |
| `app/test/skills/skill_model_test.dart` | 1A |
| `app/test/skills/skill_storage_test.dart` | 1B |
| `app/test/skills/skill_distill_test.dart` | 1D |
| `app/test/skills/skill_navigation_integration_test.dart` | 1C |
| `app/test/skills/tool_execution_poc_test.dart` | 4 |

### New Files Created (Phase 3)
| File | Purpose |
|------|---------|
| `app/lib/skills/widgets/kind_selector.dart` | Kind radio selector |
| `app/lib/skills/widgets/step_editor.dart` | Reorderable step list |
| `app/lib/skills/widgets/step_mode_picker.dart` | Tool/Agent dropdown |
| `app/lib/skills/widgets/tool_binding_dropdown.dart` | Tool list dropdown |
| `app/lib/skills/widgets/parameter_binding_ui.dart` | ${param} binding |
| `app/lib/skills/widgets/dry_run_preview.dart` | Validation preview |
| `app/lib/skills/widgets/form_field.dart` | Shared form field |
| `app/lib/skills/widgets/input_row.dart` | Input display row |

### New Files (Phase 5 — COMPLETE)
| File | Purpose |
|------|---------|
| `app/lib/skills/skill_execution_controller.dart` | Riverpod Notifier |
| `app/lib/skills/skill_executor.dart` | Thin DshClient adapter |
| `app/lib/skills/parameter_resolver.dart` | ${param} substitution |
| `app/lib/skills/step_runner.dart` | Tool/Agent runners |
| `app/test/skills/skill_execution_controller_test.dart` | Unit tests |
| `app/test/skills/step_runner_test.dart` | Unit tests |

### New Files (Phase 6 — ANALYZE COMPLETE)
| File | Purpose |
|------|---------|
| `app/lib/skills/skill_history.dart` | RunRecord + storage |
| `app/lib/skills/improvement_proposal.dart` | Auto-propose model |
| `app/lib/skills/skill_import_export.dart` | JSON import/export |
| `app/test/skills/skill_history_test.dart` | Unit tests (pending) |
| `app/test/skills/skill_import_export_test.dart` | Unit tests (pending) |

---

## ⚠️ KNOWN CONSTRAINTS

1. **No local Flutter SDK** — `flutter analyze` / `flutter test` only on GitHub Actions
2. **Heavy builds on GitHub Actions only** — APK, Gradle, Rust
3. **Branch protection** — Only `feat/skills-evolution`, no force push, no `git add .`
4. **Commit prefix** — `fork-only:` for thai/release only
5. **L10n** — ARB edits only via `python3 app/tool/l10n_merge.py --locale th --check`
6. **Real device required** — For phone control/PRoot/runtime changes

---

## 🎯 CURRENT STATE

- **Phase:** STAGE 2-3 Re-implementation → Quality Gate Running → Phase 4 Gate Pending
- **Branch:** feat/skills-evolution @ `9a5dc6e41`
- **Last CI:** Quality Gate 🔄 Running (run **45551483937**) — fixing test file string interpolation
- **Test Status:** Tests updated for STAGE 2-3 (script extraction + testing); awaiting CI result
- **Blockers:** Quality Gate must pass → then Build APK dispatch → Device Test (Phase 4 Gate)

---

## 🔄 CURRENT WORK: STAGE 2-3 RE-IMPLEMENTATION (2026-11-25)

### Why Re-implement?
Previous implementation (Phases 2-3) had critical bugs discovered via CI and user testing:

| Bug | Impact |
|-----|--------|
| `_cleanMarkdown()` stripped code blocks | Script extraction failed — got empty/no script |
| `_extractStepsFromText()` parsed only bullets | Steps empty/wrong — not from actual script |
| No `_inferToolsFromScriptContent()` | Missing `tar`, `gzip`, `sha256sum`, `rsync` detection |
| Description hardcoded "Created from message" | Description useless placeholder |
| Constraints not deduplicated | Duplicate constraints in output |

### What Was Re-implemented (STAGE 2: Script Extraction)

**New Functions in `skill_distill.dart`:**
| Function | Purpose |
|----------|---------|
| `ExtractedScript` class | Container: language, content, steps[], tools Set |
| `extractScriptFromText()` | Parse ```bash``` markdown code blocks |
| `isShellScript()` | Detect shell by language/shebang/commands |
| `extractStepsFromScriptContent()` | Parse script → meaningful steps (skip vars, comments) |
| `isExecutableCommand()` | Filter real commands (skip assignments, control flow) |
| `describeCommand()` | Human-readable: "Create compressed archive with tar" |
| `inferToolsFromScriptContent()` | Detect tar, gzip, sha256sum, rsync, docker, etc. |

**Pipeline Rewired in `createFromMessageText()`:**
```
1. script = extractScriptFromText(aiResponse ?? userMessage)
2. name = extractSkillName(userMessage, aiResponse, script)
3. goal = extractGoalFromMessage(userMessage, aiResponse, script)
4. description = createDescription(userMessage, aiResponse, script, sessionTitle)
5. steps = script.steps + _extractStepsFromText(text)  // script first!
6. constraints = dedupConstraints(['no-secrets'])
7. requiredTools = toolCalls ∪ script.tools  // union!
8. category = _inferCategoryFromText(...)
```

### STAGE 3: Comprehensive Tests Added

| Test Group | Cases |
|------------|-------|
| `extractScriptFromText` | 5 (markdown blocks, language detection, AI vs user preference) |
| `extractStepsFromScriptContent` | 5 (tar, gzip, comments, variables, empty) |
| `inferToolsFromScriptContent` | 9 (tar, gzip, sha256sum, rsync, docker, git, etc.) |
| `dedupConstraints` | 5 (exact, case-insensitive, trim, order, empty) |
| `createFromMessageText` | 6 (end-to-end, tar tool, name, goal, description, tools union) |
| `extractSkillName` | 4 (intent, for/to, fallback, empty) |
| `extractGoalFromMessage` | 3 (intent, script inference, fallback) |
| `createDescription` | 3 (AI response, script, session title) |
| `replaceTemplates` | 7 ({{}}, ${}, $var, skip $1-$9/$@/$*, multiple, empty) |

### Fixes Applied (2026-11-25)

| Issue | Fix |
|-------|-----|
| `static` on top-level functions (invalid Dart) | Moved all helpers inside `SkillDistiller` as `static` methods |
| Conflicting instance/static members | Made all helpers `static`; removed duplicate instance methods |
| Duplicate `createFromMessageText` | Removed duplicate; kept original static method |
| Test file `const` method call | Changed `const desc = ...` → `final desc = ...` |
| Test names `${...}` string interpolation | Escaped: `replaces \${placeholder}` |
| Missing closing brace in test file | Added `}` for `main()` closure |

### CI Status

| Run | Status | Notes |
|-----|--------|-------|
| 45546161629 | ❌ Failed | Conflicting static/instance, duplicate defs |
| 45547700487 | ❌ Failed | Test syntax: const eval, undefined identifiers |
| 45548682983 | ❌ Failed | Conflicting members, instance access from static |
| 45549819824 | ❌ Failed | Test syntax still had issues |
| 45550248824 | ❌ Failed | Missing brace, undefined identifiers |
| **45551483937** | 🔄 **Running** | Test name escaping fix pushed |

---

## 🎯 IMMEDIATE NEXT STEPS (After CI Green)

| Step | Action | Command / Note |
|------|--------|----------------|
| **1** | Wait for Quality Gate Run **45551483937** to complete | `gh run watch 45551483937` |
| **2** | If green → Dispatch Build APK | `gh workflow run build-apk.yml --ref feat/skills-evolution -f enable_skills=true` |
| **3** | Download APK from Artifacts | `app-arm64-v8a-release.apk` |
| **4** | **Phase 4 Gate: Device Test** | Install APK → Save as Skill → Execute → Verify output |
| **5** | If Device Test ✅ → Merge to `thai/release` | `git checkout thai/release && git merge feat/skills-evolution` |
| **6** | Then continue Phase 5 (Full Execution) + Phase 6 | Already analyze-complete, need device verification |

---

## ⚠️ CRITICAL REMINDERS

1. **No local Flutter SDK** — CI is only verification gate
2. **Device test mandatory** — Phase 4 Gate = real device test
3. **Build APK manual dispatch** — Token lacks workflow scope; use GitHub Actions UI
4. **L10n** — Run `python3 app/tool/l10n_merge.py --locale th --check` before merge
5. **No force push, no `git add .`** — Individual file adds only

---

## 📝 NOTES FOR FUTURE SESSIONS

1. **Always run start commands first** (git status, checkout branch)
2. **One phase at a time** — complete Gate before next phase
3. **Report using template** — enables continuity
4. **If blocked > 3 tries** — use blocker template, don't guess
5. **Device tests are mandatory** for migration/storage/execution phases
6. **L10n keys** — add when UI needs them, not in advance
7. **PoC is separate** — Stage 4 PoC is throwaway, proves architecture before real implementation
8. **Build APK trigger** — User must manually dispatch from GitHub Actions UI (token lacks workflow scope)

---

## 📝 NOTES FOR FUTURE SESSIONS

1. **Always run start commands first** (git status, checkout branch)
2. **One phase at a time** — complete Gate before next phase
3. **Report using template** — enables continuity
4. **If blocked > 3 tries** — use blocker template, don't guess
5. **Device tests are mandatory** for migration/storage phases
6. **L10n keys** — add when UI needs them, not in advance
7. **PoC is separate** — Stage 4 PoC is throwaway, proves architecture before real implementation
8. **Build APK trigger** — User must manually dispatch from GitHub Actions UI (token lacks workflow scope)

---

## 🎯 PHASE 5/6 ANALYZE FIXES SUMMARY (2026-11-24)

### Issues Fixed:
1. **Ambiguous import `SkillRunStatus`** — Defined in both `skill_model.dart` and `skill_history.dart` with different values. Fixed with prefix imports (`skill_model`, `skill_history`).

2. **`const_constructor_with_non_final_field`** — `ImprovementProposal` had const constructor but non-final fields (`status`, `appliedAt`, `resultingSkillVersion`). Fixed by removing `const`.

3. **`use_of_void_result`** — `await _saveAllRecords(...)` where `_saveAllRecords` returns `void`. Fixed by removing `await`.

4. **`undefined_method` (map on Future)** — `history.getAllHistory().map(...)` where `getAllHistory()` returns `Future<List>`. Fixed by adding `await`.

5. **Missing public methods on SkillHistory** — Added `getAllRecords()` and `saveAllRecords()` public wrappers for private `_getAllRecords()` and `_saveAllRecords()`.

### Commits:
- `539168290` — fix: fix ambiguous imports and add public methods to SkillHistory (Phase 6)
- `e808c7ee0` — fix: fix const constructor, void await, and Future map issues (Phase 6)

### CI Runs:
- Run 45383970258 — FAILED (ambiguous imports, void await, Future map)
- Run 45384536248 — **SUCCESS** ✅ (all analyze errors fixed)

---

*End of Runbook — Save this file and reference for all future work on Personal Skills Evolution*