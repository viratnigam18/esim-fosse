# eSim 2.5 on Ubuntu 25.04 — Issue Register (Issue Log)

This document records all confirmed defects, architectural observations, and environmental constraints identified during the investigation of eSim 2.5 on Ubuntu 25.04 (Plucky Puffin), based on upstream commit `a77d6b9` (`installers` branch).

---

## Issue Summary Table

| Issue ID | Title | Status | Severity | Target File |
| :--- | :--- | :--- | :--- | :--- |
| **ESIM-001** | Unclosed `if` Block & Erroneous 22.04 Routing in `install-eSim.sh` | **STATIC** | Critical / Blocker | `Ubuntu/install-eSim.sh` |
| **ESIM-002** | Early Script Termination (`exit 0`) on Preinstalled KiCad 8 (H-01) | **STATIC** | Critical / High | `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh` |
| **ESIM-003** | KiCad Config Path Mismatch & Unsafe Uninstaller Symbol Deletion (H-02) | **STATIC** | High | `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh` |
| **ESIM-004** | Windows CRLF Line Endings in Shell Scripts | **PASS (Executed)** | High | All `.sh` scripts |
| **ESIM-005** | Fragile Package Pinning (`kicad=8.0.8+dfsg-1`) & Missing Non-Interactive Flags | **STATIC** | Medium | `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh` |
| **ESIM-006** | Python Virtualenv Isolation Missing System Packages for PyQt5 | **PASS (Executed)** | High | `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh` |
| **ESIM-007** | LLVM 20 Incompatibility & Missing 25.04 Dispatch in NGHDL (H-03) | **STATIC** | High | `install-eSim-25.04.sh` & NGHDL toolchain |
| **ESIM-008** | Ubuntu 25.04 End-of-Life (EOL) Package Archive 404 Recovery | **STATIC** | High | `install-eSim-25.04.sh` & system APT sources |

---

## Detailed Issue Records

### ESIM-001: Unclosed `if` Block & Erroneous 22.04 Routing in `install-eSim.sh`
* **Status**: STATIC (Syntax verified via `bash -n`)
* **Affected File**: `Ubuntu/install-eSim.sh`, lines 37–71
* **Upstream Code (`a77d6b9`)**:
  ```bash
  "22.04")
      if [[ "$FULL_VERSION" == "22.04.4" ]]; then
          SCRIPT="$SCRIPT_DIR/install-eSim-22.04.sh"
      else
          SCRIPT="$SCRIPT_DIR/install-eSim-23.04.sh"
      fi
      ;;
  ...
  if [[ -f "$SCRIPT" ]]; then
      echo "Running script: $SCRIPT $ARGUMENT"
      bash "$SCRIPT" "$ARGUMENT"
  echo "[eSim]" >> $config_dir/$config_file
  ...
  }
  ```
* **Failure / Observation**:
  1. `bash -n Ubuntu/install-eSim.sh` crashes with `syntax error near unexpected token '}'` on line 70 because `if [[ -f "$SCRIPT" ]]; then` lacks a closing `fi`.
  2. For Ubuntu 22.04, any release other than `22.04.4` (e.g., 22.04.1, 22.04.2, 22.04.3, 22.04.5) is routed incorrectly to `install-eSim-23.04.sh`.
* **Root Cause**: Incomplete merge during PR #414 where stray configuration lines were merged into `run_version_script` without closing `fi`, along with a fragile equality check on 22.04 point releases.
* **Exact Fix**:
  1. Set `"22.04") SCRIPT="$SCRIPT_DIR/install-eSim-22.04.sh" ;;` for all 22.04 releases.
  2. Closed conditional with `fi`, added exit code propagation, and preserved upstream 342-line architecture.
* **Test Evidence**: `bash -n Ubuntu/install-eSim.sh` passes with exit code 0.
* **Remaining Limitations**: Assumes supported distributions provide standard release metadata in `/etc/os-release`.

---

### ESIM-002: KiCad 8 Preinstalled Early Termination (H-01)
* **Status**: STATIC (Control-flow verified)
* **Affected File**: `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh`, lines 134–137
* **Upstream Code (`a77d6b9`)**:
  ```bash
  else
      echo "KiCad 8.0 is already installed."
      exit 0
  fi
  ```
* **Failure / Observation**: When KiCad 8 is already installed, calling `exit 0` terminates the parent installer process prematurely, skipping `copyKicadLibrary`, `installNghdl`, `installSky130Pdk`, and `createDesktopStartScript`.
* **Root Cause**: Process exit (`exit 0`) used instead of function return (`return 0`).
* **Exact Fix**: Replaced `exit 0` with `return 0` so control returns to the caller.
* **Test Evidence**: Control-flow inspection confirms subsequent functions execute upon function return.
* **Remaining Limitations**: Requires real VM execution with preinstalled KiCad 8 for full end-to-end integration proof.

---

### ESIM-003: KiCad Config Path Mismatch & Unsafe Uninstaller Deletion (H-02)
* **Status**: STATIC (Path logic verified)
* **Affected File**: `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh`, lines 234–243 & lines 417–421
* **Upstream Code (`a77d6b9`)**:
  ```bash
  # In copyKicadLibrary:
  cp kicadLibrary/template/sym-lib-table ~/.config/kicad/6.0/

  # In --uninstall:
  rm -rf $HOME/.config/kicad/6.0
  ```
* **Failure / Observation**:
  1. KiCad 8 on Ubuntu 25.04 reads from `~/.config/kicad/8.0/sym-lib-table`. Installing to `6.0` leaves KiCad 8 without eSim custom symbols.
  2. The uninstaller deleted entire configuration directories and symbol tables, wiping out user-defined libraries.
* **Root Cause**: Legacy hardcoded path to KiCad 6.0 and blanket file deletion without filtering eSim-owned entries.
* **Exact Fix**:
  1. In `copyKicadLibrary`: Target `~/.config/kicad/8.0/sym-lib-table`. If existing user table exists, back it up and merge eSim entries rather than overwriting.
  2. In `--uninstall`: Back up `sym-lib-table` and remove only lines matching `eSim` or `kicadLibrary`, preserving all user data.
* **Test Evidence**: Verified directory path resolution and grep-based filtering logic.
* **Remaining Limitations**: Users with custom KiCad table formatting should verify table syntax after automated merge.

---

### ESIM-004: Windows CRLF Line Endings in Shell Scripts
* **Status**: PASS (Executed and verified)
* **Affected Files**: `Ubuntu/install-eSim.sh`, `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh`
* **Upstream Code (`a77d6b9`)**: Files committed with CRLF `\r\n` line terminators.
* **Failure / Observation**: Linux Bash reports `syntax error near unexpected token $'{\r''` and `/bin/bash^M: bad interpreter`.
* **Root Cause**: Windows editor checkout and lack of repository `.gitattributes` or autocrlf normalization.
* **Exact Fix**: Converted modified files to UNIX LF (`\n`) and verified with `file`.
* **Test Evidence**: `file` confirms `Bourne-Again shell script, ASCII text executable` without CRLF.
* **Remaining Limitations**: Unmodified neighbouring scripts retain upstream line endings to prevent unnecessary repository churn.

---

### ESIM-005: Rigid Package Pinning & Missing Non-Interactive Flags
* **Status**: STATIC (Syntax verified)
* **Affected File**: `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh`, lines 154, 174
* **Upstream Code (`a77d6b9`)**:
  ```bash
  sudo apt-get install -y --no-install-recommends kicad=8.0.8+dfsg-1 kicad-footprints kicad-libraries kicad-symbols kicad-templates
  sudo apt install python3-virtualenv
  ```
* **Failure / Observation**: Pinning fails if the PPA increments revision (e.g. 8.0.8-2 or 8.0.9); `apt install` without `-y` hangs on unattended installation.
* **Root Cause**: Rigid package revision lock and omitted `-y` parameter.
* **Exact Fix**: Installed `kicad` without minor revision lock; added `-y` across all `apt install` invocations.
* **Test Evidence**: Command syntax verified.
* **Remaining Limitations**: Depends on KiCad PPA availability.

---

### ESIM-006: Virtual Environment Isolation Missing System Packages
* **Status**: PASS (Executed in Python 3.12 environment)
* **Affected File**: `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh`, lines 177, 220–224
* **Upstream Code (`a77d6b9`)**:
  ```bash
  virtualenv $config_dir/env
  pip3 install PyQt5
  ```
* **Failure / Observation**: `pip install PyQt5` on Python 3.12+ fails building from source because binary wheels are unavailable and SIP/Qt dev headers are missing.
* **Root Cause**: Virtual environment created isolated without `--system-site-packages`.
* **Exact Fix**: Added `--system-site-packages` to `virtualenv "$config_dir/env"`, enabling inheritance of system APT `python3-pyqt5`.
* **Test Evidence**: Python 3.12 runtime test confirms successful import of system PyQt5 inside venv.
* **Remaining Limitations**: Requires `python3-pyqt5` package to be installed on host system via APT.

---

### ESIM-007: LLVM 20 Incompatibility & Missing 25.04 Dispatch in NGHDL (H-03)
* **Status**: STATIC (Toolchain verified)
* **Affected Files**: `install-eSim-25.04.sh`, `nghdl/install-nghdl.sh`
* **Upstream Code (`a77d6b9`)**:
  Upstream `Ubuntu/REPORT.md` documented the LLVM 18 fix, but `install-eSim-25.04.sh` omitted it. In `nghdl.zip`, `install-nghdl.sh` had no case for 25.04, aborting with `Unsupported Ubuntu version: 25.04`.
* **Failure / Observation**: Default LLVM in 25.04 is 19/20, which breaks GHDL 4.1.0; `libcanberra-gtk-module` is obsolete in 25.04.
* **Root Cause**: GHDL supports LLVM $\le$ 18.1; NGHDL package predated Ubuntu 25.04.
* **Exact Fix**:
  1. Provision `llvm-18`, `llvm-18-dev`, `clang-18`, and `libcanberra-gtk3-module` without error suppression.
  2. Dynamically adapt `install-nghdl.sh` to route 25.04.
  3. Configure GHDL with `--with-llvm-config=/usr/bin/llvm-config-18`.
* **Test Evidence**: Script configuration logic and syntax verified.
* **Remaining Limitations**: Full GHDL compilation requires live VM build.

---

### ESIM-008: Ubuntu 25.04 End-of-Life (EOL) Package Archive 404 Recovery
* **Status**: STATIC (Syntax & safe rollback logic verified)
* **Affected File**: `Ubuntu/install-eSim-scripts/install-eSim-25.04.sh`, function `checkAndFixEolSources`
* **Upstream Code (`a77d6b9`)**: No EOL detection or recovery logic.
* **Failure / Observation**: On EOL releases, `archive.ubuntu.com` returns HTTP 404, causing all `apt-get install` commands to abort.
* **Root Cause**: Ubuntu 25.04 interim lifecycle ended on 15 January 2026.
* **Exact Fix**:
  Implemented user-consented, scoped migration routine:
  1. Prompts for explicit user confirmation before modifying system files.
  2. Only touches files referencing official Ubuntu mirrors (`archive.ubuntu.com` / `security.ubuntu.com`).
  3. Creates timestamped backups (`.bak.<timestamp>`).
  4. Validates repository update with automated rollback if update fails.
* **Test Evidence**: Bash syntax verified; safe rollback and consent guards confirmed.
* **Remaining Limitations**: Requires network connectivity to `old-releases.ubuntu.com`.
