"""Hand computation of table1_tc smdtype() values, independent of Stata.

Usage: python3 crossval_desctab_smd_v240.py IN.csv OUT.csv

IN.csv: arm, age, sex (0/1), grp (string), w (positive integer weight).
OUT.csv rows stat,var,value for stat in
    pop_{un,wt,fw}   population SB, McCaffrey et al. (2013) eq. 5 with the
                     sec. 4.2 max over groups: max_g |m_g - m_pop| / sd_pop.
                     wt: group means weighted by w, pooled mean/SD unweighted.
                     fw: w is a frequency weight (records replicated).
    max_{un,wt,fw}   max pairwise SMD, Lopez and Gutman (2017) eq. 27, every
                     pair over sqrt(mean_g var_g); var_g weighted as Stata's
                     summarize [aw] (wt) or [fw] (fw); binary p_g (1 - p_g);
                     categorical: Yang-Dalton eq. 2 with S averaged over
                     all groups.
    pair_CA          the two-group SMD of arm C vs arm A (smdpair(C A)).
Written from the formulas, not from the Stata code: plain numpy loops.
"""

import csv
import itertools
import sys

import numpy as np


def load(path):
    with open(path, newline="") as f:
        rows = list(csv.DictReader(f))
    arm = np.array([r["arm"] for r in rows])
    age = np.array([float(r["age"]) for r in rows])
    sex = np.array([float(r["sex"]) for r in rows])
    grp = np.array([r["grp"] for r in rows])
    w = np.array([float(r["w"]) for r in rows])
    return arm, age, sex, grp, w


def wmean(y, w):
    return float(np.sum(w * y) / np.sum(w))


def wvar(y, w, kind):
    m = wmean(y, w)
    ss = float(np.sum(w * (y - m) ** 2))
    n, sw = len(y), float(np.sum(w))
    if kind == "fw":
        return ss / (sw - 1)
    # unweighted (w = 1) and Stata [aw]: n / (sum w (n - 1)) * SS
    return n / (sw * (n - 1)) * ss


def stats(arm, y, w, kind, cls):
    groups = sorted(set(arm))
    wg = w if kind in ("wt", "fw") else np.ones_like(w)
    wp = w if kind == "fw" else np.ones_like(w)
    out = {}
    if cls in ("cont", "bin"):
        m = [wmean(y[arm == g], wg[arm == g]) for g in groups]
        pm = wmean(y, wp)
        if cls == "bin":
            sd = np.sqrt(pm * (1 - pm))
            v = [mi * (1 - mi) for mi in m]
        else:
            sd = np.sqrt(wvar(y, wp, "fw" if kind == "fw" else "un"))
            v = [wvar(y[arm == g], wg[arm == g], kind) for g in groups]
        out["pop"] = max(abs(mi - pm) for mi in m) / sd
        den = np.sqrt(np.mean(v))
        out["max"] = max(abs(a - b) for a, b in itertools.combinations(m, 2)) / den
    else:
        levels = sorted(set(y))
        def share(mask, ww):
            return np.array([np.sum(ww[mask & (y == lv)]) / np.sum(ww[mask])
                             for lv in levels])
        P = [share(arm == g, wg) for g in groups]
        pp = share(np.ones(len(y), bool), wp)
        out["pop"] = max(float(np.max(np.abs(p - pp) / np.sqrt(pp * (1 - pp)))) for p in P)
        K = len(levels) - 1
        S = sum(np.diag(p[:K]) - np.outer(p[:K], p[:K]) for p in P) / len(P)
        Si = np.linalg.inv(S)
        out["max"] = max(float(np.sqrt((a[:K] - b[:K]) @ Si @ (a[:K] - b[:K])))
                         for a, b in itertools.combinations(P, 2))
    return out


def pair_smd(arm, y, a, b):
    ya, yb = y[arm == a], y[arm == b]
    return abs(ya.mean() - yb.mean()) / np.sqrt((ya.var(ddof=1) + yb.var(ddof=1)) / 2)


def main():
    arm, age, sex, grp, w = load(sys.argv[1])
    res = []
    for kind in ("un", "wt", "fw"):
        for name, y, cls in (("age", age, "cont"), ("sex", sex, "bin"), ("grp", grp, "cat")):
            s = stats(arm, y, w, kind, cls)
            res.append(("pop_" + kind, name, s["pop"]))
            res.append(("max_" + kind, name, s["max"]))
    res.append(("pair_CA", "age", pair_smd(arm, age, "C", "A")))
    with open(sys.argv[2], "w") as f:
        f.write("stat,var,value\n")
        for st, v, x in res:
            f.write(f"{st},{v},{x:.17g}\n")


if __name__ == "__main__":
    main()
