clear all
set more off
version 16.0
set linesize 255

* test_datamap_v1103.do - regressions for the 1.10.3 review fixes (three
* independent reviews of 1.10.2).  Each test names its finding:
*   A* datamap/_datamap_* (Sonnet A), P* dataprobe (Opus), B* datadict/
*   datamvp/dataqa (Sonnet B), S*/SA* suspected items that reproduced.
* Every test was red on 1.10.2 except where a comment says otherwise.
*
* 2026-11-10 (datamap 2.0.0): datadict, the text layout and its prose are
* removed.  The datadict tests (B1-B5, B13-B16, A11, A14, SA3) run on datamap's
* Markdown writer; text-layout needles became Markdown cells (see each test):
*   A7  "Max Length: 29 characters" -> "max length 29"
*   A8  "Earliest: 2021-02-04" -> "range 2021-02-04 to 2021-02-13"
*   A9  "longitudinal data with 5 units" (DESCRIPTION) -> the Panel structure line
*   A15 the stratification guidance is gone; the "All missing" cell remains
*   B4  REMOVED FEATURE: datadict's generated descriptions ("Unique identifier",
*       "Year of observation").  The test now asserts they never appear
*   B5/B13 the "3=3" value-label list is the inline "<value> <label>" cells
*   B16 "IQR=-224 to -73.50" -> "IQR=-223.50 to -73.50" (2026-11-10: both ends of
*       a pair print with one number of decimals, so p25 = -223.5 is no longer
*       rounded to -224 by the integer class; the " to " separator is unchanged)
*       and "range=-297 to 0" -> "range=-297.00 to 0.00" (repair round 3: an
*       exact zero prints with its statistics cell's decimals)

local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
do "`qa_dir'/_qa_md.do"

local test_count = 0
local pass_count = 0
local fail_count = 0

local W "`c(tmpdir)'/v1103"
capture mkdir "`W'"

* The three line counters below read through Mata (_qa_md.do's reader style): a
* datamap 2.0.0 document has lines that end in a backtick, which a macro line
* reader stops on with r(132).
* number of lines of a text file that contain a string
capture program drop _v13_count
program define _v13_count, rclass
    args file needle
    qa_md_contains using `"`file'"', needle(`"`needle'"')
    return scalar n = r(n)
end

* number of lines of a text file equal to a string after trimming blanks
capture program drop _v13_eq
program define _v13_eq, rclass
    args file needle
    mata: st_numscalar("__v13_eq", sum(strtrim(cat(st_local("file"))) :== st_local("needle")))
    return scalar n = scalar(__v13_eq)
    scalar drop __v13_eq
end

* number of lines of a text file
capture program drop _v13_lines
program define _v13_lines, rclass
    args file
    qa_md_nlines using `"`file'"'
    return scalar n = r(n)
end

* number of lines of a text file that contain the text in global V13_ND,
* read in Mata so a needle or line holding `"' is never re-read as syntax
capture program drop _v13_countg
program define _v13_countg, rclass
    args file
    mata: _v13_countg_m(st_local("file"), st_global("V13_ND"))
    return scalar n = scalar(_v13_cnt)
    scalar drop _v13_cnt
end

* number of lines of a text file holding invalid UTF-8
capture program drop _v13_badutf
program define _v13_badutf, rclass
    args file
    mata: _v13_badutf_m(st_local("file"))
    return scalar n = scalar(_v13_bad)
    scalar drop _v13_bad
end
mata:
void _v13_countg_m(string scalar f, string scalar nd)
{
	real scalar fh, n
	string scalar line
	n = 0
	fh = fopen(f, "r")
	while ((line = fget(fh)) != J(0, 0, "")) {
		if (strpos(line, nd) > 0) n++
	}
	fclose(fh)
	st_numscalar("_v13_cnt", n)
}

void _v13_badutf_m(string scalar f)
{
	real scalar fh, n
	string scalar line
	n = 0
	fh = fopen(f, "r")
	while ((line = fget(fh)) != J(0, 0, "")) {
		if (ustrinvalidcnt(line) > 0) n++
	}
	fclose(fh)
	st_numscalar("_v13_bad", n)
}
end

local ++test_count
capture noisily {
    clear
    quietly set obs 210000
    quietly gen double x = 1
    quietly replace x = 2 in 50001/200000
    quietly gen str3 s = "A"
    quietly replace s = "B" in 120000/130000
    quietly gen byte arm = 0
    quietly replace arm = 1 in 150000
    _datamap_nuniq x
    assert r(n) == 2 & r(capped) == 0
    _datamap_nuniq s
    assert r(n) == 2 & r(capped) == 0
    _datamap_nuniq arm
    assert r(n) == 2
    capture erase "`W'/a1.dta"
    quietly datamap, output("`W'/a1.md") saving("`W'/a1.dta", replace)
    use "`W'/a1.dta", clear
    quietly count if inlist(variable, "x", "s", "arm") & unique == 2
    assert r(N) == 3
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: A1 nuniq reads rows 50,001-200,000 (N = 210,000)"
}
else {
    local ++fail_count
    display as error "  FAIL: A1 nuniq reads rows 50,001-200,000 (N = 210,000)"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 40
    gen dob = mdy(3, 4, 1980) + 8 * (_n > 20)
    format dob %td
    gen x = _n
    quietly datamap, output("`W'/a2.md") detect(binary) datesafe
    _v13_count "`W'/a2.md" "7368"
    assert r(n) == 0
    _v13_count "`W'/a2.md" "7376"
    assert r(n) == 0
    quietly datamap, output("`W'/a2b.md") datesafe categorical(dob)
    _v13_count "`W'/a2b.md" "7368"
    assert r(n) == 0
    _v13_count "`W'/a2b.md" "withheld (datesafe"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: A2 detect(binary) never lists a date under datesafe"
}
else {
    local ++fail_count
    display as error "  FAIL: A2 detect(binary) never lists a date under datesafe"
}

local ++test_count
capture noisily {
    sysuse auto, clear
    local fn0 "`c(filename)'"
    quietly replace price = price + 1 in 1
    assert c(changed) == 1
    quietly datamap, output("`W'/a4.md")
    assert c(changed) == 1
    assert "`c(filename)'" == "`fn0'"
    assert price[1] == 4100
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: A4 datamap in memory keeps c(changed) and c(filename)"
}
else {
    local ++fail_count
    display as error "  FAIL: A4 datamap in memory keeps c(changed) and c(filename)"
}

local ++test_count
capture noisily {
    sysuse auto, clear
    local fn0 "`c(filename)'"
    quietly replace price = price + 1 in 1
    quietly datamap, output("`W'/b1.md") title("T")
    assert c(changed) == 1
    assert "`c(filename)'" == "`fn0'"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B1 datamap document mode in memory keeps c(changed) and c(filename)"
}
else {
    local ++fail_count
    display as error "  FAIL: B1 datamap document mode in memory keeps c(changed) and c(filename)"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 30
    gen g = cond(_n <= 14, 1, cond(_n <= 28, 2, .))
    gen x = cond(missing(g), 1000, 10)
    capture noisily dataprobe, gatesonly groupstat(mean x, by(g) band(0.5 2) relative)
    assert _rc == 0
    clear
    quietly set obs 22
    gen g = cond(_n <= 10, 1, cond(_n <= 20, 2, .))
    gen x = _n
    capture erase "`W'/p1.dta"
    quietly dataprobe, gatesonly groupstat(n x, by(g)) ledger("`W'/p1.dta")
    use "`W'/p1.dta", clear
    assert observed == "pooled 20" if family == "groupstat"
    quietly count if family == "groupstat"
    assert r(N) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: P1 groupstat pooled value leaves out rows with a missing group"
}
else {
    local ++fail_count
    display as error "  FAIL: P1 groupstat pooled value leaves out rows with a missing group"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 40
    gen g = cond(_n <= 20, 1, 2)
    gen x = _n
    quietly replace x = . if _n > 3 & _n <= 20
    capture erase "`W'/p2.dta"
    quietly dataprobe, gatesonly maskrare groupstat(n x, by(g)) ledger("`W'/p2.dta")
    assert r(masked) == 1
    use "`W'/p2.dta", clear
    assert obs_masked == 1 if family == "groupstat"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: P2 groupstat masked cells set r(masked) and the ledger obs_masked"
}
else {
    local ++fail_count
    display as error "  FAIL: P2 groupstat masked cells set r(masked) and the ledger obs_masked"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 100
    gen w = _n <= 3
    gen one = 1
    gen g = 1
    capture erase "`W'/p3.dta"
    capture dataprobe, gatesonly maskrare ledger("`W'/p3.dta") ///
        stat(ess w 0 1 \ sd w 0 0.01 \ ratio w one 0 0.001)
    assert _rc == 9
    capture dataprobe, gatesonly maskrare ledger("`W'/p3.dta") groupstat(ess w, by(g))
    capture dataprobe, gatesonly maskrare ledger("`W'/p3.dta") groupstat(sd w, by(g))
    use "`W'/p3.dta", clear
    quietly count if family == "stat" & strpos(observed, "[suppressed]") > 0
    assert r(N) == 3
    quietly count if family == "groupstat" & observed == "pooled [suppressed]"
    assert r(N) == 2
    * control: 50 ones and 50 zeros are shown
    clear
    quietly set obs 100
    gen w = _n <= 50
    gen one = 1
    capture erase "`W'/p3c.dta"
    capture dataprobe, gatesonly maskrare ledger("`W'/p3c.dta") ///
        stat(ess w 0 1 \ sd w 0 0.01 \ ratio w one 0 0.001)
    use "`W'/p3c.dta", clear
    quietly count if family == "stat" & strpos(observed, "[suppressed]") > 0
    assert r(N) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: P3 maskrare withholds ess, sd, and ratio of a rare 0/1 variable"
}
else {
    local ++fail_count
    display as error "  FAIL: P3 maskrare withholds ess, sd, and ratio of a rare 0/1 variable"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 12
    gen id = cond(_n == 1, 1, cond(_n <= 3, 2, 3))
    log using "`W'/p5.log", text replace name(v13log)
    dataprobe, id(id) maskrare nomissing
    local m = r(masked)
    log close v13log
    assert `m' == 1
    _v13_count "`W'/p5.log" "median/max = [suppressed]/"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: P5 KEY STRUCTURE median records per key masked under maskrare"
}
else {
    local ++fail_count
    display as error "  FAIL: P5 KEY STRUCTURE median records per key masked under maskrare"
}

local ++test_count
capture noisily {
    sysuse auto, clear
    capture dataprobe, gatesonly expectn(80 70)
    assert _rc == 198
    capture dataprobe, gatesonly expectn(70 80)
    assert _rc == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: P6 expectn() with reversed bounds is r(198)"
}
else {
    local ++fail_count
    display as error "  FAIL: P6 expectn() with reversed bounds is r(198)"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 10
    gen x = _n
    gen ub = cond(_n == 1, 3, 100)
    capture dataprobe, gatesonly inrange(x 0 ub*1)
    assert _rc == 198
    capture dataprobe, gatesonly stat(mean x 0 ub+0)
    assert _rc == 198
    capture dataprobe, gatesonly inrange(x 0 5*2)
    assert _rc == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: P7 a range bound naming a variable inside an expression is r(198)"
}
else {
    local ++fail_count
    display as error "  FAIL: P7 a range bound naming a variable inside an expression is r(198)"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 40
    gen rare = _n <= 2
    gen double y = _n
    quietly datamap, output("`W'/a3.md") saving("`W'/a3.dta", replace)
    use "`W'/a3.dta", clear
    assert missing(mean) & missing(min) & missing(max) if variable == "rare"
    assert !missing(mean) if variable == "y"
    clear
    quietly set obs 40
    gen double y = _n
    quietly datamap, nostats output("`W'/a3b.md") saving("`W'/a3b.dta", replace)
    use "`W'/a3b.dta", clear
    assert missing(mean) & missing(sd) & missing(max) if variable == "y"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: A3 saving() withholds categorical summaries under mincell and all under nostats"
}
else {
    local ++fail_count
    display as error "  FAIL: A3 saving() withholds categorical summaries under mincell and all under nostats"
}

local ++test_count
capture noisily {
    sysuse auto, clear
    capture datamap, output("`W'/a5.md") continuous(make)
    assert _rc == 109
    capture datamap, output("`W'/a5.md") date(make)
    assert _rc == 109
    capture datamap, output("`W'/a6.md") continuous(nosuchvar)
    assert _rc == 111
    capture datamap, output("`W'/a6.md") categorical(w* typo)
    assert _rc == 111
    * 2.0.0 (2026-11-10): datadict is removed and its datevars() is
    * datamap's date().  An unmatched date() token is an option error (198,
    * pointing to docdate(), the old datadict date(string)); continuous()
    * and categorical() typos above stay 111.
    capture datamap, output("`W'/a6.md") date(nosuch)
    assert _rc == 198
    capture datamap, output("`W'/a6.md") datevars(nosuch)
    assert _rc == 198
    quietly datamap, output("`W'/a6.md") categorical(w* tu*) saving("`W'/a6.dta", replace)
    use "`W'/a6.dta", clear
    assert class == "categorical" if inlist(variable, "weight", "turn")
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: A5 A6 override lists: strings and typos refused, wildcards per token"
}
else {
    local ++fail_count
    display as error "  FAIL: A5 A6 override lists: strings and typos refused, wildcards per token"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 6
    gen str40 t = "abcdefghijklmnop" + uchar(229) + uchar(228) + uchar(246) + "qrstuvwxyz"
    quietly datamap, output("`W'/a7.md") samples(3)
    _v13_badutf "`W'/a7.md"
    assert r(n) == 0
    _v13_count "`W'/a7.md" "N=6; 1 distinct; max length 29"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: A7 sample rows and Max Length count characters, never split UTF-8"
}
else {
    local ++fail_count
    display as error "  FAIL: A7 sample rows and Max Length count characters, never split UTF-8"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 10
    gen double t = clock("2021-02-03 04:05:06", "YMDhms") + _n * 86400000
    format t %tc
    gen double tC = Cofc(t)
    format tC %tC
    quietly datamap, output("`W'/a8.md") dateformat(%dCY-N-D)
    _v13_count "`W'/a8.md" "e+12"
    assert r(n) == 0
    _v13_count "`W'/a8.md" "range 2021-02-04 to 2021-02-13"
    assert r(n) == 2
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: A8 dateformat(%d...) on %tc and %tC variables prints dates"
}
else {
    local ++fail_count
    display as error "  FAIL: A8 dateformat(%d...) on %tc and %tC variables prints dates"
}

local ++test_count
capture noisily {
    sysuse auto, clear
    quietly datamap, output("`W'/a9.md") panelid(rep78)
    * (2026-11-10: the DESCRIPTION sentence is the Panel structure line)
    qa_md_contains using "`W'/a9.md", needle("- Panel: identifier `=char(96)'rep78`=char(96)'; 5 units; 74 rows")
    assert r(n) == 1
    gen patient_id = ceil(_n / 2)
    quietly datamap, output("`W'/a9b.md") detect(panel)
    qa_md_contains using "`W'/a9b.md", needle("- Panel: identifier `=char(96)'patient_id`=char(96)'; 37 units; 74 rows; 2.0 rows per unit") exact
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: A9 DESCRIPTION follows panelid() without detect(panel)"
}
else {
    local ++fail_count
    display as error "  FAIL: A9 DESCRIPTION follows panelid() without detect(panel)"
}

local ++test_count
capture noisily {
    sysuse auto, clear
    quietly save "`W'/sep_a.dta", replace
    capture datamap, filelist("`W'/sep_a") separate append
    assert _rc == 198
    quietly datamap, filelist("`W'/sep_a") separate
    assert `"`r(output)'"' == ""
    confirm file "`W'/sep_a_map.md"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: A10 separate: append refused, r(output) not set"
}
else {
    local ++fail_count
    display as error "  FAIL: A10 separate: append refused, r(output) not set"
}

local ++test_count
capture noisily {
    sysuse auto, clear
    quietly drop in 1/l
    quietly datamap, output("`W'/a11.md")
    assert r(nobs) == 0
    * (was a datadict twin) every variable row reads "No observations"
    qa_md_contains using "`W'/a11.md", needle("- Observations: 0") exact
    assert r(n) == 1
    qa_md_contains using "`W'/a11.md", needle(" | No observations |")
    assert r(n) == 12
    quietly datamap, output("`W'/a11b.md") title("T")
    qa_md_contains using "`W'/a11b.md", needle(" | No observations |")
    assert r(n) == 12
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: A11 zero-observation data in memory are documented"
}
else {
    local ++fail_count
    display as error "  FAIL: A11 zero-observation data in memory are documented"
}

local ++test_count
capture noisily {
    sysuse auto, clear
    capture datamap, single("a;b") output("`W'/a12.md")
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: A12 single() paths get the illegal-character guard"
}
else {
    local ++fail_count
    display as error "  FAIL: A12 single() paths get the illegal-character guard"
}

local ++test_count
capture noisily {
    capture mkdir "`W'/bad"
    sysuse auto, clear
    quietly save "`W'/bad/a.dta", replace
    quietly datamap, single("`W'/bad/a.dta") output("`W'/a13.md")
    _v13_lines "`W'/a13.md"
    local n0 = r(n)
    assert `n0' > 20
    tempname fh
    file open `fh' using "`W'/bad/b.dta", write text replace
    file write `fh' "not a dta file" _n
    file close `fh'
    capture datamap, directory("`W'/bad") output("`W'/a13.md")
    assert _rc != 0
    _v13_lines "`W'/a13.md"
    assert r(n) == `n0'
    erase "`W'/bad/b.dta"
    erase "`W'/bad/a.dta"
    rmdir "`W'/bad"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: A13 a failing dataset leaves the previous output intact"
}
else {
    local ++fail_count
    display as error "  FAIL: A13 a failing dataset leaves the previous output intact"
}

local ++test_count
capture noisily {
    local long = "d" * 100
    sysuse auto, clear
    quietly keep make price
    quietly save "`W'/`long'.dta", replace
    quietly datamap, single("`W'/`long'.dta") output("`W'/a14.md") saving("`W'/a14.dta", replace)
    use "`W'/a14.dta", clear
    assert dataset == "`long'"
    use "`W'/`long'.dta", clear
    quietly datamap, single("`W'/`long'.dta") output("`W'/b14.md") saving("`W'/b14.dta", replace) title("T")
    use "`W'/b14.dta", clear
    assert dataset == "`long'"
    erase "`W'/`long'.dta"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: A14 B14 saving() keeps a dataset name longer than 80 characters"
}
else {
    local ++fail_count
    display as error "  FAIL: A14 B14 saving() keeps a dataset name longer than 80 characters"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 10
    gen x = .
    gen y = _n
    quietly datamap, output("`W'/a15.md")
    _v13_count "`W'/a15.md" "stratification"
    assert r(n) == 0
    _v13_count "`W'/a15.md" " | All missing |"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: A15 an all-missing variable gets no stratification guidance"
}
else {
    local ++fail_count
    display as error "  FAIL: A15 an all-missing variable gets no stratification guidance"
}

local ++test_count
capture noisily {
    sysuse auto, clear
    quietly keep make price
    label data "Car file label B2"
    quietly save "`W'/b2.dta", replace
    quietly datamap, single("`W'/b2.dta") output("`W'/b2.md")
    _v13_count "`W'/b2.md" "- Label: Car file label B2"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B2 datamap file modes print the dataset label"
}
else {
    local ++fail_count
    display as error "  FAIL: B2 datamap file modes print the dataset label"
}

local ++test_count
capture noisily {
    sysuse auto, clear
    mata: st_global("price[note1]", "see code " + char(96) + "here")
    mata: st_global("price[note0]", "1")
    mata: st_global("mpg[note1]", "a " + char(34) + char(39) + " b")
    mata: st_global("mpg[note0]", "1")
    quietly datamap, output("`W'/b3.md") columns(variable notes)
    _v13_count "`W'/b3.md" "see code &#96;here"
    assert r(n) == 1
    * no row broke: all twelve variables are still one row each
    qa_md_rows using "`W'/b3.md"
    assert r(n) == 12
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B3 datamap prints a note holding a backtick and a closing compound quote"
}
else {
    local ++fail_count
    display as error "  FAIL: B3 datamap prints a note holding a backtick and a closing compound quote"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 40
    gen region_id = mod(_n, 4)
    gen person_id = _n
    gen yr = 5
    gen year = 2000 + mod(_n, 3)
    * 2026-11-10 (datamap 2.0.0): REMOVED FEATURE.  datadict guessed descriptions
    * from variable names ("Unique identifier" for a unique *_id, "Year of
    * observation" for year) and 1.10.3 made that guess need confirming values.
    * The generated descriptions are gone (plan O2): no guessed text appears,
    * whatever the names, and the Label column holds only the user's labels.
    quietly datamap, output("`W'/b4.md")
    _v13_count "`W'/b4.md" "Unique identifier"
    assert r(n) == 0
    _v13_count "`W'/b4.md" "Year of observation"
    assert r(n) == 0
    qa_md_rows using "`W'/b4.md"
    assert r(n) == 4
    * the identifier hint is the one disclosure line (person_id is 40 distinct values)
    qa_md_contains using "`W'/b4.md", needle("likely identifiers not excluded: ")
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B4 identifier and year descriptions need confirming values"
}
else {
    local ++fail_count
    display as error "  FAIL: B4 identifier and year descriptions need confirming values"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 40
    gen k = mod(_n, 10)
    local lab = uchar(229) * 30
    forvalues i = 0/9 {
        if `i' != 3 label define kl `i' "`lab'", add
    }
    label values k kl
    quietly datamap, output("`W'/b5.md")
    _v13_badutf "`W'/b5.md"
    assert r(n) == 0
    clear
    quietly set obs 10
    gen k = mod(_n, 4)
    label define kl2 0 "zero" 1 "one" 2 "two"
    label values k kl2
    quietly datamap, output("`W'/b13.md") mincell(0)
    _v13_count "`W'/b13.md" "3=3"
    assert r(n) == 0
    * an unlabelled value prints as its bare value, labelled ones with their label
    qa_md_rows using "`W'/b13.md", var(k) cell("0 zero: 2 (20.0%)<br>1 one: 3 (30.0%)<br>2 two: 3 (30.0%)<br>3: 2 (20.0%)")
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B5 B13 value-label cells: valid UTF-8, no 3=3 for an unlabelled value"
}
else {
    local ++fail_count
    display as error "  FAIL: B5 B13 value-label cells: valid UTF-8, no 3=3 for an unlabelled value"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 20
    local vn = "a" * 25 + uchar(229) + "xyz"
    gen `vn' = cond(_n < 3, ., 1)
    gen y = cond(_n > 18, ., 1)
    quietly datamvp, generate(mmmmm)
    local bad 0
    foreach v of varlist mmmmm_* {
        if ustrinvalidcnt("`v'") local ++bad
    }
    assert `bad' == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B6 datamvp generate() names are valid UTF-8"
}
else {
    local ++fail_count
    display as error "  FAIL: B6 datamvp generate() names are valid UTF-8"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 200
    gen a = cond(mod(_n, 3) == 0, ., 1)
    gen g = mod(_n, 2)
    quietly replace g = . in 1/40
    log using "`W'/b7.log", text replace name(v13log)
    datamvp a, notable graph(bar) gby(g) nodraw
    local n = r(N)
    log close v13log
    assert `n' == 160
    _v13_count "`W'/b7.log" "note: 40 observation(s) with missing g excluded"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B7 datamvp notes rows dropped for a missing gby() value"
}
else {
    local ++fail_count
    display as error "  FAIL: B7 datamvp notes rows dropped for a missing gby() value"
}

local ++test_count
capture noisily {
    capture graph drop v13g1 v13g2
    clear
    quietly set obs 300
    gen a = cond(mod(_n, 4) == 0, ., 1)
    gen b = cond(mod(_n, 5) == 0, ., 1)
    gen str12 g = cond(mod(_n, 3) == 0, "A" + char(34) + "B", ///
        cond(mod(_n, 3) == 1, "C" + char(96) + "D", "E" + char(36) + "F"))
    quietly datamvp a b, graph(bar) gby(g) notable nosummary nodraw gname(v13g1)
    mata: st_numscalar("_v13n", cols(tokens(st_global("r(gby_levels)"))))
    assert scalar(_v13n) == 3
    quietly datamvp a b, graph(bar) over(g) notable nosummary nodraw gname(v13g2)
    mata: st_numscalar("_v13n", cols(tokens(st_global("r(over_levels)"))))
    assert scalar(_v13n) == 3
    scalar drop _v13n
    capture graph drop v13g1 v13g2
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B8 datamvp gby()/over() string levels with a quote or backtick"
}
else {
    local ++fail_count
    display as error "  FAIL: B8 datamvp gby()/over() string levels with a quote or backtick"
}

local ++test_count
capture noisily {
    sysuse auto, clear
    log using "`W'/b9.log", text replace name(v13log)
    datamvp price mpg, generate(mm) monotone
    log close v13log
    _v13_count "`W'/b9.log" "note: nothing produced for generate() monotone"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B9 datamvp names the outputs it cannot produce without missing values"
}
else {
    local ++fail_count
    display as error "  FAIL: B9 datamvp names the outputs it cannot produce without missing values"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 30
    forvalues i = 1/100 {
        quietly gen v`i' = 1
    }
    quietly replace v1 = . in 1/10
    quietly replace v100 = . in 11/20
    quietly replace v99 = . in 21/30
    local ls = c(linesize)
    set linesize 80
    log using "`W'/b10.log", text replace name(v13log)
    datamvp, notable nosummary nodrop wide
    log close v13log
    set linesize `ls'
    * the last 26 characters of each pattern: they differ only there
    _v13_eq "`W'/b10.log" "+++++++++++++++++++++++++."
    assert r(n) == 1
    _v13_eq "`W'/b10.log" "++++++++++++++++++++++++.+"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B10 datamvp wide prints patterns wider than the line in full"
}
else {
    local ++fail_count
    display as error "  FAIL: B10 datamvp wide prints patterns wider than the line in full"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 40
    gen nomask = cond(_n <= 3, ., 1)
    gen x = cond(_n <= 10, ., 1)
    quietly dataqa set maskrare
    quietly datamvp nomask, nosummary notable
    local m1 = r(masked)
    capture quietly dataprobe nomask, nomissing
    local m2 = r(masked)
    quietly datamvp nomask x, nomaskrare
    local m3 = r(masked)
    quietly dataqa set clear
    assert `m1' == 1
    assert `m2' == 1
    assert `m3' == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B11 a variable named nomask does not switch session masking off"
}
else {
    local ++fail_count
    display as error "  FAIL: B11 a variable named nomask does not switch session masking off"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 20
    gen a = cond(_n < 3, ., 1)
    mata: st_varlabel("a", "x" + char(34) + char(39) + " y")
    log using "`W'/b12.log", text replace name(v13log)
    capture noisily datamvp a
    local rc = _rc
    log close v13log
    assert `rc' == 0
    mata: st_global("V13_ND", "x" + char(34) + char(39) + " y")
    _v13_countg "`W'/b12.log"
    macro drop V13_ND
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B12 datamvp prints a variable label holding a closing compound quote"
}
else {
    local ++fail_count
    display as error "  FAIL: B12 datamvp prints a variable label holding a closing compound quote"
}

local ++test_count
capture noisily {
    sysuse auto, clear
    quietly keep make price
    quietly drop in 1/l
    quietly save "`W'/b15.dta", replace
    quietly datamap, single("`W'/b15.dta") output("`W'/b15.md")
    _v13_count "`W'/b15.md" "All missing"
    assert r(n) == 0
    * one "No observations" cell per variable (make and price)
    _v13_count "`W'/b15.md" "No observations"
    assert r(n) == 2
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B15 a zero-observation file reads No observations"
}
else {
    local ++fail_count
    display as error "  FAIL: B15 a zero-observation file reads No observations"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 100
    gen double neg = -300 + 3 * _n
    gen double near = 100 + _n / 250
    quietly datamap, output("`W'/b16.md")
    * 2026-11-10: one decimal count per pair (was "IQR=-224 to -73.50"); the
    * negative-end " to " separator is what B16 pins
    _v13_count "`W'/b16.md" "IQR=-223.50 to -73.50"
    assert r(n) == 1
    * 2026-11-10 (repair round 3): an exact zero takes the cell's decimals
    * (two here, SD=87.03), and both ends of a pair print alike, so
    * "range=-297 to 0" is now "range=-297.00 to 0.00"; " to " still pinned
    _v13_count "`W'/b16.md" "range=-297.00 to 0.00"
    assert r(n) == 1
    * near-equal ends keep their digits, never "100-100"
    _v13_count "`W'/b16.md" "IQR=100-100"
    assert r(n) == 0
    _v13_count "`W'/b16.md" "IQR=100.102-100.302"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B16 negative and near-equal IQR and range ends read unambiguously"
}
else {
    local ++fail_count
    display as error "  FAIL: B16 negative and near-equal IQR and range ends read unambiguously"
}

local ++test_count
capture noisily {
    clear
    quietly set obs 2
    gen str10 s = "a"
    quietly replace s = `"x"y"' in 2
    capture dataprobe, gatesonly allowed(s a `"x"y"')
    assert _rc == 0
    capture dataprobe, gatesonly allowed(s a)
    assert _rc == 9
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: S3 allowed() matches a value holding a double quote"
}
else {
    local ++fail_count
    display as error "  FAIL: S3 allowed() matches a value holding a double quote"
}

local ++test_count
capture noisily {
    sysuse auto, clear
    log using "`W'/s4.log", text replace name(v13log)
    capture noisily dataprobe, gatesonly stat(mean price . 7000)
    local rc = _rc
    log close v13log
    assert `rc' == 198
    _v13_count "`W'/s4.log" "lower bound is missing"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: S4 a missing stat() lower bound is named as missing"
}
else {
    local ++fail_count
    display as error "  FAIL: S4 a missing stat() lower bound is named as missing"
}

local ++test_count
capture noisily {
    capture mkdir "`W'/up"
    sysuse auto, clear
    quietly keep make price
    quietly save "`W'/up/a.dta", replace
    quietly save "`W'/up/B.DTA", replace
    quietly datamap, directory("`W'/up") output("`W'/sa1.md")
    assert r(nfiles) == 2
    erase "`W'/up/a.dta"
    erase "`W'/up/B.DTA"
    rmdir "`W'/up"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: SA1 directory() finds .DTA files"
}
else {
    local ++fail_count
    display as error "  FAIL: SA1 directory() finds .DTA files"
}

local ++test_count
capture noisily {
    sysuse auto, clear
    capture datamap, recursive output("`W'/sa3.md")
    assert _rc == 198
    capture datamap, recursive output("`W'/sa3.md") title("T")
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: SA3 recursive without directory() is r(198)"
}
else {
    local ++fail_count
    display as error "  FAIL: SA3 recursive without directory() is r(198)"
}

capture log close v13log
local files : dir "`W'" files "*"
foreach f of local files {
    capture erase "`W'/`f'"
}
capture rmdir "`W'"

display as text _newline "RESULT: test_datamap_v1103 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
