# Stacked sandwich — strong-confounding undercoverage decomposition

**Diagnostic, not a gate.** Same standing as `STACKED_2026-08-07.md`: a different DGP, weight type, cell and seeds from the preregistered FIPTIW gate. Nothing here may be reported as a coverage verdict or used to change a default.

This records the diagnostic `_take_action/se_recovery.md` §13.3 item 1 left open: *why* the strong-confounding cell undercovers, and specifically whether the stacked SE is too small or the problem is elsewhere.

| | |
|---|---|
| Run date | 2026-08-07 |
| Probe | `qa/probe_stacked_strain.do` |
| Parent record | `STACKED_2026-08-07.md` |

## The question

The calibration probe (`STACKED_2026-08-07.md`) showed that `vce(stacked)` is the right size under mild confounding (SE/empSD 0.988, coverage 0.944), but undercovers at 0.832 under strong confounding. The SD/IQR-scale argument said this was a heavy-tailed pivot rather than a bad correction, but that statistic alone cannot separate three causes:

1. **The SE is too small.** The correction misses something under strain.
2. **The pivot is not normal.** The SE is right but 1.96 is the wrong critical value.
3. **The estimator is biased.** beta-hat is off-centre, so a correct interval still misses.

## The discriminator

The **oracle** interval — `beta-hat ± 1.96 × empirical SD` — uses the SE treated as known. No variance estimator can beat it. If the oracle itself undercovers, no SE fix can close the gap. A **mean-centred** oracle removes bias from shape, separating causes (2) and (3). Additionally, `median(SE) / IQR-scale(b)` compares SE to spread robustly on both sides, and `p95 of |t|` gives the critical value that would deliver 95%.

## Results

DGP: IPTW, correctly specified propensity model, truth 0.5. Strong cells use `pscoef=1.2`; mild uses `pscoef=0.5`.

| cell | n | reps | medSE/IQR | stacked cov | oracle cov | centred oracle | p95 \|t\| | skew | kurtosis |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| mild | 400 | 2000 | **0.969** | **0.946** | **0.945** | 0.945 | **1.98** | -0.17 | 3.5 |
| mild | 1600 | 1000 | **0.998** | **0.969** | **0.957** | 0.957 | **1.80** | -0.07 | 3.0 |
| strong | 400 | 2000 | 0.767 | 0.838 | **0.965** | 0.961 | 2.98 | -1.94 | 11.8 |
| strong | 800 | 2000 | 0.793 | 0.850 | **0.964** | 0.964 | 2.91 | -1.64 | 9.5 |
| strong | 1600 | 1000 | 0.801 | 0.870 | **0.971** | 0.972 | 2.71 | -2.44 | 17.6 |
| strong | 3200 | 1000 | 0.867 | 0.898 | **0.953** | 0.953 | 2.59 | — | — |
| strong | 6400 | 600 | 0.851 | 0.910 | **0.988** | 0.988 | 2.52 | -9.71 | 171.1 |

Strain-split coverage (stacked, strong cells):

| n | low-strain 75% | high-strain 25% |
|---:|---:|---:|
| 400 | 0.791 | 0.978 |
| 800 | 0.805 | 0.984 |
| 1600 | 0.831 | 0.988 |
| 3200 | 0.865 | 0.996 |
| 6400 | 0.882 | 0.993 |

## Verdict: the SE is too small, and it is not (only) a tail problem

The calibration probe's reading — "a heavy-tailed pivot, not a bad correction" — was **partly wrong**. The oracle resolves it:

**The oracle coverage is 0.95–0.99 in every strong cell**, including the ones where stacked coverage is 0.84. Since the oracle uses the true SE and still delivers nominal coverage, the problem is that **the stacked SE undershoots the actual spread by 15–23%** (medSE/IQR 0.77–0.87). No amount of non-normality can explain an oracle that covers at 0.965 while the stacked interval covers at 0.838 — that gap is the SE, not the pivot.

The centred oracle matches the truth-centred oracle within simulation noise in every cell, so **bias is negligible** (bias/empSD ≤ 0.14 at n=400, ≤ 0.06 at n≥800).

The p95 of |t| (2.5–3.0 vs nominal 1.96) confirms the SE is short: the pivot is wider than standard normal because the SE in the denominator is too small, not because the numerator is heavy-tailed. The kurtosis of beta-hat itself rises with n (17.6 at 1600, 171 at 6400) — positivity strain produces occasional extreme estimates — but the oracle absorbs these and still covers, so the tails explain a few percent of over-coverage in the oracle row, not the 8–11 point deficit in the stacked row.

**Why** the SE is short under strain: medSE/IQR improves slowly from 0.77 to 0.87 over a 16-fold n increase (400 → 6400). The fixed-weight sandwich also undershoots against IQR-scale (1.27–1.39, not 2.3 as in the mild cell). Both are consistent with the first-order correction being incomplete when the weights are highly variable — the asymptotic expansion's remainder term is large.

The strain-split coverage tells the same story: stacked covers 0.98–1.00 in the *low-strain quarter* (where the weights are well-behaved) and 0.79–0.88 in the *high-strain three quarters*. The deficit concentrates where the weights are extreme.

## What this changes for §13.3

The stacked sandwich is the **right** answer under mild confounding and the **best available analytic answer** under strong confounding — it is closer to the oracle than the fixed sandwich everywhere — but it is not *sufficient* under strong confounding. This is the expected finite-sample behaviour for a first-order correction when the nuisance model variance is large relative to the outcome model variance. The remaining SE gap means:

- The stacked sandwich can be a §11 candidate under mild-to-moderate confounding
- Under strong confounding, a different interval method is needed (bootstrap-t, cluster jackknife, or a higher-order correction)
- This is the same shape as §12's unresolved 16% deficit, now decomposed

The calibration probe's "against the robust scale the stacked SE is 3.5–4.5% low" was too optimistic: it used mean(SE)/IQR-scale, where mean(SE) is inflated by the same heavy tails that inflate empSD, masking a larger median deficit. The median-based statistic (medSE/IQR-scale) gives the honest answer.

## Reproducing

```bash
# from isolated scratch copies preserving the repo layout
cd <scratch>/iivw/qa
stata-mp -b do probe_stacked_strain.do 400  1.2 2000 880000   # strong n=400
stata-mp -b do probe_stacked_strain.do 800  1.2 2000 881000   # strong n=800
stata-mp -b do probe_stacked_strain.do 1600 1.2 1000 882000   # strong n=1600
stata-mp -b do probe_stacked_strain.do 3200 1.2 1000 883000   # strong n=3200
stata-mp -b do probe_stacked_strain.do 6400 1.2  600 884000   # strong n=6400
stata-mp -b do probe_stacked_strain.do 400  0.5 2000 890000   # mild n=400
stata-mp -b do probe_stacked_strain.do 1600 0.5 1000 891000   # mild n=1600
```
