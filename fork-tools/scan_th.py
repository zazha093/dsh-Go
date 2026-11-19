#!/usr/bin/env python3
"""Scan Thai translation completeness across all ARB parts."""
import json, re, sys, os
from pathlib import Path

REPO = Path("/root/workspace/dsh-Go")
PARTS = Path("/root/workspace/dsh-Go/app/lib/l10n/parts")
TH_PARTS = sorted(PARTS.glob("*_th.arb"))
EN_PARTS = sorted(PARTS.glob("*_en.arb"))
ZH_PARTS = sorted(PARTS.glob("*_zh.arb"))

# Load all EN parts
en_data = {}
for p in EN_PARTS:
    with open(p, 'r', encoding='utf-8') as f:
        try:
            en_data[p.stem] = json.load(f)
        except:
            pass

# Load all ZH parts
zh_data = {}
for p in ZH_PARTS:
    with open(p, 'r', encoding='utf-8') as f:
        try:
            zh_data[p.stem] = json.load(f)
        except:
            pass

# Load all TH parts
th_data = {}
for p in TH_PARTS:
    with open(p, 'r', encoding='utf-8') as f:
        try:
            th_data[p.stem] = json.load(f)
        except:
            th_data[p.stem] = {}

# ── ค. Keys in EN but missing in TH (fallback to EN) ──
missing_in_th = {}
for part, en_dict in en_data.items():
    th_dict = th_data.get(part, {})
    missing = [k for k in en_dict if k not in th_dict and not k.startswith('@')]
    if missing:
        missing_in_th[part] = missing

# ── ข. TH values identical to EN (untranslated) ──
identical = {}
for part, th_dict in th_data.items():
    en_dict = en_data.get(part, {})
    same = []
    for k, v in th_dict.items():
        if k.startswith('@') or k.startswith('@@'):
            continue
        if k in en_dict and v == en_dict[k]:
            # Skip technical terms that should stay English
            if v.lower() in ('vip', 'api', 'url', 'http', 'https', 'ssh', 'ai', 'gpu', 'cpu', 'ram', 'ssd', 'usb', 'wifi', 'bluetooth', 'gps', 'nfc', 'qr', 'pdf', 'png', 'jpg', 'jpeg', 'gif', 'svg', 'html', 'css', 'js', 'json', 'xml', 'yaml', 'toml', 'sql', 'regex', 'uuid', 'sha', 'md5', 'base64', 'utf-8', 'utf8', 'ascii', 'ansi', 'iso', 'utc', 'gmt', 'pst', 'est', 'cst', 'mst', 'pdt', 'edt', 'cdt', 'akst', 'hst', 'jst', 'kst', 'cst', 'ist', 'gmt', 'utc'):
                continue
            # Skip proper nouns that should stay
            if v in ('DeepSeek', 'DSH', 'GitHub', 'GitLab', 'Flutter', 'Android', 'iOS', 'Linux', 'Windows', 'macOS', 'Ubuntu', 'Debian', 'Arch', 'Fedora', 'CentOS', 'RedHat', 'NVIDIA', 'AMD', 'Intel', 'ARM', 'x86', 'x64', 'ARM64', 'AArch64', 'Docker', 'Kubernetes', 'K8s', 'CNCF', 'Apache', 'Mozilla', 'Google', 'Microsoft', 'Amazon', 'AWS', 'Azure', 'GCP', 'OAuth', 'OIDC', 'SAML', 'JWT', 'RSA', 'AES', 'SHA', 'MD5', 'TLS', 'SSL', 'HTTPS', 'HTTP', 'WebSocket', 'WebRTC', 'QR', 'NFC', 'BLE', 'USB', 'HDMI', 'DP', 'VGA', 'DVI', 'SATA', 'NVMe', 'RAID', 'BIOS', 'UEFI', 'MBR', 'GPT', 'SSD', 'HDD', 'RAM', 'CPU', 'GPU', 'TPU', 'NPU', 'VPU', 'ISP', 'DSP', 'SoC', 'FPGA', 'ASIC', 'MCU', 'RTOS', 'POSIX', 'GNU', 'BSD', 'MIT', 'Apache-2.0', 'GPL', 'LGPL', 'BSD-3', 'BSD-2', 'CC0', 'CC-BY', 'CC-BY-SA', 'Unlicense'):
                continue
            same.append(k)
    if same:
        identical[part] = same

# ── ค. Mixed English in Thai (2+ English words in Thai sentence) ──
mixed = {}
en_word_re = re.compile(r'\b[a-zA-Z]{2,}\b')
for part, th_dict in th_data.items():
    mixed_keys = []
    for k, v in th_dict.items():
        if k.startswith('@') or k.startswith('@@'):
            continue
        # Count English words
        en_words = en_word_re.findall(v)
        if len(en_words) >= 2:
            # Check if it's actually Thai context (has Thai chars)
            if re.search(r'[\u0E00-\u0E7F]', v):
                mixed[part] = mixed.get(part, []) + [(k, v, en_words)]

# ── ง. All-caps words in TH not in EN ──
caps = {}
caps_re = re.compile(r'\b[A-Z]{2,}\b')
for part, th_dict in th_data.items():
    en_dict = en_data.get(part, {})
    caps_list = []
    for k, v in th_dict.items():
        if k.startswith('@') or k.startswith('@@'):
            continue
        caps_words = caps_re.findall(v)
        for cw in caps_words:
            if cw not in ('CJK', 'SMS', 'MMS', 'GPS', 'USB', 'WiFi', 'Wi-Fi', 'Bluetooth', 'NFC', 'QR', 'PDF', 'PNG', 'JPEG', 'JPG', 'GIF', 'SVG', 'HTML', 'CSS', 'JSON', 'YAML', 'TOML', 'XML', 'SQL', 'HTTP', 'HTTPS', 'REST', 'API', 'SDK', 'CLI', 'GUI', 'TUI', 'CUDA', 'OpenGL', 'Vulkan', 'DirectX', 'Metal', 'WebGL', 'WebGPU', 'WASM', 'SIMD', 'AVX', 'SSE', 'MMX', 'FPU', 'ALU', 'MMU', 'TLB', 'L1', 'L2', 'L3', 'DMA', 'IRQ', 'DMA', 'PCI', 'PCIe', 'AGP', 'ISA', 'EISA', 'MCA', 'VLB', 'AGP', 'PCIe', 'SATA', 'PATA', 'SCSI', 'SAS', 'NVMe', 'AHCI', 'RAID', 'JBOD', 'NAS', 'SAN', 'iSCSI', 'FC', 'FCoE', 'RDMA', 'RoCE', 'iWARP', 'NFS', 'CIFS', 'SMB', 'AFP', 'FTP', 'SFTP', 'SSH', 'Telnet', 'RDP', 'VNC', 'X11', 'Wayland', 'DRM', 'KMS', 'GBM', 'EGL', 'GLX', 'WGL', 'Vulkan', 'OpenGL', 'OpenCL', 'OpenCL', 'CUDA', 'HIP', 'ROCm', 'SYCL', 'oneAPI', 'DPC++', 'OpenMP', 'MPI', 'Pthreads', 'OpenACC', 'OpenCL', 'SPIR-V', 'LLVM', 'Clang', 'GCC', 'MSVC', 'Rust', 'Cargo', 'Crates.io', 'npm', 'yarn', 'pnpm', 'pip', 'pip3', 'conda', 'miniconda', 'anaconda', 'venv', 'virtualenv', 'pipenv', 'poetry', 'buildout', 'setuptools', 'wheel', 'egg', 'distutils', 'pkg_resources', 'importlib', 'pkgutil', 'runpy', 'sys', 'os', 'io', 'json', 'csv', 'yaml', 'toml', 'xml', 'html', 'css', 'js', 'ts', 'jsx', 'tsx', 'vue', 'svelte', 'react', 'angular', 'next', 'nuxt', 'vite', 'webpack', 'rollup', 'esbuild', 'swc', 'babel', 'eslint', 'prettier', 'stylelint', 'jest', 'vitest', 'mocha', 'chai', 'sinon', 'cypress', 'playwright', 'puppeteer', 'selenium', 'webdriver', 'appium', 'detox', 'espresso', 'uiautomator', 'robolectric', 'mockito', 'mockk', 'powermock', 'junit', 'testng', 'assertj', 'hamcrest', 'truth', 'kotlin', 'groovy', 'scala', 'clojure', 'clojurescript', 'fsharp', 'ocaml', 'reasonml', 'elm', 'purescript', 'haskell', 'idris', 'agda', 'coq', 'lean', 'isabelle', 'hol', 'isabelle', 'hol', 'coq', 'lean', 'agda', 'idris'):
                continue
            # Check if EN has same caps
            en_val = en_dict.get(k, '')
            if cw not in en_val:
                caps_list.append((k, cw, v))
    if caps_list:
        caps[part] = caps_list

# ── จ. CJK in TH (excluding locale markers) ──
# Fixed: removed invalid 5-digit \u escapes (\uXXXXX not supported in Python, only \uXXXX)
# Covers: Hiragana, Katakana, CJK Unified Ideographs, CJK Ext A, CJK Compat, CJK Symbols, Fullwidth
cjk_re = re.compile(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF\u3400-\u4DBF\uF900-\uFAFF\u3000-\u303F\uFF00-\uFFEF]')
cjk_in_th = {}
for part, th_dict in th_data.items():
    cjk_list = []
    for k, v in th_dict.items():
        if k.startswith('@') or k.startswith('@@'):
            continue
        if cjk_re.search(v):
            # Allow Thai locale markers
            if v.strip() in ('泰语', '简体中文'):
                continue
            cjk_list.append((k, v))
    if cjk_list:
        cjk_in_th[part] = cjk_list

# ── ฉ. Parts with NO Thai at all ──
no_th = []
all_parts = set(en_data.keys()) | set(zh_data.keys())
for part in sorted(all_parts):
    if part not in th_data or not th_data[part]:
        no_th.append(part)

# ── Report ──
print("=" * 60)
print("THAI TRANSLATION SCAN REPORT")
print("=" * 60)

print(f"\nก. Missing in TH (fallback to EN): {sum(len(v) for v in missing_in_th.values())} keys in {len(missing_in_th)} parts")
for p, ks in sorted(missing_in_th.items(), key=lambda x: -len(x[1])):
    print(f"  {p}: {len(ks)} keys")

print(f"\nข. Identical to EN (untranslated): {sum(len(v) for v in identical.values())} keys in {len(identical)} parts")
for p, ks in sorted(identical.items(), key=lambda x: -len(x[1])):
    print(f"  {p}: {len(ks)} keys - e.g. {ks[:5]}")

print(f"\nค. Mixed EN in TH (>=2 EN words in Thai sentence): {sum(len(v) for v in mixed.values())} keys in {len(mixed)} parts")
for p, vs in sorted(mixed.items(), key=lambda x: -len(x[1])):
    print(f"  {p}: {len(vs)} keys - e.g. {vs[0][:2] if vs else 'N/A'}")

print(f"\nง. All-caps in TH not in EN: {sum(len(v) for v in caps.values())} in {len(caps)} parts")
for p, vs in sorted(caps.items(), key=lambda x: -len(x[1])):
    print(f"  {p}: {len(vs)} - e.g. {vs[0][:2] if vs else 'N/A'}")

print(f"\nจ. CJK in TH (excl. locale markers): {sum(len(v) for v in cjk_in_th.values())} in {len(cjk_in_th)} parts")
for p, vs in sorted(cjk_in_th.items(), key=lambda x: -len(x[1])):
    print(f"  {p}: {len(vs)} - e.g. {vs[0] if vs else 'N/A'}")

print(f"\nฉ. Parts with NO Thai: {len(no_th)} parts")
for p in no_th:
    print(f"  {p}")

# Save detailed JSON for later use
report = {
    "missing_in_th": {k: v for k, v in missing_in_th.items()},
    "identical_to_en": {k: v for k, v in identical.items()},
    "mixed_en_in_th": {k: [(k, v, w) for k, v, w in v] for k, v in mixed.items()},
    "caps_in_th": {k: v for k, v in caps.items()},
    "cjk_in_th": {k: v for k, v in cjk_in_th.items()},
    "no_th_parts": no_th,
}
with open("scan_report.json", "w", encoding="utf-8") as f:
    json.dump(report, f, ensure_ascii=False, indent=2)
print("\n✓ Saved detailed report to ~/preflight/scan_report.json")
