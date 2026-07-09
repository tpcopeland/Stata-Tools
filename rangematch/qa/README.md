# rangematch QA suite

The `rangematch` QA suite uses a flat `qa/` root and one curated lane runner,
`run_all.do`. The tests cover the single public command through functional,
adversarial, routing, return-contract, documentation-example, install, release,
and known-answer validation suites. Test data are generated at runtime with
temporary files; generated logs are ignored.

## How to run

```bash
cd rangematch/qa
stata-mp -b do run_all.do
stata-mp -b do run_all.do quick
```

`full` is the default release gate and adds all validation suites to the
functional tests. `quick` runs the functional and release-surface suites only.
The runner uses an explicit suite list rather than auto-discovery and exits
nonzero if any suite fails. Every `.do` file is runnable directly from `qa/`.

## Conventions

- `test_*.do` files cover functional, option, state, regression, release, and
  adversarial contracts for the public command.
- `validation_*.do` files contain hand-computable or invariant oracles.
- `run_all.do` emits `RESULT: run_all suites=N pass=N fail=N` for log parsing;
  newer suite files also emit `RESULT:` sentinels.
- Paths are derived from `c(pwd)` and temporary files. No QA file should depend
  on a machine-local repository path.
- Runtime debris (`*.log`, `*.smcl`, workbooks, generated data) stays untracked.

## File Index

| File | Covers |
|------|--------|
| `run_all.do` | Curated `quick` and `full` lane runner |
| `test_install.do` | Local install, public command resolution, basic installed-user run |
| `test_documentation_examples.do` | README/help examples as installed-user workflows |
| `test_release_integrity.do` | Version/date/package surface and release metadata |
| `test_rangematch_basic.do` | Basic point-in-interval joins, unmatched rows, naming, maxpairs |
| `test_rangematch_by.do` | `by()` partitioning and grouped joins |
| `test_rangematch_overlap.do` | Interval-overlap mode and overlap option interactions |
| `test_rangematch_missing*.do` | Missing-bound policy and missing-option edge cases |
| `test_rangematch_missing.do` | Baseline missing-bound behavior |
| `test_rangematch_missing_option.do` | `missing()` policy and routing cases |
| `test_rangematch_missing_option_extra.do` | Extended missing-policy interactions |
| `test_rangematch_adversarial.do` | Parser failures, cleanup, varabbrev, collisions, internal-name regressions |
| `test_rangematch_return_contract.do` | Stored-result scalars and locals across output modes |
| `test_rangematch_routing_contract.do` | `frame()`, `saving()`, `dryrun`, and `count` routing contracts |
| `test_rangematch_display_contract.do` | Display-only and count/dryrun display contracts |
| `test_rangematch_backend_equivalence.do` | Binary/sweep/overlap backend equivalence checks |
| `test_rangematch_backend_diff.do` | Differential sweep-versus-binary backend grid |
| `test_rangematch_edge_topup.do` | Zero-row, missing-bound, maxpairs-boundary, and restore edge cases |
| `test_rangematch_float_warn.do` | Float precision warnings and false-positive guards |
| `test_rangematch_labels.do` | Variable, value-label, and dataset-label preservation |
| `test_rangematch_missing_using.do` | Using-side missing-key/bound policies |
| `test_rangematch_overlap_inverted.do` | Inverted using-interval warning and return contract |
| `test_rangematch_ties_random.do` | Random tie-breaking, seed reproducibility, and RNG restoration |
| `test_rangematch_saving_matrix.do` | Saved-output routing and matrix-like result consistency |
| `test_rangematch_abbrev.do` | Minimum option abbreviations |
| `test_rangematch_v*.do` | Version-specific regression suites |
| `test_rangematch_v101.do` | v1.0.1 file/frame source regressions |
| `test_rangematch_v110.do` | v1.1.0 overlap and routing regressions |
| `test_rangematch_v120.do` | v1.2.0 missing and precision regressions |
| `test_rangematch_v130.do` | v1.3.0 random ties and inverted intervals |
| `test_rangematch_v132.do` | v1.3.2 deterministic overlap ordering and lower-bound maxpairs messaging |
| `test_rangematch_v133.do` | v1.3.3 maxpairs, session-state, naming, label, and return-gate regressions |
| `test_rangematch_v140.do` | Backend and return-contract regressions |
| `test_rangematch_v141.do` | Output-order regressions |
| `test_rangematch_v144.do` | Count/assert regressions |
| `test_rangematch_v145.do` | Routing and state regressions |
| `test_rangematch_v147.do` | Distance conformability and backend regressions |
| `test_rangematch_v148.do` | Sweep/binary/overlap backend regressions |
| `test_rangematch_v16compat.do` | Stata 16.1 compatibility surface |
| `validation_rangematch_oracle.do` | Known-answer oracle scenarios |
| `validation_rangematch_manual.do` | Manual count/statistic validation |
| `validation_rangematch_nearest.do` | Nearest/ties validation scenarios |
| `validation_rangematch_known_answers.do` | 21 hand-computed scenarios: 4 closure rules, inverted/degenerate intervals, wildcard vs literal open bounds, `missing()` policy, scalar key-offsets, `by()` isolation, match statistics, `maxpairs()` guard, point-mode distance, tolerance boundaries, full-outer accounting, overlap incl. open-ended bounds |

## Coverage Map

| Command | Functional | Validation | Cross-val | Also Exercised In |
|---------|------------|------------|-----------|-------------------|
| `rangematch` | install, basic, by, overlap, missing, adversarial, return/routing/display/backend/saving, version regressions | known_answers, manual, nearest, oracle | N/A | documentation examples and release integrity |

`rangematch` is a deterministic data-join command, so no external R/Python
cross-validation suite is required. The validation layer uses hand-built oracle
datasets and invariant checks.

## Lane Membership

| Lane | Suites |
|------|--------|
| `quick` | All `test_*.do` suites listed in `run_all.do`, including the complete backend, edge, label, missing-using, tie, version-regression, documentation, install, and release gates |
| `full` | All `quick` suites plus `validation_rangematch_oracle.do`, `validation_rangematch_manual.do`, `validation_rangematch_nearest.do`, `validation_rangematch_known_answers.do` |
