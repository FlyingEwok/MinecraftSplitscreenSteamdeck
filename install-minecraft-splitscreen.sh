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

    # --- Download sampleInstance template if not present ---
    TEMPLATE_INSTANCE="sampleInstance"
    if [ ! -d "$TEMPLATE_INSTANCE" ]; then
        echo "sampleInstance not found, downloading from GitHub..."
        wget -O sampleInstance.zip "https://github.com/FlyingEwok/MinecraftSplitscreenSteamdeck/archive/refs/heads/main.zip"
        unzip -q sampleInstance.zip "MinecraftSplitscreenSteamdeck-main/sampleInstance/*"
        rm -rf "$TEMPLATE_INSTANCE"
        mv MinecraftSplitscreenSteamdeck-main/sampleInstance "$TEMPLATE_INSTANCE"
        rm -rf MinecraftSplitscreenSteamdeck-main sampleInstance.zip
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