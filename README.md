# Enterprise Architect 17 on Linux (Wine) — 64-bit

Install Sparx Systems Enterprise Architect v17.1 **(64-bit)** on Linux using Wine stable.

Tested on **Ubuntu 24.04 / KDE Plasma** with **Wine 11.0 stable** using a **64-bit Wine prefix (wow64)**.

## Prerequisites

- Ubuntu/Debian-based Linux (64-bit)
- Internet connection (for Wine repo and winetricks downloads)
- ~4 GB free disk space
- The EA **64-bit** installer: `easetup_x64.msi` (~321 MB) from [Sparx Systems Trial](https://sparxsystems.com/products/ea/trial/request.html)

## Quick Install

```bash
chmod +x setup.sh
./setup.sh /path/to/easetup_x64.msi
```

## Manual Step-by-Step

### 1. Install Wine Stable

```bash
sudo dpkg --add-architecture i386
sudo mkdir -pm755 /etc/apt/keyrings

wget -O - https://dl.winehq.org/wine-builds/winehq.key \
    | sudo gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key -

# Replace 'noble' with your Ubuntu codename (lsb_release -cs)
sudo wget -NP /etc/apt/sources.list.d/ \
    https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources

sudo apt update
sudo apt install --install-recommends -y winehq-stable winetricks
```

### 2. Install Carlito Font

Carlito is a metric-compatible substitute for Calibri (used by EA).

```bash
sudo apt install -y fonts-crosextra-carlito
```

### 3. Create a Dedicated Wine Prefix

Using an isolated prefix avoids conflicts with other Wine apps.

```bash
export WINEPREFIX="$HOME/.wine-EA"
wineboot --init
```

Wait for initialization to complete. Ignore `fixme:service` warnings — they are harmless.

### 4. Install Windows Dependencies

```bash
export WINEPREFIX="$HOME/.wine-EA"

# MSXML3 — required for XML handling
winetricks --unattended msxml3

# MSXML4 — may show errors on 64-bit prefix, but the DLL gets copied
winetricks --force --unattended msxml4
```

> **Note:** `mdac28` and `jet40` are recommended by Sparx but **do not install on 64-bit Wine prefixes** (winetricks limitation). EA 17 x64 works without them.

### 5. Apply DLL Overrides

```bash
export WINEPREFIX="$HOME/.wine-EA"

cat > /tmp/ea_overrides.reg <<'EOF'
[HKEY_CURRENT_USER\Software\Wine\DllOverrides]
"msado15"="native,builtin"
"msxml3"="native,builtin"
"msxml4"="native,builtin"
EOF

wine regedit /tmp/ea_overrides.reg
```

### 6. Install Enterprise Architect

```bash
export WINEPREFIX="$HOME/.wine-EA"
wine msiexec /i /path/to/easetup_x64.msi /passive
```

Installation takes 1-2 minutes. The app installs to:
`C:\Program Files\Sparx Systems\EA Trial\`

### 7. Launch

```bash
WINEPREFIX="$HOME/.wine-EA" wine "C:\Program Files\Sparx Systems\EA Trial\EA.exe"
```

On first launch, select **Ultimate** edition for the full 30-day trial.

## Desktop Launcher (KDE/GNOME)

The setup script creates a `.desktop` file automatically. To do it manually:

```bash
# Extract icon from EA.exe
wrestool -x -t 14 \
    "$HOME/.wine-EA/drive_c/Program Files/Sparx Systems/EA Trial/EA.exe" \
    -o /tmp/ea.ico
icotool -x /tmp/ea.ico -o "$HOME/.local/share/icons/enterprise-architect.png"

# Create launcher
cat > "$HOME/.local/share/applications/enterprise-architect.desktop" <<'EOF'
[Desktop Entry]
Name=Enterprise Architect
Comment=Sparx Systems Enterprise Architect 17 (Wine)
Exec=env WINEPREFIX=$HOME/.wine-EA wine "C:\\Program Files\\Sparx Systems\\EA Trial\\EA.exe"
Type=Application
Icon=$HOME/.local/share/icons/enterprise-architect.png
Categories=Development;Engineering;
StartupNotify=true
StartupWMClass=ea.exe
EOF

chmod +x "$HOME/.local/share/applications/enterprise-architect.desktop"
update-desktop-database "$HOME/.local/share/applications/"
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `kernel32.dll` load error | Prefix is corrupted. Delete `~/.wine-EA` and start from step 3 |
| msxml4 assembly error 1603 | Expected on 64-bit prefix. The DLL still gets copied — EA works fine |
| mdac28/jet40 won't install | They only work on 32-bit prefixes. Not needed for EA 17 x64 |
| Fonts look wrong | Install `fonts-crosextra-carlito` (step 2) |
| EA crashes on startup | Run with `WINEDEBUG=warn+all` to diagnose. Check DLL overrides |
| Disk full during install | Need ~4 GB free. Delete prefix and restart after freeing space |

## Tested Environment

| Component | Version |
|-----------|---------|
| OS | Ubuntu 24.04 (Noble) |
| Desktop | KDE Plasma |
| Wine | 11.0 stable (winehq-stable) |
| Winetricks | 20240105 |
| Enterprise Architect | 17.1.1716 Trial **(64-bit / x64)** |
| Installer | `easetup_x64.msi` (64-bit MSI) |
| Prefix | **64-bit** (Wine wow64 mode) |

## References

- [Sparx — Official Wine Guide (v17.1)](https://sparxsystems.com/enterprise_architect_user_guide/17.1/getting_started/install_ea_wine.html)
- [Sparx — WineHowTo 2.0 (PDF)](https://sparxsystems.com/downloads/pdf/WineHowTo-2.0.0.pdf)
- [EA Linux Setup Script (Diogo1457)](https://github.com/Diogo1457/EA-linux-setup)
- [EA macOS/Wine Guide (Gist)](https://gist.github.com/JaimeChavarriaga/b38b64197695a0f083e5df65cf96c4b9)

## License

MIT
