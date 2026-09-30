clear all
set more off
version 16.0

* test_datamap_bugfixes.do - Regression tests for B1/B2/P2/C3/D2/D3 fixes
* Tests: 26

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
	* Seed: 271828
	set seed 271828
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
* Use filelist mode which writes notes section
capture {
	sysuse auto, clear
	save "`tmp_dir'/_d2_auto.dta", replace
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
* 2026-09-30 review cycle (owner C): privacy, input, and label fixes
* ============================================================

capture program drop _bf_has
program define _bf_has, rclass
	version 16.0
	syntax using/ , NEEDLE(string) [EXACT]
	tempname fh
	local found 0
	file open `fh' using `"`using'"', read text
	file read `fh' line
	while r(eof) == 0 {
		if "`exact'" != "" {
			if `"`macval(line)'"' == `"`needle'"' local found 1
		}
		else if strpos(`"`macval(line)'"', `"`needle'"') > 0 local found 1
		file read `fh' line
	}
	file close `fh'
	return scalar found = `found'
end

* {{{ T11: survival event rate honours mincell() (2 events in 1000 rows)
local ++test_count
capture noisily {
	clear
	set obs 1000
	gen byte died = _n <= 2
	gen double survtime = _n
	datamap, output("`tmp_dir'/_c11.txt") detect(survival)
	* 0.2% of the printed 1000 observations is the 2-event count
	_bf_has using "`tmp_dir'/_c11.txt", needle("died rate: .2%")
	assert r(found) == 0
	_bf_has using "`tmp_dir'/_c11.txt", needle("died rate: suppressed")
	assert r(found) == 1
	* above the threshold in both cells the rate still prints
	replace died = _n <= 100
	datamap, output("`tmp_dir'/_c11b.txt") detect(survival)
	_bf_has using "`tmp_dir'/_c11b.txt", needle("died rate: 10%")
	assert r(found) == 1
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - survival event rate suppressed below mincell"
}
else {
	di as error "  T`test_count': FAILED - survival event rate leaks a small cell (rc=`=_rc')"
}

* {{{ T12: survival time range of a date variable obeys datesafe
local ++test_count
capture noisily {
	clear
	set obs 30
	gen double followup_time = td(01jan2020) + _n
	format followup_time %td
	gen byte died = _n > 20
	datamap, output("`tmp_dir'/_c12.txt") detect(survival) datesafe
	* 21916 = 01jan2020 + 1: the raw day number is an exact date
	_bf_has using "`tmp_dir'/_c12.txt", needle("21916")
	assert r(found) == 0
	_bf_has using "`tmp_dir'/_c12.txt", needle("followup_time range")
	assert r(found) == 0
	* without datesafe the range prints as dates, not day counts
	datamap, output("`tmp_dir'/_c12b.txt") detect(survival)
	_bf_has using "`tmp_dir'/_c12b.txt", needle("followup_time range: 2020/01/02 to 2020/01/31")
	assert r(found) == 1
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - survival time range respects datesafe"
}
else {
	di as error "  T`test_count': FAILED - survival time range leaks exact dates (rc=`=_rc')"
}

* {{{ T13: complementary suppression in text, binary, and JSON tables
local ++test_count
capture noisily {
	clear
	set obs 1000
	gen byte flag = _n <= 2
	gen str3 s = cond(_n <= 3, "b", "a")
	gen byte three = cond(_n <= 3, 1, cond(_n <= 6, 2, 3))
	datamap, output("`tmp_dir'/_c13.txt") detect(binary) categorical(s)
	* 998 = 1000 - 0 missing - 2: printing it discloses the suppressed cell
	_bf_has using "`tmp_dir'/_c13.txt", needle("0 = 0: 998")
	assert r(found) == 0
	_bf_has using "`tmp_dir'/_c13.txt", needle("0 = 0: suppressed (complementary)")
	assert r(found) == 1
	_bf_has using "`tmp_dir'/_c13.txt", needle("0 (0): suppressed (complementary)")
	assert r(found) == 1
	_bf_has using "`tmp_dir'/_c13.txt", needle(`""a": suppressed (complementary)"')
	assert r(found) == 1
	* two small cells that pool to >= mincell need no complement
	_bf_has using "`tmp_dir'/_c13.txt", needle("3 = 3: 994 (99.4%)")
	assert r(found) == 1
	datamap, output("`tmp_dir'/_c13.json") format(json) categorical(s)
	_bf_has using "`tmp_dir'/_c13.json", needle(`""count": 998"')
	assert r(found) == 0
	_bf_has using "`tmp_dir'/_c13.json", needle(`""count": 997"')
	assert r(found) == 0
	_bf_has using "`tmp_dir'/_c13.json", needle(`""count": 994"')
	assert r(found) == 1
	* mincell(0) still shows every cell
	datamap, output("`tmp_dir'/_c13z.txt") mincell(0)
	_bf_has using "`tmp_dir'/_c13z.txt", needle("0 = 0: 998 (99.8%)")
	assert r(found) == 1
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - complementary small-cell suppression"
}
else {
	di as error "  T`test_count': FAILED - a lone suppressed cell is recoverable (rc=`=_rc')"
}

* {{{ T14: missing(pattern) withholds the complement of a lone small pattern
local ++test_count
capture noisily {
	clear
	set obs 100
	gen a = cond(_n <= 4, ., 1)
	gen b = cond(_n > 4 & _n <= 10, ., 1)
	datamap, output("`tmp_dir'/_c14.txt") missing(pattern)
	* patterns: ++ 90, +. 6, .+ 4; 100 - 90 - 6 recovers the 4
	_bf_has using "`tmp_dir'/_c14.txt", needle(".+: suppressed (<5)")
	assert r(found) == 1
	_bf_has using "`tmp_dir'/_c14.txt", needle("+.: suppressed (complementary)")
	assert r(found) == 1
	_bf_has using "`tmp_dir'/_c14.txt", needle("++: 90 (90%)")
	assert r(found) == 1
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - missing-pattern complementary suppression"
}
else {
	di as error "  T`test_count': FAILED - missing-pattern complement recoverable (rc=`=_rc')"
}

* {{{ T15: a zero-observation dataset file is documented, text and JSON
local ++test_count
capture noisily {
	clear
	set obs 0
	gen x = .
	gen str5 s = ""
	format x %td
	gen byte k = .
	quietly save "`tmp_dir'/_c15_zero.dta", replace
	sysuse auto, clear
	datamap, single("`tmp_dir'/_c15_zero") output("`tmp_dir'/_c15.txt") ///
		autodetect missing(pattern) quality
	assert r(nobs) == 0
	assert r(nvars) == 3
	_bf_has using "`tmp_dir'/_c15.txt", needle("Observations: 0")
	assert r(found) == 1
	datamap, single("`tmp_dir'/_c15_zero") output("`tmp_dir'/_c15.json") format(json)
	_bf_has using "`tmp_dir'/_c15.json", needle(`""observations": 0,"')
	assert r(found) == 1
	* the caller's data came back
	assert _N == 74
	confirm variable make
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - zero-observation file documented"
}
else {
	di as error "  T`test_count': FAILED - zero-observation file refused (rc=`=_rc')"
}

* {{{ T16: filelist() accepts quoted names with spaces and parentheses
local ++test_count
capture noisily {
	local sdir "`tmp_dir'/_c16 dir (v2)"
	capture mkdir "`sdir'"
	sysuse auto, clear
	quietly save "`sdir'/one.dta", replace
	quietly save "`sdir'/two.dta", replace
	datamap, filelist("`sdir'/one" "`sdir'/two") output("`tmp_dir'/_c16.txt")
	assert r(nfiles) == 2
	assert "`r(input_source)'" == "filelist"
	_bf_has using "`tmp_dir'/_c16.txt", needle("DATASET: two.dta")
	assert r(found) == 1
	* an unquoted list still splits on spaces
	quietly save "`tmp_dir'/_c16a.dta", replace
	quietly save "`tmp_dir'/_c16b.dta", replace
	datamap, filelist(`tmp_dir'/_c16a `tmp_dir'/_c16b) output("`tmp_dir'/_c16u.txt")
	assert r(nfiles) == 2
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - filelist() with quoted spaced paths"
}
else {
	di as error "  T`test_count': FAILED - filelist() lost the quotes around a spaced path (rc=`=_rc')"
}

* {{{ T17: exclude() expands wildcards and ranges; samples() masks them
local ++test_count
capture noisily {
	clear
	set obs 20
	gen long patient_id = 1000 + _n
	gen long patient_no = 5000 + _n
	gen byte age = 20 + _n
	gen byte grp = mod(_n, 2)
	datamap, output("`tmp_dir'/_c17.txt") exclude(patient_*) samples(3)
	assert r(n_excluded) == 2
	assert "`r(excluded_vars)'" == "patient_id patient_no"
	_bf_has using "`tmp_dir'/_c17.txt", needle("1001")
	assert r(found) == 0
	_bf_has using "`tmp_dir'/_c17.txt", needle("5001")
	assert r(found) == 0
	_bf_has using "`tmp_dir'/_c17.txt", needle("[MASKED] | [MASKED] |")
	assert r(found) == 1
	* a range
	datamap, output("`tmp_dir'/_c17b.txt") exclude(patient_id-patient_no)
	assert r(n_excluded) == 2
	* names absent from the dataset are still ignored
	datamap, output("`tmp_dir'/_c17c.txt") exclude(patient_id nosuchvar ssn*)
	assert r(n_excluded) == 1
	* abbreviations are not expanded
	datamap, output("`tmp_dir'/_c17d.txt") exclude(patient)
	assert r(n_excluded) == 0
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - exclude() wildcard and range expansion"
}
else {
	di as error "  T`test_count': FAILED - exclude() pattern excluded nothing (rc=`=_rc')"
}

* {{{ T18: VALUE LABEL DEFINITIONS lists levels of every user of the label
local ++test_count
capture noisily {
	clear
	set obs 20
	gen byte a = mod(_n, 3)
	gen byte b = 3 + mod(_n, 2)
	label define ab 0 "zero" 1 "one" 2 "two" 3 "three" 4 "four"
	label values a ab
	label values b ab
	datamap, output("`tmp_dir'/_c18.txt") mincell(0)
	_bf_has using "`tmp_dir'/_c18.txt", needle("ab (used by: a b)")
	assert r(found) == 1
	* whole-line match: the frequency tables also contain "4 = four: ..."
	_bf_has using "`tmp_dir'/_c18.txt", needle("  0 = zero") exact
	assert r(found) == 1
	_bf_has using "`tmp_dir'/_c18.txt", needle("  4 = four") exact
	assert r(found) == 1
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - value label definitions cover all users"
}
else {
	di as error "  T`test_count': FAILED - value label definitions read only the first user (rc=`=_rc')"
}

* {{{ T19: missing() complete-case count obeys mincell()
local ++test_count
capture noisily {
	clear
	set obs 1000
	gen a = cond(_n <= 3, 1, .)
	gen double k = _n
	datamap, output("`tmp_dir'/_c19.txt") missing(pattern)
	* 3 complete rows: the +. pattern count, printed raw beside its suppression
	_bf_has using "`tmp_dir'/_c19.txt", needle("Observations with complete data: 3")
	assert r(found) == 0
	_bf_has using "`tmp_dir'/_c19.txt", needle("Observations with complete data: suppressed")
	assert r(found) == 1
	datamap, output("`tmp_dir'/_c19b.txt") missing(detail) mincell(0)
	_bf_has using "`tmp_dir'/_c19b.txt", needle("Observations with complete data: 3 (.3%)")
	assert r(found) == 1
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - complete-case count suppressed below mincell"
}
else {
	di as error "  T`test_count': FAILED - complete-case count leaks a small cell (rc=`=_rc')"
}

* {{{ T20: saving() rows for excluded variables carry no value label, notes, chars
local ++test_count
capture noisily {
	clear
	set obs 20
	gen byte ssn = mod(_n, 2)
	label define ssnl 0 "Anna Svensson" 1 "Bo Berg"
	label values ssn ssnl
	notes ssn : raw value 19650101-1234
	char ssn[origin] "national register 19650101-1234"
	gen byte grp = mod(_n, 3)
	label define grpl 0 "a" 1 "b" 2 "c"
	label values grp grpl
	notes grp : kept note
	char grp[origin] "kept char"
	datamap, output("`tmp_dir'/_c20.txt") exclude(ssn) ///
		saving("`tmp_dir'/_c20_meta.dta", replace)
	datacheck, exclude(ssn) saving("`tmp_dir'/_c20_dc.dta", replace)
	foreach f in _c20_meta _c20_dc {
		preserve
		use "`tmp_dir'/`f'.dta", clear
		quietly count if variable == "ssn"
		assert r(N) == 1
		quietly count if variable == "ssn" & class == "excluded"
		assert r(N) == 1
		quietly count if variable == "ssn" & (value_label != "" | notes != "" | characteristics != "")
		assert r(N) == 0
		* a non-excluded variable keeps all three
		quietly count if variable == "grp" & value_label == "grpl" & ///
			strpos(notes, "kept note") & strpos(characteristics, "kept char")
		assert r(N) == 1
		restore
	}
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - saving() withholds excluded value label, notes, chars"
}
else {
	di as error "  T`test_count': FAILED - saving() leaks excluded value label, notes, or chars (rc=`=_rc')"
}

* {{{ T21: an exclude() range that does not resolve in one file fails closed
local ++test_count
capture noisily {
	clear
	set obs 20
	gen byte a = mod(_n, 2)
	gen byte b = mod(_n, 3)
	gen byte c = mod(_n, 4)
	quietly save "`tmp_dir'/_c21_f1.dta", replace
	drop c
	quietly save "`tmp_dir'/_c21_f2.dta", replace
	capture erase "`tmp_dir'/_c21.txt"
	capture noisily datamap, filelist(`tmp_dir'/_c21_f1 `tmp_dir'/_c21_f2) ///
		exclude(a-c) output("`tmp_dir'/_c21.txt")
	assert _rc == 111
	* nothing was written: the check runs before any output
	capture confirm file "`tmp_dir'/_c21.txt"
	assert _rc == 601
	* the same range where it resolves still excludes a, b, c
	datamap, single("`tmp_dir'/_c21_f1") exclude(a-c) output("`tmp_dir'/_c21b.txt")
	assert r(n_excluded) == 3
	* a plain name absent from one file stays ignored
	datamap, filelist(`tmp_dir'/_c21_f1 `tmp_dir'/_c21_f2) exclude(a c) ///
		output("`tmp_dir'/_c21c.txt")
	assert r(n_excluded) == 3
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - unresolvable exclude() range errors r(111), writes nothing"
}
else {
	di as error "  T`test_count': FAILED - exclude() range fails open in a multi-file run (rc=`=_rc')"
}

* {{{ T22: a quoted spaced name ending in .dta or holding a path never splits
local ++test_count
capture noisily {
	local here "`c(pwd)'"
	quietly cd "`tmp_dir'"
	clear
	set obs 5
	gen x = _n
	quietly save "_c22my.dta", replace
	quietly save "file.dta", replace
	capture erase "_c22my file.dta"
	capture datamap, filelist("_c22my file.dta") output("_c22.txt")
	local rc1 = _rc
	capture datamap, filelist("./_c22my file") output("_c22b.txt")
	local rc2 = _rc
	* the bare whole-list form still reads as a list
	capture datamap, filelist("_c22my file") output("_c22c.txt")
	local rc3 = _rc
	local n3 = r(nfiles)
	capture erase "file.dta"
	quietly cd "`here'"
	assert `rc1' == 601
	assert `rc2' == 601
	assert `rc3' == 0 & `n3' == 2
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - filelist() does not split a spaced .dta name or path"
}
else {
	local rc22 = _rc
	capture quietly cd "`here'"
	di as error "  T`test_count': FAILED - filelist() split one spaced name into two files (rc=`rc22')"
}

* {{{ T23: an exclude() token matching no variable in any file gets a note
local ++test_count
capture noisily {
	clear
	set obs 20
	gen long ssn = _n
	gen long ss_hash = _n + 7
	gen byte k = mod(_n, 2)
	tempfile c23log
	capture log close _c23
	quietly log using "`c23log'", text replace name(_c23)
	datamap, output("`tmp_dir'/_c23.txt") exclude(ss k)
	local n23 = r(n_excluded)
	quietly log close _c23
	assert `n23' == 1
	_bf_has using "`c23log'", needle("note: exclude() matches no variable in any dataset: ss")
	assert r(found) == 1
	* computed across all files: a name present in one file is not reported
	quietly save "`tmp_dir'/_c23_f1.dta", replace
	drop ssn
	quietly save "`tmp_dir'/_c23_f2.dta", replace
	quietly log using "`c23log'", text replace name(_c23)
	datamap, filelist(`tmp_dir'/_c23_f1 `tmp_dir'/_c23_f2) exclude(ssn) ///
		output("`tmp_dir'/_c23b.txt")
	quietly log close _c23
	_bf_has using "`c23log'", needle("matches no variable")
	assert r(found) == 0
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - unmatched exclude() token noted across files"
}
else {
	local rc23 = _rc
	capture log close _c23
	di as error "  T`test_count': FAILED - unmatched exclude() token not noted (rc=`rc23')"
}

* {{{ T24: string unique counts non-empty values; datamap and datadict agree
local ++test_count
capture noisily {
	clear
	set obs 40
	gen str3 s = cond(mod(_n, 4) == 0, "a", cond(mod(_n, 4) == 1, "b", ///
		cond(mod(_n, 4) == 2, "c", "")))
	gen byte k = mod(_n, 2)
	* hand count: three non-empty values a, b, c; "" is string missing
	datamap, output("`tmp_dir'/_c24.txt") saving("`tmp_dir'/_c24_map.dta", replace)
	datadict, output("`tmp_dir'/_c24.md") saving("`tmp_dir'/_c24_dict.dta", replace)
	_bf_has using "`tmp_dir'/_c24.txt", needle("Unique Values: 3")
	assert r(found) == 1
	_bf_has using "`tmp_dir'/_c24.txt", needle("Unique Values: 4")
	assert r(found) == 0
	datamap, output("`tmp_dir'/_c24.json") format(json)
	_bf_has using "`tmp_dir'/_c24.json", needle(`""unique_values": 3,"')
	assert r(found) == 1
	foreach f in _c24_map _c24_dict {
		preserve
		use "`tmp_dir'/`f'.dta", clear
		quietly count if variable == "s" & unique == 3
		assert r(N) == 1
		restore
	}
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - string unique count excludes empty; datamap = datadict"
}
else {
	di as error "  T`test_count': FAILED - string unique count differs between datamap and datadict (rc=`=_rc')"
}

* {{{ T25: an exclude() range in reverse order in one file fails before output
local ++test_count
capture noisily {
	clear
	set obs 20
	gen byte a = mod(_n, 2)
	gen byte b = mod(_n, 3)
	gen byte c = mod(_n, 4)
	gen byte y = mod(_n, 5)
	quietly save "`tmp_dir'/_c25_g1.dta", replace
	order c b a y
	quietly save "`tmp_dir'/_c25_g2.dta", replace
	capture erase "`tmp_dir'/_c25.txt"
	capture erase "`tmp_dir'/_c25.md"
	capture noisily datamap, filelist(`tmp_dir'/_c25_g1 `tmp_dir'/_c25_g2) ///
		exclude(a-c) output("`tmp_dir'/_c25.txt")
	assert _rc == 111
	capture confirm file "`tmp_dir'/_c25.txt"
	assert _rc == 601
	capture noisily datadict, filelist(`tmp_dir'/_c25_g1 `tmp_dir'/_c25_g2) ///
		exclude(a-c) output("`tmp_dir'/_c25.md")
	assert _rc == 111
	capture confirm file "`tmp_dir'/_c25.md"
	assert _rc == 601
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - reversed exclude() range errors before any output"
}
else {
	di as error "  T`test_count': FAILED - reversed exclude() range left a partial output (rc=`=_rc')"
}

* {{{ T26: filelist("sub/a.dta b.dta") with both files present reads two files
local ++test_count
capture noisily {
	local here "`c(pwd)'"
	quietly cd "`tmp_dir'"
	capture mkdir "_c26sub"
	clear
	set obs 5
	gen x = _n
	quietly save "_c26sub/_c26a.dta", replace
	quietly save "_c26b.dta", replace
	capture datamap, filelist("_c26sub/_c26a.dta _c26b.dta") output("_c26.txt")
	local rc26 = _rc
	local n26 = r(nfiles)
	quietly cd "`here'"
	assert `rc26' == 0 & `n26' == 2
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - quoted list of existing .dta paths still splits (1.8.0 form)"
}
else {
	local rc26f = _rc
	capture quietly cd "`here'"
	di as error "  T`test_count': FAILED - quoted list of existing .dta paths refused (rc=`rc26f')"
}

* ============================================================
* Summary
* ============================================================

di _newline
di as text "Results: `pass_count'/`test_count' passed"
local fail_count = `test_count' - `pass_count'
if `fail_count' == 0 {
	di as result "ALL TESTS PASSED"
}
else {
	di as error "`fail_count' TESTS FAILED"
}
display "RESULT: test_datamap_bugfixes tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 9
