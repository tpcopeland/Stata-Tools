# gcomp QA

Run the complete release lane from this directory with:

```bash
stata-mp -b do run_all.do
```

`run_all.do` is the canonical full lane and explicitly runs every `test_*`, `validation_*`, and `crossval_*` suite. `run_refactor_gate.do` is a faster, focused regression lane for the bootstrap-dispatch and reporting refactors.

## File index

- Full-lane inventory: `test_adversarial_gcomp.do`, `test_adversarial_gcomptab.do`, `test_doc_examples.do`, `test_errors.do`, `test_gcomp.do`, `test_gcomp_diagnostics.do`, `test_gcomp_imputation_mlogit.do`, `test_gcomp_validation.do`, `test_gcomptab_doseresponse.do`, `test_gcomptab_regressions.do`, `test_gcomptab_text_export.do`, `test_install_smoke.do`, `test_interactions.do`, `test_models.do`, `test_refactor_bootstrap_dispatch.do`, `test_refactor_display_golden.do`, `test_refactor_gcomptab_geometry.do`, `test_refactor_msm_omitted.do`, `test_stress.do`, `validation_adversarial_gcomp.do`, `validation_extra.do`, `validation_gcomp.do`, `validation_gcomp_recovery.do`, `validation_gcomp_recovery_extended.do`, `validation_gcomp_recovery_surface.do`, `validation_peripartum_readiness.do`, `validation_timevarying.do`, `crossval_external_replication.do`, `crossval_gcomp.do`, `crossval_intervention_imputation.do`, `crossval_longitudinal_extended.do`, `crossval_mediation_extended.do`, `crossval_mediation_se.do`, `crossval_timevarying.do`, and `crossval_timevarying_se.do`.
- `test_gcomp.do`, `test_gcomp_validation.do`, `test_errors.do`, `test_interactions.do`, and `test_stress.do`: core functionality, validation, invalid input, option interactions, and stress paths.
- `test_adversarial_gcomp.do`, `test_adversarial_gcomptab.do`, `test_gcomptab_regressions.do`, `test_gcomptab_doseresponse.do`, and `test_gcomptab_text_export.do`: adversarial and output-contract coverage for both public commands.
- `test_gcomp_diagnostics.do`, `test_gcomp_imputation_mlogit.do`, and `test_models.do`: diagnostics, categorical imputation, and component-model workflows.
- `test_doc_examples.do` and `test_install_smoke.do`: installed-user documentation and package-surface smoke tests.
- `test_refactor_*.do`: focused regressions for bootstrap dispatch, displayed output, MSM omitted coefficients, and Excel geometry.
- `validation_*.do`: known-answer, recovery, adversarial, time-varying, and peripartum validation suites.
- `crossval_*.do`: independent external-reference checks for mediation, longitudinal, time-varying, intervention/imputation, and bootstrap-SE paths.

## Coverage map

| Surface | Primary coverage |
| --- | --- |
| `gcomp` mediation and time-varying estimation | `test_gcomp.do`, `validation_gcomp*.do`, `crossval_*.do` |
| Simulation/bootstrapping and MSM | `test_refactor_bootstrap_dispatch.do`, `test_refactor_msm_omitted.do`, `test_stress.do` |
| `gcomptab` mediation, dose-response, and text/Excel output | `test_gcomptab_*.do`, `test_adversarial_gcomptab.do` |
| Installation, helpers, and visible examples | `test_install_smoke.do`, `test_doc_examples.do` |

## Lane membership

| Lane | Runner | Contents |
| --- | --- | --- |
| Full | `run_all.do` | All functional, validation, and cross-validation suites |
| Refactor gate | `run_refactor_gate.do` | Focused refactor regressions plus selected core, validation, and cross-validation checks |

Tests derive the package root from `c(pwd)` and put disposable artifacts in `c(tmpdir)`. Files in `data/` are deliberate external inputs or reference outputs.
