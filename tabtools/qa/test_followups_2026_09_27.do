* test_followups_2026_09_27.do - follow-ups left by the 2026-09-26/27 packages
* Regression suite, written against commit 40e28488 (the output-sink commit
* after the 2.1.11 release, 33528c76) before any fix:
*   F1  xtgee binomial/logit and poisson/log are shown on the OR/IRR scale,
*       as glm with the same family and link is; eform is honoured
*   F2  guard, not a regression test (the reported defect did not
*       reproduce on 33528c76): nbreg + zip with keepintercept keep nbreg's
*       ancillary rows and zip's inflation equation, each in its own model's
*       column
*   F3  title() and footnote() text reaches xlsx, CSV and Markdown intact:
*       no local-macro, global-macro or unbalanced-backtick expansion
*   F4  effecttab from() matrix headers read "95% CI" and "p-value", as the
*       collect path and regtab do
*   F6  a Markdown write that fails leaves the prior target byte-identical
*       and no staging file behind
*   F7  regtab and effecttab refuse a csv() path with a bad character before
*       anything is written, with the rc other commands use
*   F8  a covariate named like its own model's ancillary parameter (nbreg
*       alpha, Weibull ln_p, lognormal lnsigma, ologit cut1) is shown beside
*       that parameter instead of being refused
*   F9  a confidence level such as 99.9 is shown as typed (at most 15
*       significant digits), never as 99.90000000000001, in headers,
*       r(methods), CSV cells and frame characteristics; r(ci_level) stays
*       numeric
* Expected values come from each fit's own e(b), hand-built strings read back
* by openpyxl and markdown-it-py, checksums taken before the call, and the
* rc of commands that already validate, never from the output under test.

clear all
set more off
set varabbrev off
version 17.0

capture log close _fu
log using "test_followups_2026_09_27.log", replace text name(_fu)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global FU_TOOLS "`qa_dir'/tools"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

* Trimmed contents of column `col' on the one body row whose trimmed label is
* `label'. Errors when the row is absent or duplicated.
capture program drop _fu_cell
program define _fu_cell, rclass
    version 17.0
    args frname label col
    frame `frname' {
        tempvar rn
        quietly generate long `rn' = _n
        quietly count if strtrim(A) == `"`label'"' & _n >= 4
        if r(N) != 1 {
            display as error `"frame `frname': `r(N)' rows labelled "`label'""'
            exit 459
        }
        quietly summarize `rn' if strtrim(A) == `"`label'"' & _n >= 4, meanonly
        local row = r(min)
        local cell = strtrim(`col'[`row'])
    }
    return local cell `"`cell'"'
    return scalar row = `row'
end

* Number of body rows whose trimmed label is `label'.
capture program drop _fu_nrow
program define _fu_nrow, rclass
    version 17.0
    args frname label
    frame `frname' {
        quietly count if strtrim(A) == `"`label'"' & _n >= 4
        local n = r(N)
    }
    return scalar n = `n'
end

* The text a table prints for x at digits(2).
capture program drop _fu_fmt
program define _fu_fmt, rclass
    version 17.0
    args x
    return local s = strtrim(string(round(`x', 0.01), "%32.2f"))
end

* Assert the cell of `label' in column `col' equals the formatted value x.
capture program drop _fu_is
program define _fu_is
    version 17.0
    args frname label col x
    _fu_fmt `x'
    local want "`r(s)'"
    _fu_cell `frname' `"`label'"' `col'
    if `"`r(cell)'"' != "`want'" {
        display as error `"`label' `col': got "`r(cell)'", want "`want'""'
        exit 9
    }
end

* Assert body row `k' (1 = first body row) has label `label' and, in column
* `col', the formatted value x ("" for an empty cell).
capture program drop _fu_row
program define _fu_row
    version 17.0
    args frname k label col x
    local want ""
    if `"`x'"' != "" {
        _fu_fmt `x'
        local want "`r(s)'"
    }
    frame `frname' {
        local r = `k' + 3
        if `r' > _N {
            display as error "frame `frname' has no body row `k'"
            exit 9
        }
        local got_l = strtrim(A[`r'])
        local got_c = strtrim(`col'[`r'])
    }
    if `"`got_l'"' != `"`label'"' | `"`got_c'"' != "`want'" {
        display as error `"body row `k': got "`got_l'" / "`got_c'", want "`label'" / "`want'""'
        exit 9
    }
end

* Number of body rows of a frame.
capture program drop _fu_nbody
program define _fu_nbody, rclass
    version 17.0
    args frname
    frame `frname': local n = _N - 3
    return scalar n = `n'
end

* Estimate header (row 3) of column `col'.
capture program drop _fu_hdr
program define _fu_hdr, rclass
    version 17.0
    args frname col
    frame `frname': local h = strtrim(`col'[3])
    return local h `"`h'"'
end

* The first sentence of r(methods) must equal `want' exactly.
capture program drop _fu_methods
program define _fu_methods
    version 17.0
    args got want
    if strpos(`"`got'"', `"`want' Analysis performed in Stata"') != 1 {
        display as error `"methods: got  "`got'""'
        display as error `"       want "`want'""'
        exit 9
    }
end

* The text held in global FU_<which> (T or F) is a cell of sheet `sheet' of
* `book', read back with openpyxl. Mata compares, so nothing is expanded.
capture program drop _fu_xlsx_has
program define _fu_xlsx_has
    version 17.0
    args book sheet which
    tempfile res
    capture erase "`res'"
    shell python3 "$FU_TOOLS/xlsx_facts.py" "`book'" "`sheet'" "`res'"
    confirm file "`res'"
    mata: st_local("ok", strofreal(_fu_facts_has(st_local("res"), "value", st_global("FU_`which'"))))
    if `ok' != 1 {
        display as error "xlsx `book' [`sheet']: text FU_`which' not found"
        type "`res'"
        exit 9
    }
end

* The text held in global FU_<which> is a row of the CSV file, alone in its
* first field.
capture program drop _fu_csv_has
program define _fu_csv_has
    version 17.0
    args path which
    mata: st_local("ok", strofreal(_fu_csv_line(st_local("path"), st_global("FU_`which'"))))
    if `ok' != 1 {
        display as error "csv `path': text FU_`which' not found"
        type "`path'"
        exit 9
    }
end

* The rendered Markdown holds a `tag' element whose visible text is the text
* held in global FU_<which>.
capture program drop _fu_md_has
program define _fu_md_has
    version 17.0
    args md tag which
    tempfile res
    capture erase "`res'"
    shell python3 "$FU_TOOLS/md_facts.py" "`md'" "`res'"
    confirm file "`res'"
    mata: st_local("ok", strofreal(_fu_facts_has(st_local("res"), st_local("tag"), st_global("FU_`which'"))))
    if `ok' != 1 {
        display as error "markdown `md': no `tag' element with text FU_`which'"
        type "`md'"
        exit 9
    }
end

* All three sinks carry the title (T) and the footnote (F). `flat' names
* the global holding the note the CSV and Markdown files carry when it is not
* F alone (corrtab joins its star legend to the footnote there).
capture program drop _fu_sinks_have
program define _fu_sinks_have
    version 17.0
    args stem sheet flat
    if "`flat'" == "" local flat F
    _fu_xlsx_has "`stem'.xlsx" "`sheet'" T
    _fu_xlsx_has "`stem'.xlsx" "`sheet'" F
    _fu_csv_has "`stem'.csv" T
    _fu_csv_has "`stem'.csv" `flat'
    _fu_md_has "`stem'.md" h3 T
    _fu_md_has "`stem'.md" em `flat'
end

capture program drop _fu_clear_stem
program define _fu_clear_stem
    version 17.0
    args stem
    foreach e in xlsx csv md {
        capture erase "`stem'.`e'"
    }
end

* CRC and length of a file, as one string.
capture program drop _fu_sum
program define _fu_sum, rclass
    version 17.0
    args path
    quietly checksum "`path'"
    return local sum "`r(checksum)':`r(filelen)'"
end

mata:
// A "<kind> <cell> <text>" (xlsx_facts) or "<tag><TAB><text>" (md_facts)
// line whose text is want.
real scalar _fu_facts_has(string scalar path, string scalar kind, string scalar want)
{
    string colvector lines
    string scalar s, pre
    real scalar i, p

    lines = cat(path)
    for (i = 1; i <= rows(lines); i++) {
        s = lines[i]
        if (kind == "value") {
            pre = "value "
            if (substr(s, 1, strlen(pre)) != pre) continue
            s = substr(s, strlen(pre) + 1, .)
            p = strpos(s, " ")
            if (p == 0) continue
            if (substr(s, p + 1, .) == want) return(1)
        }
        else if (s == kind + char(9) + want) return(1)
    }
    return(0)
}

// Any comma-separated field of any line of the file, unquoted, equals want.
real scalar _fu_csv_field(string scalar path, string scalar want)
{
    string colvector lines
    string rowvector f
    string scalar x
    real scalar i, j

    lines = cat(path)
    for (i = 1; i <= rows(lines); i++) {
        f = tokens(lines[i], ",")
        for (j = 1; j <= cols(f); j++) {
            x = strtrim(f[j])
            if (strlen(x) >= 2 & substr(x, 1, 1) == char(34) & substr(x, -1, 1) == char(34)) {
                x = substr(x, 2, strlen(x) - 2)
            }
            if (x == want) return(1)
        }
    }
    return(0)
}

// A CSV row whose first field is want and whose other fields are empty.
real scalar _fu_csv_line(string scalar path, string scalar want)
{
    string colvector lines
    string scalar s
    real scalar i

    lines = cat(path)
    for (i = 1; i <= rows(lines); i++) {
        s = lines[i]
        while (strlen(s) > 0 & substr(s, -1, 1) == ",") s = substr(s, 1, strlen(s) - 1)
        if (strlen(s) >= 2 & substr(s, 1, 1) == char(34) & substr(s, -1, 1) == char(34)) {
            s = subinstr(substr(s, 2, strlen(s) - 2), char(34) + char(34), char(34))
        }
        if (s == want) return(1)
    }
    return(0)
}
end

**# F1 xtgee on the ratio scale of its family and link

* Clustered data with a binary outcome for logit/log links and a count.
capture program drop _fu_geedata
program define _fu_geedata
    version 17.0
    clear
    set seed 20260927
    quietly set obs 400
    generate id = ceil(_n / 4)
    generate x1 = runiform()
    generate x2 = rnormal()
    generate yb = runiform() < exp(-2 + 0.5 * x1 + 0.1 * x2)
    generate yc = rpoisson(exp(0.5 + 0.3 * x1))
end

* F1a: binomial/logit -> OR, exponentiated, intercept suppressed; eform
* honoured; keepintercept exponentiates the intercept; methods noun follows
capture noisily {
    _fu_geedata
    collect clear
    quietly collect: xtgee yb x1 x2, family(binomial) link(logit) i(id)
    local b1 = _b[x1]
    local b2 = _b[x2]
    local b0 = _b[_cons]
    capture frame drop _fu1
    quietly regtab, frame(_fu1, replace)
    local meth `"`r(methods)'"'
    _fu_hdr _fu1 c1
    assert "`r(h)'" == "OR"
    _fu_is _fu1 "x1" c1 `=exp(`b1')'
    _fu_is _fu1 "x2" c1 `=exp(`b2')'
    _fu_nrow _fu1 "Intercept"
    assert r(n) == 0
    _fu_methods `"`meth'"' "Odds ratios with 95% confidence intervals from multivariable generalized estimating equation (GEE) logistic regression."

    capture frame drop _fu1
    quietly regtab, frame(_fu1, replace) keepintercept
    _fu_is _fu1 "Intercept" c1 `=exp(`b0')'

    collect clear
    quietly collect: xtgee yb x1 x2, family(binomial) link(logit) i(id) eform
    capture frame drop _fu1
    quietly regtab, frame(_fu1, replace)
    _fu_hdr _fu1 c1
    assert "`r(h)'" == "OR"
    _fu_is _fu1 "x1" c1 `=exp(`b1')'
    _fu_nrow _fu1 "Intercept"
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: F1a xtgee binomial/logit shown as OR"
    local ++pass_count
}
else {
    display as error "  FAIL: F1a xtgee binomial/logit (rc=`=_rc')"
    local ++fail_count
}

* F1b: poisson/log -> IRR
capture noisily {
    _fu_geedata
    collect clear
    quietly collect: xtgee yc x1 x2, family(poisson) link(log) i(id)
    local b1 = _b[x1]
    capture frame drop _fu1
    quietly regtab, frame(_fu1, replace)
    local meth `"`r(methods)'"'
    _fu_hdr _fu1 c1
    assert "`r(h)'" == "IRR"
    _fu_is _fu1 "x1" c1 `=exp(`b1')'
    _fu_nrow _fu1 "Intercept"
    assert r(n) == 0
    _fu_methods `"`meth'"' "Incidence rate ratios with 95% confidence intervals from multivariable generalized estimating equation (GEE) Poisson regression."
}
if _rc == 0 {
    display as result "  PASS: F1b xtgee poisson/log shown as IRR"
    local ++pass_count
}
else {
    display as error "  FAIL: F1b xtgee poisson/log (rc=`=_rc')"
    local ++fail_count
}

* F1c: binomial/log stays Coef. with its intercept, as glm; with eform it is
* RR on the exponentiated scale
capture noisily {
    _fu_geedata
    collect clear
    quietly collect: xtgee yb x1 x2, family(binomial) link(log) i(id)
    local b1 = _b[x1]
    local b0 = _b[_cons]
    capture frame drop _fu1
    quietly regtab, frame(_fu1, replace)
    _fu_hdr _fu1 c1
    assert "`r(h)'" == "Coef."
    _fu_is _fu1 "x1" c1 `b1'
    _fu_is _fu1 "Intercept" c1 `b0'

    collect clear
    quietly collect: xtgee yb x1 x2, family(binomial) link(log) i(id) eform
    capture frame drop _fu1
    quietly regtab, frame(_fu1, replace)
    local meth `"`r(methods)'"'
    _fu_hdr _fu1 c1
    assert "`r(h)'" == "RR"
    _fu_is _fu1 "x1" c1 `=exp(`b1')'
    _fu_nrow _fu1 "Intercept"
    assert r(n) == 0
    _fu_methods `"`meth'"' "Risk ratios with 95% confidence intervals from multivariable generalized estimating equation (GEE) log-binomial regression."
}
if _rc == 0 {
    display as result "  PASS: F1c xtgee binomial/log Coef. (RR under eform)"
    local ++pass_count
}
else {
    display as error "  FAIL: F1c xtgee binomial/log (rc=`=_rc')"
    local ++fail_count
}

* F1d: every family/link gets the header glm gets with the same options
capture noisily {
    _fu_geedata
    local s1 "family(binomial) link(logit)"
    local s2 "family(poisson) link(log)"
    local s3 "family(binomial) link(log)"
    local s4 "family(binomial) link(logit) eform"
    local s5 "family(binomial) link(log) eform"
    local s6 "family(gaussian)"
    local s7 "fam(bin) ef"
    local s8 "family(nbinomial) link(log)"
    local s9 "family(nbinomial) link(log) eform"
    local s10 "family(binomial) link(probit)"
    local s11 "family(poisson) eform"
    forvalues s = 1/11 {
        local spec `"`s`s''"'
        local y yb
        if strpos("`spec'", "poisson") | strpos("`spec'", "nbin") local y yc
        foreach c in glm xtgee {
            collect clear
            if "`c'" == "xtgee" quietly collect: xtgee `y' x1 x2, `spec' i(id)
            else quietly collect: glm `y' x1 x2, `spec'
            capture frame drop _fu1
            quietly regtab, frame(_fu1, replace)
            _fu_hdr _fu1 c1
            local h_`c' "`r(h)'"
            _fu_nrow _fu1 "Intercept"
            local i_`c' = r(n)
        }
        display as text "  `spec': glm `h_glm' (intercept rows `i_glm'), xtgee `h_xtgee' (intercept rows `i_xtgee')"
        assert "`h_xtgee'" == "`h_glm'"
        assert `i_xtgee' == `i_glm'
    }
}
if _rc == 0 {
    display as result "  PASS: F1d xtgee header and intercept rule match glm for 11 family/link specs"
    local ++pass_count
}
else {
    display as error "  FAIL: F1d xtgee vs glm (rc=`=_rc')"
    local ++fail_count
}

**# F2 nbreg + zip with keepintercept

capture noisily {
    webuse fish, clear
    quietly nbreg count persons livebait
    matrix bn = e(b)
    quietly zip count persons livebait, inflate(child camper)
    matrix bz = e(b)
    local lna = bn[1, colnumb(bn, "/:lnalpha")]
    foreach order in "nbreg zip" "zip nbreg" {
        collect clear
        foreach c of local order {
            if "`c'" == "zip" quietly collect: zip count persons livebait, inflate(child camper)
            else quietly collect: nbreg count persons livebait
        }
        local cn = cond("`: word 1 of `order''" == "nbreg", "c1", "c4")
        local cz = cond("`cn'" == "c1", "c4", "c1")
        capture frame drop _fu2
        quietly regtab, frame(_fu2, replace) keepintercept
        _fu_is _fu2 "Ancillary: lnalpha" `cn' `lna'
        _fu_is _fu2 "Ancillary: alpha" `cn' `=exp(`lna')'
        _fu_cell _fu2 "Ancillary: lnalpha" `cz'
        assert `"`r(cell)'"' == ""
        _fu_cell _fu2 "Ancillary: alpha" `cz'
        assert `"`r(cell)'"' == ""
        _fu_is _fu2 "Inflation equation: Number of children accompanying the visitor" `cz' `=bz[1, colnumb(bz, "inflate:child")]'
        _fu_is _fu2 "Inflation equation: 1 if visitor is camping" `cz' `=bz[1, colnumb(bz, "inflate:camper")]'
        _fu_is _fu2 "Inflation equation: Intercept" `cz' `=bz[1, colnumb(bz, "inflate:_cons")]'
        _fu_cell _fu2 "Inflation equation: 1 if visitor is camping" `cn'
        assert `"`r(cell)'"' == ""
        _fu_is _fu2 "Number of fish caught: Number of persons accompanying the visitor" `cn' `=exp(bn[1, colnumb(bn, "count:persons")])'
        _fu_is _fu2 "Number of fish caught: Number of persons accompanying the visitor" `cz' `=bz[1, colnumb(bz, "count:persons")]'

        * without keepintercept both blocks drop their ancillary/intercept rows
        capture frame drop _fu2
        quietly regtab, frame(_fu2, replace)
        foreach r in "Ancillary: lnalpha" "Ancillary: alpha" "Inflation equation: Intercept" {
            _fu_nrow _fu2 "`r'"
            assert r(n) == 0
        }
        _fu_is _fu2 "Inflation equation: 1 if visitor is camping" `cz' `=bz[1, colnumb(bz, "inflate:camper")]'
    }
}
if _rc == 0 {
    display as result "  PASS: F2 nbreg + zip keep ancillary and inflation rows per model"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 nbreg + zip keepintercept (rc=`=_rc')"
    local ++fail_count
}

**# F3 title and footnote text is never macro-expanded

* The texts are built from char() codes, so this file never spells a macro
* reference the do-file itself would expand. Each holds a local-macro
* reference, a global reference to a global that exists, an unbalanced
* backtick and an underscore.
global TT_F3_SENTINEL "EXPANDED"
local T = "F3 title " + char(96) + "dose" + char(39) + " " + char(36) + "TT_F3_SENTINEL " + char(96) + "a_b" + char(39) + " z" + char(96) + "q" + char(96) + " end"
local F = "F3 note " + char(96) + "arm" + char(39) + " " + char(36) + "TT_F3_SENTINEL" + char(39) + "s end"
mata: st_global("FU_T", st_local("T"))
mata: st_global("FU_F", st_local("F"))
* corrtab's flat sinks: the footnote, then its generated star legend
mata: st_global("FU_FS", st_local("F") + "; * p<0.05, ** p<0.01, *** p<0.001")

* regtab
capture noisily {
    local stem "`output_dir'/fu_f3_regtab"
    _fu_clear_stem "`stem'"
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    quietly regtab, xlsx("`stem'.xlsx") sheet("F3") csv("`stem'.csv") markdown("`stem'.md") ///
        title(`"`macval(T)'"') footnote(`"`macval(F)'"')
    _fu_sinks_have "`stem'" "F3"
}
if _rc == 0 {
    display as result "  PASS: F3 regtab title/footnote intact in xlsx, CSV and Markdown"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 regtab title/footnote (rc=`=_rc')"
    local ++fail_count
}

* effecttab (from() matrix)
capture noisily {
    local stem "`output_dir'/fu_f3_effecttab"
    _fu_clear_stem "`stem'"
    matrix fum = (1.5, 0.8, 2.2, 0.03)
    matrix rownames fum = Treated
    quietly effecttab, from(fum) xlsx("`stem'.xlsx") sheet("F3") csv("`stem'.csv") markdown("`stem'.md") ///
        title(`"`macval(T)'"') footnote(`"`macval(F)'"')
    _fu_sinks_have "`stem'" "F3"
}
if _rc == 0 {
    display as result "  PASS: F3 effecttab title/footnote intact in xlsx, CSV and Markdown"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 effecttab title/footnote (rc=`=_rc')"
    local ++fail_count
}

* desctab, and table1_tc (which forwards its command line to desctab)
capture noisily {
    local stem "`output_dir'/fu_f3_desctab"
    _fu_clear_stem "`stem'"
    sysuse auto, clear
    quietly desctab price mpg, by(foreign) xlsx("`stem'.xlsx") sheet("F3") csv("`stem'.csv") markdown("`stem'.md") ///
        title(`"`macval(T)'"') footnote(`"`macval(F)'"')
    _fu_sinks_have "`stem'" "F3"
    local stem "`output_dir'/fu_f3_table1"
    _fu_clear_stem "`stem'"
    quietly table1_tc price mpg, by(foreign) excel("`stem'.xlsx") sheet("F3") csv("`stem'.csv") markdown("`stem'.md") ///
        title(`"`macval(T)'"') footnote(`"`macval(F)'"')
    _fu_sinks_have "`stem'" "F3"
}
if _rc == 0 {
    display as result "  PASS: F3 desctab/table1_tc title/footnote intact in xlsx, CSV and Markdown"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 desctab/table1_tc title/footnote (rc=`=_rc')"
    local ++fail_count
}

* crosstab
capture noisily {
    local stem "`output_dir'/fu_f3_crosstab"
    _fu_clear_stem "`stem'"
    sysuse auto, clear
    quietly crosstab rep78 foreign, xlsx("`stem'.xlsx") sheet("F3") csv("`stem'.csv") markdown("`stem'.md") ///
        title(`"`macval(T)'"') footnote(`"`macval(F)'"')
    _fu_sinks_have "`stem'" "F3"
}
if _rc == 0 {
    display as result "  PASS: F3 crosstab title/footnote intact in xlsx, CSV and Markdown"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 crosstab title/footnote (rc=`=_rc')"
    local ++fail_count
}

* corrtab
capture noisily {
    local stem "`output_dir'/fu_f3_corrtab"
    _fu_clear_stem "`stem'"
    sysuse auto, clear
    quietly corrtab price mpg weight, xlsx("`stem'.xlsx") sheet("F3") csv("`stem'.csv") markdown("`stem'.md") ///
        title(`"`macval(T)'"') footnote(`"`macval(F)'"')
    _fu_sinks_have "`stem'" "F3" FS
}
if _rc == 0 {
    display as result "  PASS: F3 corrtab title/footnote intact in xlsx, CSV and Markdown"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 corrtab title/footnote (rc=`=_rc')"
    local ++fail_count
}

* survtab
capture noisily {
    local stem "`output_dir'/fu_f3_survtab"
    _fu_clear_stem "`stem'"
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    quietly survtab, times(10) xlsx("`stem'.xlsx") sheet("F3") csv("`stem'.csv") markdown("`stem'.md") ///
        title(`"`macval(T)'"') footnote(`"`macval(F)'"')
    _fu_sinks_have "`stem'" "F3"
}
if _rc == 0 {
    display as result "  PASS: F3 survtab title/footnote intact in xlsx, CSV and Markdown"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 survtab title/footnote (rc=`=_rc')"
    local ++fail_count
}

* stratetab
capture noisily {
    local stem "`output_dir'/fu_f3_stratetab"
    local rate "`output_dir'/fu_f3_rate"
    _fu_clear_stem "`stem'"
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    quietly strate, output("`rate'", replace)
    quietly stratetab, using("`rate'") outcomes(1) xlsx("`stem'.xlsx") sheet("F3") csv("`stem'.csv") markdown("`stem'.md") ///
        title(`"`macval(T)'"') footnote(`"`macval(F)'"')
    _fu_sinks_have "`stem'" "F3"
}
if _rc == 0 {
    display as result "  PASS: F3 stratetab title/footnote intact in xlsx, CSV and Markdown"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 stratetab title/footnote (rc=`=_rc')"
    local ++fail_count
}

* comptab, and hrcomptab (which forwards its options to comptab)
capture noisily {
    local stem "`output_dir'/fu_f3_comptab"
    _fu_clear_stem "`stem'"
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    quietly regtab, frame(fu_f1, replace)
    quietly comptab fu_f1, rows(1) xlsx("`stem'.xlsx") sheet("F3") csv("`stem'.csv") markdown("`stem'.md") ///
        title(`"`macval(T)'"') footnote(`"`macval(F)'"')
    _fu_sinks_have "`stem'" "F3"
    frame drop fu_f1

    local stem "`output_dir'/fu_f3_hrcomptab"
    local rate "`output_dir'/fu_f3_rate_drug"
    _fu_clear_stem "`stem'"
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    quietly strate drug, output("`rate'", replace)
    quietly stratetab, using("`rate'") outcomes(1) frame(fu_rates, replace) ///
        outlabels("Death") explabels("Drug")
    collect clear
    quietly collect: stcox i.drug, nolog
    quietly regtab, models("Death") frame(fu_hrm, replace) noint
    quietly hrcomptab fu_rates, modelframes(fu_hrm) rows(3/4) effect("HR") outcomemap("Death") ///
        xlsx("`stem'.xlsx") sheet("F3") csv("`stem'.csv") markdown("`stem'.md") ///
        title(`"`macval(T)'"') footnote(`"`macval(F)'"')
    _fu_sinks_have "`stem'" "F3"
    frame drop fu_rates
    frame drop fu_hrm
}
if _rc == 0 {
    display as result "  PASS: F3 comptab/hrcomptab title/footnote intact in xlsx, CSV and Markdown"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 comptab/hrcomptab title/footnote (rc=`=_rc')"
    local ++fail_count
}

* puttab
capture noisily {
    local stem "`output_dir'/fu_f3_puttab"
    _fu_clear_stem "`stem'"
    sysuse auto, clear
    quietly puttab make price in 1/3 using "`stem'.xlsx", sheet("F3") csv("`stem'.csv") markdown("`stem'.md") ///
        title(`"`macval(T)'"') footnote(`"`macval(F)'"')
    _fu_sinks_have "`stem'" "F3"
}
if _rc == 0 {
    display as result "  PASS: F3 puttab title/footnote intact in xlsx, CSV and Markdown"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 puttab title/footnote (rc=`=_rc')"
    local ++fail_count
}

* stacktab (blocks read from a seeded workbook)
capture noisily {
    local stem "`output_dir'/fu_f3_stacktab"
    _fu_clear_stem "`stem'"
    quietly putexcel set "`stem'.xlsx", sheet("Src") replace
    quietly putexcel A1 = "Label" B1 = "Value" A2 = "Row one" B2 = "1.0"
    quietly putexcel close
    quietly stacktab using "`stem'.xlsx", blocks(sheet(Src) rows(1/2) cols(A-B)) sheet("F3") ///
        csv("`stem'.csv") markdown("`stem'.md") title(`"`macval(T)'"') footnote(`"`macval(F)'"')
    _fu_sinks_have "`stem'" "F3"
}
if _rc == 0 {
    display as result "  PASS: F3 stacktab title/footnote intact in xlsx, CSV and Markdown"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 stacktab title/footnote (rc=`=_rc')"
    local ++fail_count
}

* The documented limit: text ending in a backtick cannot pass inside
* compound quotes. The call stops with r(198) before anything is written.
capture noisily {
    local stem "`output_dir'/fu_f3_limit"
    _fu_clear_stem "`stem'"
    local E = "ends in a backtick " + char(96)
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    capture noisily regtab, markdown("`stem'.md") title(`"`macval(E)'"')
    assert _rc == 198
    capture confirm file "`stem'.md"
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: F3 known limit: a title ending in a backtick stops with r(198), nothing written"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 known limit (rc=`=_rc')"
    local ++fail_count
}

**# F4 effecttab from() headers

capture noisily {
    matrix fum = (1.5, 0.8, 2.2, 0.03)
    matrix rownames fum = Treated
    capture frame drop _fu4
    quietly effecttab, from(fum) frame(_fu4, replace)
    * the header row is the row above the first estimate (row 3)
    frame _fu4 {
        assert strtrim(A[4]) == "Treated"
        assert strtrim(c2[3]) == "95% CI"
        assert strtrim(c3[3]) == "p-value"
    }
    capture frame drop _fu4
    quietly effecttab, from(fum) frame(_fu4, replace) level(90)
    frame _fu4: assert strtrim(c2[3]) == "90% CI"

    * the collect path's own header text, for the same kind of table
    webuse cattaneo2, clear
    collect clear
    quietly collect: teffects ra (bweight mage) (mbsmoke)
    capture frame drop _fu4
    quietly effecttab, frame(_fu4, replace)
    frame _fu4 {
        assert strtrim(c2[3]) == "95% CI"
        assert strtrim(c3[3]) == "p-value"
    }
}
if _rc == 0 {
    display as result "  PASS: F4 effecttab from() headers match the collect path"
    local ++pass_count
}
else {
    display as error "  FAIL: F4 effecttab from() headers (rc=`=_rc')"
    local ++fail_count
}

**# F6 a failed Markdown write leaves the target and no staging file

* Files in the target's directory, and this process's files in c(tmpdir),
* each as one sorted string.
capture program drop _fu_ls
program define _fu_ls, rclass
    version 17.0
    args dir
    local f : dir "`dir'" files "*", respectcase
    local d : dir "`dir'" dirs "*", respectcase
    local f : list sort f
    local d : list sort d
    * only this Stata process's own tempfiles (St<pid>.*): another Stata
    * session may share c(tmpdir)
    tempfile probe
    mata: st_local("pfx", pathbasename(st_local("probe")))
    local pfx = substr("`pfx'", 1, strpos("`pfx'", "."))
    local t : dir "`c(tmpdir)'" files "`pfx'*", respectcase
    local t : list sort t
    return local here `"`f' | `d'"'
    return local tmp `"`t'"'
end

* Run the write in `0' against `target' in `dir'; it must fail, and leave the
* target byte-identical and no file added to the directory or to c(tmpdir).
capture program drop _fu_failwrite
program define _fu_failwrite
    version 17.0
    gettoken dir 0 : 0
    gettoken target 0 : 0
    _fu_sum "`target'"
    local s0 "`r(sum)'"
    _fu_ls "`dir'"
    local h0 `"`r(here)'"'
    local t0 `"`r(tmp)'"'
    capture noisily `0'
    local wrc = _rc
    _fu_sum "`target'"
    local s1 "`r(sum)'"
    _fu_ls "`dir'"
    display as text "  write rc=`wrc'; checksum `s0' -> `s1'"
    assert `wrc' != 0
    assert "`s1'" == "`s0'"
    assert `"`r(here)'"' == `"`h0'"'
    assert `"`r(tmp)'"' == `"`t0'"'
end

capture noisily {
    local d "`output_dir'/fu_f6"
    shell chmod -R u+w "`d'" 2>/dev/null; rm -rf "`d'"
    mkdir "`d'"
    local t "`d'/target.md"
    tempname fh
    file open `fh' using "`t'", write text
    file write `fh' "PRIOR CONTENT" _n
    file close `fh'
    clear
    quietly set obs 3
    generate str10 A = "r" + string(_n)
    generate str10 B = "v" + string(_n)

    * read-only target: replace and append
    shell chmod 444 "`t'"
    _fu_failwrite "`d'" "`t'" _tabtools_markdown_write using "`t'", datastart(1)
    _fu_failwrite "`d'" "`t'" _tabtools_markdown_write using "`t'", datastart(1) append
    * read-only target in a read-only directory
    shell chmod 555 "`d'"
    _fu_failwrite "`d'" "`t'" _tabtools_markdown_write using "`t'", datastart(1)
    _fu_failwrite "`d'" "`t'" _tabtools_markdown_write using "`t'", datastart(1) append
    shell chmod 755 "`d'"
    * the same through a command, with a title
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    _fu_failwrite "`d'" "`t'" regtab, markdown("`t'") title("F6")
    _fu_failwrite "`d'" "`t'" regtab, markdown("`t'") mdappend
    shell chmod 644 "`t'"
    * the target is a directory
    mkdir "`d'/dir.md"
    _fu_failwrite "`d'" "`t'" regtab, markdown("`d'/dir.md")
    local inside : dir "`d'/dir.md" files "*"
    assert `"`inside'"' == ""
    * control: the same call on a writable target replaces it
    quietly regtab, markdown("`t'") title("F6")
    mata: st_local("l1", cat(st_local("t"))[1])
    assert "`l1'" == "### F6"
}
local f6_rc = _rc
capture shell chmod -R u+w "`output_dir'/fu_f6"
if `f6_rc' == 0 {
    display as result "  PASS: F6 failed Markdown writes leave the target and no staging file"
    local ++pass_count
}
else {
    display as error "  FAIL: F6 failed Markdown write (rc=`f6_rc')"
    local ++fail_count
}

**# F7 csv() paths are validated before anything is written

capture noisily {
    local good "`output_dir'/fu_f7_good"
    _fu_clear_stem "`good'"
    local bad "`output_dir'/fu_f7;bad.csv"
    sysuse auto, clear
    capture noisily crosstab rep78 foreign, csv("`bad'")
    local ref_rc = _rc
    assert `ref_rc' == 198

    collect clear
    quietly collect: regress price mpg
    capture frame drop _fu7
    capture noisily regtab, csv("`bad'") xlsx("`good'.xlsx") markdown("`good'.md") frame(_fu7)
    assert _rc == `ref_rc'
    capture confirm file "`good'.xlsx"
    assert _rc == 601
    capture confirm file "`good'.md"
    assert _rc == 601
    capture frame _fu7: describe
    assert _rc != 0
    capture confirm file "`bad'"
    assert _rc == 601

    matrix fum = (1.5, 0.8, 2.2, 0.03)
    matrix rownames fum = Treated
    capture noisily effecttab, from(fum) csv("`bad'") xlsx("`good'.xlsx") markdown("`good'.md") frame(_fu7)
    assert _rc == `ref_rc'
    capture confirm file "`good'.xlsx"
    assert _rc == 601
    capture confirm file "`good'.md"
    assert _rc == 601
    capture frame _fu7: describe
    assert _rc != 0

    * a pipe as well
    capture noisily regtab, csv("`output_dir'/fu_f7|bad.csv")
    assert _rc == `ref_rc'
    capture noisily effecttab, from(fum) csv("`output_dir'/fu_f7|bad.csv")
    assert _rc == `ref_rc'
}
if _rc == 0 {
    display as result "  PASS: F7 regtab/effecttab refuse a bad csv() path up front (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: F7 csv() path validation (rc=`=_rc')"
    local ++fail_count
}

**# F8 a covariate named like its own model's ancillary parameter

* F8a: nbreg with a covariate named alpha. Both rows are shown: the covariate
* (IRR) and the derived ancillary alpha (its own value); labelling the
* covariate must not relabel the ancillary row.
capture noisily {
    webuse rod93, clear
    generate alpha = age_mos / 100
    collect clear
    quietly collect: nbreg deaths alpha
    matrix b = e(b)
    local bc = b[1, colnumb(b, "deaths:alpha")]
    local b0 = b[1, colnumb(b, "deaths:_cons")]
    local lna = b[1, colnumb(b, "/:lnalpha")]
    quietly collect levelsof colname
    local lev0 `"`s(levels)'"'
    capture frame drop _fu8
    quietly regtab, frame(_fu8, replace)
    _fu_nbody _fu8
    assert r(n) == 1
    _fu_row _fu8 1 "alpha" c1 `=exp(`bc')'
    capture frame drop _fu8
    quietly regtab, frame(_fu8, replace) keepintercept
    _fu_nbody _fu8
    assert r(n) == 4
    _fu_row _fu8 1 "alpha" c1 `=exp(`bc')'
    _fu_row _fu8 2 "lnalpha" c1 `lna'
    _fu_row _fu8 3 "alpha" c1 `=exp(`lna')'
    _fu_row _fu8 4 "Intercept" c1 `=exp(`b0')'
    * the collection is left as it was
    quietly collect levelsof colname
    assert `"`s(levels)'"' == `"`lev0'"'

    label variable alpha "Age (months/100)"
    collect clear
    quietly collect: nbreg deaths alpha
    capture frame drop _fu8
    quietly regtab, frame(_fu8, replace) keepintercept
    _fu_row _fu8 1 "Age (months/100)" c1 `=exp(`bc')'
    _fu_row _fu8 2 "lnalpha" c1 `lna'
    _fu_row _fu8 3 "alpha" c1 `=exp(`lna')'
    * a second regtab on the same collection gives the same table
    capture frame drop _fu8b
    quietly regtab, frame(_fu8b, replace) keepintercept
    frame _fu8: local a3 = strtrim(A[6]) + "|" + strtrim(c1[6])
    frame _fu8b: local b3 = strtrim(A[6]) + "|" + strtrim(c1[6])
    assert "`a3'" == "`b3'"
}
if _rc == 0 {
    display as result "  PASS: F8a nbreg covariate alpha shown beside the ancillary alpha"
    local ++pass_count
}
else {
    display as error "  FAIL: F8a nbreg covariate alpha (rc=`=_rc')"
    local ++fail_count
}

* F8b: two nbreg models, only the first with a covariate named alpha: the
* ancillary rows are shared, the covariate row is blank in model 2
capture noisily {
    webuse rod93, clear
    generate alpha = age_mos / 100
    collect clear
    quietly collect: nbreg deaths alpha
    matrix b1 = e(b)
    quietly collect: nbreg deaths age_mos
    matrix b2 = e(b)
    capture frame drop _fu8
    quietly regtab, frame(_fu8, replace) keepintercept
    _fu_row _fu8 1 "alpha" c1 `=exp(b1[1, colnumb(b1, "deaths:alpha")])'
    _fu_row _fu8 1 "alpha" c4 ""
    local lna1 = b1[1, colnumb(b1, "/:lnalpha")]
    local lna2 = b2[1, colnumb(b2, "/:lnalpha")]
    _fu_is _fu8 "lnalpha" c1 `lna1'
    _fu_is _fu8 "lnalpha" c4 `lna2'
    frame _fu8 {
        quietly count if strtrim(A) == "alpha" & _n >= 4
        assert r(N) == 2
        quietly generate long _r = _n
        quietly summarize _r if strtrim(A) == "alpha" & _n >= 4
        local ra = r(max)
    }
    _fu_fmt `=exp(`lna1')'
    frame _fu8: assert strtrim(c1[`ra']) == "`r(s)'"
    _fu_fmt `=exp(`lna2')'
    frame _fu8: assert strtrim(c4[`ra']) == "`r(s)'"
}
if _rc == 0 {
    display as result "  PASS: F8b ancillary alpha shared across nbreg models"
    local ++pass_count
}
else {
    display as error "  FAIL: F8b shared ancillary row (rc=`=_rc')"
    local ++fail_count
}

* F8c: Weibull with a covariate named ln_p (hazard metric, HR)
capture noisily {
    webuse kva, clear
    quietly stset failtime
    generate ln_p = load / 10
    collect clear
    quietly collect: streg ln_p bearings, distribution(weibull)
    matrix b = e(b)
    local bc = b[1, colnumb(b, "_t:ln_p")]
    local bb = b[1, colnumb(b, "_t:bearings")]
    local b0 = b[1, colnumb(b, "_t:_cons")]
    local lnp = b[1, colnumb(b, "/:ln_p")]
    capture frame drop _fu8
    quietly regtab, frame(_fu8, replace)
    _fu_nbody _fu8
    assert r(n) == 2
    _fu_row _fu8 1 "ln_p" c1 `=exp(`bc')'
    _fu_row _fu8 2 "Has new bearings" c1 `=exp(`bb')'
    capture frame drop _fu8
    quietly regtab, frame(_fu8, replace) keepintercept
    _fu_nbody _fu8
    assert r(n) == 6
    _fu_row _fu8 1 "ln_p" c1 `=exp(`bc')'
    _fu_row _fu8 2 "Has new bearings" c1 `=exp(`bb')'
    _fu_row _fu8 3 "ln_p" c1 `lnp'
    _fu_row _fu8 4 "p" c1 `=exp(`lnp')'
    _fu_row _fu8 5 "1/p" c1 `=exp(-`lnp')'
    _fu_row _fu8 6 "Intercept" c1 `=exp(`b0')'
}
if _rc == 0 {
    display as result "  PASS: F8c Weibull covariate ln_p shown beside the ancillary ln_p"
    local ++pass_count
}
else {
    display as error "  FAIL: F8c Weibull covariate ln_p (rc=`=_rc')"
    local ++fail_count
}

* F8d: lognormal with a covariate named lnsigma (time metric, TR); lnsigma
* and sigma stay visible without keepintercept
capture noisily {
    webuse kva, clear
    quietly stset failtime
    generate lnsigma = load / 10
    collect clear
    quietly collect: streg lnsigma bearings, distribution(lognormal)
    matrix b = e(b)
    local bc = b[1, colnumb(b, "_t:lnsigma")]
    local bb = b[1, colnumb(b, "_t:bearings")]
    local b0 = b[1, colnumb(b, "_t:_cons")]
    local lns = b[1, colnumb(b, "/:lnsigma")]
    foreach ki in "" "keepintercept" {
        capture frame drop _fu8
        quietly regtab, frame(_fu8, replace) `ki'
        _fu_hdr _fu8 c1
        assert "`r(h)'" == "TR"
        _fu_nbody _fu8
        assert r(n) == cond("`ki'" == "", 4, 5)
        _fu_row _fu8 1 "lnsigma" c1 `=exp(`bc')'
        _fu_row _fu8 2 "Has new bearings" c1 `=exp(`bb')'
        _fu_row _fu8 3 "lnsigma" c1 `lns'
        _fu_row _fu8 4 "sigma" c1 `=exp(`lns')'
        if "`ki'" != "" _fu_row _fu8 5 "Intercept" c1 `=exp(`b0')'
    }
}
if _rc == 0 {
    display as result "  PASS: F8d lognormal covariate lnsigma shown beside the ancillary lnsigma"
    local ++pass_count
}
else {
    display as error "  FAIL: F8d lognormal covariate lnsigma (rc=`=_rc')"
    local ++fail_count
}

* F8e: ologit with a covariate named cut1
capture noisily {
    sysuse auto, clear
    generate cut1 = mpg
    collect clear
    quietly collect: ologit rep78 cut1 weight
    matrix b = e(b)
    local bc = b[1, colnumb(b, "rep78:cut1")]
    capture frame drop _fu8
    quietly regtab, frame(_fu8, replace)
    _fu_nbody _fu8
    assert r(n) == 2
    _fu_row _fu8 1 "cut1" c1 `=exp(`bc')'
    capture frame drop _fu8
    quietly regtab, frame(_fu8, replace) keepintercept
    _fu_nbody _fu8
    assert r(n) == 6
    _fu_row _fu8 1 "cut1" c1 `=exp(`bc')'
    forvalues k = 1/4 {
        _fu_row _fu8 `=`k' + 2' "cut`k'" c1 `=b[1, colnumb(b, "/:cut`k'")]'
    }
    * cutlabels() names the cutpoints, never the covariate cut1
    capture frame drop _fu8
    quietly regtab, frame(_fu8, replace) keepintercept cutlabels("c1 \ c2 \ c3 \ c4")
    _fu_row _fu8 1 "cut1" c1 `=exp(`bc')'
    forvalues k = 1/4 {
        _fu_row _fu8 `=`k' + 2' "c`k'" c1 `=b[1, colnumb(b, "/:cut`k'")]'
    }
    * keep() by name selects both rows named cut1
    capture frame drop _fu8
    quietly regtab, frame(_fu8, replace) keepintercept keep(cut1)
    _fu_nbody _fu8
    assert r(n) == 2
    _fu_row _fu8 1 "cut1" c1 `=exp(`bc')'
    _fu_row _fu8 2 "cut1" c1 `=b[1, colnumb(b, "/:cut1")]'
}
if _rc == 0 {
    display as result "  PASS: F8e ologit covariate cut1 shown beside the cutpoints"
    local ++pass_count
}
else {
    display as error "  FAIL: F8e ologit covariate cut1 (rc=`=_rc')"
    local ++fail_count
}

**# F9 confidence levels shown as typed

* Some CSV field equals `want' exactly.
capture program drop _fu_csv_field_is
program define _fu_csv_field_is
    version 17.0
    args path want
    mata: st_local("ok", strofreal(_fu_csv_field(st_local("path"), st_local("want"))))
    if `ok' != 1 {
        display as error `"csv `path': no field "`want'""'
        type "`path'"
        exit 9
    }
end

* The frame characteristic tabtools_ci_level equals `want'.
capture program drop _fu_char_is
program define _fu_char_is
    version 17.0
    args frname want
    frame `frname': local c : char _dta[tabtools_ci_level]
    if `"`c'"' != `"`want'"' {
        display as error `"frame `frname' tabtools_ci_level: got "`c'", want "`want'""'
        exit 9
    }
end

* Some string cell of frame `frname' contains `text'.
capture program drop _fu_frame_has
program define _fu_frame_has
    version 17.0
    args frname text
    frame `frname' {
        local hit = 0
        quietly ds, has(type string)
        foreach v in `r(varlist)' {
            quietly count if strpos(`v', `"`text'"') > 0
            if r(N) > 0 local hit = 1
        }
    }
    if !`hit' {
        display as error `"frame `frname': no cell contains "`text'""'
        exit 9
    }
end

* F9a: regtab, with the level given and taken from the collection
capture noisily {
    local csvf "`output_dir'/fu_f9_regtab.csv"
    foreach v in 99.9 99.99 97.5 90 95 {
        sysuse auto, clear
        collect clear
        quietly collect: logit foreign mpg, level(`v')
        foreach how in given collected {
            local lopt = cond("`how'" == "given", "level(`v')", "")
            capture erase "`csvf'"
            capture frame drop _fu9
            capture frame drop _fu9e
            quietly regtab, `lopt' frame(_fu9, replace) eplotframe(_fu9e, replace) csv("`csvf'")
            local meth `"`r(methods)'"'
            assert reldif(r(ci_level), `v') < 1e-12
            frame _fu9: display as text "  regtab `how' level `v': header [" strtrim(c2[3]) "]"
            frame _fu9: assert strtrim(c2[3]) == "`v'% CI"
            assert strpos(`"`meth'"', "with `v'% confidence intervals") > 0
            _fu_csv_field_is "`csvf'" "`v'% CI"
            _fu_char_is _fu9 "`v'"
            _fu_char_is _fu9e "`v'"
        }
    }
}
if _rc == 0 {
    display as result "  PASS: F9a regtab levels 99.9/99.99/97.5/90/95 shown as typed"
    local ++pass_count
}
else {
    display as error "  FAIL: F9a regtab CI level text (rc=`=_rc')"
    local ++fail_count
}

* F9b: effecttab, collect path and from() matrix path
capture noisily {
    local csvf "`output_dir'/fu_f9_effecttab.csv"
    matrix fum = (1.5, 0.8, 2.2, 0.03)
    matrix rownames fum = Treated
    foreach v in 99.9 99.99 97.5 90 {
        webuse cattaneo2, clear
        collect clear
        quietly collect: teffects ra (bweight mage) (mbsmoke), level(`v')
        capture erase "`csvf'"
        capture frame drop _fu9
        capture frame drop _fu9e
        quietly effecttab, level(`v') frame(_fu9, replace) eplotframe(_fu9e, replace) csv("`csvf'")
        local meth `"`r(methods)'"'
        assert reldif(r(ci_level), `v') < 1e-12
        frame _fu9: assert strtrim(c2[3]) == "`v'% CI"
        assert strpos(`"`meth'"', "`v'% confidence intervals") > 0
        _fu_csv_field_is "`csvf'" "`v'% CI"
        _fu_char_is _fu9 "`v'"
        _fu_char_is _fu9e "`v'"

        capture erase "`csvf'"
        capture frame drop _fu9
        quietly effecttab, from(fum) level(`v') frame(_fu9, replace) csv("`csvf'")
        local meth `"`r(methods)'"'
        assert reldif(r(ci_level), `v') < 1e-12
        frame _fu9: assert strtrim(c2[3]) == "`v'% CI"
        assert strpos(`"`meth'"', "with `v'% confidence intervals") > 0
        _fu_csv_field_is "`csvf'" "`v'% CI"
        _fu_char_is _fu9 "`v'"
    }
}
if _rc == 0 {
    display as result "  PASS: F9b effecttab levels shown as typed (collect and from())"
    local ++pass_count
}
else {
    display as error "  FAIL: F9b effecttab CI level text (rc=`=_rc')"
    local ++fail_count
}

* F9c: stratetab, survtab and crosstab, with level() and with set level
capture noisily {
    local csvf "`output_dir'/fu_f9_other.csv"
    local rate "`output_dir'/fu_f9_rate"
    local lvl0 = c(level)
    foreach v in 99.9 99.99 97.5 90 {
        foreach how in option setlevel {
            local lopt ""
            if "`how'" == "option" local lopt "level(`v')"
            else set level `v'

            sysuse cancer, clear
            quietly stset studytime, failure(died)
            quietly strate drug, output("`rate'", replace) level(`v')
            capture erase "`csvf'"
            capture frame drop _fu9
            quietly stratetab, using("`rate'") outcomes(1) `lopt' frame(_fu9, replace) csv("`csvf'")
            assert reldif(r(ci_level), `v') < 1e-12
            _fu_char_is _fu9 "`v'"
            _fu_frame_has _fu9 "(`v'% CI)"

            sysuse cancer, clear
            quietly stset studytime, failure(died)
            capture erase "`csvf'"
            capture frame drop _fu9
            quietly survtab, times(10) by(drug) median `lopt' frame(_fu9, replace) csv("`csvf'")
            local meth `"`r(methods)'"'
            _fu_char_is _fu9 "`v'"
            assert strpos(`"`meth'"', "with `v'% confidence intervals") > 0
            frame _fu9 {
                quietly count if strtrim(c1) == "(`v'% CI)"
                assert r(N) >= 1
            }

            sysuse auto, clear
            generate byte hi = price > 6000
            capture frame drop _fu9
            quietly crosstab foreign hi, or `lopt' frame(_fu9, replace)
            local meth `"`r(methods)'"'
            assert reldif(r(ci_level), `v') < 1e-12
            _fu_char_is _fu9 "`v'"
            _fu_frame_has _fu9 "(`v'% CI: "
            assert strpos(`"`meth'"', "with a `v'% confidence interval") > 0
            set level `lvl0'
        }
    }
}
local f9c_rc = _rc
set level 95
if `f9c_rc' == 0 {
    display as result "  PASS: F9c stratetab/survtab/crosstab levels shown as typed (level() and set level)"
    local ++pass_count
}
else {
    display as error "  FAIL: F9c stratetab/survtab/crosstab CI level text (rc=`f9c_rc')"
    local ++fail_count
}

* F9d: hrcomptab composes a stratetab rate frame and a regtab model frame
capture noisily {
    local rate "`output_dir'/fu_f9_rate_h"
    foreach v in 99.9 99.99 90 {
        sysuse cancer, clear
        quietly stset studytime, failure(died)
        quietly strate drug, output("`rate'", replace) level(`v')
        capture frame drop fu9_rates
        quietly stratetab, using("`rate'") outcomes(1) frame(fu9_rates, replace) ///
            outlabels("Death") explabels("Drug") level(`v')
        collect clear
        quietly collect: stcox i.drug, nolog level(`v')
        capture frame drop fu9_hrm
        quietly regtab, models("Death") frame(fu9_hrm, replace) noint level(`v')
        capture frame drop _fu9
        quietly hrcomptab fu9_rates, modelframes(fu9_hrm) rows(3/4) effect("HR") ///
            outcomemap("Death") frame(_fu9, replace)
        assert reldif(r(ci_level), `v') < 1e-12
        _fu_frame_has _fu9 "HR (`v'% CI)"
        _fu_char_is _fu9 "`v'"
    }
    capture frame drop fu9_rates
    capture frame drop fu9_hrm
}
if _rc == 0 {
    display as result "  PASS: F9d hrcomptab level shown as typed"
    local ++pass_count
}
else {
    display as error "  FAIL: F9d hrcomptab CI level text (rc=`=_rc')"
    local ++fail_count
}

**# Summary
capture frame drop _fu1
capture frame drop _fu2
capture frame drop _fu4
capture frame drop _fu7
capture frame drop _fu8
capture frame drop _fu8b
capture frame drop _fu9
capture frame drop _fu9e
global TT_F3_SENTINEL
global FU_T
global FU_F
global FU_FS
global FU_TOOLS
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_followups_2026_09_27 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _fu
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_followups_2026_09_27 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _fu
