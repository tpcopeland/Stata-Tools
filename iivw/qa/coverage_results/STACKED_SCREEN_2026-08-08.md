# Stacked sandwich — R=200 screen at the FIPTIW gate DGP (§13.3 item 2)

**Diagnostic, not a gate.** R=200 has a Wilson half-width of ~±3pp — enough to reject a candidate at 0.92 or flag one at 0.985, not enough to certify one. Same relabelling prohibition as `FIPTIW_NSCALE_2026-07-23.md:5-7`.

This is the §10 tier-2 screen called for in `se_recovery.md` §13.3 item 2. DGP, seed ledger, and acceptance rule are the registered ones (master 20260715, arm 3, FIPTIW strong-dependence).

| | |
|---|---|
| Run date | 2026-08-08 |
| Probe | `qa/probe_stacked_screen.do` |
| Parent record | `STACKED_2026-08-07.md`, `STACKED_STRAIN_2026-08-07.md` |

## Results

Each dataset fitted three ways: `vce(fixed)`, `vce(stacked)`, `vce(bootstrap, reps(999))` with BCa. Oracle = `beta-hat ± 1.96 × empSD`.

### n=300 (200 reps, 0 failed)

| method | coverage | medSE/IQR | notes |
|---|---:|---:|---|
| fixed Wald | 0.920 | 0.938 | |
| **stacked Wald** | **0.905** | **0.897** | Wilson **[0.856, 0.938]** — does not contain 0.95 |
| refit-bootstrap Wald | 0.935 | 0.941 | |
| percentile | 0.935 | — | |
| basic | 0.910 | — | |
| bias-corrected | 0.900 | — | |
| BCa | 0.900 | — | |
| oracle (empSD) | 0.925 | — | |

Sampling distribution: bias/empSD 0.014, SD/IQR-scale **1.147**, skewness 0.73, kurtosis 3.8.
Stacked pivot: p95 of |t| = **2.54** (1.96 nominal).

**The stacked sandwich fails the n=300 screen.** The SE undershoots the spread by 10% (medSE/IQR 0.90) and the pivot is wider than normal (p95 |t| 2.54). The oracle itself is only 0.925, so even the true SE would barely pass — the DGP at n=300 sits in the moderate-strain regime where the first-order correction is incomplete, consistent with `STACKED_STRAIN_2026-08-07.md`.

### n=600 (200 reps, 0 failed)

| method | coverage | medSE/IQR | notes |
|---|---:|---:|---|
| fixed Wald | 0.945 | 1.003 | |
| **stacked Wald** | **0.940** | **0.968** | Wilson **[0.898, 0.965]** — contains 0.95 |
| refit-bootstrap Wald | 0.955 | 0.988 | |
| percentile | 0.955 | — | |
| basic | 0.955 | — | |
| bias-corrected | 0.945 | — | |
| BCa | 0.945 | — | |
| oracle (empSD) | 0.935 | — | |

Sampling distribution: bias/empSD -0.010, SD/IQR-scale **1.021**, skewness -0.10, kurtosis 2.9.
Stacked pivot: p95 of |t| = **2.01** (1.96 nominal).

**The stacked sandwich screens as a candidate at n=600.** The sampling distribution is near-normal (SD/IQR 1.02, kurtosis 2.9), the SE is within 3% of the spread, and the pivot is essentially standard normal (p95 |t| 2.01). No overcoverage. The Wilson interval contains 0.95.

### n=1200 (200 reps, 0 failed — 8 shards combined)

| method | coverage | medSE/IQR | notes |
|---|---:|---:|---|
| fixed Wald | 0.970 | 1.008 | |
| **stacked Wald** | **0.960** | **0.984** | Wilson **[0.923, 0.980]** — contains 0.95 |
| refit-bootstrap Wald | 0.965 | 0.986 | |
| percentile | 0.965 | — | |
| basic | 0.960 | — | |
| bias-corrected | 0.940 | — | |
| BCa | 0.940 | — | |
| oracle (empSD) | 0.955 | — | |

Sampling distribution: bias/empSD 0.057, SD/IQR-scale **1.121**, skewness -0.15, kurtosis 3.5.
Stacked pivot: p95 of |t| = **1.84** (1.96 nominal).

**The stacked sandwich passes the screen at n=1200.** No overcoverage — coverage is 0.960, well below the 0.985 that disqualified CR2+Satterthwaite. §11 clause 2 is clear.

## What the screen establishes

1. **The stacked sandwich alone does not pass the n=300 gate.** Wilson [0.856, 0.938] excludes 0.95. This was expected from `STACKED_STRAIN_2026-08-07.md`: the FIPTIW DGP at n=300 sits in the moderate-strain regime where the first-order correction is incomplete.

2. **The stacked sandwich is calibrated at n=600.** Coverage 0.940, SE/spread 0.968, near-normal pivot. No overcoverage. This makes it a valid inner SE for items 3–4 (cluster jackknife, bootstrap-t).

3. **The pattern matches the strain diagnostic exactly.** At n=300 the DGP is in the "moderate strain" regime (SD/IQR 1.15); at n=600 it has crossed into the "mild" regime (SD/IQR 1.02) where the correction works. The boundary is between n=300 and n=600.

4. **§11 clause 2 is not triggered.** The stacked sandwich shows no overcoverage at n=600 (0.940). This is the pattern CR2+Satterthwaite failed on (0.985 at n=600/1200). Pending n=1200 confirmation.

## Consequence for items 3–6

The stacked sandwich is the right **reference** and the right **inner SE** for the bootstrap-t (item 4), but it cannot be the default on its own. Items 3 (cluster jackknife) and 4 (bootstrap-t studentized by the stacked SE) are the remaining candidates for the n=300 gate.

## Reproducing

```bash
# from isolated scratch copies preserving the repo layout
cd <scratch>/iivw/qa
stata-mp -b do probe_stacked_screen.do 300 200      # n=300
stata-mp -b do probe_stacked_screen.do 600 200      # n=600

# n=1200, sharded (8 blocks of 25):
for i in $(seq 1 8); do
  FROM=$(( (i-1)*25 + 1 )); TO=$(( i*25 ))
  stata-mp -b do probe_stacked_screen.do 1200 200 20260715 $FROM $TO &
done
wait
stata-mp -b do probe_stacked_screen.do 1200 200 20260715 COMBINE
```
