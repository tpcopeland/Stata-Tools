*! test_rangematch_v1512.do
*! Regression gates for 1.5.12: a backend that fails to compile mid-file.
*!
*! WHAT WENT WRONG (clarity audit 2026-10-12, IMPORTANT #1). _rm_mata_version()
*! was the FIRST function in the backend's compile block. A compile error
*! anywhere later aborted the block with the sentinel already defined, so the
*! next rangematch call saw a matching version, skipped the reload, and died
*! with `<istmt>: 3499 _rm_first_empty_opt() not found'. The 1.5.11 message also
*! hid the Mata diagnostic and always said "reinstall".
*!
*! The fixture copies the shipped backend into a private directory with a
*! strict-mode error injected before _rm_bsearch_left(), i.e. mid-file: after
*! the old sentinel position and before the new one. The private directory is
*! put ahead of the sandbox on the adopath for the broken calls only.
*!
*!   T1  call 1 stops with r(3000) and the one-line message naming the Stata
*!       version, the 16.1 requirement, and the verbose diagnostic route;
*!       no _rm_mata_version() is left defined; matastrict is restored
*!       (under both matastrict off and on)
*!   T2  call 2 also stops with r(3000) and the same message, not r(3499)
*!   T3  `run <backend> verbose' prints the Mata diagnostic and rc 3000
*!   T4  once the broken copy is off the adopath, the next call reloads the
*!       shipped backend and matches
*!   T5  source contract: _rm_mata_version() is the last function the shipped
*!       backend defines
*!
*! Documentation claims made in 1.5.12 (clarity audit IMPORTANT #2, MINOR
*! #7-#10), run rather than searched for where they are behaviour:
*!   T6  scalar bounds are offsets from a same-named master key (as in
*!       rangejoin), and with no master key they stop with r(111)
*!   T7  a missing master key with variable bounds matches; the documented
*!       porting recipe reproduces rangejoin's output (that row unmatched)
*!   T8  the help's point-mode syntax brackets the comma, the Description
*!       names overlap() mode, and Example 1 has no {stata} link that would
*!       run with an undefined tempfile local
*!   T9  bench_rangematch.do and the README warn that it runs clear all
*!   T10 a ` or $name reaching any option (macval() at the call site) is
*!       refused r(198) with no __rm_* frame left, and the next call works;
*!       a $ that cannot start a reference (US$) is not refused (independent
*!       review 2026-10-12: seed()/generate()/masterid()/usingid()/distance()/
*!       by() still stranded the workspace frames after the saving() fix)

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"
local qa_dir  "`r(qa_dir)'"
clear all
version 16.1
set varabbrev off
set linesize 255

local TESTS 0
local PASS 0
local FAIL 0

capture findfile _rangematch_mata.ado
local shipped "`r(fn)'"

* Private broken copy under c(tmpdir); the token carries the pid.
tempfile tok_probe
mata: st_local("tok", subinstr(pathbasename(st_local("tok_probe")), ".", "_"))
local broken_dir "`c(tmpdir)'/rm1512_broken_`tok'"
capture mkdir "`broken_dir'"

capture mata: mata drop _v1512_inject()
capture mata: mata drop _v1512_scan()
capture mata: mata drop _v1512_last_def()
mata:
// Copy src to dest, inserting a function that compiles only with matastrict
// off immediately before the line that opens _rm_bsearch_left().
void _v1512_inject(string scalar src, string scalar dest)
{
    real scalar fi, fo, seen
    string matrix line
    fi = fopen(src, "r")
    fo = fopen(dest, "w")
    seen = 0
    while (1) {
        line = fget(fi)
        if (rows(line) == 0) break
        if (!seen & strpos(line, "real scalar _rm_bsearch_left(") == 1) {
            fput(fo, "void __v1512_undeclared()")
            fput(fo, "{")
            fput(fo, "    v1512_x = 1")
            fput(fo, "}")
            seen = 1
        }
        fput(fo, line)
    }
    fclose(fi)
    fclose(fo)
    st_local("inject_seen", strofreal(seen))
}

// Number of lines in a text file containing needle.
void _v1512_scan(string scalar path, string scalar needle)
{
    string colvector lines
    lines = cat(path)
    st_local("n_hits", strofreal(sum(strpos(lines, needle) :> 0)))
}

// Name of the last Mata function defined at column 0 of the file.
void _v1512_last_def(string scalar path)
{
    string colvector lines
    string scalar last, s
    real scalar i
    lines = cat(path)
    last = ""
    for (i = 1; i <= rows(lines); i++) {
        s = lines[i]
        if (regexm(s, "^(real|string|void|transmorphic|pointer)[a-z ()]* (_rm_[A-Za-z0-9_]+)\(")) {
            last = regexs(2)
        }
    }
    st_local("last_def", last)
}
end

mata: _v1512_inject(st_local("shipped"), st_local("broken_dir") + "/_rangematch_mata.ado")

capture program drop _v1512_data
program define _v1512_data
    syntax , USING(string)
    clear
    quietly set obs 3
    quietly gen long uid = _n
    quietly gen double key = _n
    quietly save `"`using'"', replace
    clear
    quietly set obs 2
    quietly gen double lo = 0
    quietly gen double hi = 5
end

tempfile u
_v1512_data, using(`"`u'"')

**# T1 and T2: two calls against the broken backend, matastrict off and on
foreach strict in off on {
    capture mata: mata drop _rm_mata_version()
    mata: mata set matastrict `strict'
    local ++TESTS
    capture noisily {
        assert "`inject_seen'" == "1"
        adopath ++ "`broken_dir'"
        capture findfile _rangematch_mata.ado
        assert "`r(fn)'" == "`broken_dir'/_rangematch_mata.ado"
        tempfile lg
        log using `"`lg'"', text replace name(v1512) nomsg
        capture noisily rangematch key lo hi using `"`u'"'
        local rc1 = _rc
        log close v1512
        display as text "strict=`strict' call 1 rc=`rc1'"
        assert `rc1' == 3000
        assert c(matastrict) == "`strict'"
        capture mata: st_local("still", _rm_mata_version())
        assert _rc != 0
        mata: _v1512_scan(st_local("lg"), "failed to compile (r(3000)) under Stata `c(stata_version)'")
        assert `n_hits' == 1
        mata: _v1512_scan(st_local("lg"), "requires Stata 16.1 or newer")
        assert `n_hits' == 1
        mata: _v1512_scan(st_local("lg"), "_rangematch_mata.ado" + char(34) + " verbose")
        assert `n_hits' == 1
        * The caller's data are untouched.
        assert _N == 2 & c(k) == 2
    }
    local body_rc = _rc
    capture log close v1512
    capture adopath - "`broken_dir'"
    if `body_rc' {
        local ++FAIL
        display as error "FAIL: T1 [strict=`strict'] first call reports the compile failure"
    }
    else {
        local ++PASS
        display as result "PASS: T1 [strict=`strict'] first call reports the compile failure"
    }

    local ++TESTS
    capture noisily {
        adopath ++ "`broken_dir'"
        tempfile lg2
        log using `"`lg2'"', text replace name(v1512b) nomsg
        capture noisily rangematch key lo hi using `"`u'"'
        local rc2 = _rc
        log close v1512b
        display as text "strict=`strict' call 2 rc=`rc2'"
        assert `rc2' == 3000
        assert c(matastrict) == "`strict'"
        mata: _v1512_scan(st_local("lg2"), "failed to compile (r(3000))")
        assert `n_hits' == 1
        mata: _v1512_scan(st_local("lg2"), "not found")
        assert `n_hits' == 0
        assert _N == 2 & c(k) == 2
    }
    local body_rc = _rc
    capture log close v1512b
    capture adopath - "`broken_dir'"
    if `body_rc' {
        local ++FAIL
        display as error "FAIL: T2 [strict=`strict'] second call retries the load, not r(3499)"
    }
    else {
        local ++PASS
        display as result "PASS: T2 [strict=`strict'] second call retries the load, not r(3499)"
    }
}
mata: mata set matastrict off

**# T3: the verbose route shows the Mata diagnostic
local ++TESTS
capture noisily {
    tempfile lg3
    log using `"`lg3'"', text replace name(v1512c) nomsg
    capture noisily run "`broken_dir'/_rangematch_mata.ado" verbose
    local rc3 = _rc
    log close v1512c
    assert `rc3' == 3000
    mata: _v1512_scan(st_local("lg3"), "v1512_x")
    assert `n_hits' >= 1
    mata: _v1512_scan(st_local("lg3"), "undeclared")
    assert `n_hits' >= 1
    assert c(matastrict) == "off"
}
local body_rc = _rc
capture log close v1512c
if `body_rc' {
    local ++FAIL
    display as error "FAIL: T3 run ... verbose prints the Mata diagnostic"
}
else {
    local ++PASS
    display as result "PASS: T3 run ... verbose prints the Mata diagnostic"
}

**# T4: with the broken copy gone, the next call reloads and matches
local ++TESTS
capture noisily {
    capture findfile _rangematch_mata.ado
    assert "`r(fn)'" == "`shipped'"
    quietly rangematch key lo hi using `"`u'"'
    assert r(N_matched_pairs) == 6
    assert _N == 6
    local got ""
    mata: st_local("got", _rm_mata_version())
    assert "`got'" == "1.5.13"
}
if _rc {
    local ++FAIL
    display as error "FAIL: T4 the shipped backend reloads after a failed compile"
}
else {
    local ++PASS
    display as result "PASS: T4 the shipped backend reloads after a failed compile"
}

**# T5: the sentinel is the last function the shipped backend defines
local ++TESTS
capture noisily {
    mata: _v1512_last_def(st_local("shipped"))
    display as text "last function defined: `last_def'"
    assert "`last_def'" == "_rm_mata_version"
}
if _rc {
    local ++FAIL
    display as error "FAIL: T5 _rm_mata_version() is defined last"
}
else {
    local ++PASS
    display as result "PASS: T5 _rm_mata_version() is defined last"
}

**# T6: scalar bounds are offsets from the master key; no key is r(111)
local ++TESTS
capture noisily {
    clear
    quietly set obs 2
    generate long uid = _n
    generate double key = cond(_n == 1, 5, 12)
    tempfile mu
    quietly save `"`mu'"'
    clear
    quietly set obs 2
    generate long mid = _n
    generate double key = cond(_n == 1, 4, 11)
    tempfile mm
    quietly save `"`mm'"'
    * key 4 + [-2, 2] holds using key 5; key 11 + [-2, 2] holds using key 12.
    quietly rangematch key -2 2 using `"`mu'"', unmatched(none)
    assert _N == 2
    sort mid
    assert uid[1] == 1 & uid[2] == 2
    * With no master key, the constants are not absolute bounds.
    quietly use `"`mm'"', clear
    drop key
    capture rangematch key 0 10 using `"`mu'"'
    assert _rc == 111
    assert _N == 2 & c(k) == 1
}
if _rc {
    local ++FAIL
    display as error "FAIL: T6 scalar-bound migration claims"
}
else {
    local ++PASS
    display as result "PASS: T6 scalar-bound migration claims"
}

**# T7: missing master key with variable bounds, and the porting recipe
local ++TESTS
capture noisily {
    quietly use `"`mm'"', clear
    quietly replace key = . in 2
    generate double lo = 0
    generate double hi = 10
    tempfile mk
    quietly save `"`mk'"'
    * rangematch: the carried missing key does not stop mid 2 matching uid 1.
    quietly rangematch key lo hi using `"`mu'"'
    quietly count if mid == 2 & uid == 1
    assert r(N) == 1
    * The help's recipe, verbatim apart from the file names.
    quietly use `"`mk'"', clear
    preserve
    keep if missing(key)
    tempfile nokey
    save `nokey'
    restore
    rangematch key lo hi using `"`mu'"' if !missing(key)
    append using `nokey'
    * rangejoin's result (SSC 1.1.3, run 2026-10-12): mid 1 matched to uid 1,
    * mid 2 present once and unmatched.
    assert _N == 2
    quietly count if mid == 1 & uid == 1
    assert r(N) == 1
    quietly count if mid == 2 & missing(uid)
    assert r(N) == 1
}
if _rc {
    local ++FAIL
    display as error "FAIL: T7 missing master key and the rangejoin porting recipe"
}
else {
    local ++PASS
    display as result "PASS: T7 missing master key and the rangejoin porting recipe"
}

**# T8: help-file syntax, Description, and example links
local ++TESTS
capture noisily {
    capture findfile rangematch.sthlp
    local hlp "`r(fn)'"
    * Point mode has no required option: the comma sits inside the brackets.
    mata: _v1512_scan(st_local("hlp"), "{ifin}")
    assert `n_hits' == 2
    mata: _v1512_lines = cat(st_local("hlp"))
    mata: _v1512_at = selectindex(_v1512_lines :== "{ifin}")
    mata: st_local("after1", _v1512_lines[_v1512_at[1] + 1])
    mata: st_local("after2", _v1512_lines[_v1512_at[2] + 1])
    assert `"`after1'"' == "[{cmd:,}"
    assert `"`after2'"' == "{cmd:,}"
    mata: mata drop _v1512_lines _v1512_at
    mata: _v1512_scan(st_local("hlp"), "In interval-overlap mode, set")
    assert `n_hits' == 1
    * No clickable example may reference a local macro.
    mata: _v1512_scan(st_local("hlp"), "{stata " + char(34) + "rangematch")
    assert `n_hits' == 0
    mata: _v1512_scan(st_local("hlp"), "Two {cmd:rangejoin} behaviors do not carry over")
    assert `n_hits' == 1
}
if _rc {
    local ++FAIL
    display as error "FAIL: T8 help syntax, Description and example links"
}
else {
    local ++PASS
    display as result "PASS: T8 help syntax, Description and example links"
}

**# T9: the benchmark's clear all is announced
local ++TESTS
capture noisily {
    mata: _v1512_scan(st_local("pkg_dir") + "/bench_rangematch.do", "WARNING: starts with -clear all-")
    assert `n_hits' == 1
    mata: _v1512_scan(st_local("pkg_dir") + "/bench_rangematch.do", "clear all")
    assert `n_hits' >= 2
    mata: _v1512_scan(st_local("pkg_dir") + "/README.md", "The benchmark starts with `clear all`")
    assert `n_hits' == 1
}
if _rc {
    local ++FAIL
    display as error "FAIL: T9 benchmark clear all warning"
}
else {
    local ++PASS
    display as result "PASS: T9 benchmark clear all warning"
}

**# T10: macro characters in any argument are refused without stranding frames
mata: st_local("tk", "a" + char(96) + "b")
mata: st_local("dl", char(36) + "HOME")
foreach opt in seed generate masterid usingid distance by prefix suffix keepusing missing assert {
    foreach bad in tk dl {
        local ++TESTS
        capture noisily {
            quietly use `"`mk'"', clear
            local v `"`macval(`bad')'"'
            if "`opt'" == "seed" local extra "nearest(before) ties(random)"
            else local extra ""
            capture noisily rangematch key lo hi using `"`mu'"', `opt'(`macval(v)') `extra'
            local rc = _rc
            assert `rc' == 198
            quietly frames dir
            assert !strpos(" `r(frames)' ", " __rm_")
            assert _N == 2
            quietly rangematch key lo hi using `"`mu'"'
            assert r(N_matched_pairs) == 2
        }
        if _rc {
            local ++FAIL
            display as error "FAIL: T10 `opt'() with `bad' is refused cleanly"
        }
        else {
            local ++PASS
            display as result "PASS: T10 `opt'() with `bad' is refused cleanly"
        }
    }
}
local ++TESTS
capture noisily {
    quietly use `"`mk'"', clear
    generate str4 cur = cond(_n == 1, "US$", "EUR")
    quietly rangematch key lo hi using `"`mu'"' if cur == "US$", unmatched(none)
    assert _N == 1 & mid == 1
    quietly use `"`mk'"', clear
    generate str8 cur = "x"
    mata: st_local("cond", "cur == " + char(34) + char(36) + "HOME" + char(34))
    capture noisily rangematch key lo hi using `"`mu'"' if `macval(cond)'
    assert _rc == 198
}
if _rc {
    local ++FAIL
    display as error "FAIL: T10 a literal US$ passes; a protected global reference is refused"
}
else {
    local ++PASS
    display as result "PASS: T10 a literal US$ passes; a protected global reference is refused"
}

capture erase "`broken_dir'/_rangematch_mata.ado"
capture rmdir "`broken_dir'"

display "RESULT: test_rangematch_v1512 tests=`TESTS' pass=`PASS' fail=`FAIL'"
if `FAIL' > 0 exit 1
