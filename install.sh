#!/bin/bash
# Hyprland MSI RTX 4070 - Instalador v3.2 (Final + Power Profile)
# Uso: bash install.sh

set -euo pipefail

trap 'echo "⚠️ Instalación interrumpida. Limpiando..."; rm -rf /tmp/paru-build; exit 1' INT TERM ERR

# ==================== VERIFICACIONES INICIALES ====================

if ! sudo -v; then
    echo "❌ Se necesitan permisos sudo. Configura sudo primero."
    exit 1
fi

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    echo "❌ No ejecutes esto desde Hyprland. Cierra sesión y usa una TTY (Ctrl+Alt+F3)."
    exit 1
fi

if ! grep -qE "Arch|CachyOS" /etc/os-release 2>/dev/null; then
    echo "❌ Este script solo funciona en Arch Linux o CachyOS"
    exit 1
fi

if ! lspci | grep -i nvidia >/dev/null; then
    echo "❌ No se detectó GPU NVIDIA. Este script es para RTX 4070."
    exit 1
fi

echo "🚀 Iniciando entorno Hyprland Pro para MSI Pulse 16 AI C1V..."

# ==================== BACKUP ====================

BACKUP_DIR=$(mktemp -d ~/kde-backup-XXXXXXXXXX)
echo "📦 Creando respaldo en: $BACKUP_DIR"

(
    shopt -s nullglob
    files=(~/.config/plasma* ~/.config/kwin* ~/.config/plasmashellrc ~/.config/kglobalshortcutsrc)
    if [ ${#files[@]} -gt 0 ]; then
        cp -r "${files[@]}" "$BACKUP_DIR/"
        echo "✅ ${#files[@]} archivos KDE respaldados"
    else
        echo "ℹ️ No se encontraron configs de KDE"
    fi
)

if [ -d ~/.config/hypr ]; then
    cp -r ~/.config/hypr "$BACKUP_DIR/hypr-old-$(date +%s)"
    echo "📦 Backup de Hyprland anterior guardado"
fi

cat > "$BACKUP_DIR/restore.sh" << 'EOF'
#!/bin/bash
BACKUP=$(ls -dt ~/kde-backup-* | head -1)
[ -z "$BACKUP" ] && { echo "❌ No hay backups"; exit 1; }
cp -r "$BACKUP"/* ~/.config/ 2>/dev/null
echo "✅ Restaurado desde: $BACKUP"
echo "🔄 Reinicia sesión para aplicar cambios."
EOF
chmod +x "$BACKUP_DIR/restore.sh"

# ==================== DEPENDENCIAS ====================

echo "📦 Verificando herramientas base..."
sudo pacman -S --needed --noconfirm base-devel git archlinux-keyring

if ! command -v paru &>/dev/null; then
    echo "📦 Instalando paru..."
    rm -rf /tmp/paru-build
    git clone https://aur.archlinux.org/paru.git /tmp/paru-build
    cd /tmp/paru-build
    if ! makepkg -si --noconfirm; then
        echo "⚠️ Falló compilación. Actualizando keyring..."
        sudo pacman -Sy --needed --noconfirm archlinux-keyring
        makepkg -si --noconfirm
    fi
    cd - >/dev/null
fi

echo "📦 Instalando paquetes..."
sudo pacman -S --needed --noconfirm \
    hyprland waybar kitty yazi hyprpaper \
    nvidia-cachyos-settings \
    libva-nvidia-driver \
    ttf-jetbrains-mono ttf-font-awesome \
    polkit-kde-agent dunst rofi-wayland \
    grimblast hyprpicker \
    jq

# ==================== HYPRLAND CONFIG ====================

echo "⚙️ Configurando Hyprland..."

mkdir -p ~/.config/hypr/UserConfigs ~/.config/hypr/scripts

cat > ~/.config/hypr/UserConfigs/nvidia-env.conf << 'EOF'
# NVIDIA RTX 4070 Mobile - MSI Pulse 16 AI C1V
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
env = XDG_SESSION_TYPE,wayland
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_DESKTOP,Hyprland

cursor {
    no_hardware_cursors = true
}
EOF

cat > ~/.config/hypr/UserConfigs/monitors.conf << 'EOF'
# MSI Pulse 16 - 2560x1600@165
monitor = eDP-1, 2560x1600@165, 0x0, 1
# Fallback: monitor = eDP-1, preferred, auto, 1
EOF

cat > ~/.config/hypr/hyprland.conf << 'EOF'
# Hyprland - MSI Pulse 16 AI C1V + RTX 4070
source = ~/.config/hypr/UserConfigs/nvidia-env.conf
source = ~/.config/hypr/UserConfigs/monitors.conf

input {
    kb_layout = es
    numlock_by_default = true
    touchpad {
        natural_scroll = true
        tap-to-click = true
        drag_lock = true
    }
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(50fa7bee) rgba(8be9fdcc) 45deg
    col.inactive_border = rgba(444444aa)
    layout = dwindle
}

decoration {
    rounding = 8
    blur { enabled = true size = 3 passes = 1 }
    shadow { enabled = true range = 4 render_power = 3 color = rgba(1a1a1aee) }
}

animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

dwindle {
    pseudotile = true
    preserve_split = true
}

$terminal = kitty
$file = yazi
$menu = rofi -show drun

bind = SUPER, Return, exec, $terminal
bind = SUPER, E, exec, $file
bind = SUPER SHIFT, E, exec, dolphin
bind = SUPER, Q, killactive
bind = SUPER, M, exit
bind = SUPER, V, togglefloating
bind = SUPER, R, exec, $menu
bind = SUPER, P, pseudo
bind = SUPER, J, togglesplit
bind = SUPER, F, fullscreen

bind = SUPER SHIFT, left, movewindow, l
bind = SUPER SHIFT, right, movewindow, r
bind = SUPER SHIFT, up, movewindow, u
bind = SUPER SHIFT, down, movewindow, d

bind = SUPER CTRL, left, resizeactive, -20 0
bind = SUPER CTRL, right, resizeactive, 20 0
bind = SUPER CTRL, up, resizeactive, 0 -20
bind = SUPER CTRL, down, resizeactive, 0 20

bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4
bind = SUPER, 5, workspace, 5
bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
bind = SUPER SHIFT, 3, movetoworkspace, 3
bind = SUPER SHIFT, 4, movetoworkspace, 4
bind = SUPER SHIFT, 5, movetoworkspace, 5

windowrulev2 = float, class:^(pavucontrol)$
windowrulev2 = float, class:^(nm-connection-editor)$
windowrulev2 = float, class:^(blueman-manager)$
windowrulev2 = float, class:^(org.kde.polkit-kde-authentication-agent-1)$
windowrulev2 = size 800 600, class:^(pavucontrol)$

exec-once = waybar
exec-once = dunst
exec-once = /usr/lib/polkit-kde-authentication-agent-1
exec-once = hyprpaper
exec-once = ~/.config/hypr/scripts/auto-power-profile.sh
EOF

# ==================== POWER PROFILE SCRIPT ====================

echo "🔌 Configurando detección de cargador..."

cat > ~/.config/hypr/scripts/auto-power-profile.sh << 'EOF'
#!/bin/bash
# Auto-detección AC/Batería para MSI Pulse 16

LAST_STATE=""

while true; do
    AC_PATH=$(find /sys/class/power_supply/ -name "AC*" -o -name "ADP*" 2>/dev/null | head -1)
    if [ -n "$AC_PATH" ] && [ -f "$AC_PATH/online" ]; then
        AC_STATUS=$(cat "$AC_PATH/online" 2>/dev/null || echo "0")
    else
        AC_STATUS="0"
    fi

    if [ "$AC_STATUS" != "$LAST_STATE" ]; then
        if [ "$AC_STATUS" = "1" ]; then
            notify-send "🔌 Cargador Conectado" "Modo Rendimiento Máximo\nGPU desbloqueada" -i battery-full-charged
        else
            notify-send "🔋 Modo Batería" "Rendimiento reducido para ahorro" -i battery-low
        fi
        LAST_STATE="$AC_STATUS"
    fi

    sleep 10
done
EOF
chmod +x ~/.config/hypr/scripts/auto-power-profile.sh

# ==================== WAYBAR ====================

echo "📊 Configurando Waybar..."

mkdir -p ~/.config/waybar/scripts

cat > ~/.config/waybar/scripts/gpu-rtx4070.sh << 'EOF'
#!/bin/bash
if ! command -v nvidia-smi &>/dev/null; then
    echo '{"text":"󰢮 N/A","class":"error"}'
    exit 0
fi

GPU_DATA=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw --format=csv,noheader,nounits 2>/dev/null)

if [ -z "$GPU_DATA" ] || echo "$GPU_DATA" | grep -qi "no devices\|failed"; then
    echo '{"text":"󰢮 Off","class":"warning"}'
    exit 0
fi

CLEAN_DATA=$(echo "$GPU_DATA" | tr -d ' ')
IFS=',' read -r UTIL TEMP VRAM_USED VRAM_TOTAL POWER <<< "$CLEAN_DATA"

if [ -z "$UTIL" ] || [ -z "$TEMP" ]; then
    echo '{"text":"󰢮 Err","class":"error"}'
    exit 0
fi

if [ "${UTIL:-0}" -gt 90 ]; then CLASS="critical"
elif [ "${UTIL:-0}" -gt 70 ]; then CLASS="warning"
else CLASS="good"; fi

POWER_DISPLAY="${POWER}W"
[ "$POWER" = "N/A" ] || [ -z "$POWER" ] && POWER_DISPLAY="N/A"

printf '{"text":"󰢮 %s%% 󰔏 %s°C 󰍛 %sMB","tooltip":"RTX 4070 Mobile\nCarga: %s%%\nVRAM: %s/%s MB\nTemp: %s°C\nPotencia: %s","class":"%s"}\n' \
    "$UTIL" "$TEMP" "$VRAM_USED" "$UTIL" "$VRAM_USED" "$VRAM_TOTAL" "$TEMP" "$POWER_DISPLAY" "$CLASS"
EOF
chmod +x ~/.config/waybar/scripts/gpu-rtx4070.sh

cat > ~/.config/waybar/scripts/power-status.sh << 'EOF'
#!/bin/bash
# Estado de carga para Waybar

AC_PATH=$(find /sys/class/power_supply/ -name "AC*" -o -name "ADP*" 2>/dev/null | head -1)
if [ -n "$AC_PATH" ] && [ -f "$AC_PATH/online" ]; then
    AC_STATUS=$(cat "$AC_PATH/online" 2>/dev/null || echo "0")
else
    AC_STATUS="0"
fi

if [ "$AC_STATUS" = "1" ]; then
    echo '{"text":"󰂄 AC","class":"ac","tooltip":"Cargador conectado\nModo: Rendimiento"}'
else
    echo '{"text":"󰁹 BAT","class":"battery","tooltip":"Modo Batería\nRendimiento reducido"}'
fi
EOF
chmod +x ~/.config/waybar/scripts/power-status.sh

cat > ~/.config/waybar/config.jsonc << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 36,
    "spacing": 6,
    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["custom/power", "custom/gpu", "cpu", "memory", "battery", "tray"],

    "hyprland/workspaces": {
        "format": "{icon}",
        "format-icons": {
            "1": "", "2": "󰈹", "3": "󰅩", "4": "󰙯", "5": "󰎆",
            "active": "󰮯", "default": "󰊠"
        },
        "on-click": "activate"
    },

    "hyprland/window": {
        "format": "{}",
        "max-length": 50,
        "tooltip": false
    },

    "custom/power": {
        "exec": "~/.config/waybar/scripts/power-status.sh",
        "return-type": "json",
        "interval": 5,
        "format": "{}"
    },

    "custom/gpu": {
        "exec": "~/.config/waybar/scripts/gpu-rtx4070.sh",
        "return-type": "json",
        "interval": 2,
        "format": "{}",
        "tooltip": true
    },

    "cpu": {
        "format": "󰻠 {usage}%",
        "interval": 2
    },

    "memory": {
        "format": "󰍛 {used:0.1f}GB",
        "tooltip-format": "Uso: {total:0.1f}GB",
        "interval": 2
    },

    "battery": {
        "bat": "BAT0",
        "format": "{icon} {capacity}%",
        "format-charging": "󰂄 {capacity}%",
        "format-plugged": "󰂄 {capacity}%",
        "format-icons": ["󰁺","󰁻","󰁼","󰁽","󰁾","󰁿","󰂀","󰂁","󰂂","󰁹"],
        "states": { "warning": 30, "critical": 15 }
    },

    "clock": {
        "format": "󰥔 {:%H:%M}",
        "format-alt": "󰃭 {:%d/%m/%Y}"
    },

    "tray": {
        "spacing": 8,
        "icon-size": 16
    }
}
EOF

cat > ~/.config/waybar/style.css << 'EOF'
* {
    font-family: "JetBrains Mono", "Font Awesome 6 Free";
    font-size: 13px;
    min-height: 0;
    border: none;
    border-radius: 0;
}
window#waybar {
    background: rgba(10, 10, 10, 0.95);
    color: #ffffff;
    border-bottom: 2px solid #1a1a1a;
}
#workspaces button {
    padding: 0 10px;
    color: #888888;
}
#workspaces button.active {
    color: #50fa7b;
    border-bottom: 2px solid #50fa7b;
}
#window { color: #bd93f9; font-weight: bold; }

#custom-power { padding: 0 8px; }
#custom-power.ac { color: #50fa7b; }
#custom-power.battery { color: #f1fa8c; }

#custom-gpu { color: #8be9fd; padding: 0 8px; }
#custom-gpu.critical { color: #ff5555; }
#custom-gpu.warning { color: #f1fa8c; }
#custom-gpu.good { color: #50fa7b; }

#cpu { color: #bd93f9; padding: 0 8px; }
#memory { color: #ffb86c; padding: 0 8px; }
#battery { color: #f1fa8c; padding: 0 8px; }
#battery.charging { color: #50fa7b; }
#clock { color: #ffffff; font-weight: bold; padding: 0 12px; }
#tray { padding: 0 8px; }
EOF

# ==================== OLLAMA ====================

echo "🧠 Configurando Ollama..."

AVAILABLE_GB=$(df -BG "$HOME" | awk 'NR==2 {print $4}' | tr -d 'G')
if [ "${AVAILABLE_GB:-0}" -lt 6 ]; then
    echo "⚠️ Espacio crítico: ${AVAILABLE_GB}GB libres."
    read -p "¿Omitir descarga del modelo? (s/N): " -r respuesta
    if [[ "$respuesta" =~ ^[Ss]$ ]]; then
        echo "⏭️ Saltando Ollama..."
        SKIP_OLLAMA=1
    fi
fi

if [ "${SKIP_OLLAMA:-0}" != "1" ]; then
    if ! command -v ollama &>/dev/null; then
        echo "⬇️ Descargando Ollama..."
        OLLAMA_INSTALLER=$(mktemp)
        if ! curl -fsSL --max-time 60 https://ollama.com/install.sh -o "$OLLAMA_INSTALLER"; then
            echo "❌ Error de red descargando Ollama"
            rm -f "$OLLAMA_INSTALLER"
            exit 1
        fi
        if head -1 "$OLLAMA_INSTALLER" | grep -qE "<!DOCTYPE|<html"; then
            echo "❌ El servidor devolvió HTML (error)"
            rm -f "$OLLAMA_INSTALLER"
            exit 1
        fi
        sh "$OLLAMA_INSTALLER"
        rm -f "$OLLAMA_INSTALLER"
    fi

    sudo systemctl enable --now ollama

    echo "⏳ Esperando servicio Ollama..."
    for i in {1..60}; do
        if curl -sf --max-time 2 http://localhost:11434/api/tags >/dev/null 2>&1; then
            echo "✅ Servicio listo (${i}s)"
            break
        fi
        [ $((i % 10)) -eq 0 ] && echo "   ... esperando ($i/60s)"
        sleep 1
    done

    if ! systemctl is-active --quiet ollama; then
        echo "❌ Ollama no inició. Revisa: systemctl status ollama"
        exit 1
    fi

    echo "⬇️ Descargando llama3.1:8b (~4.7GB)..."
    if ! ollama pull llama3.1:8b; then
        echo "❌ Error descargando modelo"
        exit 1
    fi

    if ollama list | grep -q llama3.1; then
        echo "✅ llama3.1:8b listo"
    else
        echo "⚠️ Modelo no aparece en lista"
    fi
fi

# ==================== FINALIZACIÓN ====================

echo ""
echo "🎉 ¡Instalación v3.2 completada!"
echo "═══════════════════════════════════════════════════"
echo ""
echo "NUEVO: Detección de cargador AC"
echo "  • Icono 󰂄 verde = Cargador conectado (rendimiento máximo)"
echo "  • Icono 󰁹 amarillo = Batería (ahorro energía)"
echo "  • Notificación al conectar/desconectar"
echo ""
echo "Atajos esenciales:"
echo "  Super + Enter  → Terminal"
echo "  Super + E      → Yazi"
echo "  Super + Shift+E → Dolphin"
echo "  Super + R      → Rofi"
echo "  Super + Q      → Cerrar ventana"
echo ""
echo "IA Local:"
echo "  ollama run llama3.1:8b"
echo ""
echo "═══════════════════════════════════════════════════"
echo "Backup: $BACKUP_DIR"
echo "Restaurar KDE: bash $BACKUP_DIR/restore.sh"
echo "═══════════════════════════════════════════════════"
