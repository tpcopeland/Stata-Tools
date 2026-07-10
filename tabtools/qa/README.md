# tabtools QA suite

Flat, command-level QA layout (consolidated in v1.7.0 from 85 per-directory
files). One complete `test_<command>.do` per public command, one
`validation_<command>.do` where known-answer validation exists, and a small
set of `test_package_*.do` files for QA that genuinely spans commands.

## How to run

```bash
cd tabtools/qa
stata-mp -b do run_all.do            # full lane (default)
stata-mp -b do run_all.do quick      # test_*.do only, minus adversarial
stata-mp -b do run_all.do release    # full + benchmark
stata-mp -b do run_all.do benchmark  # benchmark only
```

Every file is independently runnable from `qa/`:
`stata-mp -b do test_regtab.do`. Each file installs the package itself
(`net install ... from(<pkg_dir>)`), so single-file runs touch your real
PLUS; `run_all.do` instead sandboxes PLUS/PERSONAL in `c(tmpdir)` and
restores them afterwards.

Skip a file by listing it in `_skip.txt` (one `file.do | reason` per line).

## Lane membership

`run_all.do` uses explicit, reviewed file lists rather than glob discovery.

| Lane | Files |
|------|-------|
| `quick` | All `test_*.do` files except `test_package_adversarial.do` |
| `full` | All `test_*.do` files, all `validation_*.do` files, plus `crossval_tabtools.do` |
| `release` | `full` plus `benchmark_tabtools_speed.do` |
| `benchmark` | `benchmark_tabtools_speed.do` only |

## Conventions

- `test_*` — functional/regression tests. `validation_*` — known-answer and
  invariant checks (hand-computable oracles). `crossval_*` — comparison
  against R. `benchmark_*` — speed guardrails (release lane only).
- Files count tests with `test_count`/`pass_count`/`fail_count` locals and end
  with a machine-parseable sentinel: `RESULT: <name> tests=N pass=N fail=N`.
  A failing file exits nonzero.
- Sections inside consolidated files are marked `**# Migrated: <origin>` and
  keep their original assertions; Stata bookmarks (`**#`) give code folding.
- Generated artifacts (xlsx/csv/md/log) go to `output/` (gitignored).
  `data/` holds tracked crossval fixtures. `baseline/` holds tracked
  golden-output digests (TSV) used by `test_package_release.do`.
- Several tests load Stata example data via `webuse` (network access
  required). `test_package_integration.do` additionally requires the sibling
  `eplot` package at `../../eplot` and exits 601 without it.
  Excel-content assertions need `python3` with `openpyxl`
  (`tools/check_xlsx.py`); R is needed only for `crossval_tabtools.do`.

## File index

### Per-command tests

| File | Covers | Notes |
|------|--------|-------|
| `test_table1_tc.do` | table1_tc | Core + weighted stats, nopvalue, auto-detect types, SMD guards, aggregation fast-path contracts, edge cases (all-missing, single obs/group, long labels), dots progress option, v1.0.13–v1.5 regressions |
| `test_desctab.do` | desctab | Collect-driven descriptive tables: compose(), per-stat formats, totals, nintegerfmt/nomissing/valuelabels options, returns (r(version) parsed live from the .ado header) |
| `test_crosstab.do` | crosstab | Association measures (OR/RR/RD/chi2/Fisher/trend), zebra, digits, boldp bounds, zero-denominator and auto-Fisher regressions |
| `test_corrtab.do` | corrtab | Pearson/Spearman, stars, shapes, pairwise-N p-value regression |
| `test_regtab.do` | regtab | Model families (OLS/logit/Cox/GEE/mixed/multilevel), stats() incl. AIC/BIC recompute and n_sub aliases, compact mode, keep/drop, refcat, frames, console display, nopvalue |
| `test_effecttab.do` | effecttab | margins/teffects collects, from() matrix path, IPTW PS-coefficient filtering, digits, frames, console-only returns |
| `test_survtab.do` | survtab | KM estimates, medians, RMST (+difference, no-late-entry), events option, riskset, highlight bounds, ev abbreviation, user-variable collisions |
| `test_stratetab.do` | stratetab | strate-file workflows, multi-outcome/exposure scaffolds, rateratio, console/frame modes without xlsx(), sheet validation, row-order regression, error handling, varabbrev restore |
| `test_diagtab.do` | diagtab | Se/Sp/PPV/NPV/AUC, cutoff sweeps, prevalence adjustment, degenerate 2x2 markers, single-cutoff zebra layout |
| `test_comptab.do` | comptab | Composite tables from regtab/effecttab frames, varabbrev restore on error |
| `test_hrcomptab.do` | hrcomptab | stratetab scaffold + regtab model frames, rownames() patterns, reflabel() override + r(rateframe), xlsx success message |
| `test_puttab.do` | puttab | Dataset/frame/matrix sources, styling options, markdown-only mode |
| `test_stacktab.do` | stacktab | Workbook block assembly (vstack/hstack, columnmerge), frame replacement guard |
| `test_simtab.do` | simtab | Compute mode (bias/empse/coverage + MC SEs), nosign/sedigits options + r(n_reps_min/max), ingest mode (simsum/siman/summary) incl. byvar/estimandvar overrides, styling (uses `tools/check_xlsx.py`) |
| `test_tabtools.do` | tabtools (controller) | Command listing/categories, set/get/clear round-trips, detail re-load, disk-backed profiles (sandboxes PERSONAL for the profile section), r(version) vs header |
| `test_tabtools_tips.do` | tabtools_tips | Index display, retired cheatsheet/cookbook aliases stay absent |

### Package-level tests (genuinely multi-command)

| File | Purpose |
|------|---------|
| `test_package_helpers.do` | Shared infrastructure contracts: `_tabtools_common` utilities (col letters, path/sheet/color validators including Excel boundary-apostrophe/reserved-name rules, detect_vartype + RNG preservation), Mata xlsx write/read backends, style-engine build/apply (with in-test legacy reference via `tools/style_engine_compare.py`), markdown writer, collect-JSON render, console display, column widths, Excel engine validation sweep |
| `test_package_integration.do` | Cross-command behavior: theme/defaults propagation (`tabtools set` → consumers), persistent digits/boldp, frame(name, replace) for all frame-capable commands, frame() pre-existing rejection, addrow()/pdp() across commands, CSV/markdown export parity, post-estimation e() preservation, eplot bridge + section folding (**requires sibling eplot**) |
| `test_package_adversarial.do` | Adversarial breakage sweep, 3-perspective stress suite, and export-failure r() survival contracts, including `puttab` dimensions and `simtab` analytical metadata |
| `test_package_hardening.do` | Hostile edge-case sweep across the shared export surface: extreme table shapes (single column/row, no title, title wider than table, sheet-reshape stale-cell clearing → B2 geometry), pathological cell content round-trip (pipes/commas/quotes/leading-`=`/negatives through md/csv/xlsx), locale (`set dp comma` must not corrupt numeric export), and re-run / session-state safety (varabbrev + data + frame restoration) |
| `test_package_release.do` | Release gates: required artifacts, canonical stata.toc/.pkg author lines, .pkg ships every file, installed-user contracts, sthlp version consistency, demo artifacts regenerate (rewrites `demo/` in place — by design), golden-output digests vs `baseline/summaries/` |
| `test_option_coverage.do` | Drives per-command OPTION coverage to 100% of the testable surface: every public option of every command is passed in a real invocation and accepted (see [Option coverage](#option-coverage)). Excludes `open` (GUI launch). |

### Validation (known answers, oracles, invariants)

| File | Covers |
|------|--------|
| `validation_table1_tc.do` | Mean/SD/median/percent/p-values vs `summarize`/`tabulate`, fweight SMD oracle, descriptive identities, Excel cell accuracy |
| `validation_regtab.do` | Native-stats suite; coefficients/CIs/p-values vs `e()`, r(table) algebra, Excel accuracy, pdp formatting |
| `validation_effecttab.do` | ATE vs `e(b)`/`teffects`, SE/CI consistency, stored-results content |
| `validation_stratetab.do` | Structure/content of rate scaffolds, return values |
| `validation_survtab.do` | KM estimates vs `sts`, events/atrisk conservation, log-rank cross-checks, in-code RMST point/SE/CI bounds vs `stci, rmean` oracle, Excel survival probabilities, rendering checks (`tools/check_tabtools_render.py`) |
| `validation_crosstab.do` | Hand-computed 2x2 OR/RR/RD/chi2, counts vs `tabulate` |
| `validation_diagtab.do` | Algebraic identities (LR+/-, DOR, Youden, F1), full CI-bound surface for both wilson and exact (Se/Sp/PPV/NPV/accuracy/LR/DOR/AUC bounds vs `cii proportions` oracle, ordering + in-range), cutoff-table monotonicity, confusion matrix in Excel |
| `validation_corrtab.do` | Correlations vs `pwcorr`/`spearman`, symmetry, in-code Pearson p-values (r->t->p) vs `regress` slope-p oracle + closed form, Spearman p passthrough, Excel accuracy |
| `validation_simtab.do` | Exact known-answer + simsum oracle for performance measures |
| `validation_package.do` | Cross-command consistency (commands agree on shared statistics), universal sanity bounds, detect_vartype accuracy, set/get round-trip, comptab source-frame preservation, frame-Excel parity |

### Cross-validation and benchmarks

| File | Purpose |
|------|---------|
| `crossval_tabtools.do` | Compares SMD/ESS/categorical-SMD and association statistics against R results (`data/crossval_*.csv`, companion `crossval_tabtools_companion.R`); also includes command-backed oracles (no R needed) — CV18–20 (diagtab/crosstab/stratetab) and **CV21–23** verifying `regtab`'s recomputed model-fit statistics end-to-end: `r(aic_#)`/`r(bic_#)` vs `estat ic` (regress/logit/poisson/mixed), `r(icc_#)` vs `estat icc` (mixed/melogit), and `r(qic_#)` vs `deviance+2*rank` (xtgee, incl. AIC→QIC fallback) |
| `benchmark_tabtools_speed.do` | Speed guardrails (release/benchmark lanes only) |

### Support

| Path | Contents |
|------|----------|
| `tools/` | `check_xlsx.py` (cell/style assertions), `check_markdown.py`, `summarize_xlsx.py` (payload digests), `check_stacktab.py`, `check_tabtools_render.py`, `style_engine_compare.py`, `option_coverage.py` (per-command option-coverage diagnostic) |
| `data/` | Tracked crossval fixture CSVs (R reference results) |
| `baseline/` | Tracked golden-output digest TSVs + `baseline_manifest.tsv` (consumed by `test_package_release.do`) |
| `output/` | Generated artifacts (gitignored) |

## Coverage map

| Command | Functional | Validation | Also exercised in |
|---------|-----------|------------|-------------------|
| table1_tc | test_table1_tc | validation_table1_tc | helpers (fast-collect), integration, adversarial, release, crossval |
| desctab | test_desctab | — | helpers (collect-JSON render), integration |
| crosstab | test_crosstab | validation_crosstab | integration, adversarial, crossval |
| corrtab | test_corrtab | validation_corrtab | integration, adversarial |
| regtab | test_regtab | validation_regtab | helpers, integration, adversarial, release, crossval (CV8–10/15–17 formulas + CV21–23 estat ic/icc command oracles) |
| effecttab | test_effecttab | validation_effecttab | integration, adversarial |
| survtab | test_survtab | validation_survtab | integration, adversarial |
| stratetab | test_stratetab | validation_stratetab | integration, adversarial, crossval |
| hrcomptab | test_hrcomptab | — | integration (eplot bridge), adversarial |
| comptab | test_comptab | validation_package (KE9) | integration (eplot bridge), adversarial |
| diagtab | test_diagtab | validation_diagtab | integration, crossval |
| puttab | test_puttab | — | helpers (markdown), release |
| stacktab | test_stacktab | — | release |
| simtab | test_simtab | validation_simtab | release |
| tabtools (controller) | test_tabtools | validation_package (V10) | integration (set propagation), release |
| tabtools_tips | test_tabtools_tips | — | release |

## Option coverage

Coverage here means **per-command option exercise**: an option counts only when
it is passed in a *real invocation of its own command* somewhere in the suite —
a bare token appearing in another command's test does not count. This is
stricter than a package-wide name scan (which trivially reports 100%).

- **Command coverage:** 16/16 (100%) — every public command has a test file.
- **Testable option coverage: 425/425 (100%)** — every testable public option of every
  command is passed in a real invocation and accepted.

`test_option_coverage.do` is the dedicated driver; `tools/option_coverage.py`
measures and verifies it (parses each `.ado` syntax block for the option
surface, scans `test_*.do`/`validation_*.do` for invocations, reports gaps).

| Command | Options | Testable | Exercised | Coverage |
|---------|--------:|---------:|----------:|---------:|
| `table1_tc` | 53 | 52 | 52 | 100% |
| `desctab` | 37 | 36 | 36 | 100% |
| `crosstab` | 30 | 29 | 29 | 100% |
| `corrtab` | 24 | 23 | 23 | 100% |
| `regtab` | 44 | 43 | 43 | 100% |
| `effecttab` | 33 | 32 | 32 | 100% |
| `survtab` | 32 | 31 | 31 | 100% |
| `stratetab` | 29 | 28 | 28 | 100% |
| `hrcomptab` | 25 | 24 | 24 | 100% |
| `comptab` | 29 | 28 | 28 | 100% |
| `diagtab` | 25 | 24 | 24 | 100% |
| `puttab` | 18 | 17 | 17 | 100% |
| `stacktab` | 17 | 17 | 17 | 100% |
| `simtab` | 45 | 44 | 44 | 100% |
| `tabtools` | 10 | 10 | 10 | 100% |
| `tabtools_tips` | 1 | 0 | 0 | 100% |
| **Total** | **439** | **425** | **425** | **100%** |

**Excluded by design — `open` (14 commands).** It opens the workbook in the OS
default application (`shell xdg-open`/`open`/`start`) and cannot be driven
deterministically in batch, so it is not a coverage target. Raw coverage
*including* `open` is 425/439 = 96.8% — the only unexercised options are `open`
itself. `tabtools_tips` exposes only `open`, so it has no testable surface.

Regenerate / verify:

```
python3 qa/tools/option_coverage.py          # table; exit status 1 on any gap
python3 qa/tools/option_coverage.py --json    # machine-readable
```
