#!/usr/bin/env python3
"""
Unit tests for eSim 2.5 System Diagnostics Utility.
"""

import os
import sys
import json
import unittest
from unittest.mock import patch, mock_open

# Add project root and tools directory to path
current_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(current_dir)
tools_dir = os.path.join(project_root, "tools")
sys.path.insert(0, tools_dir)

import esim_diagnostics


class TestESimDiagnostics(unittest.TestCase):

    def test_get_os_info_structure(self):
        """Verifies OS info dict contains all required keys."""
        info = esim_diagnostics.get_os_info()
        self.assertIn("system", info)
        self.assertIn("release", info)
        self.assertIn("architecture", info)
        self.assertIn("distro_id", info)
        self.assertIn("distro_version", info)
        self.assertIn("is_ubuntu_25_04", info)

    @patch("os.path.exists")
    @patch("builtins.open", new_callable=mock_open, read_data='NAME="Ubuntu"\nID=ubuntu\nVERSION_ID="25.04"\nVERSION_CODENAME=plucky\n')
    def test_ubuntu_25_04_detection(self, mock_file, mock_exists):
        """Verifies correct parsing of Ubuntu 25.04 os-release."""
        mock_exists.return_value = True
        info = esim_diagnostics.get_os_info()
        self.assertEqual(info["distro_id"], "ubuntu")
        self.assertEqual(info["distro_version"], "25.04")
        self.assertEqual(info["distro_codename"], "plucky")
        self.assertTrue(info["is_ubuntu_25_04"])

    def test_get_python_info(self):
        """Verifies python version inspection returns valid structure."""
        py_info = esim_diagnostics.get_python_info()
        self.assertIn("version", py_info)
        self.assertIn("executable", py_info)
        self.assertIn("is_virtualenv", py_info)
        self.assertIn("packages", py_info)
        self.assertIsInstance(py_info["packages"], dict)

    def test_check_system_commands(self):
        """Verifies command availability checks return boolean flags."""
        cmds = esim_diagnostics.check_system_commands()
        self.assertIn("bash", cmds)
        self.assertIn("kicad", cmds)
        self.assertIsInstance(cmds["bash"], bool)

    @patch("shutil.which")
    @patch("os.path.isdir")
    @patch("os.path.exists")
    @patch("os.listdir")
    def test_inspect_kicad_mocked(self, mock_listdir, mock_exists, mock_isdir, mock_which):
        """Verifies KiCad inspector parses version directories correctly."""
        mock_which.return_value = "/usr/bin/kicad"
        mock_isdir.return_value = True
        mock_listdir.return_value = ["8.0", "6.0"]
        mock_exists.return_value = True

        result = esim_diagnostics.inspect_kicad()
        self.assertTrue(result["installed"])
        self.assertEqual(result["executable_path"], "/usr/bin/kicad")
        versions = [cfg["version"] for cfg in result["config_versions"]]
        self.assertIn("8.0", versions)
        self.assertIn("6.0", versions)

    @patch("os.path.exists")
    @patch("os.path.isdir")
    def test_inspect_esim_environment_mocked(self, mock_isdir, mock_exists):
        """Verifies eSim environment inspector structure."""
        mock_isdir.return_value = True
        mock_exists.return_value = False

        env_info = esim_diagnostics.inspect_esim_environment()
        self.assertIn("config_dir", env_info)
        self.assertIn("config_file_exists", env_info)
        self.assertIn("virtualenv_exists", env_info)
        self.assertIn("launcher_exists", env_info)

    def test_run_diagnostics_aggregation(self):
        """Verifies complete diagnostics aggregator."""
        report = esim_diagnostics.run_diagnostics()
        self.assertIn("os", report)
        self.assertIn("python", report)
        self.assertIn("commands", report)
        self.assertIn("kicad", report)
        self.assertIn("esim", report)
        self.assertIn("pdk_and_nghdl", report)

    def test_json_serialization(self):
        """Verifies diagnostic output serializes to valid JSON."""
        report = esim_diagnostics.run_diagnostics()
        json_str = json.dumps(report)
        self.assertIsInstance(json_str, str)
        deserialized = json.loads(json_str)
        self.assertEqual(deserialized["os"]["system"], report["os"]["system"])

    def test_format_text_report(self):
        """Verifies formatting function outputs non-empty text table."""
        report = esim_diagnostics.run_diagnostics()
        text = esim_diagnostics.format_text_report(report)
        self.assertIn("eSim 2.5 System Diagnostics & Audit Report", text)
        self.assertIn("[1] Operating System", text)
        self.assertIn("[4] KiCad Integration", text)


if __name__ == "__main__":
    unittest.main()
