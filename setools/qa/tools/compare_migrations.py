#!/usr/bin/env python3
"""Independent oracle for setools migrations, and comparator.

The exclusion rules, boundary conventions, and censoring definition below are
transcribed from migrations.sthlp -- NOT from migrations.ado. That independence
is the point: the defect fixed in 1.5.5 (a person who immigrated before study
start and emigrated permanently after it silently lost migration_out_dt)
survived a 34-suite green lane precisely because every expectation in that lane
was hand-authored alongside the implementation.

Also checks that wide- and long-format migration files produce identical
results for the same history -- the 1.5.4 divergence that was a symptom of the
same defect.

Python 3 standard library only.
"""

from __future__ import annotations

import argparse
import csv
import sys
from collections import defaultdict
from pathlib import Path


# ---------------------------------------------------------------------------
# Oracle, from migrations.sthlp
#
# Boundary conventions, quoted from the help file:
#   an immigration dated ON the study-start date counts as being in Sweden
#     at baseline            (the immigration test is in  <= start)
#   an emigration dated ON the start date does not count as emigrating before
#     baseline               (the pre-start emigration test is out <  start)
#   censoring dates are recorded only for emigrations strictly after study
#     start                  (out > start)
# ---------------------------------------------------------------------------

def classify(events, start, minresidence, keepimmigrants):
    """Return the exclusion type, or None if the person is retained."""
    ins = sorted(d for d, k in events if k == "in")
    outs = sorted(d for d, k in events if k == "out")

    pre_out = max((d for d in outs if d < start), default=None)
    pre_in = max((d for d in ins if d <= start), default=None)
    post_in = min((d for d in ins if d > start), default=None)
    last_out = max(outs, default=None)
    last_in = max(ins, default=None)

    # Type 1: emigrated before study start and never returned.
    if (last_out is not None and last_out < start
            and (last_in is None or last_in < last_out)):
        return "emigrated"

    # Type 4: most recent immigration before study start was too recent.
    # Persons with no immigration record (born in Sweden) always pass.
    if (minresidence > 0 and pre_in is not None
            and (start - pre_in) < minresidence):
        return "minresidence"

    # Type 3: abroad at baseline -- emigrated before start and returned after.
    if (pre_out is not None and post_in is not None
            and (pre_in is None or pre_in < pre_out)):
        return "abroad"

    # Type 2: no migration event before study start, and the first migration
    # event after study start is an immigration. A later emigration does not
    # change this. Retained instead of excluded under keepimmigrants.
    pre_events = [d for d in ins if d <= start] + [d for d in outs if d < start]
    if not pre_events:
        post = sorted([(d, "in") for d in ins if d > start]
                      + [(d, "out") for d in outs if d >= start])
        if post and post[0][1] == "in":
            return None if keepimmigrants else "inmigration"
    return None


def censor_date(events, start):
    """First emigration strictly after study start with no later return."""
    ins = [d for d, k in events if k == "in"]
    outs = sorted(d for d, k in events if k == "out")
    for o in outs:
        if o > start and not any(i > o for i in ins):
            return o
    return None


def immigration_date(events, start):
    """Post-start immigration date recorded for a retained Type 2 person."""
    ins = sorted(d for d, k in events if k == "in")
    return min((d for d in ins if d > start), default=None)


# ---------------------------------------------------------------------------
# Comparison driver
# ---------------------------------------------------------------------------

def num(v):
    v = (v or "").strip()
    return None if v in ("", ".") else int(round(float(v)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--events", type=Path, required=True)
    ap.add_argument("--starts", type=Path, required=True)
    ap.add_argument("--actual", type=Path, required=True)
    ap.add_argument("--report", type=Path, required=True)
    args = ap.parse_args()

    for path in (args.events, args.starts, args.actual):
        if not path.is_file() or path.stat().st_size == 0:
            raise ValueError(f"missing or empty CSV: {path}")

    events = defaultdict(list)
    with args.events.open(encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            events[row["id"]].append((int(row["day"]), row["kind"].strip()))
    for pid in events:
        events[pid].sort()

    starts = {}
    with args.starts.open(encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            starts[row["id"]] = int(row["start"])
    if not starts:
        raise ValueError(f"zero cohort rows: {args.starts}")

    actual = defaultdict(dict)
    with args.actual.open(encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            actual[row["case"]][row["id"]] = (
                num(row["censor_day"]), num(row["inmig_day"]),
                int(float(row["mig_excluded"])))
    if not actual:
        raise ValueError(f"zero comparison rows: {args.actual}")

    compared, mismatches = 0, []
    for case in sorted(actual):
        fmt, minres, keepimm, flag = case.split("|")
        minres, keepimm, flag = int(minres), bool(int(keepimm)), bool(int(flag))
        rows = actual[case]
        for pid, start in starts.items():
            ev = events.get(pid, [])
            reason = classify(ev, start, minres, keepimm)
            want_censor = censor_date(ev, start)
            want_inmig = None
            if keepimm and classify(ev, start, minres, False) == "inmigration":
                want_inmig = immigration_date(ev, start)
            compared += 1
            present = pid in rows

            if flag:
                # flag retains every cohort member and marks the excluded ones.
                if not present:
                    mismatches.append(f"{case} id={pid}: dropped under flag")
                    continue
                censor, inmig, excluded = rows[pid]
                if excluded != int(reason is not None):
                    mismatches.append(
                        f"{case} id={pid}: excluded oracle="
                        f"{int(reason is not None)} stata={excluded}")
                elif reason is None and censor != want_censor:
                    mismatches.append(
                        f"{case} id={pid}: censor oracle={want_censor} "
                        f"stata={censor}")
                continue

            if reason is not None:
                if present:
                    mismatches.append(
                        f"{case} id={pid}: retained but should be "
                        f"excluded ({reason})")
                continue
            if not present:
                mismatches.append(f"{case} id={pid}: dropped but should be kept")
                continue
            censor, inmig, _ = rows[pid]
            if censor != want_censor:
                mismatches.append(
                    f"{case} id={pid}: censor oracle={want_censor} "
                    f"stata={censor}")
            elif keepimm and inmig != want_inmig:
                mismatches.append(
                    f"{case} id={pid}: inmig oracle={want_inmig} stata={inmig}")

    # Wide and long files describing the same history must agree exactly.
    wide = {c for c in actual if c.startswith("wide|")}
    equiv_checked = 0
    for wcase in sorted(wide):
        lcase = "long|" + wcase.split("|", 1)[1]
        if lcase not in actual:
            continue
        equiv_checked += 1
        ids = set(actual[wcase]) | set(actual[lcase])
        for pid in sorted(ids):
            compared += 1
            if actual[wcase].get(pid) != actual[lcase].get(pid):
                mismatches.append(
                    f"wide/long divergence {wcase[5:]} id={pid}: "
                    f"wide={actual[wcase].get(pid)} long={actual[lcase].get(pid)}")

    if equiv_checked == 0:
        raise ValueError("no wide/long case pair was available to compare")

    if mismatches:
        sys.stderr.write(
            f"{len(mismatches)} mismatch(es) of {compared} comparisons\n")
        for line in mismatches[:20]:
            sys.stderr.write(f"  {line}\n")
        sys.exit(1)

    args.report.write_text(
        f"RESULT: migrations_python_crossval compared={compared} "
        f"mismatches=0 equivalence_pairs={equiv_checked}\n",
        encoding="utf-8")


if __name__ == "__main__":
    main()
