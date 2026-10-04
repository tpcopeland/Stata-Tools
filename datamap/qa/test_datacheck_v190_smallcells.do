clear all
set more off
version 16.0
set linesize 255

* test_datacheck_v190_smallcells.do - the smallcells() publication gate (F6).
* Oracles: hand-built results tables with planted violations, the same
* verdict from hand-written rule() equivalents, and direct count if
* computations.  Gate results are read from the ledger() file.

* === Bootstrap: targeted local reinstall ===
local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
macro drop DATAMAP_DQ

global TC 0
global PASS 0
global FAIL 0
capture program drop _cv
program define _cv
    args rc msg
    global TC = $TC + 1
    if `rc' == 0 {
        display as result "  PASS: `msg'"
        global PASS = $PASS + 1
    }
    else {
        display as error "  FAIL (rc=`rc'): `msg'"
        global FAIL = $FAIL + 1
    }
end

local W "`c(tmpdir)'/sc190"
capture mkdir "`W'"

* Narcolepsy-style results table; m = 5.  Row 5 is suppressed and carries
* small counts on purpose.  Clean: every released count is 0 or >= 5 and
* every difference is 0 or >= 5.
capture program drop _sc_clean
program define _sc_clean
    clear
    quietly set obs 5
    generate double rowid = _n
    generate double n1 = .
    generate double e1 = .
    generate double n0 = .
    generate double e0 = .
    generate double suppressed = .
    local r1 "40 12 50 15 0"
    local r2 "5 5 20 0 0"
    local r3 "100 7 80 5 0"
    local r4 "60 20 70 30 0"
    local r5 "2 1 3 1 1"
    forvalues i = 1/5 {
        local j = 0
        foreach v in n1 e1 n0 e0 suppressed {
            local ++j
            local val : word `j' of `r`i''
            quietly replace `v' = `val' in `i'
        }
    }
end

* one ledger row of family smallcells: r(st), r(n), r(obsnum), r(obs), r(exp), r(msg)
capture program drop _sc_led
program define _sc_led, rclass
    args file which
    if "`which'" == "" local which 1
    preserve
    use `"`file'"', clear
    quietly keep if family == "smallcells"
    return scalar n = _N
    local st "absent"
    local obs ""
    local exp ""
    local msg ""
    local on = .
    if _N >= `which' {
        local st = status[`which']
        local obs = observed[`which']
        local exp = expected[`which']
        local msg = message[`which']
        local on = observed_num[`which']
    }
    return local st "`st'"
    return local obs "`obs'"
    return local exp "`exp'"
    return local msg `"`msg'"'
    return scalar obsnum = `on'
    restore
end

* run one smallcells() call (extra options in `opts'); returns r(rc) and ledger fields
capture program drop _sc_run
program define _sc_run, rclass
    syntax , sc(string asis) file(string) [opts(string asis)]
    capture erase `"`file'"'
    capture quietly datacheck, gatesonly smallcells(`sc') ledger(`"`file'"') `opts'
    return scalar rc = _rc
    capture confirm file `"`file'"'
    if !_rc {
        _sc_led `"`file'"'
        return add
    }
    else return scalar n = 0
end

local SC "n1 e1 n1-e1 n0 e0 n0-e0 if !suppressed"

**## clean table and exact boundary values
_sc_clean
_sc_run, sc(`SC') file("`W'/a.dta") opts(mincell(5))
_cv `=!(r(rc) == 0 & r(st) == "pass" & r(n) == 1)' "clean table passes (rc 0, one ledger row, status pass)"
_cv `=!(strpos(`"`r(exp)'"', "m=5") > 0)' "the ledger expected column carries the threshold used: `r(exp)'"
_cv `=!(strpos(`"`r(msg)'"', "m=5") > 0)' "the gate line carries the threshold used"
* values of exactly m (n1=5, e1=5 on row 2) and 0 (e0=0, n1-e1=0) are on the table
_sc_clean
quietly count if n1 == 5 & e1 == 5 & n1 - e1 == 0 & e0 == 0
_cv `=!(r(N) == 1)' "oracle: row 2 holds exact m, and 0, in a count and a difference"
* a table of only zeros passes
clear
quietly set obs 3
generate double n1 = 0
generate double e1 = 0
generate byte suppressed = 0
_sc_run, sc(n1 e1 n1-e1) file("`W'/a0.dta") opts(mincell(5))
_cv `=!(r(rc) == 0 & r(st) == "pass")' "an all-zero table passes"

**## planted violations: each alone must fail (exit 9) with one failing row
* each plant is on row 3 (100 7 80 5)
local plants `""replace n1 = 1 in 3" "replace e1 = 4 in 3" "replace n1 = 20 in 3 \ replace e1 = 17 in 3" "replace n0 = 3 in 3" "replace e0 = 1 in 3" "replace n0 = 8 in 3 \ replace e0 = 5 in 3""'
local pl "n1=1 e1=m-1 n1-e1=3 n0=3 e0=1 n0-e0=3"
local i = 0
foreach p of local plants {
    local ++i
    local pn : word `i' of `pl'
    _sc_clean
    * the plant may hold two replace commands joined by a backslash
    local ncmd = 1 + (strpos(`"`p'"', "\") > 0)
    if `ncmd' == 1 quietly `p'
    else {
        gettoken a b : p, parse("\")
        gettoken bs b : b, parse("\")
        quietly `a'
        quietly `b'
    }
    * oracle: count rows that violate by hand
    quietly count if !suppressed & ((inrange(n1,1,4)) | inrange(e1,1,4) | inrange(n1-e1,1,4) | inrange(n0,1,4) | inrange(e0,1,4) | inrange(n0-e0,1,4))
    local want = r(N)
    _sc_run, sc(`SC') file("`W'/p`i'.dta") opts(mincell(5))
    _cv `=!(r(rc) == 9 & r(st) == "fail" & r(obsnum) == `want' & `want' == 1)' "plant `pn': exit 9, status fail, one failing row (got rc `r(rc)', rows `r(obsnum)', oracle `want')"
}

**## a violation on a suppressed row passes; the same violation unsuppressed fails
_sc_clean
replace n1 = 1 in 5
_sc_run, sc(`SC') file("`W'/s1.dta") opts(mincell(5))
_cv `=!(r(rc) == 0 & r(st) == "pass")' "violation on a suppressed row passes"
replace suppressed = 0 in 5
_sc_run, sc(`SC') file("`W'/s2.dta") opts(mincell(5))
_cv `=!(r(rc) == 9 & r(st) == "fail")' "the same row, not suppressed, fails"
* no if: the suppressed row is in scope
_sc_clean
_sc_run, sc(n1 e1 n1-e1 n0 e0 n0-e0) file("`W'/s3.dta") opts(mincell(5))
_cv `=!(r(rc) == 9 & r(obsnum) == 1)' "without an entry if, the small rows are in scope (rc 9, one row)"
* an entry if that selects nothing passes
_sc_run, sc(n1 e1 if suppressed == 7) file("`W'/s4.dta") opts(mincell(5))
_cv `=!(r(rc) == 0 & r(st) == "pass" & r(obsnum) == 0)' "an if scope that selects no row passes with 0 failing rows"

**## the call's if/in also applies
_sc_clean
replace e1 = 2 in 3
_sc_run, sc(`SC') file("`W'/c1.dta") opts(mincell(5))
local rc1 = r(rc)
capture quietly datacheck if rowid != 3, gatesonly smallcells(`SC') mincell(5)
local rc2 = _rc
capture quietly datacheck in 1/2, gatesonly smallcells(`SC') mincell(5)
local rc3 = _rc
capture quietly datacheck in 3/4, gatesonly smallcells(`SC') mincell(5)
local rc4 = _rc
_cv `=!(`rc1' == 9 & `rc2' == 0 & `rc3' == 0 & `rc4' == 9)' "call if/in narrows the scope (rcs `rc1' `rc2' `rc3' `rc4', want 9 0 0 9)"

**## parity with hand-written rule() equivalents
* rule("released_1": !inrange(n1, 1, m-1) | suppressed), one per count
local hand `""released_1": !inrange(n1,1,4) | suppressed \ "released_2": !inrange(e1,1,4) | suppressed \ "released_3": !inrange(n1-e1,1,4) | suppressed \ "released_4": !inrange(n0,1,4) | suppressed \ "released_5": !inrange(e0,1,4) | suppressed \ "released_6": !inrange(n0-e0,1,4) | suppressed"'
* one combined rule gives the failing-row count over the union
local comb `""comb": !(inrange(n1,1,4) | inrange(e1,1,4) | inrange(n1-e1,1,4) | inrange(n0,1,4) | inrange(e0,1,4) | inrange(n0-e0,1,4)) | suppressed"'
local muts `""" "replace n1 = 1 in 3" "replace e1 = 4 in 3" "replace n0 = 3 in 1" "replace n1 = 4 in 5" "replace n1 = 3 in 1" "replace e0 = 2 in 2""'
local i = 0
foreach mu of local muts {
    local ++i
    _sc_clean
    if `"`mu'"' != "" quietly `mu'
    if `i' == 3 {
        * two rows violate, one of them in two counts
        quietly replace e1 = 2 in 1
        quietly replace n1 = 4 in 4
    }
    _sc_run, sc(`SC') file("`W'/par`i'.dta") opts(mincell(5))
    local rcs = r(rc)
    local nsc = r(obsnum)
    if `rcs' == 0 local nsc = 0
    capture quietly datacheck, gatesonly rule(`hand') ledger("`W'/hand`i'.dta")
    local rch = _rc
    capture quietly datacheck, gatesonly rule(`comb') ledger("`W'/comb`i'.dta")
    preserve
    use "`W'/comb`i'.dta", clear
    quietly keep if family == "rule"
    local nrule = observed_num[1]
    restore
    _cv `=!(`rcs' == `rch' & `nsc' == `nrule')' "parity [`i': `mu']: rc smallcells `rcs' vs rules `rch'; failing rows `nsc' vs `nrule'"
}

**## negative and non-integer values fail, each with its own reason
_sc_clean
replace e1 = -3 in 3
_sc_run, sc(`SC') file("`W'/neg.dta") opts(mincell(5))
_cv `=!(r(rc) == 9 & r(st) == "fail" & strpos(`"`r(msg)'"', "negative") > 0)' "negative value fails with reason negative"
* the negative on a suppressed row is out of scope
_sc_clean
replace e1 = -3 in 5
_sc_run, sc(`SC') file("`W'/neg2.dta") opts(mincell(5))
_cv `=!(r(rc) == 0)' "a negative value on a suppressed row passes"
_sc_clean
replace e1 = 2.5 in 3
_sc_run, sc(`SC') file("`W'/nint.dta") opts(mincell(5))
_cv `=!(r(rc) == 9 & strpos(`"`r(msg)'"', "non-integer") > 0 & strpos(`"`r(msg)'"', "negative") == 0)' "non-integer value fails with reason non-integer"
_sc_clean
replace e1 = 0.5 in 3
_sc_run, sc(`SC') file("`W'/nint2.dta") opts(mincell(5))
_cv `=!(r(rc) == 9)' "0.5 (between 0 and 1) is not a pass"
_sc_clean
replace e1 = 7.25 in 3
_sc_run, sc(`SC') file("`W'/nint3.dta") opts(mincell(5))
_cv `=!(r(rc) == 9)' "a non-integer above m (7.25) is not a pass"
* a difference that is negative (e1 > n1)
_sc_clean
replace e1 = 120 in 3
_sc_run, sc(`SC') file("`W'/neg3.dta") opts(mincell(5))
_cv `=!(r(rc) == 9 & strpos(`"`r(msg)'"', "n1-e1") > 0 & strpos(`"`r(msg)'"', "negative") > 0)' "negative difference n1-e1 fails and the message names the expression"
* a float-stored integer is an integer
_sc_clean
recast float n1 e1
_sc_run, sc(`SC') file("`W'/flt.dta") opts(mincell(5))
_cv `=!(r(rc) == 0)' "float-stored integer counts pass"

**## missing values are suppressed and pass
_sc_clean
replace e1 = . in 3
replace n0 = .a in 4
_sc_run, sc(`SC') file("`W'/mis.dta") opts(mincell(5))
_cv `=!(r(rc) == 0 & r(st) == "pass")' "missing and extended missing counts pass (and so do their differences)"
* a missing next to a small value in another count still fails
replace n1 = 1 in 3
_sc_run, sc(`SC') file("`W'/mis2.dta") opts(mincell(5))
_cv `=!(r(rc) == 9 & r(obsnum) == 1)' "a missing e1 does not hide a small n1 on the same row"
* a missing scope flag follows Stata if semantics: !. is 0, so !suppressed leaves
* the row out (as the hand-written rule "| suppressed" does); suppressed != 1
* keeps it in scope and the small count is caught
_sc_clean
replace suppressed = . in 3
replace n1 = 1 in 3
_sc_run, sc(`SC') file("`W'/mis3.dta") opts(mincell(5))
local rcm3 = r(rc)
_sc_run, sc(n1 e1 n1-e1 n0 e0 n0-e0 if suppressed != 1) file("`W'/mis4.dta") opts(mincell(5))
local rcm4 = r(rc)
capture quietly datacheck, gatesonly rule("r": !inrange(n1,1,4) | suppressed)
_cv `=!(`rcm3' == 0 & `rcm4' == 9 & _rc == 0)' "missing scope flag: !suppressed excludes the row (as rule() does), suppressed != 1 keeps it"

**## several backslash entries
_sc_clean
replace n0 = 3 in 5
* entry 1 scoped to unsuppressed rows passes; entry 2 has no scope and fails on row 5
_sc_run, sc(n1 e1 n1-e1 if !suppressed \ n0 e0 n0-e0) file("`W'/multi.dta") opts(mincell(5))
local rcm = r(rc)
_sc_led "`W'/multi.dta" 1
local s1 "`r(st)'"
local n1_ = r(n)
_sc_led "`W'/multi.dta" 2
local s2 "`r(st)'"
_cv `=!(`rcm' == 9 & `n1_' == 2 & "`s1'" == "pass" & "`s2'" == "fail")' "two entries: two ledger rows, first pass, second fail, exit 9 (`s1' `s2')"
_sc_run, sc(n1 e1 if !suppressed \ n0 e0 if !suppressed \ n1-e1 if !suppressed) file("`W'/multi2.dta") opts(mincell(5))
_cv `=!(r(rc) == 0 & r(n) == 3)' "three passing entries: three ledger rows, rc 0"

**## threshold from the dataqa set session default
_sc_clean
replace e1 = 4 in 3
replace n1 = 100 in 3
quietly dataqa set mincell(3)
capture quietly datacheck, gatesonly smallcells(`SC') ledger("`W'/sess.dta")
local rcs3 = _rc
_sc_led "`W'/sess.dta"
local expsess `"`r(exp)'"'
* explicit mincell() beats the session default
capture quietly datacheck, gatesonly smallcells(`SC') mincell(5)
local rce5 = _rc
* a count of 2 fails at the session m = 3
replace e1 = 2 in 3
capture quietly datacheck, gatesonly smallcells(`SC')
local rcs3b = _rc
quietly dataqa set clear
_cv `=!(`rcs3' == 0)' "session mincell(3): a count of 4 passes"
_cv `=!(strpos(`"`expsess'"', "m=3") > 0)' "session mincell(3): the ledger expected carries m=3 (`expsess')"
_cv `=!(`rce5' == 9)' "explicit mincell(5) overrides the session default and the 4 fails"
_cv `=!(`rcs3b' == 9)' "session mincell(3): a count of 2 fails"

**## threshold resolution without mincell()
_sc_clean
capture noisily datacheck, gatesonly smallcells(n1 e1)
_cv `=!(_rc == 198)' "no threshold anywhere: refused with rc 198"
capture quietly datacheck, gatesonly smallcells(n1 e1) rare(5)
_cv `=!(_rc == 198)' "rare() alone is not a gate threshold without maskrare: rc 198"
* maskrare resolves m: mincell, else rare, else 5
replace e1 = 6 in 3
capture quietly datacheck, gatesonly smallcells(n1 e1 if !suppressed) maskrare ledger("`W'/mr5.dta")
local a = _rc
_sc_led "`W'/mr5.dta"
local ea `"`r(exp)'"'
capture quietly datacheck, gatesonly smallcells(n1 e1 if !suppressed) maskrare mincell(8) ledger("`W'/mr8.dta")
local b = _rc
_sc_led "`W'/mr8.dta"
local eb `"`r(exp)'"'
capture quietly datacheck, gatesonly smallcells(n1 e1 if !suppressed) maskrare rare(7) ledger("`W'/mr7.dta")
local c = _rc
_sc_led "`W'/mr7.dta"
local ec `"`r(exp)'"'
_cv `=!(`a' == 0 & strpos(`"`ea'"', "m=5") > 0)' "maskrare alone: m = 5 and a 6 passes"
_cv `=!(`b' == 9 & strpos(`"`eb'"', "m=8") > 0)' "maskrare mincell(8): m = 8 and the 6 fails"
_cv `=!(`c' == 9 & strpos(`"`ec'"', "m=7") > 0)' "maskrare rare(7): m = 7 and the 6 fails"

**## checks() rows
_sc_clean
replace e1 = 2 in 3
preserve
clear
input str12 gate str40 var str20 pattern
"smallcells" "n1 e1 n1-e1 n0 e0 n0-e0" "!suppressed"
end
save "`W'/spec.dta", replace
restore
capture quietly datacheck, gatesonly checks("`W'/spec.dta") mincell(5) ledger("`W'/chk.dta")
local rck = _rc
_sc_led "`W'/chk.dta"
local stck "`r(st)'"
local nck = r(obsnum)
_cv `=!(`rck' == 9 & "`stck'" == "fail" & `nck' == 1)' "checks() smallcells row: rc 9, fail, one failing row"
_sc_clean
capture quietly datacheck, gatesonly checks("`W'/spec.dta") mincell(5)
_cv `=!(_rc == 0)' "checks() smallcells row on the clean table passes"
preserve
use "`W'/spec.dta", clear
generate str8 kind = "band"
save "`W'/specb.dta", replace
restore
capture quietly datacheck, gatesonly checks("`W'/specb.dta") mincell(5)
_cv `=!(_rc == 198)' "checks() smallcells row as a band is refused (rc 198)"
preserve
use "`W'/spec.dta", clear
replace var = ""
save "`W'/spec0.dta", replace
restore
capture quietly datacheck, gatesonly checks("`W'/spec0.dta") mincell(5)
_cv `=!(_rc == 198)' "checks() smallcells row with no countexps is refused (rc 198)"

**## verdict count, violations(), r(), never a band
_sc_clean
replace e1 = 2 in 3
capture quietly datacheck, gatesonly smallcells(`SC') mincell(5) violations(vio190, replace) bandwarn
local rcv = _rc
local nviol = r(n_violations)
local nfailed = r(n_failed)
local nchk = r(n_checks)
quietly frame vio190: count
local vn = r(N)
local vcheck = ""
frame vio190: local vcheck = check[1]
local vsev = ""
frame vio190: local vsev = severity[1]
capture frame drop vio190
_cv `=!(`rcv' == 9 & `nviol' == 1 & `nfailed' == 1 & `nchk' == 1)' "verdict counts: 1 violation, 1 failed, 1 check (bandwarn does not soften it)"
_cv `=!(`vn' == 1 & "`vcheck'" == "smallcells" & "`vsev'" == "error")' "violations() frame: one row, check smallcells, severity error"
* bare warn downgrades like every invariant
capture quietly datacheck, gatesonly smallcells(`SC') mincell(5) warn
_cv `=!(_rc == 0)' "warn downgrades the invariant (rc 0)"

**## gatesonly and profile mode agree
capture quietly datacheck, smallcells(`SC') mincell(5) ledger("`W'/prof.dta")
local rcp = _rc
_sc_led "`W'/prof.dta"
local obsp "`r(obs)'"
local onp = r(obsnum)
capture quietly datacheck, gatesonly smallcells(`SC') mincell(5) ledger("`W'/gate.dta")
local rcg = _rc
_sc_led "`W'/gate.dta"
_cv `=!(`rcp' == 9 & `rcg' == 9 & "`obsp'" == "`r(obs)'" & `onp' == r(obsnum))' "profile mode and gatesonly: same rc and same ledger observation"
* the gate columns survive the gatesonly keep (a variable read only by smallcells)
_sc_clean
generate byte unrelated = 1
capture quietly datacheck unrelated, gatesonly smallcells(n1-e1 if !suppressed) mincell(5)
_cv `=!(_rc == 0)' "gatesonly with a varlist keeps the variables smallcells reads"

**## data-order independence and a 32-character variable name
_sc_clean
replace e1 = 2 in 3
_sc_run, sc(`SC') file("`W'/o1.dta") opts(mincell(5))
local o1 = r(obsnum)
gsort -rowid
_sc_run, sc(`SC') file("`W'/o2.dta") opts(mincell(5))
_cv `=!(r(rc) == 9 & r(obsnum) == `o1')' "reversing the row order gives the same failing-row count"
_sc_clean
rename e1 a234567890123456789012345678901e
rename n1 b234567890123456789012345678901n
replace a234567890123456789012345678901e = 2 in 3
_sc_run, sc(b234567890123456789012345678901n a234567890123456789012345678901e if !suppressed) file("`W'/long.dta") opts(mincell(5))
_cv `=!(r(rc) == 9 & r(obsnum) == 1)' "32-character variable names are read intact"

**## maskrare: no small value printed
_sc_clean
replace e1 = 2 in 3
replace n0 = 3 in 4
quietly log using "`W'/mask.log", text replace name(scm)
capture noisily datacheck, gatesonly smallcells(`SC') maskrare mincell(5) ledger("`W'/mask.dta")
local rcm = _rc
quietly log close scm
_sc_led "`W'/mask.dta"
local mobs "`r(obs)'"
local mon = r(obsnum)
local mmsg `"`r(msg)'"'
tempname fh
local leak = 0
local shown = 0
file open `fh' using "`W'/mask.log", read text
file read `fh' line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "smallcells(") {
        local shown = 1
        * the planted values 2 and 3 and the row count 2 must not appear as numbers
        if regexm(`"`macval(line)'"', "(^|[^0-9.<=])[1-4]([^0-9.]|$)") & !regexm(`"`macval(line)'"', "^[ ]*smallcells") local leak = 1
    }
    file read `fh' line
}
file close `fh'
_cv `=!(`rcm' == 9 & `shown' == 1)' "maskrare: the failing gate is still reported (rc 9)"
_cv `=!(strpos(`"`mmsg'"', "<5") > 0)' "maskrare: the row count and per-countexp counts print as <5 (`mmsg')"
_cv `=!(`leak' == 0)' "maskrare: no number 1 to 4 appears in the printed gate line"
_cv `=!("`mobs'" == "<5 rows fail" & missing(`mon'))' "maskrare: the ledger observed text is masked and the number is missing (`mobs')"
_cv `=!(strpos(`"`mmsg'"', "e1") > 0 & strpos(`"`mmsg'"', "n0") > 0)' "maskrare: the message names the countexps that failed"
* without maskrare the exact row count is shown
capture quietly datacheck, gatesonly smallcells(`SC') mincell(5) ledger("`W'/nomask.dta")
_sc_led "`W'/nomask.dta"
_cv `=!(r(obsnum) == 2 & "`r(obs)'" == "2 rows fail")' "without maskrare: the exact count of failing rows (2)"
* more failing rows than m: the count is not masked, no value is printed
clear
quietly set obs 12
generate double n1 = 2
generate byte suppressed = 0
capture quietly datacheck, gatesonly smallcells(n1 if !suppressed) maskrare ledger("`W'/mask12.dta")
_sc_led "`W'/mask12.dta"
_cv `=!(r(obsnum) == 12)' "maskrare: 12 failing rows (above m) print as a count"

**## parse errors
_sc_clean
capture noisily datacheck, gatesonly smallcells(n1 - e1) mincell(5)
_cv `=!(_rc != 0 & _rc != 9)' "spaces inside an expression: a parse error, never a pass (rc `=_rc')"
capture noisily datacheck, gatesonly smallcells(n1 nosuchvar) mincell(5)
_cv `=!(_rc == 111)' "unknown variable: rc 111"
capture noisily datacheck, gatesonly smallcells(n1 if) mincell(5)
_cv `=!(_rc == 198)' "an empty if: rc 198"
capture noisily datacheck, gatesonly smallcells(if !suppressed) mincell(5)
_cv `=!(_rc == 198)' "no countexp: rc 198"
capture noisily datacheck, gatesonly smallcells((n1-e1 n0) mincell(5)
_cv `=!(_rc != 0 & _rc != 9)' "unbalanced parenthesis on the command line: Stata's own parser stops it (rc `=_rc')"
preserve
clear
input str12 gate str40 var
"smallcells" "(n1-e1 n0"
end
save "`W'/specp.dta", replace
restore
capture noisily datacheck, gatesonly checks("`W'/specp.dta") mincell(5)
_cv `=!(_rc == 198)' "unbalanced parenthesis through checks(): rc 198"
capture noisily datacheck, gatesonly smallcells(n1 if nosuchvar > 1) mincell(5)
_cv `=!(_rc == 111)' "an if that does not evaluate: rc 111"
capture noisily datacheck, gatesonly smallcells(n1 n1*) mincell(5)
_cv `=!(_rc != 0 & _rc != 9)' "a malformed expression: an error, not a pass"
* a string variable is not a count
generate str5 sv = "abc"
capture noisily datacheck, gatesonly smallcells(sv) mincell(5)
_cv `=!(_rc == 109)' "a string variable: rc 109"
* a parenthesised expression may hold spaces
capture noisily datacheck, gatesonly smallcells((n1 - e1) e1 if !suppressed) mincell(5)
_cv `=!(_rc == 0)' "a parenthesised expression may contain spaces and evaluates"
* the check is on the parse path: a parse error is not downgraded by gatesonly or warn
capture noisily datacheck, gatesonly smallcells(n1 nosuchvar) mincell(5) warn
_cv `=!(_rc == 111)' "warn does not downgrade a parse error"

* tidy
local files : dir "`W'" files "*"
foreach f of local files {
    capture erase "`W'/`f'"
}
capture rmdir "`W'"

display as text _newline "RESULT: test_datacheck_v190_smallcells tests=$TC pass=$PASS fail=$FAIL"
if $FAIL > 0 exit 1
