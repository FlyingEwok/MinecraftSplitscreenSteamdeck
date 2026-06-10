#!/bin/bash
# =============================================================================
# Minecraft Splitscreen Steam Deck Installer - Modpack Installer Module
# =============================================================================
# 
# This module handles installation of CurseForge modpacks on top of existing
# splitscreen instances. It downloads the modpack ZIP, resolves all mods,
# and applies them to all 4 instances while preserving splitscreen mods.
#
# Functions provided:
# - detect_modpack_version: Detect a modpack's target MC version and optionally set MC_VERSION
# - install_modpack: Install a CurseForge modpack into all splitscreen instances
# - download_modpack_file: Download a specific mod file from CurseForge by ID
# - get_cf_api_key: Decrypt the CurseForge API key
#
# =============================================================================

readonly MOD_CACHE_DIR="/tmp/minecraft-splitscreen-modcache"

# detect_modpack_version: Check if user wants a modpack, detect its target MC version,
# and optionally set MC_VERSION before instance creation.
# This is called EARLY in the workflow so MC_VERSION is correct from the start.
# Parameters:
#   $1 - modpack_id: CurseForge project ID (e.g., 1210677 for Cobbleverse)
detect_modpack_version() {
    local modpack_id="${1:-}"
    
    if [[ -z "$modpack_id" ]]; then
        return 1
    fi
    
    local cf_api_key
    cf_api_key=$(get_cf_api_key)
    if [[ -z "$cf_api_key" ]]; then
        return 1
    fi
    
    print_progress "Modpack ID: $modpack_id"
    print_progress "Checking modpack Minecraft version compatibility..."
    
    local files_url="https://api.curseforge.com/v1/mods/$modpack_id/files?modLoaderType=4"
    local tmp_files
    tmp_files=$(mktemp)
    
    local http_code
    http_code=$(curl -s -L -w "%{http_code}" -o "$tmp_files" -H "x-api-key: $cf_api_key" "$files_url" 2>/dev/null)
    
    if [[ "$http_code" != "200" ]]; then
        print_warning "Failed to fetch modpack files (HTTP $http_code) — will use version picker normally"
        rm -f "$tmp_files"
        return 1
    fi
    
    # Determine the modpack's target MC version
    local modpack_target_version
    modpack_target_version=$(jq -r '
        [.data[]
        | .gameVersions[]
        | select(test("^[0-9]+\\.[0-9]+(\\.[0-9]+)?$"))
        ]
        | group_by(.)
        | map({version: .[0], count: length})
        | sort_by(.count)
        | reverse[0].version
    ' "$tmp_files" 2>/dev/null)
    
    local available_versions
    available_versions=$(jq -r '[.data[].gameVersions[]] | unique | sort | .[]' "$tmp_files" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)?$' | sort -V | uniq)
    
    rm -f "$tmp_files"
    
    if [[ -z "$modpack_target_version" ]]; then
        print_warning "Could not determine modpack target version — will use version picker"
        return 1
    fi
    
    echo ""
    print_info "This modpack is primarily for Minecraft $modpack_target_version."
    echo ""
    local switch_version
    read -r -p "Use Minecraft $modpack_target_version (required by modpack)? [Y/n]: " switch_version
    if [[ ! "$switch_version" =~ ^[Nn]$ ]]; then
        MC_VERSION="$modpack_target_version"
        export MC_VERSION
        
        # Verify required splitscreen mods are available for this version
        print_progress "Verifying splitscreen mods compatibility with $MC_VERSION..."
        local controllable_ok=false
        local splitscreen_ok=false
        
        if check_mod_version_compatibility "317269" "curseforge" "$MC_VERSION" "false"; then
            controllable_ok=true
        fi
        if check_mod_version_compatibility "yJgqfSDR" "modrinth" "$MC_VERSION" "false"; then
            splitscreen_ok=true
        fi
        
        if [[ "$controllable_ok" != true || "$splitscreen_ok" != true ]]; then
            echo ""
            print_warning "⚠️  Required mods NOT fully compatible with Minecraft $MC_VERSION:"
            [[ "$controllable_ok" != true ]] && echo "     ❌ Controllable"
            [[ "$splitscreen_ok" != true ]] && echo "     ❌ Splitscreen Support"
            echo ""
            print_info "   Splitscreen won't work correctly with this modpack version."
            echo ""
            local force_version
            read -r -p "Use $MC_VERSION anyway? [y/N]: " force_version
            if [[ ! "$force_version" =~ ^[Yy]$ ]]; then
                print_info "Modpack version selection cancelled — will use version picker instead."
                MC_VERSION=""
                export MC_VERSION
                return 1
            fi
        fi
        
        print_success "MC_VERSION set to $MC_VERSION (from modpack)"
        return 0
    fi
    
    return 1
}

# download_mod_file: Download a single mod + recursively resolve its CurseForge deps.
# Uses temp files for cross-call state tracking. Avoids subshells throughout.
# Parameters:
#   $1 - pid: CurseForge project ID
#   $2 - fid: CurseForge file ID
#   $3 - mods_dir: Download target directory
#   $4 - cf_api_key: CurseForge API key
#   $5 - resolved_pids_file: Path to file tracking already-resolved project IDs
#   $6 - manifest_pids_file: Path to file with manifest project IDs (skip deps already in manifest)
# Returns: 0=downloaded, 1=failed, 2=already present or already resolved
download_mod_file() {
    local pid="$1"
    local fid="$2"
    local mods_dir="$3"
    local cf_api_key="$4"
    local resolved_pids_file="$5"
    local manifest_pids_file="$6"
    
    # Guard: already resolved (circular deps)
    if grep -q "^${pid}$" "$resolved_pids_file" 2>/dev/null; then
        return 2
    fi
    echo "$pid" >> "$resolved_pids_file"
    
    # Get file info (includes file name + dependencies array)
    local file_info
    file_info=$(curl -s -m 15 -H "x-api-key: $cf_api_key" "https://api.curseforge.com/v1/mods/$pid/files/$fid" 2>/dev/null)
    local file_name
    file_name=$(echo "$file_info" | jq -r '.data.fileName // ""' 2>/dev/null)
    
    if [[ -z "$file_name" ]]; then
        return 1
    fi
    
    # Check persistent cache in /tmp
    local from_cache=false
    mkdir -p "$MOD_CACHE_DIR"
    if [[ -f "$MOD_CACHE_DIR/$file_name" ]]; then
        print_progress "  Using cached $file_name"
        cp "$MOD_CACHE_DIR/$file_name" "$mods_dir/$file_name"
        from_cache=true
    fi
    
    # Check if already present in all 4 instances
    local found_all=true
    for i in 1 2 3 4; do
        local inst_mods="$TARGET_DIR/instances/latestUpdate-$i/.minecraft/mods"
        if [[ -d "$inst_mods" ]] && [[ ! -f "$inst_mods/$file_name" ]]; then
            found_all=false
            break
        fi
    done
    if $found_all; then
        return 2
    fi
    
    if ! $from_cache; then
        print_progress "  Downloading $file_name (project $pid)..."
        local dl_url="https://www.curseforge.com/api/v1/mods/$pid/files/$fid/download"
        if ! wget -O "$mods_dir/$file_name" --header="x-api-key: $cf_api_key" "$dl_url" 2>/dev/null; then
            print_warning "    Failed to download $file_name"
            return 1
        fi
        
        # Seed cache for future runs
        mkdir -p "$MOD_CACHE_DIR"
        cp "$mods_dir/$file_name" "$MOD_CACHE_DIR/$file_name"
    fi
    
    # Resolve required dependencies (no subshell — while read < file)
    local deps_file
    deps_file=$(mktemp)
    echo "$file_info" | jq -r '.data.dependencies[]? | select(.relationType == "required_dependency") | .modId' > "$deps_file" 2>/dev/null
    
    local dep_pid
    while IFS= read -r dep_pid; do
        [[ -z "$dep_pid" ]] && continue
        
        # Skip if already in manifest (will be downloaded as a manifest entry)
        if grep -q "^${dep_pid}$" "$manifest_pids_file" 2>/dev/null; then
            continue
        fi
        # Skip if already resolved (may be in resolved_pids_file from another dep chain)
        if grep -q "^${dep_pid}$" "$resolved_pids_file" 2>/dev/null; then
            continue
        fi
        
        print_progress "    ↳ Resolving dependency: project $dep_pid..."
        
        # Find latest compatible file for this MC version + Fabric (modLoaderType=4)
        local dep_url="https://api.curseforge.com/v1/mods/$dep_pid/files?gameVersion=$MC_VERSION&modLoaderType=4&pageSize=1"
        local dep_file_id
        dep_file_id=$(curl -s -m 15 -H "x-api-key: $cf_api_key" "$dep_url" 2>/dev/null | jq -r '.data[0].id // ""' 2>/dev/null)
        
        if [[ -n "$dep_file_id" && "$dep_file_id" != "null" ]]; then
            download_mod_file "$dep_pid" "$dep_file_id" "$mods_dir" "$cf_api_key" "$resolved_pids_file" "$manifest_pids_file"
        else
            print_warning "    ↳ No compatible file found for dependency $dep_pid (skipped)"
        fi
    done < "$deps_file"
    rm -f "$deps_file"
    
    return 0
}

# install_modpack: Install a CurseForge modpack into all splitscreen instances.
# Downloads the modpack, resolves all mods, applies overrides to each instance.
# Parameters:
#   $1 - modpack_id: CurseForge project ID (e.g., 1210677 for Cobbleverse)
install_modpack() {
    local modpack_id="${1:-}"
    
    if [[ -z "$modpack_id" ]]; then
        print_error "No modpack ID provided"
        return 1
    fi
    
    print_header "📦 INSTALLING MODPACK"
    print_progress "Modpack ID: $modpack_id"
    
    # Get CurseForge API key
    local cf_api_key
    cf_api_key=$(get_cf_api_key)
    if [[ -z "$cf_api_key" ]]; then
        print_error "Failed to get CurseForge API key"
        return 1
    fi
    
    # Step 1: Find the latest modpack file
    print_progress "Fetching modpack file list..."
    local files_url="https://api.curseforge.com/v1/mods/$modpack_id/files?modLoaderType=4"
    local tmp_files
    tmp_files=$(mktemp)
    
    local http_code
    http_code=$(curl -s -L -w "%{http_code}" -o "$tmp_files" -H "x-api-key: $cf_api_key" "$files_url" 2>/dev/null)
    
    if [[ "$http_code" != "200" ]]; then
        print_error "Failed to fetch modpack files (HTTP $http_code)"
        rm -f "$tmp_files"
        return 1
    fi
    
    # Determine the modpack's target MC version (the one with the most files)
    local modpack_target_version
    modpack_target_version=$(jq -r '
        [.data[]
        | .gameVersions[]
        | select(test("^[0-9]+\\.[0-9]+(\\.[0-9]+)?$"))
        ]
        | group_by(.)
        | map({version: .[0], count: length})
        | sort_by(.count)
        | reverse[0].version
    ' "$tmp_files" 2>/dev/null)
    
    # List all available versions for display
    local available_versions
    available_versions=$(jq -r '[.data[].gameVersions[]] | unique | sort | .[]' "$tmp_files" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)?$' | sort -V | uniq)
    
    # Try to find a file matching the current MC_VERSION
    local modpack_file_id
    modpack_file_id=$(jq -r --arg v "$MC_VERSION" '
        .data[]
        | select(.gameVersions[] == $v)
        | .id
    ' "$tmp_files" 2>/dev/null | head -n1)
    
    if [[ -z "$modpack_file_id" || "$modpack_file_id" == "null" ]]; then
        echo ""
        print_warning "⚠️  Modpack does not support Minecraft $MC_VERSION"
        print_info "   Available Minecraft versions for this modpack:"
        echo "$available_versions" | head -20 | while read -r ver; do
            echo "     • $ver"
        done
        echo ""
        
        if [[ -n "$modpack_target_version" ]]; then
            print_info "   This modpack targets Minecraft $modpack_target_version."
            echo ""
            local switch_version
            read -r -p "Switch to Minecraft $modpack_target_version for the modpack? [Y/n]: " switch_version
            if [[ ! "$switch_version" =~ ^[Nn]$ ]]; then
                local old_mc_version="$MC_VERSION"
                MC_VERSION="$modpack_target_version"
                print_success "Switched MC_VERSION from $old_mc_version to $MC_VERSION"
                
                # Update existing instances to the modpack's MC version
                print_progress "Updating instance configs to Minecraft $MC_VERSION..."
                for i in 1 2 3 4; do
                    local inst_cfg="$TARGET_DIR/instances/latestUpdate-$i/instance.cfg"
                    local inst_pack="$TARGET_DIR/instances/latestUpdate-$i/mmc-pack.json"
                    
                    if [[ -f "$inst_cfg" ]]; then
                        sed -i "s/^IntendedVersion=.*/IntendedVersion=$MC_VERSION/" "$inst_cfg" 2>/dev/null || true
                    fi
                    if [[ -f "$inst_pack" ]]; then
                        sed -i "s/\"cachedVersion\": \"$old_mc_version\"/\"cachedVersion\": \"$MC_VERSION\"/" "$inst_pack" 2>/dev/null || true
                        sed -i "s/\"version\": \"$old_mc_version\"/\"version\": \"$MC_VERSION\"/g" "$inst_pack" 2>/dev/null || true
                    fi
                done
                print_success "Instance configs updated to Minecraft $MC_VERSION"
                
                # Re-find the matching file with the new version
                modpack_file_id=$(jq -r --arg v "$MC_VERSION" '
                    .data[]
                    | select(.gameVersions[] == $v)
                    | .id
                ' "$tmp_files" 2>/dev/null | head -n1)
            fi
        fi
        
        # If still no match (user declined switch or modpack_target was empty)
        if [[ -z "$modpack_file_id" || "$modpack_file_id" == "null" ]]; then
            echo ""
            local force_anyway
            read -r -p "Install latest modpack file anyway? [y/N]: " force_anyway
            if [[ "$force_anyway" =~ ^[Yy]$ ]]; then
                modpack_file_id=$(jq -r '.data[0].id' "$tmp_files" 2>/dev/null)
                print_info "Using latest file ID: $modpack_file_id (may be incompatible)"
            else
                print_info "Skipping modpack installation."
                rm -f "$tmp_files"
                return 0
            fi
        fi
    fi
    rm -f "$tmp_files"
    
    if [[ -z "$modpack_file_id" || "$modpack_file_id" == "null" ]]; then
        print_error "Could not find any modpack files"
        return 1
    fi
    
    print_info "Found modpack file ID: $modpack_file_id"
    
    # Step 2: Download the modpack ZIP
    print_progress "Downloading modpack ZIP..."
    local modpack_url="https://api.curseforge.com/v1/mods/$modpack_id/files/$modpack_file_id"
    local tmp_modpack
    tmp_modpack=$(mktemp -d)
    local zip_file="$tmp_modpack/modpack.zip"
    
    # Use direct download endpoint (downloadUrl from API is often null for modpacks)
    local dl_url="https://www.curseforge.com/api/v1/mods/$modpack_id/files/$modpack_file_id/download"
    
    if ! wget -O "$zip_file" --header="x-api-key: $cf_api_key" "$dl_url" 2>/dev/null; then
        print_error "Failed to download modpack ZIP"
        rm -rf "$tmp_modpack"
        return 1
    fi
    print_success "Modpack ZIP downloaded"
    
    # Step 3: Extract and parse manifest.json
    print_progress "Parsing modpack manifest..."
    local extract_dir="$tmp_modpack/extracted"
    mkdir -p "$extract_dir"
    
    if ! unzip -o "$zip_file" -d "$extract_dir" >/dev/null 2>&1; then
        print_error "Failed to extract modpack ZIP"
        rm -rf "$tmp_modpack"
        return 1
    fi
    
    local manifest="$extract_dir/manifest.json"
    if [[ ! -f "$manifest" ]]; then
        print_error "No manifest.json found in modpack (may be a direct mod ZIP)"
        print_info "Trying to copy as mod file directly..."
        # Try copying the ZIP contents as mods
        local mods_found=0
        for f in "$extract_dir"/*.jar; do
            if [[ -f "$f" ]]; then
                mods_found=$((mods_found + 1))
            fi
        done
        if [[ $mods_found -gt 0 ]]; then
            print_info "Found $mods_found JAR files, copying to instances..."
            for i in 1 2 3 4; do
                local inst_mods="$TARGET_DIR/instances/latestUpdate-$i/.minecraft/mods"
                if [[ -d "$inst_mods" ]]; then
                    cp "$extract_dir"/*.jar "$inst_mods/" 2>/dev/null
                fi
            done
            print_success "Copied mod JARs to all instances"
        else
            print_error "No JARs found either. This modpack format is not supported."
            rm -rf "$tmp_modpack"
            return 1
        fi
        rm -rf "$tmp_modpack"
        return 0
    fi
    
    # Read mod list from manifest
    local mod_count
    mod_count=$(jq '.files | length' "$manifest" 2>/dev/null)
    local mc_target
    mc_target=$(jq -r '.minecraft.version // ""' "$manifest" 2>/dev/null)
    local loader_needed
    loader_needed=$(jq -r '.minecraft.modLoaders[0].id // ""' "$manifest" 2>/dev/null)
    
    print_info "Modpack targets: Minecraft $mc_target, Loader: $loader_needed"
    print_info "Resolving $mod_count mods..."
    
    # Step 4: Download each mod JAR with recursive dependency resolution
    local mods_dir="$tmp_modpack/mods"
    mkdir -p "$mods_dir"
    local resolved=0
    local skipped=0
    local failed=0
    
    # Track project IDs to avoid redundant downloads
    local manifest_pids_file
    manifest_pids_file=$(mktemp)
    jq -r '.files[].projectID' "$manifest" 2>/dev/null | sort -u > "$manifest_pids_file"
    
    local resolved_pids_file
    resolved_pids_file=$(mktemp)
    > "$resolved_pids_file"
    
    # Process each manifest entry (process substitution — no subshell)
    local entry
    while IFS= read -r entry; do
        local pid fid
        pid=$(echo "$entry" | jq -r '.projectID')
        fid=$(echo "$entry" | jq -r '.fileID')
        
        download_mod_file "$pid" "$fid" "$mods_dir" "$cf_api_key" "$resolved_pids_file" "$manifest_pids_file"
        case $? in
            0) resolved=$((resolved + 1)) ;;
            1) failed=$((failed + 1)) ;;
            2) skipped=$((skipped + 1)) ;;
        esac
    done < <(jq -c '.files[]' "$manifest" 2>/dev/null)
    
    rm -f "$manifest_pids_file" "$resolved_pids_file"
    
    print_success "Downloaded $resolved mods, $skipped already present, $failed failed"
    
    # Step 5: Apply to all 4 instances
    local overrides_dir="$extract_dir/overrides"
    
    for i in 1 2 3 4; do
        local inst_dir="$TARGET_DIR/instances/latestUpdate-$i/.minecraft"
        
        if [[ ! -d "$inst_dir" ]]; then
            print_warning "Instance latestUpdate-$i not found, skipping..."
            continue
        fi
        
        print_progress "Installing modpack to Player $i..."
        
        # Copy mod JARs (don't overwrite splitscreen mods)
        if [[ -d "$mods_dir" ]] && [[ "$(ls -A "$mods_dir" 2>/dev/null)" ]]; then
            cp -n "$mods_dir"/*.jar "$inst_dir/mods/" 2>/dev/null || true
        fi
        
        # Apply overrides (config, scripts, resourcepacks, etc.)
        if [[ -d "$overrides_dir" ]]; then
            cp -rf "$overrides_dir"/* "$inst_dir/" 2>/dev/null || true
        fi
    done
    
    # Cleanup
    rm -rf "$tmp_modpack"
    
    print_success "✅ Modpack installed to all instances!"
    print_info "Make sure Controllable + Splitscreen Support are still in each mods/ folder."
    return 0
}

# get_cf_api_key: Decrypt the CurseForge API key from the repository
get_cf_api_key() {
    local cf_token_enc_url="https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/token.enc"
    local tmp_token_file
    tmp_token_file=$(mktemp)
    
    local http_code
    http_code=$(timeout 10 curl -s -L -w "%{http_code}" -o "$tmp_token_file" "$cf_token_enc_url" 2>/dev/null)
    
    if [[ "$http_code" != "200" ]] || [[ ! -s "$tmp_token_file" ]]; then
        rm -f "$tmp_token_file"
        echo ""
        return 1
    fi
    
    local cf_api_key
    if command -v openssl >/dev/null 2>&1; then
        cf_api_key=$(openssl enc -d -aes-256-cbc -a -pbkdf2 -in "$tmp_token_file" -pass pass:"MinecraftSplitscreenSteamDeck2025" 2>/dev/null | tr -d '\n\r' | sed 's/[[:space:]]*$//')
    fi
    
    rm -f "$tmp_token_file"
    echo "$cf_api_key"
}

# install_modpack_from_zip: Install modpack from a local ZIP file
# Parameters:
#   $1 - zip_path: Path to the modpack ZIP file
install_modpack_from_zip() {
    local zip_path="${1:-}"
    
    if [[ -z "$zip_path" || ! -f "$zip_path" ]]; then
        print_error "Invalid ZIP file path: $zip_path"
        return 1
    fi
    
    print_header "📦 INSTALLING MODPACK FROM ZIP"
    print_progress "ZIP file: $zip_path"
    
    local tmp_dir
    tmp_dir=$(mktemp -d)
    
    if ! unzip -o "$zip_path" -d "$tmp_dir" >/dev/null 2>&1; then
        print_error "Failed to extract ZIP"
        rm -rf "$tmp_dir"
        return 1
    fi
    
    local manifest="$tmp_dir/manifest.json"
    
    if [[ ! -f "$manifest" ]]; then
        print_warning "No manifest.json found - checking for direct JARs..."
        local jars=0
        for f in "$tmp_dir"/*.jar; do
            if [[ -f "$f" ]]; then jars=$((jars+1)); fi
        done
        if [[ $jars -gt 0 ]]; then
            for i in 1 2 3 4; do
                local inst_mods="$TARGET_DIR/instances/latestUpdate-$i/.minecraft/mods"
                [[ -d "$inst_mods" ]] && cp "$tmp_dir"/*.jar "$inst_mods/" 2>/dev/null || true
                # Also copy overrides
                [[ -d "$tmp_dir/overrides" ]] && cp -rf "$tmp_dir/overrides"/* "$TARGET_DIR/instances/latestUpdate-$i/.minecraft/" 2>/dev/null || true
            done
            print_success "Copied $jars mod JARs to all instances"
        else
            print_error "No manifest.json or JAR files found in ZIP"
            rm -rf "$tmp_dir"
            return 1
        fi
    else
        # Has manifest - need to download mods via API
        print_info "Modpack manifest found - will download mods via CurseForge API"
        
        local cf_api_key
        cf_api_key=$(get_cf_api_key)
        
        local mods_out="$tmp_dir/mods_resolved"
        mkdir -p "$mods_out"
        local resolved=0 skipped=0 failed=0
        
        # Track project IDs to avoid redundant downloads
        local manifest_pids_file
        manifest_pids_file=$(mktemp)
        jq -r '.files[].projectID' "$manifest" 2>/dev/null | sort -u > "$manifest_pids_file"
        
        local resolved_pids_file
        resolved_pids_file=$(mktemp)
        > "$resolved_pids_file"
        
        # Process each manifest entry (process substitution — no subshell)
        local entry
        while IFS= read -r entry; do
            local pid fid
            pid=$(echo "$entry" | jq -r '.projectID')
            fid=$(echo "$entry" | jq -r '.fileID')
            
            if [[ -z "$cf_api_key" ]]; then
                print_warning "  No API key - can't download mod $pid"
                failed=$((failed+1))
                continue
            fi
            
            download_mod_file "$pid" "$fid" "$mods_out" "$cf_api_key" "$resolved_pids_file" "$manifest_pids_file"
            case $? in
                0) resolved=$((resolved + 1)) ;;
                1) failed=$((failed + 1)) ;;
                2) skipped=$((skipped + 1)) ;;
            esac
        done < <(jq -c '.files[]' "$manifest" 2>/dev/null)
        
        rm -f "$manifest_pids_file" "$resolved_pids_file"
        print_info "Downloaded $resolved mod JARs, $skipped already present, $failed failed"
        
        # Apply to instances
        local overrides_dir="$tmp_dir/overrides"
        for i in 1 2 3 4; do
            local inst_dir="$TARGET_DIR/instances/latestUpdate-$i/.minecraft"
            [[ ! -d "$inst_dir" ]] && continue
            
            print_progress "Installing to Player $i..."
            [[ -d "$mods_out" ]] && [[ "$(ls -A "$mods_out" 2>/dev/null)" ]] && cp -n "$mods_out"/*.jar "$inst_dir/mods/" 2>/dev/null || true
            [[ -d "$overrides_dir" ]] && cp -rf "$overrides_dir"/* "$inst_dir/" 2>/dev/null || true
        done
    fi
    
    rm -rf "$tmp_dir"
    print_success "✅ Modpack installed from ZIP to all instances!"
}
