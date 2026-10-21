clear all
set more off
version 16.0
set linesize 255

* test_datamap_v1106.do - 1.10.6 regressions outside the dataprobe audit:
* the deferred bugs (red on 1.10.5) and guards for the one-pass paths of
* the 1.10.6 performance work (each is a guard: it passes on 1.10.5 too,
* and pins an equivalence the new code must keep).
*
*   D1  a $ in a directory() file name is refused by name (1.10.5: r(601)
*       naming a different file); a < in a name is still documented
*   D2  datadict prints values of 1e6 and more in full (1.10.5: 1.00e+07)
*   D3  dataqa compare reads the row report and assert show when a
*       (modified) rerun leaves both standing (1.10.5: the later row)
*   D4  a $ in a subdirectory name under recursive is refused by name
*   D5  datadict values of 1e15 and more print in %21.0g
*   D6  compare flags a failing (modified) row that stands (review fix)
*   D7  guard: datadict level counts at 20,000 levels
*   D8  guard: the one-pass kernels at one row, one group, one variable
*   G1  _datamap_nuniq's tabulate path against egen tag (numeric with
*       extended missings, strings with countempty, late levels, caps)
*   G2  datamap saving(): the caller's RNG state, an all-missing
*       continuous variable, and the saved summaries equal summarize
*   G3  datadict without a stats column still saves the summaries
*   G4  datamvp's all-numeric path equals the per-variable path
*   G5  dataqa report's per-dataset counts and open rows against a
*       hand count, with a call that has no seq

local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard

local test_count = 0
local pass_count = 0
local fail_count = 0

local W "`c(tmpdir)'/v1106m"
capture mkdir "`W'"
macro drop DATAMAP_DQ

* lines of a text file that contain a string
capture program drop _m6_count
program define _m6_count, rclass
    args file needle
    mata: _m6_count_m(st_local("file"), st_local("needle"))
    return scalar n = scalar(_m6_cnt)
    scalar drop _m6_cnt
end
mata:
void _m6_count_m(string scalar f, string scalar nd)
{
	real scalar fh, n
	string scalar line
	n = 0
	fh = fopen(f, "r")
	while ((line = fget(fh)) != J(0, 0, "")) {
		if (strpos(line, nd) > 0) n++
	}
	fclose(fh)
	st_numscalar("_m6_cnt", n)
}
// local _m6_l: the first line of f that contains nd
void _m6_line(string scalar f, string scalar nd)
{
	real scalar fh
	string scalar line
	st_local("_m6_l", "")
	fh = fopen(f, "r")
	while ((line = fget(fh)) != J(0, 0, "")) {
		if (strpos(line, nd) > 0) {
			st_local("_m6_l", line)
			break
		}
	}
	fclose(fh)
}
// local _m6_l: the lines of f from the one that contains start to the
// next empty line, joined with |
void _m6_block(string scalar f, string scalar start)
{
	real scalar fh, on
	string scalar line, out
	out = ""
	on = 0
	fh = fopen(f, "r")
	while ((line = fget(fh)) != J(0, 0, "")) {
		if (!on & strpos(line, start) > 0) on = 1
		if (on) {
			if (strtrim(line) == "" & out != "") break
			out = out + "|" + line
		}
	}
	fclose(fh)
	st_local("_m6_l", out)
}
end

**# D1 a $ in a directory() file name

local ++test_count
capture noisily {
    local D "`W'/d1"
    capture mkdir "`D'"
    sysuse auto, clear
    keep make price foreign
    local bad = "`D'/a" + char(36) + "b.dta"
    quietly save `"`macval(bad)'"', replace
    quietly save "`D'/plain.dta", replace
    capture log close m6
    log using "`W'/d1.log", text replace name(m6)
    capture noisily datamap, directory("`D'") output("`W'/d1.txt")
    local rc1 = _rc
    capture noisily datadict, directory("`D'") output("`W'/d1.md")
    local rc2 = _rc
    log close m6
    assert `rc1' == 198
    assert `rc2' == 198
    * the message names the file as it is on disk
    local nd = "cannot document a" + char(36) + "b.dta"
    _m6_count "`W'/d1.log" `"`macval(nd)'"'
    assert r(n) == 2
    * nothing was written
    capture confirm file "`W'/d1.txt"
    assert _rc
    capture confirm file "`W'/d1.md"
    assert _rc
    erase `"`macval(bad)'"'
    * guard: without it the directory is documented
    datamap, directory("`D'") output("`W'/d1b.txt")
    datadict, directory("`D'") output("`W'/d1b.md")
    erase "`D'/plain.dta"
    erase "`W'/d1b.txt"
    erase "`W'/d1b.md"
    rmdir "`D'"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D1 a \$ in a directory() file name is refused by name, nothing written"
}
else {
    local ++fail_count
    display as error "  FAIL: D1 a \$ in a directory() file name is refused by name, nothing written"
}
capture log close m6

**# D2 datadict prints large values in full

local ++test_count
capture noisily {
    clear
    quietly set obs 40
    gen double v = 10012345 + _n * 1000
    gen double w = -2.5e9 - _n
    datadict, output("`W'/d2.md") stats mincell(0)
    _m6_count "`W'/d2.md" "e+0"
    assert r(n) == 0
    * median of v: 10,012,345 + 20.5 * 1000
    _m6_count "`W'/d2.md" "Median=10,032,845"
    assert r(n) == 1
    _m6_count "`W'/d2.md" "Range=10,013,345-10,052,345"
    assert r(n) == 1
    * a negative range is written "a to b"
    _m6_count "`W'/d2.md" "Range=-2,500,000,040 to -2,500,000,001"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D2 datadict prints values of 1e6 and more with every digit"
}
else {
    local ++fail_count
    display as error "  FAIL: D2 datadict prints values of 1e6 and more with every digit"
}

**# D3 dataqa compare agrees with report and assert after a (modified) rerun

local ++test_count
capture noisily {
    local L "`W'/d3.dta"
    capture erase "`L'"
    dataqa set ledger("`L'") run(r1) collect
    sysuse auto, clear
    quietly dataprobe, gatesonly stat(mean mpg 25 30) notmissing(rep78)
    dataqa set ledger("`L'") run(r2) collect
    sysuse auto, clear
    quietly dataprobe, gatesonly stat(mean mpg 25 30) notmissing(rep78)
    * a subset of the data, "auto (modified)", passes; the full-data
    * failures stand
    quietly keep if inrange(mpg, 25, 30) & !missing(rep78)
    quietly dataprobe, gatesonly stat(mean mpg 25 30) notmissing(rep78)
    capture dataqa assert, expect(auto)
    assert _rc == 9 & r(n_failed) == 2
    * r2's standing rows are the ones r1 has: nothing changed
    dataqa compare, baseline(r1)
    assert r(n_flags) == 0
    dataqa set, clear
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D3 compare reads the full-data row a (modified) rerun leaves standing"
}
else {
    local ++fail_count
    display as error "  FAIL: D3 compare reads the full-data row a (modified) rerun leaves standing"
}
capture dataqa set, clear

**# D4 a $ in a subdirectory name under recursive

local ++test_count
capture noisily {
    local D "`W'/d4"
    capture mkdir "`D'"
    local sub = "`D'/s" + char(36) + "x"
    mata: (void) _mkdir(st_local("sub"), 1)
    sysuse auto, clear
    keep make price
    quietly save "`D'/ok.dta", replace
    quietly save `"`macval(sub)'/a.dta"', replace
    capture log close m6
    log using "`W'/d4.log", text replace name(m6)
    capture noisily datamap, directory("`D'") recursive output("`W'/d4.txt")
    local rc1 = _rc
    capture noisily datadict, directory("`D'") recursive output("`W'/d4.md")
    local rc2 = _rc
    log close m6
    assert `rc1' == 198 & `rc2' == 198
    local nd = "cannot scan subdirectory s" + char(36) + "x"
    _m6_count "`W'/d4.log" `"`macval(nd)'"'
    assert r(n) == 2
    capture confirm file "`W'/d4.txt"
    assert _rc
    erase `"`macval(sub)'/a.dta"'
    mata: rmdir(st_local("sub"))
    erase "`D'/ok.dta"
    rmdir "`D'"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D4 a \$ in a subdirectory name is refused by name under recursive"
}
else {
    local ++fail_count
    display as error "  FAIL: D4 a \$ in a subdirectory name is refused by name under recursive"
}
capture log close m6

**# D5 datadict values of 1e15 and more

local ++test_count
capture noisily {
    * the file's subprograms are private: run it (dropping datadict, which
    * has no -capture program drop- of its own)
    capture program drop datadict
    discard
    quietly findfile datadict.ado
    quietly run "`r(fn)'"
    _datadict_FormatStatNumber 1e23
    assert "`r(formatted)'" == "1.00000000000000e+23"
    _datadict_FormatStatNumber -1e30
    assert "`r(formatted)'" == "-1.00000000000000e+30"
    _datadict_FormatStatNumber 999999999999999
    assert "`r(formatted)'" == "999,999,999,999,999"
    _datadict_FormatStatNumber 10012345
    assert "`r(formatted)'" == "10,012,345"
}
local _d5rc = _rc
capture program drop datadict
discard
if `_d5rc' == 0 {
    local ++pass_count
    display as result "  PASS: D5 datadict prints 1e15 and more in %21.0g, below with every digit"
}
else {
    local ++fail_count
    display as error "  FAIL: D5 datadict prints 1e15 and more in %21.0g, below with every digit"
}

**# D6 dataqa compare reads a failing (modified) row that stands

* the review repro: r2 reruns the gate on a subset that fails; report and
* assert count the failure, so compare must flag it (1.10.6 before the fix
* read the unmodified pass: no change)
local ++test_count
capture noisily {
    local L "`W'/d6.dta"
    capture erase "`L'"
    dataqa set ledger("`L'") run(r1) collect
    sysuse auto, clear
    quietly dataprobe, gatesonly stat(mean mpg 15 30) notmissing(make)
    dataqa set ledger("`L'") run(r2) collect
    sysuse auto, clear
    quietly dataprobe, gatesonly stat(mean mpg 15 30) notmissing(make)
    quietly keep if mpg >= 31
    quietly dataprobe, gatesonly stat(mean mpg 15 30) notmissing(make)
    capture dataqa assert, expect(auto)
    assert _rc == 9
    dataqa compare, baseline(r1)
    assert !missing(r(n_flags))
    assert r(n_flags) > 0
    dataqa set, clear
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D6 compare flags a failing (modified) row that report and assert count"
}
else {
    local ++fail_count
    display as error "  FAIL: D6 compare flags a failing (modified) row that report and assert count"
}
capture dataqa set, clear

**# D7 guard: datadict level counts from matcell() at 20,000 levels

* levelsof, hexadecimal fails with r(920) from about 40,000 levels with or
* without matcell(), so the one-by-one fallback (any matcell() error) never
* changes a result; this guard pins the counts at a level count both forms
* still take (a guard: passes on 1.10.5 too)
local ++test_count
capture noisily {
    * the file's subprograms are private: run it (dropping datadict, which
    * has no -capture program drop- of its own)
    capture program drop datadict
    discard
    quietly findfile datadict.ado
    quietly run "`r(fn)'"
    clear
    quietly set obs 40000
    gen long v = ceil(_n / 2)
    quietly replace v = 1 in 1/9
    _datadict_GetUnlabeledStats "v" 3 40000 0 ""
    local vs `"`r(valstring)'"'
    * 19,997 levels (1 holds 10 rows), more than maxfreq: the count of
    * levels, not All missing
    assert `"`vs'"' == "Unique=19997"
}
local _d7rc = _rc
capture program drop datadict
discard
if `_d7rc' == 0 {
    local ++pass_count
    display as result "  PASS: D7 guard: datadict level counts at 20,000 levels"
}
else {
    local ++fail_count
    display as error "  FAIL: D7 guard: datadict level counts at 20,000 levels"
}

**# D8 guard: the one-pass kernels at one row, one group, one variable

* datamvp (_dmvp_colmiss, _dmvp_patt, _dmvp_mono, _dmvp_grpmiss),
* _datamap_missby (Mata path), _datamap_nuniq and dataqa report's
* _dataqa_dscounts/_dataqa_openrows at their smallest sizes; each
* datamvp call is compared with the per-variable path (a string with no
* missing value in the varlist)
local ++test_count
capture noisily {
    foreach N in 1 2 7 {
        clear
        quietly set obs `N'
        gen byte g = 1
        gen double x = cond(_n == 1, ., _n)
        gen double y = cond(_n == `N', ., 1)
        gen str1 sfull = "a"
        foreach vl in "x" "x y" {
            foreach opt in "" ", monotone" ", bytable(g)" ", graph(bar) gby(g) nodraw" ", graph(bar) over(g) nodraw" {
                capture noisily datamvp `vl' `opt'
                local rc1 = _rc
                local p1 = r(N_patterns)
                local m1 = r(N_mv_total)
                capture noisily datamvp `vl' sfull `opt'
                assert _rc == `rc1'
                if !`rc1' assert r(N_patterns) == `p1' & r(N_mv_total) == `m1'
            }
        }
        * _datamap_missby, one group: counts against count if
        gen byte t = 1
        _datamap_missby x y, by(g) touse(t)
        tempname nm ng
        matrix `nm' = r(nmiss)
        matrix `ng' = r(ngroup)
        quietly count if missing(x)
        assert el(`nm', 1, 1) == r(N)
        quietly count if missing(y)
        assert el(`nm', 2, 1) == r(N)
        assert el(`ng', 1, 1) == `N'
        * _datamap_nuniq
        _datamap_nuniq x, cap(1000)
        assert r(n) == `N' - 1 & r(capped) == 0
    }
    * dataqa report on a ledger of one dataset and one row
    local L "`W'/d8.dta"
    capture erase "`L'"
    dataqa set ledger("`L'") run(z1) collect
    sysuse auto, clear
    quietly dataprobe, gatesonly notmissing(rep78) name(solo)
    dataqa set, clear
    use "`L'", clear
    quietly keep in 1
    quietly save "`L'", replace
    capture log close m6
    log using "`W'/d8.log", text replace name(m6)
    dataqa report using "`L'", markdown("`W'/d8.md") replace
    log close m6
    _m6_count "`W'/d8.log" "  solo "
    assert r(n) == 1
    _m6_count "`W'/d8.md" "| open ("
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: D8 guard: the one-pass kernels at one row, one group, one variable"
}
else {
    local ++fail_count
    display as error "  FAIL: D8 guard: the one-pass kernels at one row, one group, one variable"
}
capture log close m6

**# G1 _datamap_nuniq tabulate path against egen tag

local ++test_count
capture noisily {
    clear
    set seed 61
    quietly set obs 120000
    * few levels, extended missings, a level first seen after row 50,000
    gen double x = ceil(runiform() * 7)
    quietly replace x = .a in 5/9
    quietly replace x = . in 100/120
    quietly replace x = 99 in 110000
    gen str3 s = "k" + string(ceil(runiform() * 12))
    quietly replace s = "" in 1/40
    quietly replace s = "zz" in 119999
    gen byte c = 1
    foreach v in x s c {
        tempvar t
        quietly egen byte `t' = tag(`v') if !missing(`v')
        quietly count if `t' == 1
        local truth = r(N)
        drop `t'
        _datamap_nuniq `v', cap(1000)
        assert r(n) == `truth' & r(capped) == 0
        * a cap below the count censors it
        _datamap_nuniq `v', cap(2)
        if `truth' > 2 assert r(n) == 3 & r(capped) == 1
        else assert r(n) == `truth' & r(capped) == 0
    }
    * countempty counts "" as a level
    _datamap_nuniq s, cap(1000) countempty
    assert r(n) == 14 & r(capped) == 0
    _datamap_nuniq x, cap(1000)
    assert r(n) == 8
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G1 _datamap_nuniq tabulate path equals egen tag (missings, late levels, caps)"
}
else {
    local ++fail_count
    display as error "  FAIL: G1 _datamap_nuniq tabulate path equals egen tag (missings, late levels, caps)"
}

**# G2 datamap saving() from the report pass

local ++test_count
capture noisily {
    sysuse auto, clear
    gen double allmiss = .
    set seed 4242
    datamap, output("`W'/g2.txt") continuous(allmiss) saving("`W'/g2.dta", replace)
    local u1 = runiform()
    set seed 4242
    local u2 = runiform()
    assert `u1' == `u2'
    * the saved summaries are summarize's, at full precision
    quietly summarize price, detail
    tempname m s p
    scalar `m' = r(mean)
    scalar `s' = r(sd)
    scalar `p' = r(p50)
    preserve
    use "`W'/g2.dta", clear
    quietly count if variable == "allmiss"
    assert r(N) == 1
    assert missing(mean) & class == "continuous" if variable == "allmiss"
    assert mean == scalar(`m') if variable == "price"
    assert sd == scalar(`s') if variable == "price"
    assert p50 == scalar(`p') if variable == "price"
    restore
    * the same call on a file gives the same rows
    quietly save "`W'/g2src.dta", replace
    datamap, single("`W'/g2src.dta") output("`W'/g2f.txt") continuous(allmiss) ///
        saving("`W'/g2f.dta", replace)
    use "`W'/g2f.dta", clear
    drop source dataset datasignature output
    tempfile a
    quietly save `a'
    use "`W'/g2.dta", clear
    drop source dataset datasignature output
    unab _vg2 : _all
    quietly describe using `a', varlist
    assert "`_vg2'" == "`r(varlist)'"
    cf _all using `a', all
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G2 saving() keeps the caller's RNG state, an all-missing variable, summarize's values"
}
else {
    local ++fail_count
    display as error "  FAIL: G2 saving() keeps the caller's RNG state, an all-missing variable, summarize's values"
}

**# G3 datadict saving() without a stats column

local ++test_count
capture noisily {
    sysuse auto, clear
    quietly summarize weight, detail
    tempname m
    scalar `m' = r(mean)
    datadict, output("`W'/g3.md") saving("`W'/g3.dta", replace)
    _m6_count "`W'/g3.md" "Mean="
    assert r(n) == 0
    use "`W'/g3.dta", clear
    assert mean == scalar(`m') if variable == "weight"
    quietly count if !missing(p50)
    assert !missing(r(N))
    assert r(N) > 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G3 datadict saves the summaries its table does not print"
}
else {
    local ++fail_count
    display as error "  FAIL: G3 datadict saves the summaries its table does not print"
}

**# G4 datamvp all-numeric path against the per-variable path

local ++test_count
capture noisily {
    clear
    set seed 7
    quietly set obs 3000
    forvalues j = 1/7 {
        gen double v`j' = rnormal()
        quietly replace v`j' = . if runiform() < 0.1 * `j'
    }
    quietly replace v3 = .b in 1/20
    * a string with no missing value leaves the varlist but sends datamvp
    * down the per-variable path
    gen str1 sfull = "a"
    local k = 0
    foreach call in "v1-v7" "v1-v7 sfull" {
        local ++k
        capture drop mvp_*
        capture log close m6
        log using "`W'/g4_`k'.log", text replace name(m6)
        datamvp `call', monotone generate(mvp) skip
        log close m6
        foreach x in N N_complete N_incomplete N_patterns N_vars max_miss mean_miss N_mv_total {
            local r_`x'_`k' = r(`x')
        }
        mata: _m6_block("`W'/g4_`k'.log", "Monotone missingness test")
        local mono_`k' `"`_m6_l'"'
        preserve
        keep mvp_*
        tempfile f`k'
        quietly save `f`k''
        restore
    }
    foreach x in N N_complete N_incomplete N_patterns N_vars max_miss mean_miss N_mv_total {
        assert `r_`x'_1' == `r_`x'_2'
    }
    assert `"`mono_1'"' != ""
    assert `"`mono_1'"' == `"`mono_2'"'
    use `f2', clear
    unab _vg4 : _all
    quietly describe using `f1', varlist
    assert "`_vg4'" == "`r(varlist)'"
    cf _all using `f1', all
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G4 datamvp's one-pass counts, patterns and monotone test equal the per-variable path"
}
else {
    local ++fail_count
    display as error "  FAIL: G4 datamvp's one-pass counts, patterns and monotone test equal the per-variable path"
}
capture log close m6

**# G5 dataqa report counts and open rows against a hand count

local ++test_count
capture noisily {
    local L "`W'/g5.dta"
    capture erase "`L'"
    dataqa set ledger("`L'") run(q1) collect
    sysuse auto, clear
    quietly dataprobe, gatesonly notmissing(rep78) stat(mean mpg 0 100) name(alpha)
    quietly dataprobe, gatesonly stat(mean price 0 1) name(beta)
    quietly dataprobe, gatesonly stat(mean weight 0 1) name(alpha)
    quietly dataprobe, gatesonly stat(mean trunk 0 1) name(alpha)
    dataqa set, clear
    * a damaged call: the last alpha call (one gate, its own) has no seq;
    * egen tag() leaves it out of the calls, as the report must
    use "`L'", clear
    quietly summarize seq if dataset == "alpha", meanonly
    quietly replace seq = . if dataset == "alpha" & seq == r(max)
    quietly save "`L'", replace
    * hand counts
    quietly count if dataset == "alpha" & status == "fail"
    local af = r(N)
    tempvar t
    quietly egen byte `t' = tag(run seq) if dataset == "alpha"
    quietly count if `t' == 1
    local ac = r(N)
    capture log close m6
    log using "`W'/g5.log", text replace name(m6)
    dataqa report using "`L'", markdown("`W'/g5.md") replace
    log close m6
    _m6_count "`W'/g5.log" "  alpha "
    assert r(n) == 1
    mata: _m6_line("`W'/g5.log", "  alpha ")
    local cells `"`_m6_l'"'
    assert word(`"`cells'"', 2) == "`ac'"
    assert `ac' == 2
    assert word(`"`cells'"', 4) == "`af'"
    * every open row of the ledger is a table row of the draft
    use "`L'", clear
    quietly count if inlist(status, "fail", "warn", "review", "error")
    local nopen = r(N)
    _m6_count "`W'/g5.md" "| open ("
    assert r(n) == `nopen'
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G5 dataqa report counts calls, failures and open rows as a hand count does"
}
else {
    local ++fail_count
    display as error "  FAIL: G5 dataqa report counts calls, failures and open rows as a hand count does"
}
capture log close m6
capture dataqa set, clear

capture log close m6
macro drop DATAMAP_DQ
local files : dir "`W'" files "*"
foreach f of local files {
    capture erase "`W'/`f'"
}
capture rmdir "`W'"

display as text _newline "RESULT: test_datamap_v1106 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
