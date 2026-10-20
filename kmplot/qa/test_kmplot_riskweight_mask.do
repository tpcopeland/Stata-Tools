* test_kmplot_riskweight_mask.do
* kmplot riskweight() and riskmask(): people counts under weights, the weighted
* companions in risksaving(), and small-count masking
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-20
*
* Expected counts come from the fixture's design (counted by hand below and
* recomputed from the data by _kmrw_truth), never from kmplot's own output.
* Fixture: two groups of 40.  Group B falls to exactly 3 at risk at t = 8 and
* to 0 at 9.2; its cumulative censored count is 2 at t = 2; group A keeps 6 at
* risk to 9.2.  Under the pweights the 3 survivors of B weigh 1.3 + 0.8 + 1.1 =
* 3.2 and A's 6 survivors weigh 0.6 each.  The value 3 occurs in exactly one
* cell of the unmasked count table and 3.2 in exactly one weighted cell.

clear all
version 16.0
set varabbrev off
local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_kmplot_qa_common.do"
quietly do "`qa_dir'/_kmplot_qa_cifsupport.do"
_kmplot_qa_bootstrap
_kmqa_init
global TABTOOLS_set_smallcells ""

local tps "0 2 4 6 8 9.2"
local ntp 6

**# Fixture
capture program drop _kmrw_fix
program define _kmrw_fix
    version 16.0
    syntax , [WT(string)]
    clear
    set obs 80
    gen int id = _n
    gen byte g = 1 + (_n > 40)
    gen double t = .
    gen byte d = 0
    replace t = 1.2 in 1/5
    replace d = 1 in 1/5
    replace t = 3.2 in 6/10
    replace d = 1 in 6/10
    replace t = 6.5 in 11/34
    replace t = 9.5 in 35/40
    replace t = 0.9 in 41/45
    replace d = 1 in 41/45
    replace t = 2.9 in 46/50
    replace d = 1 in 46/50
    replace t = 4.9 in 51/55
    replace d = 1 in 51/55
    replace t = 6.9 in 56/60
    replace d = 1 in 56/60
    replace t = 1.5 in 61/62
    replace t = 3.5 in 63/67
    replace t = 5.5 in 68/72
    replace t = 7.5 in 73/77
    replace t = 9 in 78/80
    gen double w = 1
    replace w = 1.5 in 11/34
    replace w = .6 in 35/40
    replace w = 1.3 in 78
    replace w = .8 in 79
    replace w = 1.1 in 80
    gen int fw = 1 + (mod(id, 4) == 0) * (id <= 34)
    replace fw = 1 in 35/40
    replace fw = 1 in 78/80
    label define grp 1 "A" 2 "B"
    label values g grp
    if "`wt'" == "" quietly stset t, failure(d)
    else quietly stset t [`wt'=`=cond("`wt'" == "fw", "fw", "w")'], failure(d)
end

**# Truth from the fixture: people counts and summed weights per group and time
* Rows ordered group (1, 2) then timepoint; columns at_risk events censored.
capture program drop _kmrw_truth
program define _kmrw_truth
    version 16.0
    syntax , TPS(string) PEOPLE(name) WEIGHTED(name) [FW]
    local ntp : word count `tps'
    matrix `people' = J(2 * `ntp', 3, .)
    matrix `weighted' = J(2 * `ntp', 3, .)
    tempvar one
    quietly gen double `one' = 1
    local row = 0
    forvalues gi = 1/2 {
        foreach tp of local tps {
            local ++row
            local pw = cond("`fw'" != "", "fw", "`one'")
            local ww = "w"
            quietly summarize `pw' if g == `gi' & t >= `tp', meanonly
            matrix `people'[`row', 1] = r(sum)
            quietly summarize `ww' if g == `gi' & t >= `tp', meanonly
            matrix `weighted'[`row', 1] = r(sum)
            quietly summarize `pw' if g == `gi' & t <= `tp' & d == 1, meanonly
            matrix `people'[`row', 2] = r(sum)
            quietly summarize `ww' if g == `gi' & t <= `tp' & d == 1, meanonly
            matrix `weighted'[`row', 2] = r(sum)
            quietly summarize `pw' if g == `gi' & t <= `tp' & d == 0, meanonly
            matrix `people'[`row', 3] = r(sum)
            quietly summarize `ww' if g == `gi' & t <= `tp' & d == 0, meanonly
            matrix `weighted'[`row', 3] = r(sum)
        }
    }
end

* the three displayed count columns of r(risktable)
capture program drop _kmrw_counts
program define _kmrw_counts
    version 16.0
    syntax , FROM(name) INTO(name)
    matrix `into' = `from'[1..., 3..5]
end

**## R0 fixture self-check: the design facts the masking tests rely on
capture noisily {
    _kmrw_fix
    tempname P W
    _kmrw_truth, tps(`tps') people(`P') weighted(`W')
    * at risk: A 40 35 30 30 6 6 ; B 40 33 23 13 3 0
    local a "40 35 30 30 6 6 40 33 23 13 3 0"
    forvalues i = 1/12 {
        local e : word `i' of `a'
        assert `P'[`i', 1] == `e'
    }
    * exactly one 3 in the people table, exactly one weighted 3.2
    local n3 = 0
    local nw = 0
    forvalues i = 1/12 {
        forvalues j = 1/3 {
            if `P'[`i', `j'] == 3 local ++n3
            if abs(`W'[`i', `j'] - 3.2) < 1e-9 local ++nw
        }
    }
    assert `n3' == 1 & `nw' == 1
    assert `P'[11, 1] == 3 & abs(`W'[11, 1] - 3.2) < 1e-9
    assert `P'[2, 3] == 0 & `P'[8, 3] == 2
    * six people at risk in A at t = 8 weigh 3.6 (at least 5 people, under 5 weighted)
    assert `P'[5, 1] == 6 & abs(`W'[5, 1] - 3.6) < 1e-9
}
_kmqa_record, name("R0 fixture design: B has 3 (weighted 3.2) at risk at t=8; A has 6 (weighted 3.6)") rc(`=_rc')

**## W1 pweights all equal to 1: identical tables under both settings and unweighted
capture noisily {
    _kmrw_fix
    gen double one = 1
    quietly stset t [pw=one], failure(d)
    kmplot, by(g) risktable riskevents timepoints(`tps') name(w1, replace)
    tempname Rn Rs Ru
    assert "`r(riskweight)'" == "none"
    matrix `Rn' = r(risktable)
    kmplot, by(g) risktable riskevents timepoints(`tps') riskweight(stset) name(w1, replace)
    assert "`r(riskweight)'" == "stset"
    matrix `Rs' = r(risktable)
    quietly stset t, failure(d)
    kmplot, by(g) risktable riskevents timepoints(`tps') name(w1, replace)
    matrix `Ru' = r(risktable)
    assert rowsof(`Rn') == 12 & colsof(`Rn') == 5
    assert mreldif(`Rn', `Rs') == 0
    assert mreldif(`Rn', `Ru') == 0
}
_kmqa_record, name("W1 pweights all 1: identical tables under none, stset and unweighted") rc(`=_rc')

**## W2 varying pweights: people counts equal the unweighted run; stset basis is fractional
capture noisily {
    _kmrw_fix
    tempname P W
    _kmrw_truth, tps(`tps') people(`P') weighted(`W')
    quietly stset t, failure(d)
    kmplot, by(g) risktable riskevents timepoints(`tps') name(w2, replace)
    assert "`r(riskweight)'" == "none"
    tempname Ru Rn Rs Ctr
    matrix `Ru' = r(risktable)
    quietly stset t [pw=w], failure(d)
    kmplot, by(g) risktable riskevents timepoints(`tps') name(w2, replace)
    assert "`r(riskweight)'" == "none"
    matrix `Rn' = r(risktable)
    assert mreldif(`Rn', `Ru') == 0
    * and equal to the hand-counted people table
    _kmrw_counts, from(`Rn') into(`Ctr')
    assert mreldif(`Ctr', `P') == 0
    forvalues i = 1/12 {
        forvalues j = 3/5 {
            assert `Rn'[`i', `j'] == floor(`Rn'[`i', `j'])
        }
    }
    kmplot, by(g) risktable riskevents timepoints(`tps') riskweight(stset) name(w2, replace)
    assert "`r(riskweight)'" == "stset"
    matrix `Rs' = r(risktable)
    _kmrw_counts, from(`Rs') into(`Ctr')
    assert mreldif(`Ctr', `W') < 1e-12
    assert mreldif(`Rs', `Rn') > 0.01
    * at least one weighted cell is not a whole number
    local frac = 0
    forvalues i = 1/12 {
        forvalues j = 3/5 {
            if abs(`Rs'[`i', `j'] - floor(`Rs'[`i', `j'])) > 1e-9 local frac = 1
        }
    }
    assert `frac' == 1
    * unweighted data report none
    quietly stset t, failure(d)
    kmplot, by(g) risktable timepoints(`tps') name(w2, replace)
    assert "`r(riskweight)'" == "none"
    * no risk table, no risksaving: nothing to describe
    kmplot, by(g) name(w2, replace)
    assert "`r(riskweight)'" == ""
}
_kmqa_record, name("W2 varying pweights: none = unweighted people counts = hand count; stset = summed weights") rc(`=_rc')

**## W3 fweights: default equals the expanded dataset; riskweight(none) counts records
capture noisily {
    _kmrw_fix
    tempname Pf Wf Rd Re Rn Ctr
    _kmrw_truth, tps(`tps') people(`Pf') weighted(`Wf') fw
    quietly stset t [fw=fw], failure(d)
    kmplot, by(g) risktable riskevents timepoints(`tps') name(w3, replace)
    assert "`r(riskweight)'" == "stset"
    matrix `Rd' = r(risktable)
    _kmrw_counts, from(`Rd') into(`Ctr')
    assert mreldif(`Ctr', `Pf') == 0
    * expanded dataset
    expand fw
    quietly stset t, failure(d)
    kmplot, by(g) risktable riskevents timepoints(`tps') name(w3, replace)
    assert "`r(riskweight)'" == "none"
    matrix `Re' = r(risktable)
    assert mreldif(`Rd', `Re') == 0
    * records instead of frequencies
    _kmrw_fix
    quietly stset t [fw=fw], failure(d)
    kmplot, by(g) risktable riskevents timepoints(`tps') riskweight(none) name(w3, replace)
    assert "`r(riskweight)'" == "none"
    matrix `Rn' = r(risktable)
    tempname P W
    _kmrw_truth, tps(`tps') people(`P') weighted(`W')
    _kmrw_counts, from(`Rn') into(`Ctr')
    assert mreldif(`Ctr', `P') == 0
    assert mreldif(`Rn', `Rd') > 0.01
}
_kmqa_record, name("W3 fweights: default = expanded dataset's tables; riskweight(none) = records") rc(`=_rc')

**## W4 risksaving(): displayed basis plus _w companions, against hand counts
capture noisily {
    tempfile rs
    * pweights, default basis
    _kmrw_fix
    tempname P W
    _kmrw_truth, tps(`tps') people(`P') weighted(`W')
    quietly stset t [pw=w], failure(d)
    kmplot, by(g) risktable riskevents timepoints(`tps') risksaving("`rs'", replace) name(w4, replace)
    preserve
    use "`rs'", clear
    foreach v in group group_label time at_risk events censored at_risk_w events_w censored_w {
        confirm variable `v'
    }
    assert _N == 12
    sort group time
    forvalues i = 1/12 {
        assert at_risk[`i'] == `P'[`i', 1] & events[`i'] == `P'[`i', 2] & censored[`i'] == `P'[`i', 3]
        assert abs(at_risk_w[`i'] - `W'[`i', 1]) < 1e-12
        assert abs(events_w[`i'] - `W'[`i', 2]) < 1e-12
        assert abs(censored_w[`i'] - `W'[`i', 3]) < 1e-12
    }
    restore
    * pweights, riskweight(stset): both bases carry the weighted sums
    kmplot, by(g) risktable riskevents timepoints(`tps') riskweight(stset) ///
        risksaving("`rs'", replace) name(w4, replace)
    preserve
    use "`rs'", clear
    sort group time
    forvalues i = 1/12 {
        assert abs(at_risk[`i'] - `W'[`i', 1]) < 1e-12 & abs(at_risk_w[`i'] - `W'[`i', 1]) < 1e-12
        assert abs(events[`i'] - `W'[`i', 2]) < 1e-12 & abs(events_w[`i'] - `W'[`i', 2]) < 1e-12
        assert abs(censored[`i'] - `W'[`i', 3]) < 1e-12 & abs(censored_w[`i'] - `W'[`i', 3]) < 1e-12
    }
    restore
    * unweighted: the companions equal the people counts
    quietly stset t, failure(d)
    kmplot, by(g) risktable timepoints(`tps') risksaving("`rs'", replace) name(w4, replace)
    preserve
    use "`rs'", clear
    assert at_risk == at_risk_w & events == events_w & censored == censored_w
    restore
    * fweights: default basis is the frequency counts, companions equal them
    _kmrw_fix
    tempname Pf Wf
    _kmrw_truth, tps(`tps') people(`Pf') weighted(`Wf') fw
    quietly stset t [fw=fw], failure(d)
    kmplot, by(g) risktable timepoints(`tps') risksaving("`rs'", replace) name(w4, replace)
    preserve
    use "`rs'", clear
    sort group time
    forvalues i = 1/12 {
        assert at_risk[`i'] == `Pf'[`i', 1] & at_risk_w[`i'] == `Pf'[`i', 1]
    }
    restore
}
_kmqa_record, name("W4 risksaving(): both bases (_w companions) vs hand counts, all four weightings") rc(`=_rc')

**## W5 multiple records per subject under pweights: people are subjects
capture noisily {
    * 40 subjects, each split into two records at its midpoint, weights per subject
    clear
    set obs 40
    gen int id = _n
    gen byte g = 1 + (_n > 20)
    gen double T = 1 + mod(_n * 7, 11) + .5
    gen byte d = mod(_n, 3) == 0
    gen double w = .5 + mod(_n, 5) / 2
    expand 2
    bysort id: gen byte rec = _n
    gen double t0 = cond(rec == 1, 0, T / 2)
    gen double t = cond(rec == 1, T / 2, T)
    replace d = 0 if rec == 1
    local tp5 "0 2 4 6 8"
    * hand counts: subjects with T >= tp (record covering tp is the one with t0 < tp <= t)
    tempname Pm
    matrix `Pm' = J(10, 1, .)
    tempname Wm
    matrix `Wm' = J(10, 1, .)
    local row = 0
    forvalues gi = 1/2 {
        foreach tp of local tp5 {
            local ++row
            quietly count if g == `gi' & rec == 2 & T >= `tp'
            matrix `Pm'[`row', 1] = r(N)
            quietly summarize w if g == `gi' & rec == 2 & T >= `tp', meanonly
            matrix `Wm'[`row', 1] = r(sum)
        }
    }
    quietly stset t [pw=w], id(id) failure(d) time0(t0)
    tempfile rs
    kmplot, by(g) risktable timepoints(`tp5') risksaving("`rs'", replace) name(w5, replace)
    assert "`r(riskweight)'" == "none"
    tempname R
    matrix `R' = r(risktable)
    forvalues i = 1/10 {
        assert `R'[`i', 3] == `Pm'[`i', 1]
    }
    preserve
    use "`rs'", clear
    sort group time
    forvalues i = 1/10 {
        assert at_risk[`i'] == `Pm'[`i', 1]
        assert abs(at_risk_w[`i'] - `Wm'[`i', 1]) < 1e-12
    }
    restore
}
_kmqa_record, name("W5 id() multi-record pweights: people = subjects at risk, _w = their summed weight") rc(`=_rc')

**## M1 masking rule against the hand-counted table, for several thresholds
foreach k in 2 3 4 5 6 8 {
    capture noisily {
        _kmrw_fix
        tempname P W
        _kmrw_truth, tps(`tps') people(`P') weighted(`W')
        quietly stset t [pw=w], failure(d)
        kmplot, by(g) risktable riskevents timepoints(`tps') riskmask(`k') name(m1, replace)
        assert r(riskmask) == `k'
        assert "`r(riskweight)'" == "none"
        tempname R
        matrix `R' = r(risktable)
        local nmask = 0
        forvalues i = 1/12 {
            forvalues j = 1/3 {
                local truth = `P'[`i', `j']
                local got = `R'[`i', `j' + 2]
                if `truth' >= 1 & `truth' < `k' {
                    assert missing(`got')
                    local ++nmask
                }
                else {
                    assert `got' == `truth'
                }
            }
        }
        * the fixture must actually exercise the rule at k >= 4
        if `k' >= 4 assert `nmask' >= 2
        * group and time columns are never masked
        forvalues i = 1/12 {
            assert !missing(`R'[`i', 1], `R'[`i', 2])
        }
    }
    _kmqa_record, name("M1 riskmask(`k'): cells 1..`=`k'-1' missing in r(risktable), others exact, zeros kept") rc(`=_rc')
}

**## M2 without riskmask no r(riskmask) is returned
capture noisily {
    _kmrw_fix
    kmplot, by(g) risktable timepoints(`tps') name(m2, replace)
    assert "`r(riskmask)'" == ""
}
_kmqa_record, name("M2 r(riskmask) only when masking is on") rc(`=_rc')

**## M3 risksaving(): masked cells missing in the count and its _w companion, flag set
capture noisily {
    _kmrw_fix
    tempname P W
    _kmrw_truth, tps(`tps') people(`P') weighted(`W')
    quietly stset t [pw=w], failure(d)
    tempfile rs rs0
    kmplot, by(g) risktable riskevents timepoints(`tps') risksaving("`rs0'", replace) name(m3, replace)
    kmplot, by(g) risktable riskevents timepoints(`tps') riskmask(5) risksaving("`rs'", replace) name(m3, replace)
    * unmasked file holds the exact value
    preserve
    use "`rs0'", clear
    count if at_risk == 3
    assert r(N) == 1
    restore
    preserve
    use "`rs'", clear
    foreach v in at_risk events censored {
        confirm variable `v' `v'_w `v'_masked
    }
    sort group time
    assert _N == 12
    forvalues i = 1/12 {
        local ncell = 0
        foreach v in at_risk events censored {
            local ++ncell
            local truth = `P'[`i', `ncell']
            local masked = (`truth' >= 1 & `truth' < 5)
            assert `v'_masked[`i'] == `masked'
            if `masked' {
                assert missing(`v'[`i']) & missing(`v'_w[`i'])
            }
            else {
                assert `v'[`i'] == `truth'
                assert abs(`v'_w[`i'] - `W'[`i', `ncell']) < 1e-12
            }
        }
    }
    * the masked values appear nowhere in the file
    foreach v in at_risk events censored at_risk_w events_w censored_w {
        quietly count if `v' == 3
        assert r(N) == 0
        quietly count if abs(`v' - 3.2) < 1e-9
        assert r(N) == 0
    }
    * zero is shown as zero, not masked
    assert at_risk[12] == 0 & at_risk_masked[12] == 0
    * a cell with >= 5 people but < 5 weighted is not masked (A, t = 8: 6 people, 3.6)
    assert at_risk[5] == 6 & at_risk_masked[5] == 0 & abs(at_risk_w[5] - 3.6) < 1e-12
    restore
}
_kmqa_record, name("M3 risksaving() masking: missing + _masked flag, exact 3 and 3.2 absent, 0 kept, people-based rule") rc(`=_rc')

**## M4 the console never prints the masked value
capture noisily {
    _kmrw_fix
    quietly stset t [pw=w], failure(d)
    tempfile rs
    _kmqa_run, cmd(kmplot, by(g) risktable riskevents timepoints(`tps') riskmask(5) risksaving("`rs'", replace) name(m4, replace))
    assert r(rc) == 0
    local txt `"`r(text)'"'
    assert strlen(`"`txt'"') > 50
    assert strpos(`"`txt'"', "Risk-table data saved") > 0
    * the unmasked run does not either print counts, so test the tokens directly
    assert !regexm(`"`txt'"', "(^|[^0-9A-Za-z._])3\.2([^0-9]|$)")
    assert !regexm(`"`txt'"', "(^|[^0-9A-Za-z._/-])3([^0-9A-Za-z._]|$)")
}
_kmqa_record, name("M4 console output holds neither 3 nor 3.2 under riskmask(5)") rc(`=_rc')

**## M5 SVG: <5 drawn where the count was 3, no 3 or 3.2 text, zeros unchanged
capture noisily {
    _kmrw_fix
    quietly stset t [pw=w], failure(d)
    tempfile sv0 sv1 sv2
    kmplot, by(g) risktable timepoints(`tps') xlabel(0 2 4 6 8 9.2) name(m5, replace)
    graph export "`sv0'.svg", name(m5) as(svg) replace
    kmplot, by(g) risktable timepoints(`tps') xlabel(0 2 4 6 8 9.2) riskmask(5) name(m5, replace)
    graph export "`sv1'.svg", name(m5) as(svg) replace
    kmplot, by(g) risktable timepoints(`tps') xlabel(0 2 4 6 8 9.2) riskmask(5, text(n<5)) name(m5, replace)
    graph export "`sv2'.svg", name(m5) as(svg) replace
    * unmasked: the count 3 is drawn (non-vacuous), "<5" is not
    _kmqa_svgtext using "`sv0'.svg"
    quietly count if vis & txt == "3"
    assert r(N) == 1
    quietly count if vis & txt == "<5"
    assert r(N) == 0
    quietly count if vis & txt == "0"
    local zeros0 = r(N)
    quietly count if vis & txt == "6" & midanc
    local sixes0 = r(N)
    * masked
    _kmqa_svgtext using "`sv1'.svg"
    quietly count if vis & txt == "<5"
    assert r(N) == 1
    quietly count if txt == "3" | txt == "3.2"
    assert r(N) == 0
    quietly count if vis & txt == "0"
    assert r(N) == `zeros0'
    quietly count if vis & txt == "6" & midanc
    assert r(N) == `sixes0'
    * text() override
    _kmqa_svgtext using "`sv2'.svg"
    quietly count if vis & txt == "n<5"
    assert r(N) == 1
    quietly count if vis & txt == "<5"
    assert r(N) == 0
    quietly count if txt == "3" | txt == "3.2"
    assert r(N) == 0
}
_kmqa_record, name("M5 SVG: <5 (or text()) replaces the 3; no 3/3.2 text; zero cells still drawn") rc(`=_rc')

**## M6 fweights: masking judged on the frequency counts
capture noisily {
    _kmrw_fix
    tempname Pf Wf
    _kmrw_truth, tps(`tps') people(`Pf') weighted(`Wf') fw
    quietly stset t [fw=fw], failure(d)
    kmplot, by(g) risktable riskevents timepoints(`tps') riskmask(5) name(m6, replace)
    assert "`r(riskweight)'" == "stset"
    tempname R
    matrix `R' = r(risktable)
    forvalues i = 1/12 {
        forvalues j = 1/3 {
            local truth = `Pf'[`i', `j']
            local got = `R'[`i', `j' + 2]
            if `truth' >= 1 & `truth' < 5 assert missing(`got')
            else assert `got' == `truth'
        }
    }
    * explicit stset basis is legal with fweights and gives the same table
    tempname R2
    kmplot, by(g) risktable riskevents timepoints(`tps') riskmask(5) riskweight(stset) name(m6, replace)
    matrix `R2' = r(risktable)
    forvalues i = 1/12 {
        forvalues j = 3/5 {
            assert (missing(`R'[`i', `j']) & missing(`R2'[`i', `j'])) | `R'[`i', `j'] == `R2'[`i', `j']
        }
    }
}
_kmqa_record, name("M6 fweights + riskmask: rule applied to frequency counts") rc(`=_rc')

**## M7 unweighted data: masking rule and r(riskweight)
capture noisily {
    _kmrw_fix
    tempname P W
    _kmrw_truth, tps(`tps') people(`P') weighted(`W')
    quietly stset t, failure(d)
    kmplot, by(g) risktable timepoints(`tps') riskmask(5) name(m7, replace)
    assert "`r(riskweight)'" == "none"
    tempname R
    matrix `R' = r(risktable)
    forvalues i = 1/12 {
        local truth = `P'[`i', 1]
        local got = `R'[`i', 3]
        if `truth' >= 1 & `truth' < 5 assert missing(`got')
        else assert `got' == `truth'
    }
}
_kmqa_record, name("M7 unweighted riskmask(5)") rc(`=_rc')

**## M8 masking composes with compete()
capture noisily {
    _kmrw_fix
    gen byte cause = cond(d == 1, 1, cond(t == 5.5 | t == 7.5, 2, 0))
    quietly stset t [pw=w], failure(cause == 1)
    kmplot, by(g) compete(cause == 2) risktable timepoints(`tps') riskmask(5) name(m8, replace)
    assert "`r(estimator)'" == "aalen_johansen"
    assert r(riskmask) == 5
    tempname R
    matrix `R' = r(risktable)
    * at-risk of B at t = 8 is still 3 people (competing deaths leave the risk set like censoring)
    assert missing(`R'[11, 3])
    assert `R'[12, 3] == 0
}
_kmqa_record, name("M8 riskmask with compete(): same cells masked") rc(`=_rc')

**## M9 riskmask default from tabtools set smallcells; noriskmask and riskmask() override it
capture noisily {
    local pkgdir = regexr("`c(pwd)'", "/qa$", "")
    quietly net install tabtools, from("`pkgdir'/../tabtools") replace
    _kmrw_fix
    tempname P W R
    _kmrw_truth, tps(`tps') people(`P') weighted(`W')
    quietly stset t [pw=w], failure(d)
    quietly tabtools set smallcells 5
    assert "$TABTOOLS_set_smallcells" == "5"
    * default applies when a risk table is drawn
    kmplot, by(g) risktable riskevents timepoints(`tps') name(m9, replace)
    assert r(riskmask) == 5
    matrix `R' = r(risktable)
    forvalues i = 1/12 {
        forvalues j = 1/3 {
            local truth = `P'[`i', `j']
            if `truth' >= 1 & `truth' < 5 assert missing(`R'[`i', `j' + 2])
            else assert `R'[`i', `j' + 2] == `truth'
        }
    }
    * an explicit riskmask() wins over the session default
    kmplot, by(g) risktable timepoints(`tps') riskmask(3) name(m9, replace)
    assert r(riskmask) == 3
    matrix `R' = r(risktable)
    assert `R'[11, 3] == 3
    * noriskmask turns it off
    kmplot, by(g) risktable timepoints(`tps') noriskmask name(m9, replace)
    assert "`r(riskmask)'" == ""
    matrix `R' = r(risktable)
    assert `R'[11, 3] == 3
    * no risk table: the default is not applied and nothing breaks
    kmplot, by(g) name(m9, replace)
    assert "`r(riskmask)'" == ""
    * clearing the session setting removes the default
    quietly tabtools set smallcells clear
    kmplot, by(g) risktable timepoints(`tps') name(m9, replace)
    assert "`r(riskmask)'" == ""
}
local m9rc = _rc
capture tabtools set smallcells clear
global TABTOOLS_set_smallcells ""
_kmqa_record, name("M9 tabtools smallcells default; riskmask() and noriskmask override") rc(`m9rc')

**## M10 nodraw with risktable succeeds and returns the table
capture noisily {
    _kmrw_fix
    quietly stset t [pw=w], failure(d)
    kmplot, by(g) risktable riskevents timepoints(`tps') riskmask(5) name(m10, replace)
    tempname A B
    matrix `A' = r(risktable)
    kmplot, by(g) risktable riskevents timepoints(`tps') riskmask(5) nodraw name(m10b, replace)
    assert "`r(riskweight)'" == "none"
    matrix `B' = r(risktable)
    assert rowsof(`B') == 12 & colsof(`B') == 5
    forvalues i = 1/12 {
        forvalues j = 1/5 {
            assert (missing(`A'[`i', `j']) & missing(`B'[`i', `j'])) | `A'[`i', `j'] == `B'[`i', `j']
        }
    }
}
_kmqa_record, name("M10 nodraw + risktable: success, r(risktable) populated and equal to the drawn run") rc(`=_rc')

_kmqa_finish, suite("test_kmplot_riskweight_mask")
