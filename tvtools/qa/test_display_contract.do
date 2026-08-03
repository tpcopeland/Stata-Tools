/*******************************************************************************
* test_display_contract.do
*
* Pins the console-report house style introduced at 1.13.0, and the five
* display defects the 1.13.0 capture pass found. Every check reads a NAMED log
* back with fileread(), because the defects are properties of what reached the
* console, not of anything a command returns in r().
*
* The two contract tests are the load-bearing ones:
*   - rule widths: every {hline} a command renders is 68 or 78, nothing else
*   - colon column: every "label : value" row puts its colon in one column
* Both fail on 1.12.1, which drew rules at 50, 60, 68 and 70 and padded labels
* to a different width in nearly every command.
*
* Usage:
*   cd tvtools/qa
*   do test_display_contract.do
*
* Author: Timothy P Copeland
* Date: 2026-08-02
*******************************************************************************/

clear all
set more off
set varabbrev off
version 16.0

capture log close _all
quietly log using "test_display_contract.log", replace nomsg name(dcmain)

global DATA_DIR "`c(pwd)'/data"

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools Display Contract Test Suite -- $S_DATE $S_TIME"

* --- Helpers --------------------------------------------------------------
* Every helper reads a capture log written under its own log name, so the
* suite's own log (dcmain) is never closed by a capture block.

capture program drop _dc_count_needle
program define _dc_count_needle, rclass
    syntax , logfile(string) needle(string)
    local content = fileread("`logfile'")
    local n = 0
    local pos = strpos(`"`content'"', `"`needle'"')
    while `pos' > 0 {
        local ++n
        local content = substr(`"`content'"', `pos' + 1, .)
        local pos = strpos(`"`content'"', `"`needle'"')
    }
    return scalar n = `n'
end

* Widths of every run of 3+ dashes that occupies a whole line. A rule drawn by
* {hline N} renders as exactly N dashes on its own line.
capture program drop _dc_rule_widths
program define _dc_rule_widths, rclass
    syntax , logfile(string)
    tempname fh
    local widths ""
    local bad ""
    file open `fh' using "`logfile'", read text
    file read `fh' line
    while r(eof) == 0 {
        local t `"`line'"'
        if ustrregexm(`"`t'"', "^ *-{3,} *$") {
            local w = strlen(strtrim(`"`t'"'))
            local widths "`widths' `w'"
            if !inlist(`w', 68, 78) local bad "`bad' `w'"
        }
        file read `fh' line
    }
    file close `fh'
    local _nb : word count `bad'
    return local widths "`widths'"
    return local bad "`bad'"
    return scalar n_bad = `_nb'
end

* Column of the " : " separator on every aligned label/value row. The house
* row is two leading spaces, a label padded to 28 (or 26 at indent 4), then
* " : ", so the colon always lands in the same column.
capture program drop _dc_colon_columns
program define _dc_colon_columns, rclass
    syntax , logfile(string)
    tempname fh
    local cols ""
    file open `fh' using "`logfile'", read text
    file read `fh' line
    while r(eof) == 0 {
        * Only rows the helper produced: leading spaces, then text, then " : ".
        if ustrregexm(`"`line'"', "^  [^ ].* : ") {
            local c = strpos(`"`line'"', " : ")
            local cols "`cols' `c'"
        }
        file read `fh' line
    }
    file close `fh'
    local uniq : list uniq cols
    local _nu : word count `uniq'
    local _nr : word count `cols'
    return local cols "`cols'"
    return local uniq "`uniq'"
    return scalar n_uniq = `_nu'
    return scalar n_rows = `_nr'
end

* --- Fixtures -------------------------------------------------------------
quietly {
    clear
    set seed 20260802
    set obs 60
    gen long id = _n
    gen int study_entry = mdy(1, 1, 2015) + int(runiform() * 200)
    gen int study_exit  = study_entry + 500 + int(runiform() * 400)
    format study_entry study_exit %tdCCYY/NN/DD
    gen byte female = rbinomial(1, 0.5)
    gen double age = 40 + int(runiform() * 25)
    gen double biomarker = rnormal(0, 1)
    gen byte treat = rbinomial(1, invlogit(-0.4 + 0.02 * age))
    tempfile dc_cohort
    save "`dc_cohort'"

    expand 1 + int(runiform() * 3)
    bysort id: gen int seq = _n
    bysort id: gen int dur = 40 + int(runiform() * 150)
    bysort id: gen int rx_start = study_entry if seq == 1
    bysort id: replace rx_start = rx_start[_n-1] + dur[_n-1] + 1 + int(runiform() * 40) if seq > 1
    gen int rx_stop = rx_start + dur
    gen byte drug = 0
    replace drug = 1 + int(runiform() * 2) if runiform() < 0.6
    label define dc_drug 0 "Unexposed" 1 "SSRI" 2 "SNRI"
    label values drug dc_drug
    drop if drug == 0
    keep id rx_start rx_stop drug
    tempfile dc_epi
    save "`dc_epi'"

    use "`dc_cohort'", clear
    gen int ev = study_entry + int(runiform() * 400) if runiform() < 0.4
    keep id ev
    tempfile dc_ev
    save "`dc_ev'"
}

* =========================================================================
* TEST 1: tvevent does not dump the interval variable list
* On 1.12.1 a bare `ds' printed the whole schema above the report.
* =========================================================================
local ++test_count
local _l1 "`c(pwd)'/_dc_probe1.log"
capture noisily {
    quietly log using "`_l1'", replace text nomsg name(dc1)
    use "`dc_cohort'", clear
    quietly tvexpose using "`dc_epi'", id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) entry(study_entry) exit(study_exit) ///
        keepdates frameout(dcf1)
    use "`dc_ev'", clear
    noisily tvevent, frame(dcf1) id(id) date(ev) generate(dc_out) ///
        start(rx_start) stop(rx_stop)
    quietly log close dc1
}
local _rc1 = _rc
capture log close dc1
if `_rc1' == 0 {
    * The leak is a whole line made only of the interval dataset's variable
    * names, whitespace-separated, with no label and no punctuation. Matching
    * a fixed needle is not safe: ds pads each name to a column whose width
    * depends on the longest name in the schema, so the exact spacing moves
    * with the fixture.
    tempname fh1
    local leaked = 0
    local _nm "(id|rx_start|rx_stop|tv_drug|study_entry|study_exit|dc_out)"
    local _pat "`_nm'([ ]+`_nm')+"
    file open `fh1' using "`_l1'", read text
    file read `fh1' line
    while r(eof) == 0 {
        local t `"`line'"'
        if ustrregexm(`"`t'"', "^ *`_pat' *$") {
            local ++leaked
        }
        file read `fh1' line
    }
    file close `fh1'
    if `leaked' == 0 {
        display as result "  PASS: tvevent does not dump the interval schema"
        local ++pass_count
    }
    else {
        display as error "  FAIL: tvevent leaked a bare variable list (`leaked' hit(s))"
        local ++fail_count
        local failed_tests "`failed_tests' tvevent_ds_leak"
    }
}
else {
    display as error "  FAIL: tvevent leak probe errored (rc=`_rc1')"
    local ++fail_count
    local failed_tests "`failed_tests' tvevent_ds_leak"
}

* =========================================================================
* TEST 2: tvband and tvsplit do not print raw band cutpoints
* On 1.12.1 an unquieted `levelsof' in _tvband_split printed e.g. "2015 2020".
* =========================================================================
local ++test_count
local _l2 "`c(pwd)'/_dc_probe2.log"
capture noisily {
    quietly log using "`_l2'", replace text nomsg name(dc2)
    quietly frame copy dcf1 dcf2, replace
    frame dcf2 {
        noisily tvband, id(id) start(rx_start) stop(rx_stop) type(calendar) ///
            width(5) anchor(2000) generate(dc_band) noisily
    }
    quietly log close dc2
}
local _rc2 = _rc
capture log close dc2
if `_rc2' == 0 {
    * A leaked cutpoint line is a whole line of bare 4-digit years.
    tempname fh2
    local leak2 = 0
    file open `fh2' using "`_l2'", read text
    file read `fh2' line
    while r(eof) == 0 {
        local t `"`line'"'
        * One band level leaks as a single bare year, so the count of years
        * on the line must not be part of the test.
        if ustrregexm(`"`t'"', "^ *[0-9]{4}([ ]+[0-9]{4})* *$") {
            local ++leak2
        }
        file read `fh2' line
    }
    file close `fh2'
    if `leak2' == 0 {
        display as result "  PASS: tvband does not print raw band cutpoints"
        local ++pass_count
    }
    else {
        display as error "  FAIL: tvband leaked `leak2' cutpoint line(s)"
        local ++fail_count
        local failed_tests "`failed_tests' tvband_levelsof_leak"
    }
}
else {
    display as error "  FAIL: tvband leak probe errored (rc=`_rc2')"
    local ++fail_count
    local failed_tests "`failed_tests' tvband_levelsof_leak"
}

* =========================================================================
* TEST 3: rule-width contract -- every rendered rule is 68 or 78
* On 1.12.1 this suite's own capture rendered 50, 60, 68 and 70.
* =========================================================================
local ++test_count
local _l3 "`c(pwd)'/_dc_probe3.log"
capture noisily {
    quietly log using "`_l3'", replace text nomsg name(dc3)
    use "`dc_cohort'", clear
    noisily tvexpose using "`dc_epi'", id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) entry(study_entry) exit(study_exit) ///
        keepvars(age female biomarker treat) ///
        keepdates flow frameout(dcf3) replace
    frame dcf3 {
        noisily tvdiagnose, id(id) start(rx_start) stop(rx_stop) ///
            exposure(tv_drug) entry(study_entry) exit(study_exit) all
    }
    quietly log close dc3
}
local _rc3 = _rc
capture log close dc3
if `_rc3' == 0 {
    _dc_rule_widths, logfile("`_l3'")
    local nbad = r(n_bad)
    local badw "`r(bad)'"
    if `nbad' == 0 {
        display as result "  PASS: every rendered rule is 68 or 78"
        local ++pass_count
    }
    else {
        display as error "  FAIL: `nbad' rule(s) at off-contract width(s):`badw'"
        local ++fail_count
        local failed_tests "`failed_tests' rule_width_contract"
    }
}
else {
    display as error "  FAIL: rule-width probe errored (rc=`_rc3')"
    local ++fail_count
    local failed_tests "`failed_tests' rule_width_contract"
}

* =========================================================================
* TEST 4: colon-column contract -- one colon column across all commands
* On 1.12.1 each command padded its labels to its own width, so the same
* capture produced colons in many different columns.
* =========================================================================
local ++test_count
if `_rc3' == 0 {
    _dc_colon_columns, logfile("`_l3'")
    local nuniq = r(n_uniq)
    local nrows = r(n_rows)
    local uniqc "`r(uniq)'"
    if `nrows' == 0 {
        display as error "  FAIL: no aligned rows found -- probe is blind"
        local ++fail_count
        local failed_tests "`failed_tests' colon_column_contract"
    }
    else if `nuniq' == 1 {
        display as result "  PASS: `nrows' aligned rows share one colon column (`uniqc')"
        local ++pass_count
    }
    else {
        display as error "  FAIL: `nrows' rows use `nuniq' colon columns:`uniqc'"
        local ++fail_count
        local failed_tests "`failed_tests' colon_column_contract"
    }
}
else {
    display as error "  FAIL: colon-column probe errored (rc=`_rc3')"
    local ++fail_count
    local failed_tests "`failed_tests' colon_column_contract"
}

* =========================================================================
* TEST 5: tvdiagnose percent column is formatted, not a raw double
* On 1.12.1 the person-time table listed shares as e.g. 11.542579.
* =========================================================================
local ++test_count
if `_rc3' == 0 {
    * A raw stored double shows 4+ decimals; the formatted column shows one.
    tempname fh5
    local rawdec = 0
    file open `fh5' using "`_l3'", read text
    file read `fh5' line
    while r(eof) == 0 {
        if ustrregexm(`"`line'"', "[0-9]\.[0-9]{4,}") ///
            & strpos(`"`line'"', "|") > 0 local ++rawdec
        file read `fh5' line
    }
    file close `fh5'
    if `rawdec' == 0 {
        display as result "  PASS: person-time table prints formatted shares"
        local ++pass_count
    }
    else {
        display as error "  FAIL: `rawdec' table row(s) print unformatted doubles"
        local ++fail_count
        local failed_tests "`failed_tests' pct_format"
    }
}
else {
    display as error "  FAIL: percent-format probe errored (rc=`_rc3')"
    local ++fail_count
    local failed_tests "`failed_tests' pct_format"
}

* =========================================================================
* TEST 6: tvweight does not print a raw exposure level list, and closes
* every block it opens at the same width.
* =========================================================================
local ++test_count
local _l6 "`c(pwd)'/_dc_probe6.log"
capture noisily {
    quietly log using "`_l6'", replace text nomsg name(dc6)
    frame dcf3 {
        noisily tvweight treat, covariates(age female biomarker) id(id) ///
            stabilized balance
    }
    quietly log close dc6
}
local _rc6 = _rc
capture log close dc6
if `_rc6' == 0 {
    _dc_rule_widths, logfile("`_l6'")
    local nbad6 = r(n_bad)
    local badw6 "`r(bad)'"
    local widths6 "`r(widths)'"
    * Every tvweight rule is the wide one, because the report wraps a logit
    * table. A 68 here is the 1.12.1 mismatched-pair defect returning.
    local mixed = 0
    foreach w of local widths6 {
        if `w' != 78 local mixed = 1
    }
    if `nbad6' == 0 & `mixed' == 0 {
        display as result "  PASS: tvweight rules are uniformly 78"
        local ++pass_count
    }
    else {
        display as error "  FAIL: tvweight rule widths:`widths6' (off-contract:`badw6')"
        local ++fail_count
        local failed_tests "`failed_tests' tvweight_rule_pairs"
    }
}
else {
    display as error "  FAIL: tvweight rule probe errored (rc=`_rc6')"
    local ++fail_count
    local failed_tests "`failed_tests' tvweight_rule_pairs"
}

* =========================================================================
* TEST 7: _tvtools_row rejects contradictory and out-of-range input
* =========================================================================
local ++test_count
local neg_ok = 1
capture _tvtools_row "x", value("a") num(1)
if _rc != 198 local neg_ok = 0
capture _tvtools_row "x", pad(0)
if _rc != 198 local neg_ok = 0
capture _tvtools_row "x", indent(-1)
if _rc != 198 local neg_ok = 0
capture _tvtools_rule, width(50)
if _rc != 198 local neg_ok = 0
if `neg_ok' {
    display as result "  PASS: display helpers reject invalid input with r(198)"
    local ++pass_count
}
else {
    display as error "  FAIL: a display-helper guard did not fire"
    local ++fail_count
    local failed_tests "`failed_tests' helper_guards"
}

* =========================================================================
* TEST 8: a label containing a comma is not re-parsed as options
* _tvtools_row peels its label with gettoken, so "id, entry, exit" is a label.
* =========================================================================
local ++test_count
local _l8 "`c(pwd)'/_dc_probe8.log"
capture noisily {
    quietly log using "`_l8'", replace text nomsg name(dc8)
    noisily _tvtools_row "id, entry, exit", value("a b c")
    quietly log close dc8
}
local _rc8 = _rc
capture log close dc8
if `_rc8' == 0 {
    _dc_count_needle, logfile("`_l8'") needle("id, entry, exit")
    if r(n) > 0 {
        display as result "  PASS: a comma-bearing label survives the parser"
        local ++pass_count
    }
    else {
        display as error "  FAIL: comma-bearing label was mangled"
        local ++fail_count
        local failed_tests "`failed_tests' comma_label"
    }
}
else {
    display as error "  FAIL: comma-label probe errored (rc=`_rc8')"
    local ++fail_count
    local failed_tests "`failed_tests' comma_label"
}

* --- Cleanup ---------------------------------------------------------------
capture frame drop dcf1
capture frame drop dcf2
capture frame drop dcf3
capture erase "`_l1'"
capture erase "`_l2'"
capture erase "`_l3'"
capture erase "`_l6'"
capture erase "`_l8'"

**# SUMMARY
display _newline
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_display_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
