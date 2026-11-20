# eSim 2.5 on Ubuntu 25.04 — Test Matrix & Verification Status

This document defines the test matrix, distinguishing between:
* **PASS**: Actually executed and verified in the available environment.
* **STATIC**: Verified through source inspection, control-flow tracing, and Bash syntax validation (`bash -n`).
* **BLOCKED**: Requires an isolated, root-enabled Ubuntu 25.04 VM or live GUI display not present in this workspace.

---

## 1. Automated Python Unit Tests (`tests/test_esim_diagnostics.py`)

Execution Command: `python3 -m unittest discover -s tests -v`
Total Test Methods: **9** | Passed: **9** | Failed: **0** | Status: **PASS (100% OK)**

| # | Test Method Name | Scope / Target | Result | Status |
| :---: | :--- | :--- | :--- | :---: |
| 1 | `test_get_os_info_structure` | Validates OS inspection dictionary schema and standard keys | OK | **PASS** |
| 2 | `test_ubuntu_25_04_detection` | Validates accurate detection of Ubuntu 25.04 (Plucky) `/etc/os-release` | OK | **PASS** |
| 3 | `test_get_python_info` | Inspects Python version, executable, venv detection, and package imports | OK | **PASS** |
| 4 | `test_check_system_commands` | Verifies external toolchain binary availability checks (`bash`, `kicad`, etc.) | OK | **PASS** |
| 5 | `test_inspect_kicad_mocked` | Tests KiCad version detection and user config directory parsing | OK | **PASS** |
| 6 | `test_inspect_esim_environment_mocked` | Verifies eSim `config.ini`, launcher script, and desktop shortcut inspection | OK | **PASS** |
| 7 | `test_run_diagnostics_aggregation` | Validates complete diagnostic report structure | OK | **PASS** |
| 8 | `test_json_serialization` | Confirms diagnostic report serializes into valid JSON schema | OK | **PASS** |
| 9 | `test_format_text_report` | Confirms terminal formatted summary renders without exceptions | OK | **PASS** |

---

## 2. Integration & Regression Scenarios (T01 – T10)

| Scenario ID | Test Description | Expected Behavior | Actual Behavior / Verification Result | Status |
| :---: | :--- | :--- | :--- | :---: |
| **T01** | Ubuntu 25.04 Detection & Dispatch | Entry point `install-eSim.sh` detects `VERSION_ID="25.04"` and selects `install-eSim-25.04.sh` | Clean dispatch without syntax errors; 22.04 and 25.04 version cases pass `bash -n`. | **STATIC** |
| **T02** | Clean Install / Fresh System (No KiCad) | Installer provisions KiCad 8 PPA and completes core packages | Full package installation requires disposable Ubuntu 25.04 VM with root access. | **BLOCKED** |
| **T03** | KiCad 8 Preinstalled Flow (H-01) | When KiCad 8 is installed, script must NOT exit; downstream functions must execute | Replaced `exit 0` with `return 0` in `installKicad()`; control flow verified. | **STATIC** |
| **T04** | KiCad Symbol Path Resolution (H-02) | eSim `sym-lib-table` registered in active KiCad 8 directory (`~/.config/kicad/8.0/`) | Target path resolved to `8.0/sym-lib-table` with user data preservation and backup. | **STATIC** |
| **T05** | LLVM 18 / GHDL Dependency Stage (H-03) | Script provisions `llvm-18`, `llvm-18-dev`, `clang-18` and verifies binary availability | Package commands specified without error suppression; toolchain check verified. | **STATIC** |
| **T06** | NGHDL and SKY130 PDK Extraction | Archive unpacking, permission changes, and toolchain builds | Privilege-requiring file operations in `/usr/share/local` require isolated VM. | **BLOCKED** |
| **T07** | Launcher Generation & GUI Launch | `/usr/bin/esim` wrapper created; application window renders | Requires desktop GUI display (X11 / Wayland) inside Ubuntu 25.04 VM. | **BLOCKED** |
| **T08** | Idempotency / Repeat Install & Uninstall Safety | Repeated installation or uninstall preserves unrelated user KiCad libraries | Safe merge on install and filtered removal of eSim-only lines on uninstall verified. | **STATIC** |
| **T09** | Diagnostic Utility Automated Test Suite | Unit tests for system diagnostic tool run successfully | 9 of 9 unit tests passed across Windows and Linux runtimes. | **PASS** |
| **T10** | Diagnostic Utility CLI Output | Diagnostic tool emits formatted terminal summary and JSON schema (`--json`) | CLI flags executed; valid terminal table and JSON structure captured. | **PASS** |

---

## 3. Manual Reproduction Instructions for Blocked VM Tests

For FOSSEE mentors and evaluators running an isolated Ubuntu 25.04 VM:

```bash
# 1. Clone repository on installers branch
git clone --branch installers https://github.com/viratnigam18/esim-fosse.git
cd esim-fosse

# 2. Run diagnostic tool before installation
python3 tools/esim_diagnostics.py

# 3. Execute installation (T02, T03, T04, T05, T06)
./Ubuntu/install-eSim.sh --install

# 4. Verify GUI launch (T07)
esim

# 5. Verify uninstallation safety (T08)
./Ubuntu/install-eSim.sh --uninstall
```
