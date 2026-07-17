# codescan QA suite

Tests, validation, and release checks for the `codescan` package
(`codescan`, `codescan_describe`). The suite follows the house QA layout:
a flat `qa/` root, files named by concern then command, one curated lane
runner, and a shared install scaffold.

## How to run

```bash
cd codescan/qa
stata-mp -b do run_all.do            # full lane (default release gate)
stata-mp -b do run_all.do quick      # fast dev loop
stata-mp -b do run_all.do core       # all validation + adversarial, no install/docs
```

Or via the CLI:

```bash
python3 -m _devkit.stata_dev_cli qa run-file codescan run_all.do --arg full
python3 -m _devkit.stata_dev_cli qa parse codescan/qa/run_all.log
```

`run_all.do` sources `_codescan_qa_common.do` and calls
`_codescan_qa_bootstrap`, which sandboxes `PLUS`/`PERSONAL` under `c(tmpdir)`
and installs the local package copy. Every suite sources the same scaffold and
calls the same bootstrap, so running one file standalone sandboxes the install
too rather than mutating the developer's real adopath. The bootstrap is
idempotent, so the lane re-entering it per suite is harmless.

`test_codescan_install_docs.do` is the one deliberate exception: it builds its
own `PLUS`/`PERSONAL`/work sandbox and `cd`s into it, because its whole purpose
is to exercise the package as a freshly installed user sees it.

The last line of a run is the aggregate sentinel:

```
RESULT: run_all_full tests=26 pass=26 fail=0
```

Gate on that line, not on the shell exit status — `stata-mp -b do` exits 0 even
when the do-file ends in `r(1)`. An absent or malformed sentinel is itself a
failure, and a crashed runner cannot fake one.

### Dependency: Python + openpyxl

`validation_codescan_output.do` (core and full lanes) shells out to
`tools/check_codescan_artifacts.py`, which needs `python3` with **openpyxl**:

```bash
pip install --break-system-packages openpyxl
```

The suite probes for it and exits `499` when it is missing — it does not skip.
The `quick` lane has no Python dependency.

## Conventions

- Every suite ends with `RESULT: <name> tests=N pass=N fail=N` and `exit 1`
  on any failure. Runners and `qa parse` key on that line.
- No decorative display lines; `**#`/`**##` bookmarks mark sections.
- Test data is built inline (seeded `input` blocks / generators); no `.dta`
  fixtures are tracked. Generated `.dta`/`.xlsx`/`.csv`/`.log` artifacts land
  at the `qa/` root and are gitignored.
- Paths are derived from `c(pwd)` — nothing hardcodes a home, repo, or `/tmp/`
  path. Fixed `/tmp/` filenames are shared by every checkout and every
  concurrent run, so residue from an earlier run reads as this run's output;
  they also escaped the `qa/`-root cleanup in `run_all.do`.
- A suite that changes a session setting restores it **outside** the captured
  block, after saving `_rc`. Restoring before the `if _rc == 0` verdict would
  reset `_rc` and make the test pass unconditionally.
- Every suite ends with a settings-hygiene test asserting `c(level)`,
  `c(varabbrev)` and `c(pwd)` match what it started with, so a leak cannot
  cascade silently into the suites that run after it.

## File index

Test counts below are the `RESULT: ... tests=N` totals each suite reports.

| File | Type | Tests | What it covers |
|------|------|------:|----------------|
| `test_codescan.do` | functional | 309 | Core `codescan` behaviour across every option |
| `test_countrows.do` | functional | 25 | `countrows`/`countmode` counting semantics |
| `test_mata_opt.do` | functional | 15 | Mata fast-path semantics. Every block compares codescan against a naive Stata-level oracle (one `ustrregexm()` per cell, no memoization, no early exit) on an immutable reloaded fixture, so the optimizations must reproduce a brute-force scan exactly: row-level, collapse, merge, `countmode` (`total_hits` vs `positive_units`), nested/overlapping conditions, multi-window sensitivity **and** its `r(sensitivity_n)` denominators, describe vs a `reshape`+`levelsof` tabulation, `nodots` invariance, first-slot vs `allslots` detail, prefix, `nocase`, co-occurrence, and `matched_code` first-hit order |
| `test_codescan_regressions.do` | functional | 31 | Fixed-bug regression guards, including regex-escape-safe `nocase`, merge row order, non-mutating `tostring`, arbitrary describe row names, prefix validation, and path guards |
| `test_codescan_v208.do` | functional | 5 | v2.0.8: `label()` backslash preserved (Windows paths) + `\` separator still splits, bare `.`/all-dots skipped to match `codescan_describe`, `if` on numeric scan var works with `tostring` (proven-fail on pre-2.0.8) |
| `test_codescan_v300_critical.do` | functional | 46 | v3.0.0 critical and contract regressions, each proven red by mutating the fix out: transactional rollback (C1), empty-match regex rejection (C2), codefile optional-column typing (C3), extended-missing blanking (C4), file-overwrite authorization (C5), `r(sensitivity_n)` (I2), labels reaching console/graph/export while machine names stay put (I1), three-state `unmatched()` (I4), `total_hits` vs `positive_units` (I3), first-slot vs `allslots` detail attribution (I5) |
| `test_codescan_v2_no_scoring.do` | functional | 5 | v2.0 contract: `score()`/`hierarchy()` rejected (rc=198), basename codefile gone (rc=601), core scan intact |
| `test_codescan_v203_hardening.do` | functional | 15 | v2.0.3: malformed-regex rejection (compile-probe, define()+codefile()+exclusion), unicode `nocase` (å/Å), ASCII regression guard, `r(n_excluded_missingdate)` |
| `test_codescan_perf_equiv.do` | functional | 6 | v2.0.4: distinct-value memoization equivalence vs brute-force reference + row-order determinism |
| `test_codescan_adversarial.do` | functional | 12 | Hostile inputs: wide varlists, metachars, dup IDs/dates |
| `test_codescan_describe_adversarial.do` | functional | 10 | `codescan_describe` hostile inputs |
| `test_codescan_stress_adversarial.do` | functional | 7 | Scale/sparsity/name-collision stress |
| `test_codescan_install_docs.do` | functional | 12 | `net install` smoke + help/README example reality |
| `test_documentation_examples.do` | functional | 19 | Every documented example runs as shown, asserted against hand-computed expectations: README Quick Start, row-level indicators, regex/varlist, collapse+window, prefix, export+saving, exclusion, `frame()`, `merge`, multi-window (+`r(sensitivity_n)`), `save()`→`codefile()` reuse, hits-vs-cases + `allslots` attribution, `label()` reaching output while machine names stay put, and the `codescan_describe` `top()`, `save()`, `nodots`, `if`, and `tostring` examples |
| `test_release_integrity.do` | functional | 7 | Version sync, `.pkg`/`stata.toc` surface, no dev paths/debris |
| `validation_codescan.do` | validation | 66 | Hand-computed oracles for `codescan` |
| `validation_codescan_known_answers.do` | validation | 9 | Known-answer matrix across option combinations |
| `validation_codescan_dgp_recovery.do` | validation | 24 | DGP known-answer recovery (batch 1): simulated wide-format code data with an independent (ustrregexm/substr/date-arithmetic/Wilson) oracle across matching, windows, counting, collapse/merge, cooccurrence, sensitivity, CI, and describe |
| `validation_codescan_dgp_recovery2.do` | validation | 20 | DGP known-answer recovery (batch 2): the option/output paths batch 1 omitted — matched_code first-hit, unmatched flag, regex/prefix alternation in one condition, multi-pattern & prefix exclusion, multi-window lookback + fixed lookforward, merge-broadcast date/count summaries, countrows+collapse, countmode+merge, patient-level cooccurrence, tostring numeric codes, label() variable labels, detail varcounts first-slot attribution, combined multi-output collapse, alldates shorthand, empty/wide window contract, and a 99% Wilson CI |
| `validation_mata.do` | validation | 9 | Known-answer equivalence for the Mata fast paths |
| `validation_codescan_io.do` | validation | 6 | Save/export/saving artifact fidelity |
| `validation_codescan_output.do` | validation | 5 | Graph/co-occurrence output structure, failed-export cleanup, and `format()` propagation to XLSX cell formats. The XLSX checker derives its column letters from the expected header list, so a new export column moves every downstream cell check with it |
| `validation_codescan_describe.do` | validation | 7 | `codescan_describe` oracles |
| `validation_codescan_describe_adversarial.do` | validation | 10 | `codescan_describe` adversarial oracles |
| `validation_codescan_crosscheck.do` | validation | 34 | `codescan` vs hand-computed `regexm()`/manual collapse |
| `validation_countrows.do` | validation | 9 | `countrows` oracles |
| `_codescan_qa_common.do` | scaffold | — | Sandboxed-install bootstrap |
| `run_all.do` | runner | — | Curated lane runner |
| `benchmark_codescan_scale.do` | benchmark | — | Exploratory wall-time timing at 100k and 1M rows, prefix vs ICU regex; not in any lane |
| `benchmark_codescan_vs_manual.do` | benchmark | — | Exploratory head-to-head vs a hand-coded `gen`/`replace` + `regexm()` loop for the same task; asserts identical columns, reports the time ratio; not in any lane |
| `tools/check_codescan_artifacts.py` | tool | — | Package-local `xlsx` and `svg` artifact checker (openpyxl) |

Neither benchmark is a gate: both are **exploratory** and have no reproducible
wall-time threshold, because timings are machine- and load-dependent. They print
timings for a human to read; nothing fails on a slow run. Run them by hand:

```bash
stata-mp -b do benchmark_codescan_scale.do
stata-mp -b do benchmark_codescan_vs_manual.do
```

Performance *correctness* is gated instead by `test_codescan_perf_equiv.do`,
which is in every lane and asserts the memoized fast path returns exactly what
the brute-force reference returns.

There is no true cross-validation suite: `codescan` has no external R/Python
reference implementation, so all numeric checks are validation against
hand-computable oracles.

## Coverage map

`qa contract codescan` reports full coverage of the public surface:

| Command | Options | Returns | Status |
|---------|--------:|--------:|--------|
| `codescan` | 37/37 | 28/28 | covered |
| `codescan_describe` | 4/4 | 6/6 | covered |

`codescan` has 30 `return` statements but 28 distinct names. Two names are
returned from two places each, and both paths are exercised: `r(lookback)` as a
scalar for a single window and as a macro for several, and `r(newvars)` as the
created-variable list on the normal path and as an empty string after
`preserve`/`frame()`, where nothing is left in memory.

Headline coverage by area: option-by-option (`test_codescan.do`,
`validation_codescan.do`), counting modes (`*countrows*`), date windows
(`lookback`/`lookforward`/`refdate`), codefiles & I/O & export failure cleanup
(`validation_codescan_io.do`, `validation_codescan_output.do`), Mata fast
paths (`test_mata_opt.do`, `validation_mata.do`), the v2.0 no-scoring
contract (`test_codescan_v2_no_scoring.do`), the v3.0.0 critical contracts
(`test_codescan_v300_critical.do`), and the release surface
(`test_release_integrity.do`).

## Lane membership

| Suite | quick | core | full |
|-------|:---:|:---:|:---:|
| `test_codescan` | ✓ | ✓ | ✓ |
| `test_countrows` | ✓ | ✓ | ✓ |
| `test_mata_opt` | ✓ | ✓ | ✓ |
| `test_codescan_regressions` | ✓ | ✓ | ✓ |
| `test_codescan_v208` | ✓ | ✓ | ✓ |
| `test_codescan_v2_no_scoring` | ✓ | ✓ | ✓ |
| `test_codescan_v203_hardening` | ✓ | ✓ | ✓ |
| `test_codescan_v300_critical` | ✓ | ✓ | ✓ |
| `test_codescan_perf_equiv` | ✓ | ✓ | ✓ |
| `validation_codescan` | ✓ | ✓ | ✓ |
| `validation_countrows` | ✓ | ✓ | ✓ |
| `validation_codescan_known_answers` |  | ✓ | ✓ |
| `validation_codescan_dgp_recovery` |  | ✓ | ✓ |
| `validation_codescan_dgp_recovery2` |  | ✓ | ✓ |
| `validation_mata` |  | ✓ | ✓ |
| `validation_codescan_io` |  | ✓ | ✓ |
| `validation_codescan_output` |  | ✓ | ✓ |
| `validation_codescan_describe` |  | ✓ | ✓ |
| `validation_codescan_describe_adversarial` |  | ✓ | ✓ |
| `validation_codescan_crosscheck` |  | ✓ | ✓ |
| `test_codescan_adversarial` |  | ✓ | ✓ |
| `test_codescan_describe_adversarial` |  | ✓ | ✓ |
| `test_codescan_stress_adversarial` |  | ✓ | ✓ |
| `test_codescan_install_docs` |  |  | ✓ |
| `test_documentation_examples` |  |  | ✓ |
| `test_release_integrity` |  |  | ✓ |

`quick` ⊆ `core` ⊆ `full`. The `full` lane is the release gate: **26 suites,
723 assertions**. Every runnable suite belongs to at least one lane except the
two exploratory benchmarks above; there is no `_skip.txt`.

## Adversarial coverage notes

The adversarial and stress suites concentrate on wide varlists, sparse
strings, punctuation and regex metacharacters, case variation, missing IDs
and dates, duplicate IDs, numeric `tostring`, output-name collisions, invalid
option combinations, repeated calls in one session, installation behaviour,
documentation examples, and release metadata.
`run_all.do` restores `c(pwd)` to the QA directory after each suite so an
install-smoke test cannot poison downstream path derivation.
