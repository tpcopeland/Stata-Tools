* validation_kmplot_cif_oracle.do
* kmplot compete(): Aalen-Johansen cumulative incidence against hand-computed
* values and the study's hand-coded weighted estimator
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-20
*
* Oracles that share no code with kmplot:
*   H1-H3   three enumerated datasets whose cumulative incidence was worked out
*           by hand (no ties; ties of cause 1, cause 2 and censoring at one
*           time; the same ties under weights), to 1e-12; fweights equal the
*           expanded dataset
*   S1-S5   the collapse / reverse-cumsum / product-limit estimator of the
*           Female_Cancers_DMT Table 2 bookmark (_kmqa_aj in
*           _kmplot_qa_cifsupport.do) on seeded synthetic cohorts: stabilised
*           inverse-probability weights (pweights, truncated at 4.3), rare
*           breast-cancer events injected, death competing, stset origin() and
*           scale(365.25) exactly as in the target call; landmark(5) and the
*           whole saved curve to 1e-10
*   I1-I3   invariance: multiplying every pweight by a constant leaves the
*           curve unchanged; compete() with no competing event equals failure
*           (weighted and unweighted); the competing event lowers the curve
*           relative to treating it as censoring

clear all
version 16.0
set varabbrev off
local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_kmplot_qa_common.do"
quietly do "`qa_dir'/_kmplot_qa_cifsupport.do"
_kmplot_qa_bootstrap
_kmqa_init

tempfile curve1 curve2

**# Synthetic study cohort
capture program drop _kmv_study
program define _kmv_study
    version 16.0
    syntax , SEED(integer) [N(integer 3000)]
    clear
    set seed `seed'
    set obs `n'
    gen long id = _n
    gen double x = rnormal()
    gen byte arm = runiform() < invlogit(-.4 + .5 * x)
    quietly logit arm x
    predict double ps, pr
    quietly summarize arm, meanonly
    gen double sw = cond(arm == 1, r(mean) / ps, (1 - r(mean)) / (1 - ps))
    quietly _pctile sw, percentiles(1 99)
    replace sw = min(max(sw, r(r1)), 4.3)
    gen long t0 = 20000 + floor(runiform() * 700)
    gen long admin = ceil(365.25 * (3 + 5 * runiform()))
    * rare outcome of interest, competing death, administrative censoring
    gen long tb = ceil(rexponential(365.25 / (.004 * cond(arm == 1, 1.6, 1))))
    gen long td = ceil(rexponential(365.25 / .012))
    gen long dur = min(tb, td, admin)
    gen byte st_breast = cond(dur == tb, 1, cond(dur == td, 2, 0))
    * inject breast events so each arm has events before year 5
    foreach a in 0 1 {
        gen double u`a' = runiform() if arm == `a' & st_breast == 0
        sort u`a'
        replace st_breast = 1 if _n <= 30 & arm == `a' & u`a' < .
        replace dur = 30 + floor(runiform() * 1700) if _n <= 30 & arm == `a' & u`a' < .
        drop u`a'
    }
    * deaths are common enough that ties with the injected times occur
    gen long exit_breast = t0 + dur
    format exit_breast t0 %td
    drop tb td admin dur ps
    sort id
end

**# Helper: oracle curve of a study cohort as a reference dataset
capture program drop _kmv_oracle
program define _kmv_oracle
    version 16.0
    syntax , SAVEto(string) [WTvar(string)]
    * In memory: the cohort.  Writes group time est (group = arm + 1).
    preserve
    quietly {
        gen double t = (exit_breast - t0) / 365.25
        gen double w = `=cond("`wtvar'" == "", "sw", "`wtvar'")'
        gen byte cause = st_breast
        keep arm t w cause
        _kmqa_aj
        gen byte group = arm + 1
        rename cif est
        keep group time est
        save `"`saveto'"', replace
    }
    restore
end

**## H1 hand-computed, no ties
capture noisily {
    clear
    input id t status
    1 1 1
    2 2 2
    3 3 0
    4 4 1
    5 5 2
    6 6 1
    end
    quietly stset t, failure(status == 1)
    kmplot, compete(status == 2) landmark(1 2 3 4 5 6) nodraw name(h1, replace)
    assert "`r(estimator)'" == "aalen_johansen"
    tempname L
    matrix `L' = r(landmarks)
    local exp "`=1/6' `=1/6' `=1/6' `=7/18' `=7/18' `=11/18'"
    forvalues i = 1/6 {
        local e : word `i' of `exp'
        assert abs(`L'[`i', 3] - `e') < 1e-12
    }
}
_kmqa_record, name("H1 enumerated Aalen-Johansen, no ties") rc(`=_rc')

**## H2 hand-computed, cause 1 / cause 2 / censoring tied
capture noisily {
    clear
    input id t status
    1 1 1
    2 2 1
    3 2 2
    4 2 0
    5 3 0
    6 3 2
    7 4 1
    8 5 0
    end
    quietly stset t, failure(status == 1)
    kmplot, compete(status == 2) landmark(1 2 3 4 5) nodraw name(h2, replace)
    tempname L
    matrix `L' = r(landmarks)
    local exp "`=1/8' `=1/4' `=1/4' `=31/64' `=31/64'"
    forvalues i = 1/5 {
        local e : word `i' of `exp'
        assert abs(`L'[`i', 3] - `e') < 1e-12
    }
    * the censored subject at t = 2 stays in the risk set through the events
    * at t = 2: dropping the censoring would give a different second step
    quietly replace t = 2.5 if id == 4
    quietly stset t, failure(status == 1)
    kmplot, compete(status == 2) landmark(2) nodraw name(h2, replace)
    matrix `L' = r(landmarks)
    assert abs(`L'[1, 3] - (1/8 + (7/8) * (1/7))) < 1e-12
}
_kmqa_record, name("H2 enumerated Aalen-Johansen, tied causes and censoring") rc(`=_rc')

**## H3 hand-computed under pweights and fweights; fweight equals expanded data
capture noisily {
    clear
    input id t status w
    1 1 1 2
    2 2 1 1
    3 2 2 1
    4 2 0 1
    5 3 0 1
    6 3 2 1
    7 4 1 1
    8 5 0 4
    end
    quietly stset t [pw=w], failure(status == 1)
    kmplot, compete(status == 2) landmark(1 2 3 4 5) nodraw name(h3, replace)
    tempname L
    matrix `L' = r(landmarks)
    local exp "`=1/6' `=1/4' `=1/4' `=51/140' `=51/140'"
    forvalues i = 1/5 {
        local e : word `i' of `exp'
        assert abs(`L'[`i', 3] - `e') < 1e-12
    }
    quietly stset t [fw=w], failure(status == 1)
    kmplot, compete(status == 2) landmark(1 2 3 4 5) nodraw name(h3, replace)
    matrix `L' = r(landmarks)
    forvalues i = 1/5 {
        local e : word `i' of `exp'
        assert abs(`L'[`i', 3] - `e') < 1e-12
    }
    expand w
    quietly stset t, failure(status == 1)
    kmplot, compete(status == 2) landmark(1 2 3 4 5) nodraw name(h3, replace)
    matrix `L' = r(landmarks)
    forvalues i = 1/5 {
        local e : word `i' of `exp'
        assert abs(`L'[`i', 3] - `e') < 1e-12
    }
}
_kmqa_record, name("H3 enumerated weighted Aalen-Johansen; fweight equals expand") rc(`=_rc')

**## H4 hand-computed delayed entry where entry times tie event times
* At risk at t means t0 < t <= exit: a record entering at t is not at risk at t.
* Unweighted: n = 3, 4, 4, 3 at t = 1, 2, 3, 4 -> CIF 1/3, 1/2, 5/8, 17/24.
* Weights (id 4 weighs 2): n = 3, 5, 5, 4 -> 1/3, 7/15, 43/75, 49/75.
capture noisily {
    clear
    input id t0 t status w
    1 0 1 1 1
    2 0 3 2 1
    3 1 2 1 1
    4 1 4 0 2
    5 2 3 1 1
    6 0 4 1 1
    7 3 4 2 1
    end
    local expu "`=1/3' `=1/2' `=5/8' `=17/24'"
    local expw "`=1/3' `=7/15' `=43/75' `=49/75'"
    tempname L
    * single record per subject, enter(time)
    quietly stset t, failure(status == 1) enter(time t0)
    kmplot, compete(status == 2) landmark(1 2 3 4) nodraw name(h4, replace)
    matrix `L' = r(landmarks)
    forvalues i = 1/4 {
        local e : word `i' of `expu'
        assert abs(`L'[`i', 3] - `e') < 1e-12
    }
    quietly stset t [pw=w], failure(status == 1) enter(time t0)
    kmplot, compete(status == 2) landmark(1 2 3 4) nodraw name(h4, replace)
    matrix `L' = r(landmarks)
    forvalues i = 1/4 {
        local e : word `i' of `expw'
        assert abs(`L'[`i', 3] - `e') < 1e-12
    }
    * integer weights as frequencies equal the expanded data
    quietly stset t [fw=w], failure(status == 1) enter(time t0)
    kmplot, compete(status == 2) landmark(1 2 3 4) nodraw name(h4, replace)
    matrix `L' = r(landmarks)
    forvalues i = 1/4 {
        local e : word `i' of `expw'
        assert abs(`L'[`i', 3] - `e') < 1e-12
    }
    * id() splits at integer times, including a split at an entry time of another record
    expand 2 if id == 6 | id == 2
    bysort id: gen byte piece = _n
    quietly replace t = 2 if (id == 6 | id == 2) & piece == 1
    quietly replace status = 0 if (id == 6 | id == 2) & piece == 1
    quietly replace t0 = 2 if (id == 6 | id == 2) & piece == 2
    quietly stset t, id(id) failure(status == 1) time0(t0)
    kmplot, compete(status == 2) landmark(1 2 3 4) nodraw name(h4, replace)
    matrix `L' = r(landmarks)
    forvalues i = 1/4 {
        local e : word `i' of `expu'
        assert abs(`L'[`i', 3] - `e') < 1e-12
    }
}
_kmqa_record, name("H4 enumerated delayed entry with entry times tying event times (enter, weights, id splits)") rc(`=_rc')

**## S1-S5 study oracle: landmark(5) and whole curve, five seeds
local seeds "20261020 20261021 20261022 20261023 20261024"
local si = 0
foreach seed of local seeds {
    local ++si
    capture noisily {
        _kmv_study, seed(`seed')
        * the fixture reaches 5 years in both arms and has competing events
        quietly count if st_breast == 1 & arm == 0
        assert r(N) >= 30
        quietly count if st_breast == 2 & arm == 1
        assert r(N) >= 20
        quietly summarize sw
        assert r(max) <= 4.3 + 1e-12
        tempfile ref`si'
        _kmv_oracle, saveto("`ref`si''")
        quietly stset exit_breast [pw=sw], failure(st_breast == 1) origin(time t0) scale(365.25)
        kmplot, by(arm) compete(st_breast == 2) landmark(5) ///
            saving("`curve1'", replace) nodraw name(s1, replace)
        assert "`r(estimator)'" == "aalen_johansen"
        tempname L
        matrix `L' = r(landmarks)
        assert rowsof(`L') == 2 & colsof(`L') == 5
        preserve
        use "`ref`si''", clear
        rename (group est) (arm cif)
        forvalues gi = 1/2 {
            _kmqa_step, group(`gi') time(5)
            local o`gi' = r(value)
            assert `o`gi'' > 0 & `o`gi'' < .1
        }
        restore
        assert abs(`L'[1, 3] - `o1') < 1e-10
        assert abs(`L'[2, 3] - `o2') < 1e-10
        * the whole curve, at every oracle jump
        _kmqa_cmp, km("`curve1'") ref("`ref`si''")
        assert r(nmiss) == 0 & r(nref) > 500
        assert r(maxdiff) < 1e-10
    }
    _kmqa_record, name("S`si' study oracle seed `seed': landmark(5) and curve") rc(`=_rc')
}

**## I1 scaling all pweights by a constant leaves the curve unchanged
capture noisily {
    _kmv_study, seed(20261031)
    quietly stset exit_breast [pw=sw], failure(st_breast == 1) origin(time t0) scale(365.25)
    kmplot, by(arm) compete(st_breast == 2) landmark(1 3 5) saving("`curve1'", replace) ///
        nodraw name(i1, replace)
    tempname A B
    matrix `A' = r(landmarks)
    foreach k in 7.3 0.0137 1000 {
        quietly gen double sw_k = sw * `k'
        quietly stset exit_breast [pw=sw_k], failure(st_breast == 1) origin(time t0) scale(365.25)
        kmplot, by(arm) compete(st_breast == 2) landmark(1 3 5) saving("`curve2'", replace) ///
            nodraw name(i1, replace)
        matrix `B' = r(landmarks)
        forvalues i = 1/6 {
            assert abs(`A'[`i', 3] - `B'[`i', 3]) < 1e-12
        }
        _kmqa_curvediff, a("`curve1'") b("`curve2'")
        assert r(unmatched) == 0 & r(tied) == 0 & r(n) > 100
        assert r(maxdiff) < 1e-12
        drop sw_k
    }
}
_kmqa_record, name("I1 pweights x constant: curve unchanged (x7.3, x0.0137, x1000)") rc(`=_rc')

**## I2 compete() with no competing event equals failure
foreach wt in unweighted pweighted fweighted {
    capture noisily {
        _kmv_study, seed(20261032) n(1500)
        * remove the competing events: treat deaths as censored at the same time
        quietly replace st_breast = 0 if st_breast == 2
        quietly count if st_breast == 2
        assert r(N) == 0
        if "`wt'" == "unweighted" {
            quietly stset exit_breast, failure(st_breast == 1) origin(time t0) scale(365.25)
        }
        else if "`wt'" == "pweighted" {
            quietly stset exit_breast [pw=sw], failure(st_breast == 1) origin(time t0) scale(365.25)
        }
        else {
            quietly gen int fw = 1 + mod(id, 3)
            quietly stset exit_breast [fw=fw], failure(st_breast == 1) origin(time t0) scale(365.25)
        }
        kmplot, by(arm) failure landmark(1 2 3 4 5) saving("`curve1'", replace) ///
            nodraw name(i2, replace)
        assert "`r(estimator)'" == "km_failure"
        tempname A B
        matrix `A' = r(landmarks)
        kmplot, by(arm) compete(st_breast == 2) landmark(1 2 3 4 5) ///
            saving("`curve2'", replace) nodraw name(i2, replace)
        assert "`r(estimator)'" == "aalen_johansen"
        matrix `B' = r(landmarks)
        assert rowsof(`A') == 10 & rowsof(`B') == 10
        forvalues i = 1/10 {
            assert abs(`A'[`i', 3] - `B'[`i', 3]) < 1e-13
        }
        _kmqa_curvediff, a("`curve1'") b("`curve2'")
        assert r(unmatched) == 0 & r(tied) == 0 & r(n) > 50
        assert r(maxdiff) < 1e-13
    }
    _kmqa_record, name("I2 no competing events: compete() equals failure (`wt')") rc(`=_rc')
}

**## I3 the competing event removes the person: CIF below the censoring-based curve
capture noisily {
    _kmv_study, seed(20261033)
    quietly stset exit_breast [pw=sw], failure(st_breast == 1) origin(time t0) scale(365.25)
    kmplot, by(arm) failure landmark(5) nodraw name(i3, replace)
    tempname A B
    matrix `A' = r(landmarks)
    kmplot, by(arm) compete(st_breast == 2) landmark(5) nodraw name(i3, replace)
    matrix `B' = r(landmarks)
    forvalues i = 1/2 {
        assert `B'[`i', 3] < `A'[`i', 3] - 1e-6
        assert `B'[`i', 3] > 0
    }
}
_kmqa_record, name("I3 competing event is not censoring (CIF1 < 1-KM)") rc(`=_rc')

**## I4 hostile: ties of all three kinds at every time (daily data, heavy ties)
capture noisily {
    _kmv_study, seed(20261034) n(1200)
    * coarsen follow-up to whole years' worth of 30-day months: heavy ties
    quietly replace exit_breast = t0 + 30 * ceil((exit_breast - t0) / 30)
    tempfile refh
    _kmv_oracle, saveto("`refh'")
    quietly stset exit_breast [pw=sw], failure(st_breast == 1) origin(time t0) scale(365.25)
    kmplot, by(arm) compete(st_breast == 2) landmark(5) saving("`curve1'", replace) ///
        nodraw name(i4, replace)
    * confirm the fixture really has all three kinds of ties
    quietly gen double tt = _t
    quietly bysort arm tt: gen byte nn = _N
    quietly bysort arm tt: egen byte has1 = max(st_breast == 1)
    quietly bysort arm tt: egen byte has2 = max(st_breast == 2)
    quietly bysort arm tt: egen byte has0 = max(st_breast == 0)
    quietly count if has1 & has2 & has0
    assert r(N) > 20
    _kmqa_cmp, km("`curve1'") ref("`refh'")
    assert r(nmiss) == 0 & r(nref) > 100
    assert r(maxdiff) < 1e-10
}
_kmqa_record, name("I4 heavy ties of cause 1, cause 2 and censoring vs the study estimator") rc(`=_rc')

_kmqa_finish, suite("validation_kmplot_cif_oracle")
