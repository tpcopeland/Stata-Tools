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
`_codescan_qa_bootstrap` once, which sandboxes `PLUS`/`PERSONAL` under
`c(tmpdir)` and installs the local package copy. Each suite is also
independently runnable from `qa/` (it reinstalls the local copy itself).

## Conventions

- Every suite ends with `RESULT: <name> tests=N pass=N fail=N` and `exit 1`
  on any failure. Runners and `qa parse` key on that line.
- No decorative display lines; `**#`/`**##` bookmarks mark sections.
- Test data is built inline (seeded `input` blocks / generators); no `.dta`
  fixtures are tracked. Generated `.dta`/`.xlsx`/`.csv`/`.log` artifacts land
  at the `qa/` root and are gitignored.
- Paths are derived from `c(pwd)` — nothing hardcodes a home or repo path.

## File index

Test counts below are the `RESULT: ... tests=N` totals each suite reports.

| File | Type | Tests | What it covers |
|------|------|------:|----------------|
| `test_codescan.do` | functional | 308 | Core `codescan` behaviour across every option |
| `test_countrows.do` | functional | 24 | `countrows`/`countmode` counting semantics |
| `test_mata_opt.do` | functional | 14 | Mata fast-path: match accumulation, co-occurrence, multi-window, describe hash |
| `test_codescan_regressions.do` | functional | 18 | Fixed-bug regression guards (incl. output-name vs id/date/refdate collisions) |
| `test_codescan_v2_no_scoring.do` | functional | 4 | v2.0 contract: `score()`/`hierarchy()` rejected (rc=198), basename codefile gone (rc=601), core scan intact |
| `test_codescan_v203_hardening.do` | functional | 14 | v2.0.3: malformed-regex rejection (compile-probe, define()+codefile()+exclusion), unicode `nocase` (å/Å), ASCII regression guard, `r(n_excluded_missingdate)` |
| `test_codescan_perf_equiv.do` | functional | 5 | v2.0.4: distinct-value memoization equivalence vs brute-force reference + row-order determinism |
| `test_codescan_adversarial.do` | functional | 11 | Hostile inputs: wide varlists, metachars, dup IDs/dates |
| `test_codescan_describe_adversarial.do` | functional | 9 | `codescan_describe` hostile inputs |
| `test_codescan_stress_adversarial.do` | functional | 6 | Scale/sparsity/name-collision stress |
| `test_codescan_install_docs.do` | functional | 11 | `net install` smoke + help/README example reality |
| `test_documentation_examples.do` | functional | 8 | Every documented example runs as shown |
| `test_release_integrity.do` | functional | 6 | Version sync, `.pkg`/`stata.toc` surface, no dev paths/debris |
| `validation_codescan.do` | validation | 65 | Hand-computed oracles for `codescan` |
| `validation_codescan_known_answers.do` | validation | 8 | Known-answer matrix across option combinations |
| `validation_codescan_dgp_recovery.do` | validation | 23 | DGP known-answer recovery: simulated wide-format code data with an independent (ustrregexm/substr/date-arithmetic/Wilson) oracle across matching, windows, counting, collapse/merge, cooccurrence, sensitivity, CI, and describe |
| `validation_mata.do` | validation | 8 | Known-answer equivalence for the Mata fast paths |
| `validation_codescan_io.do` | validation | 5 | Save/export/saving artifact fidelity |
| `validation_codescan_output.do` | validation | 3 | Graph/co-occurrence output structure and failed-export cleanup |
| `validation_codescan_describe.do` | validation | 6 | `codescan_describe` oracles |
| `validation_codescan_describe_adversarial.do` | validation | 9 | `codescan_describe` adversarial oracles |
| `validation_codescan_crosscheck.do` | validation | 33 | `codescan` vs hand-computed `regexm()`/manual collapse |
| `validation_countrows.do` | validation | 8 | `countrows` oracles |
| `_codescan_qa_common.do` | scaffold | — | Sandboxed-install bootstrap |
| `run_all.do` | runner | — | Curated lane runner |
| `benchmark_codescan_scale.do` | benchmark | — | Manual wall-time guardrail (1M/5M × 30 vars × 20 conds, prefix vs ICU regex); not in any lane |
| `tools/check_codescan_artifacts.py` | tool | — | Package-local `.xlsx`/`.dta` artifact checker |

There is no true cross-validation suite: `codescan` has no external R/Python
reference implementation, so all numeric checks are validation against
hand-computable oracles.

## Coverage map

`qa contract codescan` reports full coverage of the public surface:

| Command | Options | Returns | Status |
|---------|--------:|--------:|--------|
| `codescan` | 36/36 | 12/12 | covered |
| `codescan_describe` | 4/4 | 6/6 | covered |

Headline coverage by area: option-by-option (`test_codescan.do`,
`validation_codescan.do`), counting modes (`*countrows*`), date windows
(`lookback`/`lookforward`/`refdate`), codefiles & I/O & export failure cleanup
(`validation_codescan_io.do`, `validation_codescan_output.do`), Mata fast
paths (`test_mata_opt.do`, `validation_mata.do`), the v2.0 no-scoring
contract (`test_codescan_v2_no_scoring.do`), and the release surface
(`test_release_integrity.do`).

## Lane membership

| Suite | quick | core | full |
|-------|:---:|:---:|:---:|
| `test_codescan` | ✓ | ✓ | ✓ |
| `test_countrows` | ✓ | ✓ | ✓ |
| `test_mata_opt` | ✓ | ✓ | ✓ |
| `test_codescan_regressions` | ✓ | ✓ | ✓ |
| `test_codescan_v2_no_scoring` | ✓ | ✓ | ✓ |
| `test_codescan_v203_hardening` | ✓ | ✓ | ✓ |
| `test_codescan_perf_equiv` | ✓ | ✓ | ✓ |
| `validation_codescan` | ✓ | ✓ | ✓ |
| `validation_countrows` | ✓ | ✓ | ✓ |
| `validation_codescan_known_answers` |  | ✓ | ✓ |
| `validation_codescan_dgp_recovery` |  | ✓ | ✓ |
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

`quick` ⊆ `core` ⊆ `full`. Every runnable suite belongs to at least one lane;
there is no `_skip.txt`.

## Adversarial coverage notes

The adversarial and stress suites concentrate on wide varlists, sparse
strings, punctuation and regex metacharacters, case variation, missing IDs
and dates, duplicate IDs, numeric `tostring`, output-name collisions, invalid
option combinations, repeated calls in one session, installation behaviour,
documentation examples, and release metadata.
`run_all.do` restores `c(pwd)` to the QA directory after each suite so an
install-smoke test cannot poison downstream path derivation.
