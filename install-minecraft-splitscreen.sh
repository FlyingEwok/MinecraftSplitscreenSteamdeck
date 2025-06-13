#!/bin/bash
# Set the PollyMC data directory
# This is where PollyMC stores all its configuration, instances, and assets
# On Steam Deck/Linux, this is typically $HOME/.local/share/PollyMC

targetDir=$HOME/.local/share/PollyMC
mkdir -p $targetDir
pushd $targetDir

    # Download PollyMC AppImage if not already present
    if [ ! -f "PollyMC-Linux-x86_64.AppImage" ]; then
        wget https://github.com/fn2006/PollyMC/releases/download/8.0/PollyMC-Linux-x86_64.AppImage
        chmod +x PollyMC-Linux-x86_64.AppImage
    fi

    # Detect system Java (require Java 21 for modern Minecraft versions)
    # Only Java 21 is supported for new Minecraft versions
    if [ -x /usr/lib/jvm/java-21-openjdk/bin/java ]; then
        JAVA_PATH="/usr/lib/jvm/java-21-openjdk/bin/java"
    elif [ -x /usr/lib/jvm/default-runtime/bin/java ]; then
        JAVA_PATH="/usr/lib/jvm/default-runtime/bin/java"
    else
        JAVA_PATH="$(which java)"
    fi

    # Check if Java 21 is available and executable
    # Exit with a clear error if not found
    if [ -z "$JAVA_PATH" ] || ! "$JAVA_PATH" -version 2>&1 | grep -q '21'; then
        echo "Error: Java 21 is not installed or not found in a standard location. Refer to the README at https://github.com/FlyingEwok/MinecraftSplitscreenSteamdeck for installation instructions." >&2
        exit 1
    fi

    # Create a default PollyMC config if it doesn't exist
    # This configures PollyMC to skip the setup wizard and use the detected Java
    if [ ! -f pollymc.cfg ]; then
        sed 's/^            //' <<________EOF > pollymc.cfg
            [General]
            ApplicationTheme=system
            ConfigVersion=1.2
            FlameKeyShouldBeFetchedOnStartup=false
            IconTheme=pe_colored
            JavaPath=$JAVA_PATH
            Language=en_US
            LastHostname=$HOSTNAME
            MaxMemAlloc=4096
            MinMemAlloc=512
            FirstRun=false
            WizardComplete=true
________EOF
    fi

    # --- Download sampleInstance template if not present ---
    # This instance contains all mods, configs, and loader files needed for splitscreen
    TEMPLATE_INSTANCE="sampleInstance"
    if [ ! -d "$TEMPLATE_INSTANCE" ]; then
        echo "sampleInstance not found, downloading from GitHub..."
        wget -O sampleInstance.zip "https://github.com/FlyingEwok/MinecraftSplitscreenSteamdeck/archive/refs/heads/main.zip"
        unzip -q sampleInstance.zip "MinecraftSplitscreenSteamdeck-main/sampleInstance/*"
        rm -rf "$TEMPLATE_INSTANCE"
        mv MinecraftSplitscreenSteamdeck-main/sampleInstance "$TEMPLATE_INSTANCE"
        rm -rf MinecraftSplitscreenSteamdeck-main sampleInstance.zip
    fi

    # Ensure the instances directory exists
    mkdir -p "$targetDir/instances"

    # Clone the template instance 4 times for splitscreen play
    # Each instance gets a unique name in its instance.cfg
    for i in {1..4}; do
        DEST="$targetDir/instances/1.21.5-$i"
        rm -rf "$DEST"
        cp -a "$targetDir/$TEMPLATE_INSTANCE" "$DEST"
        # Update instance.cfg name for each instance
        sed -i "s/^name=.*/name=1.21.5-$i/" "$DEST/instance.cfg"
    done

    # --- Download accounts.json for splitscreen ---
    # This file contains 4 offline accounts for splitscreen play
    wget -O accounts.json "https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/accounts.json"

    # Download the launch wrapper script
    # This script is used to launch Minecraft from Steam for splitscreen
    rm -f minecraft.sh
    wget https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/minecraft.sh
    chmod +x minecraft.sh

popd

# --- Optionally add the launch wrapper to Steam automatically ---
read -p "Do you want to add the Minecraft launch wrapper to Steam? [y/N]: " add_to_steam
if [[ "$add_to_steam" =~ ^[Yy]$ ]]; then
    if ! grep -q local/share/PollyMC/minecraft ~/.steam/steam/userdata/*/config/shortcuts.vdf 2>/dev/null; then
        echo "Adding Minecraft launch wrapper to Steam..."
        steam -shutdown
        while pgrep -F ~/.steam/steam.pid; do
            sleep 1
        done
        [ -f $targetDir/shortcuts-backup.tar.xz ] || tar cJf $targetDir/shortcuts-backup.tar.xz ~/.steam/steam/userdata/*/config/shortcuts.vdf
        # Download and run the latest add-to-steam.py from the official repo for standalone use
        curl -sSL https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/add-to-steam.py | python3 -
        nohup steam &
    else
        echo "Minecraft launch wrapper already present in Steam shortcuts."
    fi
else
    echo "Skipping adding Minecraft launch wrapper to Steam."
fi

# --- Optionally create a .desktop launcher ---
# Prompt the user to create a desktop launcher for Minecraft Splitscreen
read -p "Do you want to create a desktop launcher for Minecraft Splitscreen? [y/N]: " create_desktop
if [[ "$create_desktop" =~ ^[Yy]$ ]]; then
    # Set the .desktop file name and paths
    DESKTOP_FILE_NAME="MinecraftSplitscreen.desktop"
    DESKTOP_FILE_PATH="$HOME/Desktop/$DESKTOP_FILE_NAME"
    APP_DIR="$HOME/.local/share/applications"
    mkdir -p "$APP_DIR" # Ensure the applications directory exists
    # --- Icon Handling ---
    # Use the same icon as the Steam shortcut (SteamGridDB icon)
    ICON_DIR="$targetDir/icons"
    ICON_PATH="$ICON_DIR/minecraft-splitscreen-steamgriddb.ico"
    ICON_URL="https://cdn2.steamgriddb.com/icon/add7a048049671970976f3e18f21ade3.ico"
    mkdir -p "$ICON_DIR" # Ensure the icon directory exists
    # Download the icon if it doesn't already exist
    if [ ! -f "$ICON_PATH" ]; then
        wget -O "$ICON_PATH" "$ICON_URL"
    fi
    # Determine which icon to use for the .desktop file
    if [ -f "$ICON_PATH" ]; then
        ICON_DESKTOP="$ICON_PATH" # Use the downloaded SteamGridDB icon
    elif [ -f "$targetDir/instances/1.21.5-1/icon.png" ]; then
        ICON_DESKTOP="$targetDir/instances/1.21.5-1/icon.png" # Fallback: use PollyMC instance icon
    else
        ICON_DESKTOP=application-x-executable # Fallback: use a generic system icon
    fi
    # --- Create the .desktop file ---
    # This file allows launching Minecraft Splitscreen from the desktop and application menu
    cat <<EOF > "$DESKTOP_FILE_PATH"
[Desktop Entry]
Type=Application
Name=Minecraft Splitscreen
Comment=Launch Minecraft in splitscreen mode with PollyMC
Exec=$targetDir/minecraft.sh
Icon=$ICON_DESKTOP
Terminal=false
Categories=Game;
EOF
    # Make the .desktop file executable (required for some desktop environments)
    chmod +x "$DESKTOP_FILE_PATH"
    # Copy the .desktop file to the applications directory so it appears in the app menu
    cp "$DESKTOP_FILE_PATH" "$APP_DIR/$DESKTOP_FILE_NAME"
    # Update the desktop database (if available) to register the new launcher
    update-desktop-database "$APP_DIR" 2>/dev/null || true
    echo "Desktop launcher created at $DESKTOP_FILE_PATH and added to application menu."
else
    echo "Skipping desktop launcher creation."
fi