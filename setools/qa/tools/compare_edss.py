#!/usr/bin/env python3
"""Independent oracle for setools cdp / sustainedss / pira, and comparator.

The algorithms below are transcribed from the documented contracts in
cdp.sthlp, sustainedss.sthlp, and pira.sthlp -- NOT from the .ado source. That
independence is the point: an oracle that reaches the expected value through
the same mechanism as the code shares its wrong semantics and is structurally
blind. Every rule here should be traceable to a sentence in a help file.

Reads the randomized panel the Stata driver exported, recomputes each case by
brute force, and compares against the driver's exported results. Writes the
success report ONLY on exact parity, and exits nonzero otherwise, so a stale or
truncated result file cannot be mistaken for a pass.

Python 3 standard library only.
"""

from __future__ import annotations

import argparse
import csv
import sys
from collections import defaultdict
from pathlib import Path


# ---------------------------------------------------------------------------
# Shared baseline / threshold rules (cdp.sthlp "What the command does", 1-2)
# ---------------------------------------------------------------------------

def baseline(visits, dxday, window):
    """First EDSS within `window` days of diagnosis; else the earliest
    available measurement. The lowest score is used on same-day ties."""
    inwin = [(d, e) for d, e in visits if dxday <= d <= dxday + window]
    pool = inwin if inwin else visits
    first = min(d for d, e in pool)
    return first, min(e for d, e in pool if d == first)


def thresh(base, threetier):
    """Two-tier: >=1.0 if baseline <=5.5, else >=0.5.
    Three-tier: >=1.5 if baseline is 0, >=1.0 if 1.0-5.5, >=0.5 if >5.5."""
    if threetier:
        if base == 0:
            return 1.5
        return 1.0 if base <= 5.5 else 0.5
    return 1.0 if base <= 5.5 else 0.5


def confirm(visits, cand, confirmdays, target, ctype):
    """Return (confirmed, confirming_date, confirming_edss).

    sustained: the MINIMUM EDSS across all measurements at or after
      cand+confirmdays must meet baseline+threshold.
    visit: only the EDSS at the FIRST visit at least confirmdays after the
      candidate must meet it (later dips ignored).
    At least one measurement must exist at or after cand+confirmdays.
    """
    later = [(d, e) for d, e in visits if d >= cand + confirmdays]
    if not later:
        return False, None, None
    fd = min(d for d, e in later)
    fe = min(e for d, e in later if d == fd)
    crit = fe if ctype == "visit" else min(e for d, e in later)
    return crit >= target, fd, fe


def cdp_one(visits, dxday, window, confirmdays, threetier, ctype):
    """First confirmed progression date, or None."""
    bdate, bedss = baseline(visits, dxday, window)
    th = thresh(bedss, threetier)
    for c in sorted({d for d, e in visits if e - bedss >= th and d > bdate}):
        ok, _, _ = confirm(visits, c, confirmdays, bedss + th, ctype)
        if ok:
            return c
    return None


def cdp_roving_events(visits, dxday, window, confirmdays, threetier, ctype):
    """All roving events as (event_day, baseline_edss_at_event).

    cdp.sthlp: "After an event confirms, the actual EDSS and date of that
    confirming assessment become the reference for the next event; visits
    through that date are not reused."
    """
    bdate, bedss = baseline(visits, dxday, window)
    cur, events = list(visits), []
    for _ in range(len(visits) + 2):
        th = thresh(bedss, threetier)
        hit = None
        for c in sorted({d for d, e in cur if e - bedss >= th and d > bdate}):
            ok, cd, ce = confirm(cur, c, confirmdays, bedss + th, ctype)
            if ok:
                hit = (c, cd, ce)
                break
        if hit is None:
            return events
        c, cd, ce = hit
        events.append((c, bedss))
        bdate, bedss = cd, ce
        cur = [(d, e) for d, e in cur if d > cd]
        if not cur:
            return events
    raise ValueError("roving oracle failed to converge")


def sustained_one(visits, threshold, confirmwindow, mode, floor):
    """First sustained threshold crossing, or None.

    Same-date duplicates collapse to the lowest EDSS. Default mode accepts a
    candidate when no later observed EDSS is below the floor, including when
    there is no later visit. window/unlimited require an observed later visit.
    A rejected candidate is removed and the next crossing is tested.
    """
    byday = {}
    for d, e in visits:
        byday[d] = min(e, byday.get(d, e))
    vs = sorted(byday.items())
    banned = set()
    while True:
        cands = [d for d, e in vs if e >= threshold and d not in banned]
        if not cands:
            return None
        c = min(cands)
        later = [(d, e) for d, e in vs if d > c]
        inwin = [(d, e) for d, e in later if d <= c + confirmwindow]
        if mode == "":
            ok = (not later) or min(e for d, e in later) >= floor
        else:
            pool = inwin if mode == "window" else later
            if not pool:
                ok = False
            else:
                nd = min(d for d, e in pool)
                ne = min(e for d, e in pool if d == nd)
                ok = ne >= threshold and min(e for d, e in pool) >= floor
        if ok:
            return c
        banned.add(c)


def pira_one(visits, dxday, window, confirmdays, threetier, ctype,
             relapse_days, wbefore, wafter):
    """Classify the first confirmed CDP as PIRA or RAW.

    pira.sthlp: the window runs from windowbefore() days before a relapse to
    windowafter() days after. A first CDP outside every window is PIRA; one
    inside any window is RAW.
    """
    c = cdp_one(visits, dxday, window, confirmdays, threetier, ctype)
    if c is None:
        return None, None
    raw = any(r - wbefore <= c <= r + wafter for r in relapse_days)
    return (None, c) if raw else (c, None)


# ---------------------------------------------------------------------------
# Comparison driver
# ---------------------------------------------------------------------------

def num(v):
    v = (v or "").strip()
    return None if v in ("", ".") else int(round(float(v)))


def load_panel(path):
    if not path.is_file() or path.stat().st_size == 0:
        raise ValueError(f"missing or empty panel: {path}")
    people, meta = defaultdict(list), {}
    with path.open(encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            pid = row["id"]
            people[pid].append((int(row["day"]), float(row["edss"])))
            meta[pid] = (int(row["dxday"]), num(row.get("exitday")))
    if not people:
        raise ValueError(f"zero panel rows: {path}")
    for pid in people:
        people[pid].sort()
    return people, meta


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--panel", type=Path, required=True)
    ap.add_argument("--relapses", type=Path)
    ap.add_argument("--actual", type=Path, required=True)
    ap.add_argument("--report", type=Path, required=True)
    args = ap.parse_args()

    people, meta = load_panel(args.panel)

    relapses = defaultdict(list)
    if args.relapses and args.relapses.is_file():
        with args.relapses.open(encoding="utf-8", newline="") as fh:
            for row in csv.DictReader(fh):
                relapses[row["id"]].append(int(row["rday"]))

    if not args.actual.is_file() or args.actual.stat().st_size == 0:
        raise ValueError(f"missing or empty actual results: {args.actual}")
    actual = defaultdict(dict)
    rov = defaultdict(lambda: defaultdict(list))
    with args.actual.open(encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            case, pid = row["case"], row["id"]
            if case.split("|")[0] == "rov":
                rov[case][pid].append(
                    (num(row["b"]), num(row["a"]), float(row["c"])))
            else:
                actual[case][pid] = (num(row["a"]), num(row["b"]))
    if not actual and not rov:
        raise ValueError(f"zero comparison rows: {args.actual}")

    compared, mismatches = 0, []
    for case in sorted(set(actual) | set(rov)):
        spec = case.split("|")
        kind = spec[0]
        for pid in people:
            dxday, exitday = meta[pid]
            if kind == "rov":
                win, cd, tt, ct = int(spec[1]), int(spec[2]), int(spec[3]), spec[4]
                want = cdp_roving_events(people[pid], dxday, win, cd, bool(tt), ct)
                got = [(d, b) for _, d, b in sorted(rov[case].get(pid, []))]
            else:
                if kind == "cdp":
                    win, cd, tt, ct, ux = (int(spec[1]), int(spec[2]),
                                           int(spec[3]), spec[4], int(spec[5]))
                    r = cdp_one(people[pid], dxday, win, cd, bool(tt), ct)
                    if r is not None and ux and exitday is not None and r > exitday:
                        r = None
                    want = (r, None)
                elif kind == "ss":
                    th, cw, md, fl, ux = (float(spec[1]), int(spec[2]), spec[3],
                                          float(spec[4]), int(spec[5]))
                    r = sustained_one(people[pid], th, cw, md, fl)
                    if r is not None and ux and exitday is not None and r > exitday:
                        r = None
                    want = (r, None)
                elif kind == "pira":
                    win, cd, tt, ct = int(spec[1]), int(spec[2]), int(spec[3]), spec[4]
                    wb, wa = int(spec[5]), int(spec[6])
                    want = pira_one(people[pid], dxday, win, cd, bool(tt), ct,
                                    relapses[pid], wb, wa)
                else:
                    raise ValueError(f"unknown case kind: {case}")
                if pid not in actual[case]:
                    mismatches.append(f"{case} id={pid}: absent from results")
                    compared += 1
                    continue
                got = actual[case][pid]
            compared += 1
            if want != got:
                mismatches.append(f"{case} id={pid}: oracle={want} stata={got}")

    if mismatches:
        sys.stderr.write(
            f"{len(mismatches)} mismatch(es) of {compared} comparisons\n")
        for line in mismatches[:20]:
            sys.stderr.write(f"  {line}\n")
        sys.exit(1)

    args.report.write_text(
        f"RESULT: edss_python_crossval compared={compared} mismatches=0\n",
        encoding="utf-8")


if __name__ == "__main__":
    main()
