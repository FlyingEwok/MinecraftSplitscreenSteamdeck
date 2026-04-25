#!/bin/bash
# =============================================================================
# LAUNCHER SETUP MODULE
# =============================================================================
# PolyMC setup and CLI verification functions
# PolyMC is used for automated instance creation via CLI
# It provides reliable Minecraft instance management and Fabric loader installation

# download_prism_launcher: Download the latest PolyMC AppImage
# PolyMC provides CLI tools for automated instance creation
# We download it to the target directory for temporary use during setup
download_prism_launcher() {
    # Skip download if AppImage already exists
    if [[ -f "$TARGET_DIR/PolyMC.AppImage" ]]; then
        print_success "PolyMC AppImage already present"
        return 0
    fi
    
    print_progress "Downloading latest PolyMC AppImage..."
    
    # Query GitHub API to get the latest release download URL
    # We specifically look for AppImage files in the release assets
    local prism_url
    prism_url=$(curl -s https://api.github.com/repos/PolyMC/PolyMC/releases/latest | \
        jq -r '.assets[]
            | select(
                (.name | ascii_downcase | endswith("appimage"))
                and (
                    (.name | ascii_downcase | contains("x86_64"))
                    or (.name | ascii_downcase | contains("amd64"))
                )
            )
            | .browser_download_url' | \
        head -n1)
    
    # Validate that we got a valid download URL
    if [[ -z "$prism_url" || "$prism_url" == "null" ]]; then
        print_error "Could not find latest PolyMC AppImage URL."
        print_error "Please check https://github.com/PolyMC/PolyMC/releases manually."
        exit 1
    fi
    
    # Download and make executable
    wget -O "$TARGET_DIR/PolyMC.AppImage" "$prism_url"
    chmod +x "$TARGET_DIR/PolyMC.AppImage"
    print_success "PolyMC AppImage downloaded successfully"
}

# verify_prism_cli: Ensure PolyMC supports CLI operations
# We need CLI support for automated instance creation
# This function validates that the downloaded version has the required features
verify_prism_cli() {
    print_progress "Verifying PolyMC CLI capabilities..."
    
    local appimage="$TARGET_DIR/PolyMC.AppImage"
    
    # Ensure the AppImage is executable
    chmod +x "$appimage"
    
    # Try to run the AppImage to check CLI support
    local help_output
    help_output=$("$appimage" --help 2>&1)
    local exit_code=$?
    
    # Check if AppImage failed due to FUSE issues or squashfs problems
    if [[ $exit_code -ne 0 ]] && echo "$help_output" | grep -q "FUSE\|Cannot mount\|squashfs\|Failed to open"; then
        print_warning "AppImage execution failed due to FUSE/squashfs issues"
        
        # Try extracting AppImage to avoid FUSE dependency
        print_progress "Attempting to extract AppImage contents..."
        cd "$TARGET_DIR"
        if "$appimage" --appimage-extract >/dev/null 2>&1; then
            if [[ -d "$TARGET_DIR/squashfs-root" ]] && [[ -x "$TARGET_DIR/squashfs-root/AppRun" ]]; then
                print_success "AppImage extracted successfully"
                # Update appimage path to point to extracted version
                appimage="$TARGET_DIR/squashfs-root/AppRun"
                help_output=$("$appimage" --help 2>&1)
                exit_code=$?
            else
                print_warning "AppImage extraction failed or incomplete"
                print_info "Will skip CLI creation and use manual instance creation method"
                return 1
            fi
        else
            print_warning "AppImage extraction failed"
            print_info "Will skip CLI creation and use manual instance creation method"
            return 1
        fi
    fi
    
    # Check if help command worked after potential extraction
    if [[ $exit_code -ne 0 ]]; then
        print_warning "PolyMC execution failed, using manual instance creation"
        print_info "Error output: $(echo "$help_output" | head -3)"
        return 1
    fi
    
    # Test for basic CLI support by checking help output
    # Look for keywords that indicate CLI instance creation is available
    if ! echo "$help_output" | grep -q -E "(cli|create|instance)"; then
        print_warning "PolyMC CLI may not support instance creation. Checking with --help-all..."
        
        # Fallback: try the extended help option
        local extended_help
        extended_help=$("$appimage" --help-all 2>&1)
        if ! echo "$extended_help" | grep -q -E "(cli|create-instance)"; then
            print_warning "This version of PolyMC does not support CLI instance creation"
            print_info "Will use manual instance creation method instead"
            return 1
        fi
    fi
    
    # Display available CLI commands for debugging purposes
    print_info "Available PolyMC CLI commands:"
    echo "$help_output" | grep -E "(create|instance|cli)" || echo "  (Basic CLI commands found)"
    print_success "PolyMC CLI instance creation verified"
    return 0
}

# configure_polymc_defaults: Write a baseline PolyMC config to avoid first-run setup prompts.
configure_polymc_defaults() {
    print_progress "Configuring PolyMC defaults (Java + memory)..."

    local cfg_path="$TARGET_DIR/polymc.cfg"
    local current_hostname
    if command -v hostname >/dev/null 2>&1; then
        current_hostname=$(hostname)
    elif [[ -n "${HOSTNAME:-}" ]]; then
        current_hostname="$HOSTNAME"
    else
        current_hostname="localhost"
    fi

    local java_cfg_path="${JAVA_PATH:-java}"
    cat > "$cfg_path" <<EOF
[General]
ApplicationTheme=system
ConfigVersion=1.2
IconTheme=pe_colored
JavaPath=${java_cfg_path}
Language=en_US
LastHostname=${current_hostname}
MaxMemAlloc=4096
MinMemAlloc=512
ToolbarsLocked=false
EOF

    print_success "PolyMC defaults written: $cfg_path"
    return 0
}

# setup_splitscreen_launcher_script: Install minecraftSplitscreen.sh into TARGET_DIR
# Prefer local repository copy when available, fall back to GitHub download.
setup_splitscreen_launcher_script() {
    print_progress "Installing splitscreen launcher script..."

    local launcher_script="$TARGET_DIR/minecraftSplitscreen.sh"
    local local_script="${SCRIPT_DIR:-}/minecraftSplitscreen.sh"
    local remote_script="https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/minecraftSplitscreen.sh"

    if [[ -f "$local_script" ]]; then
        cp "$local_script" "$launcher_script"
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL "$remote_script" -o "$launcher_script"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$launcher_script" "$remote_script"
    else
        print_error "Neither curl nor wget is available to fetch minecraftSplitscreen.sh"
        return 1
    fi

    chmod +x "$launcher_script"
    print_success "Splitscreen launcher script installed: $launcher_script"
    return 0
}
