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
LAUNCH_DEBUG_LOG="$HOME/.local/share/PolyMC/splitscreen-launch-debug.log"

# =============================
# Function: detectLauncher
# =============================
# Detects PolyMC launcher for splitscreen gameplay.
# Returns launcher paths and executable info.
detectLauncher() {
    # Check if PolyMC is available.
    if [ -f "$HOME/.local/share/PolyMC/PolyMC.AppImage" ] && [ -x "$HOME/.local/share/PolyMC/PolyMC.AppImage" ]; then
        export LAUNCHER_DIR="$HOME/.local/share/PolyMC"
        export LAUNCHER_EXEC="$HOME/.local/share/PolyMC/PolyMC.AppImage"
        export LAUNCHER_NAME="PolyMC"
        return 0
    fi
    
    echo "[Error] PolyMC not found at $HOME/.local/share/PolyMC/" >&2
    echo "[Error] Please run the Minecraft Splitscreen installer to set up PolyMC" >&2
    return 1
}

# Detect and set launcher variables at startup
if ! detectLauncher; then
    echo "[Error] Cannot continue without a compatible Minecraft launcher" >&2
    exit 1
fi

echo "[Info] Using $LAUNCHER_NAME for splitscreen gameplay"

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
            # Non-interactive launch (desktop shortcut/autostart/Game Mode path):
            # do not block or abort gameplay flow for an update prompt.
            echo "[Self-Update] Update available. Skipping prompt in non-interactive mode."
            rm -f "$tmpfile"
            return
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

# Call selfUpdate at the very start of the script, except in the nested
# autostart handoff path where we want deterministic immediate launch.
if [ "${1:-}" != "launchFromPlasma" ]; then
    selfUpdate
fi

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
# Launches a single Minecraft instance using the detected launcher, with KDE inhibition to prevent
# the system from sleeping, activating the screensaver, or changing color profiles.
# Arguments:
#   $1 = Launcher instance name (e.g., latestUpdate-1)
#   $2 = Player name (e.g., P1)
launchGame() {
    local instance_name="$1"
    local account_name="$2"
    local joystick_device="${3:-}"

    echo "[Info] Launching $LAUNCHER_NAME instance '$instance_name' with account '$account_name'..."
    if [ -n "$joystick_device" ]; then
        echo "[Info]   -> Restricting instance input to joystick device: $joystick_device"
    fi

    local -a launch_cmd
    launch_cmd=("$LAUNCHER_EXEC" -l "$instance_name" -a "$account_name")

    # SDL hint used by Controllable's bundled SDL backend. This constrains each process
    # to a single joystick path to reduce cross-instance controller collisions.
    local -a launch_env
    launch_env=(env)
    if [ -n "$joystick_device" ]; then
        launch_env+=("SDL_JOYSTICK_DEVICE=$joystick_device")
    fi
    # Steam can inject a very large SDL_GAMECONTROLLER_IGNORE_DEVICES blacklist that may
    # include perfectly valid controllers. Clear it for launched instances.
    launch_env+=("SDL_GAMECONTROLLER_IGNORE_DEVICES=")
    # Prefer physical controllers over Steam virtual pads in Controllable.
    launch_env+=("SDL_GAMECONTROLLER_ALLOW_STEAM_VIRTUAL_GAMEPAD=0")
    # Force SDL to use Linux joystick devices instead of HIDAPI so SDL_JOYSTICK_DEVICE
    # pinning is applied per instance.
    launch_env+=("SDL_JOYSTICK_HIDAPI=0")
    # SDL expects SDL_LINUX_JOYSTICK_CLASSIC (not SDL_JOYSTICK_LINUX_CLASSIC).
    # This is required so SDL_JOYSTICK_DEVICE pinning is honored on Linux.
    launch_env+=("SDL_LINUX_JOYSTICK_CLASSIC=1")

    mkdir -p "$(dirname "$LAUNCH_DEBUG_LOG")"
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Launching $instance_name ($account_name)"
        echo "  SDL_JOYSTICK_DEVICE=${joystick_device:-<unset>}"
        echo "  SDL_GAMECONTROLLER_IGNORE_DEVICES=<cleared>"
        echo "  SDL_GAMECONTROLLER_ALLOW_STEAM_VIRTUAL_GAMEPAD=0"
        echo "  SDL_JOYSTICK_HIDAPI=0"
        echo "  SDL_LINUX_JOYSTICK_CLASSIC=1"
        echo "  XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-<unset>}"
        echo "  XDG_SESSION_DESKTOP=${XDG_SESSION_DESKTOP:-<unset>}"
    } >> "$LAUNCH_DEBUG_LOG"

    # Only use kde-inhibit inside KDE/Plasma sessions.
    # On GNOME and other desktops it can exist but fail over DBus.
    if command -v kde-inhibit >/dev/null 2>&1 && \
       [[ "${XDG_CURRENT_DESKTOP:-}" =~ KDE|PLASMA ]] ; then
        (
            kde-inhibit --power --screenSaver --colorCorrect --notifications \
                "${launch_env[@]}" "${launch_cmd[@]}" || \
                "${launch_env[@]}" "${launch_cmd[@]}"
        ) >/dev/null 2>&1 &
    else
        # On GNOME/other desktops, launch directly to avoid DBus inhibit edge cases.
        "${launch_env[@]}" "${launch_cmd[@]}" &
    fi
    # Wait for this specific instance's Java process to appear so the next
    # player's pre-launch frontend prune won't kill this launch too early.
    local launch_started=0
    local _i
    for _i in $(seq 1 120); do
        if pgrep -af "instances/${instance_name}/natives" >/dev/null 2>&1; then
            launch_started=1
            break
        fi
        sleep 0.5
    done
    if [ "$launch_started" -eq 0 ]; then
        {
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: Java process for ${instance_name} not detected within 60s"
        } >> "$LAUNCH_DEBUG_LOG"
    fi
}

# Kill PolyMC frontend wrapper processes without touching running Java game processes.
pruneLauncherFrontends() {
    local reason="${1:-manual}"
    local launcher_pids=""
    local left_after=""

    launcher_pids="$(pgrep -f 'AppRun\.wrapped|PolyMC\.AppImage|kde-inhibit.*PolyMC' 2>/dev/null || true)"
    if [ -n "$launcher_pids" ]; then
        {
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Prune launcher frontends (${reason})"
            pgrep -af 'AppRun\.wrapped|PolyMC\.AppImage|kde-inhibit.*PolyMC' 2>/dev/null || true
        } >> "$LAUNCH_DEBUG_LOG"
        kill $launcher_pids 2>/dev/null || true
        sleep 1
        left_after="$(pgrep -f 'AppRun\.wrapped|PolyMC\.AppImage|kde-inhibit.*PolyMC' 2>/dev/null || true)"
        if [ -n "$left_after" ]; then
            kill -9 $left_after 2>/dev/null || true
            sleep 0.5
        fi
    fi

    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Frontends after prune (${reason})"
        pgrep -af 'AppRun\.wrapped|PolyMC\.AppImage|kde-inhibit.*PolyMC' 2>/dev/null || echo "  <none>"
    } >> "$LAUNCH_DEBUG_LOG"
}

# =============================
# Function: getControllerDevices
# =============================
# Builds an ordered list of joystick devices to map to players. When Steam is running
# and duplicate joystick nodes appear, we pick every second entry to align with the
# existing controller count halving behavior.
getControllerDevices() {
    local -a js_devices
    local -a external_devices
    local -a deck_devices
    local -a steam_virtual_devices
    local js
    local vendor
    local product
    local base
    local id_dir

    mapfile -t js_devices < <(ls /dev/input/js* 2>/dev/null | sort -V)

    for js in "${js_devices[@]}"; do
        base="$(basename "$js")"
        id_dir="/sys/class/input/$base/device/id"
        vendor="$(cat "$id_dir/vendor" 2>/dev/null || true)"
        product="$(cat "$id_dir/product" 2>/dev/null || true)"
        # Steam virtual pads are 28de:11ff and often appear in duplicate.
        if [ "$vendor" = "28de" ] && [ "$product" = "11ff" ]; then
            steam_virtual_devices+=("$js")
        # On Steam Deck, vendor 28de (non-11ff) is Deck/Valve-origin input.
        elif [ "$vendor" = "28de" ]; then
            deck_devices+=("$js")
        # Prefer third-party external controllers whenever present.
        else
            external_devices+=("$js")
        fi
    done

    if [ "${#external_devices[@]}" -gt 0 ]; then
        printf '%s\n' "${external_devices[@]}"
    elif [ "${#deck_devices[@]}" -gt 0 ]; then
        printf '%s\n' "${deck_devices[@]}"
    elif [ "${#steam_virtual_devices[@]}" -gt 0 ]; then
        # Only expose one virtual pad node to avoid duplicate assignment.
        printf '%s\n' "${steam_virtual_devices[0]}"
    else
        printf '%s\n' "${js_devices[@]}"
    fi
}

# Upsert a key/value in a PolyMC instance.cfg file.
setInstanceCfgValue() {
    local cfg_path="$1"
    local key="$2"
    local value="$3"
    local tmp_file

    [ -f "$cfg_path" ] || return 1

    if grep -q "^${key}=" "$cfg_path"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$cfg_path"
    else
        printf '%s=%s\n' "$key" "$value" >> "$cfg_path"
    fi

    # Verify write; if it did not stick, use a full-file rewrite fallback.
    if grep -Fqx "${key}=${value}" "$cfg_path"; then
        return 0
    fi

    tmp_file="$(mktemp)"
    awk -F= -v k="$key" -v v="$value" '
        BEGIN { updated=0 }
        $1 == k { print k "=" v; updated=1; next }
        { print }
        END { if (!updated) print k "=" v }
    ' "$cfg_path" > "$tmp_file"
    mv "$tmp_file" "$cfg_path"

    grep -Fqx "${key}=${value}" "$cfg_path"
}

# Configure per-instance wrapper command so controller pinning is applied at the
# actual game process level (instead of only the launcher process environment).
configureInstanceControllerWrapper() {
    local instance_name="$1"
    local joystick_device="${2:-}"
    local cfg_path="$LAUNCHER_DIR/instances/${instance_name}/instance.cfg"
    local wrapper_cmd=""

    [ -f "$cfg_path" ] || return 0

    if [ -n "$joystick_device" ]; then
        wrapper_cmd="env SDL_JOYSTICK_DEVICE=${joystick_device} SDL_GAMECONTROLLER_IGNORE_DEVICES= SDL_GAMECONTROLLER_ALLOW_STEAM_VIRTUAL_GAMEPAD=0 SDL_JOYSTICK_HIDAPI=0 SDL_LINUX_JOYSTICK_CLASSIC=1"
        setInstanceCfgValue "$cfg_path" "OverrideCommands" "true"
        setInstanceCfgValue "$cfg_path" "WrapperCommand" "$wrapper_cmd"
    else
        # No pinning target for this instance; clear wrapper override.
        setInstanceCfgValue "$cfg_path" "OverrideCommands" "false"
        setInstanceCfgValue "$cfg_path" "WrapperCommand" ""
    fi

    # Log what ended up in the config so we can diagnose any launcher-side override.
    mkdir -p "$(dirname "$LAUNCH_DEBUG_LOG")"
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Wrapper config for ${instance_name}"
        echo "  $(grep -m1 '^OverrideCommands=' "$cfg_path" || echo 'OverrideCommands=<missing>')"
        echo "  $(grep -m1 '^WrapperCommand=' "$cfg_path" || echo 'WrapperCommand=<missing>')"
    } >> "$LAUNCH_DEBUG_LOG"
}

# Controllable persists manually selected controllers per instance. If this file
# is stale (e.g., both instances saved as Steam Deck), it can override launch-time
# device filtering and cause every instance to grab the same controller.
clearControllableSelection() {
    local instance_name="$1"
    local selected_file="$LAUNCHER_DIR/instances/${instance_name}/.minecraft/config/controllable/selected_controllers.json"
    rm -f "$selected_file"
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
    local config_path="$LAUNCHER_DIR/instances/latestUpdate-${player}/.minecraft/config/splitscreen.properties"
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
    local -a controller_devices
    numberOfControllers=$(getControllerCount) # Detect how many players
    mapfile -t controller_devices < <(getControllerDevices)
    if [ "${#controller_devices[@]}" -gt 0 ]; then
        numberOfControllers="${#controller_devices[@]}"
        [ "$numberOfControllers" -gt 4 ] && numberOfControllers=4
    fi

    if [ "${#controller_devices[@]}" -gt 0 ]; then
        echo "[Info] Detected joystick devices for assignment: ${controller_devices[*]}"
    else
        echo "[Info] No joystick devices detected for per-instance input pinning"
    fi

    for player in $(seq 1 $numberOfControllers); do
        local joystick_device=""
        if [ "$player" -le "${#controller_devices[@]}" ]; then
            joystick_device="${controller_devices[$((player-1))]}"
        fi
        if [ "$player" -gt 1 ]; then
            pruneLauncherFrontends "pre-launch latestUpdate-$player"
        fi
        clearControllableSelection "latestUpdate-$player"
        configureInstanceControllerWrapper "latestUpdate-$player" "$joystick_device"
        setSplitscreenModeForPlayer "$player" "$numberOfControllers" # Write config for this player
        launchGame "latestUpdate-$player" "P$player" "$joystick_device" # Launch Minecraft instance for this player
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
    local -a controller_devices
    numberOfControllers=$(getControllerCount)
    mapfile -t controller_devices < <(getControllerDevices)
    if [ "${#controller_devices[@]}" -gt 0 ]; then
        numberOfControllers="${#controller_devices[@]}"
        [ "$numberOfControllers" -gt 4 ] && numberOfControllers=4
    fi

    if [ "${#controller_devices[@]}" -gt 0 ]; then
        echo "[Info] Detected joystick devices for assignment: ${controller_devices[*]}"
    else
        echo "[Info] No joystick devices detected for per-instance input pinning"
    fi

    for player in $(seq 1 $numberOfControllers); do
        local joystick_device=""
        if [ "$player" -le "${#controller_devices[@]}" ]; then
            joystick_device="${controller_devices[$((player-1))]}"
        fi
        if [ "$player" -gt 1 ]; then
            pruneLauncherFrontends "pre-launch latestUpdate-$player"
        fi
        clearControllableSelection "latestUpdate-$player"
        configureInstanceControllerWrapper "latestUpdate-$player" "$joystick_device"
        setSplitscreenModeForPlayer "$player" "$numberOfControllers"
        launchGame "latestUpdate-$player" "P$player" "$joystick_device"
    done
    wait
fi
