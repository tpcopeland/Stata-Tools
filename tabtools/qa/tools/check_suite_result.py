#!/usr/bin/env python3
# Version: 1.0.0 2026/10/01
# Author: Timothy P Copeland, Karolinska Institutet
"""Require one reconciled, nonempty RESULT receipt from a Stata QA child."""

import argparse
from pathlib import Path
import re


def check_result(name, paths, allow_skip=False):
    # The suite's own fresh log is authoritative. The runner capture is used
    # only by suites that do not open their own log. Wrapped Stata output uses
    # '> ' continuation lines; source echoes begin '. ' and cannot be receipts.
    path = next((Path(p) for p in paths if Path(p).is_file()), None)
    if path is None:
        return False, "missing child log"
    text = path.read_text(encoding="utf-8", errors="replace")
    # Stata wraps at the output width even inside names and integer tokens.
    # Strip only its continuation marker, preserving the actual characters.
    text = re.sub(r"\n> ?", "", text)
    receipts = re.findall(r"^RESULT:[ \t]+" + re.escape(name) + r"[ \t]+([^\n]*)", text, re.M)
    if len(receipts) != 1:
        return False, f"expected one RESULT receipt, found {len(receipts)}"
    receipt = receipts[0]
    fields = re.fullmatch(
        r"tests=(\d+)\s+pass=(\d+)\s+fail=(\d+)(?:\s+skip=(\d+))?\s*", receipt
    )
    if fields is None:
        return False, "malformed RESULT receipt"
    tests, passed, failed = map(int, fields.group(1, 2, 3))
    skipped = int(fields.group(4) or 0)
    if tests != passed + failed + skipped:
        return False, f"unreconciled RESULT: tests={tests}, pass+fail+skip={passed + failed + skipped}"
    if tests == 0:
        return False, "empty suite has no test evidence"
    if failed:
        return False, f"RESULT reports {failed} failure(s)"
    if skipped and not allow_skip:
        return False, f"RESULT reports {skipped} skipped test(s)"
    return True, f"{tests} reconciled test(s)"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("name")
    parser.add_argument("logs", nargs="+")
    parser.add_argument("--status", required=True)
    parser.add_argument("--allow-skip", action="store_true")
    args = parser.parse_args()
    ok, message = check_result(args.name, args.logs, args.allow_skip)
    Path(args.status).write_text(("PASS" if ok else "FAIL") + "\n" + message + "\n")
    print(f"QA receipt {args.name}: {message}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
