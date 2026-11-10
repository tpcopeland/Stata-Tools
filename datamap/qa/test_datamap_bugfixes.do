clear all
set more off
version 16.0

* test_datamap_bugfixes.do - Regression tests for B1/B2/P2/C3/D2/D3 fixes
* Tests: 26
*
* 2026-11-10 (datamap 2.0.0): datadict, the text layout and format(json) are
* removed.  All 26 tests stay.  The documents are Markdown, read through
* _qa_md.do's Mata reader (a datamap line may end in a backtick, which stopped
* the macro line readers with r(132)).  Per test:
*   T1/T2  the "6.8%" artifact check reads the Missing cell ("5 (6.8%)"); the
*          QUICK REFERENCE-vs-detail comparison is one cell now (the block that
*          repeated it is gone, plan O2) and is compared with saving()
*   T3/T4  "74 unique values" -> "74 distinct"
*   T5/T6  "spans from"/"suppressed for privacy" -> "(exact dates withheld)" / "range"
*   T7-T10 datadict -> datamap with document options; T7's "---" rule is the
*          Markdown table separator "|---|" only, never a line "---"
*   T11/T12/T13/T14/T19  text lines -> the Markdown cells and Structure lines;
*          the JSON halves of T13/T15/T24 are REMOVED FEATURE (no JSON writer)
*   T18    REMOVED FEATURE: the VALUE LABEL DEFINITIONS section ("ab (used by: a b)")
*          is gone; the levels of every user of the label are the inline cells
*          of both variables (columns(vallabel) names the label)
*   T24    the datadict half is a second datamap call (document option)

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
do "`qa_dir'/_qa_md.do"

* ============================================================
* B1: Floating-point display formatting
* ============================================================

* {{{ T1: Missing percentage has no floating-point artifacts
local ++test_count
capture noisily {
	sysuse auto, clear
	datamap, output("`tmp_dir'/_b1.md")
	confirm file "`tmp_dir'/_b1.md"
	qa_md_contains using "`tmp_dir'/_b1.md", needle("6.800000")
	assert r(n) == 0
	* rep78 has 5 missing of 74: the clean cell is "5 (6.8%)"
	qa_md_contains using "`tmp_dir'/_b1.md", needle(" | 5 (6.8%) | ")
	assert r(n) == 1
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
capture noisily {
	sysuse auto, clear
	datamap, output("`tmp_dir'/_b1b.md") saving("`tmp_dir'/_b1b_meta.dta", replace)
	* one cell per variable now (the QUICK REFERENCE block that repeated it is gone):
	* the document's percent equals the saving() table's, formatted at one decimal
	qa_md_rows using "`tmp_dir'/_b1b.md", var(rep78) miss("5 (6.8%)")
	assert r(n) == 1
	preserve
	quietly use "`tmp_dir'/_b1b_meta.dta", clear
	quietly summarize missing_pct if variable == "rep78"
	assert abs(r(mean) - 6.8) < 0.05
	assert missing == 5 if variable == "rep78"
	restore
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
capture noisily {
	sysuse auto, clear
	save "`tmp_dir'/_b2_auto.dta", replace
	datamap, single("`tmp_dir'/_b2_auto.dta") output("`tmp_dir'/_b2.md")
	confirm file "`tmp_dir'/_b2.md"
	* make should show "N=74; 74 distinct; max length 17"
	qa_md_rows using "`tmp_dir'/_b2.md", var(make) cell("N=74; 74 distinct; max length 17")
	assert r(n) == 1
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
capture noisily {
	qa_md_contains using "`tmp_dir'/_b2.md", needle("N=.;")
	assert r(n) == 0
	qa_md_contains using "`tmp_dir'/_b2.md", needle(". distinct")
	assert r(n) == 0
	qa_md_contains using "`tmp_dir'/_b2.md", needle("N=. ")
	assert r(n) == 0
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - No N=. or '. unique' in datamap output"
}
else {
	di as error "  T`test_count': FAILED - Found N=. or '. unique' in datamap output"
}

* ============================================================
* P2: datesafe suppresses date range in summary
* ============================================================

* {{{ T5: datesafe hides exact date range
local ++test_count
capture noisily {
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
	datamap, single("`tmp_dir'/_p2_dates") output("`tmp_dir'/_p2.md") datesafe
	confirm file "`tmp_dir'/_p2.md"
	* no range of dates, a span instead for each of the two date variables
	qa_md_contains using "`tmp_dir'/_p2.md", needle("range 20")
	assert r(n) == 0
	qa_md_contains using "`tmp_dir'/_p2.md", needle("(exact dates withheld)")
	assert r(n) == 2
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
capture noisily {
	datamap, single("`tmp_dir'/_p2_dates") output("`tmp_dir'/_p2_nodatesafe.md")
	qa_md_contains using "`tmp_dir'/_p2_nodatesafe.md", needle("range 20")
	assert r(n) == 2
	qa_md_contains using "`tmp_dir'/_p2_nodatesafe.md", needle("withheld")
	assert r(n) == 0
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
capture noisily {
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
	datamap, filelist("`tmp_dir'/_c3_data1 `tmp_dir'/_c3_data2") ///
		output("`tmp_dir'/_c3.md") notes("Test notes") changelog("v1.0: initial")
	confirm file "`tmp_dir'/_c3.md"
	* no line is a horizontal rule; the only "---" are the table separators "|---|"
	qa_md_contains using "`tmp_dir'/_c3.md", needle("---") exact
	assert r(n) == 0
	qa_md_contains using "`tmp_dir'/_c3.md", needle("|---|---|---|---|---|") exact
	assert r(n) == 2
	* the document parts are all there (a rule would only have separated them)
	qa_md_contains using "`tmp_dir'/_c3.md", needle("## Notes") exact
	assert r(n) == 1
}
if _rc == 0 {
	local ++pass_count
	di as result "  T`test_count': PASSED - No --- horizontal rules in datamap output"
}
else {
	di as error "  T`test_count': FAILED - Found --- in datamap output"
}

* ============================================================
* D2/D3: notes() and changelog() accept inline strings
* ============================================================

* {{{ T8: notes() with inline string writes the text
local ++test_count
* Use filelist mode which writes notes section
capture noisily {
	sysuse auto, clear
	save "`tmp_dir'/_d2_auto.dta", replace
	datamap, filelist("`tmp_dir'/_d2_auto") ///
		output("`tmp_dir'/_d2_multi.md") ///
		notes("These are inline test notes for the data dictionary.")
	confirm file "`tmp_dir'/_d2_multi.md"
	qa_md_contains using "`tmp_dir'/_d2_multi.md", needle("These are inline test notes for the data dictionary.") exact
	assert r(n) == 1
	qa_md_contains using "`tmp_dir'/_d2_multi.md", needle("not found")
	assert r(n) == 0
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
capture noisily {
	datamap, filelist("`tmp_dir'/_d2_auto") ///
		output("`tmp_dir'/_d3.md") ///
		changelog("v1.0.0: Initial release of the data dictionary.")
	confirm file "`tmp_dir'/_d3.md"
	qa_md_contains using "`tmp_dir'/_d3.md", needle("v1.0.0: Initial release of the data dictionary.") exact
	assert r(n) == 1
	qa_md_contains using "`tmp_dir'/_d3.md", needle("not found")
	assert r(n) == 0
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
capture noisily {
	tempname fh_n
	file open `fh_n' using "`tmp_dir'/_notes_file.txt", write text replace
	file write `fh_n' "These notes came from a file." _n
	file write `fh_n' "Second line of file notes." _n
	file close `fh_n'
	datamap, filelist("`tmp_dir'/_d2_auto") ///
		output("`tmp_dir'/_d2_file.md") ///
		notes("`tmp_dir'/_notes_file.txt")
	confirm file "`tmp_dir'/_d2_file.md"
	qa_md_contains using "`tmp_dir'/_d2_file.md", needle("These notes came from a file.") exact
	assert r(n) == 1
	qa_md_contains using "`tmp_dir'/_d2_file.md", needle("Second line of file notes.") exact
	assert r(n) == 1
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
	qa_md_contains using `"`using'"', needle(`"`needle'"') `exact'
	return scalar found = r(found)
end

* {{{ T11: survival event rate honours mincell() (2 events in 1000 rows)
local ++test_count
capture noisily {
	clear
	set obs 1000
	gen byte died = _n <= 2
	gen double survtime = _n
	datamap, output("`tmp_dir'/_c11.md") detect(survival)
	* 0.2% of the printed 1000 observations is the 2-event count
	_bf_has using "`tmp_dir'/_c11.md", needle("rate: 0.2%")
	assert r(found) == 0
	_bf_has using "`tmp_dir'/_c11.md", needle("rate: .2%")
	assert r(found) == 0
	_bf_has using "`tmp_dir'/_c11.md", needle("rate: suppressed")
	assert r(found) == 1
	* above the threshold in both cells the rate still prints
	replace died = _n <= 100
	datamap, output("`tmp_dir'/_c11b.md") detect(survival)
	qa_md_contains using "`tmp_dir'/_c11b.md", needle("`=char(96)'died`=char(96)' rate: 10.0%")
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
	datamap, output("`tmp_dir'/_c12.md") detect(survival) datesafe
	* 21916 = 01jan2020 + 1: the raw day number is an exact date
	_bf_has using "`tmp_dir'/_c12.md", needle("21916")
	assert r(found) == 0
	qa_md_contains using "`tmp_dir'/_c12.md", needle("followup_time`=char(96)' range")
	assert r(found) == 0
	_bf_has using "`tmp_dir'/_c12.md", needle("2020/")
	assert r(found) == 0
	* without datesafe the range prints as dates, not day counts
	datamap, output("`tmp_dir'/_c12b.md") detect(survival)
	qa_md_contains using "`tmp_dir'/_c12b.md", needle("followup_time`=char(96)' range: 2020/01/02 to 2020/01/31")
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
	datamap, output("`tmp_dir'/_c13.md") detect(binary) categorical(s)
	* 998 = 1000 - 0 missing - 2: printing it discloses the suppressed cell
	_bf_has using "`tmp_dir'/_c13.md", needle("998")
	assert r(found) == 0
	_bf_has using "`tmp_dir'/_c13.md", needle("997")
	assert r(found) == 0
	qa_md_rows using "`tmp_dir'/_c13.md", var(flag) cell("0: suppressed (complementary)<br>1: suppressed (<5)")
	assert r(n) == 1
	* (a string level reads quoted, as the text form did)
	qa_md_rows using "`tmp_dir'/_c13.md", var(s) cell(`""a": suppressed (complementary)<br>"b": suppressed (<5)"')
	assert r(n) == 1
	* two small cells that pool to >= mincell need no complement
	qa_md_rows using "`tmp_dir'/_c13.md", var(three) cell("1: suppressed (<5)<br>2: suppressed (<5)<br>3: 994 (99.4%)")
	assert r(n) == 1
	* (the JSON half, "count": 998 absent, is removed with format(json); the
	* document is the disclosure surface that remains)
	* mincell(0) still shows every cell
	datamap, output("`tmp_dir'/_c13z.md") mincell(0)
	qa_md_rows using "`tmp_dir'/_c13z.md", var(flag) cell("0: 998 (99.8%)<br>1: 2 (0.2%)")
	assert r(n) == 1
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
	datamap, output("`tmp_dir'/_c14.md") missing(pattern)
	* patterns: ++ 90, +. 6, .+ 4; 100 - 90 - 6 recovers the 4
	qa_md_contains using "`tmp_dir'/_c14.md", needle("  - `=char(96)'.+`=char(96)': suppressed (<5)") exact
	assert r(found) == 1
	qa_md_contains using "`tmp_dir'/_c14.md", needle("  - `=char(96)'+.`=char(96)': suppressed (complementary)") exact
	assert r(found) == 1
	qa_md_contains using "`tmp_dir'/_c14.md", needle("  - `=char(96)'++`=char(96)': 90 (90.0%)") exact
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
	datamap, single("`tmp_dir'/_c15_zero") output("`tmp_dir'/_c15.md") ///
		autodetect missing(pattern) quality
	assert r(nobs) == 0
	assert r(nvars) == 3
	_bf_has using "`tmp_dir'/_c15.md", needle("- Observations: 0") exact
	assert r(found) == 1
	_bf_has using "`tmp_dir'/_c15.md", needle(" | No observations |")
	assert r(found) == 1
	_bf_has using "`tmp_dir'/_c15.md", needle("- Complete rows: 0 (no observations)") exact
	assert r(found) == 1
	* (the JSON "observations": 0 half is removed with format(json))
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
	datamap, filelist("`sdir'/one" "`sdir'/two") output("`tmp_dir'/_c16.md")
	assert r(nfiles) == 2
	assert "`r(input_source)'" == "filelist"
	_bf_has using "`tmp_dir'/_c16.md", needle("## 2. two") exact
	assert r(found) == 1
	* an unquoted list still splits on spaces
	quietly save "`tmp_dir'/_c16a.dta", replace
	quietly save "`tmp_dir'/_c16b.dta", replace
	datamap, filelist(`tmp_dir'/_c16a `tmp_dir'/_c16b) output("`tmp_dir'/_c16u.md")
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
	datamap, output("`tmp_dir'/_c17.md") exclude(patient_*) samples(3)
	assert r(n_excluded) == 2
	assert "`r(excluded_vars)'" == "patient_id patient_no"
	_bf_has using "`tmp_dir'/_c17.md", needle("1001")
	assert r(found) == 0
	_bf_has using "`tmp_dir'/_c17.md", needle("5001")
	assert r(found) == 0
	_bf_has using "`tmp_dir'/_c17.md", needle("| [MASKED] | [MASKED] |")
	assert r(found) == 1
	* a range
	datamap, output("`tmp_dir'/_c17b.md") exclude(patient_id-patient_no)
	assert r(n_excluded) == 2
	* names absent from the dataset are still ignored
	datamap, output("`tmp_dir'/_c17c.md") exclude(patient_id nosuchvar ssn*)
	assert r(n_excluded) == 1
	* abbreviations are not expanded
	datamap, output("`tmp_dir'/_c17d.md") exclude(patient)
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
	datamap, output("`tmp_dir'/_c18.md") mincell(0) columns(variable vallabel values)
	* 2026-11-10: the section "ab (used by: a b)" is gone.  The levels of every user
	* of the label are the inline cells of both variables, and the label name is
	* shown once per user with columns(vallabel)
	qa_md_rows using "`tmp_dir'/_c18.md", var(a) cell("0 zero: 6 (30.0%)<br>1 one: 7 (35.0%)<br>2 two: 7 (35.0%)")
	assert r(n) == 1
	qa_md_rows using "`tmp_dir'/_c18.md", var(b) cell("3 three: 10 (50.0%)<br>4 four: 10 (50.0%)")
	assert r(n) == 1
	_bf_has using "`tmp_dir'/_c18.md", needle(" | ab | ")
	assert r(found) == 1
	_bf_has using "`tmp_dir'/_c18.md", needle("used by")
	assert r(found) == 0
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
	datamap, output("`tmp_dir'/_c19.md") missing(pattern)
	* 3 complete rows: the +. pattern count, printed raw beside its suppression
	_bf_has using "`tmp_dir'/_c19.md", needle("Complete rows: 3")
	assert r(found) == 0
	_bf_has using "`tmp_dir'/_c19.md", needle("- Complete rows: suppressed (<5 in a cell)") exact
	assert r(found) == 1
	datamap, output("`tmp_dir'/_c19b.md") missing(detail) mincell(0)
	_bf_has using "`tmp_dir'/_c19b.md", needle("- Complete rows: 3 (0.3%)") exact
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
	datamap, output("`tmp_dir'/_c20.md") exclude(ssn) ///
		saving("`tmp_dir'/_c20_meta.dta", replace)
	dataprobe, exclude(ssn) saving("`tmp_dir'/_c20_dc.dta", replace)
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
	capture erase "`tmp_dir'/_c21.md"
	capture noisily datamap, filelist(`tmp_dir'/_c21_f1 `tmp_dir'/_c21_f2) ///
		exclude(a-c) output("`tmp_dir'/_c21.md")
	assert _rc == 111
	* nothing was written: the check runs before any output
	capture confirm file "`tmp_dir'/_c21.md"
	assert _rc == 601
	* the same range where it resolves still excludes a, b, c
	datamap, single("`tmp_dir'/_c21_f1") exclude(a-c) output("`tmp_dir'/_c21b.md")
	assert r(n_excluded) == 3
	* a plain name absent from one file stays ignored
	datamap, filelist(`tmp_dir'/_c21_f1 `tmp_dir'/_c21_f2) exclude(a c) ///
		output("`tmp_dir'/_c21c.md")
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
	capture datamap, filelist("_c22my file.dta") output("_c22.md")
	local rc1 = _rc
	capture datamap, filelist("./_c22my file") output("_c22b.md")
	local rc2 = _rc
	* the bare whole-list form still reads as a list
	capture datamap, filelist("_c22my file") output("_c22c.md")
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
	datamap, output("`tmp_dir'/_c23.md") exclude(ss k)
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
		output("`tmp_dir'/_c23b.md")
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

* {{{ T24: string unique counts non-empty values; plain and document mode agree
local ++test_count
capture noisily {
	clear
	set obs 40
	gen str3 s = cond(mod(_n, 4) == 0, "a", cond(mod(_n, 4) == 1, "b", ///
		cond(mod(_n, 4) == 2, "c", "")))
	gen byte k = mod(_n, 2)
	* hand count: three non-empty values a, b, c; "" is string missing
	datamap, output("`tmp_dir'/_c24.md") saving("`tmp_dir'/_c24_map.dta", replace) ///
		columns(variable type unique values)
	datamap, output("`tmp_dir'/_c24d.md") saving("`tmp_dir'/_c24_dict.dta", replace) title("T")
	* 2026-11-10 (2.0.0 Phase 3, F4): a text variable with few distinct values
	* lists its values (each held by 10 rows); the distinct count stays 3
	qa_md_rows using "`tmp_dir'/_c24.md", var(s) cell(`"N=30; 3 distinct; max length 1; values "a" 10, "b" 10, "c" 10"')
	assert r(n) == 1
	_bf_has using "`tmp_dir'/_c24.md", needle("| str3 | 3 | ")
	assert r(found) == 1
	_bf_has using "`tmp_dir'/_c24.md", needle("| str3 | 4 | ")
	assert r(found) == 0
	* (the JSON "unique_values": 3 half is removed with format(json); the document
	* in document mode is the second writer path that datadict used to be)
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
	di as result "  T`test_count': PASSED - string unique count excludes empty; plain and document mode agree"
}
else {
	di as error "  T`test_count': FAILED - string unique count differs between plain and document mode (rc=`=_rc')"
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
	capture erase "`tmp_dir'/_c25.md"
	capture erase "`tmp_dir'/_c25.md"
	capture noisily datamap, filelist(`tmp_dir'/_c25_g1 `tmp_dir'/_c25_g2) ///
		exclude(a-c) output("`tmp_dir'/_c25.md")
	assert _rc == 111
	capture confirm file "`tmp_dir'/_c25.md"
	assert _rc == 601
	capture noisily datamap, filelist(`tmp_dir'/_c25_g1 `tmp_dir'/_c25_g2) ///
		exclude(a-c) output("`tmp_dir'/_c25b.md") title("T")
	assert _rc == 111
	capture confirm file "`tmp_dir'/_c25b.md"
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
	capture datamap, filelist("_c26sub/_c26a.dta _c26b.dta") output("_c26.md")
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
