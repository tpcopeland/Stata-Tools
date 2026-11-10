*! test_datamap_v200_link.do Version 1.0.0  2026/11/10
*! datamap 2.0.0 Phase 3, batch B: exclude(auto) (U5), placeholder candidates
*! (F5), the linkage block (F1) and the new saving() columns with csv (I2),
*! each against the acceptance test of the plan
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Fixture: the session's scenario, a 3,000-row "person" file (numeric lopnr,
* extended missings, a %tc variable, numeric text with NA, a 999 placeholder in
* bmi, an exit date in 2070, a genuine 99-year-old) and a 9,000-row "rx" file
* whose lopnr is str12.
*
*   L1  U5: exclude(auto) withholds the suggested identifier: r(excluded_vars)
*       lists it, r(suggested_exclude) is empty, no statistic for it in the
*       document or in saving(); combined with names and a data varlist; a
*       variable named auto is withheld too; config() exclude = auto
*   L2  F1: the linkage block of person and rx (lopnr long vs str12 flagged,
*       sexl defined differently), a same-type key reports 1:m, per-pair
*       merge types for three datasets, str widths are not a conflict; the
*       Contents line; no block for one dataset, separate or append
*   L3  F1 privacy: exclude() withholds uniqueness and merge type; no count
*       or value is printed in the block (mincell holds trivially)
*   L4  F5: placeholders(999) flags bmi with count if bmi == 999; the 2070
*       exit date; 01jan1900 in a %tc variable; a %tm date after the run
*       date; the genuine 99-year-old is not flagged; nothing without quality;
*       placeholders() without quality is rc 198; masking: below mincell, a
*       listed level's complement, mincell(0) prints every count
*   L5  I2: the saving() column list after the 27 (pinned), the values of each
*       new column, masked counts as .s; the key flag (missing values count
*       as values); saving(, csv) round-trips through import delimited;
*       r(metadata_csv); csv without replace on an existing file stops before
*       any output; an unknown suboption is rc 198
*   L6  F5 under datesafe (2026-11-10, Phase 3 review): a date variable's
*       candidates read "candidates withheld (datesafe)" in the document and
*       in saving() -- no exact date and no count; declared numeric
*       placeholders still print; without datesafe the dates print as in L4
* Documents are read through Mata (_v200l_slurp), never a Stata macro reader.
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_datamap_v200_link.log", replace text name(main)
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
local work "`base'_v200lwork"
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

capture mata: mata drop _v200l_slurp()
capture mata: mata drop _v200l_in()
capture mata: mata drop _v200l_line()
capture mata: mata drop _v200l_section()
mata:
void _v200l_slurp(string scalar path, string scalar dst)
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
void _v200l_in(string scalar needle, real scalar want)
{
	real scalar has
	has = (strpos(st_local("t"), subinstr(needle, "{bq}", char(96))) > 0)
	if (has != want) {
		errprintf("text check failed (want %g): %s\n", want, needle)
		exit(9)
	}
}
// local t has a whole line equal to needle ({bq} = a backtick)
void _v200l_line(string scalar needle)
{
	if (!strpos(char(10) + st_local("t"), char(10) + subinstr(needle, "{bq}", char(96)) + char(10))) {
		errprintf("line not found: %s\n", needle)
		exit(9)
	}
}
// local t cut to the text from the line "heading" to the next "## " heading
void _v200l_section(string scalar heading)
{
	string scalar t
	real scalar a, b
	t = char(10) + st_local("t")
	a = strpos(t, char(10) + heading + char(10))
	if (a == 0) {
		errprintf("section not found: %s\n", heading)
		exit(9)
	}
	t = substr(t, a + 1, .)
	b = strpos(substr(t, 2, .), char(10) + "## ")
	if (b > 0) t = substr(t, 1, b + 1)
	st_local("t", t)
}
end

* the fixture
quietly cd "`work'/run"
clear
quietly set obs 3000
generate long lopnr = 100000 + _n
generate byte edu = 1 + mod(_n, 3)
quietly replace edu = . in 1/51
quietly replace edu = .a in 52/196
quietly replace edu = .b in 197/276
label define edul 1 "Low" 2 "Mid" 3 "High" .a "Refused" .b "Not asked"
label values edu edul
generate byte sex = 1 + mod(_n, 2)
label define sexl 1 "Male" 2 "Female"
label values sex sexl
generate double bmi = 20 + mod(_n, 37) / 3
quietly replace bmi = 999 in 101/126
generate int age = 20 + mod(_n, 70)
quietly replace age = 99 in 500
generate double admit_tc = clock("2015-03-01 10:00", "YMDhm") + _n * 60000
format admit_tc %tc
generate long exitd = mdy(1, 1, 2020) + mod(_n, 400)
quietly replace exitd = mdy(6, 1, 2070) in 1/12
format exitd %td
generate str8 income_s = string(1000 + _n)
quietly replace income_s = "NA" in 1/124
quietly replace income_s = " " + income_s in 200/211
quietly save person.dta, replace
clear
quietly set obs 9000
generate str12 lopnr = string(100000 + ceil(_n / 3))
generate int drug = mod(_n, 7)
generate byte sex = 1 + mod(_n, 2)
label define sexl 1 "Female" 2 "Male"
label values sex sexl
quietly save rx.dta, replace
* rx2: the same file with lopnr as long (same type as person)
destring lopnr, replace
quietly save rx2.dta, replace
* visits: one row per person, lopnr str20 (a string of another width)
keep lopnr drug
quietly duplicates drop lopnr, force
tostring lopnr, replace format(%20.0f)
quietly recast str20 lopnr
quietly save visits.dta, replace
quietly cd "`cwd0'"

**# L1 U5: exclude(auto)

capture noisily {
    quietly cd "`work'/run"
    use person, clear
    quietly datamap, output(l1a.md) exclude(auto) saving(l1a, replace)
    assert "`r(excluded_vars)'" == "lopnr"
    assert "`r(suggested_exclude)'" == "" & r(n_suggested_exclude) == 0
    assert r(n_excluded) == 1
    mata: _v200l_slurp("l1a.md", "t")
    mata: _v200l_line("| {bq}lopnr{bq} |  | long | 0 (0.0%) | excluded (structure only) |")
    mata: _v200l_in("1 excluded ({bq}lopnr{bq})", 1)
    mata: _v200l_in("likely identifiers not excluded: none", 1)
    * no statistic of lopnr anywhere in the document
    mata: _v200l_in("100001", 0)
    mata: _v200l_in("103000", 0)
    use l1a, clear
    quietly keep if variable == "lopnr"
    assert _N == 1 & class == "excluded"
    assert missing(unique) & missing(mean) & missing(min) & missing(max) & missing(p50)
    assert missing(key) & candidates == ""
    * auto beside names, and with a data varlist: the identifier is withheld
    * outside the varlist as well (no warning, no statistics)
    use person, clear
    generate str9 ssn = "x" + string(_n)
    quietly datamap, output(l1b.md) exclude(auto ssn)
    assert "`r(excluded_vars)'" == "lopnr ssn"
    quietly datamap lopnr age, output(l1c.md) exclude(auto)
    assert "`r(excluded_vars)'" == "lopnr" & "`r(suggested_exclude)'" == ""
    * the same document as an explicit exclude(lopnr)
    quietly datamap lopnr age, output(l1d.md) exclude(lopnr)
    mata: _v200l_slurp("l1c.md", "t")
    local t1 : copy local t
    mata: _v200l_slurp("l1d.md", "t")
    mata: assert(st_local("t") == st_local("t1"))
    * a variable named auto is withheld too, and no "matches no variable" note
    use person, clear
    generate int auto = _n
    quietly datamap, output(l1e.md) exclude(auto)
    assert "`r(excluded_vars)'" == "lopnr auto"
    use person, clear
    quietly log using l1f.log, replace text name(l1f)
    datamap, output(l1f.md) exclude(auto)
    quietly log close l1f
    mata: _v200l_slurp("l1f.log", "t")
    mata: _v200l_in("matches no variable", 0)
    mata: _v200l_in("likely identifier", 0)
    * without auto: suggested, not withheld (unchanged)
    quietly datamap, output(l1g.md)
    assert "`r(suggested_exclude)'" == "lopnr" & "`r(excluded_vars)'" == ""
    * config(): exclude = auto
    tempname fh
    file open `fh' using l1.cfg, write text replace
    file write `fh' "exclude = auto" _n
    file close `fh'
    quietly datamap, output(l1h.md) config(l1.cfg)
    assert "`r(excluded_vars)'" == "lopnr"
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: L1 exclude(auto) (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: L1 exclude(auto)"'
}

**# L2 F1: the linkage block

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly datamap, filelist(person rx) output(l2a.md)
    mata: _v200l_slurp("l2a.md", "t")
    mata: _v200l_line("3. [Linkage](#linkage)")
    mata: _v200l_section("## Linkage")
    mata: _v200l_line("| Variable | Datasets | Type | Unique | Merge | Flags |")
    mata: _v200l_line("| {bq}lopnr{bq} | person, rx | person long; rx str12 | person yes; rx no | cannot merge: numeric and string | type conflict: numeric in person; string in rx |")
    mata: _v200l_line("| {bq}sex{bq} | person, rx | byte | no in both | person m:m rx |  |")
    mata: _v200l_line("- {bq}sexl{bq}: 2 definitions (person | rx)")
    * names in one dataset only are not listed
    mata: _v200l_in("{bq}drug{bq}", 0)
    mata: _v200l_in("{bq}edu{bq}", 0)
    * a same-type key: person 1:m rx2; the oracle is -isid-
    use person, clear
    isid lopnr
    use rx2, clear
    capture isid lopnr, missok
    assert _rc == 459
    quietly datamap, filelist(person rx2) output(l2b.md)
    mata: _v200l_slurp("l2b.md", "t")
    mata: _v200l_section("## Linkage")
    mata: _v200l_line("| {bq}lopnr{bq} | person, rx2 | long | person yes; rx2 no | person 1:m rx2 |  |")
    * the merge the block names runs (1:m from person; m:1 from the rx2
    * side), and a 1:1 is refused as the block says
    use person, clear
    quietly merge 1:m lopnr using rx2, keepusing(drug)
    use rx2, clear
    quietly merge m:1 lopnr using person, keepusing(age)
    use person, clear
    capture merge 1:1 lopnr using rx2
    assert _rc == 459
    * three datasets: each pair; str12 and str20 are no conflict
    quietly datamap, filelist(rx2 visits rx) output(l2c.md)
    mata: _v200l_slurp("l2c.md", "t")
    mata: _v200l_section("## Linkage")
    mata: _v200l_line("| {bq}lopnr{bq} | rx2, visits, rx | rx2 long; visits str20; rx str12 | rx2 no; visits yes; rx no | rx2 cannot merge (numeric and string) visits; rx2 cannot merge (numeric and string) rx; visits 1:m rx | type conflict: numeric in rx2; string in visits, rx |")
    quietly datamap, filelist(visits rx) output(l2d.md)
    mata: _v200l_slurp("l2d.md", "t")
    mata: _v200l_section("## Linkage")
    mata: _v200l_line("| {bq}lopnr{bq} | visits, rx | visits str20; rx str12 | visits yes; rx no | visits 1:m rx |  |")
    mata: _v200l_in("type conflict", 0)
    mata: _v200l_line("No value label is defined differently in two datasets.")
    * one dataset, separate, append: no block
    use person, clear
    quietly datamap, output(l2e.md)
    mata: _v200l_slurp("l2e.md", "t")
    mata: _v200l_in("Linkage", 0)
    quietly datamap, filelist(person rx) separate outdir(.) suffix(_l2)
    mata: _v200l_slurp("person_l2.md", "t")
    mata: _v200l_in("Linkage", 0)
    mata: _v200l_slurp("rx_l2.md", "t")
    mata: _v200l_in("Linkage", 0)
    capture erase l2f.md
    quietly datamap, filelist(person rx) output(l2f.md) append
    mata: _v200l_slurp("l2f.md", "t")
    mata: _v200l_in("Linkage", 0)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: L2 linkage block (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: L2 linkage block"'
}

**# L3 F1 privacy: exclude() and no values or counts

capture noisily {
    quietly cd "`work'/run"
    clear
    foreach ex in "lopnr" "auto" {
        quietly datamap, filelist(person rx) output(l3.md) exclude(`ex')
        mata: _v200l_slurp("l3.md", "t")
        mata: _v200l_section("## Linkage")
        mata: _v200l_line("| {bq}lopnr{bq} | person, rx | person long; rx str12 | withheld (excluded) | withheld (excluded) | type conflict: numeric in person; string in rx |")
    }
    * no value and no count: the block's digits are the str width and the
    * number of label definitions only
    quietly datamap, filelist(person rx) output(l3b.md) mincell(5)
    mata: _v200l_slurp("l3b.md", "t")
    mata: _v200l_section("## Linkage")
    mata: st_local("t", subinstr(subinstr(st_local("t"), "str12", ""), ": 2 definitions", ""))
    mata: assert(!regexm(st_local("t"), "[0-9]"))
    * a label carried only by an excluded variable is not compared
    use person, clear
    label define secretl 1 "Pos" 2 "Neg"
    generate byte hiv = 1 + mod(_n, 2)
    label values hiv secretl
    quietly save l3p.dta, replace
    use rx, clear
    label define secretl 1 "Neg" 2 "Pos"
    generate byte hiv = 1
    label values hiv secretl
    quietly save l3r.dta, replace
    quietly datamap, filelist(l3p l3r) output(l3c.md) exclude(hiv)
    mata: _v200l_slurp("l3c.md", "t")
    mata: _v200l_in("secretl", 0)
    quietly datamap, filelist(l3p l3r) output(l3d.md)
    mata: _v200l_slurp("l3d.md", "t")
    mata: _v200l_line("- {bq}secretl{bq}: 2 definitions (l3p | l3r)")
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: L3 linkage privacy (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: L3 linkage privacy"'
}

**# L4 F5: placeholder candidates

capture noisily {
    quietly cd "`work'/run"
    use person, clear
    quietly count if bmi == 999
    local n999 = r(N)
    assert `n999' == 26
    quietly count if exitd > date(c(current_date), "DMY") & !missing(exitd)
    local nfut = r(N)
    assert `nfut' == 12
    local rd = strtrim(string(date(c(current_date), "DMY"), "%tdCCYY/NN/DD"))
    quietly datamap, output(l4a.md) quality placeholders(999)
    mata: _v200l_slurp("l4a.md", "t")
    mata: _v200l_section("### Candidates (not applied)")
    mata: _v200l_line("- {bq}bmi{bq}: 999: `n999' rows")
    mata: _v200l_line("- {bq}exitd{bq}: after `rd' (run date): `nfut' rows")
    * the genuine 99-year-old is no candidate (99 not declared)
    mata: _v200l_in("{bq}age{bq}", 0)
    * nothing without quality, and placeholders() needs it
    quietly datamap, output(l4b.md)
    mata: _v200l_slurp("l4b.md", "t")
    mata: _v200l_in("Candidates", 0)
    mata: _v200l_in("### Flags", 0)
    capture datamap, output(l4c.md) placeholders(999)
    assert _rc == 198
    capture confirm file l4c.md
    assert _rc == 601
    * dates: 01jan1900 at any time of the day in %tc, 01jan1960 and
    * 31dec9999 in %td (not counted again as after the run date), a %tm
    * period after this month; a float compared as stored; masking
    clear
    quietly set obs 40
    generate double tc = clock("2015-01-01 08:00", "YMDhm") + _n * 3600000
    quietly replace tc = clock("1900-01-01 12:30", "YMDhm") in 1/6
    quietly replace tc = clock("2080-01-01 00:00", "YMDhm") in 7/8
    format tc %tc
    generate int mo = ym(2020, 1) + _n
    quietly replace mo = ym(2090, 5) in 1/7
    format mo %tm
    generate long dd = mdy(1, 1, 2020) + mod(_n, 30)
    quietly replace dd = 0 in 1/4
    quietly replace dd = mdy(12, 31, 9999) in 5/10
    quietly replace dd = mdy(1, 1, 2050) in 11/12
    format dd %td
    generate float fl = 1.1 + mod(_n, 30)
    quietly replace fl = 99.9 in 1/6
    generate int age = 20 + _n
    quietly replace age = 99 in 40
    generate byte cat = mod(_n, 3)
    quietly replace cat = 9 in 1/3
    quietly datamap, output(l4d.md) quality placeholders(99.9 9)
    mata: _v200l_slurp("l4d.md", "t")
    mata: _v200l_section("### Candidates (not applied)")
    mata: _v200l_line("- {bq}tc{bq}: 1900/01/01: 6 rows; after `rd' (run date): suppressed (<5)")
    mata: _v200l_line("- {bq}mo{bq}: after `rd' (run date): 7 rows")
    mata: _v200l_line("- {bq}dd{bq}: 1960/01/01: suppressed (<5); 9999/12/31: 6 rows; after `rd' (run date): suppressed (<5)")
    mata: _v200l_line("- {bq}fl{bq}: 99.9: 6 rows")
    mata: _v200l_line("- {bq}cat{bq}: 9: suppressed (<5)")
    mata: _v200l_in("{bq}age{bq}", 0)
    * mincell(0): every count
    quietly datamap, output(l4e.md) quality placeholders(99.9 9) mincell(0)
    mata: _v200l_slurp("l4e.md", "t")
    mata: _v200l_section("### Candidates (not applied)")
    mata: _v200l_line("- {bq}tc{bq}: 1900/01/01: 6 rows; after `rd' (run date): 2 rows")
    mata: _v200l_line("- {bq}dd{bq}: 1960/01/01: 4 rows; 9999/12/31: 6 rows; after `rd' (run date): 2 rows")
    mata: _v200l_line("- {bq}cat{bq}: 9: 3 rows")
    * a listed level withheld as a complement keeps its mask: 7 rows of 8
    * are withheld beside the 3 below mincell
    clear
    quietly set obs 100
    generate byte q = 1
    quietly replace q = 8 in 1/3
    quietly replace q = 9 in 4/10
    quietly datamap, output(l4f.md) quality placeholders(9)
    mata: _v200l_slurp("l4f.md", "t")
    mata: _v200l_in("9: suppressed (complementary)", 1)
    mata: _v200l_section("### Candidates (not applied)")
    mata: _v200l_line("- {bq}q{bq}: 9: suppressed (complementary)")
    * excluded variables get none
    quietly datamap, output(l4g.md) quality placeholders(9) exclude(q)
    mata: _v200l_slurp("l4g.md", "t")
    mata: _v200l_section("### Candidates (not applied)")
    mata: _v200l_line("No placeholder candidates.")
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: L4 placeholder candidates (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: L4 placeholder candidates"'
}

**# L5 I2: the new saving() columns and csv

capture noisily {
    quietly cd "`work'/run"
    capture erase l5.dta
    capture erase l5.csv
    use person, clear
    generate strL memo = "x"
    quietly datamap, output(l5.md) quality placeholders(999) saving(l5, csv)
    assert "`r(metadata)'" == "l5.dta" & "`r(metadata_csv)'" == "l5.csv"
    use l5, clear
    * the column list: the 27 of 1.10.6, missing_codes, then the nine
    unab _all_ : _all
    assert wordcount("`_all_'") == 37
    assert word("`_all_'", 27) == "unique_capped" & word("`_all_'", 28) == "missing_codes"
    local i2 position date_family numeric_n numeric_pct padded_n date_mask is_strl key candidates
    forvalues j = 1/9 {
        assert word("`_all_'", 28 + `j') == word("`i2'", `j')
    }
    confirm long variable position
    confirm str32 variable date_family
    confirm double variable numeric_n numeric_pct padded_n
    confirm str20 variable date_mask
    confirm byte variable is_strl key
    * 2026-11-10 (2.0.0 Phase 3 repair): strL, whole, like missing_codes (was
    * str2045, cut with no mark)
    confirm strL variable candidates
    * values
    assert position == _n
    assert date_family == "%tc datetime" if variable == "admit_tc"
    assert date_family == "%td daily" if variable == "exitd"
    assert date_family == "" if !inlist(variable, "admit_tc", "exitd")
    preserve
    use person, clear
    quietly count if missing(real(income_s))
    local nnon = r(N)
    quietly count if substr(income_s, 1, 1) == " "
    local npad = r(N)
    restore
    assert numeric_n == 3000 - `nnon' if variable == "income_s"
    assert numeric_pct == floor((2000 * (3000 - `nnon') + 3000) / 6000) / 10 if variable == "income_s"
    * the same share the document prints (one percent rule, two copies)
    quietly levelsof numeric_pct if variable == "income_s", local(_pct)
    local _pcts = strtrim(string(`_pct', "%9.1f"))
    mata: _v200l_slurp("l5.md", "t")
    mata: _v200l_in("numeric text " + strofreal(3000 - `nnon') + " (`_pcts'%)", 1)
    assert padded_n == `npad' if variable == "income_s"
    assert missing(numeric_n) & missing(padded_n) if variable != "income_s" & variable != "memo"
    assert is_strl == 1 if variable == "memo"
    assert is_strl == 0 if variable == "income_s"
    assert candidates == "999: 26 rows" if variable == "bmi"
    assert candidates == "" if variable == "age"
    * the key flag: lopnr unique (counted exactly: a likely identifier),
    * few-valued variables not, a capped continuous one not determined
    assert key == 1 if variable == "lopnr"
    assert key == 0 if inlist(variable, "edu", "sex", "age")
    assert missing(key) if variable == "admit_tc"
    * csv: the same table through import delimited
    tempfile dta
    quietly save `dta'
    import delimited using l5.csv, clear varnames(1) case(preserve) ///
        bindquotes(strict) asdouble stringcols(1/10 16/18 26 28 30 34 37)
    assert _N == 9 & c(k) == 37
    unab _csv_ : _all
    assert "`_csv_'" == "`_all_'"
    * strings verbatim, numbers equal (a missing code reads as missing)
    foreach v of local _all_ {
        rename `v' c_`v'
    }
    quietly merge 1:1 _n using `dta', nogenerate
    foreach v of local _all_ {
        capture confirm string variable `v'
        if _rc == 0 assert c_`v' == `v'
        else assert (missing(c_`v') & missing(`v')) | reldif(c_`v', `v') < 1e-15
    }
    * masked counts are .s: a padded count below mincell
    clear
    quietly set obs 100
    generate str6 s = string(_n)
    quietly replace s = " " + s in 1/2
    quietly replace s = "NA" in 3/9
    quietly datamap, output(l5b.md) saving(l5b, replace)
    use l5b, clear
    assert padded_n == .s & numeric_n == 93
    * the key flag: missing values count as values
    clear
    quietly set obs 50
    generate long id = _n
    generate long id1m = _n
    quietly replace id1m = . in 7
    generate long id2m = _n
    quietly replace id2m = . in 7/8
    generate long idcodes = _n
    quietly replace idcodes = . in 7
    quietly replace idcodes = .a in 8
    generate str5 sid = string(_n)
    quietly replace sid = "" in 3/4
    quietly datamap, output(l5c.md) saving(l5c, replace)
    use l5c, clear
    assert key == 1 if inlist(variable, "id", "id1m", "idcodes")
    assert key == 0 if inlist(variable, "id2m", "sid")
    * csv refused before any output when the .csv exists, and a bad suboption
    use person, clear
    capture erase l5d.md
    capture erase l5d.dta
    copy l5.csv l5d.csv, replace
    capture datamap, output(l5d.md) saving(l5d, csv)
    assert _rc == 602
    capture confirm file l5d.md
    assert _rc == 601
    capture confirm file l5d.dta
    assert _rc == 601
    capture datamap, output(l5d.md) saving(l5d, replace bogus)
    assert _rc == 198
    capture confirm file l5d.md
    assert _rc == 601
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: L5 saving() columns and csv (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: L5 saving() columns and csv"'
}

**# L6 F5 under datesafe

capture noisily {
    quietly cd "`work'/run"
    capture erase l6.dta
    clear
    quietly set obs 40
    generate long dob = mdy(1, 1, 1980) + _n
    quietly replace dob = 0 in 1/12
    format dob %td
    generate double tc = clock("2015-01-01 08:00", "YMDhm") + _n * 3600000
    quietly replace tc = clock("1900-01-01 12:30", "YMDhm") in 1/6
    format tc %tc
    generate float fl = 1.1 + mod(_n, 30)
    quietly replace fl = 99.9 in 1/6
    quietly datamap, output(l6a.md) quality placeholders(99.9) datesafe saving(l6)
    mata: _v200l_slurp("l6a.md", "t")
    mata: _v200l_in("1960/01/01", 0)
    mata: _v200l_in("1900/01/01", 0)
    mata: _v200l_section("### Candidates (not applied)")
    mata: _v200l_line("- {bq}dob{bq}: candidates withheld (datesafe)")
    mata: _v200l_line("- {bq}tc{bq}: candidates withheld (datesafe)")
    mata: _v200l_line("- {bq}fl{bq}: 99.9: 6 rows")
    use l6, clear
    assert candidates == "candidates withheld (datesafe)" if inlist(variable, "dob", "tc")
    assert candidates == "99.9: 6 rows" if variable == "fl"
    * without datesafe the candidate dates and counts print
    clear
    quietly set obs 40
    generate long dob = mdy(1, 1, 1980) + _n
    quietly replace dob = 0 in 1/12
    format dob %td
    quietly datamap, output(l6b.md) quality
    mata: _v200l_slurp("l6b.md", "t")
    mata: _v200l_section("### Candidates (not applied)")
    mata: _v200l_line("- {bq}dob{bq}: 1960/01/01: 12 rows")
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: L6 candidates under datesafe (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: L6 candidates under datesafe"'
}

sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_datamap_v200_link tests=`tests' pass=`pass' fail=`fail'"
log close main
if `fail' exit 1
