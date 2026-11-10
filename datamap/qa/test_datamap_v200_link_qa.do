*! test_datamap_v200_link_qa.do Version 1.0.0  2026/11/10
*! datamap 2.0.0 Phase 3 QA, part 2: U5, F5, F1 and I2 against the plan's
*! acceptance tests, the privacy cross-checks of the new sections, and the pins
*! on the duplicated Mata helpers
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Companion of test_datamap_v200_link.do (the developers' suite) and part 1,
* test_datamap_v200_content_qa.do (F2, F3, U4, F4).
*
*   R1  U5: exclude(auto) removes exactly r(suggested_exclude) of the same
*       data (metamorphic oracle), nothing when nothing is suggested, beside
*       names and a varlist, in filelist mode; no value of an excluded
*       identifier reaches the document or saving()
*   R2  F5: the run-date boundary in every period family (strictly after, by
*       period; oracle count if), the declared list, a genuine 99-year-old
*       and a 999 that nobody declared are not flagged, nothing without
*       quality
*   R3  F1: the implied merge type of every pair of 2-4 files equals the type
*       an actual -merge- accepts (master first); numeric vs string is the
*       merge's rc 106; value-label definitions: a subset, a case change, an
*       identical label (not listed), a label in one file (not listed)
*   R4  I2: the csv read raw: header equals the column list, one line per
*       variable, a hostile label quoted as RFC 4180 says, no csv without the
*       suboption, a stale csv untouched without csv
*   R5  privacy fuzz: 8 random datasets (numeric text with tokens, padded
*       values, few-valued text, numeric and date candidates) at mincell 5 and
*       3: no printed count in 1..mincell-1 in the table rows, none in saving()
*       numeric_n, padded_n or candidates; a lone small token never leaves its
*       count derivable from a printed numeric-text count
*   R6  an excluded variable's values, labels, tokens and candidate dates
*       appear nowhere (document, saving(), csv) under quality, placeholders(),
*       missing(pattern), samples() and a second dataset
*   R7  the Mata escape, percent and date-format copies agree (source text, and
*       one hostile string through every new path); DATEOPT() and sumframe()
*       are gone
* Documents are read through Mata (_vr_slurp), never a Stata macro reader.
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_datamap_v200_link_qa.log", replace text name(main)
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
local work "`base'_v200rwork"
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

capture mata: mata drop _vr_slurp()
capture mata: mata drop _vr_in()
capture mata: mata drop _vr_line()
capture mata: mata drop _vr_occ()
capture mata: mata drop _vr_section()
capture mata: mata drop _vr_die()
capture mata: mata drop _vr_split()
capture mata: mata drop _vr_counts()
capture mata: mata drop _vr_fbody()
capture mata: mata drop _vr_syntax()
mata:
// the text of the first -syntax- command of an ado file, continuation lines
// joined
string scalar _vr_syntax(string scalar path)
{
	string colvector L
	string scalar r
	real scalar i, on
	L = cat(path)
	r = ""
	on = 0
	for (i = 1; i <= rows(L); i++) {
		if (!on & regexm(L[i], "^ *syntax ")) on = 1
		if (on) {
			r = r + " " + L[i]
			if (!regexm(L[i], "///[ ]*$")) return(r)
		}
	}
	return("")
}
void _vr_die(string scalar msg)
{
	errprintf("%s", msg)
	exit(9)
}
void _vr_slurp(string scalar path, string scalar dst)
{
	real scalar fh
	string scalar s, l
	fh = fopen(path, "r")
	s = ""
	while ((l = fget(fh)) != J(0, 0, "")) s = s + l + char(10)
	fclose(fh)
	st_local(dst, s)
}
// local t holds needle ({bq} = a backtick) when want is 1, does not when 0
void _vr_in(string scalar needle, real scalar want)
{
	real scalar has
	has = (strpos(st_local("t"), subinstr(needle, "{bq}", char(96))) > 0)
	if (has != want) _vr_die(sprintf("text check failed (want %g): %s\n", want, needle))
}
// local t has a whole line equal to needle ({bq} = a backtick)
void _vr_line(string scalar needle)
{
	if (!strpos(char(10) + st_local("t"), char(10) + subinstr(needle, "{bq}", char(96)) + char(10))) {
		_vr_die(sprintf("line not found: %s\n", needle))
	}
}
real scalar _vr_occ(string scalar needle)
{
	string scalar t
	real scalar n, j
	t = st_local("t")
	n = 0
	while ((j = strpos(t, needle)) > 0) {
		n++
		t = substr(t, j + strlen(needle), .)
	}
	return(n)
}
// local t cut to the text from the line "heading" to the next "## " heading
void _vr_section(string scalar heading)
{
	string scalar t
	real scalar a, b
	t = char(10) + st_local("t")
	a = strpos(t, char(10) + heading + char(10))
	if (a == 0) _vr_die(sprintf("section not found: %s\n", heading))
	t = substr(t, a + 1, .)
	b = strpos(substr(t, 2, .), char(10) + "## ")
	if (b > 0) t = substr(t, 1, b + 1)
	st_local("t", t)
}
string rowvector _vr_split(string scalar s, string scalar sep)
{
	string rowvector r
	real scalar j
	r = J(1, 0, "")
	while ((j = strpos(s, sep)) > 0) {
		r = r, substr(s, 1, j - 1)
		s = substr(s, j + strlen(sep), .)
	}
	return(r, s)
}
// the counts local t prints in its variable-table rows: "n (p%)" pairs, a
// quoted token's count, "leading or trailing spaces n" and "n rows".  Sets
// local _min to the smallest nonzero one and _n to how many were found.
void _vr_counts()
{
	string scalar t, ln, rest
	string rowvector pat
	real scalar mn, n, x, k
	t = st_local("t")
	mn = .
	n = 0
	pat = ("([0-9]+) [(][0-9]+[.][0-9][%][)]",
		char(34) + " ([0-9]+)(,|;| [|])",
		"([0-9]+) rows?",
		"leading or trailing spaces ([0-9]+)")
	while (strpos(t, char(10))) {
		ln = substr(t, 1, strpos(t, char(10)) - 1)
		t = substr(t, strpos(t, char(10)) + 1, .)
		if (substr(ln, 1, 3) != "| " + char(96) & substr(ln, 1, 3) != "- " + char(96)) continue
		for (k = 1; k <= cols(pat); k++) {
			rest = ln
			while (regexm(rest, pat[k])) {
				x = strtoreal(regexs(1))
				rest = substr(rest, strpos(rest, regexs(0)) + strlen(regexs(0)) - 1, .)
				n++
				if (x > 0 & x < mn) mn = x
			}
		}
	}
	st_local("_min", strofreal(mn))
	st_local("_n", strofreal(n))
}
// the body of Mata function name in file path with the prefix after the
// leading underscore removed, comment lines and indentation dropped
string scalar _vr_fbody(string scalar path, string scalar name)
{
	string colvector L
	string scalar b, ln
	real scalar i, on
	L = cat(path)
	b = ""
	on = 0
	for (i = 1; i <= rows(L); i++) {
		if (!on & regexm(L[i], "^(string|real|void) (scalar|rowvector|colvector|matrix) " + name + "[(]")) on = 1
		if (on) {
			ln = strtrim(subinstr(L[i], char(9), " ", .))
			if (substr(ln, 1, 2) != "//" & ln != "") {
				ln = subinstr(ln, name, "_X_F", .)
				b = b + ln + char(10)
			}
			if (L[i] == "}") return(b)
		}
	}
	return("")
}
end

**# R1 U5: exclude(auto) is exactly r(suggested_exclude)

capture noisily {
    quietly cd "`work'/run"
    * four fixtures: identifiers of several shapes, one identifier, none, an
    * identifier-like string
    forvalues f = 1/4 {
        clear
        quietly set obs 400
        generate int age = 20 + mod(_n, 60)
        generate byte sex = 1 + mod(_n, 2)
        generate double bmi = 20 + mod(_n, 17) / 2
        * the name pattern is the classifier's (id$, _id$, ^id_, patient,
        * subject, person, lopnr, identifier): lopnr and patient_id match,
        * pnr does not and stays a visible variable
        if `f' == 1 {
            generate long lopnr = 9100000 + _n
            generate long patient_id = 500000 + _n
            generate str12 pnr = "19" + string(500000 + _n, "%8.0f") + "-0000"
        }
        if `f' == 2 generate long lopnr = 9100000 + _n
        if `f' == 4 generate str12 person_ref = "PX" + string(70000000 + _n, "%8.0f")
        quietly datamap, output(r1p.md)
        local sug "`r(suggested_exclude)'"
        quietly datamap, output(r1a.md) exclude(auto) saving(r1a, replace)
        local ex "`r(excluded_vars)'"
        local a : list sug - ex
        local b : list ex - sug
        assert "`a'" == "" & "`b'" == ""
        assert "`r(suggested_exclude)'" == ""
        * the identifiers are the intended ones, and only they
        if `f' == 1 assert "`ex'" == "lopnr patient_id"
        if `f' == 2 assert "`ex'" == "lopnr"
        if `f' == 3 assert "`ex'" == "" & "`sug'" == ""
        if `f' == 4 assert "`ex'" == "person_ref"
        assert strpos(" `ex' ", " age ") == 0 & strpos(" `ex' ", " sex ") == 0 & strpos(" `ex' ", " bmi ") == 0
        * no value of an excluded variable in the document or in saving()
        mata: _vr_slurp("r1a.md", "t")
        mata: _vr_in("9100001", 0)
        mata: _vr_in("9100400", 0)
        mata: _vr_in("500001", 0)
        mata: _vr_in("PX70000001", 0)
        mata: _vr_in("70000400", 0)
        foreach v of local ex {
            mata: _vr_in("| {bq}`v'{bq} | ", 1)
            mata: _vr_in("excluded (structure only)", 1)
        }
        if "`ex'" == "" mata: _vr_in("Disclosure: 0 excluded", 1)
        use r1a, clear
        foreach v of local ex {
            quietly count if variable == "`v'" & class == "excluded" & missing(mean) & missing(sd) & missing(p50) & missing(min) & missing(max) & missing(unique)
            assert r(N) == 1
        }
        * the others keep their statistics
        quietly count if variable == "age" & !missing(mean, min, max)
        assert r(N) == 1
    }
    * beside names and with a varlist: the identifier outside the varlist is
    * not in the document at all; names given beside auto are withheld too
    clear
    quietly set obs 400
    generate int age = 20 + mod(_n, 60)
    generate byte sex = 1 + mod(_n, 2)
    generate long lopnr = 9100000 + _n
    quietly datamap age sex, output(r1b.md) exclude(auto)
    mata: _vr_slurp("r1b.md", "t")
    mata: _vr_in("{bq}lopnr{bq}", 0)
    mata: _vr_in("9100001", 0)
    * (r(excluded_vars) lists the excluded names inside the varlist, as for
    * an explicit exclude(): sex is outside this varlist)
    quietly datamap lopnr age, output(r1c.md) exclude(auto sex)
    assert "`r(excluded_vars)'" == "lopnr"
    quietly datamap lopnr age sex, output(r1c.md) exclude(auto sex)
    assert "`r(excluded_vars)'" == "lopnr sex"
    mata: _vr_slurp("r1c.md", "t")
    mata: _vr_in("9100001", 0)
    * filelist mode: each file's identifier is withheld in its own section
    quietly save r1x, replace
    replace lopnr = lopnr + 1000000
    generate str12 subject_no = "P" + string(_n + 7000)
    quietly save r1y, replace
    quietly datamap, filelist(r1x r1y) output(r1d.md) exclude(auto)
    mata: _vr_slurp("r1d.md", "t")
    mata: _vr_in("9100001", 0)
    mata: _vr_in("10100001", 0)
    mata: _vr_in("P7001", 0)
    mata: assert(_vr_occ("excluded (structure only)") == 3)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R1 exclude(auto) (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R1 exclude(auto)"'
}

**# R2 F5: run-date boundary in every period, declared list, undeclared values

capture noisily {
    quietly cd "`work'/run"
    local attempt = 0
    local done = 0
    while !`done' & `attempt' < 2 {
        local ++attempt
        local t0 = date(c(current_date), "DMY")
        clear
        quietly set obs 80
        * %td: 10 yesterday, 10 today, 7 tomorrow, 8 far future
        generate long d = `t0' - 400 + _n
        quietly replace d = `t0' - 1 in 1/10
        quietly replace d = `t0' in 11/20
        quietly replace d = `t0' + 1 in 21/27
        quietly replace d = `t0' + 400 in 28/35
        format d %td
        * %tm: 9 this month, 6 next month
        generate int mo = mofd(`t0') - 30 + mod(_n, 5)
        quietly replace mo = mofd(`t0') in 1/9
        quietly replace mo = mofd(`t0') + 1 in 10/15
        format mo %tm
        * %ty: 8 this year, 5 next year
        generate int yr = year(`t0') - 20 + mod(_n, 7)
        quietly replace yr = year(`t0') in 1/8
        quietly replace yr = year(`t0') + 1 in 9/13
        format yr %ty
        * %tq: 7 this quarter, 9 next quarter
        generate int qt = qofd(`t0') - 20 + mod(_n, 6)
        quietly replace qt = qofd(`t0') in 1/7
        quietly replace qt = qofd(`t0') + 1 in 8/16
        format qt %tq
        * %tc: 6 yesterday noon, 11 tomorrow noon
        generate double tc = cofd(`t0' - 100 + _n)
        quietly replace tc = cofd(`t0' - 1) + 12 * 3600000 in 1/6
        quietly replace tc = cofd(`t0' + 1) + 12 * 3600000 in 7/17
        format tc %tc
        * a variable with only past dates
        generate long past = `t0' - 1000 + _n
        format past %td
        * undeclared numerics: a 999, a 99 beside ordinary ages
        generate double bmi = 20 + mod(_n, 11)
        quietly replace bmi = 999 in 1/12
        generate int age = 20 + mod(_n, 70)
        quietly replace age = 99 in 1/9
        local n_d = 15
        quietly count if d > `t0'
        assert r(N) == `n_d'
        quietly count if mo > mofd(`t0')
        local n_mo = r(N)
        quietly count if yr > year(`t0')
        local n_yr = r(N)
        quietly count if qt > qofd(`t0')
        local n_qt = r(N)
        quietly count if tc > cofd(`t0' + 1)
        local n_tc = r(N)
        assert `n_mo' == 6 & `n_yr' == 5 & `n_qt' == 9 & `n_tc' == 11
        local rd = strtrim(string(`t0', "%tdCCYY/NN/DD"))
        quietly datamap, output(r2a.md) quality mincell(0)
        local t1 = date(c(current_date), "DMY")
        if `t1' == `t0' local done = 1
    }
    assert `done'
    mata: _vr_slurp("r2a.md", "t")
    mata: _vr_section("### Candidates (not applied)")
    mata: _vr_line("- {bq}d{bq}: after `rd' (run date): `n_d' rows")
    mata: _vr_line("- {bq}mo{bq}: after `rd' (run date): `n_mo' rows")
    mata: _vr_line("- {bq}yr{bq}: after `rd' (run date): `n_yr' rows")
    mata: _vr_line("- {bq}qt{bq}: after `rd' (run date): `n_qt' rows")
    mata: _vr_line("- {bq}tc{bq}: after `rd' (run date): `n_tc' rows")
    * a variable with only past dates, and the undeclared 999 and 99, are not
    * candidates: no numeric rule set ships (the F5 literature check found
    * none to cite; 2026-11-10), only the declared list
    mata: _vr_in("{bq}past{bq}", 0)
    mata: _vr_in("{bq}bmi{bq}", 0)
    mata: _vr_in("{bq}age{bq}", 0)
    * the declared list: 999 for bmi (12 rows) and 99 for age (9 rows), and a
    * genuine 99 stays unflagged in a run that declares only 999
    quietly count if bmi == 999
    local n999 = r(N)
    quietly count if age == 99
    local n99 = r(N)
    assert `n999' == 12 & `n99' == 9
    quietly datamap, output(r2b.md) quality mincell(0) placeholders(999)
    mata: _vr_slurp("r2b.md", "t")
    mata: _vr_in("- {bq}bmi{bq}: 999: `n999' rows", 1)
    mata: _vr_in("{bq}age{bq}: ", 0)
    quietly datamap, output(r2c.md) quality mincell(0) placeholders(999 99)
    mata: _vr_slurp("r2c.md", "t")
    mata: _vr_in("- {bq}bmi{bq}: 999: `n999' rows", 1)
    mata: _vr_in("- {bq}age{bq}: 99: `n99' rows", 1)
    * the same data without quality: no candidates, no run-date lines
    quietly datamap, output(r2d.md) mincell(0)
    mata: _vr_slurp("r2d.md", "t")
    mata: _vr_in("Candidates", 0)
    mata: _vr_in("run date", 0)
    * declared negative codes
    quietly replace bmi = -9 in 13/19
    quietly replace bmi = -99 in 20/24
    quietly datamap, output(r2e.md) quality mincell(0) placeholders(-9 -99)
    mata: _vr_slurp("r2e.md", "t")
    mata: _vr_in("-9: 7 rows", 1)
    mata: _vr_in("-99: 5 rows", 1)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R2 F5 candidates (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R2 F5 candidates"'
}

**# R3 F1: the implied merge type is the one -merge- accepts

capture noisily {
    quietly cd "`work'/run"
    * u1 unique ids 1-12; u2 the same ids in another order; u3 two rows per
    * id; u4 two rows per id; u5 an id as a string; u6 unique with one missing
    clear
    quietly set obs 12
    generate long id = _n
    generate byte g = 1 + mod(_n, 3)
    label define gl 1 "A" 2 "B" 3 "C"
    label define cl 1 "Yes" 2 "No"
    label define only1 1 "x"
    label define same 1 "p" 2 "q"
    label values g gl
    generate byte c = 1 + mod(_n, 2)
    label values c cl
    generate byte s = 1 + mod(_n, 2)
    label values s same
    quietly save u1, replace
    quietly set seed 3
    generate double r = runiform()
    sort r
    drop r
    quietly save u2, replace
    use u1, clear
    quietly expand 2
    label define gl 4 "D", add
    label define cl 1 "yes" 2 "No", replace
    quietly save u3, replace
    use u1, clear
    quietly expand 2
    label define gl 1 "A" 2 "B" 3 "C", replace
    quietly save u4, replace
    use u1, clear
    tostring id, replace
    quietly save u5, replace
    use u1, clear
    quietly replace id = . in 12
    quietly save u6, replace
    * the oracle: what -merge- accepts, master first
    local files "u1 u2 u3 u4 u5 u6"
    capture program drop _vr_implied
    program define _vr_implied, rclass
        args a b
        local res ""
        foreach ty in 1:1 1:m m:1 m:m {
            if "`res'" != "" continue
            quietly use `a', clear
            capture quietly merge `ty' id using `b', nogenerate
            if _rc == 0 local res "`ty'"
            else if _rc == 106 | _rc == 107 local res "str"
            else if _rc != 459 {
                display as error "unexpected merge rc " _rc " for `a' `b' `ty'"
                exit 9
            }
        }
        return local type "`res'"
    end
    foreach set in "u1 u2" "u1 u3" "u3 u1" "u3 u4" "u1 u2 u3" "u2 u3 u4 u6" "u1 u6 u2" {
        local n : word count `set'
        local exp ""
        forvalues i = 1/`=`n' - 1' {
            forvalues j = `=`i' + 1'/`n' {
                local a : word `i' of `set'
                local b : word `j' of `set'
                _vr_implied `a' `b'
                local exp `"`exp'`=cond("`exp'" == "", "", "; ")'`a' `r(type)' `b'"'
            }
        }
        quietly datamap, filelist(`set') output(r3.md)
        mata: _vr_slurp("r3.md", "t")
        mata: _vr_section("## Linkage")
        mata: _vr_in("| {bq}id{bq} | ", 1)
        * the id row's Merge cell is the oracle's pairs
        mata: _vr_in(" | " + st_local("exp") + " |", 1)
    }
    * a string id against a numeric one is -merge-'s rc 106, and the block says so
    _vr_implied u1 u5
    assert "`r(type)'" == "str"
    quietly datamap, filelist(u1 u5) output(r3b.md)
    mata: _vr_slurp("r3b.md", "t")
    mata: _vr_section("## Linkage")
    mata: _vr_in("cannot merge", 1)
    mata: _vr_in("type conflict: numeric in u1; string in u5", 1)
    * a width change alone is no conflict: str12 against str20
    use u5, clear
    quietly recast str20 id
    quietly save u5w, replace
    use u5, clear
    quietly recast str12 id
    quietly save u5n, replace
    quietly datamap, filelist(u5w u5n) output(r3c.md)
    mata: _vr_slurp("r3c.md", "t")
    mata: _vr_section("## Linkage")
    mata: _vr_in("type conflict", 0)
    * value labels: gl differs in u3 (an extra value), cl differs in u3 (a
    * case change), same and only1 never differ
    quietly datamap, filelist(u1 u2 u3 u4) output(r3d.md)
    mata: _vr_slurp("r3d.md", "t")
    mata: _vr_section("## Linkage")
    mata: _vr_line("- {bq}gl{bq}: 2 definitions (u1, u2, u4 | u3)")
    mata: _vr_line("- {bq}cl{bq}: 2 definitions (u1, u2, u4 | u3)")
    mata: _vr_in("{bq}same{bq}", 0)
    mata: _vr_in("{bq}only1{bq}", 0)
    quietly datamap, filelist(u1 u2 u4) output(r3e.md)
    mata: _vr_slurp("r3e.md", "t")
    mata: _vr_section("## Linkage")
    mata: _vr_line("No value label is defined differently in two datasets.")
    * five or more files: a summary, each claim checked with real merges
    use u1, clear
    quietly expand 3
    quietly save u7, replace
    use u3, clear
    quietly save u10, replace
    quietly save u11, replace
    use u1, clear
    quietly save u8, replace
    use u2, clear
    quietly save u9, replace
    * two unique files among five
    quietly datamap, filelist(u1 u2 u3 u4 u7) output(r3f.md)
    mata: _vr_slurp("r3f.md", "t")
    mata: _vr_section("## Linkage")
    mata: _vr_line("| {bq}id{bq} | all 5 | long | u1 yes; u2 yes; u3 no; u4 no; u7 no | 1:1 among u1, u2; 1:m from one of them to any other; m:m among the others |  |")
    _vr_implied u1 u2
    assert "`r(type)'" == "1:1"
    foreach u in u1 u2 {
        foreach n in u3 u4 u7 {
            _vr_implied `u' `n'
            assert "`r(type)'" == "1:m"
        }
    }
    foreach a in u3 u4 u7 {
        foreach b in u3 u4 u7 {
            if "`a'" != "`b'" {
                _vr_implied `a' `b'
                assert "`r(type)'" == "m:m"
            }
        }
    }
    * 2026-11-10 (Phase 3 repair): one unique file has no 1:1 partner (the
    * summary read "1:1 among u1"), one non-unique file no m:m partner
    quietly datamap, filelist(u1 u3 u4 u7 u10) output(r3i.md)
    mata: _vr_slurp("r3i.md", "t")
    mata: _vr_section("## Linkage")
    mata: _vr_line("| {bq}id{bq} | all 5 | long | u1 yes; u3 no; u4 no; u7 no; u10 no | 1:m from u1 to any other; m:m among the others |  |")
    mata: _vr_in("1:1 among", 0)
    foreach n in u3 u4 u7 u10 {
        _vr_implied u1 `n'
        assert "`r(type)'" == "1:m"
    }
    quietly datamap, filelist(u1 u2 u8 u9 u3) output(r3j.md)
    mata: _vr_slurp("r3j.md", "t")
    mata: _vr_section("## Linkage")
    mata: _vr_line("| {bq}id{bq} | all 5 | long | u1 yes; u2 yes; u8 yes; u9 yes; u3 no | 1:1 among u1, u2, u8, u9; 1:m from one of them to u3 |  |")
    * (g, c and s are m:m in every file: only the id summary is checked)
    mata: _vr_in("m:m among the others", 0)
    foreach u in u1 u2 u8 u9 {
        _vr_implied `u' u3
        assert "`r(type)'" == "1:m"
    }
    * all unique (a single missing key counts as a value, still unique)
    quietly datamap, filelist(u1 u2 u6 u8 u9) output(r3g.md)
    mata: _vr_slurp("r3g.md", "t")
    mata: _vr_section("## Linkage")
    mata: _vr_line("| {bq}id{bq} | all 5 | long | yes in all | 1:1 between any two |  |")
    foreach a in u1 u2 u6 u8 u9 {
        foreach b in u1 u2 u6 u8 u9 {
            if "`a'" != "`b'" {
                _vr_implied `a' `b'
                assert "`r(type)'" == "1:1"
            }
        }
    }
    * none unique
    quietly datamap, filelist(u3 u4 u7 u10 u11) output(r3h.md)
    mata: _vr_slurp("r3h.md", "t")
    mata: _vr_section("## Linkage")
    mata: _vr_line("| {bq}id{bq} | all 5 | long | no in all | m:m between any two (unique in none) |  |")
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R3 F1 linkage against merge (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R3 F1 linkage against merge"'
}

**# R4 I2: the csv read raw

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 5
    generate x = _n
    label variable x `"He said "hi", ok"'
    generate y = _n * 1.5
    label variable y "Ålder, år"
    generate str5 z = "a,b"
    capture erase r4.dta
    capture erase r4.csv
    quietly datamap, output(r4.md) saving(r4, replace csv)
    * the header line is the column list of the dta
    quietly use r4, clear
    unab cols : _all
    local nvar = c(k)
    assert `nvar' == 37 & _N == 3
    local want_header = subinstr(trim("`cols'"), " ", ",", .)
    mata: lines = cat("r4.csv")
    mata: st_local("hdr", lines[1])
    mata: st_local("nl", strofreal(rows(lines)))
    assert "`hdr'" == "`want_header'"
    * one line per variable plus the header (no embedded line breaks here)
    assert `nl' == 4
    * RFC 4180: a quoted field doubles its quotes; a comma stays inside
    mata: st_local("l2", lines[2])
    mata: assert(strpos(st_local("l2"), char(34) + "He said " + char(34) + char(34) + "hi" + char(34) + char(34) + ", ok" + char(34)) > 0)
    mata: st_local("l3", lines[3])
    mata: assert(strpos(st_local("l3"), char(34) + "Ålder, år" + char(34)) > 0)
    mata: st_local("l4", lines[4])
    mata: assert(strpos(st_local("l4"), ",3,") > 0)
    quietly import delimited using r4.csv, clear varnames(1) bindquotes(strict) stringcols(_all) encoding("utf-8")
    assert c(k) == 37 & _N == 3
    quietly count if variable_label == `"He said "hi", ok"'
    assert r(N) == 1
    quietly count if variable_label == "Ålder, år"
    assert r(N) == 1
    * no csv without the suboption: a stale csv is left alone
    quietly use r4, clear
    mata: stale = cat("r4.csv")
    clear
    quietly set obs 3
    generate q = _n
    quietly datamap, output(r4b.md) saving(r4, replace)
    mata: now = cat("r4.csv")
    mata: assert(rows(stale) == rows(now) & all(stale :== now))
    assert "`r(metadata_csv)'" == ""
    capture erase r4n.csv
    quietly datamap, output(r4c.md) saving(r4n, replace)
    capture confirm file r4n.csv
    assert _rc == 601
    capture confirm file r4n.dta
    assert _rc == 0
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R4 csv read raw (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R4 csv read raw"'
}

**# R5 privacy fuzz: no printed count in 1..mincell-1 in the new content

capture noisily {
    quietly cd "`work'/run"
    local worst = .
    forvalues d = 1/8 {
        set seed `=9100 + `d''
        clear
        quietly set obs `=300 + 40 * mod(`d', 3)'
        * text that is mostly numeric text, with tokens of 0-8 rows
        forvalues k = 1/3 {
            quietly generate str10 s`k' = string(10000 + _n)
            local r0 = 0
            foreach tok in NA na N/A {
                local c = floor(runiform() * 9)
                if `c' > 0 quietly replace s`k' = "`tok'" in `=`r0' + 1'/`=`r0' + `c''
                local r0 = `r0' + `c'
            }
            local c = floor(runiform() * 9)
            if `c' > 0 quietly replace s`k' = "" in `=`r0' + 1'/`=`r0' + `c''
            local r0 = `r0' + `c'
            local c = floor(runiform() * 9)
            if `c' > 0 quietly replace s`k' = " " + s`k' in `=`r0' + 1'/`=`r0' + `c''
        }
        * few-valued text with rare levels
        quietly generate str8 t1 = cond(_n <= 120, "red", "blue")
        local c = floor(runiform() * 9)
        if `c' > 0 quietly replace t1 = "green" in 130/`=129 + `c''
        quietly generate str8 t2 = cond(mod(_n, 2), "yes", "no")
        local c = floor(runiform() * 9)
        if `c' > 0 quietly replace t2 = "maybe" in 140/`=139 + `c''
        * numeric and date candidates
        quietly generate double n1 = 20 + mod(_n, 13)
        local c = floor(runiform() * 9)
        if `c' > 0 quietly replace n1 = 999 in 1/`c'
        quietly generate byte n2 = mod(_n, 3)
        local c = floor(runiform() * 9)
        if `c' > 0 quietly replace n2 = 9 in 1/`c'
        quietly generate long dd = mdy(1, 1, 2000) + _n
        local c = floor(runiform() * 9)
        if `c' > 0 quietly replace dd = mdy(1, 1, 1960) in 1/`c'
        local c = floor(runiform() * 9)
        if `c' > 0 quietly replace dd = mdy(1, 1, 2090) in 20/`=19 + `c''
        format dd %td
        quietly save r5f, replace
        foreach m in 5 3 {
            quietly use r5f, clear
            quietly datamap, output(r5.md) mincell(`m') quality placeholders(999 9) saving(r5s, replace)
            mata: _vr_slurp("r5.md", "t")
            mata: _vr_counts()
            assert `_n' > 20
            if `_min' < . {
                if `_min' < `m' {
                    display as error "dataset `d' mincell `m': a count of `_min' is printed"
                    assert 0
                }
                if `_min' < `worst' local worst = `_min'
            }
            * saving(): withheld counts are .s, candidate counts are masked
            quietly use r5s, clear
            quietly count if numeric_n > 0 & numeric_n < `m'
            assert r(N) == 0
            quietly count if padded_n > 0 & padded_n < `m'
            assert r(N) == 0
            quietly count if regexm(candidates, ": [1-4] rows") & `m' == 5
            assert r(N) == 0
            quietly count if regexm(candidates, ": [1-2] rows") & `m' == 3
            assert r(N) == 0
        }
    }
    display as text "R5: smallest count printed in any run: `worst'"
    * a lone small token: with N and the Missing count printed, the numeric
    * text count would give the 3 NA rows away, so it is withheld too
    clear
    quietly set obs 200
    generate str6 s = string(1000 + _n)
    quietly replace s = "NA" in 1/3
    quietly datamap, output(r5h.md) mincell(5)
    mata: _vr_slurp("r5h.md", "t")
    mata: _vr_in("numeric text 197", 0)
    mata: _vr_in("{bq}s{bq} |  | str6 | 0 (0.0%) | N=200", 1)
    mata: _vr_in(char(34) + "NA" + char(34) + " 3", 0)
    quietly datamap, output(r5i.md) mincell(0)
    mata: _vr_slurp("r5i.md", "t")
    mata: _vr_in("numeric text 197 (98.5%)", 1)
    mata: _vr_in(char(34) + "NA" + char(34) + " 3", 1)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R5 privacy fuzz (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R5 privacy fuzz"'
}

**# R6 an excluded variable's values appear nowhere

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 120
    generate byte grp = 1 + mod(_n, 2)
    * the excluded variables: a labelled numeric with a coded missing, text
    * with tokens, dates at the rule values, a declared placeholder
    generate double sec_n = 7731000 + _n
    quietly replace sec_n = .a in 1/12
    label define seclbl 7731013 "SecretLabelText" .a "SecretRefused"
    label values sec_n seclbl
    generate str12 sec_s = string(5000 + _n)
    quietly replace sec_s = "SECRETTOKEN" in 1/20
    quietly replace sec_s = "SECRETOTHER" in 21/35
    generate long sec_d = mdy(3, 1, 2015) + _n
    quietly replace sec_d = mdy(12, 31, 9999) in 1/12
    quietly replace sec_d = mdy(6, 1, 2090) in 13/22
    format sec_d %td
    generate double sec_f = 40 + mod(_n, 9)
    quietly replace sec_f = 4242 in 1/12
    * the same constructions on visible variables: output must exist for them
    generate double vis_n = 40 + mod(_n, 9)
    quietly replace vis_n = 4242 in 1/12
    generate str12 vis_s = string(5000 + _n)
    quietly replace vis_s = "VISTOKEN" in 1/20
    generate long vis_d = mdy(3, 1, 2015) + _n
    quietly replace vis_d = mdy(1, 1, 1900) in 1/12
    format vis_d %td
    quietly save r6f, replace
    local ex "sec_n sec_s sec_d sec_f"
    quietly datamap, output(r6.md) exclude(`ex') quality placeholders(4242) ///
        missing(pattern) samples(3) mincell(0) saving(r6s, replace csv)
    mata: _vr_slurp("r6.md", "t")
    * the visible variables do print what the excluded ones must not
    mata: _vr_in("{bq}vis_n{bq}: 4242: 12 rows", 1)
    mata: _vr_in("VISTOKEN", 1)
    mata: _vr_in("{bq}vis_d{bq}: 1900/01/01: 12 rows", 1)
    foreach secret in 7731 SecretLabelText SecretRefused SECRETTOKEN SECRETOTHER ///
        "9999/12/31" 2090 "- {bq}sec_d{bq}: " "- {bq}sec_n{bq}: " {
        mata: _vr_in("`secret'", 0)
    }
    mata: _vr_in("{bq}sec_f{bq}: 4242", 0)
    * saving(): no secret in any string column, no statistic for the numeric
    quietly use r6s, clear
    foreach v of varlist _all {
        capture confirm string variable `v'
        if _rc continue
        foreach secret in 7731 SecretLabelText SecretRefused SECRETTOKEN SECRETOTHER 9999/12/31 2090 {
            quietly count if strpos(`v', "`secret'") > 0
            assert r(N) == 0
        }
    }
    foreach v of local ex {
        quietly count if variable == "`v'" & class == "excluded" & missing(mean) & missing(sd) & missing(p50) & missing(min) & missing(max) ///
            & candidates == "" & missing_codes == "" & date_mask == "" & missing(numeric_n) & missing(padded_n)
        assert r(N) == 1
    }
    * the csv text
    mata: _vr_slurp("r6s.csv", "t")
    foreach secret in 7731 SecretLabelText SecretRefused SECRETTOKEN SECRETOTHER 9999/12/31 2090 {
        mata: _vr_in("`secret'", 0)
    }
    * a second dataset: the linkage block names the shared excluded variable
    * and its label by structure only
    quietly use r6f, clear
    replace sec_n = sec_n + 1
    label define seclbl 7731013 "OtherSecret", modify
    quietly save r6g, replace
    quietly datamap, filelist(r6f r6g) output(r6b.md) exclude(`ex') quality mincell(0)
    mata: _vr_slurp("r6b.md", "t")
    foreach secret in 7731 SecretLabelText SecretRefused OtherSecret SECRETTOKEN 9999/12/31 {
        mata: _vr_in("`secret'", 0)
    }
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R6 excluded variables leak nothing (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R6 excluded variables leak nothing"'
}

**# R7 the duplicated Mata helpers agree; removed options are gone

capture noisily {
    quietly cd "`work'/run"
    * the copies of one helper in different files: the same body, comments
    * and indentation aside (autoloaded Mata is file-private, so a fix to one
    * copy must reach every copy)
    local v "`pkg_dir'/_datamap_md_varrows.ado"
    local s "`pkg_dir'/_datamap_md_sections.ado"
    local d "`pkg_dir'/_datamap_md_document.ado"
    local tb "`pkg_dir'/_datamap_md_textblock.ado"
    local on "`pkg_dir'/_datamap_md_outname.ado"
    mata: b = _vr_fbody(st_local("v"), "_dmv_esc"); assert(b != "")
    mata: assert(b == _vr_fbody(st_local("s"), "_dms_esc"))
    mata: assert(b == _vr_fbody(st_local("d"), "_dmd_esc"))
    mata: assert(b == _vr_fbody(st_local("tb"), "_dmtb_esc"))
    mata: b = _vr_fbody(st_local("v"), "_dmv_pctc"); assert(b != "")
    mata: assert(b == _vr_fbody(st_local("s"), "_dms_pctc"))
    mata: b = _vr_fbody(st_local("v"), "_dmv_isdatefmt"); assert(b != "")
    mata: assert(b == _vr_fbody(st_local("s"), "_dms_isdatefmt"))
    mata: b = _vr_fbody(st_local("v"), "_dmv_datefmt"); assert(b != "")
    mata: assert(b == _vr_fbody(st_local("s"), "_dms_datefmt"))
    mata: b = _vr_fbody(st_local("d"), "_dmd_unquote"); assert(b != "")
    mata: assert(b == _vr_fbody(st_local("tb"), "_dmtb_unquote"))
    mata: assert(b == _vr_fbody(st_local("on"), "_dmon_unquote"))
    mata: b = _vr_fbody(st_local("d"), "_dmd_decode"); assert(b != "")
    mata: assert(b == _vr_fbody(st_local("tb"), "_dmtb_decode"))
    * the helper's own check is not vacuous: two different bodies differ
    mata: assert(_vr_fbody(st_local("v"), "_dmv_esc") != _vr_fbody(st_local("v"), "_dmv_pctc"))
    * one hostile string through the paths that print it: a variable label,
    * value labels (a level and a coded missing), a dataset note, a text
    * token and a sample value.  Every copy must escape it alike.
    clear
    quietly set obs 60
    generate byte g = 1 + mod(_n, 2)
    quietly replace g = .a in 1/8
    generate str30 h = string(1000 + _n)
    quietly replace h = "x" in 9/9
    quietly save r7f, replace
    mata: H = "a|b" + char(36) + "c" + char(96) + "d<e>f" + char(92) + "g"
    mata: st_local("E", "a" + char(92) + "|b&#36;c&#96;d&lt;e&gt;f" + char(92) + char(92) + "g")
    mata: st_varlabel("g", H)
    mata: st_vlmodify("hl", (1 \ .a), (H \ H))
    mata: st_varvaluelabel("g", "hl")
    mata: st_global("_dta[note0]", "1")
    mata: st_global("_dta[note1]", H)
    mata: st_sstore(1::8, "h", J(8, 1, H))
    quietly datamap, output(r7.md) mincell(0) samples(3)
    mata: _vr_slurp("r7.md", "t")
    local nE = 0
    mata: st_local("nE", strofreal(_vr_occ(st_local("E"))))
    display as text "R7: the escaped hostile string appears `nE' times"
    * label cell, note, level label, coded-missing label, token, 3 samples
    assert `nE' == 8
    mata: _vr_in("  - " + st_local("E"), 1)
    mata: _vr_in("| . | " + st_local("E") + " |", 1)
    mata: _vr_in("non-numeric " + char(34) + st_local("E") + char(34) + " 8", 1)
    mata: _vr_in("a|b" + char(36), 0)
    mata: _vr_in("d<e>f", 0)
    mata: _vr_in("a" + char(92) + "|b" + char(36), 0)
    * the removed classifier option and the removed postfile option
    mata: _vr_slurp(st_local("pkg_dir") + "/_datamap_classify.ado", "t")
    * (a constant local named dateopt remains; the option must not)
    mata: st_local("syn", _vr_syntax(st_local("pkg_dir") + "/_datamap_classify.ado"))
    assert strpos(strlower(`"`syn'"'), "dateopt") == 0
    assert strpos(`"`syn'"', "AUTOexclude") > 0
    mata: _vr_slurp(st_local("pkg_dir") + "/_datamap_post_metadata_rows.ado", "t")
    mata: _vr_in("sumframe", 0)
    mata: _vr_slurp(st_local("pkg_dir") + "/datamap.ado", "t")
    mata: _vr_in("sumframe", 0)
    * format() with empty parentheses stops like the named form
    quietly use r7f, clear
    capture datamap, output(r7e.md) format()
    assert _rc == 198
    capture datamap, output(r7e.md) datevars()
    assert _rc == 198
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R7 helper copies and removed options (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R7 helper copies and removed options"'
}

sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_datamap_v200_link_qa tests=`tests' pass=`pass' fail=`fail'"
log close main
if `fail' exit 1
