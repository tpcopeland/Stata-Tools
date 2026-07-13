* test_gcomptab_text_export.do
* Markdown/CSV companion exports for gcomptab mediation and dose-response modes
* (feature added v1.4.0), plus option-coverage for previously-unexercised
* gcomptab styling/models options and gcomp boceam/graph.

clear all
set varabbrev off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory, sandboxed install
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"

local td "`c(tmpdir)'"

* ---- helper: assert a text file contains a given line/substring ----
capture program drop _file_has
program define _file_has
    gettoken fn 0 : 0
    local needle = strtrim(`"`0'"')
    tempname fh
    file open `fh' using "`fn'", read text
    local found 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', `"`needle'"') local found 1
        file read `fh' line
    }
    file close `fh'
    if !`found' {
        display as error "      missing in `fn': `needle'"
        exit 9
    }
end

* ---- data builders ----
capture program drop _mk_med
program define _mk_med
    clear
    set seed 12345
    set obs 1000
    gen double c = rnormal()
    gen double x = rbinomial(1, invlogit(-0.2 + 0.4 * c))
    gen double m = rbinomial(1, invlogit(-0.4 + 1.2 * x + 0.3 * c))
    gen double y = rbinomial(1, invlogit(-0.8 + 1.0 * m + 0.8 * x + 0.2 * c))
end

capture program drop _mk_tv
program define _mk_tv
    clear
    set seed 20260529
    set obs 900
    gen long id = ceil(_n / 3)
    bysort id: gen byte time = _n
    gen double L0 = rnormal()
    bysort id (time): replace L0 = L0[1]
    gen byte A = .
    gen double L = .
    gen byte Alag = 0
    gen double Llag = 0
    bysort id (time): replace L = 0.15 + 0.65*L0 + rnormal(0,0.35) if time==1
    bysort id (time): replace A = rbinomial(1, invlogit(-0.35+0.70*L+0.20*L0)) if time==1
    bysort id (time): replace L = 0.10 + 0.60*L[_n-1] - 0.55*A[_n-1] + 0.15*L0 + rnormal(0,0.35) if time==2
    bysort id (time): replace A = rbinomial(1, invlogit(-0.25+0.60*L+0.20*L0)) if time==2
    bysort id (time): replace L = 0.05 + 0.55*L[_n-1] - 0.55*A[_n-1] + 0.10*L0 + rnormal(0,0.35) if time==3
    bysort id (time): replace A = rbinomial(1, invlogit(-0.15+0.55*L+0.20*L0)) if time==3
    bysort id (time): replace Alag = A[_n-1] if _n>1
    bysort id (time): replace Llag = L[_n-1] if _n>1
    gen byte Y = 0
    bysort id (time): replace Y = rbinomial(1, invlogit(-1.35-0.90*A[_n-1]+0.75*L[_n-1]+0.20*L0)) if time==3
end

**# A: mediation Markdown + CSV content, returns, messages

local ++test_count
local xlsx "`td'/_te_med.xlsx"
local md   "`td'/_te_med.md"
local csv  "`td'/_te_med.csv"
capture erase "`md'"
capture erase "`csv'"
capture noisily {
    _mk_med
    gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        base_confs(c) sim(300) samples(20) seed(42) minsim
    gcomptab, xlsx("`xlsx'") sheet("Med") title("Mediation Demo") ///
        markdown("`md'") csv("`csv'")
    * returns
    assert `"`r(markdown)'"' == "`md'"
    assert `"`r(csv)'"' == "`csv'"
    * markdown structure: heading, header row, separator, a body row
    confirm file "`md'"
    _file_has "`md'" ### Mediation Demo
    _file_has "`md'" | Effect | Estimate | 95% CI | SE |
    _file_has "`md'" | --- | --- | --- | --- |
    _file_has "`md'" | Total Causal Effect (TCE) |
    * CSV: quoted, comma-bearing CI stays in ONE column -> exactly 4 columns
    import delimited using "`csv'", clear varnames(1) bindquotes(strict) case(preserve)
    assert c(k) == 4
    assert _N == 4
    unab _allv : *
    local civar : word 3 of `_allv'
    assert strpos(`civar'[1], ",") > 0
    assert strpos(`civar'[1], "(") > 0
}
if _rc == 0 {
    display as result "  PASS: A mediation markdown+csv (content/returns)"
    local ++pass_count
}
else {
    display as error "  FAIL: A mediation markdown+csv (rc=`=_rc')"
    local ++fail_count
}
capture erase "`md'"
capture erase "`csv'"

**# B: dose-response Markdown + CSV content, returns

local ++test_count
local xlsx "`td'/_te_dr.xlsx"
local md   "`td'/_te_dr.md"
local csv  "`td'/_te_dr.csv"
capture erase "`md'"
capture erase "`csv'"
capture noisily {
    _mk_tv
    gcomp Y L0 A L Alag Llag id time, outcome(Y) idvar(id) tvar(time) ///
        varyingcovariates(L) fixedcovariates(L0) laggedvars(Alag Llag) ///
        lagrules(Alag: A 1, Llag: L 1) intvars(A) eofu ///
        commands(A: logit, Y: logit, L: regress) ///
        equations(A: L0 L, Y: Alag Llag L0, L: Alag Llag L0) ///
        interventions(A=1, A=0) sim(200) samples(5) seed(20260529)
    gcomptab, xlsx("`xlsx'") sheet("DR") doseresponse ///
        strategylabels("Always treat \ Never treat \ Natural course") ///
        expyears(3 0 1.4) title("Dose Response Demo") ///
        markdown("`md'") csv("`csv'")
    assert `"`r(markdown)'"' == "`md'"
    assert `"`r(csv)'"' == "`csv'"
    confirm file "`md'"
    _file_has "`md'" ### Dose Response Demo
    _file_has "`md'" | Strategy | Mean exposure-years | Risk (95% CI) | RD vs ref |
    _file_has "`md'" | Always treat |
    * CSV: 4 columns (Strategy, Mean exposure-years, Risk (95% CI), RD vs ref),
    * 3 strategy rows; comma-bearing Risk cell stays intact
    import delimited using "`csv'", clear varnames(1) bindquotes(strict) case(preserve)
    assert c(k) == 4
    assert _N == 3
    unab _allv : *
    local riskvar : word 3 of `_allv'
    assert strpos(`riskvar'[1], ",") > 0
}
if _rc == 0 {
    display as result "  PASS: B dose-response markdown+csv (content/returns)"
    local ++pass_count
}
else {
    display as error "  FAIL: B dose-response markdown+csv (rc=`=_rc')"
    local ++fail_count
}
capture erase "`md'"
capture erase "`csv'"

**# C: extension rejection (markdown + csv)

local ++test_count
local xlsx "`td'/_te_ext.xlsx"
capture noisily {
    _mk_med
    gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        base_confs(c) sim(300) samples(10) seed(1) minsim
    * bad markdown extension
    capture gcomptab, xlsx("`xlsx'") sheet("E") markdown("`td'/bad.txt")
    assert _rc == 198
    * bad csv extension
    capture gcomptab, xlsx("`xlsx'") sheet("E") csv("`td'/bad.dat")
    assert _rc == 198
    * accepted markdown variants
    foreach ext in md markdown qmd rmd {
        capture erase "`td'/_te_ok.`ext'"
        gcomptab, xlsx("`xlsx'") sheet("E") markdown("`td'/_te_ok.`ext'")
        assert _rc == 0
        confirm file "`td'/_te_ok.`ext'"
        capture erase "`td'/_te_ok.`ext'"
    }
}
if _rc == 0 {
    display as result "  PASS: C extension rejection/acceptance"
    local ++pass_count
}
else {
    display as error "  FAIL: C extension rejection (rc=`=_rc')"
    local ++fail_count
}

**# D: companion exports + styling-option coverage (theme/headercolor/zebracolor/noshade/nozebra/open)

local ++test_count
local xlsx "`td'/_te_style.xlsx"
local md   "`td'/_te_style.md"
capture noisily {
    _mk_med
    gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        base_confs(c) sim(300) samples(10) seed(2) minsim
    * theme + explicit header/zebra colors, with markdown companion
    gcomptab, xlsx("`xlsx'") sheet("T1") theme(nejm) ///
        headercolor("200 210 230") zebracolor("245 245 245") markdown("`md'")
    assert _rc == 0
    confirm file "`md'"
    * suppress shading/zebra from a theme
    gcomptab, xlsx("`xlsx'") sheet("T2") theme(jama) noshade nozebra
    assert _rc == 0
    * open launches the OS viewer (a GUI app); exercise the option path only in
    * interactive use so batch/CI never spawns a lingering LibreOffice/Excel.
    if c(mode) != "batch" {
        gcomptab, xlsx("`xlsx'") sheet("T3") open
        assert _rc == 0
    }
}
if _rc == 0 {
    display as result "  PASS: D styling-option coverage (theme/colors/noshade/nozebra/open)"
    local ++pass_count
}
else {
    display as error "  FAIL: D styling-option coverage (rc=`=_rc')"
    local ++fail_count
}
capture erase "`md'"

**# E: models-mode option coverage (eform/noeform/raw/coef/keep/drop/digits/nointercept/keepintercept/starslevels/termlabels)

local ++test_count
local xlsx "`td'/_te_models.xlsx"
local md   "`td'/_te_models.md"
capture noisily {
    _mk_med
    gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        base_confs(c) sim(300) samples(3) seed(3) minsim savemodels
    * eform + stars/starslevels + digits + termlabels
    gcomptab, models xlsx("`xlsx'") sheet("M1") eform stars ///
        starslevels(0.05 0.01) digits(2) termlabels("Intercept \ Exposure")
    assert _rc == 0
    * noeform + se + nointercept + keep
    gcomptab, models xlsx("`xlsx'") sheet("M2") noeform se nointercept keep(x)
    assert _rc == 0
    * raw + drop + keepintercept + coef() + markdown companion
    gcomptab, models xlsx("`xlsx'") sheet("M3") raw keepintercept drop(c) ///
        coef("logOR") markdown("`md'")
    assert _rc == 0
    confirm file "`md'"
}
if _rc == 0 {
    display as result "  PASS: E models-mode option coverage"
    local ++pass_count
}
else {
    display as error "  FAIL: E models-mode option coverage (rc=`=_rc')"
    local ++fail_count
}
capture erase "`md'"

**# F: gcomp boceam (single works; multi-mediator guarded) and graph

local ++test_count
capture noisily {
    * single-mediator boceam runs
    clear
    set seed 999
    set obs 1500
    gen double c = rnormal()
    gen double x = rbinomial(1, invlogit(-0.2 + 0.4*c))
    gen byte m1 = rbinomial(1, invlogit(-0.7 + 0.8*x + 0.4*c))
    gen byte m2 = rbinomial(1, invlogit(-0.5 + 0.6*x + 0.4*m1))
    gen double y = 0.7*m1 + 0.4*m2 + 0.6*x + 0.2*c + rnormal(0, 0.7)
    gcomp y m1 x c, outcome(y) mediation obe boceam exposure(x) mediator(m1) ///
        commands(m1: logit, y: regress) equations(m1: x c, y: m1 x c) ///
        base_confs(c) msm(regress y x m1) sim(300) samples(10) seed(7) minsim
    assert "`e(analysis_type)'" == "mediation"
    assert !missing(e(tce))
    * multi-mediator boceam -> clean guarded error (rc=198), not a cryptic crash
    capture gcomp y m1 m2 x c, outcome(y) mediation obe boceam exposure(x) mediator(m1 m2) ///
        commands(m1: logit, m2: logit, y: regress) ///
        equations(m1: x c, m2: x m1 c, y: m1 m2 x c) base_confs(c) sim(50) samples(5)
    assert _rc == 198
    * graph() is a time-varying diagnostic and is rejected in mediation mode
    capture gcomp y m1 x c, outcome(y) mediation obe exposure(x) mediator(m1) ///
        commands(m1: logit, y: regress) equations(m1: x c, y: m1 x c) ///
        base_confs(c) sim(50) samples(5) seed(8) graph
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: F gcomp boceam (single/guarded) + graph guard"
    local ++pass_count
}
else {
    display as error "  FAIL: F gcomp boceam/graph (rc=`=_rc')"
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_gcomptab_text_export tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_gcomptab_text_export tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
