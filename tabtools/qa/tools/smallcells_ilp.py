#!/usr/bin/env python3
"""Exact disclosure check for slashN Table 1 count blocks (smallcells).

An attacker who reads only the published table: every printed count, every
"<k" (1..k-1) and ">=k" bound, every printed n/denominator, the group and
Total N headers and the Total column. Each true count is an integer unknown;
the published cells are linear constraints. A count whose true value is
1..k-1 is leaked when the published constraints pin it to that one value
(its integer minimum equals its integer maximum). Solved exactly with
scipy.optimize.milp. The package's own masks are never read.

  gen   --dir D --n N --seed S   write N random small tables (case_###.csv)
                                 and cases.csv (one row per case: id, vars,
                                 options, k)
  check --dir D --status F       read case_###.csv and the published table
                                 case_###_table.csv (or case_###_refused),
                                 write "PASS ..." or "FAIL ..." lines to F

Table semantics checked (tabtools 2.5.2): row 0 holds column labels, row 1
the N headers; a categorical variable is a header row then one row per
non-missing level (ascending); a binary variable is one row holding the
positive count. Under slashN the denominator of a cell is the column's
non-missing count of that variable (categorical without catrowperc, and
binary with or without it).
"""
import argparse
import csv
import os
import random
import re
import sys

import numpy as np
from scipy.optimize import Bounds, LinearConstraint, milp

GE = "≥"
# A count nothing bounds from above has no maximum; the cap stands in for
# infinity (far above any table here), so such a count reads as unpinned
# instead of making the solver report "unbounded".
CAP = 10**6


def gen(args):
    rng = random.Random(args.seed)
    os.makedirs(args.dir, exist_ok=True)
    rows = []
    for case in range(1, args.n + 1):
        k = rng.choice([3, 3, 4])
        nvars = rng.choice([1, 1, 2])
        types = [rng.choice(["cat", "bin"]) for _ in range(nvars)]
        catrowperc = all(t == "bin" for t in types) and rng.random() < 0.5
        total = rng.random() < 0.6
        sizes = [rng.randint(2, 12) for _ in range(3)]
        data = []
        for g, size in enumerate(sizes, start=1):
            for _ in range(size):
                vals = []
                for t in types:
                    if rng.random() < 0.15:
                        vals.append("")
                    elif t == "cat":
                        vals.append(str(rng.choice([1, 1, 2, 3, 3])))
                    else:
                        vals.append(str(int(rng.random() < 0.7)))
                data.append([str(g)] + vals)
        # every categorical needs at least two observed levels and a binary
        # both values somewhere, or table1_tc reshapes the block
        ok = True
        for j, t in enumerate(types):
            seen = {r[j + 1] for r in data if r[j + 1] != ""}
            if len(seen) < 2:
                ok = False
        if not ok:
            data[0][1:] = ["1" if t == "cat" else "0" for t in types]
            data[1][1:] = ["3" if t == "cat" else "1" for t in types]
        names = [f"v{j + 1}" for j in range(nvars)]
        with open(os.path.join(args.dir, f"case_{case:03d}.csv"), "w", newline="") as fh:
            w = csv.writer(fh)
            w.writerow(["g"] + names)
            w.writerows(data)
        spec = " \\ ".join(f"{n} {t}" for n, t in zip(names, types))
        opts = "slashN" + (" catrowperc" if catrowperc else "") + (" total(after)" if total else "")
        rows.append([f"{case:03d}", spec, opts, str(k)])
    with open(os.path.join(args.dir, "cases.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["id", "vars", "opts", "k"])
        w.writerows(rows)


def parse_part(text, k):
    """(lo, hi) bounds for one published number; None when nothing is shown."""
    text = text.strip()
    if text == "" or text == "Suppressed":
        return None
    if text == f"<{k}":
        return (1, k - 1)
    if text == f"{GE}{k}":
        return (k, None)
    m = re.fullmatch(r"N=([0-9,]+)", text)
    if m:
        v = int(m.group(1).replace(",", ""))
        return (v, v)
    if re.fullmatch(r"[0-9,]+", text):
        v = int(text.replace(",", ""))
        return (v, v)
    raise ValueError(f"unparsed published cell {text!r}")


def parse_cell(text, k):
    """(count bounds, denominator bounds) of one published cell."""
    text = text.strip()
    if "/" in text:
        a, b = text.split("/", 1)
        return parse_part(a, k), parse_part(b, k)
    return parse_part(text, k), None


class Model:
    def __init__(self):
        self.nvar = 0
        self.truth = []
        self.names = []
        self.rows = []  # (coef dict, lo, hi)

    def var(self, name, true):
        self.names.append(name)
        self.truth.append(true)
        self.nvar += 1
        return self.nvar - 1

    def add(self, idx, bounds):
        if bounds is None:
            return
        lo, hi = bounds
        self.rows.append(({i: 1 for i in idx}, lo, hi))

    def matrices(self):
        a = np.zeros((len(self.rows), self.nvar))
        lo = np.full(len(self.rows), -np.inf)
        hi = np.full(len(self.rows), np.inf)
        for r, (coef, l, h) in enumerate(self.rows):
            for i, c in coef.items():
                a[r, i] = c
            if l is not None:
                lo[r] = l
            if h is not None:
                hi[r] = h
        return a, lo, hi


def solve(model, target, sense):
    a, lo, hi = model.matrices()
    c = np.zeros(model.nvar)
    c[target] = sense
    res = milp(c, constraints=LinearConstraint(a, lo, hi),
               integrality=np.ones(model.nvar),
               bounds=Bounds(np.zeros(model.nvar), np.full(model.nvar, CAP)))
    if not res.success:
        raise RuntimeError(f"ILP failed for {model.names[target]}: {res.message}")
    return round(res.x[target])


def check_case(dirn, cid, spec, opts, k):
    data = list(csv.DictReader(open(os.path.join(dirn, f"case_{cid}.csv"))))
    table = list(csv.reader(open(os.path.join(dirn, f"case_{cid}_table.csv"), encoding="utf-8")))
    header, body = table[0], table[1:]
    gcols = [i for i, h in enumerate(header) if re.fullmatch(r"g_[0-9]+", h)]
    tcol = header.index("g_T") if "g_T" in header else None
    groups = sorted({int(r["g"]) for r in data})
    if len(gcols) != len(groups):
        raise ValueError(f"case {cid}: {len(gcols)} group columns for {len(groups)} groups")
    vars_ = [tuple(p.split()) for p in spec.split("\\")]
    model = Model()
    ntrue = {g: sum(1 for r in data if int(r["g"]) == g) for g in groups}
    nidx = {g: model.var(f"N[{g}]", ntrue[g]) for g in groups}
    nrow = body[1]
    for g, col in zip(groups, gcols):
        model.add([nidx[g]], parse_part(nrow[col], k))
    if tcol is not None:
        model.add(list(nidx.values()), parse_part(nrow[tcol], k))
    protected = []
    r = 2
    for name, typ in vars_:
        vals = {g: [row[name] for row in data if int(row["g"]) == g] for g in groups}
        if typ == "cat":
            levels = sorted({int(v) for g in groups for v in vals[g] if v != ""})
            r += 1  # variable header row
            cells = {}
            for lev in levels:
                for g in groups:
                    t = sum(1 for v in vals[g] if v != "" and int(v) == lev)
                    cells[lev, g] = model.var(f"{name}={lev}[{g}]", t)
            rows_for = {lev: body[r + i] for i, lev in enumerate(levels)}
            r += len(levels)
            units = [[cells[lev, g] for lev in levels] for g in groups]
            parts = {lev: [cells[lev, g] for g in groups] for lev in levels}
        else:
            levels = [1]
            cells = {}
            neg = {}
            for g in groups:
                cells[1, g] = model.var(f"{name}=1[{g}]", sum(1 for v in vals[g] if v == "1"))
                neg[g] = model.var(f"{name}=0[{g}]", sum(1 for v in vals[g] if v == "0"))
            rows_for = {1: body[r]}
            r += 1
            units = [[cells[1, g], neg[g]] for g in groups]
            parts = {1: [cells[1, g] for g in groups]}
            protected += [neg[g] for g in groups]
        miss = {}
        for gi, g in enumerate(groups):
            miss[g] = model.var(f"{name}=.[{g}]", sum(1 for v in vals[g] if v == ""))
            # group N = non-missing + missing (the N header is shared)
            model.rows.append(({**{i: 1 for i in units[gi]}, miss[g]: 1, nidx[g]: -1}, 0, 0))
        protected += list(miss.values()) + list(cells.values())
        for lev in levels:
            row = rows_for[lev]
            for gi, (g, col) in enumerate(zip(groups, gcols)):
                cnt, den = parse_cell(row[col], k)
                model.add([cells[lev, g]], cnt)
                model.add(units[gi], den)
            if tcol is not None:
                cnt, den = parse_cell(row[tcol], k)
                model.add(parts[lev], cnt)
                model.add([i for u in units for i in u], den)
    # the truth must satisfy every published constraint (parser sanity)
    x = np.array(model.truth, dtype=float)
    a, lo, hi = model.matrices()
    ax = a @ x
    if np.any(ax < lo - 1e-9) or np.any(ax > hi + 1e-9):
        bad = int(np.argmax((ax < lo - 1e-9) | (ax > hi + 1e-9)))
        raise ValueError(f"case {cid}: true counts violate published constraint {bad}")
    leaks = []
    for i in protected:
        t = model.truth[i]
        if 0 < t < k:
            if solve(model, i, 1) == solve(model, i, -1):
                leaks.append(f"{model.names[i]}={t}")
    return leaks


def check(args):
    cases = list(csv.DictReader(open(os.path.join(args.dir, "cases.csv"))))
    lines = []
    nleak = ncheck = nref = 0
    for c in cases:
        cid = c["id"]
        if os.path.exists(os.path.join(args.dir, f"case_{cid}_refused")):
            nref += 1
            continue
        try:
            leaks = check_case(args.dir, cid, c["vars"], c["opts"], int(c["k"]))
        except Exception as exc:  # a parse failure is a test failure, never a pass
            lines.append(f"FAIL case {cid}: {exc}")
            continue
        ncheck += 1
        if leaks:
            nleak += 1
            lines.append(f"FAIL case {cid} ({c['vars']}; {c['opts']}; k={c['k']}): leaked {' '.join(leaks)}")
    fails = [l for l in lines if l.startswith("FAIL")]
    head = (f"PASS checked={ncheck} refused={nref} leaks=0" if not fails
            else f"FAIL checked={ncheck} refused={nref} leaking={nleak} errors={len(fails) - nleak}")
    with open(args.status, "w") as fh:
        fh.write("\n".join([head] + lines) + "\n")
    print(head)
    for l in lines[:20]:
        print(l)


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("gen")
    g.add_argument("--dir", required=True)
    g.add_argument("--n", type=int, required=True)
    g.add_argument("--seed", type=int, required=True)
    c = sub.add_parser("check")
    c.add_argument("--dir", required=True)
    c.add_argument("--status", required=True)
    args = ap.parse_args()
    gen(args) if args.cmd == "gen" else check(args)


if __name__ == "__main__":
    sys.exit(main())
