#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--upstream", type=Path, required=True)
    args = p.parse_args()

    total = 0
    for difficulty in ("easy", "medium", "hard"):
        root = args.upstream / "challenges" / difficulty
        rows = sorted(x.parent.parent.name for x in root.glob("*/starter/starter.cu"))
        total += len(rows)
        print(f"\n{difficulty.upper()} ({len(rows)})")
        for row in rows:
            print(f"  {difficulty}_{row}")
    print(f"\nTOTAL: {total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
