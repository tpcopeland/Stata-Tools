* test_logdoc_v114.do - regression coverage for the 1.1.4 fixes
* Run: stata-mp -b do test_logdoc_v114.do

clear all
set more off
capture log close _all

local qadir = regexr("`c(pwd)'", "/+$", "")
capture confirm file "`qadir'/logdoc.pkg"
if _rc == 0 {
    local pkgdir "`qadir'"
    local qadir "`pkgdir'/qa"
}
else {
    local pkgdir = regexr("`qadir'", "/qa/?$", "")
}
capture confirm file "`pkgdir'/logdoc.pkg"
if _rc {
    display as error "Could not locate logdoc package root from c(pwd)=`c(pwd)'"
    exit 601
}

capture ado uninstall logdoc
net install logdoc, from("`pkgdir'") replace

local test_pass = 0
local test_fail = 0
local test_total = 0
local outdir "`c(tmpdir)'/logdoc_v114_tests"
capture mkdir "`outdir'"

mata:
void _logdoc_v114_file_has(
    string scalar path,
    string scalar needle,
    string scalar result
)
{
    real scalar fh, found
    string scalar line

    found = 0
    fh = fopen(path, "r")
    if (fh < 0) {
        st_local(result, "0")
        return
    }
    while ((line = fget(fh)) != J(0, 0, "")) {
        if (strpos(line, needle) > 0) {
            found = 1
            break
        }
    }
    fclose(fh)
    st_local(result, strofreal(found))
}
end

capture program drop _logdoc_v114_contains
program define _logdoc_v114_contains
    args file needle resultvar
    local found 0
    mata: _logdoc_v114_file_has(st_local("file"), st_local("needle"), "found")
    c_local `resultvar' `found'
end

* V114-T1: a stataexe() path containing spaces is passed as one executable.
local ++test_total
local spacedir "`outdir'/stata exe"
capture mkdir "`spacedir'"
if "`c(os)'" == "Windows" {
    local wrapper "`spacedir'/stata wrapper.bat"
}
else {
    local wrapper "`spacedir'/stata wrapper"
}
tempname wfh
file open `wfh' using "`wrapper'", write text replace
if "`c(os)'" == "Windows" {
    file write `wfh' "@echo off" _n
    file write `wfh' "StataMP-64 %1 %2 %3" _n
}
else {
    file write `wfh' "#!/bin/sh" _n
    local shell_line = "exec stata-mp " + char(34) + char(36) + "1" + ///
        char(34) + " " + char(34) + char(36) + "2" + char(34) + " " + ///
        char(34) + char(36) + "3" + char(34)
    file write `wfh' `"`shell_line'"' _n
}
file close `wfh'
if "`c(os)'" != "Windows" shell chmod +x "`wrapper'"

local run_do "`outdir'/space_path_run.do"
file open `wfh' using "`run_do'", write text replace
file write `wfh' "display 114001" _n
file close `wfh'
local run_out "`outdir'/space_path_run.html"
capture noisily logdoc using "`run_do'", run output("`run_out'") ///
    stataexe("`wrapper'") replace quiet
local t1_rc = _rc
local t1_found 0
if `t1_rc' == 0 _logdoc_v114_contains "`run_out'" "114001" t1_found
if `t1_rc' == 0 & `t1_found' {
    display as result "V114-T1 PASS: stataexe() preserves executable paths with spaces"
    local ++test_pass
}
else {
    display as error "V114-T1 FAIL: stataexe() space-containing path (rc=`t1_rc')"
    local ++test_fail
}

* V114-T2: help and helpb tags keep the complete topic and display text.
local ++test_total
local help_smcl "`outdir'/help_tags.smcl"
tempname hfh
file open `hfh' using "`help_smcl'", write text replace
file write `hfh' "{smcl}" _n
file write `hfh' "{txt}{help regress}" _n
file write `hfh' "{txt}{help regress##|_new:Regression}" _n
file write `hfh' "{txt}{helpb regress}" _n
file close `hfh'
local help_html "`outdir'/help_tags.html"
capture noisily logdoc using "`help_smcl'", output("`help_html'") replace quiet
local t2_rc = _rc
local t2_topic 0
local t2_label 0
local t2_helpb 0
if `t2_rc' == 0 {
    _logdoc_v114_contains "`help_html'" ///
        "https://www.stata.com/help.cgi?regress" t2_topic
    _logdoc_v114_contains "`help_html'" ">Regression</a>" t2_label
    _logdoc_v114_contains "`help_html'" "<strong>regress</strong>" t2_helpb
}
if `t2_rc' == 0 & `t2_topic' & `t2_label' & `t2_helpb' {
    display as result "V114-T2 PASS: SMCL help links preserve topics and labels"
    local ++test_pass
}
else {
    display as error "V114-T2 FAIL: SMCL help-link rendering (rc=`t2_rc')"
    local ++test_fail
}

* V114-T3: diff() retains the documented r(compare) macro through the dispatcher.
local ++test_total
local left_smcl "`outdir'/left.smcl"
local right_smcl "`outdir'/right.smcl"
file open `hfh' using "`left_smcl'", write text replace
file write `hfh' "{smcl}" _n "{txt}left" _n
file close `hfh'
file open `hfh' using "`right_smcl'", write text replace
file write `hfh' "{smcl}" _n "{txt}right" _n
file close `hfh'
local diff_html "`outdir'/diff.html"
capture noisily logdoc diff using "`left_smcl'", comp("`right_smcl'") ///
    output("`diff_html'") replace quiet
local t3_rc = _rc
local t3_compare ""
if `t3_rc' == 0 local t3_compare `"`r(compare)'"'
if `t3_rc' == 0 & `"`t3_compare'"' == `"`right_smcl'"' {
    display as result "V114-T3 PASS: diff r(compare) contract is preserved"
    local ++test_pass
}
else {
    display as error "V114-T3 FAIL: diff r(compare) contract (rc=`t3_rc')"
    local ++test_fail
}

* V114-T4: released help files are checked through Stata's SMCL interpreter,
* with a split-directive positive control proving that the oracle can fail.
local ++test_total
capture program drop _logdoc_v114_sthlp_render
program define _logdoc_v114_sthlp_render, rclass
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
        log using "`rlog'", replace text name(_logdoc_v114_render)
        type "`f'", smcl
        log close _logdoc_v114_render
        capture log on

        local hits 0
        local nlines 0
        tempname fh
        file open `fh' using "`rlog'", read text
        file read `fh' line
        while r(eof) == 0 {
            local ++nlines
            if regexm(`"`line'"', ///
                "\{(pstd|phang|pmore|pin|p_end|psee|synopt|p2col|cmd:|it:|bf:|opt |opth |helpb |hline|title:|marker |dlgtab:|break)") {
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

local sthlps : dir "`pkgdir'" files "*.sthlp"
local help_paths ""
foreach s of local sthlps {
    local help_paths "`help_paths' `pkgdir'/`s'"
}
capture noisily _logdoc_v114_sthlp_render `help_paths'
local t4_render_rc = _rc
local t4_shipped_bad = -1
if `t4_render_rc' == 0 local t4_shipped_bad = r(nbad)

local probe "`outdir'/_render_probe.sthlp"
file open `hfh' using "`probe'", write text replace
file write `hfh' "{smcl}" _n
file write `hfh' "{title:Render probe}" _n _n
file write `hfh' "{pstd}" _n
file write `hfh' "A split directive: {bf:broken" _n
file write `hfh' "directive} renders as literal markup." _n
file close `hfh'
capture noisily _logdoc_v114_sthlp_render `probe'
local t4_probe_rc = _rc
local t4_probe_bad = -1
if `t4_probe_rc' == 0 local t4_probe_bad = r(nbad)

if `t4_render_rc' == 0 & `t4_shipped_bad' == 0 & ///
    `t4_probe_rc' == 0 & `t4_probe_bad' == 1 {
    display as result "V114-T4 PASS: shipped help renders clean and the oracle detects a broken probe"
    local ++test_pass
}
else {
    display as error "V114-T4 FAIL: help render oracle (shipped=`t4_shipped_bad', probe=`t4_probe_bad')"
    local ++test_fail
}

display as result "RESULT: test_logdoc_v114 tests=`test_total' pass=`test_pass' fail=`test_fail'"
if `test_fail' > 0 exit 9
