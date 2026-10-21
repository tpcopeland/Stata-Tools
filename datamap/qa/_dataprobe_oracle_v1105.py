"""Independent disclosure oracle for dataprobe by() profiles under maskrare.

Reads one dataprobe log (text) and the data it profiled (CSV), rebuilds the
attacker's linear system from the PRINTED numbers only, and asks a MILP
(scipy/HiGHS) for the smallest and largest value of every per-group count.
A count whose true value (or complement in its group) is 1..m-1 and that
the system pins to one value is a disclosure.  The data supply only the
true values to test and the level universe (which values exist); every
constraint comes from the text.

Printed numbers read: the header (N, complete cases), MISSINGNESS, the
pooled CATEGORICAL tables, GROUPWISE SUMMARY (N, complete, MissVars, the
pooled-groups line), GROUPWISE MISSINGNESS (an absent row is a zero for a
shown group) and GROUPWISE FREQUENCIES.  Relations: a group's levels and
missing codes sum to its size; group cells sum to the pooled count; the
incomplete rows lie between the largest missing count and their sum, and
MissVars counts the nonzero missing counts; the pooled groups are one
column of size N minus the shown sizes.  A withheld frequency row is any
present level not shown (an assignment: which hidden level sits in which
row is unknown), bounded by its neighbours and its reason.

Usage: python _dataprobe_oracle_v1105.py LOG CSV M OUT
Writes OUT: one line per pinned sensitive count, then "VIOLATIONS n".
"""
import csv
import re
import sys

import numpy as np
from scipy.optimize import Bounds, LinearConstraint, milp

BIG = 10 ** 6


def parse_count(txt, n, m):
    """Class [lo, hi] of a printed count of n (None, None when unknown)."""
    t = txt.strip()
    if t == "":
        return None
    if t.startswith("all but <"):
        k = int(t[len("all but <"):])
        return (max(0, n - (k - 1)), n - 1)
    if t.startswith("<"):
        k = int(t[1:])
        return (1, k - 1)
    if t.startswith("["):
        # [suppr.] / [suppressed]: withheld; documented as an exact count
        # of m or more, so 0, m..n-m, or n (a class with gaps)
        return ("gap", n)
    return (int(float(t)), int(float(t)))


def add_class(md, expr, cl, m):
    """expr in class cl: an interval, or ('gap', n): 0, m..n-m, or n."""
    if cl[0] == "gap":
        n = cl[1]
        b0 = md.var(0, 1)
        b1 = md.var(0, 1)
        b2 = md.var(0, 1)
        md.add({b0: 1, b1: 1, b2: 1}, 1, 1)
        # expr >= m*b1 + n*b2 ; expr <= (n-m)*b1 + n*b2
        md.add({**expr, b1: -m, b2: -n}, 0, BIG)
        md.add({**expr, b1: -(n - m), b2: -n}, -BIG, 0)
        return
    md.add(expr, cl[0], cl[1])


class Model:
    def __init__(self):
        self.nv = 0
        self.lb = []
        self.ub = []
        self.integ = []
        self.rows = []  # (coef dict, lo, hi)

    def var(self, lo, hi, integer=True):
        self.lb.append(lo)
        self.ub.append(hi)
        self.integ.append(1 if integer else 0)
        self.nv += 1
        return self.nv - 1

    def add(self, coef, lo, hi):
        self.rows.append((dict(coef), lo, hi))

    def solve(self, obj_coef, sense):
        c = np.zeros(self.nv)
        for k, v in obj_coef.items():
            c[k] = v * sense
        A = np.zeros((len(self.rows), self.nv))
        lo = np.zeros(len(self.rows))
        hi = np.zeros(len(self.rows))
        for i, (coef, l, h) in enumerate(self.rows):
            for k, v in coef.items():
                A[i, k] += v
            lo[i] = l
            hi[i] = h
        res = milp(c, constraints=LinearConstraint(A, lo, hi),
                   integrality=np.array(self.integ),
                   bounds=Bounds(np.array(self.lb, float), np.array(self.ub, float)))
        if res.status != 0:
            return None
        return sense * res.fun


def read_blocks(path):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    out = {}
    cur = None
    for ln in lines:
        if ln.startswith("dataprobe: "):
            out["header"] = ln
            continue
        if ln.strip() in ("QUICK REFERENCE", "CONTINUOUS", "CATEGORICAL", "MISSINGNESS",
                          "GROUPWISE SUMMARY", "GROUPWISE MISSINGNESS",
                          "GROUPWISE FREQUENCIES", "STRING", "DATE", "KEY STRUCTURE"):
            cur = ln.strip()
            out[cur] = []
            continue
        if ln.startswith(". ") or ln.startswith("end of do-file") or \
                ln.startswith("      name:"):
            cur = None
            continue
        if cur and ln.strip() != "":
            out[cur].append(ln)
    return out


def parse_table(rows, indent):
    """A frequency table's rows: list of ('x', text, count) / ('s', reason) /
    ('more', k)."""
    out = []
    for ln in rows:
        if not ln.startswith(" " * indent) or ln.startswith(" " * (indent + 1)):
            continue
        body = ln[indent:]
        if body.startswith("[suppressed]"):
            reason = "small" if "(<" in body else "comp"
            out.append(("s", reason))
        elif body.startswith("... "):
            k = int(body.split()[1])
            out.append(("more", k))
        else:
            m = re.match(r"^(.{28})\s*(\d+)\s+\(", body)
            if not m:
                m = re.match(r"^(.*?)\s+(\d+)\s+\(", body)
            out.append(("x", m.group(1).strip(), int(m.group(2))))
    return out


def main(logp, csvp, m, outp):
    m = int(m)
    blocks = read_blocks(logp)
    data = list(csv.DictReader(open(csvp, encoding="utf-8")))
    hdr = blocks["header"]
    N = int(re.search(r"dataprobe: (\S+) obs", hdr).group(1))
    cc_txt = re.search(r"complete cases: (.*?) = ", hdr).group(1)
    pvars = []
    pclass = {}
    for ln in blocks.get("QUICK REFERENCE", [])[1:]:
        t = ln.split()
        pvars.append(t[0])
        pclass[t[0]] = t[1]
    # the data: group label, values (string, "" = missing)
    glab = [r["g"] for r in data]
    vals = {v: [r[v] for r in data] for v in pvars}
    # level universe per variable: values as dataprobe prints them
    def lev_of(v, x):
        if pclass[v] == "categorical":
            return "." if x == "" else str(int(float(x)))
        return "miss" if x == "" else "nm"
    levels = {v: sorted(set(lev_of(v, x) for x in vals[v]),
                        key=lambda s: (s == "." or s == "miss", s)) for v in pvars}
    ismiss = lambda v, l: l in (".", "miss")
    # shown groups from GROUPWISE SUMMARY
    shown = {}
    pooled_k = 0
    for ln in blocks.get("GROUPWISE SUMMARY", []):
        if ln.startswith("  by:") or ln.strip().startswith("Group"):
            continue
        mm = re.search(r"groups pooled .*: (\d+)", ln)
        if mm:
            pooled_k = int(mm.group(1))
            continue
        lab = ln[2:22].strip()
        shown[lab] = {"n": int(ln[22:31]), "comp": ln[31:43].strip(),
                      "missvars": int(ln[53:62])}
    gmiss = {}
    for ln in blocks.get("GROUPWISE MISSINGNESS", []):
        if ln.strip().startswith("Group") or "groups pooled" in ln:
            continue
        lab = ln[2:22].strip()
        # variable, count (which may overrun its column, all but <5), share
        mm = re.match(r"^(\S+)\s+(.*\S)\s+(\S+)$", ln[22:])
        gmiss[(lab, mm.group(1))] = mm.group(2).strip()
    pmiss = {}
    for ln in blocks.get("MISSINGNESS", []):
        mm = re.match(r"^  (\S+)\s+(.*?) missing  \(", ln)
        if mm:
            pmiss[mm.group(1)] = mm.group(2)
    # pooled tables
    ptab = {}
    cur = None
    buf = []
    for ln in blocks.get("CATEGORICAL", []):
        mm = re.match(r"^  (\S+):\s+(\S+) levels", ln)
        if mm:
            if cur:
                ptab[cur] = parse_table(buf, 4)
            cur = mm.group(1)
            buf = []
        else:
            buf.append(ln)
    if cur:
        ptab[cur] = parse_table(buf, 4)
    # group tables
    gtab = {}
    cur = None
    curg = None
    buf = []
    for ln in blocks.get("GROUPWISE FREQUENCIES", []):
        mm = re.match(r"^  (\S+):$", ln)
        mg = re.match(r"^    by group (.*):$", ln)
        if mm or mg or "groups pooled" in ln:
            if cur and curg is not None:
                gtab[(curg, cur)] = parse_table(buf, 6)
            buf = []
            if mm:
                cur = mm.group(1)
                curg = None
            elif mg:
                curg = mg.group(1).strip()
            else:
                curg = None
        else:
            buf.append(ln)
    if cur and curg is not None:
        gtab[(curg, cur)] = parse_table(buf, 6)

    # ---- the model ----
    cols = list(shown.keys())
    P = "__pool__" if pooled_k > 0 else None
    allcols = cols + ([P] if P else [])
    nsz = {c: shown[c]["n"] for c in cols}
    if P:
        nsz[P] = N - sum(nsz[c] for c in cols)
    true = {}
    for c in allcols:
        for v in pvars:
            for l in levels[v]:
                true[(c, v, l)] = 0
    for i, gl in enumerate(glab):
        c = gl if gl in shown else P
        for v in pvars:
            true[(c, v, lev_of(v, vals[v][i]))] += 1
    true_inc = {c: 0 for c in allcols}
    for i, gl in enumerate(glab):
        c = gl if gl in shown else P
        if any(vals[v][i] == "" for v in pvars):
            true_inc[c] += 1

    md = Model()
    X = {}
    for c in allcols:
        for v in pvars:
            for l in levels[v]:
                X[(c, v, l)] = md.var(0, nsz[c])
    INC = {c: md.var(0, nsz[c]) for c in allcols}
    for c in allcols:
        for v in pvars:
            md.add({X[(c, v, l)]: 1 for l in levels[v]}, nsz[c], nsz[c])
    # missing counts per column and pooled
    def Mexpr(c, v):
        return {X[(c, v, l)]: 1 for l in levels[v] if ismiss(v, l)}
    for v in pvars:
        cl = parse_count(pmiss.get(v, "0"), N, m)
        e = {}
        for c in allcols:
            e.update(Mexpr(c, v))
        add_class(md, e, cl, m)
        for c in cols:
            t = gmiss.get((c, v))
            cl = (0, 0) if t is None else parse_count(t, nsz[c], m)
            add_class(md, Mexpr(c, v), cl, m)
    # incomplete rows and MissVars
    for c in allcols:
        tot = {}
        for v in pvars:
            md.add({INC[c]: 1, **{k: -1 for k in Mexpr(c, v)}}, 0, BIG)
            for k in Mexpr(c, v):
                tot[k] = tot.get(k, 0) - 1
        md.add({INC[c]: 1, **tot}, -BIG, 0)
    for c in cols:
        cl = parse_count(shown[c]["comp"], nsz[c], m)
        if cl[0] == "gap":
            # complete = n - incomplete in the gap class
            cv = md.var(0, nsz[c])
            md.add({cv: 1, INC[c]: 1}, nsz[c], nsz[c])
            add_class(md, {cv: 1}, cl, m)
        else:
            md.add({INC[c]: 1}, nsz[c] - cl[1], nsz[c] - cl[0])
        zs = {}
        for v in pvars:
            z = md.var(0, 1)
            e = Mexpr(c, v)
            md.add({**e, z: -nsz[c]}, -BIG, 0)
            md.add({**e, z: -1}, 0, BIG)
            zs[z] = 1
        md.add(zs, shown[c]["missvars"], shown[c]["missvars"])
    cl = parse_count(cc_txt, N, m)
    if cl[0] == "gap":
        cv = md.var(0, N)
        md.add({cv: 1, **{INC[c]: 1 for c in allcols}}, N, N)
        add_class(md, {cv: 1}, cl, m)
    else:
        md.add({INC[c]: 1 for c in allcols}, N - cl[1], N - cl[0])

    # a frequency table: exact rows fix a level; withheld rows hold the
    # other present levels, one each, within their neighbours and reason
    def table(tab, cells, n, lab):
        # rows in print order; a row's neighbours bound the level in it,
        # with ties broken as gsort -freq var breaks them (lower value
        # first), so the bound depends on which level sits in the row
        order = lambda l: (1, 0.0, l) if l in (".",) else (0, float(l), l)
        shown_l = {}
        rows_s = []
        exact = [(i, r) for i, r in enumerate(tab) if r[0] == "x"]
        for idx, r in enumerate(tab):
            if r[0] == "x":
                shown_l[r[1]] = r[2]
        def nb(idx):
            up = None
            dn = None
            for j in range(idx - 1, -1, -1):
                if tab[j][0] == "x":
                    up = (tab[j][1], tab[j][2])
                    break
            for j in range(idx + 1, len(tab)):
                if tab[j][0] == "x":
                    dn = (tab[j][1], tab[j][2])
                    break
            return up, dn
        for idx, r in enumerate(tab):
            if r[0] == "s":
                lo, hi = (1, m - 1) if r[1] == "small" else (m, n)
                up, dn = nb(idx)
                rows_s.append((lo, hi, up, dn))
            elif r[0] == "more":
                up = None
                for j in range(len(tab) - 1, -1, -1):
                    if tab[j][0] == "x":
                        up = (tab[j][1], tab[j][2])
                        break
                for _ in range(r[1]):
                    rows_s.append((1, n, up, None))
        hidden = [l for l in cells if l not in shown_l]
        for l, k in shown_l.items():
            if l not in cells:
                raise ValueError("unknown level %s in %s" % (l, lab))
            md.add({cells[l]: 1}, k, k)
        def bounds(l, row):
            lo, hi, up, dn = row
            if up is not None:
                hi = min(hi, up[1] if order(up[0]) < order(l) else up[1] - 1)
            if dn is not None:
                lo = max(lo, dn[1] if order(l) < order(dn[0]) else dn[1] + 1)
            return lo, hi
        A = {}
        for l in hidden:
            for ri, row in enumerate(rows_s):
                A[(l, ri)] = md.var(0, 1)
            md.add({A[(l, ri)]: 1 for ri in range(len(rows_s))}, 0, 1)
            e = {cells[l]: 1}
            for ri, row in enumerate(rows_s):
                e[A[(l, ri)]] = -bounds(l, row)[0]
            md.add(e, 0, BIG)
            e = {cells[l]: 1}
            for ri, row in enumerate(rows_s):
                e[A[(l, ri)]] = -bounds(l, row)[1]
            md.add(e, -BIG, 0)
        for ri in range(len(rows_s)):
            if hidden:
                md.add({A[(l, ri)]: 1 for l in hidden}, 1, 1)
            else:
                raise ValueError("withheld row without a hidden level in %s" % lab)
    for v in pvars:
        if pclass[v] != "categorical":
            continue
        # pooled cells as sums of the columns
        pc = {}
        for l in levels[v]:
            t = md.var(0, N)
            md.add({t: 1, **{X[(c, v, l)]: -1 for c in allcols}}, 0, 0)
            pc[l] = t
        if v in ptab:
            table(ptab[v], pc, N, "pooled " + v)
        for c in cols:
            if (c, v) in gtab:
                table(gtab[(c, v)], {l: X[(c, v, l)] for l in levels[v]}, nsz[c], c + " " + v)

    # ---- the counts to test ----
    viol = []
    def pinned(expr):
        lo = md.solve(expr, 1)
        hi = md.solve(expr, -1)
        if lo is None or hi is None:
            return None
        return round(hi) - round(lo) < 1
    def check(name, expr, val, n, pexpr, ptrue):
        vsens = 1 <= val <= m - 1
        csens = n is not None and 1 <= n - val <= m - 1
        # a count that is the whole pooled total (or whose complement is
        # the whole pooled complement) says no more than the pooled
        # output, which masks it by its own rule: out of scope here
        if vsens and val == ptrue and 1 <= ptrue <= m - 1:
            vsens = False
        if csens and n - val == N - ptrue and 1 <= N - ptrue <= m - 1:
            csens = False
        if not (vsens or csens):
            return
        p = pinned(expr)
        if p is None:
            viol.append("INFEASIBLE model at %s" % name)
            return
        if p:
            viol.append("%s = %d pinned (n=%s)" % (name, val, n))
    for c in allcols:
        for v in pvars:
            mval = sum(true[(c, v, l)] for l in levels[v] if ismiss(v, l))
            pe = {}
            for c2 in allcols:
                pe.update(Mexpr(c2, v))
            pt = sum(true[(c2, v, l)] for c2 in allcols for l in levels[v] if ismiss(v, l))
            check("%s missing %s" % (c, v), Mexpr(c, v), mval, nsz[c], pe, pt)
            if pclass[v] == "categorical":
                for l in levels[v]:
                    pe = {X[(c2, v, l)]: 1 for c2 in allcols}
                    pt = sum(true[(c2, v, l)] for c2 in allcols)
                    check("%s %s=%s" % (c, v, l), {X[(c, v, l)]: 1}, true[(c, v, l)], nsz[c], pe, pt)
        check("%s incomplete" % c, {INC[c]: 1}, true_inc[c], nsz[c],
              {INC[c2]: 1 for c2 in allcols}, sum(true_inc.values()))
    keep = viol
    with open(outp, "w") as f:
        for s in keep:
            f.write(s + "\n")
        f.write("VIOLATIONS %d\n" % len(keep))


def relcheck(logp, pattern, total, sizes, m, zero_absent=True, complement=False):
    """One relation on its own: the per-group counts a pattern reads from
    the log (named groups g, the group label, and k, the printed count)
    sum to total over the groups in sizes (label -> size).  A group the
    pattern never matches holds 0 when zero_absent (a gate that passes
    prints no line).  Each count's class comes from its text; the interval
    one count keeps given the others' classes and the total is
    [max(lo, T - sum hi), min(hi, T - sum lo)].  complement: the printed
    count is the group size minus the quantity.  Returns the pinned
    counts, as text."""
    m = int(m)
    txt = open(logp, encoding="utf-8", errors="replace").read().splitlines()
    rx = re.compile(pattern)
    cls = {}
    for ln in txt:
        mm = rx.search(ln)
        if not mm:
            continue
        g = mm.group("g")
        n = sizes[g]
        c = parse_count(mm.group("k"), n, m)
        if c[0] == "gap":
            c = (0, n)
        if complement:
            c = (n - c[1], n - c[0])
        cls[g] = c
    for g in sizes:
        if g not in cls:
            cls[g] = (0, 0) if zero_absent else (0, sizes[g])
    out = []
    for g, (lo, hi) in cls.items():
        if lo == hi:
            continue
        olo = sum(cls[h][0] for h in cls if h != g)
        ohi = sum(cls[h][1] for h in cls if h != g)
        a = max(lo, total - ohi)
        b = min(hi, total - olo)
        if a == b and (1 <= a <= m - 1 or 1 <= sizes[g] - a <= m - 1):
            out.append("%s pinned at %d" % (g, a))
    return out


if __name__ == "__main__":
    main(*sys.argv[1:5])
