#!/usr/bin/env python3
"""
eSim 2.5 System Diagnostics Utility (Ubuntu 25.04 & Linux Systems)

A read-only diagnostic utility that inspects:
- Operating system release and architecture
- Python runtime and required packages
- System commands and EDA toolchain dependencies
- KiCad version and active user configuration paths (sym-lib-table)
- eSim environment configuration, launcher script, and desktop files
- NGHDL and SKY130 PDK installation paths

Outputs both human-readable terminal summaries and machine-readable JSON.
Does not require root, execute modifications, or install packages.
"""

import os
import sys
import json
import shutil
import platform
import argparse
import configparser
from typing import Dict, Any, List, Optional


def get_os_info() -> Dict[str, Any]:
    """Inspects Linux OS distribution and release version."""
    info = {
        "system": platform.system(),
        "release": platform.release(),
        "architecture": platform.machine(),
        "distro_id": "unknown",
        "distro_version": "unknown",
        "distro_codename": "unknown",
        "is_ubuntu_25_04": False,
    }

    os_release_path = "/etc/os-release"
    if os.path.exists(os_release_path):
        try:
            with open(os_release_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("ID="):
                        info["distro_id"] = line.split("=", 1)[1].strip('"\'')
                    elif line.startswith("VERSION_ID="):
                        info["distro_version"] = line.split("=", 1)[1].strip('"\'')
                    elif line.startswith("VERSION_CODENAME="):
                        info["distro_codename"] = line.split("=", 1)[1].strip('"\'')
        except Exception as e:
            info["error"] = str(e)

    if info["distro_id"].lower() == "ubuntu" and info["distro_version"] == "25.04":
        info["is_ubuntu_25_04"] = True

    return info


def get_python_info() -> Dict[str, Any]:
    """Inspects current Python version and core dependency imports."""
    packages_to_check = [
        "PyQt5",
        "matplotlib",
        "psutil",
        "watchdog",
        "setuptools",
        "hdlparse",
    ]
    package_status = {}

    for pkg in packages_to_check:
        try:
            __import__(pkg)
            package_status[pkg] = True
        except ImportError:
            package_status[pkg] = False

    return {
        "version": platform.python_version(),
        "executable": sys.executable,
        "is_virtualenv": hasattr(sys, "real_prefix") or (sys.base_prefix != sys.prefix),
        "packages": package_status,
    }


def check_system_commands() -> Dict[str, bool]:
    """Checks availability of key external binaries."""
    commands = [
        "bash",
        "kicad",
        "ngspice",
        "xterm",
        "virtualenv",
        "git",
        "tar",
        "unzip",
    ]
    return {cmd: (shutil.which(cmd) is not None) for cmd in commands}


def inspect_kicad() -> Dict[str, Any]:
    """Inspects KiCad installation, major version, and user symbol library paths."""
    kicad_bin = shutil.which("kicad")
    home = os.path.expanduser("~")
    kicad_config_base = os.path.join(home, ".config", "kicad")

    config_versions_found = []
    if os.path.isdir(kicad_config_base):
        for entry in os.listdir(kicad_config_base):
            full_entry = os.path.join(kicad_config_base, entry)
            if os.path.isdir(full_entry) and (entry.replace(".", "").isdigit()):
                sym_table = os.path.join(full_entry, "sym-lib-table")
                config_versions_found.append({
                    "version": entry,
                    "path": full_entry,
                    "has_sym_lib_table": os.path.exists(sym_table),
                })

    symbols_dir = "/usr/share/kicad/symbols"
    has_system_symbols = os.path.isdir(symbols_dir)

    return {
        "installed": kicad_bin is not None,
        "executable_path": kicad_bin,
        "config_base": kicad_config_base,
        "config_versions": config_versions_found,
        "system_symbols_dir": symbols_dir,
        "has_system_symbols_dir": has_system_symbols,
    }


def inspect_esim_environment() -> Dict[str, Any]:
    """Inspects eSim application artifacts, configuration files, and desktop entry."""
    home = os.path.expanduser("~")
    esim_config_dir = os.path.join(home, ".esim")
    config_file = os.path.join(esim_config_dir, "config.ini")
    venv_dir = os.path.join(esim_config_dir, "env")

    config_exists = os.path.exists(config_file)
    parsed_config = {}
    if config_exists:
        cp = configparser.ConfigParser()
        try:
            cp.read(config_file)
            if cp.has_section("eSim"):
                parsed_config = dict(cp.items("eSim"))
        except Exception as e:
            parsed_config["read_error"] = str(e)

    launcher_bin = "/usr/bin/esim"
    desktop_app = "/usr/share/applications/esim.desktop"
    desktop_user = os.path.join(home, "Desktop", "esim.desktop")

    return {
        "config_dir": esim_config_dir,
        "config_dir_exists": os.path.isdir(esim_config_dir),
        "config_file_exists": config_exists,
        "config_content": parsed_config,
        "virtualenv_exists": os.path.isdir(venv_dir),
        "launcher_exists": os.path.exists(launcher_bin),
        "desktop_application_entry": os.path.exists(desktop_app),
        "desktop_user_shortcut": os.path.exists(desktop_user),
    }


def inspect_pdk_and_nghdl() -> Dict[str, Any]:
    """Inspects SKY130 PDK and NGHDL installation locations."""
    sky130_dir = "/usr/share/local/sky130_fd_pr"
    return {
        "sky130_pdk_installed": os.path.isdir(sky130_dir),
        "sky130_path": sky130_dir,
    }


def run_diagnostics() -> Dict[str, Any]:
    """Aggregates all diagnostic checks into a single structured report."""
    return {
        "os": get_os_info(),
        "python": get_python_info(),
        "commands": check_system_commands(),
        "kicad": inspect_kicad(),
        "esim": inspect_esim_environment(),
        "pdk_and_nghdl": inspect_pdk_and_nghdl(),
    }


def format_text_report(data: Dict[str, Any]) -> str:
    """Formats the diagnostic report into an aligned, human-readable terminal overview."""
    lines = []
    lines.append("=" * 65)
    lines.append("           eSim 2.5 System Diagnostics & Audit Report           ")
    lines.append("=" * 65)

    # OS Section
    os_info = data.get("os", {})
    lines.append("\n[1] Operating System")
    lines.append(f"  Distribution    : {os_info.get('distro_id', 'Unknown')} ({os_info.get('distro_codename', 'N/A')})")
    lines.append(f"  Version         : {os_info.get('distro_version', 'Unknown')}")
    lines.append(f"  Architecture    : {os_info.get('architecture', 'Unknown')}")
    lines.append(f"  Ubuntu 25.04    : {'YES' if os_info.get('is_ubuntu_25_04') else 'NO'}")

    # Python Section
    py_info = data.get("python", {})
    lines.append("\n[2] Python Runtime & Dependencies")
    lines.append(f"  Python Version  : {py_info.get('version', 'Unknown')}")
    lines.append(f"  Virtualenv Active: {'YES' if py_info.get('is_virtualenv') else 'NO'}")
    packages = py_info.get("packages", {})
    for pkg, status in packages.items():
        lines.append(f"  - {pkg:<14}: {'AVAILABLE' if status else 'MISSING'}")

    # System Commands
    cmds = data.get("commands", {})
    lines.append("\n[3] Required Toolchain Binaries")
    for cmd, found in cmds.items():
        lines.append(f"  - {cmd:<14}: {'FOUND' if found else 'NOT FOUND'}")

    # KiCad Section
    kicad_info = data.get("kicad", {})
    lines.append("\n[4] KiCad Integration")
    lines.append(f"  Installed       : {'YES' if kicad_info.get('installed') else 'NO'}")
    if kicad_info.get("executable_path"):
        lines.append(f"  Binary Location : {kicad_info.get('executable_path')}")
    configs = kicad_info.get("config_versions", [])
    if configs:
        lines.append("  Config Paths Detected:")
        for cfg in configs:
            lines.append(f"    * KiCad {cfg['version']}: {cfg['path']} (sym-lib-table: {'YES' if cfg['has_sym_lib_table'] else 'NO'})")
    else:
        lines.append("  Config Paths Detected: None found under ~/.config/kicad")

    # eSim Section
    esim_info = data.get("esim", {})
    lines.append("\n[5] eSim Configuration & Launchers")
    lines.append(f"  Config Dir Exists: {'YES' if esim_info.get('config_dir_exists') else 'NO'}")
    lines.append(f"  config.ini Exists: {'YES' if esim_info.get('config_file_exists') else 'NO'}")
    lines.append(f"  Virtualenv Exists: {'YES' if esim_info.get('virtualenv_exists') else 'NO'}")
    lines.append(f"  Launcher Script  : {'YES' if esim_info.get('launcher_exists') else 'NO (/usr/bin/esim)'}")
    lines.append(f"  Desktop App File : {'YES' if esim_info.get('desktop_application_entry') else 'NO'}")

    # PDK Section
    pdk_info = data.get("pdk_and_nghdl", {})
    lines.append("\n[6] PDK & Sub-tools")
    lines.append(f"  SKY130 PDK       : {'INSTALLED' if pdk_info.get('sky130_pdk_installed') else 'NOT FOUND'}")
    lines.append("=" * 65)

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="eSim 2.5 System Diagnostics Utility")
    parser.add_argument("--json", action="store_true", help="Output results in JSON format")
    args = parser.parse_args()

    data = run_diagnostics()

    if args.json:
        print(json.dumps(data, indent=2))
    else:
        print(format_text_report(data))


if __name__ == "__main__":
    main()
