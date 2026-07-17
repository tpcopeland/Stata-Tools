* validation_codescan_dgp_recovery2.do
*
* SECOND batch of known-answer DGP recovery scenarios for codescan.  The first
* batch (validation_codescan_dgp_recovery.do) covers row/patient prevalence,
* windows, counts, cooccurrence, sensitivity, and Wilson CIs.  This file targets
* the option/output paths that batch did NOT exercise at large N:
*   matched_code first-hit, unmatched flag, regex/prefix alternation within one
*   condition, multi-pattern exclusion chains, prefix-mode exclusion,
*   multi-window lookback bracketed by a fixed lookforward, merge-broadcast of
*   date summaries / counts, countrows+collapse, countmode+merge, patient-level
*   cooccurrence (collapse), tostring on numeric codes, label() variable labels,
*   detail varcounts first-slot attribution, a combined multi-output collapse,
*   alldates shorthand, empty-window boundary, and a wide (99%) Wilson CI.
*
* As in batch 1 the oracle is computed INDEPENDENTLY of codescan's Mata scanner:
* regex via Stata-level ustrregexm(), prefixes via substr(), dates via hand
* arithmetic, Wilson via the closed form.  Same intended semantics, different code.

clear all
set varabbrev off
version 16.0

capture log close
log using "validation_codescan_dgp_recovery2.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

* Guarded shared bootstrap. Sandboxes PLUS/PERSONAL under c(tmpdir), then
* installs this working copy. Running this suite standalone must not mutate
* the developer's real adopath, which the bare net install here used to do;
* only run_all.do was sandboxed. Idempotent, so the lane re-entering it is
* harmless.
quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap

* Session settings captured for the hygiene check at the end of this suite.
* A suite that leaves c(level) or c(varabbrev) changed silently alters every
* later suite in the lane -- the level-80/99 CI scenarios restored inside a
* captured block, so any assertion failure above them used to leak.
local _qa_level0 = c(level)
local _qa_va0 "`c(varabbrev)'"
local _qa_pwd0 "`c(pwd)'"


**# DGP builder (identical pool/definitions to batch 1)

* Pool (index -> code) and the conditions they satisfy:
*   1 E110   dm2, dm2_excl      2 E116   dm2                3 E119   dm2, dm2_excl
*   4 I10    htn                5 I11    htn                6 I200   (none)
*   7 F320   dep                8 F33    dep                9 J45    (none)
*  10 ""     (empty, never matches)
capture program drop _cs_makedata
program define _cs_makedata
    syntax , [Nrows(integer 4000) Npat(integer 800) SEEDval(integer 20260704)]
    clear
    set seed `seedval'
    set obs `nrows'
    gen long pid = runiformint(1, `npat')
    gen int index_dt = mdy(1,1,2020) + mod(pid*37, 400)
    gen int visit_dt = index_dt + runiformint(-500, 500)
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
    gen byte o_dm2 = 0
    gen byte o_dm2ex = 0
    gen byte o_htn = 0
    gen byte o_dep = 0
    gen byte o_dm2_slots = 0
    forvalues s = 1/3 {
        replace o_dm2      = 1 if ustrregexm(dx`s', "^(E11)")
        replace o_htn      = 1 if ustrregexm(dx`s', "^(I1[0-35])")
        replace o_dep      = 1 if ustrregexm(dx`s', "^(F3[23])")
        replace o_dm2_slots = o_dm2_slots + (ustrregexm(dx`s', "^(E11)") == 1)
        replace o_dm2ex    = 1 if ustrregexm(dx`s', "^(E11)") & !ustrregexm(dx`s', "^(E116)")
    }
end

**# Scenario 1: matched_code first-hit recovery (raw value, varlist order)

local ++test_count
capture noisily {
    _cs_makedata
    * oracle: first slot (dx1->dx3) whose RAW value matches ^(E11)
    gen str8 o_mc = ""
    forvalues s = 1/3 {
        replace o_mc = dx`s' if o_mc == "" & ustrregexm(dx`s', "^(E11)")
    }
    codescan dx1 dx2 dx3, define(dm2 "E11") matched_code(mc)
    assert mc == o_mc
    * a matched row must carry a non-empty code; an unmatched row must be empty
    quietly count if dm2 == 1 & mc == ""
    assert r(N) == 0
    quietly count if dm2 == 0 & mc != ""
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: matched_code first-hit recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: matched_code first-hit recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 2: unmatched() flag is the row-level complement of the match

local ++test_count
capture noisily {
    _cs_makedata
    gen byte o_un = (o_dm2 == 0)
    codescan dx1 dx2 dx3, define(dm2 "E11") unmatched(nohit)
    assert nohit == o_un
    quietly count if o_dm2 == 0
    local t_none = r(N)
    quietly count if nohit == 1
    assert r(N) == `t_none'
    * every row is either a match or unmatched, never both, never neither
    quietly count if dm2 == 1 & nohit == 1
    assert r(N) == 0
    quietly count if dm2 == 0 & nohit == 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: unmatched flag complement recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: unmatched flag complement recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 3: regex alternation inside ONE condition (n_conditions == 1)

local ++test_count
capture noisily {
    _cs_makedata
    * "E11|F3[23]" is a single quoted pattern -> one condition, anchored
    * as ^(E11|F3[23]); recovers the union of the dm2 and dep cohorts.
    gen byte o_union = (o_dm2 | o_dep)
    codescan dx1 dx2 dx3, define(cvd "E11|F3[23]")
    local nc = r(n_conditions)
    assert `nc' == 1
    assert cvd == o_union
    * the union must strictly exceed either component alone (guard)
    quietly count if o_dm2 == 1
    local t_dm2 = r(N)
    quietly count if o_union == 1
    assert r(N) > `t_dm2'
}
if _rc == 0 {
    display as result "  PASS: single-condition regex alternation recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: single-condition regex alternation recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 4: prefix-mode alternation via pipe-separated prefixes

local ++test_count
capture noisily {
    _cs_makedata
    * mode(prefix) with "E11|F32" -> match prefix E11 OR prefix F32.
    * F33 is NOT an F32 prefix, so dep's F33 rows are excluded.
    gen byte o_pfx = 0
    forvalues s = 1/3 {
        replace o_pfx = 1 if substr(dx`s',1,3) == "E11" | substr(dx`s',1,3) == "F32"
    }
    codescan dx1 dx2 dx3, define(cvd "E11|F32") mode(prefix)
    assert cvd == o_pfx
    * F33-only rows (dep but not F32) must be classified 0
    gen byte o_f33only = 0
    forvalues s = 1/3 {
        replace o_f33only = 1 if dx`s' == "F33"
    }
    quietly count if o_f33only == 1 & o_pfx == 0
    assert r(N) > 0
    quietly count if o_f33only == 1 & o_pfx == 0 & cvd == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: prefix-mode pipe alternation recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: prefix-mode pipe alternation recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 5: multi-pattern exclusion chain (~ "E116" ~ "E119")

local ++test_count
capture noisily {
    _cs_makedata
    * two exclusions accumulate to ^(E116|E119); only E110 survives among E11*
    gen byte o_e11only = 0
    forvalues s = 1/3 {
        replace o_e11only = 1 if ustrregexm(dx`s', "^(E11)") ///
            & !ustrregexm(dx`s', "^(E116|E119)")
    }
    codescan dx1 dx2 dx3, define(dm2 "E11" ~ "E116" ~ "E119")
    quietly count if dm2 == 1
    local t2 = r(N)
    assert dm2 == o_e11only
    * the double exclusion must remove more than a single ~ "E116" exclusion
    codescan dx1 dx2 dx3, define(dm2 "E11" ~ "E116") replace
    quietly count if dm2 == 1
    assert `t2' < r(N)
}
if _rc == 0 {
    display as result "  PASS: multi-pattern exclusion chain recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-pattern exclusion chain recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 6: prefix-mode exclusion recovery

local ++test_count
capture noisily {
    _cs_makedata
    * prefix E11 minus prefix E116 -> {E110, E119}
    gen byte o_pex = 0
    forvalues s = 1/3 {
        replace o_pex = 1 if substr(dx`s',1,3) == "E11" & substr(dx`s',1,4) != "E116"
    }
    codescan dx1 dx2 dx3, define(dm2 "E11" ~ "E116") mode(prefix)
    assert dm2 == o_pex
    * E116 rows that would match plain E11 must be excluded
    gen byte o_e116 = 0
    forvalues s = 1/3 {
        replace o_e116 = 1 if dx`s' == "E116"
    }
    quietly count if o_e116 == 1 & o_pex == 0 & dm2 == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: prefix-mode exclusion recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: prefix-mode exclusion recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 7: multi-window lookback bracketed by a fixed lookforward

local ++test_count
capture noisily {
    _cs_makedata
    * Each window w in {30,90,365}: in-window = [ref - w, ref + 60] inclusive.
    * prevalence% = (patients with in-window match)/(patients with in-window row)*100
    foreach W in 30 90 365 {
        gen byte _in`W'   = (visit_dt >= index_dt - `W') & (visit_dt <= index_dt + 60)
        gen byte _mt`W'   = o_dm2 & _in`W'
        bysort pid: egen byte o_anyin`W' = max(_in`W')
        bysort pid: egen byte o_anymt`W' = max(_mt`W')
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
        refdate(index_dt) lookback(30 90 365) lookforward(60) collapse inclusive
    matrix S = r(sensitivity)
    assert "`r(lookback)'" == "30 90 365"
    assert abs(S[1,1] - `prev30')  < 1e-6
    assert abs(S[1,2] - `prev90')  < 1e-6
    assert abs(S[1,3] - `prev365') < 1e-6
    * widening the lookback (upper bound fixed) is monotone in the denominator
    assert `den30' <= `den90'
    assert `den90' <= `den365'
}
if _rc == 0 {
    display as result "  PASS: multi-window lookback + fixed lookforward sensitivity recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-window lookback + fixed lookforward (error `=_rc')"
    local ++fail_count
}

**# Scenario 8: earliest/latest date + MERGE broadcast (row-level)

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
    local n0 = _N
    codescan dx1 dx2 dx3, define(dm2 "E11") id(pid) date(visit_dt) ///
        merge earliestdate latestdate
    * merge preserves _N and broadcasts the patient-level date bounds to all rows
    assert _N == `n0'
    merge m:1 pid using `fl', keep(master match)
    assert dm2_first == o_first if _merge == 3
    assert dm2_last  == o_last  if _merge == 3
    * unmatched patients carry missing date bounds
    assert missing(dm2_first) if _merge == 1
}
if _rc == 0 {
    display as result "  PASS: earliest/latest + merge broadcast recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: earliest/latest + merge broadcast recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 9: countdate + MERGE broadcast (unique matching dates per patient)

local ++test_count
capture noisily {
    _cs_makedata
    preserve
        keep if o_dm2 == 1
        bysort pid visit_dt: keep if _n == 1
        bysort pid: gen int u = _N
        bysort pid: keep if _n == 1
        keep pid u
        tempfile ud
        save `ud'
    restore
    codescan dx1 dx2 dx3, define(dm2 "E11") id(pid) date(visit_dt) ///
        merge countdate
    merge m:1 pid using `ud', keep(master match)
    replace u = 0 if _merge == 1
    * every row of a patient carries that patient's unique-matching-date count
    assert dm2_count == u
}
if _rc == 0 {
    display as result "  PASS: countdate + merge broadcast recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: countdate + merge broadcast recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 10: countrows + COLLAPSE (matching rows per patient, one row out)

local ++test_count
capture noisily {
    _cs_makedata
    bysort pid: egen long o_nrows = total(o_dm2)
    preserve
        bysort pid: keep if _n == 1
        keep pid o_nrows
        tempfile nr
        save `nr'
    restore
    codescan dx1 dx2 dx3, define(dm2 "E11") id(pid) collapse countrows
    * grab returns immediately -- the later merge (r-class) clobbers r()
    local collapsed = r(collapsed)
    assert `collapsed' == 1
    * one row per patient; dm2_nrows = matching-row count
    merge 1:1 pid using `nr', keep(master match)
    assert _merge == 3
    assert dm2_nrows == o_nrows
}
if _rc == 0 {
    display as result "  PASS: countrows + collapse per-patient recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: countrows + collapse per-patient recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 11: countmode + MERGE broadcast (patient-level slot sum)

local ++test_count
capture noisily {
    _cs_makedata
    bysort pid: egen long o_slotsum = total(o_dm2_slots)
    local n0 = _N
    codescan dx1 dx2 dx3, define(dm2 "E11") id(pid) merge countmode
    assert _N == `n0'
    * merge with countmode broadcasts the patient-level TOTAL slot hits
    assert dm2 == o_slotsum
    assert r(mode_count) == 1
    assert r(merged) == 1
}
if _rc == 0 {
    display as result "  PASS: countmode + merge slot-sum broadcast recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: countmode + merge slot-sum broadcast recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 12: patient-level cooccurrence under collapse

local ++test_count
capture noisily {
    _cs_makedata
    * oracle: patient-ever indicators, then pairwise patient counts
    bysort pid: egen byte o_pdm2 = max(o_dm2)
    bysort pid: egen byte o_phtn = max(o_htn)
    bysort pid: egen byte o_pdep = max(o_dep)
    preserve
        bysort pid: keep if _n == 1
        quietly count if o_pdm2 == 1
        local m_dm2 = r(N)
        quietly count if o_phtn == 1
        local m_htn = r(N)
        quietly count if o_pdep == 1
        local m_dep = r(N)
        quietly count if o_pdm2 == 1 & o_phtn == 1
        local m_dm2_htn = r(N)
        quietly count if o_pdm2 == 1 & o_pdep == 1
        local m_dm2_dep = r(N)
        quietly count if o_phtn == 1 & o_pdep == 1
        local m_htn_dep = r(N)
    restore
    codescan dx1 dx2 dx3, ///
        define(dm2 "E11" | htn "I1[0-35]" | dep "F3[23]") ///
        id(pid) collapse cooccurrence
    matrix C = r(cooccurrence)
    * diagonal = patients ever matching; off-diagonal = patients matching both
    assert C[1,1] == `m_dm2'
    assert C[2,2] == `m_htn'
    assert C[3,3] == `m_dep'
    assert C[1,2] == `m_dm2_htn'
    assert C[1,3] == `m_dm2_dep'
    assert C[2,3] == `m_htn_dep'
    assert C[2,1] == `m_dm2_htn'
}
if _rc == 0 {
    display as result "  PASS: patient-level cooccurrence (collapse) recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: patient-level cooccurrence (collapse) recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 13: tostring on numeric code variables

local ++test_count
capture noisily {
    clear
    set seed 424242
    set obs 5000
    * numeric code pool: 250,251 (target prefix "25"); 401,428 (non-target)
    gen int ncode = 250
    replace ncode = 251 if mod(_n,4) == 1
    replace ncode = 401 if mod(_n,4) == 2
    replace ncode = 428 if mod(_n,4) == 3
    * oracle on the numeric values: prefix "25" hits 250 and 251
    gen byte o_dm = inlist(ncode, 250, 251)
    quietly count if o_dm == 1
    local truth = r(N)
    assert `truth' > 0
    codescan ncode, define(dm "25") mode(prefix) tostring
    quietly count if dm == 1
    assert r(N) == `truth'
    assert dm == o_dm
}
if _rc == 0 {
    display as result "  PASS: tostring numeric-code prefix recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: tostring numeric-code prefix recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 14: label() sets the condition's variable label

local ++test_count
capture noisily {
    _cs_makedata
    * label() entries are separated by a backslash (per the help file), not |
    codescan dx1 dx2 dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        label(dm2 "Type 2 diabetes" \ htn "Hypertension")
    local l_dm2 : variable label dm2
    local l_htn : variable label htn
    assert "`l_dm2'" == "Type 2 diabetes"
    assert "`l_htn'" == "Hypertension"
    * default (no label) falls back to the condition name
    codescan dx1 dx2 dx3, define(dm2 "E11") replace
    local l_def : variable label dm2
    assert "`l_def'" == "dm2"
}
if _rc == 0 {
    display as result "  PASS: label() variable-label recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: label() variable-label recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 15: detail varcounts attribute each matched row to its FIRST slot

local ++test_count
capture noisily {
    _cs_makedata
    * oracle: which slot (1..3) first matches dm2 for each row (0 = no match)
    gen byte o_slot = 0
    forvalues s = 1/3 {
        replace o_slot = `s' if o_slot == 0 & ustrregexm(dx`s', "^(E11)")
    }
    forvalues s = 1/3 {
        quietly count if o_slot == `s'
        local vc`s' = r(N)
    }
    codescan dx1 dx2 dx3, define(dm2 "E11") detail
    matrix V = r(varcounts)
    assert V[1,1] == `vc1'
    assert V[1,2] == `vc2'
    assert V[1,3] == `vc3'
    * column sum = number of matching rows (each row attributed once)
    quietly count if o_dm2 == 1
    assert V[1,1] + V[1,2] + V[1,3] == r(N)
}
if _rc == 0 {
    display as result "  PASS: detail varcounts first-slot attribution recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: detail varcounts first-slot attribution recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 16: combined multi-output collapse (nrows + count + first/last)

local ++test_count
capture noisily {
    _cs_makedata
    preserve
        bysort pid: egen long o_nrows = total(o_dm2)
        keep if o_dm2 == 1
        bysort pid visit_dt: gen byte _fd = (_n == 1)
        bysort pid: egen int o_udates = total(_fd)
        bysort pid: egen int o_first = min(visit_dt)
        bysort pid: egen int o_last  = max(visit_dt)
        bysort pid: keep if _n == 1
        keep pid o_nrows o_udates o_first o_last
        tempfile mo
        save `mo'
    restore
    codescan dx1 dx2 dx3, define(dm2 "E11") id(pid) date(visit_dt) ///
        collapse countrows countdate earliestdate latestdate
    merge 1:1 pid using `mo', keep(master match)
    * matched patients recover every summary; unmatched patients have 0 counts
    assert dm2_nrows == o_nrows if _merge == 3
    assert dm2_count == o_udates if _merge == 3
    assert dm2_first == o_first if _merge == 3
    assert dm2_last  == o_last  if _merge == 3
    assert dm2_count == 0 if _merge == 1
    assert dm2_nrows == 0 if _merge == 1
}
if _rc == 0 {
    display as result "  PASS: combined multi-output collapse recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: combined multi-output collapse recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 17: alldates shorthand equals earliest+latest+countdate

local ++test_count
capture noisily {
    _cs_makedata
    preserve
        keep if o_dm2 == 1
        bysort pid visit_dt: gen byte _fd = (_n == 1)
        bysort pid: egen int o_udates = total(_fd)
        bysort pid: egen int o_first = min(visit_dt)
        bysort pid: egen int o_last  = max(visit_dt)
        bysort pid: keep if _n == 1
        keep pid o_udates o_first o_last
        tempfile ad
        save `ad'
    restore
    codescan dx1 dx2 dx3, define(dm2 "E11") id(pid) date(visit_dt) ///
        collapse alldates
    * alldates must materialise all three date-summary variables
    confirm variable dm2_first
    confirm variable dm2_last
    confirm variable dm2_count
    merge 1:1 pid using `ad', keep(master match)
    assert dm2_first == o_first if _merge == 3
    assert dm2_last  == o_last  if _merge == 3
    assert dm2_count == o_udates if _merge == 3
}
if _rc == 0 {
    display as result "  PASS: alldates shorthand recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: alldates shorthand recovery (error `=_rc')"
    local ++fail_count
}

**# Scenario 18: window-boundary contract — empty window errors, full window recovers

local ++test_count
capture noisily {
    _cs_makedata
    * plain (no window) recovers the real cohort
    codescan dx1 dx2 dx3, define(dm2 "E11")
    quietly count if dm2 == 1
    local t_plain = r(N)
    assert `t_plain' > 0
    * DOCUMENTED CONTRACT (test_codescan_functional.do, "Lookback(0) without
    * inclusive yields error 2000"): lookback(0) WITHOUT inclusive
    * yields the empty window [ref, ref); an empty analysis sample is a
    * deliberate error, not an all-zero cohort.  codescan errors 2000.
    capture codescan dx1 dx2 dx3, define(dm2 "E11") date(visit_dt) ///
        refdate(index_dt) lookback(0) replace
    assert _rc == 2000
    * a window wide enough to admit every visit must recover the SAME cohort
    * as the unwindowed scan -- the window machinery drops no valid match.
    codescan dx1 dx2 dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(10000) lookforward(10000) replace
    quietly count if dm2 == 1
    assert r(N) == `t_plain'
}
if _rc == 0 {
    display as result "  PASS: window-boundary contract (empty errors, wide recovers)"
    local ++pass_count
}
else {
    display as error "  FAIL: window-boundary contract (error `=_rc')"
    local ++fail_count
}

**# Scenario 19: Wilson score CI closed-form recovery at level 99 (wider than 95)

local ++test_count
* Captured OUTSIDE the block: the restore below must run even when an
* assertion inside fails, or level 99 leaks into every later scenario.
local lvl0 = c(level)
capture noisily {
    _cs_makedata
    quietly count if o_dm2 == 1
    local k = r(N)
    local n = _N
    local p = `k' / `n'
    * hand-computed 99% Wilson interval (percentages, clamped)
    local z = invnormal(1 - (1 - 99/100)/2)
    local z2 = `z' * `z'
    local center = (`p' + `z2'/(2*`n')) / (1 + `z2'/`n')
    local halfw  = (`z'/(1 + `z2'/`n')) * sqrt(`p'*(1-`p')/`n' + `z2'/(4*`n'*`n'))
    local lo99 = max(0,   (`center' - `halfw') * 100)
    local hi99 = min(100, (`center' + `halfw') * 100)
    set level 99
    codescan dx1 dx2 dx3, define(dm2 "E11")
    matrix SUM = r(summary)
    assert SUM[1,1] == `k'
    assert abs(SUM[1,2] - `p'*100) < 1e-6
    assert abs(SUM[1,3] - `lo99') < 1e-6
    assert abs(SUM[1,4] - `hi99') < 1e-6
    assert r(ci_level) == 99
    * a 99% interval is strictly wider than the default 95% interval
    local width99 = `hi99' - `lo99'
    local z95 = invnormal(0.975)
    local z952 = `z95' * `z95'
    local c95 = (`p' + `z952'/(2*`n')) / (1 + `z952'/`n')
    local h95 = (`z95'/(1 + `z952'/`n')) * sqrt(`p'*(1-`p')/`n' + `z952'/(4*`n'*`n'))
    local width95 = (min(100,(`c95'+`h95')*100)) - (max(0,(`c95'-`h95')*100))
    assert `width99' > `width95'
}
local _s19_rc = _rc
* Restore unconditionally, outside the captured block, before the verdict.
set level `lvl0'
if `_s19_rc' == 0 {
    display as result "  PASS: Wilson CI recovery at level 99 (wider than 95)"
    local ++pass_count
}
else {
    display as error "  FAIL: Wilson CI recovery at level 99 (error `_s19_rc')"
    local ++fail_count
}


**# Settings hygiene

* This suite must not leak a session setting to whatever runs next.
local ++test_count
capture noisily {
    assert c(level) == `_qa_level0'
    assert "`c(varabbrev)'" == "`_qa_va0'"
    assert "`c(pwd)'" == "`_qa_pwd0'"
}
if _rc == 0 {
    display as result "  PASS: no session setting leaked"
    local ++pass_count
}
else {
    display as error "  FAIL: session setting leaked (error `=_rc')"
    local ++fail_count
}


**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
_codescan_qa_publish "validation_codescan_dgp_recovery2" `test_count' `pass_count' `fail_count'
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_codescan_dgp_recovery2 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_codescan_dgp_recovery2 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close
