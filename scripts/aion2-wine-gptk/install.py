#!/usr/bin/env python3
"""Build and stage the AION 2 Wine/Rosetta compatibility fix for NotProton.

The installer changes only the NotProton launcher and a dedicated library path.
It does not modify game files, Steam credentials, or the Wine prefix.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from datetime import datetime


ROOT = Path(__file__).resolve().parent
HOME = Path.home()
SUPPORT = HOME / "Library/Application Support/notproton"
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


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("install", "status", "uninstall"))
    args = parser.parse_args()

    if not RUN.is_file():
        raise SystemExit(f"No se encontró el lanzador libre de NotProton: {RUN}")
    source = RUN.read_text()
    has_block = BLOCK in source
    has_markers = BEGIN in source or END in source

    if args.action == "status":
        print(f"Lanzador: {'configurado' if has_block else 'sin configurar'}")
        print(f"Módulo: {'instalado' if LIBRARY.is_file() else 'ausente'}")
        print(f"Wine: {SUPPORT.joinpath('runners/current').resolve()}")
        return

    if args.action == "install":
        if has_markers and not has_block:
            raise SystemExit("El bloque existente cambió; no se modificó el lanzador.")
        if not has_block and source.count(ANCHOR) != 1:
            raise SystemExit("No se encontró un punto único para aplicar el cambio.")
        subprocess.run(["make", "test", "all"], cwd=ROOT, check=True)
        LIBRARY.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / "build/compat_cpuid.dylib", LIBRARY)
        if not has_block:
            backup = RUN.with_name("run.before-aion2-" + datetime.now().strftime("%Y%m%d-%H%M%S"))
            shutil.copy2(RUN, backup)
            atomic_write(RUN, source.replace(ANCHOR, ANCHOR + "\n" + BLOCK, 1))
            print(f"Copia del lanzador: {backup}")
        print(f"Módulo instalado: {LIBRARY}")
        print("AION 2 puede iniciarse desde Steam para macOS.")
        return

    if not has_block:
        raise SystemExit("Este instalador no encuentra su bloque; no se modificó el lanzador.")
    atomic_write(RUN, source.replace(BLOCK + "\n", "", 1))
    LIBRARY.unlink(missing_ok=True)
    print("Cambio retirado del lanzador. Los archivos del juego siguen intactos.")


if __name__ == "__main__":
    main()
