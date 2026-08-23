# comorbidity QA

The `comorbidity` QA suite is flat and concern-oriented, with functional, regression, source-definition, and known-answer suites driven by a curated lane runner. Every suite is independently runnable from this directory.

## How to run

```bash
cd comorbidity/qa
stata-mp -b do run_all.do            # full lane (default gate)
stata-mp -b do run_all.do quick      # fast functional lane
stata-mp -b do test_regressions.do   # one suite standalone
```

Each suite and the runner emit a terminal `RESULT:` line and exit nonzero on failure.

## Isolation

`run_all.do` and each suite write logs into the current `qa/` directory. Concurrent runs of the same lane can corrupt those logs; the tell is a `run_all.log` result that disagrees with a suite's own log.

For concurrent or gate runs, copy the package as `<scratch>/<repo-name>/comorbidity` and the dependency as `<scratch>/Stata-Tools/codescan`, remove copied `qa/*.log`, and run from the copied `comorbidity/qa` directory. The repository names must be retained because the bootstrap derives the dependency path from `c(pwd)`.

## Conventions

- `test_*` files cover functional, regression, state-preservation, and install behavior; `validation_*` files use hand-computable or source-tabulated known answers; `crossval_comorbidity_r.do` compares the Quan ICD-10 indicator mappings and original/Quan/van Walraven scores with R's `comorbidity` package.
- Every runnable suite ends with `RESULT: <name> tests=N pass=N fail=N [skip=N]` and exits nonzero on failure. The full lane accepts no dependency skips.
- Suites sandbox `SITE`, `PLUS`, `PERSONAL`, and `OLDPLACE` under `c(tmpdir)` through `_comorbidity_qa_common.do`; the user's real ado tree is untouched and the process-local settings disappear when Stata exits.
- Paths derive from `c(pwd)`; no suite contains a machine-local path.
- Test data and custom dictionaries are generated at runtime; there are no tracked QA data fixtures.
- Generated `.log`, `.smcl`, `.dta`, `.xlsx`, and `output/` artifacts are gitignored; only package `demo/` assets may be tracked generated files.
- Section bookmarks use `**#`; assertions are grouped into independently counted test blocks.

## Dependencies

| Suite or lane | Needs | If missing |
|---|---|---|
| All command-level suites | Local `Stata-Tools/codescan` sibling checkout | Hard failure during sandbox bootstrap |
| `test_comorbidity_install.do` | No visible `codescan` installation inside its dependency sandbox | The suite fails unless `comorbidity` exits cleanly with `r(199)` |
| `crossval_comorbidity_r.do` | `Rscript`, R `comorbidity` 1.1.0, and `haven` | Hard failure; the central environment installs and records the exact R package version |

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_comorbidity.do` | Public index schemes, output shapes, prefixes, replacement, windows, hierarchy control, and returned values |
| `test_regressions.do` | Failure atomicity, structural output collisions, patient-level bands, negative scores, and post-hierarchy summaries |
| `test_documentation_examples.do` | Executable help and README workflows for Charlson, Elixhauser, merge, windows, and custom dictionaries |
| `test_comorbidity_adversarial.do` | Invalid schemes, missing identifiers, malformed custom files, and `varabbrev` restoration |
| `test_comorbidity_hostile.do` | Structural score-name collision, empty input, quoted custom path, repeated merge, and row/value preservation |
| `test_comorbidity_install.do` | Fresh install behavior when the required `codescan` dependency is absent |
| `test_dictionary.do` | Built-in dictionary shape and the guarded unimplemented AHRQ surface |
| `test_weights.do` | Charlson original, Quan 2011, and van Walraven weight vectors |
| `test_hierarchy.do` | Charlson and Elixhauser supersession rules |
| `crossval_comorbidity_r.do` | R `comorbidity` 1.1.0 parity for Quan ICD-10 indicators and Charlson original, Charlson Quan, and Elixhauser van Walraven scores |

### Validation

| File | Covers |
|---|---|
| `validation_comorbidity.do` | Hand-computable Charlson, Elixhauser, and custom weighted scores |
| `validation_dictionary_quan2005.do` | Boundary inclusions and exclusions from Quan et al. (2005), Table 2 |

### Support

| Path | Contents |
|---|---|
| `run_all.do` | Explicit `quick`, `core`, and `full` lane membership with suite-level failure propagation |
| `_comorbidity_qa_common.do` | Temporary sysdir sandbox, local package/dependency installation, and terminal result helper |
| `.gitignore` | Generated QA artifact policy |

## Coverage map

| Command | Functional and regression | Validation | Also exercised in |
|---|---|---|---|
| `comorbidity` | `test_comorbidity.do`, `test_regressions.do`, `test_comorbidity_adversarial.do`, `test_comorbidity_hostile.do` | `validation_comorbidity.do`, `validation_dictionary_quan2005.do` | `test_documentation_examples.do`, `test_comorbidity_install.do` |

Private dictionaries, weights, and hierarchy helpers are covered directly by their corresponding `test_dictionary.do`, `test_weights.do`, and `test_hierarchy.do` suites.

## Lane membership

`quick` ⊆ `core` ⊆ `full`; `full` is the default package gate.

| Lane | Suites |
|---|---|
| `quick` | `test_dictionary.do`, `test_weights.do`, `test_hierarchy.do`, `test_comorbidity.do`, and `test_comorbidity_errors.do` |
| `core` | `quick` plus `test_regressions.do`, `test_documentation_examples.do`, both `validation_*` suites, `test_comorbidity_adversarial.do`, and `test_comorbidity_hostile.do` |
| `full` | `core` plus `test_comorbidity_install.do` and `crossval_comorbidity_r.do` |

## Known gaps

The Stata help render axis is checked outside these lanes with the devkit `artifact help` and package checks. The R cross-validation covers the Quan ICD-10 mapping plus the published original Charlson, Quan 2011, and van Walraven weight surfaces; it does not cover AHRQ schemes, which are intentionally unimplemented.
