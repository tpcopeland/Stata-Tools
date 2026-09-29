# consort QA

## How to run

From this directory:

```sh
stata-mp -b do run_all.do full
```

Use `quick` for the review regressions or `core` for core contracts. The default lane is `full`. Optional `_skip.txt` entries use `suite.do | reason`; skipped suites are recorded explicitly.

## Isolation

The runner installs into temporary PLUS/PERSONAL directories. Run lanes from a scratch copy of the package to keep logs and outputs isolated from concurrent work. Give each Stata process its own working directory and a `profile.do` setting `set processors 1`.

## Conventions

- `test_` files check behavior; `validation_` files check known counts.
- Numeric `RESULT:` totals reconcile passes, failures and executed checks.
- Install tests use the package manifest in the sandbox.
- Paths derive from `c(pwd)` and `c(tmpdir)`.
- Tests create their own synthetic data.
- Logs, diagrams, workbooks and temporary datasets are disposable generated artifacts.

## Dependencies

Stata 16+, Python 3 with matplotlib, Pillow and openpyxl. Unix executable-path tests use `ln` and `/bin/false`.

## File index

| File | Purpose |
|---|---|
| `run_all.do` | Curated lane runner |
| `test_consort.do` | Core functional routes |
| `test_consort_edge_cases.do` | Large counts and output formats |
| `test_consort_expanded.do` | Expanded options and error paths |
| `test_consort_v104.do` | Settings, install and help checks |
| `test_consort_v106.do` | Literal macro labels and zero matches |
| `test_consort_v110.do` | CSV/XLSX content and data preservation |
| `test_consort_v112.do` | Review regressions: population identities, path aliases, quotes, records, renderer failures and label parity |
| `validation_consort.do` | Known-answer counts |
| `validation_consort_expanded.do` | Additional count invariants |
| `test_consort_help.do` | Viewer render and deliberately broken positive control |
| `_qa_state.do` | Vendored caller-state fingerprint helper |
| `_qa_hostile.do` | Vendored hostile literal fixtures |
| `tools/check_review.py` | Independent CSV/workbook content checks, layout text and raster decoding |
| `.gitignore` | Generated artifact exclusions |

## Coverage map

| Command | Functional | Validation | Artifacts |
|---|---|---|---|
| `consort init/exclude/save/clear` | Core, expanded and version regressions | Both validation suites | CSV/XLSX values, PNG contents, help rendering and installed source |

## Lane membership

| Lane | Membership |
|---|---|
| quick | `test_consort_v112`, `test_consort_help` |
| core | quick plus `test_consort`, `test_consort_v104`, `test_consort_v106`, `test_consort_v110`, `validation_consort` |
| full | core plus `test_consort_expanded`, `test_consort_edge_cases`, `validation_consort_expanded` |

`quick` is a subset of `core`, which is a subset of the default release gate `full`.
