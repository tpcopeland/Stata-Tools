clear all
set more off
version 16.0

* test_datamap_privacy.do - Regression tests for the exclude() privacy contract
* Generated: 2026-06-16 (datamap 1.1.1)
* Guards the v1.1.1 fix: excluded variables must never leak their values,
* cardinality, max length, or value-label coding in ANY output surface
* (Binary section, QUICK REFERENCE, JSON, or VALUE LABEL DEFINITIONS).
* Also includes a structural JSON-validity check, and the 1.8.0 maskrare
* contract: no printed count from 1 to m-1 in gate messages, violations(),
* the profile blocks, the patterns table, or the ledger.

local test_count = 0
local pass_count = 0
local fail_count = 0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force

* Helper: does a file contain a needle anywhere?
capture program drop _priv_file_contains
program define _priv_file_contains, rclass
    version 16.0
    syntax using/ , NEEDLE(string)
    tempname fh
    local found 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`needle'"') > 0 local found 1
        file read `fh' line
    }
    file close `fh'
    return scalar found = `found'
end

* Helper: structural JSON validity (balanced braces/brackets, no trailing commas)
capture program drop _priv_json_ok
program define _priv_json_ok, rclass
    version 16.0
    syntax using/
    tempname fh
    local nopen 0
    local nclose 0
    local nbopen 0
    local nbclose 0
    local trailing 0
    local blob ""
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        local t = strtrim(`"`macval(line)'"')
        local nopen   = `nopen'   + length(`"`t'"') - length(subinstr(`"`t'"', "{", "", .))
        local nclose  = `nclose'  + length(`"`t'"') - length(subinstr(`"`t'"', "}", "", .))
        local nbopen  = `nbopen'  + length(`"`t'"') - length(subinstr(`"`t'"', "[", "", .))
        local nbclose = `nbclose' + length(`"`t'"') - length(subinstr(`"`t'"', "]", "", .))
        local blob `"`blob'`t'"'
        file read `fh' line
    }
    file close `fh'
    if strpos(`"`blob'"', ",}") > 0 local trailing 1
    if strpos(`"`blob'"', ",]") > 0 local trailing 1
    return scalar braces_ok   = (`nopen' == `nclose')
    return scalar brackets_ok = (`nbopen' == `nbclose')
    return scalar trailing    = `trailing'
end

* === Adversarial fixture: sensitive vars the user excludes for privacy ===
tempfile pbase ptxt pjson ptxt2
local pdta "`pbase'.dta"
clear
set obs 50
gen double patient_id = _n
gen byte hiv_status = mod(_n, 2)
label define yn 0 "Negative" 1 "Positive"
label values hiv_status yn
gen byte sex = mod(_n, 2)
label define sexl 0 "Female" 1 "Male"
label values sex sexl
gen str20 mrn = "MRN" + string(_n, "%03.0f")
* Shared value label across an excluded var (arm) and a kept var (study_arm)
gen byte arm = mod(_n, 2)
gen byte study_arm = mod(_n, 2)
label define arml 0 "Control" 1 "Treated"
label values arm arml
label values study_arm arml
label variable patient_id "Identifier"
label variable hiv_status "HIV status (sensitive)"
save "`pdta'", replace

* ============================================================
* Test 1: excluded binary variable does NOT leak via the Binary section
*         (frequencies print value labels, so the labels must be absent)
* ============================================================
local ++test_count
capture {
    datamap, single("`pdta'") output("`ptxt'") exclude(hiv_status patient_id mrn) detect(binary)
    * The sensitive coding "Negative"/"Positive" belongs only to the excluded
    * hiv_status; it must not appear anywhere (binary freqs or value labels).
    _priv_file_contains using "`ptxt'", needle("Negative")
    assert r(found) == 0
    _priv_file_contains using "`ptxt'", needle("Positive")
    assert r(found) == 0
    * The kept binary var (sex) is still documented.
    _priv_file_contains using "`ptxt'", needle("Female")
    assert r(found) == 1
    * The excluded var's STRUCTURE is still documented (name + excluded marker).
    _priv_file_contains using "`ptxt'", needle("VARIABLE: hiv_status")
    assert r(found) == 1
    _priv_file_contains using "`ptxt'", needle("excluded (privacy)")
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: excluded binary variable does not leak values in Binary section"
    local ++pass_count
}
else {
    display as error "  FAIL: excluded binary variable leaked (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Test 2: excluded variable's cardinality/max-length not exposed in returns/JSON
* ============================================================
local ++test_count
capture {
    * (detect() is text-only; since 1.6.9 format(json) refuses it with r(198))
    datamap, single("`pdta'") output("`pjson'") format(json) ///
        exclude(hiv_status patient_id mrn)
    * Excluded vars carry null cardinality and null max length in JSON.
    _priv_file_contains using "`pjson'", needle(`""unique_values": null"')
    assert r(found) == 1
    _priv_file_contains using "`pjson'", needle(`""max_length": null"')
    assert r(found) == 1
    * No leak of the sensitive coding in JSON either.
    _priv_file_contains using "`pjson'", needle("Negative")
    assert r(found) == 0
    * Excluded classification is still recorded (structure documented).
    _priv_file_contains using "`pjson'", needle(`""classification": "excluded""')
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: excluded variable cardinality/max-length suppressed in JSON"
    local ++pass_count
}
else {
    display as error "  FAIL: excluded variable cardinality/max-length leaked in JSON (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Test 3: VALUE LABEL DEFINITIONS - excluded-only labels dropped,
*         shared labels preserved and attributed to the kept variable
* ============================================================
local ++test_count
capture {
    * Exclude arm (shares arml with kept study_arm) and hiv_status (yn only on it).
    datamap, single("`pdta'") output("`ptxt2'") exclude(arm hiv_status patient_id mrn)
    * Label used only by an excluded var disappears entirely.
    _priv_file_contains using "`ptxt2'", needle("yn (used by:")
    assert r(found) == 0
    * Shared label still printed, attributed to the kept var only.
    _priv_file_contains using "`ptxt2'", needle("arml (used by: study_arm)")
    assert r(found) == 1
    _priv_file_contains using "`ptxt2'", needle("Control")
    assert r(found) == 1
    _priv_file_contains using "`ptxt2'", needle("Treated")
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: value-label definitions drop excluded-only labels, keep shared"
    local ++pass_count
}
else {
    display as error "  FAIL: value-label definitions privacy contract incorrect (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Test 4: stored results unaffected - excluded count and names still correct
* ============================================================
local ++test_count
capture {
    datamap, single("`pdta'") output("`ptxt'") exclude(hiv_status arm)
    assert r(n_excluded) == 2
    assert strpos("`r(excluded_vars)'", "hiv_status") > 0
    assert strpos("`r(excluded_vars)'", "arm") > 0
}
if _rc == 0 {
    display as result "  PASS: exclude() stored results correct"
    local ++pass_count
}
else {
    display as error "  FAIL: exclude() stored results incorrect (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Test 5: JSON output is structurally valid (balanced, no trailing commas)
*         across plain, privacy, and all-missing inputs
* ============================================================
local ++test_count
capture {
    * (a) privacy-rich JSON from above
    _priv_json_ok using "`pjson'"
    assert r(braces_ok) == 1
    assert r(brackets_ok) == 1
    assert r(trailing) == 0
    * (b) all-missing edge case
    tempfile emiss ejson
    clear
    set obs 10
    gen double allmiss = .
    gen byte g = mod(_n, 2)
    gen str5 s = ""
    save "`emiss'.dta", replace
    datamap, single("`emiss'") output("`ejson'") format(json)
    _priv_json_ok using "`ejson'"
    assert r(braces_ok) == 1
    assert r(brackets_ok) == 1
    assert r(trailing) == 0
}
if _rc == 0 {
    display as result "  PASS: JSON output is structurally valid (balanced, no trailing commas)"
    local ++pass_count
}
else {
    display as error "  FAIL: JSON output malformed (error `=_rc')"
    local ++fail_count
}

* ============================================================
* 1.8.0 masking (D1-D4, E2): no printed count from 1 to m-1
* (blocks are capture noisily: quiet output never reaches a log)
* ============================================================
* Helper: number of log lines containing a needle
capture program drop _priv_count
program define _priv_count, rclass
    version 16.0
    syntax using/ , NEEDLE(string)
    tempname fh
    local n 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`needle'"') > 0 local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

capture program drop _priv_mfix
program define _priv_mfix
    clear
    set obs 40
    gen long id = _n
    gen double x = _n
    gen byte r3 = _n <= 3
    gen byte r7 = _n <= 7
    gen byte grp = cond(_n <= 3, 1, 2)
    gen byte sex = cond(_n <= 2, 9, 1 + mod(_n, 2))
    gen str4 code = cond(_n <= 4, "bad!", "A" + string(_n))
    * a 0/1 flag delivered as 1/missing: 0 is never observed
    gen byte flag = 1
    replace flag = . in 1/2
end
tempfile mlog

* ---- D1: a planted 3-row rule failure, masked and unmasked ----
local ++test_count
capture noisily {
    _priv_mfix
    capture log close _pm
    log using "`mlog'", text replace name(_pm)
    capture noisily datacheck, gatesonly rule("r3": !r3) maskrare mincell(5) violations(pm_v, replace)
    local rc1 = _rc
    capture noisily datacheck, gatesonly rule("r7": !r7) maskrare mincell(5) warn
    capture noisily datacheck, gatesonly rule("r3u": !r3) warn
    log close _pm
    assert `rc1' == 9
    _priv_count using "`mlog'", needle("rule(r3): <5 obs fail")
    assert r(n) == 1
    _priv_count using "`mlog'", needle("rule(r7): 7 obs fail")
    assert r(n) == 1
    _priv_count using "`mlog'", needle("rule(r3u): 3 obs fail")
    assert r(n) == 1
    * masked_count: the masked count is inside the violation block, and the
    * violations() artifact agrees with the console
    frame pm_v: assert observed[1] == "<5 fail"
    frame pm_v: assert strpos(message[1], "<5 obs fail") > 0
}
if _rc == 0 {
    display as result "  PASS: D1 rule(): 3 failing rows print <5 under maskrare, 7 print 7, 3 print 3 unmasked"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 rule() failing-row masking (error `=_rc')"
    local ++fail_count
}
capture frame drop pm_v

* ---- D1: isid never prints the rows/distinct pair under maskrare ----
local ++test_count
capture noisily {
    _priv_mfix
    replace id = 1 in 2/3
    capture log close _pm
    log using "`mlog'", text replace name(_pm)
    capture noisily datacheck, gatesonly isid(id) maskrare violations(pm_v, replace)
    capture noisily datacheck, gatesonly isid(id) warn
    log close _pm
    _priv_count using "`mlog'", needle("isid(id): not unique — <5 duplicated rows")
    assert r(n) == 1
    * unmasked: 40 rows, 38 distinct (the difference, 2, is the small cell)
    _priv_count using "`mlog'", needle("isid(id): not unique — 40 rows, 38 distinct")
    assert r(n) == 1
    frame pm_v: assert observed[1] == "<5 duplicated rows"
    frame pm_v: assert strpos(message[1], "distinct") == 0
}
if _rc == 0 {
    display as result "  PASS: D1 isid(): masked number of duplicated rows, never the rows/distinct pair"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 isid() derived-count masking (error `=_rc')"
    local ++fail_count
}
capture frame drop pm_v

* ---- D1: every counting gate masks, r(n_violations) does not ----
local ++test_count
capture noisily {
    _priv_mfix
    replace x = . in 1/2
    capture datacheck, gatesonly inrange(id 4 40) allowed(sex 1 2) forbid(sex 9) ///
        notvalues(sex 9) regex(code "^[A-Z][0-9]+$") notmissing(x) binary(flag) ///
        nodups maskrare warn violations(pm_v, replace)
    assert r(n_violations) == 7
    assert r(masked) == 1
    frame pm_v: assert _N == 7
    * hand counts: 3 ids outside, 2 sex 9 (three gates), 4 bad codes, 2
    * missing x, 2 missing flag; every one is below 5 and prints as <5
    frame pm_v: count if strpos(observed, "<5") > 0
    assert r(N) == 7
    frame pm_v: count if gate == "binary" & observed == "only 1 observed (<5 missing)"
    assert r(N) == 1
    capture datacheck, gatesonly by(grp) expectn(40) maskrare warn violations(pm_v, replace)
    frame pm_v: count if observed == "<5"
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: D1 inrange/allowed/forbid/notvalues/regex/notmissing/expectn counts masked; r(n_violations) counts gates"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 masking across counting gates (error `=_rc')"
    local ++fail_count
}
capture frame drop pm_v

* ---- D2: MISSINGNESS and GROUPWISE blocks ----
local ++test_count
capture noisily {
    _priv_mfix
    replace x = . in 1/2
    gen double y = cond(_n <= 38, ., 1)
    capture log close _pm
    log using "`mlog'", text replace name(_pm)
    datacheck x y grp, by(grp) maskrare
    local pmk = r(masked)
    log close _pm
    assert `pmk' == 1
    * x: 2 missing prints <5; y: 38 of 40 missing leaves 2 observed, so it
    * prints "all but <5" (the needle below is also inside that line)
    _priv_count using "`mlog'", needle("<5 missing  (.%)")
    assert r(n) == 2
    _priv_count using "`mlog'", needle("all but <5 missing  (.%)")
    assert r(n) == 1
    * group 1 has 3 rows; pooled alone its size would be N minus group 2,
    * so group 2 is pooled with it
    _priv_count using "`mlog'", needle("groups pooled (each <5 rows, or pooled with them): 2")
    assert r(n) == 2
    * group 2's N (37) would print right-aligned in a %9 column; the bare
    * digits would also match the log's clock time
    _priv_count using "`mlog'", needle("       37")
    assert r(n) == 0
    _priv_count using "`mlog'", needle("2 missing")
    assert r(n) == 0
    _priv_count using "`mlog'", needle("[masked <5]")
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: D2 missing counts, complements, and small groups are masked in the profile"
    local ++pass_count
}
else {
    display as error "  FAIL: D2 MISSINGNESS/GROUPWISE masking (error `=_rc')"
    local ++fail_count
}

* ---- secondary suppression: a lone small level is not recoverable ----
local ++test_count
capture noisily {
    clear
    set obs 40
    gen byte k = cond(_n <= 3, 1, cond(_n <= 20, 2, 3))
    gen byte j = cond(_n <= 3, 1, 2)
    capture log close _pm
    log using "`mlog'", text replace name(_pm)
    datacheck k j, categorical(k j) maskrare nomissing
    log close _pm
    * k: level 1 (3) is small, levels 2 (17) and 3 (20) are shown and the
    * pool {1} would be 40 - 37 = 3, so the smallest shown level (2) joins it
    _priv_count using "`mlog'", needle("suppressed (complement)")
    assert r(n) == 2
    _priv_count using "`mlog'", needle("17  (")
    assert r(n) == 0
    _priv_count using "`mlog'", needle("20  (50.0%)")
    assert r(n) == 1
    * j: two levels, 3 and 37; both are withheld
    _priv_count using "`mlog'", needle("37  (")
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: frequency tables add complementary suppression so N minus the shown cells is not a small cell"
    local ++pass_count
}
else {
    display as error "  FAIL: complementary suppression in frequency tables (error `=_rc')"
    local ++fail_count
}

* ---- D3/D4: datacheck, patterns maskrare passes the masking to datamvp ----
local ++test_count
capture noisily {
    clear
    set seed 7
    set obs 2000
    forvalues j = 1/6 {
        gen double v`j' = rnormal()
        replace v`j' = . if runiform() < 0.08 * `j'
    }
    capture log close _pm
    log using "`mlog'", text replace name(_pm)
    datacheck v1-v6, patterns maskrare nomissing
    log close _pm
    _priv_count using "`mlog'", needle("other patterns (")
    assert r(n) == 1
    * no pattern row with a frequency from 1 to 4
    tempname fh
    local small 0
    file open `fh' using "`mlog'", read text
    file read `fh' line
    while r(eof) == 0 {
        if regexm(`"`macval(line)'"', "^ *\| *[+.]+ +[0-9]+ +([1-4]) *\|") local ++small
        file read `fh' line
    }
    file close `fh'
    assert `small' == 0
}
if _rc == 0 {
    display as result "  PASS: D4 datacheck patterns maskrare: no pattern frequency below 5 is printed"
    local ++pass_count
}
else {
    display as error "  FAIL: D4 patterns masking (error `=_rc')"
    local ++fail_count
}

* ---- the ledger never stores a masked number ----
local ++test_count
capture noisily {
    _priv_mfix
    local pl "`c(tmpdir)'/priv_ledger_v180.dta"
    capture erase "`pl'"
    capture datacheck, gatesonly rule("r3": !r3 \ "r7": !r7) by(grp) expectn(1 100) ///
        maskrare warn ledger("`pl'", run(p1))
    use "`pl'", clear
    * group 1 (3 rows): n_scope masked; the 3-row rule failure is masked
    assert missing(n_scope) if strpos(grp, "group 1") > 0
    assert missing(observed_num) if obs_masked == 1
    count if obs_masked == 1
    assert !missing(r(N))
    assert r(N) >= 2
    assert masked == 1
    assert minshown >= 5 if !missing(minshown)
    capture erase "`pl'"
}
if _rc == 0 {
    display as result "  PASS: ledger: observed_num and n_scope are missing whenever masked; minshown >= 5"
    local ++pass_count
}
else {
    display as error "  FAIL: ledger masking contract (error `=_rc')"
    local ++fail_count
}

* ---- E2: every verdict line ends with the active masking ----
local ++test_count
capture noisily {
    _priv_mfix
    capture log close _pm
    log using "`mlog'", text replace name(_pm)
    datacheck, gatesonly isid(id) maskrare
    capture noisily datacheck, gatesonly rule("r3": !r3) maskrare mincell(10)
    datacheck, gatesonly isid(id)
    log close _pm
    _priv_count using "`mlog'", needle("0 violations [masked <5]")
    assert r(n) == 1
    _priv_count using "`mlog'", needle("EXPECTATION VIOLATIONS (1) [masked <10]")
    assert r(n) == 1
    _priv_count using "`mlog'", needle("rule(r3): <10 obs fail")
    assert r(n) == 1
    _priv_count using "`mlog'", needle("[masked")
    assert r(n) == 2
}
if _rc == 0 {
    display as result "  PASS: E2 PASS lines and violation headings carry [masked <m] only when masking"
    local ++pass_count
}
else {
    display as error "  FAIL: E2 masking tag (error `=_rc')"
    local ++fail_count
}

* ============================================================
* 1.8.0 review round: no masked cell is recovered by subtraction
* ============================================================
* Each test builds the printed numbers a reader would have, subtracts, and
* asserts that the difference is 0 or at least the mask (5).

* ---- datamvp: N minus the shown patterns is never a small cell ----
local ++test_count
capture noisily {
    * N = 100: patterns ++ (60), .+ (37), .. (3)
    clear
    set obs 100
    gen double x1 = cond(_n > 60, ., 1)
    gen double x2 = cond(_n > 97, ., 1)
    capture log close _pm
    log using "`mlog'", text replace name(_pm)
    datamvp x1 x2, maskrare
    log close _pm
    tempname fh
    local in 0
    local shown 0
    local pooled ""
    file open `fh' using "`mlog'", read text
    file read `fh' line
    while r(eof) == 0 {
        local L `"`macval(line)'"'
        if strpos(`"`L'"', "_pattern") local in 1
        else if `in' & regexm(`"`L'"', "^ *\+-") local in 0
        else if `in' & regexm(`"`L'"', "^ *\| ") {
            local t = strtrim(subinstr(`"`L'"', "|", " ", .))
            local nw : word count `t'
            local f : word `nw' of `t'
            if strpos(`"`t'"', "other patterns") local pooled "`f'"
            else local shown = `shown' + real(subinstr("`f'", ",", "", .))
        }
        file read `fh' line
    }
    file close `fh'
    local gap = 100 - `shown'
    assert `gap' == 0 | `gap' >= 5
    assert "`pooled'" != "<5"
    * x2 has 3 missing (masked), so the mean number missing per row, times
    * N, minus x1's 40 would recover it: the mean is withheld
    _priv_count using "`mlog'", needle("Mean missing/obs:        [suppressed]")
    assert r(n) == 1
    * 97 complete rows and 3 incomplete: the complete pattern is pooled too
    clear
    set obs 100
    gen double y1 = cond(_n <= 97, 1, .)
    gen double y2 = 1
    capture log close _pm
    log using "`mlog'", text replace name(_pm)
    datamvp y1 y2, maskrare nodrop
    log close _pm
    _priv_count using "`mlog'", needle("       97 |")
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: datamvp pooling leaves no small cell in N minus the shown patterns, or in the mean"
    local ++pass_count
}
else {
    display as error "  FAIL: datamvp pooled-row complement (error `=_rc')"
    local ++fail_count
}

* ---- groupstat: pooled additive values do not give a hidden group back ----
local ++test_count
capture noisily {
    clear
    set obs 103
    gen byte g = cond(_n <= 50, 1, cond(_n <= 100, 2, 3))
    gen double y = _n
    gen byte ev = cond(_n <= 13 | _n == 101, 1, 0)
    capture log close _pm
    log using "`mlog'", text replace name(_pm)
    datacheck, gatesonly groupstat(n y, by(g) \ sum ev, by(g)) maskrare
    log close _pm
    * 50 + 50 shown; pooled 103 would give group 3's 3 rows; 13 + 0 shown,
    * pooled 14 would give its 1 event
    _priv_count using "`mlog'", needle("103")
    assert r(n) == 0
    _priv_count using "`mlog'", needle("          14")
    assert r(n) == 0
    _priv_count using "`mlog'", needle("[suppr.]")
    assert r(n) == 2
}
if _rc == 0 {
    display as result "  PASS: groupstat withholds pooled n and sum when a group is pooled away"
    local ++pass_count
}
else {
    display as error "  FAIL: groupstat pooled complement (error `=_rc')"
    local ++fail_count
}

* ---- gate messages mask a count whose complement is small ----
local ++test_count
capture noisily {
    clear
    set obs 100
    gen double x = cond(_n <= 98, ., 1)
    gen long id = _n
    capture datacheck, gatesonly notmissing(x) rule("big": id <= 2) maskrare warn violations(pm_v, replace)
    * 98 missing of 100 leaves 2 observed; 98 rows fail the rule, 2 pass
    frame pm_v: assert observed[1] == "all but <5 missing"
    frame pm_v: assert observed[2] == "all but <5 fail"
    frame pm_v: count if regexm(observed, "9[0-9]")
    assert r(N) == 0
    * the profile and the gate agree in one call
    capture log close _pm
    log using "`mlog'", text replace name(_pm)
    capture noisily datacheck x, notmissing(x) maskrare
    log close _pm
    _priv_count using "`mlog'", needle("98")
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: gate messages print 'all but <5' when the complement is the small cell"
    local ++pass_count
}
else {
    display as error "  FAIL: gate complement masking (error `=_rc')"
    local ++fail_count
}
capture frame drop pm_v

* ---- by() group sizes: console, ledger, and export ----
local ++test_count
capture noisily {
    clear
    set obs 103
    gen byte g = cond(_n <= 50, 1, cond(_n <= 100, 2, 3))
    gen long id = _n
    local pl "`c(tmpdir)'/priv_ledger_r2.dta"
    local px "`c(tmpdir)'/priv_export_r2.dta"
    capture erase "`pl'"
    capture log close _pm
    log using "`mlog'", text replace name(_pm)
    * expectn fails in every group (warn), so each group's N is printed
    capture noisily datacheck, gatesonly by(g) expectn(1000 2000) constant(g: id) ///
        maskrare warn ledger("`pl'", run(r2))
    log close _pm
    * group 3 (3 rows) is withheld, and group 1 joins it so that 103 minus
    * the shown group is not a small cell
    _priv_count using "`mlog'", needle("observed 50")
    assert r(n) == 1
    _priv_count using "`mlog'", needle("observed [suppressed]")
    assert r(n) == 1
    _priv_count using "`mlog'", needle("observed <5")
    assert r(n) == 1
    dataqa export using "`pl'", run(r2) saving("`px'") replace
    preserve
    use "`px'", clear
    quietly summarize n_scope if strpos(grp, "by(") == 1, meanonly
    local shown = r(sum)
    quietly summarize n_scope if grp == "", meanonly
    local total = r(max)
    assert `total' == 103
    local gap = `total' - `shown'
    assert `gap' == 0 | `gap' >= 5
    restore
    capture erase "`pl'"
    capture erase "`px'"
}
if _rc == 0 {
    display as result "  PASS: by() group sizes are withheld in pairs, so total minus shown groups is never small"
    local ++pass_count
}
else {
    display as error "  FAIL: by() group-size complement (error `=_rc')"
    local ++fail_count
}

capture erase "`pdta'"

* ============================================================
* Summary
* ============================================================
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_datamap_privacy tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_datamap_privacy tests=`test_count' pass=`pass_count' fail=`fail_count'"
