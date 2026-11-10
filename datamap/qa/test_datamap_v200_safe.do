*! test_datamap_v200_safe.do Version 1.0.0  2026/11/10
*! datamap 2.0.0 Phase 4, batch B: dataprobe brief (U1) and the safe preset
*! (U2) on datamap, dataprobe, datamvp and dataqa set agent, each against
*! the acceptance test of the plan
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Fixture: a 3,000-row person file with identifiers and small cells: lopnr
* (a likely identifier by name), pnr_str (all-distinct text "P100001".., not
* matched by name), clinic (eight codes "K00".."K07", 375 rows each), region
* (digit-free text), grp (level 9 "RARENINE" held by 3 rows), age (2
* missing), edu (.a "Refused" 145, .b "Notasked" 3), dob (%td), admit (%tc),
* datestr (date text), ymd (yyyymmdd integers), income_s (numeric text with
* "NA").  The needles below are what a leak would print; every safe check is
* paired with a control run in which the same needle is present, so a needle
* that cannot match never passes for a mask.
*
*   S1  U2 datamap, safe: no identifier value, exact date, or count from 1 to
*       4 (with its complement) in the document, the .dta or the .csv;
*       lopnr excluded; text above maxcat() lists no value; r() unmasked
*   S2  datamap, safe: samples() rc 198, a config() samples key ignored with
*       a note, mincell(2) raised to 5, mincell(10) kept
*   S3  U2 dataprobe, safe (full and brief): the same needles absent from the
*       log; dates withheld; text levels withheld with the reason; r()
*       unmasked; nothing is printed or stored as r(text)
*   S4  dataprobe, safe saving(): the file and the frame carry the printed
*       masks (excluded and date rows, extremes, small missing counts);
*       compare() reads a masked baseline
*   S5  dataprobe, safe: makespec(), nomaskrare, by() on an identifier, a
*       date or text holding a digit each stop rc 198 before any profile
*   S6  U2 datamvp, safe: lopnr left out; no needle in the log; save()
*       writes no pattern below 5 and no cumpct; bytable() on text holding
*       a digit and a by prefix on an identifier stop rc 198
*   S7  dataqa set agent: spec "safe"; dataprobe, datamap and datamvp run
*       under the preset without the option; dataqa set clear ends it
*   S8  U1 dataprobe, brief: line count <= variables + 8; flagged first; no
*       text level of count 1; all-distinct text collapsed; r() identical to
*       the full profile, with and without maskrare
*   S9  brief with gatesonly, patterns or byfreq is rc 198
*   S10 one identifier rule: _datamap_idnames matches what datamap suggests
*   S11 dataprobe, safe: a date's mean or percentile in stat() and
*       groupstat() prints [withheld], in the log and in the ledger
*   S12 the sweep: a second fixture with a small cell of every size 1 to 4
*       (levels, missing counts, N= complements, patterns, an identifier
*       string); control first, then safe and the dataqa set agent preset
*       over datamap, dataprobe and datamvp: every log and written file
*   S13 datamap, safe: a numeric level below mincell() is not named (its
*       value can identify; dataprobe prints [suppressed]); the rare levels
*       pool as "other values" / "all values"; without safe they are named
* Logs are read through Mata, never a Stata macro reader.
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_datamap_v200_safe.log", replace text name(main)
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
local work "`base'_v200swork"
capture mkdir "`work'"
capture mkdir "`work'/plus"
capture mkdir "`work'/personal"
capture mkdir "`work'/run"
mata: assert(direxists(st_local("work") + "/plus") & direxists(st_local("work") + "/run"))
local oldplus : sysdir PLUS
local oldpersonal : sysdir PERSONAL
sysdir set PLUS "`work'/plus"
sysdir set PERSONAL "`work'/personal"
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace
discard
local tests = 0
local pass = 0
local fail = 0
local cwd0 "`c(pwd)'"
macro drop DATAMAP_DQ

capture mata: mata drop _v2s_slurp()
capture mata: mata drop _v2s_in()
capture mata: mata drop _v2s_leaks()
capture mata: mata drop _v2s_rsnap()
capture mata: mata drop _v2s_lines()
capture mata: mata drop _v2s_cells()
capture mata: mata drop _v2s_split()
mata:
void _v2s_slurp(string scalar path, string scalar dst)
{
	real scalar fh
	string scalar s, l
	fh = fopen(path, "r")
	s = ""
	while ((l = fget(fh)) != J(0, 0, "")) s = s + l + char(10)
	fclose(fh)
	st_local(dst, s)
}
// local t holds needle when want is 1, does not when 0
void _v2s_in(string scalar needle, real scalar want)
{
	if ((strpos(st_local("t"), needle) > 0) != want) {
		errprintf("text check failed (want %g): %s\n", want, needle)
		exit(9)
	}
}
// the leak needles found in local t, space-separated, into local leaks
void _v2s_leaks()
{
	string rowvector nm, rx
	string colvector L
	string scalar t, r, out
	real scalar i, j, p
	nm = ("pnr_value", "clinic_code", "datestr_value", "td_date", "slash_date",
		"rare_level_count", "notasked_count", "refused_145", "nonmiss_2998",
		"age_miss_2", "lopnr_stats")
	rx = ("P1[0-9][0-9][0-9][0-9][0-9]", "K0[0-7]", "2020-01-1[0-4]",
		"[0-3][0-9](jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)(19|20)[0-9][0-9]",
		"(19|20)[0-9][0-9]/[01][0-9]/[0-3][0-9]",
		"RARENINE[^0-9|]*[^0-9<][1-4]([^0-9]|$)", "Notasked[^0-9|]*[^0-9<][1-4]([^0-9]|$)",
		"Refused[^0-9|]*145", "(^|[^0-9])2,?998([^0-9]|$)",
		"^ *age .* 2 missing|`age` \|[^|]*\|[^|]*\|[^|]*\| 2 \(|^age +\|.* 2 ",
		"lopnr.*(min=|mean=|p50=|range=)")
	t = st_local("t")
	// line by line: no pattern spans a line
	L = J(0, 1, "")
	r = t
	while ((p = strpos(r, char(10))) > 0) {
		L = L \ substr(r, 1, p - 1)
		r = substr(r, p + 1, .)
	}
	if (r != "") L = L \ r
	out = ""
	for (j = 1; j <= cols(rx); j++) {
		for (i = 1; i <= rows(L); i++) {
			if (ustrregexm(L[i], rx[j])) {
				out = out + " " + nm[j]
				break
			}
		}
	}
	st_local("leaks", strtrim(out))
}
// local t split on line feeds into a column
string colvector _v2s_split()
{
	string colvector L
	string scalar r
	real scalar p
	L = J(0, 1, "")
	r = st_local("t")
	while ((p = strpos(r, char(10))) > 0) {
		L = L \ substr(r, 1, p - 1)
		r = substr(r, p + 1, .)
	}
	if (r != "") L = L \ r
	return(L)
}
// S12: the small-cell leaks of the sweep fixture found in local t, one name
// per kind, into local leaks.  Each pattern is a count of 1 to 4 (or what
// gives it back) next to its label, in the way one of the commands prints it
void _v2s_cells()
{
	string rowvector nm, rx
	string colvector L
	string scalar out
	real scalar i, j
	nm = ("level_count", "missing_count", "n_complement", "pattern_count", "id_value")
	rx = ("TINY[A-Z]+[^0-9<A-Z]*[1-4]([^0-9,]|$)",
		"^\| `m[1-5]` \|[^|]*\|[^|]*\| [1-4] \(|^ *m[1-5] +[1-4] missing|^m[1-5] +\| +double +[0-9,]+ +[1-4] ",
		"N=[ ]*(3996|3997|3998|3999)([^0-9]|$)|double +3,99[6-9] ",
		"`[+.]{4,5}`: [1-4]( |$)|[+.]{4,5} +[0-9] +[1-4] \|",
		"ZQ[0-9]{7}")
	L = _v2s_split()
	out = ""
	for (j = 1; j <= cols(rx); j++) {
		for (i = 1; i <= rows(L); i++) {
			if (ustrregexm(L[i], rx[j])) {
				out = out + " " + nm[j]
				break
			}
		}
	}
	st_local("leaks", strtrim(out))
}
// every r() scalar and macro as one text, into local dst
void _v2s_rsnap(string scalar dst)
{
	string colvector s
	string scalar out
	real scalar i
	out = ""
	s = sort(st_dir("r()", "numscalar", "*"), 1)
	for (i = 1; i <= rows(s); i++) out = out + "|" + s[i] + "=" + strofreal(st_numscalar("r(" + s[i] + ")"), "%21x")
	s = sort(st_dir("r()", "macro", "*"), 1)
	for (i = 1; i <= rows(s); i++) out = out + "|" + s[i] + "=" + st_global("r(" + s[i] + ")")
	st_local(dst, out)
}
// lines of local t from the first line starting with head to the end,
// less the closing "log close" lines, into local nlines
void _v2s_lines(string scalar head)
{
	string colvector L
	string scalar r
	real scalar i, p, k, on
	L = J(0, 1, "")
	r = st_local("t")
	while ((p = strpos(r, char(10))) > 0) {
		L = L \ substr(r, 1, p - 1)
		r = substr(r, p + 1, .)
	}
	k = 0
	on = 0
	for (i = 1; i <= rows(L); i++) {
		if (!on & substr(L[i], 1, strlen(head)) == head) on = 1
		if (on & substr(L[i], 1, 1) != "." & substr(strtrim(L[i]), 1, 5) != "name:" &
			substr(strtrim(L[i]), 1, 4) != "log:" & substr(strtrim(L[i]), 1, 9) != "log type:" &
			substr(strtrim(L[i]), 1, 10) != "closed on:" & substr(L[i], 1, 5) != "-----") k++
	}
	st_local("nlines", strofreal(k))
}
end

* the fixture
capture program drop _v2s_fixture
program define _v2s_fixture
    clear
    set seed 20261110
    quietly set obs 3000
    gen long lopnr = _n
    gen str7 pnr_str = "P" + string(100000 + _n, "%06.0f")
    gen str3 clinic = "K0" + string(mod(_n, 8))
    gen str5 region = cond(mod(_n,4)==0,"North",cond(mod(_n,4)==1,"South",cond(mod(_n,4)==2,"East","West")))
    gen byte sex = 1 + mod(_n, 2)
    label define sexl 1 "Male" 2 "Female", replace
    label values sex sexl
    gen byte grp = 1 + mod(_n, 3)
    quietly replace grp = 9 in 1/3
    label define grpl 1 "A" 2 "B" 3 "C" 9 "RARENINE", replace
    label values grp grpl
    gen age = 20 + mod(_n * 7, 60)
    quietly replace age = . in 10/11
    gen float bmi = 20 + mod(_n, 15)
    quietly replace bmi = 999 in 100/125
    gen dob = mdy(1, 1, 1950) + mod(_n * 37, 15000)
    format dob %td
    gen double admit = dhms(mdy(3,1,2020) + mod(_n,200), mod(_n,24), 0, 0)
    format admit %tc
    gen str10 datestr = "2020-01-1" + string(mod(_n, 5))
    gen long ymd = 20200101 + mod(_n, 28)
    gen byte edu = 1 + mod(_n, 4)
    quietly replace edu = .a in 200/344
    quietly replace edu = .b in 400/402
    label define edul 1 "Primary" 2 "Secondary" 3 "Tertiary" 4 "Other" .a "Refused" .b "Notasked", replace
    label values edu edul
    gen str5 income_s = string(1000 + mod(_n * 13, 900))
    quietly replace income_s = "NA" in 1/124
    quietly compress
end

quietly cd "`work'/run"
_v2s_fixture
quietly save person, replace
quietly cd "`cwd0'"

**# S1 U2 datamap, safe: the document and saving() carry no leak
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    * control: without safe the needles are found (the check can see them)
    quietly datamap, output(ctl.md) samples(5) mincell(0) saving(ctl, replace csv)
    mata: _v2s_slurp("ctl.md", "t")
    mata: _v2s_leaks()
    display "control leaks: `leaks'"
    foreach n in pnr_value clinic_code datestr_value slash_date lopnr_stats {
        assert strpos(" `leaks' ", " `n' ")
    }
    use person, clear
    datamap, safe output(s1.md) saving(s1, replace csv) quality missing(pattern)
    assert r(safe) == 1 & r(mincell) == 5
    assert strpos(" `r(excluded_vars)' ", " lopnr ")
    foreach f in s1.md s1.csv {
        mata: _v2s_slurp("`f'", "t")
        mata: _v2s_leaks()
        display "`f' leaks: [`leaks']"
        assert "`leaks'" == ""
    }
    mata: _v2s_slurp("s1.md", "t")
    mata: _v2s_in("excluded (structure only)", 1)
    mata: _v2s_in("exact dates withheld", 1)
    mata: _v2s_in("values withheld (datesafe)", 1)
    * text above maxcat(): no non-numeric value listed (1.x and 2.0.0
    * without safe list "NA")
    mata: _v2s_in(`""NA""', 0)
    mata: _v2s_slurp("ctl.md", "t")
    mata: _v2s_in(`""NA""', 1)
    use s1, clear
    quietly count if variable == "age" & missing == .s & missing_pct == .s
    assert r(N) == 1
    quietly count if variable == "edu" & missing == 148
    assert r(N) == 1
    * the date rows carry no extreme
    quietly count if inlist(variable, "dob", "admit") & !missing(min, max)
    assert r(N) == 0
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: S1 datamap, safe leaves no identifier, date or small count (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S1 datamap, safe leaves no identifier, date or small count"
}

**# S2 datamap, safe: samples() refused, config samples ignored, mincell raised
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    capture noisily datamap, safe samples(5) output(s2.md)
    assert _rc == 198
    capture confirm file s2.md
    assert _rc
    tempname fh
    file open `fh' using s2cfg.txt, write text replace
    file write `fh' "samples = 5" _n
    file close `fh'
    log using s2.log, replace text name(s2)
    datamap, safe config(s2cfg.txt) output(s2.md)
    log close s2
    mata: _v2s_slurp("s2.log", "t")
    mata: _v2s_in("note: safe ignores the config() samples key", 1)
    mata: _v2s_slurp("s2.md", "t")
    mata: _v2s_in("Sample", 0)
    mata: _v2s_leaks()
    assert "`leaks'" == ""
    log using s2b.log, replace text name(s2)
    datamap, safe mincell(2) output(s2b.md)
    local _mc = r(mincell)
    log close s2
    assert `_mc' == 5
    mata: _v2s_slurp("s2b.log", "t")
    mata: _v2s_in("note: safe raises mincell(2) to 5", 1)
    datamap, safe mincell(10) output(s2c.md)
    assert r(mincell) == 10
}
local rc = _rc
capture log close s2
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: S2 datamap, safe refuses samples() and raises mincell (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S2 datamap, safe refuses samples() and raises mincell"
}

**# S3 U2 dataprobe, safe: no leak in the log, full or brief
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    log using s3c.log, replace text name(s3)
    dataprobe, detail
    log close s3
    mata: _v2s_slurp("s3c.log", "t")
    mata: _v2s_leaks()
    display "control leaks: `leaks'"
    foreach n in pnr_value clinic_code datestr_value td_date rare_level_count age_miss_2 nonmiss_2998 lopnr_stats {
        assert strpos(" `leaks' ", " `n' ")
    }
    use person, clear
    log using s3.log, replace text name(s3)
    dataprobe, safe detail patterns
    assert r(safe) == 1 & r(maskrare) == 1 & r(mincell) == 5
    * r() is not masked: age's 2 missing values still name it
    local _mv "`r(missing_vars)'"
    local _xv "`r(excluded_vars)'"
    log close s3
    local _mw "age edu"
    assert `: list _mv === _mw'
    assert strpos(" `_xv' ", " lopnr ")
    mata: _v2s_slurp("s3.log", "t")
    mata: _v2s_leaks()
    display "safe leaks: [`leaks']"
    assert "`leaks'" == ""
    mata: _v2s_in("note: safe excludes likely identifier(s): lopnr", 1)
    mata: _v2s_in("p1=[withheld]  p99=[withheld]", 1)
    mata: _v2s_in("levels withheld (safe: more than maxcat() distinct values)", 1)
    mata: _v2s_in("levels withheld (safe: text holding a digit)", 1)
    * digit-free text is still listed
    mata: _v2s_in("North", 1)
    * the identifier it excluded is still the inferred key
    mata: _v2s_in("key (lopnr):", 1)
    use person, clear
    log using s3b.log, replace text name(s3)
    dataprobe, safe brief
    log close s3
    mata: _v2s_slurp("s3b.log", "t")
    mata: _v2s_leaks()
    assert "`leaks'" == ""
    mata: _v2s_in("levels withheld (safe: text holding a digit)", 1)
}
local rc = _rc
capture log close s3
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: S3 dataprobe, safe leaves no identifier, date or small count (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S3 dataprobe, safe leaves no identifier, date or small count"
}

**# S4 dataprobe, safe saving(): the written rows carry the printed masks
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    quietly dataprobe, saving(s4c.dta, replace)
    use s4c, clear
    quietly count if variable == "age" & missing == 2
    assert r(N) == 1
    use person, clear
    capture frame drop s4f
    quietly dataprobe, safe saving(s4.dta, replace)
    quietly dataprobe, safe saving(s4f)
    foreach src in file frame {
        if "`src'" == "file" use s4, clear
        else {
            frame s4f: tempfile s4ff
            frame s4f: quietly save `s4ff'
            use `s4ff', clear
        }
        * the excluded identifier: no count and no statistic
        quietly count if variable == "lopnr" & missing(missing, unique, mean, sd, p50, min, max)
        assert r(N) == 1
        quietly count if variable == "lopnr" & missing == .s
        assert r(N) == 1
        quietly count if variable == "age" & missing == .s & missing_pct == .s
        assert r(N) == 1
        * no extreme anywhere; no statistic of a date
        quietly count if !missing(min) | !missing(max)
        assert r(N) == 0
        quietly count if inlist(variable, "dob", "admit") & (!missing(mean) | !missing(p50))
        assert r(N) == 0
        * a statistic the console prints is written
        quietly count if variable == "sex" & mean == 1.5
        assert r(N) == 1
        quietly count if variable == "edu" & missing == 148
        assert r(N) == 1
        export delimited using s4_`src'.csv, replace quote
        mata: _v2s_slurp("s4_`src'.csv", "t")
        mata: _v2s_leaks()
        assert "`leaks'" == ""
    }
    * a masked baseline is read: the masked statistics are not compared
    use person, clear
    quietly dataprobe, safe compare(s4.dta)
    assert r(compare_changed) == 0
    capture frame drop s4f
}
local rc = _rc
capture frame drop s4f
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: S4 dataprobe, safe saving() writes the printed masks (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S4 dataprobe, safe saving() writes the printed masks"
}

**# S5 dataprobe, safe refusals stop before any profile output
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    foreach c in "makespec(s5.dta)" "makespec(s5.do)" "nomaskrare" "by(clinic)" "by(lopnr)" "by(dob)" "over(datestr)" {
        log using s5.log, replace text name(s5)
        capture noisily dataprobe, safe `c'
        local rc5 = _rc
        log close s5
        display "`c' -> rc `rc5'"
        assert `rc5' == 198
        mata: _v2s_slurp("s5.log", "t")
        mata: _v2s_in("QUICK REFERENCE", 0)
    }
    capture confirm file s5.dta
    assert _rc
    * a digit-free by() variable is allowed
    quietly dataprobe, safe by(region) gatesonly expectn(1 5000)
}
local rc = _rc
capture log close s5
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: S5 dataprobe, safe refusals (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S5 dataprobe, safe refusals"
}

**# S6 U2 datamvp, safe
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    quietly datamvp, save(s6c.dta)
    use s6c, clear
    quietly count if freq < 5
    assert !missing(r(N)) & r(N) > 0
    use person, clear
    log using s6.log, replace text name(s6)
    datamvp, safe save(s6.dta) percent
    assert r(maskrare) == 1 & r(mincell) == 5
    log close s6
    mata: _v2s_slurp("s6.log", "t")
    mata: _v2s_in("note: safe excludes likely identifier(s): lopnr", 1)
    mata: _v2s_leaks()
    assert "`leaks'" == ""
    use s6, clear
    quietly count if freq < 5
    assert r(N) == 0
    capture confirm variable cumpct
    assert _rc
    quietly summarize freq
    * the rows left out are 0 or 5 or more
    local _left = 3000 - r(sum)
    assert !missing(`_left') & (`_left' == 0 | `_left' >= 5)
    use person, clear
    capture noisily datamvp age edu, safe bytable(clinic)
    assert _rc == 198
    sort lopnr
    capture noisily by lopnr: datamvp age edu, safe
    assert _rc == 198
    capture noisily datamvp lopnr, safe
    assert _rc == 102
}
local rc = _rc
capture log close s6
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: S6 datamvp, safe (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S6 datamvp, safe"
}

**# S7 dataqa set agent: the session preset
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    dataqa set agent
    assert "`r(defaults)'" == "safe"
    assert `"$DATAMAP_DQ"' == "safe"
    log using s7.log, replace text name(s7)
    dataprobe
    assert r(safe) == 1 & r(maskrare) == 1
    datamap, output(s7.md)
    assert r(safe) == 1
    datamvp
    assert r(maskrare) == 1
    log close s7
    mata: _v2s_slurp("s7.log", "t")
    mata: _v2s_leaks()
    assert "`leaks'" == ""
    mata: _v2s_slurp("s7.md", "t")
    mata: _v2s_leaks()
    assert "`leaks'" == ""
    * nomaskrare cannot turn the session preset off
    capture noisily dataprobe, nomaskrare
    assert _rc == 198
    capture noisily datamvp age, nomaskrare
    assert _rc == 198
    dataqa set agent mincell(10)
    quietly dataprobe
    assert r(mincell) == 10
    dataqa set clear
    quietly dataprobe
    assert r(safe) == 0
    quietly datamap, output(s7b.md)
    assert r(safe) == 0
}
local rc = _rc
capture log close s7
macro drop DATAMAP_DQ
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: S7 dataqa set agent (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S7 dataqa set agent"
}

**# S8 U1 dataprobe, brief
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    local nv = c(k)
    foreach m in "" "maskrare" "onlyflagged" "maskrare id(lopnr) isid(lopnr)" {
        quietly dataprobe, `m'
        mata: _v2s_rsnap("full")
        log using s8.log, replace text name(s8)
        dataprobe, brief `m'
        mata: _v2s_rsnap("brf")
        log close s8
        if `"`full'"' != `"`brf'"' {
            display as error "r() differs under `m'"
            display `"full: `full'"'
            display `"brief: `brf'"'
            exit 9
        }
        mata: _v2s_slurp("s8.log", "t")
        mata: _v2s_lines("dataprobe:")
        display "`m': `nlines' lines for `nv' variables"
        assert `nlines' <= `nv' + 8
        * no text level printed (pnr_str: count 1 each), no empty header
        mata: _v2s_in("P100", 0)
        mata: _v2s_in("STRING", 0)
        mata: _v2s_in("DATE", 0)
        if "`m'" != "onlyflagged" mata: _v2s_in("all distinct, maxlen 7", 1)
    }
    * flagged first: the first variable line is a flagged variable
    use person, clear
    log using s8.log, replace text name(s8)
    dataprobe, brief
    local fl "`r(flagged_vars)'"
    log close s8
    mata: _v2s_slurp("s8.log", "t")
    mata: st_local("first", tokens(substr(st_local("t"), strpos(st_local("t"), "Levels" + char(10)) + 7, 60))[1])
    display "first line: `first'; flagged: `fl'"
    assert strpos(" `fl' ", " `first' ")
    * the top five levels of a categorical, with counts; under maskrare the
    * rare level and the complement that would give it back are not listed
    mata: _v2s_in("1 Male 1,500; 2 Female 1,500", 1)
    use person, clear
    log using s8.log, replace text name(s8)
    dataprobe grp, brief mincell(5) maskrare
    log close s8
    mata: _v2s_slurp("s8.log", "t")
    mata: _v2s_in("1 A 999; 2 B 999; +2 more", 1)
    mata: _v2s_in("RARENINE", 0)
}
local rc = _rc
capture log close s8
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: S8 dataprobe, brief (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S8 dataprobe, brief"
}

**# S9 brief refusals
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    foreach c in gatesonly patterns "by(region) byfreq" {
        capture noisily dataprobe, brief `c'
        assert _rc == 198
    }
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: S9 brief refusals (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S9 brief refusals"
}

**# S10 one identifier rule
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    gen paid = 1
    gen subject_no = 1
    quietly datamap, output(s10.md)
    local sugg "`r(suggested_exclude)'"
    quietly ds
    _datamap_idnames `r(varlist)'
    local _in "`r(names)'"
    assert `: list _in === sugg'
    assert "`r(names)'" == "lopnr paid subject_no"
    quietly dataprobe, safe
    local _ev "`r(excluded_vars)'"
    local _ew "lopnr paid subject_no"
    assert `: list _ev === _ew'
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: S10 one identifier rule (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S10 one identifier rule"
}

**# S11 dataprobe, safe: a date's mean or percentile in a gate is withheld
* 2026-11-10 (Phase 4 review fix): stat() and groupstat() printed a date's
* mean and median as dates (1969-11) under safe and the ledger kept the day
* number, while the DATE block withheld p1 and p99.  Each control run shows
* the needle is reachable.
capture noisily {
    quietly cd "`work'/run"
    use person, clear
    capture erase s11led.dta
    capture log close s11
    log using s11.log, replace text name(s11)
    capture noisily dataprobe, safe gatesonly stat(mean dob 0 100 \ p50 dob 0 100 \ n dob 0 10) ///
        ledger(s11led.dta, run(s11))
    capture noisily dataprobe, safe gatesonly groupstat(median dob, by(sex) band(0 10))
    capture noisily dataprobe, safe gatesonly groupstat(mean median n: dob, by(sex))
    log close s11
    capture log close s11
    log using s11c.log, replace text name(s11)
    capture noisily dataprobe, maskrare gatesonly stat(mean dob 0 100) groupstat(median dob, by(sex))
    log close s11
    mata: _v2s_slurp("s11c.log", "t")
    mata: assert(ustrregexm(st_local("t"), "(19|20)[0-9][0-9]-[01][0-9]"))
    mata: _v2s_slurp("s11.log", "t")
    mata: assert(!ustrregexm(st_local("t"), "(19|20)[0-9][0-9]-[01][0-9]"))
    mata: _v2s_in("stat(mean dob): [withheld], expected [0, 100]", 1)
    mata: _v2s_in("stat(median dob): [withheld], expected [0, 100]", 1)
    * a count of a date variable is not a date: it still prints
    mata: _v2s_in("stat(n dob): 3000, expected [0, 10]", 1)
    mata: _v2s_in("groupstat(median dob): median [withheld] in group Male", 1)
    mata: _v2s_in("  pooled                     [withheld]", 1)
    mata: _v2s_in("  Male              [withh.]  [withh.]      1500", 1)
    use s11led, clear
    quietly count if strpos(label, "dob") & inlist(label, "mean dob", "median dob")
    assert r(N) == 2
    quietly count if inlist(label, "mean dob", "median dob") & ///
        (!missing(observed_num) | strpos(observed, "[withheld]") == 0)
    assert r(N) == 0
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: S11 safe withholds a date's mean or percentile in gates (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S11 safe withholds a date's mean or percentile in gates"
}

**# S12 U2 the sweep: no count of 1 to 4 in any output of the four commands
* A second fixture with a small cell of every size from 1 to 4 in a labelled
* categorical (labels TINYONE .. TINYFOURB), in the missing count of four
* variables (5, 3, 4 and 1; 3 and 4 of them reachable through N=), in five
* missing-value patterns (3, 1, 4, 2 and 1 rows) and an identifier string.  The
* truths are counted from the data here, not read back from a command.  Each
* command is run without safe first (every needle kind must show up in the
* control), then with safe, then under the dataqa set agent preset, and every
* log and every written file (the .dta files through export delimited) is
* scanned.
capture program drop _v2s_sweep
program define _v2s_sweep
    clear
    set seed 20261111
    quietly set obs 4000
    gen long lopnr = _n
    gen str9 person_key = "ZQ" + string(1000000 + _n)
    gen byte lev = 1
    quietly replace lev = 2 in 1501/2990
    quietly replace lev = 3 in 2991/3986
    quietly replace lev = 4 in 3987
    quietly replace lev = 5 in 3988/3989
    quietly replace lev = 6 in 3990/3992
    quietly replace lev = 7 in 3993/3996
    quietly replace lev = 8 in 3997/4000
    label define sweepl 1 "BIGAAA" 2 "BIGBBB" 3 "BIGCCC" 4 "TINYONE" 5 "TINYTWO" ///
        6 "TINYTHREE" 7 "TINYFOUR" 8 "TINYFOURB"
    label values lev sweepl
    forvalues i = 1/4 {
        gen double m`i' = rnormal()
    }
    quietly replace m1 = . in 1/3
    quietly replace m2 = . in 10
    quietly replace m3 = . in 20/23
    quietly replace m1 = . in 100/101
    quietly replace m2 = . in 100/101
    quietly replace m4 = . in 300
    gen byte sex = mod(_n, 2)
end
capture noisily {
    quietly cd "`work'/run"
    _v2s_sweep
    quietly save sweep, replace
    * the truths, counted here
    local small ""
    forvalues i = 1/4 {
        quietly count if missing(m`i')
        local mc`i' = r(N)
        if inrange(`mc`i'', 1, 4) local small "`small' m`i'"
    }
    assert `mc1' == 5 & `mc2' == 3 & `mc3' == 4 & `mc4' == 1
    quietly count if lev >= 4 & lev <= 8
    assert r(N) == 14
    forvalues v = 4/8 {
        quietly count if lev == `v'
        assert inrange(r(N), 1, 4)
    }
    quietly count if missing(m1) | missing(m2) | missing(m3) | missing(m4)
    assert r(N) == 11

    * control: without safe every kind of leak is there to be found
    use sweep, clear
    quietly datamap, output(sw_c.md) samples(5) missing(pattern) mincell(0) saving(sw_c, replace csv)
    foreach f in sw_c.md sw_c.csv {
        mata: _v2s_slurp("`f'", "t")
        mata: _v2s_cells()
        display "control `f': `leaks'"
        if "`f'" == "sw_c.md" {
            foreach n in level_count missing_count n_complement pattern_count id_value {
                assert strpos(" `leaks' ", " `n' ")
            }
        }
    }
    capture log close s12
    log using sw_cdp.log, replace text name(s12)
    dataprobe, detail patterns
    log close s12
    mata: _v2s_slurp("sw_cdp.log", "t")
    mata: _v2s_cells()
    display "control dataprobe: `leaks'"
    foreach n in level_count missing_count n_complement pattern_count {
        assert strpos(" `leaks' ", " `n' ")
    }
    log using sw_cmvp.log, replace text name(s12)
    datamvp m1 m2 m3 m4
    log close s12
    mata: _v2s_slurp("sw_cmvp.log", "t")
    mata: _v2s_cells()
    display "control datamvp: `leaks'"
    foreach n in missing_count n_complement pattern_count {
        assert strpos(" `leaks' ", " `n' ")
    }

    * safe, each command by its option and then by the session preset
    foreach mode in option preset {
        use sweep, clear
        if "`mode'" == "preset" dataqa set agent
        local so = cond("`mode'" == "option", "safe", "")
        capture log close s12
        log using sw_`mode'.log, replace text name(s12)
        datamap, `so' output(sw_`mode'.md) missing(pattern) quality saving(sw_`mode', replace csv)
        dataprobe, `so' detail patterns saving(sw_dp_`mode'.dta, replace)
        dataprobe, `so' brief
        datamvp m1 m2 m3 m4, `so' save(sw_mvp_`mode'.dta)
        local mr = r(maskrare)
        log close s12
        assert `mr' == 1
        * every log and written file
        use sw_dp_`mode', clear
        export delimited using sw_dp_`mode'.csv, replace quote
        use sw_mvp_`mode', clear
        export delimited using sw_mvp_`mode'.csv, replace quote
        use sw_`mode', clear
        export delimited using sw_dm_`mode'.csv, replace quote
        foreach f in sw_`mode'.log sw_`mode'.md sw_`mode'.csv sw_dp_`mode'.csv sw_mvp_`mode'.csv sw_dm_`mode'.csv {
            mata: _v2s_slurp("`f'", "t")
            mata: _v2s_cells()
            display "safe (`mode') `f': [`leaks']"
            assert "`leaks'" == ""
        }
        * not over-masked: the big levels and the missing count of 5 print
        mata: _v2s_slurp("sw_`mode'.md", "t")
        mata: _v2s_in("1 BIGAAA: 1500", 1)
        mata: _v2s_in("| `m1` |  | double | 5 (0.1%)", 1)
        * 2026-11-10 (Phase 6 fix): under safe a level below mincell() is
        * no longer named (dataprobe's maskrare [suppressed] rule); the rare
        * levels stay visible as one suppressed item, never dropped silently
        mata: _v2s_in("TINYONE", 0)
        mata: _v2s_in("other values: suppressed (<5 each)", 1)
        * the saving() rows carry no small count: missing is .s where the
        * truth is 1 to 4, and the truth where it is 5 or more
        use sw_`mode', clear
        quietly count if variable == "m1" & missing == `mc1'
        assert r(N) == 1
        foreach v in `small' {
            quietly count if variable == "`v'" & missing == .s
            assert r(N) == 1
        }
        * datamvp's pattern file: no pattern below 5 and no cumulative percent
        use sw_mvp_`mode', clear
        quietly count if freq < 5
        assert r(N) == 0
        capture confirm variable cumpct
        assert _rc
        * dataprobe's rows: the same, and the csv of datamap's rows says .s
        use sw_dp_`mode', clear
        foreach v in `small' {
            quietly count if variable == "`v'" & missing == .s
            assert r(N) == 1
        }
        quietly count if variable == "m1" & missing == `mc1'
        assert r(N) == 1
        quietly import delimited using sw_`mode'.csv, clear stringcols(_all)
        foreach v in `small' {
            quietly count if variable == "`v'" & missing == ".s" & missing_pct == ".s"
            assert r(N) == 1
        }
        if "`mode'" == "preset" dataqa set clear
    }
}
local rc = _rc
capture log close s12
macro drop DATAMAP_DQ
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: S12 safe sweep leaves no count of 1 to 4 in four commands (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S12 safe sweep leaves no count of 1 to 4 in four commands"
}

**# S13 datamap, safe: a rare numeric level is not named
* 2026-11-10 (Phase 6 review fix): under safe the exact value of every
* numeric level below mincell() was printed beside "suppressed (<5)" (a
* sparse continuous variable's seven singletons, to 16 digits); dataprobe
* safe prints [suppressed] for the same cells and datamap safe already
* pooled rare text levels.  The 1.10.6 rendering stays without safe.
capture noisily {
    quietly cd "`work'/run"
    sysuse auto, clear
    set seed 13
    generate double z = runiform() in 1/7
    local z1 = strofreal(z[1], "%18.0g")
    datamap mpg rep78 z, safe output(s13.md)
    mata: _v2s_slurp("s13.md", "t")
    mata: _v2s_in("| `z` |  | double | 67 (90.5%) | all values: suppressed (<5 each) |", 1)
    mata: _v2s_in("14: 6 (8.1%)", 1)
    mata: _v2s_in("12: suppressed", 0)
    mata: _v2s_in("<br>other values: suppressed (<5 each) |", 1)
    mata: _v2s_in("2: suppressed (complementary)", 1)
    mata: _v2s_in(substr(st_local("z1"), 1, 8), 0)
    * mincell(8): the count in the text follows it
    datamap mpg, safe mincell(8) output(s13b.md)
    mata: _v2s_slurp("s13b.md", "t")
    mata: _v2s_in("other values: suppressed (<8 each)", 1)
    mata: _v2s_in("14: suppressed", 0)
    * without safe: named, count suppressed (unchanged)
    datamap mpg z, output(s13c.md)
    mata: _v2s_slurp("s13c.md", "t")
    mata: _v2s_in("12: suppressed (<5)", 1)
    mata: _v2s_in("other values", 0)
    mata: _v2s_in(substr(st_local("z1"), 1, 8), 1)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: S13 datamap, safe: a rare numeric level is not named (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S13 datamap, safe: a rare numeric level is not named"
}

macro drop DATAMAP_DQ
sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_datamap_v200_safe tests=`tests' pass=`pass' fail=`fail'"
log close main
if `fail' exit 1
