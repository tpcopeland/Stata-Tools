# qba QA

The `qba` QA suite is flat and concern-oriented, with one curated lane runner and independently runnable suites at the `qa/` root.

## How to run

```bash
cd qba/qa
stata-mp -b do run_all.do             # full lane (default release gate)
stata-mp -b do run_all.do quick       # fast functional and contract lane
stata-mp -b do test_qba_v113.do       # one suite, standalone
```

The additional canonical lanes are `core` and `crossval`; gate on the final `RESULT:` line because `full` and `crossval` treat a dependency skip as a failure.

## Isolation

Run lanes from a scratch copy that preserves `scratch/{_data,tabtools,qba}` and remove copied `qa/*.log` and `qa/run_all_status.txt` before starting. `run_all.do` writes into the active `qa/` directory, so concurrent runs there can silently overwrite logs; the tell is `run_all.log` disagreeing with a suite's own log.

| Sibling | Required by | Behavior if absent |
|---|---|---|
| `_data` | Scratch-layout and documentation checks | Hard failure |
| `tabtools` | Install/documentation smoke paths | Hard failure |

## Conventions

- `test_*` files cover functional, regression, contract, release, and adversarial behavior; `validation_*` files use known-answer or invariant oracles; `crossval_*` files compare with independently implemented Python/R or published-code oracles.
- Every maintained suite should end with `RESULT: <name> tests=N pass=N fail=N [skip=N]` and exit nonzero on failure. The `full` and `crossval` lanes treat any skip as a failure.
- Suites sandbox `PLUS` and `PERSONAL` under `c(tmpdir)` via `_qba_qa_common.do`, install the package from `../`, and restore the caller's settings.
- Paths derive from `c(pwd)`; no suite depends on a machine-local repository path.
- Test data are generated at runtime from inline tables, Stata example data, or seeded draws; no generated dataset is a tracked oracle.
- Generated `.log`, `.smcl`, `.dta`, `.xlsx`, and graph files are disposable and gitignored; only package `demo/` assets may be tracked generated files.

## Dependencies

| Suite or lane | Needs | If missing |
|---|---|---|
| `crossval_python_qba.do` | Python 3 used by Stata | Hard failure |
| `crossval_external_qba.do` | `Rscript` and R package `episensr` | Suite reports skip; `full`/`crossval` fail |
| `crossval_episensr_dta.do` | `Rscript` and R packages `haven` and `episensr` | Hard failure |
| `crossval_fml_totalerror.do` | `Rscript` with base R | Hard failure |

A missing dependency is installed and the affected lane rerun; it is not replaced with an internal-sanity check.

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_qba.do` | Core behavior, options, error paths, returns, and state preservation across the public commands |
| `test_qba_errors.do` | Exact invalid-cell error code, legal inverse input, and caller-data preservation for `qba_misclass` |
| `test_qba_v110.do` | Regression locks for coefficient selection, model integration, saving, and graph behavior |
| `test_qba_v111.do` | Regression locks for HR/IRR, level defaults, and `cloglog` scale handling |
| `test_qba_v112.do` | Regression locks for missing inputs, save failures, model-scale rejection, option coverage, and release install behavior |
| `test_qba_v113.do` | Regression locks for estimator-scale handling, total-error validity masks, method labels, and second-edition citations |
| `test_qba_fml2023.do` | Method-alignment contracts from Fox, MacLehose, and Lash plus E-value scale conversions |
| `test_qba_contract_detect.do` | Consumption of active `tmle`/`ltmle` estimator contracts |
| `test_qba_docs.do` | Installed examples, documentation tokens, and the self-contained SMCL render oracle with positive control |
| `test_qba_documentation_examples.do` | Literal examples from every shipped qba help file, including Monte-Carlo and optional tmle workflows |
| `test_qba_plot_release_deep.do` | Installed surface, metadata/date agreement, package manifest, examples, and graph failure returns |
| `test_qba_qa_common_bootstrap.do` | QA root discovery and isolated install/restore behavior |
| `test_qba_qa_assert_helpers.do` | Numeric assertion helpers, including missing-value comparison |
| `test_qba_qa_text_assertions.do` | File-content assertion helpers and their failure cases |
| `test_qba_qa_manifest_sync.do` | Runner membership and shipped-file manifest completeness |
| `test_refactor_distribution_loader_install.do` | Distribution-helper resolution after install |
| `test_refactor_distribution_autoload.do` | Distribution-helper autoload without explicit `run` |
| `test_refactor_distribution_parser_contracts.do` | Distribution parser accept/reject contracts |
| `test_refactor_mc_return_contracts.do` | Probabilistic return surfaces across analysis commands |
| `test_refactor_mc_known_answer.do` | Constant-distribution Monte Carlo results against analytic answers |
| `test_refactor_rng_contracts.do` | Seed reproducibility and different-seed behavior |
| `test_refactor_saving_parser_adversarial.do` | `saving()` parsing with replacement and hostile filenames |
| `test_refactor_save_failure_contracts.do` | Analytical returns after a failed save |
| `test_refactor_saved_schema.do` | Saved Monte Carlo dataset schemas |
| `test_refactor_qba_plot_cell_contracts.do` | Plot cell-validator accept/reject contracts |
| `test_refactor_qba_plot_contracts.do` | Returned plot contracts for each plot type |
| `test_refactor_qba_plot_parser_adversarial.do` | Plot parsing under hostile input |
| `test_refactor_qba_plot_install_smoke.do` | Plot command and helper resolution after install |
| `test_refactor_qba_plot_sideeffects.do` | Plot data, graph, and setting preservation |
| `test_qba_adversarial_misclass.do` | Misclassification negative paths and helper failures |
| `test_qba_adversarial_misclass_deep.do` | Deeper parser, schema, and state-preservation attacks for misclassification |
| `test_qba_adversarial_selection_confound.do` | Selection and confounding negative paths plus real model families |
| `test_qba_adversarial_selection_deep.do` | Deeper selection parameter, save, and state attacks |
| `test_qba_adversarial_confound_deep.do` | Deeper coefficient eligibility, estimator-family, Monte Carlo, and state attacks |
| `test_qba_adversarial_multi_plot.do` | Multi-bias and plot negative paths |
| `test_qba_adversarial_multi_deep.do` | Deeper multi-bias option, ordering, and saved-schema attacks |

### Validation

| File | Covers |
|---|---|
| `validation_qba.do` | Broad analytical and distribution-helper known answers |
| `validation_qba_boundaries.do` | Boundary values and multi-bias invariants |
| `validation_qba_precision.do` | Exact-rational tiny and near-null OR/RR effects, corrected cells, scale invariance and 100 identical saved draws across four analytic routes |
| `validation_qba_known_misclass.do` | Hand-computed misclassification oracles |
| `validation_qba_known_selection.do` | Hand-computed selection-bias oracles |
| `validation_qba_known_confound.do` | Hand-computed confounding and `from_model` oracles |
| `validation_qba_known_multi.do` | Hand-computed multi-bias chain oracles |
| `validation_qba_known_plot.do` | Exact plot-grid and dispatcher oracles |

### Cross-validation

| File | Oracle |
|---|---|
| `crossval_python_qba.do` | Independent Python implementations of the main formulas |
| `crossval_external_qba.do` | R `episensr` worked examples |
| `crossval_episensr_dta.do` | Same-run double `.dta` parity with R `episensr::misclass()` for differential exposure misclassification |
| `crossval_fml_totalerror.do` | Published Fox/MacLehose/Lash R algorithms for systematic and total error |

### Support

| Path | Contents |
|---|---|
| `run_all.do` | Authoritative explicit lane membership and aggregate result contract |
| `_qba_qa_common.do` | Root discovery, isolated installation, cleanup, metadata parsing, and assertions |
| `tools/oracle_external_qba.R` | Independent `episensr` oracle driver |
| `tools/oracle_fml_totalerror.R` | Published-code oracle transcribed to base R without package code reuse |

The precision targets are recorded in `tools/qba_precision_oracles.json`, including exact-rational effects. The suite compares actual analytical returns and every saved draw; its domains are continuous cell counts and constant bias distributions.

## Coverage map

| Command | Functional | Validation | Cross-val | Also exercised in |
|---|---|---|---|---|
| `qba` | `test_qba` | `validation_qba_known_plot` | — | release and documentation suites |
| `qba_misclass` | core and adversarial suites | `validation_qba_known_misclass` | all cross-validation suites | method-alignment, release, and literal documentation suites |
| `qba_selection` | core and adversarial suites | `validation_qba_known_selection` | Python and `episensr` | release and literal documentation suites |
| `qba_confound` | core, contract, and adversarial suites | `validation_qba_known_confound` | Python and `episensr` | method-alignment and literal documentation suites |
| `qba_multi` | core and adversarial suites | `validation_qba_known_multi` | Python and `episensr` | method-alignment and literal documentation suites |
| `qba_plot` | core, refactor, release, and adversarial suites | `validation_qba_known_plot` | — | render and literal documentation suites |

## Lane membership

`quick` is contained in `core`, and `core` is contained in `full`; `full` is the default release gate. The explicit suite lists in `run_all.do` are authoritative.

| Lane | Suites |
|---|---|
| `quick` | Functional/regression, estimator-contract, QA-harness, and refactor-contract groups |
| `core` | `quick` plus validation, adversarial, documentation, and release groups |
| `crossval` | Independent Python/R and published-code oracle group; any skip fails the lane |
| `full` | `core` plus `crossval`; any skip fails the lane |

## Known gaps

- Representative real estimators are exercised for `from_model`, but the suite does not fit every recognized panel, mixed, count, and survival family on every Stata edition.

## Oracles

The external oracle scripts share neither qba runtime code nor nuisance-parameter helpers with the package. `oracle_fml_totalerror.R` follows the study authors' published summary-level algorithms, with the `dplyr` filter chain expressed in base R.

## Canonical fixture contract

archetypes: A6(qba_misclass qba_selection qba_confound qba_multi qba_plot) A7(qba_plot) A1(qba_confound)
fixture-exempt: qba (catalog dispatcher does not consume analytical data)

`validation_qba_fixture_contract.do` runs in core/full: 17 exact outcome-misclassification OR/RR, selection OR and confounding RR checks, with constant-parameter probabilistic paths and one-bias `qba_multi` paths. The canonical table is explicitly adapted to qba cell order E1Y1/E0Y1/E1Y0/E0Y0. Friendly and identity sensitivity/specificity boundary cases assert exact corrected cells/effects; constant draws assert 100 valid replicates and exact mean/interval targets. Exposure classification, ordered joint corrections and plotting have additional canonical suites; remaining hostile primitives/file paths remain owed, with current existing QA retained.

| `validation_qba_fixture_plots.do` | Actual native graph serset numeric series for outcome/selection/confounding sensitivity curves, canonical friendly and boundary cells, full caller fingerprints after observed native first-graph initialization | core/full |

| `test_qba_plot_fixture_state.do` | Fresh-session absent, opaque-present and empty graph global, success/tipping/early/late refusals with exact caller-state fingerprint; no native warming | core/full |

| `validation_qba_fixture_routes.do` | 34 exact exposure OR/RR, selection OR/RR, combined outcome-misclassification/selection/confounding in both correction orders, relative-effect endpoint and mean-response from_model checks, full caller fingerprints; documented seeded Monte Carlo allows RNG changes | core/full |
| `validation_qba_fixture_domains.do` | Actual sensitivity/prevalence endpoints, invalid and extended-missing inputs; independently forward-generated classification cells and exact retained graph series with full caller fingerprints. | core/full |
| `validation_qba_fixture_callers.do` | Eight exact scalar-cell curves with full caller fingerprints across arbitrary friendly/one-row/missing/label-gap/case/32-byte/signed-large-code/opaque-string caller datasets; these data serve a preservation role and are not analytical inputs | core/full |
| `validation_qba_fixture_ci_domain.do` | Thirteen actual CI-limit cases: independent numerical inversion of the primary sharp bounding equation, risk/protective/null limits, finite positive range and named missing/negative/no-evalue refusals; full caller fingerprints | core/full |
| `test_qba_plot_fixture_files.do` | Actual Unicode and quote-hostile SVG exports (A7.xlsx suffix adapted to supported.svg), exact retained curve and independently checked rendered spacing/ordinate ratios, extensionless existing-target602 and whole owned tree/caller preservation | core/full |

## Numerical precision suites

These suites compare actual returned, dataset, text or workbook values to independently derived numerical truth. Lane membership below follows the existing runner; full-lane results after these additions remain unverified.

| File | Scope | Cases | Lanes |
| --- | --- | --- | --- |
| `validation_qba_metamorphic.do` | Deterministic OR/RR and constant-draw relations, table-count scaling with correct SE changes; finite returned scalars. | 10 | core/full |
