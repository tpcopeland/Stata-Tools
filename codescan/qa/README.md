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

| File | Type | Tests | What it covers |
|------|------|------:|----------------|
| `test_codescan.do` | functional | 689 | Core `codescan` behaviour across every option |
| `test_countrows.do` | functional | 45 | `countrows`/`countmode` counting semantics |
| `test_mata_opt.do` | functional | 8 | Mata fast-path: match accumulation, co-occurrence, multi-window, describe hash |
| `test_codescan_regressions.do` | functional | 42 | Fixed-bug regression guards |
| `test_codescan_adversarial.do` | functional | 71 | Hostile inputs: wide varlists, metachars, dup IDs/dates |
| `test_codescan_describe_adversarial.do` | functional | 22 | `codescan_describe` hostile inputs |
| `test_codescan_stress_adversarial.do` | functional | 57 | Scale/sparsity/name-collision stress |
| `test_codescan_install_docs.do` | functional | 78 | `net install` smoke + help/README example reality |
| `test_documentation_examples.do` | functional | 63 | Every documented example runs as shown |
| `test_release_integrity.do` | functional | 2 | Version sync, `.pkg`/`stata.toc` surface, no dev paths/debris |
| `validation_codescan.do` | validation | 227 | Hand-computed oracles for `codescan` |
| `validation_codescan_known_answers.do` | validation | 97 | Known-answer matrix across option combinations |
| `validation_mata.do` | validation | 29 | Known-answer equivalence for the Mata fast paths |
| `validation_builtin_codefiles.do` | validation | 33 | Shipped Charlson/Elixhauser codefile answers |
| `validation_codescan_io.do` | validation | 82 | Save/export/saving artifact fidelity |
| `validation_codescan_output.do` | validation | 8 | Graph/co-occurrence output structure |
| `validation_codescan_describe.do` | validation | 62 | `codescan_describe` oracles |
| `validation_codescan_describe_adversarial.do` | validation | 93 | `codescan_describe` adversarial oracles |
| `validation_codescan_crosscheck.do` | validation | 92 | `codescan` vs hand-computed `regexm()`/manual collapse |
| `validation_countrows.do` | validation | 23 | `countrows` oracles |
| `_codescan_qa_common.do` | scaffold | — | Sandboxed-install bootstrap |
| `run_all.do` | runner | — | Curated lane runner |
| `tools/check_codescan_artifacts.py` | tool | — | Package-local `.xlsx`/`.dta` artifact checker |

There is no true cross-validation suite: `codescan` has no external R/Python
reference implementation, so all numeric checks are validation against
hand-computable oracles.

## Coverage map

`qa contract codescan` reports full coverage of the public surface:

| Command | Options | Returns | Status |
|---------|--------:|--------:|--------|
| `codescan` | 38/38 | 13/13 | covered |
| `codescan_describe` | 4/4 | 6/6 | covered |

Headline coverage by area: option-by-option (`test_codescan.do`,
`validation_codescan.do`), counting modes (`*countrows*`), date windows
(`lookback`/`lookforward`/`refdate`), scoring & hierarchy (`validation_*`,
`test_codescan_regressions.do`), shipped codefiles
(`validation_builtin_codefiles.do`), I/O & export
(`validation_codescan_io.do`, `validation_codescan_output.do`), Mata fast
paths (`test_mata_opt.do`, `validation_mata.do`), and the release surface
(`test_release_integrity.do`).

## Lane membership

| Suite | quick | core | full |
|-------|:---:|:---:|:---:|
| `test_codescan` | ✓ | ✓ | ✓ |
| `test_countrows` | ✓ | ✓ | ✓ |
| `test_mata_opt` | ✓ | ✓ | ✓ |
| `test_codescan_regressions` | ✓ | ✓ | ✓ |
| `validation_codescan` | ✓ | ✓ | ✓ |
| `validation_countrows` | ✓ | ✓ | ✓ |
| `validation_codescan_known_answers` |  | ✓ | ✓ |
| `validation_mata` |  | ✓ | ✓ |
| `validation_builtin_codefiles` |  | ✓ | ✓ |
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
documentation examples, release metadata, and shipped-codefile known answers.
`run_all.do` restores `c(pwd)` to the QA directory after each suite so an
install-smoke test cannot poison downstream path derivation.
