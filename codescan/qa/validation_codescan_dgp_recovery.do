* validation_codescan_dgp_recovery.do
*
* Known-answer DGP recovery for codescan.  Each scenario simulates
* wide-format patient-visit code data from a data-generating process whose
* correct answer is computed INDEPENDENTLY of codescan's Mata st_sview scanner:
*   - regex matches via Stata-level ustrregexm(val, "^(pat)")  (same ICU
*     engine, different implementation path — catches scanner-loop and
*     aggregation bugs, not regex-flavour differences)
*   - prefix matches via substr(val, 1, strlen(pat)) == pat
*   - date-window membership via hand-coded date arithmetic
*   - Wilson CI via the closed-form Wilson score formula
* The oracle therefore shares codescan's INTENDED semantics but not its code,
* which is exactly what a known-answer test needs.

clear all
set varabbrev off
version 16.0

capture log close
log using "validation_codescan_dgp_recovery.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall codescan
quietly net install codescan, from("`pkg_dir'") replace

**# DGP builder

* Builds fresh wide-format patient-visit data from a fixed code pool.
* Pool (index -> code) and the conditions they satisfy:
*   1 E110   dm2, dm2_excl      2 E116   dm2                3 E119   dm2, dm2_excl
*   4 I10    htn                5 I11    htn                6 I200   (none)
*   7 F320   dep                8 F33    dep                9 J45    (none)
*  10 ""     (empty, never matches)
* Definitions used across scenarios:
*   dm2      "E11"          -> {E110,E116,E119}
*   dm2_excl "E11" ~ "E116" -> {E110,E119}
*   htn      "I1[0-35]"     -> {I10,I11}
*   dep      "F3[23]"       -> {F320,F33}
capture program drop _cs_makedata
program define _cs_makedata
    syntax , [Nrows(integer 4000) Npat(integer 800) SEEDval(integer 20260704)]
    clear
    set seed `seedval'
    set obs `nrows'
    * random patient id and a per-patient index date
    gen long pid = runiformint(1, `npat')
    * per-patient index date: deterministic function of pid (stable per patient)
    gen int index_dt = mdy(1,1,2020) + mod(pid*37, 400)
    * visit date scattered around the patient's index date
    gen int visit_dt = index_dt + runiformint(-500, 500)
    * three diagnosis slots drawn independently from the pool
    forvalues s = 1/3 {
        gen byte _p`s' = runiformint(1, 10)
        gen str8 dx`s' = ""
        replace dx`s' = "E110" if _p`s' == 1
        replace dx`s' = "E116" if _p`s' == 2
        replace dx`s' = "E119" if _p`s' == 3
        replace dx`s' = "I10"  if _p`s' == 4
        replace dx`s' = "I11"  if _p`s' == 5
        replace dx`s' = "I200" if _p`s' == 6
        replace dx`s' = "F320" if _p`s' == 7
        replace dx`s' = "F33"  if _p`s' == 8
        replace dx`s' = "J45"  if _p`s' == 9
        drop _p`s'
    }
    * ----- independent oracles (row-level), computed via ustrregexm/substr -----
    * dm2: ^(E11) across any slot
    gen byte o_dm2 = 0
    * dm2 with exclusion of ^(E116)
    gen byte o_dm2ex = 0
    gen byte o_htn = 0
    gen byte o_dep = 0
    * countmode oracle: number of matching slots per row for dm2
    gen byte o_dm2_slots = 0
    forvalues s = 1/3 {
        replace o_dm2      = 1 if ustrregexm(dx`s', "^(E11)")
        replace o_htn      = 1 if ustrregexm(dx`s', "^(I1[0-35])")
        replace o_dep      = 1 if ustrregexm(dx`s', "^(F3[23])")
        replace o_dm2_slots = o_dm2_slots + (ustrregexm(dx`s', "^(E11)") == 1)
        replace o_dm2ex    = 1 if ustrregexm(dx`s', "^(E11)") & !ustrregexm(dx`s', "^(E116)")
    }
end

**# Scenario 1: row-level prevalence recovery (regex, multi-slot OR)

local ++test_count
capture noisily {
    _cs_makedata
    quietly count if o_dm2 == 1
    local truth = r(N)
    codescan dx1 dx2 dx3, define(dm2 "E11")
    * grab returns immediately -- a later `count` (r-class) would clobber r()
    matrix CL = r(codelist)
    scalar cl_count = CL[1,1]
    quietly count if dm2 == 1
    assert r(N) == `truth'
    * r(codelist) count column must equal the oracle count too
    assert cl_count == `truth'
}
if _rc == 0 {
    display as result "  PASS: row-level prevalence recovery (multi-slot regex OR)"
    local ++pass_count
}
else {
    display as error "  FAIL: row-level prevalence recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 2: exclusion recovery (~ operator drops E116)

local ++test_count
capture noisily {
    _cs_makedata
    quietly count if o_dm2ex == 1
    local truth = r(N)
    codescan dx1 dx2 dx3, define(dm2 "E11" ~ "E116")
    quietly count if dm2 == 1
    assert r(N) == `truth'
    * exclusion must remove at least one row relative to plain dm2 (guard)
    quietly count if o_dm2 == 1
    assert `truth' < r(N)
}
if _rc == 0 {
    display as result "  PASS: exclusion operator recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: exclusion operator recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 3: prefix-mode recovery differs from regex on a char class

local ++test_count
capture noisily {
    _cs_makedata
    * prefix "I1[0-35]" is a LITERAL string, matches nothing in the pool
    gen byte o_htn_prefix = 0
    forvalues s = 1/3 {
        replace o_htn_prefix = 1 if substr(dx`s', 1, 8) == "I1[0-35]"
    }
    quietly count if o_htn_prefix == 1
    local truth_prefix = r(N)
    assert `truth_prefix' == 0
    codescan dx1 dx2 dx3, define(htn "I1[0-35]") mode(prefix)
    quietly count if htn == 1
    assert r(N) == 0
    * regex form recovers the real I10/I11 rows
    quietly count if o_htn == 1
    local truth_regex = r(N)
    assert `truth_regex' > 0
    codescan dx1 dx2 dx3, define(htn "I1[0-35]") replace
    quietly count if htn == 1
    assert r(N) == `truth_regex'
}
if _rc == 0 {
    display as result "  PASS: prefix vs regex char-class recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: prefix vs regex char-class recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 4: nocase recovery

local ++test_count
capture noisily {
    _cs_makedata
    * lowercase half the E11* codes so case matters
    replace dx1 = lower(dx1) if mod(_n, 2) == 0
    * case-sensitive oracle: ustrregexm on the possibly-lowercased value
    gen byte o_cs = 0
    gen byte o_ci = 0
    forvalues s = 1/3 {
        replace o_cs = 1 if ustrregexm(dx`s', "^(E11)")
        replace o_ci = 1 if ustrregexm(ustrupper(dx`s'), "^(E11)")
    }
    quietly count if o_cs == 1
    local truth_cs = r(N)
    quietly count if o_ci == 1
    local truth_ci = r(N)
    assert `truth_ci' > `truth_cs'
    codescan dx1 dx2 dx3, define(dm2 "E11")
    quietly count if dm2 == 1
    assert r(N) == `truth_cs'
    codescan dx1 dx2 dx3, define(dm2 "E11") nocase replace
    quietly count if dm2 == 1
    assert r(N) == `truth_ci'
}
if _rc == 0 {
    display as result "  PASS: nocase recovery (case folding widens the cohort)"
    local ++pass_count
}
else {
    display as error "  FAIL: nocase recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 5: lookback-only window, inclusive vs exclusive boundary

local ++test_count
capture noisily {
    _cs_makedata
    * oracle: match AND date in [refdate-365, refdate] (inclusive)
    *         match AND date in [refdate-365, refdate-1] (exclusive)
    gen byte o_lb_inc = o_dm2 & (visit_dt >= index_dt - 365) & (visit_dt <= index_dt)
    gen byte o_lb_exc = o_dm2 & (visit_dt >= index_dt - 365) & (visit_dt <  index_dt)
    quietly count if o_lb_inc == 1
    local t_inc = r(N)
    quietly count if o_lb_exc == 1
    local t_exc = r(N)
    codescan dx1 dx2 dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(365) inclusive
    quietly count if dm2 == 1
    assert r(N) == `t_inc'
    codescan dx1 dx2 dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(365) replace
    quietly count if dm2 == 1
    assert r(N) == `t_exc'
    * inclusive window must be >= exclusive (it contains refdate-day matches)
    assert `t_inc' >= `t_exc'
}
if _rc == 0 {
    display as result "  PASS: lookback window inclusive/exclusive recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: lookback window recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 6: lookforward-only window recovery

local ++test_count
capture noisily {
    _cs_makedata
    gen byte o_lf_inc = o_dm2 & (visit_dt <= index_dt + 180) & (visit_dt >= index_dt)
    gen byte o_lf_exc = o_dm2 & (visit_dt <= index_dt + 180) & (visit_dt >  index_dt)
    quietly count if o_lf_inc == 1
    local t_inc = r(N)
    quietly count if o_lf_exc == 1
    local t_exc = r(N)
    codescan dx1 dx2 dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookforward(180) inclusive
    quietly count if dm2 == 1
    assert r(N) == `t_inc'
    codescan dx1 dx2 dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookforward(180) replace
    quietly count if dm2 == 1
    assert r(N) == `t_exc'
}
if _rc == 0 {
    display as result "  PASS: lookforward window inclusive/exclusive recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: lookforward window recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 7: bracketed window (lookback + lookforward, always inclusive)

local ++test_count
capture noisily {
    _cs_makedata
    gen byte o_both = o_dm2 & (visit_dt >= index_dt - 90) & (visit_dt <= index_dt + 90)
    quietly count if o_both == 1
    local truth = r(N)
    codescan dx1 dx2 dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(90) lookforward(90)
    quietly count if dm2 == 1
    assert r(N) == `truth'
}
if _rc == 0 {
    display as result "  PASS: bracketed lookback+lookforward recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: bracketed window recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 8: countrows recovery (matching rows per patient)

local ++test_count
capture noisily {
    _cs_makedata
    * oracle: number of matching rows per patient
    bysort pid: egen int o_nrows = total(o_dm2)
    codescan dx1 dx2 dx3, define(dm2 "E11") id(pid) date(visit_dt) ///
        merge countrows
    * dm2_nrows should broadcast the per-patient matching-row count
    assert dm2_nrows == o_nrows
}
if _rc == 0 {
    display as result "  PASS: countrows per-patient recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows per-patient recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 9: countdate recovery (unique matching dates per patient)

local ++test_count
capture noisily {
    _cs_makedata
    * oracle: number of DISTINCT visit dates on which a match occurred, per pid
    preserve
        keep if o_dm2 == 1
        bysort pid visit_dt: keep if _n == 1
        bysort pid: gen int u = _N
        bysort pid: keep if _n == 1
        keep pid u
        tempfile udates
        save `udates'
    restore
    codescan dx1 dx2 dx3, define(dm2 "E11") id(pid) date(visit_dt) ///
        collapse countdate
    * after collapse, one row per patient; dm2_count = unique matching dates
    merge 1:1 pid using `udates', keep(master match)
    * patients with no match have dm2_count 0 and no oracle row (u missing -> 0)
    replace u = 0 if _merge == 1
    assert dm2_count == u
}
if _rc == 0 {
    display as result "  PASS: countdate unique-date recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: countdate unique-date recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 10: earliestdate / latestdate recovery

local ++test_count
capture noisily {
    _cs_makedata
    preserve
        keep if o_dm2 == 1
        bysort pid: egen int o_first = min(visit_dt)
        bysort pid: egen int o_last  = max(visit_dt)
        bysort pid: keep if _n == 1
        keep pid o_first o_last
        tempfile fl
        save `fl'
    restore
    codescan dx1 dx2 dx3, define(dm2 "E11") id(pid) date(visit_dt) ///
        collapse earliestdate latestdate
    merge 1:1 pid using `fl', keep(master match)
    * only assert on patients that actually matched
    assert dm2_first == o_first if _merge == 3
    assert dm2_last  == o_last  if _merge == 3
}
if _rc == 0 {
    display as result "  PASS: earliest/latest date recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: earliest/latest date recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 11: collapse produces one row per patient with correct prevalence

local ++test_count
capture noisily {
    _cs_makedata
    * oracle: distinct patients with at least one match
    preserve
        bysort pid: egen byte o_any = max(o_dm2)
        bysort pid: keep if _n == 1
        quietly count
        local n_pat = r(N)
        quietly count if o_any == 1
        local n_match_pat = r(N)
    restore
    codescan dx1 dx2 dx3, define(dm2 "E11") id(pid) collapse
    * grab returns immediately -- a later `count` (r-class) would clobber r()
    matrix CL = r(codelist)
    scalar cl11 = CL[1,1]
    quietly count
    assert r(N) == `n_pat'
    quietly count if dm2 == 1
    assert r(N) == `n_match_pat'
    * r(codelist) count = patient-level count after collapse
    assert cl11 == `n_match_pat'
}
if _rc == 0 {
    display as result "  PASS: collapse patient-level prevalence recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: collapse patient-level recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 12: merge preserves _N and broadcasts patient-level indicator

local ++test_count
capture noisily {
    _cs_makedata
    local n0 = _N
    bysort pid: egen byte o_any = max(o_dm2)
    codescan dx1 dx2 dx3, define(dm2 "E11") id(pid) merge
    * _N unchanged, and every row of a patient carries the patient-level flag
    assert _N == `n0'
    assert dm2 == o_any
    assert r(merged) == 1
    assert r(collapsed) == 0
}
if _rc == 0 {
    display as result "  PASS: merge broadcast + _N invariance"
    local ++pass_count
}
else {
    display as error "  FAIL: merge broadcast recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 13: countmode counts matching code slots per row

local ++test_count
capture noisily {
    _cs_makedata
    * oracle o_dm2_slots was accumulated in the builder (0..3 per row)
    quietly summarize o_dm2_slots
    local tot_slots = r(sum)
    assert `tot_slots' > 0
    codescan dx1 dx2 dx3, define(dm2 "E11") countmode
    assert dm2 == o_dm2_slots
    quietly summarize dm2
    assert r(sum) == `tot_slots'
    * some row must have >1 slot hit for the test to bite
    quietly count if o_dm2_slots >= 2
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: countmode code-slot count recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: countmode code-slot count recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 14: countmode + collapse sums code-slot hits per patient

local ++test_count
capture noisily {
    _cs_makedata
    preserve
        bysort pid: egen long o_slotsum = total(o_dm2_slots)
        bysort pid: keep if _n == 1
        keep pid o_slotsum
        tempfile ss
        save `ss'
    restore
    codescan dx1 dx2 dx3, define(dm2 "E11") id(pid) collapse countmode
    merge 1:1 pid using `ss', keep(master match)
    assert dm2 == o_slotsum
}
if _rc == 0 {
    display as result "  PASS: countmode+collapse slot-sum recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: countmode+collapse slot-sum recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 15: cooccurrence matrix recovery (row-level, hand-computed)

local ++test_count
capture noisily {
    _cs_makedata
    * oracle pairwise co-occurrence counts at the row level
    quietly count if o_dm2 == 1 & o_htn == 1
    local c_dm2_htn = r(N)
    quietly count if o_dm2 == 1 & o_dep == 1
    local c_dm2_dep = r(N)
    quietly count if o_htn == 1 & o_dep == 1
    local c_htn_dep = r(N)
    quietly count if o_dm2 == 1
    local c_dm2 = r(N)
    codescan dx1 dx2 dx3, ///
        define(dm2 "E11" | htn "I1[0-35]" | dep "F3[23]") cooccurrence
    matrix C = r(cooccurrence)
    * diagonal = marginal count; off-diagonal = pairwise
    assert C[1,1] == `c_dm2'
    assert C[1,2] == `c_dm2_htn'
    assert C[2,1] == `c_dm2_htn'
    assert C[1,3] == `c_dm2_dep'
    assert C[2,3] == `c_htn_dep'
}
if _rc == 0 {
    display as result "  PASS: cooccurrence matrix recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: cooccurrence matrix recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 16: multi-window sensitivity recovery (per-window denominators)

local ++test_count
capture noisily {
    _cs_makedata
    * Each window uses its OWN denominator: patients with >=1 row inside that
    * window (documented collapse/merge behaviour -- id() values with in-window
    * observation).  prevalence% = (patients with an in-window MATCH) /
    * (patients with any in-window row) * 100.  Windows are [ref-W, ref] incl.
    foreach W in 30 90 365 {
        gen byte _in`W'    = (visit_dt >= index_dt - `W') & (visit_dt <= index_dt)
        gen byte _mtch`W'  = o_dm2 & _in`W'
        bysort pid: egen byte o_anyin`W'  = max(_in`W')
        bysort pid: egen byte o_anymt`W'  = max(_mtch`W')
    }
    preserve
        bysort pid: keep if _n == 1
        foreach W in 30 90 365 {
            quietly count if o_anyin`W' == 1
            local den`W' = r(N)
            quietly count if o_anymt`W' == 1
            local prev`W' = r(N) / `den`W'' * 100
        }
    restore
    codescan dx1 dx2 dx3, define(dm2 "E11") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(30 90 365) collapse inclusive
    matrix S = r(sensitivity)
    local lb "`r(lookback)'"
    assert "`lb'" == "30 90 365"
    assert abs(S[1,1] - `prev30')  < 1e-6
    assert abs(S[1,2] - `prev90')  < 1e-6
    assert abs(S[1,3] - `prev365') < 1e-6
    * nested windows -> the in-window denominator is non-decreasing (a theorem)
    assert `den30' <= `den90'
    assert `den90' <= `den365'
}
if _rc == 0 {
    display as result "  PASS: multi-window sensitivity recovery (per-window denominators)"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-window sensitivity recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 17: Wilson score CI closed-form recovery

local ++test_count
capture noisily {
    _cs_makedata
    quietly count if o_dm2 == 1
    local k = r(N)
    local n = _N
    local p = `k' / `n'
    * Wilson score interval at c(level) (default 95); codescan stores prevalence
    * and CI bounds as PERCENTAGES, clamped to [0,100].
    local z = invnormal(1 - (1 - c(level)/100)/2)
    local z2 = `z' * `z'
    local center = (`p' + `z2'/(2*`n')) / (1 + `z2'/`n')
    local halfw  = (`z'/(1 + `z2'/`n')) * sqrt(`p'*(1-`p')/`n' + `z2'/(4*`n'*`n'))
    local lo = max(0,   (`center' - `halfw') * 100)
    local hi = min(100, (`center' + `halfw') * 100)
    codescan dx1 dx2 dx3, define(dm2 "E11")
    matrix SUM = r(summary)
    * r(summary) columns: count, prevalence(%), CI lower(%), CI upper(%)
    assert SUM[1,1] == `k'
    assert abs(SUM[1,2] - `p'*100) < 1e-6
    assert abs(SUM[1,3] - `lo') < 1e-6
    assert abs(SUM[1,4] - `hi') < 1e-6
    assert r(ci_level) == c(level)
}
if _rc == 0 {
    display as result "  PASS: Wilson score CI closed-form recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: Wilson score CI recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 18: missing-date exclusion count recovery

local ++test_count
capture noisily {
    _cs_makedata
    * blank out a known number of visit dates among matching rows
    gen long _ord = _n
    replace visit_dt = . if mod(_ord, 7) == 0
    * oracle: rows dropped from the window for a missing date()
    quietly count if visit_dt == .
    local n_missing = r(N)
    assert `n_missing' > 0
    codescan dx1 dx2 dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(365) inclusive
    assert r(n_excluded_missingdate) == `n_missing'
    * and those rows must never be counted as matches
    quietly count if dm2 == 1 & visit_dt == .
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: missing-date exclusion count recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: missing-date exclusion recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 19: multiple-condition OR independence (each recovers separately)

local ++test_count
capture noisily {
    _cs_makedata
    quietly count if o_dm2 == 1
    local t_dm2 = r(N)
    quietly count if o_htn == 1
    local t_htn = r(N)
    quietly count if o_dep == 1
    local t_dep = r(N)
    codescan dx1 dx2 dx3, ///
        define(dm2 "E11" | htn "I1[0-35]" | dep "F3[23]")
    * grab returns immediately -- a later `count` (r-class) would clobber r()
    local nc = r(n_conditions)
    assert `nc' == 3
    quietly count if dm2 == 1
    assert r(N) == `t_dm2'
    quietly count if htn == 1
    assert r(N) == `t_htn'
    quietly count if dep == 1
    assert r(N) == `t_dep'
}
if _rc == 0 {
    display as result "  PASS: three-condition independent recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: three-condition independent recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 20: generate() prefixes derived variable names

local ++test_count
capture noisily {
    _cs_makedata
    quietly count if o_dm2 == 1
    local truth = r(N)
    codescan dx1 dx2 dx3, define(dm2 "E11") generate(cc_)
    confirm variable cc_dm2
    capture confirm variable dm2
    assert _rc != 0
    quietly count if cc_dm2 == 1
    assert r(N) == `truth'
}
if _rc == 0 {
    display as result "  PASS: generate() name-prefix recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: generate() name-prefix recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 21: Wilson CI narrows at a lower c(level) (set level 80)

local ++test_count
capture noisily {
    _cs_makedata
    quietly count if o_dm2 == 1
    local k = r(N)
    local n = _N
    local p = `k' / `n'
    local lvl0 = c(level)
    * hand-computed 80% Wilson interval (percentages, clamped)
    local z = invnormal(1 - (1 - 80/100)/2)
    local z2 = `z' * `z'
    local center = (`p' + `z2'/(2*`n')) / (1 + `z2'/`n')
    local halfw  = (`z'/(1 + `z2'/`n')) * sqrt(`p'*(1-`p')/`n' + `z2'/(4*`n'*`n'))
    local lo80 = max(0,   (`center' - `halfw') * 100)
    local hi80 = min(100, (`center' + `halfw') * 100)
    set level 80
    codescan dx1 dx2 dx3, define(dm2 "E11")
    matrix SUM = r(summary)
    set level `lvl0'
    assert abs(SUM[1,3] - `lo80') < 1e-6
    assert abs(SUM[1,4] - `hi80') < 1e-6
    assert r(ci_level) == 80
    * an 80% interval is strictly narrower than the default 95% interval
    local width80 = `hi80' - `lo80'
    local z95 = invnormal(0.975)
    local z952 = `z95' * `z95'
    local c95 = (`p' + `z952'/(2*`n')) / (1 + `z952'/`n')
    local h95 = (`z95'/(1 + `z952'/`n')) * sqrt(`p'*(1-`p')/`n' + `z952'/(4*`n'*`n'))
    local width95 = (min(100,(`c95'+`h95')*100)) - (max(0,(`c95'-`h95')*100))
    assert `width80' < `width95'
}
if _rc == 0 {
    display as result "  PASS: Wilson CI recovery at level 80 (narrower than 95)"
    local ++pass_count
}
else {
    display as error "  FAIL: Wilson CI recovery at level 80 (error `=_rc')"
    local ++fail_count
}

**# Scenario 23: level() prefix truncation to ICD chapter grouping

local ++test_count
capture noisily {
    _cs_makedata
    * prefix "E110" matches only E110; level(3) truncates it to "E11",
    * which then matches E110, E116, E119 (the full dm2 cohort).
    gen byte o_e110 = 0
    forvalues s = 1/3 {
        replace o_e110 = 1 if substr(dx`s', 1, 4) == "E110"
    }
    quietly count if o_e110 == 1
    local t_full = r(N)
    quietly count if o_dm2 == 1
    local t_trunc = r(N)
    assert `t_full' < `t_trunc'
    codescan dx1 dx2 dx3, define(dm2 "E110") mode(prefix)
    quietly count if dm2 == 1
    assert r(N) == `t_full'
    codescan dx1 dx2 dx3, define(dm2 "E110") mode(prefix) level(3) replace
    quietly count if dm2 == 1
    assert r(N) == `t_trunc'
}
if _rc == 0 {
    display as result "  PASS: level() prefix truncation recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: level() prefix truncation recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 22: codescan_describe inventory recovery

local ++test_count
capture noisily {
    _cs_makedata
    * oracle: count non-empty code entries and distinct codes across dx1-dx3
    preserve
        gen long _row = _n
        keep _row dx1 dx2 dx3
        reshape long dx, i(_row) j(_slot)
        drop if dx == ""
        quietly count
        local n_entries = r(N)
        quietly levelsof dx, local(codes)
        local n_unique : word count `codes'
    restore
    codescan_describe dx1 dx2 dx3
    assert r(n_entries) == `n_entries'
    assert r(n_unique) == `n_unique'
    assert r(n_vars) == 3
}
if _rc == 0 {
    display as result "  PASS: codescan_describe inventory recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe inventory recovery (error `=_rc')"
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_codescan_dgp_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_codescan_dgp_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close
