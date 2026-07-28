#!/usr/bin/env python3
"""Add application-window sources to Wemeet's XDG Portal chooser."""

import argparse
import mmap
import os
from pathlib import Path


TARGET = Path("bin/modules/screen_share/libscreen_share_module.so")
PATCH_OFFSET = 0x43BBDB
CONTEXT_OFFSET = 0x43BBD7
CONTEXT_ORIGINAL = bytes.fromhex(
    "48 8b 7d f0 83 3f 00 48 89 b5 88 f7 ff ff 0f 85 05 00 00 00"
)
CONTEXT_PATCHED = bytes.fromhex(
    "48 8b 7d f0 83 0f 02 48 89 b5 88 f7 ff ff 0f 85 05 00 00 00"
)
INSTRUCTION_ORIGINAL = bytes.fromhex("83 3f 00")
INSTRUCTION_PATCHED = bytes.fromhex("83 0f 02")


def patch_state(mm: mmap.mmap) -> str:
    end = CONTEXT_OFFSET + len(CONTEXT_ORIGINAL)
    if len(mm) < end:
        return "unsupported"

    context = mm[CONTEXT_OFFSET:end]
    if context == CONTEXT_ORIGINAL:
        return "original"
    if context == CONTEXT_PATCHED:
        return "patched"
    return "unsupported"


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Patch Tencent Wemeet v3.26.10.401 to add application-window "
            "sources to the XDG Portal chooser."
        )
    )
    parser.add_argument(
        "install_dir",
        type=Path,
        help="Tencent Wemeet installation directory (e.g. /opt/wemeet)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate only, do not write anything",
    )
    parser.add_argument(
        "--revert",
        action="store_true",
        help="Restore the original instruction",
    )
    args = parser.parse_args()

    target = args.install_dir / TARGET
    if not target.is_file():
        raise SystemExit(f"[ERROR] File not found: {target}")

    access = mmap.ACCESS_READ if args.dry_run else mmap.ACCESS_WRITE
    mode = "rb" if args.dry_run else "r+b"
    with target.open(mode) as handle:
        with mmap.mmap(handle.fileno(), 0, access=access) as mm:
            before = patch_state(mm)
            print(f"Target: {target}")
            print(f"State:  {before}")

            if before == "unsupported":
                raise SystemExit(
                    "[ERROR] The expected instruction context was not found; "
                    "the file may be a different Wemeet version."
                )

            wanted = "original" if args.revert else "patched"
            if before == wanted:
                print(f"[OK] Already {wanted}")
                return

            action = "revert" if args.revert else "apply"
            if args.dry_run:
                print(f"[DRY-RUN] Would {action} the window-sources patch")
                return

            replacement = (
                INSTRUCTION_ORIGINAL if args.revert else INSTRUCTION_PATCHED
            )
            print(
                f"[PATCH] 0x{PATCH_OFFSET:08x}: "
                f"{mm[PATCH_OFFSET:PATCH_OFFSET + len(replacement)].hex()} "
                f"=> {replacement.hex()}"
            )
            mm[PATCH_OFFSET:PATCH_OFFSET + len(replacement)] = replacement
            mm.flush()
            os.fsync(handle.fileno())

            after = patch_state(mm)
            print(f"State:  {after}")
            if after != wanted:
                raise SystemExit(
                    f"[ERROR] Verification failed: expected {wanted}, found {after}"
                )


if __name__ == "__main__":
    main()
