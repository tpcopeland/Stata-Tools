* test_effecttab_labels.do
* Tests for effecttab treatment label features (clean + tlabels)
* Run: stata-mp -b do ../../_devkit/_testing/test_effecttab_labels.do

clear all
set more off
set varabbrev off
version 17.0

adopath ++ tabtools
run tabtools/_tabtools_common.ado

local pass = 0
local fail = 0

capture program drop test_section
program define test_section
	args status name
	if "`status'" == "pass" {
		di as text "[PASS] `name'"
	}
	else {
		di as error "[FAIL] `name'"
	}
end

* =========================================================================
* Test 1: clean option with value-labeled treatment variable (auto-detect)
* =========================================================================
{
di _newline _dup(60) "="
di as text "Test 1: clean with auto-detected value labels"
di _dup(60) "="

capture noisily {
	sysuse cancer, clear
	* drug has value labels: 1=Placebo, 2=Drug A, 3=Drug B
	label list
	collect clear
	collect: teffects ipw (died) (drug age), ate
	effecttab, xlsx(../../_devkit/_testing/effecttab_label_test.xlsx) ///
		sheet("AutoLabels") effect("ATE") ///
		title("Test 1: Auto-detected Value Labels") clean
}
if _rc == 0 {
	test_section pass "clean with auto-detected value labels"
	local pass = `pass' + 1
}
else {
	test_section fail "clean with auto-detected value labels"
	local fail = `fail' + 1
}
}

* =========================================================================
* Test 2: tlabels() option with explicit labels
* =========================================================================
{
di _newline _dup(60) "="
di as text "Test 2: tlabels() with explicit labels"
di _dup(60) "="

capture noisily {
	sysuse cancer, clear
	collect clear
	collect: teffects ipw (died) (drug age), ate
	effecttab, xlsx(../../_devkit/_testing/effecttab_label_test.xlsx) ///
		sheet("ExplicitLabels") effect("ATE") ///
		title("Test 2: Explicit tlabels()") ///
		tlabels(1 "Control" 2 "Treatment A" 3 "Treatment B")
}
if _rc == 0 {
	test_section pass "tlabels() with explicit labels"
	local pass = `pass' + 1
}
else {
	test_section fail "tlabels() with explicit labels"
	local fail = `fail' + 1
}
}

* =========================================================================
* Test 3: clean option without value labels (fallback to regex)
* =========================================================================
{
di _newline _dup(60) "="
di as text "Test 3: clean without value labels (regex fallback)"
di _dup(60) "="

capture noisily {
	sysuse cancer, clear
	* Remove value labels from drug to test fallback
	label values drug
	collect clear
	collect: teffects ipw (died) (drug age), ate
	effecttab, xlsx(../../_devkit/_testing/effecttab_label_test.xlsx) ///
		sheet("RegexFallback") effect("ATE") ///
		title("Test 3: Regex Fallback (no value labels)") clean
}
if _rc == 0 {
	test_section pass "clean without value labels (regex fallback)"
	local pass = `pass' + 1
}
else {
	test_section fail "clean without value labels (regex fallback)"
	local fail = `fail' + 1
}
}

* =========================================================================
* Test 4: Binary treatment with value labels
* =========================================================================
{
di _newline _dup(60) "="
di as text "Test 4: Binary treatment with value labels"
di _dup(60) "="

capture noisily {
	sysuse cancer, clear
	gen byte treated = (drug >= 2)
	label define treated_lbl 0 "Placebo" 1 "Active Drug"
	label values treated treated_lbl
	collect clear
	collect: teffects ipw (died) (treated age), ate
	effecttab, xlsx(../../_devkit/_testing/effecttab_label_test.xlsx) ///
		sheet("BinaryLabels") effect("ATE") ///
		title("Test 4: Binary Treatment with Value Labels") clean
}
if _rc == 0 {
	test_section pass "Binary treatment with value labels"
	local pass = `pass' + 1
}
else {
	test_section fail "Binary treatment with value labels"
	local fail = `fail' + 1
}
}

* =========================================================================
* Test 5: No clean option (raw labels, backward compatibility)
* =========================================================================
{
di _newline _dup(60) "="
di as text "Test 5: No clean option (raw labels)"
di _dup(60) "="

capture noisily {
	sysuse cancer, clear
	collect clear
	collect: teffects ipw (died) (drug age), ate
	effecttab, xlsx(../../_devkit/_testing/effecttab_label_test.xlsx) ///
		sheet("RawLabels") effect("ATE") ///
		title("Test 5: Raw Labels (no clean)")
}
if _rc == 0 {
	test_section pass "No clean option (raw labels)"
	local pass = `pass' + 1
}
else {
	test_section fail "No clean option (raw labels)"
	local fail = `fail' + 1
}
}

* =========================================================================
* Test 6: PO Means with value labels
* =========================================================================
{
di _newline _dup(60) "="
di as text "Test 6: PO Means with value labels"
di _dup(60) "="

capture noisily {
	sysuse cancer, clear
	collect clear
	collect: teffects ipw (died) (drug age), pomeans
	effecttab, xlsx(../../_devkit/_testing/effecttab_label_test.xlsx) ///
		sheet("POMeans") effect("Pr(Death)") ///
		title("Test 6: PO Means with Value Labels") clean
}
if _rc == 0 {
	test_section pass "PO Means with value labels"
	local pass = `pass' + 1
}
else {
	test_section fail "PO Means with value labels"
	local fail = `fail' + 1
}
}

* =========================================================================
* Summary
* =========================================================================
di _newline _dup(60) "="
di as text "SUMMARY: `pass' passed, `fail' failed out of `=`pass'+`fail'' tests"
di _dup(60) "="

* Clean up test output
capture erase ../../_devkit/_testing/effecttab_label_test.xlsx
