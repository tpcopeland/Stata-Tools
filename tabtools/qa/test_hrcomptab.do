*! test_hrcomptab.do - Dedicated QA for hrcomptab

clear all
set more off
set varabbrev off

capture log close _hrcomptab
log using "test_hrcomptab.log", replace text name(_hrcomptab)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* Build shared source frames
tempfile rate11 rate12 rate21 rate22

clear
set obs 2
gen exposure = _n - 1
gen double _D = cond(_n == 1, 10, 20)
gen double _Y = cond(_n == 1, 1000, 1100)
gen double _Rate = _D / _Y
gen double _Lower = _Rate * 0.80
gen double _Upper = _Rate * 1.20
label define _hrc_exp2 0 "None" 1 "Current", replace
label values exposure _hrc_exp2
save "`rate11'.dta", replace

clear
set obs 2
gen exposure = _n - 1
gen double _D = cond(_n == 1, 5, 8)
gen double _Y = cond(_n == 1, 900, 950)
gen double _Rate = _D / _Y
gen double _Lower = _Rate * 0.80
gen double _Upper = _Rate * 1.20
label define _hrc_exp2b 0 "None" 1 "Current", replace
label values exposure _hrc_exp2b
save "`rate12'.dta", replace

clear
set obs 3
gen exposure = _n - 1
gen double _D = cond(_n == 1, 10, cond(_n == 2, 4, 6))
gen double _Y = cond(_n == 1, 1000, cond(_n == 2, 300, 400))
gen double _Rate = _D / _Y
gen double _Lower = _Rate * 0.80
gen double _Upper = _Rate * 1.20
label define _hrc_exp3 0 "None" 1 "Low" 2 "High", replace
label values exposure _hrc_exp3
save "`rate21'.dta", replace

clear
set obs 3
gen exposure = _n - 1
gen double _D = cond(_n == 1, 5, cond(_n == 2, 2, 4))
gen double _Y = cond(_n == 1, 900, cond(_n == 2, 250, 350))
gen double _Rate = _D / _Y
gen double _Lower = _Rate * 0.80
gen double _Upper = _Rate * 1.20
label define _hrc_exp3b 0 "None" 1 "Low" 2 "High", replace
label values exposure _hrc_exp3b
save "`rate22'.dta", replace

clear
stratetab, using(`rate11' `rate12' `rate21' `rate22') outcomes(2) ///
    frame(hrc_rates, replace) ///
    outlabels("Outcome 1" \ "Outcome 2") ///
    explabels("Binary HRT" \ "Dose Category")

clear
set obs 30
set seed 20260417
gen byte treated = mod(_n, 2)
gen double y1 = 10 + 2 * treated + rnormal()
gen double y2 = 6 + 1.5 * treated + rnormal()
collect clear
collect: regress y1 treated
collect: regress y2 treated
regtab, frame(hrc_bin, replace) noint

clear
set obs 45
gen byte dose = mod(_n, 3)
gen double y1 = 12 + 1.5 * (dose == 1) + 2.5 * (dose == 2) + rnormal()
gen double y2 = 8 + 0.5 * (dose == 1) + 1.5 * (dose == 2) + rnormal()
collect clear
collect: regress y1 i.dose
collect: regress y2 i.dose
regtab, frame(hrc_dose, replace) noint

* 1. rows() workflow with frame output
local ++test_count
capture noisily {
    capture frame drop hrc_final
    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
        rows(1 \ 3/4) ///
        effect("aHR") ///
        frame(hrc_final, replace)

    assert r(N_outcomes) == 2
    assert r(N_sections) == 2
    assert r(N_modelrows) == 3
    assert "`r(frame)'" == "hrc_final"

    frame hrc_final {
        assert _N == 10
        assert c1[4] == "Binary HRT"
        assert c1[7] == "Dose Category"
        assert c5[5] == "Reference"
        assert c10[5] == "Reference"
        assert c5[8] == "Reference"
        assert c10[8] == "Reference"
        assert strpos(c5[6], "(") > 0
        assert strpos(c10[6], "(") > 0
        assert c6[6] != "p-value"
        assert c11[6] != "p-value"
        assert c5[9] != "Reference"
        assert c10[10] != "Reference"
    }
    capture frame drop hrc_final
}
if _rc == 0 {
    display as result "  PASS: hrcomptab rows() composes stratetab + regtab frames"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab rows() workflow (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_final

* 2. rownames() workflow
local ++test_count
capture noisily {
    capture frame drop hrc_final2
    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
        rownames("treated" \ "1 2") ///
        frame(hrc_final2, replace)
    assert r(N_modelrows) == 3
    frame hrc_final2: assert c5[6] != ""
    capture frame drop hrc_final2
}
if _rc == 0 {
    display as result "  PASS: hrcomptab rownames() workflow"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab rownames() workflow (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_final2

* 3. xlsx export
local ++test_count
capture noisily {
    local xlsx "`output_dir'/test_hrcomptab.xlsx"
    capture erase "`xlsx'"
    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
        rows(1 \ 3/4) ///
        xlsx("`xlsx'") sheet("Table2") ///
        title("Table 2. Composite") ///
        footnote("aHR = adjusted hazard ratio")
    confirm file "`xlsx'"
}
if _rc == 0 {
    display as result "  PASS: hrcomptab xlsx export"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab xlsx export (rc=`=_rc')"
    local ++fail_count
}

display as result "hrcomptab QA summary: `pass_count' passed, `fail_count' failed"
if `fail_count' > 0 exit 1

log close _hrcomptab
