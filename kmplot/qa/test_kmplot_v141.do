* test_kmplot_v141.do
* Regression pins for the 2026-10-12 final clarity audit (I1, M1)
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-12
*
* Run from kmplot/qa:  stata-mp -b do test_kmplot_v141.do

clear all
version 16.0
set varabbrev off
local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

local test_count = 0
local pass_count = 0
local failed ""

capture program drop _km141_result
program define _km141_result, rclass
    args rc label
    if `rc' == 0 {
        display as result "PASS: `label'"
        return scalar pass = 1
    }
    else {
        display as error "FAIL: `label' (rc=`rc')"
        return scalar pass = 0
    }
end

* Last coordinate of serset #id: r(tmax) is the largest x (the last
* variable), r(y1) and r(y2) the first two variables on the last row at
* that x.  Serset variables are tempvars, so they are taken by position.
capture program drop _km141_serset_end
program define _km141_serset_end, rclass
    args id
    preserve
    serset set `id'
    serset use, clear
    unab cols : _all
    local nc : word count `cols'
    local tt : word `nc' of `cols'
    local v1 : word 1 of `cols'
    quietly drop if missing(`tt') | missing(`v1')
    gen long _km141_o = _n
    sort `tt' _km141_o
    return scalar tmax = `tt'[_N]
    return scalar y1 = `v1'[_N]
    if `nc' >= 3 {
        local v2 : word 2 of `cols'
        return scalar y2 = `v2'[_N]
    }
    return scalar N = _N
    restore
end

* Five subjects, all failing except the one censored at t = 3, so the
* curve reaches S = 0 (F = 1) at t = 5 with bounds defined on [4, 5).
capture program drop _km141_fixture
program define _km141_fixture
    clear
    quietly set obs 5
    gen double t = _n
    gen byte d = (_n != 3)
    quietly stset t, failure(d)
end

**# I1 drawn CI stops one interval early where the curve reaches 0

**## I1a band and CI lines end at the terminal time, as in sts graph, ci
local ++test_count
capture noisily {
    foreach mode in survival failure {
        local f = cond("`mode'" == "failure", "failure", "")
        _km141_fixture
        serset clear
        sts graph, ci `f' name(km141sts, replace)
        * sts graph: serset 0 is the band (lb ub _t).
        _km141_serset_end 0
        scalar sts_t = r(tmax)
        scalar sts_lo = min(r(y1), r(y2))
        scalar sts_hi = max(r(y1), r(y2))
        assert scalar(sts_t) == 5
        graph drop km141sts

        * cistyle(band): serset 0 is the stepped band (hi lo time).
        serset clear
        kmplot, ci `f' name(km141b, replace)
        _km141_serset_end 0
        assert r(tmax) == scalar(sts_t)
        assert !missing(r(y1), r(y2))
        local blo = min(r(y1), r(y2))
        local bhi = max(r(y1), r(y2))
        assert !missing(`blo', scalar(sts_lo))
        assert reldif(`blo', scalar(sts_lo)) < 1e-6
        assert !missing(`bhi', scalar(sts_hi))
        assert reldif(`bhi', scalar(sts_hi)) < 1e-6
        graph drop km141b

        * cistyle(line): serset 0 is the curve, 1 the lower, 2 the upper line.
        serset clear
        kmplot, ci cistyle(line) `f' name(km141l, replace)
        _km141_serset_end 1
        assert r(tmax) == scalar(sts_t)
        assert !missing(r(y1), scalar(sts_lo))
        assert reldif(r(y1), scalar(sts_lo)) < 1e-6
        _km141_serset_end 2
        assert r(tmax) == scalar(sts_t)
        assert !missing(r(y1), scalar(sts_hi))
        assert reldif(r(y1), scalar(sts_hi)) < 1e-6
        graph drop km141l
    }
    scalar drop sts_t sts_lo sts_hi
}
_km141_result `=_rc' "I1a band and CI lines end at the terminal time, as in sts graph, ci"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' I1a"

**## I1b returned and saved bounds stay missing at S = 0
local ++test_count
capture noisily {
    foreach mode in survival failure {
        local f = cond("`mode'" == "failure", "failure", "")
        _km141_fixture
        tempfile curve
        kmplot, ci `f' landmark(4 5) saving("`curve'", replace) name(km141s, replace)
        tempname lm
        matrix `lm' = r(landmarks)
        assert !missing(`lm'[1, 4], `lm'[1, 5])
        assert `lm'[2, 3] == ("`mode'" == "failure")
        assert missing(`lm'[2, 4], `lm'[2, 5])
        preserve
        use "`curve'", clear
        assert missing(lower, upper) if time == 5
        assert !missing(lower, upper) if time == 4
        * Plot-only rows never reach the saved data.
        assert !missing(group, time)
        assert _N == 6
        restore
        graph drop km141s
    }
}
_km141_result `=_rc' "I1b returned and saved bounds stay missing at S = 0"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' I1b"

**## I1c per-group: only a group that reaches 0 gains the terminal point
local ++test_count
capture noisily {
    * sysuse cancer: Placebo (drug 1) reaches S = 0 at t = 23 with bounds
    * last defined at t = 22; drug 3 ends censored at t = 39 with S > 0.
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    serset clear
    kmplot, by(drug) ci name(km141c, replace)
    * Bands come first, one serset per group.
    _km141_serset_end 0
    assert r(tmax) == 23
    scalar lo23 = min(r(y1), r(y2))
    scalar hi23 = max(r(y1), r(y2))
    _km141_serset_end 2
    local t3 = r(tmax)
    quietly summarize _t if drug == 3
    assert `t3' == r(max)
    graph drop km141c
    * The carried bounds are the saved bounds at t = 22.
    tempfile curve
    kmplot if drug == 1, ci saving("`curve'", replace) name(km141c1, replace)
    graph drop km141c1
    preserve
    use "`curve'", clear
    quietly summarize lower if time == 22, meanonly
    assert !missing(r(mean), scalar(lo23))
    assert reldif(r(mean), scalar(lo23)) < 1e-6
    quietly summarize upper if time == 22, meanonly
    assert !missing(r(mean), scalar(hi23))
    assert reldif(r(mean), scalar(hi23)) < 1e-6
    assert missing(lower, upper) if time == 23
    restore
    scalar drop lo23 hi23

    * A group whose curve drops from 1 straight to 0 has no bounds to
    * carry, so it draws no band; the other group still draws its own.
    clear
    input double t byte d byte g
    2 1 1
    1 1 2
    2 1 2
    3 0 2
    4 1 2
    end
    quietly stset t, failure(d)
    serset clear
    kmplot, by(g) ci cistyle(line) name(km141d, replace)
    * Group 2's CI lines end at t = 4, where its curve reaches 0 (1.4.0
    * stopped them at t = 3).  Group 1 has no bounds, so draws none.
    local found = 0
    forvalues s = 0/6 {
        capture _km141_serset_end `s'
        if _rc continue
        if r(N) > 0 & r(tmax) == 4 & r(y1) < 1 & r(y1) > 0 local found = 1
    }
    assert `found'
    graph drop km141d
}
_km141_result `=_rc' "I1c per-group: only a group that reaches 0 gains the terminal point"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' I1c"

**# M1 riskheight() requires risktable

**## M1 riskheight() without risktable is refused; r(riskheight) only with a table
local ++test_count
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    local rf "`c(tmpdir)'/km141_risk.dta"
    capture kmplot, by(drug) riskheight(30) risksaving("`rf'", replace) ///
        name(km141m, replace)
    assert _rc == 198
    capture kmplot, by(drug) riskheight(30) name(km141m, replace)
    assert _rc == 198
    kmplot, by(drug) risksaving("`rf'", replace) name(km141m, replace)
    assert missing(r(riskheight))
    confirm file "`rf'"
    kmplot, by(drug) risktable riskheight(30) name(km141m, replace)
    assert r(riskheight) == 30
    kmplot, by(drug) risktable risksaving("`rf'", replace) name(km141m, replace)
    assert r(riskheight) == 25
    capture erase "`rf'"
    capture graph drop km141m
}
_km141_result `=_rc' "M1 riskheight() without risktable is refused; r(riskheight) only with a table"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' M1"

local fail_count = `test_count' - `pass_count'
if "`failed'" != "" display as error "Failed:`failed'"
display "RESULT: test_kmplot_v141 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
