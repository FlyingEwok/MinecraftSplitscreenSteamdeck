#!/bin/bash
targetDir=$HOME/.local/share/PollyMC
mkdir -p $targetDir
pushd $targetDir

    if [ ! -f "PollyMC-Linux-x86_64.AppImage" ]; then
        # download pollymc
        wget https://github.com/fn2006/PollyMC/releases/download/8.0/PollyMC-Linux-x86_64.AppImage
        chmod +x PollyMC-Linux-x86_64.AppImage
    fi

    # Detect system Java (prefer Java 21, then Java 17, then which java)
    if [ -x /usr/lib/jvm/java-21-openjdk/bin/java ]; then
        JAVA_PATH="/usr/lib/jvm/java-21-openjdk/bin/java"
    elif [ -x /usr/lib/jvm/java-17-openjdk/bin/java ]; then
        JAVA_PATH="/usr/lib/jvm/java-17-openjdk/bin/java"
    elif [ -x /usr/lib/jvm/default-runtime/bin/java ]; then
        JAVA_PATH="/usr/lib/jvm/default-runtime/bin/java"
    else
        JAVA_PATH="$(which java)"
    fi

    # Check if Java is available and executable
    if [ -z "$JAVA_PATH" ] || [ ! -x "$JAVA_PATH" ]; then
        echo "Error: Java 17 or 21 is not installed or not found in a standard location. Please install OpenJDK 17 or 21 with: sudo pacman -S jdk21-openjdk jdk17-openjdk" >&2
        exit 1
    fi

    if [ ! -f pollymc.cfg ]; then
        # create pollymc.cfg
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

    # Download Fabric installer jar
    if [ ! -f "$TEMP_DIR/fabric-installer-0.11.2.jar" ]; then
        wget -O "$TEMP_DIR/fabric-installer-0.11.2.jar" "https://maven.fabricmc.net/net/fabricmc/fabric-installer/0.11.2/fabric-installer-0.11.2.jar"
    fi

    # --- Use sampleInstance as template for splitscreen instances ---
    TEMPLATE_INSTANCE="sampleInstance"
    if [ ! -d "$TEMPLATE_INSTANCE" ]; then
        echo "ERROR: sampleInstance directory not found. Please create a working instance named 'sampleInstance' in PollyMC and re-run this script." >&2
        exit 1
    fi

    for i in {1..4}; do
        DEST="instances/1.21.5-$i"
        rm -rf "$DEST"
        cp -a "$TEMPLATE_INSTANCE" "$DEST"
        # Update instance.cfg name for each instance
        sed -i "s/^name=.*/name=1.21.5-$i/" "$DEST/instance.cfg"
    done

    # --- Download accounts.json for splitscreen ---
    wget -O accounts.json "https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/accounts.json"

    # Clean up temp dir
    rm -rf "$TEMP_DIR"

    # download the launch wrapper
    rm -f minecraft.sh
    wget https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/minecraft.sh
    chmod +x minecraft.sh

popd

    # # add the launch wrapper to Steam
    # if ! grep -q local/share/PollyMC/minecraft ~/.steam/steam/userdata/*/config/shortcuts.vdf; then
    #     steam -shutdown
    #     while pgrep -F ~/.steam/steam.pid; do
    #         sleep 1
    #     done
    #     [ -f shortcuts-backup.tar.xz ] || tar cJf shortcuts-backup.tar.xz ~/.steam/steam/userdata/*/config/shortcuts.vdf
    #     curl https://raw.githubusercontent.com/ArnoldSmith86/minecraft-splitscreen/refs/heads/main/add-to-steam.py | python
    #     nohup steam &
    # fi