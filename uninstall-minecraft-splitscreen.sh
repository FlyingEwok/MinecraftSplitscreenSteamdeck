#!/bin/bash
# =============================================================================
# Minecraft Splitscreen Steam Deck & Linux Uninstaller
# =============================================================================

set -euo pipefail

DRY_RUN=false
ASSUME_YES=false
KEEP_DATA=false
MODE_EXPLICIT=false

FULL_TARGETS=(
    "$HOME/.local/share/PolyMC"
    "$HOME/.local/share/PrismLauncher"
    "$HOME/Desktop/MinecraftSplitscreen.desktop"
    "$HOME/.local/share/applications/MinecraftSplitscreen.desktop"
)

KEEP_DATA_TARGETS=(
    "$HOME/.local/share/PolyMC/PolyMC.AppImage"
    "$HOME/.local/share/PolyMC/minecraftSplitscreen.sh"
    "$HOME/.local/share/PolyMC/live.check"
    "$HOME/.local/share/PolyMC/PolyMC-*.log"
    "$HOME/.local/share/PrismLauncher/PrismLauncher.AppImage"
    "$HOME/.local/share/PrismLauncher/minecraftSplitscreen.sh"
    "$HOME/Desktop/MinecraftSplitscreen.desktop"
    "$HOME/.local/share/applications/MinecraftSplitscreen.desktop"
)

print_header() {
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

print_info() {
    echo "ℹ️  $1"
}

print_success() {
    echo "✅ $1"
}

print_warning() {
    echo "⚠️  $1"
}

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --yes         Skip confirmation prompts
  --dry-run     Show what would be removed (does not delete anything)
  --keep-data   Keep worlds/saves/accounts, remove launcher files and shortcuts
  --help        Show this help message
EOF
}

for arg in "$@"; do
    case "$arg" in
        --yes) ASSUME_YES=true ;;
        --dry-run) DRY_RUN=true ;;
        --keep-data)
            KEEP_DATA=true
            MODE_EXPLICIT=true
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            usage
            exit 1
            ;;
    esac
done

# If mode was not provided by flags, ask user whether to keep data.
if [[ "$MODE_EXPLICIT" != true ]]; then
    echo "Do you want to keep your Minecraft worlds, saves, and accounts?"
    echo "  y = Keep my data (recommended)"
    echo "  n = Remove everything"
    read -r -p "Keep my data? [Y/n]: " keep_choice
    if [[ "$keep_choice" =~ ^[Nn]$ ]]; then
        KEEP_DATA=false
    else
        KEEP_DATA=true
    fi
fi

print_header "🎮 MINECRAFT SPLITSCREEN UNINSTALLER"
if [[ "$KEEP_DATA" == true ]]; then
    print_info "Keep-data mode: removing launchers and shortcuts, preserving instances/worlds/accounts."
else
    print_info "Full uninstall mode: removing Minecraft Splitscreen launcher data and shortcuts."
fi
echo ""

echo "Targets:"
if [[ "$KEEP_DATA" == true ]]; then
    for path in "${KEEP_DATA_TARGETS[@]}"; do
        echo "  - $path"
    done
else
    for path in "${FULL_TARGETS[@]}"; do
        echo "  - $path"
    done
fi
echo ""

if [[ "$KEEP_DATA" == true ]]; then
    print_info "Data under ~/.local/share/PolyMC/instances and ~/.local/share/PolyMC/accounts.json will be preserved."
else
    print_warning "This can remove your local instances, mods, and worlds in PolyMC/PrismLauncher."
fi
print_info "Steam library shortcuts are not edited automatically."
print_info "If needed, remove the Steam shortcut manually from Steam."
echo ""

if [[ "$ASSUME_YES" != true ]]; then
    read -r -p "Are you sure you want to continue? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "No changes made."
        exit 0
    fi
fi

removed_count=0
missing_count=0

remove_path() {
    local path="$1"
    if [[ "$path" == *"*"* ]]; then
        local matches=()
        while IFS= read -r m; do
            matches+=("$m")
        done < <(compgen -G "$path" || true)

        if [[ ${#matches[@]} -eq 0 ]]; then
            print_info "Not found (skipped): $path"
            ((missing_count+=1))
            return
        fi

        for m in "${matches[@]}"; do
            if [[ "$DRY_RUN" == true ]]; then
                print_info "[dry-run] Would remove: $m"
            else
                rm -rf "$m"
                print_success "Removed: $m"
            fi
            ((removed_count+=1))
        done
        return
    fi

    if [[ -e "$path" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            print_info "[dry-run] Would remove: $path"
        else
            rm -rf "$path"
            print_success "Removed: $path"
        fi
        ((removed_count+=1))
    else
        print_info "Not found (skipped): $path"
        ((missing_count+=1))
    fi
}

if [[ "$KEEP_DATA" == true ]]; then
    for path in "${KEEP_DATA_TARGETS[@]}"; do
        remove_path "$path"
    done
else
    for path in "${FULL_TARGETS[@]}"; do
        remove_path "$path"
    done
fi

echo ""
if [[ "$DRY_RUN" == true ]]; then
    print_success "Dry run complete."
else
    print_success "Uninstall complete."
fi
print_info "Removed: $removed_count"
print_info "Skipped (missing): $missing_count"
