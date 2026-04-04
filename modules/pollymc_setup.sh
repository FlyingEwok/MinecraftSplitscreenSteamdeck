#!/bin/bash
# =============================================================================
# Minecraft Splitscreen Steam Deck Installer - PollyMC Setup Module
# =============================================================================
# 
# This module handles the setup and optimization of PollyMC as the primary
# launcher for splitscreen gameplay, providing better offline support and
# handling of multiple simultaneous instances compared to PrismLauncher.
#
# Functions provided:
# - setup_pollymc: Configure PollyMC as the primary splitscreen launcher
# - setup_pollymc_launcher: Configure splitscreen launcher script for PollyMC
# - cleanup_prism_launcher: Clean up PrismLauncher files after PollyMC setup
#
# =============================================================================

# setup_pollymc: Configure PollyMC as the primary launcher for splitscreen gameplay
# 
# POLLYMC ADVANTAGES FOR SPLITSCREEN:
# - No forced Microsoft login requirements (offline-friendly)
# - Better handling of multiple simultaneous instances
# - Cleaner interface without authentication popups
# - More stable for automated controller-based launching
# 
# PROCESS OVERVIEW:
# 1. Download PollyMC AppImage from GitHub releases
# 2. Migrate all instances from PrismLauncher to PollyMC
# 3. Copy offline accounts configuration
# 4. Test PollyMC compatibility and functionality
# 5. Set up splitscreen launcher script for PollyMC
# 6. Clean up PrismLauncher files to save space
#
# FALLBACK STRATEGY:
# If PollyMC fails at any step, we fall back to PrismLauncher
# This ensures the installation completes successfully regardless
setup_pollymc() {
    print_header "🎮 SETTING UP POLLYMC"
    
    print_progress "Downloading PollyMC for optimized splitscreen gameplay..."
    
    # =============================================================================
    # POLLYMC DIRECTORY INITIALIZATION
    # =============================================================================
    
    # Create PollyMC data directory structure
    # PollyMC stores instances, accounts, configuration, and launcher script here
    # Structure: ~/.local/share/PollyMC/{instances/, accounts.json, PollyMC AppImage}
    mkdir -p "$HOME/.local/share/PollyMC"
    
    # =============================================================================
    # POLLYMC APPIMAGE DOWNLOAD AND VERIFICATION
    # =============================================================================
    
    # Download PollyMC AppImage from official GitHub releases
    # AppImage format provides universal Linux compatibility without dependencies
    # Resolve the latest x86_64 AppImage dynamically from release metadata because
    # asset names can change between releases.
    local pollymc_url=""
    local pollymc_release_json=""
    local pollymc_repo="SharathGames1/PollyMC"
    pollymc_release_json="$(wget -qO- "https://api.github.com/repos/${pollymc_repo}/releases/latest" 2>/dev/null || true)"

    if [[ -n "$pollymc_release_json" ]]; then
        pollymc_url="$(jq -r '.assets[]? | select((.name | test("AppImage$")) and (.name | test("x86_64|amd64"; "i"))) | .browser_download_url' \
            <<< "$pollymc_release_json" 2>/dev/null | head -n1 || true)"
    fi

    # Fallback: choose any AppImage if architecture-specific asset not detected.
    if [[ -z "$pollymc_url" || "$pollymc_url" == "null" ]]; then
        pollymc_url="$(jq -r '.assets[]? | select(.name | test("AppImage$")) | .browser_download_url' \
            <<< "$pollymc_release_json" 2>/dev/null | head -n1 || true)"
    fi

    # Last-resort fallback to legacy static URL for environments where API access is blocked.
    if [[ -z "$pollymc_url" || "$pollymc_url" == "null" ]]; then
        pollymc_url="https://github.com/${pollymc_repo}/releases/latest/download/PollyMC-Linux-x86_64.AppImage"
        print_warning "Could not resolve PollyMC asset via GitHub API, using legacy static URL fallback"
    fi

    print_progress "Fetching PollyMC from GitHub releases: $(basename "$pollymc_url")..."
    
    # DOWNLOAD WITH FALLBACK HANDLING
    # If PollyMC download fails, we continue with PrismLauncher as the primary launcher
    # This ensures installation doesn't fail completely due to network issues or GitHub downtime
    if ! wget -O "$HOME/.local/share/PollyMC/PollyMC-Linux-x86_64.AppImage" "$pollymc_url"; then
        print_warning "❌ PollyMC download failed - continuing with PrismLauncher as primary launcher"
        print_info "   This is not a critical error - PrismLauncher works fine for splitscreen"
        USE_POLLYMC=false  # Global flag tracks which launcher is active
        return 0
    else
        # APPIMAGE PERMISSIONS: Make the downloaded AppImage executable
        # AppImages require execute permissions to run properly
        chmod +x "$HOME/.local/share/PollyMC/PollyMC-Linux-x86_64.AppImage"
        print_success "✅ PollyMC AppImage downloaded and configured successfully"
        USE_POLLYMC=true  # Mark PollyMC as available for further setup
    fi

    # =============================================================================
    # INSTANCE MIGRATION: Transfer all Minecraft instances from PrismLauncher
    # =============================================================================
    
    # INSTANCE DIRECTORY MIGRATION
    # Copy the complete instances directory structure from PrismLauncher to PollyMC
    # This includes all 4 splitscreen instances with their configurations, mods, and saves
    print_progress "Migrating PrismLauncher instances to PollyMC data directory..."
    
    # INSTANCES TRANSFER: Copy entire instances folder with all splitscreen configurations
    # Each instance (latestUpdate-1 through latestUpdate-4) contains:
    # - Minecraft version configuration
    # - Fabric mod loader setup
    # - All downloaded mods and their dependencies
    # - Splitscreen-specific mod configurations
    # - Instance-specific settings (memory, Java args, etc.)
    if [[ -d "$TARGET_DIR/instances" ]]; then
        # Create instances directory if it doesn't exist
        mkdir -p "$HOME/.local/share/PollyMC/instances"
        
        # For updates: preserve options.txt and replace instances
        if [[ -d "$HOME/.local/share/PollyMC/instances" ]]; then
            for i in {1..4}; do
                local instance_name="latestUpdate-$i"
                local instance_path="$HOME/.local/share/PollyMC/instances/$instance_name"
                local options_file="$instance_path/.minecraft/options.txt"
                
                if [[ -d "$instance_path" ]]; then
                    print_info "   → Updating $instance_name while preserving settings"
                    
                    # Backup options.txt if it exists
                    if [[ -f "$options_file" ]]; then
                        print_info "     → Preserving existing options.txt for $instance_name"
                        # Create a temporary directory for backups
                        local backup_dir="$HOME/.local/share/PollyMC/options_backup"
                        mkdir -p "$backup_dir"
                        # Copy with path structure to keep track of which instance it belongs to
                        cp "$options_file" "$backup_dir/${instance_name}_options.txt"
                    fi
                    
                    # Remove old instance but keep options backup
                    rm -rf "$instance_path"
                fi
            done
        fi
        
        # Copy the updated instances while excluding options.txt files
        rsync -a --exclude='*.minecraft/options.txt' "$TARGET_DIR/instances/"* "$HOME/.local/share/PollyMC/instances/"
        
        # Restore options.txt files from temporary backup location
        local backup_dir="$HOME/.local/share/PollyMC/options_backup"
        for i in {1..4}; do
            local instance_name="latestUpdate-$i"
            local instance_path="$HOME/.local/share/PollyMC/instances/$instance_name"
            local options_file="$instance_path/.minecraft/options.txt"
            local backup_file="$backup_dir/${instance_name}_options.txt"
            
            if [[ -f "$backup_file" ]]; then
                print_info "   → Restoring saved options.txt for $instance_name"
                mkdir -p "$(dirname "$options_file")"
                cp "$backup_file" "$options_file"
            fi
        done
        
        print_success "✅ Splitscreen instances migrated to PollyMC"
        
        # Clean up the temporary backup directory
        if [[ -d "$backup_dir" ]]; then
            rm -rf "$backup_dir"
        fi
        
        # INSTANCE COUNT VERIFICATION: Ensure all 4 instances were copied successfully
        local instance_count
        instance_count=$(find "$HOME/.local/share/PollyMC/instances" -maxdepth 1 -name "latestUpdate-*" -type d 2>/dev/null | wc -l)
        print_info "   → $instance_count splitscreen instances available in PollyMC"
    else
        print_warning "⚠️  No instances directory found in PrismLauncher - this shouldn't happen"
    fi
    
    # =============================================================================
    # ACCOUNT CONFIGURATION MIGRATION
    # =============================================================================
    
    # OFFLINE ACCOUNTS TRANSFER: Copy splitscreen player account configurations
    # The accounts.json file contains offline player profiles for Player 1-4
    # These accounts allow splitscreen gameplay without requiring multiple Microsoft accounts
    if [[ -f "$TARGET_DIR/accounts.json" ]]; then
        cp "$TARGET_DIR/accounts.json" "$HOME/.local/share/PollyMC/"
        print_success "✅ Offline splitscreen accounts copied to PollyMC"
        print_info "   → Player accounts P1, P2, P3, P4 configured for offline gameplay"
    else
        print_warning "⚠️  accounts.json not found - splitscreen accounts may need manual setup"
    fi

    # =============================================================================
    # POLLYMC CONFIGURATION: Skip Setup Wizard
    # =============================================================================
    
    # SETUP WIZARD BYPASS: Create PollyMC configuration using user's proven working settings
    # This uses the exact configuration from the user's working PollyMC installation
    # Guarantees compatibility and skips all setup wizard prompts
    print_progress "Configuring PollyMC with proven working settings..."
    
    # Get the current hostname for dynamic configuration with multiple fallback methods
    local current_hostname
    if command -v hostname >/dev/null 2>&1; then
        current_hostname=$(hostname)
    elif [[ -r /proc/sys/kernel/hostname ]]; then
        current_hostname=$(cat /proc/sys/kernel/hostname)
    elif [[ -n "$HOSTNAME" ]]; then
        current_hostname="$HOSTNAME"
    else
        current_hostname="localhost"
    fi
    
    cat > "$HOME/.local/share/PollyMC/pollymc.cfg" <<EOF
[General]
ApplicationTheme=system
ConfigVersion=1.2
FlameKeyOverride=\$2a\$10\$bL4bIL5pUWqfcO7KQtnMReakwtfHbNKh6v1uTpKlzhwoueEJQnPnm
FlameKeyShouldBeFetchedOnStartup=false
IconTheme=pe_colored
JavaPath=${JAVA_PATH}
Language=en_US
LastHostname=${current_hostname}
MainWindowGeometry=@ByteArray(AdnQywADAAAAAAwwAAAAzAAAD08AAANIAAAMMAAAAPEAAA9PAAADSAAAAAEAAAAAB4AAAAwwAAAA8QAAD08AAANI)
MainWindowState="@ByteArray(AAAA/wAAAAD9AAAAAAAAApUAAAH8AAAABAAAAAQAAAAIAAAACPwAAAADAAAAAQAAAAEAAAAeAGkAbgBzAHQAYQBuAGMAZQBUAG8AbwBsAEIAYQByAwAAAAD/////AAAAAAAAAAAAAAACAAAAAQAAABYAbQBhAGkAbgBUAG8AbwBsAEIAYQByAQAAAAD/////AAAAAAAAAAAAAAADAAAAAQAAABYAbgBlAHcAcwBUAG8AbwBsAEIAYQByAQAAAAD/////AAAAAAAAAAA=)"
MaxMemAlloc=4096
MinMemAlloc=512
ToolbarsLocked=false
WideBarVisibility_instanceToolBar="@ByteArray(111111111,BpBQWIumr+0ABXFEarV0R5nU0iY=)"
EOF
    
    print_success "✅ PollyMC configured to skip setup wizard"
    print_info "   → Setup wizard will not appear on first launch"
    print_info "   → Java path and memory settings pre-configured"

    # =============================================================================
    # POLLYMC COMPATIBILITY VERIFICATION
    # =============================================================================
    
    # POLLYMC FUNCTIONALITY TEST: Verify PollyMC works on this system
    # Test basic AppImage execution and CLI functionality before committing to use PollyMC
    # Some older systems or restricted environments may have issues with AppImages
    print_progress "Testing PollyMC compatibility and basic functionality..."
    
    # APPIMAGE EXECUTION TEST: Run PollyMC with --help flag to verify it works
    # Timeout prevents hanging if AppImage has issues
    # This tests: AppImage execution, basic CLI functionality, system compatibility
    if timeout 5s "$HOME/.local/share/PollyMC/PollyMC-Linux-x86_64.AppImage" --help >/dev/null 2>&1; then
        print_success "✅ PollyMC compatibility test passed - AppImage executes properly"
        
        # =============================================================================
        # POLLYMC INSTANCE VERIFICATION AND FINAL SETUP
        # =============================================================================
        
        # INSTANCE ACCESS VERIFICATION: Confirm PollyMC can detect and access migrated instances
        # This ensures PollyMC properly recognizes the instance format from PrismLauncher
        # Both launchers use similar formats, but compatibility should be verified
        print_progress "Verifying PollyMC can access migrated splitscreen instances..."
        local polly_instances_count
        polly_instances_count=$(find "$HOME/.local/share/PollyMC/instances" -maxdepth 1 -name "latestUpdate-*" -type d 2>/dev/null | wc -l)
        
        if [[ "$polly_instances_count" -eq 4 ]]; then
            print_success "✅ PollyMC instance verification successful - all 4 instances accessible"
            print_info "   → latestUpdate-1, latestUpdate-2, latestUpdate-3, latestUpdate-4 ready"
            
            # LAUNCHER SCRIPT CONFIGURATION: Set up the splitscreen launcher for PollyMC
            # This configures the controller detection and multi-instance launch script
            setup_pollymc_launcher
            
            # CLEANUP PHASE: Remove PrismLauncher since PollyMC is working
            # This saves significant disk space (~500MB+) and avoids launcher confusion
            # PrismLauncher was only needed for the CLI-based instance creation process
            cleanup_prism_launcher
            
            print_success "🎮 PollyMC is now the primary launcher for splitscreen gameplay"
            print_info "   → PrismLauncher files cleaned up to save disk space"
        else
            print_warning "⚠️  PollyMC instance verification failed - found $polly_instances_count instances instead of 4"
            print_info "   → Falling back to PrismLauncher as primary launcher"
            USE_POLLYMC=false
        fi
    else
        print_warning "❌ PollyMC compatibility test failed - AppImage execution issues detected"
        print_info "   → This may be due to system restrictions, missing dependencies, or AppImage incompatibility"
        print_info "   → Falling back to PrismLauncher for gameplay (still fully functional)"
        USE_POLLYMC=false
    fi
}

# Configure the splitscreen launcher script for PollyMC
# Downloads and modifies the launcher script to use PollyMC instead of PrismLauncher
setup_pollymc_launcher() {
    print_progress "Setting up launcher script for PollyMC..."
    
    # LAUNCHER SCRIPT DOWNLOAD: Get the splitscreen launcher script from GitHub
    # This script handles controller detection and multi-instance launching
    if wget -O "$HOME/.local/share/PollyMC/minecraftSplitscreen.sh" \
        "https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/minecraftSplitscreen.sh"; then
        chmod +x "$HOME/.local/share/PollyMC/minecraftSplitscreen.sh"
        
        # LAUNCHER SCRIPT CONFIGURATION: Modify paths to use PollyMC instead of PrismLauncher
        # Replace PrismLauncher AppImage path with PollyMC AppImage path
        sed -i 's|PrismLauncher/PrismLauncher.AppImage|PollyMC/PollyMC-Linux-x86_64.AppImage|g' \
            "$HOME/.local/share/PollyMC/minecraftSplitscreen.sh"
        # Replace PrismLauncher data directory with PollyMC data directory
        sed -i 's|/.local/share/PrismLauncher/|/.local/share/PollyMC/|g' \
            "$HOME/.local/share/PollyMC/minecraftSplitscreen.sh"
        
        print_success "Launcher script configured and copied to PollyMC"
    else
        print_warning "Failed to download launcher script"
    fi
}

# Clean up PrismLauncher installation after successful PollyMC setup
# This removes the temporary PrismLauncher directory to save disk space
# PrismLauncher was only needed for automated instance creation via CLI
cleanup_prism_launcher() {
    print_progress "Cleaning up PrismLauncher (no longer needed)..."
    
    # SAFETY: Navigate to home directory before removal operations
    # This prevents accidental deletion if we're currently in the target directory
    cd "$HOME" || return 1
    
    # SAFETY CHECKS: Multiple validations before removing directories
    # Ensure we're not deleting critical system directories or user home
    if [[ -d "$TARGET_DIR" && "$TARGET_DIR" != "$HOME" && "$TARGET_DIR" != "/" && "$TARGET_DIR" == *"PrismLauncher"* ]]; then
        rm -rf "$TARGET_DIR"
        print_success "Removed PrismLauncher directory: $TARGET_DIR"
        print_info "All essential files now in PollyMC directory"
    else
        print_warning "Skipped directory removal for safety: $TARGET_DIR"
    fi
}
