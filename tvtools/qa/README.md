# tvtools QA suite

Flat, concern-then-command `qa/` layout driven by one lane-based `run_all.do`.
tvtools builds time-varying datasets for survival analysis (commands `tvage`,
`tvband`, `tvdiagnose`, `tvevent`, `tvexpose`, `tvmerge`, `tvpanel`, `tvsplit`,
`tvweight`, and the `tvtools` dispatcher). This suite was consolidated from two
append-grown monoliths
(`test_tvtools.do`, 354 functional tests; `validation_tvtools.do`, 558
validation tests) into per-command and per-concern suites. Merged origins are
preserved verbatim under `**# ===== merged from … =====` banners. Large
append-grown regions that lived inside a single `capture noisily {}` scope and
intermixed commands could not be cut per command without changing their
semantics; those are kept intact in the cross-cutting concern suites
(`test_options`, `test_integration`, `test_edge_cases`, `test_regressions`,
`validation_boundary`, `validation_pipeline`, `validation_supplemental`).

## How to run

```bash
cd tvtools/qa
stata-mp -b do run_all.do            # full lane (default release gate)
stata-mp -b do run_all.do quick      # fast functional lane
stata-mp -b do run_all.do core       # quick + regressions + validation oracles
stata-mp -b do run_all.do python     # cross-validation parity only
```

`run_all.do` runs a curated per-lane suite list (not auto-discovery), sources
the shared `_tvtools_qa_common.do` scaffold, sandboxes PLUS/PERSONAL under
`c(tmpdir)` via `_tvtools_qa_bootstrap` (the real ado tree is never touched),
and exits nonzero if any suite fails. Every file is independently runnable from
`qa/` (e.g. `stata-mp -b do test_tvexpose.do`); each one re-sources the scaffold
and re-bootstraps after its own `clear all`.

## Conventions

- Prefixes: `test_*` (functional/regression), `validation_*` (hand-computable
  known-answer / invariant oracles), `crossval_*` (parity vs an external
  reference implementation).
- Every suite ends with the machine-parseable sentinel
  `RESULT: <name> tests=N pass=N fail=N` and `exit 1` on any failure.
- Consolidated suites preserve their origin bodies verbatim under
  `**# ===== merged from … =====` banners; section labels are comments, not
  decorative `display` lines.
- Shared assertion/verification helpers (`assert_exact`, `assert_approx`,
  `_validate_tvexpose_output`, `_verify_ptime_conserved`, `_verify_no_overlap`,
  `_check_log`) and the `run_test`/`test_pass`/`test_fail` harness live in
  `_tvtools_qa_common.do`.
- Tracked input fixtures live in `data/`; suites derive paths from `c(pwd)` and
  never hard-code absolute paths. Generated logs/datasets are gitignored.

## File index

### Command-level functional tests
| File | Command | Notes |
|------|---------|-------|
| `test_tvage.do` | tvage | Age-interval creation, grouping, expanded edge cases |
| `test_tvband.do` | tvband | Single-axis date-derived banding; exact boundaries, min/max, noisily |
| `test_tvsplit.do` | tvsplit | Multi-timescale Lexis splitting; tiling, returns, error paths, noisily |
| `test_tvevent.do` | tvevent | Event splitting and interval construction |
| `test_tvexpose.do` | tvexpose | Time-varying exposure creation |
| `test_tvmerge.do` | tvmerge | Multi-dataset interval merging |
| `test_tvpanel.do` | tvpanel | Fixed-width person-period panel construction, option/return coverage, label and temp-name regressions |
| `test_tvweight.do` | tvweight | IPTW weights + comprehensive option coverage |
| `test_tvdiagnose.do` | tvdiagnose | Coverage/gap/overlap diagnostics |
| `test_tvtools.do` | tvtools | Dispatcher command routing |
| `test_default_naming.do` | cross-command | Default generated-variable names across commands |
| `test_frames_input.do` | frames/options | Frame-backed inputs for tvevent/tvmerge/tvpanel and related return checks |

### Cross-cutting concern tests
| File | Covers | Notes |
|------|--------|-------|
| `test_options.do` | tvexpose/tvmerge/tvevent option groups | Revived from a previously-dead `test_pass` harness block (see Residual notes) |
| `test_integration.do` | cross-command pipelines + per-command gap coverage | Single `capture` scope; intermixes commands |
| `test_edge_cases.do` | edge cases + stress tests | Revived from previously non-gating local counters |
| `test_regressions.do` | gap coverage, deliberation/review fixes, Codex audit fixes, bug-fix regressions | Version- and review-specific regressions |
| `test_verbose.do` | verbose option across tvexpose/tvdiagnose/tvmerge | Log-content assertions via `_check_log` |

### Validation (hand-computable oracles)
| File | Covers |
|------|--------|
| `validation_tvage.do` | tvage age math + expanded validation |
| `validation_tvband.do` | tvband exact band boundaries (elapsed/calendar/age), return locals |
| `validation_tvsplit.do` | tvsplit Lexis tiling, single-band, maximality; axis return locals |
| `validation_tvevent.do` | tvevent splitting + person-time conservation |
| `validation_tvexpose.do` | tvexpose exposure tracking + person-time |
| `validation_tvmerge.do` | tvmerge correctness + person-time additivity |
| `validation_tvpanel.do` | tvpanel fixed-grid known answers: ceil period count, entry-anchored starts, last-interval clamp at exit, latest-start-wins active class, eclass secondary tie-break, multi-class cumulative accrual reshaped across classes (strict `estart<pstart` bound vs `estart<=pstart` active bound), and cumulative-unit scaling |
| `validation_tvweight.do` | tvweight IPTW weight-formula properties (1/PS, stabilized, HT, ESS, mlogit) |
| `validation_tvweight_balance.do` | tvweight covariate-balance / SMD computation; love-plot delegation to psdash (installed, multi-group, and not-installed paths) |
| `validation_tvweight_recovery.do` | **known-truth IPTW recovery**: confounded DGP, naive misses the marginal effect, IPTW recovers it (continuous additive, stabilized, binary risk difference); positivity counters match the reported propensity |
| `validation_tvweight_msm_recovery.do` | **known-truth MSM recovery**: K=3 panel with treatment-confounder feedback; cumulative (stabilized and unstabilized) IPTW recovers the marginal regime effect a confounded pooled regression misses. Two oracles: (A/B) the randomized-world working-model slope in the estimator's own parameterization, and (C/D) the canonical **regime contrast** `E[Y^(1,1,1)]-E[Y^(0,0,0)]` from a g-formula **forward-simulation** of the DGP under the static always/never regimes (model-free; matches the closed form and 3×the slope). (E) a **misspecified-MSM guard**: with treatment×covariate interaction in the outcome and nonlinear confounder feedback, `E[Y^ā]` is nonlinear in dose, so the linear MSM `3·_b[cumA]` misses while a saturated MSM `i.cumA` still recovers the contrast under valid IPTW — isolating the limitation as the MSM form, not the weighting. Avoids the longitudinal estimand-mismatch trap |
| `validation_tvdiagnose.do` | tvdiagnose deep validation |
| `validation_flow.do` | r(flow) CONSORT accounting across commands |
| `validation_boundary.do` | event/interval boundary correctness, tvexpose boundary |
| `validation_pipeline.do` | end-to-end pipeline + continuous/person-time conservation |
| `validation_supplemental.do` | cross-command math validation, return-value completeness, invariants |
| `validation_known_answers.do` | hand-computed tvexpose→tvmerge→tvage→tvevent workflows |
| `validation_dgp_known_answers.do` | **known-answer DGP battery** (20 scenarios, S1–S20): each builds data from a generating process whose exact output is derived analytically from the DGP — never the package. Deterministic transforms carry exact integer oracles (tvage continuous/grouped band counts, tvband elapsed/calendar bands, tvsplit Lexis invariants, tvpanel period count + exact-multiple exit-day coverage + cumulative accrual, tvexpose interval/exposed-PT, tvmerge intersection lattice, tvevent recurring split); tvweight uses saturated-model IPTW identities (mean unstabilized weight = 2, mean stabilized weight = 1, covariate balance) exact to machine precision. Person-time conservation and no-gap/overlap asserted throughout |
| `validation_dgp_known_answers2.do` | **known-answer DGP battery, part 2** (25 scenarios, S21–S45): reaches the option surfaces the first battery did not. tvexpose exposure-definition/data-handling (evertreated monotone, currentformer never/current/former PT, lag/washout window shifts, grace gap-bridge from both sides, dose accrual); tvmerge simultaneous-overlap lattice cell; tvevent event logic (single terminal censoring, earlier competing-date resolution, recurring PWP enum + gap-time clock, timegen elapsed, continuous() proportional split conservation); tvweight estimand identities (ATO/matching exact balance, matched pseudo-population size = 2200, saturated stabilized ESS, multinomial mean weight = #levels, truncate percentile-clamp identity + exact trim count); tvpanel active-class vector + per-class cumulative accrual; tvage minage/maxage clamp; tvsplit single- and three-axis invariants; tvdiagnose three-way overlap + exclusive large-gap threshold boundary. Each oracle confirmed against documented option semantics before pinning |

### Cross-validation
| File | Purpose |
|------|---------|
| `crossval_tvtools.do` | Parity against the external reference implementation |
| `crossval_tvmerge_mata.do` | Parity gate for the Mata interval engine vs an independent day-by-day expansion oracle (pure Stata, no external dep; runs in the `core` lane) |
| `crossval_tvexpose_expand.do` | Parity gate for the Mata expandunit() bin generator vs an independent formula oracle, all units (pure Stata, no external dep; runs in the `core` lane) |
| `crossval_tvsplit_lexis.do` | tvsplit Lexis splitting vs R `Epi`/from-scratch day-exact oracle (skip-safe; `core` lane) |
| `crossval_tvweight_ipcw.do` | IPCW known-truth recovery — single-period (PART A) and multi-period cumulative (PART C), both in-Stata — plus cumulative censoring-weight parity vs an R glm oracle (PART B, skip-safe; `core` lane) |
| `crossval_tvevent_recurring.do` | Recurrent-event enumeration / gap-time parity (`core` lane) |

### Support
| Path | Contents |
|------|----------|
| `_tvtools_qa_common.do` | Sandboxed install bootstrap, shared helpers, test globals |
| `run_all.do` | Curated lane runner (quick/core/python/full) |
| `data/` | Tracked input fixtures + `generate_test_data.do` |
| `.gitignore` | Ignore generated logs/datasets/artifacts |

## Coverage map

| Command | Functional | Validation | Cross-val | Also exercised in |
|---------|-----------|-----------|-----------|-------------------|
| tvage | `test_tvage` | `validation_tvage`, `validation_known_answers`, `validation_dgp_known_answers`, `validation_dgp_known_answers2` | `crossval_tvtools` | `test_options`, `test_regressions`, `validation_pipeline`, `validation_supplemental` |
| tvband | `test_tvband` | `validation_tvband`, `validation_dgp_known_answers` | `crossval_tvsplit_lexis` | `test_tvsplit`, `test_default_naming` |
| tvdiagnose | `test_tvdiagnose` | `validation_tvdiagnose`, `validation_dgp_known_answers`, `validation_dgp_known_answers2` | `crossval_tvtools` | `test_integration`, `test_verbose`, `test_regressions`, `validation_supplemental` |
| tvevent | `test_tvevent` | `validation_tvevent`, `validation_known_answers`, `validation_dgp_known_answers`, `validation_dgp_known_answers2`, `validation_boundary` | `crossval_tvevent_recurring` | `test_options`, `test_frames_input`, `test_regressions`, `validation_pipeline`, `validation_supplemental` |
| tvexpose | `test_tvexpose` | `validation_tvexpose`, `validation_dgp_known_answers`, `validation_dgp_known_answers2`, `validation_boundary` | `crossval_tvtools`, `crossval_tvexpose_expand` | `test_options`, `test_integration`, `test_verbose`, `test_regressions`, `validation_pipeline`, `validation_supplemental` |
| tvmerge | `test_tvmerge` | `validation_tvmerge`, `validation_dgp_known_answers`, `validation_dgp_known_answers2` | `crossval_tvtools`, `crossval_tvmerge_mata` | `test_options`, `test_integration`, `test_verbose`, `test_frames_input`, `test_regressions`, `validation_supplemental` |
| tvpanel | `test_tvpanel` | `validation_tvpanel`, `validation_dgp_known_answers`, `validation_dgp_known_answers2` | — | `test_frames_input`, `test_regressions` |
| tvsplit | `test_tvsplit` | `validation_tvsplit`, `validation_dgp_known_answers`, `validation_dgp_known_answers2` | `crossval_tvsplit_lexis` | `test_default_naming` |
| tvtools (dispatcher) | `test_tvtools` | — | — | — |
| tvweight | `test_tvweight` | `validation_tvweight`, `validation_tvweight_balance`, `validation_tvweight_recovery`, `validation_tvweight_msm_recovery`, `validation_dgp_known_answers`, `validation_dgp_known_answers2` | `crossval_tvtools`, `crossval_tvweight_ipcw` | `test_options`, `test_regressions`, `validation_flow`, `validation_supplemental` |

## Lane membership

| Lane | Suites |
|------|--------|
| `quick` | `test_tvage`, `test_tvband`, `test_tvsplit`, `test_tvevent`, `test_tvexpose`, `test_tvmerge`, `test_tvpanel`, `test_tvweight`, `test_tvdiagnose`, `test_tvtools`, `test_options`, `test_integration`, `test_edge_cases`, `test_verbose`, `test_frames_input`, `test_default_naming` |
| `core` | `quick` + `test_regressions`, `validation_known_answers`, `validation_dgp_known_answers`, `validation_dgp_known_answers2`, `validation_tvage`, `validation_tvband`, `validation_tvsplit`, `validation_tvevent`, `validation_tvexpose`, `validation_tvmerge`, `validation_tvpanel`, `validation_tvweight`, `validation_tvweight_balance`, `validation_tvweight_recovery`, `validation_tvweight_msm_recovery`, `validation_tvdiagnose`, `validation_flow`, `validation_boundary`, `validation_pipeline`, `validation_supplemental`, `crossval_tvmerge_mata`, `crossval_tvexpose_expand`, `crossval_tvsplit_lexis`, `crossval_tvweight_ipcw`, `crossval_tvevent_recurring` |
| `python` | `crossval_tvtools` |
| `full` *(default)* | `core` + `python` |
