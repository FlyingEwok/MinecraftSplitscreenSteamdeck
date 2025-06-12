#!/bin/bash
# Robust, portable, atomic Minecraft splitscreen setup for PollyMC using Fabric and user mods
set -e

POLLYMC_DIR="$HOME/.local/share/PollyMC"
MINECRAFT_VERSION="1.21.5"
FABRIC_LOADER_VERSION="0.15.7"
FABRIC_VERSION_DIR="fabric-loader-${FABRIC_LOADER_VERSION}-${MINECRAFT_VERSION}"
JAVA_DIR="$POLLYMC_DIR/jdk-21"
JAVA_PATH="$JAVA_DIR/bin/java"
TEMP_DIR=$(mktemp -d)

# Ensure PollyMC directory exists before cd
mkdir -p "$POLLYMC_DIR"
cd "$POLLYMC_DIR"

# --- Download PollyMC AppImage ---
if [ ! -f "PollyMC-Linux-x86_64.AppImage" ]; then
    wget https://github.com/fn2006/PollyMC/releases/download/8.0/PollyMC-Linux-x86_64.AppImage
    chmod +x PollyMC-Linux-x86_64.AppImage
fi

# --- Download JDK 21 ---
if [ ! -f "$JAVA_PATH" ]; then
    curl -L https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.tar.gz | tar xz -C "$POLLYMC_DIR"
    # Move to jdk-21 if extracted as something else
    JDK_EXTRACTED=$(ls -d $POLLYMC_DIR/jdk-21* | grep -v "$JAVA_DIR" | head -1)
    if [ -n "$JDK_EXTRACTED" ] && [ "$JDK_EXTRACTED" != "$JAVA_DIR" ]; then
        mv "$JDK_EXTRACTED" "$JAVA_DIR"
    fi
fi

# --- Create pollymc.cfg if missing ---
if [ ! -f pollymc.cfg ]; then
    cat <<EOF > pollymc.cfg
[General]
ApplicationTheme=system
ConfigVersion=1.2
FlameKeyShouldBeFetchedOnStartup=false
IconTheme=pe_colored
JavaPath=jdk-21/bin/java
Language=en_US
LastHostname=$HOSTNAME
MaxMemAlloc=4096
MinMemAlloc=512
EOF
fi

# --- Download all mods to temp dir ---
MOD_URLS=(
  "https://cdn.modrinth.com/data/yJgqfSDR/versions/9U4TVf3r/splitscreen-0.9.0%2B1.21.5.jar"
  "https://media.forgecdn.net/files/6413/241/controllable-0.19.0-mc1.21.5-fabric.jar"
  "https://cdn.modrinth.com/data/cudtvDnd/versions/96FYffnc/IAS-Fabric-1.21.5-9.0.2.jar"
  "https://cdn.modrinth.com/data/mOgUt4GM/versions/T7GjZmwP/modmenu-14.0.0-rc.2.jar"
  "https://cdn.modrinth.com/data/AANobbMI/versions/DA250htH/sodium-fabric-0.6.13%2Bmc1.21.5.jar"
  "https://cdn.modrinth.com/data/gvQqBUqZ/versions/VWYoZjBF/lithium-fabric-0.16.2%2Bmc1.21.5.jar"
  "https://cdn.modrinth.com/data/PtjYWJkn/versions/E5w6eZNE/sodium-extra-fabric-0.6.3%2B1.21.5.jar"
  "https://cdn.modrinth.com/data/1eAoo2KR/versions/5yBEzonb/yet_another_config_lib_v3-3.6.6%2B1.21.5-fabric.jar"
  "https://cdn.modrinth.com/data/YL57xq9U/versions/U6evbjd0/iris-fabric-1.8.11%2Bmc1.21.5.jar"
  "https://cdn.modrinth.com/data/3IuO68q1/versions/JyVlkrSf/puzzle-fabric-2.1.0%2B1.21.5.jar"
  "https://cdn.modrinth.com/data/uXXizFIs/versions/CtMpt7Jr/ferritecore-8.0.0-fabric.jar"
  "https://cdn.modrinth.com/data/NNAgCjsB/versions/29GV7fju/entityculling-fabric-1.7.4-mc1.21.5.jar"
  "https://cdn.modrinth.com/data/yBW8D80W/versions/STvJaSpP/lambdynamiclights-4.2.7%2B1.21.5.jar"
  "https://cdn.modrinth.com/data/pSfNeCCY/versions/UX9XhQ6r/name-visibility-2.0.2.jar"
  "https://cdn.modrinth.com/data/iAiqcykM/versions/HZHRCuLM/justzoom_fabric_2.1.0_MC_1.21.5.jar"
  "https://cdn.modrinth.com/data/aEK1KhsC/versions/PeVUcOGT/fullbrightnesstoggle-1.21.5-4.3.jar"
  "https://cdn.modrinth.com/data/dZ1APLkO/versions/UUtG1Pw2/old-combat-mod-1.1.1.jar"
)
for url in "${MOD_URLS[@]}"; do
  fname="$TEMP_DIR/$(basename "${url%%\?*}")"
  [ -f "$fname" ] || curl -L "$url" -o "$fname"
done

# --- Download Fabric loader jar and manifest ---
FABRIC_LOADER_JAR_URL="https://maven.fabricmc.net/net/fabricmc/fabric-loader/${FABRIC_LOADER_VERSION}/fabric-loader-${FABRIC_LOADER_VERSION}.jar"
FABRIC_MANIFEST_URL="https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}/${FABRIC_LOADER_VERSION}/profile/json"

# --- Download Minecraft client jar and version json ---
if ! command -v jq &>/dev/null; then
  sudo apt-get update && sudo apt-get install -y jq
fi
curl -sSL "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json" -o "$TEMP_DIR/version_manifest.json"
VERSION_URL=$(jq -r --arg VER "$MINECRAFT_VERSION" '.versions[] | select(.id==$VER) | .url' "$TEMP_DIR/version_manifest.json")
curl -sSL "$VERSION_URL" -o "$TEMP_DIR/mc_version.json"
JAR_URL=$(jq -r '.downloads.client.url' "$TEMP_DIR/mc_version.json")
curl -sSL "$JAR_URL" -o "$TEMP_DIR/$MINECRAFT_VERSION.jar"
cp "$TEMP_DIR/mc_version.json" "$TEMP_DIR/$MINECRAFT_VERSION.json"

# --- Create 4 instances ---
for i in {1..4}; do
  INSTANCE_DIR="$POLLYMC_DIR/instances/$MINECRAFT_VERSION-$i"
  MODS_DIR="$INSTANCE_DIR/.minecraft/mods"
  CONFIG_DIR="$INSTANCE_DIR/.minecraft/config"
  VERSIONS_DIR="$INSTANCE_DIR/.minecraft/versions"
  FABRIC_DIR="$VERSIONS_DIR/$FABRIC_VERSION_DIR"
  MC_VER_DIR="$INSTANCE_DIR/.minecraft/versions/$MINECRAFT_VERSION"
  mkdir -p "$MODS_DIR" "$CONFIG_DIR" "$FABRIC_DIR" "$MC_VER_DIR"

  # Copy all mods
  for mod in "$TEMP_DIR"/*.jar; do
    cp "$mod" "$MODS_DIR/"
  done

  # Download Fabric loader jar and manifest if not present
  [ -f "$FABRIC_DIR/fabric-loader-${FABRIC_LOADER_VERSION}.jar" ] || curl -L "$FABRIC_LOADER_JAR_URL" -o "$FABRIC_DIR/fabric-loader-${FABRIC_LOADER_VERSION}.jar"
  [ -f "$FABRIC_DIR/$FABRIC_VERSION_DIR.json" ] || curl -L "$FABRIC_MANIFEST_URL" -o "$FABRIC_DIR/$FABRIC_VERSION_DIR.json"

  # Copy Minecraft jar and json
  cp "$TEMP_DIR/$MINECRAFT_VERSION.jar" "$MC_VER_DIR/$MINECRAFT_VERSION.jar"
  cp "$TEMP_DIR/$MINECRAFT_VERSION.json" "$MC_VER_DIR/$MINECRAFT_VERSION.json"

  # options.txt
  if [ ! -f "$INSTANCE_DIR/.minecraft/options.txt" ]; then
    echo -e "onboardAccessibility:false\nskipMultiplayerWarning:true\ntutorialStep:none" > "$INSTANCE_DIR/.minecraft/options.txt"
  fi

  # instance.cfg
  cat <<EOF > "$INSTANCE_DIR/instance.cfg"
[General]
ConfigVersion=1.2
InstanceType=OneSix
JavaPath=jdk-21/bin/java
OverrideJavaLocation=true
iconKey=default
name=$MINECRAFT_VERSION-$i
EOF

  # mmc-pack.json
  cat <<EOF > "$INSTANCE_DIR/mmc-pack.json"
{
  "components": [
    {
      "cachedName": "LWJGL 3",
      "cachedVersion": "3.3.1",
      "cachedVolatile": true,
      "dependencyOnly": true,
      "uid": "org.lwjgl3",
      "version": "3.3.1"
    },
    {
      "cachedName": "Minecraft",
      "cachedRequires": [
        { "suggests": "3.3.1", "uid": "org.lwjgl3" }
      ],
      "cachedVersion": "$MINECRAFT_VERSION",
      "important": true,
      "uid": "net.minecraft",
      "version": "$MINECRAFT_VERSION"
    },
    {
      "cachedName": "Fabric Loader",
      "cachedRequires": [
        { "equals": "$MINECRAFT_VERSION", "uid": "net.minecraft" }
      ],
      "cachedVersion": "$FABRIC_LOADER_VERSION",
      "uid": "net.fabricmc.fabric-loader",
      "version": "$FABRIC_VERSION_DIR"
    }
  ],
  "formatVersion": 1
}
EOF

done

# --- Copy or create accounts.json ---
if [ ! -f "$POLLYMC_DIR/accounts.json" ]; then
  echo '[{"type":"offline","username":"Player1","uuid":"00000000-0000-0000-0000-000000000001"}]' > "$POLLYMC_DIR/accounts.json"
fi

# --- Download launcher script ---
wget -O "$POLLYMC_DIR/minecraft.sh" https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/minecraft.sh
chmod +x "$POLLYMC_DIR/minecraft.sh"

# --- Create desktop shortcut ---
cat <<EOF > "$HOME/Desktop/Minecraft-Splitscreen.desktop"
[Desktop Entry]
Name=Minecraft Splitscreen
Exec=$POLLYMC_DIR/minecraft.sh
Type=Application
Icon=application-x-executable
Terminal=false
EOF
chmod +x "$HOME/Desktop/Minecraft-Splitscreen.desktop"

# --- Clean up temp dir ---
rm -rf "$TEMP_DIR"

echo "[SUCCESS] Minecraft Splitscreen setup complete! Launch from desktop or $POLLYMC_DIR/minecraft.sh"
