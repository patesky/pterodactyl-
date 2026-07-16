#!/usr/bin/env bash
# ==============================================================
# king-installer.sh — King Installer Main Entry Point
# ==============================================================
# USAGE:
#   sudo bash king-installer.sh
#
# SETUP:
#   1. Edit lib/config.sh — set GH_USER and GH_REPO
#   2. Push scripts/ folder to your GitHub repository
#   3. Run this script as root
# ==============================================================

set -euo pipefail

# ── Resolve script directory (works with symlinks) ────────────
KING_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
export KING_DIR

# ── Source library modules ────────────────────────────────────
source "${KING_DIR}/lib/config.sh"
source "${KING_DIR}/lib/ui.sh"
source "${KING_DIR}/lib/logger.sh"
source "${KING_DIR}/lib/system.sh"
source "${KING_DIR}/lib/downloader.sh"

# Export all functions so downloaded sub-scripts can use them
export -f ui::clear ui::banner ui::section ui::subsection ui::divider
export -f ui::ok ui::fail ui::warn ui::info ui::step
export -f ui::status ui::check_item ui::bullet ui::arrow
export -f ui::summary_row ui::menu_item ui::menu_exit ui::menu_choice
export -f ui::prompt ui::prompt_secret ui::prompt_yn ui::confirm_word
export -f ui::progress_bar ui::spinner_start ui::spinner_stop
export -f ui::pause ui::press_any ui::repeat ui::center
export -f log::info log::ok log::warn log::error log::section
export -f logger::init logger::run logger::run_quiet
export -f sys::detect_os sys::require_root sys::check_internet
export -f sys::check_os sys::pkg_installed sys::cmd_exists
export -f sys::install_pkg sys::pkg_update sys::detect_php
export -f sys::gen_password sys::print_os_info
export -f dl::file dl::get_version dl::run_module dl::check_repo
export KING_DIR APP_NAME APP_VERSION
export GH_USER GH_REPO GH_BRANCH GH_RAW GH_API SCRIPTS_PATH
export LOG_DIR LOG_FILE TEMP_DIR
export PANEL_DIR PANEL_DB PANEL_DB_USER
export WINGS_DIR WINGS_BIN WINGS_SERVICE
export RESET BOLD DIM
export BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE
export BRIGHT_RED BRIGHT_GREEN BRIGHT_YELLOW BRIGHT_BLUE
export BRIGHT_MAGENTA BRIGHT_CYAN BRIGHT_WHITE
export SYM_OK SYM_FAIL SYM_WARN SYM_INFO SYM_ARROW
export SYM_BULLET SYM_GEAR SYM_STAR
export TERM_WIDTH INNER_W

# ── Pre-flight ────────────────────────────────────────────────
sys::detect_os
sys::require_root

mkdir -p "$TEMP_DIR" "$LOG_DIR"
logger::init

# ── Trap for cleanup on exit ──────────────────────────────────
_cleanup() {
    # Kill any stray spinner
    [[ -n "${_SPINNER_PID:-}" ]] && kill "$_SPINNER_PID" 2>/dev/null || true
    # Clean temp dir
    rm -rf "${TEMP_DIR:?}"/* 2>/dev/null || true
    # Restore cursor
    tput cnorm 2>/dev/null || true
}
trap _cleanup EXIT INT TERM

# Hide cursor during menus for cleaner look
tput civis 2>/dev/null || true

# ==============================================================
# Connectivity Check (once at startup)
# ==============================================================
ui::clear
ui::banner

if ! sys::check_internet; then
    echo
    ui::fail "Aborting — no internet connection."
    log::error "ABORT: no internet"
    echo
    exit 1
fi

dl::check_repo
sleep 1

# ==============================================================
# ── MAIN MENU ────────────────────────────────────────────────
# ==============================================================
main_menu() {
    while true; do
        ui::clear
        ui::banner

        echo -e "  ${BOLD}${BRIGHT_MAGENTA}Main Menu${RESET}"
        echo
        ui::menu_item "1" "Pterodactyl Panel"
        ui::menu_item "2" "Wings"
        ui::menu_exit "Exit"

        ui::menu_choice CHOICE

        case "$CHOICE" in
            1) menu_pterodactyl ;;
            2) menu_wings       ;;
            0) _exit_app        ;;
            *)
                tput cnorm 2>/dev/null || true
                ui::warn "Invalid option — please choose 1, 2, or 0."
                sleep 1
                ;;
        esac
    done
}

# ==============================================================
# ── PTERODACTYL MENU ─────────────────────────────────────────
# ==============================================================
menu_pterodactyl() {
    while true; do
        ui::clear
        ui::banner
        ui::section "PTERODACTYL PANEL"

        ui::menu_item "1" "Install Panel"
        ui::menu_item "2" "Update Panel"
        ui::menu_item "3" "Delete Panel"
        ui::menu_exit "Back to Main Menu"

        ui::menu_choice CHOICE

        case "$CHOICE" in
            1)
                log::section "USER: Pterodactyl → Install"
                tput cnorm 2>/dev/null || true
                _run_module_screen "pterodactyl/install"
                tput civis 2>/dev/null || true
                ;;
            2)
                log::section "USER: Pterodactyl → Update"
                tput cnorm 2>/dev/null || true
                _run_module_screen "pterodactyl/update"
                tput civis 2>/dev/null || true
                ;;
            3)
                log::section "USER: Pterodactyl → Delete"
                tput cnorm 2>/dev/null || true
                _run_module_screen "pterodactyl/delete"
                tput civis 2>/dev/null || true
                ;;
            0) return ;;
            *)
                ui::warn "Invalid option."
                sleep 1
                ;;
        esac
    done
}

# ==============================================================
# ── WINGS MENU ───────────────────────────────────────────────
# ==============================================================
menu_wings() {
    while true; do
        ui::clear
        ui::banner
        ui::section "WINGS"

        ui::menu_item "1" "Install Wings"
        ui::menu_item "2" "Update Wings"
        ui::menu_item "3" "Delete Wings"
        ui::menu_exit "Back to Main Menu"

        ui::menu_choice CHOICE

        case "$CHOICE" in
            1)
                log::section "USER: Wings → Install"
                tput cnorm 2>/dev/null || true
                _run_module_screen "wings/install"
                tput civis 2>/dev/null || true
                ;;
            2)
                log::section "USER: Wings → Update"
                tput cnorm 2>/dev/null || true
                _run_module_screen "wings/update"
                tput civis 2>/dev/null || true
                ;;
            3)
                log::section "USER: Wings → Delete"
                tput cnorm 2>/dev/null || true
                _run_module_screen "wings/delete"
                tput civis 2>/dev/null || true
                ;;
            0) return ;;
            *)
                ui::warn "Invalid option."
                sleep 1
                ;;
        esac
    done
}

# ==============================================================
# ── Helpers ───────────────────────────────────────────────────
# ==============================================================

# Run a downloaded module, show header, return to menu after
_run_module_screen() {
    local module="$1"
    ui::clear
    ui::banner

    # Decide: use local scripts/ if available (dev mode),
    # otherwise download from GitHub.
    local local_script="${KING_DIR}/scripts/${module}.sh"
    if [[ -f "$local_script" ]]; then
        log::info "Running LOCAL script: $local_script"
        ui::info "Running local script: ${DIM}${local_script}${RESET}"
        echo
        ui::divider
        bash "$local_script"
        local rc=$?
        echo
        ui::divider
        if [[ $rc -eq 0 ]]; then
            ui::ok "Script completed successfully."
        else
            ui::warn "Script exited with code ${rc}."
        fi
        log::info "Script exit code: $rc"
    else
        # Download from GitHub
        dl::run_module "$module"
    fi
}

# Graceful exit screen
_exit_app() {
    tput cnorm 2>/dev/null || true
    ui::clear
    ui::banner
    echo
    ui::center "${BRIGHT_CYAN}Thank you for using ${BOLD}King Installer${RESET}"
    ui::center "${DIM}Goodbye.${RESET}"
    echo
    log::section "SESSION END"
    log::info "Log saved to: ${LOG_FILE}"
    sleep 1
    exit 0
}

# ==============================================================
# ── Launch ────────────────────────────────────────────────────
# ==============================================================
main_menu
