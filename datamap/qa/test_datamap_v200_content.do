*! test_datamap_v200_content.do Version 1.0.0  2026/11/10
*! datamap 2.0.0 Phase 3, batch A: the dataset state header (F2), the
*! per-code missing breakdown (F3), the Type column's date family (U4) and the
*! string profile (F4), each against the acceptance test of the plan
*! Author: Timothy P Copeland, Karolinska Institutet
*
*   C1  xtset (panel and time), tsset (time only), xtset (panel only): the
*       declared line, exactly; absent when nothing is set
*   C2  stset: the declared line; a failure variable or expression naming an
*       excluded variable has its values withheld
*   C3  svyset: the declared line (svyset's own r(settings)); datamap leaves
*       c(changed), the sort order and the settings as they were
*   C4  mi set: the declared line
*   C5  dataset notes (escaped), the File line of the data in memory
*       (unchanged / changed / none), no File line for a file input
*   C6  detect() output is labelled inferred; autodetect has no binary line,
*       detect(binary) does; the event rate names its denominator
*   C7  F3: ". 51, .a Refused 145, .b Not asked 80" with counts equal to
*       count if x == code; masked under mincell(); no breakdown when only .
*       occurs; compact and nolabels; an excluded variable has none, and its
*       Missing count obeys mincell()
*   C8  F3 in saving(): missing_codes equals the document's breakdown, masked
*       alike; the 27 1.10.6 columns keep their values
*   C9  U4: one variable per date family, strL, str12, long
*   C10 F4: numeric text and its non-numeric values (counts equal to count),
*       masked under mincell(); padded values; a date-string mask; mixed case;
*       datesafe and nofreq; excluded variables get no profile; a value held
*       by fewer than mincell() rows is never listed
*   C11 F4 under datesafe (2026-11-10, Phase 3 review): text that date()
*       masks do not read -- ISO datetimes, year-month, quarters, two-digit
*       years, dates inside other text, full-width digits -- has its values
*       withheld; any listed value with a digit withholds them all (a code
*       such as "A1" too); text without a digit is still listed
*   C12 F3 under nofreq (2026-11-10, Phase 3 review): no per-code missing
*       breakdown, the Missing total stays; compact alike
*   C13 F4 counting above 24 distinct values (sorted, 2026-11-10 Phase 3
*       review: per-value matching cost values x rows) gives the counts
*       -count- gives, as the matching path does at 20 values
* Documents are read through Mata (_v200c_slurp), never a Stata macro reader.
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_datamap_v200_content.log", replace text name(main)
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
local work "`base'_v200cwork"
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

capture mata: mata drop _v200c_slurp()
capture mata: mata drop _v200c_in()
capture mata: mata drop _v200c_line()
capture mata: mata drop _v200c_count()
mata:
void _v200c_slurp(string scalar path, string scalar dst)
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
void _v200c_in(string scalar needle, real scalar want)
{
	real scalar has
	has = (strpos(st_local("t"), subinstr(needle, "{bq}", char(96))) > 0)
	if (has != want) {
		errprintf("text check failed (want %g): %s\n", want, needle)
		exit(9)
	}
}
// local t has a whole line equal to needle ({bq} = a backtick)
void _v200c_line(string scalar needle)
{
	if (!strpos(char(10) + st_local("t"), char(10) + subinstr(needle, "{bq}", char(96)) + char(10))) {
		errprintf("line not found: %s\n", needle)
		exit(9)
	}
}
// lines of local t that start with prefix
real scalar _v200c_count(string scalar prefix)
{
	string scalar t
	real scalar n, j
	t = st_local("t")
	n = 0
	while ((j = strpos(t, char(10))) > 0) {
		n = n + (substr(t, 1, strlen(prefix)) == prefix)
		t = substr(t, j + 1, .)
	}
	return(n)
}
end

**# C1 xtset / tsset: the declared line, as declared

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 60
    generate int firm = ceil(_n / 6)
    generate int year = 2000 + mod(_n - 1, 6)
    format year %ty
    generate double y = _n / 7
    xtset firm year
    quietly datamap, output(c1a.md)
    mata: _v200c_slurp("c1a.md", "t")
    mata: _v200c_line("- Declared xtset: panel {bq}firm{bq}; time {bq}year{bq} (%ty yearly); delta 1")
    * a time series: tsset with a monthly time variable and delta 2
    clear
    quietly set obs 24
    generate t = tm(2020m1) + 2 * (_n - 1)
    format t %tm
    generate y = _n
    tsset t, delta(2)
    quietly datamap, output(c1b.md)
    mata: _v200c_slurp("c1b.md", "t")
    mata: _v200c_line("- Declared tsset: time {bq}t{bq} (%tm monthly); delta 2")
    * a panel without a time variable
    clear
    quietly set obs 20
    generate id = ceil(_n / 2)
    xtset id
    quietly datamap, output(c1c.md)
    mata: _v200c_slurp("c1c.md", "t")
    mata: _v200c_line("- Declared xtset: panel {bq}id{bq}; no time variable")
    * nothing declared: no Declared line
    tsset, clear
    quietly datamap, output(c1d.md)
    mata: _v200c_slurp("c1d.md", "t")
    mata: _v200c_in("- Declared", 0)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: C1 xtset/tsset declared line (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: C1 xtset/tsset declared line"'
}

**# C2 stset: the declared line; values naming an excluded variable withheld

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 80
    generate int pid = _n
    generate double t1 = 10 + _n
    generate byte died = mod(_n, 3)
    generate byte age = 20 + mod(_n, 40)
    stset t1, id(pid) failure(died==1 2) exit(time 70) if(age>30) scale(7)
    quietly datamap, output(c2a.md)
    mata: _v200c_slurp("c2a.md", "t")
    mata: _v200c_line("- Declared stset: time {bq}t1{bq}; id {bq}pid{bq}; failure {bq}died{bq} == 1 2; exit {bq}time 70{bq}; if {bq}age>30{bq}; scale 7")
    quietly datamap, output(c2b.md) exclude(died age)
    mata: _v200c_slurp("c2b.md", "t")
    mata: _v200c_line("- Declared stset: time {bq}t1{bq}; id {bq}pid{bq}; failure {bq}died{bq} (values withheld: excluded); exit {bq}time 70{bq}; if withheld (names an excluded variable); scale 7")
    mata: _v200c_in("== 1 2", 0)
    mata: _v200c_in("age>30", 0)
    * a failure() without values, and no failure()
    stset t1, failure(died)
    quietly datamap, output(c2c.md)
    mata: _v200c_slurp("c2c.md", "t")
    mata: _v200c_line("- Declared stset: time {bq}t1{bq}; failure {bq}died{bq} (nonzero, nonmissing)")
    stset t1
    quietly datamap, output(c2d.md)
    mata: _v200c_slurp("c2d.md", "t")
    mata: _v200c_line("- Declared stset: time {bq}t1{bq}; failure: none declared (every record ends in failure)")
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: C2 stset declared line and exclude() (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: C2 stset declared line and exclude()"'
}

**# C3 svyset: the declared line; datamap leaves the data's state alone

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 200
    generate int psu = ceil(_n / 10)
    generate byte strat = ceil(_n / 50)
    generate double wt = 1 + mod(_n, 4)
    generate double y = _n
    svyset psu [pweight=wt], strata(strat) vce(linearized) singleunit(missing)
    quietly svyset
    local want `"`r(settings)'"'
    sort y
    quietly save c3.dta, replace
    quietly use c3.dta, clear
    local ch0 = c(changed)
    local so0 : sortedby
    quietly datamap, output(c3.md)
    assert c(changed) == `ch0'
    assert "`: sortedby'" == "`so0'"
    quietly svyset
    assert `"`r(settings)'"' == `"`want'"'
    mata: _v200c_slurp("c3.md", "t")
    mata: _v200c_line("- Declared svyset: {bq}" + st_local("want") + "{bq}")
    mata: _v200c_line("- File: {bq}" + st_global("c(filename)") + "{bq}; unchanged since it was last used or saved")
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: C3 svyset declared line, state untouched (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: C3 svyset declared line, state untouched"'
}

**# C4 mi set: the declared line

capture noisily {
    quietly cd "`work'/run"
    clear
    set seed 20261110
    quietly set obs 100
    generate double x = rnormal()
    generate double z = x + rnormal()
    generate double w = 1 + mod(_n, 3)
    quietly replace z = . in 1/10
    quietly mi set mlong
    quietly mi register imputed z
    quietly mi impute regress z x, add(3) rseed(1)
    quietly mi passive: generate double z2 = z * 2
    quietly datamap, output(c4.md)
    mata: _v200c_slurp("c4.md", "t")
    mata: _v200c_line("- Declared mi set: style mlong; M = 3; imputed {bq}z{bq}; passive {bq}z2{bq}")
    * an mi svyset dataset: the settings come from mi svyset
    quietly mi svyset [pweight=w], vce(linearized)
    quietly mi svyset
    local want `"`r(settings)'"'
    quietly datamap, output(c4b.md)
    mata: _v200c_slurp("c4b.md", "t")
    mata: _v200c_line("- Declared svyset: {bq}" + st_local("want") + "{bq}")
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: C4 mi set declared line (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: C4 mi set declared line"'
}

**# C5 dataset notes and the File line

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 10
    generate x = _n
    * never saved: no file
    quietly datamap, output(c5a.md)
    mata: _v200c_slurp("c5a.md", "t")
    mata: _v200c_line("- File: none (not used from or saved to a file)")
    mata: _v200c_in("- Dataset notes:", 0)
    notes: plain first note
    notes: a | pipe and a <tag>
    quietly save c5.dta, replace
    quietly use c5.dta, clear
    quietly replace x = x + 1 in 1
    quietly datamap, output(c5b.md)
    mata: _v200c_slurp("c5b.md", "t")
    mata: _v200c_line("- File: {bq}" + st_global("c(filename)") + "{bq}; changed since it was last used or saved")
    mata: _v200c_line("- Dataset notes:")
    mata: _v200c_line("  - plain first note")
    mata: _v200c_line("  - a \| pipe and a &lt;tag&gt;")
    * a file input: the source is the file, no File line
    quietly datamap, single(c5.dta) output(c5c.md)
    mata: _v200c_slurp("c5c.md", "t")
    mata: _v200c_in("- File:", 0)
    mata: _v200c_line("  - plain first note")
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: C5 dataset notes and the File line (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: C5 dataset notes and the File line"'
}

**# C6 detect() output is inferred; the binary line only under detect(binary)

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 100
    generate int patient_id = ceil(_n / 2)
    generate byte flag = mod(_n, 2)
    generate double followup_time = _n
    generate byte died = (mod(_n, 4) == 0)
    replace died = . in 1/20
    quietly datamap, output(c6a.md) autodetect
    mata: _v200c_slurp("c6a.md", "t")
    mata: _v200c_line("### Structure (inferred)")
    mata: _v200c_in("Structure (detected)", 0)
    mata: _v200c_in("- Binary (two distinct values)", 0)
    * the rate's denominator: 20 of 80 nonmissing
    mata: _v200c_line("  - {bq}died{bq} rate: 25.0% of nonmissing values")
    quietly datamap, output(c6b.md) detect(binary)
    mata: _v200c_slurp("c6b.md", "t")
    mata: _v200c_line("- Binary (two distinct values): {bq}flag{bq}, {bq}died{bq}")
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: C6 inferred structure, binary line, rate denominator (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: C6 inferred structure, binary line, rate denominator"'
}

**# C7 F3: the per-code missing breakdown

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 3000
    generate byte edu = 1 + mod(_n, 4)
    quietly replace edu = . in 1/51
    quietly replace edu = .a in 52/196
    quietly replace edu = .b in 197/276
    label define edul 1 "Primary" 2 "Secondary" 3 "Tertiary" 4 "Other" .a "Refused" .b "Not asked"
    label values edu edul
    generate double bmi = 20 + _n / 100
    quietly replace bmi = .a in 1/3
    quietly replace bmi = . in 4/40
    generate double onlydot = _n
    quietly replace onlydot = . in 1/10
    generate double secret = _n
    quietly replace secret = .a in 1/3
    * the counts the breakdown must print, from -count-
    foreach c in . .a .b {
        quietly count if edu == `c'
        local n`=subinstr("`c'", ".", "d", 1)' = r(N)
    }
    assert `nd' == 51 & `nda' == 145 & `ndb' == 80
    quietly datamap, output(c7a.md) exclude(secret)
    mata: _v200c_slurp("c7a.md", "t")
    mata: _v200c_in("| {bq}edu{bq} |  | byte | 276 (9.2%): . `nd', .a Refused `nda', .b Not asked `ndb' | ", 1)
    * a code below mincell() and its complement
    mata: _v200c_in("| {bq}bmi{bq} |  | double | 40 (1.3%): . suppressed (complementary), .a suppressed (<5) | ", 1)
    * only . occurs: no breakdown
    mata: _v200c_in("| {bq}onlydot{bq} |  | double | 10 (0.3%) | ", 1)
    * excluded: no breakdown, and its Missing count of 3 is not printed
    mata: _v200c_in("| {bq}secret{bq} |  | double | suppressed (<5) | excluded (structure only) |", 1)
    quietly datamap, output(c7b.md) mincell(0)
    mata: _v200c_slurp("c7b.md", "t")
    mata: _v200c_in("| {bq}bmi{bq} |  | double | 40 (1.3%): . 37, .a 3 | ", 1)
    mata: _v200c_in("| {bq}secret{bq} |  | double | 3 (0.1%): .a 3 | ", 1)
    * compact (no levels listed) and nolabels
    quietly datamap, output(c7c.md) compact
    mata: _v200c_slurp("c7c.md", "t")
    mata: _v200c_in("| 276 (9.2%): . 51, .a Refused 145, .b Not asked 80 | ", 1)
    quietly datamap, output(c7d.md) nolabels
    mata: _v200c_slurp("c7d.md", "t")
    mata: _v200c_in("| 276 (9.2%): . 51, .a 145, .b 80 | ", 1)
    * a withheld Missing total withholds every code (30 rows, .a 3)
    clear
    quietly set obs 30
    generate byte q = mod(_n, 2) + 1
    quietly replace q = .a in 1/3
    label define ql 1 "Yes" 2 "No" .a "Refused"
    label values q ql
    quietly datamap, output(c7e.md)
    mata: _v200c_slurp("c7e.md", "t")
    mata: _v200c_in("| {bq}q{bq} |  | byte | suppressed (<5): .a Refused suppressed (<5) | 1 Yes: 14 (46.7%)<br>2 No: suppressed (complementary) |", 1)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: C7 per-code missing breakdown (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: C7 per-code missing breakdown"'
}

**# C8 F3 in saving(): missing_codes

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 3000
    generate byte edu = 1 + mod(_n, 4)
    quietly replace edu = . in 1/51
    quietly replace edu = .a in 52/196
    quietly replace edu = .b in 197/276
    label define edul 1 "Primary" 2 "Secondary" 3 "Tertiary" 4 "Other" .a "Refused" .b "Not asked"
    label values edu edul
    generate double bmi = 20 + _n / 100
    quietly replace bmi = .a in 1/3
    quietly replace bmi = . in 4/40
    generate double onlydot = _n
    quietly replace onlydot = . in 1/10
    quietly datamap, output(c8.md) saving(c8m, replace)
    use c8m, clear
    * the 28th column, after the 27 of 1.10.6
    * 2026-11-10 (2.0.0 Phase 3, I2): nine new-fact columns follow it (37 in
    * all; pinned in test_datamap_v200_link.do)
    unab _all_ : _all
    assert word("`_all_'", 28) == "missing_codes" & wordcount("`_all_'") == 37
    assert word("`_all_'", 27) == "unique_capped"
    * 2026-11-10 (2.0.0 Phase 3 repair): strL, whole (was str2045, which cut a
    * long breakdown with no mark; test_datamap_v200_content_qa.do Q9)
    confirm strL variable missing_codes
    assert missing_codes == ". 51, .a Refused 145, .b Not asked 80" if variable == "edu"
    assert missing_codes == ". suppressed (complementary), .a suppressed (<5)" if variable == "bmi"
    assert missing_codes == "" if variable == "onlydot"
    * the numeric missing columns keep the exact counts (1.10.6 parity)
    assert missing == 276 if variable == "edu"
    assert missing == 40 if variable == "bmi"
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: C8 saving() missing_codes (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: C8 saving() missing_codes"'
}

**# C9 U4: the Type column

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 40
    foreach f in td tc tC tw tm tq th ty {
        generate double v_`f' = _n
        format v_`f' %`f'
    }
    generate double v_old = _n
    format v_old %d
    generate double v_left = _n
    format v_left %-tdCCYY-NN-DD
    generate strL sl = "long text " + string(_n)
    generate str12 s12 = "abc"
    generate long lg = _n
    quietly datamap, output(c9.md)
    mata: _v200c_slurp("c9.md", "t")
    local w_td "daily"
    local w_tc "datetime"
    local w_tC "datetime (leap seconds)"
    local w_tw "weekly"
    local w_tm "monthly"
    local w_tq "quarterly"
    local w_th "half-yearly"
    local w_ty "yearly"
    foreach f in td tc tC tw tm tq th ty {
        mata: _v200c_in("| {bq}v_`f'{bq} |  | double %`f' `w_`f'' | ", 1)
    }
    mata: _v200c_in("| {bq}v_old{bq} |  | double %td daily | ", 1)
    mata: _v200c_in("| {bq}v_left{bq} |  | double %td daily | ", 1)
    mata: _v200c_in("| {bq}sl{bq} |  | strL | ", 1)
    mata: _v200c_in("| {bq}s12{bq} |  | str12 | ", 1)
    mata: _v200c_in("| {bq}lg{bq} |  | long | ", 1)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: C9 Type column date families (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: C9 Type column date families"'
}

**# C10 F4: the string profile

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 3000
    generate income_s = string(1000 + _n)
    quietly replace income_s = "NA" in 1/124
    quietly replace income_s = "na" in 125/127
    quietly replace income_s = "" in 128/141
    quietly replace income_s = " " + income_s + " " in 200/211
    generate dstr = string(mdy(1, 1, 2020) + _n, "%tdCCYY-NN-DD")
    generate pnr = string(_n, "%09.0f") + "-X"
    * the counts the profile must print, from -count-
    quietly count if income_s != "" & !missing(real(income_s))
    local nnum = r(N)
    quietly count if income_s == "NA"
    local nNA = r(N)
    quietly count if income_s != "" & (substr(income_s, 1, 1) == " " | substr(income_s, -1, 1) == " ")
    local npad = r(N)
    assert `nnum' == 2859 & `nNA' == 124 & `npad' == 12
    quietly datamap, output(c10a.md) mincell(0)
    mata: _v200c_slurp("c10a.md", "t")
    mata: _v200c_in("| N=2986; >1000 distinct; max length 6; numeric text `nnum' (95.3%); non-numeric " + char(34) + "NA" + char(34) + " `nNA', " + char(34) + "na" + char(34) + " 3; leading or trailing spaces `npad' |", 1)
    mata: _v200c_in("| N=3000; >1000 distinct; max length 10; date-like text (YMD) |", 1)
    * an identifier-like text variable: no values listed, at any mincell()
    mata: _v200c_in("| {bq}pnr{bq} |  | str11 | 0 (0.0%) | N=3000; >1000 distinct; max length 11 |", 1)
    * default mincell: "na" (3 rows) is never listed; the rest it stays in
    * is below 5, so "NA" is withheld as its complement
    quietly datamap, output(c10b.md)
    mata: _v200c_slurp("c10b.md", "t")
    mata: _v200c_in("numeric text `nnum' (95.3%); non-numeric " + char(34) + "NA" + char(34) + " suppressed (complementary), others; leading or trailing spaces `npad' |", 1)
    mata: _v200c_in(char(34) + "na" + char(34), 0)
    * excluded: no profile at all
    quietly datamap, output(c10c.md) exclude(income_s dstr) mincell(0)
    mata: _v200c_slurp("c10c.md", "t")
    mata: _v200c_in("| {bq}income_s{bq} |  | str6 | 14 (0.5%) | excluded (structure only) |", 1)
    mata: _v200c_in("| {bq}dstr{bq} |  | str10 | 0 (0.0%) | excluded (structure only) |", 1)
    mata: _v200c_in("numeric text", 0)
    mata: _v200c_in("date-like", 0)
    * a few-valued text variable: mixed case and a padded value listed
    clear
    quietly set obs 200
    generate sex = cond(mod(_n, 2), "Male", "male")
    quietly replace sex = "Male " in 1/3
    quietly replace sex = "Female" in 4/60
    generate d2 = cond(_n < 100, "2020-01-01", "2021-06-30")
    quietly datamap, output(c10d.md) mincell(0)
    mata: _v200c_slurp("c10d.md", "t")
    mata: _v200c_in("| N=200; 4 distinct; max length 6; values " + char(34) + "Male" + char(34) + " 70, " + char(34) + "male" + char(34) + " 70, " + char(34) + "Female" + char(34) + " 57, " + char(34) + "Male " + char(34) + " 3; leading or trailing spaces 3 |", 1)
    mata: _v200c_in("| N=200; 2 distinct; max length 10; values " + char(34) + "2021-06-30" + char(34) + " 101, " + char(34) + "2020-01-01" + char(34) + " 99; date-like text (YMD) |", 1)
    * datesafe withholds date-like values; nofreq lists none
    quietly datamap, output(c10e.md) mincell(0) datesafe
    mata: _v200c_slurp("c10e.md", "t")
    mata: _v200c_in("| N=200; 2 distinct; max length 10; values withheld (datesafe); date-like text (YMD) |", 1)
    mata: _v200c_in("2021-06-30", 0)
    quietly datamap, output(c10f.md) mincell(0) nofreq
    mata: _v200c_slurp("c10f.md", "t")
    mata: _v200c_in("| N=200; 4 distinct; max length 6; leading or trailing spaces 3 |", 1)
    * default mincell: "Male " (3 rows) is never listed; "Female" is the
    * complement of the rest it stays in
    quietly datamap, output(c10g.md)
    mata: _v200c_slurp("c10g.md", "t")
    mata: _v200c_in("values " + char(34) + "Male" + char(34) + " 70, " + char(34) + "male" + char(34) + " 70, " + char(34) + "Female" + char(34) + " suppressed (complementary), others; leading or trailing spaces suppressed (<5) |", 1)
    mata: _v200c_in(char(34) + "Male " + char(34), 0)
    * a few-valued text variable whose values are all rare lists none
    clear
    quietly set obs 10
    generate strL nm = "person " + string(_n)
    quietly datamap, output(c10h.md)
    mata: _v200c_slurp("c10h.md", "t")
    mata: _v200c_in("| {bq}nm{bq} |  | strL | 0 (0.0%) | N=10; 10 distinct; max length 9 |", 1)
    mata: _v200c_in("person 1", 0)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: C10 string profile (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: C10 string profile"'
}

**# C11 F4 under datesafe: every date-text form

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 120
    generate byte g = mod(_n, 6)
    generate str30 s_dt = "2020-01-" + string(10 + g) + " 10:30"
    generate str30 s_iso = "2020-01-" + string(10 + g) + "T10:30:00"
    generate str30 s_ym = "2020-0" + string(1 + g)
    generate str30 s_q = "2020Q" + string(1 + mod(g, 4))
    generate str30 s_mdy2 = "1/" + string(10 + g) + "/20"
    generate str30 s_born = "born " + string(10 + g) + " jan 1980"
    generate str30 s_wk = "Jan 2020 w" + string(g)
    generate str30 s_fw = "２０２０年１月" + string(10 + g)
    generate str30 s_code = "A" + string(1 + g)
    generate str30 s_sex = cond(_n <= 60, "Male", "Female")
    drop g
    * without datesafe each is listed (the values are what datesafe hides)
    quietly datamap, output(c11a.md) mincell(5)
    mata: _v200c_slurp("c11a.md", "t")
    mata: _v200c_in(char(34) + "2020-01-10 10:30" + char(34) + " 20", 1)
    mata: _v200c_in(char(34) + "1/10/20" + char(34) + " 20", 1)
    quietly datamap, output(c11b.md) mincell(5) datesafe
    mata: _v200c_slurp("c11b.md", "t")
    mata: _v200c_line("| {bq}s_dt{bq} |  | str30 | 0 (0.0%) | N=120; 6 distinct; max length 16; values withheld (datesafe) |")
    mata: _v200c_line("| {bq}s_iso{bq} |  | str30 | 0 (0.0%) | N=120; 6 distinct; max length 19; values withheld (datesafe) |")
    mata: _v200c_line("| {bq}s_ym{bq} |  | str30 | 0 (0.0%) | N=120; 6 distinct; max length 7; values withheld (datesafe) |")
    mata: _v200c_line("| {bq}s_q{bq} |  | str30 | 0 (0.0%) | N=120; 4 distinct; max length 6; values withheld (datesafe) |")
    mata: _v200c_line("| {bq}s_mdy2{bq} |  | str30 | 0 (0.0%) | N=120; 6 distinct; max length 7; values withheld (datesafe) |")
    mata: _v200c_line("| {bq}s_born{bq} |  | str30 | 0 (0.0%) | N=120; 6 distinct; max length 16; values withheld (datesafe) |")
    mata: _v200c_line("| {bq}s_wk{bq} |  | str30 | 0 (0.0%) | N=120; 6 distinct; max length 11; values withheld (datesafe) |")
    mata: _v200c_in("| {bq}s_fw{bq} |  | str30 | 0 (0.0%) | N=120; 6 distinct; ", 1)
    mata: _v200c_in("; values withheld (datesafe) |", 1)
    mata: _v200c_in("２０２０", 0)
    mata: _v200c_line("| {bq}s_code{bq} |  | str30 | 0 (0.0%) | N=120; 6 distinct; max length 2; values withheld (datesafe) |")
    mata: _v200c_line("| {bq}s_sex{bq} |  | str30 | 0 (0.0%) | N=120; 2 distinct; max length 6; values " + char(34) + "Female" + char(34) + " 60, " + char(34) + "Male" + char(34) + " 60 |")
    * no listed value of a digit-bearing text variable reaches the file
    mata: _v200c_in(" 10:30", 0)
    mata: _v200c_in("2020-0", 0)
    mata: _v200c_in("2020Q", 0)
    mata: _v200c_in("/20" + char(34), 0)
    mata: _v200c_in("born ", 0)
    mata: _v200c_in("Jan 2020", 0)
    mata: _v200c_in(char(34) + "A1" + char(34), 0)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: C11 string profile under datesafe (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: C11 string profile under datesafe"'
}

**# C12 F3 under nofreq

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 100
    generate byte q = 1 + mod(_n, 3)
    quietly replace q = .a in 1/20
    quietly replace q = .b in 21/30
    label define c12q .a "Refused" .b "Not asked"
    label values q c12q
    quietly count if q == .a
    assert r(N) == 20
    quietly datamap, output(c12a.md)
    mata: _v200c_slurp("c12a.md", "t")
    mata: _v200c_in("| {bq}q{bq} |  | byte | 30 (30.0%): .a Refused 20, .b Not asked 10 | ", 1)
    quietly datamap, output(c12b.md) nofreq
    mata: _v200c_slurp("c12b.md", "t")
    mata: _v200c_line("| {bq}q{bq} |  | byte | 30 (30.0%) | 3 distinct |")
    mata: _v200c_in("Refused", 0)
    quietly datamap, output(c12c.md) nofreq compact
    mata: _v200c_slurp("c12c.md", "t")
    mata: _v200c_in("| 30 (30.0%) | 3 |", 1)
    mata: _v200c_in("Refused", 0)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: C12 missing breakdown under nofreq (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: C12 missing breakdown under nofreq"'
}

**# C13 F4: counting by sort above 24 distinct values

capture noisily {
    quietly cd "`work'/run"
    * value k held by k + 5 rows: 30 values (sorted) and 20 (matched)
    foreach d in 30 20 {
        clear
        quietly set obs `=`d' * (`d' + 11) / 2'
        generate int k = 0
        local r = 0
        forvalues j = 1/`d' {
            quietly replace k = `j' in `=`r' + 1'/`=`r' + `j' + 5'
            local r = `r' + `j' + 5
        }
        generate str3 s = "v" + string(k)
        drop k
        local exp ""
        local sep ""
        forvalues j = `d'(-1)`=`d' - 4' {
            quietly count if s == "v`j'"
            assert r(N) == `j' + 5
            local exp `"`exp'`sep'"v`j'" `=r(N)'"'
            local sep ", "
        }
        quietly datamap, output(c13_`d'.md) mincell(0) maxcat(50)
        mata: _v200c_slurp("c13_`d'.md", "t")
        mata: _v200c_line("| {bq}s{bq} |  | str3 | 0 (0.0%) | N=" + strofreal(`d' * (`d' + 11) / 2) + "; `d' distinct; max length 3; values " + st_local("exp") + ", others |")
    }
    * above maxcat(): no values are listed
    quietly datamap, output(c13c.md) mincell(0) maxcat(10)
    mata: _v200c_slurp("c13c.md", "t")
    mata: _v200c_line("| {bq}s{bq} |  | str3 | 0 (0.0%) | N=310; 20 distinct; max length 3 |")
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: C13 string value counts by sort (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: C13 string value counts by sort"'
}

sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_datamap_v200_content tests=`tests' pass=`pass' fail=`fail'"
log close main
if `fail' exit 1
