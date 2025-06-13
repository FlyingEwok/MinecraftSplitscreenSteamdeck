# Minecraft Splitscreen Steam Deck & Linux Installer

This project provides an easy way to set up splitscreen Minecraft on Steam Deck and Linux using PollyMC. It supports 1–4 players, controller detection, and seamless integration with Steam and your desktop environment.

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
- [PollyMC](https://github.com/fn2006/PollyMC) AppImage (downloaded automatically)

## Installation
1. **Install Java 21**
   - Refer to your distro's documentation or package manager.
   - For Arch: `sudo pacman -S jdk21-openjdk`
   - For Debian/Ubuntu: `sudo apt install openjdk-21-jre`
2. **Download and run the installer:**
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
