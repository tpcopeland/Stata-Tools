* test_datamap_paths.do - Path parsing regressions for metadata writers.
*
* 2026-11-10 (datamap 2.0.0): datadict is removed, so T2 (datadict's path
* contract) is ported to datamap's Markdown writer with a parenthesized
* output() path as well as a parenthesized saving() path, i.e. the same
* contract one level stricter than T1.  The map output is Markdown now
* (_path_map.md, was .txt).

clear all
set more off
version 16.0

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local tmp_dir "`qa_dir'/data"

capture mkdir "`tmp_dir'"
capture ado uninstall datamap
capture noisily net install datamap, from("`pkg_dir'") replace
local install_rc = _rc
if `install_rc' {
    display as error "local datamap install failed with rc `install_rc'"
    exit `install_rc'
}

local test_count = 0
local pass_count = 0
local fail_count = 0

local input "`tmp_dir'/_path_input.dta"
local map_output "`tmp_dir'/_path_map.md"
local map_meta "`tmp_dir'/_path_map_(paren).dta"
local dict_output "`tmp_dir'/_path_dict_(paren).md"
local dict_meta "`tmp_dir'/_path_dict_(paren).dta"
local check_meta "`tmp_dir'/_path_check_(paren).dta"

foreach f in "`input'" "`map_output'" "`map_meta'" "`dict_output'" "`dict_meta'" "`check_meta'" {
    capture erase `"`f'"'
}

clear
set obs 8
generate long id = _n
generate byte group = mod(_n, 2)
save "`input'", replace

* T1: datamap preserves the closing parenthesis in saving().
local ++test_count
capture noisily {
    datamap, single("`input'") output("`map_output'") saving("`map_meta'", replace)
    assert r(metadata) == "`map_meta'"
    confirm file "`map_meta'"
    capture confirm file "`tmp_dir'/_path_map_paren.dta"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: T`test_count' - datamap preserves parenthesized saving path"
    local ++pass_count
}
else {
    display as error "  FAIL: T`test_count' - datamap parenthesized saving path (rc=`=_rc')"
    local ++fail_count
}

* T2: the Markdown writer honours the contract for output() and saving() both.
local ++test_count
capture noisily {
    datamap, single("`input'") output("`dict_output'") saving("`dict_meta'", replace)
    assert r(metadata) == "`dict_meta'"
    confirm file "`dict_meta'"
    confirm file "`dict_output'"
    capture confirm file "`tmp_dir'/_path_dict_paren.dta"
    assert _rc != 0
    capture confirm file "`tmp_dir'/_path_dict_paren.md"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: T`test_count' - datamap preserves parenthesized output and saving paths"
    local ++pass_count
}
else {
    display as error "  FAIL: T`test_count' - datamap parenthesized output/saving path (rc=`=_rc')"
    local ++fail_count
}

* T3: dataprobe's optional profile writer also preserves the path.
local ++test_count
capture noisily {
    use "`input'", clear
    dataprobe, saving("`check_meta'", replace) warn
    confirm file "`check_meta'"
    * `confirm file' alone passes on an empty stub; the saved metadata must
    * actually be a readable dataset with rows, not a truncated placeholder.
    preserve
    use "`check_meta'", clear
    assert _N > 0
    restore
    capture confirm file "`tmp_dir'/_path_check_paren.dta"
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: T`test_count' - dataprobe preserves parenthesized saving path"
    local ++pass_count
}
else {
    display as error "  FAIL: T`test_count' - dataprobe parenthesized saving path (rc=`=_rc')"
    local ++fail_count
}

foreach f in "`input'" "`map_output'" "`map_meta'" "`dict_output'" "`dict_meta'" "`check_meta'" "`tmp_dir'/_path_map_paren.dta" "`tmp_dir'/_path_dict_paren.dta" "`tmp_dir'/_path_check_paren.dta" {
    capture erase `"`f'"'
}

display "RESULT: test_datamap_paths tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
exit 0
