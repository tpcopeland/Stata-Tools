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


def gen_wide(args):
    """Wider grid: 2-5 groups, cat/bin/contn mixes, missing, missingsummary,
    catrowperc on any variable set, total(before|after), percent_n, and the
    primary mode (checked literally: no printed 1..k-1)."""
    rng = random.Random(args.seed)
    os.makedirs(args.dir, exist_ok=True)
    rows = []
    for case in range(1, args.n + 1):
        k = rng.choice([3, 3, 4, 5])
        ngrp = rng.choice([2, 3, 3, 4, 5])
        nvars = rng.choice([1, 1, 1, 2])
        types = [rng.choice(["cat", "cat", "bin", "bin", "contn"]) for _ in range(nvars)]
        has_cb = any(t in ("cat", "bin") for t in types)
        opts = []
        if rng.random() < 0.85:
            opts.append("slashN")
        if has_cb and rng.random() < 0.35:
            opts.append("catrowperc")
        if rng.random() < 0.6:
            opts.append(rng.choice(["total(after)", "total(before)"]))
        if "cat" in types and rng.random() < 0.35:
            opts.append("missing")
        if rng.random() < 0.3 and not (args.no_contn_missing and "contn" in types):
            opts.append("missingsummary")
        if rng.random() < 0.25:
            opts.append("percent_n")
        mode = "primary" if rng.random() < 0.1 else "full"
        pmiss = rng.choice([0.0, 0.1, 0.2, 0.3])
        sizes = [rng.randint(3, 14) for _ in range(ngrp)]
        data = []
        for g, size in enumerate(sizes, start=1):
            for _ in range(size):
                vals = []
                for t in types:
                    if rng.random() < pmiss:
                        vals.append("")
                    elif t == "cat":
                        vals.append(str(rng.choice([1, 1, 2, 3, 3])))
                    elif t == "bin":
                        vals.append(str(int(rng.random() < 0.7)))
                    else:
                        vals.append(f"{rng.gauss(0, 1):.4f}")
                data.append([str(g)] + vals)
        ok = True
        for j, t in enumerate(types):
            seen = {r[j + 1] for r in data if r[j + 1] != ""}
            if t == "contn":
                ok = ok and len(seen) >= 3
            else:
                ok = ok and len(seen) >= 2
        if not ok:
            for j, t in enumerate(types):
                data[0][j + 1] = {"cat": "1", "bin": "0", "contn": "0.5"}[t]
                data[1][j + 1] = {"cat": "3", "bin": "1", "contn": "-0.5"}[t]
                data[2][j + 1] = {"cat": "3", "bin": "1", "contn": "1.5"}[t]
        names = [f"v{j + 1}" for j in range(nvars)]
        with open(os.path.join(args.dir, f"case_{case:03d}.csv"), "w", newline="") as fh:
            w = csv.writer(fh)
            w.writerow(["g"] + names)
            w.writerows(data)
        spec = " \\ ".join(f"{n} {t}" for n, t in zip(names, types))
        rows.append([f"{case:03d}", spec, " ".join(opts), str(k), mode])
    with open(os.path.join(args.dir, "cases.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["id", "vars", "opts", "k", "mode"])
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


def parse_pct(text):
    """(integer digits, decimals) of a printed percentage, or None."""
    text = text.strip().rstrip("%").strip()
    m = re.fullmatch(r"([0-9]+)(?:\.([0-9]+))?", text)
    if not m:
        return None
    frac = m.group(2) or ""
    return int(m.group(1) + frac), len(frac)


def parse_cell(text, k, pct_first=False):
    """(count bounds, denominator bounds, percentage) of one published cell.

    Forms: "a", "a/b", "a (pct)", "a/b (pct)" and, under percent_n,
    "pct (a)" / "pct (a/b)". Each of a and b may be a number, "<k", ">=k" or
    "Suppressed".
    """
    text = text.strip()
    pct = None
    m = re.fullmatch(r"(.*?)\s*\(([^()]*)\)", text)
    if m:
        a, b = m.group(1).strip(), m.group(2).strip()
        if pct_first and parse_pct(a) is not None:
            pct, text = parse_pct(a), b
        else:
            pct, text = parse_pct(b), a
            if pct is None:
                raise ValueError(f"unparsed published cell {text!r}")
    if "/" in text:
        a, b = text.split("/", 1)
        return parse_part(a, k), parse_part(b, k), pct
    return parse_part(text, k), None, pct


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

    def add_pct(self, cnt, den, pct):
        """Printed percentage P of cnt/den: 100*cnt/den rounds to P."""
        if pct is None:
            return
        pint, dec = pct
        scale = 200 * 10 ** dec
        for sign in (1, -1):
            coef = {}
            for i in cnt:
                coef[i] = coef.get(i, 0) + scale
            for i in den:
                coef[i] = coef.get(i, 0) - (2 * pint - sign)
            self.rows.append((coef, 0, None) if sign == 1 else (coef, None, 0))
        self.rows.append(({i: 1 for i in den}, 1, None))

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


def numeric_parts(text):
    """Every printed count-like number in a cell (counts, denominators, N)."""
    t = re.sub(r"\((?![^()]*/)[^()]*\)", "", text)  # drop a "(pct)" trailer
    t = re.sub(r"[0-9]*\.[0-9]+", "", t)
    return [int(tok.replace(",", "")) for tok in re.findall(r"[0-9][0-9,]*", t)]


def check_primary(dirn, cid, k):
    """Primary mode contract: no printed count, N or denominator of 1..k-1."""
    table = list(csv.reader(open(os.path.join(dirn, f"case_{cid}_table.csv"), encoding="utf-8")))
    header, body = table[0], table[1:]
    cols = [i for i, h in enumerate(header) if re.fullmatch(r"g_([0-9]+|T)", h)]
    bad = []
    for ri, row in enumerate(body[1:], start=1):
        for c in cols:
            text = row[c]
            if "±" in text:
                continue
            for v in numeric_parts(text):
                if 1 <= v <= k - 1:
                    bad.append(f"row{ri}/{header[c]}={text.strip()}")
    return bad


def check_case(dirn, cid, spec, opts, k):
    data = list(csv.DictReader(open(os.path.join(dirn, f"case_{cid}.csv"))))
    table = list(csv.reader(open(os.path.join(dirn, f"case_{cid}_table.csv"), encoding="utf-8")))
    header, body = table[0], table[1:]
    gcols = [i for i, h in enumerate(header) if re.fullmatch(r"g_[0-9]+", h)]
    tcol = header.index("g_T") if "g_T" in header else None
    fcol = header.index("factor")
    groups = sorted({int(r["g"]) for r in data})
    if len(gcols) != len(groups):
        raise ValueError(f"case {cid}: {len(gcols)} group columns for {len(groups)} groups")
    otoks = opts.split()
    catrowperc = "catrowperc" in otoks
    pct_first = "percent_n" in otoks
    vars_ = [tuple(p.split()) for p in spec.split("\\")]
    model = Model()
    ntrue = {g: sum(1 for r in data if int(r["g"]) == g) for g in groups}
    nidx = {g: model.var(f"N[{g}]", ntrue[g]) for g in groups}
    nrow = body[1]
    for g, col in zip(groups, gcols):
        model.add([nidx[g]], parse_part(nrow[col], k))
    if tcol is not None:
        model.add(list(nidx.values()), parse_part(nrow[tcol], k))

    # a row with a non-indented label opens a block; indented rows (levels,
    # "Missing") belong to it
    blocks = []
    for row in body[2:]:
        lab = row[fcol]
        if lab[:1] not in (" ", "\t") and lab != "":
            blocks.append([row])
        elif blocks:
            blocks[-1].append(row)
    if len(blocks) != len(vars_):
        raise ValueError(f"case {cid}: {len(blocks)} table blocks for {len(vars_)} variables")

    protected = list(nidx.values())  # a group N of 1..k-1 is protected too
    allN = list(nidx.values())

    def apply(row, cnt, den, pctden=None, first=False):
        """Published constraints of one row: group columns and the Total.
        cnt(g)/den(g) give the variables of group g (None = Total)."""
        pctden = pctden or den
        for g, col in list(zip(groups, gcols)) + ([(None, tcol)] if tcol is not None else []):
            c, d, p = parse_cell(row[col], k, first)
            model.add(cnt(g), c)
            if d is not None:
                model.add(den(g), d)
            model.add_pct(cnt(g), pctden(g), p)

    for (name, typ), blk in zip(vars_, blocks):
        vals = {g: [row[name] for row in data if int(row["g"]) == g] for g in groups}
        miss = {g: model.var(f"{name}=.[{g}]", sum(1 for v in vals[g] if v == "")) for g in groups}
        protected += list(miss.values())
        mrows = [r for r in blk[1:] if r[fcol].strip() == "Missing"]
        lrows = [r for r in blk[1:] if r[fcol].strip() != "Missing"]
        if typ == "cat":
            levels = sorted({int(v) for g in groups for v in vals[g] if v != ""})
            # with the missing option the Missing row is one more level: its
            # count is part of every denominator (the denominator is then N)
            misslevel = "missing" in otoks and bool(mrows)
            if misslevel:
                lrows, mrows = lrows + mrows, []
            if len(lrows) != len(levels) + (1 if misslevel else 0):
                raise ValueError(f"case {cid}: {len(lrows)} level rows for {len(levels)} levels of {name}")
            cells = {}
            for lev in levels:
                for g in groups:
                    t = sum(1 for v in vals[g] if v != "" and int(v) == lev)
                    cells[lev, g] = model.var(f"{name}={lev}[{g}]", t)
            for g in groups:
                cells["m", g] = miss[g]
            levs = levels + (["m"] if misslevel else [])
            units = {g: [cells[lev, g] for lev in levs] for g in groups}
            protected += [cells[lev, g] for lev in levels for g in groups]
            allunits = [i for g in groups for i in units[g]]
            for lev, row in zip(levs, lrows):
                parts = [cells[lev, g] for g in groups]
                apply(row,
                      lambda g, lev=lev, parts=parts: parts if g is None else [cells[lev, g]],
                      (lambda g, parts=parts: parts) if catrowperc
                      else (lambda g: allunits if g is None else units[g]),
                      first=pct_first)
        elif typ == "bin":
            cells, neg = {}, {}
            for g in groups:
                cells[g] = model.var(f"{name}=1[{g}]", sum(1 for v in vals[g] if v == "1"))
                neg[g] = model.var(f"{name}=0[{g}]", sum(1 for v in vals[g] if v == "0"))
            units = {g: [cells[g], neg[g]] for g in groups}
            protected += list(neg.values()) + list(cells.values())
            allunits = [i for g in groups for i in units[g]]
            if lrows:
                raise ValueError(f"case {cid}: indented non-missing rows under binary {name}")
            apply(blk[0],
                  lambda g: [cells[x] for x in groups] if g is None else [cells[g]],
                  lambda g: allunits if g is None else units[g],
                  first=pct_first)
        else:  # contn: the cell shows mean and SD, so it releases only n >= k or "<k"
            ncell = {g: model.var(f"{name}.n[{g}]", sum(1 for v in vals[g] if v != "")) for g in groups}
            units = {g: [ncell[g]] for g in groups}
            protected += list(ncell.values())
            if lrows:
                raise ValueError(f"case {cid}: indented non-missing rows under continuous {name}")
            for g, col in list(zip(groups, gcols)) + ([(None, tcol)] if tcol is not None else []):
                text = blk[0][col].strip()
                idx = list(ncell.values()) if g is None else [ncell[g]]
                if "±" in text:
                    model.add(idx, (k, None))
                elif text:
                    model.add(idx, parse_part(text, k))
            allunits = [i for g in groups for i in units[g]]
        # group N = non-missing + missing (the N header is shared)
        for g in groups:
            uset = set(units[g]) | {miss[g]}
            model.rows.append(({**{i: 1 for i in uset}, nidx[g]: -1}, 0, 0))
        if len(mrows) > 1:
            raise ValueError(f"case {cid}: {len(mrows)} Missing rows for {name}")
        if mrows:
            apply(mrows[0],
                  lambda g: list(miss.values()) if g is None else [miss[g]],
                  lambda g: allunits if g is None else units[g],
                  pctden=lambda g: allN if g is None else [nidx[g]])
    # the truth must satisfy every published constraint (parser sanity)
    x = np.array(model.truth, dtype=float)
    a, lo, hi = model.matrices()
    ax = a @ x
    if np.any(ax < lo - 1e-9) or np.any(ax > hi + 1e-9):
        bad = int(np.argmax((ax < lo - 1e-9) | (ax > hi + 1e-9)))
        coef = {model.names[i]: c for i, c in model.rows[bad][0].items()}
        raise ValueError(f"case {cid}: true counts violate published constraint {bad}: "
                         f"{coef} in [{model.rows[bad][1]}, {model.rows[bad][2]}]")
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
        if os.path.exists(os.path.join(args.dir, f"case_{cid}_error")):
            lines.append(f"FAIL case {cid}: table1_tc failed ({open(os.path.join(args.dir, f'case_{cid}_error')).read().strip()})")
            continue
        try:
            if c.get("mode", "full") == "primary":
                bad = check_primary(args.dir, cid, int(c["k"]))
                ncheck += 1
                if bad:
                    nleak += 1
                    lines.append(f"FAIL case {cid} (primary; {c['vars']}; {c['opts']}; k={c['k']}): printed {' '.join(bad[:4])}")
                continue
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
    g.add_argument("--grid", choices=["base", "wide"], default="base")
    # --no-contn-missing drops missingsummary from tables holding a continuous
    # variable. 2.5.3 needed it: a printed mean says n >= k, which the engine
    # did not use, so a Missing <k beside N = k + 1 was pinned. The engine now
    # takes that lower bound (lower()/rowlower()) and the default grid keeps
    # those tables; the flag remains for comparison runs only.
    g.add_argument("--no-contn-missing", action="store_true")
    g.add_argument("--dir", required=True)
    g.add_argument("--n", type=int, required=True)
    g.add_argument("--seed", type=int, required=True)
    c = sub.add_parser("check")
    c.add_argument("--dir", required=True)
    c.add_argument("--status", required=True)
    args = ap.parse_args()
    if args.cmd == "gen":
        (gen_wide if args.grid == "wide" else gen)(args)
    else:
        check(args)


if __name__ == "__main__":
    sys.exit(main())
