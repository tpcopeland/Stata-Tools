*! test_rangematch_dollar_paths.do
*! A $ that cannot start a global reference is literal in using and saving()
*! paths; a $ that can is refused.
*!
*! WHAT WENT WRONG (clarity audit 2026-10-12 final, IMPORTANT #1). 1.5.12
*! refused every $ in a using or saving() name with r(198), including Windows
*! hidden and administrative shares (\\server\share$\..., C$) that 1.5.11
*! handled and that Stata never expands: re-expanding `"`name'"' leaves a $
*! literal unless it is followed by a character that can start a name. The
*! general argument screen used that narrower rule, but missed two forms that
*! do expand: $$name (the inner reference expands first) and $ before a
*! Unicode letter ($éname is a global reference).
*!
*!   T1  using "<dir>/share$/u.dta" runs, matches, and r(using) is the exact
*!       path (also share$ followed by \, a digit, -, . in the file name)
*!   T2  saving("<dir>/share$/out.dta", replace) writes that exact file, and
*!       r(saving) is the exact path; the readback matches
*!   T3  a $ that can start a reference ($name, $_x, ${x}, $$x, $é) is still
*!       refused r(198) in using and in saving(): no file written under the
*!       literal or the expanded name, no __rm_* frame left
*!   T4  general screen: a protected $é reference in an if condition is
*!       refused r(198), not expanded into a different condition
*!   T5  the refusal message no longer claims Stata "would expand" every $

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
clear all
* clear all dropped the shared Mata helpers (_rm_qa_rmtree); reload them.
* The sandbox is session state and is rejoined, not rebuilt.
quietly do "`c(pwd)'/_rangematch_qa_common.do"
version 16.1
set varabbrev off

local TESTS 0
local PASS 0
local FAIL 0

* Private scratch tree under c(tmpdir), named with the tempfile token so the
* lane sweep owns it, and removed at the end of this file.
tempfile tok_probe
mata: st_local("tok", subinstr(pathbasename(st_local("tok_probe")), ".", "_"))
local root "`c(tmpdir)'/rm_dollar_`tok'"
mata: st_local("sd", st_local("root") + "/share" + char(36))
mata: mkdir(st_local("root")); mkdir(st_local("sd"))

tempfile mk uk
quietly {
    clear
    set obs 3
    generate long uid = _n
    generate double key = _n
    save `"`uk'"'
    clear
    set obs 2
    generate long mid = _n
    generate double lo = 0
    generate double hi = 5
    save `"`mk'"'
}

* Helper: no __rm_* workspace frame survives.
capture program drop _dp_noframes
program define _dp_noframes
    quietly frames dir
    assert !strpos(" `r(frames)' ", " __rm_")
end

**# T1 using paths whose $ cannot start a reference
* File names inside share$: plain, and with $ before a digit, -, . and at the
* end of the stem. Built in Mata so nothing expands while building them.
mata: st_local("n1", "u.dta")
mata: st_local("n2", "u" + char(36) + "1.dta")
mata: st_local("n3", "u" + char(36) + "-x.dta")
mata: st_local("n4", "u" + char(36) + ".dta")
foreach n in n1 n2 n3 n4 {
    local ++TESTS
    capture noisily {
        mata: st_local("uf", st_local("sd") + "/" + st_local("`n'"))
        preserve
        quietly use `"`uk'"', clear
        quietly save `"`macval(uf)'"', replace
        restore
        mata: st_local("ok", strofreal(fileexists(st_local("uf"))))
        assert `ok' == 1
        quietly use `"`mk'"', clear
        rangematch key lo hi using `"`macval(uf)'"'
        assert r(N_matched_pairs) == 6
        assert _N == 6
        mata: st_local("same", strofreal(st_global("r(using)") == st_local("uf")))
        assert `same' == 1
        _dp_noframes
    }
    if _rc {
        local ++FAIL
        display as error "FAIL: T1 using share" char(36) " path (`n')"
    }
    else {
        local ++PASS
        display as result "PASS: T1 using share" char(36) " path (`n')"
    }
}

* A Windows-style \ after the $: on Unix Stata reads it as part of the name or
* as a separator; either way the screen must not refuse it.
local ++TESTS
capture noisily {
    mata: st_local("wf", st_local("root") + "/share" + char(36) + char(92) + "u.dta")
    quietly use `"`mk'"', clear
    capture noisily rangematch key lo hi using `"`macval(wf)'"'
    local rc = _rc
    display as text "share" char(36) char(92) " rc=`rc'"
    assert inlist(`rc', 0, 601)
    _dp_noframes
}
if _rc {
    local ++FAIL
    display as error "FAIL: T1 using share" char(36) char(92) " is not refused"
}
else {
    local ++PASS
    display as result "PASS: T1 using share" char(36) char(92) " is not refused"
}

**# T2 saving() into share$ writes the exact file
foreach n in n1 n2 n4 {
    local ++TESTS
    capture noisily {
        mata: st_local("of", st_local("sd") + "/out_" + st_local("`n'"))
        mata: (void) _unlink(st_local("of"))
        quietly use `"`mk'"', clear
        mata: st_local("uf", st_local("sd") + "/u.dta")
        rangematch key lo hi using `"`macval(uf)'"', saving(`"`macval(of)'"', replace)
        mata: st_local("same", strofreal(st_global("r(saving)") == st_local("of")))
        assert `same' == 1
        mata: st_local("ok", strofreal(fileexists(st_local("of"))))
        assert `ok' == 1
        * The master in memory is untouched; the file holds the join.
        assert _N == 2
        quietly use `"`macval(of)'"', clear
        assert _N == 6
        quietly count if !missing(uid)
        assert r(N) == 6
        _dp_noframes
    }
    if _rc {
        local ++FAIL
        display as error "FAIL: T2 saving() into share" char(36) " (`n')"
    }
    else {
        local ++PASS
        display as result "PASS: T2 saving() into share" char(36) " (`n')"
    }
}

**# T3 a $ that can start a reference is still refused
global RM_DP_G "zz"
global zz "zz"
mata: st_global(uchar(233) + "zz", "zz")
mata: st_local("b1", "x" + char(36) + "RM_DP_G")
mata: st_local("b2", "x" + char(36) + "_zz")
mata: st_local("b3", "x" + char(36) + "{zz}")
mata: st_local("b4", "x" + char(36) + char(36) + "zz")
mata: st_local("b5", "x" + char(36) + uchar(233) + "zz")
foreach b in b1 b2 b3 b4 b5 {
    local ++TESTS
    capture noisily {
        mata: st_local("bf", st_local("sd") + "/" + st_local("`b'") + ".dta")
        quietly use `"`mk'"', clear
        capture noisily rangematch key lo hi using `"`macval(bf)'"'
        assert _rc == 198
        _dp_noframes
        assert _N == 2

        mata: st_local("uf", st_local("sd") + "/u.dta")
        capture noisily rangematch key lo hi using `"`macval(uf)'"', ///
            saving(`"`macval(bf)'"', replace)
        assert _rc == 198
        _dp_noframes
        assert _N == 2
        * Nothing written under the literal name, nor under any expansion
        * (every global used above expands to zz).
        mata: st_local("lit", strofreal(fileexists(st_local("bf"))))
        assert `lit' == 0
        mata: st_local("nexp", strofreal(rows(dir(st_local("sd"), "files", "xzz*"))))
        assert `nexp' == 0
        mata: st_local("nx", strofreal(rows(dir(st_local("sd"), "files", "x*"))))
        assert `nx' == 0
    }
    if _rc {
        local ++FAIL
        display as error "FAIL: T3 `b' reference refused in using and saving()"
    }
    else {
        local ++PASS
        display as result "PASS: T3 `b' reference refused in using and saving()"
    }
}

**# T4 general screen: a protected $é reference is refused
local ++TESTS
capture noisily {
    quietly use `"`mk'"', clear
    generate str4 cur = cond(_n == 1, "zz", "x")
    * Expanded, the condition would read cur == "zz" and keep mid 1 at rc 0.
    mata: st_local("cond", "cur == " + char(34) + char(36) + uchar(233) + "zz" + char(34))
    capture noisily rangematch key lo hi using `"`uk'"' if `macval(cond)', unmatched(none)
    assert _rc == 198
    _dp_noframes
    assert _N == 2
    * Same for $$name.
    mata: st_local("cond", "cur == " + char(34) + char(36) + char(36) + "RM_DP_G" + char(34))
    capture noisily rangematch key lo hi using `"`uk'"' if `macval(cond)', unmatched(none)
    assert _rc == 198
    _dp_noframes
}
if _rc {
    local ++FAIL
    display as error "FAIL: T4 protected " char(36) "é and " char(36) char(36) " references refused"
}
else {
    local ++PASS
    display as result "PASS: T4 protected " char(36) "é and " char(36) char(36) " references refused"
}

**# T5 the refusal message names the reference, not every $
local ++TESTS
capture noisily {
    findfile rangematch.ado
    mata: st_local("hits", strofreal(sum(strpos(cat(st_global("r(fn)")), "would expand it as a macro reference") :> 0)))
    assert `hits' == 0
    mata: st_local("hits", strofreal(sum(strpos(cat(st_global("r(fn)")), "that starts a global macro reference") :> 0)))
    assert `hits' == 3
}
if _rc {
    local ++FAIL
    display as error "FAIL: T5 refusal messages state the narrowed rule"
}
else {
    local ++PASS
    display as result "PASS: T5 refusal messages state the narrowed rule"
}

macro drop RM_DP_G zz
mata: st_global(uchar(233) + "zz", "")
mata: (void) _rm_qa_rmtree(st_local("root"))
mata: st_local("left", strofreal(direxists(st_local("root"))))
if `left' {
    display as error "scratch tree left behind"
    local ++FAIL
}

display "RESULT: test_rangematch_dollar_paths tests=`TESTS' pass=`PASS' fail=`FAIL'"
if `FAIL' > 0 exit 1
