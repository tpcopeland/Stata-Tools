* test_kmplot_output.do
* Console-output and group-label regression tests for kmplot
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-15
*
* O1-O3 pin a clean console: a kmplot call prints its own summary and
* "... saved to:" lines and nothing else.  censorthin() used to leak
* "(N missing values generated)", and export()/saving()/risksaving() echoed
* Stata's own "(file x not found)" / "file x saved" lines ahead of kmplot's.
* O4 checks that errors from those writers are still shown.
* L1-L2 pin the labels of an unlabelled non-integer numeric by(): a float 0.1
* used to read "g=.1000000014901161" in the legend, risk table and returns.
*
* Run from kmplot/qa:  stata-mp -b do test_kmplot_output.do

clear all
version 16.0
set varabbrev off
set linesize 255
local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

* Lines a kmplot call may print.  Everything else between the markers fails.
capture program drop _km_out_check
program define _km_out_check, rclass
    version 16.0
    syntax using/
    local allowed `""Kaplan-Meier plot" "  Observations: " "  Groups: " "  CI transform: " "  Log-rank " "  Median (" "Graph saved to: " "Curve data saved to: " "Risk-table data saved to: ""'
    tempname fh
    local inside 0
    local n_out 0
    local n_bad 0
    local pending_blank 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "KMOUT_BEGIN") == 1 local inside 1
        else if strpos(`"`macval(line)'"', "KMOUT_END") == 1 local inside 0
        else if `inside' {
            local is_cmd = (substr(`"`macval(line)'"', 1, 2) == ". " | ///
                substr(`"`macval(line)'"', 1, 2) == "> " | `"`macval(line)'"' == ".")
            local is_blank = (strtrim(`"`macval(line)'"') == "")
            * Stata's log puts one blank line before each command echo; any
            * other blank line is output.
            if `pending_blank' & !`is_cmd' {
                local ++n_bad
                display as error "unexpected blank output line"
            }
            local pending_blank = `is_blank'
            if !`is_cmd' & !`is_blank' {
                local ok 0
                foreach a of local allowed {
                    if strpos(`"`macval(line)'"', `"`a'"') == 1 local ok 1
                }
                if `ok' local ++n_out
                else {
                    local ++n_bad
                    display as error `"unexpected output line: [`macval(line)']"'
                }
            }
        }
        file read `fh' line
    }
    file close `fh'
    return scalar n_out = `n_out'
    return scalar n_bad = `n_bad'
end

**# O1-O3: every route that writes or thins prints only kmplot's own lines
local logf "`c(tmpdir)'/kmplot_output_o1.log"
local png "`c(tmpdir)'/kmplot_output_o1.png"
local svg "`c(tmpdir)'/kmplot_output_o1.svg"
local cdta "`c(tmpdir)'/kmplot_output_curve.dta"
local rdta "`c(tmpdir)'/kmplot_output_risk.dta"
foreach f in png svg cdta rdta {
    capture erase "``f''"
}
sysuse cancer, clear
quietly stset studytime, failure(died)
capture log close kmout
log using "`logf'", text replace name(kmout)
display "KMOUT_BEGIN"
kmplot, name(kmout, replace)
kmplot, by(drug) ci risktable median medianannotate censor pvalue ///
    export("`png'", replace) name(kmout, replace)
kmplot, by(drug) failure ci cistyle(line) citransform(plain) landmark(10) ///
    censor censorthin(3) export("`svg'") saving("`cdta'") name(kmout, replace)
kmplot, by(drug) risktable riskevents risksaving("`rdta'") ///
    xlabel(0(10)40) name(kmout, replace)
kmplot, by(drug) censor censorthin(2) saving("`cdta'", replace) ///
    risksaving("`rdta'", replace) name(kmout, replace)
display "KMOUT_END"
log close kmout

local ++test_count
capture noisily {
    _km_out_check using "`logf'"
    assert r(n_bad) == 0
    * the summary lines themselves are present, so the check is not vacuous
    assert !missing(r(n_out))
    assert r(n_out) >= 20
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: O1 only kmplot's own lines are printed"
}
else {
    local ++fail_count
    display as error "FAIL: O1 only kmplot's own lines are printed (rc=" _rc ")"
}

local ++test_count
capture noisily {
    foreach p in "missing values generated" "real change" "not found)" ///
        "written in" "saved as" ".dta saved" "Failure _d:" "Analysis time _t:" {
        _kmplot_assert_file_not_contains using "`logf'", pattern("`p'")
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: O2 no Stata chatter from censorthin, export, or saves"
}
else {
    local ++fail_count
    display as error "FAIL: O2 no Stata chatter from censorthin, export, or saves (rc=" _rc ")"
}

local ++test_count
capture noisily {
    _kmplot_assert_file_contains using "`logf'", pattern("Graph saved to: `png'")
    _kmplot_assert_file_contains using "`logf'", pattern("Graph saved to: `svg'")
    _kmplot_assert_file_contains using "`logf'", pattern("Curve data saved to: `cdta'")
    _kmplot_assert_file_contains using "`logf'", pattern("Risk-table data saved to: `rdta'")
    confirm file "`png'"
    confirm file "`svg'"
    confirm file "`cdta'"
    confirm file "`rdta'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: O3 files are written and reported once"
}
else {
    local ++fail_count
    display as error "FAIL: O3 files are written and reported once (rc=" _rc ")"
}

**# O4: write failures still show Stata's error and keep the returns
local ++test_count
capture noisily {
    local logf4 "`c(tmpdir)'/kmplot_output_o4.log"
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    capture log close kmout4
    log using "`logf4'", text replace name(kmout4)
    * curve file exists and replace was not given
    capture noisily kmplot, by(drug) saving("`cdta'") name(kmout, replace)
    local rc_save = _rc
    local n_save = r(N)
    * graph export rejects an unknown suboption
    capture noisily kmplot, by(drug) export("`png'", replace bogusopt) name(kmout, replace)
    local rc_exp = _rc
    local n_exp = r(N)
    * risk file exists and replace was not given
    capture noisily kmplot, by(drug) risksaving("`rdta'") name(kmout, replace)
    local rc_risk = _rc
    log close kmout4
    assert `rc_save' == 602
    assert `rc_exp' == 198
    assert `rc_risk' == 602
    assert `n_save' == 48 & `n_exp' == 48
    _kmplot_assert_file_contains using "`logf4'", pattern("kmplot_output_curve.dta already exists")
    _kmplot_assert_file_contains using "`logf4'", pattern("kmplot_output_risk.dta already exists")
    _kmplot_assert_file_contains using "`logf4'", pattern("bogusopt not allowed")
    erase "`logf4'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: O4 write errors stay visible"
}
else {
    local ++fail_count
    display as error "FAIL: O4 write errors stay visible (rc=" _rc ")"
}
foreach f in logf png svg cdta rdta {
    capture erase "``f''"
}

**# L1: unlabelled float levels read in the variable's display format
local ++test_count
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    generate float g = cond(drug == 1, 0.1, cond(drug == 2, 0.7, 1.3))
    local rdta "`c(tmpdir)'/kmplot_output_l1.dta"
    kmplot, by(g) risksaving("`rdta'", replace) name(kmout, replace)
    assert `"`r(group_labels)'"' == "g=.1 | g=.7 | g=1.3"
    use "`rdta'", clear
    assert group_label == "g=.1" if group == 1
    assert group_label == "g=.7" if group == 2
    assert group_label == "g=1.3" if group == 3
    erase "`rdta'"
    * a date format is honoured
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    generate td = mdy(1, drug, 2020)
    format td %td
    kmplot, by(td) name(kmout, replace)
    assert `"`r(group_labels)'"' == "td=01jan2020 | td=02jan2020 | td=03jan2020"
    * integers are unchanged
    generate int d = drug
    kmplot, by(d) name(kmout, replace)
    assert `"`r(group_labels)'"' == "d=1 | d=2 | d=3"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: L1 numeric by() labels use the display format"
}
else {
    local ++fail_count
    display as error "FAIL: L1 numeric by() labels use the display format (rc=" _rc ")"
}

**# L2: a format that would merge levels falls back to full precision
local ++test_count
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    generate float g = cond(drug == 1, 0.1, cond(drug == 2, 0.7, 1.3))
    format g %3.0f
    kmplot, by(g) name(kmout, replace)
    local gl `"`r(group_labels)'"'
    assert r(n_groups) == 3
    assert `"`gl'"' == "g=.1000000014901161 | g=.699999988079071 | g=1.299999952316284"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: L2 merged formatted levels keep distinct labels"
}
else {
    local ++fail_count
    display as error "FAIL: L2 merged formatted levels keep distinct labels (rc=" _rc ")"
}

capture graph drop kmout

**# Summary
display "RESULT: test_kmplot_output tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    exit 1
}
