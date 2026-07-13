# setools QA

Run every Stata suite from this `qa/` directory with `stata-mp`. The runner installs the package into temporary `PLUS` and `PERSONAL` directories, restores the original Stata settings afterward, and never needs the user’s normal adopath.

```bash
stata-mp -b do run_all.do quick
stata-mp -b do run_all.do core
stata-mp -b do run_all.do full
stata-mp -b do run_all.do python
stata-mp -b do run_all.do network
```

The lanes are nested as `quick` ⊆ `core` ⊆ `full`. `quick` covers release integrity and the highest-risk regressions; `core` adds every deterministic Stata functional, validation, and cross-command suite; `full` also runs the required Python CCI cross-validation. `python` runs that cross-validation alone. `network` is optional and verifies the checksum of the pinned upstream CCI source; no quick, core, or full test requires network access.

Python 3 with only the standard library is required for `full`/`python`. Stata 16 or later is required for every lane. No R dependency is used.

Every executable suite must print exactly one final line beginning with `RESULT:` and exit nonzero when its failure count is positive. `run_all.do` rejects an unknown lane with return code 198 and preflights the source of each selected suite for the result sentinel.

Fixtures and refresh procedures are recorded in [fixtures_manifest.md](fixtures_manifest.md). Generated datasets, exported CSV files, status files, and logs go to Stata tempfiles or suite-specific temporary directories. Suites must close any log they open; the runner removes its isolated installation during teardown even when a child suite returns nonzero.

Typical runtimes depend on hardware and Stata licensing. Use `quick` while editing, `core` before review, and `full` for the final QA gate. The optional `network` lane should not be used as evidence for deterministic release behavior.

## Suite inventory

The deterministic functional suites are `test_setools.do`, `test_release_integrity.do`, `test_documentation_examples.do`, `test_audit_regressions.do`, `test_cci_engine_smoke.do`, `test_cci_dates_parity.do`, `test_cci_se_adversarial.do`, `test_cdp_adversarial.do`, `test_cdp_roving_determinism.do`, `test_edss_fixture.do`, `test_migrations_keepimmigrants.do`, `test_migrations_malformed_rollback.do`, `test_migrations_minresidence.do`, `test_migrations_perm_emig_bug.do`, `test_setools_v130_features.do`, and `test_setools_v140_features.do`. The network-only suite is `test_network_smoke.do`.

The known-answer and boundary suites are `validation_cci_se_date_hierarchy.do`, `validation_cci_se_era_boundaries.do`, `validation_cci_se_known_scores.do`, `validation_cci_se_v121.do`, `validation_cdp_known_answers.do`, `validation_cdp_roving_exit.do`, `validation_cdp_threetier_confirmtype.do`, `validation_known_answer_boundaries.do`, `validation_migrations_adversarial_boundaries.do`, `validation_migrations_longwide_equivalence.do`, `validation_migrations_type2_censoring.do`, `validation_pira_known_answers.do`, `validation_setools.do`, and `validation_sustainedss_known_answers.do`.

The cross-validation suites are `crossval_setools.do` and `crossval_cci_se_python.do`. `run_all.do` is the lane orchestrator, while `_setools_qa_common.do` owns the isolated-install setup and teardown shared by every runnable suite.
