* test_finegray_state_surfaces.do
* Session fingerprint, lifecycle, surface parity and hostile inputs for the
* four public commands (DOTHIS 2026-09-28 Part 3, step 7).
* budget: 30
*
* Cells (each can fail; the historical defect each one would have caught is
* named where there is one):
*   fingerprint  finegray, finegray_cif, finegray_predict, finegray_phtest,
*                each on a success and an early-error path, with caller
*                matrices planted under the seventeen _finegray_* names the
*                fit's cleanup owns, a foreign active e() (regress) and
*                matastrict off before a cold engine load (F07, F08)
*   lifecycle    fit A -> fit B (different design, support and baseline
*                strata) -> restore A -> every postestimation command
*                reproduces its first output; unstratified and
*                bstrata() x tvc() fits
*   parity       finegray_cif: the CIF at a non-decimal event time is the
*                same in r(table), the graph serset (event row and terminal
*                plateau) and the saving() dataset (F04); a grid ending just
*                before the final jump ends there in every sink (F05);
*                unrequested limits are withheld in every sink.
*                finegray: e(N) and the SHR in e(b) equal the console.
*                finegray_phtest: r(phtest) equals the console.
*   hostile      qa_hostile_times fixtures through finegray, finegray_cif,
*                finegray_predict (row CIF at the exact time) and
*                finegray_phtest; qa_shift_invariance of finegray's SE and
*                ll under x + 1000; the qa_hostile_strings corpus through
*                finegray_cif saving() (refuse-or-exact: a documented
*                rejected character gives r(198), anything else writes that
*                literal file)
*
* Run from finegray/qa:  stata-mp -b do test_finegray_state_surfaces.do

clear all
set more off
set varabbrev off
version 16.0

local qa_dir "`c(pwd)'"
capture log close _all
log using "`qa_dir'/test_finegray_state_surfaces.log", replace text name(_fgss)
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_lifecycle.do"
do "`qa_dir'/_qa_parity.do"
do "`qa_dir'/_qa_hostile.do"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""

capture program drop _fgs_result
program define _fgs_result, rclass
    args rc label
    if `rc' == 0 {
        display as result "  PASS: `label'"
        return scalar pass = 1
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        return scalar pass = 0
    }
end

* 300 subjects, continuous times, two baseline strata with events in both.
capture program drop _fgs_data
program define _fgs_data
    version 16.0
    clear
    set seed 20260928
    quietly set obs 300
    gen long id = _n
    gen long clinic = ceil(id/10)
    gen double x = rnormal()
    gen byte z = runiform() < .5
    gen byte bs = 1 + (runiform() < .5)
    gen double t1 = rexponential(1)*exp(-(.5*x - .3*z))
    gen double t2 = rexponential(1.5)
    gen double cc = rexponential(2.5)
    gen double t = min(t1, t2, cc)
    gen byte status = cond(t == t1, 1, cond(t == t2, 2, 0))
    gen double h = .5
    quietly stset t, failure(status==1 2) id(id)
end

* The seventeen names finegray's cleanup owns, planted with distinct content
* and stripes, plus a user scalar; a careless cleanup drops or rewrites them.
local fgmats _finegray_b _finegray_V _finegray_ll _finegray_ll_0 ///
    _finegray_chi2 _finegray_df_m _finegray_conv _finegray_rank ///
    _finegray_nclust _finegray_basehaz _finegray_kbstrata ///
    _finegray_nwstrata _finegray_minprob _finegray_maxwt ///
    _finegray_nprobwarn _finegray_nwtwarn _finegray_nprehole
global FGS_MATS `fgmats'
capture program drop _fgs_plant
program define _fgs_plant
    version 16.0
    local k = 0
    foreach m of global FGS_MATS {
        local ++k
        matrix `m' = (`k', `k' + .5 \ -`k', 1/`k')
        matrix rownames `m' = r`k'a eq`k':r`k'b
        matrix colnames `m' = c`k'a c`k'b
    }
    scalar _finegray_user = 42
    * cold engine load from matastrict off (F08): dropping finegray's Mata
    * functions removes its load sentinel _finegray_mata_ok(), so the next
    * command reloads the engine (mata clear would also drop qa-lib's code)
    capture mata: mata drop _finegray*()
    mata: mata set matastrict off
end

* Every global's name and value, and the names whose value changed outside
* the two families finegray legitimately touches (S_E_* estimation globals,
* its own finegray_bh_ctr counter).
capture mata: mata drop _fgs_globals() _fgs_gdiff()
mata:
string matrix _fgs_globals()
{
    string colvector n
    string matrix G
    real scalar i
    n = st_dir("global", "macro", "*")
    G = J(rows(n), 2, "")
    for (i = 1; i <= rows(n); i++) G[i, .] = (n[i], st_global(n[i]))
    return(G)
}
string scalar _fgs_gdiff(string matrix A, string matrix B)
{
    string scalar out, nm
    real scalar i, j, hit
    out = ""
    for (i = 1; i <= rows(A); i++) {
        nm = A[i, 1]
        if (substr(nm, 1, 4) == "S_E_" | nm == "finegray_bh_ctr") continue
        hit = 0
        for (j = 1; j <= rows(B); j++) if (B[j, 1] == nm) hit = (B[j, 2] == A[i, 2]) + 1
        if (hit != 2) out = out + " " + nm
    }
    for (j = 1; j <= rows(B); j++) {
        nm = B[j, 1]
        if (substr(nm, 1, 4) == "S_E_" | nm == "finegray_bh_ctr") continue
        if (!anyof(A[., 1], nm)) out = out + " +" + nm
    }
    return(out)
}
end

**# Fingerprint sweep

**## FS-1a finegray success: e() replaced, nothing else (F07 success path, F08)
local ++test_count
capture noisily {
    _fgs_data
    quietly regress t x
    _fgs_plant
    qa_state_snapshot, tag(fg_ok) charns(_finegray_)
    mata: _fgs_gl = _fgs_globals()
    finegray x z, compete(status) cause(1) nolog
    * eclass: e() is the documented change; _dta[_finegray_*] is the package's
    * own namespace (charns). Globals are allowed here only so the exact set
    * can be checked below: the S_E_* estimation globals that any ereturn post
    * clears, and the package's baseline-cache counter finegray_bh_ctr.
    qa_state_compare, tag(fg_ok) allow(e global)
    mata: st_local("gdiff", _fgs_gdiff(_fgs_gl, _fgs_globals()))
    assert `"`gdiff'"' == ""
    assert "`e(cmd)'" == "finegray"
}
_fgs_result `=_rc' "FS-1a finegray success leaves caller state intact"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' FS-1a"

**## FS-1b finegray syntax error (compete() missing) touches nothing (F07)
local ++test_count
capture noisily {
    _fgs_data
    quietly regress t x
    _fgs_plant
    qa_state_snapshot, tag(fg_bad) predict(xb)
    capture finegray x z, cause(1) nolog
    assert _rc == 198
    qa_state_compare, tag(fg_bad)
}
_fgs_result `=_rc' "FS-1b finegray r(198) leaves caller matrices and foreign e() intact"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' FS-1b"

**## FS-2 finegray_cif: success (r() only) and error
local ++test_count
capture noisily {
    _fgs_data
    quietly finegray x z, compete(status) cause(1) nolog
    _fgs_plant
    qa_state_snapshot, tag(cif_ok)
    finegray_cif, at(x=1 z=1) attime(.5) ci nograph
    * rclass: r() is the documented change
    qa_state_compare, tag(cif_ok) allow(r)
    assert rowsof(r(table)) == 1

    _fgs_plant
    qa_state_snapshot, tag(cif_bad)
    capture finegray_cif, at(nosuchvar=1) nograph
    assert _rc != 0
    qa_state_compare, tag(cif_bad)
}
_fgs_result `=_rc' "FS-2 finegray_cif leaves caller state intact (success + error)"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' FS-2"

**## FS-3 finegray_predict: success (one new variable) and error
local ++test_count
capture noisily {
    _fgs_data
    quietly finegray x z, compete(status) cause(1) nolog
    _fgs_plant
    qa_state_snapshot, tag(pr_ok)
    finegray_predict double p1, cif timevar(h)
    confirm variable p1
    quietly count if missing(p1)
    assert r(N) == 0
    drop p1
    * the generated variable is dropped again, so the data must be as found
    qa_state_compare, tag(pr_ok)

    _fgs_plant
    qa_state_snapshot, tag(pr_bad)
    capture finegray_predict double p2, cif xb
    assert _rc == 198
    capture confirm variable p2
    assert _rc == 111
    qa_state_compare, tag(pr_bad)
}
_fgs_result `=_rc' "FS-3 finegray_predict leaves caller state intact (success + r(198))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' FS-3"

**## FS-4 finegray_phtest: success (r() only) and error
local ++test_count
capture noisily {
    _fgs_data
    quietly finegray x z, compete(status) cause(1) nolog
    _fgs_plant
    qa_state_snapshot, tag(ph_ok)
    finegray_phtest
    qa_state_compare, tag(ph_ok) allow(r)
    assert rowsof(r(phtest)) == 2

    _fgs_plant
    qa_state_snapshot, tag(ph_bad)
    capture finegray_phtest, time(nosuchtime)
    assert _rc == 198
    qa_state_compare, tag(ph_bad)
}
_fgs_result `=_rc' "FS-4 finegray_phtest leaves caller state intact (success + r(198))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' FS-4"

**# Lifecycle

* Fit A as the lifecycle sees it: fit, then a throwaway fit and a restore, so
* A's baseline is always rebuilt rather than read from the fit-time cache.
* The cached and rebuilt baselines differ in the last bit (reldif <= 3.1e-16
* on this fixture, measured 2026-09-28); that is not stale state, and the
* exact comparison below would otherwise report it. The grid's restore
* column holds the rebuilt path to the independent oracle at 1e-10.
capture program drop _fgs_fita
program define _fgs_fita
    version 16.0
    finegray `0'
    tempname a
    estimates store `a'
    quietly finegray z, compete(status) cause(1) nolog
    estimates restore `a'
    estimates drop `a'
end

**## LC-1 unstratified A, stratified subsample B, restore A
local ++test_count
capture noisily {
    _fgs_data
    qa_lifecycle, fita(_fgs_fita x z, compete(status) cause(1) nolog) ///
        fitb(finegray x if clinic > 10, compete(status) cause(1) nolog bstrata(bs)) ///
        post(finegray_predict double lc1, cif timevar(h); finegray_predict double lc2, xb; finegray_cif, at(x=1 z=1) attime(.5) ci nograph; finegray_phtest)
    assert "`e(cmd)'" == "finegray" & "`e(bstrata)'" == ""
}
_fgs_result `=_rc' "LC-1 restored unstratified fit: predict, finegray_cif, finegray_phtest unchanged"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' LC-1"

**## LC-2 bstrata() x tvc() A (cached per-stratum baseline), plain B, restore A
local ++test_count
capture noisily {
    _fgs_data
    qa_lifecycle, fita(_fgs_fita x z, compete(status) cause(1) nolog bstrata(bs) tvc(x) tsplit(.5)) ///
        fitb(finegray z, compete(status) cause(1) nolog) ///
        post(finegray_predict double lc3, cif timevar(h); finegray_predict double lc4, basecshazard; finegray_cif, at(x=1 z=1) bstratum(2) nograph)
    assert "`e(bstrata)'" == "bs" & "`e(tvc)'" == "x"
}
_fgs_result `=_rc' "LC-2 restored bstrata() x tvc() fit: row CIF, baseline, profile CIF unchanged"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' LC-2"

**# Surface parity and hostile times

* F01/F04 fixture: 200 balanced subjects, 100 cause events at a time a
* decimal macro rounds DOWN, 100 competing events at 1; b = 0 and one
* Breslow jump of 100/200, so CIF(t >= tev) = 1 - exp(-.5).
capture program drop _fgs_jump
program define _fgs_jump
    version 16.0
    args tev tcomp
    clear
    quietly set obs 200
    gen long id = _n
    gen byte x = mod(_n, 2)
    gen double t = cond(_n <= 100, `tev', `tcomp')
    gen byte status = cond(_n <= 100, 1, 2)
    quietly stset t, failure(status==1 2) id(id)
end

* The serset holding the CIF curve: r(k) and its row count r(n).
capture program drop _fgs_serset
program define _fgs_serset, rclass
    version 16.0
    local k = .
    local n = .
    forvalues j = 0/30 {
        capture serset set `j'
        if _rc continue
        preserve
        serset use, clear
        capture confirm numeric variable time cif
        if !_rc {
            local k = `j'
            local n = _N
        }
        restore
    }
    assert `k' < .
    return scalar k = `k'
    return scalar n = `n'
end

**## SP-1 (F01/F04) exact event time: r(table), serset event and plateau, saving()
local ++test_count
capture noisily {
    qa_hostile_times
    local down "`r(down)'"
    _fgs_jump `down' 1
    quietly finegray x, compete(status) cause(1) nolog
    capture graph drop _all
    capture serset clear
    local sv "`c(tmpdir)'/fgs_sp1.dta"
    finegray_cif, at(x=0) timepoints(`down') name(fgs_g1, replace) ///
        saving(`"`sv'"', replace)
    assert el(r(table), 1, 1) == `down'
    matrix fgs_T = r(table)
    _fgs_serset
    local k = r(k)
    local n = r(n)
    * rows: (0,0), the event, the plateau to follow-up end
    assert `n' == 3
    capture frame drop fgs_sv
    frame create fgs_sv
    frame fgs_sv: quietly use `"`sv'"'
    qa_surface_parity, expect(1 - exp(-.5)) name(CIF at the down-rounding event) ///
        result(el(fgs_T,1,2)) serset(`k' cif 2) frame(fgs_sv cif 1)
    qa_surface_parity, expect(1 - exp(-.5)) name(terminal plateau) serset(`k' cif 3)
    * no ci requested: limits withheld in every sink
    qa_surface_parity, expect(withheld) name(unrequested lower limit) ///
        result(el(fgs_T,1,4)) frame(fgs_sv lci 1)
    frame drop fgs_sv
    graph drop fgs_g1
    erase `"`sv'"'
    * finegray_predict at the same exact time, row by row
    gen double hh = `down'
    finegray_predict double pc, cif timevar(hh)
    quietly count if missing(pc) | reldif(pc, 1 - exp(-.5)) > 1e-12
    assert r(N) == 0
}
_fgs_result `=_rc' "SP-1 F04: CIF at a non-decimal event time agrees in r(table), serset (event + plateau), saving(), predict"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-1"

**## SP-2 (F05) grid ending 5e-13 before the final jump ends there in every sink
local ++test_count
capture noisily {
    qa_hostile_times
    local jump "`r(jump)'"
    local before "`r(before)'"
    _fgs_jump `jump' 2
    quietly finegray x, compete(status) cause(1) nolog
    capture graph drop _all
    capture serset clear
    finegray_cif, at(x=0) timepoints(`before') name(fgs_g2, replace)
    matrix fgs_T = r(table)
    _fgs_serset
    local k = r(k)
    local n = r(n)
    * the curve's last point is the requested endpoint, not follow-up end
    qa_surface_parity, expect(`before') name(curve end time) ///
        result(el(fgs_T,1,1)) serset(`k' time `n')
    qa_surface_parity, expect(0) name(CIF before the jump) ///
        result(el(fgs_T,1,2)) serset(`k' cif `n')
    graph drop fgs_g2
    * control: the default grid reaches the jump and its plateau
    finegray_cif, at(x=0) nograph
    assert el(r(table), 1, 1) == `jump'
    qa_assert_equal el(r(table),1,2) 1-exp(-.5), tol(1e-12) ///
        property(default grid CIF at the jump)
}
_fgs_result `=_rc' "SP-2 F05: a grid ending before the final jump ends there in r(table) and the serset"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-2"

**## SP-3 finegray: e(N) and the SHR on the console equal e()
local ++test_count
capture noisily {
    _fgs_data
    tempfile plog
    log using `"`plog'"', text replace name(_fgspar)
    finegray x z, compete(status) cause(1) nolog
    log close _fgspar
    qa_surface_parity, expect(300) name(subjects) result(e(N)) ///
        log(`"`plog'"') logregex("No\. of subjects += +([0-9,]+)")
    qa_surface_parity, expect(exp(_b[x])) name(SHR of x) ///
        log(`"`plog'"') logregex("^ +x [|] +([0-9.]+)")
}
_fgs_result `=_rc' "SP-3 finegray console and e() agree (N, SHR)"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-3"

**## SP-4 finegray_phtest: r(phtest) equals the console; hostile-time refusal
local ++test_count
capture noisily {
    _fgs_data
    quietly finegray x z, compete(status) cause(1) nolog
    tempfile plog
    log using `"`plog'"', text replace name(_fgspar)
    finegray_phtest
    tempname P
    matrix `P' = r(phtest)
    log close _fgspar
    scalar fgs_want = `P'[1, 1]
    qa_surface_parity, expect(scalar(fgs_want)) name(correlation of x) ///
        log(`"`plog'"') logregex("^ +x [|] +(-?[0-9.]+)")
    quietly count if status == 1
    qa_assert_equal `P'[1, 2] r(N), property(phtest event count = cause events)
    * every cause event at one non-decimal time: the rank correlation is
    * undefined and must be refused, not reported
    qa_hostile_times
    _fgs_jump `r(down)' 1
    quietly finegray x, compete(status) cause(1) nolog
    capture finegray_phtest
    assert _rc == 459
    scalar drop fgs_want
}
_fgs_result `=_rc' "SP-4 finegray_phtest console = r(phtest); single-time events refused"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-4"

**## HF-1 finegray: additive covariate origin leaves SE and ll unchanged (F09)
local ++test_count
capture noisily {
    _fgs_data
    qa_shift_invariance x, command(finegray x z, compete(status) cause(1) nolog) ///
        returns(_se[x] _se[z] _b[z] e(ll)) shift(1000) tol(1e-8)
}
_fgs_result `=_rc' "HF-1 finegray SE, b[z], ll invariant to x + 1000"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' HF-1"

**## HS-1 finegray_cif saving(): hostile file names are refused or written exactly
capture program drop _fgs_hs
program define _fgs_hs
    version 16.0
    args g
    mata: st_local("s", st_global("`g'"))
    global FGS_HS_RES ""
    local f `"`c(tmpdir)'/fgs_`macval(s)'.dta"'
    capture erase `"`macval(f)'"'
    capture finegray_cif, at(x=0) attime(.5) nograph saving(`"`macval(f)'"', replace)
    local rc = _rc
    * documented grammar: shell metacharacters and quote characters are
    * rejected (finegray_cif.sthlp saving()); a comma ends the filename
    mata: st_local("forbid", strofreal(sum(strpos(st_local("s"), ///
        (";", "|", "&", "<", ">", char(36), char(96), char(34), char(39), ","))) > 0))
    if `rc' == 198 & `forbid' {
        mata: st_global("FGS_HS_RES", st_local("s"))
        exit
    }
    if `rc' exit `rc'
    mata: st_local("there", strofreal(fileexists(st_local("f"))))
    assert `there'
    preserve
    quietly use `"`macval(f)'"', clear
    confirm numeric variable time cif
    restore
    capture erase `"`macval(f)'"'
    mata: st_global("FGS_HS_RES", st_local("s"))
end
* LEDGER (found 2026-09-28, fixed 2026-09-29): saving() re-expanded the
* filename as macro text before its character check, so a name holding an
* unbalanced backtick exited r(199) instead of the documented r(198) (corpus
* QA_HS_TICK, QA_HS_DOLLAR) and a literal $NAME wrote a DIFFERENT file at
* rc 0 (HS-2).  The name is now read and checked in Mata.  The ledger is
* empty: every corpus string must be refused (documented) or written exactly.
local hs_open ""
local ++test_count
capture noisily {
    _fgs_data
    quietly finegray x z, compete(status) cause(1) nolog
    capture noisily qa_hostile_strings, check(_fgs_hs) result(FGS_HS_RES)
    local hsrc = _rc
    * which corpus strings fail the refuse-or-exact contract
    local hsbad ""
    foreach g in QA_HS_TICKPAIR QA_HS_TICK QA_HS_DOLLAR QA_HS_APOS QA_HS_DQ ///
        QA_HS_BSLASH QA_HS_COMMA QA_HS_LEAD QA_HS_UNICODE {
        capture _fgs_hs `g'
        local ok = 0
        if !_rc mata: st_local("ok", strofreal(st_global("`g'") == st_global("FGS_HS_RES")))
        if !`ok' local hsbad "`hsbad' `g'"
    }
    local hsbad : list retokenize hsbad
    display as text "HS-1 failing corpus strings: [`hsbad'] recorded open: [`hs_open']"
    assert "`hsbad'" == "`hs_open'"
    assert `hsrc' == cond("`hs_open'" == "", 0, 9)
}
_fgs_result `=_rc' "HS-1 finegray_cif saving(): corpus refused (documented) or written literally"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' HS-1"

**## HS-2 a literal $NAME in saving() must not be expanded
* Through 1.3.7: rc 0, the literal file absent and the expanded name written.
* Contract: r(198) (documented rejection of "$") or the literal file.
local hs2_open ""
local ++test_count
capture noisily {
    _fgs_data
    quietly finegray x z, compete(status) cause(1) nolog
    global FGS_HS_NAME "EXPANDED"
    local d "`c(tmpdir)'"
    mata: st_local("lit", st_local("d") + "/fgs_P " + char(36) + "FGS_HS_NAME.dta")
    local exp "`d'/fgs_P EXPANDED.dta"
    capture erase `"`macval(lit)'"'
    capture erase `"`exp'"'
    capture finegray_cif, at(x=0 z=0) attime(.5) nograph saving(`"`macval(lit)'"', replace)
    local rc = _rc
    mata: st_local("haslit", strofreal(fileexists(st_local("lit"))))
    mata: st_local("hasexp", strofreal(fileexists(st_local("exp"))))
    local sig = cond(`rc' == 198 & !`hasexp' & !`haslit', "refused", ///
        cond(`rc' == 0 & `haslit' & !`hasexp', "literal", ///
        cond(`rc' == 0 & `hasexp' & !`haslit', "rc0 expanded", "rc`rc' other")))
    display as text "HS-2 outcome: [`sig'] recorded open: [`hs2_open']"
    capture erase `"`macval(lit)'"'
    capture erase `"`exp'"'
    macro drop FGS_HS_NAME
    if "`hs2_open'" == "" assert inlist("`sig'", "refused", "literal")
    else assert "`sig'" == "`hs2_open'"
}
_fgs_result `=_rc' "HS-2 finegray_cif saving() with a literal dollar-name: refused or literal"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' HS-2"

**# Summary
capture macro drop FGS_MATS FGS_HS_RES
capture matrix drop fgs_T
local fail_count = `test_count' - `pass_count'
if `fail_count' display as error "failed:`failed'"
display as text _newline ///
    "RESULT: test_finegray_state_surfaces tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _fgss
if `fail_count' > 0 exit 1
exit 0
