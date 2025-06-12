#!/bin/bash

# =============================
# Minecraft Splitscreen Launcher for Steam Deck
# =============================
# This script launches 1–4 Minecraft instances in splitscreen mode on a Steam Deck,
# using a nested KDE Plasma session and a splitscreen mod. It handles controller detection,
# per-instance mod config, KDE panel hiding/restoring, and reliable autostart in a nested session.
#
# HOW IT WORKS:
# 1. If not already in a Plasma session, launches a nested Plasma Wayland session.
# 2. Sets up an autostart .desktop file to re-invoke itself inside the nested session.
# 3. Detects how many controllers are connected (1–4, with Steam Input quirks handled).
# 4. For each player, writes the correct splitscreen mod config and launches a Minecraft instance.
# 5. Hides KDE panels for a clean splitscreen experience (by killing plasmashell), then restores them.
# 6. Logs out of the nested session when done.
#
# NOTE: This script is heavily commented for clarity and future maintainers!

# Set a temporary directory for intermediate files (used for wrappers, etc)
export target=/tmp

# =============================
# Function: nestedPlasma
# =============================
# Launches a nested KDE Plasma Wayland session and sets up Minecraft autostart.
# This is needed so Minecraft can run in a clean, isolated desktop environment
# (avoiding SteamOS overlays, etc). The autostart .desktop file ensures Minecraft
# launches automatically inside the nested session.
nestedPlasma() {
    # Unset variables that may interfere with launching a nested session
    unset LD_PRELOAD XDG_DESKTOP_PORTAL_DIR XDG_SEAT_PATH XDG_SESSION_PATH
    # Get current screen resolution (e.g., 1280x800)
    RES=$(xdpyinfo | awk '/dimensions/{print $2}')
    # Create a wrapper for kwin_wayland with the correct resolution
    cat <<EOF > $target/kwin_wayland_wrapper
#!/bin/bash
/usr/bin/kwin_wayland_wrapper --width ${RES%x*} --height ${RES#*x} --no-lockscreen \$@
EOF
    chmod +x $target/kwin_wayland_wrapper
    export PATH=$target:$PATH

    # Write an autostart .desktop file that will re-invoke this script with a special argument
    # This ensures Minecraft launches automatically inside the nested session
    SCRIPT_PATH="$(readlink -f "$0")"
    mkdir -p ~/.config/autostart
    cat <<EOF > ~/.config/autostart/minecraft-launch.desktop
[Desktop Entry]
Name=Minecraft Split Launch
Exec=$SCRIPT_PATH launchFromPlasma
Type=Application
X-KDE-AutostartScript=true
EOF

    # Start the nested KDE Plasma Wayland session (this blocks until session ends)
    dbus-run-session startplasma-wayland
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
    kde-inhibit --power --screenSaver --colorCorrect --notifications ~/.local/share/PollyMC/PollyMC-Linux-x86_64.AppImage -l "$1" -a "$2" &
    sleep 10 # Give time for the instance to start (avoid race conditions)
}

# =============================
# Function: hidePanels
# =============================
# Kills plasmashell to remove all KDE panels and widgets. This is a brute-force workaround
# that works even in nested Plasma Wayland sessions, where scripting APIs may not work.
hidePanels() {
    # Kill plasmashell to remove all panels (Wayland workaround)
    pkill plasmashell
}

# =============================
# Function: restorePanels
# =============================
# Restarts plasmashell to restore all KDE panels and widgets after gameplay.
restorePanels() {
    # Restart plasmashell to restore panels
    nohup plasmashell >/dev/null 2>&1 &
    # Wait a bit for it to come back (avoid race conditions)
    sleep 2
}

# =============================
# Function: getControllerCount
# =============================
# Detects the number of controllers (1–4) by counting /dev/input/js* devices.
# Steam Input creates duplicate devices, so we halve the count (rounding up).
# Ensures at least 1 and at most 4 controllers are reported.
getControllerCount() {
    local count
    count=$(ls /dev/input/js* 2>/dev/null | wc -l)
    count=$(( (count + 1) / 2 ))  # Halve, rounding up, to account for Steam Input duplicates
    [ "$count" -gt 4 ] && count=4
    [ "$count" -lt 1 ] && count=1
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
    local config_path="~/.local/share/PollyMC/instances/1.21.5-${player}/.minecraft/config/splitscreen.properties"
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
    # Log for debugging (shows what was written)
    echo "[DEBUG] splitscreen.properties for player $player (controllers: $numberOfControllers):" >> "$(dirname "$0")/minecraft.sh.log"
    cat "$config_path" >> "$(dirname "$0")/minecraft.sh.log"
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
        launchGame "1.21.5-$player" "P$player" # Launch Minecraft instance for this player
    done
    #splitScreen "Minecraft"  # Commented out: mod handles window placement
    wait # Wait for all Minecraft instances to exit
    restorePanels # Bring back KDE panels
    sleep 2 # Give time for panels to reappear
}

# =============================
# MAIN LOGIC: Entry Point
# =============================
# Handles autostart, nested session, and launching. This block ensures the script
# works both when run directly and when autostarted inside the nested session.
(
    # Log every invocation for debugging
    echo "$(date) - Script called with $# arguments: $@" >> ~/minecraft-launch.log

    if [ "$1" = launchFromPlasma ]; then
        # If autostarted inside nested session, remove autostart file so it doesn't relaunch
        rm ~/.config/autostart/minecraft-launch.desktop
        launchGames # Launch Minecraft instances
        # Log out of nested Plasma session after games close
        qdbus org.kde.Shutdown /Shutdown org.kde.Shutdown.logout
    elif xwininfo -root -tree | grep -q plasmashell; then
        # If already in a Plasma session, just launch games (no nesting needed)
        launchGames
    else
        # Otherwise, start a nested Plasma session (for clean environment)
        nestedPlasma
    fi
)
