* test_tabtools_surfaces.do
* Surface parity, hostile inputs, lifecycle and identity twins for the tabtools
* commands (DOTHIS 2026-09-28 Part 3.1/3.3/3.4, step 7).
* budget: 45
*
* Cells (each can fail; the audit finding each would have caught is named):
*   parity    one published value per command, identical in r(), the frame,
*             CSV, the workbook and the console, against an independent
*             oracle (native correlate, tabulate, teffects e(b), regress,
*             sts/stci, the rate design, the source workbook):
*             corrtab, crosstab, desctab (F02: the test on the displayed
*             Missing coding), effecttab, puttab, regtab, stacktab,
*             stratetab, survtab, tabtools
*   hostile   qa_hostile_missing (desctab F02, crosstab), qa_hostile_codes
*             (desctab F04), qa_shift_invariance (desctab F05 SD, corrtab),
*             qa_hostile_times (survtab F01 RMST SE)
*   strings   the qa_hostile_strings corpus through title() of all ten
*             commands with a text sink (read back from workbook cell A1),
*             stacktab columnmerge() headers (F09) and puttab sheet() (F10)
*   lifecycle regtab after fit A -> fit B -> restore A (qa_lifecycle)
*   twin      qa_counterfeit_twin kind(case): regtab frames of y and Y are
*             not composed as one model by comptab (F06)
* Open ledger: Muse 2026-09-27 I1 (crosstab, trend missing: the trend test
* drops the displayed Missing column) is recorded, not fixed; its block must
* fail as recorded.
*
* Run from tabtools/qa:  stata-mp -b do test_tabtools_surfaces.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _ttsf
log using "test_tabtools_surfaces.log", replace text name(_ttsf)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear
do "`qa_dir'/_qa_parity.do"
do "`qa_dir'/_qa_hostile.do"
do "`qa_dir'/_qa_lifecycle.do"

local test_count = 0
local pass_count = 0
local failed ""
tempfile scratch
global TTSF_DIR "`scratch'_d"
capture mkdir "$TTSF_DIR"

capture program drop _ttsf_result
program define _ttsf_result, rclass
    args rc label
    if `rc' == 0 display as result "  PASS: `label'"
    else display as error "  FAIL: `label' (rc=`rc')"
    return scalar pass = (`rc' == 0)
end

**# Fixtures

* Rate files, a stacktab source workbook, and two regtab frames.
capture program drop _ttsf_setup
program define _ttsf_setup
    version 17.0
    forvalues k = 1/2 {
        clear
        quietly set obs 2
        gen exposure = _n - 1
        gen double _D = cond(_n == 1, 10, 20) + `k'
        gen double _Y = cond(_n == 1, 1000, 1100)
        gen double _Rate = _D / _Y
        gen double _Lower = _Rate * .8
        gen double _Upper = _Rate * 1.2
        label variable _Lower "Lower 95% confidence limit"
        label variable _Upper "Upper 95% confidence limit"
        label define _ttsf_e 0 "None" 1 "Current", replace
        label values exposure _ttsf_e
        quietly save "$TTSF_DIR/rate`k'.dta", replace
    }
    matrix MA = (1.23, 1.05, 1.44)
    matrix colnames MA = HR LL UL
    quietly puttab using "$TTSF_DIR/parts.xlsx", sheet("A") matrix(MA) title("Model A")
    quietly puttab using "$TTSF_DIR/parts.xlsx", sheet("B") matrix(MA) title("Model B")
    matrix drop MA
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    quietly regtab, frame(ttsf_m1, replace) noint
    collect clear
    quietly collect: regress price mpg weight
    quietly regtab, frame(ttsf_m2, replace) noint
end
_ttsf_setup

* Run one command with title() taken from global TTSF_TITLE (never through a
* decimal or macro-expanding path at the call site), writing workbook `x'.
* Leaves the sheet name in global TTSF_SHEET.
capture program drop _ttsf_run
program define _ttsf_run
    version 17.0
    args cmd x
    mata: st_local("tl", st_global("TTSF_TITLE"))
    capture erase "`x'"
    global TTSF_SHEET ""
    if "`cmd'" == "corrtab" {
        sysuse auto, clear
        corrtab price mpg weight, title(`"`macval(tl)'"') xlsx("`x'")
    }
    if "`cmd'" == "crosstab" {
        sysuse auto, clear
        gen byte expensive = price > 6000
        crosstab expensive foreign, title(`"`macval(tl)'"') xlsx("`x'")
    }
    if "`cmd'" == "desctab" {
        sysuse auto, clear
        desctab, by(foreign) vars(mpg contn \ rep78 cat) title(`"`macval(tl)'"') xlsx("`x'")
    }
    if "`cmd'" == "survtab" {
        sysuse auto, clear
        set seed 1
        gen double time = 1 + 20*runiform()
        gen byte died = runiform() < .6
        quietly stset time, failure(died)
        survtab, times(5 10) by(foreign) title(`"`macval(tl)'"') xlsx("`x'")
    }
    if "`cmd'" == "regtab" {
        sysuse auto, clear
        collect clear
        quietly collect: regress price mpg weight
        regtab, noint title(`"`macval(tl)'"') xlsx("`x'")
    }
    if "`cmd'" == "effecttab" {
        clear
        set seed 83920
        quietly set obs 200
        gen double x = rnormal()
        gen byte t = mod(_n, 2)
        gen double y = 2*x + 5*t + rnormal()
        collect clear
        quietly collect: teffects ra (y x) (t)
        effecttab, title(`"`macval(tl)'"') xlsx("`x'")
    }
    if "`cmd'" == "comptab" {
        comptab ttsf_m1 ttsf_m2, rows(1 \ 1) title(`"`macval(tl)'"') xlsx("`x'")
    }
    if "`cmd'" == "stratetab" {
        stratetab, using("$TTSF_DIR/rate1" "$TTSF_DIR/rate2") outcomes(2) ///
            title(`"`macval(tl)'"') xlsx("`x'")
    }
    if "`cmd'" == "puttab" {
        sysuse auto, clear
        puttab make price mpg in 1/5 using "`x'", sheet("S") title(`"`macval(tl)'"')
    }
    if "`cmd'" == "stacktab" {
        copy "$TTSF_DIR/parts.xlsx" "`x'", replace
        stacktab using "`x'", sheet("T2") blocks(sheet(A) \ sheet(B)) title(`"`macval(tl)'"')
    }
    global TTSF_SHEET "`r(sheet)'"
    if "`cmd'" == "puttab" global TTSF_SHEET "S"
    if "`cmd'" == "stacktab" global TTSF_SHEET "T2"
end

* Read one workbook cell as text into global TTSF_RES (exact bytes).
capture program drop _ttsf_cell
program define _ttsf_cell
    version 17.0
    args book sheet cell
    global TTSF_RES ""
    preserve
    quietly import excel using "`book'", sheet("`sheet'") cellrange(`cell':`cell') allstring clear
    mata: st_global("TTSF_RES", st_nobs() ? st_sdata(1, 1) : "")
    restore
end

**# Surface parity

**## SP-corrtab correlation: r(C), frame, CSV, workbook, console = native correlate
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly correlate price mpg
    scalar ttsf_want = r(rho)
    tempfile lg
    log using `"`lg'"', text replace name(_ttsfl)
    corrtab price mpg weight, frame(ttsf_f, replace) csv("$TTSF_DIR/c.csv") ///
        xlsx("$TTSF_DIR/c.xlsx")
    matrix ttsf_C = r(C)
    log close _ttsfl
    qa_surface_parity, expect(scalar(ttsf_want)) name(corr price mpg) ///
        result(el(ttsf_C,2,1)) frame(ttsf_f c2 4) csv("$TTSF_DIR/c.csv" 3 2) ///
        xlsx("$TTSF_DIR/c.xlsx" Correlation C4) ///
        log(`"`lg'"') logregex("Mileage \(mpg\) +(-[0-9.]+)")
    * hostile: a shifted origin leaves the correlation unchanged
    qa_shift_invariance price, command(corrtab price mpg) returns(el(r(C),2,1)) tol(1e-10)
}
_ttsf_result `=_rc' "SP-corrtab one correlation in r(), frame, CSV, workbook, console; shift-invariant"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-corrtab"

**## SP-crosstab the test on the displayed coding (missing codes shown separately)
local ++test_count
capture noisily {
    qa_hostile_missing, clear
    * small cells: the displayed table gets Fisher's exact test
    quietly tabulate group x, missing exact
    scalar ttsf_want = r(p_exact)
    tempfile lg
    log using `"`lg'"', text replace name(_ttsfl)
    crosstab group x, missing frame(ttsf_f, replace) xlsx("$TTSF_DIR/x.xlsx")
    scalar ttsf_got = r(p)
    local sh "`r(sheet)'"
    log close _ttsfl
    qa_surface_parity, expect(scalar(ttsf_want)) name(exact p on displayed codes) ///
        result(scalar(ttsf_got)) log(`"`lg'"') logregex("exact test: p = ([0-9.]+)")
}
_ttsf_result `=_rc' "SP-crosstab exact p in r() and console = native tabulate on the displayed missing codes"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-crosstab"

**## SP-desctab (F02) the test uses the displayed Missing coding, in every sink
local ++test_count
capture noisily {
    qa_hostile_missing, clear
    * displayed coding: every missing code in one Missing row
    gen double xd = cond(missing(x), ., x)
    quietly tabulate xd group, missing chi2
    scalar ttsf_want = r(p)
    tempfile lg
    log using `"`lg'"', text replace name(_ttsfl)
    * sheet() named explicitly: qa_surface_parity's xlsx() address splits on
    * blanks, so the default "Table 1" cannot be named there
    desctab, by(group) vars(x cat) missing test frame(ttsf_f, replace) ///
        csv("$TTSF_DIR/d.csv") xlsx("$TTSF_DIR/d.xlsx") sheet(T1)
    matrix ttsf_T = r(table)
    log close _ttsfl
    qa_surface_parity, expect(scalar(ttsf_want)) name(desctab p on displayed coding) ///
        result(el(ttsf_T,1,1)) frame(ttsf_f pvalue 3) csv("$TTSF_DIR/d.csv" 3 5) ///
        xlsx("$TTSF_DIR/d.xlsx" T1 F4) ///
        log(`"`lg'"') logregex("Chi-square +([0-9.]+)")
}
_ttsf_result `=_rc' "SP-desctab F02: p on the displayed Missing coding in r(), frame, CSV, workbook, console"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-desctab"

**## SP-effecttab ATE: r(table), frame, CSV, workbook = teffects e(b)
local ++test_count
capture noisily {
    clear
    set seed 83920
    quietly set obs 200
    gen double x = rnormal()
    gen byte t = mod(_n, 2)
    gen double y = 2*x + 5*t + rnormal()
    collect clear
    quietly collect: teffects ra (y x) (t)
    scalar ttsf_want = el(e(b), 1, 1)
    effecttab, frame(ttsf_f, replace) csv("$TTSF_DIR/e.csv") xlsx("$TTSF_DIR/e.xlsx")
    matrix ttsf_T = r(table)
    local sh "`r(sheet)'"
    qa_surface_parity, expect(scalar(ttsf_want)) name(ATE) ///
        result(el(ttsf_T,1,1)) frame(ttsf_f c1 4) csv("$TTSF_DIR/e.csv" 2 2) ///
        xlsx("$TTSF_DIR/e.xlsx" `sh' C4)
}
_ttsf_result `=_rc' "SP-effecttab ATE in r(table), frame, CSV, workbook = e(b)"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-effecttab"

**## SP-regtab coefficient: frame, CSV, workbook, console = regress _b
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    scalar ttsf_want = _b[mpg]
    tempfile lg
    log using `"`lg'"', text replace name(_ttsfl)
    regtab, noint frame(ttsf_f, replace) csv("$TTSF_DIR/r.csv") xlsx("$TTSF_DIR/r.xlsx")
    local sh "`r(sheet)'"
    log close _ttsfl
    qa_surface_parity, expect(scalar(ttsf_want)) name(coef of mpg) ///
        frame(ttsf_f c1 4) csv("$TTSF_DIR/r.csv" 3 2) xlsx("$TTSF_DIR/r.xlsx" `sh' C4) ///
        log(`"`lg'"') logregex("Mileage \(mpg\) +(-[0-9.]+)")
}
_ttsf_result `=_rc' "SP-regtab coefficient in frame, CSV, workbook, console = regress"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-regtab"

**## SP-stratetab rate per 1,000 PY: frame, CSV, workbook = the rate file design
local ++test_count
capture noisily {
    clear
    stratetab, using("$TTSF_DIR/rate1" "$TTSF_DIR/rate2") outcomes(2) ///
        frame(ttsf_f, replace) csv("$TTSF_DIR/s.csv") xlsx("$TTSF_DIR/s.xlsx")
    local sh "`r(sheet)'"
    qa_surface_parity, expect(11/1000*1000) name(rate None outcome 1) ///
        frame(ttsf_f c4 5) csv("$TTSF_DIR/s.csv" 4 4) xlsx("$TTSF_DIR/s.xlsx" `sh' E5)
}
_ttsf_result `=_rc' "SP-stratetab rate in frame, CSV, workbook = design"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-stratetab"

**## SP-stacktab stacked estimate: frame, CSV, workbook = source workbook
local ++test_count
capture noisily {
    copy "$TTSF_DIR/parts.xlsx" "$TTSF_DIR/k.xlsx", replace
    stacktab using "$TTSF_DIR/k.xlsx", sheet("T9") blocks(sheet(A) \ sheet(B)) ///
        frame(ttsf_f, replace) csv("$TTSF_DIR/k.csv")
    qa_surface_parity, expect(1.23) name(HR block B) ///
        frame(ttsf_f _xcol3 6) csv("$TTSF_DIR/k.csv" 6 3) xlsx("$TTSF_DIR/k.xlsx" T9 C7)
}
_ttsf_result `=_rc' "SP-stacktab source value in frame, CSV, workbook"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-stacktab"

**## SP-puttab matrix cell: workbook and CSV = the matrix
local ++test_count
capture noisily {
    sysuse auto, clear
    matrix ttsf_M = (1.25, 2.5 \ 3.75, 4)
    matrix colnames ttsf_M = a b
    puttab using "$TTSF_DIR/p.xlsx", sheet("M") matrix(ttsf_M) csv("$TTSF_DIR/p.csv")
    qa_surface_parity, expect(3.75) name(matrix cell 2,1) ///
        csv("$TTSF_DIR/p.csv" 3 2) xlsx("$TTSF_DIR/p.xlsx" M C4)
}
_ttsf_result `=_rc' "SP-puttab matrix cell in workbook and CSV"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-puttab"

**## SP-survtab KM survival and RMST: r(), frame, workbook = native sts/stci
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 1
    gen double time = 1 + 20*runiform()
    gen byte died = runiform() < .6
    quietly stset time, failure(died)
    quietly sts generate ttsf_s = s if foreign == 0
    quietly summarize ttsf_s if foreign == 0 & _t <= 5, meanonly
    scalar ttsf_want = r(min)
    survtab, times(5 10) by(foreign) frame(ttsf_f, replace) xlsx("$TTSF_DIR/v.xlsx")
    local sh "`r(sheet)'"
    qa_surface_parity, expect(scalar(ttsf_want)) name(S(5) Domestic) textscale(0.01) ///
        frame(ttsf_f c2 4) xlsx("$TTSF_DIR/v.xlsx" `sh' C4)
}
_ttsf_result `=_rc' "SP-survtab S(5) in frame and workbook = sts"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-survtab"

**## HF-survtab (F01) RMST SE at a non-decimal event time = stci; r() = frame
local ++test_count
capture noisily {
    qa_hostile_times
    local up "`r(up)'"
    clear
    quietly set obs 4
    gen double time = 1
    quietly replace time = `up' in 1
    gen byte fail = _n == 1
    quietly stset time, failure(fail)
    quietly stci, rmean
    scalar ttsf_m = r(rmean)
    scalar ttsf_se = r(se)
    survtab, times(1) rmst(1) frame(ttsf_f, replace)
    qa_assert_equal r(rmst_se_1) scalar(ttsf_se), tol(1e-8) ///
        property(RMST SE uses the exact event-time risk set)
    qa_surface_parity, expect(scalar(ttsf_m)) name(RMST) result(r(rmst_1))
}
_ttsf_result `=_rc' "HF-survtab F01: RMST and SE at a non-decimal event time = stci"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' HF-survtab"

**## SP-tabtools a setting in r(), the global and the console agree
local ++test_count
capture noisily {
    tabtools set digits 3
    tempfile lg
    log using `"`lg'"', text replace name(_ttsfl)
    tabtools get
    local dg "`r(digits)'"
    log close _ttsfl
    qa_surface_parity, expect(3) name(digits setting) result(real("`dg'")) ///
        log(`"`lg'"') logregex("Digits: +([0-9]+)")
    qa_assert_equal real("$TABTOOLS_DIGITS") 3, property(global holds the setting)
    tabtools set clear
}
_ttsf_result `=_rc' "SP-tabtools setting in r(), global and console"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' SP-tabtools"

**# Hostile fixtures (desctab)

**## HF-desctab-codes (F04) group codes above c(maxlong), negative, 2 vs 20
local ++test_count
capture noisily {
    qa_hostile_codes, clear
    local ng = r(ngroups) - 1
    * the documented domain is non-negative integers: the -7 group is refused
    capture desctab, by(code) vars(y contn %12.3f)
    assert _rc == 498
    * the other four groups, two of them above c(maxlong), are all kept
    quietly drop if code < 0
    desctab, by(code) vars(y contn %12.3f) total(after) frame(ttsf_f, replace)
    * every group column plus the total: four headers N=3, one N=12
    frame ttsf_f {
        quietly ds
        local nN = 0
        local nT = 0
        foreach v in `r(varlist)' {
            capture confirm string variable `v'
            if _rc continue
            quietly count if ustrregexm(`v', "N=3([^0-9]|$)")
            local nN = `nN' + r(N)
            quietly count if ustrregexm(`v', "N=12([^0-9]|$)")
            local nT = `nT' + r(N)
        }
    }
    assert `nT' == 1
    assert `nN' == `ng'
}
_ttsf_result `=_rc' "HF-desctab F04: codes above c(maxlong) and 2/20 all shown (N=3 each, total 12); negative refused"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' HF-desctab-codes"

**## HF-desctab-shift (F05) the displayed SD is invariant to a shifted origin
capture program drop _ttsf_sd
program define _ttsf_sd, rclass
    version 17.0
    desctab, by(g) vars(x contn %20.6f) frame(ttsf_sd, replace)
    frame ttsf_sd: local cell = g_0[3]
    mata: st_local("sd", substr(st_local("cell"), strpos(st_local("cell"), uchar(177)) + 2, .))
    return scalar sd = real("`sd'")
end
local ++test_count
capture noisily {
    clear
    quietly set obs 8
    gen byte g = _n > 4
    gen double x = mod(_n, 4)/100
    quietly summarize x if g == 0
    scalar ttsf_sd0 = r(sd)
    _ttsf_sd
    qa_assert_equal r(sd) scalar(ttsf_sd0), tol(1e-4) property(displayed SD = summarize)
    qa_shift_invariance x, command(_ttsf_sd) returns(r(sd)) shift(1e8) tol(1e-4)
}
_ttsf_result `=_rc' "HF-desctab F05: displayed SD = summarize and invariant to x + 1e8"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' HF-desctab-shift"

**# Lifecycle and identity

**## LC-regtab restored fit A: regtab over the same collection reproduces
local ++test_count
capture noisily {
    sysuse auto, clear
    gen byte expensive = price > 6000
    collect clear
    qa_lifecycle, fita(collect: logit expensive mpg weight) ///
        fitb(regress price mpg if foreign == 1) ///
        post(regtab; regtab, frame(ttsf_lc, replace))
}
_ttsf_result `=_rc' "LC-regtab output after fit B and restore A is unchanged"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' LC-regtab"

**## TW-regtab (F06) case twins y/Y are different analyses to regtab and comptab
local ++test_count
capture noisily {
    qa_counterfeit_twin, kind(case) twin(a) clear
    local dva "`r(depvar)'"
    gen double x = mod(_n, 5)
    collect clear
    quietly collect: regress `dva' x
    regtab, frame(ttsf_tw_a, replace)
    qa_counterfeit_twin, kind(case) twin(b) clear
    local dvb "`r(depvar)'"
    gen double x = mod(_n, 5)
    collect clear
    quietly collect: regress `dvb' x
    regtab, frame(ttsf_tw_b, replace)
    frame ttsf_tw_a: local oa : char _dta[tabtools_outcome_id_1]
    frame ttsf_tw_b: local ob : char _dta[tabtools_outcome_id_1]
    assert "`oa'" == "`dva'" & "`ob'" == "`dvb'" & "`oa'" != "`ob'"
    capture comptab ttsf_tw_a ttsf_tw_b, rows(1 \ 1)
    assert _rc == 198
}
_ttsf_result `=_rc' "TW-regtab F06: y and Y keep distinct identities; comptab refuses to merge"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' TW-regtab"

**# Hostile strings

* title(): refuse nothing, preserve every byte (read back from A1)
capture program drop _ttsf_hs
program define _ttsf_hs
    version 17.0
    args g
    global TTSF_RES ""
    mata: st_global("TTSF_TITLE", st_global("`g'"))
    local x "$TTSF_DIR/hs_$TTSF_CMD.xlsx"
    quietly _ttsf_run $TTSF_CMD "`x'"
    _ttsf_cell "`x'" "$TTSF_SHEET" A1
end
foreach cmd in comptab corrtab crosstab desctab effecttab puttab regtab ///
    stacktab stratetab survtab {
    local ++test_count
    capture noisily {
        global TTSF_CMD `cmd'
        qa_hostile_strings, check(_ttsf_hs) result(TTSF_RES)
    }
    _ttsf_result `=_rc' "HS-`cmd' title(): every corpus string reaches the workbook byte for byte"
    local pass_count = `pass_count' + r(pass)
    if !r(pass) local failed "`failed' HS-`cmd'"
}

**## HS-stacktab-cm (F09) columnmerge() header text is literal
capture program drop _ttsf_cm
program define _ttsf_cm
    version 17.0
    args g
    global TTSF_RES ""
    mata: st_local("h", st_global("`g'"))
    * a quote inside the header cannot be carried by the quoted grammar;
    * such strings are out of scope for this option and pass unchanged
    mata: st_local("hasq", strofreal(strpos(st_local("h"), char(34)) > 0))
    if `hasq' {
        mata: st_global("TTSF_RES", st_global("`g'"))
        exit
    }
    mata: st_local("spec", "B+C as " + char(34) + st_local("h") + char(34))
    local x "$TTSF_DIR/cm.xlsx"
    copy "$TTSF_DIR/cmsrc.xlsx" "`x'", replace
    stacktab using "`x'", blocks(sheet(Src)) sheet("CM") columnmerge(`macval(spec)')
    _ttsf_cell "`x'" "CM" C2
end
local ++test_count
capture noisily {
    clear
    quietly set obs 3
    gen str10 A = cond(_n == 1, "Term", cond(_n == 2, "A", "B"))
    gen str10 B = cond(_n == 1, "Est", cond(_n == 2, "1.23", "2.10"))
    gen str14 C = cond(_n == 1, "CI", cond(_n == 2, "(0.50, 2.20)", "(1.00, 3.20)"))
    quietly export excel using "$TTSF_DIR/cmsrc.xlsx", sheet("Src") replace
    qa_hostile_strings, check(_ttsf_cm) result(TTSF_RES)
}
_ttsf_result `=_rc' "HS-stacktab-cm F09: columnmerge() headers preserved byte for byte"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' HS-stacktab-cm"

**## HS-puttab-sheet (F10) sheet() names reach the workbook exactly
* Excel itself forbids \ / ? * [ ] : in a sheet name, a leading or trailing
* apostrophe, and more than 31 characters; such a name is correctly refused
* with r(198). Any other name must be written and returned byte for byte.
capture program drop _ttsf_sh
program define _ttsf_sh
    version 17.0
    args g
    global TTSF_RES ""
    mata: st_local("sh", st_global("`g'"))
    local x "$TTSF_DIR/sh.xlsx"
    capture erase "`x'"
    sysuse auto, clear
    capture puttab make price in 1/3 using "`x'", sheet(`"`macval(sh)'"')
    local rc = _rc
    mata: s = st_local("sh"); ///
        st_local("xlbad", strofreal(ustrlen(s) > 31 | ustrregexm(s, "[\\/?*\[\]:]") | ///
        substr(s, 1, 1) == char(39) | substr(s, strlen(s), 1) == char(39)))
    if `rc' == 198 & `xlbad' {
        mata: st_global("TTSF_RES", st_local("sh"))
        exit
    }
    if `rc' exit `rc'
    mata: st_global("TTSF_RES", st_global("r(sheet)"))
    * the workbook really holds that sheet
    preserve
    quietly import excel using "`x'", sheet(`"`macval(sh)'"') allstring clear
    restore
end
* OPEN LEDGER (new finding, 2026-09-28, tabtools 2.1.15 on main): puttab
* sheet() still re-expands the name as macro text. The TICKPAIR name
* (a $global and a `lit' pair) is written as a different sheet at rc 0, and
* an unbalanced backtick exits r(132) (QA_HS_TICK, QA_HS_DOLLAR). The F10 fix
* covered the double quote only. The recorded failure set must match exactly.
local sh_open "QA_HS_TICKPAIR QA_HS_TICK QA_HS_DOLLAR"
local ++test_count
capture noisily {
    capture noisily qa_hostile_strings, check(_ttsf_sh) result(TTSF_RES)
    local hsrc = _rc
    local shbad ""
    foreach g in QA_HS_TICKPAIR QA_HS_TICK QA_HS_DOLLAR QA_HS_APOS QA_HS_DQ ///
        QA_HS_BSLASH QA_HS_COMMA QA_HS_LEAD QA_HS_UNICODE {
        capture _ttsf_sh `g'
        local ok = 0
        if !_rc mata: st_local("ok", strofreal(st_global("`g'") == st_global("TTSF_RES")))
        if !`ok' local shbad "`shbad' `g'"
    }
    local shbad : list retokenize shbad
    display as text "HS-puttab-sheet failing corpus strings: [`shbad'] recorded open: [`sh_open']"
    assert "`shbad'" == "`sh_open'"
    assert `hsrc' == cond("`sh_open'" == "", 0, 9)
}
_ttsf_result `=_rc' "HS-puttab-sheet F10: sheet() names written exactly or refused by Excel's rules; open set as recorded"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' HS-puttab-sheet"

**# Open ledger

**## OPEN Muse I1: crosstab, trend missing tests fewer rows than it displays
* Contract (either): the trend test's N equals the displayed table N, or
* trend with missing is refused like cochran. Recorded on 2.1.15: rc 0, the
* displayed N is 6 and the p for trend equals the complete-case p (N 5).
local i1_open "rc0 completecase"
local ++test_count
capture noisily {
    clear
    input byte(r c)
    1 1
    1 2
    2 1
    2 2
    2 .a
    1 1
    end
    quietly spearman r c
    scalar ttsf_pcc = r(p)
    capture crosstab r c, missing trend
    local rc = _rc
    local sig "rc`rc' other"
    if `rc' == 0 & r(N) == 6 & !missing(r(p_trend), ttsf_pcc) & reldif(r(p_trend), ttsf_pcc) < 1e-12 {
        local sig "rc0 completecase"
    }
    if `rc' == 198 local sig "refused"
    display as text "Muse I1 outcome: [`sig'] recorded open: [`i1_open']"
    if "`i1_open'" == "" assert "`sig'" != "rc0 completecase" & "`sig'" != "rc0 other"
    else assert "`sig'" == "`i1_open'"
}
_ttsf_result `=_rc' "OPEN Muse I1 crosstab trend + missing: outcome as recorded"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' OPEN-I1"

**# Summary
capture shell rm -rf "$TTSF_DIR"
foreach f in ttsf_f ttsf_sd ttsf_lc ttsf_m1 ttsf_m2 ttsf_tw_a ttsf_tw_b {
    capture frame drop `f'
}
capture scalar drop ttsf_want ttsf_got ttsf_m ttsf_se ttsf_sd0 ttsf_pcc
capture matrix drop ttsf_C ttsf_T ttsf_M
capture macro drop TTSF_DIR TTSF_TITLE TTSF_SHEET TTSF_RES TTSF_CMD
local fail_count = `test_count' - `pass_count'
if `fail_count' display as error "failed:`failed'"
display as text "RESULT: test_tabtools_surfaces tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _ttsf
if `fail_count' > 0 exit 1
exit 0
