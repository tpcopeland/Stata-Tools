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
| `test_rangematch_adversarial.do` | Parser failures, cleanup, varabbrev, collisions, internal-name regressions |
| `test_rangematch_return_contract.do` | Stored-result scalars and locals across output modes |
| `test_rangematch_routing_contract.do` | `frame()`, `saving()`, `dryrun`, and `count` routing contracts |
| `test_rangematch_display_contract.do` | Display-only and count/dryrun display contracts |
| `test_rangematch_backend_equivalence.do` | Binary/sweep/overlap backend equivalence checks |
| `test_rangematch_saving_matrix.do` | Saved-output routing and matrix-like result consistency |
| `test_rangematch_abbrev.do` | Minimum option abbreviations |
| `test_rangematch_v*.do` | Version-specific regression suites |
| `validation_rangematch_oracle.do` | Known-answer oracle scenarios |
| `validation_rangematch_manual.do` | Manual count/statistic validation |
| `validation_rangematch_nearest.do` | Nearest/ties validation scenarios |

## Coverage Map

| Command | Functional | Validation | Cross-val | Also Exercised In |
|---------|------------|------------|-----------|-------------------|
| `rangematch` | install, basic, by, overlap, missing, adversarial, return/routing/display/backend/saving, version regressions | manual, nearest, oracle | N/A | documentation examples and release integrity |

`rangematch` is a deterministic data-join command, so no external R/Python
cross-validation suite is required. The validation layer uses hand-built oracle
datasets and invariant checks.

## Lane Membership

| Lane | Suites |
|------|--------|
| `quick` | `test_install.do`, `test_rangematch_basic.do`, `test_rangematch_by.do`, `test_rangematch_overlap.do`, `test_rangematch_missing.do`, `test_rangematch_v110.do`, `test_rangematch_v120.do`, `test_rangematch_v130.do`, `test_rangematch_v140.do`, `test_rangematch_v141.do`, `test_rangematch_v144.do`, `test_rangematch_v145.do`, `test_rangematch_v147.do`, `test_rangematch_v148.do`, `test_rangematch_v101.do`, `test_rangematch_missing_option.do`, `test_rangematch_missing_option_extra.do`, `test_rangematch_abbrev.do`, `test_rangematch_adversarial.do`, `test_rangematch_return_contract.do`, `test_rangematch_display_contract.do`, `test_rangematch_routing_contract.do`, `test_rangematch_backend_equivalence.do`, `test_rangematch_saving_matrix.do`, `test_rangematch_v16compat.do`, `test_documentation_examples.do`, `test_release_integrity.do` |
| `full` | All `quick` suites plus `validation_rangematch_oracle.do`, `validation_rangematch_manual.do`, `validation_rangematch_nearest.do` |
