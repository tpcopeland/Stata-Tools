clear all
set more off
version 16.0
set linesize 255

* test_datamap_v1103r2.do - regressions for the second 1.10.3 review of
* datamap, datadict and dataqa.  Each test names its finding:
*   M* datamap, K* datadict, Q* dataqa, S* suspected items that reproduced.
* Every test was red on the tree before these fixes.

local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard

local test_count = 0
local pass_count = 0
local fail_count = 0

local W "`c(tmpdir)'/v1103r2"
capture mkdir "`W'"
macro drop DATAMAP_DQ

* number of lines of a text file that contain a string (read in Mata, so a
* needle or a line holding quotes, backticks or $ is never re-read)
capture program drop _r2_count
program define _r2_count, rclass
    args file needle
    mata: _r2_count_m(st_local("file"), st_local("needle"), 0)
    return scalar n = scalar(_r2_cnt)
    scalar drop _r2_cnt
end

* number of lines equal to a string after trimming blanks
capture program drop _r2_eq
program define _r2_eq, rclass
    args file needle
    mata: _r2_count_m(st_local("file"), st_local("needle"), 1)
    return scalar n = scalar(_r2_cnt)
    scalar drop _r2_cnt
end

* number of lines that contain the text of global R2_ND
capture program drop _r2_countg
program define _r2_countg, rclass
    args file
    mata: _r2_count_m(st_local("file"), st_global("R2_ND"), 0)
    return scalar n = scalar(_r2_cnt)
    scalar drop _r2_cnt
end

* whole text of a file into global R2_TXT
capture program drop _r2_slurp
program define _r2_slurp
    args file
    mata: st_global("R2_TXT", _r2_slurp_m(st_local("file")))
end

mata:
void _r2_count_m(string scalar f, string scalar nd, real scalar exact)
{
	real scalar fh, n
	string scalar line
	n = 0
	fh = fopen(f, "r")
	while ((line = fget(fh)) != J(0, 0, "")) {
		if (exact) {
			if (strtrim(line) == nd) n++
		}
		else if (strpos(line, nd) > 0) n++
	}
	fclose(fh)
	st_numscalar("_r2_cnt", n)
}
string scalar _r2_slurp_m(string scalar f)
{
	real scalar fh
	string scalar line, out
	out = ""
	fh = fopen(f, "r")
	while ((line = fget(fh)) != J(0, 0, "")) out = out + line + char(10)
	fclose(fh)
	return(out)
}
end

**# M1 VALUE LABEL DEFINITIONS list the label, not every data value

local ++test_count
capture noisily {
    clear
    quietly set obs 40
    gen id = _n
    gen dob = mdy(1, 1, 1950) + _n * 37
    format dob %td
    label define dobl 0 "unknown"
    label values dob dobl
    gen income = 20000 + _n * 1013
    label define incl 99999 "refused" .a "not asked"
    label values income incl
    quietly datamap, output("`W'/m1.txt") datesafe exclude(id) mincell(5)
    * a data value of each: an exact date (day count) and a unique income
    _r2_count "`W'/m1.txt" "-3615"
    local n1 = r(n)
    _r2_count "`W'/m1.txt" "21013"
    local n2 = r(n)
    assert `n1' == 0 & `n2' == 0
    _r2_eq "`W'/m1.txt" "0 = unknown"
    assert r(n) == 1
    _r2_eq "`W'/m1.txt" "99999 = refused"
    assert r(n) == 1
    _r2_eq "`W'/m1.txt" ".a = not asked"
    assert r(n) == 1
    _r2_count "`W'/m1.txt" "(used by: income)"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: M1 value-label section lists defined values only (no dates or incomes)"
}
else {
    local ++fail_count
    display as error "  FAIL: M1 value-label section lists defined values only (no dates or incomes)"
}

**# M2 a date forced into continuous() under datesafe: no date anywhere

local ++test_count
capture noisily {
    clear
    quietly set obs 40
    gen visit = mdy(3, 1, 2020) + _n
    format visit %td
    gen y = _n
    quietly datamap, output("`W'/m2.txt") datesafe continuous(visit) samples(2) ///
        saving("`W'/m2.dta", replace)
    * day counts 21976..22015 and the dates themselves
    foreach v in 21976 21977 22015 2020/03 03mar2020 {
        _r2_count "`W'/m2.txt" "`v'"
        assert r(n) == 0
    }
    _r2_count "`W'/m2.txt" "withheld (datesafe; date-formatted variable)"
    assert r(n) == 1
    _r2_count "`W'/m2.txt" "[DATE SUPPRESSED]"
    assert r(n) == 2
    quietly datamap, output("`W'/m2.json") format(json) datesafe continuous(visit)
    _r2_count "`W'/m2.json" "2197"
    assert r(n) == 0
    _r2_count "`W'/m2.json" `""withheld": "datesafe""'
    assert r(n) == 1
    use "`W'/m2.dta", clear
    quietly keep if variable == "visit"
    assert class == "continuous"
    assert missing(mean) & missing(min) & missing(max) & missing(p50)
    * control: without datesafe the range is printed
    clear
    quietly set obs 40
    gen visit = mdy(3, 1, 2020) + _n
    format visit %td
    quietly datamap, output("`W'/m2c.txt") continuous(visit)
    _r2_count "`W'/m2c.txt" "Range: 21976 to 22015"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: M2 datesafe hides a date forced into continuous() in text, JSON, samples, saving()"
}
else {
    local ++fail_count
    display as error "  FAIL: M2 datesafe hides a date forced into continuous() in text, JSON, samples, saving()"
}

**# M3 survey weight mean and a two-valued continuous() mean under mincell()

local ++test_count
capture noisily {
    clear
    quietly set obs 60
    gen wgt = cond(_n <= 2, 10, 1)
    gen y = _n
    quietly datamap, output("`W'/m3.txt") detect(survey)
    * mean 1.3 = 1 + 9 * 2 / 60 gives the suppressed cell (2 rows of 10) back
    _r2_count "`W'/m3.txt" "mean: 1.3"
    assert r(n) == 0
    _r2_count "`W'/m3.txt" "Sampling weight: wgt (range: 1 to 10, mean: withheld (mincell))"
    assert r(n) == 1
    * control: mincell(0) prints it
    quietly datamap, output("`W'/m3c.txt") detect(survey) mincell(0)
    _r2_count "`W'/m3c.txt" "mean: 1.3)"
    assert r(n) == 1
    * a 0/1 flag forced into continuous(): mean .05 x N 60 = 3 events
    clear
    quietly set obs 60
    gen byte flag = _n <= 3
    gen y = _n
    quietly datamap, output("`W'/m3b.txt") continuous(flag) saving("`W'/m3b.dta", replace)
    _r2_count "`W'/m3b.txt" "Mean: .05"
    assert r(n) == 0
    _r2_count "`W'/m3b.txt" "Mean: withheld (mincell; two or three values)"
    assert r(n) == 1
    _r2_count "`W'/m3b.txt" "skewness="
    assert r(n) == 0
    quietly datamap, output("`W'/m3b.json") format(json) continuous(flag)
    _r2_count "`W'/m3b.json" `""mean": null"'
    assert r(n) == 1
    use "`W'/m3b.dta", clear
    quietly keep if variable == "flag"
    assert missing(mean) & missing(sd) & max == 1
    clear
    quietly set obs 60
    gen byte flag = _n <= 3
    quietly datamap, output("`W'/m3d.txt") continuous(flag) mincell(0)
    _r2_count "`W'/m3d.txt" "Mean: .05"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: M3 survey weight and two-valued continuous means withheld under mincell()"
}
else {
    local ++fail_count
    display as error "  FAIL: M3 survey weight and two-valued continuous means withheld under mincell()"
}

**# M4 Sort Order is written (file and memory, text and JSON)

local ++test_count
capture noisily {
    sysuse auto, clear
    keep make price foreign
    sort foreign price
    quietly save "`W'/m4.dta", replace
    quietly datamap, single("`W'/m4.dta") output("`W'/m4.txt")
    _r2_eq "`W'/m4.txt" "Sort Order: foreign price"
    assert r(n) == 1
    quietly datamap, single("`W'/m4.dta") output("`W'/m4.json") format(json)
    _r2_count "`W'/m4.json" `""sort_order": "foreign price""'
    assert r(n) == 1
    use "`W'/m4.dta", clear
    sort price
    quietly datamap, output("`W'/m4m.txt")
    _r2_eq "`W'/m4m.txt" "Sort Order: price"
    assert r(n) == 1
    assert "`: sortedby'" == "price"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: M4 Sort Order written from file and memory"
}
else {
    local ++fail_count
    display as error "  FAIL: M4 Sort Order written from file and memory"
}

**# M5 separate: a failed dataset keeps its previous good output

local ++test_count
capture noisily {
    capture mkdir "`W'/m5"
    sysuse auto, clear
    quietly save "`W'/m5/a.dta", replace
    tempname fh
    file open `fh' using "`W'/m5/c.dta", write replace
    file write `fh' "not a dta" _n
    file close `fh'
    file open `fh' using "`W'/m5/c_map.txt", write replace
    file write `fh' "PREVIOUS GOOD CONTENT" _n
    file close `fh'
    capture datamap, directory("`W'/m5") separate
    assert _rc != 0
    _r2_eq "`W'/m5/c_map.txt" "PREVIOUS GOOD CONTENT"
    assert r(n) == 1
    _r2_count "`W'/m5/c_map.txt" "Dataset Documentation"
    assert r(n) == 0
    erase "`W'/m5/c.dta"
    erase "`W'/m5/c_map.txt"
    capture erase "`W'/m5/a_map.txt"
    erase "`W'/m5/a.dta"
    rmdir "`W'/m5"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: M5 separate keeps the previous output of a dataset that fails"
}
else {
    local ++fail_count
    display as error "  FAIL: M5 separate keeps the previous output of a dataset that fails"
}

**# M6 separate + saving(): the output column names each dataset's file

local ++test_count
capture noisily {
    capture mkdir "`W'/m6"
    sysuse auto, clear
    quietly save "`W'/m6/a.dta", replace
    sysuse census, clear
    quietly save "`W'/m6/b.dta", replace
    local here "`c(pwd)'"
    capture erase "`here'/datamap.txt"
    quietly datamap, directory("`W'/m6") separate saving("`W'/m6meta.dta", replace)
    capture confirm file "`here'/datamap.txt"
    assert _rc != 0
    use "`W'/m6meta.dta", clear
    quietly count if output == "datamap.txt"
    assert r(N) == 0
    quietly count if dataset == "a" & output == "`W'/m6/a_map.txt"
    assert r(N) > 0 & r(N) < .
    quietly count if dataset == "b" & output == "`W'/m6/b_map.txt"
    assert r(N) > 0 & r(N) < .
    foreach f in a.dta b.dta a_map.txt b_map.txt {
        erase "`W'/m6/`f'"
    }
    rmdir "`W'/m6"
    * memory + separate
    sysuse auto, clear
    capture erase "`here'/memory_map.txt"
    quietly datamap, separate saving("`W'/m6m.dta", replace)
    use "`W'/m6m.dta", clear
    assert output == "memory_map.txt"
    capture erase "`here'/memory_map.txt"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: M6 separate saving() records each dataset's own output file"
}
else {
    local ++fail_count
    display as error "  FAIL: M6 separate saving() records each dataset's own output file"
}

**# M7 compact still writes the sections asked for by name

local ++test_count
capture noisily {
    sysuse auto, clear
    gen byte hi = price > 10000
    gen age = cond(_n == 1, 130, 20)
    quietly datamap, output("`W'/m7.txt") compact samples(2) quality detect(binary)
    _r2_count "`W'/m7.txt" "SAMPLE OBSERVATIONS"
    assert r(n) == 1
    _r2_count "`W'/m7.txt" "DATA QUALITY FLAGS"
    assert r(n) == 1
    _r2_count "`W'/m7.txt" "Binary Variables"
    assert r(n) == 1
    * compact still drops the detail sections and label definitions
    _r2_count "`W'/m7.txt" "CATEGORICAL VARIABLES"
    assert r(n) == 0
    _r2_count "`W'/m7.txt" "VALUE LABEL DEFINITIONS"
    assert r(n) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: M7 compact keeps samples(), quality and detect(binary)"
}
else {
    local ++fail_count
    display as error "  FAIL: M7 compact keeps samples(), quality and detect(binary)"
}

**# S1 a non-integer threshold from config() is refused by name

local ++test_count
capture noisily {
    tempname fh
    file open `fh' using "`W'/s1.cfg", write replace
    file write `fh' "mincell = 2.5" _n
    file close `fh'
    sysuse auto, clear
    capture log close _r2l
    log using "`W'/s1.log", text replace name(_r2l)
    capture noisily datamap, output("`W'/s1.txt") config("`W'/s1.cfg")
    local rc1 = _rc
    capture noisily datadict, output("`W'/s1.md") config("`W'/s1.cfg")
    local rc2 = _rc
    log close _r2l
    assert `rc1' == 198 & `rc2' == 198
    _r2_count "`W'/s1.log" "mincell() must be an integer"
    assert r(n) == 2
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: S1 config() mincell = 2.5 refused with a named message"
}
else {
    local ++fail_count
    display as error "  FAIL: S1 config() mincell = 2.5 refused with a named message"
}

**# K5/S2 a reversed range in an override option is r(111), not ignored

local ++test_count
capture noisily {
    sysuse auto, clear
    * auto: price comes before weight, so weight-price is reversed
    foreach o in continuous categorical date {
        capture datamap, output("`W'/k5.txt") `o'(weight-price)
        assert _rc == 111
    }
    capture datadict, output("`W'/k5.md") categorical(weight-price)
    assert _rc == 111
    capture datadict, output("`W'/k5.md") datevars(weight-price)
    assert _rc == 111
    * file mode too (precheck on the file list)
    quietly save "`W'/k5.dta", replace
    capture datamap, single("`W'/k5.dta") output("`W'/k5.txt") categorical(weight-price)
    assert _rc == 111
    * control: the forward range still works
    quietly datamap, output("`W'/k5.txt") categorical(price-weight)
    assert strpos(" `r(categorical_vars)' ", " price ")
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: K5/S2 reversed override range refused r(111)"
}
else {
    local ++fail_count
    display as error "  FAIL: K5/S2 reversed override range refused r(111)"
}

**# K4/S3 saving() without .dta: an existing name is refused before output

local ++test_count
capture noisily {
    sysuse auto, clear
    capture erase "`W'/k4meta.dta"
    capture erase "`W'/k4b.md"
    capture erase "`W'/k4b.txt"
    quietly datadict, output("`W'/k4a.md") saving("`W'/k4meta")
    confirm file "`W'/k4meta.dta"
    capture datadict, output("`W'/k4b.md") saving("`W'/k4meta")
    assert _rc == 602
    capture confirm file "`W'/k4b.md"
    assert _rc != 0
    capture erase "`W'/k4meta2.dta"
    quietly datamap, output("`W'/k4a.txt") saving("`W'/k4meta2")
    assert "`r(metadata)'" == "`W'/k4meta2.dta"
    capture datamap, output("`W'/k4b.txt") saving("`W'/k4meta2")
    assert _rc == 602
    capture confirm file "`W'/k4b.txt"
    assert _rc != 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: K4/S3 saving() name without .dta checked before any output"
}
else {
    local ++fail_count
    display as error "  FAIL: K4/S3 saving() name without .dta checked before any output"
}

**# K1 datadict saving(): no categorical summaries under mincell()

local ++test_count
capture noisily {
    clear
    quietly set obs 100
    gen byte flag = _n <= 3
    gen double y = _n
    quietly datadict, output("`W'/k1.md") saving("`W'/k1.dta", replace)
    _r2_count "`W'/k1.md" "suppressed <5"
    assert r(n) == 1
    use "`W'/k1.dta", clear
    quietly keep if variable == "flag"
    assert class == "categorical"
    assert missing(mean) & missing(sd) & missing(p50) & missing(min) & missing(max)
    * a two-valued variable forced into continuous(): mean and sd withheld
    clear
    quietly set obs 100
    gen byte flag = _n <= 3
    quietly datadict, output("`W'/k1b.md") continuous(flag) stats saving("`W'/k1b.dta", replace)
    _r2_count "`W'/k1b.md" "Mean=withheld"
    assert r(n) == 1
    _r2_count "`W'/k1b.md" "Mean=.03"
    assert r(n) == 0
    use "`W'/k1b.dta", clear
    assert missing(mean) & missing(sd)
    * control: mincell(0) keeps them
    clear
    quietly set obs 100
    gen byte flag = _n <= 3
    quietly datadict, output("`W'/k1c.md") mincell(0) saving("`W'/k1c.dta", replace)
    use "`W'/k1c.dta", clear
    assert abs(mean - .03) < 1e-12
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: K1 datadict saving() withholds categorical and two-valued summaries under mincell()"
}
else {
    local ++fail_count
    display as error "  FAIL: K1 datadict saving() withholds categorical and two-valued summaries under mincell()"
}

**# K2 datadict: a failed run keeps the previous dictionary

local ++test_count
capture noisily {
    sysuse auto, clear
    quietly save "`W'/k2good.dta", replace
    tempname fh
    file open `fh' using "`W'/k2bad.dta", write replace
    file write `fh' "not a dta" _n
    file close `fh'
    file open `fh' using "`W'/k2.md", write replace
    file write `fh' "PREVIOUS GOOD CONTENT" _n
    file close `fh'
    capture datadict, filelist("`W'/k2good" "`W'/k2bad") output("`W'/k2.md")
    assert _rc != 0
    _r2_eq "`W'/k2.md" "PREVIOUS GOOD CONTENT"
    assert r(n) == 1
    _r2_count "`W'/k2.md" "Data Dictionary"
    assert r(n) == 0
    * separate: the failing file's dictionary is not truncated
    file open `fh' using "`W'/k2bad_dictionary.md", write replace
    file write `fh' "PREVIOUS GOOD CONTENT" _n
    file close `fh'
    capture datadict, filelist("`W'/k2good" "`W'/k2bad") separate
    assert _rc != 0
    _r2_eq "`W'/k2bad_dictionary.md" "PREVIOUS GOOD CONTENT"
    assert r(n) == 1
    * an unwritable output still fails before any dataset is read
    capture datadict, single("`W'/k2good") output("`W'/nodir/x.md")
    assert _rc == 603
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: K2 datadict stages output; a failure keeps the previous file"
}
else {
    local ++fail_count
    display as error "  FAIL: K2 datadict stages output; a failure keeps the previous file"
}

**# K3 config() missing = no leaves the Missing column off

local ++test_count
capture noisily {
    tempname fh
    file open `fh' using "`W'/k3.cfg", write replace
    file write `fh' "missing = no" _n
    file close `fh'
    file open `fh' using "`W'/k3y.cfg", write replace
    file write `fh' "missing = yes" _n
    file close `fh'
    sysuse auto, clear
    quietly datadict, output("`W'/k3.md") config("`W'/k3.cfg")
    _r2_count "`W'/k3.md" "| Missing |"
    assert r(n) == 0
    quietly datadict, output("`W'/k3y.md") config("`W'/k3y.cfg")
    _r2_count "`W'/k3y.md" "| Missing |"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: K3 config() missing = no is off, yes is on"
}
else {
    local ++fail_count
    display as error "  FAIL: K3 config() missing = no is off, yes is on"
}

**# K6 a non-ASCII dataset name: heading and working anchor

local ++test_count
capture noisily {
    sysuse auto, clear
    keep make price
    local nm = "`W'/" + uchar(246) + "rebro_data.dta"
    quietly save "`nm'", replace
    quietly datadict, single("`nm'") output("`W'/k6.md")
    global R2_ND = "## 1. " + uchar(214) + "rebro Data"
    _r2_countg "`W'/k6.md"
    assert r(n) == 1
    global R2_ND = "(#1-" + uchar(246) + "rebro-data)"
    _r2_countg "`W'/k6.md"
    assert r(n) == 1
    * ASCII names unchanged: proper() rules (after a digit, upper case)
    quietly save "`W'/k6_2nd_wave.dta", replace
    quietly datadict, single("`W'/k6_2nd_wave") output("`W'/k6b.md")
    _r2_count "`W'/k6b.md" "## 1. K6 2Nd Wave"
    assert r(n) == 1
    erase "`nm'"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: K6 non-ASCII dataset heading and anchor"
}
else {
    local ++fail_count
    display as error "  FAIL: K6 non-ASCII dataset heading and anchor"
}

**# K7 labelled extended missing codes are documented

local ++test_count
capture noisily {
    clear
    quietly set obs 30
    gen byte q = mod(_n, 2) + 1
    replace q = .a in 1/3
    label define ql 1 "Yes" 2 "No" .a "Refused"
    label values q ql
    quietly datadict, output("`W'/k7.md")
    _r2_count "`W'/k7.md" ".a=Refused (missing code)"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: K7 labelled extended missing codes documented"
}
else {
    local ++fail_count
    display as error "  FAIL: K7 labelled extended missing codes documented"
}

**# K8 a backslash before a pipe survives Markdown escaping

local ++test_count
capture noisily {
    clear
    quietly set obs 10
    gen x = _n
    local bs = char(92)
    label variable x "a`bs'|b"
    quietly datadict, output("`W'/k8.md")
    * source a\\\|b renders a\|b (cmark-gfm: \\ is a backslash, \| a pipe)
    global R2_ND = "a" + char(92) + char(92) + char(92) + "|b"
    _r2_countg "`W'/k8.md"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: K8 backslash escaped before the pipe"
}
else {
    local ++fail_count
    display as error "  FAIL: K8 backslash escaped before the pipe"
}

**# K9 a manifest with a UTF-8 byte-order mark

local ++test_count
capture noisily {
    sysuse auto, clear
    quietly save "`W'/k9.dta", replace
    tempname fh
    file open `fh' using "`W'/k9.txt", write replace
    file write `fh' (uchar(65279) + "`W'/k9.dta") _n
    file close `fh'
    datadict, manifest("`W'/k9.txt") output("`W'/k9.md")
    assert r(nfiles) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: K9 manifest with a byte-order mark"
}
else {
    local ++fail_count
    display as error "  FAIL: K9 manifest with a byte-order mark"
}

**# K10 a variable named twice is documented once

local ++test_count
capture noisily {
    sysuse auto, clear
    quietly datadict price price mpg, output("`W'/k10.md")
    assert r(nvars_total) == 2
    _r2_count "`W'/k10.md" "| `=char(96)'price`=char(96)' |"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: K10 repeated varlist name documented once"
}
else {
    local ++fail_count
    display as error "  FAIL: K10 repeated varlist name documented once"
}

**# K11 Filename shows the file's own name (UP.DTA)

local ++test_count
capture noisily {
    capture mkdir "`W'/k11"
    sysuse auto, clear
    keep make price
    quietly save "`W'/k11/UP.DTA", replace
    quietly datadict, directory("`W'/k11") output("`W'/k11.md")
    _r2_count "`W'/k11.md" "**Filename:** `=char(96)'UP.DTA`=char(96)'"
    assert r(n) == 1
    _r2_count "`W'/k11.md" "UP.dta"
    assert r(n) == 0
    erase "`W'/k11/UP.DTA"
    rmdir "`W'/k11"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: K11 Filename keeps the real extension"
}
else {
    local ++fail_count
    display as error "  FAIL: K11 Filename keeps the real extension"
}

**# K12 a date forced into categorical() follows dateformat()

local ++test_count
capture noisily {
    clear
    quietly set obs 30
    gen d = mdy(3, 4, 1980) + mod(_n, 3)
    format d %td
    quietly datadict, output("`W'/k12.md") categorical(d) dateformat(%tdDD/NN/CCYY) mincell(0) stats
    _r2_count "`W'/k12.md" "04/03/1980"
    assert r(n) == 1
    _r2_count "`W'/k12.md" "04mar1980"
    assert r(n) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: K12 categorical date levels in dateformat()"
}
else {
    local ++fail_count
    display as error "  FAIL: K12 categorical date levels in dateformat()"
}

**# S4 an e-notation IQR is written "a to b", not "a-b"

local ++test_count
capture noisily {
    clear
    quietly set obs 50
    gen double v = (_n + 10) * 1e-5
    quietly datadict, output("`W'/s4.md") stats mincell(0)
    _r2_count "`W'/s4.md" "IQR=2.30e-04 to 4.80e-04"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: S4 e-notation IQR separator"
}
else {
    local ++fail_count
    display as error "  FAIL: S4 e-notation IQR separator"
}

**# S5 a dataset name with < is escaped in the heading and contents

local ++test_count
capture noisily {
    capture mkdir "`W'/s5"
    sysuse auto, clear
    keep make price
    local nm = "`W'/s5/a" + char(60) + "b.dta"
    quietly save "`nm'", replace
    quietly datadict, directory("`W'/s5") output("`W'/s5.md")
    _r2_count "`W'/s5.md" "## 1. A&lt;B"
    assert r(n) == 1
    _r2_count "`W'/s5.md" "[A&lt;B](#1-ab)"
    assert r(n) == 1
    erase "`nm'"
    rmdir "`W'/s5"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: S5 dataset name escaped in heading and TOC"
}
else {
    local ++fail_count
    display as error "  FAIL: S5 dataset name escaped in heading and TOC"
}

**# Q1 export: a small dataset's signature does not print its N

local ++test_count
capture noisily {
    local L "`W'/q1.dta"
    capture erase "`L'"
    dataqa set maskrare mincell(5) ledger("`L'") run(r1) signature
    sysuse auto, clear
    keep in 1/3
    quietly dataprobe, gatesonly isid(make) name(tiny)
    sysuse auto, clear
    quietly dataprobe, gatesonly isid(make) name(full)
    dataqa export, saving("`W'/q1rel.dta") replace
    local nsd = r(n_sig_dropped)
    use "`W'/q1rel.dta", clear
    quietly count if dataset == "tiny" & signature != ""
    assert r(N) == 0
    quietly count if dataset == "full" & substr(signature, 1, 3) == "74:"
    assert r(N) == 1
    assert `nsd' == 1
    dataqa set clear
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: Q1 export blanks the signature of a dataset below the threshold"
}
else {
    local ++fail_count
    display as error "  FAIL: Q1 export blanks the signature of a dataset below the threshold"
}

**# Q2 a failed invariant is not superseded by the same check as a band

local ++test_count
capture noisily {
    local L "`W'/q2.dta"
    capture erase "`L'"
    dataqa set maskrare mincell(5) ledger("`L'") run(r1) collect
    sysuse auto, clear
    quietly dataprobe, gatesonly stat(mean mpg 25 30) name(auto)
    quietly dataprobe, gatesonly bands(stat(mean mpg 25 30)) bandwarn name(auto)
    capture dataqa assert, expect(auto)
    assert _rc == 9 & r(n_failed) == 1
    dataqa set clear
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: Q2 gate key includes kind (invariant not cleared by a band)"
}
else {
    local ++fail_count
    display as error "  FAIL: Q2 gate key includes kind (invariant not cleared by a band)"
}

**# Q3 a rerun on a subset does not supersede a full-data failure
* 1.10.4 (user decision, narrow rule): only a "(modified)" rerun is kept from
* superseding an unmodified row.  A call under name() carries no
* (modified) marker, so the named-subset cases r2 and r4 below now
* supersede, as a fixed file reloaded and rerun does; they pinned the
* 1.10.3 n_scope rule and were updated, not dropped.

local ++test_count
capture noisily {
    local L "`W'/q3.dta"
    capture erase "`L'"
    dataqa set maskrare mincell(5) ledger("`L'") run(r1) collect
    sysuse auto, clear
    quietly dataprobe, gatesonly stat(mean mpg 25 30) notmissing(rep78)
    quietly keep if inrange(mpg, 25, 30) & !missing(rep78)
    quietly dataprobe, gatesonly stat(mean mpg 25 30) notmissing(rep78)
    capture dataqa assert, expect(auto)
    assert _rc == 9 & r(n_failed) == 2
    * named, data subset in memory (no (modified) marker): supersedes
    dataqa set maskrare mincell(5) ledger("`L'") run(r2) collect
    sysuse auto, clear
    quietly dataprobe, gatesonly stat(mean mpg 25 30) name(auto2)
    preserve
    quietly keep if inrange(mpg, 25, 30)
    quietly dataprobe, gatesonly stat(mean mpg 25 30) name(auto2)
    restore
    capture dataqa assert, expect(auto2)
    assert _rc == 0 & r(n_failed) == 0 & r(n_superseded) == 1
    * a by() group: the subset changes the group's rows
    dataqa set maskrare mincell(5) ledger("`L'") run(r4) collect
    sysuse auto, clear
    quietly dataprobe, gatesonly by(foreign) notmissing(rep78) name(auto4)
    quietly keep if !missing(rep78) | foreign == 0
    quietly replace rep78 = 3 if missing(rep78)
    quietly dataprobe, gatesonly by(foreign) notmissing(rep78) name(auto4)
    capture dataqa assert, expect(auto4)
    * both groups' failures are superseded by the named rerun (1.10.3 kept
    * foreign = 1's, whose rows went 22 -> 21)
    assert _rc == 0 & r(n_failed) == 0 & r(n_superseded) == 2
    * control: the same rows rerun after a fix still supersede
    dataqa set maskrare mincell(5) ledger("`L'") run(r3) collect
    sysuse auto, clear
    quietly dataprobe, gatesonly notmissing(rep78) name(auto3)
    quietly replace rep78 = 3 if missing(rep78)
    quietly dataprobe, gatesonly notmissing(rep78) name(auto3)
    capture dataqa assert, expect(auto3)
    assert _rc == 0 & r(n_superseded) == 1
    dataqa set clear
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: Q3 a (modified) subset rerun does not supersede; a named or same-rows rerun does"
}
else {
    local ++fail_count
    display as error "  FAIL: Q3 a (modified) subset rerun does not supersede; a named or same-rows rerun does"
}

**# Q4 export blanks literal identifiers in expected, label and message

local ++test_count
capture noisily {
    local L "`W'/q4.dta"
    capture erase "`L'"
    dataqa set maskrare mincell(5) ledger("`L'") run(r1) collect
    sysuse auto, clear
    gen str12 pnr = "19800101" + string(_n, "%04.0f")
    quietly dataprobe, gatesonly rule(pnrchk: pnr != "198001010009") forbid(pnr 198001010011) name(autob)
    quietly dataprobe, gatesonly inrange(price 1000 20000) name(autod)
    dataqa export, saving("`W'/q4rel.dta") replace
    local ntd = r(n_text_dropped)
    use "`W'/q4rel.dta", clear
    foreach v in expected label message scope {
        quietly count if strpos(`v', "19800101")
        assert r(N) == 0
    }
    * bounds keep their numbers
    quietly count if family == "inrange" & expected == "[1000, 20000]"
    assert r(N) == 1
    assert `ntd' >= 3 & `ntd' < .
    dataqa set clear
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: Q4 export blanks literal values in value-gate text, keeps bounds"
}
else {
    local ++fail_count
    display as error "  FAIL: Q4 export blanks literal values in value-gate text, keeps bounds"
}

**# Q5 expect() matches the name, not a prefix

local ++test_count
capture noisily {
    local L "`W'/q5.dta"
    capture erase "`L'"
    dataqa set maskrare mincell(5) ledger("`L'") run(r1) collect
    sysuse auto, clear
    quietly dataprobe, gatesonly isid(make) name(cohort (2019))
    quietly dataprobe, gatesonly isid(make) name(lisa, sample)
    capture dataqa assert, expect(cohort lisa)
    assert _rc == 9
    assert "`r(missing)'" == "cohort lisa"
    capture dataqa assert, expect(`"cohort (2019)"')
    assert _rc == 0
    dataqa set clear
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: Q5 expect() needs the exact name"
}
else {
    local ++fail_count
    display as error "  FAIL: Q5 expect() needs the exact name"
}

**# Q6 report shows ledger text as text (no $global or SMCL expansion)

local ++test_count
capture noisily {
    local L "`W'/q6.dta"
    capture erase "`L'"
    global R2_HX "EXPANDED"
    quietly dataqa set maskrare mincell(5) ledger("`L'") run(r1) collect
    sysuse auto, clear
    quietly dataprobe, gatesonly stat(mean mpg 25 30) name(auto)
    quietly dataprobe, gatesonly bands(stat(mean price 1 2)) bandwarn name(autob)
    dataqa set clear
    use "`L'", clear
    mata: st_sstore(1, "expected", "^[a-z]+" + char(36) + "R2_HX")
    mata: st_sstore(2, "dataset", "au{bf:to}")
    quietly save "`L'", replace
    sysuse auto, clear
    capture log close _r2l
    log using "`W'/q6.log", text replace name(_r2l)
    dataqa report using "`L'", run(r1) markdown("`W'/q6.md") replace bands
    log close _r2l
    _r2_count "`W'/q6.md" "EXPANDED"
    assert r(n) == 0
    global R2_ND = "^[a-z]+" + char(36) + "R2_HX"
    _r2_countg "`W'/q6.md"
    assert r(n) >= 1 & r(n) < .
    _r2_count "`W'/q6.log" "au{bf:to}"
    assert r(n) >= 1 & r(n) < .
    macro drop R2_HX
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: Q6 report prints ledger text literally"
}
else {
    local ++fail_count
    display as error "  FAIL: Q6 report prints ledger text literally"
}

**# Q7 compare N and stat flags name the by() group

local ++test_count
capture noisily {
    local L "`W'/q7.dta"
    capture erase "`L'"
    sysuse auto, clear
    gen site = cond(_n <= 30, 1, 2)
    quietly dataprobe, gatesonly stat(mean mpg 10 40) by(site) name(auto) ledger("`L'", run(base))
    sysuse auto, clear
    gen site = cond(_n <= 50, 1, 2)
    replace mpg = mpg * 1.5
    quietly dataprobe, gatesonly stat(mean mpg 10 40) by(site) name(auto) ledger("`L'", run(now))
    capture log close _r2l
    log using "`W'/q7.log", text replace name(_r2l)
    dataqa compare using "`L'", run(now) baseline(base)
    log close _r2l
    _r2_count "`W'/q7.log" "[by(site | site=1)]"
    local n1 = r(n)
    _r2_count "`W'/q7.log" "[by(site | site=2)]"
    local n2 = r(n)
    * each group's N line and stat line carry the group
    assert `n1' >= 2 & `n2' >= 2
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: Q7 compare flags carry the by() group"
}
else {
    local ++fail_count
    display as error "  FAIL: Q7 compare flags carry the by() group"
}

**# Q8 dataqa set mincell(-1) is refused and keeps the defaults

local ++test_count
capture noisily {
    dataqa set maskrare mincell(7)
    capture dataqa set mincell(-1)
    assert _rc == 198
    dataqa set
    assert strpos(`"`r(defaults)'"', "mincell(7)")
    dataqa set clear
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: Q8 dataqa set mincell(-1) refused"
}
else {
    local ++fail_count
    display as error "  FAIL: Q8 dataqa set mincell(-1) refused"
}

**# S6 export refuses to write over the session's ledger

local ++test_count
capture noisily {
    local L1 "`W'/s6a.dta"
    local L2 "`W'/s6b.dta"
    capture erase "`L1'"
    capture erase "`L2'"
    sysuse auto, clear
    quietly dataprobe, gatesonly isid(make) name(auto) maskrare mincell(5) ledger("`L1'", run(r1))
    quietly dataprobe, gatesonly notmissing(price) name(auto) maskrare mincell(5) ledger("`L2'", run(r1))
    dataqa set ledger("`L1'") run(r1)
    capture dataqa export using "`L2'", run(r1) saving("`L1'") replace
    assert _rc == 602
    use "`L1'", clear
    assert _N == 1 & family == "isid"
    dataqa set clear
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: S6 export refuses the session ledger as saving()"
}
else {
    local ++fail_count
    display as error "  FAIL: S6 export refuses the session ledger as saving()"
}

**# S7 compare reads a ledger written without a signature column

local ++test_count
capture noisily {
    local L "`W'/s7.dta"
    capture erase "`L'"
    sysuse auto, clear
    quietly dataprobe, gatesonly notmissing(price) name(auto) ledger("`L'", run(base))
    quietly dataprobe, gatesonly notmissing(price) name(auto) ledger("`L'", run(now))
    use "`L'", clear
    drop signature
    quietly save "`L'", replace
    dataqa compare using "`L'", run(now) baseline(base)
    assert r(n_flags) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: S7 compare without a signature column"
}
else {
    local ++fail_count
    display as error "  FAIL: S7 compare without a signature column"
}

capture log close _r2l
macro drop DATAMAP_DQ R2_ND R2_TXT
local files : dir "`W'" files "*"
foreach f of local files {
    capture erase "`W'/`f'"
}
capture rmdir "`W'"

display as text _newline "RESULT: test_datamap_v1103r2 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
