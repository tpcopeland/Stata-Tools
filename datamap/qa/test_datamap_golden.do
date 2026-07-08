clear all
set more off
version 16.0

* test_datamap_golden.do - Normalized golden-output tests for datamap/datadict
* Generated: 2026-05-15
* Tests: normalized full-file output equivalence

capture program drop _golden_normalize
program define _golden_normalize
    version 16.0
    syntax using/ , Saving(string) [DATAMAP DATADICT]

    tempname fh_in fh_out
    file open `fh_in' using `"`using'"', read text
    capture erase `"`saving'"'
    file open `fh_out' using `"`saving'"', write text

    file read `fh_in' line
    while r(eof) == 0 {
        local norm `"`macval(line)'"'

        if `"`datamap'"' != "" {
            if regexm(`"`macval(norm)'"', "^Generated: .*") {
                local norm "Generated: <normalized>"
            }
        }

        if `"`datadict'"' != "" {
            if regexm(`"`macval(norm)'"', "^\*\*Source path:\*\* `.*`  $") {
                local norm "**Source path:** <normalized>"
            }
            if regexm(`"`macval(norm)'"', "^\*\*Description:\*\* .*  $") {
                local norm = substr(`"`macval(norm)'"', 1, length(`"`macval(norm)'"') - 2)
            }
            if regexm(`"`macval(norm)'"', "^\*\*Observations:\*\* .*  $") {
                local norm = substr(`"`macval(norm)'"', 1, length(`"`macval(norm)'"') - 2)
            }
            if regexm(`"`macval(norm)'"', "^\*\*Variables in file:\*\* .*  $") {
                local norm = substr(`"`macval(norm)'"', 1, length(`"`macval(norm)'"') - 2)
            }
            if regexm(`"`macval(norm)'"', "^\*\*Variables documented:\*\* .*  $") {
                local norm = substr(`"`macval(norm)'"', 1, length(`"`macval(norm)'"') - 2)
            }
            if regexm(`"`macval(norm)'"', "^\*\*File size:\*\* .* bytes") {
                local norm "**File size:** <normalized>"
            }
            if regexm(`"`macval(norm)'"', "^\*\*Last Updated:\*\* .*") & ///
               !regexm(`"`macval(norm)'"', "^\*\*Last Updated:\*\* [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$") {
                local norm "**Last Updated:** <normalized>"
            }
        }

        file write `fh_out' `"`macval(norm)'"' _n
        file read `fh_in' line
    }

    file close `fh_in'
    file close `fh_out'
end

capture program drop _golden_compare
program define _golden_compare
    version 16.0
    syntax , Expected(string) Actual(string) Name(string)

    tempname fh_expected fh_actual
    file open `fh_expected' using `"`expected'"', read text
    file open `fh_actual' using `"`actual'"', read text

    local lineno 1
    while 1 {
        file read `fh_expected' expected_line
        local eof_expected = r(eof)
        file read `fh_actual' actual_line
        local eof_actual = r(eof)

        if `eof_expected' & `eof_actual' {
            continue, break
        }

        if `eof_expected' != `eof_actual' {
            noisily display as error `"Golden mismatch: `name'"'
            noisily display as error "Line `lineno'"
            if `eof_expected' {
                noisily display as error "Expected: <EOF>"
            }
            else {
                noisily display as error `"Expected: `macval(expected_line)'"'
            }
            if `eof_actual' {
                noisily display as error "Actual:   <EOF>"
            }
            else {
                noisily display as error `"Actual:   `macval(actual_line)'"'
            }
            file close `fh_expected'
            file close `fh_actual'
            exit 9
        }

        if `"`macval(expected_line)'"' != `"`macval(actual_line)'"' {
            noisily display as error `"Golden mismatch: `name'"'
            noisily display as error "Line `lineno'"
            noisily display as error `"Expected: `macval(expected_line)'"'
            noisily display as error `"Actual:   `macval(actual_line)'"'
            file close `fh_expected'
            file close `fh_actual'
            exit 9
        }

        local ++lineno
    }

    file close `fh_expected'
    file close `fh_actual'
end

capture program drop _golden_check
program define _golden_check
    version 16.0
    syntax , Name(string) Raw(string) Norm(string) Expected(string) [DATAMAP DATADICT]

    _golden_normalize using `"`raw'"', saving(`"`norm'"') `datamap' `datadict'

    if `"$DATAMAP_UPDATE_GOLDEN"' == "1" {
        copy `"`norm'"' `"`expected'"', replace
        noisily display as result `"  UPDATED: `name'"'
    }
    else {
        _golden_compare, expected(`"`expected'"') actual(`"`norm'"') name(`"`name'"')
        noisily display as result `"  PASS: `name'"'
    }
end

* ============================================================
* Setup
* ============================================================

local qa_dir     "`c(pwd)'"
local pkg_dir    "`qa_dir'/.."
local data_dir   "`qa_dir'/data"
local golden_dir "`qa_dir'/golden"

capture mkdir "`golden_dir'"

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace

tempname tmpstub
local tmp_dir "`c(tmpdir)'/datamap_golden_`tmpstub'"
capture mkdir "`tmp_dir'"

local test_count 0

* ============================================================
* datamap golden cases
* ============================================================

local ++test_count
local raw  "`tmp_dir'/g1_datamap_compact.txt"
local norm "`tmp_dir'/g1_datamap_compact.norm.txt"
quietly datamap, single("`data_dir'/test_small") output("`raw'")
_golden_check, name("G1 compact datamap single default text") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g1_datamap_compact.txt") datamap

local ++test_count
local raw  "`tmp_dir'/g2_datamap_full.txt"
local norm "`tmp_dir'/g2_datamap_full.norm.txt"
quietly datamap, single("`data_dir'/test_cohort_miss") output("`raw'") ///
    exclude(id name) datesafe autodetect quality missing(pattern) samples(3)
_golden_check, name("G2 full datamap privacy quality missing samples") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g2_datamap_full.txt") datamap

local ++test_count
local raw  "`tmp_dir'/g3_datamap_append.txt"
local norm "`tmp_dir'/g3_datamap_append.norm.txt"
quietly datamap, single("`data_dir'/test_small") output("`raw'")
quietly datamap, single("`data_dir'/test_single") output("`raw'") append
_golden_check, name("G3 datamap append two calls") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g3_datamap_append.txt") datamap

local sep_dir "`tmp_dir'/separate_datamap"
capture mkdir "`sep_dir'"
capture erase "`sep_dir'/test_cohort.dta"
capture erase "`sep_dir'/test_small.dta"
copy "`data_dir'/test_cohort.dta" "`sep_dir'/test_cohort.dta"
copy "`data_dir'/test_small.dta" "`sep_dir'/test_small.dta"
quietly datamap, filelist("`sep_dir'/test_cohort" "`sep_dir'/test_small") separate

local ++test_count
local raw  "`sep_dir'/test_cohort_map.txt"
local norm "`tmp_dir'/g4_datamap_separate_test_cohort.norm.txt"
_golden_check, name("G4 datamap separate filelist test_cohort") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g4_datamap_separate_test_cohort_map.txt") datamap

local ++test_count
local raw  "`sep_dir'/test_small_map.txt"
local norm "`tmp_dir'/g4_datamap_separate_test_small.norm.txt"
_golden_check, name("G4 datamap separate filelist test_small") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g4_datamap_separate_test_small_map.txt") datamap

* ============================================================
* datadict golden cases
* ============================================================

local ++test_count
local raw  "`tmp_dir'/g5_datadict_basic.md"
local norm "`tmp_dir'/g5_datadict_basic.norm.md"
quietly datadict, single("`data_dir'/test_cohort_miss") output("`raw'") missing stats
_golden_check, name("G5 basic datadict single missing stats") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g5_datadict_basic.md") datadict

local ++test_count
local raw  "`tmp_dir'/g6_datadict_full.md"
local norm "`tmp_dir'/g6_datadict_full.norm.md"
quietly datadict, single("`data_dir'/test_cohort_miss") output("`raw'") ///
    title("MS Cohort") subtitle("Golden data dictionary") ///
    version("2.0") author("Timothy P Copeland, Karolinska Institutet") ///
    date("2026-01-01") notes("Golden notes for refactor safety.") ///
    changelog("v2.0: Golden harness baseline") missing stats
_golden_check, name("G6 full datadict metadata explicit date") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g6_datadict_full.md") datadict

local sep_dd_dir "`tmp_dir'/separate_datadict"
capture mkdir "`sep_dd_dir'"
capture erase "`sep_dd_dir'/test_cohort.dta"
capture erase "`sep_dd_dir'/test_small.dta"
copy "`data_dir'/test_cohort.dta" "`sep_dd_dir'/test_cohort.dta"
copy "`data_dir'/test_small.dta" "`sep_dd_dir'/test_small.dta"
quietly datadict, filelist("`sep_dd_dir'/test_cohort" "`sep_dd_dir'/test_small") separate

local ++test_count
local raw  "`sep_dd_dir'/test_cohort_dictionary.md"
local norm "`tmp_dir'/g7_datadict_separate_test_cohort.norm.md"
_golden_check, name("G7 datadict separate filelist test_cohort") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g7_datadict_separate_test_cohort_dictionary.md") datadict

local ++test_count
local raw  "`sep_dd_dir'/test_small_dictionary.md"
local norm "`tmp_dir'/g7_datadict_separate_test_small.norm.md"
_golden_check, name("G7 datadict separate filelist test_small") ///
    raw("`raw'") norm("`norm'") ///
    expected("`golden_dir'/g7_datadict_separate_test_small_dictionary.md") datadict

* ============================================================
* Cleanup and summary
* ============================================================

capture erase "`tmp_dir'/g1_datamap_compact.txt"
capture erase "`tmp_dir'/g1_datamap_compact.norm.txt"
capture erase "`tmp_dir'/g2_datamap_full.txt"
capture erase "`tmp_dir'/g2_datamap_full.norm.txt"
capture erase "`tmp_dir'/g3_datamap_append.txt"
capture erase "`tmp_dir'/g3_datamap_append.norm.txt"
capture erase "`tmp_dir'/g5_datadict_basic.md"
capture erase "`tmp_dir'/g5_datadict_basic.norm.md"
capture erase "`tmp_dir'/g6_datadict_full.md"
capture erase "`tmp_dir'/g6_datadict_full.norm.md"
capture erase "`tmp_dir'/g4_datamap_separate_test_cohort.norm.txt"
capture erase "`tmp_dir'/g4_datamap_separate_test_small.norm.txt"
capture erase "`tmp_dir'/g7_datadict_separate_test_cohort.norm.md"
capture erase "`tmp_dir'/g7_datadict_separate_test_small.norm.md"
capture erase "`sep_dir'/test_cohort.dta"
capture erase "`sep_dir'/test_small.dta"
capture erase "`sep_dir'/test_cohort_map.txt"
capture erase "`sep_dir'/test_small_map.txt"
capture erase "`sep_dd_dir'/test_cohort.dta"
capture erase "`sep_dd_dir'/test_small.dta"
capture erase "`sep_dd_dir'/test_cohort_dictionary.md"
capture erase "`sep_dd_dir'/test_small_dictionary.md"
capture rmdir "`sep_dir'"
capture rmdir "`sep_dd_dir'"
capture rmdir "`tmp_dir'"

display as result "Golden-output tests passed: `test_count'"
display as result "ALL TESTS PASSED"
display "RESULT: test_datamap_golden tests=`test_count' pass=`test_count' fail=0"
exit 0
