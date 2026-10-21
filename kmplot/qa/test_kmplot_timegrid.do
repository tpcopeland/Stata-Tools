* test_kmplot_timegrid.do
* Requested-time grid: float time variables, decimal ranges, duplicate times,
* times beyond tmax(), and the automatic y-axis top
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-20
*
* Expected values are hand-computed from the fixtures (product-limit fractions
* and record counts written out below), never read from kmplot.
*
* Float fixture F: t = .1 .2 .3 .3 .7 .9 1.1 1.3 stored as float,
* d = 1 1 0 1 1 0 1 0.  Product limit: S(.1) = 7/8, S(.2) = 6/8,
* S(.3) = 6/8 * 5/6 = 5/8, S(.7) = 5/8 * 3/4 = 15/32.
* At risk (t >= tp): 8 at .1, 6 at .3, 4 at .7.  Cumulative events
* (t <= tp, d = 1): 1, 3, 4.  Cumulative censored: 0, 1, 1.

clear all
version 16.0
set varabbrev off
local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_kmplot_qa_common.do"
quietly do "`qa_dir'/_kmplot_qa_cifsupport.do"
_kmplot_qa_bootstrap
_kmqa_init
global TABTOOLS_set_smallcells ""

capture program drop _kmtg_float
program define _kmtg_float
    version 16.0
    syntax , [TYPE(string)]
    if "`type'" == "" local type "float"
    clear
    quietly set obs 8
    gen `type' t = real(word(".1 .2 .3 .3 .7 .9 1.1 1.3", _n))
    gen byte d = real(word("1 1 0 1 1 0 1 0", _n))
end

* hand truth for fixture F at .1 .3 .7
matrix KMTG_S = (7/8 \ 5/8 \ 15/32)
matrix KMTG_R = (8, 1, 0 \ 6, 3, 1 \ 4, 4, 1)

capture program drop _kmtg_check
program define _kmtg_check
    version 16.0
    * r(landmarks) and r(risktable) of the last kmplot call against the truth
    tempname L R
    matrix `L' = r(landmarks)
    matrix `R' = r(risktable)
    assert rowsof(`L') == 3 & rowsof(`R') == 3
    forvalues i = 1/3 {
        assert !missing(`L'[`i', 3])
        assert !missing(KMTG_S[`i', 1])
        assert reldif(`L'[`i', 3], KMTG_S[`i', 1]) < 1e-12
        forvalues j = 1/3 {
            assert `R'[`i', `j' + 2] == KMTG_R[`i', `j']
        }
    }
end

**## G1 float time: landmarks and risk-table counts at records stored exactly at the times
capture noisily {
    _kmtg_float
    quietly stset t, failure(d)
    assert "`: type t'" == "float"
    kmplot, landmark(0.1 0.3 0.7) risktable timepoints(0.1 0.3 0.7) nodraw
    _kmtg_check
}
_kmqa_record, name("G1 float time: landmark() and risk table count the records at .1, .3, .7") rc(`=_rc')

**## G2 the same data stored as double give the same answers (metamorphic)
capture noisily {
    _kmtg_float, type(double)
    quietly stset t, failure(d)
    kmplot, landmark(0.1 0.3 0.7) risktable timepoints(0.1 0.3 0.7) nodraw
    _kmtg_check
    tempname LD RD
    matrix `LD' = r(landmarks)
    matrix `RD' = r(risktable)
    _kmtg_float
    quietly stset t, failure(d)
    kmplot, landmark(0.1 0.3 0.7) risktable timepoints(0.1 0.3 0.7) nodraw
    assert mreldif(r(landmarks), `LD') < 1e-12
    assert mreldif(r(risktable), `RD') == 0
}
_kmqa_record, name("G2 float and double storage of the same decimals agree") rc(`=_rc')

**## G3 float time under scale(): requested analysis times map through the stset transform
capture noisily {
    _kmtg_float
    quietly stset t, failure(d) scale(0.1)
    kmplot, landmark(1 3 7) risktable timepoints(1 3 7) nodraw
    _kmtg_check
    _kmtg_float
    quietly stset t, failure(d) origin(time 0.1)
    * analysis time t - .1: the records at .1 .3 .7 sit at 0, .2, .6
    kmplot, landmark(0.2 0.6) risktable timepoints(0.2 0.6) nodraw
    tempname L R
    matrix `L' = r(landmarks)
    matrix `R' = r(risktable)
    assert !missing(`L'[1, 3])
    assert reldif(`L'[1, 3], 5/8) < 1e-12
    assert !missing(`L'[2, 3])
    assert reldif(`L'[2, 3], 15/32) < 1e-12
    * at risk: origin moves the record at .1 to 0, so it is not at risk
    * after 0; events at .1 (time 0) are not counted by stset
    assert `R'[1, 3] == 6 & `R'[2, 3] == 4
}
_kmqa_record, name("G3 float time with scale() and origin(): the transformed grid is matched") rc(`=_rc')

**## G4 float time and tmax(): the record at tmax() is plotted, so ymax() below it is refused
capture noisily {
    _kmtg_float
    quietly stset t, failure(d)
    * F(.3) = 3/8 is drawn at t = .3 = tmax()
    kmplot, failure tmax(0.3) nodraw
    assert r(ymax) >= 3/8 & r(ymax) < .
    _kmqa_expect, rc(198) cmd(kmplot, failure tmax(0.3) ymax(0.3) nodraw) ///
        text("below the plotted maximum")
}
_kmqa_record, name("G4 float time: tmax() includes the record stored at tmax()") rc(`=_rc')

**## G5 decimal range equals the typed list: risk table and r(timepoints)
capture noisily {
    clear
    set obs 20
    gen double t = _n / 10
    gen byte d = 1
    quietly stset t, failure(d)
    kmplot, risktable timepoints(0(0.1)1) nodraw
    local tp_range "`r(timepoints)'"
    tempname RR
    matrix `RR' = r(risktable)
    kmplot, risktable timepoints(0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1) nodraw
    assert "`r(timepoints)'" == "`tp_range'"
    assert mreldif(r(risktable), `RR') == 0
    * hand count: 20 records at .1, .2, ..., 2.0; at risk at .3 is 18, at .6 15
    assert `RR'[4, 3] == 18
    assert `RR'[7, 3] == 15
    assert `RR'[8, 3] == 14
    foreach tp of local tp_range {
        assert strlen("`tp'") <= 3
    }
}
_kmqa_record, name("G5 timepoints(0(0.1)1) equals the typed decimals") rc(`=_rc')

**## G6 decimal range in landmark() equals the typed list
capture noisily {
    clear
    set obs 20
    gen double t = _n / 10
    gen byte d = 1
    quietly stset t, failure(d)
    kmplot, landmark(0(0.1)0.5) nodraw
    tempname LR
    matrix `LR' = r(landmarks)
    kmplot, landmark(0 0.1 0.2 0.3 0.4 0.5) nodraw
    assert mreldif(r(landmarks), `LR') == 0
    * S(.3) = 1 - 3/20, S(.5) = 1 - 5/20
    assert !missing(`LR'[4, 3])
    assert reldif(`LR'[4, 3], 17/20) < 1e-12
    assert !missing(`LR'[6, 3])
    assert reldif(`LR'[6, 3], 15/20) < 1e-12
    kmplot, landmark(0.1(0.1)0.3) nodraw
    assert !missing(r(landmarks)[3, 3])
    assert reldif(r(landmarks)[3, 3], 17/20) < 1e-12
    assert r(landmarks)[3, 2] == 0.3
}
_kmqa_record, name("G6 landmark(0(0.1)0.5) equals the typed decimals") rc(`=_rc')

**## G7 duplicate times are dropped (typed, and a range member equal to a typed value)
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    kmplot, by(drug) risktable timepoints(0 12 12 24) nodraw
    assert "`r(timepoints)'" == "0 12 24"
    assert r(n_timepoints) == 3
    assert rowsof(r(risktable)) == 9
    kmplot, landmark(5 5) nodraw
    assert r(n_landmarks) == 1
    assert rowsof(r(landmarks)) == 1
    assert "`r(landmark_times)'" == "5"
    clear
    set obs 20
    gen double t = _n / 10
    gen byte d = 1
    quietly stset t, failure(d)
    kmplot, risktable timepoints(0(0.1)0.3 0.3) nodraw
    assert r(n_timepoints) == 4
    assert "`r(timepoints)'" == "0 .1 .2 .3"
}
_kmqa_record, name("G7 duplicate timepoints() and landmark() times are dropped") rc(`=_rc')

**## G8 timepoints() beyond tmax() are refused; within tmax() they are kept
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    _kmqa_expect, rc(198) cmd(kmplot, by(drug) risktable tmax(30) timepoints(0 10 50) nodraw) ///
        text("beyond tmax(30)")
    _kmqa_expect, rc(198) cmd(kmplot, by(drug) risksaving(x.dta, replace) tmax(30) timepoints(0 31) nodraw) ///
        text("beyond tmax(30)")
    kmplot, by(drug) risktable tmax(30) timepoints(0 10 30) nodraw
    assert "`r(timepoints)'" == "0 10 30"
    * the same limit for positions taken from xlabel()
    _kmqa_expect, rc(198) cmd(kmplot, by(drug) risktable tmax(30) xlabel(0 20 40) nodraw) ///
        text("beyond tmax(30)")
    kmplot, by(drug) risktable tmax(30) xlabel(0 15 30) nodraw
    assert "`r(timepoints)'" == "0 15 30"
}
_kmqa_record, name("G8 risk-table times beyond tmax() are an error") rc(`=_rc')

**## G9 median guide lines stop at tmax(): no line for a median beyond it
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    tempfile sv
    * group 3 (median 33) is drawn first, in blue (#0072B2)
    kmplot, by(drug) byorder(3 1 2) median tmax(30) xlabel(0 10 20 30) ///
        export("`sv'.svg", replace)
    assert r(median_1) == 33
    assert r(median_2) == 8
    * x position of the 30 tick label
    local x30 = .
    local n_blue_beyond = 0
    local grey_max = 0
    tempname fh
    file open `fh' using "`sv'.svg", read text
    file read `fh' line
    while r(eof) == 0 {
        if regexm(`"`line'"', `"<text x="([0-9.]+)"[^>]*>30</text>"') {
            local x30 = real(regexs(1))
        }
        if regexm(`"`line'"', `"<line x1="([0-9.]+)" y1="[0-9.]+" x2="([0-9.]+)" y2="[0-9.]+" style="stroke:#([0-9A-F]+)"') {
            local x1 = real(regexs(1))
            local x2 = real(regexs(2))
            local col = regexs(3)
            if "`col'" == "0072B2" & `x1' == `x2' {
                local ++n_blue_beyond
                local blue_x_`n_blue_beyond' = `x1'
            }
            if "`col'" == "C0C0C0" & `x2' > `grey_max' local grey_max = `x2'
        }
        file read `fh' line
    }
    file close `fh'
    assert `x30' < .
    local beyond = 0
    forvalues i = 1/`n_blue_beyond' {
        if `blue_x_`i'' > `x30' + 2 local ++beyond
    }
    assert `beyond' == 0
    assert `grey_max' > 0
    assert `grey_max' <= `x30' + 2
}
_kmqa_record, name("G9 median lines beyond tmax() are not drawn; r(median_#) kept") rc(`=_rc')

**## G10 automatic y-axis top carries no floating-point noise
capture noisily {
    clear
    set obs 20
    gen double t = _n
    gen byte d = (_n <= 11)
    quietly stset t, failure(d)
    * F max = 11/20 = .55; automatic step .1, so the top is .6, not 6 * .1
    kmplot, failure nodraw
    assert r(ymax) == 0.6
    assert "`: display %21.17g r(ymax)'" == "`: display %21.17g 0.6'"
}
_kmqa_record, name("G10 r(ymax) is the decimal axis top (.6, not .6000000000000001)") rc(`=_rc')

_kmqa_finish, suite("test_kmplot_timegrid")
