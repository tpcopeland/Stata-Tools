*! test_hrcomptab.do - Focused QA for hrcomptab

capture log close _hrcomptab
log using "test_hrcomptab.log", replace text name(_hrcomptab)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
quietly tabtools set clear

local test_count = 0
local pass_count = 0
local fail_count = 0

* -------------------------------------------------------------------------
* Build stable rate/model frames once
* -------------------------------------------------------------------------
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
capture frame drop hrc_bin
regtab, frame(hrc_bin) noint
capture frame drop hrc_bin_comp
regtab, compact frame(hrc_bin_comp) noint

clear
set obs 45
gen byte dose = mod(_n, 3)
gen double y1 = 12 + 1.5 * (dose == 1) + 2.5 * (dose == 2) + rnormal()
gen double y2 = 8 + 0.5 * (dose == 1) + 1.5 * (dose == 2) + rnormal()
collect clear
collect: regress y1 i.dose
collect: regress y2 i.dose
capture frame drop hrc_dose
regtab, frame(hrc_dose) noint

capture frame drop hrc_cmp3
frame copy hrc_bin_comp hrc_cmp3
frame hrc_cmp3 {
    gen str244 c5 = c1
    gen str244 c6 = c2
}

* -------------------------------------------------------------------------
* 1. rows() workflow with frame output
* -------------------------------------------------------------------------
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
    }
    capture frame drop hrc_final
}
if _rc == 0 {
    display as result "  PASS: hrcomptab rows() composes the final scaffold"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab rows() workflow (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_final

* -------------------------------------------------------------------------
* 1b. reflabel() overrides inferred reference text; r(rateframe) returns source
*     Clarity audit MINOR-4 (2026-06-13): reflabel and r(rateframe) untested.
*     Same rows()/effect() as test 1 so reference-row positions match.
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    capture frame drop hrc_reflab
    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
        rows(1 \ 3/4) effect("aHR") reflabel("Ref. group") ///
        frame(hrc_reflab, replace)

    assert "`r(rateframe)'" == "hrc_rates"

    frame hrc_reflab {
        assert c5[5]  == "Ref. group"
        assert c10[5] == "Ref. group"
        assert c5[8]  == "Ref. group"
        assert c10[8] == "Ref. group"
        * The default "Reference" text must no longer appear anywhere.
        local _saw_default 0
        foreach _v of varlist c* {
            quietly count if strtrim(`_v') == "Reference"
            if r(N) > 0 local _saw_default 1
        }
        assert `_saw_default' == 0
    }
    capture frame drop hrc_reflab
}
if _rc == 0 {
    display as result "  PASS: hrcomptab reflabel() + r(rateframe)"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab reflabel()/r(rateframe) (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_reflab

* -------------------------------------------------------------------------
* 2. rownames() workflow
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    capture frame drop hrc_final2
    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
        rownames("treated" \ "1 2") ///
        frame(hrc_final2, replace)
    assert r(N_modelrows) == 3
    frame hrc_final2 {
        assert c5[6] != ""
        assert c10[9] != ""
    }
    capture frame drop hrc_final2
}
if _rc == 0 {
    display as result "  PASS: hrcomptab rownames() matches rendered labels"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab rownames() workflow (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_final2

* -------------------------------------------------------------------------
* 2b. rownames() minimum-abbreviation rown() (regression: ROWNAMES was
*     all-caps so rown() failed rc=198 despite the help documenting it)
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    capture frame drop hrc_final2b
    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
        rown("treated" \ "1 2") ///
        frame(hrc_final2b, replace)
    assert r(N_modelrows) == 3
    capture frame drop hrc_final2b
}
if _rc == 0 {
    display as result "  PASS: hrcomptab rown() abbreviation accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab rown() abbreviation (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_final2b

* -------------------------------------------------------------------------
* 3. Ambiguous mixed layouts are rejected
* -------------------------------------------------------------------------
local ++test_count
capture noisily hrcomptab hrc_rates, modelframes(hrc_bin hrc_cmp3) ///
    rows(1 \ 1) display
if _rc == 198 {
    display as result "  PASS: hrcomptab rejects mixed standard/compact layouts"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab mixed-layout rejection (expected 198, got `=_rc')"
    local ++fail_count
}

* -------------------------------------------------------------------------
* 4. theme(apa) propagates workbook font settings
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    quietly tabtools set clear
    local xlsx "`output_dir'/test_hrcomptab_apa.xlsx"
    local styles "`output_dir'/test_hrcomptab_apa_styles.xml"
    capture erase "`xlsx'"
    capture erase "`styles'"
    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
        rows(1 \ 3/4) ///
        xlsx("`xlsx'") sheet("APA") theme(apa)
    confirm file "`xlsx'"
    shell unzip -p "`xlsx'" xl/styles.xml > "`styles'"
    confirm file "`styles'"
    shell grep -q 'Times New Roman' "`styles'"
    assert _rc == 0
    shell grep -q 'sz val=\"12\"' "`styles'"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: hrcomptab theme(apa) reaches workbook styles"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab theme(apa) workbook styles (rc=`=_rc')"
    local ++fail_count
}

* -------------------------------------------------------------------------
* 5. tabtools set font/fontsize defaults propagate into hrcomptab
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    quietly tabtools set clear
    quietly tabtools set font "Courier New"
    quietly tabtools set fontsize 13
    local xlsx "`output_dir'/test_hrcomptab_defaults.xlsx"
    local styles "`output_dir'/test_hrcomptab_defaults_styles.xml"
    capture erase "`xlsx'"
    capture erase "`styles'"
    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
        rows(1 \ 3/4) ///
        excel("`xlsx'") sheet("Defaults")
    confirm file "`xlsx'"
    shell unzip -p "`xlsx'" xl/styles.xml > "`styles'"
    confirm file "`styles'"
    shell grep -q 'Courier New' "`styles'"
    assert _rc == 0
    shell grep -q 'sz val=\"13\"' "`styles'"
    assert _rc == 0
    quietly tabtools set clear
}
if _rc == 0 {
    display as result "  PASS: hrcomptab honors tabtools set font/fontsize defaults"
    local ++pass_count
}
else {
    local _test_rc = _rc
    capture noisily tabtools set clear
    display as error "  FAIL: hrcomptab persistent formatting defaults (rc=`_test_rc')"
    local ++fail_count
}

* -------------------------------------------------------------------------
* 6. frame()-only output automatically previews the completed table
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    local preview_log "`output_dir'/test_hrcomptab_preview_off.log"
    capture erase "`preview_log'"
    capture log close _preview_off
    log using "`preview_log'", replace text name(_preview_off)
    capture frame drop hrc_nodisplay
    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
        rows(1 \ 3/4) ///
        frame(hrc_nodisplay, replace)
    log close _preview_off
    local preview_text ""
    tempname fh
    file open `fh' using "`preview_log'", read text
    file read `fh' line
    while r(eof) == 0 {
        local preview_text `"`preview_text'`line'"'
        file read `fh' line
    }
    file close `fh'
    assert strpos(`"`preview_text'"', "Binary HRT") > 0
    capture frame drop hrc_nodisplay
}
if _rc == 0 {
    display as result "  PASS: hrcomptab frame()-only path auto-previews"
    local ++pass_count
}
else {
    capture log close _preview_off
    display as error "  FAIL: hrcomptab frame()-only auto-preview (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_nodisplay

* -------------------------------------------------------------------------
* 7. display option remains accepted and still previews
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    local preview_log "`output_dir'/test_hrcomptab_preview_on.log"
    capture erase "`preview_log'"
    capture log close _preview_on
    log using "`preview_log'", replace text name(_preview_on)
    capture frame drop hrc_display
    hrcomptab hrc_rates, modelframes(hrc_bin hrc_dose) ///
        rows(1 \ 3/4) ///
        frame(hrc_display, replace) display
    log close _preview_on
    local preview_text ""
    tempname fh
    file open `fh' using "`preview_log'", read text
    file read `fh' line
    while r(eof) == 0 {
        local preview_text `"`preview_text'`line'"'
        file read `fh' line
    }
    file close `fh'
    assert strpos(`"`preview_text'"', "Binary HRT") > 0
    capture frame drop hrc_display
}
if _rc == 0 {
    display as result "  PASS: hrcomptab display option remains accepted"
    local ++pass_count
}
else {
    capture log close _preview_on
    display as error "  FAIL: hrcomptab display option preview (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_display
**# Migrated: xlsx success message

**# 5. hrcomptab xlsx success message is visible

**## 5a. Export confirmation message appears in log output
capture noisily {
    * Build minimal stratetab frame
    clear
    set obs 2
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 10, 20)
    gen double _Y = cond(_n == 1, 1000, 1100)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.80
    gen double _Upper = _Rate * 1.20
    label define _hrc_exp 0 "None" 1 "Current", replace
    label values exposure _hrc_exp
    tempfile hrc_rate
    save "`hrc_rate'.dta", replace

    clear
    capture frame drop _hrc_rf
    stratetab, using(`hrc_rate') outcomes(1) frame(_hrc_rf, replace)

    * Build minimal regtab frame
    clear
    set obs 30
    set seed 20260427
    gen byte treated = mod(_n, 2)
    gen double y = 10 + 2 * treated + rnormal()
    collect clear
    collect: regress y treated
    capture frame drop _hrc_mf
    regtab, frame(_hrc_mf) noint

    * Run hrcomptab with xlsx and capture output to a file
    clear
    local hrclog_path "`output_dir'/_rev1013_hrc_check"
    capture log close _hrccheck
    log using "`hrclog_path'", replace text name(_hrccheck)
    hrcomptab _hrc_rf, modelframes(_hrc_mf) rows(1) ///
        xlsx("`output_dir'/_rev1013_hrcomptab.xlsx") ///
        sheet("Test")
    log close _hrccheck

    * Read back the log and search for the success message
    tempname fh2
    local found_msg 0
    file open `fh2' using "`hrclog_path'.log", read text
    file read `fh2' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "Exported") > 0 & strpos(`"`line'"', "cols to") > 0 {
            local found_msg 1
        }
        file read `fh2' line
    }
    file close `fh2'
    assert `found_msg' == 1

    * Cleanup frames
    capture frame drop _hrc_rf
    capture frame drop _hrc_mf
}
if _rc == 0 {
    display as result "  PASS [5a]: hrcomptab xlsx success message visible in output"
    local ++pass_count
}
else {
    display as error "  FAIL [5a]: hrcomptab xlsx success message not found (rc=`=_rc')"
    local ++fail_count
    capture frame drop _hrc_rf
    capture frame drop _hrc_mf
}
capture erase "`output_dir'/_rev1013_hrcomptab.xlsx"
capture erase "`output_dir'/_rev1013_hrc_check.log"



**# Migrated: rownames() pattern matching

**# QA Gap 5: hrcomptab rownames() pattern matching

**## 5a. rownames() with unique match works
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    gen byte agecat = cond(age < 55, 1, cond(age < 65, 2, 3))
    label define agelab 1 "<55" 2 "55-64" 3 "65+"
    label values agecat agelab

    * Use a real file path (tempfile gets cleaned up inside capture noisily)
    local _strate_path "`output_dir'/_test_strate_5a"
    capture erase "`_strate_path'.dta"
    strate agecat, per(1000) output("`_strate_path'", replace)

    capture frame drop _str_test
    stratetab, using("`_strate_path'") outcomes(1) ///
        outlabels("Event") explabels("Age") frame(_str_test)

    collect clear
    collect: stcox i.agecat, nolog
    capture frame drop _reg_test
    regtab, frame(_reg_test) coef(HR) display

    * hrcomptab with rownames — "55" should match "55-64" in regtab
    capture frame drop _hrc_test
    hrcomptab _str_test, modelframes(_reg_test) ///
        rownames(55) display frame(_hrc_test)

    frame _hrc_test {
        assert _N > 3
    }
    capture frame drop _hrc_test
    capture frame drop _str_test
    capture frame drop _reg_test
    capture erase "`_strate_path'.dta"
}
if _rc == 0 {
    display as result "  PASS [5a]: hrcomptab rownames() with unique match"
    local ++pass_count
}
else {
    display as error "  FAIL [5a]: hrcomptab rownames (rc=`=_rc')"
    local ++fail_count
}

**## 5b. rownames() with non-matching pattern errors correctly
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    gen byte agecat = cond(age < 55, 1, cond(age < 65, 2, 3))
    label define agelab2 1 "<55" 2 "55-64" 3 "65+"
    label values agecat agelab2

    local _strate_path2 "`output_dir'/_test_strate_5b"
    capture erase "`_strate_path2'.dta"
    strate agecat, per(1000) output("`_strate_path2'", replace)

    capture frame drop _str_test2
    stratetab, using("`_strate_path2'") outcomes(1) ///
        outlabels("Event") explabels("Age") frame(_str_test2)

    collect clear
    collect: stcox i.agecat, nolog
    capture frame drop _reg_test2
    regtab, frame(_reg_test2) coef(HR) display

    hrcomptab _str_test2, modelframes(_reg_test2) ///
        rownames(NONEXISTENT_PATTERN) display
}
if _rc == 198 {
    display as result "  PASS [5b]: hrcomptab rownames() with no match errors rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL [5b]: hrcomptab non-matching rownames should give rc=198, got rc=`=_rc'"
    local ++fail_count
}
capture frame drop _str_test2
capture frame drop _reg_test2
capture erase "`output_dir'/_test_strate_5b.dta"





display as result "hrcomptab QA summary: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_hrcomptab tests=`_tc' pass=`pass_count' fail=`fail_count'"
quietly tabtools set clear
if `fail_count' > 0 exit 1

log close _hrcomptab
