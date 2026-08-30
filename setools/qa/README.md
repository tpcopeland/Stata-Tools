# setools QA

The `setools` QA suite is flat and concern-oriented: one functional, regression, validation, or cross-validation file per concern, driven by a curated lane runner. Every suite is independently runnable from this directory.

## How to run

```bash
cd setools/qa
stata-mp -b do run_all.do                 # full lane (default release gate)
stata-mp -b do run_all.do quick           # fast functional lane
stata-mp -b do test_setools_v154_regressions.do
stata-mp -b do benchmark_setools_performance.do 100000
```

The `python` alias runs the three external-oracle cross-validation suites, while `network` runs the optional pinned-source checksum smoke. Gate on the final `RESULT:` line or `run_all_status.txt`, not only the shell exit status.

## Isolation

`run_all.do` writes its batch log in the active `qa/` directory, so concurrent runs of the same lane can corrupt evidence; a disagreement between `run_all.log` and a suite sentinel is the tell. Run release evidence from a scratch copy that preserves the repository layout, remove copied `qa/*.log` and `qa/run_all_status.txt` first, and include the sibling `_data/` directory so the shipped-data documentation path is exercised rather than its embedded fallback.

## Conventions

- `test_*` files provide functional and regression coverage; `validation_*` files provide known-answer and invariant checks; `crossval_*` files compare with an independently implemented external oracle; `benchmark_*` files are timing guardrails and never correctness gates.
- Every suite ends with one `RESULT: <name> tests=N pass=N fail=N [skip=N]` sentinel and exits nonzero on failure. The `full` release lane accepts no skips.
- Suites sandbox `PLUS` and `PERSONAL` under `c(tmpdir)` through `_setools_qa_common.do`, install `setools` there, and restore the caller's settings afterward.
- Paths derive from `c(pwd)` or Stata tempfiles; no suite uses machine-local paths.
- Most data are generated from deterministic fixtures at runtime. Tracked fixtures live in `data/`, with provenance and refresh commands in `fixtures_manifest.md`.
- Generated logs, datasets, status files, and exports are disposable and gitignored; tracked generated documentation assets belong only under `demo/`.

## Dependencies

| Suite or lane | Needs | If missing |
|---|---|---|
| `full` / `python` | Python 3 standard library | Hard failure |
| `network` | Network access and `/usr/bin/sha256sum` | Hard failure in that optional lane |

Stata 16 or later is required throughout. No R package is used.

## File index

### Functional and regression tests

| File | Covers |
|---|---|
| `test_setools.do` | Public command discovery, overview output, and basic command behavior. |
| `test_setools_option_errors.do` | Numeric option boundaries, exact rollback, dispatcher invalid-option, and mutually-exclusive-option errors. |
| `test_setools_oracle.do` | Seeded repeated catalog oracle for exact category command lists and counts. |
| `test_release_integrity.do` | Relocatable package inventory, version, metadata, author, path, helper, and source contracts. |
| `test_documentation_examples.do` | Runnable README and help examples, including shipped-data CDP behavior. |
| `test_setools_sthlp_render.do` | Self-contained literal-SMCL and synopt-width gates with fault injection. |
| `test_audit_regressions.do` | Cross-command regressions found by prior adversarial audits. |
| `test_cci_engine_smoke.do` | Minimal installed CCI engine execution. |
| `test_cci_dates_parity.do` | Component-date and score parity across CCI paths. |
| `test_cci_se_adversarial.do` | CCI input validation, state preservation, and adversarial codes. |
| `test_cdp_adversarial.do` | CDP output, error, state, ordering, and option contracts. |
| `test_cdp_roving_determinism.do` | Deterministic roving-reference event selection. |
| `test_edss_fixture.do` | Tracked synthetic EDSS fixture integrity and execution. |
| `test_migrations_keepimmigrants.do` | `keepimmigrants` classifications and returned cohort behavior. |
| `test_migrations_malformed_rollback.do` | Malformed migration inputs and byte-preserving rollback. |
| `test_migrations_minresidence.do` | Minimum-residence exclusions and boundaries. |
| `test_migrations_perm_emig_bug.do` | Permanent-emigration censoring regression. |
| `test_setools_abbrev_and_namespace.do` | Documented abbreviations and the reserved migration namespace. |
| `test_setools_v130_features.do` | Three-tier, confirmation, event-indicator, and lookback regressions. |
| `test_setools_v140_features.do` | Exit censoring, migration flow, flag mode, and CCI diagnostics. |
| `test_setools_v154_regressions.do` | Person-level date consistency, helper isolation, and PIRA parser/namespace regressions. |
| `test_setools_v155_regressions.do` | Migration censoring-date loss and zero-row abort, wide/long agreement, and the `r(converged)` contract. |
| `test_network_smoke.do` | Optional download and checksum of the pinned upstream CCI source. |

### Validation

| File | Covers |
|---|---|
| `validation_cci_se_date_hierarchy.do` | CCI component precedence and earliest-date hierarchy. |
| `validation_cci_se_era_boundaries.do` | ICD-era transition boundaries. |
| `validation_cci_se_known_scores.do` | Hand-computable CCI component and total scores. |
| `validation_cci_se_v121.do` | Corrected Swedish CCI mapping vectors. |
| `validation_cdp_known_answers.do` | Fixed-reference CDP known answers. |
| `validation_cdp_roving_exit.do` | Roving event sequences with exit censoring. |
| `validation_cdp_threetier_confirmtype.do` | Threshold tiers and sustained-versus-visit confirmation. |
| `validation_known_answer_boundaries.do` | Cross-command endpoint and missing-value boundaries. |
| `validation_migrations_adversarial_boundaries.do` | Migration event-order and same-day boundaries. |
| `validation_migrations_longwide_equivalence.do` | Equivalent results from long and wide migration layouts. |
| `validation_migrations_type2_censoring.do` | Type-2 migration censoring known answers. |
| `validation_pira_known_answers.do` | PIRA/RAW classification known answers. |
| `validation_setools_performance_identity.do` | Exact legacy-versus-optimized PIRA rebaseline states and grouped-minimum equivalence. |
| `validation_setools.do` | Broad command-level invariants and stored-result contracts. |
| `validation_setools_crosschecks.do` | Manual formulas and internal consistency across CDP, sustained EDSS, CCI, and PIRA. |
| `validation_sustainedss_known_answers.do` | Sustained EDSS threshold and confirmation known answers. |

### Cross-validation

| File | Oracle |
|---|---|
| `crossval_cci_se_python.do` | Python comparison against pinned authoritative CCI vectors through `tools/compare_cci_fixture.py`. |
| `crossval_edss_python.do` | Randomized differential test of `cdp`, `sustainedss`, `pira`, and roving `allevents` against `tools/compare_edss.py`, an oracle transcribed from the help files. |
| `crossval_migrations_python.do` | Randomized differential test of `migrations` in both file formats against `tools/compare_migrations.py`, including wide/long equivalence. |

### Support

| Path | Contents |
|---|---|
| `run_all.do` | Authoritative lane membership and result aggregation. |
| `benchmark_setools_performance.do` | Seeded registry-scale timing for PIRA, CDP, and sustained EDSS; accepts the person count as its argument. |
| `_setools_qa_common.do` | Isolated installation and session-state teardown. |
| `_expected_warnings.txt` | Narrow declarations for warning messages deliberately provoked by negative-path suites. |
| `tools/build_edss_fixture.do` | Deterministic EDSS fixture generator, run by hand. |
| `tools/build_cci_authoritative_fixture.py` | Pinned-source CCI vector builder, run by hand. |
| `tools/compare_cci_fixture.py` | Independent Python CCI comparator used by cross-validation. |
| `tools/compare_edss.py` | Independent EDSS-progression oracle and comparator, written from `cdp.sthlp`, `sustainedss.sthlp`, and `pira.sthlp`. |
| `tools/compare_migrations.py` | Independent migration oracle and comparator, written from `migrations.sthlp`. |
| `data/cci_authoritative_prefixes.csv` | Pinned authoritative CCI cases and expected components. |
| `data/edss_long.dta` | Synthetic repeated-visit EDSS fixture. |
| `fixtures_manifest.md` | Fixture schema, provenance, hashes, and refresh commands. |

## Coverage map

| Command | Functional | Validation | Cross-val | Also exercised in |
|---|---|---|---|---|
| `setools` | `test_setools`, `test_setools_abbrev_and_namespace` | `validation_setools` | — | `test_release_integrity`, `test_setools_sthlp_render` |
| `cci_se` | CCI engine, date-parity, adversarial, and versioned suites | CCI era, score, date, mapping, boundary, and crosscheck validations | `crossval_cci_se_python` | Documentation, audit, and help-render suites |
| `migrations` | Migration regression, rollback, namespace, and versioned suites | Migration boundary, type-2, long/wide, general, and crosscheck validations | `crossval_migrations_python` | Documentation, audit, and help-render suites |
| `sustainedss` | Adversarial and versioned regression suites | Known-answer, boundary, general, and crosscheck validations | `crossval_edss_python` | Documentation, audit, and help-render suites |
| `cdp` | Adversarial, roving, date-consistency, and versioned suites | Fixed/roving/threshold/boundary/general crosschecks | `crossval_edss_python` | Documentation, audit, and help-render suites |
| `pira` | Parser, censoring, and versioned regression suites | PIRA known answers, boundary, general, and crosscheck validations | `crossval_edss_python` | Documentation, audit, and help-render suites |

## Lane membership

`quick` is a subset of `core`, which is a subset of `full`; `full` is the default release gate. `run_all.do` is the sole authoritative suite list.

| Lane | Suites |
|---|---|
| `quick` | Release/install surfaces, documentation examples, help rendering, high-risk audit regressions, CCI smoke/date checks, CDP adversarial checks, MS known answers, and the EDSS fixture. |
| `core` | `quick` plus every remaining deterministic Stata functional, regression, validation, and internal-crosscheck suite. |
| `full` | `core` plus the three independent-oracle cross-validation suites (CCI, EDSS progression, migrations). |
| `python` | The three independent-oracle cross-validation suites only. |
| `network` | Pinned upstream CCI download and checksum only; run on demand. |
| `benchmark` | The non-gating one-million-visit longitudinal-engine benchmark only. |

## Known gaps

- The repository-root version badge is checked by `check version`, not by the relocatable Stata lane.
- The optional network checksum is deliberately outside `full`; deterministic release evidence comes from the pinned local fixture and Python parity.
- `crossval_edss_python` is a coverage-gap filler, not a regression test: it passes on the pre-1.5.5 code as well, because no EDSS-progression defect was known. Its negative controls (perturbed and empty result files must be rejected) are what demonstrate the comparator can fail. `crossval_migrations_python` does fail on pre-1.5.5 code.
