# tabtools QA

The `tabtools` QA suite is flat and concern-oriented, with one curated lane runner and independently runnable suites at the `qa/` root. It covers command behavior, known answers, external parity, disclosure control, exported artifacts, documentation, and release contracts.

## How to run

```bash
cd tabtools/qa
stata-mp -b do run_all.do            # full lane (default correctness gate)
stata-mp -b do run_all.do quick      # fast functional lane
stata-mp -b do test_desctab.do       # one suite standalone
```

`release` adds the benchmark to `full`; `benchmark` runs only the timing guardrail. Direct `run_all.do` users should gate on its terminal `RESULT:` line, because Stata batch shell status is not the suite verdict.

## Isolation

`run_all.do` sandboxes PLUS/PERSONAL and generated output under `c(tmpdir)`, installs the package from `../`, and restores the caller’s ado paths. Standalone suites install from `../` into the active PLUS, so use the runner when the real ado tree must remain untouched.

Concurrent runs of the same lane can collide through shared logs. Use a scratch copy preserving the sibling layout and remove copied `qa/*.log` plus `qa/run_all_status.txt`; a disagreement between `run_all.log` and a suite’s own log is the collision tell.

| Sibling | Required by | Behavior if absent |
|---|---|---|
| `_data/` | release demo regeneration | hard failure |
| `eplot/` | integration and release forest demos | hard failure |

## Conventions

- `test_*` files cover functional and regression behavior; `validation_*` files use known-answer or invariant oracles; `crossval_*` files compare against an independent implementation; `benchmark_*` files are timing guardrails, not correctness evidence.
- Every runnable suite ends with `RESULT: <name> tests=N pass=N fail=N [skip=N]` and exits nonzero on failure. Any skip fails `full` and `release`; `quick` treats `_skip.txt` as advisory.
- The runner sandboxes package installation and restores PLUS/PERSONAL; standalone files install from the package root for independent execution.
- Paths derive from `c(pwd)`; no suite uses a machine-local repository path.
- Synthetic data are generated at runtime; tracked cross-validation inputs live in `data/`, and fixture ownership is recorded in `fixtures_manifest.md`.
- Generated logs, workbooks, datasets, images, and `output/` contents are gitignored; tracked `demo/` assets and declared QA fixtures are the only generated-file exceptions.
- Consolidated sections use `**# Migrated:` bookmarks so retained contracts remain traceable.

## Dependencies

| Suite or lane | Needs | If missing |
|---|---|---|
| Excel/artifact suites | Python 3, `openpyxl`, and Pillow | hard failure |
| `crossval_tabtools.do` | `Rscript`; Python with `numpy` and `statsmodels` | hard failure |
| full/release bootstrap | Stata packages `simsum`, `siman`, `sencode`, and `labelsof` | installed into the sandbox; installation failure is fatal |

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_ci_level_provenance.do` | Confidence-level provenance and explicit fallback contracts across model-table commands. |
| `test_comptab.do` | Vertical composition, source-frame handling, option guards, and error-state restoration. |
| `test_corrtab.do` | Pearson/Spearman output, stars, shapes, and pairwise-N p-values. |
| `test_crosstab.do` | Association measures, weights, small-cell disclosure control, returns, and sink parity. |
| `test_deep_audit_core.do` | Destructive and silent-corruption regressions in frames, metadata, scales, weights, and samples. |
| `test_deep_audit_output.do` | CI provenance, formatting boundaries, atomic exports, quotation, and output normalization. |
| `test_desctab.do` | Direct descriptive-engine behavior, option semantics, returns, styles, sinks, and cleanup. |
| `test_effecttab.do` | Supported result sources, matrix mode, frames, formatting, and console returns. |
| `test_hrcomptab.do` | Rate/model scaffold composition, frame/workbook parity, eplot output, and guards. |
| `test_issue_review_1_11_0.do` | Regression pins for factor rendering, merging, precision, labels, legends, and whitespace. |
| `test_option_coverage.do` | Real-invocation exercise of each public command’s option surface. |
| `test_package_adversarial.do` | Package-wide hostile inputs, state attacks, and export-failure return survival. |
| `test_package_hardening.do` | Extreme shapes, hostile cell content, locale behavior, and rerun safety. |
| `test_package_helpers.do` | Shared validators, renderers, Excel engines, styles, Markdown, and collection helpers. |
| `test_package_integration.do` | Persistent defaults, cross-command frames and exports, e() preservation, and eplot integration. |
| `test_package_release.do` | Metadata, manifest/install, help rendering and width, demos, and golden artifact digests. |
| `test_puttab.do` | Dataset/frame/matrix sources, styling, Markdown, and dimensions. |
| `test_regtab.do` | Model families, statistics, selection, display modes, frames, and p-value policies. |
| `test_review_2026_08_13.do` | Disclosure-reconstruction attacks and correlation-star regression contracts. |
| `test_smallcells.do` | Small-cell parsing, masking, irredundancy, compositions, sink parity, and leak attacks. |
| `test_stacktab.do` | Workbook block assembly, stacking, column merging, Markdown, and frame guards. |
| `test_stratetab.do` | Rate-file workflows, multi-outcome scaffolds, ordering, sheets, and cleanup. |
| `test_survtab.do` | Kaplan-Meier, medians, RMST, events, risks, formatting, and collisions. |
| `test_synthesis_review.do` | Caller-visible errors, sink shapes, escaping, formatting, and stack previews. |
| `test_table1_tc.do` | Front-end descriptive behavior, weights, formatting, SMDs, missingness, and historical regressions. |
| `test_tabtools.do` | Controller listing, persistent defaults, profiles, reloads, and error guards. |
| `test_tabtools_documentation_examples.do` | Executable help examples and documented workflow contracts. |
| `test_tabtools_errors.do` | Exact association-measure errors, legal inverse input, and data preservation. |
| `test_tabtools_oracle.do` | Seeded command-catalog and category return-surface oracle. |
| `test_tabtools_tips.do` | Quick-reference behavior, README Quick Start, and fresh-session recipes. |
| `test_tabtools_v1163.do` | Missing-summary row attachment and group-specific count regression. |
| `test_tabtools_v202.do` | Caller Mata namespace preservation, unconditional stored results, and atomic multi-sink composition. |
| `test_theme_removed.do` | Rejection of the removed `theme()` surface. |
| `test_xlsx_style_compaction.do` | Style-pool compaction, workbook equivalence, verification guards, and platform paths. |

### Validation

| File | Covers |
|---|---|
| `validation_corrtab.do` | Correlations, symmetry, and p-values against native and closed-form oracles. |
| `validation_crosstab.do` | Hand-computed odds/risk measures, chi-squared statistics, and counts. |
| `validation_effecttab.do` | Treatment-effect values, standard errors, intervals, and stored results. |
| `validation_package.do` | Cross-command identities, sanity bounds, type detection, settings, and frame preservation. |
| `validation_regtab.do` | Coefficients, intervals, p-values, fit statistics, Excel values, and display precision. |
| `validation_smallcells.do` | Bounded exhaustive safety and irredundancy oracles for disclosure control. |
| `validation_stratetab.do` | Rate scaffold structure, contents, and returns. |
| `validation_survtab.do` | Survival estimates, conservation, log-rank tests, RMST, Excel values, and rendering. |
| `validation_table1_tc.do` | Descriptive statistics, Yang–Dalton SMDs, coding invariance, identities, and Excel cells. |

### Cross-validation

| File | Oracle |
|---|---|
| `crossval_tabtools.do` + `crossval_tabtools_companion.R` | Fresh R formulas and Python statsmodels parity for statistical and model-fit contracts. |

### Support and benchmarks

| Path | Contents |
|---|---|
| `run_all.do` | Curated lane manifest, sandbox installer, skip policy, and terminal status writer. |
| `benchmark_tabtools_speed.do` | Timing guardrail included only in `release`/`benchmark`. |
| `_visual_stress_gen.do` | Manual disposable workbook generator; not a gate. |
| `tools/` | Package-local Excel, Markdown, SMCL-width, demo, style, crossval, and option-coverage validators. |
| `data/`, `baseline/`, root QA fixtures | Tracked oracle inputs and semantic artifact summaries governed by `fixtures_manifest.md`. |
| `CROSSVAL_MODULE_MAP.md`, `TOLERANCE_FRAMEWORK.md` | Oracle ownership and numerical tolerance policy. |
| `clean_artifacts.sh`, `.gitignore` | Recoverable artifact cleanup and generated-file policy. |

## Coverage map

| Command | Functional | Validation | Cross-val | Also exercised in |
|---|---|---|---|---|
| `table1_tc` | `test_table1_tc`, `test_smallcells`, `test_tabtools_v1163` | `validation_table1_tc`, `validation_smallcells` | `crossval_tabtools` | helpers, integration, adversarial, deep audit, release |
| `desctab` | `test_desctab` | `validation_table1_tc`, `validation_smallcells` | — | helpers, integration, option coverage |
| `crosstab` | `test_crosstab` | `validation_crosstab`, `validation_smallcells` | `crossval_tabtools` | integration, adversarial, deep audit |
| `corrtab` | `test_corrtab` | `validation_corrtab` | `crossval_tabtools` | integration, adversarial |
| `regtab` | `test_regtab` | `validation_regtab` | `crossval_tabtools` | helpers, integration, adversarial, deep audit, release |
| `effecttab` | `test_effecttab` | `validation_effecttab` | `crossval_tabtools` | integration, adversarial |
| `survtab` | `test_survtab` | `validation_survtab` | `crossval_tabtools` | integration, adversarial, deep audit |
| `stratetab` | `test_stratetab` | `validation_stratetab` | `crossval_tabtools` | integration, adversarial, deep audit |
| `hrcomptab` | `test_hrcomptab` | — | — | integration, adversarial |
| `comptab` | `test_comptab` | `validation_package` | — | integration, adversarial |
| `puttab` | `test_puttab` | — | — | helpers, release |
| `stacktab` | `test_stacktab` | — | — | release |
| `tabtools` | `test_tabtools`, `test_tabtools_oracle` | `validation_package` | — | integration, release |
| `tabtools_tips` | `test_tabtools_tips` | — | — | release |

## Lane membership

`quick` is contained in `full`, and `full` is contained in `release`; the explicit file list in `run_all.do` is authoritative.

| Lane | Suites |
|---|---|
| `quick` | Functional/regression suites except the adversarial sweep. |
| `full` | All functional/regression suites, validation suites, and external cross-validation; default correctness gate. |
| `release` | `full` plus the timing benchmark. |
| `benchmark` | Timing benchmark only; run on demand. |

## Coverage verification

`tools/option_coverage.py` parses each public syntax surface and requires a real same-command invocation; `test_package_release.do` independently gates help rendering and synopt widths with positive controls.

```bash
python3 tools/option_coverage.py
python3 tools/check_sthlp_width.py ..
```
