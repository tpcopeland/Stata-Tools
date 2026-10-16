clear all
set more off
version 16.0
set varabbrev off

* probe_iivw_coulombe_fiptiw.do
*
* PROBE, NOT A GATE. It asserts nothing and is in no lane. It is the source of the
* numbers quoted in the header of crossval_iivw_published_coulombe-2021-biometrics.do
* about why the VW and FIPTM columns of Coulombe Table 3.1 are not reproduced
* through iivw's visit-row input. Same DGP as that suite (thesis section 3.3).
*
*   P1  iivw: OLS / VW / IPT / FIPTM bias, three settings, R = 60. Recorded run:
*       VW 0.82 / -1.14 / -2.02, FIPTM 0.08 / -1.84 / -2.75 (signed bias)
*   P2  the same DGP with the TRUE intensity weights exp(-(g1 I + g2 Z)), R = 150.
*       Recorded: VW 0.79 / 0.68 / 0.73, FIPTM 0.17 / -0.04 / 0.01
*   P3  setting (0,0): SD of OLS (0.680) and of iivw VW (0.699), correlation 0.93,
*       SD of the iivw weight 0.030, R = 300
*   P4  setting (0,0): the paper's estimator on the full 0.01 grid (Cox on I and
*       Z(t) with a row per grid step): variance of OLS 0.382 against VW 0.420,
*       R = 400
* The numbers above are one recorded run; they move in the second digit with R.
*
* Usage: cd iivw/qa; stata-mp -b do probe_iivw_coulombe_fiptiw.do
* Seeds: 101 (P1), 102 (P2), 103 (P3), 104 (P4).

do "`c(pwd)'/_iivw_qa_common.do"
iivw_qa_bootstrap

capture program drop _gen_cb
program define _gen_cb
    version 16.0
    syntax , N(integer) G1(real) G2(real)
    clear
    set obs `n'
    gen long id = _n
    gen double K1 = rnormal(1, 1)
    gen byte K2 = runiform() < 0.55
    gen double K3 = rnormal(0, 1)
    gen byte A = runiform() < invlogit(0.5 + 0.8 * K1 + 0.05 * K2 - K3)
    gen double phi = rnormal(0, 0.2)
    gen double eta = rgamma(100, 0.01)
    gen double C = runiform(1, 2)
    tempfile base
    quietly save `base'
    quietly expand 200
    bysort id: gen int k = _n
    quietly drop if k > 100 * C
    gen double t = k / 100
    gen double Z = cond(A == 1, rnormal(2, 1), rnormal(4, 2))
    gen double EZ = cond(A == 1, 2, 4)
    gen byte vis = runiform() < eta * exp(`g1' * A + `g2' * Z) * 0.01
    quietly keep if vis
    gen double y = 3 + A + 3 * (Z - EZ) + 0.4 * K1 + 0.05 * K2 - 0.6 * K3 + rnormal(phi, 0.1)
    gen byte entry = 0
    drop k vis
    tempfile visits
    quietly save `visits'
    quietly use `base', clear
    gen double t = 0
    gen double y = .
    gen byte entry = 1
    quietly append using `visits'
    sort id t
end


**# P1 iivw estimators, three settings
set seed 101
tempfile p1
capture postclose _p1
postfile _p1 byte set double(ols vw ipt fip) using "`p1'", replace
local si = 0
foreach gs in "0 0" "-0.3 0.2" "0.6 0.3" {
    local ++si
    local g1 : word 1 of `gs'
    local g2 : word 2 of `gs'
    forvalues r = 1/60 {
        _gen_cb, n(250) g1(`g1') g2(`g2')
        quietly iivw_fit y A, unweighted id(id) time(t) timespec(none) nolog
        local bo = _b[A]
        quietly iivw_weight, id(id) time(t) visit_cov(A Z) stabcov(A) wtype(iivw) censor(C) baseline(entry) nolog replace
        quietly iivw_fit y A, timespec(none) vce(fixed) nolog replace
        local bv = _b[A]
        quietly iivw_weight, id(id) time(t) treat(A) treat_cov(K1 K2 K3) wtype(iptw) nolog replace
        quietly iivw_fit y A, timespec(none) vce(fixed) nolog replace
        local bi = _b[A]
        quietly iivw_weight, id(id) time(t) treat(A) treat_cov(K1 K2 K3) visit_cov(Z) wtype(fiptiw) censor(C) baseline(entry) nolog replace
        quietly iivw_fit y A, timespec(ns(3)) vce(fixed) nolog replace
        post _p1 (`si') (`bo') (`bv') (`bi') (_b[A])
    }
}
postclose _p1
use "`p1'", clear
foreach v in ols vw ipt fip {
    replace `v' = `v' - 1
}
collapse (mean) ols vw ipt fip, by(set)
display as text "P1: iivw mean bias by setting (published |bias| OLS .72/1.05/1.98, VW .71/.72/.76, IPT .06/1.77/2.65, FIPTM .09/.04/.00)"
list, noobs

**# P2 true intensity weights
set seed 102
tempfile p2
capture postclose _p2
postfile _p2 byte set double(vw fip) using "`p2'", replace
local si = 0
foreach gs in "0 0" "-0.3 0.2" "0.6 0.3" {
    local ++si
    local g1 : word 1 of `gs'
    local g2 : word 2 of `gs'
    forvalues r = 1/150 {
        _gen_cb, n(250) g1(`g1') g2(`g2')
        quietly keep if entry == 0
        gen double wv = exp(-(`g1' * A + `g2' * Z))
        quietly logit A K1 K2 K3
        quietly predict double ps, pr
        gen double wt = cond(A == 1, 1 / ps, 1 / (1 - ps))
        quietly regress y A [pw = wv]
        local bv = _b[A]
        gen double wf = wv * wt
        quietly regress y A [pw = wf]
        post _p2 (`si') (`bv') (`=_b[A]')
    }
}
postclose _p2
use "`p2'", clear
replace vw = vw - 1
replace fip = fip - 1
collapse (mean) vw fip, by(set)
display as text "P2: true-weight mean bias by setting"
list, noobs

**# P3 setting (0,0): iivw VW variance against OLS
set seed 103
tempfile p3
capture postclose _p3
postfile _p3 double(ols vw sdw) using "`p3'", replace
forvalues r = 1/300 {
    _gen_cb, n(250) g1(0) g2(0)
    quietly iivw_fit y A, unweighted id(id) time(t) timespec(none) nolog
    local bo = _b[A]
    quietly iivw_weight, id(id) time(t) visit_cov(A Z) stabcov(A) wtype(iivw) censor(C) baseline(entry) nolog replace
    quietly summarize _iivw_iw if entry == 0
    local sdw = r(sd)
    quietly iivw_fit y A, timespec(none) vce(fixed) nolog replace
    post _p3 (`bo') (_b[A]) (`sdw')
}
postclose _p3
use "`p3'", clear
summarize
correlate ols vw

**# P4 setting (0,0): the paper's estimator on the full grid
capture program drop _gen_grid
program define _gen_grid
    syntax , N(integer)
    clear
    set obs `n'
    gen long id = _n
    gen double K1 = rnormal(1, 1)
    gen byte K2 = runiform() < 0.55
    gen double K3 = rnormal(0, 1)
    gen byte A = runiform() < invlogit(0.5 + 0.8 * K1 + 0.05 * K2 - K3)
    gen double phi = rnormal(0, 0.2)
    gen double eta = rgamma(100, 0.01)
    gen double C = runiform(1, 2)
    quietly expand 200
    bysort id: gen int k = _n
    quietly drop if k > 100 * C
    gen double t = k / 100
    gen double Z = cond(A == 1, rnormal(2, 1), rnormal(4, 2))
    gen double EZ = cond(A == 1, 2, 4)
    gen byte vis = runiform() < eta * 0.01
    gen double y = 3 + A + 3 * (Z - EZ) + 0.4 * K1 + 0.05 * K2 - 0.6 * K3 + rnormal(phi, 0.1)
end
set seed 104
tempfile p4
capture postclose _p4
postfile _p4 double(ols vw) using "`p4'", replace
forvalues r = 1/400 {
    _gen_grid, n(250)
    gen double t0 = t - 0.01
    quietly stset t, failure(vis) enter(t0) id(id)
    quietly stcox A Z, efron
    quietly predict double xb, xb
    gen double wg = exp(-xb)
    quietly stcox A, efron
    quietly predict double xb0, xb
    replace wg = wg * exp(xb0)
    quietly keep if vis
    quietly regress y A
    local bo = _b[A]
    quietly regress y A [pw = wg]
    post _p4 (`bo') (_b[A])
}
postclose _p4
use "`p4'", clear
quietly summarize ols
display as text "P4: variance OLS " r(sd)^2
quietly summarize vw
display as text "P4: variance grid-VW " r(sd)^2

iivw_qa_sandbox_restore
clear
