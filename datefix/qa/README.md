# datefix QA

archetypes: A4

Canonical fixture adoption is in progress. Every returned daily date is compared with the canonical start date after string conversion/native pass-through and each output ownership mode. Leap/year boundaries, row shuffling, invalid-order refusal and shared long-name invariance are exercised. Spell overlap/length columns unused by the date parser are not counted as hostile parser evidence. Frozen generators and state/primitive helpers are byte-vendored from the devkit. New fixture suites join the core/full lane (full only where the runner has no core lane); additional route/minimum/domain cells reported by the fixture census remain explicit, and this declaration does not certify them.

New suite index: `test_fixture_names.do`, `validation_fixture_contract.do`.

The `datefix` QA suite is flat and concern-oriented: functional, regression, release-surface, and known-answer files at the `qa/` root are driven by one curated lane runner. Every suite is independently runnable from this directory.

## How to run

```bash
cd datefix/qa
stata-mp -b do run_all.do            # full lane (default release gate)
stata-mp -b do run_all.do quick      # fast functional/regression lane
stata-mp -b do test_datefix_v112.do  # one suite standalone
```

`run_all.do` exits nonzero if any suite fails; each suite and the runner end with a machine-parseable `RESULT:` sentinel.

## Isolation

Each batch process installs `datefix` into temporary PLUS/PERSONAL directories. Do not run the same lane concurrently from one working tree because Stata writes `run_all.log` in `qa/`; use a scratch copy that preserves the repository layout and remove copied logs before running.

## Conventions

- **Prefixes:** `test_*` files cover functional, regression, and package contracts; `validation_*` files use hand-computable known-answer and invariant oracles. `datefix` is a deterministic transform, so it needs neither parameter-recovery nor external cross-validation.
- **Sentinel contract:** every runnable suite ends with `RESULT: <name> tests=N pass=N fail=N` and exits nonzero on failure; the full lane accepts no failed suite.
- **Install isolation:** suites sandbox PLUS/PERSONAL under `c(tmpdir)` through `_datefix_qa_common.do`; batch-process termination restores the user's configured Stata paths.
- **Paths:** suites derive package paths from `c(pwd)` and contain no machine-local paths.
- **Data:** every fixture is generated at runtime; no tracked `.dta` input is required.
- **Artifacts:** generated `.log`, `.smcl`, and transient data are gitignored; only deliberate assets under `demo/` may be tracked.

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_datefix.do` | Core conversion, every option, error handling, data preservation, varabbrev restoration, and install discoverability |
| `test_datefix_expanded.do` | Separators, tie-breaking, `topyear()`, mixed input types, labels, formats, larger data, and option combinations |
| `test_diagnose.do` | Diagnostic failure paths, command-wide rollback, capped reporting, abbreviation, and incidental `r()` cleanup |
| `test_datefix_v112.do` | Colon-separated dates, zero-result guards, atomic all-missing rejection, and literal Unicode-safe diagnostic output |
| `test_package_release.do` | Fresh-install resolution, helper-dependent execution, help rendering, executable help examples, and the repo-root installed-user demo |

### Validation

| File | Covers |
|---|---|
| `validation_datefix.do` | Known daily-date values, YMD/DMY/MDY parity, leap years, date arithmetic, missing propagation, and agreement with Stata's `date()` |

### Support

| Path | Contents |
|---|---|
| `run_all.do` | Curated quick/full lane runner |
| `_datefix_qa_common.do` | Temporary PLUS/PERSONAL bootstrap and local package installation |
| `.gitignore` | Generated-log and transient-artifact exclusions |

## Coverage map

| Command | Functional and regression | Validation | Also exercised in |
|---|---|---|---|
| `datefix` | `test_datefix`, `test_datefix_expanded`, `test_diagnose`, `test_datefix_v112` | `validation_datefix` | `test_package_release` |

## Lane membership

`quick` is a subset of `full`; `full` is the default release gate.

| Lane | Suites |
|---|---|
| `quick` | `test_datefix`, `test_diagnose`, `test_datefix_v112` |
| `full` | `quick` + `test_datefix_expanded`, `validation_datefix`, `test_package_release` |
