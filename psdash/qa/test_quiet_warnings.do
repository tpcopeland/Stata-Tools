* test_quiet_warnings.do -- panel warnings and coloured verdict words obey `quietly`
*
* Fail-on-old (psdash 1.8.0 as first built): "Warning:" lines and the WARNING /
* IMBALANCED / FAIL verdict word were written with `display as error`, a class
* that `quietly` does not suppress, so `quietly psdash ...` still printed them.
* The findings stay in r(warnings), r(n_warnings) and r(verdict); the noisy run
* still prints them.

version 16.0
clear all
capture log close _all
do "`c(pwd)'/_psdash_bootstrap.do"
local tests = 0
local pass = 0
local fail = 0
local failed ""

tempfile stem
* Append to the tempfile name; rewriting its dots would also rewrite dots in
* the TMPDIR path (e.g. ~/.cache) and point at a directory that does not exist.
local logf "`stem'_qw.log"

* Count log lines carrying a warning word.
capture mata: mata drop _qw_count()
mata:
// Whole-file fread: cat() and file read drop an unterminated last line,
// and a leaked verdict word is exactly that (display with no newline).
void _qw_count(string scalar f)
{
    real scalar fh, n
    string scalar txt, pat
    fh = fopen(f, "r")
    txt = fread(fh, 50000000)
    fclose(fh)
    n = 0
    if (rows(txt) == 0) {
        st_local("n", "0")
        return
    }
    pat = "Warning:|WARNING|IMBALANCED|UNDEFINED|FAIL|Exact boundaries|probability of some"
    while (regexm(txt, pat)) {
        n++
        txt = substr(txt, strpos(txt, regexs(0)) + strlen(regexs(0)), .)
    }
    st_local("n", strofreal(n))
}
end

capture program drop _qw_hits
program define _qw_hits, rclass
    args f
    * Mata cat() keeps an unterminated last line, which file read can drop.
    mata: _qw_count(st_local("f"))
    return scalar n = `n'
end

* Run a psdash command quietly or noisily under a text log.
capture program drop _qw_run
program define _qw_run, rclass
    args mode f cmd
    quietly log using "`f'", name(qw) text replace
    capture noisily {
        if "`mode'" == "quiet" quietly `cmd'
        else `cmd'
    }
    local rc = _rc
    local nw = r(n_warnings)
    local vd "`r(verdict)'"
    * a leaked verdict word has no newline; end the line so the log keeps it
    display
    quietly log close qw
    return scalar rc = `rc'
    return scalar nw = `nw'
    return local verdict "`vd'"
end

capture program drop _qw_checkq
program define _qw_checkq
    args f cmd
    _qw_run quiet "`f'" "`cmd'"
    assert r(rc) == 0
    _qw_hits "`f'"
    assert r(n) == 0
    _qw_run loud "`f'" "`cmd'"
    assert r(rc) == 0
    _qw_hits "`f'"
    assert r(n) >= 1
end

clear
set seed 4321
set obs 300
gen byte treat = _n > 150
gen double x = rnormal() + 4 * treat
gen double cov = rnormal(0, cond(treat, 10, 1))
quietly logit treat x
predict double ps
gen double w = cond(treat, 1/ps, 1/(1-ps))
replace w = 60 in 1
gen double smdcov = rnormal() + 2 * treat
gen double ps_bd = ps
replace ps_bd = 0 in 1
replace ps_bd = 1 in 300

capture program drop _qw_check
program define _qw_check
    args f cmd
    _qw_run quiet "`f'" "`cmd'"
    assert r(rc) == 0
    local nwq = r(nw)
    _qw_hits "`f'"
    assert r(n) == 0
    * the finding still reaches r()
    assert `nwq' >= 1 & `nwq' < .
    _qw_run loud "`f'" "`cmd'"
    assert r(rc) == 0
    _qw_hits "`f'"
    assert r(n) >= 1
end

local ++tests
capture noisily _qw_check "`logf'" "psdash overlap treat ps"
if _rc == 0 {
    local ++pass
    display as result "  PASS: T1_overlap"
}
else {
    local ++fail
    local failed "`failed' T1_overlap"
    display as error "  FAIL: T1_overlap (rc=`=_rc')"
    capture log close qw
}

local ++tests
capture noisily _qw_check "`logf'" "psdash weights treat ps, wvar(w)"
if _rc == 0 {
    local ++pass
    display as result "  PASS: T2_weights"
}
else {
    local ++fail
    local failed "`failed' T2_weights"
    display as error "  FAIL: T2_weights (rc=`=_rc')"
    capture log close qw
}

local ++tests
capture noisily _qw_check "`logf'" "psdash support treat ps"
if _rc == 0 {
    local ++pass
    display as result "  PASS: T3_support"
}
else {
    local ++fail
    local failed "`failed' T3_support"
    display as error "  FAIL: T3_support (rc=`=_rc')"
    capture log close qw
}

local ++tests
capture noisily _qw_check "`logf'" "psdash balance treat ps, covariates(cov)"
if _rc == 0 {
    local ++pass
    display as result "  PASS: T4_balance"
}
else {
    local ++fail
    local failed "`failed' T4_balance"
    display as error "  FAIL: T4_balance (rc=`=_rc')"
    capture log close qw
}

local ++tests
capture noisily {
    _qw_checkq "`logf'" "psdash balance treat ps, covariates(smdcov)"
}
if _rc == 0 {
    local ++pass
    display as result "  PASS: T5_balance_smd_status"
}
else {
    local ++fail
    local failed "`failed' T5_balance_smd_status"
    display as error "  FAIL: T5_balance_smd_status (rc=`=_rc')"
    capture log close qw
}

local ++tests
capture noisily {
    _qw_checkq "`logf'" "psdash overlap treat ps_bd"
}
if _rc == 0 {
    local ++pass
    display as result "  PASS: T6_overlap_ps_boundary"
}
else {
    local ++fail
    local failed "`failed' T6_overlap_ps_boundary"
    display as error "  FAIL: T6_overlap_ps_boundary (rc=`=_rc')"
    capture log close qw
}

local ++tests
capture noisily {
    _qw_checkq "`logf'" "psdash support treat ps_bd"
}
if _rc == 0 {
    local ++pass
    display as result "  PASS: T7_support_ps_boundary"
}
else {
    local ++fail
    local failed "`failed' T7_support_ps_boundary"
    display as error "  FAIL: T7_support_ps_boundary (rc=`=_rc')"
    capture log close qw
}

local ++tests
capture noisily {
    preserve
    clear
    set seed 77
    set obs 300
    gen byte treat = ceil(_n / 100) - 1
    gen double x1 = rnormal() + 2 * treat
    gen double w = 1
    _qw_checkq "`logf'" "psdash balance treat, covariates(x1) wvar(w)"
    restore
}
if _rc == 0 {
    local ++pass
    display as result "  PASS: T8_multigroup_balance_status"
}
else {
    local ++fail
    local failed "`failed' T8_multigroup_balance_status"
    display as error "  FAIL: T8_multigroup_balance_status (rc=`=_rc')"
    capture log close qw
    restore
}

capture erase "`logf'"
display "RESULT: test_quiet_warnings tests=`tests' pass=`pass' fail=`fail'"
capture _psdash_qa_cleanup
capture log close _all
if `fail' > 0 {
    display as error "FAILED:`failed'"
    exit 9
}
