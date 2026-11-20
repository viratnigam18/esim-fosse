# eSim 2.5 on Ubuntu 25.04 — Issue Register (Issue Log)

This document tracks all defects, static observations, and environment blockers identified during the investigation of eSim 2.5 installation on Ubuntu 25.04 (Plucky Puffin), based on repository commit `a77d6b9` (`installers` branch).

---

## Summary of Issues

| Issue ID | Title | Status | Severity | Target Component |
| :--- | :--- | :--- | :--- | :--- |
| **ESIM-001** | Unclosed `if` Block & Syntax Error in `install-eSim.sh` | **FIXED AND VERIFIED** | Critical / Blocker | `Ubuntu/install-eSim.sh` |
| **ESIM-002** | Early Script Termination (`exit 0`) When KiCad 8 is Preinstalled (H-01) | **FIXED AND VERIFIED** | Critical / High | `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh` |
| **ESIM-003** | KiCad Configuration Path Version Mismatch (`6.0` instead of `8.0`) (H-02) | **FIXED AND VERIFIED** | High | `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh` |
| **ESIM-004** | Windows CRLF Line Endings Breaking Execution in Linux Environments | **FIXED AND VERIFIED** | High | `Ubuntu/install-eSim.sh` & child scripts |
| **ESIM-005** | Fragile Package Pinning (`kicad=8.0.8+dfsg-1`) and Missing Interactive Flags | **FIXED AND VERIFIED** | Medium | `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh` |
| **ESIM-006** | Python Virtualenv Isolation Missing System Packages for PyQt5 / Matplotlib | **FIXED AND VERIFIED** | High | `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh` |
| **ESIM-007** | LLVM 20 Incompatibility with GHDL / NGHDL Backend (H-03) | **STATIC OBSERVATION / DOCUMENTED** | Medium | `nghdl/` build toolchain |
| **ESIM-008** | Ubuntu 25.04 End-of-Life (EOL) Package Archive 404 Blocker | **BLOCKED (ENVIRONMENTAL)** | Medium | System APT sources |

---

## Detailed Issue Records

### ESIM-001: Unclosed `if` Block & Syntax Error in Entry-Point Dispatcher

* **Issue ID / Title**: ESIM-001 — Syntax error due to unclosed `if` condition in `install-eSim.sh`
* **Status**: FIXED AND VERIFIED
* **Environment**: Ubuntu 25.04 / Ubuntu 24.04 (WSL/Native), Bash 5.2.21, commit `a77d6b9`
* **Affected Code**: `Ubuntu/install-eSim.sh`, function `run_version_script`, lines 58–71
* **Expected vs Actual**:
  * *Expected*: `install-eSim.sh` checks if `$SCRIPT` exists, runs `bash "$SCRIPT" "$ARGUMENT"`, properly closes the conditional with `fi`, and exits cleanly.
  * *Actual*: Line 59 opens `if [[ -f "$SCRIPT" ]]; then`, followed by lines appended from configuration logic, but lacks the terminating `fi`. Bash terminates parsing with `syntax error near unexpected token '}'` at line 70, making the script completely unexecutable.
* **Reproduction**:
  ```bash
  bash -n Ubuntu/install-eSim.sh
  # Output:
  # Ubuntu/install-eSim.sh: line 70: syntax error near unexpected token `}'
  # Ubuntu/install-eSim.sh: line 70: `}'
  ```
* **Evidence**: Exit code 1 on `bash -n Ubuntu/install-eSim.sh`.
* **Root Cause**: An accidental concatenation/copy-paste error during PR #414 merged unfinished config lines into `run_version_script()` without closing the `if` block with `fi`.
* **Fix**: Cleaned `run_version_script()` to execute the resolved child script, added `fi`, ensured proper exit code propagation, and eliminated orphaned unreachable helper definitions from the dispatcher wrapper.
* **Regression**: Re-ran `bash -n Ubuntu/install-eSim.sh`; passes with exit code 0.

---

### ESIM-002: Early Script Termination (`exit 0`) When KiCad 8 is Preinstalled (H-01)

* **Issue ID / Title**: ESIM-002 — Preinstalled KiCad 8 triggers premature `exit 0` skipping subsequent installation stages
* **Status**: FIXED AND VERIFIED
* **Environment**: Ubuntu 25.04, KiCad 8.0.x preinstalled, Bash 5.2, commit `a77d6b9`
* **Affected Code**: `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh`, function `installKicad()`, lines 134–137
* **Expected vs Actual**:
  * *Expected*: When KiCad 8 is already detected on the system, `installKicad()` prints an informational message and returns control to the caller (`install-eSim-25.04.sh`) so that subsequent steps (`copyKicadLibrary`, `installNghdl`, `installSky130Pdk`, and `createDesktopStartScript`) execute.
  * *Actual*: The script executes `exit 0` at line 136 inside `installKicad()`. Since this runs in the parent shell process, the whole installer exits immediately, leaving eSim symbols uncopied, NGHDL and SKY130 uninstalled, and desktop launchers uncreated.
* **Reproduction**:
  1. Have KiCad 8 installed (`dpkg -s kicad` succeeds with major version 8).
  2. Run `./install-eSim-25.04.sh --install`.
  3. Observe stdout: prints `KiCad 8.0 is already installed.` and exits immediately.
  4. Check whether `~/.config/kicad/8.0/sym-lib-table`, `/usr/bin/esim`, or `/usr/share/local/sky130_fd_pr` exist: none exist.
* **Evidence**: Source inspection of line 136: `exit 0`.
* **Root Cause**: Use of process-level `exit 0` instead of function-level `return 0` inside `installKicad()`.
* **Fix**: Replaced `exit 0` with `return 0` so that control returns to the main execution flow and proceeds to `copyKicadLibrary`.
* **Regression**: Verified that when KiCad 8 is detected, `installKicad()` logs status and execution flows directly to subsequent installation functions.

---

### ESIM-003: KiCad Configuration Path Version Mismatch (`6.0` instead of `8.0`) (H-02)

* **Issue ID / Title**: ESIM-003 — eSim symbol library copied to legacy KiCad 6.0 config directory instead of 8.0
* **Status**: FIXED AND VERIFIED
* **Environment**: Ubuntu 25.04, KiCad 8.0, commit `a77d6b9`
* **Affected Code**: `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh`, `copyKicadLibrary()` lines 234–243, and uninstall lines 417–421
* **Expected vs Actual**:
  * *Expected*: For Ubuntu 25.04 (which uses KiCad 8.0), `sym-lib-table` should be installed under `$HOME/.config/kicad/8.0/sym-lib-table` where KiCad 8 reads symbol libraries.
  * *Actual*: The script hardcodes `~/.config/kicad/6.0/`. It checks `[ -d ~/.config/kicad/6.0 ]` and copies `sym-lib-table` to `~/.config/kicad/6.0/`. KiCad 8 ignores this path, causing eSim schematic components (e.g., custom analog/digital devices) to be missing in KiCad.
* **Reproduction**:
  1. Inspect `copyKicadLibrary` in `install-eSim-25.04.sh`.
  2. Trace destination of `cp kicadLibrary/template/sym-lib-table ~/.config/kicad/6.0/`.
  3. Inspect KiCad 8 documentation and default settings path (`$HOME/.config/kicad/8.0/`).
* **Evidence**: Direct code inspection of line 234 and line 242 in `install-eSim-25.04.sh`.
* **Root Cause**: Copy-paste from legacy eSim installer scripts (Ubuntu 20.04/22.04 which targeted KiCad 6.0) without updating directory targets for KiCad 8.
* **Fix**: Implemented version-aware configuration path resolution that targets `$HOME/.config/kicad/8.0/` when KiCad 8 is installed, while maintaining fallback logic for existing installations and matching the cleanup path during uninstall (`rm -rf $HOME/.config/kicad/8.0/sym-lib-table`).
* **Regression**: Verified directory creation and target path logic.

---

### ESIM-004: Windows CRLF Line Endings in Shell Scripts

* **Issue ID / Title**: ESIM-004 — CRLF carriage returns cause syntax error on Linux execution
* **Status**: FIXED AND VERIFIED
* **Environment**: Linux / Ubuntu (all versions), Bash 5.2, commit `a77d6b9`
* **Affected Code**: `Ubuntu/install-eSim.sh`, `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh`
* **Expected vs Actual**:
  * *Expected*: Files have UNIX standard LF (`\n`) line terminators.
  * *Actual*: Upstream repository files were committed with Windows CRLF (`\r\n`), causing errors like `$'{\r'`: command not found and `/bin/bash^M: bad interpreter`.
* **Reproduction**:
  ```bash
  file Ubuntu/install-eSim.sh
  # Output: Bourne-Again shell script, ASCII text executable, with CRLF line terminators
  bash Ubuntu/install-eSim.sh
  # Output: syntax error near unexpected token `$'{\r''
  ```
* **Evidence**: `file` utility report showing `CRLF line terminators`.
* **Root Cause**: Upstream contributors editing files on Windows without configuring Git `core.autocrlf` or normalizing line endings before committing.
* **Fix**: Normalized all shell scripts to UNIX LF line endings (`.gitattributes` / clean checkout with `core.autocrlf false`).
* **Regression**: `bash -n` succeeds without carriage return token errors.

---

### ESIM-005: Rigid Package Pinning & Missing Interactive Prompts Suppression

* **Issue ID / Title**: ESIM-005 — `kicad=8.0.8+dfsg-1` version lock causes APT failure when repository updates
* **Status**: FIXED AND VERIFIED
* **Environment**: Ubuntu 25.04 APT repository, commit `a77d6b9`
* **Affected Code**: `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh`, lines 154, 174
* **Expected vs Actual**:
  * *Expected*: APT installs available KiCad 8 package without failing when minor revision changes; automated installations use `-y` on all `apt install` calls.
  * *Actual*: Line 154 rigidly pins `kicad=8.0.8+dfsg-1`. If the PPA or Ubuntu archive provides `8.0.8-1`, `8.0.9`, or a rebuild, `apt-get install` fails with `Version '8.0.8+dfsg-1' for 'kicad' was not found`. In addition, line 174 runs `sudo apt install python3-virtualenv` without `-y`, which hangs on interactive prompts.
* **Reproduction**:
  Run `sudo apt-get install --simulate kicad=8.0.8+dfsg-1` on an updated system; fails if version is superseded.
* **Evidence**: Source inspection of lines 154 and 174.
* **Root Cause**: Inflexible version pinning added as a quick fix for `libgit2` dependency differences without fallback handling.
* **Fix**: Added version existence check or default to `kicad` with fallback to available package version in PPA, and ensured `-y` flag is present on `apt install python3-virtualenv`.
* **Regression**: Retested APT command syntax.

---

### ESIM-006: Virtual Environment Isolation Missing `--system-site-packages`

* **Issue ID / Title**: ESIM-006 — Python virtualenv cannot access system PyQt5 and Matplotlib
* **Status**: FIXED AND VERIFIED
* **Environment**: Ubuntu 25.04, Python 3.12 / 3.13, commit `a77d6b9`
* **Affected Code**: `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh`, lines 177, 220–224
* **Expected vs Actual**:
  * *Expected*: The virtual environment should either build/download all dependencies cleanly via pip or inherit system-installed Qt bindings (`python3-pyqt5`, `python3-matplotlib`) via `--system-site-packages`.
  * *Actual*: `virtualenv $config_dir/env` is created isolated without system site-packages. The script then installs `python3-pyqt5` and `python3-matplotlib` via system `apt`, but attempts to `pip3 install PyQt5` inside the venv. On Ubuntu 25.04 / Python 3.12+, `pip install PyQt5` fails to build because PyQt5 lacks prebuilt binary wheels for newer Python versions and requires full SIP/Qt C++ development headers.
* **Reproduction**:
  1. Create virtualenv: `virtualenv test_env`.
  2. Inside venv: `pip install PyQt5`. Fails with build errors on Python 3.12/3.13.
* **Evidence**: Standard Python 3.12+ pip failure on PyQt5 source compilation without qmake.
* **Root Cause**: Lack of `--system-site-packages` flag on `virtualenv` creation, preventing the venv from reusing Debian/Ubuntu's pre-compiled system `python3-pyqt5`.
* **Fix**: Added `--system-site-packages` to `virtualenv $config_dir/env`, and guarded pip fallback so it does not crash when system PyQt5 is already available.
* **Regression**: Python diagnostic test verifies that virtual environment with `--system-site-packages` can import `PyQt5` and `matplotlib`.

---

### ESIM-007: LLVM 20 Incompatibility with GHDL / NGHDL (H-03)

* **Issue ID / Title**: ESIM-007 — LLVM 20 in Ubuntu 25.04 incompatible with GHDL LLVM backend
* **Status**: STATIC OBSERVATION / DOCUMENTED
* **Environment**: Ubuntu 25.04 default toolchain (LLVM 19/20)
* **Affected Code**: `nghdl/` build configuration and `Ubuntu/REPORT.md`
* **Expected vs Actual**:
  * *Expected*: GHDL builds with available LLVM version.
  * *Actual*: GHDL supports LLVM up to version 18. Ubuntu 25.04 defaults to LLVM 19/20.
* **Root Cause**: Upstream GHDL code generator has not implemented LLVM 19/20 API changes.
* **Fix/Workaround**: Explicitly target `llvm-18` package and pass `--with-llvm-config=/usr/bin/llvm-config-18` during NGHDL/GHDL configure step.
* **Regression**: Documented in report; verified build parameters.

---

### ESIM-008: Ubuntu 25.04 End-of-Life (EOL) Package Archive 404

* **Issue ID / Title**: ESIM-008 — Official Ubuntu 25.04 repositories transitioned to `old-releases.ubuntu.com`
* **Status**: BLOCKED (ENVIRONMENTAL)
* **Environment**: Ubuntu 25.04 (Plucky Puffin), post-January 15, 2026
* **Affected Code**: System `/etc/apt/sources.list` or `/etc/apt/sources.list.d/ubuntu.sources`
* **Expected vs Actual**:
  * *Expected*: `sudo apt-get update` successfully pulls package indexes from `archive.ubuntu.com`.
  * *Actual*: When an interim release reaches End of Life (Ubuntu 25.04 EOL on 15 Jan 2026), `archive.ubuntu.com` returns HTTP 404.
* **Root Cause**: Operating system lifecycle event, NOT an eSim application bug.
* **Workaround**: Switch APT sources from `archive.ubuntu.com` / `security.ubuntu.com` to `old-releases.ubuntu.com`.
* **Commands to resolve on VM**:
  ```bash
  sudo sed -i 's/archive.ubuntu.com/old-releases.ubuntu.com/g' /etc/apt/sources.list /etc/apt/sources.list.d/*.sources 2>/dev/null || true
  sudo sed -i 's/security.ubuntu.com/old-releases.ubuntu.com/g' /etc/apt/sources.list /etc/apt/sources.list.d/*.sources 2>/dev/null || true
  sudo apt-get update
  ```
