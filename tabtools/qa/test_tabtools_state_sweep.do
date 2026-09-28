* test_tabtools_state_sweep.do
* Session-fingerprint sweep: every public tabtools command, on a success path
* and an early-error path, leaves what the caller owns exactly as it found it
* (DOTHIS 2026-09-28 Part 3.2, step 7). _qa_state.do fingerprints e() (with a
* predict round trip on the caller's active model), matrices, scalars,
* globals, settings (varabbrev planted on), RNG state, data and sort order,
* value labels, _dta[] characteristics, frames and the working directory.
* budget: 30
*
* Planted before every call: a foreign active regress in e(), a user matrix
* T and scalar table (names the commands' own r(table) work could collide
* with), a user global, and varabbrev on. allow() exempts r(), which every
* command except tabtools_tips documents as rclass output, and globals, which
* _ttss_gcheck then restricts to Stata's own S_# saved results; frame(),
* xlsx() and csv() sinks are not requested, so no frame or file may appear.
* Error paths snapshot without r(): an rclass command owns r().
*
* Historical defect this would have caught: tabtools F07 (desctab replaced
* the caller's active estimates with an internal anova/regress).
*
* Run from tabtools/qa:  stata-mp -b do test_tabtools_state_sweep.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _ttss
log using "test_tabtools_state_sweep.log", replace text name(_ttss)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear
do "`qa_dir'/_qa_state.do"

local test_count = 0
local pass_count = 0
local failed ""
tempfile scratch
global TTSS_DIR "`scratch'_d"
capture mkdir "$TTSS_DIR"

* A foreign model, user objects and a non-default setting the commands must
* leave alone. Needs price and mpg in memory.
* Globals: the success paths allow the global category only so that this
* check can name the exact set. Official commands the tables call (cs,
* spearman, sts test, ...) overwrite Stata's legacy saved-result globals S_#
* (and ereturn post clears S_E_*); any other global that changes is a
* violation.
capture mata: mata drop _ttss_globals() _ttss_gdiff()
mata:
string matrix _ttss_globals()
{
    string colvector n
    string matrix G
    real scalar i
    n = st_dir("global", "macro", "*")
    G = J(rows(n), 2, "")
    for (i = 1; i <= rows(n); i++) G[i, .] = (n[i], st_global(n[i]))
    return(G)
}
real scalar _ttss_exempt(string scalar nm)
{
    return(regexm(nm, "^S_[0-9]+$") | substr(nm, 1, 4) == "S_E_")
}
string scalar _ttss_gdiff(string matrix A, string matrix B)
{
    string scalar out, nm
    real scalar i, j, hit
    out = ""
    for (i = 1; i <= rows(A); i++) {
        nm = A[i, 1]
        if (_ttss_exempt(nm)) continue
        hit = 0
        for (j = 1; j <= rows(B); j++) if (B[j, 1] == nm) hit = (B[j, 2] == A[i, 2]) + 1
        if (hit != 2) out = out + " " + nm
    }
    for (j = 1; j <= rows(B); j++) {
        nm = B[j, 1]
        if (!_ttss_exempt(nm) & !anyof(A[., 1], nm)) out = out + " +" + nm
    }
    return(out)
}
end
capture program drop _ttss_gcheck
program define _ttss_gcheck
    version 17.0
    mata: st_local("gd", _ttss_gdiff(_ttss_g0, _ttss_globals()))
    if `"`gd'"' != "" {
        display as error "globals outside S_# changed:`gd'"
        exit 9
    }
end

capture program drop _ttss_plant
program define _ttss_plant
    version 17.0
    quietly regress price mpg
    matrix T = (1, 2 \ 3, 4)
    matrix rownames T = r1 r2
    scalar table = 7
    global TTSS_USER "user value"
    set varabbrev on
end

capture program drop _ttss_auto
program define _ttss_auto
    version 17.0
    sysuse auto, clear
    gen byte expensive = price > 6000
end

* Survival data: 60 subjects, two groups, continuous times.
capture program drop _ttss_surv
program define _ttss_surv
    version 17.0
    _ttss_auto
    set seed 20260928
    gen double time = 1 + 20*runiform()
    gen byte died = runiform() < .6
    quietly stset time, failure(died)
end

* Two strate-style rate files for stratetab/hrcomptab.
capture program drop _ttss_rates
program define _ttss_rates
    version 17.0
    forvalues k = 1/2 {
        clear
        quietly set obs 2
        gen exposure = _n - 1
        gen double _D = cond(_n == 1, 10, 20) + `k'
        gen double _Y = cond(_n == 1, 1000, 1100)
        gen double _Rate = _D / _Y
        gen double _Lower = _Rate * .8
        gen double _Upper = _Rate * 1.2
        label variable _Lower "Lower 95% confidence limit"
        label variable _Upper "Upper 95% confidence limit"
        label define _ttss_e 0 "None" 1 "Current", replace
        label values exposure _ttss_e
        quietly save "$TTSS_DIR/rate`k'.dta", replace
    }
end

capture program drop _ttss_result
program define _ttss_result, rclass
    args rc label
    if `rc' == 0 display as result "  PASS: `label'"
    else display as error "  FAIL: `label' (rc=`rc')"
    return scalar pass = (`rc' == 0)
end

**# corrtab
local ++test_count
capture noisily {
    _ttss_auto
    _ttss_plant
    qa_state_snapshot, tag(corr_ok) predict(xb)
    mata: _ttss_g0 = _ttss_globals()
    corrtab price mpg weight
    qa_state_compare, tag(corr_ok) allow(r global)
    _ttss_gcheck
    _ttss_plant
    qa_state_snapshot, tag(corr_bad) predict(xb)
    capture corrtab price
    assert _rc == 102
    qa_state_compare, tag(corr_bad)
}
_ttss_result `=_rc' "corrtab leaves caller state intact (success + r(102))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' corrtab"

**# crosstab
local ++test_count
capture noisily {
    _ttss_auto
    _ttss_plant
    qa_state_snapshot, tag(cross_ok) predict(xb)
    mata: _ttss_g0 = _ttss_globals()
    crosstab expensive foreign, or rr trend label
    qa_state_compare, tag(cross_ok) allow(r global)
    _ttss_gcheck
    _ttss_plant
    qa_state_snapshot, tag(cross_bad) predict(xb)
    capture crosstab expensive foreign, nosuchoption
    assert _rc == 198
    qa_state_compare, tag(cross_bad)
}
_ttss_result `=_rc' "crosstab leaves caller state intact (success + r(198))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' crosstab"

**# desctab (F07: the internal anova/regress must not replace e())
local ++test_count
capture noisily {
    _ttss_auto
    _ttss_plant
    qa_state_snapshot, tag(desc_ok) predict(xb)
    mata: _ttss_g0 = _ttss_globals()
    desctab, by(foreign) vars(mpg contn \ weight conts \ rep78 cat) test
    qa_state_compare, tag(desc_ok) allow(r global)
    _ttss_gcheck
    _ttss_plant
    qa_state_snapshot, tag(desc_bad) predict(xb)
    capture desctab, by(nosuchvar) vars(mpg contn)
    assert _rc == 111
    qa_state_compare, tag(desc_bad)
}
_ttss_result `=_rc' "desctab leaves caller state intact incl. active e() (success + r(111))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' desctab"

**# table1_tc (the desctab front end)
local ++test_count
capture noisily {
    _ttss_auto
    _ttss_plant
    qa_state_snapshot, tag(t1_ok) predict(xb)
    mata: _ttss_g0 = _ttss_globals()
    table1_tc, by(foreign) vars(mpg contn \ rep78 cat) test
    qa_state_compare, tag(t1_ok) allow(r global)
    _ttss_gcheck
    _ttss_plant
    qa_state_snapshot, tag(t1_bad) predict(xb)
    capture table1_tc, by(nosuchvar) vars(mpg contn)
    assert _rc == 111
    qa_state_compare, tag(t1_bad)
}
_ttss_result `=_rc' "table1_tc leaves caller state intact incl. active e() (success + r(111))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' table1_tc"

**# survtab
local ++test_count
capture noisily {
    _ttss_surv
    _ttss_plant
    qa_state_snapshot, tag(surv_ok) predict(xb)
    mata: _ttss_g0 = _ttss_globals()
    survtab, times(5 10) by(foreign) rmst(10) median events
    qa_state_compare, tag(surv_ok) allow(r global)
    _ttss_gcheck
    _ttss_plant
    qa_state_snapshot, tag(surv_bad) predict(xb)
    capture survtab, times(-1)
    assert _rc == 125
    qa_state_compare, tag(surv_bad)
}
_ttss_result `=_rc' "survtab leaves caller state intact (success + r(125))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' survtab"

**# regtab
local ++test_count
capture noisily {
    _ttss_auto
    collect clear
    quietly collect: regress price mpg weight
    _ttss_plant
    qa_state_snapshot, tag(reg_ok) predict(xb)
    mata: _ttss_g0 = _ttss_globals()
    regtab, noint
    qa_state_compare, tag(reg_ok) allow(r global)
    _ttss_gcheck
    _ttss_plant
    qa_state_snapshot, tag(reg_bad) predict(xb)
    capture regtab, nosuchoption
    assert _rc == 198
    qa_state_compare, tag(reg_bad)
}
_ttss_result `=_rc' "regtab leaves caller state intact (success + r(198))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' regtab"

**# effecttab
local ++test_count
capture noisily {
    clear
    set seed 83920
    quietly set obs 200
    gen double x = rnormal()
    gen byte t = mod(_n, 2)
    gen double y = 2*x + 5*t + rnormal()
    collect clear
    quietly collect: teffects ra (y x) (t)
    gen double price = y
    gen double mpg = x
    _ttss_plant
    qa_state_snapshot, tag(eff_ok) predict(xb)
    mata: _ttss_g0 = _ttss_globals()
    effecttab
    qa_state_compare, tag(eff_ok) allow(r global)
    _ttss_gcheck
    _ttss_plant
    qa_state_snapshot, tag(eff_bad) predict(xb)
    capture effecttab, nosuchoption
    assert _rc == 198
    qa_state_compare, tag(eff_bad)
}
_ttss_result `=_rc' "effecttab leaves caller state intact (success + r(198))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' effecttab"

**# comptab
local ++test_count
capture noisily {
    _ttss_auto
    collect clear
    quietly collect: regress price mpg
    quietly regtab, frame(ttss_m1, replace) noint
    collect clear
    quietly collect: regress price mpg weight
    quietly regtab, frame(ttss_m2, replace) noint
    _ttss_plant
    qa_state_snapshot, tag(comp_ok) predict(xb)
    mata: _ttss_g0 = _ttss_globals()
    comptab ttss_m1 ttss_m2, rows(1 \ 1)
    qa_state_compare, tag(comp_ok) allow(r global)
    _ttss_gcheck
    _ttss_plant
    qa_state_snapshot, tag(comp_bad) predict(xb)
    capture comptab ttss_m1 nosuchframe, rows(1 \ 1)
    assert _rc == 111
    qa_state_compare, tag(comp_bad)
}
_ttss_result `=_rc' "comptab leaves caller state intact (success + r(111))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' comptab"

**# stratetab
local ++test_count
capture noisily {
    _ttss_rates
    _ttss_auto
    _ttss_plant
    qa_state_snapshot, tag(strate_ok) predict(xb)
    mata: _ttss_g0 = _ttss_globals()
    stratetab, using("$TTSS_DIR/rate1" "$TTSS_DIR/rate2") outcomes(2)
    qa_state_compare, tag(strate_ok) allow(r global)
    _ttss_gcheck
    _ttss_plant
    qa_state_snapshot, tag(strate_bad) predict(xb)
    capture stratetab, using("$TTSS_DIR/nosuchrate") outcomes(1)
    assert _rc == 601
    qa_state_compare, tag(strate_bad)
}
_ttss_result `=_rc' "stratetab leaves caller state intact (success + r(601))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' stratetab"

**# hrcomptab
local ++test_count
capture noisily {
    _ttss_rates
    clear
    quietly stratetab, using("$TTSS_DIR/rate1" "$TTSS_DIR/rate2") outcomes(2) ///
        frame(ttss_rates, replace) outlabels("Outcome 1" \ "Outcome 2") ///
        explabels("Exposure")
    clear
    set seed 20260417
    quietly set obs 240
    gen byte exposure = mod(_n, 2)
    label define _ttss_e2 0 "None" 1 "Current", replace
    label values exposure _ttss_e2
    gen double t1 = 1 + 12*runiform()*exp(-.35*exposure)
    gen byte d1 = mod(_n, 4) != 0
    gen double t2 = 1 + 10*runiform()*exp(-.2*exposure)
    gen byte d2 = mod(_n, 5) != 0
    collect clear
    quietly stset t1, failure(d1)
    quietly collect: stcox exposure, nolog
    quietly stset t2, failure(d2)
    quietly collect: stcox exposure, nolog
    quietly regtab, models("Outcome 1" \ "Outcome 2") frame(ttss_hr, replace) noint
    gen double price = t1
    gen double mpg = t2
    _ttss_plant
    qa_state_snapshot, tag(hr_ok) predict(xb)
    mata: _ttss_g0 = _ttss_globals()
    hrcomptab ttss_rates, modelframes(ttss_hr) rows(1) ///
        outcomemap("Outcome 1" \ "Outcome 2") effect("HR")
    qa_state_compare, tag(hr_ok) allow(r global)
    _ttss_gcheck
    _ttss_plant
    qa_state_snapshot, tag(hr_bad) predict(xb)
    capture hrcomptab ttss_rates, modelframes(nosuchframe) rows(1)
    assert _rc == 111
    qa_state_compare, tag(hr_bad)
}
_ttss_result `=_rc' "hrcomptab leaves caller state intact (success + r(111))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' hrcomptab"

**# puttab
local ++test_count
capture noisily {
    _ttss_auto
    _ttss_plant
    qa_state_snapshot, tag(put_ok) predict(xb)
    mata: _ttss_g0 = _ttss_globals()
    puttab make price mpg in 1/5 using "$TTSS_DIR/put.xlsx", sheet("S") title("Top")
    qa_state_compare, tag(put_ok) allow(r global)
    _ttss_gcheck
    _ttss_plant
    qa_state_snapshot, tag(put_bad) predict(xb)
    capture puttab make price using "$TTSS_DIR/put.xlsx", nosuchoption
    assert _rc == 198
    qa_state_compare, tag(put_bad)
}
_ttss_result `=_rc' "puttab leaves caller state intact (success + r(198))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' puttab"

**# stacktab
local ++test_count
capture noisily {
    _ttss_auto
    matrix MA = (1.23, 1.05, 1.44)
    matrix colnames MA = HR LL UL
    quietly puttab using "$TTSS_DIR/parts.xlsx", sheet("A") matrix(MA) title("Model A")
    quietly puttab using "$TTSS_DIR/parts.xlsx", sheet("B") matrix(MA) title("Model B")
    matrix drop MA
    _ttss_plant
    qa_state_snapshot, tag(stack_ok) predict(xb)
    mata: _ttss_g0 = _ttss_globals()
    stacktab using "$TTSS_DIR/parts.xlsx", sheet("T2") blocks(sheet(A) \ sheet(B))
    qa_state_compare, tag(stack_ok) allow(r global)
    _ttss_gcheck
    _ttss_plant
    qa_state_snapshot, tag(stack_bad) predict(xb)
    capture stacktab using "$TTSS_DIR/parts.xlsx", sheet("T3") blocks(sheet(A)) style(nosuchgroup)
    assert _rc == 198
    qa_state_compare, tag(stack_bad)
}
_ttss_result `=_rc' "stacktab leaves caller state intact (success + r(198))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' stacktab"

**# tabtools (read-only query)
local ++test_count
capture noisily {
    _ttss_auto
    _ttss_plant
    qa_state_snapshot, tag(tt_ok) predict(xb)
    mata: _ttss_g0 = _ttss_globals()
    tabtools get
    qa_state_compare, tag(tt_ok) allow(r global)
    _ttss_gcheck
    _ttss_plant
    qa_state_snapshot, tag(tt_bad) predict(xb)
    capture tabtools set nosuchsetting 3
    assert _rc == 198
    qa_state_compare, tag(tt_bad)
}
_ttss_result `=_rc' "tabtools get/set error leave caller state intact (success + r(198))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' tabtools"

**# tabtools_tips
local ++test_count
capture noisily {
    _ttss_auto
    _ttss_plant
    qa_state_snapshot, tag(tips_ok) predict(xb) rreturn
    tabtools_tips
    qa_state_compare, tag(tips_ok)
    _ttss_plant
    qa_state_snapshot, tag(tips_bad) predict(xb) rreturn
    capture tabtools_tips, nosuchoption
    assert _rc == 198
    qa_state_compare, tag(tips_bad)
}
_ttss_result `=_rc' "tabtools_tips leaves caller state intact incl. r() (success + r(198))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' tabtools_tips"

**# Summary
set varabbrev off
capture shell rm -rf "$TTSS_DIR"
capture matrix drop T
capture scalar drop table
capture frame drop ttss_m1
capture frame drop ttss_m2
capture frame drop ttss_rates
capture frame drop ttss_hr
macro drop TTSS_DIR TTSS_USER
local fail_count = `test_count' - `pass_count'
if `fail_count' display as error "failed:`failed'"
display as text "fingerprint sweep: `pass_count'/`test_count' commands x 2 paths"
display as text "RESULT: test_tabtools_state_sweep tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _ttss
if `fail_count' > 0 exit 1
exit 0
