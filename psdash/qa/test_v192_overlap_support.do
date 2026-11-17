* test_v192_overlap_support.do -- psdash 1.9.2 overlap/support fixes
* Author: Timothy P Copeland, Karolinska Institutet
*
* Changes under test (Gemini review v2, slice overlap/support):
*   I1  estimand(ATT/ATC/ATE) is case-normalised: r(estimand) is lowercase in
*       overlap and support (binary and multi-group), and support compare
*       computes the ESS with the requested estimand's weights (uppercase
*       ATT previously fell through to the ATE weights at rc=0)
*   I2  support compare with a trim that keeps <2 observations in an arm
*       exits 459 before generate() runs: a replace() target survives and a
*       new generate() variable is not leaked
*   I9  overlap bwidth() of a non-finite number (1e500) is refused (198)
*       on the binary and multi-group routes
*   I10 support compare notes observations left out of the ESS because
*       their IPTW weight is undefined (PS at the 0/1 boundary)
*   M3  support crump with no PS strictly inside (0,1) errors 459 without
*       the false "using alpha = 0.1" fallback note
*   M4  multi-group "Mean GPS" columns widen to the longest e(label) header
*
* Oracles are hand computed from the PS columns, never from psdash output.
*
* Usage: cd psdash/qa && stata-mp -b do test_v192_overlap_support.do
version 16.0
capture log close _all
log using test_v192_overlap_support.log, replace nomsg
do "`c(pwd)'/_psdash_bootstrap.do"
local tests = 0
local pass = 0
local fail = 0
local skip = 0
global V192C_FAILED ""

capture program drop _v192c_rec
program define _v192c_rec
    args name rc
    if `rc' {
        display as error "FAIL: `name' (rc=`rc')"
        global V192C_FAILED "$V192C_FAILED `name'"
    }
    else display as result "PASS: `name'"
end

* Binary fixture with a logit PS.
capture program drop _v192c_binary
program define _v192c_binary
    clear
    set seed 1
    set obs 200
    generate byte treat = runiform() < .4
    generate double x1 = rnormal() + treat
    quietly logit treat x1
    quietly predict double ps, pr
end

* Three-arm fixture with mlogit GPS columns.
capture program drop _v192c_three
program define _v192c_three
    clear
    set seed 3
    set obs 300
    generate byte arm = floor(runiform() * 3)
    generate double x1 = rnormal() + arm
    quietly mlogit arm x1
    quietly predict double p0 p1 p2, pr
end

* Kish pooled ESS% of estimand weights on a sample (hand oracle).
capture program drop _v192c_ess
program define _v192c_ess, rclass
    syntax [if] , estimand(string)
    tempvar w
    quietly {
        generate double `w' = .
        if "`estimand'" == "att" {
            replace `w' = 1 if treat == 1
            replace `w' = ps / (1 - ps) if treat == 0 & ps < 1
        }
        else {
            replace `w' = 1 / ps if treat == 1 & ps > 0
            replace `w' = 1 / (1 - ps) if treat == 0 & ps < 1
        }
        tempvar w2
        generate double `w2' = `w'^2
        summarize `w' `if', meanonly
        local s1 = r(sum)
        local n = r(N)
        summarize `w2' `if', meanonly
        local s2 = r(sum)
    }
    return scalar ess_pct = 100 * (`s1'^2 / `s2') / `n'
end

**# T1 (I1): uppercase estimand returns lowercase r(estimand), binary
foreach c in overlap support {
    foreach e in ATT ATC ATE {
        capture noisily {
            _v192c_binary
            quietly psdash `c' treat ps, estimand(`e') nograph
            assert "`r(estimand)'" == strlower("`e'")
        }
        local rc = _rc
        local ++tests
        if `rc' local ++fail
        else local ++pass
        _v192c_rec estimand_case_`c'_`e' `rc'
    }
}

**# T2 (I1): uppercase estimand returns lowercase r(estimand), multi-group
foreach c in overlap support {
    capture noisily {
        _v192c_three
        quietly psdash `c' arm, psvars(p0 p1 p2) estimand(ATE) nograph
        assert "`r(estimand)'" == "ate"
    }
    local rc = _rc
    local ++tests
    if `rc' local ++fail
    else local ++pass
    _v192c_rec estimand_case_mg_`c' `rc'
}

**# T3 (I1): support compare with estimand(ATT) uses ATT weights
capture noisily {
    _v192c_binary
    _v192c_ess, estimand(att)
    local o_pre_att = r(ess_pct)
    _v192c_ess, estimand(ate)
    local o_pre_ate = r(ess_pct)
    _v192c_ess if ps >= .1 & ps <= .9, estimand(att)
    local o_post_att = r(ess_pct)
    assert abs(`o_pre_att' - `o_pre_ate') > 1
    quietly psdash support treat ps, threshold(.1) compare covariates(x1) ///
        estimand(ATT) nograph
    local up_pre = r(ess_pct_pre)
    local up_post = r(ess_pct_post)
    assert "`r(estimand)'" == "att"
    assert !missing(`up_pre') & !missing(`o_pre_att')
    assert reldif(`up_pre', `o_pre_att') < 1e-10
    assert !missing(`up_post') & !missing(`o_post_att')
    assert reldif(`up_post', `o_post_att') < 1e-10
    quietly psdash support treat ps, threshold(.1) compare covariates(x1) ///
        estimand(att) nograph
    assert !missing(r(ess_pct_pre)) & !missing(`up_pre')
    assert reldif(r(ess_pct_pre), `up_pre') < 1e-12
    assert !missing(r(ess_pct_post)) & !missing(`up_post')
    assert reldif(r(ess_pct_post), `up_post') < 1e-12
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192c_rec compare_ess_uppercase_att `rc'

* Singleton-arm trim fixture: one treated row survives threshold(.05).
capture program drop _v192c_single
program define _v192c_single
    clear
    set seed 11
    set obs 20
    generate byte treat = (_n > 10)
    generate double x1 = rnormal()
    generate double ps = cond(treat == 1, cond(_n == 11, 0.5, 0.01), 0.5)
end

**# T4 (I2): compare failure keeps the caller's replace() target intact
capture noisily {
    _v192c_single
    generate double myflag = 99
    capture noisily psdash support treat ps, threshold(0.05) compare ///
        covariates(x1) generate(myflag) replace nograph
    assert _rc == 459
    confirm double variable myflag
    quietly count if myflag != 99
    assert r(N) == 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192c_rec compare_singleton_keeps_replace_target `rc'

**# T5 (I2): compare failure does not leak a new generate() variable
capture noisily {
    _v192c_single
    quietly ds
    local before "`r(varlist)'"
    capture noisily psdash support treat ps, threshold(0.05) compare ///
        covariates(x1) generate(newf) nograph
    assert _rc == 459
    capture confirm variable newf
    assert _rc == 111
    quietly ds
    assert "`r(varlist)'" == "`before'"
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192c_rec compare_singleton_no_leak `rc'

**# T6 (I2 guard): without compare the singleton trim still succeeds and
* generate() replace writes the hand-computed indicator
capture noisily {
    _v192c_single
    generate double myflag = 99
    quietly psdash support treat ps, threshold(0.05) generate(myflag) replace nograph
    generate byte oracle = (ps >= .05 & ps <= .95)
    assert myflag == oracle
    quietly count if myflag == 1 & treat == 1
    assert r(N) == 1
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192c_rec nocompare_singleton_generate_ok `rc'

**# T7 (I2 guard): a successful compare still commits generate() replace
capture noisily {
    _v192c_binary
    generate double flag = 99
    quietly psdash support treat ps, threshold(.1) compare covariates(x1) ///
        generate(flag) replace nograph
    confirm byte variable flag
    generate byte oracle = (ps >= .1 & ps <= .9)
    assert flag == oracle
    local lab : variable label flag
    assert strpos(`"`lab'"', "In trimmed support") == 1
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192c_rec compare_success_commits_generate `rc'

**# T8 (I9): non-finite bwidth() is refused, binary and multi-group
capture noisily {
    _v192c_binary
    capture psdash overlap treat ps, bwidth(1e500) nograph
    assert _rc == 198
    capture psdash overlap treat ps, bwidth(1e500)
    assert _rc == 198
    _v192c_three
    capture psdash overlap arm, psvars(p0 p1 p2) bwidth(1e500)
    assert _rc == 198
    quietly psdash overlap arm, psvars(p0 p1 p2) bwidth(.05) nograph
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192c_rec bwidth_nonfinite_refused `rc'
graph drop _all

**# T9 (I10): boundary PS rows are noted as excluded from the ESS
capture noisily {
    clear
    set seed 5
    set obs 20
    generate byte treat = (_n > 10)
    generate double x1 = rnormal()
    generate double ps = runiform(.2, .8)
    replace ps = 0 if _n == 11
    _v192c_ess if ps > 0, estimand(ate)
    local o_pre = r(ess_pct)
    tempfile lg
    log using `"`lg'"', text replace name(_v192c_i10)
    quietly noisily psdash support treat ps, threshold(0.05) compare ///
        covariates(x1) nograph
    local got_pre = r(ess_pct_pre)
    log close _v192c_i10
    assert !missing(`got_pre') & !missing(`o_pre')
    assert reldif(`got_pre', `o_pre') < 1e-10
    tempname fh
    local found = 0
    file open `fh' using `"`lg'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "note: ESS excludes 1 obs pre-trim, 0 post-trim (PS at 0/1, weight undefined)") ///
            local found = 1
        file read `fh' line
    }
    file close `fh'
    assert `found' == 1
}
local rc = _rc
capture log close _v192c_i10
local ++tests
if `rc' local ++fail
else local ++pass
_v192c_rec ess_boundary_note `rc'

**# T10 (I10 guard): no boundary rows, no note
capture noisily {
    _v192c_binary
    tempfile lg
    log using `"`lg'"', text replace name(_v192c_i10b)
    quietly noisily psdash support treat ps, threshold(.1) compare ///
        covariates(x1) nograph
    log close _v192c_i10b
    tempname fh
    local found = 0
    file open `fh' using `"`lg'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "ESS excludes") local found = 1
        file read `fh' line
    }
    file close `fh'
    assert `found' == 0
}
local rc = _rc
capture log close _v192c_i10b
local ++tests
if `rc' local ++fail
else local ++pass
_v192c_rec ess_no_boundary_no_note `rc'

**# T11 (M3): crump with no interior PS errors without the fallback note
capture noisily {
    clear
    set obs 20
    generate byte treat = (_n > 10)
    generate double ps = mod(_n, 2)
    tempfile lg
    log using `"`lg'"', text replace name(_v192c_m3)
    capture noisily psdash support treat ps, crump nograph
    local prc = _rc
    log close _v192c_m3
    assert `prc' == 459
    tempname fh
    local fallback = 0
    local undefined = 0
    file open `fh' using `"`lg'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "using alpha = 0.1") local fallback = 1
        if strpos(`"`macval(line)'"', "no propensity score lies strictly inside (0,1)") local undefined = 1
        file read `fh' line
    }
    file close `fh'
    assert `fallback' == 0
    assert `undefined' == 1
}
local rc = _rc
capture log close _v192c_m3
local ++tests
if `rc' local ++fail
else local ++pass
_v192c_rec crump_no_interior_errors `rc'

**# T12 (M4): each GPS column widens to its own e(label) header
* Widths: 30 (group + N) + e(Short)=13 (min) + e(VeryLongLabelAB)=18+2=20
* + e(Med)=13 (min) = 76. A uniform max width would give 30+3*20 = 90.
* linesize is pinned so the header cannot wrap; the header is the first
* line starting with "Observed group" and the next nonblank row is "Short".
foreach c in overlap support {
    local _ls = c(linesize)
    capture noisily {
        set linesize 200
        _v192c_three
        label define _v192c_L 0 "Short" 1 "VeryLongLabelAB" 2 "Med", replace
        label values arm _v192c_L
        tempfile lg
        log using `"`lg'"', text replace name(_v192c_m4)
        quietly noisily psdash `c' arm, psvars(p0 p1 p2) nograph
        log close _v192c_m4
        tempname fh
        local hdr ""
        local row ""
        local state 0
        file open `fh' using `"`lg'"', read text
        file read `fh' line
        while r(eof) == 0 {
            local t = strtrim(`"`macval(line)'"')
            if `state' == 0 & substr(`"`macval(t)'"', 1, 14) == "Observed group" {
                local hdr = rtrim(`"`macval(line)'"')
                local state 1
            }
            else if `state' == 1 & substr(`"`macval(t)'"', 1, 5) == "Short" {
                local row = rtrim(`"`macval(line)'"')
                local state 2
            }
            file read `fh' line
        }
        file close `fh'
        assert `"`hdr'"' != ""
        assert `"`row'"' != ""
        assert strpos(`"`hdr'"', "e(Short)") > 0
        assert strpos(`"`hdr'"', "e(VeryLongLabelAB)") > 0
        assert strpos(`"`hdr'"', ")e(") == 0
        assert strpos(`"`hdr'"', "Ne(") == 0
        * per-column widths: header and data row both end at column 76
        assert ustrlen(`"`hdr'"') == 76
        assert ustrlen(`"`row'"') == 76
        * the long column is 20 wide: e(VeryLongLabelAB) ends at 30+13+20
        assert strpos(`"`hdr'"', "e(VeryLongLabelAB)") + 17 == 63
    }
    local rc = _rc
    capture log close _v192c_m4
    set linesize `_ls'
    local ++tests
    if `rc' local ++fail
    else local ++pass
    _v192c_rec mg_header_width_`c' `rc'
}

**# T13 (I2 follow-up): the guard message names the covariate-free route,
* and that route (compare, no covariates) still succeeds on the same
* singleton fixture: 1 treated + 10 control retained, ESS pre/post defined.
capture noisily {
    _v192c_single
    tempfile lg
    log using `"`lg'"', text replace name(_v192c_i2b)
    capture noisily psdash support treat ps, threshold(0.05) compare ///
        covariates(x1) nograph
    local rc459 = _rc
    log close _v192c_i2b
    assert `rc459' == 459
    tempname fh
    local hit 0
    file open `fh' using `"`lg'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Without covariates, compare") local hit = 1
        file read `fh' line
    }
    file close `fh'
    assert `hit' == 1
    psdash support treat ps, threshold(0.05) compare nograph
    assert r(n_trimmed) == 9
    assert !missing(r(ess_pct_pre)) & !missing(r(ess_pct_post))
}
local rc = _rc
capture log close _v192c_i2b
local ++tests
if `rc' local ++fail
else local ++pass
_v192c_rec compare_guard_message_nocov_route `rc'

**# T14 (M8 mirror): overlap/support xlsx() is written although saving()
* fails, binary and multi-group; the command still exits nonzero.
capture noisily {
    clear
    set seed 19202
    set obs 400
    gen double x1 = rnormal()
    gen byte treat = runiform() < invlogit(0.4 * x1)
    quietly logit treat x1
    quietly predict double ps, pr
    tempfile xo xs xmo xms
    capture psdash overlap treat ps, saving("/nonexistent_dir_v192c/zz.png") xlsx("`xo'.xlsx")
    assert _rc != 0
    confirm file "`xo'.xlsx"
    capture psdash support treat ps, saving("/nonexistent_dir_v192c/zz.png") xlsx("`xs'.xlsx")
    assert _rc != 0
    confirm file "`xs'.xlsx"
    gen byte arm = cond(runiform() < 0.33, 0, cond(runiform() < 0.5, 1, 2))
    quietly mlogit arm x1, baseoutcome(0)
    quietly predict double p0 p1 p2, pr
    capture psdash overlap arm, psvars(p0 p1 p2) saving("/nonexistent_dir_v192c/zz.png") xlsx("`xmo'.xlsx")
    assert _rc != 0
    confirm file "`xmo'.xlsx"
    capture psdash support arm, psvars(p0 p1 p2) saving("/nonexistent_dir_v192c/zz.png") xlsx("`xms'.xlsx")
    assert _rc != 0
    confirm file "`xms'.xlsx"
    quietly import excel using "`xs'.xlsx", clear allstring
    assert _N > 0
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
_v192c_rec xlsx_after_saving_failure `rc'
capture graph drop _all

display "RESULT: test_v192_overlap_support tests=`tests' pass=`pass' fail=`fail' skip=`skip'"
if `fail' display as error "Failed:$V192C_FAILED"
global V192C_FAILED
_psdash_qa_cleanup
log close
if `fail' exit 1
