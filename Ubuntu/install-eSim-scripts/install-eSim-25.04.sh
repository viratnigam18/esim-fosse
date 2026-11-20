#!/bin/bash
#=============================================================================
#          FILE: install-eSim-25.04.sh
#
#         USAGE: ./install-eSim-25.04.sh --install
#                            OR
#                ./install-eSim-25.04.sh --uninstall
#
#   DESCRIPTION: Installation script for eSim EDA Suite on Ubuntu 25.04
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#       AUTHORS: Fahim Khan, Rahul Paknikar, Saurabh Bansode,
#                Sumanto Kar, Partha Singha Roy, Harsha Narayana P,
#                Jayanth Tatineni, Anshul Verma
#  ORGANIZATION: eSim Team, FOSSEE, IIT Bombay
#       CREATED: Wednesday 15 July 2015 15:26
#      REVISION: Friday 20 November 2026 22:45
#=============================================================================

# All variables go here
config_dir="$HOME/.esim"
config_file="config.ini"
eSim_Home=$(pwd)
ngspiceFlag=0

## All Functions go here

error_exit()
{
    echo -e "\n\nError! Kindly resolve above error(s) and try again."
    echo -e "\nAborting Installation...\n"
    exit 1
}

function checkAndFixEolSources
{
    echo "Checking APT repository reachability for Ubuntu 25.04..."
    # Check if official Ubuntu archive mirrors return 404
    set +e
    apt_check=$(sudo apt-get update 2>&1)
    set -e

    if echo "$apt_check" | grep -qE "(archive\.ubuntu\.com|security\.ubuntu\.com).*404"; then
        echo ""
        echo "================================================================="
        echo "NOTICE: Ubuntu 25.04 reached official End-of-Life on 15 Jan 2026."
        echo "Official packages have been archived to old-releases.ubuntu.com."
        echo "================================================================="
        read -r -p "Migrate official Ubuntu mirrors to old-releases.ubuntu.com? (yes/no): " eol_consent
        if [[ ! "$eol_consent" =~ ^([Yy][Ee][Ss]|[Yy])$ ]]; then
            echo "Skipping repository migration. Proceeding with existing sources..."
            return 0
        fi

        backup_ts=$(date +%Y%m%d_%H%M%S)
        modified_files=()

        # Update /etc/apt/sources.list if it references standard ubuntu mirrors
        if [ -f /etc/apt/sources.list ] && grep -qE "archive\.ubuntu\.com|security\.ubuntu\.com" /etc/apt/sources.list; then
            sudo cp /etc/apt/sources.list "/etc/apt/sources.list.bak.${backup_ts}"
            sudo sed -i 's|http://\(.*\).ubuntu.com/ubuntu|http://old-releases.ubuntu.com/ubuntu|g' /etc/apt/sources.list
            sudo sed -i 's|https://\(.*\).ubuntu.com/ubuntu|https://old-releases.ubuntu.com/ubuntu|g' /etc/apt/sources.list
            modified_files+=("/etc/apt/sources.list")
        fi

        # Update official Ubuntu sources under /etc/apt/sources.list.d/ (e.g. ubuntu.sources)
        for src in /etc/apt/sources.list.d/*.sources; do
            if [ -f "$src" ] && grep -qE "archive\.ubuntu\.com|security\.ubuntu\.com" "$src"; then
                sudo cp "$src" "${src}.bak.${backup_ts}"
                sudo sed -i 's|http://\(.*\).ubuntu.com/ubuntu|http://old-releases.ubuntu.com/ubuntu|g' "$src"
                sudo sed -i 's|https://\(.*\).ubuntu.com/ubuntu|https://old-releases.ubuntu.com/ubuntu|g' "$src"
                modified_files+=("$src")
            fi
        done

        echo "Validating repository migration..."
        set +e
        sudo apt-get update -y
        update_status=$?
        set -e

        if [ $update_status -ne 0 ]; then
            echo "Error: apt update failed after migration. Rolling back repository sources..."
            for f in "${modified_files[@]}"; do
                if [ -f "${f}.bak.${backup_ts}" ]; then
                    sudo cp "${f}.bak.${backup_ts}" "$f"
                    echo "Restored $f from backup."
                fi
            done
            return 1
        else
            echo "Repository migration verified successfully."
        fi
    else
        echo "APT repository sources are functional."
    fi
}

function createConfigFile
{
    # Creating config.ini file and adding configuration information
    # Check if config file is present
    if [ -d "$config_dir" ]; then
        rm -f "$config_dir/$config_file" && touch "$config_dir/$config_file"
    else
        mkdir -p "$config_dir" && touch "$config_dir/$config_file"
    fi

    echo "[eSim]" >> "$config_dir/$config_file"
    echo "eSim_HOME = $eSim_Home" >> "$config_dir/$config_file"
    echo "LICENSE = %(eSim_HOME)s/LICENSE" >> "$config_dir/$config_file"
    echo "KicadLib = %(eSim_HOME)s/library/kicadLibrary.tar.xz" >> "$config_dir/$config_file"
    echo "IMAGES = %(eSim_HOME)s/images" >> "$config_dir/$config_file"
    echo "VERSION = %(eSim_HOME)s/VERSION" >> "$config_dir/$config_file"
    echo "MODELICA_MAP_JSON = %(eSim_HOME)s/library/ngspicetoModelica/Mapping.json" >> "$config_dir/$config_file"
}

function installNghdl
{
    echo "Installing NGHDL..........................."

    target_zip=""
    if [ -f "nghdl.zip" ]; then
        target_zip="nghdl.zip"
    elif [ -f "MacOS/nghdl.zip" ]; then
        target_zip="MacOS/nghdl.zip"
    fi

    if [ -z "$target_zip" ]; then
        echo "nghdl.zip not found. Skipping NGHDL extraction..."
        return 0
    fi

    if command -v unzip >/dev/null 2>&1; then
        unzip -o "$target_zip"
    else
        echo "unzip command not found; using python3 zipfile fallback..."
        python3 -m zipfile -e "$target_zip" .
    fi

    if [ ! -d "nghdl" ]; then
        echo "NGHDL folder not found after extraction. Skipping..."
        return 0
    fi

    cd nghdl/ || return 1
    chmod +x install-nghdl.sh

    # Adapt NGHDL dispatcher for Ubuntu 25.04
    if [ -f "install-nghdl.sh" ] && ! grep -q '"25.04"' install-nghdl.sh; then
        echo "Configuring NGHDL dispatcher for Ubuntu 25.04..."
        sed -i 's/"24.04")/"24.04" | "25.04")/g' install-nghdl.sh
    fi

    # Adapt NGHDL child script for Ubuntu 25.04 toolchain requirements:
    # 1. libcanberra-gtk3-module replacing obsolete libcanberra-gtk-module
    # 2. llvm-18, llvm-18-dev, clang-18 replacing generic llvm
    # 3. --with-llvm-config=/usr/bin/llvm-config-18
    for child in install-nghdl-scripts/install-nghdl-24.04.sh install-nghdl-scripts/install-nghdl-25.04.sh; do
        if [ -f "$child" ]; then
            sed -i 's/libcanberra-gtk-module libcanberra-gtk3-module/libcanberra-gtk3-module/g' "$child"
            sed -i 's/apt install -y llvm llvm-dev/apt install -y llvm-18 llvm-18-dev clang-18/g' "$child"
            sed -i 's/--with-llvm-config=\/usr\/bin\/llvm-config/--with-llvm-config=\/usr\/bin\/llvm-config-18/g' "$child"
        fi
    done

    if [ -f "install-nghdl-scripts/install-nghdl-24.04.sh" ] && [ ! -f "install-nghdl-scripts/install-nghdl-25.04.sh" ]; then
        cp install-nghdl-scripts/install-nghdl-24.04.sh install-nghdl-scripts/install-nghdl-25.04.sh
    fi

    # Do not trap on error of any command. Let NGHDL script handle its own errors.
    trap "" ERR

    ./install-nghdl.sh --install       # Install NGHDL

    # Set trap again to error_exit function to exit on errors
    trap error_exit ERR

    ngspiceFlag=1
    cd ../
}

function installSky130Pdk
{
    echo "Installing SKY130 PDK......................"

    pdk_archive=""
    if [ -f "library/sky130_fd_pr.tar.xz" ]; then
        pdk_archive="library/sky130_fd_pr.tar.xz"
    elif [ -f "sky130_fd_pr.tar.xz" ]; then
        pdk_archive="sky130_fd_pr.tar.xz"
    fi

    if [ -z "$pdk_archive" ]; then
        echo "SKY130 archive not found. Skipping PDK extraction..."
        return 0
    fi

    # Extract SKY130 PDK
    tar -xJf "$pdk_archive"

    # Remove any previous sky130-fd-pr instance, if any
    sudo rm -rf /usr/share/local/sky130_fd_pr

    # Copy SKY130 library
    echo "Copying SKY130 PDK........................."

    sudo mkdir -p /usr/share/local/
    sudo mv sky130_fd_pr /usr/share/local/

    # Change ownership from root to the user
    sudo chown -R "$USER:$USER" /usr/share/local/sky130_fd_pr/
}

function installKicad
{
    echo "Installing KiCad..........................."

    # Detect Ubuntu version
    ubuntu_version=$(lsb_release -rs 2>/dev/null || echo "25.04")

    # Define KiCad PPAs based on Ubuntu version
    if [[ "$ubuntu_version" == "24.04" || "$ubuntu_version" == "25.04" ]]; then
        echo "Ubuntu $ubuntu_version detected."
        kicadppa="kicad/kicad-8.0-releases"

        # Check if KiCad is installed using dpkg-query for the main package
        if dpkg -s kicad &>/dev/null; then
            installed_version=$(dpkg-query -W -f='${Version}' kicad 2>/dev/null | cut -d'.' -f1)
            if [[ "$installed_version" != "8" ]]; then
                echo "A different version of KiCad ($installed_version) is installed."
                read -p "Do you want to remove it and install KiCad 8.0? (yes/no): " response

                if [[ "$response" =~ ^([Yy][Ee][Ss]|[Yy])$ ]]; then
                    echo "Removing KiCad $installed_version..."
                    sudo apt-get remove --purge -y kicad kicad-footprints kicad-libraries kicad-symbols kicad-templates
                    sudo apt-get autoremove -y
                else
                    echo "Exiting installation. KiCad $installed_version remains installed."
                    exit 1
                fi
            else
                echo "KiCad 8.0 is already installed."
                # FIX (H-01): Return 0 instead of exit 0 so subsequent installation stages continue
                return 0
            fi
        fi
    else
        kicadppa="kicad/kicad-6.0-releases"
    fi

    # Check if the PPA is already added
    if ! grep -q "^deb .*${kicadppa}" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        echo "Adding KiCad PPA to local apt repository: $kicadppa"
        sudo add-apt-repository -y "ppa:$kicadppa"
        sudo apt-get update
    else
        echo "KiCad PPA is already present in sources."
    fi

    # Install KiCad packages - avoiding rigid package revision lock for reliability
    sudo apt-get install -y --no-install-recommends kicad kicad-footprints kicad-libraries kicad-symbols kicad-templates

    echo "KiCad installation completed successfully!"
}

function installDependency
{
    set +e      # Temporarily disable exit on error for apt refresh
    trap "" ERR # Do not trap on error of any command

    # Update apt repository
    echo "Updating apt index files..................."
    sudo apt-get update

    set -e      # Re-enable exit on error
    trap error_exit ERR

    echo "Installing core dependencies (virtualenv, unzip, xterm)..."
    sudo apt install -y python3-virtualenv unzip xterm

    echo "Creating virtual environment with system site packages..."
    # FIX (H-06): Use --system-site-packages so system PyQt5/Matplotlib are visible inside virtualenv
    virtualenv --system-site-packages "$config_dir/env"

    echo "Starting the virtual env..................."
    source "$config_dir/env/bin/activate"

    echo "Upgrading Pip.............................."
    pip install --upgrade pip

    echo "Installing system Python packages via APT..."
    sudo apt-get install -y python3-psutil python3-pyqt5 python3-matplotlib python3-setuptools python3-pip

    # Provision LLVM 18 for GHDL compiler backend
    echo "Installing GHDL and LLVM 18 dependencies..."
    sudo apt-get install -y libcanberra-gtk3-module llvm-18 llvm-18-dev clang-18

    # Verify toolchain binary availability
    if [ -x "/usr/bin/llvm-config-18" ]; then
        echo "Verified LLVM 18 configuration tool: /usr/bin/llvm-config-18"
    else
        echo "Warning: /usr/bin/llvm-config-18 is not currently available."
    fi

    # Install NgVeri Dependencies inside virtual environment
    echo "Installing EDA helper packages in virtualenv..."
    pip3 install watchdog makerchip-app sandpiper-saas

    echo "Installing Hdlparse..."
    pip3 install --upgrade https://github.com/hdl/pyhdlparser/tarball/master || pip3 install hdlparse

    # Verify or fallback-install Matplotlib and PyQt5 inside venv if not available from system
    python3 -c "import matplotlib" 2>/dev/null || pip3 install matplotlib || true
    python3 -c "import PyQt5" 2>/dev/null || pip3 install PyQt5 || true
}

function copyKicadLibrary
{
    # Extract custom KiCad Library
    if [ -f "library/kicadLibrary.tar.xz" ]; then
        tar -xJf library/kicadLibrary.tar.xz
    elif [ -f "kicadLibrary.tar.xz" ]; then
        tar -xJf kicadLibrary.tar.xz
    else
        echo "Warning: kicadLibrary.tar.xz not found. Skipping library extraction..."
        return 0
    fi

    # FIX (H-02): KiCad 8.0 configuration directory resolution on Ubuntu 25.04
    kicad_version="8.0"
    kicad_user_config="$HOME/.config/kicad/$kicad_version"

    if [ -d "$kicad_user_config" ]; then
        echo "KiCad config folder exists: $kicad_user_config"
    else
        echo "$kicad_user_config does not exist; creating directory..."
        mkdir -p "$kicad_user_config"
    fi

    # Safely merge or copy sym-lib-table preserving user data
    if [ -f "kicadLibrary/template/sym-lib-table" ]; then
        target_table="$kicad_user_config/sym-lib-table"
        if [ -f "$target_table" ]; then
            # Backup existing table before modification
            cp "$target_table" "${target_table}.bak.$(date +%Y%m%d_%H%M%S)"
            # If eSim libraries are not yet registered, append them
            if ! grep -q "eSim" "$target_table"; then
                # Append eSim library entries into existing symbol table
                grep "(lib " "kicadLibrary/template/sym-lib-table" >> "$target_table" || true
                echo "Merged eSim symbol entries into existing $target_table"
            else
                echo "eSim symbols already present in $target_table"
            fi
        else
            cp "kicadLibrary/template/sym-lib-table" "$target_table"
            echo "Installed sym-lib-table into $kicad_user_config/"
        fi
    fi

    # Ensure KiCad symbols directory exists
    sudo mkdir -p /usr/share/kicad/symbols/

    # Copy KiCad symbols made for eSim
    if [ -d "kicadLibrary/eSim-symbols" ]; then
        sudo cp -r kicadLibrary/eSim-symbols/* /usr/share/kicad/symbols/
    fi

    set +e      # Temporary disable exit on error
    trap "" ERR # Do not trap on error of any command

    # Remove extracted KiCad Library - not needed anymore
    rm -rf kicadLibrary

    set -e      # Re-enable exit on error
    trap error_exit ERR

    # Change ownership from Root to the User
    sudo chown -R "$USER:$USER" /usr/share/kicad/symbols/
}

function createDesktopStartScript
{
    # Generating new esim-start.sh
    echo '#!/bin/bash' > esim-start.sh
    echo "cd \"$eSim_Home/src/frontEnd\"" >> esim-start.sh
    echo "source \"$config_dir/env/bin/activate\"" >> esim-start.sh
    echo "python3 Application.py" >> esim-start.sh

    # Make it executable
    sudo chmod 755 esim-start.sh
    # Copy esim start script
    sudo cp -vp esim-start.sh /usr/bin/esim
    # Remove local copy of esim start script
    rm -f esim-start.sh

    # Generating esim.desktop file
    echo "[Desktop Entry]" > esim.desktop
    echo "Version=1.0" >> esim.desktop
    echo "Name=eSim" >> esim.desktop
    echo "Comment=EDA Tool" >> esim.desktop
    echo "GenericName=eSim" >> esim.desktop
    echo "Keywords=eda-tools" >> esim.desktop
    echo "Exec=esim %u" >> esim.desktop
    echo "Terminal=true" >> esim.desktop
    echo "X-MultipleArgs=false" >> esim.desktop
    echo "Type=Application" >> esim.desktop
    getIcon="$config_dir/logo.png"
    echo "Icon=$getIcon" >> esim.desktop
    echo "Categories=Development;" >> esim.desktop
    echo "MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;x-scheme-handler/chrome;video/webm;application/x-xpinstall;" >> esim.desktop
    echo "StartupNotify=true" >> esim.desktop

    # Make esim.desktop file executable
    sudo chmod 755 esim.desktop
    # Copy desktop icon file to share applications
    sudo cp -vp esim.desktop /usr/share/applications/
    # Copy desktop icon file to Desktop
    if [ -d "$HOME/Desktop" ]; then
        cp -vp esim.desktop "$HOME/Desktop/"
        set +e
        gio set "$HOME/Desktop/esim.desktop" "metadata::trusted" true 2>/dev/null || true
        chmod a+x "$HOME/Desktop/esim.desktop" 2>/dev/null || true
        set -e
    fi

    # Remove local copy of esim.desktop file
    rm -f esim.desktop

    # Copying logo.png to .esim directory to access as icon
    if [ -f "images/logo.png" ]; then
        cp -vp images/logo.png "$config_dir/"
    fi
}

####################################################################
#                   MAIN START FROM HERE                           #
####################################################################

### Checking if argument is passed to script
if [ "$#" -eq 1 ]; then
    option=$1
else
    echo "USAGE : "
    echo "./install-eSim.sh --install"
    echo "./install-eSim.sh --uninstall"
    exit 1
fi

## Checking flags
if [ "$option" == "--install" ]; then

    set -e  # Set exit option immediately on error
    set -E  # Inherit ERR trap by shell functions

    # Trap on function error_exit before exiting on error
    trap error_exit ERR

    echo "Enter proxy details if you are connected to internet through proxy"

    echo -n "Is your internet connection behind proxy? (y/n): "
    read -r getProxy
    if [ "$getProxy" == "y" -o "$getProxy" == "Y" ]; then
        echo -n 'Proxy Hostname :'
        read -r proxyHostname

        echo -n 'Proxy Port :'
        read -r proxyPort

        echo -n "username@$proxyHostname:$proxyPort :"
        read -r username

        echo -n 'Password :'
        read -r -s passwd
        echo ""

        unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ftp_proxy FTP_PROXY

        export http_proxy="http://$username:$passwd@$proxyHostname:$proxyPort"
        export https_proxy="http://$username:$passwd@$proxyHostname:$proxyPort"
        export HTTP_PROXY="http://$username:$passwd@$proxyHostname:$proxyPort"
        export HTTPS_PROXY="http://$username:$passwd@$proxyHostname:$proxyPort"
        export ftp_proxy="http://$username:$passwd@$proxyHostname:$proxyPort"
        export FTP_PROXY="http://$username:$passwd@$proxyHostname:$proxyPort"

        echo "Install with proxy"

    elif [ "$getProxy" == "n" -o "$getProxy" == "N" ]; then
        echo "Install without proxy"
    else
        echo "Please select the right option"
        exit 0
    fi

    # Step 1: Check and resolve repository EOL reachability safely
    checkAndFixEolSources

    # Step 2: Call installation functions sequentially
    createConfigFile
    installDependency
    installKicad
    copyKicadLibrary
    installNghdl
    installSky130Pdk
    createDesktopStartScript

    echo "-----------------eSim Installed Successfully-----------------"
    echo "Type \"esim\" in Terminal to launch it"
    echo "or double click on \"eSim\" icon placed on Desktop"

elif [ "$option" == "--uninstall" ]; then
    echo -n "Are you sure? It will remove eSim, NGHDL and SKY130 PDK (y/n): "
    read -r getConfirmation
    if [ "$getConfirmation" == "y" -o "$getConfirmation" == "Y" ]; then
        echo "Removing eSim application and launchers..."
        sudo rm -rf "$HOME/.esim" "$HOME/Desktop/esim.desktop" /usr/bin/esim /usr/share/applications/esim.desktop

        echo "Cleaning KiCad eSim library registrations safely..."
        # Safely preserve user's KiCad settings and non-eSim libraries
        for v in 8.0 6.0; do
            sym_table="$HOME/.config/kicad/$v/sym-lib-table"
            if [ -f "$sym_table" ]; then
                cp "$sym_table" "${sym_table}.bak.$(date +%Y%m%d_%H%M%S)"
                # Remove only eSim-specific library lines
                grep -v -E "eSim|kicadLibrary" "$sym_table" > "${sym_table}.tmp" && mv "${sym_table}.tmp" "$sym_table"
                echo "Removed eSim entries from $sym_table (backup preserved)."
            fi
        done

        # Remove eSim custom symbol files from /usr/share/kicad/symbols without deleting the directory
        if [ -d "/usr/share/kicad/symbols" ]; then
            sudo find /usr/share/kicad/symbols/ -maxdepth 1 -name "eSim*" -exec rm -rf {} + 2>/dev/null || true
        fi

        echo "Removing Virtual env..."
        sudo rm -rf "$config_dir/env"

        echo "Removing SKY130 PDK..."
        sudo rm -rf /usr/share/local/sky130_fd_pr

        echo "Removing NGHDL..."
        rm -rf library/modelParamXML/Nghdl/*
        rm -rf library/modelParamXML/Ngveri/*
        if [ -d "nghdl" ]; then
            cd nghdl/ || true
            if [ -f "install-nghdl.sh" ]; then
                chmod +x install-nghdl.sh
                ./install-nghdl.sh --uninstall
            fi
            cd ../ || true
            rm -rf nghdl
            echo -e "----------------eSim Uninstalled Successfully----------------"
        else
            echo -e "\nCannot find \"nghdl\" directory. Please remove it manually if installed."
        fi
    elif [ "$getConfirmation" == "n" -o "$getConfirmation" == "N" ]; then
        exit 0
    else
        echo "Please select the right option."
        exit 0
    fi

else
    echo "Please select the proper operation."
    echo "--install"
    echo "--uninstall"
    exit 1
fi
