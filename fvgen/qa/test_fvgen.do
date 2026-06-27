clear all
set varabbrev off
version 16.0

* Bootstrap (sandboxed install) + data builder.
do _fvgen_qa_common.do
_fvgen_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# 1. Basic cat-by-continuous: variables, returns, naming
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age
    assert r(k_main) == 2
    assert r(k_int)  == 1
    assert r(k_all)  == 3
    assert "`r(intvars)'"  == "_armXage_1"
    assert "`r(genvars)'"  == "_arm_1 _armXage_1"
    assert "`r(spec)'"     != ""
    confirm variable _arm_1
    confirm variable _armXage_1
    * age passes through (not generated)
    assert "`r(mainvars)'" == "_arm_1 age"
}
if _rc == 0 {
    display as result "  PASS: basic cat-by-continuous surface"
    local ++pass_count
}
else {
    display as error "  FAIL: basic cat-by-continuous surface (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**# 2. Value label becomes variable label (quote/ampersand safe)
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age
    local lb : variable label _arm_1
    assert `"`lb'"' == `"large & wide"'
    * interaction label combines the two sides with the default symbol
    local li : variable label _armXage_1
    assert ustrpos(`"`li'"', "large & wide") == 1
    assert ustrpos(`"`li'"', "×") > 0
}
if _rc == 0 {
    display as result "  PASS: value label -> variable label (ampersand)"
    local ++pass_count
}
else {
    display as error "  FAIL: value label -> variable label (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# 3. Double-quote inside a value label survives (alllevels exposes base)
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm, alllevels
    confirm variable _arm_0
    local lb : variable label _arm_0
    assert `"`lb'"' == `"6" rim"'
}
if _rc == 0 {
    display as result "  PASS: double-quote label is quote-safe"
    local ++pass_count
}
else {
    display as error "  FAIL: double-quote label (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**# 4. Categorical-by-categorical: empty cell is skipped
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.grp##i.arm
    * grp==3 co-occurs only with arm==0, so grp3 x arm1 is empty
    capture confirm variable _grpXarm_3_1
    assert _rc != 0
    * grp2 x arm1 is populated and must exist
    confirm variable _grpXarm_2_1
    * base level grp==1 is dropped by default
    capture confirm variable _grp_1
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: empty interaction cell skipped, base dropped"
    local ++pass_count
}
else {
    display as error "  FAIL: empty cell / base handling (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**# 5. Missing-value propagation in dummies and products
local ++test_count
capture noisily {
    _fvgen_make_data
    quietly count if missing(grp)
    local n_grp_miss = r(N)
    quietly count if missing(age)
    local n_age_miss = r(N)
    fvgen i.grp##c.age
    quietly count if missing(_grp_2)
    assert r(N) == `n_grp_miss'
    * product missing wherever age (or grp) missing; arm/grp drive it
    quietly count if missing(_grpXage_2)
    assert r(N) == `n_grp_miss' + `n_age_miss'
}
if _rc == 0 {
    display as result "  PASS: missing propagation (dummies + products)"
    local ++pass_count
}
else {
    display as error "  FAIL: missing propagation (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**# 6. prefix() option
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age, prefix(z_)
    confirm variable z_arm_1
    confirm variable z_armXage_1
    capture confirm variable _arm_1
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: prefix() option"
    local ++pass_count
}
else {
    display as error "  FAIL: prefix() option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

**# 7. xsymbol() ASCII label
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age, xsymbol(x)
    local li : variable label _armXage_1
    assert ustrpos(`"`li'"', " x ") > 0
    assert ustrpos(`"`li'"', "×") == 0
}
if _rc == 0 {
    display as result "  PASS: xsymbol() ASCII separator"
    local ++pass_count
}
else {
    display as error "  FAIL: xsymbol() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

**# 8. center: centered copies created, sample mean ~ 0
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen c.age##c.bmi, center
    confirm variable _age_c
    confirm variable _bmi_c
    confirm variable _ageXbmi
    * centering mean is taken over the joint analysis sample (age & bmi present)
    quietly summarize _age_c if !missing(age, bmi), meanonly
    assert abs(r(mean)) < 1e-8
    quietly summarize _bmi_c if !missing(age, bmi), meanonly
    assert abs(r(mean)) < 1e-8
    local lc : variable label _age_c
    assert ustrpos(`"`lc'"', "centered") > 0
}
if _rc == 0 {
    display as result "  PASS: center semantics"
    local ++pass_count
}
else {
    display as error "  FAIL: center semantics (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

**# 9. replace recovers a name collision
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age
    * second call without replace must error 110
    capture fvgen i.arm##c.age
    assert _rc == 110
    * with replace it succeeds
    fvgen i.arm##c.age, replace
    confirm variable _armXage_1
}
if _rc == 0 {
    display as result "  PASS: replace recovers collision"
    local ++pass_count
}
else {
    display as error "  FAIL: replace recovers collision (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}

**# 10. if/in restricts which levels are materialized
local ++test_count
capture noisily {
    _fvgen_make_data
    * Restricting to grp<3 removes level 3 from the materialized set
    fvgen i.grp if grp < 3
    capture confirm variable _grp_3
    assert _rc != 0
    confirm variable _grp_2
}
if _rc == 0 {
    display as result "  PASS: if/in restricts materialized levels"
    local ++pass_count
}
else {
    display as error "  FAIL: if/in restriction (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}

**# 11. Continuous self-interaction gets a squared (²) label and squared values
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen c.age##c.age
    confirm variable _ageXage
    local lb : variable label _ageXage
    * label ends in the superscript-two, not "Age × Age"
    assert ustrpos(`"`lb'"', "²") > 0
    assert ustrpos(`"`lb'"', "×") == 0
    * value is age*age where age is present (obs 20), missing where age is (obs 6)
    assert reldif(_ageXage[20], age[20]*age[20]) < 1e-10
    assert missing(_ageXage[6])
}
if _rc == 0 {
    display as result "  PASS: squared self-interaction label + values"
    local ++pass_count
}
else {
    display as error "  FAIL: squared self-interaction (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11"
}

**# 12. ibn. (no base) materializes every level, base included
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen ibn.grp
    confirm variable _grp_1
    confirm variable _grp_2
    confirm variable _grp_3
    assert r(k_main) == 3
}
if _rc == 0 {
    display as result "  PASS: ibn. materializes all levels"
    local ++pass_count
}
else {
    display as error "  FAIL: ibn. all levels (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 12"
}

**# 13. Weight-aware centering: centered mean is the weighted mean
local ++test_count
capture noisily {
    _fvgen_make_data
    generate double wt = 1 + 2 * runiform()
    * weighted centering: mean of the centered copy is ~0 under the SAME weights
    fvgen c.age##c.bmi [aweight=wt], center
    quietly summarize _age_c [aweight=wt] if !missing(age, bmi), meanonly
    assert abs(r(mean)) < 1e-8
    * known answer: centered value == raw minus the weighted sample mean
    quietly summarize age [aweight=wt] if !missing(age, bmi), meanonly
    scalar wm = r(mean)
    assert reldif(_age_c[20], age[20] - wm) < 1e-10
    * pweight is accepted and gives the same centering mean as aweight
    fvgen c.age##c.bmi [pweight=wt], center replace
    quietly summarize _age_c [aweight=wt] if !missing(age, bmi), meanonly
    assert abs(r(mean)) < 1e-8
}
if _rc == 0 {
    display as result "  PASS: weight-aware centering (aweight + pweight)"
    local ++pass_count
}
else {
    display as error "  FAIL: weight-aware centering (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 13"
}

**# 14. vsref(): reference appended to main-effect labels only
local ++test_count
capture noisily {
    _fvgen_make_data
    * grp base is level 1 (Low); template "(vs. @)" appends the base label
    fvgen i.grp##c.age, vsref("(vs. @)")
    assert `"`: variable label _grp_2'"' == `"Mid (vs. Low)"'
    assert `"`: variable label _grp_3'"' == `"High (vs. Low)"'
    * interaction labels are NOT suffixed
    assert ustrpos(`"`: variable label _grpXage_2'"', "(vs.") == 0
    * custom, paren-free template
    fvgen i.grp, vsref("versus @") replace
    assert `"`: variable label _grp_2'"' == `"Mid versus Low"'
    * alllevels: the base level's own indicator is left unsuffixed
    fvgen i.grp, alllevels vsref("(vs. @)") replace
    assert `"`: variable label _grp_1'"' == `"Low"'
    assert `"`: variable label _grp_2'"' == `"Mid (vs. Low)"'
    * the reference shown honors ref()
    fvgen i.grp, ref(grp 2) vsref("(vs. @)") replace
    assert `"`: variable label _grp_1'"' == `"Low (vs. Mid)"'
    assert `"`: variable label _grp_3'"' == `"High (vs. Mid)"'
}
if _rc == 0 {
    display as result "  PASS: vsref() reference labels (template, alllevels, ref)"
    local ++pass_count
}
else {
    display as error "  FAIL: vsref() reference labels (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14"
}

**# 15. Long variable names: vsref()/center map by list, not name-keyed macro
* A name-keyed macro (_vsbase_<var> / cmap_<var>) overflows Stata's 31-char
* local-name limit; both must resolve via parallel lists for long names.
local ++test_count
capture noisily {
    _fvgen_make_data
    * 24-char factor name -> _vsbase_<name> would be 32 chars (invalid name)
    rename grp abcdefghijklmnopqrstuvwx
    local long abcdefghijklmnopqrstuvwx
    fvgen i.`long', vsref("(vs. @)")
    assert `"`: variable label _`long'_2'"' == `"Mid (vs. Low)"'
    * 24-char continuous name under center -> cmap_<name> would overflow too
    _fvgen_make_data
    rename age abcdefghijklmnopqrstuvwx
    local longc abcdefghijklmnopqrstuvwx
    fvgen c.`longc'##c.bmi, center
    confirm variable _`longc'_c
    quietly summarize _`longc'_c if !missing(`longc', bmi), meanonly
    assert abs(r(mean)) < 1e-8
}
if _rc == 0 {
    display as result "  PASS: long varnames resolve (vsref + center, no name overflow)"
    local ++pass_count
}
else {
    display as error "  FAIL: long varnames (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 15"
}

**# 16. Over-long variable label is truncated to Stata's 80-char limit
* A value label exceeding 80 characters becomes the indicator's variable label;
* _fvgen_setlabel must truncate it to exactly 80 chars (and emit a note).
local ++test_count
capture noisily {
    clear
    set obs 30
    generate byte f = 1 + mod(_n, 2)
    * a 100-character value label on the materialized (non-base) level
    local long100 ""
    forvalues i = 1/100 {
        local long100 "`long100'X"
    }
    label define fl 1 "short" 2 `"`long100'"'
    label values f fl
    fvgen i.f
    local lb : variable label _f_2
    assert ustrlen(`"`lb'"') == 80
    assert `"`lb'"' == usubstr(`"`long100'"', 1, 80)
}
if _rc == 0 {
    display as result "  PASS: over-long label truncated to 80 chars"
    local ++pass_count
}
else {
    display as error "  FAIL: label truncation (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16"
}

**# 17. Unlabeled factor falls back to a "var=level" indicator label
* When a factor carries no value label, _fvgen_partlabel labels each level
* "var=level" rather than leaving it blank.
local ++test_count
capture noisily {
    clear
    set obs 60
    generate byte grpx = 1 + mod(_n, 3)
    assert "`: value label grpx'" == ""
    fvgen i.grpx
    * base level 1 dropped; levels 2 and 3 labeled var=level
    assert `"`: variable label _grpx_2'"' == "grpx=2"
    assert `"`: variable label _grpx_3'"' == "grpx=3"
    * the fallback also flows through to interaction labels
    generate double xc = rnormal()
    fvgen i.grpx##c.xc, replace
    local li : variable label _grpxXxc_2
    assert ustrpos(`"`li'"', "grpx=2") == 1
}
if _rc == 0 {
    display as result "  PASS: unlabeled factor -> var=level fallback label"
    local ++pass_count
}
else {
    display as error "  FAIL: unlabeled-factor fallback label (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 17"
}

**# Summary
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED:`failed_tests'"
    display "RESULT: test_fvgen tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_fvgen tests=`test_count' pass=`pass_count' fail=`fail_count'"
