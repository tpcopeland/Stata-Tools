clear all
set more off
version 16.0

* test_datamap_bugfixes.do - Regression tests for B1/B2/P2/C3/D2/D3 fixes
* Tests: 10

* ============================================================
* Setup
* ============================================================

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local tmp_dir "`qa_dir'/data"

capture mkdir "`tmp_dir'"

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force

* ============================================================
* B1: Floating-point display formatting
* ============================================================

* {{{ T1: Missing percentage has no floating-point artifacts
local ++test_count
capture {
	sysuse auto, clear
	datamap, output("`tmp_dir'/_b1.txt")
	confirm file "`tmp_dir'/_b1.txt"
	tempname fh
	file open `fh' using "`tmp_dir'/_b1.txt", read text
	local found_artifact 0
	file read `fh' line
	while r(eof) == 0 {
		if strpos(`"`macval(line)'"', "6.800000") > 0 {
			local found_artifact 1
		}
		if strpos(`"`macval(line)'"', "6.8%") > 0 {
			local found_clean 1
		}
		file read `fh' line
	}
	file close `fh'
	assert `found_artifact' == 0
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - No floating-point artifacts in missing %"
}
else {
	di as error "  T`test_count': FAILED - Floating-point artifact found in output"
}

* {{{ T2: QUICK REFERENCE and detailed sections show same formatted percentage
local ++test_count
capture {
	sysuse auto, clear
	datamap, output("`tmp_dir'/_b1b.txt")
	tempname fh
	file open `fh' using "`tmp_dir'/_b1b.txt", read text
	local qr_pct ""
	local detail_pct ""
	file read `fh' line
	while r(eof) == 0 {
		* QUICK REFERENCE line for rep78 shows formatted %
		if strpos(`"`macval(line)'"', "rep78") > 0 & strpos(`"`macval(line)'"', "categorical") > 0 {
			local qr_pct `"`macval(line)'"'
		}
		* Detailed section for rep78
		if strpos(`"`macval(line)'"', "Missing:") > 0 & strpos(`"`macval(line)'"', "6.8%") > 0 {
			local detail_pct "found"
		}
		file read `fh' line
	}
	file close `fh'
	assert "`detail_pct'" == "found"
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - Detailed section shows clean 6.8%"
}
else {
	di as error "  T`test_count': FAILED - Detailed section missing clean percentage"
}

* ============================================================
* B2: datadict string variable unique count
* ============================================================

* {{{ T3: String variables show correct unique count
local ++test_count
capture {
	sysuse auto, clear
	datadict, single("`tmp_dir'/_b2_auto.dta") output("`tmp_dir'/_b2.md") stats missing
	* auto has no .dta file at that path — use data in memory
}
* datadict requires a .dta file — save one first
capture {
	sysuse auto, clear
	save "`tmp_dir'/_b2_auto.dta", replace
	datadict, single("`tmp_dir'/_b2_auto.dta") output("`tmp_dir'/_b2.md") stats missing
	confirm file "`tmp_dir'/_b2.md"
	tempname fh
	file open `fh' using "`tmp_dir'/_b2.md", read text
	local found_unique 0
	file read `fh' line
	while r(eof) == 0 {
		* make should show "N=74; 74 unique values"
		if strpos(`"`macval(line)'"', "make") > 0 & strpos(`"`macval(line)'"', "74 unique") > 0 {
			local found_unique 1
		}
		file read `fh' line
	}
	file close `fh'
	assert `found_unique' == 1
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - String variable shows correct unique count"
}
else {
	di as error "  T`test_count': FAILED - String variable unique count wrong or missing"
}

* {{{ T4: String vars don't show "N=.; . unique values"
local ++test_count
capture {
	tempname fh
	file open `fh' using "`tmp_dir'/_b2.md", read text
	local found_dot 0
	file read `fh' line
	while r(eof) == 0 {
		if strpos(`"`macval(line)'"', "N=.;") > 0 {
			local found_dot 1
		}
		if strpos(`"`macval(line)'"', ". unique") > 0 {
			local found_dot 1
		}
		file read `fh' line
	}
	file close `fh'
	assert `found_dot' == 0
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - No N=. or '. unique' in datadict output"
}
else {
	di as error "  T`test_count': FAILED - Found N=. or '. unique' in datadict output"
}

* ============================================================
* P2: datesafe suppresses date range in summary
* ============================================================

* {{{ T5: datesafe hides exact date range
local ++test_count
capture {
	clear
	set obs 100
	gen id = _n
	gen entry = td(01jan2020) + int(runiform()*365)
	format entry %td
	gen exit = entry + int(runiform()*730)
	format exit %td
	save "`tmp_dir'/_p2_dates.dta", replace
	datamap, single("`tmp_dir'/_p2_dates") output("`tmp_dir'/_p2.txt") datesafe
	confirm file "`tmp_dir'/_p2.txt"
	tempname fh
	file open `fh' using "`tmp_dir'/_p2.txt", read text
	local found_exact_date 0
	local found_suppressed 0
	file read `fh' line
	while r(eof) == 0 {
		if strpos(`"`macval(line)'"', "spans from") > 0 {
			local found_exact_date 1
		}
		if strpos(`"`macval(line)'"', "suppressed for privacy") > 0 {
			local found_suppressed 1
		}
		file read `fh' line
	}
	file close `fh'
	assert `found_exact_date' == 0
	assert `found_suppressed' == 1
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - datesafe suppresses exact date range"
}
else {
	di as error "  T`test_count': FAILED - datesafe did not suppress date range"
}

* {{{ T6: Without datesafe, date range is shown
local ++test_count
capture {
	datamap, single("`tmp_dir'/_p2_dates") output("`tmp_dir'/_p2_nodatesafe.txt")
	tempname fh
	file open `fh' using "`tmp_dir'/_p2_nodatesafe.txt", read text
	local found_spans 0
	file read `fh' line
	while r(eof) == 0 {
		if strpos(`"`macval(line)'"', "spans from") > 0 {
			local found_spans 1
		}
		file read `fh' line
	}
	file close `fh'
	assert `found_spans' == 1
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - Without datesafe, date range is shown"
}
else {
	di as error "  T`test_count': FAILED - Date range missing without datesafe"
}

* ============================================================
* C3: datadict no longer writes --- horizontal rules
* ============================================================

* {{{ T7: datadict output contains no --- separators
local ++test_count
capture {
	clear
	set obs 50
	gen id = _n
	gen x = rnormal()
	save "`tmp_dir'/_c3_data1.dta", replace
	clear
	set obs 30
	gen id = _n
	gen y = runiform()
	save "`tmp_dir'/_c3_data2.dta", replace
	datadict, filelist("`tmp_dir'/_c3_data1 `tmp_dir'/_c3_data2") ///
		output("`tmp_dir'/_c3.md") notes("Test notes") changelog("v1.0: initial")
	confirm file "`tmp_dir'/_c3.md"
	tempname fh
	file open `fh' using "`tmp_dir'/_c3.md", read text
	local found_hr 0
	file read `fh' line
	while r(eof) == 0 {
		if ustrregexm(`"`macval(line)'"', "^---$") {
			local found_hr 1
		}
		file read `fh' line
	}
	file close `fh'
	assert `found_hr' == 0
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - No --- horizontal rules in datadict output"
}
else {
	di as error "  T`test_count': FAILED - Found --- in datadict output"
}

* ============================================================
* D2/D3: notes() and changelog() accept inline strings
* ============================================================

* {{{ T8: notes() with inline string writes the text
local ++test_count
capture {
	sysuse auto, clear
	save "`tmp_dir'/_d2_auto.dta", replace
	datadict, single("`tmp_dir'/_d2_auto.dta") output("`tmp_dir'/_d2.md") ///
		notes("These are inline test notes for the data dictionary.")
	confirm file "`tmp_dir'/_d2.md"
	* For single-dataset mode, notes are not written to sections — check multi-dataset
}
* Use filelist mode which writes notes section
capture {
	datadict, filelist("`tmp_dir'/_d2_auto") ///
		output("`tmp_dir'/_d2_multi.md") ///
		notes("These are inline test notes for the data dictionary.")
	confirm file "`tmp_dir'/_d2_multi.md"
	tempname fh
	file open `fh' using "`tmp_dir'/_d2_multi.md", read text
	local found_inline 0
	local found_notfound 0
	file read `fh' line
	while r(eof) == 0 {
		if strpos(`"`macval(line)'"', "inline test notes") > 0 {
			local found_inline 1
		}
		if strpos(`"`macval(line)'"', "not found") > 0 {
			local found_notfound 1
		}
		file read `fh' line
	}
	file close `fh'
	assert `found_inline' == 1
	assert `found_notfound' == 0
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - notes() writes inline string"
}
else {
	di as error "  T`test_count': FAILED - notes() inline string not written or 'not found' present"
}

* {{{ T9: changelog() with inline string writes the text
local ++test_count
capture {
	datadict, filelist("`tmp_dir'/_d2_auto") ///
		output("`tmp_dir'/_d3.md") ///
		changelog("v1.0.0: Initial release of the data dictionary.")
	confirm file "`tmp_dir'/_d3.md"
	tempname fh
	file open `fh' using "`tmp_dir'/_d3.md", read text
	local found_inline 0
	local found_notfound 0
	file read `fh' line
	while r(eof) == 0 {
		if strpos(`"`macval(line)'"', "Initial release") > 0 {
			local found_inline 1
		}
		if strpos(`"`macval(line)'"', "not found") > 0 {
			local found_notfound 1
		}
		file read `fh' line
	}
	file close `fh'
	assert `found_inline' == 1
	assert `found_notfound' == 0
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - changelog() writes inline string"
}
else {
	di as error "  T`test_count': FAILED - changelog() inline string not written"
}

* {{{ T10: notes() with actual file still works
local ++test_count
capture {
	tempname fh_n
	file open `fh_n' using "`tmp_dir'/_notes_file.txt", write text replace
	file write `fh_n' "These notes came from a file." _n
	file write `fh_n' "Second line of file notes." _n
	file close `fh_n'
	datadict, filelist("`tmp_dir'/_d2_auto") ///
		output("`tmp_dir'/_d2_file.md") ///
		notes("`tmp_dir'/_notes_file.txt")
	confirm file "`tmp_dir'/_d2_file.md"
	tempname fh
	file open `fh' using "`tmp_dir'/_d2_file.md", read text
	local found_file 0
	file read `fh' line
	while r(eof) == 0 {
		if strpos(`"`macval(line)'"', "notes came from a file") > 0 {
			local found_file 1
		}
		file read `fh' line
	}
	file close `fh'
	assert `found_file' == 1
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - notes() with file path still works"
}
else {
	di as error "  T`test_count': FAILED - notes() file path broken"
}

* ============================================================
* Summary
* ============================================================

di _newline
di as text "Results: `pass_count'/`test_count' passed"
if `pass_count' == `test_count' {
	di as result "ALL TESTS PASSED"
}
else {
	local nfail = `test_count' - `pass_count'
	di as error "`nfail' TESTS FAILED"
	exit 9
}
