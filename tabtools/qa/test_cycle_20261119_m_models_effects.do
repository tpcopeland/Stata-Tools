* test_cycle_20261119_m_models_effects.do - regtab/effecttab model-scale and
* equation-layout regressions (review cycle 2026-11-19, unit m_models_effects)
*
*   F1  an estimator without a dedicated scale rule, fitted with an eform
*       display option (xtlogit, or; xtpoisson, irr; cloglog, eform;
*       meologit, or; gnbreg, irr; zip, irr), is labelled with its ratio, its
*       base level is "Reference" (not "Empty"), and dimnonsig tests its CI
*       against 1. A replay (collect: logit, or) is labelled from the collected
*       values, not from e(cmdline).
*   F2  an equation of _cons alone (gnbreg lnalpha:, betareg scale:, nl,
*       xtologit cut#:, plain intreg lnsigma:) or of lnsigma terms (hetprobit,
*       intreg het()) gets
*       equation-aware rows: no
*       coefficient is printed under another equation's label or dropped.
*   F3  BIC uses e(N_ic) when the command sets it (cm choice models), as
*       estat ic does ([R] IC note).
*   F4  effecttab from() with the r(table)' stripe reads b, ll, ul, pvalue by
*       name; a b/se/z/pvalue matrix is refused.
* Oracles are the fitted command's own r(table) and estat ic, never regtab.

clear all
set more off
set varabbrev off
version 17.0

capture log close _c19me
log using "test_cycle_20261119_m_models_effects.log", replace text name(_c19me)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* Trimmed contents of column `col' on the first row at or after row 4 whose
* label is `label'. Errors when the row is absent, so a dropped or renamed row
* can never pass a cell assertion.
capture program drop _c19_cell
program define _c19_cell, rclass
    version 17.0
    args frname label col
    frame `frname' {
        tempvar rn
        quietly generate long `rn' = _n
        quietly summarize `rn' if strtrim(A) == `"`label'"' & _n >= 4, meanonly
        if r(N) == 0 {
            display as error "row not found in frame `frname': `label'"
            exit 459
        }
        local cell = strtrim(`col'[r(min)])
    }
    return local cell `"`cell'"'
end

* Number of body rows (row 4 on) whose label is `label'
capture program drop _c19_nrow
program define _c19_nrow, rclass
    version 17.0
    args frname label
    frame `frname' {
        quietly count if strtrim(A) == `"`label'"' & _n >= 4
        local n = r(N)
    }
    return scalar n = `n'
end

* The estimate header of a regtab frame (row 3, first model)
capture program drop _c19_hdr
program define _c19_hdr, rclass
    version 17.0
    args frname
    frame `frname': local h = strtrim(c1[3])
    return local cell `"`h'"'
end

* A number as regtab prints it at the default two decimals
capture program drop _c19_f2
program define _c19_f2, rclass
    version 17.0
    args x
    local s = strtrim(string(round(`x', 0.01), "%9.2f"))
    if "`s'" == "-0.00" local s "0.00"
    return local s "`s'"
end

* Column of matrix `m' with full name `nm' (eq:name), or error
capture program drop _c19_col
program define _c19_col, rclass
    version 17.0
    args m nm
    local j = colnumb(`m', "`nm'")
    if missing(`j') {
        display as error "column `nm' not in `m'"
        exit 111
    }
    return scalar j = `j'
end

* Panel data shared by the F1 tests
capture program drop _c19_panel
program define _c19_panel
    version 17.0
    clear
    set seed 20261119
    set obs 600
    generate id = ceil(_n / 6)
    generate x1 = rnormal()
    generate z = rnormal()
    generate g = 1 + floor(runiform() * 3)
    generate u = rnormal() * 0.5 if mod(_n, 6) == 1
    bysort id: replace u = u[1]
    generate y = runiform() < invlogit(-0.5 + 0.7 * x1 + 0.4 * (g == 2) - 0.6 * (g == 3) + u)
    generate cnt = rpoisson(exp(0.2 + 0.25 * x1 + 0.2 * (g == 2) + u))
    xtset id
end

**# F1: unlisted estimators fitted with an eform display option

**## F1a: xtlogit, or is labelled OR, base Reference, cells = r(table)
local ++test_count
capture noisily {
    _c19_panel
    collect clear
    quietly collect: xtlogit y x1 i.g, or
    matrix T = r(table)
    quietly regtab, nore frame(c19a, replace)
    assert "`r(coef_label)'" == "OR"
    assert strpos(`"`r(methods)'"', "Odds ratios") > 0
    _c19_hdr c19a
    assert "`r(cell)'" == "OR"
    _c19_cell c19a "1" c1
    assert "`r(cell)'" == "Reference"
    * the printed OR and interval are Stata's displayed (already exponentiated)
    * values, not exponentiated a second time
    _c19_col T "y:x1"
    local j = r(j)
    _c19_f2 T[1,`j']
    local eb "`r(s)'"
    _c19_f2 T[5,`j']
    local el "`r(s)'"
    _c19_f2 T[6,`j']
    local eu "`r(s)'"
    _c19_cell c19a "x1" c1
    assert "`r(cell)'" == "`eb'"
    _c19_cell c19a "x1" c2
    assert "`r(cell)'" == "(`el', `eu')"
    _c19_nrow c19a "Empty"
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: F1a xtlogit, or: OR header, Reference base, r(table) cells"
    local ++pass_count
}
else {
    display as error "  FAIL: F1a xtlogit, or: OR header, Reference base, r(table) cells (rc=`=_rc')"
    local ++fail_count
}

**## F1b: xtpoisson, irr is labelled IRR with a Reference base
local ++test_count
capture noisily {
    _c19_panel
    collect clear
    quietly collect: xtpoisson cnt x1 i.g, irr
    matrix T = r(table)
    quietly regtab, nore frame(c19b, replace)
    assert "`r(coef_label)'" == "IRR"
    _c19_hdr c19b
    assert "`r(cell)'" == "IRR"
    _c19_cell c19b "1" c1
    assert "`r(cell)'" == "Reference"
    _c19_col T "cnt:x1"
    _c19_f2 T[1,`r(j)']
    local eb "`r(s)'"
    _c19_cell c19b "x1" c1
    assert "`r(cell)'" == "`eb'"
    * the ratio header hides the intercept by default, as for poisson, irr
    _c19_nrow c19b "Intercept"
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: F1b xtpoisson, irr: IRR header, Reference base"
    local ++pass_count
}
else {
    display as error "  FAIL: F1b xtpoisson, irr: IRR header, Reference base (rc=`=_rc')"
    local ++fail_count
}

**## F1c: cloglog eform, meologit or, gnbreg irr, zip irr name their scale
local ++test_count
capture noisily {
    _c19_panel
    local specs `""cloglog y x1 i.g, eform" "meologit cnt x1 i.g || id:, or" "gnbreg cnt x1 i.g, irr" "zip cnt x1 i.g, inflate(x1) irr""'
    local want `""exp(b)" "OR" "IRR" "IRR""'
    local k = 0
    foreach s of local specs {
        local ++k
        local w : word `k' of `want'
        collect clear
        quietly collect: `s'
        quietly regtab, nore frame(c19c, replace)
        display as text "  `s' -> `r(coef_label)'"
        assert "`r(coef_label)'" == "`w'"
        _c19_hdr c19c
        assert "`r(cell)'" == "`w'"
        frame c19c: quietly count if inlist(strtrim(c1), "Reference") & _n >= 4
        assert r(N) == 1
        frame c19c: quietly count if strtrim(c1) == "Empty" & _n >= 4
        assert r(N) == 0
    }
}
if _rc == 0 {
    display as result "  PASS: F1c cloglog/meologit/gnbreg/zip eform options name the scale"
    local ++pass_count
}
else {
    display as error "  FAIL: F1c cloglog/meologit/gnbreg/zip eform options name the scale (rc=`=_rc')"
    local ++fail_count
}

**## F1d: dimnonsig tests an xtlogit, or row against 1
* The xlsx font colour of a dimmed row is 160/160/160 (A0A0A0). z is noise:
* its OR interval spans 1 and must be dimmed; x1's lies above 1 and must not.
* Before the fix the null was 0, so no OR row could ever be dimmed.
local ++test_count
capture noisily {
    local dim_py "`c(tmpdir)'/c19me_dim.py"
    capture erase "`dim_py'"
    tempname fh
    file open `fh' using "`dim_py'", write text replace
    file write `fh' "import sys, openpyxl" _n
    file write `fh' "wb = openpyxl.load_workbook(sys.argv[1]); ws = wb.active" _n
    file write `fh' "out = []" _n
    file write `fh' "for lab in sys.argv[3:]:" _n
    file write `fh' "    row = [r for r in range(1, ws.max_row + 1) if str(ws.cell(r, 2).value or '').strip() == lab]" _n
    file write `fh' "    rgb = ws.cell(row[0], 3).font.color.rgb if row and ws.cell(row[0], 3).font.color is not None else ''" _n
    file write `fh' "    out.append(str(rgb).upper().endswith('A0A0A0'))" _n
    file write `fh' "open(sys.argv[2], 'w').write(' '.join('1' if o else '0' for o in out))" _n
    file close `fh'
    local dim_out "`c(tmpdir)'/c19me_dim.txt"

    _c19_panel
    collect clear
    quietly collect: xtlogit y x1 z, or
    matrix T = r(table)
    * the oracle: z's OR interval spans 1, x1's does not
    _c19_col T "y:z"
    assert T[5, `r(j)'] < 1 & T[6, `r(j)'] > 1
    _c19_col T "y:x1"
    assert T[5, `r(j)'] > 1
    local x "`output_dir'/c19me_dim.xlsx"
    capture erase "`x'"
    capture erase "`dim_out'"
    quietly regtab, nore xlsx("`x'") sheet("T") dimnonsig
    shell python3 "`dim_py'" "`x'" "`dim_out'" "z" "x1"
    file open `fh' using "`dim_out'", read text
    file read `fh' line
    file close `fh'
    display as text "  dimmed (z x1): `line'"
    assert "`line'" == "1 0"
}
if _rc == 0 {
    display as result "  PASS: F1d dimnonsig null is 1 for xtlogit, or"
    local ++pass_count
}
else {
    display as error "  FAIL: F1d dimnonsig null is 1 for xtlogit, or (rc=`=_rc')"
    local ++fail_count
}

**## F1e: a replay is labelled from the collected values
* collect: logit, or replays the active fit as ORs, and the collection holds
* no command line; e(cmdline) still reads "logit y x1 i.g". Conversely a fit
* with or replayed without it collects coefficients.
local ++test_count
capture noisily {
    _c19_panel
    quietly logit y x1 i.g
    collect clear
    quietly collect: logit, or
    matrix T = r(table)
    quietly regtab, frame(c19e, replace)
    assert "`r(coef_label)'" == "OR"
    _c19_hdr c19e
    assert "`r(cell)'" == "OR"
    _c19_cell c19e "1" c1
    assert "`r(cell)'" == "Reference"
    _c19_cell c19e "1" c2
    assert "`r(cell)'" == ""
    _c19_col T "y:x1"
    _c19_f2 T[1,`r(j)']
    local eb "`r(s)'"
    _c19_cell c19e "x1" c1
    assert "`r(cell)'" == "`eb'"
    _c19_nrow c19e "Intercept"
    assert r(n) == 0

    quietly logit y x1 i.g, or
    collect clear
    quietly collect: logit
    matrix T = r(table)
    quietly regtab, frame(c19e2, replace)
    assert "`r(coef_label)'" == "Coef."
    _c19_col T "y:x1"
    _c19_f2 T[1,`r(j)']
    local eb "`r(s)'"
    _c19_cell c19e2 "x1" c1
    assert "`r(cell)'" == "`eb'"
}
if _rc == 0 {
    display as result "  PASS: F1e replay scale follows the collected values"
    local ++pass_count
}
else {
    display as error "  FAIL: F1e replay scale follows the collected values (rc=`=_rc')"
    local ++fail_count
}

**## F1f: control - xtlogit without or stays Coef. with a Reference base
local ++test_count
capture noisily {
    _c19_panel
    collect clear
    quietly collect: xtlogit y x1 i.g
    quietly regtab, nore frame(c19f, replace)
    assert "`r(coef_label)'" == "Coef."
    _c19_cell c19f "1" c1
    assert "`r(cell)'" == "Reference"
}
if _rc == 0 {
    display as result "  PASS: F1f xtlogit coefficient scale unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: F1f xtlogit coefficient scale unchanged (rc=`=_rc')"
    local ++fail_count
}

**# F2: equations of _cons alone or of lnsigma terms

capture program drop _c19_xs
program define _c19_xs
    version 17.0
    clear
    set seed 31
    set obs 800
    generate x1 = rnormal()
    generate x2 = rnormal()
    generate g = 1 + floor(runiform() * 3)
    generate cnt = rnbinomial(2, 1 / (1 + exp(0.3 + 0.4 * x1) / 2))
    generate y = runiform() < invlogit(-0.3 + 0.6 * x1 + 0.4 * x2)
    generate lo = x1 + rnormal()
    generate hi = lo + 1
    generate p01 = invlogit(0.3 * x1 + rnormal() * 0.5)
end

* every (row label, r(table) column) pair must print that column's b
capture program drop _c19_pairs
program define _c19_pairs
    version 17.0
    gettoken fr 0 : 0
    while `"`0'"' != "" {
        gettoken lab 0 : 0
        gettoken col 0 : 0
        _c19_col T "`col'"
        _c19_f2 T[1,`r(j)']
        local e "`r(s)'"
        _c19_cell `fr' "`lab'" c1
        display as text "    `lab' = `r(cell)' (r(table) `col' = `e')"
        assert "`r(cell)'" == "`e'"
    }
end

**## F2a: gnbreg prints both intercepts under their own equations
local ++test_count
capture noisily {
    _c19_xs
    collect clear
    quietly collect: gnbreg cnt x1 i.g
    matrix T = r(table)
    quietly regtab, keepintercept frame(c19g, replace)
    _c19_pairs c19g "cnt: x1" "cnt:x1" "cnt: Intercept" "cnt:_cons" ///
        "lnalpha: Intercept" "lnalpha:_cons"
    _c19_nrow c19g "Intercept"
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: F2a gnbreg count and lnalpha intercepts both shown, correctly labelled"
    local ++pass_count
}
else {
    display as error "  FAIL: F2a gnbreg count and lnalpha intercepts (rc=`=_rc')"
    local ++fail_count
}

**## F2b: hetprobit keeps lnsigma:x2 as its own row
local ++test_count
capture noisily {
    _c19_xs
    collect clear
    quietly collect: hetprobit y x1 x2, het(x2)
    matrix T = r(table)
    quietly regtab, frame(c19h, replace)
    _c19_pairs c19h "y: x1" "y:x1" "y: x2" "y:x2" "Scale: x2" "lnsigma:x2"
    * four estimated columns, four printed estimates
    frame c19h: quietly count if _n >= 4 & strtrim(c2) != ""
    assert r(N) == 4

    collect clear
    quietly collect: hetprobit y x1 i.g, het(x2)
    matrix T = r(table)
    quietly regtab, frame(c19h2, replace)
    _c19_pairs c19h2 "y: x1" "y:x1" "Scale: x2" "lnsigma:x2"
    _c19_nrow c19h2 "x2"
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: F2b hetprobit variance-equation rows kept and labelled"
    local ++pass_count
}
else {
    display as error "  FAIL: F2b hetprobit variance-equation rows (rc=`=_rc')"
    local ++fail_count
}

**## F2c: intreg het() keeps lnsigma:x2 and lnsigma:_cons
local ++test_count
capture noisily {
    _c19_xs
    collect clear
    quietly collect: intreg lo hi x1 i.g, het(x2)
    matrix T = r(table)
    quietly regtab, frame(c19i, replace)
    _c19_pairs c19i "model: x1" "model:x1" "model: Intercept" "model:_cons" ///
        "Scale: x2" "lnsigma:x2" "Scale: Intercept" "lnsigma:_cons"
}
if _rc == 0 {
    display as result "  PASS: F2c intreg het() scale equation kept"
    local ++pass_count
}
else {
    display as error "  FAIL: F2c intreg het() scale equation (rc=`=_rc')"
    local ++fail_count
}

**## F2d: betareg keeps the mean intercept and scale:_cons apart
local ++test_count
capture noisily {
    _c19_xs
    collect clear
    quietly collect: betareg p01 x1
    matrix T = r(table)
    quietly regtab, frame(c19j, replace)
    _c19_pairs c19j "p01: x1" "p01:x1" "p01: Intercept" "p01:_cons" ///
        "scale: Intercept" "scale:_cons"
}
if _rc == 0 {
    display as result "  PASS: F2d betareg mean and scale intercepts both shown"
    local ++pass_count
}
else {
    display as error "  FAIL: F2d betareg mean and scale intercepts (rc=`=_rc')"
    local ++fail_count
}

**## F2e: nl parameters and xtologit cutpoints are not merged into one row
* nl stores b0:_cons and b1:_cons; xtologit cut1:_cons, cut2:_cons and
* sigma2_u:_cons. Before the fix one "Intercept" row held whichever value
* collect returned and the others were dropped.
local ++test_count
capture noisily {
    _c19_xs
    generate yc = 1 + 0.5 * x1 + rnormal()
    collect clear
    quietly collect: nl (yc = {b0} + {b1}*x1)
    matrix T = r(table)
    quietly regtab, frame(c19n, replace)
    _c19_pairs c19n "b0: Intercept" "b0:_cons" "b1: Intercept" "b1:_cons"

    _c19_panel
    generate yo = 1 + (x1 + rnormal() > 0) + (x1 + rnormal() > 1)
    collect clear
    quietly collect: xtologit yo x1
    matrix T = r(table)
    quietly regtab, keepintercept frame(c19o, replace)
    _c19_pairs c19o "yo: x1" "yo:x1" "cut1: Intercept" "cut1:_cons" ///
        "cut2: Intercept" "cut2:_cons" "sigma2 u: Intercept" "sigma2_u:_cons"
}
if _rc == 0 {
    display as result "  PASS: F2e nl and xtologit single-_cons equations each keep their row"
    local ++pass_count
}
else {
    display as error "  FAIL: F2e nl and xtologit single-_cons equations (rc=`=_rc')"
    local ++fail_count
}

**## F2f: plain intreg keeps lnsigma:_cons and its base level is Reference
* Without het() the lnsigma equation holds only _cons. Before the fix the
* colname merge dropped it; now the table is equation-aware, so the factor
* base row reads "model:   1" and must still be the Reference.
local ++test_count
capture noisily {
    _c19_xs
    collect clear
    quietly collect: intreg lo hi x1 i.g
    matrix T = r(table)
    quietly regtab, frame(c19p, replace)
    _c19_pairs c19p "model: x1" "model:x1" "model:   2" "model:2.g" ///
        "model: Intercept" "model:_cons" "Scale: Intercept" "lnsigma:_cons"
    _c19_cell c19p "model:   1" c1
    assert "`r(cell)'" == "Reference"
    frame c19p: quietly count if strtrim(c1) == "Empty" & _n >= 4
    assert r(N) == 0
    _c19_nrow c19p "Scale: Intercept"
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: F2f plain intreg lnsigma:_cons kept, base Reference"
    local ++pass_count
}
else {
    display as error "  FAIL: F2f plain intreg lnsigma:_cons / base (rc=`=_rc')"
    local ++fail_count
}

**# F3: BIC uses e(N_ic)

**## F3a: cmclogit BIC equals estat ic (N = cases), AIC unchanged
local ++test_count
capture noisily {
    clear
    set seed 1010
    set obs 300
    generate case = ceil(_n / 3)
    bysort case: generate alt = _n
    generate x = rnormal()
    generate u = x + rlogistic()
    bysort case (u): generate ch = _n == _N
    quietly cmset case alt
    collect clear
    quietly collect: cmclogit ch x, noconstant
    assert e(N_ic) == 100 & e(N) == 300
    quietly estat ic
    matrix S = r(S)
    quietly regtab, stats(n bic aic) frame(c19k, replace)
    display as text "  regtab BIC " %12.6f r(bic_1) "  estat ic BIC " %12.6f S[1, 6]
    assert reldif(r(bic_1), S[1, 6]) < 1e-10
    assert reldif(r(aic_1), S[1, 5]) < 1e-10
    _c19_f2 S[1,6]
    local e "`r(s)'"
    _c19_cell c19k "BIC" c1
    assert "`r(cell)'" == "`e'"
}
if _rc == 0 {
    display as result "  PASS: F3a cmclogit BIC uses e(N_ic)"
    local ++pass_count
}
else {
    display as error "  FAIL: F3a cmclogit BIC uses e(N_ic) (rc=`=_rc')"
    local ++fail_count
}

**## F3b: control - logit (no e(N_ic)) BIC still equals estat ic
local ++test_count
capture noisily {
    _c19_xs
    collect clear
    quietly collect: logit y x1 x2
    assert missing(e(N_ic))
    quietly estat ic
    matrix S = r(S)
    quietly regtab, stats(n bic)
    assert reldif(r(bic_1), S[1, 6]) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: F3b logit BIC unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: F3b logit BIC unchanged (rc=`=_rc')"
    local ++fail_count
}

**# F4: effecttab from() and the r(table)' stripe

**## F4a: r(table)' rows are read by column name
local ++test_count
capture noisily {
    _c19_xs
    quietly logit y x1 x2
    matrix T0 = r(table)'
    matrix TF = T0[1..2, 1...]
    quietly effecttab, from(TF) frame(c19l, replace)
    foreach v in x1 x2 {
        local r = rownumb(T0, "y:`v'")
        _c19_f2 T0[`r',5]
        local el "`r(s)'"
        _c19_f2 T0[`r',6]
        local eu "`r(s)'"
        _c19_f2 T0[`r',1]
        local eb "`r(s)'"
        frame c19l {
            quietly generate long _rn = _n
            quietly summarize _rn if strtrim(A) == "`v'", meanonly
            assert r(N) == 1
            local cb = strtrim(c1[r(min)])
            local ci = strtrim(c2[r(min)])
            drop _rn
        }
        display as text "    `v': `cb' `ci' (r(table): `eb' (`el', `eu'))"
        assert "`cb'" == "`eb'"
        assert "`ci'" == "(`el', `eu')"
    }
}
if _rc == 0 {
    display as result "  PASS: F4a effecttab from(r(table)') prints b (ll, ul)"
    local ++pass_count
}
else {
    display as error "  FAIL: F4a effecttab from(r(table)') prints b (ll, ul) (rc=`=_rc')"
    local ++fail_count
}

**## F4b: a b/se/z/pvalue matrix is refused
local ++test_count
capture noisily {
    _c19_xs
    quietly logit y x1 x2
    matrix T0 = r(table)'
    matrix TB = T0[1..2, 1..4]
    capture noisily effecttab, from(TB)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: F4b effecttab from() refuses a b se z pvalue matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: F4b effecttab from() refuses a b se z pvalue matrix (rc=`=_rc')"
    local ++fail_count
}

**## F4c: control - a matrix with other column names is still positional
local ++test_count
capture noisily {
    matrix U = (0.5, 0.3, 0.7, 0.01 \ 0.2, -0.1, 0.5, 0.2)
    matrix colnames U = est lo hi p
    matrix rownames U = a b
    quietly effecttab, from(U) frame(c19m, replace)
    frame c19m {
        quietly generate long _rn = _n
        quietly summarize _rn if strtrim(A) == "a", meanonly
        assert r(N) == 1
        local ci = strtrim(c2[r(min)])
    }
    assert "`ci'" == "(0.30, 0.70)"
}
if _rc == 0 {
    display as result "  PASS: F4c effecttab from() positional reading unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: F4c effecttab from() positional reading unchanged (rc=`=_rc')"
    local ++fail_count
}

foreach f in c19a c19b c19c c19e c19e2 c19f c19g c19h c19h2 c19i c19j c19k c19l c19m c19n c19o {
    capture frame drop `f'
}

display as text ""
display as text "RESULT: test_cycle_20261119_m_models_effects tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _c19me
if `fail_count' > 0 exit 1
