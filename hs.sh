#!/usr/bin/env bash
# Szybkie zarządzanie sesjami Herdr (lista, otwórz/utwórz, stop, usuń)
# Parsowanie listy: awk (bez python3/node — obraz code-server ich nie ma na stałe).
set -euo pipefail

export PATH="${HOME}/.local/bin:/opt/host/bin:/usr/local/bin:${PATH}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}$*${NC}"; }
ok()    { echo -e "${GREEN}$*${NC}"; }
warn()  { echo -e "${YELLOW}$*${NC}"; }
err()   { echo -e "${RED}$*${NC}" >&2; }

require_herdr() {
    if ! command -v herdr &>/dev/null; then
        err "herdr nie jest na PATH (szukano ~/.local/bin/herdr)"
        exit 1
    fi
}

# Tekstowa lista herdr (kolumny: name status directory socket) — bez JSON/python.
sessions_table() {
    herdr session list
}

session_names() {
    sessions_table | awk 'NR > 1 && NF { print $1 }'
}

print_sessions() {
    echo ""
    echo -e "${BOLD}=== Sesje Herdr ===${NC}"
    sessions_table | awk '
    NR == 1 { next }
    NF == 0 { next }
    {
        n++
        if (n == 1) print "  #  status     nazwa"
        mark = ($1 == "default") ? " *" : ""
        printf "  %s) %-9s %s%s\n", n, $2, $1, mark
    }
    END {
        if (n == 0) print "  (brak sesji)"
    }
    '
}

# UI na stderr — wynik (nazwa) tylko na stdout, żeby $(...) nie łapało listy.
pick_session_name() {
    local prompt="${1:-Sesja}"
    local names=()
    mapfile -t names < <(session_names)
    if [ "${#names[@]}" -eq 0 ]; then
        err "Brak sesji"
        return 1
    fi
    print_sessions >&2
    echo "" >&2
    local CHOICE
    read -r -p "$prompt [numer lub nazwa]: " CHOICE
    if [ -z "$CHOICE" ]; then
        warn "Anulowano" >&2
        return 1
    fi
    if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#names[@]}" ]; then
        echo "${names[$((CHOICE - 1))]}"
        return 0
    fi
    echo "$CHOICE"
}

session_running() {
    local name="$1"
    local status
    status="$(sessions_table | awk -v n="$name" 'NR > 1 && $1 == n { print $2; found=1; exit } END { if (!found) exit 2 }')" || {
        local rc=$?
        return "$rc"
    }
    [ "$status" = "running" ]
}

open_session() {
    local name="${1:-}"
    if [ -z "$name" ]; then
        read -r -p "Sesja (Enter = default, nowa nazwa = utwórz): " name
        name="${name:-default}"
    fi
    exec herdr --session "$name"
}

attach_session() {
    local name
    name="$(pick_session_name "Dołącz do sesji")" || return 0
    info "Attach: $name"
    exec herdr session attach "$name"
}

stop_session() {
    local name
    name="$(pick_session_name "Zatrzymaj sesję")" || return 0
    if [ "$name" = "default" ]; then
        warn "Sesji default nie zatrzymuję bez potwierdzenia."
        local CONFIRM
        read -r -p "Wpisz default aby potwierdzić: " CONFIRM
        [ "$CONFIRM" = "default" ] || { warn "Anulowano"; return 0; }
    fi
    info "Stop: $name"
    herdr session stop "$name"
    ok "Zatrzymano $name"
}

delete_session() {
    local name
    name="$(pick_session_name "Usuń sesję")" || return 0
    name="${name//$'\r'/}"
    name="${name#"${name%%[![:space:]]*}"}"
    name="${name%"${name##*[![:space:]]}"}"
    if [ "$name" = "default" ]; then
        err "Nie usuwam sesji default"
        return 1
    fi
    echo ""
    warn "Usunięcie kasuje katalog sesji (~/.config/herdr/sessions/$name)."
    local CONFIRM
    read -r -p "Aby potwierdzić, wpisz nazwę sesji ($name): " CONFIRM
    if [ "$CONFIRM" != "$name" ]; then
        warn "Anulowano"
        return 0
    fi
    if session_running "$name"; then
        info "Sesja działa — najpierw stop"
        herdr session stop "$name"
    fi
    herdr session delete "$name"
    ok "Usunięto $name"
}

stop_and_delete() {
    delete_session
}

# Skrócone menu: numer = sesja, litery = akcje.
show_menu() {
    local names=()
    mapfile -t names < <(session_names)

    echo ""
    echo -e "${BOLD}Herdr — sesje${NC}"
    print_sessions
    echo ""
    echo "  [numer]  otwórz sesję"
    echo "  n        nowa / po nazwie"
    echo "  a        dołącz (attach)"
    echo "  s        zatrzymaj"
    echo "  d        usuń"
    echo "  x        zatrzymaj i usuń"
    echo "  q        wyjście"
    echo ""

    local CHOICE
    read -r -p "Wybierz: " CHOICE
    case "${CHOICE:-}" in
        ""|q|Q|0)
            echo "Do widzenia."
            exit 0
            ;;
        n|N)
            open_session
            ;;
        a|A)
            attach_session
            ;;
        s|S)
            stop_session
            ;;
        d|D)
            delete_session
            ;;
        x|X)
            stop_and_delete
            ;;
        *)
            if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#names[@]}" ]; then
                open_session "${names[$((CHOICE - 1))]}"
            elif [[ "$CHOICE" =~ ^[0-9]+$ ]]; then
                warn "Brak sesji nr $CHOICE"
            else
                # nazwa wpisana wprost
                open_session "$CHOICE"
            fi
            ;;
    esac
}

run_menu() {
    while true; do
        show_menu
        # tu wracamy tylko po stop/delete (open/attach robią exec)
        echo ""
        read -r -p "Enter…" _
    done
}

usage() {
    cat <<'EOF'
Użycie: hs [komenda] [nazwa]

Bez argumentów — skrócone menu (numer = otwórz sesję).

  open [nazwa]         otwórz lub utwórz sesję
  list                 lista sesji
  menu                 to samo co bez argumentów
  attach [nazwa]       dołącz do istniejącej
  stop <nazwa>         zatrzymaj
  delete <nazwa>       usuń (najpierw stop, jeśli działa)

Szybki start:  hs
               hs 5
               hs platforma
EOF
}

main() {
    require_herdr
    case "${1:-menu}" in
        -h|--help|help) usage; return 0 ;;
        list|ls) print_sessions ;;
        open|start)
            shift || true
            open_session "${1:-}"
            ;;
        attach)
            shift || true
            if [ -n "${1:-}" ]; then
                exec herdr session attach "$1"
            fi
            attach_session
            ;;
        stop)
            shift || true
            if [ -n "${1:-}" ]; then
                herdr session stop "$1"
                ok "Zatrzymano $1"
                return 0
            fi
            stop_session
            ;;
        delete|rm)
            shift || true
            if [ -n "${1:-}" ]; then
                name="$1"
                if session_running "$name"; then
                    herdr session stop "$name"
                fi
                herdr session delete "$name"
                ok "Usunięto $name"
                return 0
            fi
            delete_session
            ;;
        menu) run_menu ;;
        *)
            if [[ "$1" =~ ^- ]]; then
                err "Nieznana komenda: $1"
                usage
                exit 1
            fi
            # hs <nazwa|numer> — od razu otwórz
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                local names=()
                mapfile -t names < <(session_names)
                if [ "$1" -ge 1 ] && [ "$1" -le "${#names[@]}" ]; then
                    open_session "${names[$(($1 - 1))]}"
                else
                    err "Brak sesji nr $1"
                    exit 1
                fi
            else
                open_session "$1"
            fi
            ;;
    esac
}

main "$@"
