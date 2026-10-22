#!/usr/bin/env python3
"""Build the AION 2 Wine/Rosetta fix into the free NotProton Steam bridge.

Run install/uninstall with Steam closed. Status can be checked while Steam runs.
Game files and credentials are never changed.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from datetime import datetime
import hashlib


ROOT = Path(__file__).resolve().parent
HOME = Path.home()
SUPPORT = HOME / "Library/Application Support/notproton"
SOURCE_ROOT = HOME / "Library/Caches/notproton-free/src"
SOURCE_RUN = SOURCE_ROOT / "dylib/feats/compat_run.sh"
BUILT_DYLIB = SOURCE_ROOT / "out/notproton.dylib"
STEAM_APP = Path("/Applications/Steam.app")
STEAM_DYLIB = STEAM_APP / "Contents/MacOS/notproton.dylib"
RUN = HOME / "Library/Application Support/Steam/compatibilitytools.d/notproton/run"
LIBRARY = SUPPORT / "aion2-compat/compat_cpuid.dylib"
BEGIN = "# BEGIN AION 2 Rosetta compatibility fix"
END = "# END AION 2 Rosetta compatibility fix"
ANCHOR = 'export WINEDEBUG="${WINEDEBUG:-err+all,fixme-all}"'
BLOCK = f"""{BEGIN}
if [ "$app_id" = 3393110 ]; then
  aion2_compat="$HOME/Library/Application Support/notproton/aion2-compat/compat_cpuid.dylib"
  if [ -f "$aion2_compat" ]; then
    export STEAM_DYLD_INSERT_LIBRARIES="$aion2_compat${{STEAM_DYLD_INSERT_LIBRARIES:+:$STEAM_DYLD_INSERT_LIBRARIES}}"
  fi
fi
{END}"""
RETINA_BEGIN = "# BEGIN AION 2 non-Retina default"
RETINA_END = "# END AION 2 non-Retina default"
RETINA_ANCHOR = 'NOTPROTON_RETINA="${NOTPROTON_RETINA:-1}"'
RETINA_BLOCK = f"""{RETINA_BEGIN}
if [ "$app_id" = 3393110 ]; then
  NOTPROTON_RETINA=0
fi
{RETINA_END}"""
NATIVE_OVERLAY_BEGIN = "# BEGIN AION 2 native Steam overlay exclusion"
NATIVE_OVERLAY_END = "# END AION 2 native Steam overlay exclusion"
NATIVE_OVERLAY_BLOCK = f"""{NATIVE_OVERLAY_BEGIN}
if [ "$app_id" = 3393110 ]; then
  aion2_libraries=
  aion2_saved_ifs=$IFS
  IFS=:
  for aion2_library in $STEAM_DYLD_INSERT_LIBRARIES; do
    case "$aion2_library" in
      */gameoverlayrenderer.dylib) ;;
      *) aion2_libraries="$aion2_libraries${{aion2_libraries:+:}}$aion2_library" ;;
    esac
  done
  IFS=$aion2_saved_ifs
  export STEAM_DYLD_INSERT_LIBRARIES="$aion2_libraries"
fi
{NATIVE_OVERLAY_END}"""
ESYNC_BEGIN = "# BEGIN AION 2 esync compatibility test"
ESYNC_END = "# END AION 2 esync compatibility test"
ESYNC_ANCHOR = 'case "$app_id" in \'\'|*[!0-9]*) app_id=0 ;; esac'
ESYNC_BLOCK = f"""{ESYNC_BEGIN}
if [ "$app_id" = 3393110 ]; then
  export WINEESYNC=0
  echo "aion2: WINEESYNC=0" >> "$log" 2>&1 || true
fi
{ESYNC_END}"""
PREVIOUS_NATIVE_OVERLAY_BLOCK = NATIVE_OVERLAY_BLOCK.replace(
    '  export STEAM_DYLD_INSERT_LIBRARIES="$aion2_libraries"',
    '''  export STEAM_DYLD_INSERT_LIBRARIES="$aion2_libraries"
  case ",$WINEDEBUG," in
    *,+seh,*) ;;
    *) export WINEDEBUG="$WINEDEBUG,+seh" ;;
  esac''',
)
SHIM_ANCHOR = 'if [ -f "\\$shim" ]; then'
SHIM_MARKER = '# AION 2: skip NotProton Metal overlay shim'
SHIM_BLOCK = f'''{SHIM_MARKER}
if [ "\\$STEAM_COMPAT_APP_ID" != 3393110 ] && [ -f "\\$shim" ]; then'''
# The working route bypasses the bundle/shim and makes unsupported tutorial
# videos fail at initialization rather than hang in Wine's media pipeline.
DIRECT_BEGIN = "# BEGIN AION 2 raw Wine launch diagnostic"
DIRECT_END = "# END AION 2 raw Wine launch diagnostic"
DIRECT_ANCHOR = 'target="$1"'
DIRECT_BLOCK = r'''# BEGIN AION 2 raw Wine launch diagnostic
if [ "$app_id" = 3393110 ] && [ "${1##*/}" = AION2.exe ]; then
  echo "=== AION 2 raw Wine diagnostic, bundle and steam.exe wrapper omitted ===" >> "$log"
  export DYLD_INSERT_LIBRARIES="$STEAM_DYLD_INSERT_LIBRARIES"
  # AION 2 diagnostic: let video initialization fail instead of entering GStreamer.
  export WINEDLLOVERRIDES="winegstreamer=;${WINEDLLOVERRIDES}"
  echo "aion2: winegstreamer disabled (tutorial diagnostic)" >> "$log"
  exec "$WINELOADER" "$@" >> "$log" 2>&1
fi
# END AION 2 raw Wine launch diagnostic'''
RETIRED_BLOCKS = (
    ("# BEGIN AION 2 Metal translation test", "# END AION 2 Metal translation test"),
    ("# BEGIN AION 2 software video decoding test", "# END AION 2 software video decoding test"),
    ("# BEGIN AION 2 Wine media DXGI workaround", "# END AION 2 Wine media DXGI workaround"),
    ("# BEGIN AION 2 isolated Wine runner", "# END AION 2 isolated Wine runner"),
)


def same_bytes(first: Path, second: Path) -> bool:
    return (first.is_file() and second.is_file()
            and hashlib.sha256(first.read_bytes()).digest() == hashlib.sha256(second.read_bytes()).digest())


def backup(path: Path) -> Path:
    target = path.with_name(path.name + ".before-aion2-" + datetime.now().strftime("%Y%m%d-%H%M%S"))
    shutil.copy2(path, target)
    print(f"Copia: {target}")
    return target


def atomic_write(path: Path, content: str) -> None:
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        stream.write(content)
    try:
        os.chmod(temporary, path.stat().st_mode)
        subprocess.run(["sh", "-n", str(temporary)], check=True)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def edited_source(source: str, install: bool) -> str:
    source = source.replace(PREVIOUS_NATIVE_OVERLAY_BLOCK, NATIVE_OVERLAY_BLOCK)
    for begin, end in RETIRED_BLOCKS:
        if begin not in source and end not in source:
            continue
        if source.count(begin) != 1 or source.count(end) != 1:
            raise SystemExit(f"El bloque anterior {begin} cambió; no se modificó el lanzador.")
        start = source.index(begin)
        finish = source.index(end, start) + len(end)
        if source[finish:finish + 1] == "\n":
            finish += 1
        source = source[:start] + source[finish:]
    source = source.replace("GST_PLUGIN_PATH|GST_PLUGIN_FEATURE_RANK|VK_DRIVER_FILES", "GST_PLUGIN_PATH|VK_DRIVER_FILES")
    for begin, end, block, anchor, before in (
        (BEGIN, END, BLOCK, ANCHOR, False),
        (DIRECT_BEGIN, DIRECT_END, DIRECT_BLOCK, DIRECT_ANCHOR, True),
        (RETINA_BEGIN, RETINA_END, RETINA_BLOCK, RETINA_ANCHOR, True),
        (NATIVE_OVERLAY_BEGIN, NATIVE_OVERLAY_END, NATIVE_OVERLAY_BLOCK, END, False),
    ):
        marked = begin in source or end in source
        if marked and block not in source:
            raise SystemExit(f"El bloque {begin} cambió; no se modificó el lanzador.")
        if install and not marked:
            if source.count(anchor) != 1:
                raise SystemExit(f"No se encontró un punto único para {begin}.")
            insertion = block + "\n" + anchor if before else anchor + "\n" + block
            source = source.replace(anchor, insertion, 1)
        elif not install and marked:
            source = source.replace(block + "\n", "", 1)
    if SHIM_MARKER in source and SHIM_BLOCK not in source:
        raise SystemExit("La exclusión del overlay cambió; no se modificó el lanzador.")
    if install and SHIM_MARKER not in source:
        if source.count(SHIM_ANCHOR) != 1:
            raise SystemExit("No se encontró un punto único para excluir el overlay.")
        source = source.replace(SHIM_ANCHOR, SHIM_BLOCK, 1)
    elif not install and SHIM_MARKER in source:
        source = source.replace(SHIM_BLOCK, SHIM_ANCHOR, 1)
    return source


def edited_esync(source: str, enabled: bool) -> str:
    marked = ESYNC_BEGIN in source or ESYNC_END in source
    if marked and ESYNC_BLOCK not in source:
        raise SystemExit("El bloque de esync cambió; no se modificó el lanzador.")
    if enabled and not marked:
        if source.count(ESYNC_ANCHOR) != 1:
            raise SystemExit("No se encontró un punto único para esync.")
        return source.replace(ESYNC_ANCHOR, ESYNC_ANCHOR + "\n" + ESYNC_BLOCK, 1)
    if not enabled and marked:
        return source.replace(ESYNC_BLOCK + "\n", "", 1)
    return source


def steam_is_running() -> bool:
    return subprocess.run(["pgrep", "-x", "steam_osx"], capture_output=True).returncode == 0


def sign_steam() -> None:
    for path in (STEAM_DYLIB, STEAM_APP / "Contents/MacOS/steam_osx", STEAM_APP):
        subprocess.run(["codesign", "-f", "-s", "-", str(path)], check=True, capture_output=True)
    subprocess.run(["codesign", "--verify", str(STEAM_APP)], check=True, capture_output=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("install", "status", "uninstall", "esync-off", "esync-on"))
    args = parser.parse_args()

    for path in (SOURCE_RUN, STEAM_DYLIB, RUN):
        if not path.is_file():
            raise SystemExit(f"Falta un componente del NotProton libre: {path}")
    source = SOURCE_RUN.read_text()

    if args.action == "status":
        installed = RUN.read_text()
        print(f"Código fuente: {'configurado' if BLOCK in source and RETINA_BLOCK in source and NATIVE_OVERLAY_BLOCK in source and SHIM_BLOCK in source else 'sin configurar'}")
        print(f"Lanzador de Steam: {'configurado' if BLOCK in installed and RETINA_BLOCK in installed and NATIVE_OVERLAY_BLOCK in installed and SHIM_BLOCK in installed else 'sin configurar'}")
        print(f"Arranque directo y videos omitidos: {'configurado' if DIRECT_BLOCK in source and DIRECT_BLOCK in installed else 'sin configurar'}")
        print(f"Módulo: {'instalado' if LIBRARY.is_file() else 'ausente'}")
        print(f"Biblioteca integrada: {'actual' if same_bytes(BUILT_DYLIB, STEAM_DYLIB) else 'diferente'}")
        print(f"Esync para AION 2: {'desactivado (prueba)' if ESYNC_BLOCK in source and ESYNC_BLOCK in installed else 'predeterminado'}")
        return

    if steam_is_running():
        raise SystemExit("Cierra Steam completamente antes de instalar o retirar la corrección.")

    install = args.action != "uninstall"
    revised = edited_source(source, install)
    if args.action == "esync-off":
        revised = edited_esync(revised, True)
    elif args.action in ("esync-on", "uninstall"):
        revised = edited_esync(revised, False)
    if install:
        subprocess.run(["make", "test", "all"], cwd=ROOT, check=True)
    if revised != source:
        backup(SOURCE_RUN)
        atomic_write(SOURCE_RUN, revised)
    subprocess.run(["make", "all"], cwd=SOURCE_ROOT, check=True)

    if not same_bytes(BUILT_DYLIB, STEAM_DYLIB):
        backup(STEAM_DYLIB)
        shutil.copy2(BUILT_DYLIB, STEAM_DYLIB)
    sign_steam()
    if RUN.read_text() != revised:
        backup(RUN)
        atomic_write(RUN, revised)

    if install:
        LIBRARY.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / "build/compat_cpuid.dylib", LIBRARY)
        print("AION 2 configurado en el código y en Steam. Ya puedes abrir Steam.")
    else:
        LIBRARY.unlink(missing_ok=True)
        print("Corrección retirada de NotProton. Los archivos del juego siguen intactos.")


if __name__ == "__main__":
    main()
