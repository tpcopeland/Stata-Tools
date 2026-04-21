* Test effecttab IPTW fix: should filter PS model coefficients by default
clear all
set more off

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local n_pass = 0
local n_fail = 0

webuse cattaneo2, clear
label define smokelbl 0 "Non-smoker" 1 "Smoker"
label values mbsmoke smokelbl

* ============================================================
* Test 1: IPTW without clean — should filter PS model coefficients
* Rows: title + 2 headers + ATE section (header + value) + POmean section (header + value) = 7
* ============================================================
collect clear
collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
effecttab, display title("IPTW no clean") effect("ATE")
local _nrows = r(N_rows)
display "N_rows = `_nrows'"
* Must be fewer than the original 12 (which included PS model coefficients)
if `_nrows' <= 8 {
    display as result "PASS: T1 — IPTW filtered PS model (`_nrows' rows)"
    local ++n_pass
}
else {
    display as error "FAIL: T1 — IPTW shows `_nrows' rows (expected <=8, PS model not filtered)"
    local ++n_fail
}

* ============================================================
* Test 2: IPTW with clean — cleaner labels, fewer rows
* ============================================================
collect clear
collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
effecttab, display title("IPTW clean") effect("ATE") clean
local _nrows = r(N_rows)
if `_nrows' <= 6 {
    display as result "PASS: T2 — IPTW with clean (`_nrows' rows)"
    local ++n_pass
}
else {
    display as error "FAIL: T2 — IPTW with clean shows `_nrows' rows (expected <=6)"
    local ++n_fail
}

* ============================================================
* Test 3: IPTW with full — should show ALL rows including PS model
* ============================================================
collect clear
collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
effecttab, display title("IPTW full") effect("ATE") full
local _nrows = r(N_rows)
if `_nrows' > 8 {
    display as result "PASS: T3 — IPTW with full shows all rows (`_nrows' rows)"
    local ++n_pass
}
else {
    display as error "FAIL: T3 — IPTW with full should show >8 rows, got `_nrows'"
    local ++n_fail
}

* ============================================================
* Test 4: AIPW — should filter nuisance parameters
* ============================================================
collect clear
collect: teffects aipw (bweight mage prenatal1 mmarried) (mbsmoke mage prenatal1 mmarried fbaby), ate
effecttab, display title("AIPW") effect("ATE")
local _nrows = r(N_rows)
if `_nrows' <= 8 {
    display as result "PASS: T4 — AIPW filtered (`_nrows' rows)"
    local ++n_pass
}
else {
    display as error "FAIL: T4 — AIPW shows `_nrows' rows (expected <=8)"
    local ++n_fail
}

* ============================================================
* Test 5: IPWRA — should filter nuisance parameters
* ============================================================
collect clear
collect: teffects ipwra (bweight mage prenatal1 mmarried) (mbsmoke mage prenatal1 mmarried fbaby), ate
effecttab, display title("IPWRA") effect("ATE")
local _nrows = r(N_rows)
if `_nrows' <= 8 {
    display as result "PASS: T5 — IPWRA filtered (`_nrows' rows)"
    local ++n_pass
}
else {
    display as error "FAIL: T5 — IPWRA shows `_nrows' rows (expected <=8)"
    local ++n_fail
}

* ============================================================
* Test 6: RA — same behavior
* ============================================================
collect clear
collect: teffects ra (bweight mage prenatal1 mmarried fbaby) (mbsmoke), ate
effecttab, display title("RA") effect("ATE")
local _nrows = r(N_rows)
if `_nrows' <= 8 {
    display as result "PASS: T6 — RA filtered (`_nrows' rows)"
    local ++n_pass
}
else {
    display as error "FAIL: T6 — RA shows `_nrows' rows (expected <=8)"
    local ++n_fail
}

* ============================================================
* Test 7: Multi-arm (3 levels)
* ============================================================
gen trt3 = cond(mage < 25, 0, cond(mage < 35, 1, 2))
label define trt3lbl 0 "Young" 1 "Middle" 2 "Older"
label values trt3 trt3lbl

collect clear
collect: teffects ra (bweight prenatal1 mmarried fbaby) (trt3), ate
effecttab, display title("Multi-arm") effect("ATE") clean
local _nrows = r(N_rows)
if `_nrows' <= 9 {
    display as result "PASS: T7 — Multi-arm shows correct rows (`_nrows' rows)"
    local ++n_pass
}
else {
    display as error "FAIL: T7 — Multi-arm shows `_nrows' rows (expected <=9)"
    local ++n_fail
}

* ============================================================
* Test 8: Margins (should be unaffected)
* ============================================================
gen byte low_bw = bweight < 2500
logit low_bw i.mbsmoke mage prenatal1 mmarried fbaby
collect clear
collect: margins mbsmoke
effecttab, display title("Margins") effect("Pr(Y)")
local _nrows = r(N_rows)
if `_nrows' >= 4 {
    display as result "PASS: T8 — Margins works (`_nrows' rows)"
    local ++n_pass
}
else {
    display as error "FAIL: T8 — Margins shows only `_nrows' rows (expected >=4)"
    local ++n_fail
}

* ============================================================
* Test 9: Excel export — verify PS model coefficients removed
* ============================================================
collect clear
collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
effecttab, xlsx("/tmp/iptw_fix_test.xlsx") sheet("IPTW") title("IPTW Fixed") effect("ATE")
local _nrows = r(N_rows)
if `_nrows' <= 8 {
    display as result "PASS: T9 — IPTW Excel export filtered (`_nrows' rows)"
    local ++n_pass
}
else {
    display as error "FAIL: T9 — IPTW Excel export shows `_nrows' rows"
    local ++n_fail
}

* ============================================================
* Test 10: Binary outcome IPTW
* ============================================================
collect clear
collect: teffects ipw (low_bw) (mbsmoke mage prenatal1 mmarried fbaby), ate
effecttab, display title("IPTW Binary") effect("RD")
local _nrows = r(N_rows)
if `_nrows' <= 8 {
    display as result "PASS: T10 — IPTW binary filtered (`_nrows' rows)"
    local ++n_pass
}
else {
    display as error "FAIL: T10 — IPTW binary shows `_nrows' rows (expected <=8)"
    local ++n_fail
}

* ============================================================
* Test 11: Verify IPTW Excel has no PS model coefficients
* ============================================================
capture {
    preserve
    import excel "/tmp/iptw_fix_test.xlsx", sheet("IPTW") clear
    * Check that "Mother's age" does not appear in column B
    gen byte _has_ps = regexm(B, "Mother") | regexm(B, "prenatal") | regexm(B, "married") | regexm(B, "first baby") | regexm(B, "Intercept")
    summarize _has_ps, meanonly
    restore
}
if _rc == 0 & r(max) == 0 {
    display as result "PASS: T11 — Excel contains no PS model coefficients"
    local ++n_pass
}
else {
    display as error "FAIL: T11 — Excel still contains PS model coefficients"
    local ++n_fail
}

* ============================================================
* Test 12: Value-level ATE comparison to direct teffects
* ============================================================
webuse cattaneo2, clear
label define smokelbl2 0 "Non-smoker" 1 "Smoker", replace
label values mbsmoke smokelbl2

collect clear
collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
matrix _te_table = r(table)
local _ref_ate = _te_table[1,1]
local _ref_pval = _te_table[4,1]

effecttab, frame(eff_val, replace) effect("ATE") clean display

* Extract ATE value from frame — c1 contains the estimate, A contains the row label
frame eff_val {
	local _found = 0
	forvalues _r = 1/`=_N' {
		local _val = real(strtrim(c1[`_r']))
		if !missing(`_val') {
			* First numeric c1 value is the ATE
			assert abs(`_val' - round(`_ref_ate', 0.01)) < 0.015
			local _found = 1
			continue, break
		}
	}
	assert `_found' == 1
}
capture frame drop eff_val

if _rc == 0 {
	display as result "PASS: T12 — ATE value matches direct teffects"
	local ++n_pass
}
else {
	display as error "FAIL: T12 — ATE value mismatch"
	local ++n_fail
	capture frame drop eff_val
}

* Summary
display _newline
display "============================="
display "  Results: `n_pass' passed, `n_fail' failed"
display "============================="
assert `n_fail' == 0
