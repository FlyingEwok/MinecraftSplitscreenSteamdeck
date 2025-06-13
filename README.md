# Minecraft Splitscreen Steam Deck & Linux Installer

This project provides an easy way to set up splitscreen Minecraft on Steam Deck and Linux using PollyMC. It supports 1–4 players, controller detection, and seamless integration with Steam Game Mode and your desktop environment.

## Features
- Launch 1–4 Minecraft instances in splitscreen mode
- Automatic controller detection and per-player config
- Works on Steam Deck (Game Mode & Desktop Mode) and any Linux PC
- Optionally adds a launcher to Steam and your desktop menu
- Handles KDE/Plasma quirks for a clean splitscreen experience when running from Game Mode
- Self-updating launcher script

## Requirements
- **Java 21** (OpenJDK 21)
- Linux (Steam Deck or any modern distro)

## What gets installed
- [PollyMC](https://github.com/fn2006/PollyMC) AppImage
- **Minecraft version:** 1.21.5 (with 4 separate instances for splitscreen)
- **Mods included:**
  - [Better Name Visibility](https://modrinth.com/mod/better-name-visibility)
  - [Collective](https://modrinth.com/mod/collective)
  - [Controllable](https://www.curseforge.com/minecraft/mc-mods/controllable)
  - [Fabric API](https://modrinth.com/mod/fabric-api)
  - [Framework](https://www.curseforge.com/minecraft/mc-mods/framework)
  - [Full Brightness Toggle](https://modrinth.com/mod/full-brightness-toggle)
  - [In-Game Account Switcher](https://modrinth.com/mod/in-game-account-switcher)
  - [Just Zoom](https://modrinth.com/mod/just-zoom)
  - [Konkrete](https://modrinth.com/mod/konkrete)
  - [Mod Menu](https://modrinth.com/mod/modmenu)
  - [Old Combat Mod](https://modrinth.com/mod/old-combat-mod)
  - [Reese's Sodium Options](https://modrinth.com/mod/reeses-sodium-options)
  - [Sodium](https://modrinth.com/mod/sodium)
  - [Sodium Dynamic Lights](https://modrinth.com/mod/sodium-dynamic-lights)
  - [Sodium Extra](https://modrinth.com/mod/sodium-extra)
  - [Sodium Extras](https://modrinth.com/mod/sodium-extras)
  - [Sodium Options API](https://modrinth.com/mod/sodium-options-api)
  - [Splitscreen Support](https://modrinth.com/mod/splitscreen-support) (preconfigured for 1–4 players)
  - [YetAnotherConfigLib](https://modrinth.com/mod/yacl)

## Installation
1. **Install Java 21**
   - Refer to your distro's documentation or package manager.
   - For Arch: `sudo pacman -S jdk21-openjdk`
   - For Debian/Ubuntu: `sudo apt install openjdk-21-jre`
2. **Download and run the installer:**
   - You can get the latest installer script from the [Releases section](https://github.com/FlyingEwok/MinecraftSplitscreenSteamdeck/releases) (recommended for stable versions), or use the latest development version with:
   ```sh
   wget https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/install-minecraft-splitscreen.sh
   chmod +x install-minecraft-splitscreen.sh
   ./install-minecraft-splitscreen.sh
   ```
3. **Follow the prompts** to:
   - Add the launcher to Steam (optional)
   - Create a desktop/applications menu shortcut (optional)

## Usage
- Launch the game from Steam, your desktop menu, or the generated desktop shortcut.
- The script will detect controllers and launch the correct number of Minecraft instances.
- On Steam Deck Game Mode, it will use a nested KDE session for best compatibility.

## Troubleshooting
- **Java 21 not found:**
  - Make sure you have Java 21 installed and available in your PATH.
  - See the error message for a link to this README.
- **Controller issues:**
  - Make sure controllers are connected before launching.

## Updating
The launcher script (`minecraft.sh`) will auto-update itself when a new version is available.

## Uninstall
- Delete the PollyMC folder: `rm -rf ~/.local/share/PollyMC`
- Remove any desktop or Steam shortcuts you created.

## Credits
- Inspired by [ArnoldSmith86/minecraft-splitscreen](https://github.com/ArnoldSmith86/minecraft-splitscreen) (original concept/script, but this project is mostly a full rewrite).
- Additional contributions by [FlyingEwok](https://github.com/FlyingEwok) and others.
- Uses [PollyMC](https://github.com/fn2006/PollyMC).

---
For more details, see the comments in the scripts or open an issue on the [GitHub repo](https://github.com/FlyingEwok/MinecraftSplitscreenSteamdeck).
