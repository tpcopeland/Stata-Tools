* test_regtab_v230_review.do - independent-review regressions for the 2.3.0
* regtab / effecttab / tabtools fitcount slice. Each block reproduces a defect
* found by reading the code; every block failed on the pre-fix code.
*   R1  fitcount, terms on mlogit: the base-outcome equation (every coefficient
*       constrained, zero variance) marked every level "no variance", so
*       mincount() masked every non-base level of every equation
*   R2  fitcount after svy, subpop(): e(sample) spans the whole design, so the
*       counts included observations outside the subpopulation; now refused
*   R3  fitcount after fweights: refused with a misleading e(N) message; now an
*       explicit weights refusal, r(101)
*   R4  cellnote() with the text missing silently blanked the cell
*   R5  frame(, flat): a header longer than 80 bytes was cut mid-character,
*       leaving an invalid UTF-8 variable label
*   R6  frame(, flat): rowlabel's empty label made puttab, varlabels print
*       "rowlabel" in the table's corner cell, which regtab leaves blank
*   R8  fitcount identity: a same-command refit on changed data was attached
*   R9  fitcount name() for collect, name(): fits
*   R10 comma-decimal cformat() with a comma in sep() refused
*   R11 stats(obs): e(N) beside n's subjects for st models
*   R12 transposed multi-equation headers: eq: Factor: level
*   R7  footnote() paragraphs typed in their own quotes: Excel stripped the
*       quotes, CSV/Markdown did not; every sink now gets the same text

clear all
set more off
set varabbrev off
version 17.0

capture log close _rvrev
log using "test_regtab_v230_review.log", replace text name(_rvrev)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local dash = uchar(8211)

**# R1 mlogit: the base-outcome equation does not decide the variance flag
local ++test_count
capture noisily {
    clear
    set seed 2026
    quietly set obs 600
    generate byte g = 1 + mod(_n, 3)
    generate byte y = 0
    * outcome 1 and 2 events spread over every level of g; level 3 of g has
    * a single outcome-2 observation
    quietly replace y = 1 if runiform() < .3
    quietly replace y = 2 if runiform() < .3 & g != 3
    quietly replace y = 2 in 2
    generate byte ev = y == 2
    collect clear
    quietly collect: mlogit y i.g
    tabtools fitcount, events(ev) terms
    local t `"`r(terms)'"'
    * oracle: level 2 of g has many ev events and a finite variance in the
    * estimated equations 1 and 2
    quietly count if ev & g == 2 & e(sample)
    local ev2 = r(N)
    assert `ev2' >= 5
    assert strpos(`"`t'"', "2.g=`ev2'|1")
    * level 3: one event, masked
    assert strpos(`"`t'"', "3.g=1|1")
    regtab, mincount(5) frame(_r1, replace)
    assert r(N_masked) == 2
    frame _r1 {
        quietly count if strtrim(c1) == "`dash'"
        local nmask = r(N)
    }
    * one masked level (3) in each of the two displayed equations, never 2
    assert `nmask' == 2
}
if _rc == 0 {
    display as result "  PASS: R1 mlogit base-outcome equation does not mask every level"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 mlogit mincount (rc=`=_rc')"
    local ++fail_count
}

**# R2 svy subpop refused
local ++test_count
capture noisily {
    clear
    set seed 11
    quietly set obs 400
    generate psu = ceil(_n / 20)
    generate st = ceil(psu / 4)
    generate w = 1 + runiform()
    generate byte women = runiform() < .5
    generate byte y = runiform() < .3
    generate byte g = 1 + mod(_n, 3)
    quietly svyset psu [pw = w], strata(st)
    collect clear
    quietly collect: svy, subpop(women): logit y i.g
    capture noisily tabtools fitcount, events(y) terms
    assert _rc == 459
    * without subpop() it is accepted and counts e(sample)
    collect clear
    quietly collect: svy: logit y i.g
    tabtools fitcount, events(y)
    local fev = r(events)
    quietly count if y & e(sample)
    assert `fev' == r(N)
}
if _rc == 0 {
    display as result "  PASS: R2 svy subpop() refused, plain svy counted"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 svy subpop (rc=`=_rc')"
    local ++fail_count
}

**# R3 fweights refused explicitly; pweights counted as observations
local ++test_count
capture noisily {
    sysuse auto, clear
    generate byte fw = 1 + (rep78 == 3)
    collect clear
    quietly collect: logit foreign mpg [fw = fw]
    capture noisily tabtools fitcount, events(foreign)
    assert _rc == 101
    collect clear
    quietly collect: logit foreign mpg [pw = fw]
    tabtools fitcount, events(foreign)
    assert r(events) == 22 & r(N) == 74
}
if _rc == 0 {
    display as result "  PASS: R3 fweight refused (r(101)), pweight counts observations"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 weights (rc=`=_rc')"
    local ++fail_count
}

**# R4 cellnote() needs its text
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    capture noisily regtab, cellnote("Mileage (mpg)" 1)
    assert _rc == 198
    * an explicit empty text is a deliberate blank and is accepted
    regtab, cellnote("Mileage (mpg)" 1 "") frame(_r4, replace)
    frame _r4 {
        quietly count if strtrim(A) == "Mileage (mpg)" & strtrim(c1) == "" & strtrim(c2) == ""
        assert r(N) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: R4 cellnote() without text refused"
    local ++pass_count
}
else {
    display as error "  FAIL: R4 cellnote() missing text (rc=`=_rc')"
    local ++fail_count
}

**# R5 flat label truncation keeps whole characters
* The label is the statistic header (2.4.0), so a long coef() header is what
* reaches the 80-character variable-label limit.
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg
    local nm = "a" + 45 * uchar(233)
    regtab, coef("`nm'") frame(_r5, replace flat)
    frame _r5 {
        local L : variable label c1
        local H : char c1[tabtools_header]
    }
    * 50 characters (95 bytes) fit a variable label whole
    assert ustrinvalidcnt(`"`L'"') == 0
    assert `"`L'"' == `"`nm'"'
    assert `"`H'"' == `"Model, `nm'"'
    * past 80 characters the label is cut on a character boundary
    local nm2 = "a" + 90 * uchar(233)
    regtab, coef("`nm2'") frame(_r5, replace flat)
    frame _r5 {
        local L : variable label c1
        local H : char c1[tabtools_header]
    }
    assert ustrinvalidcnt(`"`L'"') == 0
    assert ustrlen(`"`L'"') == 80
    assert usubstr(`"`nm2'"', 1, 80) == `"`L'"'
    assert `"`H'"' == `"Model, `nm2'"'
    * a long model name: whole in char c#[tabtools_block] and in the
    * header char; the label (the statistic header) is not cut
    regtab, models("`nm2'") frame(_r5, replace flat)
    frame _r5 {
        local L : variable label c1
        local H : char c1[tabtools_header]
        local B : char c1[tabtools_block]
    }
    assert `"`B'"' == `"`nm2'"'
    assert ustrinvalidcnt(`"`H'"') == 0 & `"`H'"' == `"`nm2', OR"'
    assert `"`L'"' == "OR"
}
if _rc == 0 {
    display as result "  PASS: R5 flat label truncated on a character boundary"
    local ++pass_count
}
else {
    display as error "  FAIL: R5 flat unicode label (rc=`=_rc')"
    local ++fail_count
}

**# R6 flat frame corner cell is blank through puttab, varlabels
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    regtab, frame(_r6, replace flat)
    local f "`output_dir'/_rv_flat_corner.xlsx"
    capture erase "`f'"
    frame _r6: puttab rowlabel c* using "`f'", sheet("S") varlabels
    import excel using "`f'", sheet("S") clear allstring
    quietly ds
    local vl `r(varlist)'
    local hit = 0
    foreach v of local vl {
        quietly count if strtrim(`v') == "rowlabel"
        if r(N) local hit = 1
        quietly count if strtrim(`v') == "Coef."
        if r(N) local hdr = 1
    }
    assert `hit' == 0
    assert "`hdr'" == "1"
}
if _rc == 0 {
    display as result "  PASS: R6 flat rowlabel header is blank"
    local ++pass_count
}
else {
    display as error "  FAIL: R6 flat rowlabel header (rc=`=_rc')"
    local ++fail_count
}

**# R7 quoted footnote paragraphs: same text in Excel and CSV (regtab, effecttab)
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    local f "`output_dir'/_rv_fnq"
    capture erase "`f'.xlsx"
    regtab, xlsx("`f'.xlsx") sheet("Q") csv("`f'.csv") ///
        footnote(`""First, quoted." \ Second."')
    import excel using "`f'.xlsx", sheet("Q") clear allstring
    local n0 = _N
    local x1 = strtrim(B[`n0' - 1])
    local x2 = strtrim(B[`n0'])
    import delimited using "`f'.csv", clear varnames(nonames) stringcols(_all) bindquote(strict)
    local n0 = _N
    local c1 = strtrim(v1[`n0' - 1])
    local c2 = strtrim(v1[`n0'])
    assert `"`x1'"' == `"`c1'"'
    assert `"`x2'"' == `"`c2'"'
    assert `"`x1'"' == `""First, quoted.""'
    assert `"`x2'"' == "Second."
    * effecttab: same rule
    sysuse auto, clear
    quietly logit foreign mpg
    collect clear
    quietly collect: margins, dydx(mpg)
    capture erase "`f'e.xlsx"
    effecttab, type(margins) xlsx("`f'e.xlsx") sheet("Q") ///
        footnote(`""First, quoted." \ Second."')
    import excel using "`f'e.xlsx", sheet("Q") clear allstring
    local n0 = _N
    assert strtrim(B[`n0' - 1]) == `""First, quoted.""'
    assert strtrim(B[`n0']) == "Second."
}
if _rc == 0 {
    display as result "  PASS: R7 quoted footnote paragraphs identical in Excel and CSV"
    local ++pass_count
}
else {
    display as error "  FAIL: R7 footnote quotes (rc=`=_rc')"
    local ++fail_count
}

**# R8 fitcount: the collected model must carry the active e(b)
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg weight
    * same command line, same N, different data: a different fit
    quietly replace weight = weight + 300 * (rep78 == 3)
    quietly logit foreign mpg weight
    capture noisily tabtools fitcount, events(foreign)
    assert _rc == 459
    * the collected fit itself passes, including an eform (HR) collection
    collect clear
    quietly collect: logit foreign mpg weight
    tabtools fitcount, events(foreign)
    assert r(events) == 22
    stset mpg, failure(foreign)
    quietly collect: stcox weight i.rep78
    tabtools fitcount, events(_d)
    assert r(cmdset) == 2
}
if _rc == 0 {
    display as result "  PASS: R8 refit with the same command line on changed data refused"
    local ++pass_count
}
else {
    display as error "  FAIL: R8 fitcount e(b) identity (rc=`=_rc')"
    local ++fail_count
}

**# R9 fitcount, name(): a collect, name(): fit
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    capture collect drop c2
    quietly collect: regress price mpg
    collect create c2
    quietly collect set default
    quietly collect, name(c2): logit foreign mpg
    assert "`c(collect_current)'" == "default"
    * the current collection lacks the fit: refused, never attached there
    capture noisily tabtools fitcount, events(foreign)
    assert _rc == 459
    tabtools fitcount, events(foreign) name(c2)
    assert r(events) == 22 & "`r(collection)'" == "c2" & r(cmdset) == 1
    assert "`c(collect_current)'" == "default"
    capture noisily tabtools fitcount, events(foreign) name(nosuchcoll)
    assert _rc == 111
    assert "`c(collect_current)'" == "default"
    quietly collect set c2
    regtab, stats(events) frame(_r9, replace)
    assert r(events_1) == 22
    quietly collect set default
    collect drop c2
}
if _rc == 0 {
    display as result "  PASS: R9 fitcount name() writes into the named collection"
    local ++pass_count
}
else {
    display as error "  FAIL: R9 fitcount name() (rc=`=_rc')"
    local ++fail_count
}

**# R10 comma-decimal cformat() needs a comma-free sep()
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg
    matrix T = r(table)
    capture noisily regtab, cformat(%9,2f)
    assert _rc == 198
    * a comma-free separator is accepted
    regtab, cformat(%9,2f) sep("; ")
    regtab, cformat(%9,2f) sep(" to ") frame(_r10, replace)
    local lo = subinstr(strtrim(string(exp(T[5, 1]), "%9,2f")), " ", "", .)
    local hi = subinstr(strtrim(string(exp(T[6, 1]), "%9,2f")), " ", "", .)
    frame _r10 {
        quietly count if strtrim(A) == "Mileage (mpg)" & strtrim(c2) == "(`lo' to `hi')"
        assert r(N) == 1
    }
    * a point-decimal cformat() keeps the comma separator
    regtab, cformat(%9.3f)
    quietly logit foreign mpg
    collect clear
    quietly collect: margins, dydx(mpg)
    capture noisily effecttab, type(margins) cformat(%9,3f)
    assert _rc == 198
    effecttab, type(margins) cformat(%9,3f) sep(" to ")
}
if _rc == 0 {
    display as result "  PASS: R10 comma-decimal cformat() refused with a comma sep()"
    local ++pass_count
}
else {
    display as error "  FAIL: R10 comma-decimal cformat() (rc=`=_rc')"
    local ++fail_count
}

**# R11 stats(obs): e(N) for a survival model, beside n's subjects
local ++test_count
capture noisily {
    clear
    set seed 5
    quietly set obs 100
    generate id = _n
    generate x = rnormal()
    quietly expand 3
    bysort id: generate t0 = _n - 1
    generate t1 = t0 + 1
    generate byte d = runiform() < .1
    quietly stset t1, id(id) time0(t0) failure(d)
    collect clear
    quietly collect: stcox x
    local eN = e(N)
    local eNs = e(N_sub)
    assert `eNs' == 100 & `eN' > `eNs'
    regtab, stats(n obs) frame(_r11, replace)
    assert r(obs_1) == `eN' & r(n_1) == `eNs'
    frame _r11 {
        quietly count if strtrim(A) == "Observations" & strtrim(c1) == "`eN'"
        assert r(N) == 1
        quietly count if strtrim(A) == "Subjects" & strtrim(c1) == "100"
        assert r(N) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: R11 stats(obs) prints e(N) for an st model"
    local ++pass_count
}
else {
    display as error "  FAIL: R11 stats(obs) (rc=`=_rc')"
    local ++fail_count
}

**# R12 transposed multi-equation headers keep regtab's "eq: " prefix
local ++test_count
capture noisily {
    sysuse auto, clear
    generate y3 = cond(rep78 >= 4, 2, cond(rep78 == 3, 1, 0)) if rep78 < .
    collect clear
    quietly collect: mlogit y3 i.foreign mpg, baseoutcome(1)
    regtab, frame(_r12u, replace)
    regtab, transpose nopvalue frame(_r12, replace flat)
    * the untransposed row label of eq 2's Foreign level
    frame _r12u {
        quietly count if ustrregexm(strtrim(A), "^2: +Foreign$")
        assert r(N) == 1
    }
    frame _r12 {
        local hits = 0
        foreach v of varlist c* {
            local L : char `v'[tabtools_header]
            if `"`L'"' == "2: Car origin: Foreign, RRR (95% CI)" local ++hits
            assert !ustrregexm(`"`L'"', "^Car origin: [0-9]+:")
        }
        assert `hits' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: R12 transposed multi-equation header reads eq: Factor: level"
    local ++pass_count
}
else {
    display as error "  FAIL: R12 transposed multi-equation header (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text ""
display "RESULT: test_regtab_v230_review tests=`test_count' pass=`pass_count' fail=`fail_count'"
foreach fr in _r1 _r4 _r5 _r6 _r9 _r10 _r11 _r12 _r12u {
    capture frame drop `fr'
}
log close _rvrev
if `fail_count' > 0 exit 1
