# Personal Skills Feature - Testing Checklist

> **Target Version:** feat/fix-skill-crash branch  
> **Last Updated:** 2025-11-22  
> **Scope:** Personal Skills (Chat → Save as Skill → SkillCreatePage → SkillsPage → SkillDetailPage → Edit)

---

## 1. ขั้นตอนการเปิดหน้า "สร้างสกิล" จากหน้าแชท

### 1.1 เส้นทางหลัก (Happy Path)
1. เปิดแอป dsh-Go → เข้าสู่หน้าแชท (ChatScreen)
2. ส่งข้อความใดๆ ให้ AI (หรือมีข้อความ AI ตอบกลับอยู่แล้ว)
3. **กดค้าง (Long-press)** ที่ข้อความตอบกลับของ AI (Assistant Message)
4. เมนู Bottom Sheet จะขึ้นมา → เลือก **"บันทึกเป็นสกิล" (Save as Skill)**
5. ต้องเห็น: **SkillCreatePage** เปิดขึ้นมาพร้อมข้อมูล Pre-filled จากข้อความที่เลือก

### 1.2 เส้นทางทางเลือก (Alternative Entry Points)
| จุดเข้า | วิธีเปิด | ความคาดหวัง |
|----------|----------|-------------|
| หน้า Skills (Tab) | กดปุ่ม **+** (FAB หรือ AppBar) | SkillCreatePage ว่างเปล่า (New Skill) |
| SkillDetailPage | กดไอคอน **Edit** (ดินสอ) | SkillCreatePage Pre-filled ด้วยข้อมูล Skill นั้น |
| การกลั่นจาก Session | ผ่านเมนู Distill (ถ้ามี) | SkillCreatePage Pre-filled จาก Session |

### 1.3 Checklist การเปิดหน้า
- [ ] หน้าเปิดภายใน < 1 วินาที (ไม่ค้าง)
- [ ] Keyboard ไม่ขึ้นอัตโนมัติ (รอ User กดช่องกรอก)
- [ ] AppBar แสดง Title ให้ถูกต้อง: "สร้างสกิล" / "บันทึกจากข้อความ" / "แก้ไขสกิล"
- [ ] ปุ่ม X (Close) และ Cancel ทำงานได้
- [ ] ไม่มี Error/Exception ใน Console (flutter logs)

---

## 2. ขั้นตอนการทดสอบกดยกเลิก/บันทึก/กากบาท (Close/Cancel/Save/Back)

### 2.1 ปุ่ม X (AppBar Leading - Close)
| การทดสอบ | ผลลัพธ์ที่คาดหวัง |
|------------|-------------------|
| กด X ขณะฟอร์มว่าง | กลับหน้าก่อนหน้า (Chat/SkillsPage) ไม่มี Dialog ยืนยัน |
| กด X ขณะกรอกข้อมูลบางส่วน | กลับหน้าก่อนหน้า **ทันที** (ไม่มี Prompt "Save changes?") |
| กด X ระหว่าง Loading (`_isLoading = true`) | **ไม่สามารถกดได้** (ปุ่ม disabled/hidden) |

### 2.2 ปุ่ม Cancel (Bottom Bar)
| การทดสอบ | ผลลัพธ์ที่คาดหวัง |
|------------|-------------------|
| กด Cancel ขณะฟอร์มว่าง | กลับหน้าก่อนหน้า |
| กด Cancel ขณะกรอกข้อมูลบางส่วน | กลับหน้าก่อนหน้า **ทันที** (ไม่มี Prompt) |
| กด Cancel ระหว่าง Loading | **ไม่สามารถกดได้** |

### 2.3 ปุ่ม Save (FilledButton)
| สถานการณ์ | ผลลัพธ์ที่คาดหวัง |
|------------|-------------------|
| ฟอร์มถูกต้อง (Required fields ครบ) | Loading → Success Snackbar → **Pop กลับหน้าก่อนหน้า** |
| ฟอร์มไม่ถูกต้อง (ชื่อว่าง) | แสดง Error ใต้ TextField, **อยู่หน้าเดิม** |
| Save แล้วกด Back เร็วเกินไป | ไม่ Crash, State สม่ำเสมอ (mounted check) |
| Save สำเร็จ → กลับไป SkillsPage | Skill ใหม่ปรากฏในรายการทันที |

### 2.4 System Back Gesture / Hardware Back Button (Android)
| การทดสอบ | ผลลัพธ์ที่คาดหวัง |
|------------|-------------------|
| Swipe Back / กดปุ่ม Back ขณะฟอร์มว่าง | Pop กลับหน้าก่อนหน้า |
| Swipe Back ขณะกรอกข้อมูล | Pop กลับหน้าก่อนหน้า (ไม่มี Prompt) |
| Swipe Back ระหว่าง Loading | **ไม่ Pop** (canPop = false) |
| Back ซ้ำเร็ว (Double back) | **ไม่ Double-pop** (PopScope กันไว้) |

### 2.4.1 สิ่งที่ต้องสังเกต (Critical Observations)
- [ ] **Keyboard ดิ้งลงก่อน Pop** (FocusManager.unfocus เรียกก่อน Navigator.pop)
- [ ] **ไม่มี Double-pop** (Navigator stack ไม่ว่างเปล่า)
- [ ] **ไม่มี Black Screen Freeze** (UI responsive ตลอด)
- [ ] **mounted check** ทุกจุดก่อน Navigator.pop / setState / ScaffoldMessenger

---

## 3. ขั้นตอนการทดสอบฟอร์ม (Form Validation & Pre-filled Data)

### 3.1 ฟิลด์ที่มีในฟอร์ม
| ฟิลด์ | Required | Type | หมายเหตุ |
|-------|----------|------|----------|
| **ชื่อสกิล (Name)** | ✅ | TextField | ≤ 60 chars |
| **คำอธิบาย (Description)** | ❌ | TextField (multiline) | ≤ 200 chars |
| **เป้าหมาย (Goal)** | ✅ | TextField (multiline) | ≤ 300 chars |
| **ขั้นตอน (Steps)** | ✅ | TextField (multiline) | 1 บรรทัด = 1 step |
| **เงื่อนไข (Constraints)** | ❌ | TextField (multiline) | 1 บรรทัด = 1 constraint |
| **เครื่องมือที่ต้องการ (Tools)** | ❌ | TextField | คั่นด้วย comma |
| **User Inputs** | ❌ | Dynamic List | เพิ่ม/ลบได้ |

### 3.2 การทดสอบ Pre-filled Data (จาก Chat → Save as Skill)
| ฟิลด์ | ข้อมูลที่คาดหวังจาก Draft | เกณฑ์ Pass |
|-------|---------------------------|------------|
| **Name** | บรรทัดแรกที่มีความหมาย (≤60 chars) | ไม่ว่าง, ไม่เกิน 60 chars |
| **Goal** | เนื้อหาหลักของข้อความ | สะท้อนเจตนาของ User |
| **Steps** | แยกเป็นขั้นตอนจาก tool calls / คำสั่ง | แต่ละบรรทัด = 1 step |
| **Tools** | จาก `draftTools` หรือ detect จากข้อความ | comma-separated, ไม่ซ้ำ |
| **Constraints** | (ว่างหรือจาก heuristics) | ถ้ามี ต้องสมเหตุสมผล |

### 3.3 Validation Rules
| Test Case | Expected Behavior |
|-----------|-------------------|
| Name ว่าง | Error "กรุณาใส่ชื่อสกิล" / Save disabled |
| Name > 60 chars | Truncate หรือ Error |
| Steps ว่าง | Error / Save disabled (ถ้า Required) |
| Tools มีเครื่องมือไม่รู้จัก | ยอมรับ (แค่ string) |
| Special chars ในทุกฟิลด์ | ยอมรับ (ไม่ crash) |

---

## 4. สิ่งที่ต้องรายงานกลับมา ถ้าเจอ Error

### 4.1 ระดับ Critical (ต้อง Fix ทันที)
| Error Pattern | สิ่งที่ต้องรายงาน |
|---------------|-------------------|
| **Black Screen Freeze** | 1. เส้นทางที่ทำให้เกิด (Steps to reproduce)<br>2. Device/OS version<br>3. flutter logs (รัน `flutter logs` คัดลอกทั้งหมด)<br>4. Stack trace (ถ้ามี) |
| **Double-pop / Navigator Error** | 1. Stack trace เต็ม<br>2. Navigator state ก่อน/หลัง (debugPrint)<br>3. Widget tree ที่ PopScope อยู่ |
| **Data Loss** | 1. ข้อมูลที่หาย (Skill ไหน, ฟิลด์ไหน)<br>2. Steps ก่อนเกิด<br>5. SharedPreferences dump (ถ้าได้) |

### 4.2 ระดับ High (Regression)
| Error Pattern | สิ่งที่ต้องรายงาน |
|---------------|-------------------|
| **Flutter Analyze Error** | 1. ไฟล์ + บรรทัดที่ Error<br>2. Error message เต็ม<br>3. Commit hash ที่เกิด |
| **Widget Test Fail** | 1. Test name ที่ fail<br>2. Expected vs Actual<br>3. Screenshot (ถ้า UI) |
| **Build APK Fail** | 1. Gradle task ที่ fail<br>2. Error log ส่วนท้าย 50 บรรทัด |

### 4.3 ระดับ Medium (UX/Logic)
| Issue | สิ่งที่ต้องรายงาน |
|-------|-------------------|
| Pre-filled data ผิด | 1. Input ข้อความต้นฉบับ<br>2. ข้อมูลที่ได้จริง vs คาดหวัง |
| Validation ไม่ทำงาน | 1. Input ที่ทดสอบ<br>2. ผลลัพธ์จริง vs คาดหวัง |
| Keyboard ไม่ dismiss | 1. จุดที่เกิด (ปุ่มไหน)<br>2. Device/Keyboard type |

### 4.4 Format รายงานแนะนำ (Copy-Paste Ready)

```markdown
## Bug Report: [Short Title]

**Severity:** Critical / High / Medium / Low
**Branch:** feat/fix-skill-crash
**Commit:** `git rev-parse --short HEAD`
**Device:** [Device model, Android version]
**Flutter:** `flutter --version`

### Steps to Reproduce
1. [Step 1]
2. [Step 2]
3. [Step 3]

### Expected vs Actual
- **Expected:** ...
- **Actual:** ...

### Logs / Stack Trace
```
[paste full logs here]
```

### Additional Context
- Screenshots: [attach if UI]
- Workaround: [if any]
```

---

## 5. Test Matrix Summary (Quick Reference)

| Feature Area | Manual Tests | Automated Tests | CI Gate |
|--------------|--------------|-----------------|---------|
| Chat → SkillCreatePage | ✅ Required | `skill_navigation_integration_test.dart` | flutter analyze |
| X / Cancel / Save / Back | ✅ Required | ✅ Covered | flutter analyze + test |
| Form Validation | ✅ Required | ✅ Covered | flutter test |
| Pre-filled Data Accuracy | ✅ Required | Partial | Manual |
| System Back / PopScope | ✅ Required | ✅ Covered | flutter analyze |
| Keyboard Dismiss | ✅ Required | ❌ (Hard to test) | Manual |
| SkillDetailPage Edit Flow | ✅ Required | ✅ Covered | flutter test |
| SkillsPage Navigation | ✅ Required | ❌ | Manual |

---

## 6. Debug Tips (สำหรับ Developer)

```bash
# ดู logs แบบ realtime
flutter logs

# รัน analyze แบบ strict
flutter analyze --fatal-infos

# รัน test แบบ verbose
flutter test test/skills/skill_navigation_integration_test.dart -v

# ดู Navigator stack (debug)
# ในโค้ด: Navigator.debugDumpFocusTree()
```

---

> **หมายเหตุ:** Checklist นี้ครอบคลุม Test Cases หลักสำหรับ PR `feat/fix-skill-crash` หากพบ Case ใหม่ ให้อัปเดตไฟล์นี้ด้วย