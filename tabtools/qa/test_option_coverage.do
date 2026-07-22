* test_option_coverage.do - exercise every public option of every command.
*
* Purpose: drive per-command OPTION coverage to 100% of the testable surface.
* An option counts as exercised only when it is passed in a REAL invocation of
* its own command (not merely mentioned somewhere in qa/). The companion
* analyzer qa/tools/option_coverage.py measures this and writes the diagnostic
* table in qa/README.md.
*
* The `open` option is exercised through guard-path invocations (open without
* an Excel target) so batch QA covers the parser branch without launching a GUI
* viewer.

clear all
set more off
set varabbrev off
* No `version` pin: the desctab setup uses `collect: table ..., statistic()`,
* which requires Stata 17+; pinning version 16 would select the legacy table.

capture log close _optcov
log using "test_option_coverage.log", replace text name(_optcov)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local out "`c(tmpdir)'/`c(pid)'_tabtools_optcov"
capture mkdir "`out'"

* markdown()/csv() (non-append) deliberately refuse to overwrite an existing
* file (clobber-guard; mdappend is the documented way to add). Erase prior-run
* targets up front so the suite is idempotent -- mirrors demo_tabtools.do.
foreach f in diagtab effecttab regtab table1 survtab puttab desctab simtab ///
             comptab hrcomptab stratetab stacktab {
    capture erase "`out'/`f'.md"
}
foreach f in comptab hrcomptab {
    capture erase "`out'/`f'.csv"
}

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""

capture program drop _oc_record
program define _oc_record
    args name rc
    if `rc' == 0 {
        display as result "  PASS: `name' option coverage"
        c_local _oc_ok = 1
    }
    else {
        display as error "  FAIL: `name' option coverage (rc=`rc')"
        c_local _oc_ok = 0
    }
end

* =====================================================================
**# corrtab: zebracolor
* =====================================================================
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, xlsx("`out'/corrtab.xlsx") sheet("S") zebra zebracolor("240 245 250")
    confirm file "`out'/corrtab.xlsx"
}
_oc_record "corrtab" `=_rc'
if `_oc_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' corrtab"
}

* =====================================================================
**# crosstab: excel, footnote, headercolor, headershade, theme, zebracolor
* =====================================================================
local ++test_count
capture noisily {
    sysuse auto, clear
    crosstab foreign rep78, excel("`out'/crosstab.xlsx") sheet("S") ///
        footnote("note") headercolor("200 220 240") headershade zebracolor("240 245 250")
    confirm file "`out'/crosstab.xlsx"
    crosstab foreign rep78, xlsx("`out'/crosstab2.xlsx") sheet("T") theme(apa)
    confirm file "`out'/crosstab2.xlsx"
}
_oc_record "crosstab" `=_rc'
if `_oc_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' crosstab"
}

* =====================================================================
**# diagtab: excel, footnote, markdown, mdappend, theme, zebracolor
* =====================================================================
local ++test_count
capture noisily {
    clear
    set obs 200
    set seed 71
    gen byte gold = (_n <= 100)
    gen byte test = runiform() < cond(gold, 0.8, 0.1)
    diagtab test gold, excel("`out'/diagtab.xlsx") sheet("S") footnote("note") ///
        theme(apa) zebracolor("240 245 250")
    confirm file "`out'/diagtab.xlsx"
    diagtab test gold, markdown("`out'/diagtab.md")
    confirm file "`out'/diagtab.md"
    diagtab test gold, markdown("`out'/diagtab.md") mdappend
}
_oc_record "diagtab" `=_rc'
if `_oc_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' diagtab"
}

* =====================================================================
**# effecttab: labelwidth, markdown, mdappend  (from-matrix path)
* =====================================================================
local ++test_count
capture noisily {
    sysuse auto, clear
    matrix mymat = (1.5, 0.8, 2.2, 0.04 \ 2.3, 1.1, 3.5, 0.001 \ -0.5, -1.2, 0.2, 0.15)
    matrix rownames mymat = Age Sex BMI
    effecttab, from(mymat) xlsx("`out'/effecttab.xlsx") sheet("S") ///
        effect("OR") labelwidth(20)
    confirm file "`out'/effecttab.xlsx"
    effecttab, from(mymat) markdown("`out'/effecttab.md") effect("OR")
    confirm file "`out'/effecttab.md"
    effecttab, from(mymat) markdown("`out'/effecttab.md") mdappend effect("OR")
}
_oc_record "effecttab" `=_rc'
if `_oc_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' effecttab"
}

* =====================================================================
**# regtab: markdown, mdappend
* =====================================================================
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, markdown("`out'/regtab.md") noint
    confirm file "`out'/regtab.md"
    collect clear
    collect: regress price mpg weight
    regtab, markdown("`out'/regtab.md") mdappend noint
}
_oc_record "regtab" `=_rc'
if `_oc_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' regtab"
}

* =====================================================================
**# table1_tc: mdappend, spacelowpercent
* =====================================================================
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc price mpg foreign, by(foreign) ///
        markdown("`out'/table1.md") spacelowpercent clear
    confirm file "`out'/table1.md"
    sysuse auto, clear
    table1_tc price mpg foreign, by(foreign) ///
        markdown("`out'/table1.md") mdappend clear
}
_oc_record "table1_tc" `=_rc'
if `_oc_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' table1_tc"
}

* =====================================================================
**# survtab: borderstyle, excel, headercolor, markdown, mdappend, open, zebracolor
* =====================================================================
local ++test_count
capture noisily {
    clear
    set obs 60
    set seed 91
    gen double time = runiform()*10 + 0.5
    gen byte event = runiform() < 0.6
    gen byte grp = mod(_n, 2)
    stset time, failure(event)
    survtab, times(2 5) by(grp) excel("`out'/survtab.xlsx") sheet("S") ///
        borderstyle(academic) headercolor("200 220 240") zebracolor("240 245 250")
    confirm file "`out'/survtab.xlsx"
    survtab, times(2 5) by(grp) markdown("`out'/survtab.md")
    confirm file "`out'/survtab.md"
    survtab, times(2 5) by(grp) markdown("`out'/survtab.md") mdappend
 capture survtab, times(2 5) by(grp) open
    assert _rc == 198
}
_oc_record "survtab" `=_rc'
if `_oc_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' survtab"
}

* =====================================================================
**# puttab: mdappend, open, zebracolor
* =====================================================================
local ++test_count
capture noisily {
    sysuse auto, clear
    puttab make mpg price in 1/5 using "`out'/puttab.xlsx", sheet("S") zebracolor("240 245 250") zebra
    confirm file "`out'/puttab.xlsx"
    puttab make mpg price in 1/5 using "`out'/puttab.xlsx", sheet("M") ///
        markdown("`out'/puttab.md")
    confirm file "`out'/puttab.md"
    puttab make mpg price in 1/5 using "`out'/puttab.xlsx", sheet("M2") ///
        markdown("`out'/puttab.md") mdappend
    capture puttab make mpg price in 1/5, markdown("`out'/puttab_open_guard.md") open
    assert _rc == 198
}
_oc_record "puttab" `=_rc'
if `_oc_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' puttab"
}

* =====================================================================
**# desctab: borderstyle, headercolor, markdown, mdappend,
**#          zebra, zebracolor
* =====================================================================
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    version 17.0: collect: table rep78, statistic(mean price) statistic(count price)
    desctab, xlsx("`out'/desctab.xlsx") sheet("S") borderstyle(academic) ///
        headercolor("200 220 240") zebra zebracolor("240 245 250")
    confirm file "`out'/desctab.xlsx"
    collect clear
    version 17.0: collect: table rep78, statistic(mean price) statistic(count price)
    desctab, markdown("`out'/desctab.md")
    confirm file "`out'/desctab.md"
    collect clear
    version 17.0: collect: table rep78, statistic(mean price) statistic(count price)
    desctab, markdown("`out'/desctab.md") mdappend
}
_oc_record "desctab" `=_rc'
if `_oc_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' desctab"
}

* =====================================================================
**# simtab: alpha, excel, headercolor, level, mdappend, minreps, open,
**#         pctdigits, warnreps, zebra, zebracolor
* =====================================================================
local ++test_count
capture noisily {
    clear
    set obs 60
    set seed 41
    gen long sim = mod(_n-1, 20) + 1
    gen byte estid = mod(floor((_n-1)/20), 3) + 1
    gen double truev = 0.5
    gen double est = truev + rnormal(0, 0.05)
    gen double se = 0.05 + runiform()*0.005
    gen byte covered = 1
    gen double pval = 2*(1 - normal(abs(est/se)))
    gen byte rej = pval < 0.05
    simtab estid, estimate(est) se(se) true(truev) coverage(covered) reject(rej) ///
        excel("`out'/simtab.xlsx") sheet("S") alpha(0.05) level(95) theme(apa) ///
        minreps(2) warnreps(2) pctdigits(1) headercolor("200 220 240") zebra zebracolor("240 245 250") ///
        plotframe(oc_simpf, replace)
    confirm file "`out'/simtab.xlsx"
    simtab estid, estimate(est) se(se) true(truev) coverage(covered) ///
        markdown("`out'/simtab.md") plotframe(oc_simpf2, replace)
    confirm file "`out'/simtab.md"
    simtab estid, estimate(est) se(se) true(truev) coverage(covered) ///
        markdown("`out'/simtab.md") mdappend plotframe(oc_simpf3, replace)
    capture simtab estid, estimate(est) se(se) true(truev) coverage(covered) ///
        display open
    assert _rc == 198
}
_oc_record "simtab" `=_rc'
if `_oc_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' simtab"
}

* =====================================================================
**# comptab: boldp, compact, csv, highlight, labelwidth, mdappend, relabel,
**#          separator, theme, zebracolor   (needs regtab source frames)
* =====================================================================
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price foreign mpg
    collect: regress price foreign mpg weight
    capture frame drop oc_cf
    regtab, frame(oc_cf) noint models("Model A" \ "Model B")
    comptab oc_cf, rows(1 2) csv("`out'/comptab.csv") theme(apa) zebracolor("240 245 250") ///
        labelwidth(20) relabel(1 "Relabeled foreign") separator(1) ///
        highlight(0.05) boldp(0.05) compact frame(oc_cmp1, replace)
    confirm file "`out'/comptab.csv"
    comptab oc_cf, rows(1 2) markdown("`out'/comptab.md") frame(oc_cmp2, replace)
    confirm file "`out'/comptab.md"
    comptab oc_cf, rows(1 2) markdown("`out'/comptab.md") mdappend ///
        frame(oc_cmp3, replace)
}
_oc_record "comptab" `=_rc'
if `_oc_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' comptab"
}

* =====================================================================
**# hrcomptab: borderstyle, csv, footnote, mdappend, open, zebra, zebracolor
**#            (needs stratetab rates frame + regtab modelframes)
* =====================================================================
local ++test_count
capture noisily {
    * strate-style rate file
    clear
    set obs 2
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 10, 20)
    gen _Y = cond(_n == 1, 1000, 1100)
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label variable _Lower "Lower 95% confidence limit"
    label variable _Upper "Upper 95% confidence limit"
    label define oc_exp 0 "None" 1 "Current", replace
    label values exposure oc_exp
    tempfile r1
    save "`r1'.dta", replace
    stratetab, using("`r1'") outcomes(1) outcomeids(_t) ///
        frame(oc_rates, replace)
    * regtab model frame
    clear
    set obs 100
    set seed 20260713
    gen byte treated = mod(_n, 2)
    gen double follow = exp(-0.4 * treated + rnormal())
    gen byte failed = 1
    stset follow, failure(failed)
    collect clear
    collect: stcox treated
    capture frame drop oc_mod
    regtab, frame(oc_mod) noint coef(HR)
    hrcomptab oc_rates, modelframes(oc_mod) rows(1) effect("aHR") ///
        csv("`out'/hrcomptab.csv") footnote("note") borderstyle(academic) ///
        zebra zebracolor("240 245 250") frame(oc_hrc1, replace)
    confirm file "`out'/hrcomptab.csv"
    hrcomptab oc_rates, modelframes(oc_mod) rows(1) effect("aHR") ///
        markdown("`out'/hrcomptab.md") frame(oc_hrc2, replace)
    confirm file "`out'/hrcomptab.md"
    hrcomptab oc_rates, modelframes(oc_mod) rows(1) effect("aHR") ///
        markdown("`out'/hrcomptab.md") mdappend frame(oc_hrc3, replace)
    capture hrcomptab oc_rates, modelframes(oc_mod) rows(1) effect("aHR") ///
 open
    assert _rc == 198
}
_oc_record "hrcomptab" `=_rc'
if `_oc_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' hrcomptab"
}

* =====================================================================
**# stacktab: display, markdown, mdappend  (needs a workbook with blocks)
* =====================================================================
local ++test_count
capture noisily {
    local wb "`out'/stacktab_src.xlsx"
    capture erase "`wb'"
    clear
    input str20 label str10 est str16 ci
    "Category"   "HR"    "95% CI"
    "Binary HRT" "1.23"  "(1.05, 1.44)"
    "Active"     "1.45"  "(1.20, 1.75)"
    end
    export excel "`wb'", sheet("SrcA") sheetreplace
    clear
    input str20 label str10 est str16 ci
    "Dose"      "aHR"   "95% CI"
    "Low dose"  "1.10"  "(0.90, 1.35)"
    "High dose" "1.67"  "(1.30, 2.15)"
    end
    export excel "`wb'", sheet("SrcB") sheetreplace
    stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(1/3) cols(A-C) \ sheet(SrcB) rows(1/3) cols(A-C)) ///
        sheet("Composite") sheetreplace display
    stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(1/3) cols(A-C)) ///
        sheet("Composite2") sheetreplace markdown("`out'/stacktab.md")
    confirm file "`out'/stacktab.md"
    stacktab using "`wb'", ///
        blocks(sheet(SrcB) rows(1/3) cols(A-C)) ///
        sheet("Composite3") sheetreplace markdown("`out'/stacktab.md") mdappend
}
_oc_record "stacktab" `=_rc'
if `_oc_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' stacktab"
}

* =====================================================================
**# stratetab: excel, markdown, mdappend  (needs a strate rate file)
* =====================================================================
local ++test_count
capture noisily {
    clear
    set obs 3
    gen exposure = _n - 1
    gen _D = cond(_n == 1, 10, cond(_n == 2, 20, 30))
    gen _Y = cond(_n == 1, 1000, cond(_n == 2, 1100, 1200))
    gen _Rate = _D / _Y
    gen _Lower = _Rate * 0.8
    gen _Upper = _Rate * 1.2
    label variable _Lower "Lower 95% confidence limit"
    label variable _Upper "Upper 95% confidence limit"
    label define oc_sexp 0 "Low" 1 "Med" 2 "High", replace
    label values exposure oc_sexp
    tempfile sr1
    save "`sr1'.dta", replace
    clear
    stratetab, using("`sr1'") outcomes(1) excel("`out'/stratetab.xlsx") sheet("Excel")
    confirm file "`out'/stratetab.xlsx"
    clear
    stratetab, using("`sr1'") outcomes(1) markdown("`out'/stratetab.md")
    confirm file "`out'/stratetab.md"
    clear
    stratetab, using("`sr1'") outcomes(1) markdown("`out'/stratetab.md") mdappend
}
_oc_record "stratetab" `=_rc'
if `_oc_ok' local ++pass_count
else {
    local ++fail_count
    local failed "`failed' stratetab"
}

* =====================================================================
**# Summary
* =====================================================================
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED commands:`failed'"
    display "RESULT: test_option_coverage tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _optcov
    exit 1
}
display as result "ALL OPTION-COVERAGE TESTS PASSED"
display "RESULT: test_option_coverage tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _optcov
