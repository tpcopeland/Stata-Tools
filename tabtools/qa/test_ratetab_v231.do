* test_ratetab_v231.do - ratetab per-outcome person-time, zerocells(),
* masktext(), excludemasked, saving(), tabtools 2.3.1
* Oracles: event and person-time sums by hand (summarize), exact Poisson
* limits invpoissontail()/invpoisson() over those sums, and the closed-form
* cluster sandwich of the saturated Poisson model computed by hand
* (rate-intervals.notes.md, sec. 3):
*     Var b_j = G/(G-1) * sum_c (d_cj - Y_cj D_j/Y_j)^2 / D_j^2
* with G the clusters in the fit; excludemasked changes only G.

clear all
set more off
set varabbrev off
version 17.0

capture log close _rt231
log using "test_ratetab_v231.log", replace text name(_rt231)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

local pass_count = 0
local fail_count = 0

* Two outcomes with their own person-time; g has levels 1 and 2.
capture program drop _rt231_two
program define _rt231_two
    version 17.0
    clear
    quietly set obs 12
    gen long id = _n
    gen byte g = 1 + (_n > 6)
    gen long e1 = mod(_n, 3)
    gen long e2 = mod(_n, 2)
    gen double py1 = 1 + _n / 4
    gen double py2 = 0.5 + _n / 10
end

* Clustered fixture. Levels 1 (ids 1-20) and 2 (ids 21-36) carry many events;
* level 3 carries 2 events, from ids 37 and 38 only, plus zero-event rows of
* ids 39, 40 and of id 1 (who is also in level 1).
capture program drop _rt231_clus
program define _rt231_clus
    version 17.0
    clear
    set seed 20261005
    quietly set obs 40
    gen long id = _n
    quietly expand 2
    bysort id: gen byte k = _n
    gen byte grp = cond(id <= 20, 1, cond(id <= 36, 2, 3))
    gen double pt = runiform(0.5, 2)
    gen long ev = rpoisson(1.5 * pt * grp) if grp < 3
    quietly replace ev = (id == 37 | id == 38) & k == 1 if grp == 3
    * id 1's second row moves to level 3 with no events
    quietly replace grp = 3 if id == 1 & k == 2
    quietly replace ev = 0 if id == 1 & k == 2
end

* Hand closed-form clustered limits for level `lev' of grp over the rows
* with `fitif', at G = clusters among those rows; into r(lb) r(ub) r(G).
capture program drop _rt231_cf
program define _rt231_cf, rclass
    version 17.0
    args lev fitif
    preserve
    quietly keep if `fitif'
    quietly levelsof id
    local G = r(r)
    quietly keep if grp == `lev'
    collapse (sum) dc = ev yc = pt, by(id)
    quietly summarize dc
    local D = r(sum)
    quietly summarize yc
    local Y = r(sum)
    gen double u2 = (dc - yc * `D' / `Y')^2
    quietly summarize u2
    local V = `G' / (`G' - 1) * r(sum) / `D'^2
    local z = invnormal(0.975)
    return scalar lb = 1000 * exp(ln(`D' / `Y') - `z' * sqrt(`V'))
    return scalar ub = 1000 * exp(ln(`D' / `Y') + `z' * sqrt(`V'))
    return scalar G = `G'
    restore
end

**# R1: one exposure() variable per outcome, paired with events()
capture noisily {
    _rt231_two
    ratetab g, events(e1 e2) exposure(py1 py2) frame(_r1, replace)
    matrix E = r(estimates)
    assert rowsof(E) == 4 & r(N) == 12
    local r 0
    forvalues o = 1/2 {
        forvalues l = 1/2 {
            local ++r
            quietly summarize e`o' if g == `l'
            local D = r(sum)
            quietly summarize py`o' if g == `l'
            local Y = r(sum)
            assert E[`r', 1] == `o' & E[`r', 3] == `l'
            assert E[`r', 4] == `D'
            assert reldif(E[`r', 5], `Y') < 1e-12
            assert reldif(E[`r', 6], 1000 * `D' / `Y') < 1e-12
            assert reldif(E[`r', 7], 1000 * invpoissontail(`D', 0.025) / `Y') < 1e-12
            assert reldif(E[`r', 8], 1000 * invpoisson(`D', 0.025) / `Y') < 1e-12
        }
    }
    * printed person-time: outcome 1 (c3) the py1 sum, outcome 2 (c6) the
    * py2 sum (level 1: 11.25 -> 11 and 5.1 -> 5)
    frame _r1: assert c3[5] == "11" & c6[5] == "5"
    forvalues l = 1/2 {
        quietly summarize py1 if g == `l'
        frame _r1: assert c3[`=4 + `l''] == string(round(r(sum), 1), "%24.0fc")
        quietly summarize py2 if g == `l'
        frame _r1: assert c6[`=4 + `l''] == string(round(r(sum), 1), "%24.0fc")
    }
    frame drop _r1
    * one exposure() variable is still shared by every outcome
    ratetab g, events(e1 e2) exposure(py1)
    matrix S = r(estimates)
    quietly summarize py1 if g == 1
    assert reldif(S[3, 5], r(sum)) < 1e-12
    * clustered limits per outcome use that outcome's person-time
    ratetab g, events(e1 e2) exposure(py1 py2) ci(cluster(id))
    matrix C2 = r(estimates)
    ratetab g, events(e2) exposure(py2) ci(cluster(id))
    matrix C1 = r(estimates)
    matrix C2b = C2[3..4, 4..8]
    matrix C1b = C1[1..2, 4..8]
    assert mreldif(C2b, C1b) < 1e-10
    * refusals: lengths that do not pair
    capture ratetab g, events(e1 e2) exposure(py1 py2 py1)
    assert _rc == 198
    capture ratetab g, events(e1) exposure(py1 py2)
    assert _rc == 198
    * events without person-time are judged against the outcome's own variable
    replace py2 = 0 in 1
    replace e2 = 0 in 1
    replace e1 = 1 in 1
    ratetab g, events(e1 e2) exposure(py1 py2)
    replace e2 = 1 in 1
    capture ratetab g, events(e1 e2) exposure(py1 py2)
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: R1 per-outcome exposure(): hand sums and exact limits; refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 per-outcome exposure() (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _r1

**# R2: zerocells(dash|blank) prints no count or rate; r() keeps the numbers
capture noisily {
    clear
    quietly set obs 4
    gen byte g = 1 + (_n > 2)
    gen long ev = cond(_n <= 2, 0, 4)
    gen double pt = 50
    ratetab g, events(ev) exposure(pt) frame(_r2, replace) zerocells(dash)
    frame _r2: assert c2[5] == "–" & c3[5] == "100" & c4[5] == "–"
    frame _r2: assert c2[6] == "8" & c3[6] == "100"
    matrix E = r(estimates)
    assert E[1, 4] == 0 & E[1, 6] == 0 & E[1, 7] == 0
    assert reldif(E[1, 8], 1000 * -ln(0.025) / 100) < 1e-12
    assert strpos(`"`r(methods)'"', "cells with no events are printed without a count or rate") > 0
    assert strpos(`"`r(methods)'"', "exact upper limit") == 0
    ratetab g, events(ev) exposure(pt) frame(_r2, replace) zerocells(blank) ci(poisson)
    frame _r2: assert c2[5] == "" & c3[5] == "100" & c4[5] == ""
    * default unchanged: 0 with the exact limits
    ratetab g, events(ev) exposure(pt) frame(_r2, replace)
    local want = "0.0 (0.0, " + strtrim(string(round(1000 * -ln(0.025) / 100, 0.1), "%24.1f")) + ")"
    frame _r2: assert c2[5] == "0" & c4[5] == "`want'"
    assert strpos(`"`r(methods)'"', "exact upper limit") > 0
    capture ratetab g, events(ev) exposure(pt) zerocells(zero)
    assert _rc == 198
    frame drop _r2
}
if _rc == 0 {
    display as result "  PASS: R2 zerocells(dash|blank) cells, numbers kept, methods sentence"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 zerocells() (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _r2

**# R3: masktext() replaces the masked count text; the default stays <#
capture noisily {
    clear
    quietly set obs 4
    gen byte g = 1 + (_n > 2)
    gen long ev = cond(_n <= 2, 1, 5)
    gen double pt = 50
    ratetab g, events(ev) exposure(pt) frame(_r3, replace) smallcells(5) masktext("–")
    frame _r3: assert c2[5] == "–" & c3[5] == "–" & c4[5] == "–"
    frame _r3: assert c2[6] == "10" & c3[6] == "100"
    assert strpos(`"`r(methods)'"', "events are shown as – with") > 0
    ratetab g, events(ev) exposure(pt) frame(_r3, replace) smallcells(5)
    frame _r3: assert c2[5] == "<5" & c3[5] == "–"
    assert strpos(`"`r(methods)'"', "events are shown as <5 with") > 0
    * the session default threshold is honoured
    tabtools set smallcells 5
    ratetab g, events(ev) exposure(pt) frame(_r3, replace) masktext("n<5")
    frame _r3: assert c2[5] == "n<5"
    quietly tabtools set clear
    capture ratetab g, events(ev) exposure(pt) masktext("–")
    assert _rc == 198
    frame drop _r3
}
if _rc == 0 {
    display as result "  PASS: R3 masktext() cells and methods; default <# unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 masktext() (rc=`=_rc')"
    local ++fail_count
}
quietly tabtools set clear
capture frame drop _r3

**# R4: excludemasked: masked levels leave the clustered fit; only G changes
capture noisily {
    _rt231_clus
    * level 3 has 2 events: masked at smallcells(5)
    quietly summarize ev if grp == 3
    assert r(sum) == 2
    * without excludemasked: all levels with events in the fit, G = 40
    ratetab grp, events(ev) exposure(pt) ci(cluster(id)) smallcells(5)
    matrix A = r(estimates)
    assert el(r(clusters), 1, 1) == 40 & r(N_noci) == 0
    forvalues l = 1/2 {
        _rt231_cf `l' "1"
        assert r(G) == 40
        assert reldif(A[`l', 7], r(lb)) < 1e-8 & reldif(A[`l', 8], r(ub)) < 1e-8
    }
    * with excludemasked: level 3 out of the fit, G = 36 (id 1 stays)
    ratetab grp, events(ev) exposure(pt) ci(cluster(id)) smallcells(5) excludemasked
    matrix B = r(estimates)
    assert el(r(clusters), 1, 1) == 36
    assert r(N_maskfit) == 1 & r(N_noci) == 0
    assert strpos(`"`r(methods)'"', "levels with 1 to 4 events were left out of the clustered fit") > 0
    forvalues l = 1/2 {
        _rt231_cf `l' "grp != 3"
        assert r(G) == 36
        assert reldif(B[`l', 7], r(lb)) < 1e-8 & reldif(B[`l', 8], r(ub)) < 1e-8
        * estimate unchanged; the interval moves only by the G/(G-1) factor
        assert B[`l', 4] == A[`l', 4] & reldif(B[`l', 6], A[`l', 6]) < 1e-12
        local seA = ln(A[`l', 8] / A[`l', 6]) / invnormal(0.975)
        local seB = ln(B[`l', 8] / B[`l', 6]) / invnormal(0.975)
        assert reldif(`seB' / `seA', sqrt((36 / 35) / (40 / 39))) < 1e-8
    }
    * the masked level keeps its counts, has no interval
    assert B[3, 4] == 2 & missing(B[3, 7]) & missing(B[3, 8])
    assert !missing(A[3, 7])
    * session threshold; refusals
    tabtools set smallcells 5
    ratetab grp, events(ev) exposure(pt) ci(cluster(id)) excludemasked
    matrix S = r(estimates)
    matrix S2 = S[1..2, 1...]
    matrix B2 = B[1..2, 1...]
    assert mreldif(S2, B2) < 1e-12
    capture ratetab grp, events(ev) exposure(pt) ci(cluster(id)) excludemasked nosmallcells
    assert _rc == 198
    quietly tabtools set clear
    capture ratetab grp, events(ev) exposure(pt) ci(cluster(id)) excludemasked
    assert _rc == 198
    capture ratetab grp, events(ev) exposure(pt) ci(cluster(id)) excludemasked smallcells(1)
    assert _rc == 198
    capture ratetab grp, events(ev) exposure(pt) ci(exact) excludemasked smallcells(5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: R4 excludemasked equals the closed form at the reduced G; refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: R4 excludemasked (rc=`=_rc')"
    local ++fail_count
}
quietly tabtools set clear

**# R5: saving() writes the numbers per level; existing file needs replace
capture noisily {
    local f "`output_dir'/rt231_saved"
    capture erase "`f'.dta"
    _rt231_two
    label variable e1 "First outcome"
    label define _rt231_g 1 "Low" 2 "High", replace
    label values g _rt231_g
    ratetab g, events(e1 e2) exposure(py1 py2) smallcells(3) saving("`f'")
    matrix E = r(estimates)
    assert `"`r(saving)'"' == "`f'"
    preserve
    use "`f'", clear
    assert _N == 4
    forvalues r = 1/4 {
        assert outcome[`r'] == E[`r', 1] & group[`r'] == E[`r', 2] & level[`r'] == E[`r', 3]
        assert events[`r'] == E[`r', 4]
        assert persontime[`r'] == E[`r', 5] & rate[`r'] == E[`r', 6]
        assert lb[`r'] == E[`r', 7] & ub[`r'] == E[`r', 8]
    }
    assert outcome_var[1] == "e1" & outcome_var[3] == "e2"
    assert outcome_label[1] == "First outcome" & outcome_label[3] == "e2"
    assert groupvar[1] == "g" & level_label[1] == "Low" & level_label[2] == "High"
    * hand: level 1 of outcome 1, e1 over py1
    restore
    quietly summarize e1 if g == 1
    local D = r(sum)
    quietly summarize py1 if g == 1
    local Y = r(sum)
    preserve
    use "`f'", clear
    assert events[1] == `D' & reldif(persontime[1], `Y') < 1e-12
    assert reldif(rate[1], 1000 * `D' / `Y') < 1e-12
    * masked: 1 to 2 events at smallcells(3)
    assert masked == (events >= 1 & events < 3)
    restore
    * an existing file is refused before any work, then replaced on request
    capture ratetab g, events(e1 e2) exposure(py1 py2) saving("`f'")
    assert _rc == 602
    ratetab g, events(e1) exposure(py1) saving("`f'.dta", replace)
    preserve
    use "`f'", clear
    assert _N == 2
    restore
    capture ratetab g, events(e1) exposure(py1) saving("`f'", bogus)
    assert _rc == 198
    capture ratetab g, events(e1) exposure(py1) saving(, replace)
    assert _rc == 198
    capture erase "`f'.dta"
}
if _rc == 0 {
    display as result "  PASS: R5 saving() rows equal r(estimates) and hand sums; replace guard"
    local ++pass_count
}
else {
    display as error "  FAIL: R5 saving() (rc=`=_rc')"
    local ++fail_count
}
capture restore

**# R6: help-file examples (drugtr)
capture noisily {
    webuse drugtr, clear
    generate id = _n
    generate double pt = _t - _t0
    generate byte died2 = died & _t < 20
    generate double pt2 = min(_t, 20) - _t0
    local f "`output_dir'/rt231_rates"
    capture erase "`f'.dta"
    ratetab drug, events(died died2) exposure(pt pt2) smallcells(15) masktext("–") zerocells(dash) saving("`f'", replace)
    matrix E = r(estimates)
    quietly summarize pt2 if drug == 1
    assert reldif(E[4, 5], r(sum)) < 1e-12
    ratetab drug, ci(cluster(id)) smallcells(15) excludemasked
    assert r(N_maskfit) == 1
    capture erase "`f'.dta"
}
if _rc == 0 {
    display as result "  PASS: R6 help examples run"
    local ++pass_count
}
else {
    display as error "  FAIL: R6 help examples (rc=`=_rc')"
    local ++fail_count
}

**# R7: session hygiene: varabbrev and frames on success and error
capture noisily {
    _rt231_two
    set varabbrev on
    quietly frames dir
    local before `"`r(frames)'"'
    capture ratetab g, events(e1 e2) exposure(py1 py2 py1)
    assert c(varabbrev) == "on"
    ratetab g, events(e1 e2) exposure(py1 py2) zerocells(dash)
    assert c(varabbrev) == "on"
    quietly frames dir
    assert `"`r(frames)'"' == `"`before'"'
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: R7 varabbrev restored and no frames left"
    local ++pass_count
}
else {
    display as error "  FAIL: R7 session hygiene (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off

local _tc = `pass_count' + `fail_count'
display "RESULT: test_ratetab_v231 tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _rt231
if `fail_count' > 0 exit 1
