clear all
set more off
version 16.0
set linesize 255

* test_dataprobe_v1106.do - 1.10.6 regressions: the linked-count audit of a
* dataprobe by() maskrare profile is bounded.
*
* 1.10.5 counted the twin search's tries but kept enumerating candidates
* once the budget was spent, and the budget restarted on every audit pass,
* so a 3,000-row profile with 40 groups ran past 12 minutes without
* finishing.  1.10.6 stops the search when the budget is spent, shares one
* budget across the passes of a call, and, when the budget runs out before
* every count is proven safe, pools every group for the audited counts,
* prints a note and returns r(linkaudit_capped) = 1.
*
* B1 and B5 are red on 1.10.5 by not finishing (watched under a timeout);
* the other tests are red on 1.10.5 because r(used), r(capped),
* _dataprobe_audpass and r(linkaudit_capped) do not exist there, except the
* guards that say so.

local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard

local test_count = 0
local pass_count = 0
local fail_count = 0

local W "`c(tmpdir)'/v1106"
capture mkdir "`W'"
macro drop DATAMAP_DQ

* lines of a text file that contain a string
capture program drop _v6_count
program define _v6_count, rclass
    args file needle
    mata: _v6_count_m(st_local("file"), st_local("needle"))
    return scalar n = scalar(_v6_cnt)
    scalar drop _v6_cnt
end
mata:
void _v6_count_m(string scalar f, string scalar nd)
{
	real scalar fh, n
	string scalar line
	n = 0
	fh = fopen(f, "r")
	while ((line = fget(fh)) != J(0, 0, "")) {
		if (strpos(line, nd) > 0) n++
	}
	fclose(fh)
	st_numscalar("_v6_cnt", n)
}
end

* the benchmark data of the 2026-10-21 audit (N rows, G groups plus a
* three-row group G+1, about 30 variables); seeded
capture program drop _v6_gen
program define _v6_gen
    args N G
    clear
    set seed 20261021
    set obs `N'
    gen long id = _n
    gen int g = ceil(runiform()*`G')
    replace g = `G' + 1 in 1/3
    gen long pid = ceil(_n/4)
    gen double start = mod(_n, 4) * 100
    gen double stop = start + 100
    label define yn 0 "no" 1 "yes"
    forvalues j = 1/5 {
        gen double x1_`j' = rnormal(50, 10)
        replace x1_`j' = . if runiform() < 0.02
    }
    gen float f1 = round(rnormal(), 0.1)
    forvalues j = 1/6 {
        gen byte c1_`j' = ceil(runiform()*(2 + 2*`j'))
        replace c1_`j' = . if runiform() < 0.05
    }
    label values c1_1 yn
    gen byte b1 = runiform() < 0.3
    forvalues j = 1/3 {
        gen str12 s1_`j' = "lev" + string(ceil(runiform()*(5 + 8*`j')))
        replace s1_`j' = "" if runiform() < 0.03
    }
    gen int d1_1 = td(01jan2015) + floor(runiform()*2500)
    gen int d1_2 = td(01jan2018) + floor(runiform()*1000)
    replace d1_2 = . if runiform() < 0.1
    format d1_1 d1_2 %td
    compress
end

* the audit's subprograms are private to dataprobe.ado: run the installed
* copy so they can be called directly
quietly findfile dataprobe.ado
local dp_fn "`r(fn)'"
quietly run "`dp_fn'"

local spec ";M|c1_1||cg|;M|c1_2||c|;M|x1_1||cp|;I|c1_1 c1_2 x1_1||ph|;N|b1||cg|;V0|b1||zg|;V1|b1||zg|;C|d1_1|w|cgw|"

**# A: the budget inside one audit

* ---- A1: a spent budget stops the search and says so ----
local ++test_count
capture noisily {
    _v6_gen 300 12
    egen long grp = group(g)
    gen byte w = d1_1 > td(01jan2020)
    _dataprobe_linkaudit, grp(grp) mask(5) cell(5) maxfreq(20) spec(`"`spec'"') budget(10)
    assert r(capped) == 1
    assert !missing(r(used))
    assert r(used) > 10
    * the search stops at its first step past the budget: one try, or one
    * linear program, which is charged (its size cubed / 6,000, some 50,000
    * tries here) and then refused unsolved
    assert r(used) < 200000
    assert "`r(add)'" != ""
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: A1 a spent budget stops the twin search and returns r(capped) = 1"
}
else {
    local ++fail_count
    display as error "  FAIL: A1 a spent budget stops the twin search and returns r(capped) = 1"
}

* ---- A2: within budget the verdict does not depend on it ----
* a budget of exactly the tries used gives the same verdict as a large
* one; one try fewer refuses the last one and caps
local ++test_count
capture noisily {
    _v6_gen 300 12
    egen long grp = group(g)
    gen byte w = d1_1 > td(01jan2020)
    _dataprobe_linkaudit, grp(grp) mask(5) cell(5) maxfreq(20) spec(`"`spec'"') budget(100000000)
    assert r(capped) == 0
    local U = r(used)
    local add "`r(add)'"
    local fails "`r(fails)'"
    local nfail = r(nfail)
    local nsens = r(nsens)
    assert `U' > 100
    _dataprobe_linkaudit, grp(grp) mask(5) cell(5) maxfreq(20) spec(`"`spec'"') budget(`U')
    assert r(capped) == 0
    assert r(used) == `U'
    assert "`r(add)'" == "`add'"
    assert "`r(fails)'" == "`fails'"
    assert r(nfail) == `nfail'
    assert r(nsens) == `nsens'
    _dataprobe_linkaudit, grp(grp) mask(5) cell(5) maxfreq(20) spec(`"`spec'"') budget(`=`U' - 1')
    assert r(capped) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: A2 within budget the audit's verdict is the same at any budget"
}
else {
    local ++fail_count
    display as error "  FAIL: A2 within budget the audit's verdict is the same at any budget"
}

* ---- A3: one budget per call, shared by the passes (_dataprobe_audpass) ----
local ++test_count
capture noisily {
    _v6_gen 300 12
    egen long grp = group(g)
    gen byte w = d1_1 > td(01jan2020)
    quietly summarize grp, meanonly
    local G = r(max)
    * capped: every group pooled, the pass repeated once, nothing left
    local _hideg ""
    local _aud_cap = .
    local _aud_go = .
    local _aud_bud = .
    _dataprobe_audpass grp, mask(5) cell(5) maxfreq(20) pooled() spec(`"`spec'"') budget(10)
    assert `_aud_cap' == 1
    assert `_aud_go' == 1
    assert `_aud_bud' < 0
    assert `: word count `_hideg'' == `G'
    numlist "1/`G'"
    local all "`r(numlist)'"
    local srt : list sort _hideg
    assert `: list srt === all'
    * within budget: what is left comes back
    local _hideg ""
    _dataprobe_audpass grp, mask(5) cell(5) maxfreq(20) pooled() spec(`"`spec'"') budget(100000000)
    assert `_aud_cap' == 0
    _dataprobe_linkaudit, grp(grp) mask(5) cell(5) maxfreq(20) spec(`"`spec'"') budget(100000000)
    assert `_aud_bud' == 100000000 - r(used)
    assert `_aud_go' == ("`r(add)'" != "")
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: A3 a capped pass pools every group; the budget left is handed back"
}
else {
    local ++fail_count
    display as error "  FAIL: A3 a capped pass pools every group; the budget left is handed back"
}

**# B: dataprobe calls

* ---- B1: the 1.10.5 hang: 3,000 rows, 40 groups, byfreq and gates ----
* 1.10.5 was still in its first audit pass after 12 minutes; 1.10.6 spends
* its 4,000,000 tries (about 70-90 seconds at one core) and pools every
* group.  Bound: 600 seconds.
local ++test_count
capture noisily {
    _v6_gen 3000 40
    capture log close v6
    log using "`W'/b1.log", text replace name(v6)
    timer clear 61
    timer on 61
    dataprobe, by(g) maskrare byfreq isid(id) nodups notmissing(c1_1 x1_1) ///
        allowed(c1_2 1 2 3 \ s1_1 lev1 lev2 lev3 lev4 lev5) ///
        inrange(x1_1 0 100 \ d1_1 2015-01-01 2021-12-31) ///
        stat(mean x1_1 40 60 \ n x1_2 0 1e9) complete(c1_1 c1_2) ///
        groupstat(mean x1_3, by(g)) heaping(d1_1) ///
        coverage(d1_1 2015-01-01 2021-12-31, gap(30)) intervals(pid start stop) ///
        binary(b1) warn
    local lc = r(linkaudit_capped)
    local ng = r(n_groups)
    local msk = r(masked)
    timer off 61
    log close v6
    quietly timer list 61
    local secs = r(t61)
    display as text "    B1 seconds: `secs'"
    assert `lc' == 1
    assert `ng' == 41
    assert `msk' == 1
    assert !missing(`secs')
    assert `secs' < 600
    _v6_count "`W'/b1.log" "note: the linked-count audit ran out of budget"
    assert r(n) == 1
    * no group's table or row prints: every group is pooled
    _v6_count "`W'/b1.log" "by group "
    assert r(n) == 0
    _v6_count "`W'/b1.log" "groups pooled (the linked-count check ran out of budget): 41"
    assert !missing(r(n))
    assert r(n) >= 2
    _v6_count "`W'/b1.log" "groups pooled (each <5 rows"
    assert r(n) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B1 the 1.10.5 hang finishes, capped, every group pooled"
}
else {
    local ++fail_count
    display as error "  FAIL: B1 the 1.10.5 hang finishes, capped, every group pooled"
}
capture log close v6

* ---- B2 guard: an audit within budget prints its groups ----
* (passes on 1.10.5 apart from the new return)
local ++test_count
capture noisily {
    sysuse nlsw88, clear
    capture log close v6
    log using "`W'/b2.log", text replace name(v6)
    dataprobe, by(race) maskrare
    local lc = r(linkaudit_capped)
    log close v6
    assert `lc' == 0
    _v6_count "`W'/b2.log" "linked-count audit ran out of budget"
    assert r(n) == 0
    * the GROUPWISE SUMMARY rows of White and Black
    _v6_count "`W'/b2.log" "  White "
    assert !missing(r(n))
    assert r(n) > 0
    _v6_count "`W'/b2.log" "  Black "
    assert r(n) > 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B2 guard: nlsw88 by(race) is audited within budget and prints its groups"
}
else {
    local ++fail_count
    display as error "  FAIL: B2 guard: nlsw88 by(race) is audited within budget and prints its groups"
}
capture log close v6

* ---- B3: r(linkaudit_capped) only where the audit runs ----
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly dataprobe, by(foreign)
    assert missing(r(linkaudit_capped))
    quietly dataprobe, maskrare
    assert missing(r(linkaudit_capped))
    quietly dataprobe, gatesonly by(foreign) maskrare notmissing(price)
    assert missing(r(linkaudit_capped))
    quietly dataprobe, by(foreign) maskrare
    assert r(linkaudit_capped) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B3 r(linkaudit_capped) is posted only by an audited by() maskrare profile"
}
else {
    local ++fail_count
    display as error "  FAIL: B3 r(linkaudit_capped) is posted only by an audited by() maskrare profile"
}

* ---- B4: a high-cardinality string in byfreq ----
* every level of sid is its own frequency-table row; the audit reads each
* through the levels a move touches, not the whole table
local ++test_count
capture noisily {
    clear
    set seed 5
    set obs 2000
    gen int g = ceil(runiform()*40)
    gen str16 sid = "S" + string(floor(runiform()*1e7), "%08.0f")
    gen byte c = ceil(runiform()*4)
    timer clear 62
    timer on 62
    quietly dataprobe sid c, by(g) maskrare byfreq
    timer off 62
    local lc = r(linkaudit_capped)
    quietly timer list 62
    display as text "    B4 seconds: " r(t62)
    assert `lc' == 0
    assert !missing(r(t62))
    assert r(t62) < 120
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B4 a 2,000-level string under byfreq maskrare finishes within budget"
}
else {
    local ++fail_count
    display as error "  FAIL: B4 a 2,000-level string under byfreq maskrare finishes within budget"
}

**# B5 the linear programs draw on the same budget

* auto by(foreign) with make (74 single-row levels) in byfreq: the twin
* search fails fast and each linear program (316 unknowns, 1,381
* constraints) takes some 15 seconds; 1.10.5 started up to 40 of them on
* every repeat of the check and ran past 10 minutes.  Bound: 600 seconds.
local ++test_count
capture noisily {
    sysuse auto, clear
    capture log close v6
    log using "`W'/b5.log", text replace name(v6)
    timer clear 63
    timer on 63
    dataprobe, by(foreign) maskrare byfreq groupstat(n mean: price, by(foreign))
    local lc = r(linkaudit_capped)
    timer off 63
    log close v6
    quietly timer list 63
    local secs = r(t63)
    display as text "    B5 seconds: `secs'"
    assert `lc' == 1
    assert !missing(`secs')
    assert `secs' < 600
    _v6_count "`W'/b5.log" "note: the linked-count audit ran out of budget"
    assert r(n) == 1
    _v6_count "`W'/b5.log" "by group "
    assert r(n) == 0
    * review 8: the note names the remedies of this call (byfreq), and the
    * groupstat footer says why groups of 22 and 52 rows are pooled
    _v6_count "`W'/b5.log" "every by() group is pooled; no byfreq"
    assert r(n) == 1
    _v6_count "`W'/b5.log" "groups pooled (the linked-count check ran out of budget): 2"
    assert !missing(r(n))
    assert r(n) >= 1
    _v6_count "`W'/b5.log" "groups with <5 rows"
    assert r(n) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: B5 the linear-programming stage is bounded by the same budget"
}
else {
    local ++fail_count
    display as error "  FAIL: B5 the linear-programming stage is bounded by the same budget"
}
capture log close v6

**# C: the 1.10.6 review (fix round)

* dataprobe was loaded by the B calls; its subprograms are private, so the
* file is run again (dataprobe has no -capture program drop- of its own)
* (and its audit's Mata, whose struct cannot be defined twice)
capture program drop dataprobe
capture mata: mata drop _dpa*()
capture mata: mata drop _dpa_st()
quietly findfile dataprobe.ado
quietly run "`r(fn)'"

* ---- C1: a capped audit with more than 2,500 groups ----
* the fallback built 1..G with numlist, which stops with r(123) past ~2,500
local ++test_count
capture noisily {
    clear
    set seed 11
    quietly set obs 32000
    gen long g = ceil(_n / 8)
    forvalues j = 1/2 {
        gen double x`j' = rnormal()
        quietly replace x`j' = . if runiform() < .04
    }
    egen long grp = group(g)
    local _hideg ""
    local _aud_cap = .
    _dataprobe_audpass grp, mask(5) pooled() spec(";M|x1||cp|;M|x2||c|") budget(1)
    assert `_aud_cap' == 1
    assert `: word count `_hideg'' == 4000
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: C1 a capped audit pools 4,000 groups (no numlist r(123))"
}
else {
    local ++fail_count
    display as error "  FAIL: C1 a capped audit pools 4,000 groups (no numlist r(123))"
}

* ---- C2: a table with one nonempty level that is withheld ----
* selectindex() of a 1 x 1 false is 1 x 0, whose rows() is 1: r(3301)
* (1.10.5 too)
local ++test_count
capture noisily {
    mata: st_local("_tt", invtokens(strofreal(_dpa_tabtext((3, 0), (0, 0), 5, 0, 10))))
    assert "`_tt'" == "-3 1"
    clear
    input str5 site b n
    "" 0 46
    "" 1 6
    "a b" 0 5
    "a b" 1 1
    "north" 0 117
    "north" 1 36
    "north" . 9
    "south" 0 79
    "south" 1 18
    "south" . 4
    end
    quietly expand n
    drop n
    quietly dataprobe b, by(site) maskrare byfreq
    assert !missing(r(N))
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: C2 a one-level withheld table in the audit"
}
else {
    local ++fail_count
    display as error "  FAIL: C2 a one-level withheld table in the audit"
}

* ---- C3: per-group review() counts are in the audit ----
* b == 2 in 4 Domestic and 4 Foreign rows: the frequency table prints 8,
* so two group lines of <5 forced 4 and 4 (the audit takes a review()
* total as printed, which the frequency table does here)
local ++test_count
capture noisily {
    sysuse auto, clear
    sort foreign make
    by foreign: gen byte b = cond(_n <= 4, 2, mod(_n, 2))
    capture log close v6
    log using "`W'/c3.log", text replace name(v6)
    dataprobe b, by(foreign) maskrare review(r: b == 2) warn
    log close v6
    _v6_count "`W'/c3.log" "review(r): <5 of"
    assert r(n) == 0
    _v6_count "`W'/c3.log" "review(r): [suppressed]"
    assert r(n) == 2
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: C3 per-group review() counts cannot be recovered from their total"
}
else {
    local ++fail_count
    display as error "  FAIL: C3 per-group review() counts cannot be recovered from their total"
}
capture log close v6

* ---- C4: the cap note without byfreq ----
local ++test_count
capture noisily {
    capture log close v6
    log using "`W'/c4.log", text replace name(v6)
    _dataprobe_capnote
    log close v6
    _v6_count "`W'/c4.log" "byfreq"
    assert r(n) == 0
    _v6_count "`W'/c4.log" "fewer profiled variables or per-group gates, or no maskrare"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: C4 the cap note names only the call's options"
}
else {
    local ++fail_count
    display as error "  FAIL: C4 the cap note names only the call's options"
}

capture log close v6

**# E: second fix round

* ---- E1: one (level, group) cell; degenerate sizes of the new kernels ----
* _dataprobe_bfjoin stopped with r(3200) on a byfreq table of one cell (a
* 1 x 1 indexed by a column vector is a row); 1.10.5 ran these at rc 0.
* The same calls cover the premask group order (_dataprobe_pmcount), the
* grouped byfreq tables (_dataprobe_freqprep) and the CONTINUOUS mask test
* (_dataprobe_qshowv) at one row, one group, one level, one variable.
local ++test_count
capture noisily {
    clear
    set seed 5
    quietly set obs 300
    gen byte g = ceil(_n / 60)
    gen byte one = 1
    gen byte many = ceil(runiform() * 12)
    gen double x = rnormal()
    foreach call in ///
        `"one if g == 1, by(g) maskrare byfreq"' ///
        `"many if g == 1, by(g) maskrare byfreq"' {
        capture noisily dataprobe `call'
        assert _rc == 0
        assert r(N) == 60 & r(n_groups) == 1
    }
    foreach call in ///
        `"one x, by(g) maskrare byfreq"' ///
        `"x, by(g) maskrare"' {
        capture noisily dataprobe `call'
        assert _rc == 0
        assert r(N) == 300 & r(n_groups) == 5
    }
    quietly keep if g == 1
    foreach call in ///
        `"one, by(g) maskrare byfreq"' ///
        `"one, by(g) byfreq"' ///
        `"one x many, by(g) maskrare byfreq"' {
        capture noisily dataprobe `call'
        assert _rc == 0
        assert r(N) == 60 & r(n_groups) == 1
    }
    gen byte h = 1 + (_n > 30)
    capture noisily dataprobe one, by(h) maskrare byfreq
    assert _rc == 0
    assert r(N) == 60 & r(n_groups) == 2
    * one row
    quietly keep in 1
    foreach call in ///
        `"one x, by(g) maskrare byfreq"' ///
        `"x, maskrare"' ///
        `"one, by(g) maskrare byfreq review(r: one == 1) warn"' {
        capture noisily dataprobe `call'
        assert _rc == 0
        assert r(N) == 1
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: E1 byfreq tables of one cell, one row, one group, one level"
}
else {
    local ++fail_count
    display as error "  FAIL: E1 byfreq tables of one cell, one row, one group, one level"
}

* ---- E2: the audit kernels at one level and two groups ----
local ++test_count
capture noisily {
    capture program drop dataprobe
    capture mata: mata drop _dpa*()
    capture mata: mata drop _dpa_st()
    quietly findfile dataprobe.ado
    quietly run "`r(fn)'"
    mata: st_local("_tt", invtokens(strofreal(_dpa_tabtext(3, 0, 5, 0, 10))))
    assert "`_tt'" == "-3 1"
    mata: st_local("_tt", invtokens(strofreal(_dpa_tabtext(0, 0, 5, 0, 10))))
    assert "`_tt'" == "0"
    clear
    quietly set obs 12
    gen byte g = 1 + (_n > 6)
    gen byte one = 1
    gen byte bf = 0
    egen long grp = group(g)
    _dataprobe_linkaudit, grp(grp) mask(5) cell(5) maxfreq(20) spec(";M|one||cp|;F|one|bf||")
    assert r(capped) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: E2 the audit at one level and two groups"
}
else {
    local ++fail_count
    display as error "  FAIL: E2 the audit at one level and two groups"
}

* ---- E3: a review() count that prints nowhere else is not withheld ----
* price > 4000 is no printed count: 1.10.5 printed 45 of 52 rows for
* Domestic and the first fix round withheld it
local ++test_count
capture noisily {
    sysuse auto, clear
    capture log close v6
    log using "`W'/e3.log", text replace name(v6)
    dataprobe price mpg rep78, by(foreign) maskrare byfreq review(r3: rep78 == 3 \ hi: price > 4000)
    log close v6
    _v6_count "`W'/e3.log" "review(hi): 45 of 52 rows"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: E3 a review() count with no printed total prints as in 1.10.5"
}
else {
    local ++fail_count
    display as error "  FAIL: E3 a review() count with no printed total prints as in 1.10.5"
}
capture log close v6

* ---- E4: a review() count whose total prints elsewhere stays protected ----
* rep78 == 3 is the level 3 row of rep78's table (30): Domestic 27 beside
* Foreign <5 gave Foreign back (1.10.5)
local ++test_count
capture noisily {
    sysuse auto, clear
    capture log close v6
    log using "`W'/e4.log", text replace name(v6)
    dataprobe price mpg rep78, by(foreign) maskrare review(r3: rep78 == 3)
    log close v6
    _v6_count "`W'/e4.log" "review(r3): 27 of"
    local n27 = r(n)
    _v6_count "`W'/e4.log" "review(r3): <5 of"
    assert !missing(`n27') & !missing(r(n))
    assert !(`n27' > 0 & r(n) > 0)
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: E4 a review() count linked to a printed level stays protected"
}
else {
    local ++fail_count
    display as error "  FAIL: E4 a review() count linked to a printed level stays protected"
}

capture log close v6
macro drop DATAMAP_DQ
local files : dir "`W'" files "*"
foreach f of local files {
    capture erase "`W'/`f'"
}
capture rmdir "`W'"
discard

display as text _newline "RESULT: test_dataprobe_v1106 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
