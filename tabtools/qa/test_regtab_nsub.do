*! test_regtab_nsub.do — Validate stats(n) reports subjects for survival models
*! Tests the N_sub fix: survival models with time-varying covariates should
*! report number of subjects, not number of rows/episodes.

clear all
set more off

capture ado uninstall tabtools
net install tabtools, from("~/Stata-Tools/tabtools") replace

local failures = 0

**# Test 1: stcox with stsplit — N should be subjects, not episodes
{
    di _newline
    di "Test 1: stcox with stsplit — stats(n) reports subjects"
    di _dup(60) "-"

    webuse diet, clear
    stset dox, origin(dob) enter(doe) id(id) fail(fail) scale(365.25)

    * Get subject count from a simple stcox before stsplit
    quietly stcox height
    local n_subjects = e(N_sub)

    stsplit, at(failures)
    local n_rows = _N

    di "Subjects: `n_subjects'"
    di "Rows after stsplit: `n_rows'"
    assert `n_rows' > `n_subjects' // sanity: stsplit actually expanded

    collect clear
    collect: stcox height

    * Verify e() values — N should be rows, N_sub should be subjects
    di "e(N) = " e(N) " (rows in risk set)"
    di "e(N_sub) = " e(N_sub) " (subjects)"
    assert e(N) > e(N_sub)
    assert e(N_sub) == `n_subjects'

    regtab, stats(n) display frame(t1, replace)

    frame t1 {
        * Find the N row — should say "Subjects", not "Observations"
        count if A == "Subjects"
        local found_subjects = r(N)
        count if A == "Observations"
        local found_obs = r(N)

        di "Found 'Subjects' rows: `found_subjects'"
        di "Found 'Observations' rows: `found_obs'"

        assert `found_subjects' == 1
        assert `found_obs' == 0

        * Check the value is the subject count, not row count
        levelsof c1 if A == "Subjects", local(nval) clean
        local nval_clean = subinstr("`nval'", ",", "", .)
        di "N value in table: `nval_clean'"
        di "Expected (subjects): `n_subjects'"
        assert real("`nval_clean'") == `n_subjects'
    }
    di "PASS: stcox+stsplit reports subjects correctly"
}


**# Test 2: stcox without stsplit — N should still work (N == N_sub)
{
    di _newline
    di "Test 2: stcox without stsplit — stats(n) still works"
    di _dup(60) "-"

    webuse diet, clear
    stset dox, origin(dob) enter(doe) id(id) fail(fail) scale(365.25)

    collect clear
    collect: stcox height

    local expected_n = e(N_sub)
    assert e(N) == e(N_sub)

    regtab, stats(n) display frame(t2, replace)

    frame t2 {
        * Should say "Subjects" (N_sub is always set for st commands)
        count if A == "Subjects"
        assert r(N) == 1

        levelsof c1 if A == "Subjects", local(nval) clean
        local nval_clean = subinstr("`nval'", ",", "", .)
        assert real("`nval_clean'") == `expected_n'
    }
    di "PASS: stcox without stsplit reports correctly"
}


**# Test 3: logit — should still say "Observations" (no N_sub)
{
    di _newline
    di "Test 3: logit — stats(n) says Observations"
    di _dup(60) "-"

    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight

    local expected_n = e(N)

    regtab, stats(n) display frame(t3, replace)

    frame t3 {
        count if A == "Observations"
        local found_obs = r(N)
        count if A == "Subjects"
        local found_sub = r(N)

        di "Found 'Observations' rows: `found_obs'"
        di "Found 'Subjects' rows: `found_sub'"

        assert `found_obs' == 1
        assert `found_sub' == 0

        levelsof c1 if A == "Observations", local(nval) clean
        local nval_clean = subinstr("`nval'", ",", "", .)
        assert real("`nval_clean'") == `expected_n'
    }
    di "PASS: logit says Observations"
}


**# Test 4: regress — should still say "Observations"
{
    di _newline
    di "Test 4: regress — stats(n) says Observations"
    di _dup(60) "-"

    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    local expected_n = e(N)

    regtab, stats(n) display frame(t4, replace)

    frame t4 {
        count if A == "Observations"
        assert r(N) == 1
        count if A == "Subjects"
        assert r(N) == 0

        levelsof c1 if A == "Observations", local(nval) clean
        local nval_clean = subinstr("`nval'", ",", "", .)
        assert real("`nval_clean'") == `expected_n'
    }
    di "PASS: regress says Observations"
}


**# Test 5: Mixed table — stcox + logit in same collect
{
    di _newline
    di "Test 5: Mixed table — stcox (stsplit) + logit"
    di _dup(60) "-"

    * First model: stcox with stsplit
    webuse diet, clear
    stset dox, origin(dob) enter(doe) id(id) fail(fail) scale(365.25)
    local n_subjects = r(N_sub)
    stsplit, at(failures)

    collect clear
    collect: stcox height

    local cox_n_sub = e(N_sub)
    local cox_n_obs = e(N)
    di "Cox: N_sub=`cox_n_sub', N=`cox_n_obs'"

    * Second model: logit on different data
    sysuse auto, clear
    collect: logit foreign mpg weight

    local logit_n = e(N)
    di "Logit: N=`logit_n'"

    regtab, stats(n) display frame(t5, replace)

    frame t5 {
        * Should say "Subjects" because at least one model has N_sub
        count if A == "Subjects"
        assert r(N) == 1

        * Model 1 (Cox) should show subject count
        levelsof c1 if A == "Subjects", local(nval1) clean
        local nval1_clean = subinstr("`nval1'", ",", "", .)
        di "Model 1 (Cox) N: `nval1_clean' (expected `cox_n_sub')"
        assert real("`nval1_clean'") == `cox_n_sub'

        * Model 2 (logit) should show its observation count
        levelsof c4 if A == "Subjects", local(nval2) clean
        local nval2_clean = subinstr("`nval2'", ",", "", .)
        di "Model 2 (logit) N: `nval2_clean' (expected `logit_n')"
        assert real("`nval2_clean'") == `logit_n'
    }
    di "PASS: mixed table — Cox gets subjects, logit gets observations"
}


**# Test 6: streg with stsplit — confirms fix works for non-stcox st commands
{
    di _newline
    di "Test 6: streg with stsplit — stats(n) reports subjects"
    di _dup(60) "-"

    webuse diet, clear
    stset dox, origin(dob) enter(doe) id(id) fail(fail) scale(365.25)

    quietly streg height, dist(weibull)
    local n_subjects = e(N_sub)

    stsplit, at(failures)
    local n_rows = _N

    di "Subjects: `n_subjects'"
    di "Rows after stsplit: `n_rows'"
    assert `n_rows' > `n_subjects'

    collect clear
    collect: streg height, dist(weibull)

    di "e(N) = " e(N) ", e(N_sub) = " e(N_sub)
    assert e(N) > e(N_sub)
    assert e(N_sub) == `n_subjects'

    regtab, stats(n) display frame(t6, replace)

    frame t6 {
        count if A == "Subjects"
        assert r(N) == 1
        count if A == "Observations"
        assert r(N) == 0

        levelsof c1 if A == "Subjects", local(nval) clean
        local nval_clean = subinstr("`nval'", ",", "", .)
        di "N value: `nval_clean' (expected `n_subjects')"
        assert real("`nval_clean'") == `n_subjects'
    }
    di "PASS: streg+stsplit reports subjects correctly"
}


**# Summary
{
    di _newline
    di _dup(60) "="
    di "ALL TESTS PASSED"
    di _dup(60) "="
}
