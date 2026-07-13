* test_refactor_msm_omitted.do - S3 refactor guard for omitted MSM terms
* Coverage: omitted factor/interactions in msm(), e(b)/e(V)/e(se)/CI names,
*           dimensions, and bootstrap covariance alignment.

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local testdir "`c(tmpdir)'"

do "`qa_dir'/_qa_bootstrap.do"

capture program drop _s3_name_absent
program define _s3_name_absent
    version 16.0
    syntax name(name=mname), Bad(string)

    local names : colfullnames `mname'
    foreach token of local bad {
        assert !strpos(" `names' ", " `token' ")
    }
    if rowsof(`mname') == colsof(`mname') {
        local rnames : rowfullnames `mname'
        foreach token of local bad {
            assert !strpos(" `rnames' ", " `token' ")
        }
    }
end

**# Synthetic non-EOFU longitudinal setup
clear
set seed 202605153
set obs 360
gen long id = ceil(_n / 3)
bysort id: gen byte time = _n
gen double c = rnormal()
bysort id (time): replace c = c[1]
gen byte a = rbinomial(1, invlogit(-0.20 + 0.40 * c))
gen double l = 0.30 * c + 0.25 * a + rnormal(0, 0.40)
gen byte d = 0
replace d = rbinomial(1, invlogit(-1.00 + 0.10 * c)) if time == 3
gen byte y = rbinomial(1, invlogit(-2.00 + 0.45 * a + 0.25 * l + 0.15 * c))
tempfile s3_data
save `s3_data'

**# S3: omitted MSM terms are dropped before posting e() matrices
local ++test_count
capture noisily {
    use `s3_data', clear
    gcomp y d l a c id time, outcome(y) ///
        idvar(id) tvar(time) ///
        varyingcovariates(l) fixedcovariates(c) ///
        intvars(a) interventions(a=1, a=0) ///
        death(d) ///
        commands(d: logit, l: regress, a: logit, y: logit) ///
        equations(d: c, l: c, a: c l, y: a c) ///
        pooled msm(logit y i.a##i.a) ///
        sim(120) samples(6) seed(202605153)

    assert "`e(cmd)'" == "gcomp"
    assert "`e(analysis_type)'" == "time_varying"
    assert "`e(msm)'" == "logit y i.a##i.a"

    tempname b se V ci
    matrix `b' = e(b)
    matrix `se' = e(se)
    matrix `V' = e(V)
    matrix `ci' = e(ci_normal)

    local expected "y:1.a y:_cons PO1 PO2 PO3 out1 death1 out2 death2 out3 death3"
    local bcols : colfullnames `b'
    local secols : colfullnames `se'
    local Vcols : colfullnames `V'
    local Vrows : rowfullnames `V'
    local cicols : colfullnames `ci'

    assert "`bcols'" == "`expected'"
    assert "`secols'" == "`expected'"
    assert "`Vcols'" == "`expected'"
    assert "`Vrows'" == "`expected'"
    assert "`cicols'" == "`expected'"

    assert rowsof(`b') == 1
    assert colsof(`b') == 11
    assert rowsof(`se') == 1
    assert colsof(`se') == 11
    assert rowsof(`V') == 11
    assert colsof(`V') == 11
    assert rowsof(`ci') == 2
    assert colsof(`ci') == 11

    _s3_name_absent `b', bad("1.a#1.a o. 0b. 1o. a_")
    _s3_name_absent `se', bad("1.a#1.a o. 0b. 1o. a_")
    _s3_name_absent `V', bad("1.a#1.a o. 0b. 1o. a_")
    _s3_name_absent `ci', bad("1.a#1.a o. 0b. 1o. a_")

    assert colnumb(`b', "1.a") < .
    assert colnumb(`b', "_cons") < .
    assert colnumb(`b', "PO1") < .
    assert colnumb(`b', "death3") < .

    forvalues j = 1/11 {
        assert `se'[1,`j'] >= 0
        assert reldif(sqrt(`V'[`j',`j']), `se'[1,`j']) < 1e-10
        assert `ci'[1,`j'] <= `ci'[2,`j']
    }
}
if _rc == 0 {
    display as result "  PASS: S3 omitted MSM terms do not leak into posted e() matrices"
    local ++pass_count
}
else {
    display as error "  FAIL: S3 omitted MSM e() matrix contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' S3"
}

display ""
display as result "test_refactor_msm_omitted Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display "RESULT: test_refactor_msm_omitted tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    display as error "FAIL"
}
else {
    display "RESULT: test_refactor_msm_omitted tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
    display as result "PASS"
}

if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 1
}
