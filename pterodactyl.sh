#!/bin/bash
# ===========================================================================
#   KING KOM — Pterodactyl Installer
# ===========================================================================
set -euo pipefail

# ── Terminal colours ────────────────────────────────────────────────────────
RESET=$'\e[0m'
BOLD=$'\e[1m'
DIM=$'\e[2m'

RED=$'\e[91m'
GREEN=$'\e[92m'
YELLOW=$'\e[93m'
CYAN=$'\e[96m'
WHITE=$'\e[97m'

BG_BLACK=$'\e[40m'
BG_DARK=$'\e[48;5;235m'

GOLD=$'\e[38;5;214m'

# ── Helpers ─────────────────────────────────────────────────────────────────
W=72

_line() {
    local char="${1:-─}" clr="${2:-$DIM}"
    printf "${clr}"; printf '%*s' "$W" '' | tr ' ' "$char"; printf "${RESET}\n"
}

_center() {
    local raw="$1" clr="${2:-$WHITE}"
    local plain; plain=$(printf '%s' "$raw" | sed 's/\x1b\[[0-9;]*m//g; s/\\e\[[0-9;]*m//g')
    local pad=$(( (W - ${#plain}) / 2 ))
    printf "%${pad}s${clr}${raw}${RESET}\n" ""
}

# ── Clear + KING KOM Banner ─────────────────────────────────────────────────
clear
echo
_line "═" "${GOLD}"
printf "${GOLD}${BOLD}"
cat << 'BANNER'
  ██╗  ██╗██╗███╗   ██╗ ██████╗     ██╗  ██╗ ██████╗ ███╗   ███╗
  ██║ ██╔╝██║████╗  ██║██╔════╝     ██║ ██╔╝██╔═══██╗████╗ ████║
  █████╔╝ ██║██╔██╗ ██║██║  ███╗    █████╔╝ ██║   ██║██╔████╔██║
  ██╔═██╗ ██║██║╚██╗██║██║   ██║    ██╔═██╗ ██║   ██║██║╚██╔╝██║
  ██║  ██╗██║██║ ╚████║╚██████╔╝    ██║  ██╗╚██████╔╝██║ ╚═╝ ██║
  ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝
BANNER
printf "${RESET}"
_line "═" "${GOLD}"
echo
_center "✦  P T E R O D A C T Y L   I N S T A L L E R  ✦" "${BOLD}${GOLD}"
echo
_line "─" "${DIM}"
echo

# ── System info ─────────────────────────────────────────────────────────────
OS_LABEL="Unknown"
if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    OS_LABEL="${NAME} ${VERSION_ID:-}"
fi
printf "  ${DIM}System :${RESET}  ${CYAN}${BOLD}%s${RESET}\n" "$OS_LABEL"
printf "  ${DIM}Kernel :${RESET}  ${CYAN}%s${RESET}\n"        "$(uname -r)"
printf "  ${DIM}Host   :${RESET}  ${CYAN}%s${RESET}\n"        "$(hostname -f 2>/dev/null || hostname)"
echo
_line "─" "${DIM}"
echo

# ── Menu ─────────────────────────────────────────────────────────────────────
printf "  ${BOLD}${GOLD}SELECT AN OPTION${RESET}\n\n"

_item() {
    printf "  ${BG_DARK} ${BOLD}${GOLD} %s ${RESET}${BG_DARK}  ${WHITE}%-26s${RESET}  ${DIM}%s${RESET}\n" \
        "$1" "$2" "$3"
}

_item "0" "Install Panel"       "Pterodactyl web panel"
_item "1" "Install Wings"       "Daemon / node agent"
_item "2" "Install Both"        "Panel + Wings on same machine"
echo
_line "─" "${DIM}"
_item "3" "Panel  (canary)"     "Dev build — may be unstable"
_item "4" "Wings  (canary)"     "Dev build — may be unstable"
_item "5" "Both   (canary)"     "Panel + Wings dev builds"
echo
_line "─" "${DIM}"
_item "6" "Uninstall"           "Remove panel or Wings"
echo
_line "─" "${DIM}"
echo

# ── Input ─────────────────────────────────────────────────────────────────────
while true; do
    printf "  ${BOLD}${GOLD}➤ ${RESET}${BOLD}Enter option [0-6]: ${RESET}"
    read -r CHOICE
    case "$CHOICE" in
        0|1|2|3|4|5|6) break ;;
        *) printf "  ${RED}✗  Invalid — enter a number from 0 to 6.${RESET}\n" ;;
    esac
done

# ── Confirm ───────────────────────────────────────────────────────────────────
echo
_line "─" "${DIM}"
LABELS=("Install Panel" "Install Wings" "Install Both (Panel + Wings)"
        "Install Panel (canary)" "Install Wings (canary)"
        "Install Both (canary)" "Uninstall")

printf "\n  ${BOLD}${WHITE}You selected:${RESET}  ${BOLD}${GOLD}%s${RESET}\n\n" "${LABELS[$CHOICE]}"
printf "  ${BOLD}${YELLOW}➤ Confirm? [Y/n]: ${RESET}"
read -r CONFIRM
CONFIRM="${CONFIRM:-Y}"
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    printf "\n  ${DIM}Cancelled.${RESET}\n\n"
    exit 0
fi

# ── Check curl ────────────────────────────────────────────────────────────────
if ! command -v curl &>/dev/null; then
    printf "\n  ${RED}${BOLD}✗  curl is not installed.${RESET}\n"
    printf "  ${DIM}Run: apt install curl${RESET}\n\n"
    exit 1
fi

# ── Launch ────────────────────────────────────────────────────────────────────
echo
_line "═" "${GOLD}"
_center "🚀  Starting Installation — Please Follow On-Screen Steps  🚀" "${BOLD}${CYAN}"
_line "═" "${GOLD}"
echo

# Pass the user's choice into the official installer via stdin.
# Options 2 & 5 (install both) also prompt "proceed to wings?" — answer Y.
if [[ "$CHOICE" == "2" || "$CHOICE" == "5" ]]; then
    printf '%s\nY\n' "$CHOICE" | bash <(curl -s https://pterodactyl-installer.se)
else
    printf '%s\n' "$CHOICE" | bash <(curl -s https://pterodactyl-installer.se)
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo
_line "═" "${GOLD}"
printf "${BOLD}${GOLD}"
_center "✅  Installation Complete  ✅" "${BOLD}${GOLD}"
_center "KING KOM" "${BOLD}${GOLD}"
printf "${RESET}"
_line "═" "${GOLD}"
echo
