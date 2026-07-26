# qba QA

Run the whole lane from this directory:

```stata
cd qba/qa
do run_all.do
```

`run_all.do` isolates `PLUS`/`PERSONAL` into throwaway directories, `net install`s
the package from `../` before each suite, and reinstates the caller's `sysdir`
settings at the end. Every suite is also runnable on its own.

**Run the lane from a scratch copy of the repo layout** (`scratch/{_data,tabtools,qba}`),
not from the working tree: `run_all.do` writes `run_all.log` into this shared
directory, so two concurrent runs silently overwrite each other's results. The
tell is `run_all.log` disagreeing with a suite's own `.log`.

## Lanes

| Lane | Files | What it proves |
|------|-------|----------------|
| Functional | `test_qba.do`, `test_qba_v110.do`, `test_qba_v111.do`, `test_qba_v112.do` | Every command and option behaves as documented; regressions from earlier review rounds stay fixed |
| Method alignment | `test_qba_fml2023.do` | The 1.1.0 corrections against Fox/MacLehose/Lash 2023 and VanderWeele/Ding 2017 Table 2 |
| Contract | `test_qba_contract_detect.do`, `test_refactor_*.do` | Parser contracts, return contracts, saved-dataset schemas, helper autoload, RNG determinism, side-effect isolation |
| QA self-test | `test_qba_qa_common_bootstrap.do`, `test_qba_qa_assert_helpers.do`, `test_qba_qa_text_assertions.do`, `test_qba_qa_manifest_sync.do` | The shared harness and assertion helpers work, and no suite or shipped file is missing from its manifest |
| Known answer | `validation_qba.do`, `validation_qba_boundaries.do`, `validation_qba_known_*.do` | Hand-computed oracles for each estimator, its boundaries, and the plot grids |
| Cross-validation | `crossval_python_qba.do`, `crossval_external_qba.do`, `crossval_fml_totalerror.do` | Parity against independent implementations: a Python oracle, R `episensr`, and the study authors' own published R code |
| Documentation / release | `test_qba_docs.do`, `test_qba_plot_release_deep.do` | Documented examples run for an installed user; version and date metadata agree across every file that carries them |
| Adversarial | `test_qba_adversarial_*.do` | Negative paths, invalid parameter sets, degenerate tables, save failures, state and `varabbrev` restoration |

## External dependencies

| Suite | Needs |
|-------|-------|
| `crossval_python_qba.do` | Python 3 (the interpreter Stata's `python` uses) |
| `crossval_external_qba.do` | `Rscript` and the R package `episensr` |
| `crossval_fml_totalerror.do` | `Rscript` (base R only) |

A missing dependency is a gap to install, not a reason to weaken a suite.
`crossval_external_qba.do` exits 77 (skip) when `episensr` is absent; treat a
skip in the lane summary as an unrun check, not a pass.

## Coverage map

| Command | Functional | Known answer | Crossval | Adversarial |
|---------|-----------|--------------|----------|-------------|
| `qba_misclass` | `test_qba`, `test_qba_fml2023` | `validation_qba_known_misclass` | `crossval_python_qba`, `crossval_external_qba`, `crossval_fml_totalerror` | `test_qba_adversarial_misclass`, `test_qba_adversarial_misclass_deep` |
| `qba_selection` | `test_qba` | `validation_qba_known_selection` | `crossval_python_qba`, `crossval_external_qba` | `test_qba_adversarial_selection_confound`, `test_qba_adversarial_selection_deep` |
| `qba_confound` | `test_qba`, `test_qba_fml2023`, `test_qba_contract_detect` | `validation_qba_known_confound` | `crossval_python_qba`, `crossval_external_qba` | `test_qba_adversarial_selection_confound`, `test_qba_adversarial_confound_deep` |
| `qba_multi` | `test_qba`, `test_qba_fml2023` | `validation_qba_known_multi` | `crossval_python_qba`, `crossval_external_qba` | `test_qba_adversarial_multi_deep`, `test_qba_adversarial_multi_plot` |
| `qba_plot` | `test_qba`, `test_refactor_qba_plot_*` | `validation_qba_known_plot` | -- | `test_qba_adversarial_multi_plot`, `test_refactor_qba_plot_parser_adversarial` |
| `qba` (dispatcher) | `test_qba` | `validation_qba_known_plot` (K1) | -- | -- |

## File index

Every suite in this directory, in the order `run_all.do` executes it.

- `test_qba.do` -- Functional coverage of every command and its current option semantics
- `test_qba_v110.do` -- Regression lock for the v1.1.0 review round
- `test_qba_v111.do` -- Regression lock for the v1.1.1 review round
- `test_qba_v112.do` -- Regression lock for the v1.1.2 review round
- `test_qba_fml2023.do` -- The 1.1.0 corrections against Fox/MacLehose/Lash 2023 and VanderWeele/Ding Table 2: interval labelling, zero-cell screen, `totalerror`, `corr()`, `fcase()`/`fctrl()`, E-value conversions, `reps()` messaging, saved-dataset contract, version parsing
- `test_qba_contract_detect.do` -- `qba_confound` reading an active `tmle`/`ltmle` estimator contract
- `test_qba_qa_common_bootstrap.do` -- The shared harness: root detection and isolated bootstrap/restore
- `test_qba_qa_assert_helpers.do` -- The numeric assertion helpers, including missing-value comparison
- `test_qba_qa_text_assertions.do` -- The file-content assertion helpers and their failure cases
- `test_qba_qa_manifest_sync.do` -- Manifest completeness: helper suites in the runner, `qba.pkg` lists every shipped file, every suite is wired into `run_all.do`
- `test_refactor_distribution_loader_install.do` -- The distribution helper resolves for an installed user
- `test_refactor_distribution_autoload.do` -- The distribution helper autoloads without an explicit `run`
- `test_refactor_distribution_parser_contracts.do` -- `_qba_parse_dist` accept/reject contracts
- `test_refactor_mc_return_contracts.do` -- The Monte Carlo `r()` surface of each probabilistic arm
- `test_refactor_mc_known_answer.do` -- A constant-distribution Monte Carlo run reproduces the analytic answer
- `test_refactor_rng_contracts.do` -- `seed()` reproducibility and RNG-state isolation
- `test_refactor_saving_parser_adversarial.do` -- `saving()` parsing, including `replace` and hostile filenames
- `test_refactor_save_failure_contracts.do` -- A failed `saving()` still posts the analytical `r()` payload
- `test_refactor_saved_schema.do` -- The saved Monte Carlo dataset schema for each command
- `test_refactor_qba_plot_cell_contracts.do` -- `_qba_plot_validate_cells` accept/reject contracts
- `test_refactor_qba_plot_contracts.do` -- `qba_plot` returned contracts for each plot type
- `test_refactor_qba_plot_parser_adversarial.do` -- `qba_plot` option parsing under hostile input
- `test_refactor_qba_plot_install_smoke.do` -- `qba_plot` and its helpers resolve for an installed user
- `test_refactor_qba_plot_sideeffects.do` -- `qba_plot` leaves data, graphs, and settings untouched
- `validation_qba.do` -- Known-answer validation across the analytical commands and distribution helpers
- `validation_qba_boundaries.do` -- Boundary values and multi-bias invariants
- `validation_qba_known_misclass.do` -- Hand-computed misclassification oracles
- `validation_qba_known_selection.do` -- Hand-computed selection-bias oracles
- `validation_qba_known_confound.do` -- Hand-computed confounding and `from_model` oracles
- `validation_qba_known_multi.do` -- Hand-computed multi-bias chain oracles
- `validation_qba_known_plot.do` -- Exact known answers for the plot grids and the dispatcher contract
- `test_qba_docs.do` -- Documented examples run for an installed user; package surface is discoverable
- `test_qba_plot_release_deep.do` -- Release surface and version/date agreement across every file that carries them
- `crossval_python_qba.do` -- Python oracle parity for the formulas
- `crossval_external_qba.do` -- R `episensr` parity on its documented worked examples
- `crossval_fml_totalerror.do` -- Parity against the study authors' own published R code for the systematic-, total-, and random-error arms and the case-control sampling-fraction adjustment
- `test_qba_adversarial_misclass.do` -- `qba_misclass` negative paths and helper failure modes
- `test_qba_adversarial_misclass_deep.do` -- Deeper `qba_misclass` adversarial coverage: parser contracts, saved schema, state preservation
- `test_qba_adversarial_selection_confound.do` -- `qba_selection` and `qba_confound` adversarial coverage
- `test_qba_adversarial_selection_deep.do` -- Deeper `qba_selection` adversarial coverage
- `test_qba_adversarial_confound_deep.do` -- Deeper `qba_confound` adversarial coverage, including `from_model` families
- `test_qba_adversarial_multi_plot.do` -- `qba_multi` and `qba_plot` adversarial coverage
- `test_qba_adversarial_multi_deep.do` -- Deeper `qba_multi` adversarial coverage

## Oracles

`tools/` holds the external oracle scripts. Each is an independent
implementation, not a wrapper around `qba`:

- `oracle_external_qba.R` -- R `episensr` worked examples.
- `oracle_fml_totalerror.R` -- the study authors' own published summary-level
  algorithms for exposure misclassification and for case-control outcome
  misclassification, transcribed from their "Short code" page with the `dplyr`
  filter chain rewritten in base R. It shares no code and no nuisance parameter
  with the package, so agreement is parity rather than a mirror.

## Known blind spots

- The `.sthlp` render axis is checked by `python3 -m _devkit.stata_dev_cli
  validate package qba --repo tools`, not by this lane. A help file can pass
  every suite here and still cascade-corrupt in the GUI Viewer.
- No suite exercises `qba_confound, from_model` against every supported
  estimator family; `test_qba_adversarial_confound_deep.do` covers a subset.
- `r(level)` handling is asserted only indirectly, through interval widths.
