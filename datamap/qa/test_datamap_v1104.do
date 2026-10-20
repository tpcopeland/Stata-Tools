clear all
set more off
version 16.0
set linesize 255

* test_datamap_v1104.do - regressions for the review of the 1.10.3 fixes
* (findings R1-R7 and the groupstat scope item S1).  Each test names its
* finding.  Every test was red on 1.10.3 except where a comment says it is
* a guard.

local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard

local test_count = 0
local pass_count = 0
local fail_count = 0

local W "`c(tmpdir)'/v1104"
capture mkdir "`W'"
macro drop DATAMAP_DQ

* number of lines of a text file that contain a string
capture program drop _v4_count
program define _v4_count, rclass
    args file needle
    mata: _v4_count_m(st_local("file"), st_local("needle"), 0)
    return scalar n = scalar(_v4_cnt)
    scalar drop _v4_cnt
end

* number of lines equal to a string once blanks are trimmed and runs of
* blanks collapsed (a table row such as "1   30" reads "1 30")
capture program drop _v4_eq
program define _v4_eq, rclass
    args file needle
    mata: _v4_count_m(st_local("file"), st_local("needle"), 1)
    return scalar n = scalar(_v4_cnt)
    scalar drop _v4_cnt
end

* rows of the table under the first line that starts with `head': r(n) rows
* (group and pooled lines), r(bad) of them not exactly `w' characters long
* (a cell wider than its column pushes the line past the width)
capture program drop _v4_width
program define _v4_width, rclass
    args file head w
    mata: _v4_width_m(st_local("file"), st_local("head"), `w')
    return scalar n = scalar(_v4_n)
    return scalar bad = scalar(_v4_bad)
    scalar drop _v4_n _v4_bad
end

mata:
void _v4_count_m(string scalar f, string scalar nd, real scalar exact)
{
	real scalar fh, n
	string scalar line
	n = 0
	fh = fopen(f, "r")
	while ((line = fget(fh)) != J(0, 0, "")) {
		if (exact) {
			if (stritrim(strtrim(line)) == nd) n++
		}
		else if (strpos(line, nd) > 0) n++
	}
	fclose(fh)
	st_numscalar("_v4_cnt", n)
}
void _v4_width_m(string scalar f, string scalar hd, real scalar w)
{
	real scalar fh, on, n, bad, row
	string scalar line
	on = 0
	n = 0
	bad = 0
	row = 0
	fh = fopen(f, "r")
	while ((line = fget(fh)) != J(0, 0, "")) {
		if (on == 1) {
			// the table ends at a blank line or the next echoed command
			if (strtrim(line) == "" | substr(line, 1, 1) == ".") on = 2
			else {
				row++
				// the column header row and the small-group line are text
				if (row > 1 & substr(strtrim(line), 1, 6) != "groups") {
					n++
					if (ustrlen(line) != w) bad++
				}
			}
		}
		if (on == 0 & substr(line, 1, strlen(hd)) == hd) on = 1
	}
	fclose(fh)
	st_numscalar("_v4_n", n)
	st_numscalar("_v4_bad", bad)
}
end

**# R1 a group printed "all but <m" beside an exact group

local ++test_count
capture noisily {
    clear
    quietly set obs 100
    gen g = cond(_n <= 50, 1, 2)
    gen double x = _n
    quietly replace x = . if _n <= 48 | inrange(_n, 51, 60)
    gen double y = 1
    capture log close v4
    quietly log using "`W'/r1.log", text replace name(v4)
    dataprobe x, by(g) maskrare
    dataprobe x y, by(g) maskrare
    capture noisily dataprobe x, by(g) notmissing(x) complete(x) maskrare warn
    quietly log close v4
    * MISSINGNESS prints 58 and the header 42 complete; group 1 is
    * "all but <5" missing and "<5" complete, so group 2's exact 10 and 40
    * gave its 2 nonmissing rows back (58 - 10 = 48 = 50 - 2; 42 - 40 = 2)
    _v4_count "`W'/r1.log" "complete cases: 42"
    assert r(n) == 3
    _v4_eq "`W'/r1.log" "1 50 <5 [masked] 1"
    assert r(n) == 3
    _v4_eq "`W'/r1.log" "2 50 40 80.0% 1"
    assert r(n) == 0
    _v4_eq "`W'/r1.log" "2 x 10 20.0%"
    assert r(n) == 0
    * group 2 is withheld as an exact count of the mask or more
    _v4_eq "`W'/r1.log" "2 50 [suppr.] [masked] 1"
    assert r(n) == 3
    _v4_eq "`W'/r1.log" "2 x [suppr.] [masked]"
    assert r(n) == 3
    * the per-group gate counts follow the same test
    _v4_count "`W'/r1.log" "by(g | g=2): notmissing: x has 10 missing"
    assert r(n) == 0
    _v4_count "`W'/r1.log" "by(g | g=2): complete(x): 40 of 50"
    assert r(n) == 0
    _v4_count "`W'/r1.log" "by(g | g=2): notmissing: x has [suppressed] missing"
    assert r(n) >= 1 & r(n) < .
    _v4_count "`W'/r1.log" "by(g | g=1): notmissing: x has all but <5 missing"
    assert r(n) >= 1 & r(n) < .
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: R1 all but <m beside an exact group: the complement is tested"
}
else {
    local ++fail_count
    display as error "  FAIL: R1 all but <m beside an exact group: the complement is tested"
}

* R1, two masked groups: their complements sum to a small count
local ++test_count
capture noisily {
    clear
    quietly set obs 150
    gen g = cond(_n <= 50, 1, cond(_n <= 100, 2, 3))
    gen double x = _n
    * groups 1 and 2: 48 missing each (2 nonmissing); group 3: 10 missing
    quietly replace x = . if inrange(_n, 1, 48) | inrange(_n, 51, 98) | inrange(_n, 101, 110)
    capture log close v4
    quietly log using "`W'/r1b.log", text replace name(v4)
    dataprobe x, by(g) maskrare
    quietly log close v4
    * MISSINGNESS 106 minus group 3's 10 is 96 = 100 - 4: groups 1 and 2
    * together hold 4 nonmissing rows
    _v4_eq "`W'/r1b.log" "3 x 10 20.0%"
    assert r(n) == 0
    _v4_eq "`W'/r1b.log" "3 x [suppr.] [masked]"
    assert r(n) == 1
    _v4_eq "`W'/r1b.log" "1 x all but <5 [masked]"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: R1 two all-but-<m groups: their complements' total is not small"
}
else {
    local ++fail_count
    display as error "  FAIL: R1 two all-but-<m groups: their complements' total is not small"
}

* R1 guard: the remainder alone still decides when no group is all but <m
local ++test_count
capture noisily {
    clear
    quietly set obs 100
    gen g = cond(_n <= 50, 1, 2)
    gen double x = _n
    quietly replace x = . if inrange(_n, 1, 20) | inrange(_n, 51, 70)
    capture log close v4
    quietly log using "`W'/r1c.log", text replace name(v4)
    dataprobe x, by(g) maskrare
    quietly log close v4
    * every count exact: nothing withheld
    _v4_eq "`W'/r1c.log" "1 x 20 40.0%"
    assert r(n) == 1
    _v4_eq "`W'/r1c.log" "2 x 20 40.0%"
    assert r(n) == 1
    _v4_count "`W'/r1c.log" "[suppr.]"
    assert r(n) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: R1 guard: exact groups with no masked cell stay printed"
}
else {
    local ++fail_count
    display as error "  FAIL: R1 guard: exact groups with no masked cell stay printed"
}

**# R2 groupstat(n) beside an N printed by a review() or complete() item

local ++test_count
capture noisily {
    clear
    quietly set obs 63
    gen g = cond(_n <= 30, 1, cond(_n <= 60, 2, 3))
    gen double x = _n
    capture log close v4
    quietly log using "`W'/r2.log", text replace name(v4)
    dataprobe, gatesonly review("all": 1==1) groupstat(n x, by(g)) maskrare
    dataprobe, gatesonly complete(x) groupstat(n x, by(g)) maskrare
    quietly log close v4
    * "63 of 63" minus cells 30 and 30 gave group 3's 3 rows back: exactly
    * one of the tied groups is withheld in each table, and no table
    * prints both
    _v4_eq "`W'/r2.log" "1 30"
    local a = r(n)
    _v4_eq "`W'/r2.log" "2 30"
    local b = r(n)
    assert `a' + `b' == 2
    _v4_eq "`W'/r2.log" "1 [suppr.]"
    local c = r(n)
    _v4_eq "`W'/r2.log" "2 [suppr.]"
    local d = r(n)
    assert `c' + `d' == 2
    assert (`a' == 2 & `d' == 2) | (`b' == 2 & `c' == 2)
    _v4_count "`W'/r2.log" "63 of 63"
    assert r(n) == 2
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: R2 groupstat(n) is tested against N printed by review()/complete()"
}
else {
    local ++fail_count
    display as error "  FAIL: R2 groupstat(n) is tested against N printed by review()/complete()"
}

**# S1 groupstat(n) with its own if: the cells' total over its rows

local ++test_count
capture noisily {
    clear
    quietly set obs 100
    gen g = cond(_n <= 50, 1, 2)
    gen double x = _n
    gen byte keep = g == 1 | inlist(_n, 51, 52, 53)
    capture log close v4
    quietly log using "`W'/s1.log", text replace name(v4)
    dataprobe x, groupstat(n x, by(g) if keep) review("k": keep) maskrare
    dataprobe, gatesonly groupstat(n x, by(g) if keep) review("k": keep) maskrare
    quietly log close v4
    * review(k) prints 53; group 1's 50 gave the pooled group's 3 rows back
    * (the profile test set the cells against all 100 rows)
    _v4_count "`W'/s1.log" "review(k): 53 of 100"
    assert r(n) == 2
    _v4_eq "`W'/s1.log" "1 50"
    assert r(n) == 0
    _v4_eq "`W'/s1.log" "1 [suppr.]"
    assert r(n) == 2
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: S1 groupstat(n) if-scope remainder is taken over its own rows"
}
else {
    local ++fail_count
    display as error "  FAIL: S1 groupstat(n) if-scope remainder is taken over its own rows"
}

**# R3 a three-valued continuous() variable: no mean or SD under mincell()

local ++test_count
capture noisily {
    clear
    quietly set obs 60
    gen double x = cond(_n <= 55, 0, cond(_n <= 58, 1, 2))
    gen double y = _n
    gen double q = mod(_n, 4)
    quietly datamap, output("`W'/r3.txt") continuous(x q) saving("`W'/r3m.dta", replace)
    quietly datamap, output("`W'/r3.json") format(json) continuous(x q)
    quietly datadict, output("`W'/r3.md") continuous(x q) stats saving("`W'/r3d.dta", replace)
    * mean .117 and SD .415 with N 60 gave n1 = 3, n2 = 2 back
    _v4_count "`W'/r3.txt" "Mean: .117"
    assert r(n) == 0
    _v4_count "`W'/r3.txt" "SD: .415"
    assert r(n) == 0
    _v4_count "`W'/r3.txt" "Mean: withheld (mincell; two or three values)"
    assert r(n) == 1
    _v4_count "`W'/r3.md" "Mean=0.117"
    assert r(n) == 0
    _v4_count "`W'/r3.md" "Mean=withheld (mincell; two or three values)"
    assert r(n) == 1
    _v4_count "`W'/r3.json" ".1166"
    assert r(n) == 0
    _v4_count "`W'/r3.json" ".4154"
    assert r(n) == 0
    * guard: a four-valued variable keeps its mean (1.5) and SD
    _v4_count "`W'/r3.txt" "Mean: 1.5"
    assert r(n) == 1
    use "`W'/r3m.dta", clear
    quietly count if variable == "x" & missing(mean) & missing(sd)
    assert r(N) == 1
    quietly count if variable == "q" & !missing(mean) & !missing(sd)
    assert r(N) == 1
    use "`W'/r3d.dta", clear
    quietly count if variable == "x" & missing(mean) & missing(sd)
    assert r(N) == 1
    quietly count if variable == "q" & !missing(mean)
    assert r(N) == 1
    * guard: mincell(0) prints the mean
    clear
    quietly set obs 60
    gen double x = cond(_n <= 55, 0, cond(_n <= 58, 1, 2))
    quietly datamap, output("`W'/r3z.txt") continuous(x) mincell(0)
    _v4_count "`W'/r3z.txt" "Mean: .117"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: R3 two- or three-valued continuous(): mean/SD withheld in text, JSON, saving(), datadict"
}
else {
    local ++fail_count
    display as error "  FAIL: R3 two- or three-valued continuous(): mean/SD withheld in text, JSON, saving(), datadict"
}

**# R4 a fixed file reloaded and rerun supersedes; a (modified) subset does not

local ++test_count
capture noisily {
    local L "`W'/r4.dta"
    capture erase "`L'"
    local cpath "`W'/r4cohort.dta"
    dataqa set ledger("`L'") run(r1) collect
    sysuse auto, clear
    quietly expand 2 in 1/3
    quietly save "`cpath'", replace
    use "`cpath'", clear
    quietly dataprobe, gatesonly isid(make) nodups
    * fix upstream: drop the duplicates, save, reload unmodified
    quietly duplicates drop
    quietly save "`cpath'", replace
    use "`cpath'", clear
    assert c(changed) == 0 & _N == 74
    quietly dataprobe, gatesonly isid(make) nodups
    capture noisily dataqa assert, expect(r4cohort)
    assert _rc == 0 & r(n_superseded) == 2
    * the 1.10.3 review repro: a keep-if subset of auto, "auto (modified)",
    * does not clear the full-data failures
    dataqa set ledger("`L'") run(r2) collect
    sysuse auto, clear
    quietly dataprobe, gatesonly stat(mean mpg 25 30) notmissing(rep78)
    quietly keep if inrange(mpg, 25, 30) & !missing(rep78)
    quietly dataprobe, gatesonly stat(mean mpg 25 30) notmissing(rep78)
    capture dataqa assert, expect(auto)
    assert _rc == 9 & r(n_failed) == 2 & r(n_superseded) == 0
    * guard: modified data rerun on modified data supersedes
    dataqa set ledger("`L'") run(r3) collect
    sysuse auto, clear
    gen double one = 1
    quietly dataprobe, gatesonly notmissing(rep78)
    quietly replace rep78 = 3 if missing(rep78)
    quietly dataprobe, gatesonly notmissing(rep78)
    capture dataqa assert, expect(auto)
    assert _rc == 0 & r(n_superseded) == 1
    dataqa set, clear
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: R4 narrow supersession: fixed file rerun clears, (modified) subset does not"
}
else {
    local ++fail_count
    display as error "  FAIL: R4 narrow supersession: fixed file rerun clears, (modified) subset does not"
}
capture dataqa set, clear
macro drop DATAMAP_DQ

**# R5 every groupstat cell fits its column

local ++test_count
capture noisily {
    sysuse auto, clear
    gen str3 grp = cond(_n <= 30, "a", cond(_n <= 60, "b", "c"))
    gen double tri = cond(_n <= 60, 0, cond(_n <= 71, 1, 2))
    gen double dob = td(01jan1960) + _n*41
    format dob %tdDD_Month_CCYY
    gen double tc = dob*86400000 + 3600000
    format tc %tc
    capture log close v4
    quietly log using "`W'/r5.log", text replace name(v4)
    dataprobe, gatesonly groupstat(sum sd mean: tri, by(grp)) maskrare
    dataprobe, gatesonly groupstat(mean p50: dob, by(grp))
    dataprobe, gatesonly groupstat(mean tc, by(grp))
    dataprobe, gatesonly groupstat(sum: price, by(grp))
    quietly log close v4
    * the pooled sd printed [suppressed] (12 characters) in a 10-wide column
    _v4_eq "`W'/r5.log" "pooled [suppr.] [suppr.] .2297"
    assert r(n) == 1
    _v4_count "`W'/r5.log" "[suppressed]"
    assert r(n) == 0
    * multi-statistic rows: 2 + 16 + 10 per statistic
    _v4_width "`W'/r5.log" "GROUPSTAT sum sd mean: tri" 48
    assert r(n) == 4 & r(bad) == 0
    _v4_width "`W'/r5.log" "GROUPSTAT mean p50: dob" 38
    assert r(n) == 4 & r(bad) == 0
    * one-statistic rows: 2 + 24 + 13; a %tc mean was 18 characters
    _v4_width "`W'/r5.log" "GROUPSTAT mean by(grp)" 39
    assert r(n) == 4 & r(bad) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: R5 groupstat cells, pooled sd and long date formats fit their columns"
}
else {
    local ++fail_count
    display as error "  FAIL: R5 groupstat cells, pooled sd and long date formats fit their columns"
}

**# R6 a cell already printed <m stays <m

local ++test_count
capture noisily {
    sysuse auto, clear
    gen str3 grp = cond(_n <= 30, "a", cond(_n <= 60, "b", "c"))
    capture log close v4
    quietly log using "`W'/r6.log", text replace name(v4)
    dataprobe rep78, by(grp) byfreq maskrare
    capture noisily dataprobe rep78 foreign, by(grp) byfreq maskrare notmissing(rep78) warn
    quietly log close v4
    * rep78 missing per group is 2, 2, 1: every cell is small, so each
    * reads <5; [suppr.] stands for an exact count of 5 or more
    foreach gg in a b c {
        _v4_eq "`W'/r6.log" "`gg' rep78 <5 [masked]"
        assert r(n) == 2
        _v4_eq "`W'/r6.log" "`gg' rep78 [suppr.] [masked]"
        assert r(n) == 0
        _v4_count "`W'/r6.log" "by(grp | grp=[`gg']): notmissing: rep78 has [suppressed]"
        assert r(n) == 0
        _v4_count "`W'/r6.log" "by(grp | grp=[`gg']): notmissing: rep78 has <5 missing"
        assert r(n) >= 1 & r(n) < .
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: R6 a small masked cell reads <m, never [suppr.]"
}
else {
    local ++fail_count
    display as error "  FAIL: R6 a small masked cell reads <m, never [suppr.]"
}

**# R7 an unmasked groupstat band failure for a date keeps full precision

local ++test_count
capture noisily {
    sysuse auto, clear
    gen double dob = td(01jan1960) + _n*41
    format dob %td
    gen str3 grp = cond(_n <= 30, "a", cond(_n <= 60, "b", "c"))
    capture log close v4
    quietly log using "`W'/r7.log", text replace name(v4)
    capture noisily dataprobe, gatesonly groupstat(mean dob, by(grp) band(0 1)) warn
    capture noisily dataprobe, gatesonly groupstat(mean dob, by(grp) band(0 1)) maskrare warn
    quietly log close v4
    * group b's mean is 1865.5: 08feb1965 alone could round onto a bound
    _v4_count "`W'/r7.log" "groupstat(mean dob): mean 1865.5 (08feb1965) in group b"
    assert r(n) == 1
    _v4_count "`W'/r7.log" "groupstat(mean dob): mean 08feb1965 in group b"
    assert r(n) == 0
    * under the mask: month precision, never the exact value
    _v4_count "`W'/r7.log" "groupstat(mean dob): mean 1965-02 in group b"
    assert r(n) == 1
    _v4_count "`W'/r7.log" "1865.5"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: R7 unmasked date band failures print the value; masked ones the month"
}
else {
    local ++fail_count
    display as error "  FAIL: R7 unmasked date band failures print the value; masked ones the month"
}

capture log close v4
macro drop DATAMAP_DQ
local files : dir "`W'" files "*"
foreach f of local files {
    capture erase "`W'/`f'"
}
capture rmdir "`W'"

display as text _newline "RESULT: test_datamap_v1104 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
