#!/bin/bash
# Guided setup of the verified RESONANCE profile for native Steam.
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
profile="$root/scripts/resonance-wine/install.py"
steam_app=/Applications/Steam.app
steam="$HOME/Library/Application Support/Steam"
runner="$HOME/Library/Application Support/notproton/runners/current/bin/wine"
free_runner="$HOME/Library/Application Support/notproton/runners/sikarugir-11/bin/wine"
tool="$steam/compatibilitytools.d/notproton/run"
prefix="$steam/steamapps/compatdata/3259780/pfx"
game="$steam/steamapps/common/FINAL FANTASY RESONANCE/FFRS.exe"
source_url=https://github.com/Xipzer/mac-windows-gaming.git
revision=c0bbee764f4317b4bcaeea08a0fb46cb051691e7
fork_url=https://github.com/lechuit/NotProton.git
fork_ref=refs/heads/wine11-free-base
fork_revision=5b8d18683b619b66390be8cbcffc1fbf47e45971
export PATH="/opt/homebrew/bin:$PATH"

fail() { printf '%s\n' "$*" >&2; exit 1; }
pause() { printf '\n%s\nPulsa Enter para continuar.\n' "$1"; read -r _ || fail 'Vuelve a ejecutar el instalador cuando esté listo.'; }
steam_closed() {
  while /usr/bin/pgrep -x steam_osx >/dev/null; do
    pause 'Sal de Steam completamente desde su menú (⌘Q).'
  done
}
stack_ready() {
  [[ -x "$runner" && "$runner" -ef "$free_runner" && -x "$tool" && -f "$steam_app/Contents/MacOS/notproton.dylib" ]] &&
    /usr/libexec/PlistBuddy -c 'Print :LSEnvironment:DYLD_INSERT_LIBRARIES' "$steam_app/Contents/Info.plist" 2>/dev/null |
      /usr/bin/grep -Fxq "$steam_app/Contents/MacOS/notproton.dylib"
}
steam_url() { /usr/bin/open -b com.valvesoftware.steam "$1"; }

case "${1:-}" in
  --help|-h) printf 'Uso: bash Instalar-RESONANCE.command [--status]\n'; exit 0 ;;
  --status)
    stack_ready && printf 'NotProton: archivos de integración presentes\n' || printf 'NotProton: falta instalar o reparar la integración\n'
    exec python3 "$profile" status ;;
  '') ;;
  *) fail 'Usa --help para ver las opciones.' ;;
esac

[[ "$(uname -m)" == arm64 ]] || fail 'Se necesita un Mac con Apple Silicon y una Terminal ejecutada sin Rosetta.'
version="$(sw_vers -productVersion)"
(( ${version%%.*} >= 15 )) || fail 'Esta compilación de NotProton requiere macOS 15 o posterior.'
[[ -f "$profile" ]] || fail 'Descomprime el ZIP completo antes de abrir el instalador.'
if ! xcrun --find clang >/dev/null 2>&1; then
  xcode-select --install || true
  fail 'Completa la instalación de las herramientas de Apple y vuelve a abrir este instalador.'
fi

if ! stack_ready; then
  if [[ -e "$tool" || -e "$steam_app/Contents/MacOS/notproton.dylib" ]]; then
    fail 'Detecté una instalación de NotProton incompleta o distinta. Revisa la sección de reparación en RESONANCE_WINE.md antes de reemplazarla.'
  fi
  printf '%s\n' 'La instalación descarga Wine 11 e instala Steam, Rosetta, Homebrew y cmake si hacen falta.' \
    'NotProton modifica y vuelve a firmar Steam.app, guarda una copia local y se configura como herramienta predeterminada para juegos de Windows.'
  printf '¿Continuar? [s/N] '
  read -r answer
  [[ "$answer" == s || "$answer" == S ]] || exit 0
  steam_closed
  checkout="$(mktemp -d "${TMPDIR:-/tmp}/resonance-notproton.XXXXXX")"
  trap 'rm -rf -- "$checkout"' EXIT
  git -C "$checkout" init -q
  git -C "$checkout" fetch -q --depth 1 "$source_url" "$revision"
  git -C "$checkout" checkout -q --detach FETCH_HEAD
  [[ "$(git -C "$checkout" rev-parse HEAD)" == "$revision" ]] || fail 'No coincide la revisión del instalador de NotProton.'
  fork_tip="$(git ls-remote --exit-code "$fork_url" "$fork_ref" | cut -f1)"
  [[ "$fork_tip" == "$fork_revision" ]] || fail 'No coincide la revisión guardada en el fork de NotProton.'
  # Redirect only the source checkout. Keep upstream version pins and checksums.
  python3 - "$checkout/scripts/setup-notproton.sh" "$fork_url" "$fork_ref" "$fork_revision" <<'PY'
from pathlib import Path
import sys

path, url, ref, revision = sys.argv[1:]
path = Path(path)
text = path.read_text()
if text.count(f'FORK_COMMIT="{revision}"') != 1:
    raise SystemExit('No coincide la revisión de NotProton en el instalador base.')
for old, new in (
    ('FORK_URL="https://github.com/NotProtonNot/NotProton.git"', f'FORK_URL="{url}"'),
    ('FORK_REF="pull/18/head"', f'FORK_REF="{ref}"'),
):
    if text.count(old) != 1:
        raise SystemExit('Cambió la configuración del instalador base.')
    text = text.replace(old, new, 1)
path.write_text(text)
PY
  if [[ ! -d "$steam_app" ]]; then
    bash "$checkout/install.sh" --no-heroic
    pause 'Inicia sesión en Steam y deja que termine de actualizarse.'
  elif [[ ! -f "$steam/config/config.vdf" ]]; then
    /usr/bin/open -a "$steam_app"
    pause 'Inicia sesión en Steam y deja que termine de actualizarse.'
  fi
  steam_closed
  [[ -f "$steam/config/config.vdf" ]] || fail 'Abre Steam, inicia sesión y vuelve a ejecutar este instalador.'
  bash "$checkout/install.sh" --no-heroic
  stack_ready || fail 'No se pudo confirmar la instalación de NotProton.'
fi

if [[ ! -f "$game" ]]; then
  steam_url 'steam://install/3259780'
  pause 'Confirma la instalación de FINAL FANTASY RESONANCE en Steam y espera a que termine la descarga.'
  [[ -f "$game" ]] || fail 'El juego aún no está instalado en la biblioteca predeterminada. Completa la descarga y vuelve a ejecutar este instalador.'
fi

if [[ ! -f "$prefix/user.reg" || ! -f "$prefix/system.reg" ]]; then
  steam_url 'steam://rungameid/3259780'
  pause 'Deja que el primer arranque cree el entorno de Wine. Cierra el juego o el aviso de Visual C++ si aparece.'
fi

steam_closed
python3 "$profile" install
printf '\nConfiguración de RESONANCE aplicada. Abre el juego desde tu biblioteca de Steam.\n'
/usr/bin/open -a "$steam_app"
