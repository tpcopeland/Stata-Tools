* test_ratetab_v254_cluster.do - ratetab ci(cluster()) when events sit in one
* cluster
*
* The help once said a level whose events all come from one cluster has no
* clustered interval. The code gives no interval only when the clustered
* variance is not finite and positive (one fitted cluster, or every cluster
* score zero). Events in one of several exposure clusters still get a finite
* interval.
*
* Oracles: hand calculation, not ratetab output. Records (cid,event,exposure)
* (1,6,1),(2,0,1),(3,0,1): D = 6, Y = 3, rate = 2, scores u_c = d_c - y_c D/Y
* = (4,-2,-2), Var(b) = G/(G-1) * sum(u_c^2) / D^2 = (3/2) * 24 / 36 = 1,
* limits 2 * exp(-/+ invnormal(0.975) * 1).
* Zero-score control (1,1,1),(2,1,1),(3,1,1): every u_c = 0, variance 0.
* Single-cluster control: one cluster, G/(G-1) undefined.
*
* Run from tabtools/qa.

clear all
version 17.0
set more off
set varabbrev off

capture log close _rt254
log using "test_ratetab_v254_cluster.log", replace text name(_rt254)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

local pass_count = 0
local fail_count = 0
local test_count = 0

capture program drop _rt254_data
program define _rt254_data
    version 17.0
    args which
    clear
    quietly set obs 3
    gen long cid = _n
    gen double d = 0
    gen double y = 1
    gen byte g = 1
    if "`which'" == "conc" quietly replace d = 6 in 1
    if "`which'" == "zero" quietly replace d = 1
    if "`which'" == "one" {
        quietly replace cid = 1
        quietly replace d = 6 in 1
    }
end

**# C1: events in one of three exposure clusters keep a finite interval
local ++test_count
capture noisily {
    _rt254_data conc
    ratetab g, events(d) exposure(y) ci(cluster(cid)) per(1) pyscale(1) level(95) nosmallcells
    assert r(N_noci) == 0
    matrix E = r(estimates)
    assert rowsof(E) == 1
    local z = invnormal(0.975)
    local lb0 = 2 * exp(-`z')
    local ub0 = 2 * exp(`z')
    assert !missing(E[1, 7]) & !missing(E[1, 8])
    assert reldif(E[1, 7], `lb0') < 1e-9 & reldif(E[1, 8], `ub0') < 1e-9
    * the values quoted in the ticket, independently
    assert reldif(E[1, 7], 0.28172698818643499) < 1e-9
    assert reldif(E[1, 8], 14.198142768462672) < 1e-9
    assert E[1, 4] == 6 & E[1, 5] == 3 & E[1, 6] == 2
    assert el(r(clusters), 1, 1) == 3
}
if _rc == 0 {
    display as result "  PASS: C1 events in one of three clusters: interval printed, N_noci 0"
    local ++pass_count
}
else {
    display as error "  FAIL: C1 concentrated events (rc=`=_rc')"
    local ++fail_count
}

**# C2: one fitted cluster in total has no interval
local ++test_count
capture noisily {
    _rt254_data one
    ratetab g, events(d) exposure(y) ci(cluster(cid)) per(1) pyscale(1) level(95) nosmallcells
    assert r(N_noci) == 1
    matrix E = r(estimates)
    assert E[1, 4] == 6 & E[1, 5] == 3 & reldif(E[1, 6], 2) < 1e-12
    assert missing(E[1, 7]) & missing(E[1, 8])
    assert el(r(clusters), 1, 1) == 1
}
if _rc == 0 {
    display as result "  PASS: C2 a single total cluster: missing bounds, N_noci 1"
    local ++pass_count
}
else {
    display as error "  FAIL: C2 single total cluster (rc=`=_rc')"
    local ++fail_count
}

**# C3: every cluster score zero (zero variance) has no interval
local ++test_count
capture noisily {
    _rt254_data zero
    ratetab g, events(d) exposure(y) ci(cluster(cid)) per(1) pyscale(1) level(95) nosmallcells
    assert r(N_noci) == 1
    matrix E = r(estimates)
    assert E[1, 4] == 3 & E[1, 5] == 3 & reldif(E[1, 6], 1) < 1e-12
    assert missing(E[1, 7]) & missing(E[1, 8])
    assert el(r(clusters), 1, 1) == 3
}
if _rc == 0 {
    display as result "  PASS: C3 balanced zero scores: missing bounds, N_noci 1"
    local ++pass_count
}
else {
    display as error "  FAIL: C3 zero-score control (rc=`=_rc')"
    local ++fail_count
}

**# C4: the help no longer says one event cluster means no interval, and
**#     states the primary-mode ESS exception
local ++test_count
capture noisily {
    tempname fh
    foreach f in ratetab desctab table1_tc {
        mata: st_local("txt", invtokens(cat("`pkg_dir'/`f'.sthlp")'))
        local txt = subinstr(`"`txt'"', char(10), " ", .)
        if "`f'" == "ratetab" {
            assert strpos(`"`txt'"', "events all come from one cluster") == 0
            assert strpos(`"`txt'"', "only one fitted cluster") > 0
            assert strpos(`"`txt'"', "one of several exposure clusters") > 0
        }
        else {
            assert strpos(`"`txt'"', "nothing else changes") == 0
            assert strpos(`"`txt'"', "effective sample size") > 0
            assert strpos(`"`txt'"', "(suppression code 3)") > 0
        }
    }
}
if _rc == 0 {
    display as result "  PASS: C4 help text states the corrected contracts"
    local ++pass_count
}
else {
    display as error "  FAIL: C4 help text (rc=`=_rc')"
    local ++fail_count
}

**# C5: primary mode withholds a weighted ESS whose group N is masked
local ++test_count
capture noisily {
    clear
    quietly set obs 10
    gen double age = _n
    gen str5 grp = cond(_n <= 2, "Small", "Large")
    gen double w = 1
    quietly replace w = 3 in 2
    desctab age, by(grp) vars(age contn) wt(w) wtn wtcompare smd smallcells(5, primary) clear
    assert r(N_primary_suppressed) == 2 & r(N_secondary_suppressed) == 0
    assert r(N_derived_suppressed) == 1
    * exactly one code-3 cell in r(suppression), and no SMD or p-value cell
    * carries it: the only derived cell is the ESS
    matrix S = r(suppression)
    mata: st_local("n3", strofreal(sum(st_matrix("S") :== 3)))
    mata: st_local("n1", strofreal(sum(st_matrix("S") :== 1)))
    assert `n3' == 1 & `n1' == 2
    local cn : colnames S
    assert colsof(S) >= 4
    * unweighted primary: no derived cells
    clear
    quietly set obs 10
    gen double age = _n
    gen str5 grp = cond(_n <= 2, "Small", "Large")
    desctab age, by(grp) vars(age contn) smd smallcells(5, primary) clear
    assert r(N_derived_suppressed) == 0
}
if _rc == 0 {
    display as result "  PASS: C5 primary mode counts the masked weighted ESS in N_derived_suppressed"
    local ++pass_count
}
else {
    display as error "  FAIL: C5 primary ESS (rc=`=_rc')"
    local ++fail_count
}

**# C6: the desctab and crosstab primary-mode footnotes no longer claim every other cell, total
**#     and test is shown as computed
local ++test_count
capture noisily {
    clear
    quietly set obs 10
    gen double age = _n
    gen str5 grp = cond(_n <= 2, "Small", "Large")
    tempfile fnlog
    local ls = c(linesize)
    set linesize 255
    quietly log using "`fnlog'", text replace name(_rt254fn)
    desctab age, by(grp) vars(age contn) smd smallcells(5, primary) clear
    quietly log close _rt254fn
    mata: st_local("txt", invtokens(cat("`fnlog'")'))
    assert strpos(`"`txt'"', "primary suppression only: no complementary cells are masked)") > 0
    assert strpos(`"`txt'"', "shown as computed") == 0
    * crosstab prints the same primary-mode footnote
    sysuse auto, clear
    quietly log using "`fnlog'", text replace name(_rt254fn)
    crosstab rep78 foreign, colpct smallcells(5, primary)
    quietly log close _rt254fn
    mata: st_local("txt", invtokens(cat("`fnlog'")'))
    assert strpos(`"`txt'"', "primary suppression only: no complementary cells are masked)") > 0
    assert strpos(`"`txt'"', "shown as computed") == 0
    set linesize `ls'
}
if _rc == 0 {
    display as result "  PASS: C6 primary footnote drops the shown-as-computed clause"
    local ++pass_count
}
else {
    local rc6 = _rc
    capture log close _rt254fn
    display as error "  FAIL: C6 primary footnote (rc=`rc6')"
    local ++fail_count
}

display "RESULT: test_ratetab_v254_cluster tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _rt254
if `fail_count' > 0 exit 9
