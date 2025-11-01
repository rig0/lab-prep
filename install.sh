#!/usr/bin/env bash
set -e

# ----------------------------
# Prepare
# ----------------------------

# Default:
TEST=false

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --test) TEST=true ;;
    -h|--help)
      echo "Usage: $0 [--test]"
      exit 0
      ;;
  esac
  shift
done

# Detect distro
if [ -f /etc/os-release ]; then
    . /etc/os-release

    DISTRO_ID=$ID   # debian, ubuntu, fedora, bazzite, etc.

    # Some Fedora-based immutables (kinoite, silverblue, bazzite) set VARIANT_ID
    if [ "$DISTRO_ID" = "fedora" ] && [ -n "${VARIANT_ID:-}" ]; then
        if [ "$VARIANT_ID" = "kde" ] || [ "$VARIANT_ID" = "workstation" ]; then
            DISTRO="$DISTRO_ID-$VARIANT_ID"
        else
            DISTRO=$VARIANT_ID
        fi
    else
        DISTRO=$DISTRO_ID
    fi
else
    echo 
    echo "Could not detect Linux distribution!"
    exit 1
fi

# ----------------------------
# Supported distributions
# ----------------------------
DEBIAN_BASED=("debian" "ubuntu" "linuxmint")
FEDORA_BASED=("fedora" "bazzite" "bazzite-nvidia" "kinoite" "silverblue" "fedora-workstation" "fedora-kde")

SUPPORTED_DISTROS=("${DEBIAN_BASED[@]}" "${FEDORA_BASED[@]}")

if [[ ! " ${SUPPORTED_DISTROS[@]} " =~ " ${DISTRO} " ]]; then
    echo
    echo "Unsupported distribution: $DISTRO"
    echo "Consider manual installation."
    exit 1
fi

# ----------------------------
# Check if OS is Immutable
# ----------------------------
IMMUTABLE=false
if [[ " ${FEDORA_BASED[@]} " =~ " ${DISTRO} " ]] && command -v rpm-ostree >/dev/null 2>&1; then
    IMMUTABLE=true
    echo
    echo "Immutable OS detected: $DISTRO"
else
    echo
    echo "Detected distro: $DISTRO"
    echo
fi

# ----------------------------
# Base packages
# ----------------------------
if [[ " ${DEBIAN_BASED[@]} " =~ " ${DISTRO} " ]]; then
    BASE_PKGS="
        python3
        python3-pip
        python3-venv
        python3-dev
        libglib2.0-dev
        libgirepository1.0-dev
        libcairo2-dev
        gobject-introspection
        python3-gi
        python3-gi-cairo
        gir1.2-gtk-3.0
        build-essential
        pkg-config
        libffi-dev
        libssl-dev
        zlib1g-dev
        libxml2-dev
        libxslt1-dev
        libpq-dev
        curl
    "
elif [[ " ${FEDORA_BASED[@]} " =~ " ${DISTRO} " ]]; then
    BASE_PKGS="
        python3
        python3-pip
        python3-virtualenv
        python3-devel
        glib2-devel
        gobject-introspection-devel
        cairo-devel
        python3-gobject
        python3-gobject-base
        cairo-gobject
        gtk3
        gcc
        gcc-c++
        make
        pkg-config
        libffi-devel
        openssl-devel
        zlib-devel
        libxml2-devel
        libxslt-devel
        libpq-devel
        curl
    "
fi

# Convert BASE_PKGS multi-line string to array (fix newlines)
read -r -a BASE_ARR <<< "$(echo "$BASE_PKGS" | tr '\n' ' ')"

# Combine packages
ALL_PKGS=("${BASE_ARR[@]}")

# ----------------------------
# Install System dependencies
# ----------------------------
if [[ " ${DEBIAN_BASED[@]} " =~ " ${DISTRO} " ]]; then
    sudo apt update
    sudo apt install -y "${ALL_PKGS[@]}"

    if [ "$DISTRO" = "linuxmint" ]; then
        sudo apt install -y python3.12-venv
    fi

elif [[ " ${FEDORA_BASED[@]} " =~ " ${DISTRO} " ]]; then
    if [ "$IMMUTABLE" = true ]; then
        echo
        echo "⚠️  Immutable Fedora detected. You can layer packages with rpm-ostree or use a toolbox (container)."
        echo "Given the nature of this software, It's recommended to layer the packages with rpm-ostree."
        echo "Running in a toolbox currently requires some workarounds for some sensors."
        echo
        read -p "Do you want to layer packages into the system? (Y/n): " choice
        echo
        if [[ "$choice" =~ ^[Nn]$ ]]; then
            TOOLBOX=1
            HOSTNAME=$(hostname)
            echo
            echo "Skipping layering. Using toolbox for installation instead."
            echo 
            toolbox create -c desktop-agent || true
            toolbox run -c desktop-agent sudo dnf install -y "${ALL_PKGS[@]}"
            toolbox run -c desktop-agent sudo hostname $HOSTNAME
        else
            RPM_OSTREE=1
            sudo rpm-ostree install --allow-inactive "${ALL_PKGS[@]}"
            echo
            echo "Reboot required to apply changes!"
        fi
    else
        sudo dnf install -y "${ALL_PKGS[@]}"
    fi
fi

echo
echo "All system dependencies installed."

# ----------------------------
# Install python dependencies
# ----------------------------
echo
echo "=== Python dependency installer ==="
echo

SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR/.." || exit 1

# Check python3 exists
if ! command -v python3 >/dev/null 2>&1; then
    echo "❌ python3 is not installed! Aborting."
    exit 1
fi

# Check if system is externally managed
EXTERNALLY_MANAGED=false
python3 -m pip install --upgrade pip >/dev/null 2>&1 || EXTERNALLY_MANAGED=true

# Check if installation is layered or system is immutable
if [ "$RPM_OSTREE" = 1 ]; then
    echo "Layered installation detected."
    echo "Reboot then install the python requirements like so:"
    echo
    echo "  cd $(realpath ./)"
    echo "  python3 -m pip install --upgrade pip setuptools wheel"
    echo "  python3 -m pip install -r requirements.txt"
    echo
    echo "Then run the agent:"
    echo
    echo "  python3 main.py"
    echo
elif [ "$TOOLBOX" = 1 ]; then
    echo "Installing python dependencies in toolbox desktop-agent..."
    echo
    cd $(realpath ./)
    toolbox run -c desktop-agent python3 -m pip install --upgrade pip setuptools wheel
    toolbox run -c desktop-agent python3 -m pip install -r requirements.txt
    echo
    cd $(realpath ./)
    echo "✅ Python dependencies installed"


# Check if system is externally managed and create virtual environment
elif [ "$EXTERNALLY_MANAGED" = true ]; then
    echo "⚠️ System Python is externally managed. Creating virtual environment..."
    echo
    VENV_DIR=".venv"
    python3 -m venv --system-site-packages "$VENV_DIR"
    VENV_PY="$VENV_DIR/bin/python"
    VENV_PIP="$VENV_DIR/bin/pip"

    echo "Upgrading pip inside virtual environment..."
    "$VENV_PIP" install --upgrade pip setuptools wheel

    echo "Installing dependencies into virtual environment..."
    "$VENV_PIP" install -r requirements.txt

    echo
    echo "✅ Python dependencies installed in virtual environment at $VENV_DIR"
    echo
    echo "Since your system Python is externally managed, a virtual environment was created at:"
    echo
    echo "  $(realpath ./.venv)"
    echo
    echo "To activate the virtual environment and run the app:"
    echo
    echo "  cd $(realpath ./)"
    echo "  source ./.venv/bin/activate"
    echo "  python3 main.py"
    echo
    echo "While inside the virtual environment, you can install additional Python packages safely using pip."
    echo "To exit the virtual environment, simply run:"
    echo
    echo "  deactivate"
    echo
else
    echo "Installing Python dependencies..."
    echo
    python3 -m pip install --upgrade pip setuptools wheel
    python3 -m pip install -r requirements.txt

    echo
    echo "✅ Python dependencies installed"

fi