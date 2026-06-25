# datefix QA suite

`datefix` converts string date variables to numeric, date-formatted variables.
This `qa/` directory follows the house layout: a flat root of self-contained,
concern-named `.do` suites driven by one curated lane runner (`run_all.do`).
Every suite is independently runnable from `qa/` and ends with a machine-parseable
`RESULT:` sentinel.

## How to run

```bash
cd datefix/qa
stata-mp -b do run_all.do            # full lane (default release gate)
stata-mp -b do run_all.do quick      # fast functional lane
```

`run_all.do` runs a curated per-lane suite list (not auto-discovery), sandboxes
PLUS/PERSONAL under `c(tmpdir)` via `_datefix_qa_common.do` so the real ado tree
is never touched, runs each suite, and exits nonzero if any suite fails. Each
suite also self-bootstraps (`ado uninstall` + `net install` from the package
dir), so its install lands in the same sandbox when run under the runner and in
the real tree when run standalone for debugging.

## Conventions

- **Prefixes:** `test_*` = functional/regression; `validation_*` = hand-computable
  known-answer / invariant oracles (no external interpreter). datefix is a
  deterministic string→date transform, so it owns no parameter-recovery or
  cross-validation suite — known-answer validation is the correctness oracle.
- **Sentinel contract:** every suite ends with
  `RESULT: <name> tests=N pass=N fail=N` and `exit 1` on any failure.
- **Relocatable paths:** suites derive the package dir from `c(pwd)`; no
  hardcoded `/home/...` or `~/Stata-...` paths.
- **Runtime-built data:** every suite builds its own data inline via `input`;
  no tracked `.dta` fixtures.
- **Artifacts gitignored:** `.log`/`.smcl`/transient `.dta` are never tracked.

## File index

### Command-level tests

| File | Command | Covers |
|------|---------|--------|
| `test_datefix.do` | `datefix` | Core conversion, all options, error handling, edge cases, data preservation, varabbrev restore, install discoverability |
| `test_datefix_expanded.do` | `datefix` | Pre-1960 dates, separators, auto-detect tie-breaking, `topyear()`+auto-detect, mixed types, in-place label transfer, redundant-drop note, large/constant/duplicate data, format styles |
| `test_diagnose.do` | `datefix` | `diagnose` option: report-then-abort on all three failure paths (auto-detect, explicit `order()`, datetime detection), non-destructive guarantee, distinct-value grouping/frequencies, `diag` abbreviation, >50-distinct capped path |

### Validation

| File | Covers |
|------|--------|
| `validation_datefix.do` | Known-answer date parsing (days since 1960), YMD/DMY/MDY formats, leap years, duration invariants, missing-in=missing-out, format-independence, agreement with Stata's `date()` |

### Support

| Path | Contents |
|------|----------|
| `run_all.do` | Curated lane runner (quick/full) |
| `_datefix_qa_common.do` | Sandboxed install bootstrap (`_datefix_qa_bootstrap`) |
| `.gitignore` | Ignores generated logs and transient `.dta` |

## Coverage map

| Surface | Functional | Validation |
|---------|-----------|------------|
| `datefix` (conversion) | `test_datefix`, `test_datefix_expanded` | `validation_datefix` |
| `newvar()` | `test_datefix`, `test_datefix_expanded` | — |
| `drop` | `test_datefix`, `test_datefix_expanded` | — |
| `df()` | `test_datefix`, `test_datefix_expanded` | `validation_datefix` |
| `order()` | `test_datefix`, `test_datefix_expanded` | `validation_datefix` |
| `topyear()` | `test_datefix`, `test_datefix_expanded` | — |
| `diagnose` | `test_diagnose` | — |

## Lane membership

| Lane | Suites |
|------|--------|
| `quick` | `test_datefix`, `test_diagnose` |
| `full` *(default)* | `quick` + `test_datefix_expanded`, `validation_datefix` |
