*! test_regtab_stats_alias.do — stats() aliases (n_sub/subjects) and unknown-token warning
*! Verifies that stats(n_sub) and stats(subjects) request the N row identically to
*! stats(n) (subject count for survival models), and that an unrecognized token warns
*! without aborting while valid tokens still render.

clear all
set more off

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

* Confirm we are testing the bumped version
which regtab

local failures = 0

**# Test 1: stats(n_sub) renders the same N row as stats(n)
{
    di _newline
    di "Test 1: stats(n_sub) == stats(n) for survival models"
    di _dup(60) "-"

    webuse diet, clear
    stset dox, origin(dob) enter(doe) id(id) fail(fail) scale(365.25)

    collect clear
    collect: stcox height

    local expected_n = e(N_sub)

    * Baseline: stats(n)
    regtab, stats(n) display frame(t_n, replace)
    frame t_n {
        count if A == "Subjects"
        assert r(N) == 1
        levelsof c1 if A == "Subjects", local(v_n) clean
        local v_n = subinstr("`v_n'", ",", "", .)
    }

    * Alias: stats(n_sub)
    regtab, stats(n_sub) display frame(t_nsub, replace)
    frame t_nsub {
        count if A == "Subjects"
        assert r(N) == 1
        levelsof c1 if A == "Subjects", local(v_nsub) clean
        local v_nsub = subinstr("`v_nsub'", ",", "", .)
    }

    di "stats(n) N = `v_n', stats(n_sub) N = `v_nsub', expected = `expected_n'"
    assert real("`v_n'") == `expected_n'
    assert real("`v_nsub'") == `expected_n'
    assert "`v_n'" == "`v_nsub'"
    di "PASS: stats(n_sub) matches stats(n)"
}

**# Test 2: stats(subjects) also renders the N row
{
    di _newline
    di "Test 2: stats(subjects) renders the N row"
    di _dup(60) "-"

    webuse diet, clear
    stset dox, origin(dob) enter(doe) id(id) fail(fail) scale(365.25)

    collect clear
    collect: stcox height
    local expected_n = e(N_sub)

    regtab, stats(subjects) display frame(t_subj, replace)
    frame t_subj {
        count if A == "Subjects"
        assert r(N) == 1
        levelsof c1 if A == "Subjects", local(v) clean
        local v = subinstr("`v'", ",", "", .)
        assert real("`v'") == `expected_n'
    }
    di "PASS: stats(subjects) renders the N row"
}

**# Test 3: unknown token warns but does not abort; valid n still renders
{
    di _newline
    di "Test 3: stats(bogus n) warns, does not abort, N still present"
    di _dup(60) "-"

    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    local expected_n = e(N)

    * Plain call (NO noisily prefix): the warning must surface to a normal user
    * even though the parse block runs inside regtab's internal quietly{}.
    * Capture the session log to a tempfile and assert the warning text appears.
    tempfile warnlog
    log using "`warnlog'", replace text name(_alias_warn)
    regtab, stats(bogus n) display frame(t_bogus, replace)
    local plain_rc = _rc
    log close _alias_warn

    assert `plain_rc' == 0

    * Scan the captured log for the warning text
    local warned = 0
    file open _fh using "`warnlog'", read text
    file read _fh line
    while r(eof) == 0 {
        if strpos(`"`line'"', "not recognized and ignored") local warned = 1
        file read _fh line
    }
    file close _fh
    di "Warning surfaced in plain (non-noisily) call: `warned'"
    assert `warned' == 1

    frame t_bogus {
        count if A == "Observations"
        assert r(N) == 1
        levelsof c1 if A == "Observations", local(v) clean
        local v = subinstr("`v'", ",", "", .)
        assert real("`v'") == `expected_n'
    }
    di "PASS: unknown token surfaces warning to normal user, valid n rendered"
}

**# Test 4: regression — stats(n) output unchanged vs stats(n_sub) on non-survival model
{
    di _newline
    di "Test 4: non-survival stats(n) unchanged; alias still maps to N row"
    di _dup(60) "-"

    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight
    local expected_n = e(N)

    regtab, stats(n) display frame(t4n, replace)
    regtab, stats(n_sub) display frame(t4a, replace)

    frame t4n {
        count if A == "Observations"
        assert r(N) == 1
        levelsof c1 if A == "Observations", local(vn) clean
        local vn = subinstr("`vn'", ",", "", .)
    }
    frame t4a {
        count if A == "Observations"
        assert r(N) == 1
        levelsof c1 if A == "Observations", local(va) clean
        local va = subinstr("`va'", ",", "", .)
    }
    assert real("`vn'") == `expected_n'
    assert "`vn'" == "`va'"
    di "PASS: alias maps to N row for non-survival models too"
}

**# Summary
{
    di _newline
    di _dup(60) "="
    di "ALL TESTS PASSED"
    di _dup(60) "="
}
