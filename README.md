# eSim Packaging & Installer Suite

This repository contains the packaging and installation suite for the eSim EDA Suite across supported platforms.

---

## Supported Platforms

* **Ubuntu Linux**: Ubuntu 22.04 LTS, 23.04, 24.04 LTS, and **Ubuntu 25.04 (Plucky Puffin)**
* **Arch Linux**
* **Fedora Linux**
* **macOS**
* **Microsoft Windows**

---

## Ubuntu 25.04 Installation & Upgradation (Task 4)

For detailed engineering reports and verification results on Ubuntu 25.04, refer to:
* **Engineering Report**: [docs/REPORT.md](docs/REPORT.md)
* **Issue Register**: [docs/ISSUE_LOG.md](docs/ISSUE_LOG.md)
* **Test Matrix**: [docs/TEST_MATRIX.md](docs/TEST_MATRIX.md)
* **Baseline Audit**: [docs/AUDIT.md](docs/AUDIT.md)

### Running the Installer

```bash
# Clone the repository on the installers branch
git clone --branch installers https://github.com/viratnigam18/esim-fosse.git
cd esim-fosse

# Run the installer entry point
./Ubuntu/install-eSim.sh --install

# Or run the Ubuntu 25.04 installer directly
./Ubuntu/install-eSim-scripts/install-eSim-25.04.sh --install
```

### Running the Diagnostic Tool

A safe, read-only system diagnostic helper is provided to inspect your environment, KiCad installation, symbol tables, and prerequisites:

```bash
# Print formatted human-readable terminal summary
python3 tools/esim_diagnostics.py

# Output machine-readable JSON
python3 tools/esim_diagnostics.py --json
```

### Running Unit Tests

```bash
# Execute the test suite
python3 -m unittest discover -s tests -v
```

---

## General Packaging Documentation

1. Refer to [Version_Change.md](Version_Change.md) for version release instructions.
2. Refer to [Ubuntu/README.md](Ubuntu/README.md) for Ubuntu packaging.
3. Refer to [Windows/README.md](Windows/README.md) for Windows packaging.
