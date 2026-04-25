# Minecraft Splitscreen Steam Deck & Linux Installer

This project provides an easy way to set up splitscreen Minecraft on Steam Deck and Linux using a PolyMC-first approach. It supports 1–4 players, controller detection, and seamless integration with Steam Game Mode and your desktop environment.

## Features
- **Automatic Java Installation:** Detects required Java version and installs automatically (no manual setup required)
- **Optimized Installation:** Uses PolyMC for automated instance creation and gameplay
- Launch 1–4 Minecraft instances in splitscreen mode with proper Fabric support
- Automatic controller detection and per-player config
- Works on Steam Deck (Game Mode & Desktop Mode) and any Linux PC
- Optionally adds a launcher to Steam and your desktop menu
- Handles KDE/Plasma quirks for a clean splitscreen experience when running from Game Mode
- Self-updating launcher script
- **Fabric Loader:** Complete dependency chain implementation ensures mods load and function correctly
- **Automatic Dependency Resolution:** Uses live API calls to discover and install all mod dependencies without manual maintenance
- **Smart Cleanup:** Automatically removes temporary files and directories after successful setup

## Requirements
- Linux (Steam Deck or any modern distro)
- Internet connection for initial setup
- No manual Java setup required (the installer automatically installs the correct Java version if needed)
- Steam Deck controller auto-disable is optional; use it only if you still experience controller mapping issues with external controllers. See [Steam-Deck.Auto-Disable-Steam-Controller](https://github.com/scawp/Steam-Deck.Auto-Disable-Steam-Controller).

## Installation Process
The installer uses a **PolyMC-only approach**:

1. **PolyMC CLI** - Automated instance creation with proper Fabric setup
2. **PolyMC gameplay** - Single launcher path for launch, updates, and management
3. **Smart Cleanup** - Removes temporary installer files after setup

## What gets installed
- [PolyMC](https://github.com/PolyMC/PolyMC) AppImage (primary launcher)
- **Minecraft version:** User-selectable (defaults to latest stable release, with 4 separate instances for splitscreen)
- **Fabric Loader:** Complete dependency chain including LWJGL 3, Minecraft, Intermediary Mappings, and Fabric Loader
- **Mods included (automatically installed):**
  - [Controllable](https://www.curseforge.com/minecraft/mc-mods/controllable) - Required for controller support
  - [Splitscreen Support](https://modrinth.com/mod/splitscreen) - Required for splitscreen functionality (preconfigured for 1–4 players)
- **Optional mods (selectable during installation):**
  - [Better Name Visibility](https://modrinth.com/mod/better-name-visibility)
  - [Full Brightness Toggle](https://modrinth.com/mod/full-brightness-toggle)
  - [In-Game Account Switcher](https://modrinth.com/mod/in-game-account-switcher)
  - [Just Zoom](https://modrinth.com/mod/just-zoom)
  - [Legacy4J](https://modrinth.com/mod/legacy4j)
  - [Mod Menu](https://modrinth.com/mod/modmenu)
  - [Old Combat Mod](https://modrinth.com/mod/old-combat-mod)
  - [Reese's Sodium Options](https://modrinth.com/mod/reeses-sodium-options)
  - [Sodium](https://modrinth.com/mod/sodium)
  - [Sodium Dynamic Lights](https://modrinth.com/mod/sodium-dynamic-lights)
  - [Sodium Extra](https://modrinth.com/mod/sodium-extra)
  - [Sodium Extras](https://modrinth.com/mod/sodium-extras)
- **Mod dependencies (automatically installed when needed):**
  - [Collective](https://modrinth.com/mod/collective) - Required by several optional mods
  - [Fabric API](https://modrinth.com/mod/fabric-api) - Required by most Fabric mods
  - [Framework](https://www.curseforge.com/minecraft/mc-mods/framework) - Required by Controllable
  - [Konkrete](https://modrinth.com/mod/konkrete) - Required by some optional mods
  - [Sodium Options API](https://modrinth.com/mod/sodium-options-api) - Required by Sodium-related mods
  - [YetAnotherConfigLib](https://modrinth.com/mod/yacl) - Required by several optional mods
  - *Note: These dependencies are automatically downloaded when a mod that requires them is selected*

## Installation Features
- **CLI-driven instance creation:** Automated setup using PolyMC's command-line interface
- **Intelligent version selection:** Only offers Minecraft versions that are fully compatible with both required splitscreen mods (Controllable and Splitscreen Support)
- **Fabric compatibility verification:** All mods are filtered to ensure they're Fabric-compatible versions
- **Automatic dependency resolution:** Uses Modrinth and CurseForge APIs to automatically discover and install all required mod dependencies
- **Dependency chain validation:** Proper Fabric Loader setup with LWJGL 3, Intermediary Mappings, and all required dependencies
- **Fallback mechanisms:** Manual instance creation if CLI fails, with multiple retry strategies
- **Smart cleanup:** Automatically removes temporary installer files after successful setup

## Installation
1. **Download and run the installer:**
   - You can get the latest installer script from the [Releases section](https://github.com/FlyingEwok/MinecraftSplitscreenSteamdeck/releases) (recommended for stable versions), or use the latest development version with:
   ```sh
   wget https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/install-minecraft-splitscreen.sh
   chmod +x install-minecraft-splitscreen.sh
   ./install-minecraft-splitscreen.sh
   ```
   
   **Note:** The installer will automatically detect which Java version you need based on your selected Minecraft version and install it if not present. No manual Java setup required!

2. **Install Python 3 (optional)**
   - Only required if you want to add the launcher to Steam automatically
   - Most Linux distributions include Python 3 by default
   - For Arch: `sudo pacman -S python`
   - For Debian/Ubuntu: `sudo apt install python3`

3. **Follow the prompts** to customize your installation:
   - **Java installation:** The installer will automatically:
     - Detect the required Java version for your chosen Minecraft version (Java 8, 16, 17, or 21)
     - Search for existing Java installations on your system
     - Download and install the correct Java version automatically if not found (using [install-jdk-on-steam-deck](https://github.com/FlyingEwok/install-jdk-on-steam-deck))
     - Configure environment variables and validate the installation
   - **Minecraft version:** Choose your preferred version from a curated list of versions that are fully compatible with both required splitscreen mods (Controllable and Splitscreen Support), or press Enter for the latest compatible version
   - **Mod selection process:** The installer will automatically:
     - Search for compatible Fabric versions of all supported mods
     - Filter out incompatible versions using Modrinth and CurseForge APIs
     - Automatically resolve and download all mod dependencies using live API calls
     - Download dependency mods (like Fabric API for most mods) without manual specification
     - Handle mod conflicts and suggest alternatives when needed
     - Show progress for each mod download with success/failure status
     - Report any missing mods at the end if compatible versions aren't found
   - **Steam integration (optional):** 
     - Choose "y" to add a shortcut to Steam for easy access from Game Mode on Steam Deck
     - Choose "n" if you prefer to launch manually or don't use Steam
   - **Desktop launcher (optional):**
     - Choose "y" to create a desktop shortcut and add to your applications menu
     - Choose "n" if you only want to launch from Steam or manually
   - **Installation progress:** The installer will show detailed progress including:
     - PolyMC download and CLI verification
     - Instance creation (4 separate Minecraft instances for splitscreen)
     - PolyMC download and configuration
     - Automatic Java version detection and installation (if needed)
     - Mod downloads with Fabric compatibility verification
     - Automatic cleanup of temporary files

5. **Steam Deck only - Install Steam Deck controller auto-disable (required):**
   ```sh
   curl -sSL https://raw.githubusercontent.com/scawp/Steam-Deck.Auto-Disable-Steam-Controller/main/curl_install.sh | bash
   ```
   This automatically disables the built-in Steam Deck controller when external controllers are connected, which is essential for proper splitscreen controller counting. **This step is only needed on Steam Deck.**

## Technical Details
- **Mod Compatibility:** Uses both Modrinth and CurseForge APIs with Fabric filtering (`modLoaderType=4` for CurseForge, `.loaders[] == "fabric"` for Modrinth)
- **Instance Management:** Dynamic verification and registration of created instances
- **Error Recovery:** Enhanced error handling with automatic fallbacks and manual creation options
- **Memory Optimization:** Configured for splitscreen performance (3GB max, 512MB min per instance)

## Usage
- Launch the game from Steam, your desktop menu, or the generated desktop shortcut.
- The script will detect controllers and launch the correct number of Minecraft instances.
- On Steam Deck Game Mode, it will use a nested KDE session for best compatibility.
- **Steam Deck users:** For proper controller counting, you must disable the built-in Steam Deck controller when an external controller is connected. Use [Steam-Deck.Auto-Disable-Steam-Controller](https://github.com/scawp/Steam-Deck.Auto-Disable-Steam-Controller) to automate this process.

## Installation Locations
- **Primary installation:** `~/.local/share/PolyMC/` (instances, launcher, and game files)
- **Temporary files:** Automatically cleaned up after successful installation
- **Launcher script:** `~/.local/share/PolyMC/minecraftSplitscreen.sh`

## Troubleshooting
- **Java installation issues:**
  - The installer automatically handles Java installation, but if issues occur:
  - Ensure you have an internet connection for downloading Java
  - For manual installation, the installer will provide specific instructions for your system
  - Steam Deck users can use the [install-jdk-on-steam-deck](https://github.com/FlyingEwok/install-jdk-on-steam-deck) script separately if needed
- **Controller issues:**
  - Make sure controllers are connected before launching.

## Updating

### Launcher Updates
The launcher script (`minecraftSplitscreen.sh`) will auto-update itself when a new version is available.

### Minecraft Version Updates
To update your Minecraft version or mod configuration:
1. Download the latest installer:
   ```sh
   wget https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/install-minecraft-splitscreen.sh
   chmod +x install-minecraft-splitscreen.sh
   ```
2. Run the installer:
   ```sh
   ./install-minecraft-splitscreen.sh
   ```
3. Select your new Minecraft version when prompted
4. The installer will:
   - Preserve your existing options.txt settings (keybindings, video settings, etc.)
   - Clear old mods and install fresh ones for the new version
   - Update the Fabric loader and all dependencies
   - Keep your existing player profiles and accounts
   - Preserve all your existing worlds

## Uninstall
Run the uninstall script:
```sh
wget https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/uninstall-minecraft-splitscreen.sh
chmod +x uninstall-minecraft-splitscreen.sh
./uninstall-minecraft-splitscreen.sh
```

Optional flags:
- `--yes` to skip confirmation
- `--dry-run` to preview what would be removed
- `--keep-data` to remove launchers/shortcuts but keep instances, worlds, and accounts

Note: Steam library shortcuts are not edited automatically. Remove the Minecraft Splitscreen shortcut manually from Steam if needed.

## Credits
- Inspired by [ArnoldSmith86/minecraft-splitscreen](https://github.com/ArnoldSmith86/minecraft-splitscreen) (original concept/script, but this project is mostly a full rewrite).
- Additional contributions by [FlyingEwok](https://github.com/FlyingEwok) and others.
- Uses [PolyMC](https://github.com/PolyMC/PolyMC) for both instance creation and gameplay.
- Steam Deck Java installation script by [FlyingEwok](https://github.com/FlyingEwok/install-jdk-on-steam-deck) - provides seamless Java installation for Steam Deck's read-only filesystem with automatic version detection.
- Steam Deck controller auto-disable tool by [scawp](https://github.com/scawp/Steam-Deck.Auto-Disable-Steam-Controller) - automatically disables built-in Steam Deck controller when external controllers are connected, essential for proper splitscreen controller counting.

## Technical Improvements
- **Complete Fabric Dependency Chain:** Ensures mods load and function correctly by including LWJGL 3, Minecraft, Intermediary Mappings, and Fabric Loader with proper dependency references
- **API Filtering:** Both Modrinth and CurseForge APIs are filtered to only download Fabric-compatible mod versions
- **Automatic Dependency Resolution:** Recursively resolves all mod dependencies using live API calls, eliminating the need to manually maintain dependency lists
- **Optimized Launcher Strategy:** Uses PolyMC's reliable CLI automation and gameplay flow
- **Smart Cleanup:** Automatically removes temporary build files and directories after successful setup
- **Enhanced Error Handling:** Multiple fallback mechanisms and retry strategies for robust installation

## TODO
- **Figure out preconfiguring controllers within controllable (if possible)** - Investigate automatic controller assignment configuration to avoid having Controllable grab the same controllers as all the other instances, ensuring each player gets their own dedicated controller

## Recent Improvements
- ✅ **Steam Deck Controller Handling Improved**: Added per-instance controller filtering so Steam Deck controls no longer need to be disabled system-wide for splitscreen sessions
- ✅ **Automatic Java Installation**: No manual Java setup required - the installer automatically detects, downloads, and installs the correct Java version for your chosen Minecraft version
- ✅ **Automatic Java Version Detection**: Automatically detects and uses the correct Java version for each Minecraft version (Java 8, 16, 17, or 21) with smart backward compatibility
- ✅ **Intelligent Version Selection**: Only Minecraft versions supported by both Controllable and Splitscreen Support mods are offered to users, ensuring full compatibility
- ✅ **Automatic Dependency Resolution**: No more hardcoded dependency lists - all mod dependencies are detected via API
- ✅ **Robust CurseForge Integration**: Full CurseForge API support with authentication and download URL resolution
- ✅ **Mixed Platform Support**: Seamlessly handles both Modrinth and CurseForge mods in the same installation
- ✅ **Smart Fallbacks**: Graceful degradation when APIs are unavailable



---
For more details, see the comments in the scripts or open an issue on the [GitHub repo](https://github.com/FlyingEwok/MinecraftSplitscreenSteamdeck).
