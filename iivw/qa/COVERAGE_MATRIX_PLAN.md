# SOL-04 coverage matrix — costed plan for the remaining cells

**Written 2026-07-23, after the first cell ran.** The 2026-07-22 run covered
**one correctly specified scenario per weight family at one sample size**. SOL-04
asks for considerably more. This file costs the remainder from measured
runtime rather than guesswork, and orders it by what actually bears on release
risk.

## What the measured run tells us about cost

| Quantity | Measured |
|---|---|
| One 50-replication `iiw` block at `REPS=999`, idle box | **89.7 min** |
| All 60 blocks (3 families x 1000 reps) | **~90 CPU-hours** |
| Wall-clock at `WORKERS=8`, shared box | **8h55m** |

So **one family-cell of 1000 replications costs ~30 CPU-hours**, or ~3.75 h
wall-clock at 8 workers. That is the unit of currency below.

A diagnostic cell does not need 1000 replications. To resolve a coverage
proportion near 0.92 to +/-0.02 needs R ~ 500; to distinguish a variance ratio
of 0.86 from 1.00 needs far less. **R = 250-400 is adequate for every
diagnostic row below**, which is why the costs are not simply 30 CPU-h each.

## Priority order

Ordered by what would change a release decision, not by matrix tidiness.

### P1 — Does the FIPTIW shortfall shrink with n? *(running 2026-07-23)*

The only question whose answer changes how FIPTIW must be *documented*. If the
deficit is finite-sample it is a small-sample caveat; if it persists, the
asymptotic variance does not describe this estimator and that is a much stronger
statement.

`fiptiw` at n = 600 and n = 1200, R = 200 each. **~36 CPU-h.**
n = 300 (R = 1000) is already in hand as the third point.

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

## Two constraints on executing this

1. **P3 and P4 require changing `validation_iivw_inference.do`** — the release
   gate file — to expose new DGP knobs and a logit arm. Every previous change to
   that file's aggregation path introduced a defect that later had to be found
   (twice). It should not be extended further until the current changes have had
   independent review.
2. **Only P1 and P2 need no new knobs** and can run against the file as it
   stands.

## The rule that still applies

Any cell run here is a **diagnostic**, not a gate, unless it uses
`COVERAGE_R = 1000` at the family's default `nsub`. `combine` enforces exactly
that: `blk_nsub` must be 0 and `blk_sims` must equal `COVERAGE_R`, so a
diagnostic cell cannot be reported as a gate verdict even by accident. Report
diagnostic cells with their own R and their own MCSE, and never fold them into
the headline coverage number.
