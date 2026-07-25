#!/usr/bin/env python3
import argparse
import struct
from pathlib import Path


MAGIC = 0x31534659524F4300
PATH_SIZE = 64
RECORD_SIZE = 88
KIND_DIR = 1
KIND_FILE = 2
DATA_ALIGN = 4096


def align(value, alignment):
    return (value + alignment - 1) & ~(alignment - 1)


def record(path, kind, data=b""):
    encoded = path.encode("ascii")
    if len(encoded) >= PATH_SIZE:
        raise ValueError(f"path too long: {path}")
    return {
        "path": encoded + b"\0" * (PATH_SIZE - len(encoded)),
        "kind": kind,
        "data": data,
        "offset": 0,
    }


def arch_from_output(output):
    name = output.name
    if "aarch64" in name:
        return "aarch64"
    if "riscv64" in name:
        return "riscv64"
    raise ValueError(f"cannot infer architecture from output path: {output}")


def user_image(arch, program):
    return Path("user") / "build" / f"cory-user-{program}-{arch}.bin"


def user_image_bytes(arch, program):
    path = user_image(arch, program)
    if not path.exists():
        raise FileNotFoundError(f"missing user image: {path}")
    return path.read_bytes()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    arch = arch_from_output(args.output)

    records = [
        record("/", KIND_DIR),
        record("/bin", KIND_DIR),
        record("/etc", KIND_DIR),
        record("/etc/motd", KIND_FILE, b"hello from cory fs\n"),
        record("/bin/cat", KIND_FILE, user_image_bytes(arch, "cat")),
        record("/bin/echo", KIND_FILE, user_image_bytes(arch, "echo")),
        record("/bin/ls", KIND_FILE, user_image_bytes(arch, "ls")),
        record("/bin/ps", KIND_FILE, user_image_bytes(arch, "ps")),
        record("/bin/selftest", KIND_FILE, user_image_bytes(arch, "selftest")),
        record("/bin/shell", KIND_FILE, user_image_bytes(arch, "shell")),
    ]

    data_offset = 16 + RECORD_SIZE * len(records)
    data = bytearray()
    for entry in records:
        if entry["data"]:
            aligned_offset = align(data_offset + len(data), DATA_ALIGN)
            data.extend(b"\0" * (aligned_offset - data_offset - len(data)))
            entry["offset"] = aligned_offset
            data.extend(entry["data"])
    archive_end = data_offset + len(data)
    data.extend(b"\0" * (align(archive_end, DATA_ALIGN) - archive_end))

    out = bytearray()
    out.extend(struct.pack("<QQ", MAGIC, len(records)))
    for entry in records:
        out.extend(entry["path"])
        out.extend(struct.pack("<QQQ", entry["kind"], entry["offset"], len(entry["data"])))
    out.extend(data)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(out)


if __name__ == "__main__":
    main()
