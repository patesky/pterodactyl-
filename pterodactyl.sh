#!/bin/bash
# ===========================================================================
#   KING KOM — Pterodactyl Installer Wrapper
#   Powered by: https://pterodactyl-installer.se
# ===========================================================================
set -euo pipefail

# ── Terminal colours ────────────────────────────────────────────────────────
RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"

BLACK="\e[30m"
RED="\e[91m"
GREEN="\e[92m"
YELLOW="\e[93m"
BLUE="\e[94m"
MAGENTA="\e[95m"
CYAN="\e[96m"
WHITE="\e[97m"

BG_BLACK="\e[40m"
BG_GOLD="\e[48;5;214m"
BG_DARK="\e[48;5;235m"
BG_DARKBLUE="\e[48;5;17m"

GOLD="\e[38;5;214m"
ORANGE="\e[38;5;208m"
DARK_GOLD="\e[38;5;136m"

# ── Helpers ─────────────────────────────────────────────────────────────────
_width=72

_line() {
    local char="${1:-─}" color="${2:-$DIM}"
    printf "${color}"
    printf '%*s' "$_width" '' | tr ' ' "$char"
    printf "${RESET}\n"
}

_center() {
    local text="$1" color="${2:-$WHITE}"
    # strip ANSI for length calculation
    local plain
    plain=$(printf '%s' "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#plain}
    local pad=$(( (_width - len) / 2 ))
    printf "%${pad}s${color}%s${RESET}\n" "" "$text"
}

_banner_line() {
    printf "${BG_BLACK}${GOLD}${BOLD}  %-*s  ${RESET}\n" "$((_width - 4))" "$1"
}

clear

# ── KING KOM watermark banner ───────────────────────────────────────────────
echo
printf "${BG_BLACK}"
printf '%*s' "$((_width + 4))" '' | tr ' ' ' '
printf "${RESET}\n"

_line "═" "${GOLD}"
printf "${GOLD}${BOLD}"
echo '  ██╗  ██╗██╗███╗   ██╗ ██████╗     ██╗  ██╗ ██████╗ ███╗   ███╗  '
echo '  ██║ ██╔╝██║████╗  ██║██╔════╝     ██║ ██╔╝██╔═══██╗████╗ ████║  '
echo '  █████╔╝ ██║██╔██╗ ██║██║  ███╗    █████╔╝ ██║   ██║██╔████╔██║  '
echo '  ██╔═██╗ ██║██║╚██╗██║██║   ██║    ██╔═██╗ ██║   ██║██║╚██╔╝██║  '
echo '  ██║  ██╗██║██║ ╚████║╚██████╔╝    ██║  ██╗╚██████╔╝██║ ╚═╝ ██║  '
echo '  ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝  '
printf "${RESET}"
_line "═" "${GOLD}"

echo
_center "✦  P T E R O D A C T Y L   I N S T A L L E R  ✦" "${BOLD}${GOLD}"
_center "Official installer by pterodactyl-installer.se" "${DIM}${CYAN}"
echo
_line "─" "${DIM}"
_center "🔥  Powered & Styled by  ${BOLD}${GOLD}KING KOM${RESET}${DIM}  🔥" "${DIM}"
_line "─" "${DIM}"
echo

# ── System info ─────────────────────────────────────────────────────────────
OS_LABEL="Unknown"
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    OS_LABEL="${NAME} ${VERSION_ID:-}"
fi

printf "  ${DIM}System :${RESET}  ${CYAN}${BOLD}%s${RESET}\n"   "$OS_LABEL"
printf "  ${DIM}Kernel :${RESET}  ${CYAN}%s${RESET}\n"           "$(uname -r)"
printf "  ${DIM}Host   :${RESET}  ${CYAN}%s${RESET}\n"           "$(hostname -f 2>/dev/null || hostname)"
echo
_line "─" "${DIM}"
echo

# ── Menu ────────────────────────────────────────────────────────────────────
printf "  ${BOLD}${GOLD}SELECT AN OPTION${RESET}\n\n"

menu_item() {
    local num="$1" label="$2" desc="$3"
    printf "  ${BG_DARK} ${BOLD}${GOLD} %s ${RESET}${BG_DARK}  ${WHITE}%-28s${RESET}  ${DIM}%s${RESET}\n" \
        "$num" "$label" "$desc"
}

menu_item "0" "Install Panel"        "Pterodactyl web panel"
menu_item "1" "Install Wings"        "Daemon / node agent"
menu_item "2" "Install Both"         "Panel + Wings on same machine"
echo
_line "─" "${DIM}"
menu_item "3" "Panel (canary)"       "Latest dev build — may be broken"
menu_item "4" "Wings (canary)"       "Latest dev build — may be broken"
menu_item "5" "Both  (canary)"       "Panel + Wings dev builds"
echo
_line "─" "${DIM}"
menu_item "6" "Uninstall"            "Remove panel or Wings"
echo
_line "─" "${DIM}"
echo

# ── Input ────────────────────────────────────────────────────────────────────
while true; do
    printf "  ${BOLD}${GOLD}➤ ${RESET}${BOLD}Enter option [0-6]: ${RESET}"
    read -r CHOICE

    case "$CHOICE" in
        0|1|2|3|4|5|6) break ;;
        *)
            printf "  ${RED}✗  Invalid option. Please enter a number from 0 to 6.${RESET}\n"
            ;;
    esac
done

# ── Confirmation ─────────────────────────────────────────────────────────────
echo
_line "─" "${DIM}"

LABELS=("Install Panel" "Install Wings" "Install Both (Panel + Wings)"
        "Install Panel (canary)" "Install Wings (canary)"
        "Install Both (canary)" "Uninstall")

printf "\n  ${BOLD}${WHITE}You selected:${RESET}  ${BOLD}${GOLD}${LABELS[$CHOICE]}${RESET}\n\n"

printf "  ${BOLD}${YELLOW}➤ Confirm? [Y/n]: ${RESET}"
read -r CONFIRM
CONFIRM="${CONFIRM:-Y}"
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo
    printf "  ${DIM}Cancelled. Exiting.${RESET}\n\n"
    exit 0
fi

# ── Launch official installer ─────────────────────────────────────────────────
echo
_line "═" "${GOLD}"
_center "🚀  Launching Official Pterodactyl Installer  🚀" "${BOLD}${CYAN}"
_center "https://pterodactyl-installer.se" "${DIM}"
_line "═" "${GOLD}"
echo
printf "  ${DIM}Installer log: /var/log/pterodactyl-installer.log${RESET}\n"
echo

# Check curl is available
if ! command -v curl &>/dev/null; then
    printf "  ${RED}${BOLD}✗  curl is not installed. Install it first:${RESET}\n"
    printf "  ${DIM}apt install curl   OR   yum install curl${RESET}\n\n"
    exit 1
fi

# The official installer reads the menu choice from stdin.
# For option 2 (panel+wings) it also asks "proceed to wings?" — answer Y automatically.
# For option 5 (both canary) same applies.
if [[ "$CHOICE" == "2" || "$CHOICE" == "5" ]]; then
    # Send choice + "Y" to auto-confirm the wings follow-up question
    printf '%s\nY\n' "$CHOICE" | bash <(curl -s https://pterodactyl-installer.se)
else
    printf '%s\n' "$CHOICE" | bash <(curl -s https://pterodactyl-installer.se)
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo
_line "═" "${GOLD}"
_center "✅  Done! — ${BOLD}KING KOM${RESET}${GOLD} Installer Complete" "${BOLD}${GOLD}"
_line "═" "${GOLD}"
echo
