"""Recompute the 2026-07-22 headline coverage numbers from the raw block .dta
files, in Python, sharing no code with validation_iivw_inference.do's combine.

combine had two defects before this work (it re-ran the study; it accepted a
missing interior block) and a third found on 2026-07-22. Its acceptance
arithmetic has therefore never been checked by anything but itself. This does
not make the check independent of me -- I wrote both -- but it does make it
independent of that code path.
"""
import glob, os, sys
import pandas as pd
import numpy as np

POOL = "/tmp/claude-1000/covgate/blockpool/r999_s20260715"
TRUTH = {"iiw": 0.5, "iptw": 1.5, "fiptiw": 1.0}
FLOOR = 0.92

def wilson(p, n, z=1.959963984540054):
    den = 1 + z*z/n
    ctr = (p + z*z/(2*n)) / den
    hw = z*np.sqrt(p*(1-p)/n + z*z/(4*n*n)) / den
    return ctr - hw, ctr + hw

print(f"{'family':8s} {'R':>5s} {'cov':>7s} {'Wilson':>16s} {'empSD':>9s} "
      f"{'meanSE':>9s} {'ratio':>7s} {'bias':>9s} {'MCSE':>8s}  gate")
print("-" * 100)

for fam, truth in TRUTH.items():
    files = sorted(glob.glob(os.path.join(POOL, f"{fam}_*.dta")))
    if not files:
        print(f"{fam}: no blocks"); continue
    df = pd.concat([pd.read_stata(f) for f in files], ignore_index=True)

    # structural checks, done independently of combine's tiling proof
    sims = np.sort(df["sim"].values)
    expected = np.arange(1, 1001)
    tiles = len(sims) == 1000 and np.array_equal(sims, expected)

    R = len(df)
    cov = df["cov_refit"].mean()
    lo, hi = wilson(cov, R)
    empsd = df["b_refit"].std(ddof=1)
    mse = df["se_refit"].mean()
    bias = df["b_refit"].mean() - truth
    mcse = empsd / np.sqrt(R)
    gate = (lo <= 0.95 <= hi) and (cov >= FLOOR)

    print(f"{fam:8s} {R:5d} {cov:7.3f} [{lo:6.3f},{hi:6.3f}] {empsd:9.5f} "
          f"{mse:9.5f} {mse/empsd:7.4f} {bias:9.5f} {mcse:8.5f}  "
          f"{'PASS' if gate else 'FAIL'}   tiles1..1000={tiles}")

print("-" * 100)
print("Cross-check vs the three other variance estimators (fiptiw):")
files = sorted(glob.glob(os.path.join(POOL, "fiptiw_*.dta")))
df = pd.concat([pd.read_stata(f) for f in files], ignore_index=True)
empsd = df["b_refit"].std(ddof=1)
for col in ("se_refit", "se_fwb", "se_fix"):
    print(f"  {col:9s} mean={df[col].mean():8.5f}  mean/empSD={df[col].mean()/empsd:7.4f}")
z = (df["b_refit"] - 1.0) / df["se_refit"]
print(f"  z=err/se_refit : SD={z.std(ddof=1):6.4f}  kurtosis={z.kurtosis()+3:6.3f}  "
      f"skew={z.skew():7.4f}")
