* test_kmplot_v124.do
* Regression tests for kmplot 1.2.4
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-08-11

clear all
version 16.0

**# Bootstrap
local qa_dir "`c(pwd)'"
do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _kmplot_qa_sthlp_render
program define _kmplot_qa_sthlp_render, rclass
    version 16.0
    syntax anything(name=files id="help files")

    local files = subinstr(`"`files'"', char(34), "", .)
    local nbad 0
    local badfiles ""

    foreach f of local files {
        capture confirm file "`f'"
        if _rc {
            display as error "  render: file not found: `f'"
            local ++nbad
            local badfiles "`badfiles' `f'"
            continue
        }

        tempfile rlog
        capture log off
        log using "`rlog'", replace text name(_qarender)
        type "`f'", smcl
        log close _qarender
        capture log on

        local hits 0
        local nlines 0
        tempname fh
        file open `fh' using "`rlog'", read text
        file read `fh' line
        while r(eof) == 0 {
            local ++nlines
            if regexm(`"`line'"', "\{(pstd|phang|pmore|pin|p_end|psee|synopt|p2col|cmd:|it:|bf:|opt |opth |helpb |hline|title:|marker |dlgtab:|break)") {
                local shown = subinstr(`"`line'"', "{", char(1), .)
                local shown = subinstr(`"`shown'"', "}", char(2), .)
                local shown = subinstr(`"`shown'"', char(1), "{c -(}", .)
                local shown = subinstr(`"`shown'"', char(2), "{c )-}", .)
                display as error "  literal SMCL: `shown'"
                local ++hits
            }
            file read `fh' line
        }
        file close `fh'

        if `nlines' == 0 {
            display as error "  render produced no output for `f' -- FAILING"
            local ++nbad
            local badfiles "`badfiles' `f'"
            continue
        }
        if `hits' > 0 {
            local ++nbad
            local badfiles "`badfiles' `f'"
        }
    }

    return scalar nbad = `nbad'
    return local badfiles "`badfiles'"
end

**# Regression tests
**## R1: Multiple-record risk sets count subjects and true losses

local ++test_count
capture noisily {
    clear
    input id start stop event
    1 0 5 0
    1 5 10 1
    2 0 5 0
    2 5 12 0
    end
    stset stop, id(id) enter(time start) failure(event)

    local curvefile "`c(tmpdir)'/kmplot_v124_multirecord.dta"
    capture erase "`curvefile'"
    kmplot, risktable censor timepoints(0 5 6 10 12) ///
        saving("`curvefile'", replace) name(v124_r1, replace)

    matrix R = r(risktable)
    assert rowsof(R) == 5
    assert colsof(R) == 5
    assert R[1,3] == 2
    assert R[2,3] == 2
    assert R[3,3] == 2
    assert R[4,3] == 2
    assert R[5,3] == 1
    assert R[1,4] == 0
    assert R[2,4] == 0
    assert R[3,4] == 0
    assert R[4,4] == 1
    assert R[5,4] == 1
    assert R[1,5] == 0
    assert R[2,5] == 0
    assert R[3,5] == 0
    assert R[4,5] == 0
    assert R[5,5] == 1

    preserve
    use "`curvefile'", clear
    quietly count if time == 5 & censor == 1
    assert r(N) == 0
    quietly count if time == 12 & censor == 1
    assert r(N) == 1
    restore
    erase "`curvefile'"
}
if _rc == 0 {
    display as result "  PASS: R1 Multiple-record subject and loss counts"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 Multiple-record subject and loss counts (rc=`=_rc')"
    local ++fail_count
}

**## R2: Risk-table counts honor the active stset weights

local ++test_count
capture noisily {
    clear
    input time event frequency
    5  1 10
    10 0 1
    end
    stset time [fw=frequency], failure(event)

    kmplot, risktable timepoints(0 5 10) name(v124_r2, replace)
    matrix R = r(risktable)
    assert rowsof(R) == 3
    assert R[1,3] == 11
    assert R[2,3] == 11
    assert R[3,3] == 1
    assert R[1,4] == 0
    assert R[2,4] == 10
    assert R[3,4] == 10
    assert R[1,5] == 0
    assert R[2,5] == 0
    assert R[3,5] == 1
}
if _rc == 0 {
    display as result "  PASS: R2 stset weights honored by risk table"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 stset weights honored by risk table (rc=`=_rc')"
    local ++fail_count
}

**## R3: Subordinate options reject silent no-op combinations

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    capture kmplot, medianannotate name(v124_bad_med, replace)
    local rc_med = _rc
    capture kmplot, riskevents name(v124_bad_evt, replace)
    local rc_evt = _rc
    capture kmplot, riskcompact name(v124_bad_compact, replace)
    local rc_compact = _rc
    capture kmplot, riskmono name(v124_bad_mono, replace)
    local rc_mono = _rc
    capture kmplot, timepoints(0 10) name(v124_bad_tp, replace)
    local rc_tp = _rc
    capture kmplot, riskheight(30) name(v124_bad_rh, replace)
    local rc_rh = _rc
    capture kmplot, riskheight(-1) name(v124_bad_rh_sentinel, replace)
    local rc_rh_sentinel = _rc
    capture kmplot, censor censorthin(0) name(v124_bad_ct0, replace)
    local rc_ct0 = _rc
    capture kmplot, censorthin(2) name(v124_bad_ct2, replace)
    local rc_ct2 = _rc
    capture kmplot, pvaluepos(topleft) name(v124_bad_ppos, replace)
    local rc_ppos = _rc
    capture kmplot, pvalueformat(%6.4f) name(v124_bad_pfmt, replace)
    local rc_pfmt = _rc
    capture kmplot, pvaluetext("P") name(v124_bad_ptxt, replace)
    local rc_ptxt = _rc
    capture kmplot, pvalueat(.9 10) name(v124_bad_pat, replace)
    local rc_pat = _rc
    capture kmplot, cistyle(line) name(v124_bad_cs, replace)
    local rc_cs = _rc
    capture kmplot, citransform(log) name(v124_bad_ct, replace)
    local rc_ct = _rc
    capture kmplot, ciopacity(50) name(v124_bad_cio, replace)
    local rc_cio = _rc
    capture kmplot, level(90) name(v124_bad_lvl, replace)
    local rc_lvl = _rc
    capture kmplot, ciopacity(12) name(v124_bad_cio_default, replace)
    local rc_cio_default = _rc
    capture kmplot, level(95) name(v124_bad_lvl_default, replace)
    local rc_lvl_default = _rc
    capture kmplot, censorthin(1) name(v124_bad_ct_default, replace)
    local rc_ct_default = _rc
    capture kmplot, pvalue name(v124_bad_pvalue, replace)
    local rc_pvalue = _rc
    capture kmplot, by(drug) pvalue pvaluepos(topleft) pvalueat(.9 10) ///
        name(v124_bad_pplace, replace)
    local rc_pplace = _rc

    generate byte one_group = 1
    capture kmplot, by(one_group) pvalue name(v124_bad_one_group, replace)
    local rc_one_group = _rc

    capture kmplot, ci cistyle(line) ciopacity(50) ///
        name(v124_bad_line_opacity, replace)
    local rc_line_opacity = _rc

    foreach rc in med evt compact mono tp rh rh_sentinel ct0 ct2 ppos pfmt ptxt pat cs ct cio lvl ///
        cio_default lvl_default ct_default pvalue pplace one_group line_opacity {
        assert `rc_`rc'' == 198
    }
}
if _rc == 0 {
    display as result "  PASS: R3 Subordinate option dependencies"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 Subordinate option dependencies (rc=`=_rc')"
    local ++fail_count
}

**## R4: Valid dependent-option combinations remain supported

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) ci level(90) cistyle(band) ciopacity(20) ///
        citransform(loglog) median medianannotate censor censorthin(2) ///
        risktable riskevents riskmono riskheight(30) timepoints(0 10 20) ///
        pvalue pvalueformat(%6.4f) ///
        pvaluetext("Log-rank P") pvalueat(.9 10) name(v124_r4, replace)
    assert !missing(r(N))
    assert r(N) == 48
    assert r(n_groups) == 3
    assert r(level) == 90
    assert r(riskheight) == 30
    assert r(n_timepoints) == 3
    assert !missing(r(p))
}
if _rc == 0 {
    display as result "  PASS: R4 Valid dependent-option combinations"
    local ++pass_count
}
else {
    display as error "  FAIL: R4 Valid dependent-option combinations (rc=`=_rc')"
    local ++fail_count
}

**## R5: Delayed entry and group transitions follow Stata risk-set boundaries

local ++test_count
capture noisily {
    clear
    input id start stop event group
    1 0 5  0 1
    1 5 10 1 2
    2 0 5  0 1
    2 5 12 0 1
    end
    stset stop, id(id) enter(time start) failure(event)

    local curvefile "`c(tmpdir)'/kmplot_v124_group_transition.dta"
    capture erase "`curvefile'"
    kmplot, by(group) risktable censor timepoints(0 5 6 10 12) ///
        saving("`curvefile'", replace) name(v124_r5, replace)

    matrix R = r(risktable)
    assert R[1,3] == 2
    assert R[2,3] == 2
    assert R[3,3] == 1
    assert R[4,3] == 1
    assert R[5,3] == 1
    assert R[6,3] == 0
    assert R[7,3] == 0
    assert R[8,3] == 1
    assert R[9,3] == 1
    assert R[10,3] == 0
    assert R[2,5] == 1
    assert R[5,5] == 2

    preserve
    use "`curvefile'", clear
    quietly count if group == 1 & time == 5 & censor == 1
    assert r(N) == 1
    restore
    erase "`curvefile'"
}
if _rc == 0 {
    display as result "  PASS: R5 Delayed-entry and group-transition boundaries"
    local ++pass_count
}
else {
    display as error "  FAIL: R5 Delayed-entry and group-transition boundaries (rc=`=_rc')"
    local ++fail_count
}

**## R6: Shipped help renders without literal SMCL

local ++test_count
capture noisily {
    local helpfile "`qa_dir'/../kmplot.sthlp"
    _kmplot_qa_sthlp_render `helpfile'
    assert r(nbad) == 0

    tempfile broken
    tempname bfh
    file open `bfh' using "`broken'", write replace text
    file write `bfh' "{smcl}" _n
    file write `bfh' "{title:Render probe}" _n _n
    file write `bfh' "{pstd}" _n
    file write `bfh' "A directive split across a source newline: {bf:broken" _n
    file write `bfh' "directive} renders as literal markup." _n
    file close `bfh'
    _kmplot_qa_sthlp_render `broken'
    assert r(nbad) == 1
}
if _rc == 0 {
    display as result "  PASS: R6 Shipped help render and positive control"
    local ++pass_count
}
else {
    display as error "  FAIL: R6 Shipped help render and positive control (rc=`=_rc')"
    local ++fail_count
}

**# Summary
if `fail_count' > 0 {
    display as error "RESULT: test_kmplot_v124 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "RESULT: test_kmplot_v124 tests=`test_count' pass=`pass_count' fail=`fail_count'"
