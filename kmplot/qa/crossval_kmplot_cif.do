* crossval_kmplot_cif.do
* External cross-validation of kmplot, compete(): Aalen-Johansen cumulative
* incidence against R survival::survfit (multi-state pstate), R cmprsk::cuminc
* and Stata stcompet
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-20
*
* Seed: 20261020.  Nine scenarios x 15 replicates x 2 groups (n = 80 each rep):
*   plain     unweighted, one record per subject, continuous times
*   ties      the same draws rounded up to a 0.25 grid: events of both causes
*             and censoring tie at one time
*   wt        pweights in (0.3, 3.3), against survfit(weights =)
*   entry     40% delayed entry, against survfit counting-process input
*   gridentry integer times with entry times tying event times, one record
*   gridid    the same with id() splits at integer times
*   gridfw    gridid with frequency weights; gridpw with double pweights
*             (entry at t is not at risk at t: strict t0 < t)
*   multirec  1-3 contiguous records per subject under stset id(), against
*             survfit counting-process input with id =
* Checks, each at EVERY reference time (1e-10): the saved kmplot curve against
* survfit pstate in all scenarios, against cuminc in plain/ties, against
* stcompet in plain/ties; the unweighted ci limits against stcompet hi/lo
* (1e-8, ln(-ln) transform, Aalen variance as in stcompet); and r(landmarks)
* against the survfit step function.  R and stcompet are required: the suite
* fails, not skips, without them.

clear all
version 16.0
set varabbrev off
local qa_dir "`c(pwd)'"

* stcompet is a user-written command living in the caller's PLUS tree; find it
* before the sandbox replaces PLUS, and install it when missing.
capture findfile stcompet.ado
if _rc {
    quietly ssc install stcompet, replace
    capture findfile stcompet.ado
}
if _rc {
    display as error "stcompet could not be located or installed"
    exit 601
}
local stcompet_dir = substr("`r(fn)'", 1, strlen("`r(fn)'") - strlen("stcompet.ado") - 1)

quietly do "`qa_dir'/_kmplot_qa_common.do"
quietly do "`qa_dir'/_kmplot_qa_cifsupport.do"
_kmplot_qa_bootstrap
adopath + "`stcompet_dir'"
which stcompet

local nrep 15
tempfile sim rin rout
set seed 20261020
clear
set obs `=`nrep' * 80'
gen int rep = ceil(_n / 80)
gen int sid = _n
gen byte g = mod(_n, 2) + 1
gen double t0 = cond(runiform() < .4, runiform() * .8, 0)
gen double t1 = t0 + rexponential(1 / cond(g == 1, .15, .25))
gen double t2 = t0 + rexponential(1 / cond(g == 1, .10, .12))
gen double tc = t0 + 3 + runiform() * 6
gen double T = min(t1, t2, tc)
gen byte status = cond(T == t1, 1, cond(T == t2, 2, 0))
gen double w = .3 + 3 * runiform()
drop t1 t2 tc
* every group of every replicate is observed beyond the last landmark (3)
bysort rep g: egen double maxT = max(T)
assert maxT > 3
drop maxT
tempfile base
save "`base'"

* scenarios
local first 1
foreach sc in plain ties wt entry multirec {
    use "`base'", clear
    gen str10 scenario = "`sc'"
    gen int id = sid
    if inlist("`sc'", "plain", "ties", "wt") replace t0 = 0
    if "`sc'" == "ties" replace T = ceil(T * 4) / 4
    if "`sc'" != "wt" replace w = 1
    if "`sc'" == "multirec" {
        gen byte k = 1 + floor(runiform() * 3)
        expand k
        bysort id: gen int piece = _n
        gen double tstart = t0 + (T - t0) * (piece - 1) / k
        gen double tstop = cond(piece == k, T, t0 + (T - t0) * piece / k)
        replace status = 0 if piece < k
        replace t0 = tstart
        replace T = tstop
        drop k piece tstart tstop
        assert T > t0
    }
    rename T t
    if !`first' {
        append using "`sim'"
    }
    save "`sim'", replace
    local first 0
}
* integer-grid delayed entry: entry times tie event times
use "`sim'", clear
tempfile main
save "`main'"
local gfirst 1
foreach sc in gridentry gridid gridfw gridpw {
    clear
    set seed 20261021
    set obs `=`nrep' * 80'
    gen int rep = ceil(_n / 80)
    gen int id = _n
    gen byte g = mod(_n, 2) + 1
    gen double t0 = cond(runiform() < .5, floor(runiform() * 3), 0)
    gen double d1 = ceil(rexponential(1 / cond(g == 1, .20, .30)))
    gen double d2 = ceil(rexponential(1 / .12))
    gen double dc = 4 + floor(runiform() * 6)
    gen double t = t0 + max(1, min(d1, d2, dc))
    gen byte status = cond(t == t0 + d1 & d1 <= min(d2, dc), 1, cond(t == t0 + d2 & d2 <= dc, 2, 0))
    drop d1 d2 dc
    * the integer grid must create the ties the scenario is about
    gen double w = 1
    if "`sc'" == "gridfw" replace w = 1 + floor(runiform() * 3)
    if "`sc'" == "gridpw" replace w = .3 + 3 * runiform()
    gen str10 scenario = "`sc'"
    if inlist("`sc'", "gridid", "gridfw", "gridpw") {
        * split subjects with two or more time units at an integer cut
        gen byte k = 1 + (t - t0 >= 2 & runiform() < .6)
        gen double cut = t0 + 1 + floor(runiform() * (t - t0 - 1))
        expand k
        bysort id: gen byte piece = _n
        replace t0 = cut if k == 2 & piece == 2
        replace t = cut if k == 2 & piece == 1
        replace status = 0 if k == 2 & piece == 1
        drop k cut piece
        assert t > t0
    }
    * every group of every replicate is observed beyond the last landmark
    bysort rep g: egen double maxT = max(t)
    assert maxT > 3
    drop maxT
    * entry times that tie an event time of a different record exist
    quietly count if t0 > 0
    assert r(N) > 100
    append using "`main'"
    save "`main'", replace
}
use "`main'", clear
order scenario rep g id t0 t status w
sort scenario rep g id t0
save "`sim'", replace
export delimited scenario rep g id t0 t status w using "`rin'.csv", replace

shell Rscript "`qa_dir'/crossval_kmplot_cif.R" "`rin'.csv" "`rout'.csv" > "`rout'.txt" 2>&1
capture confirm file "`rout'.csv"
if _rc {
    type "`rout'.txt"
    display as error "Rscript did not produce reference output; install R, survival and cmprsk"
    exit 601
}
type "`rout'.txt"
import delimited using "`rout'.csv", clear case(preserve) stringcols(1 4) asdouble
tempfile ref
save "`ref'"

local lm "1 2 3"
local test_count = 0
local pass_count = 0
local fail_count = 0
local kmfile "`c(tmpdir)'/kmcif_curve.dta"

foreach sc in plain ties wt entry multirec gridentry gridid gridfw gridpw {
    forvalues r = 1/`nrep' {
        * ---- kmplot
        use "`sim'", clear
        quietly keep if scenario == "`sc'" & rep == `r'
        if "`sc'" == "wt" {
            quietly stset t [pw=w], failure(status == 1)
        }
        else if "`sc'" == "entry" {
            quietly stset t, failure(status == 1) enter(time t0)
        }
        else if "`sc'" == "multirec" | "`sc'" == "gridid" {
            quietly stset t, id(id) failure(status == 1) time0(t0)
        }
        else if "`sc'" == "gridentry" {
            quietly stset t, failure(status == 1) enter(time t0)
        }
        else if "`sc'" == "gridfw" {
            quietly stset t [fw=w], id(id) failure(status == 1) time0(t0)
        }
        else if "`sc'" == "gridpw" {
            quietly stset t [pw=w], id(id) failure(status == 1) time0(t0)
        }
        else {
            quietly stset t, failure(status == 1)
        }
        local minref = cond(substr("`sc'", 1, 4) == "grid", 8, 20)
        local ci ""
        if inlist("`sc'", "plain", "ties") local ci "ci"
        capture noisily kmplot, by(g) compete(status == 2) `ci' landmark(`lm') ///
            saving("`kmfile'", replace) nodraw name(kmcif, replace)
        local krc = _rc
        local est "`r(estimator)'"
        tempname LM
        capture matrix `LM' = r(landmarks)
        if `krc' == 0 & "`est'" != "aalen_johansen" local krc = 9
        if `krc' == 0 & "`est'" == "" local krc = 9

        * ---- survfit pstate at every time (all scenarios)
        local ++test_count
        capture noisily {
            assert `krc' == 0
            preserve
            use "`ref'", clear
            quietly keep if scenario == "`sc'" & rep == `r' & src == "sf"
            rename (g est) (group est)
            keep group time est
            tempfile rsf
            quietly save "`rsf'"
            restore
            preserve
            use "`rsf'", clear
            _kmqa_cmp, km("`kmfile'") ref("`rsf'")
            local nref = r(nref)
            assert r(nmiss) == 0
            assert `nref' >= `minref'
            assert r(maxdiff) < 1e-10
            restore
        }
        local rc1 = _rc
        capture restore
        if `rc1' == 0 {
            local ++pass_count
        }
        else {
            local ++fail_count
            display as error "FAIL: `sc' rep `r' kmplot vs survfit pstate (rc=`rc1')"
        }

        * ---- landmarks against the survfit step function
        local ++test_count
        capture noisily {
            assert `krc' == 0
            assert rowsof(`LM') == 6 & colsof(`LM') == 5
            preserve
            use "`rsf'", clear
            rename (group est) (arm cif)
            local row = 0
            forvalues gi = 1/2 {
                foreach tm of local lm {
                    local ++row
                    _kmqa_step, group(`gi') time(`tm')
                    assert abs(`LM'[`row', 3] - r(value)) < 1e-10
                    assert `LM'[`row', 1] == `gi' & `LM'[`row', 2] == `tm'
                }
            }
            restore
        }
        local rc2 = _rc
        capture restore
        if `rc2' == 0 {
            local ++pass_count
        }
        else {
            local ++fail_count
            display as error "FAIL: `sc' rep `r' landmarks vs survfit step (rc=`rc2')"
        }

        if inlist("`sc'", "plain", "ties") {
            * ---- cmprsk::cuminc
            local ++test_count
            capture noisily {
                assert `krc' == 0
                preserve
                use "`ref'", clear
                quietly keep if scenario == "`sc'" & rep == `r' & src == "cm"
                rename (g est) (group est)
                keep group time est
                tempfile rcm
                quietly save "`rcm'"
                _kmqa_cmp, km("`kmfile'") ref("`rcm'")
                assert r(nmiss) == 0 & r(nref) >= 20
                assert r(maxdiff) < 1e-10
                restore
            }
            local rc3 = _rc
            capture restore
            if `rc3' == 0 {
                local ++pass_count
            }
            else {
                local ++fail_count
                display as error "FAIL: `sc' rep `r' kmplot vs cuminc (rc=`rc3')"
            }

            * ---- stcompet: estimate and ci limits
            local ++test_count
            capture noisily {
                assert `krc' == 0
                use "`sim'", clear
                quietly keep if scenario == "`sc'" & rep == `r'
                quietly stset t, failure(status == 1)
                quietly stcompet sc_ci = ci sc_hi = hi sc_lo = lo, ///
                    compet1(2) by(g)
                * stcompet stores the cause-specific cumulative incidence of the record's own
                * event type in sc_ci; only the rows of the event of interest carry CIF1
                quietly keep if _d == 1 & !missing(sc_ci)
                gen double time = _t
                rename (g sc_ci sc_lo sc_hi) (group est lo hi)
                keep group time est lo hi
                quietly duplicates drop
                isid group time
                tempfile rsc
                quietly save "`rsc'"
                _kmqa_cmp, km("`kmfile'") ref("`rsc'") bounds
                assert r(nmiss) == 0 & r(nref) >= 15
                assert r(maxdiff) < 1e-10
                assert r(nbounds) > 10
                assert r(maxbound) < 1e-8
            }
            local rc4 = _rc
            if `rc4' == 0 {
                local ++pass_count
            }
            else {
                local ++fail_count
                display as error "FAIL: `sc' rep `r' kmplot estimate/ci vs stcompet (rc=`rc4')"
            }
        }
    }
}
capture erase "`kmfile'"
display as text "comparisons: `test_count'  passed: `pass_count'  failed: `fail_count'"
if `fail_count' == 0 {
    display as result "RESULT: crossval_kmplot_cif tests=`test_count' pass=`pass_count' fail=0 skip=0"
}
else {
    display as error "RESULT: crossval_kmplot_cif tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
    exit 1
}
