#!/usr/bin/env bash
# uninstall-xui.sh — one-click uninstaller for x-ui / 3x-ui / xray-ui
#
# Usage:
#   sudo bash uninstall-xui.sh [--dry-run] [--yes] [--keep-unit-files] [--log <file>]
#
# Options:
#   --dry-run          Show what would be done without making any changes
#   --yes              Skip confirmation prompts (non-interactive mode)
#   --keep-unit-files  Do NOT remove systemd unit files from /etc/systemd/system/
#   --log <file>       Append log output to <file> (default: /var/log/uninstall-xui.log)
#
# WARNING: This script is destructive. It permanently removes services,
# Docker containers/images and directories related to x-ui / 3x-ui.
# Always run with --dry-run first to review what will be removed.

set -euo pipefail

# ── constants ──────────────────────────────────────────────────────────────────
SCRIPT_VERSION="1.0.0"
DEFAULT_LOG="/var/log/uninstall-xui.log"

KNOWN_SERVICE_NAMES=(x-ui 3x-ui xray-ui)
KNOWN_INSTALL_DIRS=(
    /usr/local/x-ui
    /usr/local/3x-ui
    /etc/x-ui
    /etc/3x-ui
    /opt/x-ui
    /opt/3x-ui
)

# ── option parsing ─────────────────────────────────────────────────────────────
DRY_RUN=false
AUTO_YES=false
KEEP_UNIT_FILES=false
LOG_FILE="$DEFAULT_LOG"

usage() {
    awk '/^# Usage:/{f=1} f && /^[^#]/{exit} f{sub(/^# ?/,""); print}' "$0"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)         DRY_RUN=true ;;
        --yes|-y)          AUTO_YES=true ;;
        --keep-unit-files) KEEP_UNIT_FILES=true ;;
        --log)             shift; LOG_FILE="$1" ;;
        --help|-h)         usage ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run with --help for usage." >&2
            exit 1
            ;;
    esac
    shift
done

# ── logging ────────────────────────────────────────────────────────────────────
# Write to stdout and optionally to a log file (only when NOT dry-run, to avoid
# creating files unexpectedly; the log path is shown in dry-run mode).
log() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    local line="[$ts] [$level] $msg"
    echo "$line"
    if [[ "$DRY_RUN" == false ]]; then
        # Best-effort: ignore failures if the log directory is not writable
        echo "$line" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

info()    { log "INFO " "$@"; }
warn()    { log "WARN " "$@" >&2; }
success() { log "OK   " "$@"; }
dryrun()  { log "DRY  " "[DRY-RUN] $*"; }
action()  {
    if [[ "$DRY_RUN" == true ]]; then
        dryrun "$@"
    else
        info "$@"
    fi
}

# ── privilege check ────────────────────────────────────────────────────────────
require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "Error: This script must be run as root (use sudo)." >&2
        exit 1
    fi
}

# ── helper: run or simulate a command ─────────────────────────────────────────
run() {
    if [[ "$DRY_RUN" == true ]]; then
        dryrun "would run: $*"
    else
        "$@"
    fi
}

# ── discovery functions ────────────────────────────────────────────────────────
find_active_services() {
    local found=()
    for name in "${KNOWN_SERVICE_NAMES[@]}"; do
        if systemctl list-unit-files --no-legend 2>/dev/null | grep -qE "^${name}\.service"; then
            found+=("$name")
        fi
    done
    echo "${found[@]+"${found[@]}"}"
}

find_unit_files() {
    local found=()
    for name in "${KNOWN_SERVICE_NAMES[@]}"; do
        for dir in /etc/systemd/system /lib/systemd/system /usr/lib/systemd/system; do
            local f="$dir/${name}.service"
            [[ -f "$f" ]] && found+=("$f")
        done
    done
    echo "${found[@]+"${found[@]}"}"
}

find_docker_containers() {
    command -v docker &>/dev/null || return 0
    local found=()
    for name in "${KNOWN_SERVICE_NAMES[@]}"; do
        # match containers whose name equals or starts with the pattern
        local ids
        ids=$(docker ps -a --format '{{.Names}}\t{{.ID}}' 2>/dev/null \
              | grep -E "^(${name}[[:space:]])" \
              | awk '{print $2}') || true
        [[ -n "$ids" ]] && found+=($ids)
    done
    echo "${found[@]+"${found[@]}"}"
}

find_docker_images() {
    command -v docker &>/dev/null || return 0
    local found=()
    for name in "${KNOWN_SERVICE_NAMES[@]}"; do
        local ids
        ids=$(docker images --format '{{.Repository}}\t{{.ID}}' 2>/dev/null \
              | grep -E "^(${name}[[:space:]])" \
              | awk '{print $2}') || true
        [[ -n "$ids" ]] && found+=($ids)
    done
    echo "${found[@]+"${found[@]}"}"
}

find_install_dirs() {
    local found=()
    for d in "${KNOWN_INSTALL_DIRS[@]}"; do
        [[ -d "$d" ]] && found+=("$d")
    done
    echo "${found[@]+"${found[@]}"}"
}

# ── preview ────────────────────────────────────────────────────────────────────
print_preview() {
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  x-ui / 3x-ui / xray-ui  —  Uninstaller v${SCRIPT_VERSION}"
    echo "════════════════════════════════════════════════════════════"
    [[ "$DRY_RUN" == true ]] && echo "  *** DRY-RUN MODE — no changes will be made ***"
    echo ""

    echo "Systemd services detected:"
    local svc_list
    svc_list=$(find_active_services)
    if [[ -z "$svc_list" ]]; then
        echo "  (none)"
    else
        for s in $svc_list; do
            echo "  • $s"
        done
    fi

    if [[ "$KEEP_UNIT_FILES" == false ]]; then
        echo ""
        echo "Systemd unit files to remove:"
        local unit_list
        unit_list=$(find_unit_files)
        if [[ -z "$unit_list" ]]; then
            echo "  (none)"
        else
            for f in $unit_list; do
                echo "  • $f"
            done
        fi
    fi

    if command -v docker &>/dev/null; then
        echo ""
        echo "Docker containers to remove:"
        local ct_list
        ct_list=$(find_docker_containers)
        if [[ -z "$ct_list" ]]; then
            echo "  (none)"
        else
            for c in $ct_list; do
                echo "  • container $c"
            done
        fi

        echo ""
        echo "Docker images to remove:"
        local img_list
        img_list=$(find_docker_images)
        if [[ -z "$img_list" ]]; then
            echo "  (none)"
        else
            for i in $img_list; do
                echo "  • image $i"
            done
        fi
    fi

    echo ""
    echo "Directories to remove:"
    local dir_list
    dir_list=$(find_install_dirs)
    if [[ -z "$dir_list" ]]; then
        echo "  (none)"
    else
        for d in $dir_list; do
            echo "  • $d"
        done
    fi

    if [[ "$DRY_RUN" == false ]]; then
        echo ""
        echo "Actions will be logged to: $LOG_FILE"
    fi
    echo ""
}

# ── confirmation prompt ────────────────────────────────────────────────────────
confirm() {
    if [[ "$AUTO_YES" == true ]]; then
        return 0
    fi
    read -r -p "Proceed with uninstallation? [y/N] " answer
    case "$answer" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) echo "Aborted."; exit 0 ;;
    esac
}

# ── uninstall steps ────────────────────────────────────────────────────────────
stop_and_disable_services() {
    local svc_list
    svc_list=$(find_active_services)
    [[ -z "$svc_list" ]] && return 0

    for name in $svc_list; do
        action "Stopping service: $name"
        run systemctl stop "$name" 2>/dev/null || true

        action "Disabling service: $name"
        run systemctl disable "$name" 2>/dev/null || true
    done
}

remove_unit_files() {
    [[ "$KEEP_UNIT_FILES" == true ]] && return 0

    local unit_list
    unit_list=$(find_unit_files)
    [[ -z "$unit_list" ]] && return 0

    for f in $unit_list; do
        action "Removing unit file: $f"
        run rm -f "$f"
    done

    action "Reloading systemd daemon"
    run systemctl daemon-reload 2>/dev/null || true
}

remove_docker_containers() {
    command -v docker &>/dev/null || return 0

    local ct_list
    ct_list=$(find_docker_containers)
    [[ -z "$ct_list" ]] && return 0

    for id in $ct_list; do
        action "Stopping Docker container: $id"
        run docker stop "$id" 2>/dev/null || true

        action "Removing Docker container: $id"
        run docker rm -f "$id" 2>/dev/null || true
    done
}

remove_docker_images() {
    command -v docker &>/dev/null || return 0

    local img_list
    img_list=$(find_docker_images)
    [[ -z "$img_list" ]] && return 0

    for id in $img_list; do
        action "Removing Docker image: $id"
        run docker rmi -f "$id" 2>/dev/null || true
    done
}

remove_install_dirs() {
    local dir_list
    dir_list=$(find_install_dirs)
    [[ -z "$dir_list" ]] && return 0

    for d in $dir_list; do
        action "Removing directory: $d"
        run rm -rf "$d"
    done
}

# ── main ───────────────────────────────────────────────────────────────────────
main() {
    require_root

    print_preview

    if [[ "$DRY_RUN" == true ]]; then
        info "Dry-run complete. No changes were made."
        exit 0
    fi

    confirm

    info "Starting uninstallation — logging to $LOG_FILE"

    stop_and_disable_services
    remove_unit_files
    remove_docker_containers
    remove_docker_images
    remove_install_dirs

    success "Uninstallation complete."
    info "If residual files remain, inspect $LOG_FILE for details."
}

main "$@"
