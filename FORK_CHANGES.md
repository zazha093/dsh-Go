# FORK_CHANGES.md

**Fork:** zazha093/dsh-Go | **Upstream:** ccch1mneyyy/dsh-Go | **Branch:** thai/release
**Last Updated:** 2026-11-20

---

> **กฎ:** ทุกครั้งที่แก้ไขไฟล์ต้นฉบับ (upstream files) ต้องจดบันทึกในไฟล์นี้
> - ระบุ: Commit Hash, ไฟล์, บรรทัด (โดยประมาณ), เหตุผล/การเปลี่ยนแปลง
> - ไฟล์ที่เป็น fork-only (ไม่มีใน upstream): ไม่ต้องจด แต่ควรระบุไว้ในตารางแยก

---

## 1. สรุปการเปลี่ยนแปลงแบบ Overview

| หมวด | จำนวนไฟล์ | หมายเหตุ |
|------|-----------|---------|
| **Workflow/CI** | 6 ไฟล์ | build-apk.yml, ci.yml, weekly-upstream-check.yml, pr-gate.yml, goldens.yml, ios-* |
| **Thai L10N (ARB)** | 80 ไฟล์ | app/lib/l10n/parts/*_th.arb + generated catalogs |
| **Flutter/Dart Code** | 3 ไฟล์ | test/thai_locale_test.dart, plugin_widgets.dart, scan_th.py |
| **Config/Build** | 4 ไฟล์ | build.gradle.kts, AndroidManifest.xml, tooling/build-apk.sh, key.properties |
| **Documentation** | 2 ไฟล์ | THAI_FORK_GUIDE.md, FORK_CHANGES.md (this file) |
| **Tools** | 2 ไฟล์ | fork-tools/scan_th.py, fork-tools/README.md |

---

## 2. ประวัติการแก้ไขรายละเอียด (ตามลำดับเวลาเก่าไปใหม่)

### 2.1 Workflow/CI Changes

| Commit | ไฟล์ | บรรทัด | เหตุผล/การเปลี่ยนแปลง |
|--------|------|--------|----------------------|
| `c49111287` | `.github/workflows/build-apk.yml` | ทั้งไฟล์ | เพิ่ม keystore setup และ trigger สำหรับ branch `thai/release` |
| `afef57a5f` | `.github/workflows/build-apk.yml` | ~25-30 | แก้ YAML indentation สำหรับ heredoc (cat <<'EOF') |
| `637af17bd` | `.github/workflows/build-apk.yml` | ~35-40 | แก้ syntax `if:` condition ใช้ `env.VAR` แทน `secrets.*` โดยตรง |
| `31d78b55d` | `.github/workflows/build-apk.yml` | ~35-40 | แก้ `if:` condition ให้ใช้ env vars ให้ถูกต้อง |
| `4fa43d6ba` | `.github/workflows/build-apk.yml` | ~55 | เพิ่ม `mkdir -p app/android/keystore` (path ผิด - ควรเป็น app/android/app/keystore) |
| `aedce89dc` | `.github/workflows/build-apk.yml` | ~55 | แก้ path keystore ให้ถูกต้อง: `app/android/app/keystore/release.keystore` |
| `f595dfe62` | `.github/workflows/build-apk.yml` | ~150-160 | เปลี่ยน verify signature ใช้ `keytool` แทน `apksigner` |
| `c0545a2b5` | `.github/workflows/build-apk.yml` | ~125-130 | เพิ่ม step `Flutter analyze` ก่อน build APK |
| `8cb19f7fc` | `.github/workflows/ci.yml` | ~60-80 | **ลบ iOS/OHOS jobs** (ios_runtime, ohos_compile) ออกจาก `changes` job outputs และ filters เพื่อลด conflict sync |
| `8cb19f7fc` | `.github/workflows/ci.yml` | ~150 | เพิ่ม `--locale th` ใน `l10n_merge.py --check` |
| `098e21e49` | `.github/workflows/ci.yml` | ~150 | เพิ่ม `--locale th` ใน l10n checks (duplicate fix) |
| `e0c26f6bd` | `.github/workflows/weekly-upstream-check.yml` | ~15-25 | แก้ YAML syntax error (heredoc → echo commands) |
| `4d5251511` | `.github/workflows/weekly-upstream-check.yml` | ทั้งไฟล์ | สร้าง workflow ใหม่: cron weekly check upstream/main ahead |

### 2.2 Thai L10N (ARB Files) - app/lib/l10n/parts/

| Commit | ไฟล์ | บรรทัด | เหตุผล/การเปลี่ยนแปลง |
|--------|------|--------|----------------------|
| `d8e06ecf6` | 15 ไฟล์ *_th.arb | หลายจุด | **Polish Thai UI strings**: license key, placeholders, safe mode, live activity, plugins approval, pet names, workshop |
| `d8e06ecf6` | `hub_settings_licenses_th.arb` | ~5 | `สัญญาอ픈ซอร์ส` → `ใบอนุญาตโอเพนซอร์ส` (แก้ Korean mixed) |
| `d8e06ecf6` | `phone_safe_th.arb` | ~8 | `phoneSafeStartSettingsHint`: mixed EN/TH → proper Thai |
| `d8e06ecf6` | `live_th.arb` | 4 keys | 4 live activity strings: mixed EN/TH → proper Thai |
| `d8e06ecf6` | `plugins_th.arb` | 2 keys | `pluginsTurnComplete`, `pluginsApprovalDescription` → proper Thai |
| `d8e06ecf6` | `bots_th.arb` | 3 keys | `botsPetDeepy`, `botsPetWhaleGirl`, `botsPetImportHint` → proper Thai |
| `d8e06ecf6` | `workshop_th.arb` | 2 keys | `workshopTitle`, `workshopEntrySubtitle` → proper Thai |
| `d8e06ecf6` | 15 ไฟล์ | placeholder keys | **Restore placeholders**: `{โฮสต์}`→`{host}`, `{ที่อยู่}`→`{address}` (ห้ามแปล placeholder) |
| `74a1e89c5` | `companion_th.arb` | 37 keys | **Fix CJK**: 37 keys ที่มี Chinese chars → แทนที่ด้วย Thai translation ถูกต้อง |
| `461b2078a` | 9 ไฟล์ *_th.arb | หลายจุด | **Fix CJK**: bots, features, market, phone, plugslots, remote_upload, state, tavern, voice |
| `168449738` | `.gitignore` | root | เพิ่ม `app/lib/l10n/app_*.arb` เข้า .gitignore (generated catalogs) |

### 2.3 Flutter/Dart Code Changes

| Commit | ไฟล์ | บรรทัด | เหตุผล/การเปลี่ยนแปลง |
|--------|------|--------|----------------------|
| `95f4d1930` | `app/test/thai_locale_test.dart` | ~1-20 | **Fix flutter analyze**: เพิ่ม `import 'dart:ui'`, ใช้ `const Locale('th')`, แทนที่ getter ที่ไม่มี (`settingsTitle`→`tavernSettings`, `settingsAppearance`→`phoneRestrictedAdvanced`) |
| `c0545a2b5` | `app/lib/widgets/plugin_widgets.dart` | ~50-60 | เพิ่ม **Haptic feedback** ให้ `PluginInstallButton` |
| `098e21e49` | `fork-tools/scan_th.py` | ~85-90 | **Fix CJK regex**: `\u20000-\u2A6DF` (5-digit, invalid) → `[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF\u3400-\u4DBF\uF900-\uFAFF\u3000-\u303F\uFF00-\uFFEF]` |

### 2.4 Config/Build Changes

| Commit | ไฟล์ | บรรทัด | เหตุผล/การเปลี่ยนแปลง |
|--------|------|--------|----------------------|
| (initial) | `app/android/app/build.gradle.kts` | ~10-15 | `applicationId = "io.github.ccch1mneyyy.dsh_app.thai"` (suffix `.thai`) |
| (initial) | `app/android/app/src/main/AndroidManifest.xml` | ~5 | `android:label="DSH Go (Thai)"` (จาก "DSH Go (Thai Test)") |
| (initial) | `tooling/build-apk.sh` | - | Build script รองรับ keystore signing |
| (initial) | `app/android/key.properties` | - | Keystore config (generated by workflow) |

### 2.5 Documentation

| Commit | ไฟล์ | บรรทัด | เหตุผล/การเปลี่ยนแปลง |
|--------|------|--------|----------------------|
| `a942d5ab3` | `THAI_FORK_GUIDE.md` | หลายส่วน | อัปเดต SHA-256, part/key counts, checklist |
| `098e21e49` | `THAI_FORK_GUIDE.md` | หลายส่วน | เพิ่ม sync rules, PR wait policy, scan_th.py CJK fix |
| `4d5251511` | `THAI_FORK_GUIDE.md` | หลายส่วน | เพิ่ม weekly upstream check workflow |
| `a22723dcc` | `THAI_FORK_GUIDE.md` | หลายส่วน | เพิ่ม keystore verification, CI status, flutter analyze test fix |
| (now) | `FORK_CHANGES.md` | ทั้งไฟล์ | **สร้างใหม่**: บันทึกการเปลี่ยนแปลง fork-only ทั้งหมด |

### 2.6 Fork-Only Tools (ไฟล์ใหม่ ไม่อยู่ใน upstream)

| ไฟล์ | วัตถุประสงค์ |
|------|-------------|
| `fork-tools/scan_th.py` | Thai l10n scanner: ตรวจสอบ CJK, missing keys, mixed EN, caps, identical to EN |
| `fork-tools/README.md` | Documentation สำหรับ fork-tools |
| `fork-tools/scan_report.json` | Output จาก scan_th.py (generated, ไม่ commit) |

---

## 3. ไฟล์ที่ต้องระวังเมื่อ Sync กับ Upstream

> ไฟล์เหล่านี้มีการแก้ไข fork-only **ต้องเก็บไว้/ปรับใหม่หลัง sync ทุกครั้ง**

| ไฟล์ | การแก้ไขที่ต้องเก็บ |
|------|---------------------|
| `app/android/app/build.gradle.kts` | `applicationId` suffix `.thai` |
| `app/android/app/src/main/AndroidManifest.xml` | `android:label="DSH Go (Thai)"` |
| `.github/workflows/build-apk.yml` | **Fork version ทั้งไฟล์** (keystore, thai/release trigger, flutter analyze) |
| `.github/workflows/ci.yml` | **Reverted to upstream** (ไม่แก้แล้ว - ใช้ upstream version ตรงๆ) |
| `.github/workflows/weekly-upstream-check.yml` | **Fork-only workflow** (คงไว้) |
| `app/lib/l10n/parts/*_th.arb` | **80 Thai ARB files** (คงไว้ทั้งหมด) |
| `fork-tools/` | **Fork-only directory** (คงไว้ทั้งหมด) |
| `THAI_FORK_GUIDE.md` | **Fork-only guide** (คงไว้ อัปเดตตลอด) |
| `FORK_CHANGES.md` | **Fork-only log** (คงไว้ อัปเดตตลอด) |

---

## 4. Sync Procedure (สำหรับการ sync ขึ้นไป)

```bash
# 1. สร้าง branch sync จาก upstream/main
git fetch upstream main
git checkout -b sync-$(date +%Y%m%d) upstream/main

# 2. Apply fork customizations (cherry-pick หรือ apply manual)
#    - Thai ARB files (copy จาก thai/release)
#    - build.gradle.kts applicationId
#    - AndroidManifest.xml label
#    - .github/workflows/build-apk.yml (fork version)
#    - fork-tools/ directory
#    - THAI_FORK_GUIDE.md, FORK_CHANGES.md

# 3. Validate
python3 app/tool/l10n_merge.py --locale th --no-gen
python3 app/tool/l10n_merge.py --locale th --check
bash tooling/build-apk.sh --build-name <version>

# 4. Merge to thai/release
git checkout thai/release
git merge sync-$(date +%Y%m%d)
git push origin thai/release
```

---

## 5. การจดบันทึกการแก้ไขใหม่ (Template)

> **ใช้ template นี้ทุกครั้งที่แก้ไขไฟล์ต้นฉบับ**

```markdown
### [Date] Commit: <short-hash>
**File:** `<path/to/file>`
**Lines:** ~<line numbers>
**Reason:** <เหตุผลการเปลี่ยนแปลง>
**Change:** <รายละเอียดการเปลี่ยนแปลง>
```

---

*Generated and maintained by fork maintenance workflow. Update on every fork-only change.*