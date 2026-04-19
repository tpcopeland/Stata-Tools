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
* 6. frame()-only output does not preview unless display is requested
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
    assert strpos(`"`preview_text'"', "Binary HRT") == 0
    capture frame drop hrc_nodisplay
}
if _rc == 0 {
    display as result "  PASS: hrcomptab frame()-only path does not auto-preview"
    local ++pass_count
}
else {
    capture log close _preview_off
    display as error "  FAIL: hrcomptab frame()-only preview suppression (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_nodisplay

* -------------------------------------------------------------------------
* 7. display option still forces a preview
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
    display as result "  PASS: hrcomptab display option still previews"
    local ++pass_count
}
else {
    capture log close _preview_on
    display as error "  FAIL: hrcomptab display option preview (rc=`=_rc')"
    local ++fail_count
}
capture frame drop hrc_display

display as result "hrcomptab QA summary: `pass_count' passed, `fail_count' failed"
quietly tabtools set clear
if `fail_count' > 0 exit 1

log close _hrcomptab
