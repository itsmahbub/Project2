#!/usr/bin/env python3

import json
import subprocess
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: replay-compile-commands.py /absolute/path/to/compile_commands.json", file=sys.stderr)
        return 1

    compile_commands = Path(sys.argv[1])
    if not compile_commands.is_file():
        print(f"compile_commands.json not found: {compile_commands}", file=sys.stderr)
        return 1

    entries = json.loads(compile_commands.read_text())
    for index, entry in enumerate(entries, start=1):
        directory = entry["directory"]
        command = entry.get("command")
        arguments = entry.get("arguments")

        print(f"[{index}/{len(entries)}] {entry['file']}", flush=True)

        if arguments:
            result = subprocess.run(arguments, cwd=directory)
        elif command:
            result = subprocess.run(command, cwd=directory, shell=True)
        else:
            print(f"Malformed entry with no command or arguments: {entry}", file=sys.stderr)
            return 1

        if result.returncode != 0:
            print(f"Compilation failed for {entry['file']} with exit code {result.returncode}", file=sys.stderr)
            return result.returncode

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
