clear all
set more off
version 16.0

* test_datadict_v14.do - Functional tests for datadict 1.4.0 features

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local tmp_dir "`qa_dir'/data"

capture mkdir "`tmp_dir'"

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace

capture program drop _dd14_contains
program define _dd14_contains, rclass
    version 16.0
    syntax using/ , NEEDLE(string)

    tempname fh
    local found 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`needle'"') > 0 local found 1
        file read `fh' line
    }
    file close `fh'
    return scalar found = `found'
end

local dta "`tmp_dir'/v14_dictionary_source.dta"
local md  "`tmp_dir'/v14_dictionary.md"
local meta "`tmp_dir'/v14_dictionary_meta.dta"
local manifest "`tmp_dir'/v14_manifest.txt"
local config "`tmp_dir'/v14_config.txt"
local sepout "`tmp_dir'/v14_dictionary_source_codebook.md"

clear
set obs 10
gen int id = _n
gen byte group = cond(_n <= 5, 1, 2)
gen double score = _n * 1.5
gen str12 comment = cond(_n <= 5, "alpha", "beta")
replace score = . in 10
label define groupl 1 "Arm | A" 2 "Arm <B>"
label values group groupl
label variable id "Identifier"
label variable group "Treatment | group <raw>"
label variable score "Score variable"
label variable comment "Free text"
notes group: group note with pipe | and <angle>
char group[source] "case report"
label data "Dictionary QA dataset"
capture erase "`dta'"
quietly save "`dta'", replace

capture erase "`md'"
capture erase "`meta'"
capture noisily datadict group score, single("`dta'") output("`md'") ///
    detail missing stats datasignature ///
    columns(name label type storage format vallabel missing stats notes chars) ///
    saving("`meta'", replace)
local rc = _rc
local ++test_count
if `rc' == 0 {
    assert r(nfiles) == 1
    assert r(nvars_total) == 2
    assert r(nobs_total) == 10
    assert "`r(mode)'" == "single"
    assert "`r(output)'" == "`md'"
    assert "`r(outputs)'" == "`md'"
    assert "`r(metadata)'" == "`meta'"
    display as result "  PASS: datadict v14 richer returns and saving() complete"
    local ++pass_count
}
else {
    display as error "  FAIL: datadict v14 richer returns and saving() (error `rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    preserve
    use "`meta'", clear
    assert _N == 2
    assert inlist("group", variable[1], variable[2])
    assert inlist("score", variable[1], variable[2])
    assert source[1] == "`dta'"
    assert output[1] == "`md'"
    assert N[1] == 10
    assert nvars[1] == 4
    quietly count if variable == "score" & missing == 1
    assert r(N) == 1
    quietly count if variable == "group" & value_label == "groupl"
    assert r(N) == 1
    restore
}
if _rc == 0 {
    display as result "  PASS: saving() metadata dataset has expected rows and fields"
    local ++pass_count
}
else {
    display as error "  FAIL: saving() metadata dataset content (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _dd14_contains using "`md'", needle("| Variable | Label | Type | Storage | Format | Value label | Missing | Statistics/Values | Notes | Characteristics |")
    assert r(found) == 1
    _dd14_contains using "`md'", needle("Treatment \| group &lt;raw&gt;")
    assert r(found) == 1
    _dd14_contains using "`md'", needle("Arm \| A")
    assert r(found) == 1
    _dd14_contains using "`md'", needle("**Data signature:**")
    assert r(found) == 1
    _dd14_contains using "`md'", needle("group note with pipe \| and &lt;angle&gt;")
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: detail columns, provenance, and Markdown escaping are present"
    local ++pass_count
}
else {
    display as error "  FAIL: Markdown detail/provenance/escaping checks (error `=_rc')"
    local ++fail_count
}

quietly file open mf using "`manifest'", write text replace
file write mf "`dta'" _n
file close mf

quietly file open cf using "`config'", write text replace
file write cf "title = Configured Dictionary" _n
file write cf "detail = yes" _n
file write cf "columns = name storage format values" _n
file close cf

capture erase "`sepout'"
capture noisily datadict, manifest("`manifest'") separate ///
    outdir("`tmp_dir'") suffix("_codebook") config("`config'")
local rc = _rc
local ++test_count
if `rc' == 0 {
    assert r(nfiles) == 1
    assert r(nvars_total) == 4
    assert "`r(mode)'" == "manifest"
    assert "`r(output)'" == "`sepout'"
    confirm file "`sepout'"
    _dd14_contains using "`sepout'", needle("# Configured Dictionary: v14_dictionary_source")
    assert r(found) == 1
    _dd14_contains using "`sepout'", needle("| Variable | Storage | Format | Values/Notes |")
    assert r(found) == 1
    display as result "  PASS: manifest(), config(), outdir(), suffix(), and columns() work in separate mode"
    local ++pass_count
}
else {
    display as error "  FAIL: manifest/config/separate output flow (error `rc')"
    local ++fail_count
}

* 2026-09-30 review cycle (owner C): filelist quoting, exclude() patterns,
* complementary small-cell suppression

local ++test_count
capture noisily {
    local sdir "`tmp_dir'/_dd14 dir (v2)"
    capture mkdir "`sdir'"
    sysuse auto, clear
    quietly save "`sdir'/one.dta", replace
    quietly save "`sdir'/two.dta", replace
    datadict, filelist("`sdir'/one" "`sdir'/two") output("`tmp_dir'/_dd14_fl.md")
    assert r(nfiles) == 2
    assert "`r(mode)'" == "filelist"
    _dd14_contains using "`tmp_dir'/_dd14_fl.md", needle("## 2. Two")
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: filelist() accepts quoted paths with spaces and parentheses"
    local ++pass_count
}
else {
    display as error "  FAIL: filelist() quoted spaced paths (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    set obs 20
    gen long patient_id = 1000 + _n
    gen long patient_no = 5000 + _n
    gen byte age = 20 + _n
    datadict, output("`tmp_dir'/_dd14_ex.md") stats exclude(patient_*) ///
        saving("`tmp_dir'/_dd14_ex.dta", replace)
    assert r(nvars_total) == 1
    _dd14_contains using "`tmp_dir'/_dd14_ex.md", needle("patient_")
    assert r(found) == 0
    preserve
    use "`tmp_dir'/_dd14_ex.dta", clear
    assert _N == 1
    assert variable[1] == "age"
    restore
}
if _rc == 0 {
    display as result "  PASS: exclude() expands wildcards in the dictionary and saving()"
    local ++pass_count
}
else {
    display as error "  FAIL: exclude() wildcard left identifiers in the dictionary (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    set obs 1000
    gen byte flag = _n <= 2
    label define flagl 0 "No" 1 "Yes"
    label values flag flagl
    gen byte u = _n <= 3
    gen str3 s = cond(_n <= 2, "b", "a")
    gen byte three = cond(_n <= 3, 1, cond(_n <= 6, 2, 3))
    datadict, output("`tmp_dir'/_dd14_cs.md") stats categorical(s)
    * 998 = 1000 - 2: printing it discloses the suppressed cell
    _dd14_contains using "`tmp_dir'/_dd14_cs.md", needle("(998;")
    assert r(found) == 0
    _dd14_contains using "`tmp_dir'/_dd14_cs.md", needle("0 No (suppressed, complementary)")
    assert r(found) == 1
    _dd14_contains using "`tmp_dir'/_dd14_cs.md", needle("(997;")
    assert r(found) == 0
    _dd14_contains using "`tmp_dir'/_dd14_cs.md", needle("a (suppressed, complementary)")
    assert r(found) == 1
    * two small cells that pool to >= mincell need no complement
    _dd14_contains using "`tmp_dir'/_dd14_cs.md", needle("3 (994; 99.4%)")
    assert r(found) == 1
    datadict, output("`tmp_dir'/_dd14_cs0.md") stats mincell(0)
    _dd14_contains using "`tmp_dir'/_dd14_cs0.md", needle("0 No (998; 99.8%)")
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: stats cells use complementary small-cell suppression"
    local ++pass_count
}
else {
    display as error "  FAIL: a lone suppressed stats cell is recoverable (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    set obs 20
    gen byte a = mod(_n, 2)
    gen byte b = mod(_n, 3)
    gen byte c = mod(_n, 4)
    quietly save "`tmp_dir'/_dd14_r1.dta", replace
    drop c
    quietly save "`tmp_dir'/_dd14_r2.dta", replace
    capture erase "`tmp_dir'/_dd14_r.md"
    capture noisily datadict, filelist(`tmp_dir'/_dd14_r1 `tmp_dir'/_dd14_r2) ///
        exclude(a-c) stats output("`tmp_dir'/_dd14_r.md")
    assert _rc == 111
    capture confirm file "`tmp_dir'/_dd14_r.md"
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: an exclude() range unresolvable in one file errors r(111)"
    local ++pass_count
}
else {
    display as error "  FAIL: exclude() range fails open in a multi-file datadict run (error `=_rc')"
    local ++fail_count
}

capture erase "`md'"
capture erase "`meta'"
capture erase "`manifest'"
capture erase "`config'"
capture erase "`sepout'"
capture erase "`dta'"
foreach f in _dd14_fl.md _dd14_ex.md _dd14_ex.dta _dd14_cs.md _dd14_cs0.md ///
    _dd14_r1.dta _dd14_r2.dta _dd14_r.md {
    capture erase "`tmp_dir'/`f'"
}
foreach f in one.dta two.dta {
    capture erase "`tmp_dir'/_dd14 dir (v2)/`f'"
}
capture rmdir "`tmp_dir'/_dd14 dir (v2)"

display as text "datadict v14 tests: `pass_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_datadict_v14 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 9
}
display as result "ALL TESTS PASSED"
display "RESULT: test_datadict_v14 tests=`test_count' pass=`pass_count' fail=`fail_count'"
exit 0
