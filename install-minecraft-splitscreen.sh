#!/bin/bash

# =============================
# Minecraft Splitscreen Installer for Steam Deck & Linux PCs
# =============================
# This script automates the setup of PollyMC, Minecraft instances, required mods,
# and the splitscreen launcher script. It is designed to be portable and easy to use
# on any Linux device.
#
# WHAT IT DOES:
# 1. Downloads the latest PollyMC AppImage (or uses a specified version).
# 2. Sets up the PollyMC directory structure in ~/.local/share/PollyMC.
# 3. Downloads and installs the splitscreen mod and any other required mods.
# 4. Copies the splitscreen launcher script to the PollyMC directory and makes it executable.
# 5. Optionally creates a desktop shortcut for easy launching.
#
# NOTE: This script is heavily commented for clarity and future maintainers!

set -e

# --------- CONFIGURABLE VARIABLES ---------
POLLYMC_DIR="$HOME/.local/share/PollyMC"
POLLYMC_APPIMAGE_URL="https://github.com/fn2006/PollyMC/releases/download/8.0/PollyMC-Linux-x86_64.AppImage"
SPLITSCREEN_MOD_URL="https://cdn.modrinth.com/data/yJgqfSDR/versions/9U4TVf3r/splitscreen-0.9.0%2B1.21.5.jar"
CONTROLLER_MOD_URL="https://media.forgecdn.net/files/6413/241/controllable-0.19.0-mc1.21.5-fabric.jar"
IN_GAME_ACCOUNT_SWITCHER_URL="https://cdn.modrinth.com/data/cudtvDnd/versions/96FYffnc/IAS-Fabric-1.21.5-9.0.2.jar"
MOD_MENU_URL="https://cdn.modrinth.com/data/mOgUt4GM/versions/T7GjZmwP/modmenu-14.0.0-rc.2.jar"
SODIUM_MOD_URL="https://cdn.modrinth.com/data/AANobbMI/versions/DA250htH/sodium-fabric-0.6.13%2Bmc1.21.5.jar"
LITHIUM_MOD_URL="https://cdn.modrinth.com/data/gvQqBUqZ/versions/VWYoZjBF/lithium-fabric-0.16.2%2Bmc1.21.5.jar"
SODIUM_EXTRA_MOD_URL="https://cdn.modrinth.com/data/PtjYWJkn/versions/E5w6eZNE/sodium-extra-fabric-0.6.3%2Bmc1.21.5.jar"
YACL_MOD_URL="https://cdn.modrinth.com/data/1eAoo2KR/versions/5yBEzonb/yet_another_config_lib_v3-3.6.6%2B1.21.5-fabric.jar"
IRIS_MOD_URL="https://cdn.modrinth.com/data/YL57xq9U/versions/U6evbjd0/iris-fabric-1.8.11%2Bmc1.21.5.jar"
PUZZLE_MOD_URL="https://cdn.modrinth.com/data/3IuO68q1/versions/JyVlkrSf/puzzle-fabric-2.1.0%2B1.21.5.jar"
FERRITECORE_MOD_URL="https://cdn.modrinth.com/data/uXXizFIs/versions/CtMpt7Jr/ferritecore-8.0.0-fabric.jar"
ENTITYCULLING_MOD_URL="https://cdn.modrinth.com/data/NNAgCjsB/versions/29GV7fju/entityculling-fabric-1.7.4-mc1.21.5.jar"
LAMB_DYNAMIC_LIGHTS_MOD_URL="https://cdn.modrinth.com/data/yBW8D80W/versions/STvJaSpP/lambdynamiclights-4.2.7%2B1.21.5.jar"
BETTER_NAME_VISIBILITY_MOD_URL="https://cdn.modrinth.com/data/pSfNeCCY/versions/UX9XhQ6r/name-visibility-2.0.2.jar"
JUST_ZOOM_MOD_URL="https://cdn.modrinth.com/data/iAiqcykM/versions/HZHRCuLM/justzoom_fabric_2.1.0_MC_1.21.5.jar"
FULL_BRIGHTNESS_TOGGLE_MOD_URL="https://cdn.modrinth.com/data/aEK1KhsC/versions/PeVUcOGT/fullbrightnesstoggle-1.21.5-4.3.jar"
OLD_COMBAT_MOD_URL="https://cdn.modrinth.com/data/dZ1APLkO/versions/UUtG1Pw2/old-combat-mod-1.1.1.jar"
MINECRAFT_VERSION="1.21.5"
MODS_DIR="$POLLYMC_DIR/instances/$MINECRAFT_VERSION-1/.minecraft/mods"
LAUNCHER_SCRIPT_URL="https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/minecraft.sh"

# Helper: Copy a mod to all instance mods folders
copy_mod_to_all_instances() {
    local modfile="$1"
    for i in 1 2 3 4; do
        cp "$modfile" "$POLLYMC_DIR/instances/$MINECRAFT_VERSION-$i/.minecraft/mods/"
    done
}

# --------- CREATE POLLYMC DIRECTORY STRUCTURE ---------
echo "[INFO] Creating PollyMC directory structure..."
mkdir -p "$POLLYMC_DIR/instances/$MINECRAFT_VERSION-1/.minecraft/mods"
mkdir -p "$POLLYMC_DIR/instances/$MINECRAFT_VERSION-2/.minecraft/mods"
mkdir -p "$POLLYMC_DIR/instances/$MINECRAFT_VERSION-3/.minecraft/mods"
mkdir -p "$POLLYMC_DIR/instances/$MINECRAFT_VERSION-4/.minecraft/mods"

# --------- CREATE TEMP DIRECTORY FOR DOWNLOADS ---------
# Create a temporary directory for all downloads to avoid file clashes and ensure atomic operations
TEMP_DIR=$(mktemp -d)
echo "[INFO] Using temp directory: $TEMP_DIR"

# --------- DOWNLOAD POLLYMC APPIMAGE ---------
# Download the PollyMC AppImage to the temp directory, then move it to the PollyMC directory
echo "[INFO] Downloading PollyMC AppImage..."
curl -L "$POLLYMC_APPIMAGE_URL" -o "$TEMP_DIR/PollyMC-Linux-x86_64.AppImage"
chmod +x "$TEMP_DIR/PollyMC-Linux-x86_64.AppImage"
mv "$TEMP_DIR/PollyMC-Linux-x86_64.AppImage" "$POLLYMC_DIR/PollyMC-Linux-x86_64.AppImage"

# --------- DOWNLOAD MODS TO TEMP DIR ---------
# Download all required mods into the temp directory
echo "[INFO] Downloading mods to temp directory..."
curl -L "$SPLITSCREEN_MOD_URL" -o "$TEMP_DIR/splitscreen.jar"
curl -L "$CONTROLLER_MOD_URL" -o "$TEMP_DIR/controllable.jar"
curl -L "$IN_GAME_ACCOUNT_SWITCHER_URL" -o "$TEMP_DIR/in-game-account-switcher.jar"
curl -L "$MOD_MENU_URL" -o "$TEMP_DIR/modmenu.jar"
curl -L "$SODIUM_MOD_URL" -o "$TEMP_DIR/sodium-fabric-0.6.13+mc1.21.5.jar"
curl -L "$LITHIUM_MOD_URL" -o "$TEMP_DIR/lithium.jar"
curl -L "$SODIUM_EXTRA_MOD_URL" -o "$TEMP_DIR/sodium-extra.jar"
curl -L "$YACL_MOD_URL" -o "$TEMP_DIR/yacl.jar"
curl -L "$IRIS_MOD_URL" -o "$TEMP_DIR/iris.jar"
curl -L "$PUZZLE_MOD_URL" -o "$TEMP_DIR/puzzle.jar"
curl -L "$FERRITECORE_MOD_URL" -o "$TEMP_DIR/ferritecore.jar"
curl -L "$ENTITYCULLING_MOD_URL" -o "$TEMP_DIR/entityculling.jar"
curl -L "$LAMB_DYNAMIC_LIGHTS_MOD_URL" -o "$TEMP_DIR/lambdynamiclights.jar"
curl -L "$BETTER_NAME_VISIBILITY_MOD_URL" -o "$TEMP_DIR/betternamevisibility.jar"
curl -L "$JUST_ZOOM_MOD_URL" -o "$TEMP_DIR/justzoom.jar"
curl -L "$FULL_BRIGHTNESS_TOGGLE_MOD_URL" -o "$TEMP_DIR/fullbrightnesstoggle.jar"
curl -L "$OLD_COMBAT_MOD_URL" -o "$TEMP_DIR/old-combat-mod.jar"

# Use helper function to copy each mod to all instance mods folders from temp dir
for modfile in "$TEMP_DIR"/*.jar; do
    copy_mod_to_all_instances "$modfile"
done

# --------- DOWNLOAD LAUNCHER SCRIPT TO TEMP DIR ---------
# Download the splitscreen launcher script to the temp directory, then move it to the PollyMC directory
echo "[INFO] Downloading splitscreen launcher script..."
curl -L "$LAUNCHER_SCRIPT_URL" -o "$TEMP_DIR/minecraft.sh"
chmod +x "$TEMP_DIR/minecraft.sh"
mv "$TEMP_DIR/minecraft.sh" "$POLLYMC_DIR/minecraft.sh"

# --------- DOWNLOAD AND SETUP JDK 21 IN TEMP DIR ---------
# Download and extract JDK 21 in the temp directory, then move it to the PollyMC directory if not already present
echo "[INFO] Downloading and setting up JDK 21..."
JDK21_URL="https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.tar.gz"
JDK21_DIR="$POLLYMC_DIR/jdk-21"
if [ ! -d "$JDK21_DIR" ]; then
    curl -L "$JDK21_URL" -o "$TEMP_DIR/jdk-21.tar.gz"
    tar -xzf "$TEMP_DIR/jdk-21.tar.gz" -C "$TEMP_DIR/"
    JDK_EXTRACTED_DIR=$(tar -tf "$TEMP_DIR/jdk-21.tar.gz" | head -1 | cut -f1 -d"/")
    if [ "$JDK_EXTRACTED_DIR" != "jdk-21" ]; then
        mv "$TEMP_DIR/$JDK_EXTRACTED_DIR" "$JDK21_DIR"
    else
        mv "$TEMP_DIR/jdk-21" "$JDK21_DIR"
    fi
fi
JAVA_PATH="$JDK21_DIR/bin/java"

# --------- CONFIGURE OFFLINE ACCOUNTS FOR EACH PLAYER ---------
echo "[INFO] Copying accounts.json from script directory to PollyMC config..."
cp "$(dirname "$0")/accounts.json" "$POLLYMC_DIR/accounts.json"

# --------- INSTALL FABRIC LOADER IN EACH PROFILE ---------
# For each PollyMC instance, create or update the instance.cfg to use Fabric Loader and the downloaded JDK 21
echo "[INFO] Installing Fabric Loader in each PollyMC instance..."
for i in 1 2 3 4; do
    INSTANCE_DIR="$POLLYMC_DIR/instances/$MINECRAFT_VERSION-$i"
    # Create instance.cfg with Fabric Loader if it doesn't exist
    if [ ! -f "$INSTANCE_DIR/instance.cfg" ]; then
        cat <<EOF > "$INSTANCE_DIR/instance.cfg"
InstanceType=OneSix
name=$MINECRAFT_VERSION-$i
iconKey=minecraft
iconPath=

[LoaderComponent]
id=fabric-loader
version=0.15.7+1.21.5
EOF
    fi
    # Set javaPath to JDK 21 in the config (add or update as needed)
    if ! grep -q '^javaPath=' "$INSTANCE_DIR/instance.cfg"; then
        echo "javaPath=$JAVA_PATH" >> "$INSTANCE_DIR/instance.cfg"
    else
        sed -i "s|^javaPath=.*|javaPath=$JAVA_PATH|" "$INSTANCE_DIR/instance.cfg"
    fi
    # Ensure mods directory exists for each instance
    mkdir -p "$INSTANCE_DIR/.minecraft/mods"
done

# --------- DOWNLOAD MINECRAFT AND FABRIC LOADER FOR EACH INSTANCE ---------
echo "[INFO] Downloading Minecraft $MINECRAFT_VERSION and Fabric Loader for PollyMC splitscreen setup..."
FABRIC_INSTALLER_URL="https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.0/fabric-installer-1.0.0.jar"
FABRIC_INSTALLER_JAR="$TEMP_DIR/fabric-installer.jar"
curl -L "$FABRIC_INSTALLER_URL" -o "$FABRIC_INSTALLER_JAR"

INSTANCE1_DIR="$POLLYMC_DIR/instances/$MINECRAFT_VERSION-1"

for i in 1 2 3 4; do
    INSTANCE_DIR="$POLLYMC_DIR/instances/$MINECRAFT_VERSION-$i"
    if [ "$i" -eq 1 ]; then
        # Download Minecraft and Fabric loader for instance 1 only if not already present
        if [ ! -f "$INSTANCE1_DIR/.minecraft/versions/$MINECRAFT_VERSION/$MINECRAFT_VERSION.jar" ]; then
            echo "[INFO] Launching PollyMC to generate launcher profile for instance 1..."
            "$POLLYMC_DIR/PollyMC-Linux-x86_64.AppImage" --launch "$MINECRAFT_VERSION-1" --no-gui --quit || true
            echo "[INFO] Downloading Minecraft and Fabric for instance 1..."
            "$JAVA_PATH" -jar "$FABRIC_INSTALLER_JAR" client -mcversion $MINECRAFT_VERSION -dir "$INSTANCE1_DIR/.minecraft" --noprofile --downloadMinecraft
            "$POLLYMC_DIR/PollyMC-Linux-x86_64.AppImage" --launch "$MINECRAFT_VERSION-1" --no-gui --quit || true
        else
            echo "[INFO] Minecraft already exists for instance 1, skipping download."
        fi
    else
        # For instances 2-4, copy Minecraft from instance 1 if it exists
        if [ -d "$INSTANCE1_DIR/.minecraft/versions/$MINECRAFT_VERSION" ]; then
            echo "[INFO] Copying Minecraft core files from instance 1 to instance $i..."
            rsync -a --exclude 'mods' --exclude 'saves' --exclude 'options.txt' --exclude 'logs' --exclude 'crash-reports' --exclude 'screenshots' --exclude 'resourcepacks' --exclude 'shaderpacks' "$INSTANCE1_DIR/.minecraft/" "$INSTANCE_DIR/.minecraft/"
            echo "[INFO] Launching PollyMC to generate launcher profile for instance $i..."
            "$POLLYMC_DIR/PollyMC-Linux-x86_64.AppImage" --launch "$MINECRAFT_VERSION-$i" --no-gui --quit || true
        else
            echo "[WARN] Minecraft not found in instance 1. Skipping copy for instance $i."
        fi
        # Install Fabric loader for this instance (will not re-download Minecraft)
        "$JAVA_PATH" -jar "$FABRIC_INSTALLER_JAR" client -mcversion $MINECRAFT_VERSION -dir "$INSTANCE_DIR/.minecraft" --noprofile
        "$POLLYMC_DIR/PollyMC-Linux-x86_64.AppImage" --launch "$MINECRAFT_VERSION-$i" --no-gui --quit || true
    fi
done

# --------- (OPTIONAL) CREATE DESKTOP SHORTCUT ---------
# Create a desktop shortcut for easy launching of the splitscreen setup
echo "[INFO] Creating desktop shortcut..."
cat <<EOF > "$HOME/Desktop/Minecraft-Splitscreen.desktop"
[Desktop Entry]
Name=Minecraft Splitscreen
Exec=$POLLYMC_DIR/minecraft.sh
Type=Application
Icon=application-x-executable
Terminal=false
EOF
chmod +x "$HOME/Desktop/Minecraft-Splitscreen.desktop"

# --------- CLEAN UP TEMP DIRECTORY ---------
# Remove the temporary directory and all its contents to clean up
echo "[INFO] Cleaning up temp directory..."
rm -rf "$TEMP_DIR"

# --------- FINAL SUCCESS MESSAGE ---------
echo "[SUCCESS] Minecraft Splitscreen setup complete!"
echo "You can launch the game using the desktop shortcut or by running: $POLLYMC_DIR/minecraft.sh"
