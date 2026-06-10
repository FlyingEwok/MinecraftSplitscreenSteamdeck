#!/bin/bash
# =============================================================================
# VERSION MANAGEMENT MODULE
# =============================================================================
# Minecraft and Fabric version selection and detection functions
# Intelligent version selection based on required mod compatibility

# get_supported_minecraft_versions: Check what Minecraft versions support required mods
# Queries APIs for Controllable and Splitscreen Support to find compatible versions
# Returns: Array of supported Minecraft versions in descending order (newest first)
get_supported_minecraft_versions() {
    if [[ -n "${EXTRA_REQUIRED_MOD_ID:-}" && -n "${EXTRA_REQUIRED_MOD_PLATFORM:-}" ]]; then
        print_progress "Checking supported Minecraft versions for core mods + ${EXTRA_REQUIRED_MOD_NAME:-custom mod}..." >&2
    else
        print_progress "Checking supported Minecraft versions for essential splitscreen mods..." >&2
    fi
    
    local -a supported_versions=()
    local -a all_versions=()
    
    # Get all Minecraft versions from Mojang API
    local mojang_versions
    mojang_versions=$(curl -s "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json" 2>/dev/null | jq -r '.versions[] | select(.type=="release") | .id' 2>/dev/null)
    
    if [[ -z "$mojang_versions" ]]; then
        print_error "Could not fetch Minecraft versions from Mojang API" >&2
        print_error "Please check your internet connection and try again" >&2
        return 1
    else
        # Convert to array and limit to recent versions (last 15 releases for testing)
        readarray -t all_versions <<< "$mojang_versions"
        all_versions=("${all_versions[@]:0:15}")
    fi
    
    print_info "Checking compatibility for required splitscreen mods..." >&2
    
    # Optional extra required mod constraint (used when user asks to switch versions
    # to support a specific custom mod in addition to the two required core mods).
    local extra_mod_id="${EXTRA_REQUIRED_MOD_ID:-}"
    local extra_mod_platform="${EXTRA_REQUIRED_MOD_PLATFORM:-}"
    local extra_mod_name="${EXTRA_REQUIRED_MOD_NAME:-Custom mod}"

    # Check each Minecraft version for compatibility with core required mods,
    # and optionally with an extra custom mod requirement.
    for mc_version in "${all_versions[@]}"; do
        print_progress "  Testing $mc_version..." >&2
        
        local controllable_compatible=false
        local splitscreen_compatible=false
        
        # Check Controllable (CurseForge mod 317269)
        if check_mod_version_compatibility "317269" "curseforge" "$mc_version"; then
            controllable_compatible=true
        fi
        
        # Check Splitscreen Support (Modrinth mod yJgqfSDR)  
        if check_mod_version_compatibility "yJgqfSDR" "modrinth" "$mc_version"; then
            splitscreen_compatible=true
        fi
        
        local extra_mod_compatible=true
        if [[ -n "$extra_mod_id" && -n "$extra_mod_platform" ]]; then
            if ! check_mod_version_compatibility "$extra_mod_id" "$extra_mod_platform" "$mc_version" "true"; then
                extra_mod_compatible=false
            fi
        fi

        # Only include versions where core required mods are available,
        # and custom required mod too when specified.
        if [[ "$controllable_compatible" == true && "$splitscreen_compatible" == true && "$extra_mod_compatible" == true ]]; then
            supported_versions+=("$mc_version")
            if [[ -n "$extra_mod_id" && -n "$extra_mod_platform" ]]; then
                print_success "    ✅ $mc_version - Core mods + $extra_mod_name compatible" >&2
            else
                print_success "    ✅ $mc_version - Both core mods compatible" >&2
            fi
        else
            if [[ -n "$extra_mod_id" && -n "$extra_mod_platform" ]]; then
                print_info "    ❌ $mc_version - Missing support for core mods or $extra_mod_name" >&2
            else
                print_info "    ❌ $mc_version - Missing essential core mod support" >&2
            fi
        fi
    done
    
    if [[ ${#supported_versions[@]} -eq 0 ]]; then
        if [[ -n "$extra_mod_id" && -n "$extra_mod_platform" ]]; then
            print_error "No Minecraft versions found that support both required core mods and $extra_mod_name." >&2
            print_error "This may be due to exact-version compatibility limits in the selected custom mod." >&2
        else
            print_error "No Minecraft versions found with both required mods available!" >&2
            print_error "This may be due to API issues. Please try again later or check your internet connection." >&2
        fi
        return 1
    fi
    
    # Return the supported versions array (to stdout only)
    printf '%s\n' "${supported_versions[@]}"
}

# check_mod_version_compatibility: Check if a specific mod supports a specific MC version
# This is a lightweight version check that doesn't add mods to arrays
# Parameters:
#   $1 - mod_id: Mod ID (Modrinth project ID or CurseForge project ID)
#   $2 - platform: "modrinth" or "curseforge"  
#   $3 - mc_version: Minecraft version to check (e.g. "1.21.3")
# Returns: 0 if compatible, 1 if not compatible
check_mod_version_compatibility() {
    local mod_id="$1"
    local platform="$2"
    local mc_version="$3"
    local strict_mode="${4:-false}"  # true = exact MC version only
    
    if [[ "$platform" == "modrinth" ]]; then
        # Check Modrinth mod for version compatibility using same logic as check_modrinth_mod
        local api_url="https://api.modrinth.com/v2/project/$mod_id/version"
        local tmp_body
        tmp_body=$(mktemp)
        if [[ -z "$tmp_body" ]]; then
            return 1
        fi
        
        # Fetch version data from Modrinth API
        local http_code
        http_code=$(curl -s -L -w "%{http_code}" -o "$tmp_body" "$api_url")
        local version_json
        version_json=$(cat "$tmp_body")
        rm "$tmp_body"
        
        # Validate API response
        if [[ "$http_code" != "200" ]] || ! printf "%s" "$version_json" | jq -e . > /dev/null 2>&1; then
            return 1
        fi
        
        # Use the same multi-stage version matching logic as check_modrinth_mod
        local file_url=""
        
        # STAGE 1: Try exact version match with Fabric loader requirement
        file_url=$(printf "%s" "$version_json" | jq -r --arg v "$mc_version" '.[] | select(.game_versions[] == $v and (.loaders[] == "fabric")) | .files[] | select(.primary == true) | .url' 2>/dev/null | head -n1)
        
        # STAGE 2: Fallback matching if exact match failed (disabled in strict mode)
        if [[ "$strict_mode" != "true" ]] && [[ -z "$file_url" || "$file_url" == "null" ]]; then
            local mc_major_minor
            mc_major_minor=$(echo "$mc_version" | grep -oE '^[0-9]+\.[0-9]+')
            local requested_patch
            requested_patch=$(echo "$mc_version" | grep -oE '^[0-9]+\.[0-9]+\.([0-9]+)' | grep -oE '[0-9]+$')
            
            # Get all available game versions for this mod to validate fallback logic
            local all_game_versions
            all_game_versions=$(printf "%s" "$version_json" | jq -r '.[] | select(.loaders[] == "fabric") | .game_versions[]' 2>/dev/null | sort -u)
            
            # Check if any patch versions or standalone major.minor exist for this series
            local has_patch_versions=false
            local has_standalone_major_minor=false
            local highest_patch_version=0
            
            while IFS= read -r version; do
                if [[ "$version" =~ ^${mc_major_minor//./\.}\.([0-9]+)$ ]]; then
                    has_patch_versions=true
                    local patch_num="${BASH_REMATCH[1]}"
                    if [[ $patch_num -gt $highest_patch_version ]]; then
                        highest_patch_version=$patch_num
                    fi
                elif [[ "$version" == "$mc_major_minor" ]]; then
                    has_standalone_major_minor=true
                fi
            done <<< "$all_game_versions"
            
            # Apply strict fallback rules:
            # 1. If we have patch versions AND the requested patch > highest available patch, block fallback
            # 2. Only allow fallback to major.minor if no patch versions exist OR standalone major.minor exists
            local allow_fallback=true
            
            if [[ $has_patch_versions == true && -n "$requested_patch" ]]; then
                if [[ $requested_patch -gt $highest_patch_version ]]; then
                    allow_fallback=false
                fi
            fi
            
            # Only proceed with fallback if allowed
            if [[ $allow_fallback == true ]]; then
                # Try exact major.minor (e.g., "1.21")
                file_url=$(printf "%s" "$version_json" | jq -r --arg v "$mc_major_minor" '.[] | select(.game_versions[] == $v and (.loaders[] == "fabric")) | .files[] | select(.primary == true) | .url' 2>/dev/null | head -n1)
                
                # Try wildcard version format (e.g., "1.21.x") 
                if [[ -z "$file_url" || "$file_url" == "null" ]]; then
                    local mc_major_minor_x="$mc_major_minor.x"
                    file_url=$(printf "%s" "$version_json" | jq -r --arg v "$mc_major_minor_x" '.[] | select(.game_versions[] == $v and (.loaders[] == "fabric")) | .files[] | select(.primary == true) | .url' 2>/dev/null | head -n1)
                fi
                
                # Try zero-padded version format (e.g., "1.21.0")
                if [[ -z "$file_url" || "$file_url" == "null" ]]; then
                    local mc_major_minor_0="$mc_major_minor.0"
                    file_url=$(printf "%s" "$version_json" | jq -r --arg v "$mc_major_minor_0" '.[] | select(.game_versions[] == $v and (.loaders[] == "fabric")) | .files[] | select(.primary == true) | .url' 2>/dev/null | head -n1)
                fi
            fi
        fi
        
        # Return success if we found a compatible version
        if [[ -n "$file_url" && "$file_url" != "null" ]]; then
            return 0  # Compatible
        fi
        
    elif [[ "$platform" == "curseforge" ]]; then
        # Check CurseForge mod for version compatibility using same logic as check_curseforge_mod
        # First get the encrypted API token
        local token_url="https://raw.githubusercontent.com/FlyingEwok/MinecraftSplitscreenSteamdeck/main/token.enc"
        local encrypted_token_file=$(mktemp)
        
        if command -v curl >/dev/null 2>&1; then
            curl -s -L -o "$encrypted_token_file" "$token_url" 2>/dev/null
        elif command -v wget >/dev/null 2>&1; then
            wget -q -O "$encrypted_token_file" "$token_url" 2>/dev/null
        else
            rm -f "$encrypted_token_file"
            return 1
        fi
        
        # Decrypt the API token
        local fixed_passphrase="MinecraftSplitscreenSteamDeck2025"
        local cf_api_key
        cf_api_key=$(openssl enc -aes-256-cbc -d -a -pbkdf2 -pass pass:"$fixed_passphrase" -in "$encrypted_token_file" 2>/dev/null)
        rm -f "$encrypted_token_file"
        
        if [[ -z "$cf_api_key" ]]; then
            return 1  # Can't get API key
        fi
        
        # Query CurseForge API with Fabric loader filter
        local cf_api_url="https://api.curseforge.com/v1/mods/$mod_id/files?modLoaderType=4"
        local tmp_body
        tmp_body=$(mktemp)
        if [[ -z "$tmp_body" ]]; then
            return 1
        fi
        
        # Make authenticated API request
        local http_code
        http_code=$(curl -s -L -w "%{http_code}" -o "$tmp_body" -H "x-api-key: $cf_api_key" "$cf_api_url")
        local version_json
        version_json=$(cat "$tmp_body")
        rm "$tmp_body"
        
        # Validate API response
        if [[ "$http_code" != "200" ]] || ! printf "%s" "$version_json" | jq -e . > /dev/null 2>&1; then
            return 1
        fi
        
        # Version compatibility checking using same logic as check_curseforge_mod
        local mc_major_minor
        mc_major_minor=$(echo "$mc_version" | grep -oE '^[0-9]+\.[0-9]+')
        local mc_major_minor_x="$mc_major_minor.x"
        local mc_major_minor_0="$mc_major_minor.0"
        
        # CurseForge-specific jq filter for version matching
        local jq_filter
        if [[ "$strict_mode" == "true" ]]; then
            jq_filter='
                .data[]
                | select(.gameVersions[] == $mc_version)
                | .downloadUrl
            '
        else
            jq_filter='
                .data[]
                | select(
                    ((.gameVersions[] == $mc_version) or
                    (.gameVersions[] == $mc_major_minor) or
                    (.gameVersions[] == $mc_major_minor_x) or
                    (.gameVersions[] == $mc_major_minor_0))
                  )
                | .downloadUrl
            '
        fi
        
        local jq_result
        jq_result=$(printf "%s" "$version_json" | jq -r \
            --arg mc_version "$mc_version" \
            --arg mc_major_minor "$mc_major_minor" \
            --arg mc_major_minor_x "$mc_major_minor_x" \
            --arg mc_major_minor_0 "$mc_major_minor_0" \
            "$jq_filter" 2>/dev/null | head -n1)
        
        # Return success if we found a compatible version
        if [[ -n "$jq_result" && "$jq_result" != "null" ]]; then
            return 0  # Compatible
        fi
    fi
    
    return 1  # Not compatible
}

# Add fallback dependencies for critical mods when API calls fail
fallback_dependencies() {
    local mod_id="$1"
    local platform="$2"
    
    case "$platform:$mod_id" in
        "modrinth:P7dR8mSH")  # Fabric API
            echo ""
            ;;
        "modrinth:yJgqfSDR")  # Splitscreen Support
            echo "P7dR8mSH" # Fabric API
            ;;
        "curseforge:317269")  # Controllable
            echo "634179"  # Framework
            ;;
        *)
            echo ""
            ;;
    esac
}

# get_minecraft_version: Get target Minecraft version with intelligent compatibility checking
# Only offers versions that support both Controllable and Splitscreen Support mods
get_minecraft_version() {
    # If MC_VERSION already set (e.g. by modpack detection), skip the picker
    if [[ -n "${MC_VERSION:-}" ]]; then
        echo ""
        print_info "Minecraft version already selected: $MC_VERSION"
        echo ""
        return 0
    fi
    
    print_header "🎯 MINECRAFT VERSION SELECTION"
    
    # Get list of supported Minecraft versions
    local -a supported_versions
    readarray -t supported_versions <<< "$(get_supported_minecraft_versions)"
    
    # Filter out any empty entries
    local -a clean_versions=()
    for version in "${supported_versions[@]}"; do
        if [[ -n "$version" && "$version" != "null" ]]; then
            clean_versions+=("$version")
        fi
    done
    supported_versions=("${clean_versions[@]}")
    
    if [[ ${#supported_versions[@]} -eq 0 ]]; then
        print_error "Could not determine supported Minecraft versions. Please check your internet connection and try again."
        return 1
    fi
    
    # Display supported versions to user
    if [[ -n "${EXTRA_REQUIRED_MOD_ID:-}" && -n "${EXTRA_REQUIRED_MOD_PLATFORM:-}" ]]; then
        echo "🎮 Available Minecraft versions (core mods + ${EXTRA_REQUIRED_MOD_NAME:-custom mod} support):"
    else
        echo "🎮 Available Minecraft versions (with full splitscreen mod support):"
    fi
    
    local counter=1
    for version in "${supported_versions[@]}"; do
        if [[ $counter -le 10 ]]; then  # Show top 10 most recent supported versions
            echo "  $counter. Minecraft $version"
            ((counter++))
        fi
    done
    
    echo "These versions have been verified to support both essential splitscreen mods:"
    echo "  ✅ Controllable (controller support)"  
    echo "  ✅ Splitscreen Support (split-screen functionality)"
    if [[ -n "${EXTRA_REQUIRED_MOD_ID:-}" && -n "${EXTRA_REQUIRED_MOD_PLATFORM:-}" ]]; then
        echo "  ✅ ${EXTRA_REQUIRED_MOD_NAME:-Requested custom mod}"
    fi
    
    # Get user choice
    local latest_supported="${supported_versions[0]}"
    echo "Enter your choice:"
    echo "  1-${#supported_versions[@]} = Select a specific version from the list above"
    echo "  [Enter] = Use latest supported version ($latest_supported) [RECOMMENDED]"
    
    local user_choice
    read -p "Your choice [latest]: " user_choice
    
    if [[ -z "$user_choice" || "$user_choice" == "latest" ]]; then
        # Use latest supported version
        MC_VERSION="$latest_supported"
        print_success "Using latest supported version: $MC_VERSION"
        
    elif [[ "$user_choice" =~ ^[0-9]+$ ]] && [[ $user_choice -ge 1 && $user_choice -le ${#supported_versions[@]} ]]; then
        # User selected a number from the list
        local selected_index=$((user_choice - 1))
        MC_VERSION="${supported_versions[$selected_index]}"
        print_success "Using selected version: $MC_VERSION"
        
    else
        # Invalid input, use latest supported
        print_warning "Invalid choice, using latest supported version: $latest_supported"
        MC_VERSION="$latest_supported"
    fi
    print_info "Selected Minecraft version: $MC_VERSION"
}

# get_fabric_version: Fetch the latest Fabric loader version from official API
# Fabric loader provides the mod loading framework for Minecraft
get_fabric_version() {
    print_progress "Detecting latest Fabric loader version..."
    
    # Query Fabric Meta API for the latest loader version
    FABRIC_VERSION=$(curl -s "https://meta.fabricmc.net/v2/versions/loader" | jq -r '.[0].version' 2>/dev/null)
    
    # Fallback to known stable version if API call fails
    if [[ -z "$FABRIC_VERSION" || "$FABRIC_VERSION" == "null" ]]; then
        print_warning "Could not detect latest Fabric version, using fallback"
        FABRIC_VERSION="0.16.9"  # Known stable version that works with most mods
    fi
    
    print_success "Using Fabric loader version: $FABRIC_VERSION"
}
