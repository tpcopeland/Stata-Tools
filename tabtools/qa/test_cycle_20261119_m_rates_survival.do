* test_cycle_20261119_m_rates_survival.do - 2026-11-19 review cycle, unit m_rates_survival
*   F1 ratetab honours stset fweights (expanded-data identity) and refuses
*      pweight/iweight instead of printing unweighted counts
*   F2 survtab median and limits under stset fweights (stci refuses weights;
*      the captured error printed NR), and parity with stci on unweighted data
*   F3 survtab Events counts failures, not subjects, in multiple-failure data

clear all
set more off
set varabbrev off
version 17.0

capture log close _cyc_mrs
log using "test_cycle_20261119_m_rates_survival.log", replace text name(_cyc_mrs)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* every c* cell of frame A equals frame B (the printed table cells)
capture program drop _cyc_frames_equal
program define _cyc_frames_equal
    args fa fb
    frame `fa': local na = _N
    frame `fb': local nb = _N
    assert `na' == `nb' & `na' > 0
    frame `fa': ds c*
    local cols "`r(varlist)'"
    foreach c of local cols {
        forvalues i = 1/`na' {
            frame `fa': local va = `c'[`i']
            frame `fb': local vb = `c'[`i']
            if `"`va'"' != `"`vb'"' {
                display as error `"cell `c'[`i']: `va' vs `vb'"'
                exit 9
            }
        }
    }
end

* the fweighted fixture of F1
capture program drop _cyc_f1_data
program define _cyc_f1_data
    clear
    set seed 4711
    set obs 200
    gen long rid = _n
    gen byte grp = 1 + mod(_n, 3)
    gen double t = rexponential(5) + 0.01
    gen byte d = runiform() < 0.4
    gen byte w = 1 + floor(runiform()*3)
end

**# F1 ratetab under stset weights
**## fweights: counts, person-time and exact limits match independent sums
local ++test_count
capture noisily {
    _cyc_f1_data
    * oracle by a different route: weighted sums of the raw variables
    forvalues g = 1/3 {
        quietly summarize d if grp == `g' [fw=w], meanonly
        local D`g' = r(sum)
        quietly summarize t if grp == `g' [fw=w], meanonly
        local Y`g' = r(sum)
    }
    quietly count
    local Nw = 0
    quietly summarize w, meanonly
    local Nw = r(sum)
    stset t [fw=w], failure(d)
    capture frame drop rf_w
    ratetab grp, per(1) digits(4) frame(rf_w)
    matrix E = r(estimates)
    assert r(N) == `Nw'
    assert strpos(`"`r(methods)'"', "weighted by the stset frequency weight w") > 0
    local cn : colnames E
    local ce : list posof "events" in cn
    local cp : list posof "persontime" in cn
    local cr : list posof "rate" in cn
    local cl : list posof "lb" in cn
    local cu : list posof "ub" in cn
    forvalues g = 1/3 {
        assert E[`g', `ce'] == `D`g''
        assert reldif(E[`g', `cp'], `Y`g'') < 1e-12
        assert reldif(E[`g', `cr'], `D`g'' / `Y`g'') < 1e-12
        assert reldif(E[`g', `cl'], invpoissontail(`D`g'', .025) / `Y`g'') < 1e-10
        assert reldif(E[`g', `cu'], invpoisson(`D`g'', .025) / `Y`g'') < 1e-10
    }
    * the printed events cell of group 1 is the weighted count (65)
    assert `D1' == 65
    frame rf_w: quietly count if strtrim(c1) == "1" & strtrim(c2) == "65"
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: ratetab fweighted counts and exact limits"
    local ++pass_count
}
else {
    display as error "  FAIL: ratetab fweighted counts and exact limits (rc=`=_rc')"
    local ++fail_count
}

**## fweights: every ci() method equals the expanded data, cells and r()
local ++test_count
capture noisily {
    foreach m in exact poisson cluster {
        local ciopt "ci(`m')"
        if "`m'" == "cluster" local ciopt "ci(cluster(rid))"
        _cyc_f1_data
        stset t [fw=w], failure(d)
        capture frame drop rf_a
        ratetab grp, per(1) digits(4) pydigits(3) `ciopt' frame(rf_a)
        matrix Ew = r(estimates)
        local Nw = r(N)
        _cyc_f1_data
        expand w
        stset t, failure(d)
        capture frame drop rf_b
        ratetab grp, per(1) digits(4) pydigits(3) `ciopt' frame(rf_b)
        matrix Ex = r(estimates)
        assert r(N) == `Nw'
        assert mreldif(Ew, Ex) < 1e-10
        _cyc_frames_equal rf_a rf_b
    }
}
if _rc == 0 {
    display as result "  PASS: ratetab fweighted = expanded data for exact, poisson, cluster"
    local ++pass_count
}
else {
    display as error "  FAIL: ratetab fweighted = expanded data for exact, poisson, cluster (rc=`=_rc')"
    local ++fail_count
}

**## pweight and iweight are refused (r(101)), no table is produced
local ++test_count
capture noisily {
    foreach wt in pw iw {
        _cyc_f1_data
        gen double sw = 0.5 + runiform() * 2
        stset t [`wt'=sw], failure(d)
        capture frame drop rf_p
        capture noisily ratetab grp, per(1) frame(rf_p)
        assert _rc == 101
        capture confirm frame rf_p
        assert _rc != 0
    }
}
if _rc == 0 {
    display as result "  PASS: ratetab refuses stset pweight and iweight"
    local ++pass_count
}
else {
    display as error "  FAIL: ratetab refuses stset pweight and iweight (rc=`=_rc')"
    local ++fail_count
}

**## unweighted stset data and events()/exposure() keep their counts
local ++test_count
capture noisily {
    _cyc_f1_data
    stset t, failure(d)
    ratetab grp, per(1)
    matrix E = r(estimates)
    assert r(N) == 200
    quietly count if grp == 1 & d == 1
    local cn : colnames E
    local ce : list posof "events" in cn
    assert E[1, `ce'] == r(N)
    * explicit events()/exposure() ignore an stset weight (own variables)
    _cyc_f1_data
    gen double sw = 0.5 + runiform() * 2
    stset t [pw=sw], failure(d)
    ratetab grp, events(d) exposure(t) per(1)
    matrix E = r(estimates)
    assert r(N) == 200
    quietly count if grp == 1 & d == 1
    assert E[1, `ce'] == r(N)
}
if _rc == 0 {
    display as result "  PASS: ratetab unweighted paths unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: ratetab unweighted paths unchanged (rc=`=_rc')"
    local ++fail_count
}

**# F2 survtab median
* the fweighted fixture of F2
capture program drop _cyc_f2_data
program define _cyc_f2_data
    clear
    set seed 7
    set obs 80
    gen byte grp = 1 + (_n > 40)
    gen double t = ceil(rexponential(3)*4)/4
    gen byte d = runiform() < 0.75
    gen byte w = 1 + floor(runiform()*3)
end

**## fweights: median and limits equal stci on the expanded data
local ++test_count
capture noisily {
    _cyc_f2_data
    expand w
    stset t, failure(d)
    forvalues g = 1/2 {
        quietly stci if grp == `g'
        local m`g' = r(p50)
        local l`g' = r(lb)
        local u`g' = r(ub)
    }
    * the documented values of the reviewer's run
    assert `m1' == 3.75 & `l1' == 1.5 & `u1' == 4
    assert `m2' == 3.75 & `l2' == 2 & `u2' == 5
    _cyc_f2_data
    stset t [fw=w], failure(d)
    capture frame drop sf_w
    survtab, times(1 2) by(grp) median digits(2) frame(sf_w)
    assert r(median_1) == `m1'
    assert r(median_2) == `m2'
    frame sf_w: quietly count if strpos(c1, "Median") & c2 == "3.75" & c3 == "3.75"
    assert r(N) == 1
    frame sf_w: quietly count if strpos(c1, "CI)") & c2 == "(1.50, 4.00)" & c3 == "(2.00, 5.00)"
    assert r(N) == 1
    * overall (no by()): weighted = expanded
    survtab, times(1 2) median
    local mo = r(median_1)
    _cyc_f2_data
    expand w
    stset t, failure(d)
    quietly stci
    assert `mo' == r(p50) & !missing(`mo')
}
if _rc == 0 {
    display as result "  PASS: survtab fweighted median = stci on expanded data"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab fweighted median = stci on expanded data (rc=`=_rc')"
    local ++fail_count
}

**## unweighted: median and printed limits equal stci (ties at 0.5, NR, level, delayed entry)
local ++test_count
capture noisily {
    local nbad 0
    forvalues r = 1/40 {
        clear
        set seed `=2000 + `r''
        local n = 6 + floor(runiform() * 50)
        set obs `n'
        gen byte grp = 1 + mod(_n, 2)
        if mod(`r', 3) == 0 gen double t = ceil(rexponential(3) * 2) / 2
        else gen double t = rexponential(3) + .01
        gen byte d = runiform() < cond(mod(`r', 5) == 0, .3, .8)
        gen double t0 = cond(mod(`r', 4) == 0, t * runiform() * .5, 0)
        quietly stset t, failure(d) time0(t0)
        local lev = cond(mod(`r', 2), 95, 90)
        capture frame drop sf_u
        quietly survtab, times(1) by(grp) median level(`lev') digits(6) frame(sf_u)
        local s1 = r(median_1)
        local s2 = r(median_2)
        forvalues g = 1/2 {
            quietly stci if grp == `g', level(`lev')
            local p = r(p50)
            local lb = r(lb)
            local ub = r(ub)
            if !(missing(`p') & missing(`s`g'')) & reldif(`p', `s`g'') > 1e-12 local ++nbad
            local el = cond(missing(`lb'), "NR", strtrim(string(`lb', "%21.6f")))
            local eu = cond(missing(`ub'), "NR", strtrim(string(`ub', "%21.6f")))
            local ex "(`el', `eu')"
            if missing(`lb') & missing(`ub') local ex ""
            local c = `g' + 1
            frame sf_u: quietly levelsof c`c' if strpos(c1, "CI)") > 0, local(got) clean
            if `"`got'"' != `"`ex'"' {
                display as error `"r=`r' g=`g': stci `ex' survtab `got'"'
                local ++nbad
            }
        }
    }
    assert `nbad' == 0
    * a hand case with S(t) exactly 0.5: 4 subjects fail at 1 2 3 4;
    * S(2) = 0.5, so the median is 2 (minimum t with S(t) <= 0.5)
    clear
    input double t byte d byte grp
    1 1 1
    2 1 1
    3 1 1
    4 1 1
    1 1 2
    2 0 2
    3 0 2
    4 0 2
    end
    stset t, failure(d)
    survtab, times(1) by(grp) median
    assert r(median_1) == 2
    assert missing(r(median_2))
}
if _rc == 0 {
    display as result "  PASS: survtab median and limits = stci on unweighted data"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab median and limits = stci on unweighted data (rc=`=_rc')"
    local ++fail_count
}

**# F3 survtab events in multiple-failure data
**## Events counts failures; N stays subjects; single-failure split data unchanged
local ++test_count
capture noisily {
    clear
    input long id double(t0 t) byte d byte grp
    1 0 1 1 1
    1 1 2 1 1
    1 2 3 0 1
    2 0 2 1 1
    3 0 1.5 1 2
    3 1.5 2.5 1 2
    4 0 3 0 2
    end
    stset t, id(id) failure(d) time0(t0) exit(time .)
    capture frame drop sf_e
    survtab, times(1 2) by(grp) events frame(sf_e)
    assert r(events_1) == 3
    assert r(events_2) == 2
    assert r(atrisk_1) == 2 & r(atrisk_2) == 2
    frame sf_e: quietly count if c1 == "Events / N" & c2 == "3 / 2" & c3 == "2 / 2"
    assert r(N) == 1
    * single failure per subject, split into several records: one event each
    clear
    input long id double(t0 t) byte d byte grp
    1 0 1 0 1
    1 1 2 1 1
    2 0 1 0 1
    2 1 3 0 1
    3 0 2 1 2
    4 0 1 0 2
    4 1 2.5 1 2
    end
    stset t, id(id) failure(d) time0(t0)
    survtab, times(1 2) by(grp) events
    assert r(events_1) == 1
    assert r(events_2) == 2
}
if _rc == 0 {
    display as result "  PASS: survtab events count failures"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab events count failures (rc=`=_rc')"
    local ++fail_count
}

display as result "test_cycle_20261119_m_rates_survival: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_cycle_20261119_m_rates_survival tests=`_tc' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1

log close _cyc_mrs
