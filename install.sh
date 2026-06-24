#!/bin/sh
#
# This script is meant for quick & easy install via:
#   'curl -sSL https://raw.githubusercontent.com/vinicgobbi/unetlab-integration/master/install.sh | sh'
# or:
#   'wget -qO- https://raw.githubusercontent.com/vinicgobbi/unetlab-integration/master/install.sh | sh'

set -e

url="https://github.com/vinicgobbi/unetlab-integration/archive/master.tar.gz"

_command_exists() { command -v "$@" > /dev/null 2>&1; }
_msg() { echo "=>" "$@" >&2; }

_unsupported() {
    cat << 'EOF' >&2

    Your Linux distribution is not supported.

    Feel free to ask support for it by opening an issue at:
      https://github.com/vinicgobbi/unetlab-integration/issues

EOF
    exit 1
}

_get_file() {
    if _command_exists wget; then
        wget -qO- "$1"
    else
        curl -sLo- "$1"
    fi
}

do_install() {
    temp_dir="$(mktemp -d)"

    _msg "Download and extract into '$temp_dir'..."
    _get_file "$url" | tar --strip-components=1 -C "$temp_dir" -xzf -

    _msg "Detectando terminal..."
    if _command_exists ptyxis; then
        TERM_APP="ptyxis"
    elif _command_exists gnome-terminal; then
        TERM_APP="gnome-terminal"
    else
        TERM_APP="ptyxis" # Fallback
    fi
    _msg "Terminal definido para uso: $TERM_APP"

    _msg "Configurando apps Flatpak (Remmina e Wireshark)..."
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    sudo flatpak install -y flathub org.remmina.Remmina org.wireshark.Wireshark

    _msg "Ajustando binários para Flatpak e o terminal detectado..."
    sed -i "s/gnome-terminal/$TERM_APP/g" "$temp_dir/bin/unetlab-integration" 2>/dev/null || true
    sed -i "s/vinagre/flatpak run org.remmina.Remmina/g" "$temp_dir/bin/eni-rdp-wrapper" 2>/dev/null || true
    sed -i "s/wireshark/flatpak run org.wireshark.Wireshark/g" "$temp_dir/bin/unetlab-integration" 2>/dev/null || true

    _msg "Installing..."
    sudo mkdir -p /usr/bin
    sudo install -m 755 "$temp_dir/bin/unetlab-integration" /usr/bin/
    sudo install -m 755 "$temp_dir/bin/eni-rdp-wrapper" /usr/bin/
    sudo mkdir -p /usr/share/applications
    sudo install -m 644 "$temp_dir/data/unetlab-integration.desktop" \
        /usr/share/applications/
    sudo install -m 644 "$temp_dir/data/eni-rdp-wrapper.desktop" \
        /usr/share/applications/
    sudo mkdir -p /usr/share/mime/packages
    sudo install -m 644 "$temp_dir/data/eni-rdp-wrapper.xml" \
        /usr/share/mime/packages/

    # build cache database of MIME types handled by desktop files
    sudo update-desktop-database -q || true
    sudo update-mime-database -n /usr/share/mime || true

    _msg "Clearing cache ..."
    rm -rf "$temp_dir"

    _msg "Complete!"

    # Garante que o grupo exista para evitar erros, já que a versão Flatpak
    # pode ter dinâmicas diferentes de permissão dependendo do sistema
    sudo groupadd -r wireshark 2>/dev/null || true

    cat << 'EOF' >&2

      Do not forget add the user to the wireshark group:

        # You will need to log out and then log back in
        # again for this change to take effect.
        sudo usermod -a -G wireshark $USER

EOF

    exit 0
}

# Detect Linux distribution
if [ -r /etc/os-release ]; then
    . /etc/os-release
elif _command_exists lsb_release; then
    ID=$(lsb_release -si)
    VERSION_ID=$(lsb_release -sr)
else
    _unsupported
fi

_msg "Detected distribution: $ID $VERSION_ID (${ID_LIKE:-"none"})"

# Check if python is installed
if _command_exists python3; then
    # declare a variable
    PYTHON=""
fi

for dist_id in $ID $ID_LIKE; do
    case "$dist_id" in
        debian|ubuntu)
            _msg "Install dependencies..."
            sudo apt-get install -y ${PYTHON-"python3"} \
                ssh-askpass telnet flatpak
            do_install
            ;;
        arch|archlinux|manjaro)
            _msg "Install dependencies..."
            sudo pacman -S --needed --noconfirm ${PYTHON-"python3"} \
                inetutils x11-ssh-askpass flatpak
            do_install
            ;;
        fedora)
            _msg "Install dependencies..."
            sudo dnf install -y ${PYTHON-"python3"} \
                openssh-askpass telnet flatpak
            do_install
            ;;
        opensuse|suse)
            _msg "Install dependencies..."
            sudo zypper install -y ${PYTHON-"python3"} \
                openssh-askpass telnet flatpak
            do_install
            ;;
        centos|CentOS|rhel)
            _msg "Install dependencies..."
            sudo yum install -y ${PYTHON-"python3"} \
                openssh-askpass telnet flatpak
            do_install
            ;;
        *)
            continue
            ;;
    esac
done

_unsupported