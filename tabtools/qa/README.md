# tabtools QA

Flat, command-level QA layout (consolidated in v1.7.0 from 85 per-directory files). One complete `test_<command>.do` per public command, one `validation_<command>.do` where known-answer validation exists, and focused package-level suites for cross-command, adversarial, deep-audit, and release contracts.

## How to run

```bash
cd tabtools/qa
stata-mp -b do run_all.do            # full lane (default)
stata-mp -b do run_all.do quick      # test_*.do only, minus adversarial
stata-mp -b do run_all.do release    # full + benchmark
stata-mp -b do run_all.do benchmark  # benchmark only
```

Every file is independently runnable from `qa/`: `stata-mp -b do test_regtab.do`. Each file installs the package itself (`net install ... from(<pkg_dir>)`), so single-file runs touch your real PLUS; `run_all.do` instead sandboxes PLUS/PERSONAL in `c(tmpdir)` and restores them afterwards. The runner sets `processors 1`, uses per-process temporary paths, and emits its own `RESULT:` sentinel. The full and release lanes install `simsum`, `siman`, `sencode`, and `labelsof` into that disposable tree and fail if a required oracle is unavailable. `crossval_tabtools.do` runs the R companion fresh in a temporary directory and verifies all four regenerated fixtures before using them.

Two restart/fresh-session contracts normally launch child Stata processes: the disk-backed profile restart in `test_tabtools.do` and the 21 help recipes in `test_tabtools_tips.do`. When a run must keep exactly one Stata process alive at a time, execute `tools/run_profile_restart.py` and `tools/run_help_recipes.py` first; both drivers run their Stata jobs strictly serially. Pass their result-file paths to the parent lane through `TABTOOLS_QA_PROFILE_RESTART_RESULT` and `TABTOOLS_QA_TIPS_RECIPES_RESULT`. The tests read and validate those handoffs instead of starting child processes.

The runner directs generated QA outputs to a per-run temporary directory. To remove ignored debris left by independent file runs:

```bash
bash clean_artifacts.sh
```

Skip a file by listing it in `_skip.txt` (one `file.do | reason` per line). Any skip fails the `full` and `release` lanes; only `quick` treats the list as advisory.

## Lane membership

`run_all.do` uses explicit, reviewed file lists rather than glob discovery.

| Lane | Files |
|------|-------|
| `quick` | 27 explicitly listed `test_*.do` files (all except `test_package_adversarial.do`) |
| `full` | 28 tests + 11 validations + `crossval_tabtools.do` (40 files) |
| `release` | `full` plus `benchmark_tabtools_speed.do` (41 files) |
| `benchmark` | `benchmark_tabtools_speed.do` only |

## Conventions

- `test_*` — functional/regression tests. `validation_*` — known-answer and
  invariant checks (hand-computable oracles). `crossval_*` — comparison
  against external R/Python implementations. `benchmark_*` — speed guardrails
  (release lane only).
- Files count tests with `test_count`/`pass_count`/`fail_count` locals and end
  with a machine-parseable sentinel: `RESULT: <name> tests=N pass=N fail=N`.
  A failing file exits nonzero.
- `test_package_release.do` renders every shipped `.sthlp` through Stata's SMCL interpreter and includes a deliberately broken positive control, so a no-op render oracle cannot pass.
- Sections inside consolidated files are marked `**# Migrated: <origin>` and
  keep their original assertions; Stata bookmarks (`**#`) give code folding.
- Under `run_all.do`, generated artifacts go to a disposable directory under `c(tmpdir)`; independent file runs use gitignored `output/`. `data/` holds tracked crossval fixtures. `baseline/` holds tracked semantic summaries; the manifest distinguishes regenerated gates from stored-only historical references.
- Several tests load Stata example data via `webuse` (network access required). `test_package_integration.do` additionally requires the sibling `eplot` package at `../../eplot` and exits 601 without it. Excel-content assertions require the vendored `tools/check_xlsx.py` and `python3` with `openpyxl`; a missing checker is a failure even when a Stata-native diagnostic can still run. `crossval_tabtools.do` requires `Rscript` plus Python with `numpy` and `statsmodels`. A full/release lane has zero acceptable hidden oracle skips.

## File index

### Per-command tests

| File | Covers | Notes |
|------|--------|-------|
| `test_table1_tc.do` | table1_tc | Core + weighted stats, nopvalue, auto-detect types, SMD guards, aggregation fast-path contracts, semantic edge contracts (all-missing row, one observation/group, long labels), dots progress option, pdp()/highpdp() 1-10 bound (1.9.11), v1.0.13–v1.5 regressions |
| `test_smallcells.do` | table1_tc | Small-cell threshold parsing, primary/complementary/derived masking, continuous and missingness dependencies, weighted/frequency-weight semantics, percent/row-percent/total/clear compositions, caller-state stability, sink parity, failure atomicity, and raw-leak attacks |
| `test_desctab.do` | desctab | Collect-driven descriptive tables: compose(), per-stat formats, totals, nintegerfmt/nomissing options, returns (r(version) parsed live from the .ado header) |
| `test_crosstab.do` | crosstab | Association measures (OR/RR/RD/chi2/Fisher/trend), zebra, digits, boldp bounds, zero-denominator and auto-Fisher regressions |
| `test_corrtab.do` | corrtab | Pearson/Spearman, stars, shapes, pairwise-N p-value regression |
| `test_regtab.do` | regtab | Model families (OLS/logit/Cox/GEE/mixed/multilevel), stats() incl. AIC/BIC recompute and n_sub aliases, compact mode, keep/drop, refcat, frames, console display, nopvalue |
| `test_effecttab.do` | effecttab | margins/teffects collects, from() matrix path, IPTW PS-coefficient filtering, digits, frames, console-only returns, refcat() option (1.9.11) |
| `test_survtab.do` | survtab | KM estimates, medians, RMST (+difference, no-late-entry), events option, riskset, highlight bounds, ev abbreviation, user-variable collisions, pdp()/highpdp() 1-10 bound (1.9.11) |
| `test_stratetab.do` | stratetab | strate-file workflows, multi-outcome/exposure scaffolds, rateratio, console/frame modes without xlsx(), sheet validation, row-order regression, error handling, varabbrev restore |
| `test_diagtab.do` | diagtab | Se/Sp/PPV/NPV/AUC, cutoff sweeps, prevalence adjustment, degenerate 2x2 markers, single-cutoff zebra layout |
| `test_comptab.do` | comptab | Composite tables from regtab/effecttab frames, varabbrev restore on error |
| `test_ci_level_provenance.do` | regtab, effecttab, `_tabtools_collect_ci_level` | CI-level provenance: key present/absent/non-default, explicit `level()` fallback only when provenance is absent, refusal without either source, and conflict guard. Guards the Stata 19 `r(459)` breakage (`collect save` omits the undocumented `ci-level` key) |
| `test_hrcomptab.do` | hrcomptab | stratetab scaffold + regtab model frames, rownames() patterns, reflabel() override + r(rateframe), xlsx success message |
| `test_puttab.do` | puttab | Dataset/frame/matrix sources, styling options, markdown-only mode |
| `test_stacktab.do` | stacktab | Workbook block assembly (vstack/hstack, columnmerge), frame replacement guard |
| `test_simtab.do` | simtab | Compute mode (bias/empse/coverage + MC SEs), numeric/string cell identities and empty-string exclusion, nosign/sedigits options + r(n_reps_min/max), ingest mode (simsum/siman/summary) incl. byvar/estimandvar overrides, styling (uses `tools/check_xlsx.py`) |
| `test_tabtools.do` | tabtools (controller) | Command listing/categories, set/get/clear round-trips, detail re-load, disk-backed profiles (sandboxes PERSONAL and supports a serial external restart-result handoff), r(version) vs header |
| `test_tabtools_tips.do` | tabtools_tips | Index display, README Quick Start execution, numerical incidence-rate contract, and all 21 help recipes in separate fresh Stata processes (strictly serial external handoff supported) |

### Package-level tests (genuinely multi-command)

| File | Purpose |
|------|---------|
| `test_package_helpers.do` | Shared infrastructure contracts: `_tabtools_common` utilities (col letters, path/sheet/color validators including Excel boundary-apostrophe/reserved-name rules, detect_vartype + RNG preservation), Mata xlsx write/read backends, style-engine build/apply (with in-test legacy reference via `tools/style_engine_compare.py`), markdown writer, collect-JSON render, console display, column widths, Excel engine validation sweep |
| `test_package_integration.do` | Cross-command behavior: theme/defaults propagation (`tabtools set` → consumers), persistent digits/boldp, frame(name, replace) for all frame-capable commands, frame() pre-existing rejection, addrow()/pdp() across commands, CSV/markdown export parity, post-estimation e() preservation, eplot bridge + section folding (**requires sibling eplot**) |
| `test_package_adversarial.do` | Adversarial breakage sweep, 3-perspective stress suite, and export-failure r() survival contracts, including `puttab` dimensions and `simtab` analytical metadata |
| `test_package_hardening.do` | Hostile edge-case sweep across the shared export surface: extreme table shapes (single column/row, no title, title wider than table, sheet-reshape stale-cell clearing → B2 geometry), pathological cell content round-trip (pipes/commas/quotes/leading-`=`/negatives through md/csv/xlsx), locale (`set dp comma` must not corrupt numeric export), and re-run / session-state safety (varabbrev + data + frame restoration) |
| `test_deep_audit_core.do` | Critical destructive/silent-corruption regressions plus Table 1 and simtab sample/cell identity contracts: Excel used ranges, frame alias/current-source transactions, semantic metadata, GLM scales, fweight/sample handling, and adversarial failures |
| `test_deep_audit_output.do` | Output/provenance regressions: CI levels, near-one p-values, zero effects, reserved labels, maximum precision, atomic sinks, trend errors, Markdown, medians, empty templates, and quotation preservation |
| `test_package_release.do` | Release gates: required artifacts, canonical metadata, manifest/install contracts, help versions, rendered-SMCL checks with a positive control, staged demo regeneration compared semantically with all 15 tracked workbooks, the required eplot integration demo (runs `demo_tabtools_eplot.do` and regenerates both forest PNGs), and regenerated golden-output digests vs `baseline/summaries/`; tracked demo assets are never rewritten by ordinary QA |
| `test_option_coverage.do` | Drives per-command OPTION coverage to 100% of the testable surface: every public option of every command is passed in a real invocation and accepted (see [Option coverage](#option-coverage)). Excludes `open` (GUI launch). |
| `test_synthesis_review.do` | Regression pins for the 1.12.0 synthesized four-reviewer audit: the caller-visible return code of `table1_tc` and `desctab` on a **bare** call (a `capture` prefix resets `_rc` to the program's own exit code, so no wrapped test can see this class); the CSV shape contract for every table-writing command — `title()` in the first field of row 1, `footnote()` in the first field of the last row, a row label in the last data row, and no reserved all-empty first row — plus the `corrtab` star legend reaching the CSV and a compound-quoted title round-tripping; Markdown emphasis escaping so a star legend survives export; `puttab` varlist order; the `regtab` stacked-rule and vertical-alignment rules and the single-cutoff `diagtab` rules (via `tools/check_synthesis_style.py`); the `table1_tc` missingsummary indent and percent format; leading-space-free p-values; and the `stacktab` console preview and CSV. Also pins the 1.12.1 rider: a raw `puttab` export whose first observation is blank in every column must keep that row, because the reserved-title-row trim added in 1.12.0 dropped it and shipped a CSV one row shorter than the workbook at `rc == 0`. 19 of its 28 assertions fail on the 1.11.0 tree and the 1.12.1 rider fails on the 1.12.0 tree; the other 8 are scope guards that hold both ways |
| `test_issue_review_1_11_0.do` | Regression pins for the 1.11.0 issue review: per-model factor-level rendering and Excel merging in `regtab`, fixed-point precision for large confidence limits, the single `table1_tc` header descriptor and sink parity with/without `xlsx()`, Markdown headings only from `title()`, flattened two-level Markdown headers that do not leak into `frame()`, p-value phrase grammar, generated star/legend parity, footnote punctuation joins, `diagtab` cutoff labels, negative-zero normalization, the `stratetab` CI separator, console chatter, and trailing whitespace in rendered cells |

### Validation (known answers, oracles, invariants)

| File | Covers |
|------|--------|
| `validation_table1_tc.do` | Mean/SD/median/percent/p-values vs `summarize`/`tabulate`, weighted expanded-data oracle, Yang–Dalton multinomial Mahalanobis SMD, coding invariance, two-level reduction, descriptive identities, and Excel cell accuracy |
| `validation_smallcells.do` | Independent exhaustive 2x2/2x3 reconstruction oracles, tight-bound false-green cases, hidden logical cells, truthful full-block fallback and threshold boundaries, engine input guards, and `.p`/`.s`/`.d` rendering |
| `validation_regtab.do` | Native-stats suite; coefficients/CIs/p-values vs `e()`, r(table) algebra, Excel accuracy, pdp formatting |
| `validation_effecttab.do` | ATE vs `e(b)`/`teffects`, SE/CI consistency, stored-results content |
| `validation_stratetab.do` | Structure/content of rate scaffolds, return values |
| `validation_survtab.do` | KM estimates vs `sts`, events/atrisk conservation, log-rank cross-checks, in-code RMST point/SE/CI bounds vs `stci, rmean` oracle, Excel survival probabilities, rendering checks (`tools/check_tabtools_render.py`) |
| `validation_crosstab.do` | Hand-computed 2x2 OR/RR/RD/chi2, counts vs `tabulate` |
| `validation_diagtab.do` | Algebraic identities (LR+/-, DOR, Youden, F1), full CI-bound surface for both wilson and exact (Se/Sp/PPV/NPV/accuracy/LR/DOR/AUC bounds vs `cii proportions` oracle, ordering + in-range), cutoff-table monotonicity, confusion matrix in Excel, and `level()` response for LR/DOR/prevalence-adjusted PPV/NPV bounds (VC13.8/13.9 — 90% vs 95% oracle, 1.9.11 regression) |
| `validation_corrtab.do` | Correlations vs `pwcorr`/`spearman`, symmetry, in-code Pearson p-values (r->t->p) vs `regress` slope-p oracle + closed form, Spearman p passthrough, Excel accuracy |
| `validation_simtab.do` | Exact known-answer + simsum oracle for performance measures |
| `validation_package.do` | Cross-command consistency (commands agree on shared statistics), universal sanity bounds, detect_vartype accuracy, set/get round-trip, comptab source-frame preservation, frame-Excel parity |

### Cross-validation and benchmarks

| File | Purpose |
|------|---------|
| `crossval_tabtools.do` | Runs `crossval_tabtools_companion.R` fresh, compares all four regenerated fixtures with tracked data, uses exact `qnorm(0.975)`/`invnormal(0.975)` interval quantiles, bridges CV1–17 to public command frames/returns, and includes command-backed CV18–20 (diagtab/crosstab/stratetab) plus **CV21–23** verifying `regtab` model-fit statistics against `estat ic`, `estat icc`, and an independent statsmodels fixed-scale GEE QICu oracle; CV19 filters nonpositive fweights before explicit expansion, and CV23 compares within-data model differences, checks the rendered label and AIC/QICu deduplication, and rejects estimated model-specific dispersion |
| `benchmark_tabtools_speed.do` | Speed guardrails (release/benchmark lanes only) |

### Support

| Path | Contents |
|------|----------|
| `tools/` | Excel/Markdown/render checkers, semantic demo-tree and crossval-fixture comparators, `run_profile_restart.py` (two-phase serial profile restart), `run_help_recipes.py` (21 fresh Stata processes, run serially), `style_engine_compare.py`, `check_synthesis_style.py` (negative and paired border/alignment assertions that `check_xlsx.py` does not offer: a rule that must be *absent*, and a label cell that must *agree* with its value cells), and `option_coverage.py` |
| `data/` | Tracked crossval fixture CSVs (R reference results) |
| `baseline/` | Tracked golden-output digest TSVs + `baseline_manifest.tsv` (consumed by `test_package_release.do`) |
| `CROSSVAL_MODULE_MAP.md` | Package-to-oracle mapping for CV1–CV23 |
| `TOLERANCE_FRAMEWORK.md` | Numerical and display-tolerance policy |
| `fixtures_manifest.md` | Fixture ownership, regeneration, and consumer map |
| `_visual_stress_gen.do` | Manual disposable workbook generator; not a release-lane test |
| `output/` | Generated artifacts (gitignored) |
| `clean_artifacts.sh` | Deletes only ignored runtime artifacts from the package/QA roots and disposable `output/` contents |

## Coverage map

| Command | Functional | Validation | Also exercised in |
|---------|-----------|------------|-------------------|
| table1_tc | test_table1_tc, test_smallcells | validation_table1_tc, validation_smallcells | helpers (fast-collect), integration, adversarial, deep core/output, release, crossval |
| desctab | test_desctab | — | helpers (collect-JSON render), integration |
| crosstab | test_crosstab | validation_crosstab | integration, adversarial, deep output, crossval |
| corrtab | test_corrtab | validation_corrtab | integration, adversarial |
| regtab | test_regtab | validation_regtab | helpers, integration, adversarial, deep core/output, release, crossval |
| effecttab | test_effecttab | validation_effecttab | integration, adversarial |
| survtab | test_survtab | validation_survtab | integration, adversarial, deep output |
| stratetab | test_stratetab | validation_stratetab | integration, adversarial, deep output, crossval |
| hrcomptab | test_hrcomptab | — | integration (eplot bridge), adversarial |
| comptab | test_comptab | validation_package (KE9) | integration (eplot bridge), adversarial |
| diagtab | test_diagtab | validation_diagtab | integration, crossval |
| puttab | test_puttab | — | helpers (markdown), release |
| stacktab | test_stacktab | — | release |
| simtab | test_simtab | validation_simtab | deep core, release |
| tabtools (controller) | test_tabtools | validation_package (V10) | integration (set propagation), release |
| tabtools_tips | test_tabtools_tips | — | release |

## Option coverage

Coverage here means **per-command option exercise**: an option counts only when
it is passed in a *real invocation of its own command* somewhere in the suite —
a bare token appearing in another command's test does not count. This is
stricter than a package-wide name scan (which trivially reports 100%).

- **Command coverage:** 16/16 (100%) — every public command has a test file.
- **Testable option coverage: 435/435 (100%)** — every testable public option of every
  command is passed in a real invocation and accepted.

`test_option_coverage.do` is the dedicated driver; `tools/option_coverage.py`
measures and verifies it (parses each `.ado` syntax block for the option
surface, scans `test_*.do`/`validation_*.do` for invocations, reports gaps).

| Command | Options | Testable | Exercised | Coverage |
|---------|--------:|---------:|----------:|---------:|
| `table1_tc` | 53 | 52 | 52 | 100.0% |
| `desctab` | 33 | 32 | 32 | 100.0% |
| `crosstab` | 31 | 30 | 30 | 100.0% |
| `corrtab` | 23 | 22 | 22 | 100.0% |
| `regtab` | 44 | 43 | 43 | 100.0% |
| `effecttab` | 34 | 33 | 33 | 100.0% |
| `survtab` | 32 | 31 | 31 | 100.0% |
| `stratetab` | 30 | 29 | 29 | 100.0% |
| `hrcomptab` | 25 | 24 | 24 | 100.0% |
| `comptab` | 28 | 27 | 27 | 100.0% |
| `diagtab` | 25 | 24 | 24 | 100.0% |
| `puttab` | 18 | 17 | 17 | 100.0% |
| `stacktab` | 17 | 17 | 17 | 100.0% |
| `simtab` | 45 | 44 | 44 | 100.0% |
| `tabtools` | 10 | 10 | 10 | 100.0% |
| `tabtools_tips` | 1 | 0 | 0 | 100.0% |
| **Total** | **449** | **435** | **435** | **100%** |

**Excluded by design — `open` (14 commands).** It opens the workbook in the OS default application (`shell xdg-open`/`open`/`start`) and cannot be driven deterministically in batch, so it is not a testable coverage target. `tabtools_tips` exposes only `open`, so it has no testable surface.

Regenerate / verify:

```
python3 qa/tools/option_coverage.py          # table; exit status 1 on any gap
python3 qa/tools/option_coverage.py --json    # machine-readable
```
