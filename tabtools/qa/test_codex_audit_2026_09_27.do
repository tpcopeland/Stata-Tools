* test_codex_audit_2026_09_27.do - regressions for the 2026-09-27 Codex audit
* of tabtools 2.1.14 (Stata-Tools commit 1255176d).
* Written against 1255176d before any fix; every finding below failed there:
*   F01  survtab RMST risk sets compared _t0/_t with a decimal round-trip of
*        the event time, dropping the failing subject from its own risk set
*   F02  desctab missing: one displayed Missing row, but .a/.b kept distinct
*        in the chi-square/Fisher test
*   F03  effecttab full: same-named coefficients of separate equations
*        overwrote each other in r(table), frames and CSV
*   F04  desctab by(): a valid group code above c(maxlong) became missing
*   F05  desctab SD: raw-moment cancellation zeroed a finite SD
*   F06  regtab/comptab lowercased machine identities (y and Y merged)
*   F07  desctab replaced the caller's active estimates
*   F08  survtab: a failure in a missing-by row defeated the no-failure guard
*   F09  stacktab columnmerge() expanded header text as macros and split on a
*        quoted backslash
*   F10  puttab rejected a valid sheet name containing a double quote
*   F11  effecttab found cmd/cmdline metadata by their display labels
*   F12  regtab parsed every collected item (GEE working correlations) before
*        selecting the requested results; a small table took minutes
*   F13  stacktab style() accepted unknown and duplicate groups
* Oracles: native stci, rmean; native tabulate on the displayed coding;
* native summarize; each fit's own e(b)/e(V)/e(sample) and predict; the
* producer's raw variable names; openpyxl reads of every workbook cell,
* sheet name and column width (inline reader below); Mata comparisons of
* text built with char(), so no expected string passes through a macro.

clear all
set more off
set varabbrev off
version 17.0

capture log close _ca27
log using "test_codex_audit_2026_09_27.log", replace text name(_ca27)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global CA27_OUT "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

* openpyxl reader. argv = mode book out [sheet] [cell|col].
*   cell   : the cell's text, written verbatim (no trailing newline);
*            sheet @1 is the first worksheet, whatever its name
*   sheets : the sheet names, one per line
*   width  : the column's stored width, %.4f
tempname fh
file open `fh' using "`output_dir'/ca27_xlsx.py", write text replace
file write `fh' "import sys, openpyxl" _n
file write `fh' "mode, book, out = sys.argv[1], sys.argv[2], sys.argv[3]" _n
file write `fh' "wb = openpyxl.load_workbook(book)" _n
file write `fh' "if mode == 'sheets':" _n
file write `fh' "    txt = chr(10).join(wb.sheetnames)" _n
file write `fh' "elif mode == 'cell':" _n
file write `fh' "    ws = wb.worksheets[0] if sys.argv[4] == '@1' else wb[sys.argv[4]]" _n
file write `fh' "    v = ws[sys.argv[5]].value" _n
file write `fh' "    txt = '' if v is None else str(v)" _n
file write `fh' "else:" _n
file write `fh' "    d = wb[sys.argv[4]].column_dimensions[sys.argv[5]]" _n
file write `fh' "    txt = '%.4f' % (d.width if d.width is not None else -1)" _n
file write `fh' "open(out, 'w', encoding='utf-8').write(txt)" _n
file close `fh'

* _ca27_xl mode book sheet cell -> Mata global string ca27_txt holds the text
capture program drop _ca27_xl
program define _ca27_xl
    version 17.0
    args mode book sheet cell
    local out "$CA27_OUT/ca27_xlsx_out.txt"
    capture erase "`out'"
    shell python3 "$CA27_OUT/ca27_xlsx.py" `mode' "`book'" "`out'" "`sheet'" "`cell'"
    confirm file "`out'"
    mata: ca27_txt = _ca27_slurp("`out'")
end

mata:
string scalar _ca27_slurp(string scalar fn)
{
    real scalar fh
    string scalar s, line
    fh = fopen(fn, "r")
    s = ""
    line = fget(fh)
    if (line != J(0, 0, "")) s = line
    while ((line = fget(fh)) != J(0, 0, "")) s = s + char(10) + line
    fclose(fh)
    return(s)
}
end

**# F01 - RMST risk sets use the exact event time
* Two subjects: failure at a double time whose %18.0g expansion rounds up,
* one censored at 1. Native stci, rmean: SE .3099048.
capture noisily {
    clear
    set obs 2
    gen double time = 1
    replace time = .12345678912345678 in 1
    gen byte fail = _n == 1
    stset time, failure(fail)
    quietly stci, rmean
    local nat_m = r(rmean)
    local nat_se = r(se)
    survtab, times(1) rmst(1)
    assert reldif(r(rmst_1), `nat_m') < 1e-10
    assert reldif(r(rmst_se_1), `nat_se') < 1e-8
    assert r(rmst_se_1) > 0.3
    assert r(rmst_lb_1) < r(rmst_1) & r(rmst_ub_1) > r(rmst_1)
    assert abs(r(rmst_lb_1) - (`nat_m' - invnormal(.975) * `nat_se')) < 1e-8
    assert abs(r(rmst_ub_1) - (`nat_m' + invnormal(.975) * `nat_se')) < 1e-8
}
if _rc == 0 {
    display as result "  PASS: F01a two-subject RMST SE matches stci (no zero-width CI)"
    local ++pass_count
}
else {
    display as error "  FAIL: F01a two-subject RMST SE (rc=`=_rc')"
    local ++fail_count
}

* Four subjects: one failure at the double time, three censored at 1.
capture noisily {
    clear
    set obs 4
    gen double time = 1
    replace time = .12345678912345678 in 1
    gen byte fail = _n == 1
    stset time, failure(fail)
    quietly stci, rmean
    local nat_se = r(se)
    survtab, times(1) rmst(1)
    assert reldif(r(rmst_se_1), `nat_se') < 1e-8
}
if _rc == 0 {
    display as result "  PASS: F01b four-subject RMST SE matches stci (not inflated)"
    local ++pass_count
}
else {
    display as error "  FAIL: F01b four-subject RMST SE (rc=`=_rc')"
    local ++fail_count
}

* stset id() with a split record and delayed entry: same exact-time axis.
capture noisily {
    clear
    input byte id double(t0 t1) byte fail
    1 0    .05 0
    1 .05  .   1
    2 0    1   0
    3 .02  1   0
    4 0    .7  1
    5 0    1   0
    end
    replace t1 = .12345678912345678 in 2
    stset t1, id(id) time0(t0) failure(fail)
    quietly stci, rmean
    local nat_m = r(rmean)
    local nat_se = r(se)
    survtab, times(1) rmst(1)
    assert reldif(r(rmst_1), `nat_m') < 1e-10
    assert reldif(r(rmst_se_1), `nat_se') < 1e-8
}
if _rc == 0 {
    display as result "  PASS: F01c id()/delayed-entry RMST SE matches stci"
    local ++pass_count
}
else {
    display as error "  FAIL: F01c id()/delayed-entry RMST SE (rc=`=_rc')"
    local ++fail_count
}

**# F02 - the test uses the displayed Missing coding
* Identical displayed distributions (0/1/Missing = 10/10/20 in each group),
* with .a in one group and .b in the other: native p on the displayed
* coding is 1.
foreach fe in cat cate {
    capture noisily {
        clear
        set obs 80
        gen byte g = _n > 40
        gen double x = cond(mod(_n,4)==0, 0, ///
            cond(mod(_n,4)==1, 1, cond(g==0, .a, .b)))
        gen double xd = x
        replace xd = . if missing(xd)
        if "`fe'" == "cat" {
            quietly tabulate xd g, missing chi2
            local nat_p = r(p)
        }
        else {
            quietly tabulate xd g, missing exact
            local nat_p = r(p_exact)
        }
        desctab, by(g) vars(x `fe') missing test
        matrix T = r(table)
        assert reldif(T[1,1], `nat_p') < 1e-8
        assert T[1,1] > .99
        table1_tc, by(g) vars(x `fe') missing test
        matrix T = r(table)
        assert reldif(T[1,1], `nat_p') < 1e-8
    }
    if _rc == 0 {
        display as result "  PASS: F02 `fe' test on collapsed missing codes (desctab, table1_tc)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: F02 `fe' test on collapsed missing codes (rc=`=_rc')"
        local ++fail_count
    }
}

**# F03 - effecttab full keeps every equation's coefficients
capture noisily {
    clear
    set seed 83920
    set obs 200
    gen double x = rnormal()
    gen byte t = mod(_n,2)
    gen double y = 2*x + 5*t + 3*x*t + rnormal()
    collect clear
    quietly collect: teffects ra (y x) (t)
    matrix B = e(b)
    local kb = colsof(B)
    local beqs : coleq B
    local bnames : colnames B
    effecttab, full frame(_ca27_ef, replace) eplotframe(_ca27_ep, replace) ///
        csv("`output_dir'/ca27_full.csv")
    matrix R = r(table)
    assert rowsof(R) == `kb'
    * every fitted element appears exactly once, under its equation
    local rnames : rownames R
    local reqs : roweq R
    forvalues j = 1/`kb' {
        local hits = 0
        forvalues i = 1/`=rowsof(R)' {
            if reldif(R[`i',1], B[1,`j']) < 1e-7 local ++hits
        }
        assert `hits' == 1
    }
    * OME0 and OME1 both carry an x row with their own value
    local ome0x = B[1, colnumb(B, "OME0:x")]
    local ome1x = B[1, colnumb(B, "OME1:x")]
    assert reldif(R[rownumb(R, "OME0:x"), 1], `ome0x') < 1e-7
    assert reldif(R[rownumb(R, "OME1:x"), 1], `ome1x') < 1e-7
    * plot frame: one row per fitted element, equation in section
    frame _ca27_ep {
        assert _N == `kb'
        quietly count if label == "x" & section == "OME0" & reldif(estimate, `ome0x') < 1e-7
        assert r(N) == 1
        quietly count if label == "x" & section == "OME1" & reldif(estimate, `ome1x') < 1e-7
        assert r(N) == 1
    }
    * CSV sink: both x rows, with their own displayed estimate
    import delimited using "`output_dir'/ca27_full.csv", clear varnames(nonames) stringcols(_all)
    quietly count if strtrim(v1) == "x" & strtrim(v2) == string(`ome0x', "%9.2f")
    assert r(N) == 1
    quietly count if strtrim(v1) == "x" & strtrim(v2) == string(`ome1x', "%9.2f")
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: F03 effecttab full keeps same-named coefficients of every equation"
    local ++pass_count
}
else {
    display as error "  FAIL: F03 effecttab full repeated equation names (rc=`=_rc')"
    local ++fail_count
}

* The default (filtered) teffects table is unchanged: ATE and POmean only.
capture noisily {
    clear
    set seed 83920
    set obs 200
    gen double x = rnormal()
    gen byte t = mod(_n,2)
    gen double y = 2*x + 5*t + 3*x*t + rnormal()
    collect clear
    quietly collect: teffects ra (y x) (t)
    matrix B = e(b)
    effecttab
    matrix R = r(table)
    assert rowsof(R) == 2
    assert reldif(R[1,1], B[1,1]) < 1e-7
    assert reldif(R[2,1], B[1,2]) < 1e-7
}
if _rc == 0 {
    display as result "  PASS: F03b filtered teffects table keeps ATE/POmean only"
    local ++pass_count
}
else {
    display as error "  FAIL: F03b filtered teffects table (rc=`=_rc')"
    local ++fail_count
}

* The shared renderer refuses, under uniquekeys, a layout that projects two
* equations' x onto one row key, instead of keeping one of the values.
capture noisily {
    clear
    set seed 83920
    set obs 200
    gen double x = rnormal()
    gen byte t = mod(_n,2)
    gen double y = 2*x + 5*t + 3*x*t + rnormal()
    collect clear
    quietly collect: teffects ra (y x) (t)
    preserve
    capture _tabtools_collect_render, type(main) rowdim(colname) ///
        results(_r_b) uniquekeys
    local rc1 = _rc
    restore
    assert `rc1' == 459
    preserve
    _tabtools_collect_render, type(main) rowdim(coleq#colname) ///
        results(_r_b) uniquekeys
    restore
}
if _rc == 0 {
    display as result "  PASS: F03d renderer uniquekeys refuses an ambiguous projection"
    local ++pass_count
}
else {
    display as error "  FAIL: F03d renderer uniquekeys (rc=`=_rc')"
    local ++fail_count
}

* AIPW: outcome equations OME0/OME1 and the treatment equation TME1 share
* names; every fitted element is kept once, under its own equation.
capture noisily {
    clear
    set seed 83920
    set obs 300
    gen double x = rnormal()
    gen byte t = runiform() < invlogit(.4*x)
    gen double y = 2*x + 5*t + 3*x*t + rnormal()
    collect clear
    quietly collect: teffects aipw (y x) (t x)
    matrix B = e(b)
    local kb = colsof(B)
    effecttab, full eplotframe(_ca27_ep2, replace)
    matrix R = r(table)
    assert rowsof(R) == `kb'
    local beqs : coleq B
    local bnames : colnames B
    forvalues j = 1/`kb' {
        local eq : word `j' of `beqs'
        local nm : word `j' of `bnames'
        if "`nm'" == "_cons" continue
        if "`eq'" == "ATE" | "`eq'" == "POmean" continue
        assert reldif(R[rownumb(R, "`eq':`nm'"), 1], B[1,`j']) < 1e-7
    }
    frame _ca27_ep2: assert _N == `kb'
}
if _rc == 0 {
    display as result "  PASS: F03c effecttab full on AIPW keeps every equation"
    local ++pass_count
}
else {
    display as error "  FAIL: F03c effecttab full on AIPW (rc=`=_rc')"
    local ++fail_count
}

**# F04 - group codes above c(maxlong) survive
capture noisily {
    clear
    set obs 12
    gen double g = cond(_n<=4,0,cond(_n<=8,1,3000000000))
    gen double x = _n
    desctab, by(g) vars(x contn %12.3f) total(after) frame(_ca27_big, replace)
    frame _ca27_big {
        quietly ds
        local fv `r(varlist)'
        * factor, three groups, total, p-value
        assert `: word count `fv'' == 6
        assert strtrim(g_T[2]) == "N=12"
        assert strtrim(g_T[3]) == "6.500±3.606"
        assert strtrim(g_3000000000[2]) == "N=4"
        assert strtrim(g_3000000000[3]) == "10.500±1.291"
    }
}
if _rc == 0 {
    display as result "  PASS: F04 group code 3e9 kept; total N=12"
    local ++pass_count
}
else {
    display as error "  FAIL: F04 large group code (rc=`=_rc')"
    local ++fail_count
}

**# F05 - SD is translation invariant
capture noisily {
    clear
    set obs 8
    gen byte g = _n > 4
    gen double x = 1e8 + mod(_n,4)/100
    gen double w = 1
    quietly summarize x if g == 0
    local nat = string(r(mean), "%20.6f") + "±" + string(r(sd), "%20.6f")
    local nat = subinstr("`nat'", " ", "", .)
    desctab, by(g) vars(x contn %20.6f) frame(_ca27_sd, replace)
    frame _ca27_sd: assert strtrim(g_0[3]) == "`nat'"
    desctab, by(g) vars(x contn %20.6f) wt(w) frame(_ca27_sdw, replace)
    * the weighted table adds an effective-sample-size row above x
    frame _ca27_sdw: assert strtrim(g_0[_N]) == "`nat'" & strtrim(factor[_N]) == "x"
    * 1e10 + integers: native SD 1.290994, previously a missing SD
    replace x = 1e10 + mod(_n,4)
    quietly summarize x if g == 0
    local nat = string(r(mean), "%20.6f") + "±" + string(r(sd), "%20.6f")
    local nat = subinstr("`nat'", " ", "", .)
    desctab, by(g) vars(x contn %20.6f) frame(_ca27_sd2, replace)
    frame _ca27_sd2: assert strtrim(g_0[3]) == "`nat'"
    * 1e5 + hundredths: distortion before collapse
    replace x = 1e5 + mod(_n,4)/100
    quietly summarize x if g == 0
    local nat = string(r(mean), "%20.6f") + "±" + string(r(sd), "%20.6f")
    local nat = subinstr("`nat'", " ", "", .)
    desctab, by(g) vars(x contn %20.6f) frame(_ca27_sd3, replace)
    frame _ca27_sd3: assert strtrim(g_0[3]) == "`nat'"
}
if _rc == 0 {
    display as result "  PASS: F05 SD matches summarize after translation (unweighted and wt())"
    local ++pass_count
}
else {
    display as error "  FAIL: F05 SD cancellation (rc=`=_rc')"
    local ++fail_count
}

**# F06 - machine identities keep their case
capture noisily {
    clear
    set seed 83920
    set obs 200
    gen double x = rnormal()
    gen byte t = mod(_n,2)
    gen double y = 2*x + 5*t + 3*x*t + rnormal()
    gen double Y = -5*x + rnormal()
    collect clear
    quietly collect: regress y x
    regtab, frame(_ca27_lc, replace)
    collect clear
    quietly collect: regress Y x
    regtab, frame(_ca27_uc, replace)
    frame _ca27_lc: local o1 : char _dta[tabtools_outcome_id_1]
    frame _ca27_uc: local o2 : char _dta[tabtools_outcome_id_1]
    frame _ca27_uc: local m2 : char _dta[tabtools_model_id_1]
    assert "`o1'" == "y"
    assert "`o2'" == "Y"
    assert "`m2'" == "regress Y x"
    * different outcomes are not composed as one model column
    capture comptab _ca27_lc _ca27_uc, rows(1 \ 1) frame(_ca27_cmb, replace)
    assert _rc == 198
    * identical identities still compose
    collect clear
    quietly collect: regress Y x
    regtab, frame(_ca27_uc2, replace)
    comptab _ca27_uc _ca27_uc2, rows(1 \ 1) frame(_ca27_cmb, replace)
}
if _rc == 0 {
    display as result "  PASS: F06 y and Y stay distinct identities; comptab refuses to merge them"
    local ++pass_count
}
else {
    display as error "  FAIL: F06 case-folded identities (rc=`=_rc')"
    local ++fail_count
}

**# F07 - desctab leaves the caller's estimates usable
foreach cmd in desctab table1_tc {
    capture noisily {
        clear
        set obs 40
        gen byte g = _n > 20
        gen double x = mod(_n,13) + g
        gen double y = 3 + 2*x + mod(_n,3)
        quietly regress y x if _n > 2
        matrix b0 = e(b)
        matrix V0 = e(V)
        local dv0 "`e(depvar)'"
        predict double p0
        gen byte s0 = e(sample)
        `cmd', by(g) vars(x contn \ y conts) test
        assert "`e(depvar)'" == "`dv0'"
        assert mreldif(e(b), b0) == 0
        assert mreldif(e(V), V0) == 0
        gen byte s1 = e(sample)
        assert s1 == s0
        predict double p1
        assert reldif(p1, p0) < 1e-12
    }
    if _rc == 0 {
        display as result "  PASS: F07 `cmd' restores e(b), e(V), e(depvar), e(sample); predict works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: F07 `cmd' caller estimates (rc=`=_rc')"
        local ++fail_count
    }
}

* No active estimates before: none after.
capture noisily {
    clear
    ereturn clear
    set obs 40
    gen byte g = _n > 20
    gen double x = mod(_n,13) + g
    desctab, by(g) vars(x contn) test
    assert "`e(cmd)'" == ""
}
if _rc == 0 {
    display as result "  PASS: F07b no active estimates stays none"
    local ++pass_count
}
else {
    display as error "  FAIL: F07b no active estimates (rc=`=_rc')"
    local ++fail_count
}

* A failing call restores the caller's estimates too.
capture noisily {
    clear
    set obs 40
    gen byte g = _n > 20
    gen double x = mod(_n,13) + g
    gen double y = 3 + 2*x + mod(_n,3)
    quietly regress y x
    matrix b0 = e(b)
    capture desctab, by(g) vars(x contn \ x nosuchtype) test
    assert _rc != 0
    assert "`e(cmd)'" == "regress"
    assert mreldif(e(b), b0) == 0
    predict double p1
}
if _rc == 0 {
    display as result "  PASS: F07c estimates survive a failing desctab"
    local ++pass_count
}
else {
    display as error "  FAIL: F07c estimates after a failing desctab (rc=`=_rc')"
    local ++fail_count
}

**# F08 - no-failure guard uses the grouped sample
capture noisily {
    clear
    input byte(g time fail)
    0 1 0
    0 2 0
    1 1 0
    1 2 0
    . 1 1
    end
    stset time, failure(fail)
    survtab, times(1) by(g) frame(_ca27_nf, replace)
    assert missing(r(logrank_p))
    frame _ca27_nf: assert _N > 0
    * string by() with an empty group
    gen str1 gs = cond(g == 0, "a", cond(g == 1, "b", ""))
    survtab, times(1) by(gs) frame(_ca27_nfs, replace)
    assert missing(r(logrank_p))
}
if _rc == 0 {
    display as result "  PASS: F08 failure in a missing-by row does not defeat the no-failure guard"
    local ++pass_count
}
else {
    display as error "  FAIL: F08 missing-by failure (rc=`=_rc')"
    local ++fail_count
}

* Control: failures in the groups still get a test.
capture noisily {
    clear
    input byte(g time fail)
    0 1 1
    0 2 0
    1 1 0
    1 2 1
    . 1 1
    end
    stset time, failure(fail)
    survtab, times(1) by(g)
    assert !missing(r(logrank_p))
}
if _rc == 0 {
    display as result "  PASS: F08b groups with failures still tested"
    local ++pass_count
}
else {
    display as error "  FAIL: F08b groups with failures (rc=`=_rc')"
    local ++fail_count
}

**# F09 - columnmerge() header text is literal
local cmbook "`output_dir'/ca27_cm.xlsx"
capture erase "`cmbook'"
clear
input str8 A str8 B str16 C str8 D str16 E
"Term" "Est" "CI" "Est2" "CI2"
"A" "1.23" "(0.50, 2.20)" "3.1" "(1.0, 4.0)"
"B" "2.10" "(1.00, 3.20)" "4.2" "(2.0, 5.0)"
end
export excel using "`cmbook'", sheet("Src") replace

* each spec: sheet | header text built with char() in Mata
local nt = 0
mata: ca27_exp = J(0, 1, "")
foreach case in macro dollar backslash lone quote {
    capture noisily {
        if "`case'" == "macro" {
            mata: ca27_h = "Literal " + char(96) + "missing_local" + char(39)
        }
        else if "`case'" == "dollar" {
            mata: ca27_h = "ASCII " + char(36) + "UNKNOWN_GLOBAL"
        }
        else if "`case'" == "backslash" {
            mata: ca27_h = "Ratio " + char(92) + " CI"
        }
        else if "`case'" == "lone" {
            mata: ca27_h = "Odd " + char(96) + " tick"
        }
        else {
            mata: ca27_h = "HR " + char(39) + "adj" + char(39)
        }
        mata: st_local("spec", "B+C as " + char(96) + char(34) + ca27_h + char(34) + char(39))
        stacktab using "`cmbook'", blocks(sheet(Src)) ///
            sheet("CM_`case'") columnmerge(`macval(spec)')
        _ca27_xl cell "`cmbook'" "CM_`case'" C2
        mata: assert(ca27_txt == ca27_h)
        _ca27_xl cell "`cmbook'" "CM_`case'" C3
        mata: assert(ca27_txt == "1.23 (0.50, 2.20)")
    }
    if _rc == 0 {
        display as result "  PASS: F09 columnmerge() header `case' preserved exactly"
        local ++pass_count
    }
    else {
        display as error "  FAIL: F09 columnmerge() header `case' (rc=`=_rc')"
        local ++fail_count
    }
}

* Two rules, one quoted backslash and one dollar sign
capture noisily {
    mata: ca27_h1 = "Ratio " + char(92) + " CI"
    mata: ca27_h2 = "Second " + char(36) + "x"
    mata: st_local("spec", "B+C as " + char(34) + ca27_h1 + char(34) + " " + char(92) + ///
        " D+E as " + char(34) + ca27_h2 + char(34))
    stacktab using "`cmbook'", blocks(sheet(Src)) ///
        sheet("CM_two") columnmerge(`macval(spec)')
    _ca27_xl cell "`cmbook'" "CM_two" C2
    mata: assert(ca27_txt == ca27_h1)
    _ca27_xl cell "`cmbook'" "CM_two" D2
    mata: assert(ca27_txt == ca27_h2)
    _ca27_xl cell "`cmbook'" "CM_two" D3
    mata: assert(ca27_txt == "3.1 (1.0, 4.0)")
}
if _rc == 0 {
    display as result "  PASS: F09 two columnmerge() rules with quoted separators"
    local ++pass_count
}
else {
    display as error "  FAIL: F09 two columnmerge() rules (rc=`=_rc')"
    local ++fail_count
}

* Malformed pieces still fail with r(198)
capture noisily {
    capture stacktab using "`cmbook'", blocks(sheet(Src)) ///
        sheet("CM_bad") columnmerge(B+C "no as")
    assert _rc == 198
    capture stacktab using "`cmbook'", blocks(sheet(Src)) ///
        sheet("CM_bad") columnmerge(B+B as "self")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: F09 malformed columnmerge() still r(198)"
    local ++pass_count
}
else {
    display as error "  FAIL: F09 malformed columnmerge() (rc=`=_rc')"
    local ++fail_count
}

**# F10 - puttab addresses a sheet named A"B
capture noisily {
    local qbook "`output_dir'/ca27_qsheet.xlsx"
    capture erase "`qbook'"
    local sh = "A" + char(34) + "B"
    mata: qb = xl()
    mata: qb.create_book(st_local("qbook"), st_local("sh"), "xlsx")
    mata: qb.put_string(1, 1, "sentinel")
    mata: qb.close_book()
    clear
    set obs 1
    gen str1 x = "x"
    puttab x using "`qbook'", sheet(`"`sh'"')
    mata: assert(st_global("r(sheet)") == "A" + char(34) + "B")
    _ca27_xl sheets "`qbook'"
    mata: assert(ca27_txt == "A" + char(34) + "B")
    * the sheet was rewritten: the sentinel is gone
    _ca27_xl cell "`qbook'" "@1" A1
    mata: assert(ca27_txt != "sentinel")
}
if _rc == 0 {
    display as result "  PASS: F10 puttab writes and reports sheet A" as result char(34) as result "B"
    local ++pass_count
}
else {
    display as error "  FAIL: F10 puttab double-quote sheet (rc=`=_rc')"
    local ++fail_count
}

**# F11 - relabelled cmd/cmdline metadata
capture noisily {
    clear
    set seed 83920
    set obs 200
    gen double x = rnormal()
    gen byte t = mod(_n,2)
    gen double y = 2*x + 5*t + 3*x*t + rnormal()
    quietly regress y i.t##c.x
    collect clear
    quietly collect: margins t
    effecttab
    matrix R0 = r(table)
    collect label levels result cmd "My command" ///
        cmdline "My command line", modify
    effecttab, frame(_ca27_rl, replace)
    assert mreldif(r(table), R0) == 0
    * the caller's labels survive
    quietly collect label list result, all
    local k = s(k)
    local seen = 0
    forvalues i = 1/`k' {
        if "`s(level`i')'" == "cmd" {
            assert "`s(label`i')'" == "My command"
            local ++seen
        }
        if "`s(level`i')'" == "cmdline" {
            assert "`s(label`i')'" == "My command line"
            local ++seen
        }
    }
    assert `seen' == 2
}
if _rc == 0 {
    display as result "  PASS: F11 effecttab reads metadata by level; labels restored"
    local ++pass_count
}
else {
    display as error "  FAIL: F11 relabelled metadata (rc=`=_rc')"
    local ++fail_count
}

**# F12 - regtab with large ancillary matrices is bounded
capture noisily {
    clear
    set seed 12345
    set obs 400
    gen byte c = mod(_n,2)
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen double x3 = rnormal()
    gen byte y = runiform() < invlogit(.3*x1-.2*x2+.1*x3+.5*c)
    gen id = mod(_n,3)+1
    bysort id: gen tt = _n
    xtset id tt
    collect clear
    quietly collect: xtgee y x1 x2 x3, family(binomial) link(logit) ///
        corr(independent) vce(robust)
    matrix b1 = e(b)
    quietly collect: xtgee y x1 x2 x3, family(binomial) link(logit) corr(independent)
    matrix b2 = e(b)
    timer clear 97
    timer on 97
    regtab, stats(qic) frame(_ca27_gee, replace)
    timer off 97
    quietly timer list 97
    local secs = r(t97)
    display as text "  regtab on 36k collected items: `secs' s"
    assert `secs' < 15
    matrix R = r(table)
    * odds ratios of the first model's first coefficient
    assert reldif(R[1,1], exp(b1[1,1])) < 1e-7
}
if _rc == 0 {
    display as result "  PASS: F12 regtab over GEE working-correlation items in bounded time"
    local ++pass_count
}
else {
    display as error "  FAIL: F12 regtab GEE latency (rc=`=_rc')"
    local ++fail_count
}

* The line-indexed fast path of the collection reader returns exactly the
* items of the full character scan, for selected and for all results.
capture noisily {
    quietly collect save "`output_dir'/ca27_gee.stjson", replace
    quietly findfile _tabtools_collect_render.ado
    capture program drop _tabtools_collect_render
    quietly run "`r(fn)'"
    local _tt_res_level_1 "cmd"
    local _tt_res_level_2 "_r_ci"
    local _tt_res_level_3 "qic"
    mata: ca27_a = _tt_collect_items("`output_dir'/ca27_gee.stjson", 3)
    mata: ca27_b = _tt_collect_items("`output_dir'/ca27_gee.stjson", 3, 1)
    mata: assert(rows(ca27_a) > 0 & ca27_a == ca27_b)
    mata: ca27_a = _tt_collect_items("`output_dir'/ca27_gee.stjson")
    mata: ca27_b = _tt_collect_items("`output_dir'/ca27_gee.stjson", 0, 1)
    mata: assert(rows(ca27_a) > 30000 & ca27_a == ca27_b)
    mata: mata drop ca27_a ca27_b
}
if _rc == 0 {
    display as result "  PASS: F12b fast collection reader matches the full scan"
    local ++pass_count
}
else {
    display as error "  FAIL: F12b fast reader parity (rc=`=_rc')"
    local ++fail_count
}

**# F13 - style() rejects unknown and duplicate groups
local stbook "`output_dir'/ca27_style.xlsx"
capture erase "`stbook'"
clear
input str8 A str8 B str16 C
"Term" "Est" "CI"
"A" "1.23" "(0.50, 2.20)"
end
export excel using "`stbook'", sheet("Src") replace
export excel using "`stbook'", sheet("Out", replace)
foreach bad in `"colwidh(A 80)"' `"colwidth(A 20) colwidth(B 80)"' ///
    `"xcolwidth(A 20)"' `"colwidth(A 20) junk"' ///
    `"titlerowheight(20) titlerowheight(30)"' {
    capture noisily {
        capture stacktab using "`stbook'", blocks(sheet(Src)) ///
            sheet("Out") style(`bad') sheetreplace
        assert _rc == 198
        _ca27_xl cell "`stbook'" "Out" A1
        mata: assert(ca27_txt == "Term")
    }
    if _rc == 0 {
        display as result `"  PASS: F13 style(`bad') rejected; sheet untouched"'
        local ++pass_count
    }
    else {
        display as error `"  FAIL: F13 style(`bad') (rc=`=_rc')"'
        local ++fail_count
    }
}

* Control: the documented grouped form still applies both widths.
capture noisily {
    stacktab using "`stbook'", blocks(sheet(Src)) ///
        sheet("OK") style(COLWIDTH(A 20 \ B 80) titlerowheight(20))
    _ca27_xl width "`stbook'" "OK" B
    mata: assert(abs(strtoreal(ca27_txt) - 20) < 1)
    _ca27_xl width "`stbook'" "OK" C
    mata: assert(abs(strtoreal(ca27_txt) - 80) < 1)
}
if _rc == 0 {
    display as result "  PASS: F13b grouped colwidth() applied to both columns"
    local ++pass_count
}
else {
    display as error "  FAIL: F13b grouped colwidth() (rc=`=_rc')"
    local ++fail_count
}

**# Summary
foreach f in _ca27_ef _ca27_ep _ca27_ep2 _ca27_big _ca27_sd _ca27_sdw _ca27_sd2 _ca27_sd3 ///
    _ca27_lc _ca27_uc _ca27_uc2 _ca27_cmb _ca27_nf _ca27_nfs _ca27_rl _ca27_gee {
    capture frame drop `f'
}
capture mata: mata drop ca27_txt ca27_exp ca27_h ca27_h1 ca27_h2 qb
global CA27_OUT
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_codex_audit_2026_09_27 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _ca27
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_codex_audit_2026_09_27 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _ca27
