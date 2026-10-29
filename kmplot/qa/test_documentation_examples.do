* test_documentation_examples.do
* Every example in the kmplot.sthlp {title:Examples} section, run verbatim for
* an installed user, in help-file order, with an assertion on its result.
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-29
*
* This is the suite the release gate `runnable_examples' probes.  The other
* suites call kmplot their own way; a documented invocation that stops parsing
* (a renamed option, a dropped default, a block that depends on data the block
* above it did not leave) is invisible to them.
*
* Each block is copied AS PRINTED.  If a block needs changing, change the help
* file first, then mirror it here.  Blocks share state exactly as a reader
* working down the page would have it.
*
* Oracles are independent of kmplot: medians and fixed-time estimates come from
* -sts generate-, the log-rank p-value from -sts test-, at-risk counts from a
* direct count of the stset sample, and the Aalen-Johansen landmark from a
* hand-built cumulative incidence over the distinct event times.
*
* EX10 and EX11 run -webuse hypoxia- and -webuse diet-, which need network
* access to www.stata-press.com.
*
* Run from kmplot/qa:  stata-mp -b do test_documentation_examples.do

clear all
version 16.0
set varabbrev off
local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

* export() and risksaving() in the examples write into the working directory;
* run them in a scratch directory and return afterwards.
local work "`c(tmpdir)'/kmplot_docex_`=c(current_time)'"
local work = subinstr("`work'", ":", "", .)
capture mkdir "`work'"
quietly cd "`work'"

* Hand-built Aalen-Johansen cumulative incidence at time `at' of the first
* indicator in varlist, with the second competing, on the `if' sample, over the distinct event times of the data in memory.  Works on
* the stored _t values, so float times are compared exactly.
capture program drop _kmdoc_aj_oracle
program define _kmdoc_aj_oracle, rclass
    version 16.0
    syntax varlist(min=2 max=2 numeric) if, at(real)
    marksample touse
    tempname F
    mata: st_numscalar("`F'", _kmdoc_aj(st_data(., "_t _t0 `varlist'", "`touse'"), `at'))
    return scalar F = `F'
end
mata:
real scalar _kmdoc_aj(real matrix X, real scalar at)
{
    real colvector t, t0, e1, e2, times
    real scalar S, F, j, tj, n, d1, d2
    t = X[., 1]; t0 = X[., 2]; e1 = X[., 3]; e2 = X[., 4]
    times = uniqrows(select(t, (e1 :| e2)))
    S = 1
    F = 0
    for (j = 1; j <= rows(times); j++) {
        tj = times[j]
        if (tj > at) break
        n  = sum((t :>= tj) :& (t0 :< tj))
        d1 = sum((t :== tj) :& e1)
        d2 = sum((t :== tj) :& e2)
        F  = F + S * d1 / n
        S  = S * (1 - (d1 + d2) / n)
    }
    return(F)
}
end

local test_count = 0
local pass_count = 0
local fail_count = 0

* Setup (help-file block 1)
sysuse cancer, clear
stset studytime, failure(died)

* Oracle: KM survival by drug, from sts generate.  The group column of the
* returned matrices is the display position; drug's levels 1, 2, 3 coincide
* with it, which EX3 checks through r(group_labels).
tempvar s_oracle
quietly sts generate `s_oracle' = s, by(drug)

**# EX1 Basic KM curve
local ++test_count
capture noisily {
    kmplot
    assert r(N) == 48
    assert r(n_groups) == 1
    assert "`r(cmd)'" == "kmplot"
    assert "`r(plot_type)'" == "survival"
    assert "`r(estimator)'" == "km"
    assert "`r(graph_name)'" == "kmplot"
    quietly graph describe kmplot
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: EX1 basic KM curve"
}
else {
    local ++fail_count
    display as error "FAIL: EX1 basic KM curve (rc=" _rc ")"
}

**# EX2 KM curves by treatment group
local ++test_count
capture noisily {
    kmplot, by(drug)
    assert r(N) == 48
    assert r(n_groups) == 3
    assert "`r(by)'" == "drug"
    assert "`r(plot_type)'" == "survival"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: EX2 by(drug)"
}
else {
    local ++fail_count
    display as error "FAIL: EX2 by(drug) (rc=" _rc ")"
}

**# EX3 With CI bands and median lines
* Medians equal the first time each group's sts-generate survival is <= 0.5.
local ++test_count
capture noisily {
    kmplot, by(drug) ci median medianannotate
    assert r(ci) == 1
    assert r(n_groups) == 3
    tempname med
    matrix `med' = r(medians)
    assert rowsof(`med') == 3
    assert "`r(group_labels)'" == "Placebo | Other | NA"
    forvalues g = 1/3 {
        local km_med`g' = r(median_`g')
    }
    forvalues g = 1/3 {
        quietly summarize _t if drug == `g' & `s_oracle' <= 0.5, meanonly
        local oracle = r(min)
        assert !missing(`oracle')
        assert reldif(`km_med`g'', `oracle') < 1e-9
        assert `med'[`g', 1] == `g'
        assert reldif(`med'[`g', 2], `oracle') < 1e-9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: EX3 ci median medianannotate"
}
else {
    local ++fail_count
    display as error "FAIL: EX3 ci median medianannotate (rc=" _rc ")"
}

**# EX4 Cumulative failure with risk table
* At-risk counts equal a direct count: _t >= t and (_t0 < t, or t == 0).
local ++test_count
capture noisily {
    kmplot, by(drug) failure risktable
    assert r(failure) == 1
    assert "`r(plot_type)'" == "failure"
    assert "`r(estimator)'" == "km_failure"
    assert r(n_timepoints) >= 2
    tempname rt
    matrix `rt' = r(risktable)
    assert rowsof(`rt') == 3 * r(n_timepoints)
    local checked 0
    forvalues i = 1/`=rowsof(`rt')' {
        local g = `rt'[`i', 1]
        local t = `rt'[`i', 2]
        if `t' == 0 quietly count if drug == `g' & _st == 1 & _t >= 0
        else quietly count if drug == `g' & _st == 1 & _t >= `t' & _t0 < `t'
        assert `rt'[`i', 3] == r(N)
        local ++checked
    }
    assert `checked' == rowsof(`rt')
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: EX4 failure risktable"
}
else {
    local ++fail_count
    display as error "FAIL: EX4 failure risktable (rc=" _rc ")"
}

**# EX5 Full publication example
* r(p) equals the sts test log-rank p-value.
local ++test_count
capture noisily {
    quietly sts test drug
    local oracle_p = chi2tail(r(df), r(chi2))
    kmplot, by(drug) ci risktable median medianannotate pvalue censor
    assert reldif(r(p), `oracle_p') < 1e-9
    assert r(ci) == 1
    assert !missing(r(riskheight))
    confirm matrix r(risktable)
    confirm matrix r(medians)
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: EX5 publication example"
}
else {
    local ++fail_count
    display as error "FAIL: EX5 publication example (rc=" _rc ")"
}

**# EX6 Custom styling
local ++test_count
capture noisily {
    kmplot, by(drug) ci colors(navy red) lpattern(solid dash)
    assert strpos("`r(colors)'", "navy") == 1
    assert strpos("`r(colors)'", "red") > 0
    assert "`r(lpattern)'" == "solid dash"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: EX6 custom styling"
}
else {
    local ++fail_count
    display as error "FAIL: EX6 custom styling (rc=" _rc ")"
}

**# EX7 Export to PDF
local ++test_count
capture noisily {
    capture erase km_figure.pdf
    kmplot, by(drug) ci median export(km_figure.pdf, replace)
    assert strpos("`r(export)'", "km_figure.pdf") > 0
    confirm file km_figure.pdf
    checksum km_figure.pdf
    assert r(filelen) > 1000
    erase km_figure.pdf
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: EX7 export PDF"
}
else {
    local ++fail_count
    display as error "FAIL: EX7 export PDF (rc=" _rc ")"
}

**# EX8 Fixed-time estimates and saved table data
* Landmark estimates equal sts-generate survival at the last _t <= 12 and 24.
local ++test_count
capture noisily {
    capture erase risk.dta
    kmplot, by(drug) ci risktable landmark(12 24) risksaving(risk.dta, replace)
    matrix list r(landmarks)
    matrix list r(risktable)
    assert r(n_landmarks) == 2
    tempname lm rt8
    matrix `lm' = r(landmarks)
    matrix `rt8' = r(risktable)
    assert rowsof(`lm') == 6
    forvalues i = 1/6 {
        local g = `lm'[`i', 1]
        local t = `lm'[`i', 2]
        quietly summarize _t if drug == `g' & _t <= `t', meanonly
        local tlast = r(max)
        quietly summarize `s_oracle' if drug == `g' & _t == `tlast', meanonly
        assert reldif(`lm'[`i', 3], r(mean)) < 1e-9
        * a curve that has reached 0 has no confidence limits
        if `lm'[`i', 3] > 0 {
            assert `lm'[`i', 4] <= `lm'[`i', 3] & `lm'[`i', 3] <= `lm'[`i', 5]
        }
        else {
            assert missing(`lm'[`i', 4]) & missing(`lm'[`i', 5])
        }
    }
    * Drug 1 reaches 0 before t = 24, so the else branch above is exercised.
    assert `lm'[2, 3] == 0
    * The saved risk table holds the same at-risk counts as r(risktable).
    confirm file risk.dta
    capture frame drop _kmdoc_risk
    frame create _kmdoc_risk
    frame _kmdoc_risk {
        use risk.dta, clear
        assert _N == rowsof(`rt8')
        forvalues i = 1/`=_N' {
            assert at_risk[`i'] == `rt8'[`i', 3]
        }
    }
    frame drop _kmdoc_risk
    erase risk.dta
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: EX8 landmark risksaving"
}
else {
    local ++fail_count
    display as error "FAIL: EX8 landmark risksaving (rc=" _rc ")"
}

**# EX9 Custom p-value text and coordinates
local ++test_count
capture noisily {
    quietly sts test drug
    local oracle_p = chi2tail(r(df), r(chi2))
    kmplot, by(drug) pvalue pvalueformat(%6.4f) pvaluetext("Log-rank P") pvalueat(.9 10)
    assert reldif(r(p), `oracle_p') < 1e-9
    assert "`r(pvalue_format)'" == "%6.4f"
    assert "`r(pvalue_label)'" == "Log-rank P"
    * p is below 0.001 on these data, which kmplot prints as "< 0.001"
    assert `oracle_p' < 0.001
    assert `"`r(pvalue_text)'"' == "Log-rank P < 0.001"
    assert "`r(pvalue_at)'" == ".9 10"
    assert reldif(r(pvalue_y), .9) < 1e-12
    assert reldif(r(pvalue_x), 10) < 1e-12
    assert "`r(pvalue_placement)'" == "c"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: EX9 p-value text and coordinates"
}
else {
    local ++fail_count
    display as error "FAIL: EX9 p-value text and coordinates (rc=" _rc ")"
}

**# EX10 Competing risks
* The landmark at t = 5 equals a hand-built Aalen-Johansen cumulative incidence
* (r(landmarks) stays in proportions under percent), and each at-risk cell
* equals a direct count, printed as missing exactly when that count is 1 to 4.
local ++test_count
capture noisily {
    webuse hypoxia, clear
    stset dftime, failure(failtype == 1)
    kmplot, by(pelnode) byorder(1 0) compete(failtype == 2) ci percent risktable riskmask(5) tmax(8) landmark(5)
    matrix list r(landmarks)
    assert "`r(estimator)'" == "aalen_johansen"
    assert "`r(plot_type)'" == "failure"
    assert "`r(scale)'" == "percent"
    assert "`r(compete)'" == "failtype == 2"
    assert r(riskmask) == 5
    assert r(tmax) == 8
    tempname lm10 rt10
    matrix `lm10' = r(landmarks)
    matrix `rt10' = r(risktable)
    assert rowsof(`lm10') == 2
    * The group column is the display position: byorder(1 0) puts pelnode 1
    * first.
    assert "`r(group_labels)'" == "pelnode=1 | pelnode=0"
    local n_masked 0
    forvalues i = 1/`=rowsof(`rt10')' {
        local gval = cond(`rt10'[`i', 1] == 1, 1, 0)
        local t = `rt10'[`i', 2]
        if `t' == 0 quietly count if pelnode == `gval' & _st == 1 & _t >= 0
        else quietly count if pelnode == `gval' & _st == 1 & _t >= `t' & _t0 < `t'
        if inrange(r(N), 1, 4) {
            assert missing(`rt10'[`i', 3])
            local ++n_masked
        }
        else {
            assert `rt10'[`i', 3] == r(N)
        }
        forvalues j = 4/5 {
            local v = `rt10'[`i', `j']
            assert missing(`v') | `v' == 0 | `v' >= 5
        }
    }
    assert `n_masked' >= 1
    tempvar ev1 ev2
    quietly generate byte `ev1' = _d == 1
    quietly generate byte `ev2' = _d == 0 & failtype == 2
    forvalues i = 1/2 {
        local g = `lm10'[`i', 1]
        local t = `lm10'[`i', 2]
        assert `g' == `i'
        assert `t' == 5
        local gval = cond(`g' == 1, 1, 0)
        _kmdoc_aj_oracle `ev1' `ev2' if _st == 1 & pelnode == `gval', at(`t')
        local F = r(F)
        assert `F' > 0
        assert reldif(`lm10'[`i', 3], `F') < 1e-9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: EX10 competing risks"
}
else {
    local ++fail_count
    display as error "FAIL: EX10 competing risks (rc=" _rc ")"
}

**# EX11 Delayed entry on the age time scale
* At-risk counts at ages 40 50 60 70 equal subjects with _t0 < t <= _t.
local ++test_count
capture noisily {
    webuse diet, clear
    stset dox, failure(fail) origin(time dob) enter(time doe) scale(365.25) id(id)
    kmplot, by(hienergy) risktable timepoints(40 50 60 70) xtitle("Age (years)")
    assert "`r(timepoints)'" == "40 50 60 70"
    assert "`r(xtitle)'" == "Age (years)"
    assert r(n_groups) == 2
    tempname rt11
    matrix `rt11' = r(risktable)
    assert rowsof(`rt11') == 8
    * The group column is the display position: 1 = hienergy 0, 2 = hienergy 1.
    assert "`r(group_labels)'" == "hienergy=0 | hienergy=1"
    local nonzero 0
    forvalues i = 1/8 {
        local g = `rt11'[`i', 1]
        local t = `rt11'[`i', 2]
        local gval = `g' - 1
        tempvar tag
        quietly egen byte `tag' = tag(id) if hienergy == `gval' & _st == 1 & _t >= `t' & _t0 < `t'
        quietly count if `tag' == 1
        assert `rt11'[`i', 3] == r(N)
        if r(N) > 0 local ++nonzero
        drop `tag'
    }
    assert `nonzero' >= 4
    * Delayed entry matters: at age 40 each group's count is below its size.
    forvalues i = 1(4)5 {
        local gval = `rt11'[`i', 1] - 1
        assert `rt11'[`i', 2] == 40
        quietly count if hienergy == `gval' & _st == 1
        assert `rt11'[`i', 3] < r(N)
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: EX11 delayed entry"
}
else {
    local ++fail_count
    display as error "FAIL: EX11 delayed entry (rc=" _rc ")"
}

quietly cd "`qa_dir'"
capture graph drop _all

**# Summary
display "RESULT: test_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    exit 1
}
