#!/usr/bin/env python3
import argparse
import struct
from pathlib import Path


MAGIC = 0x31534659524F4300
PATH_SIZE = 64
RECORD_SIZE = 88
KIND_DIR = 1
KIND_FILE = 2


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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    records = [
        record("/", KIND_DIR),
        record("/bin", KIND_DIR),
        record("/etc", KIND_DIR),
        record("/etc/motd", KIND_FILE, b"hello from cory fs\n"),
        record("/bin/cat", KIND_FILE),
        record("/bin/echo", KIND_FILE),
        record("/bin/ls", KIND_FILE),
        record("/bin/ps", KIND_FILE),
        record("/bin/selftest", KIND_FILE),
        record("/bin/shell", KIND_FILE),
    ]

    data_offset = 16 + RECORD_SIZE * len(records)
    data = bytearray()
    for entry in records:
        if entry["data"]:
            entry["offset"] = data_offset + len(data)
            data.extend(entry["data"])

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
