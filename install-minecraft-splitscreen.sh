#!/bin/bash
targetDir=$HOME/.local/share/PollyMC
mkdir -p $targetDir
pushd $targetDir

    if [ ! -f "PollyMC-Linux-x86_64.AppImage" ]; then
        # download pollymc
        wget https://github.com/fn2006/PollyMC/releases/download/8.0/PollyMC-Linux-x86_64.AppImage
        chmod +x PollyMC-Linux-x86_64.AppImage
    fi

    if [ ! -f "jdk-21/bin/java" ]; then
        # download java 21
        curl -L https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.tar.gz | tar xz
        # Move to jdk-21 if extracted as something else
        JDK_EXTRACTED=$(ls -d jdk-21* | grep -v "jdk-21" | head -1)
        if [ -n "$JDK_EXTRACTED" ] && [ "$JDK_EXTRACTED" != "jdk-21" ]; then
            mv "$JDK_EXTRACTED" jdk-21
        fi
    fi

    if [ ! -f pollymc.cfg ]; then
        # create pollymc.cfg
        sed 's/^            //' <<________EOF > pollymc.cfg
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
________EOF
    fi

    # Download all mods and jars once to a temp dir
    TEMP_DIR=$(mktemp -d)
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
        modfile="$TEMP_DIR/$(basename "${url%%\?*}")"
        [ -f "$modfile" ] || wget -O "$modfile" "$url"
    done

    # Download Fabric loader jar and manifest
    if [ ! -f "$TEMP_DIR/fabric-loader-0.15.7.jar" ]; then
        wget -O "$TEMP_DIR/fabric-loader-0.15.7.jar" "https://maven.fabricmc.net/net/fabricmc/fabric-loader/0.15.7/fabric-loader-0.15.7.jar"
    fi
    if [ ! -f "$TEMP_DIR/fabric-loader-0.15.7-1.21.5.json" ]; then
        wget -O "$TEMP_DIR/fabric-loader-0.15.7-1.21.5.json" "https://meta.fabricmc.net/v2/versions/loader/1.21.5/0.15.7/profile/json"
    fi

    # Download Minecraft jar and json
    if [ ! -f "$TEMP_DIR/1.21.5.jar" ]; then
        if ! command -v jq &>/dev/null; then
          echo "Error: jq is required but not installed. Please run: sudo pacman -S jq" >&2
          exit 1
        fi
        curl -sSL "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json" -o "$TEMP_DIR/version_manifest.json"
        VERSION_URL=$(jq -r --arg VER "1.21.5" '.versions[] | select(.id==$VER) | .url' "$TEMP_DIR/version_manifest.json")
        curl -sSL "$VERSION_URL" -o "$TEMP_DIR/mc_version.json"
        JAR_URL=$(jq -r '.downloads.client.url' "$TEMP_DIR/mc_version.json")
        curl -sSL "$JAR_URL" -o "$TEMP_DIR/1.21.5.jar"
        mv "$TEMP_DIR/mc_version.json" "$TEMP_DIR/1.21.5.json"
        rm "$TEMP_DIR/version_manifest.json"
    fi

    # create the 4 game instances for 1.21.5
    for i in {1..4}; do
        mkdir -p "instances/1.21.5-$i/.minecraft/mods" "instances/1.21.5-$i/.minecraft/config" "instances/1.21.5-$i/.minecraft/versions/fabric-loader-0.15.7-1.21.5" "instances/1.21.5-$i/.minecraft/versions/1.21.5"
        pushd "instances/1.21.5-$i"

            # Copy all mods
            for mod in "$TEMP_DIR"/*.jar; do
                cp "$mod" ".minecraft/mods/"
            done

            # Copy Fabric loader jar and manifest
            cp "$TEMP_DIR/fabric-loader-0.15.7.jar" ".minecraft/versions/fabric-loader-0.15.7-1.21.5/fabric-loader-0.15.7.jar"
            cp "$TEMP_DIR/fabric-loader-0.15.7-1.21.5.json" ".minecraft/versions/fabric-loader-0.15.7-1.21.5/fabric-loader-0.15.7-1.21.5.json"

            # Copy Minecraft jar and json
            cp "$TEMP_DIR/1.21.5.jar" ".minecraft/versions/1.21.5/1.21.5.jar"
            cp "$TEMP_DIR/1.21.5.json" ".minecraft/versions/1.21.5/1.21.5.json"

            # options.txt
            if [ ! -f ".minecraft/options.txt" ]; then
                echo -e "onboardAccessibility:false\nskipMultiplayerWarning:true\ntutorialStep:none" > .minecraft/options.txt
            fi

            # instance.cfg
            if [ ! -f "instance.cfg" ]; then
                sed 's/^                    //' <<________________EOF > "instance.cfg"
                    [General]
                    ConfigVersion=1.2
                    InstanceType=OneSix
                    JavaPath=jdk-21/bin/java
                    OverrideJavaLocation=true
                    iconKey=default
                    name=1.21.5-$i
________________EOF
            fi

            # mmc-pack.json
            if [ ! -f "mmc-pack.json" ]; then
                cat <<EOF > "mmc-pack.json"
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
      "cachedVersion": "1.21.5",
      "important": true,
      "uid": "net.minecraft",
      "version": "1.21.5"
    },
    {
      "cachedName": "Fabric Loader",
      "cachedRequires": [
        { "equals": "1.21.5", "uid": "net.minecraft" }
      ],
      "cachedVersion": "0.15.7",
      "uid": "net.fabricmc.fabric-loader",
      "version": "fabric-loader-0.15.7-1.21.5"
    }
  ],
  "formatVersion": 1
}
EOF
            fi

        popd
    done

    # --- Create accounts.json with 4 offline accounts ---
    if [ ! -f "accounts.json" ]; then
        sed 's/^            //' <<________EOF > accounts.json
            [
                {"type":"offline","username":"P1","uuid":"00000000-0000-0000-0000-000000000001"},
                {"type":"offline","username":"P2","uuid":"00000000-0000-0000-0000-000000000002"},
                {"type":"offline","username":"P3","uuid":"00000000-0000-0000-0000-000000000003"},
                {"type":"offline","username":"P4","uuid":"00000000-0000-0000-0000-000000000004"}
            ]
________EOF
    fi

    # Clean up temp dir
    rm -rf "$TEMP_DIR"

    # download the launch wrapper
    rm -f minecraft.sh
    wget https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/minecraft.sh
    chmod +x minecraft.sh

popd

    # add the launch wrapper to Steam
    if ! grep -q local/share/PollyMC/minecraft ~/.steam/steam/userdata/*/config/shortcuts.vdf; then
        steam -shutdown
        while pgrep -F ~/.steam/steam.pid; do
            sleep 1
        done
        [ -f shortcuts-backup.tar.xz ] || tar cJf shortcuts-backup.tar.xz ~/.steam/steam/userdata/*/config/shortcuts.vdf
        curl https://raw.githubusercontent.com/ArnoldSmith86/minecraft-splitscreen/refs/heads/main/add-to-steam.py | python
        nohup steam &
    fi