* _make_diagnose_fixture.do
*
* One-off generator, kept for provenance. It was run ONCE against msm 1.4.12
* (Stata-Tools git tree before the 2.0.0 slim-down) to write
* data/diagnose_fixture_1412.mmat. Re-running it against 2.x would only copy the
* current behaviour into the fixture, so do not regenerate it to make a test pass.
*
* Usage: do _make_diagnose_fixture.do <pkg_dir_1412> <out_file>

version 16.0
args pkg_dir out_file
local qa_dir "`c(pwd)'"
do "`qa_dir'/_diagnose_fixture_scenarios.do"

mata: _dfx_fh = fopen(st_local("out_file"), "rw")
forvalues s = 1/3 {
    _dfx_setup, scenario(`s') pkgdir("`pkg_dir'")
    msm_diagnose, `dfx_opts'
    foreach m in treatment_balance support censor_balance {
        capture confirm matrix r(`m')
        local has = (_rc == 0)
        mata: fputmatrix(_dfx_fh, `has')
        if `has' mata: fputmatrix(_dfx_fh, st_matrix("r(`m')"))
    }
    mata: fputmatrix(_dfx_fh, (st_numscalar("r(n_positivity_violations)"), ///
        st_numscalar("r(min_obs_probability)"), ///
        st_numscalar("r(positivity_threshold)")))
}
mata: fclose(_dfx_fh)
display "FIXTURE WRITTEN: `out_file'"
