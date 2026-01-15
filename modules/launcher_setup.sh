#!/bin/bash
# =============================================================================
# LAUNCHER SETUP MODULE
# =============================================================================
# PrismLauncher setup and CLI verification functions
# PrismLauncher is used for automated instance creation via CLI
# It provides reliable Minecraft instance management and Fabric loader installation

# download_prism_launcher: Download the latest PrismLauncher AppImage
# PrismLauncher provides CLI tools for automated instance creation
# We download it to the target directory for temporary use during setup
download_prism_launcher() {
    # Skip download if AppImage already exists
    if [[ -f "$TARGET_DIR/PrismLauncher.AppImage" ]]; then
        print_success "PrismLauncher AppImage already present"
        return 0
    fi
    
    print_progress "Downloading latest PrismLauncher AppImage..."
    
    # Query GitHub API to get the latest release download URL
    # We specifically look for AppImage files in the release assets
    local prism_url
    prism_url=$(curl -s https://api.github.com/repos/PrismLauncher/PrismLauncher/releases/latest | \
        jq -r '.assets[] | select(.name | test("x86_64.*AppImage$")) | .browser_download_url' | head -n1)
    
    # Validate that we got a valid download URL
    if [[ -z "$prism_url" || "$prism_url" == "null" ]]; then
        print_error "Could not find latest PrismLauncher AppImage URL."
        print_error "Please check https://github.com/PrismLauncher/PrismLauncher/releases manually."
        exit 1
    fi
    
    # Download and make executable
    wget -O "$TARGET_DIR/PrismLauncher.AppImage" "$prism_url"
    chmod +x "$TARGET_DIR/PrismLauncher.AppImage"
    print_success "PrismLauncher AppImage downloaded successfully"
}

# verify_prism_cli: Ensure PrismLauncher supports CLI operations
# We need CLI support for automated instance creation
# This function validates that the downloaded version has the required features
verify_prism_cli() {
    print_progress "Verifying PrismLauncher CLI capabilities..."
    
    local appimage="$TARGET_DIR/PrismLauncher.AppImage"
    
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
        print_warning "PrismLauncher execution failed, using manual instance creation"
        print_info "Error output: $(echo "$help_output" | head -3)"
        return 1
    fi
    
    # Test for basic CLI support by checking help output
    # Look for keywords that indicate CLI instance creation is available
    if ! echo "$help_output" | grep -q -E "(cli|create|instance)"; then
        print_warning "PrismLauncher CLI may not support instance creation. Checking with --help-all..."
        
        # Fallback: try the extended help option
        local extended_help
        extended_help=$("$appimage" --help-all 2>&1)
        if ! echo "$extended_help" | grep -q -E "(cli|create-instance)"; then
            print_warning "This version of PrismLauncher does not support CLI instance creation"
            print_info "Will use manual instance creation method instead"
            return 1
        fi
    fi
    
    # Display available CLI commands for debugging purposes
    print_info "Available PrismLauncher CLI commands:"
    echo "$help_output" | grep -E "(create|instance|cli)" || echo "  (Basic CLI commands found)"
    print_success "PrismLauncher CLI instance creation verified"
    return 0
}
