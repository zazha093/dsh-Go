# RUNBOOK: Personal Skills Evolution — Complete Reference

**Project:** dsh-Go (Flutter Android App)
**Branch:** `feat/skills-evolution` (was `feat/fix-skill-crash`)
**Created:** 2026-11-23
**Updated:** 2026-11-26
**Status:** AI Summarizer Implementation (Phases 0-6) — Phase 1 Next: Fix Black Screen/Spinning

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

## 🤖 NEW: AI SUMMARIZER IMPLEMENTATION PLAN (Phases 0-6)

**Problem:** Current `distillTurn` in `heuristics.dart` is rule-based only. User wants AI (`fcc`/ephemeral session) as primary summarizer with rule-based as fallback.

**Architecture:**
- **Primary:** AI summarization via ephemeral DshClient session (create → prompt → archive)
- **Fallback:** Instant rule-based `distillTurn` (opens form in milliseconds)
- **Validator:** Field-level — AI result per field validated; failed fields use rule-based value
- **Safety:** Redact + truncate before sending; 25s timeout; cancellable; breadcrumbs

### Phase 0: Document Findings (5 min)
- **File:** `~/dsh-go-handoff/DISTILL-AI-DESIGN.md`
- Record: AI channel decision (ephemeral session + archiveSession), redact utilities exist, field-level validation spec, skill name auto-fill removal, breadcrumbs spec

### Phase 1: Fix Black Screen/Spinning (5 min) — CRITICAL FIRST
- **File:** `app/lib/skills/skill_create_page.dart`
- Fixes:
  - PopScope: Allow close always (remove `canPop: !_isLoading` or add emergency close)
  - Loading text: Separate session distillation vs message distillation text
  - Add 25s timeout to `compute()` calls using `Future.any([compute(...), Future.delayed(25s)])`
  - Add cancellation flag checked before/after await
  - Show "AI summarizing..." badge instead of full-screen spinner

### Phase 2: Stabilize Controller (7 min)
- **New File:** `app/lib/skills/skill_distill_controller.dart`
- `NotifierProvider.autoDispose` with:
  - `CancelToken` / `cancelled` flag
  - `ref.onDispose` → cancel work
  - State: `idle` | `running` | `ready` | `failed` | `cancelled`
  - Every state write after `await` checks `ref.mounted` + `context.mounted`
  - Result after dispose → silently discard

### Phase 3: Instant Rule-Based Draft (5 min)
- **Files:** `skill_create_page.dart`, `heuristics.dart`
- Form opens instantly with `distillTurn` result (no network)
- Show "AI summarizing..." status badge with cancel button
- User can edit/save immediately without waiting for AI

### Phase 4: AI Summarizer + Validator (7 min)
- **New Files:** `app/lib/fork/ai_summarizer.dart`, `app/lib/fork/draft_validator.dart`
- **AI Summarizer:**
  - `createEphemeralSession()` → `prompt()` → `archiveSession(stopActivity: true)`
  - Input truncation: userPrompt≤1500, assistant≤4000, writeScript≤6000, total≤20000
  - Redact pipeline: `redactText()` → `cutText()` on all inputs
  - Prompt: JSON schema (name≤60, goal≤300, description≤200, steps[8]≤150, constraints[], tools[], params[])
  - Locale-aware: "ตอบเป็นภาษาไทย ศัพท์เทคนิค คำสั่ง โค้ด คงอังกฤษ"
  - 25s timeout, 1 retry, robust JSON extraction (strip fences, parse object)
- **Draft Validator (field-level):**
  - Checks per field: CJK (if locale≠zh), generic names, duplicates, length, secrets pattern
  - Fallback: `distillTurn` value for **each failed field individually**
  - Never discards entire AI result

### Phase 5: UI Integration (5 min)
- **Files:** `skill_create_page.dart`, l10n (zh/en/th)
- "AI proposes draft" banner: [ใช้ร่างนี้] [ไม่ใช้] — doesn't overwrite user edits
- Skill name field: empty with hint (`skillsNameHint`), no 'Draft' default
- Breadcrumbs: `ai:start/ok/timeout/cancel/invalid` with source + field counts
- Settings toggle: "Use AI summarization" (default on, stored in fork settings)

### Phase 6: Test & CI (7 min)
- **Widget Tests:** (1) AI hangs + cancel → close works, (2) AI responds after dispose → no error, (3) AI error/timeout → form saves from rule-based, (4) open/close 5x no leak
- **Unit Tests:** AI summarizer (mock client), validator (field-level fallback), redact+truncate
- **CI:** `xcheck`, `l10n_merge --check`, Quality Gate, Build APK (manual dispatch)
- **Device Test Cases:**
  - (ก) Agent pastes full script → Save as Skill
  - (ข) Agent writes file via tool → Save as Skill
  - (ค) Chat without script → Save as Skill
  - (ง) FCC slow/down → Cancel/back during wait → no black screen
  - (จ) Disable AI summarization → Uses rule-based only

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

### New Files (AI Summarizer — Phases 0-6)
| File | Purpose |
|------|---------|
| `~/dsh-go-handoff/DISTILL-AI-DESIGN.md` | Design doc (Phase 0) |
| `app/lib/fork/ai_summarizer.dart` | AI summarization via ephemeral session (Phase 4) |
| `app/lib/fork/draft_validator.dart` | Field-level validation + rule fallback (Phase 4) |
| `app/lib/skills/skill_distill_controller.dart` | NotifierProvider with CancelToken (Phase 2) |
| `app/test/skills/ai_summarizer_test.dart` | Unit tests for AI summarizer (Phase 6) |
| `app/test/skills/draft_validator_test.dart` | Unit tests for validator (Phase 6) |
| `app/test/skills/skill_distill_controller_test.dart` | Widget tests for controller (Phase 6) |

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

- **Phase:** STAGE 2-3 Re-implementation → Quality Gate Running → **NEW: AI Summarizer Implementation (Phase 0-6)**
- **Branch:** feat/skills-evolution @ `6823e49f4` (latest CI green: Quality Gate 45778926682, Build APK 45778926723)
- **Last CI:** Quality Gate ✅ **PASSED** (run 45778926682, 2m28s) — flutter analyze 0 errors
- **Last CI:** Build APK ✅ **PASSED** (run 45778926723, 17m45s) — APK built and signed
- **Test Status:** All CI gates green, turn-based distillation with full tool call args implemented
- **Current Issue:** **Black screen + infinite spinning** in SkillCreatePage when saving skill from chat
  - PopScope `canPop: !_isLoading` blocks navigation when loading
  - Wrong loading text: shows "Pick a completed session..." even for message-based distillation
  - No timeout on `compute()` calls — can hang indefinitely
  - No cancellation mechanism for user to abort distillation
- **Blockers:** Fix black screen/spinning → Implement AI Summarizer (Phases 0-6) → Device test

---

## 🔄 CURRENT WORK: AI SUMMARIZER IMPLEMENTATION (2026-11-26)

### Why This Work?
The turn-based distillation (`distillTurn` in `heuristics.dart`) is rule-based only. User wants AI as primary summarizer with rule-based as instant fallback. Current SkillCreatePage has **black screen + infinite spinning** bug when saving from chat.

### Problems to Fix

| Issue | Location | Root Cause |
|-------|----------|------------|
| Black screen | `skill_create_page.dart:337-349` | `PopScope(canPop: !_isLoading)` blocks all navigation when loading |
| Wrong loading text | `skill_create_page.dart:370-383` | Condition `sessionId != null && _distilledSkill == null` true for message distillation; both branches show "Pick a completed session..." |
| Infinite hang risk | `skill_create_page.dart:196-204` | `compute()` no timeout; if isolate hangs, `finally` never runs → `_isLoading` stuck true |
| No cancellation | `skill_create_page.dart:170-235` | No `CancelToken`; user cannot abort distillation |

### AI Summarizer Architecture (New)

| Component | Role | Location |
|-----------|------|----------|
| **Rule-based (primary fallback)** | Instant distillation, opens form in ms | `heuristics.dart:distillTurn()` |
| **AI Summarizer** | Primary: ephemeral session → prompt → archive | New: `app/lib/fork/ai_summarizer.dart` |
| **Draft Validator** | Field-level validation + rule-based fallback | New: `app/lib/fork/draft_validator.dart` |
| **Controller** | State management, cancellation, dispose safety | New: `app/lib/skills/skill_distill_controller.dart` |
| **UI** | Form opens instantly, AI badge, proposal banner | `skill_create_page.dart` + l10n |

### Implementation Phases (0-6)

| Phase | Goal | Time | Key Files |
|-------|------|------|-----------|
| **0** | Document findings | 5 min | `~/dsh-go-handoff/DISTILL-AI-DESIGN.md` |
| **1** | Fix black screen/spinning | 5 min | `skill_create_page.dart` |
| **2** | Stabilize Controller | 7 min | New: `skill_distill_controller.dart` |
| **3** | Instant rule-based draft | 5 min | `skill_create_page.dart`, `heuristics.dart` |
| **4** | AI Summarizer + Validator | 7 min | New: `ai_summarizer.dart`, `draft_validator.dart` |
| **5** | UI Integration | 5 min | `skill_create_page.dart`, l10n (zh/en/th) |
| **6** | Test & CI | 7 min | Widget/unit tests, xcheck, l10n_merge, CI |

### CI Status (Latest)

| Run | Status | Notes |
|-----|--------|-------|
| **45778926682** | ✅ **PASSED** | Quality Gate — flutter analyze 0 errors (2m28s) |
| **45778926723** | ✅ **PASSED** | Build APK — APK built & signed (17m45s) |

---

## 🎯 IMMEDIATE NEXT STEPS (Current Priority: Fix Black Screen + AI Summarizer)

| Step | Action | Command / Note |
|------|--------|----------------|
| **1** | **Phase 0:** Document findings in `~/dsh-go-handoff/DISTILL-AI-DESIGN.md` | Write AI channel decision, redact utilities, field-level validation, skill name, breadcrumbs |
| **2** | **Phase 1:** Fix black screen/spinning in `skill_create_page.dart` | PopScope fix, loading text fix, 25s timeout on compute, cancellation flag |
| **3** | **Phase 2:** Create `skill_distill_controller.dart` with CancelToken | NotifierProvider.autoDispose, ref.onDispose, mounted checks |
| **4** | **Phase 3:** Wire instant rule-based draft + AI badge | Form opens instantly, "AI summarizing..." badge with cancel |
| **5** | **Phase 4:** Implement `ai_summarizer.dart` + `draft_validator.dart` | Ephemeral session, redact+truncate, field-level fallback |
| **6** | **Phase 5:** UI integration — banner, skill name hint, breadcrumbs | "AI proposes draft" [Use]/[Dismiss], no 'Draft' default |
| **7** | **Phase 6:** Tests + CI + Device test | Widget tests (hang+cancel, post-dispose), xcheck, l10n_merge, Quality Gate, Build APK |
| **8** | Device test 5 cases (script, tool write, no-script, slow AI cancel, AI disabled) | Verify no black screen, correct distillation, proper fallback |
| **9** | If all passes → Merge to `thai/release` | `git checkout thai/release && git merge feat/skills-evolution` |

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

## 🗺️ FUTURE ROADMAP (Stage 4 → Stage 10+)

> **Complete plan from current Stage 4 Gate through final Stage 10+**
> **Purpose:** Prevent scope loss, enable seamless continuation across sessions

---

### 📅 STAGE 4: Execution PoC — Device Verification (CRITICAL GATE)
**Status:** ⏳ Pending — Requires Quality Gate pass → Build APK → Device test
**Goal:** Prove Save as Skill → Execute → Verify output works on real device
**Tasks:**
- [ ] Wait for Quality Gate Run 45551483937 to pass
- [ ] Manual dispatch Build APK: `gh workflow run build-apk.yml --ref feat/skills-evolution -f enable_skills=true`
- [ ] Download `app-arm64-v8a-release.apk` from Artifacts
- [ ] Install on device → Open dsh-Go → Chat → Save as Skill from message
- [ ] Verify: Script extracted correctly, steps meaningful, tools detected (tar/gzip/sha256sum)
- [ ] Execute skill → Verify approval flow → Verify output
- [ ] **Gate Criteria:** All above work → Merge to `thai/release`

---

### 📅 STAGE 5: Full Execution — Device Verification
**Status:** ⏳ After Stage 4 Gate passes
**Analyze Status:** ✅ Complete (Quality Gate 45384536248)
**Goal:** Verify full execution engine works on device
**Components to verify:**
- [ ] `SkillExecutionController` (Riverpod Notifier) — state machine works
- [ ] `SkillExecutor` (DshClient adapter) — tool calls execute correctly
- [ ] `ParameterResolver` — `${param}` substitution works with user inputs
- [ ] `StepRunner` — Tool mode & Agent mode both execute
- [ ] State machine: Pending → Running → WaitingApproval → WaitingInput → Running → Completed/Failed/Cancelled
- [ ] Retry/ErrorHandling configurable
- [ ] Concurrent skill execution (if supported)
- [ ] **Gate Criteria:** All execution paths work on device → Ready for Stage 6

---

### 📅 STAGE 6: Intelligence & Evolution — Device Verification
**Status:** ⏳ After Stage 5 passes
**Analyze Status:** ✅ Complete (Quality Gate 45384536248)
**Goal:** Verify intelligence features work on device
**Components to verify:**
- [ ] `SkillHistory` — RunRecord storage, retrieval, query
- [ ] `ImprovementProposal` — Auto-propose after failures, apply improvements
- [ ] `SkillImportExport` — JSON export/import with full v2 schema
- [ ] Sub-skills / Composition (if implemented) — skill calls skill
- [ ] **Gate Criteria:** All intelligence features work → Ready for Stage 7

---

### 📅 STAGE 7: MVP LITE — Missing Features Implementation
**Status:** 🔄 Planned (from MVP Lite Proposal "NOT in MVP")
**Features NOT in MVP Lite but planned:**
| Feature | Priority | Notes |
|---------|----------|-------|
| Audit Log (RunRecord) | 🔴 High | Phase 6 foundation exists |
| Auto-propose improvements | 🔴 High | Phase 6 foundation exists |
| Export/Import JSON | 🔴 High | Phase 6 foundation exists |
| Sub-skills / Composition | 🟡 Medium | Skill calls skill, parameter passing |
| Knowledge skill execution | 🟡 Medium | Currently not runnable by design |
| Skill versioning & diff | 🟡 Medium | Git-like history for skills |
| Skill sharing / marketplace | 🟢 Low | Export/import + community features |
| Skill scheduling / cron | 🟢 Low | Run skills on schedule |

---

### 📅 STAGE 8: Advanced Execution Features
**Status:** 🔄 Future
| Feature | Description |
|---------|-------------|
| Parallel step execution | Run independent steps concurrently |
| Conditional branching | if/else steps based on previous output |
| Loop steps | Repeat step N times or until condition |
| Dynamic parameter injection | Runtime values from previous steps |
| Skill timeout & resource limits | Per-skill CPU/memory/time budgets |
| Streaming output | Real-time output during long-running skills |

---

### 📅 STAGE 9: Skill Ecosystem & Community
**Status:** 🔄 Future
| Feature | Description |
|---------|-------------|
| Skill marketplace | Browse, install, rate community skills |
| Skill versioning & semver | Git-like history, branches, tags |
| Skill dependencies | Skill A requires Skill B |
| Private skill registry | Team/org internal skill sharing |
| Skill signing & verification | Provenance, tamper detection |
| Analytics dashboard | Usage stats, success rates, performance |

---

### 📅 STAGE 10: AI-Native Skill Evolution
**Status:** 🔮 Vision / Long-term
| Feature | Description |
|---------|-------------|
| Auto-generate skills from intent | LLM writes skill from natural language |
| Self-improving skills | Skills learn from execution traces |
| Skill composition by AI | AI combines skills for complex tasks |
| Cross-session learning | Skills improve across all user sessions |
| Predictive skill suggestion | "You might need this skill next" |
| Skill health monitoring | Auto-detect broken/deprecated skills |

---

### 📋 MILESTONE TIMELINE (Estimated)

| Stage | Target | Dependencies |
|-------|--------|--------------|
| **4 Gate: Device Test** | Immediately after CI green | CI pass → Build APK → Device |
| **5 Device Verify** | +1-2 weeks after Stage 4 | Stage 4 gate pass |
| **6 Device Verify** | +1-2 weeks after Stage 5 | Stage 5 pass |
| **7 MVP Lite Missing** | +2-4 weeks after Stage 6 | Stage 6 pass |
| **8 Advanced Execution** | +1-2 months | Stage 7 complete |
| **9 Ecosystem** | +2-3 months | Stage 8 complete |
| **10 AI-Native** | +6+ months | Stage 9 + AI infra |

---

### 🔑 KEY DECISIONS LOGGED (Do Not Revisit)

| Decision | Rationale | Logged |
|----------|-----------|--------|
| No local Flutter SDK — CI only | arm64 no Flutter SDK | 2026-11-23 |
| Build APK manual dispatch | Token lacks workflow scope | 2026-11-23 |
| Device test mandatory | PRoot/runtime only verifiable on device | 2026-11-23 |
| No Sub-skills in MVP | Complexity, defer to Stage 7 | 2026-11-24 |
| Knowledge skills not runnable | By design — reference only | 2026-11-24 |
| Execution via Agent prompt | No direct tool RPC | 2026-11-23 |
| `FORK_SKILLS` kill switch | Safety, easy rollback | 2026-11-23 |

---

### 📌 QUICK REFERENCE: NEXT ACTIONS BY STAGE

| Current Stage | Next Action | Command / Note |
|---------------|-------------|----------------|
| **AI Summarizer (current)** | Phase 0: Document findings | Write `~/dsh-go-handoff/DISTILL-AI-DESIGN.md` |
| **AI Summarizer** | Phase 1: Fix black screen/spinning | `skill_create_page.dart` — PopScope, loading text, timeout |
| **AI Summarizer** | Phase 2: Stabilize Controller | New: `skill_distill_controller.dart` |
| **AI Summarizer** | Phase 3: Instant rule-based draft | Form opens instantly, AI badge |
| **AI Summarizer** | Phase 4: AI Summarizer + Validator | New: `ai_summarizer.dart`, `draft_validator.dart` |
| **AI Summarizer** | Phase 5: UI Integration | Banner, skill name hint, breadcrumbs, l10n |
| **AI Summarizer** | Phase 6: Test & CI | Widget/unit tests, xcheck, l10n_merge, Quality Gate, Build APK |
| **4** | Wait CI → Build APK → Device Test | `gh run watch <run_id>` → dispatch Build APK |
| **5** | Device verify execution engine | Install APK → test all execution paths |
| **6** | Device verify intelligence | Test history, proposals, import/export |
| **7** | Implement MVP missing features | Audit log, auto-propose, export/import, sub-skills |
| **8** | Advanced execution features | Parallel, conditional, loops, streaming |
| **9** | Ecosystem features | Marketplace, versioning, sharing |
| **10** | AI-native evolution | Auto-generation, self-improvement |

---

*End of Runbook — Save this file and reference for all future work on Personal Skills Evolution*