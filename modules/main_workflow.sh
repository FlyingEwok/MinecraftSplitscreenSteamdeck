#!/bin/bash
# =============================================================================
# Minecraft Splitscreen Steam Deck Installer - Main Workflow Module
# =============================================================================
# 
# This module contains the main orchestration logic for the complete splitscreen
# installation process. It coordinates all the other modules and provides
# comprehensive status reporting and user guidance.
#
# Functions provided:
# - main: Primary function that orchestrates the complete installation process
#
# =============================================================================

# main: Primary function that orchestrates the complete splitscreen installation process
#
# INSTALLATION WORKFLOW:
# 1. WORKSPACE SETUP: Create directories and initialize environment
# 2. CORE SETUP: Java detection and PolyMC download
# 3. VERSION DETECTION: Minecraft and Fabric version determination
# 4. ACCOUNT SETUP: Download offline splitscreen player accounts
# 5. MOD COMPATIBILITY: Query APIs and determine compatible mod versions
# 6. USER SELECTION: Interactive mod selection interface
# 7. INSTANCE CREATION: Create 4 splitscreen instances with manual configuration
# 8. INTEGRATION: Optional Steam and desktop launcher integration
# 9. COMPLETION: Summary report and usage instructions
#
# ERROR HANDLING STRATEGY:
# - Each phase has fallback mechanisms to ensure installation can complete
# - Non-critical integration failures don't halt the entire process
# - Comprehensive error reporting helps users understand any issues
# - Multiple validation checkpoints ensure data integrity
#
# LAUNCHER APPROACH:
# The script uses PolyMC as the primary launcher for day-to-day splitscreen gameplay.
main() {
    # Support direct module testing calls with --debug.
    local arg
    for arg in "$@"; do
        if [[ "$arg" == "--debug" ]]; then
            DEBUG_MODE=true
        fi
    done

    print_header "🎮 MINECRAFT SPLITSCREEN INSTALLER 🎮"
    print_info "PolyMC launcher setup with manual instance creation"
    print_debug "Debug logging enabled"
    echo ""
    
    # =============================================================================
    # WORKSPACE INITIALIZATION PHASE
    # =============================================================================
    
    # WORKSPACE SETUP: Create and navigate to working directory
    # All temporary files, downloads, and initial setup happen in TARGET_DIR
    # This provides a clean, isolated environment for the installation process
    print_progress "Initializing installation workspace: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
    cd "$TARGET_DIR" || exit 1
    print_success "✅ Workspace initialized successfully"
    
    # =============================================================================
    # CORE SYSTEM REQUIREMENTS VALIDATION
    # =============================================================================
    
    download_prism_launcher        # Download PolyMC AppImage for splitscreen launcher usage
    
    # =============================================================================
    # MODPACK VERSION DETECTION (before MC version picker)
    # =============================================================================
    
    # Ask about modpack early so it can set MC_VERSION before version selection
    local modpack_selected=false
    local modpack_install_id=""
    echo ""
    print_info "ℹ️  Do you want to install a modpack (e.g. Cobbleverse) on the splitscreen instances?"
    print_info "   If yes, the modpack's target Minecraft version will be used automatically."
    echo ""
    local early_modpack_choice
    read -r -p "Install modpack? [y/N]: " early_modpack_choice
    if [[ "$early_modpack_choice" =~ ^[Yy]$ ]]; then
        echo ""
        print_info "Choose installation method:"
        echo "1) Download from CurseForge (requires numeric ID, e.g. 1210677 for Cobbleverse)"
        echo "2) Install from a local ZIP file"
        read -r -p "Choose [1/2]: " early_install_method
        
        if [[ "$early_install_method" == "2" ]]; then
            modpack_selected=true
            # ZIP modpack — can't detect version early, user will handle during install
            print_info "ZIP modpack selected — version will be checked during installation."
        else
            local early_modpack_id=""
            print_info "Enter CurseForge modpack ID (default: 1210677 for Cobbleverse)"
            read -r -p "Modpack ID [1210677]: " early_modpack_id
            if [[ -z "$early_modpack_id" ]]; then
                early_modpack_id="1210677"
            fi
            modpack_install_id="$early_modpack_id"
            
            # Detect modpack version and potentially set MC_VERSION
            if detect_modpack_version "$early_modpack_id"; then
                modpack_selected=true
            fi
        fi
    fi
    
    # =============================================================================
    # VERSION DETECTION AND CONFIGURATION
    # =============================================================================
    
    get_minecraft_version         # Determine target Minecraft version (skip if already set by modpack)
    detect_java                   # Automatically detect, install, and configure correct Java version for selected Minecraft version
    configure_polymc_defaults     # Write launcher defaults so Quick Setup wizard is skipped
    get_fabric_version           # Get compatible Fabric loader version from API
    get_lwjgl_version            # Detect appropriate LWJGL version for Minecraft version
    
    # =============================================================================
    # OFFLINE ACCOUNTS CONFIGURATION
    # =============================================================================
    
    print_progress "Setting up offline accounts for splitscreen gameplay..."
    print_debug "Downloading pre-configured offline accounts for Player 1-4"
    
    # OFFLINE ACCOUNTS DOWNLOAD: Get splitscreen player account configurations
    # These accounts enable splitscreen without requiring multiple Microsoft accounts
    # Each player (P1, P2, P3, P4) gets a separate offline profile for identification
    if ! wget -O accounts.json "https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/accounts.json"; then
        print_warning "⚠️  Failed to download accounts.json from repository"
        print_info "   → Attempting to use local copy if available..."
        if [[ ! -f "accounts.json" ]]; then
            print_error "❌ No accounts.json found - splitscreen accounts may require manual setup"
            print_info "   → Splitscreen will still work but players may have generic names"
        fi
    else
        print_success "✅ Offline splitscreen accounts configured successfully"
        print_debug "P1, P2, P3, P4 player accounts ready for offline gameplay"
    fi
    
    # =============================================================================
    # MOD ECOSYSTEM SETUP PHASE
    # =============================================================================
    
    check_mod_compatibility       # Query Modrinth/CurseForge APIs for compatible versions
    select_user_mods             # Interactive mod selection interface with categories
    
    # =============================================================================
    # MINECRAFT INSTANCE CREATION PHASE
    # =============================================================================
    
    
    create_instances             # Create 4 splitscreen instances using manual configuration
    setup_splitscreen_launcher_script   # Install minecraftSplitscreen.sh into launcher directory
    
    # =============================================================================
    # MODPACK INSTALLATION PHASE: Install modpack mods + overrides
    # =============================================================================
    
    if [[ "$modpack_selected" == true && -n "$modpack_install_id" ]]; then
        # Already configured early — install now
        echo ""
        print_info "Installing modpack (ID: $modpack_install_id) into all instances..."
        install_modpack "$modpack_install_id" || print_warning "⚠️  Modpack installation had some issues"
        
    elif [[ "$modpack_selected" == true && -z "$modpack_install_id" ]]; then
        # ZIP modpack was selected early — ask for path now
        echo ""
        read -r -p "Path to modpack ZIP file: " zip_path
        if [[ -n "$zip_path" ]]; then
            install_modpack_from_zip "$zip_path" || print_warning "⚠️  Modpack installation had some issues"
        else
            print_warning "No file specified, skipping modpack installation."
        fi
        
    else
        echo ""
        print_info "ℹ️  Do you want to install a modpack (e.g. Cobbleverse) on the splitscreen instances?"
        print_info "   The modpack will be applied to all 4 players."
        echo ""
        local install_modpack_choice
        read -r -p "Install modpack? [y/N]: " install_modpack_choice
        if [[ "$install_modpack_choice" =~ ^[Yy]$ ]]; then
            echo ""
            print_info "Choose installation method:"
            echo "1) Download from CurseForge (requires numeric ID, e.g. 1210677 for Cobbleverse)"
            echo "2) Install from a local ZIP file"
            read -r -p "Choose [1/2]: " install_method
            
            if [[ "$install_method" == "2" ]]; then
                echo ""
                read -r -p "Path to modpack ZIP file: " zip_path
                if [[ -n "$zip_path" ]]; then
                    install_modpack_from_zip "$zip_path" || print_warning "⚠️  Modpack installation had some issues"
                else
                    print_warning "No file specified, skipping modpack installation."
                fi
            else
                local modpack_id=""
                echo ""
                print_info "Enter CurseForge modpack ID (default: 1210677 for Cobbleverse)"
                read -r -p "Modpack ID [1210677]: " modpack_id
                if [[ -z "$modpack_id" ]]; then
                    modpack_id="1210677"
                fi
                install_modpack "$modpack_id" || print_warning "⚠️  Modpack installation had some issues"
            fi
        fi
    fi
    
    # =============================================================================
    # SYSTEM INTEGRATION PHASE: Optional platform integration
    # =============================================================================
    
    setup_steam_integration     # Add splitscreen launcher to Steam library (optional)
    create_desktop_launcher     # Create native desktop launcher and app menu entry (optional)
    
    # =============================================================================
    # INSTALLATION COMPLETION AND STATUS REPORTING
    # =============================================================================
    
    print_header "🎉 INSTALLATION COMPLETE"
    
    # =============================================================================
    # MISSING MODS ANALYSIS: Report any compatibility issues
    # =============================================================================
    
    # MISSING MODS REPORT: Alert user to any mods that couldn't be installed
    # This helps users understand if specific functionality might be unavailable
    # Common causes: no Fabric version available, API changes, temporary download issues
    local missing_count=0
    if [[ ${#MISSING_MODS[@]} -gt 0 ]]; then
        missing_count=${#MISSING_MODS[@]}
    fi
    if [[ $missing_count -gt 0 ]]; then
        echo ""
        print_warning "Some optional mods could not be installed:"
        for mod in "${MISSING_MODS[@]}"; do
            echo "  ❌ $mod"
        done
        print_info "Core splitscreen functionality will still work."
    fi
    
    # =============================================================================
    # FINAL SUCCESS MESSAGE AND NEXT STEPS
    # =============================================================================
    
    echo "✅ Installation successful"
    echo "Launcher: PolyMC"
    echo "Instances: 4 (latestUpdate-1 to latestUpdate-4)"
    echo ""
    echo "Run: $TARGET_DIR/minecraftSplitscreen.sh"

    if [[ "${DEBUG_MODE:-false}" == "true" ]]; then
        echo ""
        echo "Debug details"
        echo "- Installation dir: $TARGET_DIR"
        echo "- Launcher executable: $TARGET_DIR/PolyMC.AppImage"
        echo "- Instances dir: $TARGET_DIR/instances/"
        echo "- Accounts file: $TARGET_DIR/accounts.json"
    fi

    echo ""
    echo "For troubleshooting or updates, visit:"
    echo "https://github.com/FlyingEwok/MinecraftSplitscreenSteamdeck"
    echo "=========================================="
}
