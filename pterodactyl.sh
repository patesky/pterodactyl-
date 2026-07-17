#!/usr/bin/env bash
# ================================================================
#  pterodactyl.sh — King Installer (Single File Edition)
#  Pterodactyl Panel & Wings — Install / Update / Delete
#
#  Run with:
#    bash <(curl -sSL https://raw.githubusercontent.com/patesky/pterodactyl-/main/pterodactyl.sh)
#
#  GitHub: https://github.com/patesky/pterodactyl-
# ================================================================

set -euo pipefail

# ================================================================
# CONFIG
# ================================================================
GH_USER="patesky"
GH_REPO="pterodactyl-"
GH_BRANCH="main"

APP_NAME="King Installer"
APP_VERSION="2.0"

PANEL_DIR="/var/www/pterodactyl"
PANEL_DB="pterodactyl"
PANEL_DB_USER="pterodactyl"

WINGS_DIR="/etc/pterodactyl"
WINGS_BIN="/usr/local/bin/wings"
WINGS_SERVICE="/etc/systemd/system/wings.service"

LOG_DIR="/var/log/king-installer"
LOG_FILE="${LOG_DIR}/install.log"

# ================================================================
# UI LIBRARY
# ================================================================
RESET="\e[0m"; BOLD="\e[1m"; DIM="\e[2m"
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; CYAN="\e[36m"
MAGENTA="\e[35m"
BRIGHT_RED="\e[91m"; BRIGHT_GREEN="\e[92m"; BRIGHT_YELLOW="\e[93m"
BRIGHT_CYAN="\e[96m"; BRIGHT_WHITE="\e[97m"; BRIGHT_MAGENTA="\e[95m"

SYM_OK="✓"; SYM_FAIL="✗"; SYM_WARN="⚠"
SYM_INFO="●"; SYM_ARROW="›"; SYM_BULLET="•"
SYM_GEAR="⚙"; SYM_STAR="★"

TERM_WIDTH=$(tput cols 2>/dev/null || echo 70)
[[ $TERM_WIDTH -lt 50 ]] && TERM_WIDTH=70
[[ $TERM_WIDTH -gt 100 ]] && TERM_WIDTH=100
INNER_W=$((TERM_WIDTH - 4))
_SPINNER_PID=""

ui::repeat() {
    local char="$1" count="$2" i
    for ((i=0; i<count; i++)); do printf "%s" "$char"; done
}

ui::center() {
    local text="$1" width="${2:-$TERM_WIDTH}"
    local plain; plain=$(echo -e "$text" | sed 's/\x1B\[[0-9;]*m//g')
    local len=${#plain}
    local pad=$(( (width - len) / 2 ))
    [[ $pad -lt 0 ]] && pad=0
    printf "%${pad}s%b\n" "" "$text"
}

ui::banner() {
    local w=$TERM_WIDTH
    echo
    echo -e "${CYAN}$(ui::repeat '═' $w)${RESET}"
    ui::center "${BOLD}${BRIGHT_YELLOW}${SYM_STAR}  KING INSTALLER  ${SYM_STAR}${RESET}"
    ui::center "${DIM}${CYAN}Pterodactyl Manager  •  v${APP_VERSION}${RESET}"
    echo -e "${CYAN}$(ui::repeat '═' $w)${RESET}"
    local now; now=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "  ${DIM}${CYAN}${now}   •   ${GH_USER}/${GH_REPO}${RESET}"
    echo -e "${DIM}${CYAN}$(ui::repeat '─' $w)${RESET}"
    echo
}

ui::section() {
    local title="$1" w=$TERM_WIDTH
    echo
    echo -e "${CYAN}$(ui::repeat '═' $w)${RESET}"
    ui::center "${BOLD}${BRIGHT_YELLOW}${title}${RESET}"
    echo -e "${CYAN}$(ui::repeat '═' $w)${RESET}"
    echo
}

ui::subsection() {
    local title="$1" w=$TERM_WIDTH
    echo
    echo -e "${DIM}${CYAN}$(ui::repeat '─' $w)${RESET}"
    echo -e "  ${BOLD}${BRIGHT_CYAN}${title}${RESET}"
    echo -e "${DIM}${CYAN}$(ui::repeat '─' $w)${RESET}"
    echo
}

ui::divider()     { echo -e "${DIM}${CYAN}$(ui::repeat '─' $TERM_WIDTH)${RESET}"; }
ui::ok()          { echo -e "  ${BRIGHT_GREEN}${SYM_OK}${RESET}  $*"; }
ui::fail()        { echo -e "  ${BRIGHT_RED}${SYM_FAIL}${RESET}  $*"; }
ui::warn()        { echo -e "  ${BRIGHT_YELLOW}${SYM_WARN}${RESET}  $*"; }
ui::info()        { echo -e "  ${BRIGHT_CYAN}${SYM_INFO}${RESET}  $*"; }
ui::step()        { echo -e "  ${BRIGHT_MAGENTA}${SYM_GEAR}${RESET}  ${BOLD}$*${RESET}"; }
ui::bullet()      { echo -e "    ${DIM}${CYAN}${SYM_BULLET}${RESET}  $*"; }

ui::status() {
    local label="$1" state="$2"
    local w=$((INNER_W - 10))
    printf "  %-${w}s" "$label"
    case "$state" in
        ok)   echo -e "  [ ${BRIGHT_GREEN}${SYM_OK} OK${RESET}     ]" ;;
        fail) echo -e "  [ ${BRIGHT_RED}${SYM_FAIL} FAIL${RESET}   ]" ;;
        skip) echo -e "  [ ${DIM}SKIP${RESET}    ]" ;;
        warn) echo -e "  [ ${BRIGHT_YELLOW}${SYM_WARN} WARN${RESET}   ]" ;;
        *)    echo -e "  [ ${DIM}${state}${RESET} ]" ;;
    esac
}

ui::check_item() {
    local label="$1" state="$2"
    case "$state" in
        ok)   echo -e "    ${BRIGHT_GREEN}${SYM_OK}${RESET}  ${label}" ;;
        fail) echo -e "    ${BRIGHT_RED}${SYM_FAIL}${RESET}  ${label}  ${DIM}(will install)${RESET}" ;;
        skip) echo -e "    ${DIM}─  ${label} (skipped)${RESET}" ;;
    esac
}

ui::spinner_start() {
    local msg="${1:-Working...}"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    ( local i=0
      while true; do
          printf "\r  ${BRIGHT_CYAN}%s${RESET}  %b" "${frames[i % ${#frames[@]}]}" "${CYAN}${msg}${RESET}"
          sleep 0.08
          ((i++)) || true   # ((i++)) returns 0 when i=0 (falsy); "|| true" prevents set -e from killing the subshell
      done
    ) &
    _SPINNER_PID=$!
    disown "$_SPINNER_PID" 2>/dev/null
}

ui::spinner_stop() {
    local state="${1:-ok}" msg="${2:-}"
    [[ -n "$_SPINNER_PID" ]] && kill "$_SPINNER_PID" 2>/dev/null; _SPINNER_PID=""
    printf "\r%${TERM_WIDTH}s\r" ""
    [[ -n "$msg" ]] && ui::status "$msg" "$state"
}

ui::menu_item() { echo -e "    ${DIM}${CYAN}[${RESET}${BOLD}${BRIGHT_YELLOW}$1${RESET}${DIM}${CYAN}]${RESET}  ${BRIGHT_WHITE}$2${RESET}"; }
ui::menu_exit() { echo; echo -e "    ${DIM}${CYAN}[${RESET}${RED}0${RESET}${DIM}${CYAN}]${RESET}  ${DIM}${1:-Back}${RESET}"; }

ui::prompt() {
    local _v="$1" _p="$2" _d="${3:-}" _i
    [[ -n "$_d" ]] \
        && echo -ne "\n  ${BRIGHT_YELLOW}${SYM_ARROW}${RESET}  ${_p} ${DIM}[${_d}]${RESET}: " \
        || echo -ne "\n  ${BRIGHT_YELLOW}${SYM_ARROW}${RESET}  ${_p}: "
    read -r _i
    [[ -z "$_i" && -n "$_d" ]] && _i="$_d"
    printf -v "$_v" '%s' "$_i"
}

ui::prompt_secret() {
    local _v="$1" _p="$2" _i
    echo -ne "\n  ${BRIGHT_YELLOW}${SYM_ARROW}${RESET}  ${_p}: "
    read -rs _i; echo
    printf -v "$_v" '%s' "$_i"
}

ui::prompt_yn() {
    local _v="$1" _p="$2" _d="${3:-Y}" _i
    local _opts; [[ "$_d" == "Y" ]] \
        && _opts="${BRIGHT_GREEN}Y${RESET}/${DIM}n${RESET}" \
        || _opts="${DIM}y${RESET}/${BRIGHT_RED}N${RESET}"
    echo -ne "\n  ${BRIGHT_YELLOW}${SYM_ARROW}${RESET}  ${_p} [${_opts}]: "
    read -r _i
    [[ -z "$_i" ]] && _i="$_d"
    printf -v "$_v" '%s' "${_i^^}"
}

ui::confirm_word() {
    local required="$1" _i
    echo -e "\n  ${BRIGHT_RED}${BOLD}This action is irreversible.${RESET}"
    echo -ne "  Type ${BOLD}${BRIGHT_RED}${required}${RESET} to confirm: "
    read -r _i
    [[ "$_i" == "$required" ]]
}

ui::summary_row() {
    printf "    ${DIM}${CYAN}%-28s${RESET}  ${BRIGHT_WHITE}%s${RESET}\n" "${1}:" "${2}"
}

ui::pause()     { echo; echo -e "  ${DIM}Press ${BRIGHT_WHITE}Enter${RESET}${DIM} to continue...${RESET}"; read -r; }
ui::press_any() { echo; ui::divider; echo -e "  ${DIM}Press any key to return...${RESET}"; read -rsn1; }

ui::menu_choice() {
    local _v="$1" _i
    echo; echo -ne "  ${BRIGHT_YELLOW}${BOLD}${SYM_ARROW}${RESET}  Enter choice: "
    read -r _i; printf -v "$_v" '%s' "$_i"
}

# ================================================================
# LOGGER
# ================================================================
_log() {
    local level="$1"; shift
    local ts; ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] [$level] $*" >> "$LOG_FILE" 2>/dev/null || true
}
log::info()    { _log "INFO " "$@"; }
log::ok()      { _log "OK   " "$@"; }
log::warn()    { _log "WARN " "$@"; }
log::error()   { _log "ERROR" "$@"; }
log::section() { _log "----" "--- $* ---"; }

logger::init() {
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    touch "$LOG_FILE"   2>/dev/null || true
    log::info "========================================"
    log::info "SESSION START  ${APP_NAME} v${APP_VERSION}"
    log::info "========================================"
}

# ================================================================
# SYSTEM
# ================================================================
OS_NAME=""; OS_VERSION=""; OS_ID=""; OS_ID_LIKE=""
PKG_MANAGER="apt"; PKG_UPDATE="apt-get update -qq"
PKG_INSTALL="apt-get install -y -qq"; PKG_QUERY="dpkg -s"
SUPPORTED=false; PHP_VERSION=""

sys::detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        OS_NAME="$NAME"; OS_VERSION="$VERSION_ID"
        OS_ID="${ID,,}"; OS_ID_LIKE="${ID_LIKE,,}"
    else
        OS_NAME="Unknown"; OS_VERSION="0"; OS_ID="unknown"; OS_ID_LIKE=""
    fi
    SUPPORTED=false
    case "$OS_ID" in
        ubuntu)
            PKG_MANAGER="apt"; PKG_UPDATE="apt-get update -qq"
            PKG_INSTALL="apt-get install -y -qq"; PKG_QUERY="dpkg -s"
            case "${OS_VERSION%%.*}" in 22|24) SUPPORTED=true ;; esac ;;
        debian)
            PKG_MANAGER="apt"; PKG_UPDATE="apt-get update -qq"
            PKG_INSTALL="apt-get install -y -qq"; PKG_QUERY="dpkg -s"
            case "${OS_VERSION%%.*}" in 11|12) SUPPORTED=true ;; esac ;;
        almalinux|alma)
            OS_ID="almalinux"; PKG_MANAGER="dnf"
            PKG_UPDATE="dnf makecache -q"; PKG_INSTALL="dnf install -y -q"
            PKG_QUERY="rpm -q"
            case "${OS_VERSION%%.*}" in 9) SUPPORTED=true ;; esac ;;
        rocky)
            PKG_MANAGER="dnf"; PKG_UPDATE="dnf makecache -q"
            PKG_INSTALL="dnf install -y -q"; PKG_QUERY="rpm -q"
            case "${OS_VERSION%%.*}" in 9) SUPPORTED=true ;; esac ;;
        *)
            if [[ "$OS_ID_LIKE" == *"debian"* || "$OS_ID_LIKE" == *"ubuntu"* ]]; then
                PKG_MANAGER="apt"; PKG_UPDATE="apt-get update -qq"
                PKG_INSTALL="apt-get install -y -qq"; PKG_QUERY="dpkg -s"; SUPPORTED=true
            elif [[ "$OS_ID_LIKE" == *"rhel"* || "$OS_ID_LIKE" == *"fedora"* ]]; then
                PKG_MANAGER="dnf"; PKG_UPDATE="dnf makecache -q"
                PKG_INSTALL="dnf install -y -q"; PKG_QUERY="rpm -q"; SUPPORTED=true
            fi ;;
    esac
}

sys::print_os_info() {
    echo
    ui::summary_row "Operating System" "${OS_NAME} ${OS_VERSION}"
    ui::summary_row "Package Manager"  "${PKG_MANAGER}"
    ui::summary_row "Architecture"     "$(uname -m)"
    ui::summary_row "Kernel"           "$(uname -r)"
    [[ "$SUPPORTED" == "true" ]] \
        && ui::summary_row "Support Status" "${BRIGHT_GREEN}Supported${RESET}" \
        || ui::summary_row "Support Status" "${BRIGHT_YELLOW}Unsupported (continuing)${RESET}"
    echo
}

sys::cmd_exists()  { command -v "$1" > /dev/null 2>&1; }
sys::gen_password() {
    # Use a subshell with pipefail disabled: "tr | head" sends SIGPIPE to tr when head
    # exits after reading $len bytes, making tr exit non-zero.  With set -o pipefail
    # active in the parent, the pipeline is considered failed even though the output is
    # correct.  Disabling pipefail locally prevents a silent script exit.
    local len="${1:-24}"
    local _pw
    _pw=$(set +o pipefail; tr -dc 'A-Za-z0-9!@#%^&*' < /dev/urandom 2>/dev/null | head -c "$len") || true
    printf '%s\n' "$_pw"
}

sys::pkg_update() {
    ui::spinner_start "Updating package index..."
    if $PKG_UPDATE >> "$LOG_FILE" 2>&1; then
        ui::spinner_stop "ok" "Package index updated"
    else
        ui::spinner_stop "warn" "Package index update had warnings"
    fi
}

# ================================================================
# SHARED HELPERS  (used by all 6 action functions)
# ================================================================
_run() {
    local label="$1"; shift
    ui::spinner_start "$label"
    if "$@" >> "$LOG_FILE" 2>&1; then
        ui::spinner_stop "ok" "$label"; log::ok "$label"
    else
        ui::spinner_stop "fail" "$label"; log::error "$label FAILED (cmd: $*)"
        return 1
    fi
}

_run_no_fail() {
    local label="$1"; shift
    ui::spinner_start "$label"
    if "$@" >> "$LOG_FILE" 2>&1; then
        ui::spinner_stop "ok" "$label"
    else
        ui::spinner_stop "warn" "$label"
    fi
}

_rm() {
    local label="$1"; shift
    ui::spinner_start "Removing: $label"
    "$@" >> "$LOG_FILE" 2>&1 && true
    ui::spinner_stop "ok" "Removed: $label"; log::ok "Removed: $label"
}

# ================================================================
# ① PANEL — INSTALL
# ================================================================
# Optional debug mode: set PANEL_DEBUG=1 before running, or select it in the
# install menu, to enable set -x tracing of every installation command.
PANEL_DEBUG="${PANEL_DEBUG:-0}"

panel_install() {
    clear; ui::banner; ui::section "INSTALL PTERODACTYL PANEL"

    # ── Debug mode ────────────────────────────────────────────
    echo
    ui::menu_item "D" "Enable debug mode (set -x — shows every command)"
    echo -ne "\n  ${DIM}Press ${BRIGHT_YELLOW}D${RESET}${DIM} to enable debug, or ${BRIGHT_WHITE}Enter${RESET}${DIM} to continue normally: ${RESET}"
    local _debug_choice
    read -r -t 5 _debug_choice || _debug_choice=""
    if [[ "${_debug_choice^^}" == "D" ]]; then
        PANEL_DEBUG=1
        ui::warn "Debug mode ON — all commands will be printed to terminal and log."
        log::info "Debug mode enabled by user."
    fi

    # ── ERR trap: show exactly which command caused an exit ───
    # This replaces the silent "nothing happens" with a clear error line.
    _panel_err_trap() {
        local _exit=$? _line=$1 _cmd=$2
        echo >&2
        echo -e "  ${BRIGHT_RED}${SYM_FAIL}  FATAL: installation command failed (exit ${_exit})${RESET}" >&2
        echo -e "  ${DIM}Line ${_line}: ${_cmd}${RESET}" >&2
        echo -e "  ${DIM}Full log: ${LOG_FILE}${RESET}" >&2
        log::error "Fatal exit at line ${_line}: ${_cmd} (exit ${_exit})"
    }
    trap '_panel_err_trap "$LINENO" "$BASH_COMMAND"' ERR

    # Activate set -x tracing if debug requested
    [[ "$PANEL_DEBUG" == "1" ]] && { log::info "set -x enabled"; set -x; }

    sys::detect_os; sys::print_os_info

    ui::subsection "Dependency Check"
    # Official Pterodactyl docs do NOT require Node.js or Yarn for the panel —
    # the release archive already contains pre-built assets.
    local NEED_NGINX=false NEED_MARIADB=false NEED_REDIS=false
    local NEED_PHP=false NEED_COMPOSER=false

    sys::cmd_exists nginx     && ui::check_item "Nginx"    "ok" || { NEED_NGINX=true;    ui::check_item "Nginx"    "fail"; }
    sys::cmd_exists mysqld    && ui::check_item "MariaDB"  "ok" || { NEED_MARIADB=true;  ui::check_item "MariaDB"  "fail"; }
    sys::cmd_exists redis-cli && ui::check_item "Redis"    "ok" || { NEED_REDIS=true;    ui::check_item "Redis"    "fail"; }
    sys::cmd_exists php       && ui::check_item "PHP 8.3"  "ok" || { NEED_PHP=true;      ui::check_item "PHP 8.3"  "fail"; }
    sys::cmd_exists composer  && ui::check_item "Composer" "ok" || { NEED_COMPOSER=true; ui::check_item "Composer" "fail"; }
    echo

    ui::subsection "Panel Configuration"
    local PANEL_FQDN USE_HTTPS LE_EMAIL="" SETUP_FIREWALL TIMEZONE PANEL_DB_PASS ADMIN_USERNAME
    local ADMIN_EMAIL ADMIN_FIRSTNAME ADMIN_LASTNAME ADMIN_PASS _DB_PASS_OPT _CONFIRM

    ui::prompt   PANEL_FQDN      "Panel domain (e.g. panel.example.com)"
    ui::prompt_yn USE_HTTPS      "Enable HTTPS (Let's Encrypt)?" "Y"
    [[ "$USE_HTTPS" == "Y" ]] && ui::prompt LE_EMAIL "Let's Encrypt email"
    ui::prompt_yn SETUP_FIREWALL "Configure firewall automatically?" "Y"
    ui::prompt   TIMEZONE        "Timezone" "UTC"
    echo
    echo -e "  ${DIM}${CYAN}Database password:${RESET}"
    ui::menu_item "1" "Generate randomly"
    ui::menu_item "2" "Enter custom"
    ui::menu_choice _DB_PASS_OPT
    if [[ "$_DB_PASS_OPT" == "2" ]]; then
        ui::prompt_secret PANEL_DB_PASS "Database password"
    else
        PANEL_DB_PASS=$(sys::gen_password 28)
        ui::ok "Generated: ${BRIGHT_YELLOW}${PANEL_DB_PASS}${RESET}"
    fi

    ui::subsection "Admin Account"
    ui::prompt   ADMIN_USERNAME  "Username"
    ui::prompt   ADMIN_EMAIL     "Email address"
    ui::prompt   ADMIN_FIRSTNAME "First name"
    ui::prompt   ADMIN_LASTNAME  "Last name"
    ui::prompt_secret ADMIN_PASS "Password"

    ui::subsection "Installation Summary"
    echo
    ui::summary_row "OS"              "${OS_NAME} ${OS_VERSION}"
    ui::summary_row "Panel Domain"    "${PANEL_FQDN}"
    ui::summary_row "HTTPS / SSL"     "${USE_HTTPS}"
    [[ "$USE_HTTPS" == "Y" ]] && ui::summary_row "LE Email" "${LE_EMAIL}"
    ui::summary_row "Firewall"        "${SETUP_FIREWALL}"
    ui::summary_row "Timezone"        "${TIMEZONE}"
    ui::summary_row "DB Name"         "${PANEL_DB}"
    ui::summary_row "DB User"         "${PANEL_DB_USER}"
    ui::summary_row "DB Password"     "${PANEL_DB_PASS:0:4}••••••••••••"
    echo
    ui::summary_row "Admin Username"  "${ADMIN_USERNAME}"
    ui::summary_row "Admin Email"     "${ADMIN_EMAIL}"
    echo

    ui::prompt_yn _CONFIRM "Proceed with installation?" "Y"
    [[ "$_CONFIRM" != "Y" ]] && {
        ui::warn "Installation cancelled by user."
        log::info "Installation cancelled at confirmation prompt."
        trap - ERR    # Remove ERR trap before returning
        [[ "$PANEL_DEBUG" == "1" ]] && set +x
        ui::press_any; return 0
    }

    log::section "PTERODACTYL PANEL INSTALL"
    ui::info "Installation started. Full log: ${DIM}${LOG_FILE}${RESET}"
    echo

    # ── Dependencies ──────────────────────────────────────────
    # Commands taken directly from https://pterodactyl.io/panel/1.0/getting_started.html
    ui::subsection "Installing Dependencies"
    log::info "Step: Installing Dependencies (official Pterodactyl commands)"

    case "$OS_ID" in
        # ── Ubuntu / Debian ───────────────────────────────────
        ubuntu|debian)
            # Step 1 — update package index first so apt can find the prereq packages
            ui::step "Updating package index..."
            log::info "apt-get update (initial, before adding repos)"
            _run "Initial apt update" bash -c "apt-get update -qq"

            # Step 2 — install tools needed to add extra repos
            ui::step "[Official] Adding required apt tools..."
            log::info "apt install: software-properties-common curl apt-transport-https ca-certificates gnupg"
            _run "Installing apt prerequisites" bash -c \
                "DEBIAN_FRONTEND=noninteractive apt -y install \
                    software-properties-common curl apt-transport-https ca-certificates gnupg"

            # Step 3 — PHP repo (ppa:ondrej/php)
            if [[ "$NEED_PHP" == "true" ]]; then
                ui::step "[Official] Adding PHP repository (ppa:ondrej/php)..."
                log::info "add-apt-repository ppa:ondrej/php"
                _run "Adding ondrej/php PPA" bash -c \
                    "LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php"
            fi

            # Step 4 — Redis official APT repo
            if [[ "$NEED_REDIS" == "true" ]]; then
                ui::step "[Official] Adding Redis official APT repository..."
                log::info "Adding packages.redis.io repo"
                _run "Adding Redis GPG key" bash -c \
                    "curl -fsSL https://packages.redis.io/gpg \
                     | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg"
                _run "Adding Redis APT source" bash -c \
                    "echo \"deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] \
https://packages.redis.io/deb \$(lsb_release -cs) main\" \
                     | tee /etc/apt/sources.list.d/redis.list"
            fi

            # Step 5 — update again now that all repos are added
            ui::step "[Official] Running apt update (with new repos)..."
            log::info "apt update (after repo additions)"
            sys::pkg_update

            # Step 6 — install everything in one command (matches official docs exactly)
            ui::step "[Official] Installing all panel dependencies..."
            log::info "apt install: php8.3 extensions + mariadb-server + nginx + redis-server + tar + unzip + git"
            _run "Installing all dependencies" bash -c \
                "DEBIAN_FRONTEND=noninteractive apt -y install \
                    php8.3 php8.3-{common,cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} \
                    mariadb-server nginx tar unzip git redis-server"
            ;;

        # ── AlmaLinux / Rocky Linux ───────────────────────────
        almalinux|rocky)
            ui::step "[Official] Adding EPEL + Remi PHP 8.3 repo..."
            log::info "dnf: EPEL + Remi repo + PHP 8.3 module"
            _run "Installing EPEL release" bash -c "dnf install -y epel-release"
            _run "Adding Remi repository" bash -c \
                "dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm"
            _run "Enabling PHP 8.3 module" bash -c \
                "dnf module reset php -y && dnf module enable php:remi-8.3 -y"

            sys::pkg_update

            ui::step "[Official] Installing all panel dependencies..."
            log::info "dnf install: php + extensions + mariadb-server + nginx + redis"
            _run "Installing all dependencies" bash -c \
                "dnf install -y \
                    php php-{common,fpm,cli,mbstring,bcmath,gd,mysql,pdo,zip,xml,curl} \
                    mariadb-server nginx tar unzip git redis"
            ;;

        *)
            # Fallback for other distros — best-effort
            ui::warn "Unsupported OS '${OS_ID}' — attempting best-effort install."
            log::warn "Unsupported OS: ${OS_ID}"
            sys::pkg_update
            _run_no_fail "Installing common packages" bash -c \
                "$PKG_INSTALL php mariadb-server nginx redis-server tar unzip git curl"
            ;;
    esac

    # ── Start MariaDB and Redis after install ──────────────────
    ui::step "Enabling and starting MariaDB..."
    log::info "systemctl enable --now mariadb"
    _run "Enabling MariaDB" bash -c "systemctl enable --now mariadb"

    ui::step "Enabling and starting Redis..."
    log::info "systemctl enable --now redis-server / redis"
    _run_no_fail "Enabling Redis" bash -c \
        "systemctl enable --now redis-server 2>/dev/null || systemctl enable --now redis"

    # ── Start PHP-FPM ─────────────────────────────────────────
    ui::step "Enabling PHP-FPM..."
    log::info "systemctl enable --now php8.3-fpm / php-fpm"
    _run_no_fail "Enabling PHP-FPM" bash -c \
        "systemctl enable --now php8.3-fpm 2>/dev/null || systemctl enable --now php-fpm"

    # ── Composer — official Pterodactyl command ────────────────
    if [[ "$NEED_COMPOSER" == "true" ]] || ! sys::cmd_exists composer; then
        ui::step "[Official] Installing Composer..."
        log::info "curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer"
        _run "Installing Composer" bash -c \
            "curl -sS https://getcomposer.org/installer \
             | php -- --install-dir=/usr/local/bin --filename=composer"
    else
        ui::info "Composer already installed — skipping."
    fi

    # ── Database ──────────────────────────────────────────────
    ui::subsection "Configuring Database"
    log::info "Step: Configuring Database"

    # Ensure MariaDB is running before we try to connect.
    # The bare "mysql" heredoc was previously NOT wrapped in error handling;
    # if MariaDB wasn't ready, set -e would cause a silent exit here.
    _run "Starting MariaDB" systemctl start mariadb
    ui::step "Creating database and user..."
    log::info "Running: mysql -u root (CREATE DATABASE / USER)"
    if mysql -u root >> "$LOG_FILE" 2>&1 <<-MYSQL
        CREATE USER IF NOT EXISTS '${PANEL_DB_USER}'@'127.0.0.1' IDENTIFIED BY '${PANEL_DB_PASS}';
        CREATE DATABASE IF NOT EXISTS \`${PANEL_DB}\`;
        GRANT ALL PRIVILEGES ON \`${PANEL_DB}\`.* TO '${PANEL_DB_USER}'@'127.0.0.1' WITH GRANT OPTION;
        FLUSH PRIVILEGES;
MYSQL
    then
        ui::status "Database + user created" "ok"
        log::ok "Database configured (db=${PANEL_DB} user=${PANEL_DB_USER})"
    else
        ui::fail "mysql command failed — check ${LOG_FILE} for details."
        ui::warn "Common causes: MariaDB socket not ready, root password required, or 'mysql' binary not in PATH."
        ui::warn "Try: mysql -u root -p  to test manually, then re-run the installer."
        log::error "mysql CREATE DATABASE/USER failed. Aborting."
        trap - ERR
        [[ "$PANEL_DEBUG" == "1" ]] && set +x
        ui::press_any; return 1
    fi

    # ── Download Panel ────────────────────────────────────────
    ui::subsection "Downloading Pterodactyl Panel"
    log::info "Step: Downloading Pterodactyl Panel"
    local PANEL_VERSION
    # Use a subshell with pipefail disabled: grep/head in the pipeline would
    # send SIGPIPE to curl and make the pipeline return non-zero under pipefail.
    PANEL_VERSION=$(set +o pipefail
        curl -fsSL --max-time 10 \
            "https://api.github.com/repos/pterodactyl/panel/releases/latest" 2>/dev/null \
        | grep '"tag_name"' | head -1 \
        | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/') || PANEL_VERSION="latest"
    [[ -z "$PANEL_VERSION" ]] && PANEL_VERSION="latest"
    ui::info "Latest version: ${BRIGHT_YELLOW}${PANEL_VERSION}${RESET}"
    log::info "Panel version to install: ${PANEL_VERSION}"
    mkdir -p "$PANEL_DIR"; cd "$PANEL_DIR"
    _run "Downloading panel archive" curl -Lo panel.tar.gz \
        "https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz"
    _run "Extracting archive" tar -xzf panel.tar.gz
    rm -f panel.tar.gz
    _run "Setting storage permissions" chmod -R 755 storage/* bootstrap/cache/

    # ── Configure Panel ───────────────────────────────────────
    # All commands below are from https://pterodactyl.io/panel/1.0/getting_started.html
    ui::subsection "Configuring Panel"
    log::info "Step: Configuring Panel (official commands)"

    ui::step "[Official] cp .env.example .env"
    if [[ ! -f .env.example ]]; then
        ui::fail ".env.example not found in ${PANEL_DIR} — archive may be incomplete."
        log::error ".env.example missing after extraction."
        trap - ERR; [[ "$PANEL_DEBUG" == "1" ]] && set +x; ui::press_any; return 1
    fi
    cp .env.example .env
    ui::status ".env created" "ok"; log::ok ".env.example → .env"

    ui::step "[Official] COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader"
    _run "Installing Composer dependencies" bash -c \
        "COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader"

    ui::step "[Official] php artisan key:generate --force"
    _run "Generating application key" php artisan key:generate --force

    # p:environment:setup — official command, run non-interactively with flags
    ui::step "[Official] php artisan p:environment:setup"
    log::info "p:environment:setup: url=http${USE_HTTPS/Y/s}://${PANEL_FQDN} tz=${TIMEZONE}"
    _run "Configuring environment" php artisan p:environment:setup \
        --author="${LE_EMAIL:-admin@${PANEL_FQDN}}" \
        --url="http${USE_HTTPS/Y/s}://${PANEL_FQDN}" \
        --timezone="${TIMEZONE}" \
        --cache=redis --session=redis --queue=redis \
        --settings-ui=true --telemetry=false --no-interaction

    # p:environment:database — official command
    ui::step "[Official] php artisan p:environment:database"
    log::info "p:environment:database: host=127.0.0.1 db=${PANEL_DB} user=${PANEL_DB_USER}"
    _run "Configuring database connection" php artisan p:environment:database \
        --host=127.0.0.1 --port=3306 \
        --database="${PANEL_DB}" --username="${PANEL_DB_USER}" \
        --password="${PANEL_DB_PASS}" --no-interaction

    # php artisan migrate --seed --force — official command
    ui::step "[Official] php artisan migrate --seed --force"
    log::info "Running database migrations + seeding"
    _run "Running database migrations" php artisan migrate --seed --force

    # php artisan p:user:make — official command
    ui::step "[Official] php artisan p:user:make"
    log::info "Creating admin account: ${ADMIN_USERNAME} <${ADMIN_EMAIL}>"
    _run "Creating admin account" php artisan p:user:make \
        --email="${ADMIN_EMAIL}" --username="${ADMIN_USERNAME}" \
        --name-first="${ADMIN_FIRSTNAME}" --name-last="${ADMIN_LASTNAME}" \
        --password="${ADMIN_PASS}" --admin=1 --no-interaction

    # ── Permissions ───────────────────────────────────────────
    # Official command: chown -R www-data:www-data /var/www/pterodactyl/*
    # RHEL/Rocky/Alma: chown -R nginx:nginx /var/www/pterodactyl/*
    ui::subsection "Setting Permissions"
    log::info "Step: Setting file permissions (official command)"
    ui::step "[Official] chown -R www-data:www-data /var/www/pterodactyl/*"
    _run "Setting ownership" bash -c \
        "chown -R www-data:www-data ${PANEL_DIR}/* 2>/dev/null || chown -R nginx:nginx ${PANEL_DIR}/*"

    # ── Nginx ─────────────────────────────────────────────────
    # Config template from https://pterodactyl.io/panel/1.0/webserver_configuration.html
    ui::subsection "Configuring Nginx"
    log::info "Step: Configuring Nginx (official config template)"

    # Official socket path is /run/php/php8.3-fpm.sock
    # /var/run is a symlink to /run on modern systems, but use /run to match docs exactly.
    local PHP_SOCK
    PHP_SOCK=$(set +o pipefail; ls /run/php/php*-fpm.sock 2>/dev/null | head -1) || PHP_SOCK=""
    [[ -z "$PHP_SOCK" ]] && \
        PHP_SOCK=$(set +o pipefail; ls /var/run/php/php*-fpm.sock 2>/dev/null | head -1) || true
    [[ -z "$PHP_SOCK" ]] && PHP_SOCK="/run/php/php8.3-fpm.sock"
    ui::info "PHP-FPM socket: ${DIM}${PHP_SOCK}${RESET}"
    log::info "Using PHP-FPM socket: ${PHP_SOCK}"

    # Remove default site as per official docs
    ui::step "[Official] rm /etc/nginx/sites-enabled/default"
    rm -f /etc/nginx/sites-enabled/default
    log::info "Removed default nginx site"

    if [[ "$USE_HTTPS" == "Y" ]]; then
        # Official SSL config — certbot will add the ssl/https stanzas after we enable HTTP first
        ui::info "Writing HTTP config; certbot will convert to HTTPS..."
        log::info "Writing HTTP-only nginx config (certbot will upgrade to HTTPS)"
        cat > /etc/nginx/sites-available/pterodactyl.conf <<NGINX
server {
    listen 80;
    server_name ${PANEL_FQDN};

    root ${PANEL_DIR}/public;
    index index.html index.htm index.php;
    charset utf-8;

    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    location ~ \\.php$ {
        fastcgi_split_path_info ^(.+\\.php)(/.+)$;
        fastcgi_pass unix:${PHP_SOCK};
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        include /etc/nginx/fastcgi_params;
    }

    location ~ /\\.ht {
        deny all;
    }
}
NGINX
    else
        # Official HTTP-only config (no SSL)
        cat > /etc/nginx/sites-available/pterodactyl.conf <<NGINX
server {
    listen 80;
    server_name ${PANEL_FQDN};

    root ${PANEL_DIR}/public;
    index index.html index.htm index.php;
    charset utf-8;

    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    location ~ \\.php$ {
        fastcgi_split_path_info ^(.+\\.php)(/.+)$;
        fastcgi_pass unix:${PHP_SOCK};
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        include /etc/nginx/fastcgi_params;
    }

    location ~ /\\.ht {
        deny all;
    }
}
NGINX
    fi

    # Official: ln -s sites-available → sites-enabled; restart nginx
    ui::step "[Official] ln -s pterodactyl.conf → sites-enabled && systemctl restart nginx"
    log::info "Enabling nginx site and restarting"
    [[ -d /etc/nginx/sites-enabled ]] && \
        ln -sf /etc/nginx/sites-available/pterodactyl.conf \
               /etc/nginx/sites-enabled/pterodactyl.conf
    _run "Testing Nginx config" nginx -t
    _run "Enabling Nginx"       systemctl enable nginx
    _run "Restarting Nginx"     systemctl restart nginx

    # ── SSL ───────────────────────────────────────────────────
    if [[ "$USE_HTTPS" == "Y" ]]; then
        ui::subsection "Installing SSL Certificate"
        log::info "Step: Let's Encrypt SSL via certbot"
        _run_no_fail "Installing Certbot" bash -c \
            "$PKG_INSTALL certbot python3-certbot-nginx"
        # Official: certbot --nginx -d <domain> --non-interactive --agree-tos -m <email> --redirect
        ui::step "[Official] certbot --nginx -d ${PANEL_FQDN} --redirect"
        _run "Obtaining SSL certificate" bash -c \
            "certbot --nginx -d ${PANEL_FQDN} --non-interactive --agree-tos \
             --email ${LE_EMAIL} --redirect"
        log::ok "SSL certificate obtained for ${PANEL_FQDN}"
    fi

    # ── Firewall ──────────────────────────────────────────────
    if [[ "$SETUP_FIREWALL" == "Y" ]]; then
        ui::subsection "Configuring Firewall"
        log::info "Step: Configuring Firewall"
        if sys::cmd_exists ufw; then
            _run_no_fail "UFW: enable"      bash -c "ufw --force enable"
            _run_no_fail "UFW: allow SSH"   bash -c "ufw allow 22/tcp"
            _run_no_fail "UFW: allow HTTP"  bash -c "ufw allow 80/tcp"
            _run_no_fail "UFW: allow HTTPS" bash -c "ufw allow 443/tcp"
            _run_no_fail "UFW: reload"      bash -c "ufw reload"
        elif sys::cmd_exists firewall-cmd; then
            _run_no_fail "FW: SSH"          bash -c "firewall-cmd --permanent --add-service=ssh"
            _run_no_fail "FW: HTTP"         bash -c "firewall-cmd --permanent --add-service=http"
            _run_no_fail "FW: HTTPS"        bash -c "firewall-cmd --permanent --add-service=https"
            _run_no_fail "FW: reload"       bash -c "firewall-cmd --reload"
        fi
    fi

    # ── Queue Worker ──────────────────────────────────────────
    # Service file from https://pterodactyl.io/panel/1.0/getting_started.html#queue-listeners
    ui::subsection "Setting Up Queue Worker"
    log::info "Step: Creating pteroq systemd service (official)"
    ui::step "[Official] Writing /etc/systemd/system/pteroq.service"
    cat > /etc/systemd/system/pteroq.service <<'UNIT'
# Pterodactyl Queue Worker File — from https://pterodactyl.io
# ----------------------------------

[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service mariadb.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
UNIT
    log::ok "pteroq.service written"
    _run "Reloading systemd"    systemctl daemon-reload
    _run "Enabling pteroq"      systemctl enable pteroq
    _run "Starting pteroq"      systemctl start pteroq

    # ── Cron ──────────────────────────────────────────────────
    ui::subsection "Configuring Cron"
    log::info "Step: Configuring Cron"
    # The "(crontab -l | grep -v ...) | crontab -" pipeline could fail under pipefail
    # if crontab -l exits non-zero (e.g. no existing crontab on a fresh system).
    # Use a bash -c subshell so pipefail does not apply to the inner pipeline.
    if bash -c '
        ( crontab -l 2>/dev/null | grep -v "pterodactyl"
          echo "* * * * * php '"${PANEL_DIR}"'/artisan schedule:run >> /dev/null 2>&1"
        ) | crontab -
    ' >> "$LOG_FILE" 2>&1; then
        ui::status "Cron job installed" "ok"
        log::ok "Cron job added"
    else
        ui::warn "Cron job setup returned non-zero — check ${LOG_FILE}"
        log::warn "crontab command returned non-zero (may still have worked)"
    fi

    # ── Restart & Verify ──────────────────────────────────────
    ui::subsection "Restarting Services"
    log::info "Step: Restarting Services"
    _run_no_fail "Restarting PHP-FPM" bash -c \
        "systemctl restart php8.3-fpm 2>/dev/null || systemctl restart php-fpm"
    _run "Restarting Nginx"   systemctl restart nginx
    _run "Restarting MariaDB" systemctl restart mariadb
    _run "Restarting Redis"   bash -c \
        "systemctl restart redis-server 2>/dev/null || systemctl restart redis"

    ui::subsection "Verifying Installation"
    log::info "Step: Verifying Installation"
    [[ -f "${PANEL_DIR}/public/index.php" ]] \
        && { ui::status "Panel files present" "ok"; log::ok "Panel files present"; } \
        || { ui::status "Panel files present" "fail"; log::warn "Panel files missing — check archive extraction"; }
    [[ -f "${PANEL_DIR}/.env" ]] \
        && { ui::status ".env configured" "ok"; log::ok ".env exists"; } \
        || { ui::status ".env configured" "fail"; log::warn ".env missing"; }
    systemctl is-active --quiet nginx   \
        && { ui::status "Nginx running"   "ok"; log::ok "Nginx active"; } \
        || { ui::status "Nginx running"   "warn"; log::warn "Nginx not active"; }
    systemctl is-active --quiet mariadb \
        && { ui::status "MariaDB running" "ok"; log::ok "MariaDB active"; } \
        || { ui::status "MariaDB running" "warn"; log::warn "MariaDB not active"; }
    systemctl is-active --quiet pteroq  \
        && { ui::status "Queue worker"    "ok"; log::ok "pteroq active"; } \
        || { ui::status "Queue worker"    "warn"; log::warn "pteroq not active"; }
    local HTTP_CODE
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost" 2>/dev/null || echo "000")
    [[ "$HTTP_CODE" =~ ^[23] ]] \
        && { ui::status "HTTP response (${HTTP_CODE})" "ok"; log::ok "HTTP ${HTTP_CODE}"; } \
        || { ui::status "HTTP response (${HTTP_CODE} — may need DNS)" "warn"; log::warn "HTTP ${HTTP_CODE}"; }

    # ── Done ──────────────────────────────────────────────────
    # Remove ERR trap and debug tracing before returning cleanly.
    trap - ERR
    [[ "$PANEL_DEBUG" == "1" ]] && { set +x; log::info "set -x disabled"; }

    echo; ui::divider; echo
    echo -e "  ${BRIGHT_GREEN}${BOLD}${SYM_STAR}  Pterodactyl Panel installed successfully!  ${SYM_STAR}${RESET}"
    echo
    ui::summary_row "Panel URL"    "http${USE_HTTPS/Y/s}://${PANEL_FQDN}"
    ui::summary_row "Admin User"   "${ADMIN_USERNAME}"
    ui::summary_row "Admin Email"  "${ADMIN_EMAIL}"
    ui::summary_row "DB Password"  "${PANEL_DB_PASS}  ${DIM}(save this!)${RESET}"
    ui::summary_row "Log File"     "${LOG_FILE}"
    echo
    log::ok "Panel install complete. URL=http${USE_HTTPS/Y/s}://${PANEL_FQDN} User=${ADMIN_USERNAME}"
    ui::press_any
}

# ================================================================
# ② PANEL — UPDATE
# ================================================================
panel_update() {
    clear; ui::banner; ui::section "UPDATE PTERODACTYL PANEL"
    sys::detect_os

    if [[ ! -d "$PANEL_DIR" ]]; then
        ui::fail "Panel directory not found: ${PANEL_DIR}"
        ui::warn "Is Pterodactyl Panel installed?"
        ui::press_any; return 0
    fi

    local CURRENT_VER LATEST_VER _CONFIRM
    CURRENT_VER=$(cd "$PANEL_DIR" && php artisan --version 2>/dev/null \
        | grep -oP '[\d.]+' | tail -1 || echo "unknown")
    LATEST_VER=$(curl -fsSL --max-time 10 \
        "https://api.github.com/repos/pterodactyl/panel/releases/latest" 2>/dev/null \
        | grep '"tag_name"' | head -1 \
        | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' || echo "unknown")

    ui::info "Current version : ${BRIGHT_YELLOW}${CURRENT_VER}${RESET}"
    ui::info "Latest release  : ${BRIGHT_YELLOW}${LATEST_VER}${RESET}"
    echo
    ui::prompt_yn _CONFIRM "Proceed with update?" "Y"
    [[ "$_CONFIRM" != "Y" ]] && { ui::warn "Update cancelled."; ui::press_any; return 0; }

    log::section "PTERODACTYL PANEL UPDATE"
    cd "$PANEL_DIR"

    ui::subsection "Enabling Maintenance Mode"
    _run "Maintenance mode ON" php artisan down

    ui::subsection "Creating Backup"
    local BACKUP_DIR="/var/backups/pterodactyl"
    local BACKUP_FILE="${BACKUP_DIR}/panel-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    mkdir -p "$BACKUP_DIR"
    _run "Backing up panel files" tar -czf "$BACKUP_FILE" \
        --exclude="${PANEL_DIR}/vendor" --exclude="${PANEL_DIR}/node_modules" "$PANEL_DIR"
    ui::info "Backup: ${DIM}${BACKUP_FILE}${RESET}"
    if sys::cmd_exists mysqldump; then
        local DB_BACKUP="${BACKUP_DIR}/panel-db-$(date +%Y%m%d-%H%M%S).sql"
        _run "Backing up database" bash -c "mysqldump ${PANEL_DB} > ${DB_BACKUP}"
        ui::info "DB backup: ${DIM}${DB_BACKUP}${RESET}"
    fi

    ui::subsection "Downloading Latest Panel"
    _run "Downloading panel archive" curl -Lo /tmp/panel-latest.tar.gz \
        "https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz"
    _run "Extracting archive" tar -xzf /tmp/panel-latest.tar.gz
    rm -f /tmp/panel-latest.tar.gz

    ui::subsection "Updating Composer Dependencies"
    _run "Updating Composer packages" bash -c \
        "COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader"

    ui::subsection "Running Database Migrations"
    _run "Running migrations" php artisan migrate --force
    _run "Seeding database"   bash -c "php artisan db:seed --force 2>/dev/null || true"

    ui::subsection "Clearing Cache"
    _run "Clearing view cache"   php artisan view:clear
    _run "Clearing config cache" php artisan config:clear
    _run "Clearing route cache"  php artisan route:clear
    _run "Clearing event cache"  php artisan event:clear
    _run "Clearing compiled"     php artisan clear-compiled
    _run "Caching config"        php artisan config:cache
    _run "Caching routes"        php artisan route:cache
    _run "Caching views"         php artisan view:cache

    ui::subsection "Setting Permissions"
    _run "Setting ownership" bash -c \
        "chown -R www-data:www-data ${PANEL_DIR} 2>/dev/null || chown -R nginx:nginx ${PANEL_DIR}"
    _run "Setting storage permissions" chmod -R 755 \
        "${PANEL_DIR}/storage"/* "${PANEL_DIR}/bootstrap/cache/"

    ui::subsection "Restarting Services"
    _run_no_fail "Restarting PHP-FPM" bash -c \
        "systemctl restart php8.3-fpm 2>/dev/null || systemctl restart php-fpm"
    _run "Restarting Queue Worker" systemctl restart pteroq
    _run "Reloading Nginx"         systemctl reload nginx

    ui::subsection "Disabling Maintenance Mode"
    _run "Maintenance mode OFF" php artisan up

    ui::subsection "Verifying Update"
    local NEW_VER
    NEW_VER=$(php artisan --version 2>/dev/null | grep -oP '[\d.]+' | tail -1 || echo "unknown")
    ui::summary_row "Previous version" "${CURRENT_VER}"
    ui::summary_row "Updated version"  "${NEW_VER}"
    ui::summary_row "Backup location"  "${BACKUP_FILE}"
    systemctl is-active --quiet nginx  && ui::status "Nginx running"        "ok" || ui::status "Nginx running"        "warn"
    systemctl is-active --quiet pteroq && ui::status "Queue worker running" "ok" || ui::status "Queue worker running" "warn"

    echo
    ui::ok "${BOLD}Pterodactyl Panel updated successfully!${RESET}"
    log::ok "Panel updated: ${CURRENT_VER} → ${NEW_VER}"
    ui::press_any
}

# ================================================================
# ③ PANEL — DELETE
# ================================================================
panel_delete() {
    clear; ui::banner; ui::section "DELETE PTERODACTYL PANEL"
    sys::detect_os

    echo -e "  ${BRIGHT_RED}${BOLD}WARNING: This will permanently remove Pterodactyl Panel!${RESET}"
    echo -e "  ${DIM}This operation cannot be undone.${RESET}"
    echo
    if ! ui::confirm_word "DELETE"; then
        echo; ui::warn "Confirmation not matched. Operation cancelled."
        ui::press_any; return 0
    fi

    ui::subsection "Select Components to Remove"
    echo -e "  ${DIM}Press${RESET} ${BRIGHT_GREEN}Y${RESET} ${DIM}to remove, ${RESET}${RED}N${RESET} ${DIM}to keep:${RESET}"
    echo
    local RM_FILES RM_DATABASE RM_REDIS RM_NGINX RM_SSL RM_CRON RM_QUEUE RM_USER _FINAL_CONFIRM
    ui::prompt_yn RM_FILES    "Remove panel files (${PANEL_DIR})?" "Y"
    ui::prompt_yn RM_DATABASE "Remove database and DB user?"       "Y"
    ui::prompt_yn RM_REDIS    "Remove Redis configuration?"        "N"
    ui::prompt_yn RM_NGINX    "Remove Nginx configuration?"        "Y"
    ui::prompt_yn RM_SSL      "Remove SSL certificates?"           "Y"
    ui::prompt_yn RM_CRON     "Remove cron job?"                   "Y"
    ui::prompt_yn RM_QUEUE    "Remove queue worker service?"       "Y"
    ui::prompt_yn RM_USER     "Remove www-data system user?"       "N"

    echo
    ui::subsection "Removal Summary"
    [[ "$RM_FILES"    == "Y" ]] && ui::bullet "Panel files:    ${PANEL_DIR}"
    [[ "$RM_DATABASE" == "Y" ]] && ui::bullet "Database:       ${PANEL_DB} (user: ${PANEL_DB_USER})"
    [[ "$RM_REDIS"    == "Y" ]] && ui::bullet "Redis config"
    [[ "$RM_NGINX"    == "Y" ]] && ui::bullet "Nginx site config"
    [[ "$RM_SSL"      == "Y" ]] && ui::bullet "SSL certificates"
    [[ "$RM_CRON"     == "Y" ]] && ui::bullet "Cron job"
    [[ "$RM_QUEUE"    == "Y" ]] && ui::bullet "Queue worker service (pteroq)"
    [[ "$RM_USER"     == "Y" ]] && ui::bullet "System user (www-data)"
    echo
    ui::prompt_yn _FINAL_CONFIRM "Are you absolutely sure? This is your last chance." "N"
    [[ "$_FINAL_CONFIRM" != "Y" ]] && { ui::warn "Cancelled."; ui::press_any; return 0; }

    log::section "PTERODACTYL PANEL DELETE"

    ui::subsection "Stopping Services"
    ui::spinner_start "Stopping Queue Worker"
    systemctl stop pteroq 2>/dev/null || true; systemctl disable pteroq 2>/dev/null || true
    ui::spinner_stop "ok" "Queue Worker stopped"
    ui::spinner_start "Stopping Nginx"
    systemctl stop nginx 2>/dev/null || true
    ui::spinner_stop "ok" "Nginx stopped"

    [[ "$RM_CRON" == "Y" ]] && {
        ui::subsection "Removing Cron Job"
        (crontab -l 2>/dev/null | grep -v "pterodactyl") | crontab - 2>/dev/null || true
        ui::status "Cron job removed" "ok"; log::ok "Cron removed"
    }
    [[ "$RM_QUEUE" == "Y" ]] && {
        ui::subsection "Removing Queue Worker"
        _rm "pteroq service file" rm -f /etc/systemd/system/pteroq.service
        systemctl daemon-reload 2>/dev/null || true
    }
    [[ "$RM_SSL" == "Y" ]] && {
        ui::subsection "Removing SSL Certificates"
        if sys::cmd_exists certbot; then
            ui::spinner_start "Removing Certbot certificates"
            certbot delete --non-interactive 2>/dev/null || true
            ui::spinner_stop "ok" "SSL certificates removed"; log::ok "SSL certs removed"
        else
            ui::status "Certbot not installed — skipping" "skip"
        fi
    }
    [[ "$RM_NGINX" == "Y" ]] && {
        ui::subsection "Removing Nginx Configuration"
        _rm "Nginx site (sites-enabled)"   rm -f /etc/nginx/sites-enabled/pterodactyl.conf
        _rm "Nginx site (sites-available)" rm -f /etc/nginx/sites-available/pterodactyl.conf
        ui::spinner_start "Reloading Nginx"
        systemctl reload nginx 2>/dev/null || true
        ui::spinner_stop "ok" "Nginx reloaded"
    }
    [[ "$RM_DATABASE" == "Y" ]] && {
        ui::subsection "Removing Database"
        mysql -u root 2>/dev/null <<-MYSQL || ui::warn "MySQL errors — DB may already be removed."
            DROP DATABASE IF EXISTS ${PANEL_DB};
            DROP USER IF EXISTS '${PANEL_DB_USER}'@'127.0.0.1';
            FLUSH PRIVILEGES;
MYSQL
        ui::status "Database + user removed" "ok"; log::ok "DB removed: ${PANEL_DB}"
    }
    [[ "$RM_REDIS" == "Y" ]] && {
        ui::subsection "Removing Redis Configuration"
        ui::spinner_start "Flushing Redis"
        redis-cli FLUSHALL 2>/dev/null || true
        ui::spinner_stop "ok" "Redis flushed"; log::ok "Redis flushed"
    }
    [[ "$RM_FILES" == "Y" ]] && {
        ui::subsection "Removing Panel Files"
        _rm "Panel directory" rm -rf "$PANEL_DIR"
    }
    [[ "$RM_USER" == "Y" ]] && {
        ui::subsection "Removing System User"
        ui::spinner_start "Removing www-data user"
        userdel -r www-data 2>/dev/null || true
        ui::spinner_stop "ok" "User removed"; log::ok "User www-data removed"
    }

    echo; ui::divider; echo
    ui::ok "${BOLD}Pterodactyl Panel has been removed.${RESET}"
    log::ok "Pterodactyl Panel removal complete."
    ui::press_any
}

# ================================================================
# ④ WINGS — INSTALL
# ================================================================
wings_install() {
    clear; ui::banner; ui::section "INSTALL WINGS"
    sys::detect_os; sys::print_os_info

    ui::subsection "Dependency Check"
    local NEED_DOCKER=false NEED_CURL=false NEED_TAR=false
    sys::cmd_exists docker && ui::check_item "Docker"       "ok" || { NEED_DOCKER=true; ui::check_item "Docker"       "fail"; }
    sys::cmd_exists curl   && ui::check_item "curl"         "ok" || { NEED_CURL=true;   ui::check_item "curl"         "fail"; }
    sys::cmd_exists tar    && ui::check_item "tar"          "ok" || { NEED_TAR=true;    ui::check_item "tar"          "fail"; }
                              ui::check_item "Wings binary" "fail"
    echo

    ui::subsection "Installing Required Packages"
    sys::pkg_update
    [[ "$NEED_CURL" == "true" ]] && _run "Installing curl" bash -c "$PKG_INSTALL curl"
    [[ "$NEED_TAR"  == "true" ]] && _run "Installing tar"  bash -c "$PKG_INSTALL tar"

    if [[ "$NEED_DOCKER" == "true" ]]; then
        ui::subsection "Installing Docker"
        _run "Installing Docker (official script)" bash -c \
            "curl -sSL https://get.docker.com/ | CHANNEL=stable bash"
        _run "Enabling Docker service" systemctl enable --now docker
        ui::status "Docker installed" "ok"; log::ok "Docker installed"
    else
        ui::info "Docker already installed — ensuring service is running..."
        _run_no_fail "Starting Docker" systemctl enable --now docker
    fi

    ui::subsection "Configuring Firewall Rules"
    if sys::cmd_exists ufw; then
        _run_no_fail "UFW: allow SSH"          bash -c "ufw allow 22/tcp"
        _run_no_fail "UFW: allow Wings (2022)" bash -c "ufw allow 2022/tcp"
        _run_no_fail "UFW: reload"             bash -c "ufw --force enable && ufw reload"
    elif sys::cmd_exists firewall-cmd; then
        _run_no_fail "Firewall: SSH"           bash -c "firewall-cmd --permanent --add-service=ssh"
        _run_no_fail "Firewall: Wings port"    bash -c "firewall-cmd --permanent --add-port=2022/tcp"
        _run_no_fail "Firewall: reload"        bash -c "firewall-cmd --reload"
    fi

    ui::subsection "Downloading Wings"
    local WINGS_VERSION ARCH WINGS_ARCH
    WINGS_VERSION=$(curl -fsSL --max-time 10 \
        "https://api.github.com/repos/pterodactyl/wings/releases/latest" 2>/dev/null \
        | grep '"tag_name"' | head -1 \
        | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' || echo "latest")
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  WINGS_ARCH="amd64" ;;
        aarch64) WINGS_ARCH="arm64" ;;
        armv7l)  WINGS_ARCH="arm"   ;;
        *)       WINGS_ARCH="amd64" ;;
    esac
    ui::info "Wings version : ${BRIGHT_YELLOW}${WINGS_VERSION}${RESET}"
    ui::info "Architecture  : ${BRIGHT_YELLOW}${ARCH} → ${WINGS_ARCH}${RESET}"
    echo
    mkdir -p "$WINGS_DIR"
    _run "Downloading Wings binary" curl -fsSL -o "$WINGS_BIN" \
        "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${WINGS_ARCH}"
    _run "Setting binary permissions" chmod u+x "$WINGS_BIN"

    ui::subsection "Wings Configuration"
    echo -e "  ${BRIGHT_WHITE}${BOLD}Choose configuration method:${RESET}"
    echo
    ui::menu_item "1" "Paste config.yml from Panel Admin → Nodes → Configuration"
    ui::menu_item "2" "Enter Panel URL + Node UUID + Token (auto-generate)"
    ui::menu_exit  "Back"
    echo
    local CONFIG_METHOD WINGS_PANEL_URL=""
    ui::menu_choice CONFIG_METHOD

    case "$CONFIG_METHOD" in
        "1")
            ui::subsection "Paste config.yml"
            echo -e "  ${DIM}Go to: Panel Admin → Nodes → Your Node → Configuration${RESET}"
            echo -e "  ${DIM}Paste the full config.yml below, then press ${BRIGHT_WHITE}Ctrl+D${RESET}${DIM} on a new line:${RESET}"
            echo; ui::divider
            local CONFIG_CONTENT; CONFIG_CONTENT=$(cat)
            ui::divider; echo
            if [[ -z "$CONFIG_CONTENT" ]]; then
                ui::fail "No content pasted. Aborting."
                ui::press_any; return 1
            fi
            mkdir -p "$WINGS_DIR"
            echo "$CONFIG_CONTENT" > "${WINGS_DIR}/config.yml"
            ui::status "config.yml saved" "ok"; log::ok "config.yml saved from paste"
            if sys::cmd_exists python3; then
                ui::spinner_start "Validating YAML..."
                if python3 -c "import yaml; yaml.safe_load(open('${WINGS_DIR}/config.yml'))" >> "$LOG_FILE" 2>&1; then
                    ui::spinner_stop "ok" "YAML validation passed"
                else
                    ui::spinner_stop "warn" "YAML validation warning (continuing)"
                fi
            fi ;;
        "2")
            ui::subsection "Auto-Generate config.yml"
            local WINGS_NODE_UUID WINGS_TOKEN_ID WINGS_TOKEN
            ui::prompt WINGS_PANEL_URL  "Panel URL (e.g. https://panel.example.com)"
            ui::prompt WINGS_NODE_UUID  "Node UUID"
            ui::prompt WINGS_TOKEN_ID   "Token ID"
            ui::prompt WINGS_TOKEN      "Token"
            WINGS_PANEL_URL="${WINGS_PANEL_URL%/}"
            ui::spinner_start "Generating config.yml..."
            mkdir -p "$WINGS_DIR" /var/lib/pterodactyl/volumes /var/log/pterodactyl
            cat > "${WINGS_DIR}/config.yml" <<YAML
debug: false
uuid: ${WINGS_NODE_UUID}
token_id: ${WINGS_TOKEN_ID}
token: ${WINGS_TOKEN}
api:
  host: 0.0.0.0
  port: 8080
  ssl:
    enabled: false
    cert: /etc/letsencrypt/live/node.example.com/fullchain.pem
    key:  /etc/letsencrypt/live/node.example.com/privkey.pem
  upload_limit: 100
system:
  data: /var/lib/pterodactyl/volumes
  sftp:
    bind_port: 2022
remote: ${WINGS_PANEL_URL}
allowed_mounts: []
remote_query:
  timeout: 30
  boot_servers_per_page: 50
YAML
            ui::spinner_stop "ok" "config.yml generated"; log::ok "config.yml generated" ;;
        "0") ui::warn "Going back."; return 0 ;;
        *) ui::fail "Invalid option."; ui::press_any; return 1 ;;
    esac

    ui::subsection "Installing Wings Service"
    cat > "$WINGS_SERVICE" <<'UNIT'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
UNIT
    _run "Reloading systemd"       systemctl daemon-reload
    _run "Enabling Wings service"  systemctl enable wings
    _run "Starting Wings service"  systemctl start wings

    ui::subsection "Verifying Wings"
    sleep 3
    systemctl is-active --quiet wings \
        && ui::status "Wings service running"     "ok" || ui::status "Wings service (check log)" "warn"
    [[ -f "$WINGS_BIN" ]] \
        && ui::status "Wings binary present"      "ok" || ui::status "Wings binary missing"      "fail"
    [[ -f "${WINGS_DIR}/config.yml" ]] \
        && ui::status "config.yml present"        "ok" || ui::status "config.yml missing"        "fail"
    systemctl is-active --quiet docker \
        && ui::status "Docker running"            "ok" || ui::status "Docker not running"         "warn"
    if [[ -n "$WINGS_PANEL_URL" ]]; then
        ui::spinner_start "Testing Panel connection..."
        if curl -sf --max-time 8 "${WINGS_PANEL_URL}" > /dev/null 2>&1; then
            ui::spinner_stop "ok" "Panel reachable"; log::ok "Panel reachable: ${WINGS_PANEL_URL}"
        else
            ui::spinner_stop "warn" "Panel not reachable — check URL and firewall"
        fi
    fi

    echo; ui::divider; echo
    echo -e "  ${BRIGHT_GREEN}${BOLD}${SYM_STAR}  Wings installed successfully!  ${SYM_STAR}${RESET}"
    echo
    ui::summary_row "Wings binary"  "$WINGS_BIN"
    ui::summary_row "Config file"   "${WINGS_DIR}/config.yml"
    ui::summary_row "Service name"  "wings"
    ui::summary_row "Log file"      "${LOG_FILE}"
    echo
    ui::info "Check Wings logs: ${BRIGHT_YELLOW}journalctl -u wings -f${RESET}"
    ui::info "In Panel: Admin → Nodes → Your Node → verify ${BRIGHT_GREEN}Online${RESET}"
    log::ok "Wings installation complete."
    ui::press_any
}

# ================================================================
# ⑤ WINGS — UPDATE
# ================================================================
wings_update() {
    clear; ui::banner; ui::section "UPDATE WINGS"
    sys::detect_os

    if [[ ! -f "$WINGS_BIN" ]]; then
        ui::fail "Wings binary not found at ${WINGS_BIN}."
        ui::warn "Is Wings installed?"; ui::press_any; return 0
    fi

    local CURRENT_VER LATEST_VER _CONFIRM _FORCE
    CURRENT_VER=$("$WINGS_BIN" --version 2>/dev/null | grep -oP '[\d.]+' | head -1 || echo "unknown")
    LATEST_VER=$(curl -fsSL --max-time 10 \
        "https://api.github.com/repos/pterodactyl/wings/releases/latest" 2>/dev/null \
        | grep '"tag_name"' | head -1 \
        | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' || echo "unknown")

    ui::info "Current version : ${BRIGHT_YELLOW}${CURRENT_VER}${RESET}"
    ui::info "Latest release  : ${BRIGHT_YELLOW}${LATEST_VER}${RESET}"
    echo

    if [[ "$CURRENT_VER" == "$LATEST_VER" ]]; then
        ui::ok "Wings is already up to date."
        ui::prompt_yn _FORCE "Force re-download anyway?" "N"
        [[ "$_FORCE" != "Y" ]] && { ui::press_any; return 0; }
    fi

    ui::prompt_yn _CONFIRM "Proceed with update?" "Y"
    [[ "$_CONFIRM" != "Y" ]] && { ui::warn "Update cancelled."; ui::press_any; return 0; }

    log::section "WINGS UPDATE"

    ui::subsection "Stopping Wings"
    _run "Stopping Wings service" systemctl stop wings
    ui::status "Wings stopped" "ok"

    ui::subsection "Backing Up Current Binary"
    local BACKUP_BIN="${WINGS_BIN}.bak.$(date +%Y%m%d%H%M%S)"
    _run "Backing up binary" cp "$WINGS_BIN" "$BACKUP_BIN"
    ui::info "Backup: ${DIM}${BACKUP_BIN}${RESET}"

    ui::subsection "Downloading Latest Wings"
    local ARCH WINGS_ARCH
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  WINGS_ARCH="amd64" ;;
        aarch64) WINGS_ARCH="arm64" ;;
        armv7l)  WINGS_ARCH="arm"   ;;
        *)       WINGS_ARCH="amd64" ;;
    esac
    ui::info "Architecture: ${BRIGHT_YELLOW}${ARCH} → ${WINGS_ARCH}${RESET}"
    _run "Downloading Wings binary" curl -fsSL -o "$WINGS_BIN" \
        "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${WINGS_ARCH}"
    _run "Setting binary permissions" chmod u+x "$WINGS_BIN"

    ui::subsection "Verifying Configuration"
    [[ -f "${WINGS_DIR}/config.yml" ]] \
        && { ui::status "config.yml intact" "ok"; log::ok "config.yml preserved"; } \
        || { ui::status "config.yml not found — Wings may not start" "warn"; log::warn "config.yml missing"; }

    ui::subsection "Restarting Wings"
    _run "Starting Wings service" systemctl start wings
    sleep 3

    ui::subsection "Verifying Update"
    local NEW_VER
    NEW_VER=$("$WINGS_BIN" --version 2>/dev/null | grep -oP '[\d.]+' | head -1 || echo "unknown")
    systemctl is-active --quiet wings \
        && ui::status "Wings service running" "ok" || ui::status "Wings service not running — check logs" "fail"
    ui::summary_row "Previous version" "${CURRENT_VER}"
    ui::summary_row "Updated version"  "${NEW_VER}"
    ui::summary_row "Binary backup"    "${BACKUP_BIN}"
    ui::summary_row "Config file"      "${WINGS_DIR}/config.yml  (preserved)"

    echo
    ui::info "Check logs: ${BRIGHT_YELLOW}journalctl -u wings -f${RESET}"
    echo
    ui::ok "${BOLD}Wings updated successfully!${RESET}"
    log::ok "Wings updated: ${CURRENT_VER} → ${NEW_VER}"
    ui::press_any
}

# ================================================================
# ⑥ WINGS — DELETE
# ================================================================
wings_delete() {
    clear; ui::banner; ui::section "DELETE WINGS"
    sys::detect_os

    echo -e "  ${BRIGHT_RED}${BOLD}WARNING: This will permanently remove Wings!${RESET}"
    echo -e "  ${DIM}Running servers will be stopped. Cannot be undone.${RESET}"
    echo
    local _CONFIRM
    ui::prompt_yn _CONFIRM "Are you sure you want to remove Wings?" "N"
    [[ "$_CONFIRM" != "Y" ]] && { ui::warn "Cancelled."; ui::press_any; return 0; }

    ui::subsection "Select Components to Remove"
    echo -e "  ${DIM}Press${RESET} ${BRIGHT_GREEN}Y${RESET} ${DIM}to remove, ${RESET}${RED}N${RESET} ${DIM}to keep:${RESET}"
    echo
    local RM_BINARY RM_CONFIG RM_SERVICE RM_DOCKER RM_DOCKER_IMG RM_DOCKER_CTR RM_DOCKER_VOL _FINAL
    ui::prompt_yn RM_BINARY     "Remove Wings binary (${WINGS_BIN})?"      "Y"
    ui::prompt_yn RM_CONFIG     "Remove Wings config.yml?"                  "Y"
    ui::prompt_yn RM_SERVICE    "Remove Wings systemd service?"             "Y"
    ui::prompt_yn RM_DOCKER     "Remove Docker (engine + CLI)?"             "N"
    ui::prompt_yn RM_DOCKER_IMG "Remove all Docker images?"                 "N"
    ui::prompt_yn RM_DOCKER_CTR "Remove all Docker containers?"             "N"
    ui::prompt_yn RM_DOCKER_VOL "Remove all Docker volumes (server data!)?" "N"

    echo
    ui::subsection "Removal Summary"
    [[ "$RM_BINARY"     == "Y" ]] && ui::bullet "Wings binary:    ${WINGS_BIN}"
    [[ "$RM_CONFIG"     == "Y" ]] && ui::bullet "config.yml:      ${WINGS_DIR}/config.yml"
    [[ "$RM_SERVICE"    == "Y" ]] && ui::bullet "Systemd service: wings.service"
    [[ "$RM_DOCKER"     == "Y" ]] && ui::bullet "Docker engine + CLI"
    [[ "$RM_DOCKER_IMG" == "Y" ]] && ui::bullet "All Docker images"
    [[ "$RM_DOCKER_CTR" == "Y" ]] && ui::bullet "All Docker containers"
    [[ "$RM_DOCKER_VOL" == "Y" ]] && {
        echo
        echo -e "  ${BRIGHT_RED}${BOLD}  ⚠  WARNING: Removing volumes will DELETE all server data!${RESET}"
        echo
    }
    echo
    ui::prompt_yn _FINAL "Confirm removal of selected components?" "N"
    [[ "$_FINAL" != "Y" ]] && { ui::warn "Cancelled."; ui::press_any; return 0; }

    log::section "WINGS DELETE"

    ui::subsection "Stopping Wings"
    ui::spinner_start "Stopping Wings service"
    systemctl stop wings 2>/dev/null || true; systemctl disable wings 2>/dev/null || true
    ui::spinner_stop "ok" "Wings service stopped"; log::ok "Wings stopped"

    [[ "$RM_DOCKER_CTR" == "Y" ]] && {
        ui::subsection "Removing Docker Containers"
        ui::spinner_start "Stopping all containers"
        docker stop "$(docker ps -aq 2>/dev/null)" 2>/dev/null || true
        ui::spinner_stop "ok" "Containers stopped"
        _rm "All Docker containers" bash -c \
            "docker rm -f \$(docker ps -aq 2>/dev/null) 2>/dev/null || true"
    }
    [[ "$RM_DOCKER_VOL" == "Y" ]] && {
        ui::subsection "Removing Docker Volumes"
        _rm "All Docker volumes" bash -c \
            "docker volume rm \$(docker volume ls -q 2>/dev/null) 2>/dev/null || true"
        _rm "Pterodactyl data dir" rm -rf /var/lib/pterodactyl/volumes
    }
    [[ "$RM_DOCKER_IMG" == "Y" ]] && {
        ui::subsection "Removing Docker Images"
        _rm "All Docker images" bash -c \
            "docker rmi -f \$(docker images -aq 2>/dev/null) 2>/dev/null || true"
    }
    [[ "$RM_SERVICE" == "Y" ]] && {
        ui::subsection "Removing Wings Service"
        _rm "Wings service file" rm -f "$WINGS_SERVICE"
        ui::spinner_start "Reloading systemd"
        systemctl daemon-reload 2>/dev/null || true
        ui::spinner_stop "ok" "systemd reloaded"
    }
    [[ "$RM_CONFIG" == "Y" ]] && {
        ui::subsection "Removing Wings Configuration"
        _rm "config.yml" rm -f "${WINGS_DIR}/config.yml"
        rmdir "$WINGS_DIR" 2>/dev/null || true
        ui::status "Wings config directory removed (if empty)" "ok"
    }
    [[ "$RM_BINARY" == "Y" ]] && {
        ui::subsection "Removing Wings Binary"
        _rm "Wings binary" rm -f "$WINGS_BIN"
    }
    [[ "$RM_DOCKER" == "Y" ]] && {
        ui::subsection "Removing Docker"
        case "$OS_ID" in
            ubuntu|debian)
                _rm "Docker engine (apt)" bash -c \
                    "apt-get purge -y docker-ce docker-ce-cli containerd.io \
                     docker-buildx-plugin docker-compose-plugin 2>/dev/null || \
                     apt-get purge -y docker.io 2>/dev/null || true"
                _rm "Docker residual data" bash -c "rm -rf /var/lib/docker /etc/docker" ;;
            almalinux|rocky)
                _rm "Docker engine (dnf)" bash -c \
                    "dnf remove -y docker-ce docker-ce-cli containerd.io \
                     docker-buildx-plugin docker-compose-plugin 2>/dev/null || true"
                _rm "Docker residual data" bash -c "rm -rf /var/lib/docker /etc/docker" ;;
        esac
        rm -f /var/run/docker.sock 2>/dev/null || true
        log::ok "Docker removed"
    }

    echo; ui::divider; echo
    ui::ok "${BOLD}Wings has been removed.${RESET}"
    log::ok "Wings removal complete."
    ui::press_any
}

# ================================================================
# SUB-MENUS
# ================================================================
menu_panel() {
    local choice
    while true; do
        clear; ui::banner; ui::section "PTERODACTYL PANEL"
        ui::menu_item "1" "Install Panel"
        ui::menu_item "2" "Update Panel"
        ui::menu_item "3" "Delete Panel"
        ui::menu_exit  "Back to main menu"
        ui::menu_choice choice
        case "$choice" in
            1) panel_install ;;
            2) panel_update  ;;
            3) panel_delete  ;;
            0) return 0 ;;
            *) ui::warn "Invalid choice." ;;
        esac
    done
}

menu_wings() {
    local choice
    while true; do
        clear; ui::banner; ui::section "WINGS"
        ui::menu_item "1" "Install Wings"
        ui::menu_item "2" "Update Wings"
        ui::menu_item "3" "Delete Wings"
        ui::menu_exit  "Back to main menu"
        ui::menu_choice choice
        case "$choice" in
            1) wings_install ;;
            2) wings_update  ;;
            3) wings_delete  ;;
            0) return 0 ;;
            *) ui::warn "Invalid choice." ;;
        esac
    done
}

# ================================================================
# MAIN MENU
# ================================================================
main_menu() {
    local choice
    while true; do
        clear; ui::banner
        echo -e "  ${BRIGHT_WHITE}${BOLD}What do you want to manage?${RESET}"
        echo
        ui::menu_item "1" "Pterodactyl Panel  ${DIM}(install / update / delete)${RESET}"
        ui::menu_item "2" "Wings              ${DIM}(install / update / delete)${RESET}"
        echo
        ui::menu_item "3" "View log file"
        ui::menu_exit  "Exit"
        ui::menu_choice choice
        case "$choice" in
            1) menu_panel ;;
            2) menu_wings ;;
            3) clear; ui::banner; ui::section "LOG FILE"
               echo -e "  ${DIM}${LOG_FILE}${RESET}"; echo
               tail -50 "$LOG_FILE" 2>/dev/null || ui::warn "Log file not found."
               ui::press_any ;;
            0) clear
               echo -e "\n  ${BRIGHT_YELLOW}${SYM_STAR}${RESET}  Goodbye!\n"
               exit 0 ;;
            *) ui::warn "Invalid choice." ;;
        esac
    done
}

# ================================================================
# ENTRY POINT
# ================================================================

# Root check
if [[ $EUID -ne 0 ]]; then
    echo
    echo -e "  ${BRIGHT_RED}✗${RESET}  Must be run as root."
    echo -e "  Run: ${BRIGHT_YELLOW}sudo bash pterodactyl.sh${RESET}"
    echo -e "  Or:  ${BRIGHT_YELLOW}bash <(curl -sSL https://raw.githubusercontent.com/${GH_USER}/${GH_REPO}/${GH_BRANCH}/pterodactyl.sh)${RESET}"
    echo
    exit 1
fi

# Internet check
clear
echo
echo -e "  ${BRIGHT_CYAN}●${RESET}  Checking connectivity..."
if ! curl -sf --max-time 8 https://github.com > /dev/null 2>&1; then
    echo -e "  ${BRIGHT_RED}✗${RESET}  Cannot reach GitHub. Check your internet connection."
    exit 1
fi
echo -e "  ${BRIGHT_GREEN}✓${RESET}  Connected"

# Logger init
logger::init

# Launch
main_menu
