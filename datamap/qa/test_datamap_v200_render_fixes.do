*! test_datamap_v200_render_fixes.do Version 1.0.0  2026/11/10
*! datamap 2.0.0 Phase 2 review fixes in the Markdown renderer: numeric
*! levels never print through a lossy display format, notes and
*! characteristics print whole, percentages round half up exactly, and the
*! sample-row cells carry the same escape as every other cell; repair round
*! (R5-R11): append numbering, empty format()/datevars(), control bytes,
*! zero-observation Missing cell, statistic magnitude carry, pattern
*! suppression against the Missing column, config missing = yes|no;
*! repair round 2 (R12-R13): Missing cell and N= under mincell(), one
*! number of decimals per IQR/range pair; repair round 3 (R14): an exact
*! zero takes its statistics cell's decimals; Phase 6 (R15-R16): one
*! missing-code row or one missingness pattern no longer aborts the run
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_datamap_v200_render_fixes.log", replace text name(main)
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
* tempfile names repeat across suites in one runner session: own suffix
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

* the whole text of file `1' into local `2' (Mata: a Markdown line holds
* backticks, which a Stata line reader would expand)
capture mata: mata drop _v200r_slurp()
capture mata: mata drop _v200r_in()
capture mata: mata drop _v200r_onewithheld()
capture mata: mata drop _v200r_split()
capture mata: mata drop _v200r_lines()
mata:
void _v200r_slurp(string scalar path, string scalar dst)
{
	real scalar fh
	string scalar s, l
	fh = fopen(path, "r")
	s = ""
	while ((l = fget(fh)) != J(0, 0, "")) s = s + l + char(10)
	fclose(fh)
	st_local(dst, s)
}
// the lines of t (split at line feeds; Mata tokens() would bind quotes)
string colvector _v200r_split(string scalar t)
{
	string colvector L
	real scalar j
	L = J(0, 1, "")
	while ((j = strpos(t, char(10))) > 0) {
		L = L \ substr(t, 1, j - 1)
		t = substr(t, j + 1, .)
	}
	if (t != "") L = L \ t
	return(L)
}
// how many lines of t start with prefix
real scalar _v200r_lines(string scalar t, string scalar prefix)
{
	string colvector L
	L = _v200r_split(t)
	return(sum(substr(L, 1, strlen(prefix)) :== prefix))
}
// no variable's margin (its position in the patterns) holds exactly one
// withheld pattern line ("  - `p`: suppressed ..."), k variables
void _v200r_onewithheld(string scalar t, real scalar k)
{
	string colvector L
	string scalar p
	real scalar i, j, n
	L = _v200r_split(t)
	for (j = 1; j <= k; j++) {
		n = 0
		for (i = 1; i <= rows(L); i++) {
			if (substr(L[i], 1, 5) != "  - " + char(96)) continue
			if (!strpos(L[i], ": suppressed")) continue
			p = substr(L[i], 6, k)
			if (substr(p, j, 1) == ".") n++
		}
		if (n == 1) {
			errprintf("variable %g: one withheld pattern in its margin\n", j)
			exit(9)
		}
	}
}
// local t holds needle ({bq} = a backtick) when want is 1, does not when 0
void _v200r_in(string scalar needle, real scalar want)
{
	real scalar has
	has = (strpos(st_local("t"), subinstr(needle, "{bq}", char(96))) > 0)
	if (has != want) {
		errprintf("text check failed (want %g): %s\n", want, needle)
		exit(9)
	}
}
end

**# R1 numeric levels never print through a lossy display format
* 2026-11-10 (review must-fix): a categorical level printed in its variable's
* display format, so 1234567890 and 1234567891 at %8.0g both printed
* 1.2e+09, and the floats 0.2 0.4 0.6 at %9.0f printed 0 0 1 at rc 0.  A
* display format now prints a level only when it reads back as the level;
* otherwise the level prints at full (double) or float precision.

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 60
    generate double big = 1234567890 + mod(_n, 2)
    format big %8.0g
    generate float f = 0.2 * (1 + mod(_n, 3))
    format f %9.0f
    generate float g = cond(mod(_n, 3) == 0, -0.7, cond(mod(_n, 3) == 1, 123.456789, 16777216))
    generate byte b = mod(_n, 3)
    generate double cm = 1500 + mod(_n, 2)
    format cm %9.2fc
    generate double dd = td(01jan2020) + mod(_n, 3)
    format dd %td
    generate long l = 2000000000 + mod(_n, 2)
    format l %6.0g
    label define r1l 2000000000 "two bn"
    label values l r1l
    quietly datamap, output(r1.md) mincell(0) categorical(big f g b cm dd l) ///
        columns(variable values)
    mata: _v200r_slurp("r1.md", "t")
    * distinct levels print distinctly, as the numbers they are
    mata: _v200r_in("1234567890: 30 (50.0%)<br>1234567891: 30 (50.0%)", 1)
    mata: _v200r_in("1.2e+09", 0)
    mata: _v200r_in(".2: 20 (33.3%)<br>.4: 20 (33.3%)<br>.6: 20 (33.3%)", 1)
    * a float level prints as its shortest decimal, never its binary noise
    mata: _v200r_in("-.7: 20 (33.3%)<br>123.45679: 20 (33.3%)<br>16777216: 20 (33.3%)", 1)
    mata: _v200r_in("69999", 0)
    * label beside an exactly printed value
    mata: _v200r_in("2000000000 two bn: 30 (50.0%)<br>2000000001: 30 (50.0%)", 1)
    * a lossless display format and the date format still print as before
    mata: _v200r_in("1,500.00: 30 (50.0%)<br>1,501.00: 30 (50.0%)", 1)
    mata: _v200r_in("0: 20 (33.3%)<br>1: 20 (33.3%)<br>2: 20 (33.3%)", 1)
    mata: _v200r_in("2020/01/01: 20 (33.3%)", 1)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R1 numeric levels never print through a lossy display format (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R1 numeric levels never print through a lossy display format"'
}

**# R2 notes and characteristics print whole; saving() keeps its 2045-byte cut
* 2026-11-10 (review should-fix): the variables frame cut every text cell to
* 2045 bytes on entry, so a variable's notes past that point vanished from
* the document with no mark.  The frame now keeps notes and characteristics
* whole; saving() still writes them as str2045, cut on a character boundary.
* An excluded variable's notes and characteristics stay withheld.

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 30
    generate x = _n
    generate secret = _n
    local blk ""
    forvalues i = 1/60 {
        local blk "`blk' word`i'_abcdefghijklmnopqrstuvwxyz0123456789"
    }
    note x: short note
    note x: A`blk'
    note x: B`blk'
    note x: C`blk'é
    char x[longchar] Z`blk'
    note secret: HIDDENNOTE`blk'
    char secret[hid] HIDDENCHAR`blk'
    quietly datamap, output(r2.md) exclude(secret) columns(variable notes chars) ///
        saving(r2, replace)
    mata: _v200r_slurp("r2.md", "t")
    * each note whole: the third ~2.3 KB note and its last word are there
    mata: _v200r_in("<br>C word1_", 1)
    mata: _v200r_in("word60_abcdefghijklmnopqrstuvwxyz0123456789é |", 1)
    mata: _v200r_in("| longchar=Z word1_", 1)
    mata: st_local("nlen", strofreal(strlen(st_local("t"))))
    assert `nlen' > 10000
    * privacy: nothing of the excluded variable's notes or characteristics
    mata: _v200r_in("HIDDENNOTE", 0)
    mata: _v200r_in("HIDDENCHAR", 0)
    mata: _v200r_in("| {bq}secret{bq} |  |  |", 1)
    * saving(): str2045, cut to 2045 bytes on a UTF-8 boundary, as before
    quietly use "r2.dta", clear
    confirm str2045 variable notes characteristics
    quietly keep if variable == "x"
    assert _N == 1
    mata: assert(strlen(st_sdata(1, "notes")) == 2045)
    mata: assert(strlen(st_sdata(1, "characteristics")) == 2045)
    mata: assert(substr(st_sdata(1, "notes"), 1, 15) == "short note<br>A")
    quietly use "r2.dta", clear
    quietly keep if variable == "secret"
    assert notes == "" & characteristics == ""
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R2 notes and characteristics print whole; saving() keeps its cut (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R2 notes and characteristics print whole; saving() keeps its cut"'
}

**# R3 percentages round half up to 0.1 exactly
* 2026-11-10 (review should-fix): round(share, 0.1) split decimal ties on
* binary noise (N = 2000: 3 -> 0.1%, 5 -> 0.3%, 7 -> 0.3%, 19 -> 0.9%).  Every
* tie below rounds up: the level shares, the Missing column and the
* complete-rows line.

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 2000
    generate int g = 1
    quietly replace g = 2 in 1/3
    quietly replace g = 3 in 4/8
    quietly replace g = 4 in 9/15
    quietly replace g = 5 in 16/34
    generate m3 = 1
    quietly replace m3 = . in 1/3
    generate m7 = 1
    quietly replace m7 = . in 1/7
    generate m19 = 1
    quietly replace m19 = . in 1982/2000
    quietly datamap, output(r3.md) mincell(0) categorical(g) missing(detail) ///
        columns(variable missing values)
    mata: _v200r_slurp("r3.md", "t")
    mata: _v200r_in("<br>2: 3 (0.2%)<br>3: 5 (0.3%)<br>4: 7 (0.4%)<br>5: 19 (1.0%) |", 1)
    mata: _v200r_in("| {bq}m3{bq} | 3 (0.2%) |", 1)
    mata: _v200r_in("| {bq}m7{bq} | 7 (0.4%) |", 1)
    mata: _v200r_in("| {bq}m19{bq} | 19 (1.0%) |", 1)
    * rows 1-7 and 1982-2000 are incomplete: 26 of 2000, complete 1974 = 98.7%;
    * 1997 complete (three incomplete) is the tie 99.85 -> 99.9
    mata: _v200r_in("- Complete rows: 1974 (98.7%)", 1)
    quietly drop m7 m19
    quietly datamap, output(r3b.md) mincell(0) missing(detail) columns(variable missing)
    mata: _v200r_slurp("r3b.md", "t")
    mata: _v200r_in("- Complete rows: 1997 (99.9%)", 1)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R3 percentages round half up to 0.1 exactly (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R3 percentages round half up to 0.1 exactly"'
}

**# R4 sample-row cells carry the same escape as every other cell
* 2026-11-10 (review should-fix): the sample-row escape lacked the "' rule of
* the other three copies, so a value a"'b reached the file raw, and a Stata
* reader using `"`line'"' in an expression stopped at rc 132 on that line.

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 3
    generate str12 s = char(97) + char(34) + char(39) + "b"
    quietly datamap, output(r4.md) samples(2) columns(variable values)
    mata: _v200r_slurp("r4.md", "t")
    * the sample cell is a"&#39;b, and no raw "' is left anywhere
    mata: _v200r_in("| a" + char(34) + "&#39;b |", 1)
    mata: _v200r_in(char(34) + char(39), 0)
    * every backtick-free line reads through a Stata expression intact
    file open fh using "r4.md", read text
    local nread = 0
    file read fh line
    while r(eof) == 0 {
        mata: st_local("hasbq", strofreal(strpos(st_local("line"), char(96)) > 0))
        if !`hasbq' {
            local L = strlen(`"`line'"')
            mata: assert(strlen(st_local("line")) == `L')
            local ++nread
        }
        file read fh line
    }
    file close fh
    assert `nread' >= 4
}
local rc = _rc
capture file close fh
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R4 sample-row cells carry the same escape as every other cell (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R4 sample-row cells carry the same escape as every other cell"'
}

**# R5 append continues the section numbers
* 2026-11-10 (Phase 2 repair; review note 6): an appended section was headed
* "## 1." again, repeating the first heading and its anchor.

capture noisily {
    quietly cd "`work'/run"
    sysuse auto, clear
    capture erase r5.md
    quietly datamap, output(r5.md)
    quietly datamap, output(r5.md) append
    quietly datamap, output(r5.md) append
    mata: _v200r_slurp("r5.md", "t")
    mata: _v200r_in("## 1. Data in memory", 1)
    mata: _v200r_in("## 2. Data in memory", 1)
    mata: _v200r_in("## 3. Data in memory", 1)
    * "## 1. " heads exactly one line (the file starts with it)
    mata: st_local("n1", strofreal(_v200r_lines(st_local("t"), "## 1. ")))
    assert `n1' == 1
    * a fresh run without append starts at 1 again
    quietly datamap, output(r5.md)
    mata: _v200r_slurp("r5.md", "t")
    mata: _v200r_in("## 1. Data in memory", 1)
    mata: _v200r_in("## 2. ", 0)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R5 append continues the section numbers (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R5 append continues the section numbers"'
}

**# R6 format() and datevars() with empty parentheses stop like the named forms
* 2026-11-10 (Phase 2 repair; review note 7): -syntax- leaves format() as
* empty as an option not given, so both ran at rc 0.  The same removed-option
* message and rc 198 as format(json) / datevars(x), and no file.  Text that
* merely contains "format()" inside another option stays legal.

capture noisily {
    quietly cd "`work'/run"
    sysuse auto, clear
    foreach o in "format()" "format( )" "f()" "datevars()" "datev()" {
        capture erase r6.md
        capture datamap price, output(r6.md) `o'
        assert _rc == 198
        confirm new file r6.md
    }
    * the exact message, read from a side log (the suite log is paused)
    capture erase r6.md
    log off main
    quietly log using r6msg.log, text replace name(r6msg)
    capture noisily datamap price, output(r6.md) format()
    local r6rc = _rc
    capture noisily datamap price, output(r6.md) datevars()
    local r6rc2 = _rc
    quietly log close r6msg
    log on main
    assert `r6rc' == 198 & `r6rc2' == 198
    mata: _v200r_slurp("r6msg.log", "t")
    mata: _v200r_in("format() was removed in 2.0.0: datamap writes Markdown; use saving() for a machine-readable table", 1)
    mata: _v200r_in("datevars() was removed in 2.0.0: use date() to classify variables as dates", 1)
    capture erase r6t.md
    quietly datamap price, output(r6t.md) title("format() datevars()") notes(`"see "format()" here"')
    confirm file r6t.md
    quietly datamap price, output(r6u.md) missing(detail)
    confirm file r6u.md
}
local rc = _rc
capture log close r6msg
capture log on main
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R6 format() and datevars() with empty parentheses stop (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R6 format() and datevars() with empty parentheses stop"'
}

**# R7 control bytes in labels are written as spaces
* 2026-11-10 (Phase 2 repair): only line breaks were folded; a tab, CHR(1) or
* DEL in a variable or value label reached the table cell raw.

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 10
    generate byte x = mod(_n, 2)
    label variable x "a`=char(1)'b`=char(9)'c`=char(127)'d"
    label define r7l 0 "no`=char(9)'pe" 1 "y`=char(2)'es"
    label values x r7l
    quietly datamap, output(r7.md) mincell(0)
    mata: _v200r_slurp("r7.md", "t")
    mata: _v200r_in("| a b c d |", 1)
    mata: _v200r_in("0 no pe: 5 (50.0%)<br>1 y es: 5 (50.0%)", 1)
    * no byte below 32 but the line feeds, and no DEL
    mata: st_local("nctl", strofreal(sum((ascii(st_local("t")) :< 32 :& ascii(st_local("t")) :!= 10) :| (ascii(st_local("t")) :== 127))))
    assert `nctl' == 0
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R7 control bytes in labels are written as spaces (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R7 control bytes in labels are written as spaces"'
}

**# R8 zero observations: the Missing cell has no percent
* 2026-11-10 (Phase 2 repair): it read "0 (.%)".

capture noisily {
    quietly cd "`work'/run"
    sysuse auto, clear
    quietly drop in 1/l
    quietly datamap, output(r8.md)
    mata: _v200r_slurp("r8.md", "t")
    mata: _v200r_in("| {bq}price{bq} | Price | int | 0 | No observations |", 1)
    mata: _v200r_in(".%", 0)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R8 zero observations: the Missing cell has no percent (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R8 zero observations: the Missing cell has no percent"'
}

**# R9 a statistic that rounds into the next magnitude prints by its rule
* 2026-11-10 (Phase 2 repair): the magnitude rule (3 decimals below 1, 2
* from 1, none from 100) chose the class before rounding, so 0.99975
* printed "1.000" and 99.99625 "100.00".  Means: (0.9996+...+0.9999)/4 =
* 0.99975 and 99.996 + (1+2+3+4)/40000 = 99.99625.

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 4
    generate double v = 0.9995 + _n / 10000
    generate double w = 99.996 + _n / 10000
    quietly datamap, output(r9.md) continuous(v w) mincell(0)
    mata: _v200r_slurp("r9.md", "t")
    mata: _v200r_in("N=4; mean=1.00; SD=", 1)
    mata: _v200r_in("N=4; mean=100; SD=", 1)
    mata: _v200r_in("1.000", 0)
    mata: _v200r_in("100.00", 0)
    * a pair whose ends print alike keeps eight significant digits
    mata: _v200r_in("range=.9996-.9999", 1)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R9 a statistic that rounds into the next magnitude prints by its rule (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R9 a statistic that rounds into the next magnitude prints by its rule"'
}

**# R10 a suppressed pattern cannot be read off the Missing column
* 2026-11-10 (Phase 2 repair; golden read, g2): complementary suppression of
* the missing-value patterns pooled against the total only.  The Missing
* column prints each variable's missing count, the sum of the patterns with
* "." in its place, so with patterns +++ 79, ++. 6, ..+ 6, +.+ 5, .++ 4 the
* document printed .++ "suppressed (<5)" beside a's 10 and ..+ 6: 10 - 6 = 4.
* Derivation of the expected lines: a's margin {..+, .++} and b's {..+, +.+}
* must each hold two withheld cells, so ..+ and +.+ are withheld; then the
* withheld {..+, +.+, .++} meet three independent equations (total 15, a 10,
* b 11) and are solved, so one more cell joins: ++. is pinned by c's margin
* (its only cell), so the complete-rows cell +++ is the one that frees .++
* (null vector +++ +t, ..+ +t, +.+ -t, .++ -t).
* Generic check: no variable's margin holds exactly one withheld pattern.

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 100
    generate double a = 1
    generate double b = 1
    generate double c = 1
    quietly replace c = . in 80/85
    quietly replace a = . in 86/91
    quietly replace b = . in 86/91
    quietly replace b = . in 92/96
    quietly replace a = . in 97/100
    quietly datamap, output(r10.md) missing(pattern)
    mata: _v200r_slurp("r10.md", "t")
    mata: _v200r_in("| {bq}a{bq} |  | double | 10 (10.0%) |", 1)
    mata: _v200r_in("- Complete rows: suppressed (complementary)", 1)
    mata: _v200r_in("  - {bq}+++{bq}: suppressed (complementary)", 1)
    mata: _v200r_in("  - {bq}++.{bq}: 6 (6.0%)", 1)
    mata: _v200r_in("  - {bq}..+{bq}: suppressed (complementary)", 1)
    mata: _v200r_in("  - {bq}+.+{bq}: suppressed (complementary)", 1)
    mata: _v200r_in("  - {bq}.++{bq}: suppressed (<5)", 1)
    mata: _v200r_onewithheld(st_local("t"), 3)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R10 a suppressed pattern cannot be read off the Missing column (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R10 a suppressed pattern cannot be read off the Missing column"'
}

**# R11 config() missing = yes|no names the removed datadict switch
* 2026-11-10 (Phase 2 repair): it stopped with missing()'s "must be 'detail'
* or 'pattern'" message, which named no config key.  Still rc 198.

capture noisily {
    quietly cd "`work'/run"
    sysuse auto, clear
    foreach val in yes no {
        tempname fh
        file open `fh' using "r11.cfg", write replace text
        file write `fh' "missing = `val'" _n
        file close `fh'
        capture erase r11.md
        log off main
        quietly log using r11msg.log, text replace name(r11msg)
        capture noisily datamap, config(r11.cfg) output(r11.md)
        local r11rc = _rc
        quietly log close r11msg
        log on main
        assert `r11rc' == 198
        confirm new file r11.md
        mata: _v200r_slurp("r11msg.log", "t")
        mata: _v200r_in("config(): missing = `val' was datadict's Missing-column switch, removed in 2.0.0", 1)
    }
    * the user's missing() wins over the config key
    quietly datamap, config(r11.cfg) output(r11.md) missing(detail)
    confirm file r11.md
}
local rc = _rc
capture file close _all
capture log close r11msg
capture log on main
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R11 config() missing = yes|no names the removed datadict switch (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R11 config() missing = yes|no names the removed datadict switch"'
}

**# R12 the Missing cell and N= follow mincell() like any other cell
* 2026-11-10 (Phase 2 repair round 2; p2rev NOTE 5, p2qa2 issue 4): the
* Missing cell printed every missing count and N= every nonmissing count, so
* 1,000 rows with 3 observed printed "997 (99.7%)" beside "1: suppressed
* (<5)" (1000 - 997 = 3), and N=3 / "3 (0.3%)" printed outright.  The two
* parts of N are each other's complement; for a listed categorical the
* Missing total is one more cell of the level mask.  Expected cells derived
* by hand: k2 (3 missing, 499/498) withholds Missing (<5) and the smaller
* level 498 as its complement; two (996 missing, levels 2 and 2, pooled
* 4 < 5) withholds Missing as the complement; lone (6 observed) and k3
* (7 missing) print.  mincell(0) prints every count again.

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 1000
    generate a = cond(_n <= 3, 1, .)
    quietly datamap, output(r12a.md) missing(pattern)
    mata: _v200r_slurp("r12a.md", "t")
    mata: _v200r_in("| {bq}a{bq} |  | float | suppressed (complementary) | 1: suppressed (<5) |", 1)
    mata: _v200r_in("997 (", 0)
    * one observation, nothing missing: a one-row level block must not read
    * as a withheld Missing total (Mata selectindex() on a 1x1 argument)
    clear
    quietly set obs 1
    generate x = 42
    quietly datamap, output(r12e.md)
    mata: _v200r_slurp("r12e.md", "t")
    mata: _v200r_in("| {bq}x{bq} |  | float | 0 (0.0%) | 42: suppressed (<5) |", 1)
    clear
    quietly set obs 1000
    generate double c = cond(_n <= 3, _n * 1.5, .)
    generate s = cond(_n <= 3, "x" + string(_n), "")
    generate d = cond(_n <= 3, td(01jan2020) + _n, .)
    format d %td
    generate double m = cond(_n <= 3, ., _n)
    generate byte k2 = cond(_n <= 3, ., mod(_n, 2))
    generate byte k3 = cond(_n <= 7, ., cond(_n <= 10, 1, cond(_n <= 22, 2, 3)))
    generate byte lone = cond(_n <= 6, 1, .)
    generate byte two = cond(_n <= 2, 1, cond(_n <= 4, 2, .))
    quietly datamap, output(r12b.md) continuous(c m) categorical(k2 k3 lone two)
    mata: _v200r_slurp("r12b.md", "t")
    mata: _v200r_in("| {bq}c{bq} |  | double | suppressed (complementary) | N=suppressed (<5); ", 1)
    mata: _v200r_in("| {bq}s{bq} |  | str2 | suppressed (complementary) | N=suppressed (<5); 3 distinct", 1)
    * 2026-11-10 (2.0.0 Phase 3, U4): the Type column names the date family
    mata: _v200r_in("| {bq}d{bq} |  | float %td daily | suppressed (complementary) | N=suppressed (<5); range", 1)
    mata: _v200r_in("| {bq}m{bq} |  | double | suppressed (<5) | N=suppressed (complementary); mean=", 1)
    mata: _v200r_in("| {bq}k2{bq} |  | byte | suppressed (<5) | 0: 499 (49.9%)<br>1: suppressed (complementary) |", 1)
    mata: _v200r_in("| {bq}k3{bq} |  | byte | 7 (0.7%) | 1: suppressed (<5)<br>2: suppressed (complementary)<br>3: 978 (97.8%) |", 1)
    mata: _v200r_in("| {bq}lone{bq} |  | byte | 994 (99.4%) | 1: 6 (0.6%) |", 1)
    mata: _v200r_in("| {bq}two{bq} |  | byte | suppressed (complementary) | 1: suppressed (<5)<br>2: suppressed (<5) |", 1)
    mata: _v200r_in("N=3;", 0)
    mata: _v200r_in("N=997;", 0)
    mata: _v200r_in("| 3 (0.3%) |", 0)
    mata: _v200r_in("| 997 (99.7%) |", 0)
    * compact (no values column): the same Missing cells
    quietly datamap, output(r12c.md) continuous(c m) categorical(k2 k3 lone two) compact
    mata: _v200r_slurp("r12c.md", "t")
    mata: _v200r_in("| {bq}c{bq} | double |  | suppressed (complementary) |", 1)
    mata: _v200r_in("| {bq}k2{bq} | byte |  | suppressed (<5) |", 1)
    * mincell(0): every count printed
    quietly datamap, output(r12d.md) continuous(c m) categorical(k2 k3 lone two) mincell(0)
    mata: _v200r_slurp("r12d.md", "t")
    mata: _v200r_in("| {bq}c{bq} |  | double | 997 (99.7%) | N=3; ", 1)
    mata: _v200r_in("| {bq}k2{bq} |  | byte | 3 (0.3%) | 0: 499 (49.9%)<br>1: 498 (49.8%) |", 1)
    mata: _v200r_in("suppressed", 0)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R12 the Missing cell and N= follow mincell() like any other cell (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R12 the Missing cell and N= follow mincell() like any other cell"'
}

**# R13 both ends of an IQR or range print with one number of decimals
* 2026-11-10 (Phase 2 repair round 2; p2qa2 issue 5, golden read): the
* magnitude classes split a pair: "range=0-1.00" (0/1 flag), "range=1.00-100"
* (id 1..100), "IQR=-224 to -73.50" (the -224 was -223.5 printed in the
* integer class).  Now the finer of the two decimal counts
* (a zero end takes the other's); scientific ends keep their own form; the
* print-alike fallback pads %g's dropped zeros (100.004-100.24).

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 60
    generate byte flag = _n <= 3
    generate double id = _n * 100 / 60
    generate double neg = -300 + 3 * _n
    generate double near = 100 + _n / 250
    generate double tiny = _n * 1e-5
    quietly datamap, output(r13.md) continuous(flag id neg near tiny) mincell(0)
    mata: _v200r_slurp("r13.md", "t")
    * 2026-11-10 (repair round 3): the flag cell pinned "median=0; IQR=0-0;
    * range=0.00-1.00", the bare zeros that round left; the exact zeros now
    * take the cell's decimals (R14).  The pair intent (one number of
    * decimals per range) is unchanged.
    mata: _v200r_in("N=60; mean=0.050; SD=0.220; median=0.000; IQR=0.000-0.000; range=0.000-1.000 |", 1)
    mata: _v200r_in("range=1.67-100.00 |", 1)
    mata: _v200r_in("IQR=-254 to -164; range=-297 to -120 |", 1)
    mata: _v200r_in("IQR=100.062-100.182; range=100.004-100.240 |", 1)
    mata: _v200r_in("IQR=1.55e-04 to 4.55e-04; range=1.00e-05 to 6.00e-04 |", 1)
    mata: _v200r_in("range=0-1.00", 0)
    clear
    quietly set obs 100
    generate double neg = -300 + 3 * _n
    quietly datamap, output(r13b.md) continuous(neg) mincell(0)
    mata: _v200r_slurp("r13b.md", "t")
    mata: _v200r_in("IQR=-223.50 to -73.50", 1)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R13 both ends of an IQR or range print with one number of decimals (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R13 both ends of an IQR or range print with one number of decimals"'
}

**# R14 an exact zero prints with the decimals of its statistics cell
* 2026-11-10 (Phase 2 repair round 3; p2qa2 issue 5, p2v2 item 3): a zero
* printed bare beside the cell's decimals ("mean=0.050; SD=0.220; median=0;
* IQR=0-0").  An exact zero now takes the finest decimal count among the
* cell's nonzero statistics; a cell with none (all zero, integer class,
* scientific) keeps a bare 0.  A withheld mean/SD does not set the decimals.

capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 60
    generate byte flag = _n <= 3
    generate double cnt = cond(_n <= 40, 0, _n - 40.5)
    generate double big = cond(_n <= 40, 0, 1000 + _n)
    generate double allz = 0
    generate double tiny = cond(_n <= 40, 0, _n * 1e-5)
    quietly datamap, output(r14.md) continuous(flag cnt big allz tiny) mincell(0)
    mata: _v200r_slurp("r14.md", "t")
    mata: _v200r_in("N=60; mean=0.050; SD=0.220; median=0.000; IQR=0.000-0.000; range=0.000-1.000 |", 1)
    mata: _v200r_in("N=60; mean=3.33; SD=5.82; median=0.00; IQR=0.00-5.00; range=0.00-19.50 |", 1)
    mata: _v200r_in("N=60; mean=350; SD=499; median=0; IQR=0-1,046; range=0-1,060 |", 1)
    mata: _v200r_in("N=60; mean=0; SD=0; median=0; IQR=0-0; range=0-0 |", 1)
    mata: _v200r_in("median=0; IQR=0 to 4.55e-04; range=0 to 6.00e-04 |", 1)
    mata: _v200r_in("median=0; IQR=0-0; range=0.00", 0)
    * default mincell: the mean and SD of a two-valued variable are withheld,
    * the zeros take the quantiles' decimals
    clear
    quietly set obs 60
    generate byte flag = _n <= 3
    quietly datamap, output(r14b.md) continuous(flag)
    mata: _v200r_slurp("r14b.md", "t")
    mata: _v200r_in("mean and SD withheld (mincell; two or three values); median=0.00; IQR=0.00-0.00; range=0.00-1.00 |", 1)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R14 an exact zero prints with the decimals of its statistics cell (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R14 an exact zero prints with the decimals of its statistics cell"'
}

**# R15 one missing-code row on a categorical whose levels are not listed
* 2026-11-10 (Phase 6 review fix): _dmv_values read rows() of a
* selectindex() of a 1 x 1, which is 1 x 0 (rows 1), and stopped the whole
* run with r(3301), no document written, at default options: a labelled
* variable with more than maxfreq() values and only "." missing.
capture noisily {
    quietly cd "`work'/run"
    clear
    quietly set obs 100
    generate byte county = ceil(_n / 2.5)
    forvalues i = 1/40 {
        label define r15l `i' "County `i'", add
    }
    label values county r15l
    quietly replace county = . in 1/3
    quietly datamap, output(r15.md) saving(r15, replace)
    mata: _v200r_slurp("r15.md", "t")
    mata: _v200r_in("| {bq}county{bq} |  | byte | suppressed (<5) | 39 distinct; frequencies not listed (more than maxfreq(25)) |", 1)
    use r15, clear
    assert missing == 3 & unique == 39 if variable == "county"
    * maxfreq() below the level count, and maxcat() above 25
    sysuse auto, clear
    forvalues k = 1/3 {
        quietly datamap rep78, output(r15b.md) maxfreq(`k')
        mata: _v200r_slurp("r15b.md", "t")
        mata: _v200r_in("| {bq}rep78{bq} | Repair record 1978 | int | 5 (6.8%) | 5 distinct; frequencies not listed (more than maxfreq(`k')) |", 1)
    }
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R15 one missing-code row on an unlisted categorical (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R15 one missing-code row on an unlisted categorical"'
}

**# R16 one missingness pattern
* 2026-11-10 (Phase 6 review fix): missing(pattern) on data whose rows all
* share one pattern, fewer than mincell() rows, stopped with r(3200) in
* _dms_patmargin/_dms_patviol (selectindex() of a 1 x 1 false is 1 x 0, and
* c[J(0,1,.)] of a 1 x 1 is 1 x 0).  In a directory() or filelist() run
* one such file aborted the whole document.
capture noisily {
    quietly cd "`work'/run"
    forvalues n = 1/6 {
        clear
        quietly set obs `n'
        generate byte x = .
        generate byte y = 1
        quietly datamap, output(r16.md) missing(pattern)
        mata: _v200r_slurp("r16.md", "t")
        mata: _v200r_in("over {bq}x{bq}: 1 distinct", 1)
        if `n' < 5 mata: _v200r_in("  - {bq}.{bq}: suppressed (<5)", 1)
        else mata: _v200r_in("  - {bq}.{bq}: `n' (100.0%)", 1)
    }
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error `"FAIL: R16 one missingness pattern (rc=`rc')"'
}
else {
    local ++pass
    display as result `"PASS: R16 one missingness pattern"'
}

sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_datamap_v200_render_fixes tests=`tests' pass=`pass' fail=`fail'"
log close main
if `fail' exit 1
