* test_kmplot_compete_errors.do
* kmplot compete(): refusals with exact return codes, legal inverses, and the
* r(estimator) / r(compete) returns
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-20
*
* Black-box contract tests.  Every refusal asserts the exact rc, the key words
* of the message, and that the data in memory are untouched; every refusal has
* a legal inverse that must run.  Codes: 459 compete() true on an event
* record, 416 compete() missing, 198 for the option conflicts and bad values.

clear all
version 16.0
set varabbrev off
local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_kmplot_qa_common.do"
quietly do "`qa_dir'/_kmplot_qa_cifsupport.do"
_kmplot_qa_bootstrap
_kmqa_init

* Fixture: 90 subjects, two groups, causes 0/1/2, a 0/1 flag with missing
* values on 5 st-sample rows and 3 rows excluded by stset's if, weights.
capture program drop _kmce_data
program define _kmce_data
    version 16.0
    syntax , [WT(string)]
    clear
    set seed 20261020
    set obs 90
    gen int id = _n
    gen byte g = 1 + (_n > 45)
    gen double t1 = rexponential(1 / .15)
    gen double t2 = rexponential(1 / .10)
    gen double tc = 2 + runiform() * 8
    gen double t = min(t1, t2, tc)
    gen byte status = cond(t == t1, 1, cond(t == t2, 2, 0))
    gen byte cf = status == 2
    * five missing flags among rows that stay in the sample (ids 1-5)
    replace cf = . in 1/5
    gen double w = .5 + runiform() * 2
    gen byte keepme = id > 3
    drop t1 t2 tc
    quietly count if status == 1
    assert r(N) >= 10
    quietly count if status == 2
    assert r(N) >= 10
    if "`wt'" == "" quietly stset t if keepme, failure(status == 1)
    else quietly stset t [`wt'=w] if keepme, failure(status == 1)
end

**## E1 compete() true on an event record: rc 459
capture noisily {
    _kmce_data
    _kmqa_expect, rc(459) cmd(kmplot, by(g) compete(status >= 1) nodraw name(e1, replace)) ///
        text("compete()" "both")
    * compete() true only on some event records is still refused
    quietly levelsof id if status == 1 & keepme, local(evids)
    local one : word 2 of `evids'
    _kmqa_expect, rc(459) cmd(kmplot, compete(status == 2 | id == `one') nodraw name(e1, replace)) ///
        text("compete()")
}
_kmqa_record, name("E1 compete() true on _d==1 records -> 459") rc(`=_rc')

**## E2 legal inverses of E1: scope is the st sample and kmplot's if/in
capture noisily {
    _kmce_data
    * true on event records only in group 2, but the call is restricted to group 1
    kmplot if g == 1, by(g) compete(status == 2 | (g == 2 & status == 1)) nodraw name(e2, replace)
    assert "`r(estimator)'" == "aalen_johansen"
    * true on an event record that stset excluded (id 2, keepme == 0) is ignored
    quietly count if id == 2 & status == 1
    kmplot, compete(status == 2 | (id <= 3 & status == 1)) nodraw name(e2, replace)
    assert "`r(estimator)'" == "aalen_johansen"
    * and the plain expression
    kmplot, compete(status == 2) nodraw name(e2, replace)
}
_kmqa_record, name("E2 compete() judged on the st sample and if/in only") rc(`=_rc')

**## E3 compete() missing: rc 416 with the count
capture noisily {
    _kmce_data
    * ids 1-3 are outside the st sample; ids 4-5 are inside: 2 missing rows
    _kmqa_expect, rc(416) cmd(kmplot, compete(cf) nodraw name(e3, replace)) ///
        text("compete() evaluates to missing for 2 observations")
    * an expression that is missing by construction
    _kmqa_expect, rc(416) cmd(kmplot, compete(cond(missing(cf), ., cf)) nodraw name(e3, replace)) ///
        text("missing")
    * legal inverse: restrict the call to rows with a flag
    kmplot if !missing(cf), compete(cf) nodraw name(e3, replace)
    assert "`r(estimator)'" == "aalen_johansen"
    kmplot if id > 5, compete(cf) nodraw name(e3, replace)
    * the comparison form never evaluates to missing: missing flag means not competing
    kmplot, compete(cf == 1) nodraw name(e3, replace)
}
_kmqa_record, name("E3 compete() missing on sample rows -> 416, inverses run") rc(`=_rc')

**## E4 pvalue / median / medianannotate with compete(): rc 198
capture noisily {
    _kmce_data
    _kmqa_expect, rc(198) cmd(kmplot, by(g) compete(status == 2) pvalue nodraw name(e4, replace))
    _kmqa_expect, rc(198) cmd(kmplot, by(g) compete(status == 2) median nodraw name(e4, replace))
    _kmqa_expect, rc(198) cmd(kmplot, by(g) compete(status == 2) median medianannotate nodraw name(e4, replace))
    * the same options are legal without compete()
    kmplot, by(g) pvalue median nodraw name(e4, replace)
    * and compete() alone, with ci (unweighted)
    kmplot, by(g) compete(status == 2) ci nodraw name(e4, replace)
}
_kmqa_record, name("E4 pvalue, median, medianannotate refused with compete()") rc(`=_rc')

**## E5 weights: ci and pvalue refused under pweights, point estimates work
capture noisily {
    _kmce_data, wt(pw)
    _kmqa_expect, rc(198) cmd(kmplot, by(g) compete(status == 2) ci nodraw name(e5, replace)) ///
        text("ci and pvalue are not supported with stset probability weights")
    _kmqa_expect, rc(198) cmd(kmplot, by(g) compete(status == 2) pvalue nodraw name(e5, replace)) ///
        text("ci and pvalue are not supported with stset probability weights")
    _kmqa_expect, rc(198) cmd(kmplot, by(g) ci nodraw name(e5, replace)) ///
        text("ci and pvalue are not supported with stset probability weights")
    * legal inverse: point estimates, landmark and saving
    tempfile cv
    kmplot, by(g) compete(status == 2) landmark(2 4) saving("`cv'", replace) nodraw name(e5, replace)
    assert "`r(estimator)'" == "aalen_johansen"
    tempname L
    matrix `L' = r(landmarks)
    assert rowsof(`L') == 4 & colsof(`L') == 5
    assert !missing(`L'[1, 3], `L'[4, 3])
    assert missing(`L'[1, 4]) & missing(`L'[1, 5])
    preserve
    use "`cv'", clear
    assert _N > 20
    assert !missing(estimate)
    assert missing(lower) & missing(upper)
    restore
}
_kmqa_record, name("E5 pweights: ci/pvalue -> 198 with the existing message; estimates work") rc(`=_rc')

**## E6 iweights and fweights: compete() behaves as failure does
capture noisily {
    _kmce_data, wt(iw)
    * the contract lists iweights with pweights: ci and pvalue refused under compete()
    _kmqa_expect, rc(198) cmd(kmplot, by(g) compete(status == 2) ci nodraw name(e6, replace))
    _kmqa_expect, rc(198) cmd(kmplot, by(g) compete(status == 2) pvalue nodraw name(e6, replace))
    kmplot, by(g) compete(status == 2) nodraw name(e6, replace)
    assert "`r(estimator)'" == "aalen_johansen"
}
_kmqa_record, name("E6 iweights: ci/pvalue refused with compete(); point estimates work") rc(`=_rc')

capture noisily {
    * fweights need integer weights
    _kmce_data
    gen int fw = 1 + mod(id, 3)
    quietly stset t [fw=fw] if keepme, failure(status == 1)
    quietly capture kmplot, by(g) failure ci nodraw name(e6, replace)
    local rc_fail = _rc
    quietly capture kmplot, by(g) compete(status == 2) ci nodraw name(e6, replace)
    assert _rc == `rc_fail'
    kmplot, by(g) compete(status == 2) nodraw name(e6, replace)
    assert "`r(estimator)'" == "aalen_johansen"
}
_kmqa_record, name("E6b fweights: ci acceptance matches failure; compete() works") rc(`=_rc')

**## E7 failure with compete() is accepted silently; r(estimator), r(compete)
capture noisily {
    _kmce_data
    _kmqa_run, cmd(kmplot, by(g) failure compete(status == 2) nodraw name(e7, replace))
    assert r(rc) == 0
    kmplot, by(g) failure compete(status == 2) nodraw name(e7, replace)
    assert "`r(estimator)'" == "aalen_johansen"
    assert `"`r(compete)'"' == "status == 2"
    kmplot, by(g) compete(cf == 1) nodraw name(e7, replace)
    assert `"`r(compete)'"' == "cf == 1"
    kmplot, by(g) nodraw name(e7, replace)
    assert "`r(estimator)'" == "km"
    assert `"`r(compete)'"' == ""
    kmplot, by(g) failure nodraw name(e7, replace)
    assert "`r(estimator)'" == "km_failure"
    assert `"`r(compete)'"' == ""
    kmplot, nodraw name(e7, replace)
    assert "`r(estimator)'" == "km"
    kmplot, compete(status == 2) nodraw name(e7, replace)
    assert "`r(estimator)'" == "aalen_johansen"
}
_kmqa_record, name("E7 failure+compete accepted; r(estimator) km|km_failure|aalen_johansen; r(compete)") rc(`=_rc')

**## E8 r(estimator) is returned with every route (ci, risktable, weights)
capture noisily {
    _kmce_data
    kmplot, by(g) ci nodraw name(e8, replace)
    assert "`r(estimator)'" == "km"
    kmplot, by(g) failure ci risktable name(e8, replace)
    assert "`r(estimator)'" == "km_failure"
    kmplot, by(g) compete(status == 2) ci risktable name(e8, replace)
    assert "`r(estimator)'" == "aalen_johansen"
    _kmce_data, wt(pw)
    kmplot, by(g) nodraw name(e8, replace)
    assert "`r(estimator)'" == "km"
    kmplot, by(g) compete(status == 2) landmark(3) nodraw name(e8, replace)
    assert "`r(estimator)'" == "aalen_johansen"
}
_kmqa_record, name("E8 r(estimator) on every route") rc(`=_rc')

**## E9 numeric domains: ymax, tmax, riskmask, riskweight
capture noisily {
    _kmce_data
    foreach bad in 0 -1 -0.5 {
        _kmqa_expect, rc(198) cmd(kmplot, by(g) failure ymax(`bad') nodraw name(e9, replace))
        _kmqa_expect, rc(198) cmd(kmplot, by(g) tmax(`bad') nodraw name(e9, replace))
    }
    foreach bad in 0 1 -3 5.5 {
        _kmqa_expect, rc(198) cmd(kmplot, by(g) risktable riskmask(`bad') name(e9, replace))
    }
    _kmqa_expect, rc(198) cmd(kmplot, by(g) risktable riskweight(both) name(e9, replace))
    * legal inverses
    kmplot, by(g) failure ymax(1) nodraw name(e9, replace)
    kmplot, by(g) tmax(5) nodraw name(e9, replace)
    kmplot, by(g) risktable riskmask(2) name(e9, replace)
    kmplot, by(g) risktable riskmask(5) timepoints(0 2 4) name(e9, replace)
    kmplot, by(g) risktable riskweight(none) name(e9, replace)
    kmplot, by(g) risktable riskweight(stset) name(e9, replace)
}
_kmqa_record, name("E9 ymax/tmax <= 0, riskmask < 2 or non-integer, bad riskweight -> 198; legal values run") rc(`=_rc')

**## E10 riskmask with riskweight(stset) under pweights: 198; fweights allowed
capture noisily {
    _kmce_data, wt(pw)
    _kmqa_expect, rc(198) cmd(kmplot, by(g) risktable riskweight(stset) riskmask(5) name(e10, replace))
    _kmqa_expect, rc(198) cmd(kmplot, by(g) risktable riskweight(stset) riskmask(5) compete(status == 2) name(e10, replace))
    kmplot, by(g) risktable riskweight(none) riskmask(5) name(e10, replace)
    kmplot, by(g) risktable riskmask(5) name(e10, replace)
    assert "`r(riskweight)'" == "none"
    * iweights are weights, not counts
    _kmce_data, wt(iw)
    _kmqa_expect, rc(198) cmd(kmplot, by(g) risktable riskweight(stset) riskmask(5) name(e10, replace))
    * fweights are counts: stset basis plus masking is legal
    _kmce_data
    gen int fw = 1 + mod(id, 3)
    quietly stset t [fw=fw] if keepme, failure(status == 1)
    kmplot, by(g) risktable riskweight(stset) riskmask(5) name(e10, replace)
    assert "`r(riskweight)'" == "stset"
    * unweighted: either value is legal and reports none
    _kmce_data
    kmplot, by(g) risktable riskweight(stset) riskmask(5) name(e10, replace)
    assert "`r(riskweight)'" == "none"
}
_kmqa_record, name("E10 riskmask needs people counts: pweight/iweight + stset basis -> 198") rc(`=_rc')

**## E11 byorder: needs by(), levels must exist, numeric by only
capture noisily {
    _kmce_data
    gen str3 gs = cond(g == 1, "one", "two")
    gen byte g3 = g
    replace g3 = 3 in 1/10
    _kmqa_expect, rc(198) cmd(kmplot, byorder(2 1) nodraw name(e11, replace))
    _kmqa_expect, rc(198) cmd(kmplot, by(g) byorder(1 7) nodraw name(e11, replace))
    _kmqa_expect, rc(198) cmd(kmplot, by(g) byorder(7) nodraw name(e11, replace))
    quietly capture kmplot, by(gs) byorder(1 2) nodraw name(e11, replace)
    assert inlist(_rc, 109, 198)
    * legal inverses
    kmplot, by(g) byorder(2 1) nodraw name(e11, replace)
    kmplot, by(g) byorder(2) nodraw name(e11, replace)
    kmplot, by(g3) byorder(3 2) nodraw name(e11, replace)
    kmplot, by(gs) nodraw name(e11, replace)
}
_kmqa_record, name("E11 byorder: no by(), absent level, string by() refused; legal orders run") rc(`=_rc')

**## E12 compete() with riskmask/percent/tmax/ymax/byorder composes
capture noisily {
    _kmce_data
    kmplot, by(g) compete(status == 2) risktable riskmask(5) percent tmax(6) ymax(60) ///
        byorder(2 1) timepoints(0 2 4 6) landmark(3 8) name(e12, replace)
    assert "`r(estimator)'" == "aalen_johansen"
    assert "`r(scale)'" == "percent"
    assert r(tmax) == 6
    assert r(riskmask) == 5
    assert r(ymax) == 60
    tempname L
    matrix `L' = r(landmarks)
    * landmark() beyond tmax() is still computed and returned
    assert rowsof(`L') == 4
    assert !missing(`L'[2, 3]) | !missing(`L'[4, 3])
}
_kmqa_record, name("E12 compete() composes with riskmask, percent, tmax, ymax, byorder") rc(`=_rc')

_kmqa_finish, suite("test_kmplot_compete_errors")
