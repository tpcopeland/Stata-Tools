* test_logdoc_v117.do - regression coverage for the 1.1.7 deep-review fixes
* Run: stata-mp -b do test_logdoc_v117.do

version 16.0
clear all
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
quietly net install logdoc, from("`pkgdir'") replace
quietly logdoc_py
local python "`r(python)'"
local renderer "`r(renderer)'"

local test_pass = 0
local test_fail = 0
local test_total = 0
local oldpwd "`c(pwd)'"
local outdir "`c(tmpdir)'/logdoc_v117_tests"
capture mkdir "`outdir'"

mata:
void _logdoc_v117_file_has(
    string scalar path,
    string scalar needle,
    string scalar result
)
{
    real scalar fh, found
    string scalar line

    found = 0
    fh = fopen(path, "r")
    if (fh >= 0) {
        while ((line = fget(fh)) != J(0, 0, "")) {
            if (strpos(line, needle) > 0) found = 1
        }
        fclose(fh)
    }
    st_local(result, strofreal(found))
}
end

capture program drop _logdoc_v117_contains
program define _logdoc_v117_contains, rclass
    syntax using/, Pattern(string)
    local found 0
    mata: _logdoc_v117_file_has(st_local("using"), st_local("pattern"), "found")
    return scalar found = `found'
end

capture program drop _logdoc_v117_state_probe
program define _logdoc_v117_state_probe, rclass
    syntax, Case(string) Renderer(string) PYthon(string) Scratch(string)
    local child_rc 0
    local child_ok 1
    local observed ""

    if "`case'" == "find_script" {
        set varabbrev on
        capture noisily _logdoc_find_script, result(found)
        local child_rc = _rc
        local observed "`c(varabbrev)'"
        set varabbrev on
        assert `child_rc' == 0
        assert "`found'" != ""
    }
    else if "`case'" == "resolve_python" {
        set varabbrev on
        capture noisily _logdoc_resolve_python, result(found)
        local child_rc = _rc
        local observed "`c(varabbrev)'"
        set varabbrev on
        assert `child_rc' == 0
        assert `"`found'"' != ""
    }
    else if "`case'" == "py_check_stata" {
        set varabbrev on
        capture noisily _logdoc_py_check_stata, renderer("`scratch'/missing.py")
        local child_rc = _rc
        local child_ok = r(ok)
        local observed "`c(varabbrev)'"
        set varabbrev on
        assert `child_rc' == 0
        assert `child_ok' == 0
    }
    else if "`case'" == "py_check_candidate" {
        set varabbrev on
        capture noisily _logdoc_py_check_candidate, ///
            python("`scratch'/missing-python") source("test") ///
            renderer(`"`renderer'"')
        local child_rc = _rc
        local child_ok = r(ok)
        local observed "`c(varabbrev)'"
        set varabbrev on
        assert `child_rc' == 0
        assert `child_ok' == 0
    }
    else if "`case'" == "py_find_script" {
        set varabbrev on
        capture noisily _logdoc_py_find_script, result(found)
        local child_rc = _rc
        local observed "`c(varabbrev)'"
        set varabbrev on
        assert `child_rc' == 0
        assert `"`found'"' != ""
    }
    else if "`case'" == "py_install" {
        set varabbrev on
        capture noisily _logdoc_py_install, ///
            python(`"`python'"') install("required") quiet
        local child_rc = _rc
        local child_ok = r(installed)
        local observed "`c(varabbrev)'"
        set varabbrev on
        assert `child_rc' == 0
        assert `child_ok' == 0
    }
    else {
        display as error "unknown state probe: `case'"
        exit 198
    }

    assert "`observed'" == "on"
    return scalar restored = 1
end

tempname fh
local fixture1 "`outdir'/fixture_one.smcl"
local fixture2 "`outdir'/fixture_two.smcl"
file open `fh' using "`fixture1'", write text replace
file write `fh' "{smcl}" _n "{com}. display 117001" _n "{res}ONE_117001" _n
file close `fh'
file open `fh' using "`fixture2'", write text replace
file write `fh' "{smcl}" _n "{com}. display 117002" _n "{res}TWO_117002" _n
file close `fh'

**# Config allowlist and precedence

* V117-T1: Unknown config keys cannot overwrite explicit convert arguments.
local ++test_total
local configdir "`outdir'/config"
capture mkdir "`configdir'"
file open `fh' using "`configdir'/.logdocrc", write text replace
file write `fh' "theme=dark" _n
file write `fh' "output=shadow.html" _n
file write `fh' "unknown=ignored" _n
file close `fh'
local expected "`outdir'/config_expected.html"
capture erase "`expected'"
capture erase "`configdir'/shadow.html"
capture noisily {
    cd "`configdir'"
    logdoc using "`fixture1'", output("`expected'") theme(light) replace quiet
    assert `"`r(output)'"' == `"`expected'"'
    assert "`r(theme)'" == "light"
    confirm file "`expected'"
    _logdoc_v117_contains using "`expected'", pattern("ONE_117001")
    assert r(found) == 1
    capture confirm file "`configdir'/shadow.html"
    assert _rc != 0
}
local t1_rc = _rc
capture cd "`oldpwd'"
if `t1_rc' == 0 {
    display as result "V117-T1 PASS: convert config keys are allowlisted"
    local ++test_pass
}
else {
    display as error "V117-T1 FAIL: config overwrote explicit convert state (rc=`t1_rc')"
    local ++test_fail
}

* V117-T2: Unknown config keys cannot overwrite explicit combine arguments.
local ++test_total
local combined_expected "`outdir'/combine_expected.html"
capture erase "`combined_expected'"
capture erase "`configdir'/shadow.html"
capture noisily {
    cd "`configdir'"
    logdoc combine using "`fixture1'" "`fixture2'", ///
        output("`combined_expected'") theme(light) replace quiet
    assert `"`r(output)'"' == `"`combined_expected'"'
    confirm file "`combined_expected'"
    _logdoc_v117_contains using "`combined_expected'", pattern("ONE_117001")
    assert r(found) == 1
    _logdoc_v117_contains using "`combined_expected'", pattern("TWO_117002")
    assert r(found) == 1
    capture confirm file "`configdir'/shadow.html"
    assert _rc != 0
}
local t2_rc = _rc
capture cd "`oldpwd'"
if `t2_rc' == 0 {
    display as result "V117-T2 PASS: combine config keys are allowlisted"
    local ++test_pass
}
else {
    display as error "V117-T2 FAIL: config overwrote explicit combine state (rc=`t2_rc')"
    local ++test_fail
}

**# Path and parser regressions

* V117-T3: format(both) uses the basename when splitting dotted paths.
local ++test_total
local dotdir "`outdir'/a.b"
capture mkdir "`dotdir'"
capture erase "`dotdir'/.hidden.html"
capture erase "`dotdir'/.hidden.md"
capture noisily {
    logdoc using "`fixture1'", output("`dotdir'/.hidden") ///
        format(both) replace quiet
    assert `"`r(output)'"' == `"`dotdir'/.hidden.html"'
    assert `"`r(secondary)'"' == `"`dotdir'/.hidden.md"'
    confirm file "`dotdir'/.hidden.html"
    confirm file "`dotdir'/.hidden.md"
    _logdoc_v117_contains using "`dotdir'/.hidden.html", pattern("ONE_117001")
    assert r(found) == 1
    _logdoc_v117_contains using "`dotdir'/.hidden.md", pattern("ONE_117001")
    assert r(found) == 1
}
if _rc == 0 {
    display as result "V117-T3 PASS: dotted-directory and dotfile both paths agree"
    local ++test_pass
}
else {
    display as error "V117-T3 FAIL: format(both) path mapping (rc=" _rc ")"
    local ++test_fail
}

* V117-T4: A comma inside a quoted combine filename is not the option separator.
local ++test_total
local comma_fixture "`outdir'/a,b.smcl"
copy "`fixture1'" "`comma_fixture'", replace
local comma_output "`outdir'/comma_combine.html"
capture erase "`comma_output'"
capture noisily {
    logdoc combine using "`comma_fixture'" "`fixture2'", ///
        output("`comma_output'") replace quiet
    assert r(n_sources) == 2
    confirm file "`comma_output'"
    _logdoc_v117_contains using "`comma_output'", pattern("ONE_117001")
    assert r(found) == 1
    _logdoc_v117_contains using "`comma_output'", pattern("TWO_117002")
    assert r(found) == 1
}
if _rc == 0 {
    display as result "V117-T4 PASS: quoted comma filename combines correctly"
    local ++test_pass
}
else {
    display as error "V117-T4 FAIL: quoted comma filename parsing (rc=" _rc ")"
    local ++test_fail
}

* V117-T5: A batch with no successful outputs must return nonzero.
local ++test_total
local batchin "`outdir'/batch_in"
local batchout "`outdir'/batch_out"
capture mkdir "`batchin'"
capture mkdir "`batchout'"
copy "`fixture1'" "`batchin'/one.smcl", replace
copy "`fixture2'" "`batchin'/two.smcl", replace
capture noisily logdoc batch, input("`batchin'/*.smcl") ///
    outdir("`batchout'") theme(bogus) replace quiet
local batch_rc = _rc
local batch_n = r(n_files)
local batch_failed = r(n_failed)
capture confirm file "`batchout'/one.html"
local batch_one = (_rc == 0)
capture confirm file "`batchout'/two.html"
local batch_two = (_rc == 0)
if `batch_rc' == 198 & `batch_n' == 2 & `batch_failed' == 2 & ///
    !`batch_one' & !`batch_two' {
    display as result "V117-T5 PASS: all-failed batch returns its child error"
    local ++test_pass
}
else {
    display as error "V117-T5 FAIL: all-failed batch rc=`batch_rc' files=`batch_n' failed=`batch_failed'"
    local ++test_fail
}

**# Helper state restoration

quietly run "`pkgdir'/logdoc.ado"
quietly run "`pkgdir'/logdoc_py.ado"
local state_cases "find_script resolve_python py_check_stata py_check_candidate py_find_script"
local state_number = 5
foreach state_case of local state_cases {
    local ++state_number
    local ++test_total
    capture noisily {
        _logdoc_v117_state_probe, case("`state_case'") ///
            renderer(`"`renderer'"') python(`"`python'"') scratch("`outdir'")
        assert r(restored) == 1
    }
    if _rc == 0 {
        display as result "V117-T`state_number' PASS: `state_case' restores varabbrev"
        local ++test_pass
    }
    else {
        display as error "V117-T`state_number' FAIL: `state_case' leaked varabbrev (rc=" _rc ")"
        local ++test_fail
        set varabbrev on
    }
}

* V117-T11: The missing-wkhtmltopdf branch restores varabbrev.
local ++test_total
local empty_path "`outdir'/empty_path"
local pdf_child "`outdir'/pdf_state_child.do"
local pdf_marker "`outdir'/pdf_state_ok.txt"
local pdf_child_out "`outdir'/pdf_state_child.out"
tempfile stata_which
capture mkdir "`empty_path'"
capture erase "`pdf_marker'"
shell command -v stata-mp > "`stata_which'" 2>/dev/null
file open `fh' using "`stata_which'", read text
file read `fh' stata_exe
file close `fh'
file open `fh' using "`pdf_child'", write text replace
file write `fh' "version 16.0" _n
file write `fh' "set processors 1" _n
file write `fh' `"sysdir set PLUS "`c(sysdir_plus)'""' _n
file write `fh' `"sysdir set PERSONAL "`c(sysdir_personal)'""' _n
file write `fh' `"quietly run "`pkgdir'/logdoc_py.ado""' _n
file write `fh' "set varabbrev on" _n
file write `fh' "_logdoc_py_check_pdf, path(found)" _n
file write `fh' "clear" _n
file write `fh' "set obs 1" _n
file write `fh' "generate long_variable_name = 1" _n
file write `fh' "assert long_variable == 1" _n
file write `fh' `"file open marker using "`pdf_marker'", write text replace"' _n
file write `fh' `"file write marker "ok" _n"' _n
file write `fh' "file close marker" _n
file close `fh'
shell env PATH="`empty_path'" "`stata_exe'" -b do "`pdf_child'" ///
    > "`pdf_child_out'" 2>&1
capture confirm file "`pdf_marker'"
if _rc == 0 {
    display as result "V117-T11 PASS: py_check_pdf restores varabbrev on rejection"
    local ++test_pass
}
else {
    display as error "V117-T11 FAIL: py_check_pdf leaked varabbrev on rejection"
    local ++test_fail
}

* V117-T12: The no-op install branch restores varabbrev.
local ++test_total
capture noisily {
    _logdoc_v117_state_probe, case("py_install") ///
        renderer(`"`renderer'"') python(`"`python'"') scratch("`outdir'")
    assert r(restored) == 1
}
if _rc == 0 {
    display as result "V117-T12 PASS: py_install restores varabbrev"
    local ++test_pass
}
else {
    display as error "V117-T12 FAIL: py_install leaked varabbrev (rc=" _rc ")"
    local ++test_fail
    set varabbrev on
}

**# Released help-table width oracle

* V117-T13: Shipped help fits Viewer columns and a positive control fails.
local ++test_total
local width_tool "`qadir'/tools/_logdoc_check_sthlp_width.py"
local width_result "`outdir'/width_result.txt"
local width_bad_result "`outdir'/width_bad_result.txt"
local width_bad "`outdir'/width_bad.sthlp"
file open `fh' using "`width_bad'", write text replace
file write `fh' "{smcl}" _n
file write `fh' "{synoptset 28 tabbed}{...}" _n
file write `fh' "{synopt:{opt foo}}xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx{p_end}" _n
file close `fh'
capture noisily {
    shell "`python'" "`width_tool'" ///
        "`pkgdir'/logdoc.sthlp" "`pkgdir'/logdoc_py.sthlp" ///
        --result-file "`width_result'" > "`outdir'/width_stdout.txt" 2>&1
    file open `fh' using "`width_result'", read text
    file read `fh' width_line
    file close `fh'
    assert "`width_line'" == "PASS"

    shell "`python'" "`width_tool'" "`width_bad'" ///
        --result-file "`width_bad_result'" > "`outdir'/width_bad_stdout.txt" 2>&1
    file open `fh' using "`width_bad_result'", read text
    file read `fh' width_bad_line
    file close `fh'
    assert substr("`width_bad_line'", 1, 4) == "FAIL"
}
if _rc == 0 {
    display as result "V117-T13 PASS: help width oracle passes shipped files and rejects overflow"
    local ++test_pass
}
else {
    display as error "V117-T13 FAIL: help width oracle (rc=" _rc ")"
    local ++test_fail
}

capture cd "`oldpwd'"
set varabbrev on
display as text "RESULT: test_logdoc_v117 tests=`test_total' pass=`test_pass' fail=`test_fail'"
if `test_fail' > 0 exit 9
