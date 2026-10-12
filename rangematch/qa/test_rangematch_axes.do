*! test_rangematch_axes.do
*! qa-lib adversarial axis probes for rangematch (clarity audit 2026-10-12,
*! IMPORTANT #4). Each block drives one owed axis through the vendored helper
*! that the axis contract counts; hand-rolled neighbours elsewhere in qa/ do
*! not count toward it.
*!
*!   A  fingerprint-error  failing calls (missing saving() directory, bad
*!                         closed(), macro characters in saving()) leave the
*!                         caller's state untouched, frames included
*!   B  lifecycle          foreign estimates A -> B -> restore A do not change
*!                         what a saving() call writes or returns
*!   C  parity             the matched count agrees across r(), the console
*!                         table, and the in-place/frame/saving/dryrun routes;
*!                         a distance agrees between r()-free oracle and frame
*!   D  hostile-strings    saving() and using names from the qa-lib corpus are
*!                         written and reported byte-exact, or refused r(198)
*!                         when they hold ` or $, with no stranded frames
*!   E  hostile-fixture    by() on codes above maxlong, negative and prefix-
*!                         pair codes, and on 32-character names that differ
*!                         only in the last character, against a joinby oracle

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"
local qa_dir  "`r(qa_dir)'"
clear all
version 16.1
set varabbrev off
set linesize 255

do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_hostile.do"
do "`qa_dir'/_qa_parity.do"
do "`qa_dir'/_qa_lifecycle.do"

local TESTS 0
local PASS 0
local FAIL 0

* Private output directory under c(tmpdir); the token carries the pid.
tempfile tok_probe
mata: st_local("tok", subinstr(pathbasename(st_local("tok_probe")), ".", "_"))
local out_dir "`c(tmpdir)'/rm_axes_`tok'"
capture mkdir "`out_dir'"

* Fixture. using: uid 1-4 at key 1, 3, 6, 10. master: mid 1-3 with intervals
* [0,4] (uid 1 and 2), [5,7] (uid 3), [20,30] (none). Default unmatched(master):
* 3 matched rows + 1 unmatched master row = 4 output rows; uid 4 is the one
* unmatched using observation. y and x exist only so a regression can run.
capture program drop _ax_data
program define _ax_data
    syntax , USING(string)
    clear
    quietly set obs 4
    generate long uid = _n
    generate double key = cond(_n == 1, 1, cond(_n == 2, 3, cond(_n == 3, 6, 10)))
    quietly save `"`using'"', replace
    clear
    quietly set obs 3
    generate long mid = _n
    generate double lo = cond(_n == 1, 0, cond(_n == 2, 5, 20))
    generate double hi = cond(_n == 1, 4, cond(_n == 2, 7, 30))
    generate double y = cond(_n == 1, 1, cond(_n == 2, 3, 2))
    generate double x = cond(_n == 1, 2, cond(_n == 2, 1, 5))
end

* Reads a saved output back and returns what a later reader would see.
capture program drop _ax_readback
program define _ax_readback, rclass
    version 16.1
    args file
    preserve
    quietly use `"`file'"', clear
    quietly count if !missing(uid)
    return scalar N_matched = r(N)
    return scalar N = _N
    quietly summarize uid, meanonly
    return scalar sum_uid = r(sum)
    restore
end

tempfile u
_ax_data, using(`"`u'"')
tempfile master
quietly save `"`master'"'

**# A fingerprint-error: failing calls leave the caller's state untouched
local ++TESTS
capture noisily {
    quietly use `"`master'"', clear
    qa_state_snapshot, tag(ax_err_save)
    capture noisily rangematch key lo hi using `"`u'"', saving(`"`out_dir'/no_such_dir/out.dta"')
    local rc = _rc
    assert `rc' != 0
    assert `rc' == 603
    qa_state_compare, tag(ax_err_save)

    qa_state_snapshot, tag(ax_err_closed)
    capture noisily rangematch key lo hi using `"`u'"', closed(sideways)
    local rc = _rc
    assert `rc' != 0
    assert `rc' == 198
    qa_state_compare, tag(ax_err_closed)

    mata: st_local("bad", st_local("out_dir") + "/a " + char(96) + "b.dta")
    qa_state_snapshot, tag(ax_err_tick)
    capture noisily rangematch key lo hi using `"`u'"', saving(`"`macval(bad)'"')
    local rc = _rc
    assert `rc' != 0
    assert `rc' == 198
    qa_state_compare, tag(ax_err_tick)
}
if _rc {
    local ++FAIL
    display as error "FAIL: A failing calls leave caller state untouched"
}
else {
    local ++PASS
    display as result "PASS: A failing calls leave caller state untouched"
}

**# B lifecycle: foreign estimates do not change a saving() call
local ++TESTS
capture noisily {
    quietly use `"`master'"', clear
    local out "`out_dir'/lifecycle.dta"
    qa_lifecycle, fita(regress y x) fitb(regress y lo hi) ///
        post(rangematch key lo hi using `"`u'"', saving(`"`out'"', replace) masterid(mrow); _ax_readback `"`out'"')
    assert e(cmd) == "regress"
    _ax_readback `"`out'"'
    assert r(N) == 4
    assert r(N_matched) == 3
    assert r(sum_uid) == 6
    * The caller's data were never replaced by the saving() route.
    assert _N == 3 & c(k) == 5
}
if _rc {
    local ++FAIL
    display as error "FAIL: B foreign estimate lifecycle around saving()"
}
else {
    local ++PASS
    display as result "PASS: B foreign estimate lifecycle around saving()"
}

**# C parity: one count across r(), console and every output route
local ++TESTS
capture noisily {
    quietly use `"`master'"', clear
    tempfile lg
    tempname matched
    log using `"`lg'"', text replace name(axpar) nomsg
    rangematch key lo hi using `"`u'"', frame(ax_out) replace
    scalar `matched' = r(N_matched_pairs)
    log close axpar
    qa_surface_parity, name(matched rows) expect(3) result(scalar(`matched')) ///
        log(`"`lg'"') logregex("^ +Matched +([0-9,]+)")
    frame ax_out: quietly count if !missing(uid)
    assert r(N) == 3
    capture frame drop ax_out

    * Route parity: the same counts on every route.
    foreach route in inplace frame saving dryrun {
        quietly use `"`master'"', clear
        local ropt ""
        if "`route'" == "frame"  local ropt "frame(ax_route) replace"
        if "`route'" == "saving" local ropt `"saving(`"`out_dir'/route.dta"', replace)"'
        if "`route'" == "dryrun" local ropt "dryrun"
        * stats: r(N_unmatched_using) is a match-density result.
        quietly rangematch key lo hi using `"`u'"', `ropt' stats
        qa_surface_parity, name(`route' N_pairs) expect(4) result(r(N_pairs))
        qa_surface_parity, name(`route' N_matched_pairs) expect(3) result(r(N_matched_pairs))
        qa_surface_parity, name(`route' N_unmatched) expect(1) result(r(N_unmatched))
        qa_surface_parity, name(`route' N_unmatched_using) expect(1) result(r(N_unmatched_using))
        assert "`r(backend)'" != ""
        if "`route'" == "inplace" local backend0 "`r(backend)'"
        else assert "`r(backend)'" == "`backend0'"
        capture frame drop ax_route
    }
}
local body_rc = _rc
capture log close axpar
capture frame drop ax_out
capture frame drop ax_route
if `body_rc' {
    local ++FAIL
    display as error "FAIL: C count parity across r(), console and routes"
}
else {
    local ++PASS
    display as result "PASS: C count parity across r(), console and routes"
}

local ++TESTS
capture noisily {
    * Distance parity in scalar-offset mode: master key 4, window [-2, +2];
    * using keys 3 and 6 are within, at signed distances -1 and +2.
    clear
    quietly set obs 3
    generate long uid = _n
    generate double key = 3 * _n
    tempfile ud
    quietly save `"`ud'"'
    clear
    quietly set obs 1
    generate long mid = 1
    generate double key = 4
    rangematch key -2 2 using `"`ud'"', frame(ax_dist) replace distance(dist) nosort
    frame ax_dist: sort uid
    qa_surface_parity, name(distance uid 1) expect(-1) frame(ax_dist dist 1)
    qa_surface_parity, name(distance uid 2) expect(2) frame(ax_dist dist 2)
    frame ax_dist: assert _N == 2
}
local body_rc = _rc
capture frame drop ax_dist
if `body_rc' {
    local ++FAIL
    display as error "FAIL: C distance parity between oracle and frame"
}
else {
    local ++PASS
    display as result "PASS: C distance parity between oracle and frame"
}

**# D hostile strings in saving() and using names
qa_hostile_strings
local hs_names "`r(names)'"
foreach g of local hs_names {
    local ++TESTS
    capture noisily {
        quietly use `"`master'"', clear
        mata: st_local("s", st_global("`g'"))
        mata: st_local("macro_char", strofreal(strpos(st_local("s"), char(96)) | strpos(st_local("s"), char(36))))
        mata: st_local("f", st_local("out_dir") + "/sv_" + st_local("s") + ".dta")
        mata: st_local("uf", st_local("out_dir") + "/us_" + st_local("s") + ".dta")
        * Stage the using file under the hostile name. A name holding ` or $
        * is refused before any file is read, so it needs no staged file (and
        * could not be saved safely: save would expand it too).
        if !`macro_char' {
            preserve
            quietly use `"`u'"', clear
            quietly save `"`macval(uf)'"', replace
            restore
            mata: st_local("uf_exists", strofreal(fileexists(st_local("uf"))))
            assert `uf_exists' == 1
        }

        qa_state_snapshot, tag(ax_hs)
        capture noisily rangematch key lo hi using `"`u'"', saving(`"`macval(f)'"', replace)
        local rc_s = _rc
        mata: st_local("got", st_global("r(saving)"))
        mata: st_local("same", strofreal(st_local("got") == st_local("f")))
        mata: st_local("f_exists", strofreal(fileexists(st_local("f"))))
        qa_state_compare, tag(ax_hs)
        if `macro_char' {
            assert `rc_s' == 198
            assert `f_exists' == 0
        }
        else {
            assert `rc_s' == 0
            assert `same' == 1
            assert `f_exists' == 1
            _ax_readback `"`macval(f)'"'
            assert r(N) == 4 & r(N_matched) == 3 & r(sum_uid) == 6
        }

        quietly use `"`master'"', clear
        capture noisily rangematch key lo hi using `"`macval(uf)'"', frame(ax_hs_out) replace
        local rc_u = _rc
        mata: st_local("gotu", st_global("r(using)"))
        mata: st_local("sameu", strofreal(st_local("gotu") == st_local("uf")))
        if `macro_char' {
            assert `rc_u' == 198
            capture confirm frame ax_hs_out
            assert _rc != 0
        }
        else {
            assert `rc_u' == 0
            assert `sameu' == 1
            frame ax_hs_out: quietly count if !missing(uid)
            assert r(N) == 3
        }
        * No workspace frame may survive either outcome.
        quietly frames dir
        local fr "`r(frames)'"
        assert !strpos(" `fr' ", " __rm_")
        display as text "`g': saving rc=`rc_s' using rc=`rc_u'"
    }
    local body_rc = _rc
    capture frame drop ax_hs_out
    capture qa_state_drop, tag(ax_hs)
    if `body_rc' {
        local ++FAIL
        display as error "FAIL: D hostile name `g'"
    }
    else {
        local ++PASS
        display as result "PASS: D hostile name `g'"
    }
}
capture macro drop QA_HS_*

**# E hostile by() fixtures against a joinby oracle
capture program drop _ax_oracle_check
program define _ax_oracle_check
    * Compare rangematch pairs with joinby + inrange on the same by variable.
    syntax , BY(name) USING(string) MASTER(string)
    tempfile got want
    quietly use `"`master'"', clear
    * keepusing(): a carried twin of the by() name would collide with the
    * master's copy, and its _U-decorated name exceeds 32 characters, which
    * rangematch rightly refuses.
    quietly rangematch key lo hi using `"`using'"', by(`by') unmatched(none) keepusing(uid)
    keep mid uid
    sort mid uid
    quietly save `"`got'"'
    quietly use `"`master'"', clear
    quietly joinby `by' using `"`using'"'
    quietly keep if inrange(key, lo, hi)
    keep mid uid
    sort mid uid
    quietly save `"`want'"'
    quietly count
    local nw = r(N)
    quietly use `"`got'"', clear
    assert _N == `nw'
    assert _N > 0
    quietly cf _all using `"`want'"'
end

local ++TESTS
capture noisily {
    qa_hostile_codes, clear
    local ncodes = r(ngroups)
    assert `ncodes' == 5
    * using: the 15 code rows, each a point at key = y.
    rename y key
    generate long uid = _n
    recast double key
    tempfile uc mc
    quietly save `"`uc'"'
    * master: one interval per code, covering the code's first two keys only,
    * so a collapsed or rounded code would pull in a neighbour's rows.
    quietly bysort code (key): keep if _n == 1
    generate double lo = key
    generate double hi = key + 1
    keep code lo hi
    generate long mid = _n
    quietly save `"`mc'"'
    _ax_oracle_check, by(code) using(`"`uc'"') master(`"`mc'"')
    * Every code group matches at least its own first key.
    assert _N >= `ncodes'
}
if _rc {
    local ++FAIL
    display as error "FAIL: E by() on hostile codes matches the joinby oracle"
}
else {
    local ++PASS
    display as result "PASS: E by() on hostile codes matches the joinby oracle"
}

local ++TESTS
capture noisily {
    qa_hostile_names, clear
    local long "`r(long)'"
    local n1 : word 1 of `long'
    local n2 : word 2 of `long'
    assert strlen("`n1'") == 32 & strlen("`n2'") == 32 & "`n1'" != "`n2'"
    * Two group variables that differ only in character 32 and disagree on
    * every row: grouping on the wrong one would change the pairs.
    keep in 1/6
    keep `n1' `n2'
    quietly replace `n1' = mod(_n, 2)
    quietly replace `n2' = 1 - mod(_n, 2)
    generate long uid = _n
    generate double key = _n
    tempfile un mn
    quietly save `"`un'"'
    clear
    quietly set obs 2
    generate long mid = _n
    generate double `n1' = _n - 1
    generate double `n2' = _n - 1
    generate double lo = 0
    generate double hi = 10
    quietly save `"`mn'"'
    _ax_oracle_check, by(`n1') using(`"`un'"') master(`"`mn'"')
    assert _N == 6
    _ax_oracle_check, by(`n2') using(`"`un'"') master(`"`mn'"')
    assert _N == 6
    * The two groupings must disagree: mid 1 takes the even uids under one
    * name and the odd uids under the other.
    quietly use `"`mn'"', clear
    quietly rangematch key lo hi using `"`un'"', by(`n1') unmatched(none) keepusing(uid)
    quietly summarize uid if mid == 1, meanonly
    local s1 = r(sum)
    quietly use `"`mn'"', clear
    quietly rangematch key lo hi using `"`un'"', by(`n2') unmatched(none) keepusing(uid)
    quietly summarize uid if mid == 1, meanonly
    assert `s1' != r(sum)
}
if _rc {
    local ++FAIL
    display as error "FAIL: E by() on 32-character near-twin names"
}
else {
    local ++PASS
    display as result "PASS: E by() on 32-character near-twin names"
}

* Remove the private output directory (names may be hostile: go through Mata).
mata: _ax_files = dir(st_local("out_dir"), "files", "*")
mata: for (_ax_i = 1; _ax_i <= rows(_ax_files); _ax_i++) unlink(st_local("out_dir") + "/" + _ax_files[_ax_i])
mata: mata drop _ax_files _ax_i
capture rmdir "`out_dir'"

display "RESULT: test_rangematch_axes tests=`TESTS' pass=`PASS' fail=`FAIL'"
if `FAIL' > 0 exit 1
