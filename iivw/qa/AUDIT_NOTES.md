# iivw QA audit notes

This page preserves durable interpretation that does not belong in the runnable QA index. Runtime pass/fail counts live only in suite `RESULT:` sentinels and `run_all_status.txt`.

## Evidence hierarchy

- The strongest weight-construction oracle is parity with `IrregLong` on the visit-model coefficient and weights after terminal censoring rows and lags are rebuilt independently.
- Outcome GEE parity is checked against `geepack`; stabilized IPTW also has a saturated hand-computed oracle and a mean-one identity.
- FIPTIW correctness leads with known-truth recovery: only the product weight should recover the treatment effect when treatment drives both monitoring and outcome.
- The stacked sandwich is checked by independent matrix reconstruction, zero-derivative collapse to the fixed sandwich, and nonzero nuisance-correction fixtures.

## Historical false-green defects

- A visit-row-only risk set ended follow-up at each subject's last visit and attenuated the visit-model coefficient. Current `censor()` and `maxfu()` routes append terminal event-0 intervals; `endatlastvisit` is an explicit compatibility acknowledgment.
- Stabilized IIW once lacked an outcome-design gate. Current `iivw_fit` refuses a stored stabilizer source absent from the expanded outcome design.
- An incomplete bootstrap once returned inference without disclosing failed draws. Current inference contracts require full completion unless `allowfailedreps` is explicit.
- A split SMCL directive once passed source-text checks but rendered literal markup. The release suite now checks line-level SMCL integrity, and agent-side audits also run Stata's renderer.
- A shell-success-only runner could miss malformed or absent suite sentinels. `run_all.sh` now validates the runner verdict, status file, sentinel arithmetic, failures, and skips.
- Captured `exit` statements once bypassed varabbrev cleanup on selected error and helper-success paths. The release adversarial suite exercises those exact branches.

## Inference boundary

IIW and IPTW use the nuisance-refitting bootstrap route by default, but the current build is stamped `uncleared-current-build` until its long-run gate is reproduced against the source manifest. Bare FIPTIW remains point-only because the retained stacked-sandwich study is explicitly diagnostic rather than a release coverage gate. Explicit `vce(stacked)` remains available and is stamped as empirically uncleared.

The preregistered long-run designs and receipts live in `TOLERANCE_FRAMEWORK.md`, `COVERAGE_GATE_RUNBOOK.md`, and `coverage_results/`. Do not promote a diagnostic screen into a release claim without the corresponding gate.

## Method and oracle maps

- `METHOD_CONTRACT.md` records estimator assumptions and supported boundaries.
- `METHOD_ORACLE_MAP.md` maps each mathematical claim to an independent oracle.
- `CROSSVAL_MODULE_MAP.md` records which R module grounds each parity surface.
