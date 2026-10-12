#!/usr/bin/env python3
"""Create an AION 2 scoped mfplat.dll with Proton's DXGI manager workaround.

The original Wine DLL is read only. This copies it and makes the exported
MFCreateDXGIDeviceManager return E_NOTIMPL, as Proton does when its
WINE_DO_NOT_CREATE_DXGI_DEVICE_MANAGER option is enabled.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import struct
import tempfile
import os


FUNCTION = b"MFCreateDXGIDeviceManager"
EXPECTED = bytes.fromhex("66 90 56 57 53 48")
RETURN_NOT_IMPLEMENTED = bytes.fromhex("b8 01 40 00 80 c3")


def u16(data: bytes, offset: int) -> int:
    return struct.unpack_from("<H", data, offset)[0]


def u32(data: bytes, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]


def function_offset(data: bytes) -> int:
    if data[:2] != b"MZ":
        raise ValueError("El módulo no es un ejecutable PE.")
    pe = u32(data, 0x3C)
    if data[pe:pe + 4] != b"PE\0\0" or u16(data, pe + 4) != 0x8664:
        raise ValueError("Se esperaba un módulo PE x86-64.")
    count = u16(data, pe + 6)
    optional = pe + 24
    optional_size = u16(data, pe + 20)
    if u16(data, optional) != 0x20B:
        raise ValueError("Se esperaba un módulo PE32+.")
    sections = []
    for i in range(count):
        section = optional + optional_size + i * 40
        virtual_size, virtual_addr, raw_size, raw_addr = struct.unpack_from("<IIII", data, section + 8)
        sections.append((virtual_addr, max(virtual_size, raw_size), raw_addr))

    def file_offset(rva: int) -> int:
        for address, size, raw in sections:
            if address <= rva < address + size:
                result = raw + rva - address
                if result >= len(data):
                    break
                return result
        raise ValueError(f"RVA {rva:#x} fuera del módulo.")

    export_rva = u32(data, optional + 112)
    if not export_rva:
        raise ValueError("El módulo no tiene exportaciones.")
    directory = file_offset(export_rva)
    number_of_functions = u32(data, directory + 20)
    number_of_names = u32(data, directory + 24)
    functions = file_offset(u32(data, directory + 28))
    names = file_offset(u32(data, directory + 32))
    ordinals = file_offset(u32(data, directory + 36))
    for i in range(number_of_names):
        name_at = file_offset(u32(data, names + 4 * i))
        if data[name_at:name_at + len(FUNCTION) + 1] != FUNCTION + b"\0":
            continue
        ordinal = u16(data, ordinals + 2 * i)
        if ordinal >= number_of_functions:
            raise ValueError("Ordinal de exportación inválido.")
        return file_offset(u32(data, functions + 4 * ordinal))
    raise ValueError("MFCreateDXGIDeviceManager no está exportada.")


def patch(source: Path, destination: Path) -> None:
    original = source.read_bytes()
    offset = function_offset(original)
    if original[offset:offset + len(EXPECTED)] != EXPECTED:
        raise ValueError("La versión de mfplat.dll cambió; se rechazó el parche.")
    updated = bytearray(original)
    updated[offset:offset + len(RETURN_NOT_IMPLEMENTED)] = RETURN_NOT_IMPLEMENTED
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as stream:
        temporary = Path(stream.name)
        stream.write(updated)
    try:
        os.chmod(temporary, source.stat().st_mode)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)
    print(f"Copia de mfplat.dll lista: {destination}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    patch(args.source, args.destination)
