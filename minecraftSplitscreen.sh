#!/bin/bash

set +e  # Allow script to continue on errors for robustness

# =============================
# Minecraft Splitscreen Launcher for Steam Deck & Linux
# =============================
# This script launches 1–4 Minecraft instances in splitscreen mode.
# On Steam Deck Game Mode, it launches a nested KDE Plasma session for clean splitscreen.
# On desktop mode, it launches Minecraft instances directly.
# Handles controller detection, per-instance mod config, KDE panel hiding/restoring, and reliable autostart in a nested session.
#
# HOW IT WORKS:
# 1. If in Steam Deck Game Mode, launches a nested Plasma Wayland session (if not already inside).
# 2. Sets up an autostart .desktop file to re-invoke itself inside the nested session.
# 3. Detects how many controllers are connected (1–4, with Steam Input quirks handled).
# 4. For each player, writes the correct splitscreen mod config and launches a Minecraft instance.
# 5. Hides KDE panels for a clean splitscreen experience (by killing plasmashell), then restores them.
# 6. Logs out of the nested session when done.
#
# NOTE: This script is robust and heavily commented for clarity and future maintainers!
# The main script file should be named minecraftSplitscreen.sh for clarity and version-agnostic usage.

# Set a temporary directory for intermediate files (used for wrappers, etc)
export target=/tmp

# =============================
# Function: selfUpdate
# =============================
# Checks if this script is the latest version from GitHub. If not, downloads and replaces itself.
selfUpdate() {
    local repo_url="https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/minecraftSplitscreen.sh"
    local tmpfile
    tmpfile=$(mktemp)
    local script_path
    script_path="$(readlink -f "$0")"
    # Download the latest version
    if ! curl -fsSL "$repo_url" -o "$tmpfile"; then
        echo "[Self-Update] Failed to check for updates." >&2
        rm -f "$tmpfile"
        return
    fi
    # Compare files byte-for-byte
    if ! cmp -s "$tmpfile" "$script_path"; then
        # --- Terminal Detection and Relaunch Logic ---
        # If not running in an interactive shell (no $PS1), not launched by a terminal program, and not attached to a tty,
        # then we are likely running from a GUI (e.g., .desktop launcher) and cannot prompt the user for input.
        if [ -z "$PS1" ] && [ -z "$TERM_PROGRAM" ] && ! tty -s; then
            # Try to find a terminal emulator to relaunch the script for the update prompt.
            # This loop checks for common terminal emulators in order of preference.
            for term in x-terminal-emulator gnome-terminal konsole xfce4-terminal xterm; do
                if command -v $term >/dev/null 2>&1; then
                    # Relaunch this script in the found terminal emulator, passing all arguments.
                    exec $term -e "$script_path" "$@"
                fi
            done
            # If no terminal emulator is found, print an error and exit.
            echo "[Self-Update] Update available, but no terminal found for prompt. Please run this script from a terminal to update." >&2
            rm -f "$tmpfile"
            exit 1
        fi
        # --- Interactive Update Prompt ---
        # If we are running in a terminal, prompt the user for update confirmation.
        echo "[Self-Update] A new version is available. Update now? [y/N]"
        read -r answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            echo "[Self-Update] Updating..."
            cp "$tmpfile" "$script_path"
            chmod +x "$script_path"
            rm -f "$tmpfile"
            echo "[Self-Update] Update complete. Restarting..."
            exec "$script_path" "$@"
        else
            echo "[Self-Update] Update skipped by user."
            rm -f "$tmpfile"
        fi
    else
        rm -f "$tmpfile"
        echo "[Self-Update] Already up to date."
    fi
}

# Call selfUpdate at the very start of the script
selfUpdate

# =============================
# Function: nestedPlasma
# =============================
# Launches a nested KDE Plasma Wayland session and sets up Minecraft autostart.
# Needed so Minecraft can run in a clean, isolated desktop environment (avoiding SteamOS overlays, etc).
# The autostart .desktop file ensures Minecraft launches automatically inside the nested session.
nestedPlasma() {
    # Unset variables that may interfere with launching a nested session
    unset LD_PRELOAD XDG_DESKTOP_PORTAL_DIR XDG_SEAT_PATH XDG_SESSION_PATH
    # Get current screen resolution (e.g., 1280x800)
    RES=$(xdpyinfo 2>/dev/null | awk '/dimensions/{print $2}')
    [ -z "$RES" ] && RES="1280x800"
    # Create a wrapper for kwin_wayland with the correct resolution
    cat <<EOF > $target/kwin_wayland_wrapper
#!/bin/bash
/usr/bin/kwin_wayland_wrapper --width ${RES%x*} --height ${RES#*x} --no-lockscreen \$@
EOF
    chmod +x $target/kwin_wayland_wrapper
    export PATH=$target:$PATH
    # Write an autostart .desktop file that will re-invoke this script with a special argument
    SCRIPT_PATH="$(readlink -f "$0")"
    mkdir -p ~/.config/autostart
    cat <<EOF > ~/.config/autostart/minecraft-launch.desktop
[Desktop Entry]
Name=Minecraft Split Launch
Exec=$SCRIPT_PATH launchFromPlasma
Type=Application
X-KDE-AutostartScript=true
EOF
    # Start nested Plasma session (never returns)
    exec dbus-run-session startplasma-wayland
}

# =============================
# Function: launchGame
# =============================
# Launches a single Minecraft instance using PollyMC, with KDE inhibition to prevent
# the system from sleeping, activating the screensaver, or changing color profiles.
# Arguments:
#   $1 = PollyMC instance name (e.g., 1.21.5-1)
#   $2 = Player name (e.g., P1)
launchGame() {
    if command -v kde-inhibit >/dev/null 2>&1; then
        kde-inhibit --power --screenSaver --colorCorrect --notifications ~/.local/share/PollyMC/PollyMC-Linux-x86_64.AppImage -l "$1" -a "$2" &
    else
        echo "[Warning] kde-inhibit not found. Running PollyMC without KDE inhibition."
        ~/.local/share/PollyMC/PollyMC-Linux-x86_64.AppImage -l "$1" -a "$2" &
    fi
    sleep 10 # Give time for the instance to start (avoid race conditions)
}

# =============================
# Function: hidePanels
# =============================
# Kills all plasmashell processes to remove KDE panels and widgets. This is a brute-force workaround
# that works even in nested Plasma Wayland sessions, where scripting APIs may not work.
hidePanels() {
    if command -v plasmashell >/dev/null 2>&1; then
        pkill plasmashell
        sleep 1
        if pgrep -u "$USER" plasmashell >/dev/null; then
            killall plasmashell
            sleep 1
        fi
        if pgrep -u "$USER" plasmashell >/dev/null; then
            pkill -9 plasmashell
            sleep 1
        fi
    else
        echo "[Info] plasmashell not found. Skipping KDE panel hiding."
    fi
}

# =============================
# Function: restorePanels
# =============================
# Restarts plasmashell to restore all KDE panels and widgets after gameplay.
restorePanels() {
    if command -v plasmashell >/dev/null 2>&1; then
        nohup plasmashell >/dev/null 2>&1 &
        sleep 2
    else
        echo "[Info] plasmashell not found. Skipping KDE panel restore."
    fi
}

# =============================
# Function: getControllerCount
# =============================
# Detects the number of controllers (1–4) by counting /dev/input/js* devices.
# Steam Input (when Steam is running) creates duplicate devices, so we halve the count (rounding up).
# Ensures at least 1 and at most 4 controllers are reported.
# Logic:
#   - Counts all /dev/input/js* devices (joysticks/gamepads recognized by the system)
#   - Checks if the main Steam client is running (native or Flatpak)
#   - Only halves the count if the main Steam client is running (not just helpers)
#   - Returns a value between 1 and 4 (inclusive)
getControllerCount() {
    local count
    local steam_running=0
    # Count all joystick/gamepad devices
    count=$(ls /dev/input/js* 2>/dev/null | wc -l)
    # Only halve if the main Steam client is running (native or Flatpak)
    #   - pgrep -x steam: native Steam client
    #   - pgrep -f '^/app/bin/steam$': Flatpak Steam binary
    #   - pgrep -f 'flatpak run com.valvesoftware.Steam': Flatpak Steam launcher
    if pgrep -x steam >/dev/null \
        || pgrep -f '^/app/bin/steam$' >/dev/null \
        || pgrep -f 'flatpak run com.valvesoftware.Steam' >/dev/null; then
        steam_running=1
    fi
    # If Steam is running, halve the count (rounding up) to account for Steam Input duplicates
    if [ "$steam_running" -eq 1 ]; then
        count=$(( (count + 1) / 2 ))
    fi
    # Clamp the count between 1 and 4
    [ "$count" -gt 4 ] && count=4
    [ "$count" -lt 1 ] && count=1
    # Output the detected controller count
    echo "$count"
}

# =============================
# Function: setSplitscreenModeForPlayer
# =============================
# Writes the splitscreen.properties config for the splitscreen mod for each player instance.
# This tells the mod which part of the screen each instance should use.
# Arguments:
#   $1 = Player number (1–4)
#   $2 = Total number of controllers/players
setSplitscreenModeForPlayer() {
    local player=$1
    local numberOfControllers=$2
    local config_path="$HOME/.local/share/PollyMC/instances/latestUpdate-${player}/.minecraft/config/splitscreen.properties"
    mkdir -p "$(dirname $config_path)"
    local mode="FULLSCREEN"
    # Decide the splitscreen mode for this player based on total controllers
    case "$numberOfControllers" in
        1)
            mode="FULLSCREEN" # Single player: use whole screen
            ;;
        2)
            if [ "$player" = 1 ]; then mode="TOP"; else mode="BOTTOM"; fi # 2 players: split top/bottom
            ;;
        3)
            if [ "$player" = 1 ]; then mode="TOP";
            elif [ "$player" = 2 ]; then mode="BOTTOM_LEFT";
            else mode="BOTTOM_RIGHT"; fi # 3 players: 1 top, 2 bottom corners
            ;;
        4)
            if [ "$player" = 1 ]; then mode="TOP_LEFT";
            elif [ "$player" = 2 ]; then mode="TOP_RIGHT";
            elif [ "$player" = 3 ]; then mode="BOTTOM_LEFT";
            else mode="BOTTOM_RIGHT"; fi # 4 players: 4 corners
            ;;
    esac
    # Write the config file for the mod
    echo -e "gap=1\nmode=$mode" > "$config_path"
    sync
    sleep 0.5
}

# =============================
# Function: launchGames
# =============================
# Hides panels, launches the correct number of Minecraft instances, and restores panels after.
# Handles all splitscreen logic and per-player config.
launchGames() {
    hidePanels # Remove KDE panels for a clean game view
    numberOfControllers=$(getControllerCount) # Detect how many players
    for player in $(seq 1 $numberOfControllers); do
        setSplitscreenModeForPlayer "$player" "$numberOfControllers" # Write config for this player
        launchGame "latestUpdate-$player" "P$player" # Launch Minecraft instance for this player
    done
    wait # Wait for all Minecraft instances to exit
    restorePanels # Bring back KDE panels
    sleep 2 # Give time for panels to reappear
}

# =============================
# Function: isSteamDeckGameMode
# =============================
# Returns 0 if running on Steam Deck in Game Mode, 1 otherwise.
isSteamDeckGameMode() {
    local dmi_file="/sys/class/dmi/id/product_name"
    local dmi_contents=""
    if [ -f "$dmi_file" ]; then
        dmi_contents="$(cat "$dmi_file" 2>/dev/null)"
    fi
    if echo "$dmi_contents" | grep -Ei 'Steam Deck|Jupiter' >/dev/null; then
        if [ "$XDG_SESSION_DESKTOP" = "gamescope" ] && [ "$XDG_CURRENT_DESKTOP" = "gamescope" ]; then
            return 0
        fi
        if pgrep -af 'steam' | grep -q '\-gamepadui'; then
            return 0
        fi
    else
        # Fallback: If both XDG vars are gamescope and user is deck, assume Steam Deck Game Mode
        if [ "$XDG_SESSION_DESKTOP" = "gamescope" ] && [ "$XDG_CURRENT_DESKTOP" = "gamescope" ] && [ "$USER" = "deck" ]; then
            return 0
        fi
        # Additional fallback: nested session (gamescope+KDE, user deck)
        if [ "$XDG_SESSION_DESKTOP" = "gamescope" ] && [ "$XDG_CURRENT_DESKTOP" = "KDE" ] && [ "$USER" = "deck" ]; then
            return 0
        fi
    fi
    return 1
}

# =============================
# Always remove the autostart file on script exit to prevent unwanted autostart on boot
cleanup_autostart() {
    rm -f "$HOME/.config/autostart/minecraft-launch.desktop"
}
trap cleanup_autostart EXIT


# =============================
# MAIN LOGIC: Entry Point
# =============================
# Universal: Steam Deck Game Mode = nested KDE, else just launch on current desktop
if isSteamDeckGameMode; then
    if [ "$1" = launchFromPlasma ]; then
        # Inside nested Plasma session: launch Minecraft splitscreen and logout when done
        rm ~/.config/autostart/minecraft-launch.desktop
        launchGames
        qdbus org.kde.Shutdown /Shutdown org.kde.Shutdown.logout
    else
        # Not yet in nested session: start it
        nestedPlasma
    fi
else
    # Not in Game Mode: just launch Minecraft instances directly
    numberOfControllers=$(getControllerCount)
    for player in $(seq 1 $numberOfControllers); do
        setSplitscreenModeForPlayer "$player" "$numberOfControllers"
        launchGame "latestUpdate-$player" "P$player"
    done
    wait
fi



