* test_comptab_v230_review.do - review regressions: comptab keyed exact-or-error,
* and the 2.3.0 stratetab/ratetab paths under set dp comma, tabtools 2.3.0
* Oracles: the rate frame's own category rows, -ln(alpha/2)/Y by hand, and the
* same call under set dp period.

clear all
set more off
set varabbrev off
version 17.0

capture log close _ctr
log using "test_comptab_v230_review.log", replace text name(_ctr)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear
global TABTOOLS_set_smallcells

local pass_count = 0
local fail_count = 0

capture program drop _ctr_surv
program define _ctr_surv
    version 17.0
    sysuse cancer, clear
    gen byte agegrp = cond(age < 55, 1, cond(age < 60, 2, 3))
    label define _ctrag 1 "<55" 2 "55-59" 3 "60+", replace
    label values agegrp _ctrag
    label variable agegrp "Age band"
    gen byte trt = drug > 1
    label define _ctrtr 0 "Placebo" 1 "Active", replace
    label values trt _ctrtr
    label variable trt "Treatment"
    gen byte old = age >= 55
    label define _ctrold 0 "Under 55" 1 "55 or older", replace
    label values old _ctrold
    label variable old "Age"
    label variable age "Age"
    stset studytime, failure(died)
    quietly ratetab agegrp trt old, outlabels("Death") level(95) frame(_ctr_rates, replace)
end

**# CK1: keyed placement: a plain (non-factor) row never fills a rate category
capture noisily {
    _ctr_surv
    * control: the factor form places by block|level
    collect clear
    quietly collect: stcox i.agegrp i.trt
    quietly regtab, frame(_ctr_m, replace) noint compact models("M1")
    comptab _ctr_m, rateframe(_ctr_rates) rows(all) keyed allmodels effect("aHR") frame(_ctr_c, replace)
    frame _ctr_m: assert strtrim(A[10]) == "Active"
    frame _ctr_m: local hr = strtrim(c1[10])
    frame _ctr_c: assert strtrim(c1[10]) == "Active" & c5[10] == "`hr'" & "`hr'" != ""
    * the same treatment as a 0/1 indicator: the row "Treatment" has no level
    collect clear
    quietly collect: stcox i.agegrp trt
    quietly regtab, frame(_ctr_m, replace) noint compact models("M1")
    capture noisily comptab _ctr_m, rateframe(_ctr_rates) rows(all) keyed allmodels effect("aHR")
    assert _rc == 198
    capture noisily comptab _ctr_m, rateframe(_ctr_rates) rows(all) modelonly allmodels effect("aHR")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: CK1 keyed: an indicator row whose label is a rate section's is refused (198)"
    local ++pass_count
}
else {
    display as error "  FAIL: CK1 keyed plain indicator row (rc=`=_rc')"
    local ++fail_count
}

**# CK2: keyed placement: a continuous term labelled like a two-category section
capture noisily {
    _ctr_surv
    collect clear
    quietly collect: stcox i.trt age
    quietly regtab, frame(_ctr_m, replace) noint compact models("M1")
    * age (per year) must not land on the "55 or older" category of section "Age"
    capture noisily comptab _ctr_m, rateframe(_ctr_rates) rows(all) modelonly allmodels effect("aHR")
    assert _rc == 198
    * a continuous term with its own label is still listed by modelonly
    label variable age "Age in years"
    collect clear
    quietly collect: stcox i.trt age
    quietly regtab, frame(_ctr_m, replace) noint compact models("M1")
    comptab _ctr_m, rateframe(_ctr_rates) rows(all) modelonly allmodels effect("aHR") frame(_ctr_c, replace)
    assert r(N_modelonly) == 1
    frame _ctr_c: assert strtrim(c1[_N]) == "Age in years"
}
if _rc == 0 {
    display as result "  PASS: CK2 keyed: a continuous term labelled like a section is refused; others list as modelonly"
    local ++pass_count
}
else {
    display as error "  FAIL: CK2 keyed continuous term (rc=`=_rc')"
    local ++fail_count
}

**# CK3: set dp comma: ratetab/stratetab cformat(), sep(), zeroexact, level(97.5)
capture noisily {
    sysuse cancer, clear
    replace died = 0 if drug == 3
    stset studytime, failure(died)
    quietly summarize studytime if drug == 3
    local y3 = r(sum)
    local want = strtrim(string(-ln(0.0125) / `y3' * 1000, "%9.3f"))
    foreach dp in period comma {
        set dp `dp'
        quietly strate drug, output("`output_dir'/_ctr_s1", replace) level(97.5)
        stratetab, using("`output_dir'/_ctr_s1") outcomes(1) zeroexact ///
            cformat(%9.3f) sep(" to ") frame(_ctr_d`dp', replace)
        frame _ctr_d`dp': assert c4[7] == "0.000 (0.000 to `want')"
        assert r(ci_level) == 97.5
        ratetab drug, level(97.5) cformat(%9.3f) sep("; ") ci(cluster(studytime)) frame(_ctr_r`dp', replace)
        frame _ctr_r`dp': assert c4[7] == "0.000 (0.000; `want')"
        frame _ctr_r`dp': assert strpos(c4[3], "97.5% CI") > 0
    }
    set dp period
    * every printed cell is identical under the two settings
    foreach f in d r {
        frame _ctr_`f'period: ds c*
        foreach v in `r(varlist)' {
            forvalues i = 1/7 {
                frame _ctr_`f'period: local a = `v'[`i']
                frame _ctr_`f'comma: local b = `v'[`i']
                assert `"`a'"' == `"`b'"'
            }
        }
    }
}
set dp period
if _rc == 0 {
    display as result "  PASS: CK3 set dp comma: cformat/sep/zeroexact/level(97.5) cells equal the dp period cells"
    local ++pass_count
}
else {
    display as error "  FAIL: CK3 set dp comma (rc=`=_rc')"
    local ++fail_count
}

local _tc = `pass_count' + `fail_count'
display "RESULT: test_comptab_v230_review tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _ctr
if `fail_count' > 0 exit 1
