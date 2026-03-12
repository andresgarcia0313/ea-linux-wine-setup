#!/bin/bash
set -euo pipefail

# Enterprise Architect 17 — Linux Wine Installer
# Tested: Ubuntu 24.04, Wine 11.0 stable, EA 17.1.1716 x64

INSTALL_DIR="/opt/enterprise-architect"
WINEPREFIX_DIR="$INSTALL_DIR/prefix"
EA_INSTALL_DIR="C:\\Program Files\\Sparx Systems\\EA Trial"
ICON_DIR="$HOME/.local/share/icons"
APP_DIR="$HOME/.local/share/applications"

usage() {
    echo "Usage: $0 <path-to-easetup_x64.msi>"
    echo ""
    echo "Download the installer from:"
    echo "  https://sparxsystems.com/products/ea/trial/request.html"
    exit 1
}

log() { echo -e "\n=== $1 ===\n"; }

check_deps() {
    local missing=()
    command -v wine &>/dev/null || missing+=("winehq-stable")
    command -v winetricks &>/dev/null || missing+=("winetricks")
    command -v wrestool &>/dev/null || missing+=("icoutils")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing packages: ${missing[*]}"
        echo "Install them with:"
        echo "  sudo apt install -y ${missing[*]}"
        exit 1
    fi
}

install_fonts() {
    if ! fc-list | grep -qi carlito; then
        log "Installing Carlito font"
        sudo apt install -y fonts-crosextra-carlito
    else
        echo "Carlito font already installed."
    fi
}

create_prefix() {
    log "Creating Wine prefix at $WINEPREFIX_DIR"

    sudo mkdir -p "$INSTALL_DIR"
    sudo chown "$(id -un):$(id -gn)" "$INSTALL_DIR"

    export WINEPREFIX="$WINEPREFIX_DIR"

    if [[ -d "$WINEPREFIX_DIR/drive_c" ]]; then
        echo "Prefix already exists. Skipping creation."
        return
    fi

    wineboot --init 2>&1 | grep -v "^[0-9a-f]*:fixme" || true

    # Verify prefix works
    if ! wine cmd.exe /c 'echo %AppData%' &>/dev/null; then
        echo "ERROR: Wine prefix creation failed."
        echo "Delete $WINEPREFIX_DIR and try again."
        exit 1
    fi
    echo "Prefix created successfully."
}

install_dependencies() {
    log "Installing Windows dependencies (msxml3, msxml4)"
    export WINEPREFIX="$WINEPREFIX_DIR"

    echo "Installing msxml3..."
    winetricks --unattended msxml3 2>&1 | grep -E "(warning|error|Executing wine)" || true

    echo "Installing msxml4 (errors on 64-bit are expected)..."
    winetricks --force --unattended msxml4 2>&1 | grep -E "(warning|error|Executing wine)" || true
}

apply_overrides() {
    log "Applying DLL overrides"
    export WINEPREFIX="$WINEPREFIX_DIR"

    cat > /tmp/ea_overrides.reg <<'EOF'
[HKEY_CURRENT_USER\Software\Wine\DllOverrides]
"msado15"="native,builtin"
"msxml3"="native,builtin"
"msxml4"="native,builtin"
EOF

    wine regedit /tmp/ea_overrides.reg 2>/dev/null
    rm -f /tmp/ea_overrides.reg
    echo "DLL overrides applied."
}

install_ea() {
    local msi_path="$1"
    log "Installing Enterprise Architect"
    export WINEPREFIX="$WINEPREFIX_DIR"

    wine msiexec /i "$msi_path" /passive 2>&1 | grep -v "^[0-9a-f]*:fixme" || true

    local ea_exe="$WINEPREFIX_DIR/drive_c/Program Files/Sparx Systems/EA Trial/EA.exe"
    if [[ -f "$ea_exe" ]]; then
        echo "Enterprise Architect installed successfully."
    else
        echo "ERROR: EA.exe not found after installation."
        exit 1
    fi
}

create_launcher() {
    log "Creating desktop launcher"
    export WINEPREFIX="$WINEPREFIX_DIR"
    local ea_exe="$WINEPREFIX_DIR/drive_c/Program Files/Sparx Systems/EA Trial/EA.exe"

    mkdir -p "$ICON_DIR" "$APP_DIR"

    # Extract icon
    local icon_path="$ICON_DIR/enterprise-architect.png"
    if wrestool -x -t 14 "$ea_exe" -o /tmp/ea.ico 2>/dev/null; then
        icotool -x /tmp/ea.ico -o "$icon_path" 2>/dev/null
        rm -f /tmp/ea.ico
    fi

    # If wrestool extraction was too small, check Wine-extracted icons
    if [[ ! -s "$icon_path" ]] || [[ $(stat -c%s "$icon_path" 2>/dev/null) -lt 1000 ]]; then
        local wine_icon
        wine_icon=$(find "$HOME/.local/share/icons/hicolor/256x256" \
            -name "*EA*" 2>/dev/null | head -1)
        [[ -n "$wine_icon" ]] && cp "$wine_icon" "$icon_path"
    fi

    # Create launcher script
    cat > "$INSTALL_DIR/ea.sh" <<LAUNCHER
#!/bin/bash
WINEPREFIX="$WINEPREFIX_DIR" \\
    wine "$EA_INSTALL_DIR\\\\EA.exe" "\\\$@"
LAUNCHER
    chmod +x "$INSTALL_DIR/ea.sh"

    cat > "$APP_DIR/enterprise-architect.desktop" <<EOF
[Desktop Entry]
Name=Enterprise Architect
Comment=Sparx Systems Enterprise Architect 17 (Wine)
Exec=$INSTALL_DIR/ea.sh
Type=Application
Icon=$icon_path
Categories=Development;Engineering;
StartupNotify=true
StartupWMClass=ea.exe
EOF

    chmod +x "$APP_DIR/enterprise-architect.desktop"
    update-desktop-database "$APP_DIR" 2>/dev/null || true
    echo "Desktop launcher created."
}

# --- Main ---

[[ $# -lt 1 ]] && usage

MSI_PATH="$(realpath "$1")"
[[ ! -f "$MSI_PATH" ]] && echo "ERROR: File not found: $1" && exit 1
[[ "$MSI_PATH" != *.msi ]] && echo "ERROR: Expected .msi file" && exit 1

echo "Enterprise Architect 17 — Linux Wine Installer"
echo "Installer: $MSI_PATH"
echo "Prefix:    $WINEPREFIX_DIR"
echo ""

check_deps
install_fonts
create_prefix
install_dependencies
apply_overrides
install_ea "$MSI_PATH"
create_launcher

log "Installation complete!"
echo "Launch from menu or run:"
echo "  $INSTALL_DIR/ea.sh"
