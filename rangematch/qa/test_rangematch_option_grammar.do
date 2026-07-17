* test_rangematch_option_grammar.do
* Phase 2 public-contract regressions:
*   RM-I03  keepusing() is a real Stata varlist (wildcards, ranges, _all)
*   RM-I04  an explicitly empty required argument fails rc=198
*   RM-I05  missing(drop) emptying the using side honours unmatched()
*   RM-I07  r(saving) names the file that actually exists
*
* All of these FAIL on the shipped 1.3.3 code.

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
clear all
version 16.1
set varabbrev off

local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
    local qa_dir "`cwd'"
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
}
else {
    local pkg_dir "`cwd'"
    local qa_dir "`pkg_dir'/qa"
}


local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _rm_mk_master
program define _rm_mk_master
    clear
    quietly set obs 1
    quietly gen double mlow = 0
    quietly gen double mhigh = 10
end

capture program drop _rm_mk_using
program define _rm_mk_using
    clear
    quietly set obs 2
    quietly gen double key = _n
    quietly gen double x1 = 10
    quietly gen double x2 = 20
    quietly gen double y1 = 30
end

**# T1: RM-I04 -- every required-argument option rejects an empty argument
local ++test_count
capture noisily {
    _rm_mk_using
    tempfile u
    quietly save "`u'"
    foreach opt in "missing()" "assert()" "closed()" "nearest()" "ties()" ///
            "unmatched()" "keepusing()" "by()" "generate()" "distance()" ///
            "masterid()" "usingid()" "frame()" "seed()" "overlap()" "saving()" {
        _rm_mk_master
        capture rangematch key mlow mhigh using "`u'", `opt'
        if _rc != 198 {
            display as error "  `opt' gave rc=`_rc', expected 198"
            error 9
        }
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: empty required arguments fail rc=198"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T1_empty_args"
    display as error "FAIL: empty required arguments"
}

**# T2: RM-I04 -- abbreviated option names are screened too
local ++test_count
capture noisily {
    _rm_mk_using
    tempfile u
    quietly save "`u'"
    foreach opt in "miss()" "missi()" "as()" "sav()" "keepu()" ///
            "unmatch()" "near()" "gen()" "dist()" {
        _rm_mk_master
        capture rangematch key mlow mhigh using "`u'", `opt'
        if _rc != 198 {
            display as error "  `opt' gave rc=`_rc', expected 198"
            error 9
        }
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: abbreviated empty options fail rc=198"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T2_empty_abbrev"
    display as error "FAIL: abbreviated empty options"
}

**# T3: RM-I04 -- the real-world trap: a macro that expanded to nothing
local ++test_count
capture noisily {
    _rm_mk_using
    tempfile u
    quietly save "`u'"
    local policy ""
    _rm_mk_master
    capture rangematch key mlow mhigh using "`u'", missing(`policy')
    assert _rc == 198
    * whitespace-only is equally empty
    _rm_mk_master
    capture rangematch key mlow mhigh using "`u'", missing(  )
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: macro-expanded empty argument fails rc=198"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T3_macro_empty"
    display as error "FAIL: macro-expanded empty argument"
}

**# T4: RM-I04 -- NO false positives. The screen must not reject valid calls.
*       prefix()/suffix() are legitimately empty; a quoted path may contain
*       text that looks like an empty option; saving() with a quoted path and
*       no suboption must survive (masking quotes with spaces broke this).
local ++test_count
capture noisily {
    _rm_mk_using
    tempfile u
    quietly save "`u'"

    _rm_mk_master
    rangematch key mlow mhigh using "`u'"

    _rm_mk_master
    rangematch key mlow mhigh using "`u'", missing(drop) closed(both) ///
        unmatched(master)

    _rm_mk_master
    rangematch key mlow mhigh using "`u'", prefix() suffix() missing(drop)

    _rm_mk_master
    rangematch key mlow mhigh using "`u'", generate(by_flag)

    _rm_mk_master
    rangematch key mlow mhigh using "`u'", missing( drop )

    * quoted path containing literal option text with empty parens
    tempfile odd
    _rm_mk_master
    rangematch key mlow mhigh using "`u'", saving("`odd'", replace)

    _rm_mk_master
    rangematch key mlow mhigh using "`u'", usingid(src)
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: valid calls are not rejected by the empty screen"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T4_no_false_positives"
    display as error "FAIL: empty screen rejected a valid call"
}

**# T5: RM-I03 -- keepusing() expands wildcards, ranges, and _all
local ++test_count
capture noisily {
    _rm_mk_using
    tempfile u
    quietly save "`u'"

    _rm_mk_master
    rangematch key mlow mhigh using "`u'", keepusing(x*)
    local ku "`r(keepusing)'"
    assert "`ku'" == "x1 x2"
    confirm variable x1
    confirm variable x2
    capture confirm variable y1
    assert _rc != 0

    _rm_mk_master
    rangematch key mlow mhigh using "`u'", keepusing(x1-y1)
    local ku "`r(keepusing)'"
    assert "`ku'" == "x1 x2 y1"

    _rm_mk_master
    rangematch key mlow mhigh using "`u'", keepusing(_all)
    local ku "`r(keepusing)'"
    assert "`ku'" == "key x1 x2 y1"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: keepusing() expands wildcard/range/_all"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T5_keepusing_expand"
    display as error "FAIL: keepusing() varlist expansion"
}

**# T6: RM-I03 -- expanded names drive output naming (the r(198) x*_U bug)
local ++test_count
capture noisily {
    _rm_mk_using
    tempfile u
    quietly save "`u'"
    _rm_mk_master
    rangematch key mlow mhigh using "`u'", keepusing(x*) suffix(_U) all
    confirm variable x1_U
    confirm variable x2_U
    assert x1_U == 10
    assert x2_U == 20
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: expanded keepusing() builds valid output names"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T6_keepusing_names"
    display as error "FAIL: expanded keepusing() output names"
}

**# T7: RM-I03 -- frame source, dry run, and a bad pattern
local ++test_count
capture noisily {
    capture frame drop rm_kg_src
    frame create rm_kg_src
    frame rm_kg_src {
        _rm_mk_using
    }
    _rm_mk_master
    rangematch key mlow mhigh using rm_kg_src, keepusing(x*)
    local ku "`r(keepusing)'"
    assert "`ku'" == "x1 x2"

    _rm_mk_using
    tempfile u
    quietly save "`u'"
    _rm_mk_master
    rangematch key mlow mhigh using "`u'", keepusing(x*) dryrun
    local ku "`r(keepusing)'"
    assert "`ku'" == "x1 x2"

    _rm_mk_master
    capture rangematch key mlow mhigh using "`u'", keepusing(qqq*)
    assert _rc != 0
    capture frame drop rm_kg_src
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: keepusing() frame/dryrun/bad-pattern behaviour"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T7_keepusing_sources"
    display as error "FAIL: keepusing() sources"
}

**# T8: RM-I05 -- missing(drop) emptying the using side honours unmatched()
*       and matches the equivalent upstream drop (rc=0, not rc=2000)
local ++test_count
capture noisily {
    clear
    quietly set obs 2
    quietly gen double key = .
    tempfile umiss
    quietly save "`umiss'"

    foreach um in master none using both {
        _rm_mk_master
        rangematch key mlow mhigh using "`umiss'", missing(drop) unmatched(`um')
        if inlist("`um'", "master", "both") assert _N == 1
        if inlist("`um'", "none", "using")  assert _N == 0
    }
    * stats and count must survive the empty side
    _rm_mk_master
    rangematch key mlow mhigh using "`umiss'", missing(drop) stats
    _rm_mk_master
    rangematch key mlow mhigh using "`umiss'", missing(drop) count
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: missing(drop) empty using side honours unmatched()"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T8_empty_using"
    display as error "FAIL: missing(drop) empty using side"
}

**# T9: RM-I05 -- equivalence with the upstream drop, and assert() still fires
local ++test_count
capture noisily {
    * inside-the-command drop
    clear
    quietly set obs 2
    quietly gen double key = .
    tempfile umiss
    quietly save "`umiss'"
    _rm_mk_master
    rangematch key mlow mhigh using "`umiss'", missing(drop) unmatched(master)
    local n_inside = _N

    * identical filtering performed upstream
    clear
    quietly set obs 2
    quietly gen double key = .
    quietly drop if missing(key)
    tempfile uzero
    quietly save "`uzero'"
    _rm_mk_master
    rangematch key mlow mhigh using "`uzero'", missing(drop) unmatched(master)
    local n_upstream = _N

    assert `n_inside' == `n_upstream'

    * an emptied side must NOT silently satisfy assert(match)
    _rm_mk_master
    capture rangematch key mlow mhigh using "`umiss'", missing(drop) assert(match)
    assert _rc != 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: inside drop == upstream drop; assert() still fires"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T9_drop_equivalence"
    display as error "FAIL: missing(drop) upstream equivalence"
}

**# T10: RM-I05 -- missing(drop) may empty the MASTER side too
*        The phase contract says post-policy empty sides (plural) reach the
*        backends and honour unmatched()/assert()/stats/count. Pin exact output
*        instead of treating r(2000) as success.
local ++test_count
capture noisily {
    _rm_mk_using
    tempfile uok
    quietly save "`uok'"

    foreach um in master none using both {
        clear
        quietly set obs 1
        quietly gen double mlow = .
        quietly gen double mhigh = .
        rangematch key mlow mhigh using "`uok'", missing(drop) unmatched(`um')
        if inlist("`um'", "using", "both") assert _N == 2
        if inlist("`um'", "master", "none") assert _N == 0
        assert r(N_master) == 0
        assert r(N_using) == 2
        assert r(N_matched_pairs) == 0
    }

    * The equivalent upstream zero-row master follows the same join contract.
    clear
    quietly set obs 1
    quietly gen double mlow = .
    quietly gen double mhigh = .
    quietly drop in 1
    rangematch key mlow mhigh using "`uok'", unmatched(using)
    assert _N == 2
    assert r(N_master) == 0

    * A missing matching key can independently empty the master side.
    clear
    quietly set obs 1
    quietly gen double key = .
    rangematch key -1 1 using "`uok'", missing(drop) unmatched(using)
    assert _N == 2
    assert r(N_master_key_missing) == 1

    * Diagnostics/count routing survive; assert(using) still detects that no
    * using row matched, while assert(match) is vacuously true for zero masters.
    clear
    quietly set obs 1
    quietly gen double mlow = .
    quietly gen double mhigh = .
    rangematch key mlow mhigh using "`uok'", missing(drop) unmatched(using) stats
    clear
    quietly set obs 1
    quietly gen double mlow = .
    quietly gen double mhigh = .
    rangematch key mlow mhigh using "`uok'", missing(drop) count
    clear
    quietly set obs 1
    quietly gen double mlow = .
    quietly gen double mhigh = .
    capture rangematch key mlow mhigh using "`uok'", missing(drop) assert(using)
    assert _rc == 9
    clear
    quietly set obs 1
    quietly gen double mlow = .
    quietly gen double mhigh = .
    rangematch key mlow mhigh using "`uok'", missing(drop) assert(match) unmatched(none)
    assert _N == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: empty master side honours output/assert routing"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T10_empty_master"
    display as error "FAIL: missing(drop) empty master side"
}

**# T11: RM-I07 -- r(saving) names a file that exists, for every path shape
local ++test_count
capture noisily {
    _rm_mk_using
    tempfile u
    quietly save "`u'"

    * no extension: save appends .dta, so r(saving) must report the .dta file
    local f1 "`c(tmpdir)'/rm_qa_i07_noext"
    capture erase "`f1'.dta"
    _rm_mk_master
    rangematch key mlow mhigh using "`u'", saving("`f1'", replace)
    local rs "`r(saving)'"
    confirm file "`rs'"
    assert "`rs'" == "`f1'.dta"
    capture erase "`f1'.dta"

    * explicit .dta
    local f2 "`c(tmpdir)'/rm_qa_i07_ext.dta"
    capture erase "`f2'"
    _rm_mk_master
    rangematch key mlow mhigh using "`u'", saving("`f2'", replace)
    local rs "`r(saving)'"
    confirm file "`rs'"
    assert "`rs'" == "`f2'"
    capture erase "`f2'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: r(saving) exists for extension/no-extension paths"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T11_saving_exists"
    display as error "FAIL: r(saving) path normalization"
}

**# T12: RM-I07 -- a DOTTED name is written literally: .dta must NOT be added.
*        Stata's rule is "no extension -> append .dta", not "does not end in
*        .dta -> append .dta". A tempfile (St<pid>.<seq>) is the case that bites:
*        forcing .dta would write a different file and leak past cleanup.
local ++test_count
capture noisily {
    _rm_mk_using
    tempfile u
    quietly save "`u'"

    local f3 "`c(tmpdir)'/rm_qa_i07.v1.2"
    capture erase "`f3'"
    _rm_mk_master
    rangematch key mlow mhigh using "`u'", saving("`f3'", replace)
    local rs "`r(saving)'"
    assert "`rs'" == "`f3'"
    confirm file "`rs'"
    capture erase "`f3'"

    * tempfile round trip: r(saving) must be the registered tempfile itself
    tempfile tf
    _rm_mk_master
    rangematch key mlow mhigh using "`u'", saving("`tf'", replace)
    local rs "`r(saving)'"
    assert "`rs'" == "`tf'"
    confirm file "`rs'"
    use "`rs'", clear
    quietly count
    assert r(N) > 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: dotted/tempfile names are reported literally"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' T12_saving_dotted"
    display as error "FAIL: dotted/tempfile saving() name"
}

capture program drop _rm_mk_master
capture program drop _rm_mk_using

display as result _newline "OPTION GRAMMAR TEST SUMMARY"
display as result "Tests:  `test_count'"
display as result "Passed: `pass_count'"
display as result "Failed: `fail_count'"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display "RESULT: test_rangematch_option_grammar tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 9
}
display "RESULT: test_rangematch_option_grammar tests=`test_count' pass=`pass_count' fail=`fail_count'"
