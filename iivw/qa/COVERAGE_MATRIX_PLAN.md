# SOL-04 coverage matrix — costed plan for the remaining cells

**Written 2026-07-23, after the first cell ran.** The 2026-07-22 run covered
**one correctly specified scenario per weight family at one sample size**. SOL-04
asks for considerably more. This file costs the remainder from measured
runtime rather than guesswork, and orders it by what actually bears on release
risk.

## What the measured run tells us about cost

**Per-block times below are host-specific and do not transfer. Re-measure one
block before costing anything from them.** The 2026-07-23 figures were taken on
a **16-vCPU** host; the 2026-08-05 gate run on the current box measured
materially different per-block times at a *smaller* block size, which is the
opposite of what a portable calibration would do.

| Quantity | Measured | Host |
|---|---|---|
| One 50-replication `iiw` block at `REPS=999`, idle box | **89.7 min** | 16 vCPU, 2026-07-23 |
| One 25-replication `iptw` block at `REPS=999`, ~30-way concurrency | **~40 min** | 28 vCPU / 16 physical cores, 2026-08-05 |
| One 25-replication `iiw` block at `REPS=999`, ~30-way concurrency | **~95–128 min** | as above |
| One 25-replication `fiptiw` block at `REPS=999`, ~30-way concurrency | **~140 min** | as above |
| All 60 blocks (3 families x 1000 reps) | **~90 CPU-hours** | both runs agree |
| Wall-clock, `WORKERS=8`, shared 16-vCPU box | **8h55m** | 2026-07-23 |
| Wall-clock, 120 blocks of 25, `WORKERS≈30` | **5h34m** | 2026-08-05 |

The one figure that *did* transfer is the **~90 CPU-hour** total for a
three-family 1000-replication study, and that is the unit of currency below:
**one family-cell of 1000 replications costs ~30 CPU-hours.** Wall-clock is
whatever that divides into on the host of the day — note that the 2026-08-05
host's 28 vCPUs are SMT siblings of 16 physical cores, so its aggregate
throughput is ~16–20 single-thread-equivalents, not 28.

Source for the 2026-08-05 row: `coverage_results/RESULT_2026-08-05.md`
("Note on block calibration").

A diagnostic cell does not need 1000 replications. To resolve a coverage
proportion near 0.92 to +/-0.02 needs R ~ 500; to distinguish a variance ratio
of 0.86 from 1.00 needs far less. **R = 250-400 is adequate for every
diagnostic row below**, which is why the costs are not simply 30 CPU-h each.

## Priority order

Ordered by what would change a release decision, not by matrix tidiness.

### P1 — Does the FIPTIW shortfall shrink with n? *(completed 2026-07-23)*

The only question whose answer changes how FIPTIW must be *documented*. If the
deficit is finite-sample it is a small-sample caveat; if it persists, the
asymptotic variance does not describe this estimator and that is a much stronger
statement.

`fiptiw` at n = 600 and n = 1200, R = 200 each. **~36 CPU-h.**
n = 300 (R = 1000) is already in hand as the third point.

Observed refit coverage was 0.914, 0.950, and 0.960 at n = 300, 600,
and 1200, respectively; mean SE / empirical SD was 0.857, 1.006, and
0.952. The larger-n cells therefore support a finite-sample calibration
problem in this DGP rather than a persistent asymptotic variance failure. They
do not establish a universal sample-size cutoff. Full record:
`coverage_results/FIPTIW_NSCALE_2026-07-23.md`.

### P2 — Misspecified visit model, all three families

Tompkins 2025 identifies nonlinear monitoring-model misspecification as the most
damaging failure mode, and the audit (SOL-16) flags that `iivw` has no strong
functional-form diagnostic. Correct-specification coverage says nothing about it.
This is the largest untested risk in the package's actual use case.

Fit the visit model omitting a term that genuinely drives intensity (e.g. drop
the nonlinear part of `Z`), all three families, R = 400. **~36 CPU-h.**

Expect failure. That is the point: a documented failure mode is worth more than
an untested claim.

### P3 — FIPTIW under weak positivity

Directly probes the leading hypothesis for the 0.914 result. The current DGP's
propensity is `invlogit(0.5 + 0.8*K1 + 0.05*K2 - K3)`; tightening those
coefficients sharpens overlap, loosening them worsens it. Two extra cells at
R = 400 bracket the current one. **~24 CPU-h.**

Requires a knob on the propensity coefficients, which the DGP does not currently
expose — a small change to `_inf_dgp_fiptiw`.

### P4 — Non-identity link

The audit's SOL-10 concerns marginal/ATE language under nonlinear links. Coverage
under logit is a different question from coverage under identity, and the package
supports both. `iiw` and `fiptiw` with a binomial outcome, R = 400.
**~24 CPU-h.**

Requires a logit arm in the DGP/runner; the current families are Gaussian.

### P5 — Small cluster count

Cluster-robust and cluster-bootstrap variances are anticonservative with few
clusters, and `iivw_fit` already warns below 40. Confirm where the default
interval actually degrades: `iiw` at n = 40 and n = 80, R = 400.
**~12 CPU-h** (small n is cheap).

## Total

**~132 CPU-hours**, about **17 hours wall-clock at `WORKERS=8`**, or two to
three shared-machine nights. That is materially less than the "another overnight
run per dimension" first estimate, because diagnostic cells do not need
`COVERAGE_R = 1000`.

## The constraint on executing this

**P2 through P5 all require changing `validation_iivw_inference.do`** — the
release gate file. Each runner hard-codes its visit model (`visit_cov(Z)` at
`:224` and `:359`), so even P2's misspecification arm needs a knob; the DGP's
propensity coefficients are likewise fixed, and the outcome families are all
Gaussian.

*(An earlier draft of this file claimed P2 needed no new knobs. That was wrong —
the runner hard-codes `visit_cov(Z)`. Corrected 2026-07-23.)*

**Only P1 (sample size) runs against the file as it stands**, because `nsub` is
the one knob that has been exposed — and exposing it is precisely what reopened
the pool-contamination hole that `blk_nsub` now closes. Every previous change to
this file introduced a defect that had to be found later, twice. It should not
be extended further until the current changes have had independent review.

## The rule that still applies

Any cell run here is a **diagnostic**, not a gate, unless it uses
`COVERAGE_R = 1000` at the family's default `nsub`. `combine` enforces exactly
that: `blk_nsub` must be 0 and `blk_sims` must equal `COVERAGE_R`, so a
diagnostic cell cannot be reported as a gate verdict even by accident. Report
diagnostic cells with their own R and their own MCSE, and never fold them into
the headline coverage number.
