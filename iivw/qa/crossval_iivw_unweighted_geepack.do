clear all
set more off
version 16.0
set varabbrev off

* crossval_iivw_unweighted_geepack.do
* Tests: 4
*
* WHAT THIS COVERS
* ----------------
* Reference parity of `iivw_fit, unweighted' (glm + vce(cluster id), i.e. independence
* GEE with a cluster-robust sandwich) against R geepack::geeglm(corstr =
* "independence", std.err = "san.se") on IDENTICAL exported data.
*
* ORACLE: geepack (version recorded in crossval_iivw_unweighted_geepack_versions.csv
* and on the REFERENCE: line). Datasets come from the two DGPs of _iivw_unw_dgp.do:
* A (G = 300), B (G = 300), and B_small (G = 40, to make the finite-cluster factor
* matter). Families: gaussian/identity, binomial/logit (ybin = 1{y > mean}),
* poisson/log (ycnt = Poisson(exp(.2 + .2 x + .1 t))). Seeds: 20261201 (A), 20261202
* (B), 20261203 (B_small); the count/binary responses are drawn after, same stream.
*
* THE ONE CONVENTION DIFFERENCE (stated, exact, not a loosened tolerance)
* Stata's glm vce(cluster) scales the sandwich by G/(G-1) for G clusters; geeglm's
* san.se applies no small-sample factor. So the exact relation is
*     se_Stata = se_geeglm * sqrt(G/(G-1)).
* The suite asserts THAT relation to 1e-6 relative. Because the unrescaled gap at
* G = 40 is 1.27% (sqrt(40/39) - 1), T4 asserts the unrescaled comparison is NOT
* within 1e-4 at G = 40, so the rescaling cannot be hiding a real SE disagreement.
*
* TOLERANCES
*   coefficients: |b_Stata - b_R| < 1e-6 absolute. Same estimator; geeglm is run with
*     geese.control(epsilon = 1e-10) so its IRLS stopping rule (default 1e-5) does not
*     set the floor, and glm's ML tolerance is 1e-6 on the deviance.
*   SE: relative gap to the rescaled reference < 1e-6 (same sandwich formula, double
*     precision).
* Tests: T1 gaussian, T2 binomial-logit, T3 poisson-log (all three datasets each),
*   T4 rescaling is exact and non-vacuous.

args run_only
do "`c(pwd)'/_iivw_qa_common.do"
iivw_qa_selector "`run_only'"
local run_only = `r(run_only)'
local qa_dir "`c(pwd)'"
if substr("`qa_dir'", -3, 3) != "/qa" {
    display as error "crossval_iivw_unweighted_geepack.do must be run from iivw/qa"
    exit 198
}
iivw_qa_bootstrap
do "`qa_dir'/_iivw_unw_dgp.do"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# Reference generation (fresh dir, success sentinel, preflight)
local rscript "`qa_dir'/crossval_iivw_unweighted_geepack.R"
capture confirm file "`rscript'"
if _rc {
    display as error "missing R generator: `rscript'"
    exit 601
}
tempfile _stub
local work "`_stub'_cv"
capture mkdir "`work'"
local indir "`work'/in"
local outdir "`work'/out"
capture mkdir "`indir'"
capture mkdir "`outdir'"
capture confirm file "`outdir'"
if _rc {
    display as error "could not create scratch directories under `work'"
    exit 603
}
local rpre "`work'/.pre_ok"
shell Rscript -e "if (requireNamespace('geepack', quietly=TRUE)) quit(status=0) else quit(status=1)" > /dev/null 2>&1 && touch "`rpre'"
capture confirm file "`rpre'"
if _rc {
    display as error "R preflight failed: Rscript with package geepack is required"
    display as error `"  install.packages("geepack", repos="https://cloud.r-project.org")"'
    exit 198
}

* export the three datasets
local dsnames A B B_small
local seedA = 20261201
local seedB = 20261202
local seedBs = 20261203
foreach spec in "A A 300 `seedA'" "B B 300 `seedB'" "B_small B 40 `seedBs'" {
    tokenize `spec'
    local nm `1'
    local dgp `2'
    local n `3'
    local sd `4'
    set seed `sd'
    _unw_gen, dgp(`dgp') n(`n')
    quietly summarize y, meanonly
    gen byte ybin = y > r(mean)
    gen long ycnt = rpoisson(exp(.2 + .2*x + .1*t))
    quietly export delimited id t x y ybin ycnt using "`indir'/ds_`nm'.csv", replace
    tempfile d_`nm'
    quietly save "`d_`nm''"
}

local rok "`work'/.gen_ok"
capture erase "`rok'"
shell Rscript "`rscript'" --indir="`indir'" --outdir="`outdir'" --versions="`qa_dir'/crossval_iivw_unweighted_geepack_versions.csv" && touch "`rok'"
capture confirm file "`rok'"
if _rc {
    display as error "R reference generation did not complete (no success sentinel)"
    exit 198
}
foreach nm of local dsnames {
    capture confirm file "`outdir'/ref_`nm'.csv"
    if _rc {
        display as error "R did not write ref_`nm'.csv"
        exit 601
    }
}

* _cv_compare: fit iivw_fit unweighted with `fam' on dataset `nm'; compare to the
* reference. Posts nothing; returns max coefficient gap, max rescaled SE rel gap,
* and max UNrescaled SE rel gap. Every comparison guards against missing.
capture program drop _cv_compare
program define _cv_compare, rclass
    syntax , NAME(string) FAMILY(string) DSFILE(string) REFFILE(string)
    quietly use "`dsfile'", clear
    local resp = cond("`family'" == "gaussian", "y", cond("`family'" == "binomial", "ybin", "ycnt"))
    quietly iivw_fit `resp' x, unweighted id(id) time(t) timespec(linear) ///
        family(`family') nolog
    local sb_x = _b[x]
    local sb_t = _b[t]
    local sb_c = _b[_cons]
    local ss_x = _se[x]
    local ss_t = _se[t]
    local ss_c = _se[_cons]
    quietly import delimited "`reffile'", clear asdouble
    quietly keep if family == "`family'"
    local G = g[1]
    local f = sqrt(`G' / (`G' - 1))
    local maxb = 0
    local maxse = 0
    local maxraw = 0
    foreach pair in "x x" "t t" "(Intercept) c" {
        tokenize `pair'
        quietly summarize est if term == "`1'", meanonly
        local rb = r(mean)
        quietly summarize se_san if term == "`1'", meanonly
        local rs = r(mean)
        if missing(`rb', `rs', `sb_`2'', `ss_`2'') {
            return scalar maxb = .
            exit
        }
        local maxb = max(`maxb', abs(`sb_`2'' - `rb'))
        local maxse = max(`maxse', abs(`ss_`2'' - `rs' * `f') / `ss_`2'')
        local maxraw = max(`maxraw', abs(`ss_`2'' - `rs') / `ss_`2'')
    }
    return scalar maxb = `maxb'
    return scalar maxse = `maxse'
    return scalar maxraw = `maxraw'
    return scalar G = `G'
end

local ntest = 0
foreach fam in gaussian binomial poisson {
    local ++ntest
    local ++test_count
    if `run_only' == 0 | `run_only' == `ntest' {
        capture noisily {
            foreach nm of local dsnames {
                _cv_compare, name(`nm') family(`fam') dsfile("`d_`nm''") reffile("`outdir'/ref_`nm'.csv")
                display as text "  `fam' `nm' (G=" r(G) "): max|b diff| " %11.3e r(maxb) "  max SE rel gap (rescaled) " %11.3e r(maxse) "  (unrescaled " %9.5f r(maxraw) ")"
                assert r(maxb) < .
                assert r(maxb) < 1e-6
                assert r(maxse) < .
                assert r(maxse) < 1e-6
            }
        }
        if _rc == 0 {
            display as result "  PASS: T`ntest' `fam' coefficients and rescaled robust SE match geeglm"
            local ++pass_count
        }
        else {
            display as error "  FAIL: T`ntest' `fam' parity"
            local ++fail_count
            local failed_tests "`failed_tests' T`ntest'"
        }
    }
}

**# T4: the G/(G-1) rescaling is exact and non-vacuous
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        _cv_compare, name(B_small) family(gaussian) dsfile("`d_B_small'") reffile("`outdir'/ref_B_small.csv")
        local G = r(G)
        assert `G' == 40
        local expect = 1 - 1 / sqrt(`G' / (`G' - 1))
        * the unrescaled gap at G=40 must be the finite-cluster factor itself, ~1.27% / 1.0127
        display as text "  unrescaled max SE rel gap " %9.6f r(maxraw) "  expected 1 - 1/sqrt(G/(G-1)) = " %9.6f `expect'
        assert r(maxraw) < .
        assert abs(r(maxraw) - `expect') < 1e-6
        assert r(maxraw) > 1e-4
    }
    if _rc == 0 {
        display as result "  PASS: T4 unrescaled gap equals the G/(G-1) factor exactly (rescaling is not hiding a disagreement)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T4 rescaling check"
        local ++fail_count
        local failed_tests "`failed_tests' T4"
    }
}

**# Summary
iivw_qa_summary, name(crossval_iivw_unweighted_geepack) tests(`test_count') pass(`pass_count') fail(`fail_count') runonly(`run_only') failedtests(`failed_tests')
