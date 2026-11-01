#!/bin/sh
# Instalator hs — menu sesji Herdr.
#
#   curl -fsSL https://raw.githubusercontent.com/bartlomiejszwakop/herdr-hs/main/install.sh | sh
#
# Kładzie jeden skrypt w PATH. Bez sudo: ~/.local/bin. Z rootem: /usr/local/bin.
# Zmienne: HS_REPO, HS_REF (domyślnie main), PREFIX.

set -eu

REPO="${HS_REPO:-bartlomiejszwakop/herdr-hs}"
REF="${HS_REF:-main}"

czerwony() { printf '\033[31m%s\033[0m\n' "$1" >&2; }
info()     { printf '%s\n' "$1" >&2; }

koniec() {
  czerwony "instalacja przerwana: $1"
  exit 1
}

command -v curl >/dev/null 2>&1 || koniec "brak curl-a"

if [ -n "${PREFIX:-}" ]; then
  CEL="$PREFIX/bin"
elif [ "$(id -u)" = "0" ]; then
  CEL="/usr/local/bin"
else
  CEL="$HOME/.local/bin"
fi
mkdir -p "$CEL" || koniec "nie mogę utworzyć $CEL"

ROBOCZY="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$ROBOCZY'" EXIT INT TERM

URL="https://raw.githubusercontent.com/$REPO/$REF/hs.sh"
info "Pobieram hs z $REPO ($REF)..."
curl -fsSL "$URL" -o "$ROBOCZY/hs" || koniec "nie udało się pobrać $URL"

head -n 1 "$ROBOCZY/hs" | grep -q '^#!' || koniec "pobrany plik nie wygląda na skrypt"

chmod 755 "$ROBOCZY/hs"
mv "$ROBOCZY/hs" "$CEL/hs" || koniec "nie mogę zapisać do $CEL"

info ""
info "Gotowe: $CEL/hs"

case ":$PATH:" in
  *":$CEL:"*) ;;
  *) info ""
     info "UWAGA: $CEL nie jest w PATH. Dopisz do ~/.bashrc lub ~/.profile:"
     info "    export PATH=\"$CEL:\$PATH\"" ;;
esac

if ! command -v herdr >/dev/null 2>&1; then
  info ""
  info "hs wymaga herdr na PATH (szuka też ~/.local/bin/herdr)."
  info "Zainstaluj herdr, potem: hs"
fi

info ""
info "Uruchom:  hs"
