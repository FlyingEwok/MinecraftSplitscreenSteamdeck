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
POLLYMC_APPIMAGE_URL="https://github.com/PolyMC/PolyMC/releases/download/7.0/PolyMC-Linux-7.0-x86_64.AppImage"
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
MINECRAFT_VERSION="1.21.5"
MODS_DIR="$POLLYMC_DIR/instances/$MINECRAFT_VERSION-1/.minecraft/mods"
LAUNCHER_SCRIPT_URL="https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/minecraft.sh"
OLD_COMBAT_MOD_URL="https://cdn.modrinth.com/data/dZ1APLkO/versions/UUtG1Pw2/old-combat-mod-1.1.1.jar"

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

# --------- DOWNLOAD POLLYMC APPIMAGE ---------
echo "[INFO] Downloading PollyMC AppImage..."
curl -L "$POLLYMC_APPIMAGE_URL" -o "$POLLYMC_DIR/PollyMC-Linux-x86_64.AppImage"
chmod +x "$POLLYMC_DIR/PollyMC-Linux-x86_64.AppImage"

# --------- DOWNLOAD SPLITSCREEN MOD ---------
echo "[INFO] Downloading splitscreen mod..."
curl -L "$SPLITSCREEN_MOD_URL" -o "$MODS_DIR/splitscreen.jar"
copy_mod_to_all_instances "$MODS_DIR/splitscreen.jar"

# --------- DOWNLOAD CONTROLLER MOD ---------
echo "[INFO] Downloading controller mod..."
curl -L "$CONTROLLER_MOD_URL" -o "$MODS_DIR/controllable.jar"
copy_mod_to_all_instances "$MODS_DIR/controllable.jar"

# --------- DOWNLOAD IN-GAME ACCOUNT SWITCHER MOD ---------
echo "[INFO] Downloading In-Game Account Switcher mod..."
curl -L "$IN_GAME_ACCOUNT_SWITCHER_URL" -o "$MODS_DIR/in-game-account-switcher.jar"
copy_mod_to_all_instances "$MODS_DIR/in-game-account-switcher.jar"

# --------- DOWNLOAD MOD MENU MOD ---------
echo "[INFO] Downloading Mod Menu mod..."
curl -L "$MOD_MENU_URL" -o "$MODS_DIR/modmenu.jar"
copy_mod_to_all_instances "$MODS_DIR/modmenu.jar"

# --------- DOWNLOAD SODIUM MOD ---------
echo "[INFO] Downloading Sodium mod..."
curl -L "$SODIUM_MOD_URL" -o "$MODS_DIR/sodium-fabric-0.6.13+mc1.21.5.jar"
copy_mod_to_all_instances "$MODS_DIR/sodium-fabric-0.6.13+mc1.21.5.jar"

# --------- DOWNLOAD LITHIUM MOD ---------
echo "[INFO] Downloading Lithium mod..."
curl -L "$LITHIUM_MOD_URL" -o "$MODS_DIR/lithium.jar"
copy_mod_to_all_instances "$MODS_DIR/lithium.jar"

# --------- DOWNLOAD SODIUM EXTRA MOD ---------
echo "[INFO] Downloading Sodium Extra mod..."
curl -L "$SODIUM_EXTRA_MOD_URL" -o "$MODS_DIR/sodium-extra.jar"
copy_mod_to_all_instances "$MODS_DIR/sodium-extra.jar"

# --------- DOWNLOAD YACL MOD (REQUIRED FOR SODIUM EXTRA) ---------
echo "[INFO] Downloading YetAnotherConfigLib (YACL) mod..."
curl -L "$YACL_MOD_URL" -o "$MODS_DIR/yacl.jar"
copy_mod_to_all_instances "$MODS_DIR/yacl.jar"

# --------- DOWNLOAD IRIS SHADERS MOD ---------
echo "[INFO] Downloading Iris Shaders mod..."
curl -L "$IRIS_MOD_URL" -o "$MODS_DIR/iris.jar"
copy_mod_to_all_instances "$MODS_DIR/iris.jar"

# --------- DOWNLOAD PUZZLE MOD ---------
echo "[INFO] Downloading Puzzle mod..."
curl -L "$PUZZLE_MOD_URL" -o "$MODS_DIR/puzzle.jar"
copy_mod_to_all_instances "$MODS_DIR/puzzle.jar"

# --------- DOWNLOAD FERRITECORE MOD ---------
echo "[INFO] Downloading FerriteCore mod..."
curl -L "$FERRITECORE_MOD_URL" -o "$MODS_DIR/ferritecore.jar"
copy_mod_to_all_instances "$MODS_DIR/ferritecore.jar"

# --------- DOWNLOAD ENTITY CULLING MOD ---------
echo "[INFO] Downloading Entity Culling mod..."
curl -L "$ENTITYCULLING_MOD_URL" -o "$MODS_DIR/entityculling.jar"
copy_mod_to_all_instances "$MODS_DIR/entityculling.jar"

# --------- DOWNLOAD LAMB DYNAMIC LIGHTS MOD ---------
echo "[INFO] Downloading LambDynamicLights mod..."
curl -L "$LAMB_DYNAMIC_LIGHTS_MOD_URL" -o "$MODS_DIR/lambdynamiclights.jar"
copy_mod_to_all_instances "$MODS_DIR/lambdynamiclights.jar"

# --------- DOWNLOAD BETTER NAME VISIBILITY MOD ---------
echo "[INFO] Downloading Better Name Visibility mod..."
curl -L "$BETTER_NAME_VISIBILITY_MOD_URL" -o "$MODS_DIR/betternamevisibility.jar"
copy_mod_to_all_instances "$MODS_DIR/betternamevisibility.jar"

# --------- DOWNLOAD JUST ZOOM MOD ---------
echo "[INFO] Downloading Just Zoom mod..."
curl -L "$JUST_ZOOM_MOD_URL" -o "$MODS_DIR/justzoom.jar"
copy_mod_to_all_instances "$MODS_DIR/justzoom.jar"

# --------- DOWNLOAD FULL BRIGHTNESS TOGGLE MOD ---------
echo "[INFO] Downloading Full Brightness Toggle mod..."
curl -L "$FULL_BRIGHTNESS_TOGGLE_MOD_URL" -o "$MODS_DIR/fullbrightnesstoggle.jar"
copy_mod_to_all_instances "$MODS_DIR/fullbrightnesstoggle.jar"

# --------- DOWNLOAD OLD COMBAT MOD ---------
echo "[INFO] Downloading Old Combat Mod..."
curl -L "$OLD_COMBAT_MOD_URL" -o "$MODS_DIR/old-combat-mod.jar"
copy_mod_to_all_instances "$MODS_DIR/old-combat-mod.jar"

# --------- DOWNLOAD LAUNCHER SCRIPT ---------
echo "[INFO] Downloading splitscreen launcher script..."
curl -L "$LAUNCHER_SCRIPT_URL" -o "$POLLYMC_DIR/minecraft.sh"
chmod +x "$POLLYMC_DIR/minecraft.sh"

# --------- INSTALL FABRIC LOADER IN EACH PROFILE ---------
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
    # Ensure mods directory exists
    mkdir -p "$INSTANCE_DIR/.minecraft/mods"
done

# --------- (OPTIONAL) CREATE DESKTOP SHORTCUT ---------
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

echo "[SUCCESS] Minecraft Splitscreen setup complete!"
echo "You can launch the game using the desktop shortcut or by running: $POLLYMC_DIR/minecraft.sh"
