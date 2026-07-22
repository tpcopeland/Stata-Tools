* test_deep_audit_output.do - fail-first output-contract regressions

clear all
set more off
set varabbrev off
version 17.0

capture log close _deepoutput
log using "test_deep_audit_output.log", replace text name(_deepoutput) nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local outdir "`c(tmpdir)'/`c(pid)'_tabtools_deep_audit"
capture mkdir "`outdir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

capture findfile _tabtools_common.ado
if _rc == 0 run "`r(fn)'"

**# M10: confidence-level calculations, labels, and provenance

local ++test_count
clear
set obs 100
generate byte gold = _n <= 50
generate byte test = (gold & _n <= 40) | (!gold & _n <= 55)
set level 95
capture frame drop deep_diag90
capture noisily diagtab test gold, level(90) digits(6) ///
    frame(deep_diag90, replace)
local diag_rc = _rc
local diag_level = cond(`diag_rc' == 0, r(ci_level), .)
local diag_lb = cond(`diag_rc' == 0, r(sensitivity_lb), .)
quietly cii proportions 50 40, wilson level(90)
local diag_want = r(lb)

capture frame drop deep_cross90
capture noisily crosstab test gold, or level(90) digits(6) ///
    frame(deep_cross90, replace)
local cross_rc = _rc
local cross_level = cond(`cross_rc' == 0, r(ci_level), .)
capture noisily {
    assert `diag_rc' == 0
    assert `diag_level' == 90
    assert reldif(`diag_lb', `diag_want') < 1e-12
    frame deep_diag90: count if c3 == "(90% CI)"
    frame deep_diag90: assert r(N) == 1
    assert `cross_rc' == 0
    assert `cross_level' == 90
    frame deep_cross90: count if strpos(c1, "90% CI") > 0
    frame deep_cross90: assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS M10a: calculated intervals share one explicit level contract"
    local ++pass_count
}
else {
    display as error "  FAIL M10a: calculated CI level contract (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
sysuse auto, clear
set level 90
collect clear
collect: regress price mpg
set level 95
capture frame drop deep_reg90
capture noisily regtab, level(90) frame(deep_reg90, replace) noint
local reg_rc = _rc
local reg_level = cond(`reg_rc' == 0, r(ci_level), .)
local reg_methods ""
if `reg_rc' == 0 local reg_methods `"`r(methods)'"'
local reg_char ""
if `reg_rc' == 0 frame deep_reg90: local reg_char : char _dta[tabtools_ci_level]

matrix E = (1.25, .90, 1.70, .25)
matrix rownames E = Treatment
capture frame drop deep_effect90
capture noisily effecttab, from(E) level(90) frame(deep_effect90, replace)
local effect_rc = _rc
local effect_level = cond(`effect_rc' == 0, r(ci_level), .)
local effect_methods ""
if `effect_rc' == 0 local effect_methods `"`r(methods)'"'
local effect_char ""
if `effect_rc' == 0 frame deep_effect90: local effect_char : char _dta[tabtools_ci_level]
capture noisily {
    assert `reg_rc' == 0
    assert `reg_level' == 90
    assert "`reg_char'" == "90"
    assert strpos("`reg_methods'", "90%") > 0
    frame deep_reg90: assert c2[3] == "90% CI"
    assert `effect_rc' == 0
    assert `effect_level' == 90
    assert "`effect_char'" == "90"
    assert strpos("`effect_methods'", "90%") > 0
    frame deep_effect90: assert c2[3] == "(90% CI)"
}
if _rc == 0 {
    display as result "  PASS M10b: stored collect/matrix levels survive later set level changes"
    local ++pass_count
}
else {
    display as error "  FAIL M10b: stored CI provenance (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
tempfile rate90
clear
set obs 2
generate byte exposure = _n - 1
generate double _D = 10 * _n
generate double _Y = 1000 * _n
generate double _Rate = _D / _Y
generate double _Lower = _Rate * .80
generate double _Upper = _Rate * 1.20
label variable _Lower "Lower 90% confidence limit"
label variable _Upper "Upper 90% confidence limit"
save "`rate90'.dta", replace
clear
capture frame drop deep_strate90
capture noisily stratetab, using("`rate90'") outcomes(1) level(90) ///
    outcomeids(deep_rate) ///
    frame(deep_strate90, replace)
local strate_rc = _rc
local strate_level = cond(`strate_rc' == 0, r(ci_level), .)
local strate_outcome_ids ""
local strate_methods ""
if `strate_rc' == 0 local strate_outcome_ids `"`r(outcome_ids)'"'
if `strate_rc' == 0 local strate_methods `"`r(methods)'"'
local strate_char ""
if `strate_rc' == 0 frame deep_strate90: local strate_char : char _dta[tabtools_ci_level]
capture noisily {
    assert `strate_rc' == 0
    assert `strate_level' == 90
    assert "`strate_char'" == "90"
    assert "`strate_outcome_ids'" == "deep_rate"
    assert strpos("`strate_methods'", "90%") > 0
    local _strate_ci_hits = 0
    frame deep_strate90 {
        foreach v of varlist c* {
            count if strpos(`v', "90% CI") > 0
            local _strate_ci_hits = `_strate_ci_hits' + r(N)
        }
    }
    assert `_strate_ci_hits' == 1
}
if _rc == 0 {
    display as result "  PASS M10c: stratetab reads saved interval provenance"
    local ++pass_count
}
else {
    display as error "  FAIL M10c: stratetab CI provenance (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
sysuse auto, clear
set level 90
collect clear
collect: regress price mpg
capture frame drop deep_src90
regtab, frame(deep_src90, replace) noint
set level 95
collect clear
collect: regress price mpg
capture frame drop deep_src95
regtab, frame(deep_src95, replace) noint
capture noisily comptab deep_src90 deep_src95, rows(1 \ 1)
local mixed_level_rc = _rc
capture noisily assert `mixed_level_rc' == 198
if _rc == 0 {
    display as result "  PASS M10d: composites reject mixed CI provenance"
    local ++pass_count
}
else {
    display as error "  FAIL M10d: mixed composite CI levels (rc=`=_rc')"
    local ++fail_count
}

**# M11-M14: values, identities, and high-precision rendering

local ++test_count
matrix P = (1.25, .90, 1.70, .999)
matrix rownames P = NearOne
capture frame drop deep_pnear
effecttab, from(P) frame(deep_pnear, replace) highpdp(2)
capture noisily frame deep_pnear: assert c3[4] == ">0.99"
if _rc == 0 {
    display as result "  PASS M11: near-one p-values are not understated"
    local ++pass_count
}
else {
    display as error "  FAIL M11: near-one p-value comparator (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
matrix Z = (0, ., ., .5 \ 0, -.1, .1, 1)
matrix rownames Z = ExactZero ZeroWithCI
capture frame drop deep_zero
effecttab, from(Z) frame(deep_zero, replace)
capture noisily {
    frame deep_zero: assert c1[4] == "0.00"
    frame deep_zero: assert c3[4] == "0.50"
    frame deep_zero: assert c1[5] == "0.00"
    frame deep_zero: assert c2[5] == "(-0.10, 0.10)"
}
if _rc == 0 {
    display as result "  PASS M12: numeric zero is never inferred to be a reference row"
    local ++pass_count
}
else {
    display as error "  FAIL M12: zero/reference identity (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
clear
input byte category
1
1
2
2
end
label define reserved_total 1 "Total" 2 "Other"
label values category reserved_total
collect clear
collect: table category, statistic(frequency)
capture frame drop deep_total_label
desctab, nototals frame(deep_total_label, replace)
local real_total_n = 0
frame deep_total_label {
    count if strtrim(A) == "Total"
    local real_total_n = r(N)
}

clear
input byte category
1
1
2
.
end
label define reserved_missing 1 "Missing" 2 "Other"
label values category reserved_missing
collect clear
collect: table category, statistic(frequency) missing
capture frame drop deep_missing_label
desctab, nomissing frame(deep_missing_label, replace)
local real_missing_n = 0
frame deep_missing_label {
    count if strtrim(A) == "Missing"
    local real_missing_n = r(N)
}
capture noisily {
    assert `real_total_n' == 1
    assert `real_missing_n' == 1
}
if _rc == 0 {
    display as result "  PASS M13: total/missing filters use raw collect identity"
    local ++pass_count
}
else {
    display as error "  FAIL M13: reserved display labels (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
sysuse auto, clear
capture frame drop deep_corr6
corrtab price mpg weight, digits(6) frame(deep_corr6, replace)
local corr_ok = 0
frame deep_corr6 {
    foreach v of varlist c* {
        count if `v' == "1.000000"
        local corr_ok = `corr_ok' | r(N) > 0
    }
}

collect clear
collect: table foreign, statistic(mean price) statistic(sd price)
capture frame drop deep_desc6
desctab, digits(6) frame(deep_desc6, replace)
local desc_shell = 0
frame deep_desc6 {
    count if regexm(strtrim(c1), "^[%(), -]+$")
    local desc_shell = r(N)
}

clear
set obs 100
generate byte gold = _n <= 50
generate byte test = (gold & _n <= 40) | (!gold & _n <= 55)
capture frame drop deep_diag6
diagtab test gold, digits(6) frame(deep_diag6, replace)
local diag_shell = 0
frame deep_diag6 {
    foreach v of varlist c* {
        count if inlist(strtrim(`v'), "%", "(, )", "(,)")
        local diag_shell = `diag_shell' + r(N)
    }
}

capture frame drop deep_cross6
crosstab test gold, or digits(6) frame(deep_cross6, replace)
local cross_ok = 0
frame deep_cross6 {
    count if strpos(c1, "OR = ") > 0 & strpos(c1, "(95% CI:") > 0
    local cross_ok = r(N) == 1
}

sysuse cancer, clear
stset studytime, failure(died)
capture frame drop deep_surv6
survtab, times(10) digits(6) frame(deep_surv6, replace)
local surv_shell = 0
frame deep_surv6 {
    count if regexm(strtrim(c1), "^[%(), -]+$") & _n >= 3
    local surv_shell = r(N)
}
capture noisily {
    assert `corr_ok'
    assert `desc_shell' == 0
    assert `diag_shell' == 0
    assert `cross_ok'
    assert `surv_shell' == 0
}
if _rc == 0 {
    display as result "  PASS M14: digits(6) retains finite numeric output"
    local ++pass_count
}
else {
    display as error "  FAIL M14: high-precision rendering (rc=`=_rc')"
    local ++fail_count
}

**# M17-M21: requested output, Markdown, sparse cells, and text

local ++test_count
clear
input byte outcome byte exposure
0 1
1 1
0 1
1 1
end
capture noisily crosstab outcome exposure, trend
local onelevel_rc = _rc

clear
input byte outcome byte exposure
0 1
0 2
0 3
0 4
end
capture noisily crosstab outcome exposure, cochran
local constant_rc = _rc

clear
input byte outcome byte exposure
0 1
0 1
0 2
1 2
1 3
1 3
end
capture noisily crosstab outcome exposure, trend
local valid_rc = _rc
local valid_p = cond(`valid_rc' == 0, r(p_trend), .)
capture noisily {
    assert `onelevel_rc' == 498
    assert `constant_rc' == 498
    assert `valid_rc' == 0
    assert `valid_p' < .
}
if _rc == 0 {
    display as result "  PASS M17: requested trend tests either return a statistic or fail"
    local ++pass_count
}
else {
    display as error "  FAIL M17: silent trend omission (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
matrix M = (1, 2 \ 3, 4)
matrix rownames M = row1 row2
matrix colnames M = col1 col2
local footmd "`outdir'/deep_footnote.md"
local noheadmd "`outdir'/deep_noheader.md"
capture erase "`footmd'"
capture erase "`noheadmd'"
puttab, matrix(M) markdown("`footmd'") footnote("Unique footnote")
puttab, matrix(M) markdown("`noheadmd'") noheader
tempname fh
file open `fh' using "`footmd'", read text
local foot_count = 0
file read `fh' line
while r(eof) == 0 {
    if strpos(`"`line'"', "Unique footnote") local ++foot_count
    file read `fh' line
}
file close `fh'
file open `fh' using "`noheadmd'", read text
file read `fh' nohead_first
file close `fh'
capture noisily {
    assert `foot_count' == 1
    assert strpos(`"`nohead_first'"', "c1") == 0
    assert strpos(`"`nohead_first'"', "c2") == 0
    assert regexm(`"`nohead_first'"', "^[| ]+$")
}
if _rc == 0 {
    display as result "  PASS M18: Markdown footnotes and noheader obey their contracts"
    local ++pass_count
}
else {
    display as error "  FAIL M18: Markdown footnote/noheader (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
sysuse cancer, clear
stset studytime, failure(died)
capture frame drop deep_surv_no_median
survtab, times(10) by(drug) level(90) frame(deep_surv_no_median, replace)
local _surv_level = r(ci_level)
frame deep_surv_no_median: local _surv_char : char _dta[tabtools_ci_level]
local implicit_median = 0
frame deep_surv_no_median {
    ds, has(type string)
    foreach v of varlist `r(varlist)' {
        count if strpos(lower(`v'), "median") > 0
        local implicit_median = `implicit_median' + r(N)
    }
}
capture frame drop deep_surv_median
survtab, times(10) by(drug) median level(90) frame(deep_surv_median, replace)
local explicit_median = 0
frame deep_surv_median {
    ds, has(type string)
    foreach v of varlist `r(varlist)' {
        count if strpos(lower(`v'), "median") > 0
        local explicit_median = `explicit_median' + r(N)
    }
}
capture noisily {
    assert `implicit_median' == 0
    assert `explicit_median' > 0
    assert `_surv_level' == 90
    assert "`_surv_char'" == "90"
}
if _rc == 0 {
    display as result "  PASS M19: median remains opt-in under by()"
    local ++pass_count
}
else {
    display as error "  FAIL M19: implicit median rows (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
clear
input byte row byte col byte event
0 0 1
0 0 0
1 1 1
1 1 1
end
collect clear
collect: table row col, statistic(sum event) statistic(count event) statistic(mean event)
capture frame drop deep_sparse_compose
desctab, compose(events_n_pct) frame(deep_sparse_compose, replace)
local shell_count = 0
frame deep_sparse_compose {
    foreach v of varlist c* {
        count if regexm(strtrim(`v'), "^[ /()-]+$") & strtrim(`v') != ""
        local shell_count = `shell_count' + r(N)
    }
}
capture noisily assert `shell_count' == 0
if _rc == 0 {
    display as result "  PASS M20: structurally empty composite cells are blank"
    local ++pass_count
}
else {
    display as error "  FAIL M20: delimiter-only composite cells (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
local embedded = "He said " + char(34) + "yes" + char(34)
capture noisily _tabtools_strip_outer_quotes, text(`"`embedded'"')
local stripped `"`r(text)'"'
local wrapped = char(34) + "outer" + char(34)
capture noisily _tabtools_strip_outer_quotes, text(`"`wrapped'"')
local unwrapped `"`r(text)'"'
capture noisily {
    assert `"`stripped'"' == `"`embedded'"'
    assert `"`unwrapped'"' == "outer"
}
if _rc == 0 {
    display as result "  PASS M21: only one balanced outer quote layer is removed"
    local ++pass_count
}
else {
    display as error "  FAIL M21: embedded quotation preservation (rc=`=_rc')"
    local ++fail_count
}

set level 95
display as text ""
display "RESULT: test_deep_audit_output tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _deepoutput
if `fail_count' > 0 exit 9
exit, clear
