clear all
set more off
version 16.0

* test_datamap_markdown_dictionary.do - datamap's Markdown dictionary features
*
* Ported 2026-11-10 (datamap 2.0.0, Phase 2) from test_datamap_markdown_dictionary.do, the
* functional suite for datadict 1.4.0 (richer returns, saving(), detail
* columns, escaping, manifest/config/separate, filelist quoting, exclude()
* patterns, complementary suppression).  datadict is removed; every
* assertion's intent is kept on datamap's single Markdown writer.  What
* changed with the port, test by test:
*   1 returns: r(nvars_total) -> r(nvars) (variables in the file, 4; the
*     Markdown says "4 (2 documented)"), r(nobs_total) -> r(nobs)
*   2 saving(): the unified 27-column table (class, storage_type, ...)
*   3 columns(): datadict's names and aliases (name, storage, stats) are
*     still accepted; storage and type are one column; the signature is
*     always printed ("- Data signature:"); detail/missing/stats/datasignature
*     are removed options (test_datamap_v200_removed.do asserts rc 198)
*   4 config(): the legacy detail key is ignored; the document heading is
*     "# <title>: <file>" with the file name as written (no title-casing)
*   6 exclude(): datamap keeps an excluded variable as a structure-only row
*     (datadict dropped it), so the assertions are: no value, no statistic
*   7 cells: "<value> <label>: n (p%)" and "suppressed (complementary)"
* Documents are read through _qa_md.do (Mata): a line ending in a backtick
* breaks a Stata-macro line reader.

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local tmp_dir "`qa_dir'/data"

capture mkdir "`tmp_dir'"

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace

do "`qa_dir'/_qa_md.do"

local bt = char(96)
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
local ++test_count
capture noisily {
    datamap group score, single("`dta'") output("`md'") ///
        columns(name label type storage format vallabel missing stats notes chars) ///
        saving("`meta'", replace)
    assert r(nfiles) == 1
    assert r(nvars) == 4
    assert r(nobs) == 10
    assert "`r(files)'" == "`dta'"
    assert "`r(mode)'" == "single"
    assert "`r(output)'" == "`md'"
    assert "`r(outputs)'" == "`md'"
    assert "`r(metadata)'" == "`meta'"
}
if _rc == 0 {
    display as result "  PASS: datamap richer returns and saving() complete"
    local ++pass_count
}
else {
    display as error "  FAIL: datamap richer returns and saving() (error `=_rc')"
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
    * the raw (unescaped) note and characteristic travel in saving()
    assert notes == "group note with pipe | and <angle>" if variable == "group"
    assert characteristics == "source=case report" if variable == "group"
    assert datasignature[1] != ""
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
    * storage is datadict's name for type: one column, not two
    qa_md_contains using "`md'", needle("| Variable | Label | Type | Format | Value label | Missing | Values/Statistics | Notes | Characteristics |") exact
    assert r(found) == 1
    qa_md_contains using "`md'", needle("Storage")
    assert r(found) == 0
    qa_md_contains using "`md'", needle("Treatment \| group &lt;raw&gt;")
    assert r(found) == 1
    qa_md_contains using "`md'", needle("Arm \| A")
    assert r(found) == 1
    qa_md_contains using "`md'", needle("- Data signature: `bt'")
    assert r(found) == 1
    qa_md_contains using "`md'", needle("group note with pipe \| and &lt;angle&gt;")
    assert r(found) == 1
    qa_md_contains using "`md'", needle("source=case report")
    assert r(found) == 1
    * a raw pipe or angle bracket from a label or note would break the table
    qa_md_contains using "`md'", needle("<raw>")
    assert r(found) == 0
    qa_md_contains using "`md'", needle("<angle>")
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: columns(), provenance, and Markdown escaping are present"
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
local ++test_count
capture noisily {
    * the config's detail key is datadict's and is ignored, not an error
    datamap, manifest("`manifest'") separate ///
        outdir("`tmp_dir'") suffix("_codebook") config("`config'")
    * read r() before the qa_md helpers, which return their own results
    assert r(nfiles) == 1
    assert "`r(mode)'" == "manifest"
    assert "`r(input_source)'" == "manifest"
    * separate mode: the files are r(outputs); r(output) is combined mode's
    assert "`r(outputs)'" == "`sepout'"
    assert "`r(output)'" == ""
    * r(nobs)/r(nvars) are single-file and memory mode only (1.10.6 datamap
    * rule; datadict's r(nobs_total)/r(nvars_total) have no successor), so the
    * four documented variables are read from the document
    qa_md_contains using "`sepout'", needle("- Variables: 4") exact
    assert r(found) == 1
    confirm file "`sepout'"
    qa_md_contains using "`sepout'", needle("# Configured Dictionary: v14_dictionary_source") exact
    assert r(found) == 1
    qa_md_contains using "`sepout'", needle("| Variable | Type | Format | Values/Statistics |") exact
    assert r(found) == 1
    * config(title) is a document option, so the file is a titled document
    qa_md_contains using "`sepout'", needle("**Last Updated:**")
    assert r(found) == 1
    * separate mode writes no combined document
    capture confirm file "`tmp_dir'/datamap.md"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: manifest(), config(), outdir(), suffix(), and columns() work in separate mode"
    local ++pass_count
}
else {
    display as error "  FAIL: manifest/config/separate output flow (error `=_rc')"
    local ++fail_count
}

* 2026-09-30 review cycle (owner C): filelist quoting, exclude() patterns,
* complementary small-cell suppression

local ++test_count
capture noisily {
    local sdir "`tmp_dir'/_dmmd dir (v2)"
    capture mkdir "`sdir'"
    sysuse auto, clear
    quietly save "`sdir'/one.dta", replace
    quietly save "`sdir'/two.dta", replace
    datamap, filelist("`sdir'/one" "`sdir'/two") output("`tmp_dir'/_dmmd_fl.md")
    assert r(nfiles) == 2
    assert "`r(mode)'" == "filelist"
    qa_md_contains using "`tmp_dir'/_dmmd_fl.md", needle("## 1. one") exact
    assert r(found) == 1
    qa_md_contains using "`tmp_dir'/_dmmd_fl.md", needle("## 2. two") exact
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
    * datadict dropped an excluded variable; datamap keeps it as a
    * structure-only row, so the privacy assertions are on values and
    * statistics, not on the name
    datamap, output("`tmp_dir'/_dmmd_ex.md") exclude(patient_*) continuous(age) ///
        saving("`tmp_dir'/_dmmd_ex.dta", replace)
    assert r(n_excluded) == 2
    assert "`r(excluded_vars)'" == "patient_id patient_no"
    qa_md_contains using "`tmp_dir'/_dmmd_ex.md", needle("| `bt'patient_id`bt' |  | long | 0 (0.0%) | excluded (structure only) |") exact
    assert r(found) == 1
    qa_md_contains using "`tmp_dir'/_dmmd_ex.md", needle("| `bt'patient_no`bt' |  | long | 0 (0.0%) | excluded (structure only) |") exact
    assert r(found) == 1
    * no value of either identifier (1001-1020, 5001-5020) reaches the file
    foreach v in 1001 1010 1020 5001 5010 5020 {
        qa_md_contains using "`tmp_dir'/_dmmd_ex.md", needle("`v'")
        assert r(found) == 0
    }
    qa_md_contains using "`tmp_dir'/_dmmd_ex.md", needle("| `bt'age`bt' |  | byte | 0 (0.0%) | N=20; mean=30.50;")
    assert r(found) == 1
    preserve
    use "`tmp_dir'/_dmmd_ex.dta", clear
    assert _N == 3
    assert inlist(class, "excluded") if inlist(variable, "patient_id", "patient_no")
    assert missing(mean, sd, p50, p25, p75, min, max) if inlist(variable, "patient_id", "patient_no")
    assert unique == 0 | missing(unique) if inlist(variable, "patient_id", "patient_no")
    assert class == "continuous" & mean == 30.5 if variable == "age"
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
    datamap, output("`tmp_dir'/_dmmd_cs.md") categorical(s)
    * 998 = 1000 - 2: printing it discloses the suppressed cell
    qa_md_contains using "`tmp_dir'/_dmmd_cs.md", needle("998 (")
    assert r(found) == 0
    qa_md_contains using "`tmp_dir'/_dmmd_cs.md", needle("0 No: suppressed (complementary)")
    assert r(found) == 1
    qa_md_contains using "`tmp_dir'/_dmmd_cs.md", needle("997 (")
    assert r(found) == 0
    * string values are quoted in the cell
    local q = char(34)
    qa_md_contains using "`tmp_dir'/_dmmd_cs.md", needle(`"`q'a`q': suppressed (complementary)"')
    assert r(found) == 1
    * two small cells that pool to >= mincell need no complement
    qa_md_contains using "`tmp_dir'/_dmmd_cs.md", needle("3: 994 (99.4%)")
    assert r(found) == 1
    datamap, output("`tmp_dir'/_dmmd_cs0.md") mincell(0)
    qa_md_contains using "`tmp_dir'/_dmmd_cs0.md", needle("0 No: 998 (99.8%)")
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
    quietly save "`tmp_dir'/_dmmd_r1.dta", replace
    drop c
    quietly save "`tmp_dir'/_dmmd_r2.dta", replace
    capture erase "`tmp_dir'/_dmmd_r.md"
    capture noisily datamap, filelist(`tmp_dir'/_dmmd_r1 `tmp_dir'/_dmmd_r2) ///
        exclude(a-c) output("`tmp_dir'/_dmmd_r.md")
    assert _rc == 111
    capture confirm file "`tmp_dir'/_dmmd_r.md"
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: an exclude() range unresolvable in one file errors r(111)"
    local ++pass_count
}
else {
    display as error "  FAIL: exclude() range fails open in a multi-file datamap run (error `=_rc')"
    local ++fail_count
}

capture erase "`md'"
capture erase "`meta'"
capture erase "`manifest'"
capture erase "`config'"
capture erase "`sepout'"
capture erase "`dta'"
foreach f in _dmmd_fl.md _dmmd_ex.md _dmmd_ex.dta _dmmd_cs.md _dmmd_cs0.md ///
    _dmmd_r1.dta _dmmd_r2.dta _dmmd_r.md {
    capture erase "`tmp_dir'/`f'"
}
foreach f in one.dta two.dta {
    capture erase "`tmp_dir'/_dmmd dir (v2)/`f'"
}
capture rmdir "`tmp_dir'/_dmmd dir (v2)"

display as text "datamap markdown dictionary tests: `pass_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_datamap_markdown_dictionary tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 9
}
display as result "ALL TESTS PASSED"
display "RESULT: test_datamap_markdown_dictionary tests=`test_count' pass=`pass_count' fail=`fail_count'"
exit 0
