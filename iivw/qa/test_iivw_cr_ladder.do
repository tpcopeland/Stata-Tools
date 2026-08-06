* =============================================================================
* test_iivw_cr_ladder.do - prove the CR ladder transcription against clubSandwich
* =============================================================================
* _iivw_cr_ladder.do claims to reproduce clubSandwich's CR0 / CR1S / CR2 / CR3
* cluster-robust standard errors for a weighted linear fit. That claim is the
* whole basis of probe_cr_ladder.do's numbers, and a transcription error in the
* CR2 adjustment would produce plausible SEs that are simply wrong -- rc 0, no
* warning, and an inflation factor nobody could distinguish from a real one.
*
* So the reference implementation itself is the oracle: every case below is
* recomputed by R's clubSandwich (crossval_cr_ladder.R) and compared. The test
* SKIPS if R or clubSandwich is unavailable rather than passing vacuously.
*
* Stata's `shell' NEVER sets _rc, so every R call here is verified by the
* existence and shape of its output file, never by a return code.
*
* Cases:
*   C1  wide clusters, strong weight variation      (transcription)
*   C2  ragged small clusters incl. singletons      (CR3 near-singular I-H)
*   C3  real FIPTIW weights from iivw_weight         (end-to-end)
*   C4  CR0/CR1S against Stata's own glm vce(cluster) (which rung Stata ships)
*   C5  unsorted input must not change the answer    (the sort contract)
* =============================================================================

clear all
version 16.0
set varabbrev off

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_cr_ladder.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"
do "`qa_dir'/_iivw_cr_ladder.do"

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0
local failed_tests ""

* -----------------------------------------------------------------------------
* Is the oracle available? A missing oracle is a SKIP, never a silent pass.
* -----------------------------------------------------------------------------
tempfile rprobe
local have_R = 0
shell Rscript -e "cat(as.character(packageVersion('clubSandwich')))" > "`rprobe'" 2>/dev/null
capture confirm file "`rprobe'"
if !_rc {
    tempname fh
    capture file open `fh' using "`rprobe'", read text
    if !_rc {
        file read `fh' rline
        file close `fh'
        if regexm("`rline'", "^[0-9]+\.[0-9]+") local have_R = 1
        local cs_version "`rline'"
    }
}
if `have_R' {
    display as text "clubSandwich oracle available: version `cs_version'"
}
else {
    display as error "clubSandwich not available -- oracle cases will SKIP"
}

* -----------------------------------------------------------------------------
* Helper: run the ladder, export the same rows, run R, compare.
* -----------------------------------------------------------------------------
capture program drop _cr_compare
program define _cr_compare, rclass
    version 16.0
    syntax , YVAR(varname) XVAR(varname) WVAR(varname) IDVAR(varname) ///
        TOL(real) LABel(string) [IFEXP(string)]

    local ifc ""
    if `"`ifexp'"' != "" local ifc "if `ifexp'"

    iivw_cr_ladder `yvar' `xvar' `ifc', clustervar(`idvar') weightvar(`wvar')
    local s_b    = r(b)
    local s_cr0  = r(se_cr0)
    local s_cr1  = r(se_cr1)
    local s_cr1s = r(se_cr1s)
    local s_cr2  = r(se_cr2)
    local s_cr3  = r(se_cr3)
    local s_m    = r(nclust)
    local s_n    = r(nobs)

    * The handoff is BINARY, not CSV. Measured 2026-08-06: through a CSV the two
    * implementations agreed to only ~3e-9, while on natively generated data
    * they agree to ~5e-16 -- so the gap was the text round trip, not the
    * algebra. A tolerance loosened to accommodate 3e-9 would have been wide
    * enough to hide a real error in the CR2 adjustment, which is the one thing
    * this test exists to catch.
    tempfile indta outcsv
    preserve
        if `"`ifexp'"' != "" quietly keep if `ifexp'
        quietly keep if !missing(`yvar', `xvar', `wvar', `idvar')
        quietly keep `yvar' `xvar' `wvar' `idvar'
        quietly rename `yvar' y
        quietly rename `xvar' x
        quietly rename `wvar' w
        quietly rename `idvar' id
        quietly order y x w id
        quietly recast double y x w
        quietly save "`indta'", replace
    restore

    shell Rscript crossval_cr_ladder.R "`indta'" "`outcsv'" > /dev/null 2>&1

    * shell never sets _rc: verify by reading the artifact.
    capture confirm file "`outcsv'"
    if _rc {
        return scalar ok = -1
        return local why "R produced no output file"
        exit
    }
    * levelsof would round each value through its display format, which is far
    * coarser than the 1e-8 agreement this test is asserting. Read the numbers
    * as doubles instead.
    tempname R_B R_CR0 R_CR1 R_CR1S R_CR2 R_CR3
    preserve
        quietly import delimited using "`outcsv'", clear varnames(1) case(preserve)
        quietly count
        local nrow = r(N)
        if `nrow' != 6 {
            restore
            return scalar ok = -1
            return local why "R output has `nrow' rows, expected 6"
            exit
        }
        quietly summarize value if type == "b",    meanonly
        scalar `R_B' = r(mean)
        quietly summarize value if type == "CR0",  meanonly
        scalar `R_CR0' = r(mean)
        quietly summarize value if type == "CR1",  meanonly
        scalar `R_CR1' = r(mean)
        quietly summarize value if type == "CR1S", meanonly
        scalar `R_CR1S' = r(mean)
        quietly summarize value if type == "CR2",  meanonly
        scalar `R_CR2' = r(mean)
        quietly summarize value if type == "CR3",  meanonly
        scalar `R_CR3' = r(mean)
    restore
    local r_b    = `R_B'
    local r_cr0  = `R_CR0'
    local r_cr1  = `R_CR1'
    local r_cr1s = `R_CR1S'
    local r_cr2  = `R_CR2'
    local r_cr3  = `R_CR3'

    local d_b    = reldif(`s_b',    `r_b')
    local d_cr0  = reldif(`s_cr0',  `r_cr0')
    local d_cr1  = reldif(`s_cr1',  `r_cr1')
    local d_cr1s = reldif(`s_cr1s', `r_cr1s')
    local d_cr2  = reldif(`s_cr2',  `r_cr2')
    local d_cr3  = reldif(`s_cr3',  `r_cr3')
    local worst  = max(`d_b', `d_cr0', `d_cr1', `d_cr1s', `d_cr2', `d_cr3')

    display as text "`label': n=`s_n' m=`s_m'"
    display as text "   b    Stata " %12.9f `s_b'    "  R " %12.9f `r_b'    "  reldif " %8.2e `d_b'
    display as text "   CR0  Stata " %12.9f `s_cr0'  "  R " %12.9f `r_cr0'  "  reldif " %8.2e `d_cr0'
    display as text "   CR1  Stata " %12.9f `s_cr1'  "  R " %12.9f `r_cr1'  "  reldif " %8.2e `d_cr1'
    display as text "   CR1S Stata " %12.9f `s_cr1s' "  R " %12.9f `r_cr1s' "  reldif " %8.2e `d_cr1s'
    display as text "   CR2  Stata " %12.9f `s_cr2'  "  R " %12.9f `r_cr2'  "  reldif " %8.2e `d_cr2'
    display as text "   CR3  Stata " %12.9f `s_cr3'  "  R " %12.9f `r_cr3'  "  reldif " %8.2e `d_cr3'

    return scalar worst = `worst'
    return scalar ok = (`worst' < `tol') & !missing(`worst')
    return scalar se_cr0  = `s_cr0'
    return scalar se_cr1  = `s_cr1'
    return scalar se_cr1s = `s_cr1s'
    return scalar se_cr2  = `s_cr2'
    return scalar se_cr3  = `s_cr3'
    return local why ""
end

**# C1 - wide clusters, strong weight variation

local ++test_count
if `have_R' {
    clear
    set seed 91117
    quietly set obs 80
    quietly generate long id = _n
    quietly generate double u = rnormal(0, 0.8)
    quietly expand 12
    bysort id: generate int k = _n
    quietly generate double x = rnormal(0, 1) + 0.3*u
    quietly generate double w = exp(rnormal(0, 1.1))
    quietly generate double y = 1 + 0.7*x + u + rnormal(0, 0.5)

    _cr_compare, yvar(y) xvar(x) wvar(w) idvar(id) tol(1e-10) label("C1 wide clusters")
    if r(ok) == 1 {
        local ++pass_count
        display "PASS C1: CR ladder matches clubSandwich (worst reldif " %8.2e r(worst) ")"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' C1"
        display "FAIL C1: `r(why)' worst reldif " %8.2e r(worst)
    }
}
else {
    local ++skip_count
    display "SKIP C1: clubSandwich unavailable"
}

**# C2 - ragged clusters including singletons

* CR3 divides by (I - H_g). A singleton cluster with high leverage is where
* that inverse degrades first, so the ladder must either reproduce R exactly or
* declare CR3 missing -- it must not quietly return a finite wrong number.
local ++test_count
if `have_R' {
    clear
    set seed 40213
    quietly set obs 45
    quietly generate long id = _n
    quietly generate double u = rnormal(0, 1)
    quietly generate int nvis = 1 + floor(runiform()*6)
    quietly expand nvis
    bysort id: generate int k = _n
    quietly generate double x = rnormal(0, 1.4) + 0.5*u
    quietly generate double w = exp(rnormal(0, 1.6))
    quietly generate double y = 0.4 + 1.2*x + u + rnormal(0, 0.7)

    _cr_compare, yvar(y) xvar(x) wvar(w) idvar(id) tol(1e-10) label("C2 ragged clusters")
    if r(ok) == 1 {
        local ++pass_count
        display "PASS C2: ragged/singleton clusters match (worst reldif " %8.2e r(worst) ")"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' C2"
        display "FAIL C2: `r(why)' worst reldif " %8.2e r(worst)
    }
}
else {
    local ++skip_count
    display "SKIP C2: clubSandwich unavailable"
}

**# C3 - real FIPTIW weights, end to end

* The two cases above feed the ladder weights drawn from a lognormal. The
* deficit under study is a property of FIPTIW weights specifically -- a product
* of two estimated weight processes -- so at least one case must use the real
* thing, produced by iivw_weight rather than by rnormal().
local ++test_count
clear
set seed 20260806
quietly set obs 120
quietly generate long id = _n
quietly generate double K1 = rnormal(1, 1)
quietly generate byte   K2 = runiform() < 0.55
quietly generate double K3 = rnormal(0, 1)
quietly generate byte   A  = runiform() < invlogit(0.5 + 0.8*K1 + 0.05*K2 - K3)
quietly generate double Z  = cond(A == 1, rnormal(2, 1), rnormal(4, 2))
quietly generate double EZ = cond(A == 1, 2, 4)
quietly generate double phi = rnormal(0, 0.2)
quietly generate double eta = rgamma(100, 0.01)
quietly generate double C  = runiform(1, 2)
quietly generate double lam = eta * exp(0.6*A + 0.3*Z)
tempfile base
quietly save "`base'"
quietly expand 150
bysort id: generate int k = _n
quietly generate double gap = -ln(runiform()) / lam
bysort id (k): generate double t = sum(gap)
quietly drop if t > C
quietly generate double y = 3 + 1*A + 3*(Z - EZ) + 0.4*K1 + 0.05*K2 - 0.6*K3 + rnormal(phi, 0.1)
quietly generate byte entry = 0
quietly drop k gap
tempfile visits
quietly save "`visits'"
quietly use "`base'", clear
quietly generate double t = 0
quietly generate double y = .
quietly generate byte entry = 1
quietly append using "`visits'"
sort id t

quietly iivw_weight, id(id) time(t) treat(A) treat_cov(K1 K2 K3) visit_cov(Z) ///
    wtype(fiptiw) censor(C) baseline(entry) nolog
quietly iivw_fit y A, timespec(none) vce(fixed) nolog replace
local wvar "`e(iivw_weight_var)'"
local se_stata = _se[A]
local b_stata  = _b[A]
tempvar esamp
quietly generate byte `esamp' = e(sample)

if `have_R' {
    _cr_compare, yvar(y) xvar(A) wvar(`wvar') idvar(id) tol(1e-10) ///
        label("C3 real FIPTIW weights") ifexp(`esamp' == 1)
    local c3_cr0  = r(se_cr0)
    local c3_cr1  = r(se_cr1)
    local c3_cr1s = r(se_cr1s)
    if r(ok) == 1 {
        local ++pass_count
        display "PASS C3: FIPTIW-weighted ladder matches (worst reldif " %8.2e r(worst) ")"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' C3"
        display "FAIL C3: `r(why)' worst reldif " %8.2e r(worst)
    }
}
else {
    local ++skip_count
    display "SKIP C3: clubSandwich unavailable"
    quietly iivw_cr_ladder y A if `esamp' == 1, clustervar(id) weightvar(`wvar')
    local c3_cr0  = r(se_cr0)
    local c3_cr1  = r(se_cr1)
    local c3_cr1s = r(se_cr1s)
}

**# C4 - which rung is Stata's own vce(fixed)?

* probe_cr_ladder.do reports every rung as a ratio to the SE the package
* actually ships. That baseline had to be identified, not assumed: `glm
* [pw=], vce(cluster)' applies a small-sample multiplier and the question was
* which one.
*
* MEASURED, first run of this test, 2026-08-06: at n=713 rows in m=117 clusters
* with p=2, vce(fixed) gave 1.249776186 against CR0 1.244423801 and CR1S
* 1.250654764 -- matching NEITHER. The variance ratio is 1.0086209 against
* m/(m-1) = 117/116 = 1.0086207. So iivw_fit's analytic sandwich is the CR1
* rung. Reporting inflation factors against CR0 or CR1S would have quoted every
* one of them against a baseline the package does not use.
*
* Locking it here means a Stata version change that alters the multiplier shows
* up as a test failure rather than as a shifted inflation factor in a table.
local ++test_count
local d0  = reldif(`se_stata', `c3_cr0')
local d1  = reldif(`se_stata', `c3_cr1')
local d1s = reldif(`se_stata', `c3_cr1s')
display as text "C4: vce(fixed) SE = " %12.9f `se_stata'
display as text "    vs CR0  " %12.9f `c3_cr0'  "  reldif " %8.2e `d0'
display as text "    vs CR1  " %12.9f `c3_cr1'  "  reldif " %8.2e `d1'
display as text "    vs CR1S " %12.9f `c3_cr1s' "  reldif " %8.2e `d1s'
if `d1' < 1e-8 {
    local ++pass_count
    display "PASS C4: iivw_fit vce(fixed) is the CR1 rung (m/(m-1))"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' C4"
    display "FAIL C4: vce(fixed) is no longer the CR1 rung. Whichever rung it is"
    display "         now, probe_cr_ladder.do's baseline column is wrong until"
    display "         this is re-identified."
}

**# C5 - the sort contract

* The Mata code walks clusters as contiguous row blocks. If the wrapper's sort
* were removed, an id-shuffled dataset would be silently split into many
* one-row "clusters" and every SE would come back too small at rc 0. This is
* the test that fails when that happens.
local ++test_count
quietly iivw_cr_ladder y A if `esamp' == 1, clustervar(id) weightvar(`wvar')
local sorted_cr0 = r(se_cr0)
local sorted_cr2 = r(se_cr2)
local sorted_m   = r(nclust)

set seed 5150
quietly generate double _shuf = runiform()
sort _shuf
quietly iivw_cr_ladder y A if `esamp' == 1, clustervar(id) weightvar(`wvar')
local shuf_cr0 = r(se_cr0)
local shuf_cr2 = r(se_cr2)
local shuf_m   = r(nclust)
quietly drop _shuf

display as text "C5: clusters sorted=`sorted_m' shuffled=`shuf_m'"
display as text "    CR0 " %12.9f `sorted_cr0' " vs " %12.9f `shuf_cr0'
display as text "    CR2 " %12.9f `sorted_cr2' " vs " %12.9f `shuf_cr2'
if `sorted_m' == `shuf_m' & reldif(`sorted_cr0', `shuf_cr0') < 1e-10 ///
    & reldif(`sorted_cr2', `shuf_cr2') < 1e-10 {
    local ++pass_count
    display "PASS C5: row order does not change the ladder"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' C5"
    display "FAIL C5: the ladder depends on row order"
}

**# SUMMARY

iivw_qa_summary, name(test_iivw_cr_ladder) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed_tests'")
