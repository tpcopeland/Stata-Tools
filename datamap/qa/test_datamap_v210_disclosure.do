*! test_datamap_v210_disclosure.do
*! datamap 2.1.0 F7 (smallcells() on microdata: id(), by(), margins) and
*! O4 (dataprobe topvalues())
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Oracles never call the code under test: cell counts come from collapse,
* fillin and egen tag over the fixture, the margins patterns from by-group
* sums of that table, the topvalues pooling from a restatement in Stata
* commands (collapse, gsort, merge, egen tag), and the planted tables from
* hand arithmetic.  Rule sources: Hundepool et al. (2026), _literature/
* datamap/hundepool-2026.notes.md; the rules tagged datamap's own in the
* help file are pinned as documented.
*
*   S1  floor and margins against the collapse/fillin oracle: seeded
*       microdata, rows only and with id(), margins(strata|conditions|both)
*   S2  id(): a cell of many rows from few persons fails, passes without it
*   S3  planted margins patterns, exact ledger messages: single,
*       singletons (ids and rows), smallsum, pinned (m-1 and ones),
*       narrowed (from below and above, with the boundaries), none
*   S4  margins(conditions) and both over by(), exact messages
*   S5  masking: a stratum withheld under maskrare and every stratum under
*       exclude() named by number; no count in any message; safe refuses
*   S6  hostile strL strata (" ' $ ` { } \) in the ledger form; strL id
*   S7  edge cases: empty scope, one stratum, all-missing by(), G = 300
*   S8  guards and errors: count column, flag with missing, string
*       condition, bad suboptions, margins requirements
*   S9  additive: the 2.0.0 results-table message; the call's by() ignored
*   S10 session state unchanged (success and error paths)
*   S11 dataqa report and assert read the new records
*   T1  topvalues() against the Stata-command oracle over seeds, with and
*       without id(): r(topvalues), listed lines, pooled values never printed
*   T2  parity with the profile's maskrare frequency table (no id())
*   T3  datamap's id() pooling rule, hand values
*   T4  total ids withheld when a complement (a level's, the pool's) is 1 to m-1
*   T5  k withheld when the pool forces a single-row level (rows < 2k)
*   T6  everything pooled below m: counts and totals withheld together
*   T7  types: value labels, extended missings, float, date, all-missing,
*       strL = str#, hostile strings printed literally
*   T8  errors: threshold, max(), exclude(), safe, empty sample
*   T9  no varlist profiles nothing; no ledger row; no "nothing checked"
*   T10 threshold and max() defaults (mincell(), dataqa set, 5, maxfreq())
*   T11 by() ignored; quietly; several entries and a varlist; state
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_datamap_v210_disclosure.log", replace text name(main)
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
local W "`base'_v210dc"
capture mkdir "`W'"
capture mkdir "`W'/plus"
capture mkdir "`W'/personal"
mata: assert(direxists(st_local("W") + "/plus"))
local oldplus : sysdir PLUS
local oldpersonal : sysdir PERSONAL
sysdir set PLUS "`W'/plus"
sysdir set PERSONAL "`W'/personal"
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace
discard
quietly do _qa_state.do
quietly do _qa_hostile.do
local tests = 0
local pass = 0
local fail = 0
macro drop DATAMAP_DQ

**# Helpers

mata:
string scalar _dc_slurp(string scalar fn)
{
	real scalar fh
	string scalar s, line
	fh = fopen(fn, "r")
	s = ""
	while ((line = fget(fh)) != J(0, 0, "")) s = s + line + char(10)
	fclose(fh)
	return(s)
}
real scalar _dc_has(string scalar fn, string scalar needle)
{
	return(strpos(_dc_slurp(fn), needle) > 0)
}
// the lines of a log matching a regular expression, in order
string scalar _dc_lines(string scalar fn, string scalar re)
{
	real scalar fh
	string scalar s, line
	fh = fopen(fn, "r")
	s = ""
	while ((line = fget(fh)) != J(0, 0, "")) {
		if (ustrregexm(line, re)) s = s + line + char(10)
	}
	fclose(fh)
	return(s)
}
// the ledger form of a string value, as dataprobe documents it: in square
// brackets, each of \ " ' ` $ [ ] { } tab LF CR as \xHH
string scalar _dc_esc(string scalar s)
{
	real scalar i, a
	string scalar out, c
	out = ""
	for (i = 1; i <= strlen(s); i++) {
		c = substr(s, i, 1)
		a = ascii(c)
		if (a == 92 | a == 34 | a == 39 | a == 96 | a == 36 | a == 91 | a == 93 | a == 123 | a == 125 | a == 9 | a == 10 | a == 13) {
			out = out + "\x" + substr("0123456789abcdef", floor(a / 16) + 1, 1) + substr("0123456789abcdef", mod(a, 16) + 1, 1)
		}
		else out = out + c
	}
	return("[" + out + "]")
}
end

* _dc_cap file : command   runs command with its output in a text log;
* r() is the command's, plus r(rc)
capture program drop _dc_cap
program define _dc_cap, rclass
    gettoken file 0 : 0
    gettoken colon 0 : 0, parse(":")
    capture log close _dccap
    quietly log using `"`file'"', text replace name(_dccap)
    capture noisily `0'
    local rc = _rc
    return add
    quietly log close _dccap
    return scalar rc = `rc'
end

* _dc_table "g j n nid \ ...": microdata with n rows in cell (g, c = j) from
* nid persons of their own (pid), the rows spread over the persons in turn
capture program drop _dc_table
program define _dc_table
    args spec
    clear
    tempname T
    matrix `T' = (`spec')
    quietly svmat double `T', names(col)
    rename (c1 c2 c3 c4) (g c n nid)
    quietly drop if n == 0
    generate long cell = _n
    quietly expand n
    sort cell, stable
    quietly by cell: generate long pid = cell * 1000 + mod(_n - 1, nid)
    drop cell n nid
end

* _dc_micro seed n G J: seeded microdata, skewed strata g and categories c
* (every category 1..J on some row), persons pid with about 2 rows each
capture program drop _dc_micro
program define _dc_micro
    args seed n G J
    clear
    set seed `seed'
    quietly set obs `n'
    generate long pid = 1 + floor(runiform() * (`n' / 2))
    generate int g = 1 + floor(runiform()^2 * `G')
    generate int c = 1 + floor(runiform()^1.7 * `J')
    quietly replace c = _n in 1/`J'
end

* _dc_oracle, m() J() [id() strata conditions]: the cells (g, c==1..J) of
* the data in memory by collapse and fillin, and the margins patterns by
* by-group sums.  r(nbad) failing cells, r(nxs) exposed strata, r(nxc)
* exposed conditions.  The data are left as they were.
capture program drop _dc_oracle
program define _dc_oracle, rclass
    syntax , M(integer) J(integer) [ID(varname) STRATA CONDITIONS]
    preserve
    local hasid = ("`id'" != "")
    if `hasid' {
        quietly bysort g c `id': generate byte _t = (_n == 1)
    }
    else quietly generate byte _t = 0
    quietly generate byte _one = 1
    quietly collapse (sum) n = _one nid = _t, by(g c)
    quietly fillin g c
    quietly replace n = 0 if _fillin
    quietly replace nid = 0 if _fillin
    quietly count if !inrange(c, 1, `j')
    assert r(N) == 0
    quietly levelsof g
    local G : word count `r(levels)'
    quietly generate byte sm = inrange(n, 1, `m' - 1) | (`hasid' & inrange(nid, 1, `m' - 1))
    quietly count if sm
    return scalar nbad = r(N)
    quietly generate double u1 = cond(`hasid', nid, n)
    foreach rt in strata conditions {
        local key = cond("`rt'" == "strata", "g", "c")
        local size = cond("`rt'" == "strata", `j', `G')
        quietly bysort `key': egen double k = total(sm)
        quietly by `key': egen double sn = total(n * sm)
        quietly by `key': egen double sd = total(nid * sm)
        quietly by `key': egen double s1 = total(sm & u1 == 1)
        quietly by `key': egen double an = min(cond(sm, inrange(n, 1, `m' - 1), 1))
        quietly by `key': egen double ai = min(cond(sm, inrange(nid, 1, `m' - 1), 1))
        quietly generate byte ex = (k == 1) | (k == 2 & s1 == 2) | ///
            (k >= 2 & (sn < `m' | (`hasid' & sd < `m'))) | ///
            (k >= 2 & an & (max(1, sn - (k - 1) * (`m' - 1)) > 1 | min(`m' - 1, sn - (k - 1)) < `m' - 1 | sn <= k)) | ///
            (k >= 2 & `hasid' & ai & (max(1, sd - (k - 1) * (`m' - 1)) > 1 | min(`m' - 1, sd - (k - 1)) < `m' - 1 | sd <= k))
        quietly by `key': generate byte first = (_n == 1)
        quietly count if first & ex & `size' >= 2
        local nx_`rt' = r(N)
        drop k sn sd s1 an ai ex first
    }
    return scalar nxs = cond("`strata'" != "", `nx_strata', 0)
    return scalar nxc = cond("`conditions'" != "", `nx_conditions', 0)
    return scalar G = `G'
    restore
end

* _tv_oracle varname, m() mx() [id()]: topvalues() restated with Stata
* commands on the data in memory.  r(N) r(NID) r(L) r(s) r(k) r(RR) r(RD)
* as the block prints them (missing where withheld), r(kraw) the pooled
* levels, r(shown) "level:rows[:ids] ..." in rank order, r(pooled) the
* pooled values.  For the token levels of these fixtures (no spaces).
capture program drop _tv_oracle
program define _tv_oracle, rclass
    syntax varname, M(integer) MX(integer) [ID(varname)]
    local v `varlist'
    local hasid = ("`id'" != "")
    preserve
    tempfile LV
    quietly generate byte _one = 1
    if `hasid' quietly bysort `v' `id': generate byte _t = (_n == 1)
    else quietly generate byte _t = 0
    quietly count
    local N = r(N)
    local NID = .
    if `hasid' {
        tempvar tg
        quietly egen byte `tg' = tag(`id')
        quietly count if `tg'
        local NID = r(N)
        drop `tg'
    }
    quietly save "`LV'_micro", replace
    quietly collapse (sum) n = _one nid = _t, by(`v')
    gsort -n `v'
    quietly generate long rk = _n
    local L = _N
    quietly generate byte sup = n < `m'
    if `hasid' quietly replace sup = 1 if nid < `m'
    quietly count if sup
    if r(N) {
        while 1 {
            quietly count if sup | rk > `mx'
            local pn = r(N)
            quietly summarize n if sup | rk > `mx', meanonly
            local ps = r(sum)
            if `pn' >= 2 & `ps' >= `m' continue, break
            quietly summarize rk if !sup & rk <= `mx', meanonly
            if r(N) == 0 continue, break
            quietly replace sup = 1 if rk == r(max)
        }
    }
    quietly generate byte res = sup | rk > `mx'
    quietly save "`LV'", replace
    local ok = 1
    while 1 {
        quietly use "`LV'", clear
        quietly summarize n if res, meanonly
        local RR = r(sum)
        local RD = .
        if `hasid' {
            quietly use "`LV'_micro", clear
            quietly merge m:1 `v' using "`LV'", keepusing(res) nogenerate
            tempvar tg
            quietly egen byte `tg' = tag(`id') if res == 1
            quietly count if `tg' == 1
            local RD = r(N)
        }
        local bad = inrange(`RR', 1, `m' - 1) | (`hasid' & inrange(`RD', 1, `m' - 1))
        if !`bad' continue, break
        quietly use "`LV'", clear
        quietly summarize rk if !res, meanonly
        if r(N) == 0 {
            local ok = 0
            continue, break
        }
        quietly replace res = 1 if rk == r(max)
        quietly save "`LV'", replace
    }
    quietly use "`LV'", clear
    quietly count if res
    local k = r(N)
    local s = _N - `k'
    local pN = (`k' == 0 | `ok')
    local pNID = 0
    if `hasid' & `pN' {
        local pNID = (`NID' == 0 | `NID' >= `m')
        quietly count if !res & inrange(`NID' - nid, 1, `m' - 1)
        if r(N) local pNID = 0
        if `k' & inrange(`NID' - `RD', 1, `m' - 1) local pNID = 0
    }
    * fewer than 2k rows in k levels force a pooled level of one row
    local pK = (`k' > 0 & `ok' & `RR' >= 2 * `k')
    if `hasid' & `pK' local pK = (`RD' > `k')
    local shown ""
    local pooled ""
    forvalues i = 1/`=_N' {
        local lv = `v'[`i']
        if res[`i'] local pooled "`pooled' `lv'"
        else {
            local e "`lv':`=n[`i']'"
            if `hasid' local e "`e':`=nid[`i']'"
            local shown "`shown' `e'"
        }
    }
    return scalar N = cond(`pN', `N', .)
    return scalar NID = cond(`pNID', `NID', .)
    return scalar L = cond(`k' == 0 | `pK', `L', .)
    return scalar s = `s'
    return scalar k = cond(`k' == 0 | `pK', `k', .)
    return scalar kraw = `k'
    return scalar RR = cond(`k' & `ok', `RR', .)
    return scalar RD = cond(`k' & `ok' & `hasid', `RD', .)
    return local shown = strtrim("`shown'")
    return local pooled = strtrim("`pooled'")
    capture erase "`LV'_micro"
    restore
end

* _tv_fix seed n nlev: a str3 variable v of tokens L01..Lnn, skewed, and
* persons pid with about 2 rows each
capture program drop _tv_fix
program define _tv_fix
    args seed n nlev
    clear
    set seed `seed'
    quietly set obs `n'
    generate str3 v = "L" + string(1 + floor(runiform()^2.2 * `nlev'), "%02.0f")
    generate long pid = 1 + floor(runiform() * (`n' / 2))
end

**# S1 floor and margins against the collapse/fillin oracle
local ++tests
capture noisily {
    local ncases = 0
    foreach seed in 101 102 103 104 {
        foreach hid in 0 1 {
            foreach mg in strata conditions both {
                _dc_micro `seed' 160 5 4
                local idopt = cond(`hid', "id(pid) ", "")
                local so = cond("`mg'" == "both", "strata conditions", "`mg'")
                local mo = cond("`mg'" == "both", "margins", "margins(`mg')")
                _dc_oracle, m(5) j(4) `=cond(`hid', "id(pid)", "")' `so'
                local want_bad = r(nbad)
                local want_x = r(nxs) + r(nxc)
                local f "`W'/s1.dta"
                capture erase "`f'"
                capture noisily dataprobe, gatesonly mincell(5) ledger("`f'") ///
                    smallcells(c==1 c==2 c==3 c==4, `idopt'by(g) `mo')
                local rc = _rc
                quietly use "`f'", clear
                quietly keep if family == "smallcells"
                assert _N == 2
                assert observed_num[1] == `want_bad'
                assert status[1] == cond(`want_bad' == 0, "pass", "fail")
                assert observed_num[2] == `want_x'
                assert status[2] == cond(`want_x' == 0, "pass", "fail")
                assert `rc' == cond(`want_bad' + `want_x' == 0, 0, 9)
                assert ustrregexm(label[2], " \[margins\]$")
                local ++ncases
                if `want_bad' > 0 local anyb = 1
                if `want_x' > 0 local anyx = 1
            }
        }
    }
    display as text "S1: `ncases' seeded cases agree with the oracle"
    * the fixtures exercise both outcomes
    assert "`anyb'" == "1" & "`anyx'" == "1"
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: S1 floor and margins = collapse/fillin oracle (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S1 floor and margins = collapse/fillin oracle"
}

**# S2 id(): many rows from few persons
local ++tests
capture noisily {
    * c==1: 10 rows from 2 persons; c==2: 20 rows from 20 persons
    _dc_table "1, 1, 10, 2 \ 1, 2, 20, 20"
    local f "`W'/s2.dta"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2, id(pid)) ledger("`f'")
    assert _rc == 9
    quietly use "`f'", clear
    assert _N == 1 & status[1] == "fail" & observed_num[1] == 1
    assert message[1] == "smallcells(c==1 c==2, id(pid)): 1 cells fail, c==1 (ids); expected no cell of 1..4 rows or ids (m=5)"
    assert expected[1] == "no cell of 1..4 rows or ids (m=5)"
    * without id() the rows pass
    _dc_table "1, 1, 10, 2 \ 1, 2, 20, 20"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2, by(g)) ledger("`f'")
    assert _rc == 0
    quietly use "`f'", clear
    assert status[1] == "pass" & observed_num[1] == 0
    assert message[1] == "smallcells(c==1 c==2, by(g)): no cell of 1..4 rows (m=5)"
    * small in both units
    _dc_table "1, 1, 3, 2 \ 1, 2, 20, 20"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2, id(pid)) ledger("`f'")
    quietly use "`f'", clear
    assert strpos(message[1], "c==1 (rows, ids)") > 0
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: S2 id() checks distinct persons in the same pass (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S2 id() checks distinct persons in the same pass"
}

**# S3 planted margins patterns, exact messages
local ++tests
capture noisily {
    local f "`W'/s3.dta"
    local E2 "expected no small cell recoverable from a margin (m=5)"
    * single: (20, 3, 20)
    _dc_table "1, 1, 20, 20 \ 1, 2, 3, 3 \ 1, 3, 20, 20"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2 c==3, margins) ledger("`f'")
    assert _rc == 9
    quietly use "`f'", clear
    assert _N == 2
    assert message[1] == "smallcells(c==1 c==2 c==3, margins): 1 cells fail, c==2 (rows); expected no cell of 1..4 rows (m=5)"
    assert label[2] == "c==1 c==2 c==3, margins [margins]"
    assert observed[2] == "1 margins exposed" & observed_num[2] == 1 & status[2] == "fail"
    assert message[2] == "smallcells(c==1 c==2 c==3, margins) margins: 1 exposed, total: single (c==2); `E2'"
    * singletons with id(): 2 rows and 3 rows, each from one person
    _dc_table "1, 1, 20, 20 \ 1, 2, 2, 1 \ 1, 3, 3, 1"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2 c==3, id(pid) margins) ledger("`f'")
    quietly use "`f'", clear
    assert message[2] == "smallcells(c==1 c==2 c==3, id(pid) margins) margins: 1 exposed, total: singletons (c==2, c==3); `E2'"
    * the same rows without id(): 2 + 3 = 5, interval 1..4, not exposed
    _dc_table "1, 1, 20, 20 \ 1, 2, 2, 1 \ 1, 3, 3, 1"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2 c==3, margins) ledger("`f'")
    assert _rc == 9
    quietly use "`f'", clear
    assert status[1] == "fail" & observed_num[1] == 2
    assert status[2] == "pass" & observed_num[2] == 0
    assert message[2] == "smallcells(c==1 c==2 c==3, margins) margins: no small cell recoverable from a margin (m=5)"
    * singletons in rows: (20, 1, 1)
    _dc_table "1, 1, 20, 20 \ 1, 2, 1, 1 \ 1, 3, 1, 1"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2 c==3, margins) ledger("`f'")
    quietly use "`f'", clear
    assert strpos(message[2], "total: singletons (c==2, c==3)") > 0
    * smallsum: (20, 1, 2)
    _dc_table "1, 1, 20, 20 \ 1, 2, 1, 1 \ 1, 3, 2, 2"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2 c==3, margins) ledger("`f'")
    quietly use "`f'", clear
    assert message[2] == "smallcells(c==1 c==2 c==3, margins) margins: 1 exposed, total: smallsum (c==2, c==3); `E2'"
    * pinned at m-1: (20, 4, 4), sum 8 = 2 x 4
    _dc_table "1, 1, 20, 20 \ 1, 2, 4, 4 \ 1, 3, 4, 4"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2 c==3, margins) ledger("`f'")
    quietly use "`f'", clear
    assert message[2] == "smallcells(c==1 c==2 c==3, margins) margins: 1 exposed, total: pinned (c==2, c==3); `E2'"
    * pinned at one: five single rows, sum 5 = 5 cells (not below m)
    _dc_table "1, 1, 20, 20 \ 1, 2, 1, 1 \ 1, 3, 1, 1 \ 1, 4, 1, 1 \ 1, 5, 1, 1 \ 1, 6, 1, 1"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2 c==3 c==4 c==5 c==6, margins) ledger("`f'")
    quietly use "`f'", clear
    assert strpos(message[2], "total: pinned (c==2, c==3, c==4, c==5, c==6)") > 0
    * narrowed (m=10): 9 + 8 = 17 from the total, so each is 8 or 9
    _dc_table "1, 1, 9, 9 \ 1, 2, 8, 8 \ 1, 3, 113, 113"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(10) smallcells(c==1 c==2 c==3, margins) ledger("`f'")
    assert _rc == 9
    quietly use "`f'", clear
    assert message[2] == "smallcells(c==1 c==2 c==3, margins) margins: 1 exposed, total: narrowed (c==1, c==2); expected no small cell recoverable from a margin (m=10)"
    * the boundary: 5 + 5 = 10 = m leaves each 1..9, not exposed
    _dc_table "1, 1, 5, 5 \ 1, 2, 5, 5 \ 1, 3, 113, 113"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(10) smallcells(c==1 c==2 c==3, margins) ledger("`f'")
    quietly use "`f'", clear
    assert status[2] == "pass" & observed_num[2] == 0
    * narrowed from above (m=5): 1 + 1 + 1 + 2 = 5 leaves each 1 or 2
    _dc_table "1, 1, 20, 20 \ 1, 2, 1, 1 \ 1, 3, 1, 1 \ 1, 4, 1, 1 \ 1, 5, 2, 2"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2 c==3 c==4 c==5, margins) ledger("`f'")
    quietly use "`f'", clear
    assert strpos(message[2], "total: narrowed (c==2, c==3, c==4, c==5)") > 0
    * three cells (m=10) 3 + 3 + 5 = 11: each still 1..9, not exposed
    _dc_table "1, 1, 3, 3 \ 1, 2, 3, 3 \ 1, 3, 5, 5 \ 1, 4, 113, 113"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(10) smallcells(c==1 c==2 c==3 c==4, margins) ledger("`f'")
    quietly use "`f'", clear
    assert status[2] == "pass" & observed_num[2] == 0
    * a zero beside large cells is not small
    _dc_table "1, 1, 20, 20 \ 1, 3, 30, 30"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2 c==3, margins) ledger("`f'")
    assert _rc == 0
    quietly use "`f'", clear
    assert status[1] == "pass" & status[2] == "pass"
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: S3 planted margins patterns (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S3 planted margins patterns"
}

**# S4 margins over by(): conditions, strata, both
local ++tests
capture noisily {
    local f "`W'/s4.dta"
    local E2 "expected no small cell recoverable from a margin (m=5)"
    local T "1, 1, 30, 30 \ 1, 2, 30, 30 \ 2, 1, 2, 2 \ 2, 2, 30, 30 \ 3, 1, 30, 30 \ 3, 2, 30, 30"
    _dc_table "`T'"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2, by(g) margins(conditions)) ledger("`f'")
    quietly use "`f'", clear
    assert message[1] == "smallcells(c==1 c==2, by(g) margins(conditions)): 1 cells fail, c==1 in g=2 (rows); expected no cell of 1..4 rows (m=5)"
    assert message[2] == "smallcells(c==1 c==2, by(g) margins(conditions)) margins: 1 exposed, c==1: single (g=2); `E2'"
    _dc_table "`T'"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2, by(g) margins(strata)) ledger("`f'")
    quietly use "`f'", clear
    assert message[2] == "smallcells(c==1 c==2, by(g) margins(strata)) margins: 1 exposed, g=2: single (c==1); `E2'"
    _dc_table "`T'"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2, by(g) margins) ledger("`f'")
    quietly use "`f'", clear
    assert message[2] == "smallcells(c==1 c==2, by(g) margins) margins: 2 exposed, g=2: single (c==1); c==1: single (g=2); `E2'"
    * no margins: one record only
    _dc_table "`T'"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2, by(g)) ledger("`f'")
    quietly use "`f'", clear
    assert _N == 1
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: S4 margins over by() (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S4 margins over by()"
}

**# S5 masking: withheld strata by number, no count printed, safe
local ++tests
capture noisily {
    local f "`W'/s5.dta"
    capture program drop _dc_s5fix
    program define _dc_s5fix
        clear
        quietly set obs 33
        generate str2 s = cond(_n <= 30, "aa", "bb")
        generate str1 c = cond(_n <= 15 | _n > 30, "x", "y")
        generate long pid = _n
    end
    _dc_s5fix
    capture erase "`f'"
    capture noisily dataprobe, gatesonly maskrare mincell(5) smallcells((c=="x") (c=="y"), by(s) margins) ledger("`f'")
    assert _rc == 9
    quietly use "`f'", clear
    assert message[1] == `"smallcells((c=="x") (c=="y"), by(s) margins): <5 cells fail, (c=="x") in group 2 (rows); expected no cell of 1..4 rows (m=5)"'
    assert message[2] == `"smallcells((c=="x") (c=="y"), by(s) margins) margins: <5 exposed, group 2: single ((c=="x")); (c=="x"): single (group 2); expected no small cell recoverable from a margin (m=5)"'
    assert observed[1] == "<5 cells fail" & missing(observed_num[1]) & obs_masked[1] == 1
    assert observed[2] == "<5 margins exposed" & missing(observed_num[2]) & obs_masked[2] == 1
    * no digit beyond the threshold text, the masked count and the group number
    forvalues r = 1/2 {
        local mm = message[`r']
        mata: st_local("rest", ustrregexra(st_local("mm"), "1\.\.4|m=5|<5|group 2", ""))
        mata: assert(!ustrregexm(st_local("rest"), "[0-9]"))
        assert strpos(`"`mm'"', "bb") == 0
    }
    * without maskrare the stratum is named by its value
    _dc_s5fix
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells((c=="x") (c=="y"), by(s) margins) ledger("`f'")
    quietly use "`f'", clear
    assert message[1] == `"smallcells((c=="x") (c=="y"), by(s) margins): 1 cells fail, (c=="x") in s=[bb] (rows); expected no cell of 1..4 rows (m=5)"'
    assert strpos(message[2], `"s=[bb]: single ((c=="x")); (c=="x"): single (s=[bb])"') > 0
    * a stratum of 5 or more rows keeps its value under maskrare: bb has 8
    * rows, 3 of them x
    _dc_s5fix
    quietly set obs 38
    quietly replace s = "bb" in 34/38
    quietly replace c = "y" in 34/38
    capture erase "`f'"
    capture noisily dataprobe, gatesonly maskrare mincell(5) smallcells((c=="x") (c=="y"), by(s)) ledger("`f'")
    quietly use "`f'", clear
    assert strpos(message[1], `"(c=="x") in s=[bb] (rows)"') > 0
    * exclude(): every stratum by number
    _dc_s5fix
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) exclude(s) smallcells((c=="x") (c=="y"), by(s)) ledger("`f'")
    quietly use "`f'", clear
    assert strpos(message[1], `"(c=="x") in group 2 (rows)"') > 0 & strpos(message[1], "bb") == 0
    * safe refuses a by() variable whose values it withholds
    _dc_s5fix
    generate str3 code = "a" + string(mod(_n, 3))
    capture noisily dataprobe, gatesonly safe smallcells((c=="x"), by(code))
    assert _rc == 198
    generate long patient_id = _n
    capture noisily dataprobe, gatesonly safe smallcells((c=="x"), by(patient_id))
    assert _rc == 198
    * safe with a digit-free string stratum runs
    capture noisily dataprobe, gatesonly safe smallcells((c=="x"), by(s))
    assert _rc == 9
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: S5 masking of strata and counts (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S5 masking of strata and counts"
}

**# S6 hostile strL strata; strL id
local ++tests
capture noisily {
    local f "`W'/s6.dta"
    qa_hostile_strings
    local hs "QA_HS_DQ QA_HS_TICK QA_HS_DOLLAR QA_HS_APOS QA_HS_BSLASH QA_HS_TICKPAIR"
    clear
    quietly set obs 84
    generate strL s = ""
    generate byte c = 2
    local i = 0
    foreach g of local hs {
        local ++i
        local a = (`i' - 1) * 12 + 1
        local b = `i' * 12
        mata: for (r = `a'; r <= `b'; r++) st_sstore(r, "s", st_global("`g'"))
        * two rows of c==1 in each stratum: a small cell
        quietly replace c = 1 in `a'/`=`a' + 1'
    }
    mata: for (r = 73; r <= 84; r++) st_sstore(r, "s", char(123) + "e" + char(125))
    quietly replace c = 1 in 73/74
    generate long pid = _n
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2, by(s) margins) ledger("`f'")
    assert _rc == 9
    quietly use "`f'", clear
    assert observed_num[1] == 7
    local mm = message[1]
    mata: st_local("hit", strofreal(strpos(st_local("mm"), "EXPANDED")))
    assert `hit' == 0
    foreach g of local hs {
        mata: st_local("hit", strofreal(strpos(st_local("mm"), "s=" + _dc_esc(st_global("`g'")))))
        assert `hit' > 0
    }
    * seven failing cells: all listed (the list stops at eight)
    assert strpos(message[1], "and more") == 0
    mata: st_local("hit", strofreal(strpos(st_local("mm"), "s=" + _dc_esc(char(123) + "e" + char(125)))))
    assert `hit' > 0
    * a strL id gives the numeric id's records
    clear
    quietly set obs 40
    generate int c = 1 + (_n > 10)
    generate long pid = ceil(_n / 3)
    generate strL spid = "p" + string(pid)
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2, id(pid)) ledger("`f'")
    preserve
    quietly use "`f'", clear
    local n1 = observed_num[1]
    local m1 = message[1]
    restore
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2, id(spid)) ledger("`f'")
    quietly use "`f'", clear
    assert observed_num[1] == `n1' & `n1' == 1
    assert subinstr(message[1], "id(spid)", "id(pid)", 1) == "`m1'"
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: S6 hostile strL strata and strL id (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S6 hostile strL strata and strL id"
}

**# S7 edge cases
local ++tests
capture noisily {
    local f "`W'/s7.dta"
    * an entry if that selects nothing: both records pass with 0
    _dc_micro 7 80 3 3
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2 if c == 99, by(g) margins) ledger("`f'")
    assert _rc == 0
    quietly use "`f'", clear
    assert _N == 2 & observed[1] == "0 cells fail" & observed[2] == "0 margins exposed"
    assert scope[1] == "c == 99"
    * one stratum: the counts of the call without by()
    _dc_micro 8 80 3 3
    generate byte k = 1
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2 c==3, id(pid)) ledger("`f'")
    preserve
    quietly use "`f'", clear
    local n0 = observed_num[1]
    local s0 = status[1]
    restore
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2 c==3, id(pid) by(k)) ledger("`f'")
    preserve
    quietly use "`f'", clear
    assert observed_num[1] == `n0' & status[1] == "`s0'"
    if `n0' > 0 assert strpos(message[1], " in k=1 (") > 0
    restore
    * an all-missing by() variable is one stratum, written as its code
    quietly replace k = .
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2 c==3, id(pid) by(k)) ledger("`f'")
    quietly use "`f'", clear
    assert observed_num[1] == `n0'
    if `n0' > 0 assert strpos(message[1], " in k=. (") > 0
    * many strata: 300, against the oracle
    _dc_micro 9 3000 300 3
    _dc_oracle, m(5) j(3) id(pid) strata conditions
    local wb = r(nbad)
    local wx = r(nxs) + r(nxc)
    assert !missing(r(G)) & r(G) >= 250
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2 c==3, id(pid) by(g) margins) ledger("`f'")
    quietly use "`f'", clear
    assert observed_num[1] == `wb' & observed_num[2] == `wx'
    * more than eight failing cells: eight listed, then "and more"
    assert `wb' > 8
    assert ustrregexm(message[1], ", and more; expected ")
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: S7 edge cases (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S7 edge cases"
}

**# S8 guards and errors
local ++tests
capture noisily {
    _dc_micro 11 60 3 3
    generate double cnt = 7
    generate byte flag = (c == 1)
    quietly replace flag = . in 5
    generate str1 sv = "a"
    * a count column is not a condition
    capture noisily dataprobe, gatesonly mincell(5) smallcells(cnt, by(g))
    assert _rc == 459
    * a flag with a missing value is refused, never counted
    capture noisily dataprobe, gatesonly mincell(5) smallcells(flag, by(g))
    assert _rc == 459
    * ... unless the row is out of scope
    capture noisily dataprobe, gatesonly mincell(5) smallcells(flag if !missing(flag), by(g)) warn
    assert _rc == 0
    capture noisily dataprobe, gatesonly mincell(5) smallcells(sv, id(pid))
    assert _rc == 109
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1, by(nosuch))
    assert _rc == 111
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1, id(pid nosuch))
    assert _rc != 0
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1, color(red))
    assert _rc == 198
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2, margins(rows))
    assert _rc == 198
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2, )
    assert _rc == 198
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1, margins(strata) by(g))
    assert _rc == 198
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2, margins(conditions))
    assert _rc == 198
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1, margins)
    assert _rc == 198
    * margins with one condition and by() audits the strata of that condition
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1, margins by(g)) warn
    assert _rc == 0
    * no threshold: the 2.0.0 error
    capture noisily dataprobe, gatesonly smallcells(c==1, by(g))
    assert _rc == 198
    * a comma inside quotes or parentheses is not the suboption comma
    capture noisily dataprobe, gatesonly mincell(5) smallcells((inlist(c,1,2)) (sv==","), by(g)) warn
    assert _rc == 0
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: S8 guards and errors (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S8 guards and errors"
}

**# S9 additive: the results-table message; the call's by() ignored
local ++tests
capture noisily {
    local f "`W'/s9.dta"
    clear
    quietly set obs 3
    generate n1 = 40
    generate e1 = 12
    quietly replace e1 = 1 in 2
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(n1 e1) ledger("`f'")
    assert _rc == 9
    quietly use "`f'", clear
    assert _N == 1
    assert message[1] == "smallcells(n1 e1): 1 table rows fail, e1 (1 small); expected no released count in 1..4 (m=5)"
    assert observed[1] == "1 rows fail" & expected[1] == "no released count in 1..4 (m=5)"
    * the call's by() does not split the microdata audit
    _dc_micro 12 120 3 3
    generate byte arm = mod(_n, 2)
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2 c==3, by(g) margins) ledger("`f'")
    preserve
    quietly use "`f'", clear
    quietly keep if family == "smallcells"
    local a1 = message[1]
    local a2 = message[2]
    restore
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) by(arm) smallcells(c==1 c==2 c==3, by(g) margins) ledger("`f'")
    quietly use "`f'", clear
    quietly keep if family == "smallcells"
    assert _N == 2 & grp[1] == "" & grp[2] == ""
    assert message[1] == "`a1'" & message[2] == "`a2'"
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: S9 additive behaviour (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S9 additive behaviour"
}

**# S10 session state unchanged
local ++tests
capture noisily {
    _dc_micro 13 90 3 3
    sort c pid
    qa_state_snapshot, tag(dc_sc_ok)
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2, id(pid) by(g) margins)
    assert inlist(_rc, 0, 9)
    qa_state_compare, tag(dc_sc_ok)
    qa_state_snapshot, tag(dc_sc_err)
    capture noisily dataprobe, gatesonly mincell(5) smallcells(pid, by(g))
    assert _rc == 459
    qa_state_compare, tag(dc_sc_err)
    _tv_fix 13 90 8
    qa_state_snapshot, tag(dc_tv_ok)
    capture noisily dataprobe, topvalues(v, id(pid))
    assert _rc == 0
    qa_state_compare, tag(dc_tv_ok)
    qa_state_snapshot, tag(dc_tv_err)
    capture noisily dataprobe, topvalues(v, mincell(1))
    assert _rc == 198
    qa_state_compare, tag(dc_tv_err)
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: S10 session state unchanged (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S10 session state unchanged"
}

**# S11 dataqa reads the new records
local ++tests
capture noisily {
    local f "`W'/s11.dta"
    _dc_table "1, 1, 30, 30 \ 1, 2, 30, 30 \ 2, 1, 2, 2 \ 2, 2, 30, 30"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2, id(pid) by(g) margins) ledger("`f'", run(s11))
    assert _rc == 9
    dataqa report using "`f'", run(s11)
    capture noisily dataqa assert using "`f'", run(s11)
    assert _rc == 9
    * a clean audit asserts
    _dc_table "1, 1, 30, 30 \ 1, 2, 30, 30 \ 2, 1, 20, 20 \ 2, 2, 30, 30"
    capture erase "`f'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2, id(pid) by(g) margins) ledger("`f'", run(s11))
    assert _rc == 0
    dataqa assert using "`f'", run(s11)
    quietly use "`f'", clear
    assert _N == 2 & label[1] != label[2]
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: S11 dataqa reads the new records (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: S11 dataqa reads the new records"
}

**# T1 topvalues() against the Stata-command oracle
local ++tests
capture noisily {
    local f "`W'/t1.log"
    local ncases = 0
    foreach seed in 201 202 203 204 205 {
        foreach hid in 0 1 {
            foreach mx in 20 4 {
                _tv_fix `seed' 150 14
                local io = cond(`hid', " id(pid)", "")
                _tv_oracle v, m(5) mx(`mx') `=cond(`hid', "id(pid)", "")'
                foreach q in N NID L s k RR RD kraw {
                    local o_`q' = r(`q')
                }
                local o_shown "`r(shown)'"
                local o_pooled "`r(pooled)'"
                _dc_cap "`f'" : dataprobe, topvalues(v, mincell(5) max(`mx')`io')
                assert r(rc) == 0
                tempname M
                matrix `M' = r(topvalues)
                assert rowsof(`M') == 1 & colsof(`M') == 7
                local j = 0
                foreach q in N NID L s k RR RD {
                    local ++j
                    assert `M'[1, `j'] == `o_`q'' | (missing(`M'[1, `j']) & missing(`o_`q''))
                }
                * every listed level prints with its rows (and ids), in rank order
                local listed = 0
                foreach e of local o_shown {
                    gettoken lv e : e, parse(":")
                    gettoken colon e : e, parse(":")
                    gettoken nr e : e, parse(":")
                    local re "^    `lv' +`nr'  \("
                    if `hid' {
                        gettoken colon e : e, parse(":")
                        local re "`re'.*\)  ids `e'$"
                    }
                    mata: st_local("nl", strofreal(ustrlen(_dc_lines(st_local("f"), st_local("re"))) > 0))
                    assert `nl' == 1
                    local ++listed
                }
                assert `listed' == `o_s'
                * no pooled value appears anywhere in the output
                foreach lv of local o_pooled {
                    mata: st_local("hit", strofreal(_dc_has(st_local("f"), st_local("lv"))))
                    assert `hit' == 0
                }
                local ++ncases
                if `o_kraw' > 0 local anyk = 1
            }
        }
    }
    assert "`anyk'" == "1"
    display as text "T1: `ncases' seeded cases agree with the oracle"
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: T1 topvalues = Stata-command oracle (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: T1 topvalues = Stata-command oracle"
}

**# T2 parity with the profile's maskrare frequency table
local ++tests
capture noisily {
    local f1 "`W'/t2a.log"
    local f2 "`W'/t2b.log"
    local re "^    L[0-9][0-9] +[0-9]+  \([ 0-9.]+%\)$"
    foreach seed in 301 302 303 304 {
        foreach mx in 20 5 {
            _tv_fix `seed' 120 12
            _tv_oracle v, m(5) mx(`mx')
            local kraw = r(kraw)
            _dc_cap "`f1'" : dataprobe v, maskrare mincell(5) maxfreq(`mx')
            assert r(rc) == 0
            _dc_cap "`f2'" : dataprobe, topvalues(v, mincell(5) max(`mx'))
            assert r(rc) == 0
            mata: st_local("same", strofreal(_dc_lines(st_local("f1"), st_local("re")) == _dc_lines(st_local("f2"), st_local("re"))))
            mata: st_local("nl", strofreal(ustrlen(_dc_lines(st_local("f2"), st_local("re")))))
            assert `same' == 1 & `nl' > 0
            * the profile's withheld rows and its maxfreq remainder: the pool
            mata: st_local("more", _dc_lines(st_local("f1"), "^    \.\.\. [0-9]+ more level"))
            local nmore = 0
            if regexm(`"`more'"', "\.\.\. ([0-9]+) more") local nmore = regexs(1)
            * tokens() with a parse character returns the separators too
            mata: st_local("nsup", strofreal(sum(tokens(_dc_lines(st_local("f1"), "^    \[suppressed\] "), char(10)) :!= char(10))))
            assert `nsup' + `nmore' == `kraw'
        }
    }
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: T2 parity with the profile's maskrare table (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: T2 parity with the profile's maskrare table"
}

**# T3 datamap's id() pooling rule, hand values
local ++tests
capture noisily {
    local f "`W'/t3.log"
    * A 30 rows / 10 persons, B 20/8, C 12/2, D 6/6, E 2/2; persons of their own
    capture program drop _dc_t3fix
    program define _dc_t3fix
        clear
        generate str1 v = ""
        generate long pid = .
        local rows "30 20 12 6 2"
        local ppl "10 8 2 6 2"
        local labs "A B C D E"
        local base = 0
        forvalues i = 1/5 {
            local n : word `i' of `rows'
            local p : word `i' of `ppl'
            local l : word `i' of `labs'
            local N0 = _N
            quietly set obs `=`N0' + `n''
            quietly replace v = "`l'" in `=`N0' + 1'/l
            quietly replace pid = `base' + mod(_n - `N0' - 1, `p') + 1 in `=`N0' + 1'/l
            local base = `base' + `p'
        }
    end
    _dc_t3fix
    _dc_cap "`f'" : dataprobe, topvalues(v, id(pid))
    tempname M
    matrix `M' = r(topvalues)
    * C (2 ids) and E (2 rows) are suppressed; the pool has 14 rows but 4
    * ids, so D joins: 20 rows, 10 ids; A and B are listed; 28 persons
    matrix want = (70, 28, 5, 2, 3, 20, 10)
    assert mreldif(`M', want) == 0
    mata: st_local("a", strofreal(ustrlen(_dc_lines(st_local("f"), "^    A +30  \(42\.9%\)  ids 10$")) > 0))
    mata: st_local("b", strofreal(ustrlen(_dc_lines(st_local("f"), "^    \[3 levels suppressed\] +20  \(28\.6%\)  ids 10$")) > 0))
    assert `a' == 1 & `b' == 1
    foreach l in C D E {
        mata: st_local("hit", strofreal(ustrlen(_dc_lines(st_local("f"), "^    `l' "))))
        assert `hit' == 0
    }
    * without id(): E alone joins D (8 rows); A, B, C are listed
    _dc_t3fix
    _dc_cap "`f'" : dataprobe, topvalues(v)
    matrix `M' = r(topvalues)
    matrix want = (70, ., 5, 3, 2, 8, .)
    assert mreldif(`M', want) == 0
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: T3 id() pooling rule (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: T3 id() pooling rule"
}

**# T4 total ids withheld when a complement is 1 to m-1
local ++tests
capture noisily {
    local f "`W'/t4.log"
    * A: persons 1-10, 2 rows each; B: persons 1-12, 2 rows each: 12 persons,
    * 12 - 10 = 2 hold no A
    clear
    quietly set obs 44
    generate str1 v = cond(_n <= 20, "A", "B")
    generate long pid = cond(_n <= 20, ceil(_n / 2), ceil((_n - 20) / 2))
    _dc_cap "`f'" : dataprobe, topvalues(v, id(pid))
    tempname M
    matrix `M' = r(topvalues)
    assert `M'[1, 1] == 44 & missing(`M'[1, 2]) & `M'[1, 4] == 2 & `M'[1, 5] == 0
    mata: st_local("a", strofreal(_dc_has(st_local("f"), "44 rows, [suppressed] ids, 2 levels")))
    assert `a' == 1
    * with 15 persons for B (5 hold no A) the total prints
    clear
    quietly set obs 50
    generate str1 v = cond(_n <= 20, "A", "B")
    generate long pid = cond(_n <= 20, ceil(_n / 2), ceil((_n - 20) / 2))
    _dc_cap "`f'" : dataprobe, topvalues(v, id(pid))
    matrix `M' = r(topvalues)
    assert `M'[1, 2] == 15
    * the pool's complement: A holds persons 1-10 (5 rows each); the pooled
    * b, c, d hold persons 1-8, so 10 - 8 = 2 hold no pooled level; A's own
    * complement is 10 - 10 = 0
    clear
    quietly set obs 58
    generate str1 v = "A"
    generate long pid = ceil(_n / 5)
    quietly replace v = "b" in 51/53
    quietly replace v = "c" in 54/56
    quietly replace v = "d" in 57/58
    quietly replace pid = _n - 50 in 51/58
    _dc_cap "`f'" : dataprobe, topvalues(v, id(pid) mincell(5))
    matrix `M' = r(topvalues)
    assert `M'[1, 1] == 58 & missing(`M'[1, 2]) & `M'[1, 4] == 1 & `M'[1, 5] == 3
    assert `M'[1, 6] == 8 & `M'[1, 7] == 8
    mata: st_local("a", strofreal(_dc_has(st_local("f"), "58 rows, [suppressed] ids, 4 levels")))
    assert `a' == 1
    * one more person in A only (11 - 8 = 3, still 1..4): withheld; with
    * persons 9-13 in A (13 - 8 = 5) the total prints
    quietly replace pid = 11 in 49/50
    _dc_cap "`f'" : dataprobe, topvalues(v, id(pid) mincell(5))
    matrix `M' = r(topvalues)
    assert missing(`M'[1, 2])
    quietly replace pid = 9 + mod(_n, 5) in 41/50
    _dc_cap "`f'" : dataprobe, topvalues(v, id(pid) mincell(5))
    matrix `M' = r(topvalues)
    assert `M'[1, 2] == 13
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: T4 total ids and their complements (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: T4 total ids and their complements"
}

**# T5 k withheld when the pool forces a single-row level (rows < 2k)
local ++tests
capture noisily {
    local f "`W'/t5.log"
    * 20 rows of "big", 10 single-row levels: pool of 10 rows in 10 levels
    clear
    quietly set obs 30
    generate str4 v = cond(_n <= 20, "big", "s" + char(96 + _n - 20))
    _dc_cap "`f'" : dataprobe, topvalues(v)
    tempname M
    matrix `M' = r(topvalues)
    assert `M'[1, 1] == 30 & missing(`M'[1, 3]) & `M'[1, 4] == 1 & missing(`M'[1, 5]) & `M'[1, 6] == 10
    mata: st_local("a", strofreal(ustrlen(_dc_lines(st_local("f"), "^    \[levels suppressed\] +10  \(33\.3%\)$")) > 0))
    mata: st_local("b", strofreal(_dc_has(st_local("f"), "levels;")))
    assert `a' == 1 & `b' == 0
    * one more row in a pooled level: 11 rows in 10 levels; fewer than 20
    * rows force a single-row level, so k is still withheld
    quietly set obs 31
    quietly replace v = "sa" in 31
    _dc_cap "`f'" : dataprobe, topvalues(v)
    matrix `M' = r(topvalues)
    assert missing(`M'[1, 3]) & missing(`M'[1, 5]) & `M'[1, 6] == 11
    mata: st_local("a", strofreal(ustrlen(_dc_lines(st_local("f"), "^    \[levels suppressed\] +11  ")) > 0))
    assert `a' == 1
    * 19 rows in 10 levels: still withheld
    quietly set obs 39
    quietly replace v = "s" + char(96 + _n - 30) in 32/39
    _dc_cap "`f'" : dataprobe, topvalues(v)
    matrix `M' = r(topvalues)
    assert missing(`M'[1, 5]) & `M'[1, 6] == 19
    * 20 rows in 10 levels (two each): no level is forced to one row, k prints
    quietly set obs 40
    quietly replace v = "sj" in 40
    _dc_cap "`f'" : dataprobe, topvalues(v)
    matrix `M' = r(topvalues)
    assert `M'[1, 3] == 11 & `M'[1, 5] == 10 & `M'[1, 6] == 20
    mata: st_local("a", strofreal(ustrlen(_dc_lines(st_local("f"), "^    \[10 levels suppressed\] +20  ")) > 0))
    assert `a' == 1
    * the review's case (m=5): AAA 50, r4 5, then 1 + 1 + 3 = 5 rows in 3
    * pooled levels (5 < 6): k withheld
    clear
    quietly set obs 60
    generate str3 v = cond(_n <= 50, "AAA", cond(_n <= 55, "r4", cond(_n == 56, "r1", cond(_n == 57, "r2", "r3"))))
    _dc_cap "`f'" : dataprobe, topvalues(v, mincell(5))
    matrix `M' = r(topvalues)
    assert `M'[1, 4] == 2 & missing(`M'[1, 5]) & `M'[1, 6] == 5
    mata: st_local("a", strofreal(ustrlen(_dc_lines(st_local("f"), "^    \[levels suppressed\] +5  ")) > 0))
    mata: st_local("b", strofreal(_dc_has(st_local("f"), "3 levels suppressed")))
    assert `a' == 1 & `b' == 0
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: T5 the number of pooled levels (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: T5 the number of pooled levels"
}

**# T6 everything pooled below m: counts and totals withheld together
local ++tests
capture noisily {
    local f "`W'/t6.log"
    clear
    quietly set obs 3
    generate str2 v = cond(_n == 1, "qa", "qb")
    generate long pid = _n
    _dc_cap "`f'" : dataprobe, topvalues(v, id(pid))
    tempname M
    matrix `M' = r(topvalues)
    assert `M'[1, 4] == 0
    forvalues j = 1/7 {
        if `j' == 4 continue
        assert missing(`M'[1, `j'])
    }
    mata: st_local("t", _dc_lines(st_local("f"), "^  v:|^    "))
    mata: st_local("hasd", strofreal(ustrregexm(ustrregexra(st_local("t"), "fewer than 5|5 or more|at most 20", ""), "[0-9]")))
    assert `hasd' == 0
    mata: st_local("a", strofreal(_dc_has(st_local("f"), "[suppressed] rows, [suppressed] ids;")))
    assert `a' == 1
    foreach l in qa qb {
        mata: st_local("hit", strofreal(_dc_has(st_local("f"), " `l'")))
        assert `hit' == 0
    }
    * rows of 5 or more from too few persons: the totals are withheld too
    clear
    quietly set obs 12
    generate str1 v = cond(_n <= 6, "A", "B")
    generate long pid = 1 + (_n > 6)
    _dc_cap "`f'" : dataprobe, topvalues(v, id(pid))
    matrix `M' = r(topvalues)
    assert missing(`M'[1, 1]) & missing(`M'[1, 6]) & `M'[1, 4] == 0
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: T6 withheld together (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: T6 withheld together"
}

**# T7 types
local ++tests
capture noisily {
    local f "`W'/t7.log"
    * a value-labelled numeric: the value, then its label
    sysuse auto, clear
    _dc_cap "`f'" : dataprobe, topvalues(foreign)
    mata: st_local("a", strofreal(ustrlen(_dc_lines(st_local("f"), "^    0 Domestic +52  \(70\.3%\)$")) > 0))
    assert `a' == 1
    * extended missing values are levels of their own; float shown as float
    clear
    quietly set obs 23
    generate float x = 0.1
    quietly replace x = . in 11/16
    quietly replace x = .a in 17/23
    _dc_cap "`f'" : dataprobe, topvalues(x)
    foreach re in "^    \.1 +10  " "^    \.a +7  " "^    \. +6  " {
        mata: st_local("a", strofreal(ustrlen(_dc_lines(st_local("f"), st_local("re"))) > 0))
        assert `a' == 1
    }
    matrix M7 = r(topvalues)
    assert M7[1, 1] == 23 & M7[1, 3] == 3 & M7[1, 4] == 3
    * a date prints in its display format
    clear
    quietly set obs 10
    generate int d = td(01jan2020)
    format d %td
    _dc_cap "`f'" : dataprobe, topvalues(d)
    mata: st_local("a", strofreal(ustrlen(_dc_lines(st_local("f"), "^    01jan2020 +10  ")) > 0))
    assert `a' == 1
    * all missing: one level, blank strings as (blank)
    clear
    quietly set obs 9
    generate str5 s = ""
    generate y = .
    _dc_cap "`f'" : dataprobe, topvalues(s y)
    mata: st_local("a", strofreal(ustrlen(_dc_lines(st_local("f"), "^    \(blank\) +9  \(100\.0%\)$")) > 0))
    mata: st_local("b", strofreal(ustrlen(_dc_lines(st_local("f"), "^    \. +9  \(100\.0%\)$")) > 0))
    assert `a' == 1 & `b' == 1
    * strL gives the str# results
    _tv_fix 41 100 9
    generate strL vl = v
    _dc_cap "`f'" : dataprobe, topvalues(v, id(pid))
    matrix A = r(topvalues)
    _dc_cap "`f'" : dataprobe, topvalues(vl, id(pid))
    matrix B = r(topvalues)
    assert mreldif(A, B) == 0
    * hostile strings print as their literal characters, nothing expanded
    qa_hostile_strings
    local hs "`r(names)'"
    clear
    quietly set obs 60
    generate strL h = ""
    local i = 0
    foreach g of local hs {
        local ++i
        local a = (`i' - 1) * 6 + 1
        mata: for (r = `a'; r <= `a' + 5; r++) st_sstore(r, "h", st_global("`g'"))
    }
    mata: for (r = 55; r <= 60; r++) st_sstore(r, "h", char(123) + "e" + char(125) + char(10) + "x")
    _dc_cap "`f'" : dataprobe, topvalues(h)
    assert r(rc) == 0
    matrix M7 = r(topvalues)
    assert M7[1, 4] == 10 & M7[1, 5] == 0
    foreach g of local hs {
        mata: st_local("a", strofreal(_dc_has(st_local("f"), "    " + st_global("`g'"))))
        assert `a' == 1
    }
    mata: st_local("a", strofreal(_dc_has(st_local("f"), "    " + char(123) + "e" + char(125) + char(92) + "nx")))
    mata: st_local("b", strofreal(_dc_has(st_local("f"), "EXPANDED")))
    assert `a' == 1 & `b' == 0
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: T7 variable types and hostile values (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: T7 variable types and hostile values"
}

**# T8 errors
local ++tests
capture noisily {
    sysuse auto, clear
    capture noisily dataprobe, topvalues(rep78, mincell(1))
    assert _rc == 198
    capture noisily dataprobe, topvalues(rep78, max(0))
    assert _rc == 198
    capture noisily dataprobe, topvalues(nosuch)
    assert _rc == 111
    capture noisily dataprobe, topvalues(rep78, id(nosuch))
    assert _rc == 111
    capture noisily dataprobe, topvalues(rep78, color(red))
    assert _rc == 198
    capture noisily dataprobe, topvalues(make) exclude(make)
    assert _rc == 198
    * safe: text holding a digit, a date, a likely identifier
    capture noisily dataprobe, safe topvalues(make)
    assert _rc == 198
    generate int d = td(01jan2020)
    format d %td
    capture noisily dataprobe, safe topvalues(d)
    assert _rc == 198
    generate long patient_id = _n
    capture noisily dataprobe, safe topvalues(patient_id)
    assert _rc == 198
    capture noisily dataprobe, safe topvalues(foreign)
    assert _rc == 0
    * an empty sample stops as every dataprobe call does
    capture noisily dataprobe if price < 0, topvalues(rep78)
    assert _rc == 2000
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: T8 errors (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: T8 errors"
}

**# T9 no varlist profiles nothing; no ledger row; no note
local ++tests
capture noisily {
    local f "`W'/t9.log"
    local led "`W'/t9.dta"
    sysuse auto, clear
    _dc_cap "`f'" : dataprobe, topvalues(make)
    assert r(gatesonly) == 1 & r(n_checks) == 0
    foreach h in "STRING" "CATEGORICAL" "CONTINUOUS" "nothing was checked" "AMC" {
        mata: st_local("a", strofreal(_dc_has(st_local("f"), st_local("h"))))
        assert `a' == 0
    }
    mata: st_local("a", strofreal(_dc_has(st_local("f"), "TOP VALUES")))
    assert `a' == 1
    _dc_cap "`f'" : dataprobe, gatesonly topvalues(make)
    mata: st_local("a", strofreal(_dc_has(st_local("f"), "nothing was checked")))
    assert `a' == 0
    * with a varlist the profile prints as well
    _dc_cap "`f'" : dataprobe rep78, topvalues(rep78)
    assert r(gatesonly) == 0
    mata: st_local("a", strofreal(_dc_has(st_local("f"), "CATEGORICAL")))
    assert `a' == 1
    * a gate beside it: one ledger row, the gate's
    capture erase "`led'"
    dataprobe, topvalues(rep78) expectn(74) ledger("`led'")
    assert r(n_checks) == 1
    preserve
    quietly use "`led'", clear
    assert _N == 1 & family[1] == "expectn"
    restore
    * topvalues() alone writes no ledger
    capture erase "`led'"
    dataprobe, topvalues(rep78) ledger("`led'")
    capture confirm file "`led'"
    assert _rc == 601
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: T9 the view alone (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: T9 the view alone"
}

**# T10 threshold and max() defaults
local ++tests
capture noisily {
    local f "`W'/t10.log"
    sysuse auto, clear
    * rep78: 3 30, 4 18, 5 11, 2 8, . 5, 1 2
    dataprobe, topvalues(rep78)
    assert el(r(topvalues), 1, 4) == 4
    dataprobe, topvalues(rep78) mincell(10)
    assert el(r(topvalues), 1, 4) == 3
    dataprobe, topvalues(rep78, mincell(2)) mincell(10)
    assert el(r(topvalues), 1, 4) == 6
    dataprobe, topvalues(rep78) maxfreq(2)
    assert el(r(topvalues), 1, 4) == 2 & el(r(topvalues), 1, 6) == 26
    dataprobe, topvalues(rep78, max(3)) maxfreq(2)
    assert el(r(topvalues), 1, 4) == 3
    dataprobe, topvalues(rep78) maskrare rare(12)
    assert el(r(topvalues), 1, 4) == 2
    dataqa set mincell(19)
    dataprobe, topvalues(rep78)
    assert el(r(topvalues), 1, 4) == 1
    dataqa set clear
    macro drop DATAMAP_DQ
    _dc_cap "`f'" : dataprobe, topvalues(rep78) mincell(10)
    mata: st_local("a", strofreal(_dc_has(st_local("f"), "listed: 10 or more rows, at most 20")))
    assert `a' == 1
}
local rc = _rc
capture macro drop DATAMAP_DQ
if `rc' {
    local ++fail
    display as error "FAIL: T10 threshold and max() defaults (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: T10 threshold and max() defaults"
}

**# T11 by() ignored; quietly; several entries; state
local ++tests
capture noisily {
    local f "`W'/t11.log"
    _tv_fix 51 130 10
    generate byte arm = mod(_n, 3)
    dataprobe, topvalues(v, id(pid))
    matrix A = r(topvalues)
    dataprobe, topvalues(v, id(pid)) by(arm)
    matrix B = r(topvalues)
    assert mreldif(A, B) == 0
    _dc_cap "`f'" : quietly dataprobe, topvalues(v, id(pid))
    matrix B = r(topvalues)
    assert mreldif(A, B) == 0
    mata: st_local("a", strofreal(_dc_has(st_local("f"), "TOP VALUES")))
    assert `a' == 0
    * a varlist and \-separated entries: one row each, named by the variable
    sysuse auto, clear
    dataprobe, topvalues(rep78 foreign \ make, max(3))
    matrix C = r(topvalues)
    local rn : rownames C
    assert "`rn'" == "rep78 foreign make"
    local cn : colnames C
    assert "`cn'" == "N N_id levels shown suppressed resid resid_id"
    assert C[3, 4] == 0 & C[3, 6] == 74
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: T11 by() ignored, quietly, several entries (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: T11 by() ignored, quietly, several entries"
}

**# Wrap up
capture log close _dccap
local files : dir "`W'" files "*"
foreach fl of local files {
    capture erase "`W'/`fl'"
}
sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
macro drop DATAMAP_DQ
display "RESULT: test_datamap_v210_disclosure tests=`tests' pass=`pass' fail=`fail'"
log close main
if `fail' exit 1
