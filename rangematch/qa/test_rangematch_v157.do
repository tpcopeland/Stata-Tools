*! test_rangematch_v157.do
*! Regression gates for the 1.5.7 fixes.
*!
*!   T1  keepusing() range on a FRAME source was expanded against the internal
*!       work frame, whose column order puts the key and by() first. A range
*!       that spans the key in the source frame (a-c over `a key c') silently
*!       lost the key at rc=0.
*!   T2  frame and file sources expand the same keepusing() to the same
*!       variables, in the same (source) order.
*!   T3  file-source keepusing(_all) / keepusing(*) combined with by() failed
*!       r(103) "too many variables specified".
*!   T4  overlap(u u) -- one using variable as both bounds, i.e. degenerate
*!       point intervals -- crashed in Mata with r(3300). It must follow the
*!       documented closure rule: closed(both) equals point mode, closed(none)
*!       matches nothing.
*!   T5  a repeated by() variable failed r(111) "variable g not found".
*!   T6  guards: abbreviated / nonexistent keepusing() names are still refused
*!       on both sources after the expansion moved.
*!   T7  guard: a using file wider than c(maxvar) still joins with a narrow
*!       keepusing() (plain names and a pattern).

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
clear all
version 16.1

local TESTS 0
local PASS 0
local FAIL 0

**# T1: frame-source keepusing() range that spans the key keeps the key
local ++TESTS
capture noisily {
    capture frame drop v157_src
    frame create v157_src
    frame v157_src {
        input double(a key c) byte g
        1 5 3 1
        2 7 4 1
        end
    }
    clear
    input double(lo hi) byte g
    0 10 1
    end
    rangematch key lo hi using v157_src, keepusing(a-c) by(g) unmatched(none)
    assert "`r(keepusing)'" == "a key c"
    unab got : _all
    assert "`got'" == "lo hi g a key c"
    sort key
    assert _N == 2
    assert key[1] == 5 & a[1] == 1 & c[1] == 3
    assert key[2] == 7 & a[2] == 2 & c[2] == 4
    frame drop v157_src
}
if _rc {
    local ++FAIL
    display as error "FAIL: T1 frame-source keepusing() range keeps the spanned key"
}
else {
    local ++PASS
    display as result "PASS: T1 frame-source keepusing() range keeps the spanned key"
}

**# T2: frame and file sources expand keepusing() identically
local ++TESTS
capture noisily {
    tempfile usrc
    clear
    input double(a key c) byte g str2 s
    1 5 3 1 "p"
    end
    save "`usrc'"
    capture frame drop v157_src
    frame create v157_src
    frame v157_src: use "`usrc'"
    clear
    input double(lo hi) byte g
    0 10 1
    end
    tempfile m
    save "`m'"
    foreach ku in "a-c" "key-s" "c-s" "*" "_all" "?" "a key c" {
        use "`m'", clear
        rangematch key lo hi using "`usrc'", keepusing(`ku') by(g)
        local kfile "`r(keepusing)'"
        unab vfile : _all
        use "`m'", clear
        rangematch key lo hi using v157_src, keepusing(`ku') by(g)
        local kframe "`r(keepusing)'"
        unab vframe : _all
        display "[`ku'] file=`kfile' | frame=`kframe'"
        assert "`kfile'" == "`kframe'"
        assert "`vfile'" == "`vframe'"
    }
    * The expansion follows the SOURCE order (a key c g s).
    use "`m'", clear
    rangematch key lo hi using v157_src, keepusing(key-s) by(g)
    assert "`r(keepusing)'" == "key c g s"
    unab got : _all
    assert "`got'" == "lo hi g key c s"
    frame drop v157_src
}
if _rc {
    local ++FAIL
    display as error "FAIL: T2 frame/file keepusing() expansion parity"
}
else {
    local ++PASS
    display as result "PASS: T2 frame/file keepusing() expansion parity"
}

**# T3: file-source keepusing(_all) and keepusing(*) work with by()
local ++TESTS
capture noisily {
    tempfile usrc
    clear
    input double(a key c) byte g
    1 5 3 1
    9 8 6 2
    end
    save "`usrc'"
    clear
    input double(lo hi) byte g
    0 10 1
    0 10 2
    end
    tempfile m
    save "`m'"
    foreach ku in "_all" "*" "_all key" {
        use "`m'", clear
        rangematch key lo hi using "`usrc'", keepusing(`ku') by(g)
        assert "`r(keepusing)'" == "a key c g"
        unab got : _all
        assert "`got'" == "lo hi g a key c"
        sort g
        assert a[1] == 1 & key[1] == 5 & c[1] == 3
        assert a[2] == 9 & key[2] == 8 & c[2] == 6
    }
    * dryrun takes the same expansion
    use "`m'", clear
    rangematch key lo hi using "`usrc'", keepusing(_all) by(g) dryrun
    assert "`r(keepusing)'" == "a key c g"
    assert r(N_pairs) == 2
}
if _rc {
    local ++FAIL
    display as error "FAIL: T3 file-source keepusing(_all)/(*) with by()"
}
else {
    local ++PASS
    display as result "PASS: T3 file-source keepusing(_all)/(*) with by()"
}

**# T4: overlap() with one using variable as both bounds
local ++TESTS
capture noisily {
    tempfile u
    clear
    input int uid double d byte g
    1 3 1
    2 7 1
    3 5 1
    4 5 2
    5 . 1
    end
    save "`u'"
    clear
    input int mid double(lo hi) byte g
    1 0 5 1
    2 5 5 1
    3 6 9 2
    4 . 4 1
    end
    tempfile m
    save "`m'"

    * closed(both): identical pair set to point mode. missing(drop) on both
    * routes, because a missing using bound is open-ended in overlap mode but a
    * missing point key never matches -- a documented difference between the
    * modes, not part of this gate.
    use "`m'", clear
    rangematch lo hi using "`u'", overlap(d d) by(g) unmatched(both) ///
        missing(drop) masterid(M) usingid(U)
    assert "`r(backend)'" == "overlap"
    assert r(N_using_inverted) == 0
    local np = r(N_pairs)
    keep M U
    sort M U
    tempfile ov
    save "`ov'"
    use "`m'", clear
    rangematch d lo hi using "`u'", by(g) unmatched(both) missing(drop) ///
        masterid(M) usingid(U)
    assert r(N_pairs) == `np'
    keep M U
    sort M U
    unab _v157_now : _all
    describe using "`ov'", varlist
    assert "`_v157_now'" == "`r(varlist)'"
    cf _all using "`ov'"

    * known answer under missing(wildcard): (1,1) (1,3) (2,3) (4,1), plus the
    * missing-bound using row 5, open-ended on both sides, matching every
    * group-1 master
    use "`m'", clear
    rangematch lo hi using "`u'", overlap(d d) by(g) unmatched(none) ///
        masterid(M) usingid(U)
    assert r(N_matched_pairs) == 4 + 3
    count if M == 1 & inlist(U, 1, 3, 5)
    assert r(N) == 3
    count if M == 2 & inlist(U, 3, 5)
    assert r(N) == 2
    count if M == 4 & inlist(U, 1, 5)
    assert r(N) == 2
    confirm variable d

    * closed(none): a degenerate (x,x) using interval is empty
    use "`m'", clear
    rangematch lo hi using "`u'", overlap(d d) by(g) closed(none) ///
        unmatched(none) masterid(M) usingid(U)
    * only the fully open using row 5 (missing -> -inf, +inf) is nonempty, and
    * master 2 = (5,5) is itself empty, leaving masters 1 and 4
    assert r(N_matched_pairs) == 2
    assert U == 5
    sort M
    assert M[1] == 1 & M[2] == 4

    * the source using file and the master data are unchanged in shape
    use "`u'", clear
    assert _N == 5
    unab got : _all
    assert "`got'" == "uid d g"
}
if _rc {
    local ++FAIL
    display as error "FAIL: T4 overlap(u u) degenerate using intervals"
}
else {
    local ++PASS
    display as result "PASS: T4 overlap(u u) degenerate using intervals"
}

**# T5: a repeated by() variable is the same partition as one mention
local ++TESTS
capture noisily {
    tempfile u
    clear
    input double key byte g int uid
    3 1 1
    4 2 2
    end
    save "`u'"
    clear
    input double(lo hi) byte g
    0 5 1
    0 5 2
    end
    tempfile m
    save "`m'"
    rangematch key lo hi using "`u'", by(g) masterid(M) usingid(U)
    keep M U
    sort M U
    tempfile once
    save "`once'"
    use "`m'", clear
    rangematch key lo hi using "`u'", by(g g) masterid(M) usingid(U)
    assert "`r(by)'" == "g"
    assert r(N_pairs) == 2
    keep M U
    sort M U
    unab _v157_now : _all
    describe using "`once'", varlist
    assert "`_v157_now'" == "`r(varlist)'"
    cf _all using "`once'"
}
if _rc {
    local ++FAIL
    display as error "FAIL: T5 repeated by() variable"
}
else {
    local ++PASS
    display as result "PASS: T5 repeated by() variable"
}

**# T6: abbreviated / nonexistent keepusing() names are still refused
local ++TESTS
capture noisily {
    tempfile u
    clear
    input double(alpha key) str3 beta byte g
    1 5 "x" 1
    end
    save "`u'"
    capture frame drop v157_src
    frame create v157_src
    frame v157_src: use "`u'"
    clear
    input double(lo hi) byte g
    0 10 1
    end
    tempfile m
    save "`m'"
    foreach src in file frame {
        local utok = cond("`src'" == "file", "`u'", "v157_src")
        foreach ku in "alp" "alpha bet" "nosuch" "alpha-nosuch" "zz*" {
            use "`m'", clear
            capture rangematch key lo hi using "`utok'", keepusing(`ku') by(g)
            local rc = _rc
            display "[`src'][`ku'] rc=`rc'"
            assert `rc' == 111
            * caller data untouched, no workspace left behind
            assert _N == 1
            unab got : _all
            assert "`got'" == "lo hi g"
            capture frame __rm_using: describe
            assert _rc != 0
        }
    }
    frame drop v157_src
}
if _rc {
    local ++FAIL
    display as error "FAIL: T6 invalid keepusing() names refused"
}
else {
    local ++PASS
    display as result "PASS: T6 invalid keepusing() names refused"
}

**# T7: a using FILE wider than c(maxvar) still joins with a narrow keepusing()
* The source-order expansion builds a shell holding every file variable; that
* is impossible past c(maxvar), where the plain-name and pattern forms must keep
* working exactly as before (use reads only the selected columns).
local ++TESTS
local _v157_maxvar0 = c(maxvar)
capture noisily {
    tempfile wide
    clear all
    set maxvar 2200
    set obs 2
    gen double key = 3 + 4 * (_n - 1)
    gen double w1 = 10 * _n
    gen double w2 = 20 * _n
    forvalues j = 1/2150 {
        quietly gen byte z`j' = 0
    }
    gen byte g = 1
    save "`wide'"
    clear all
    set maxvar 2048
    clear
    input double(lo hi) byte g
    0 5 1
    end
    tempfile m
    save "`m'"
    rangematch key lo hi using "`wide'", keepusing(w*) by(g) unmatched(none)
    assert "`r(keepusing)'" == "w1 w2"
    * the key is loaded for matching but carried only when listed
    assert _N == 1 & w1 == 10 & w2 == 20
    unab got : _all
    assert "`got'" == "lo hi g w1 w2"
    use "`m'", clear
    rangematch key lo hi using "`wide'", keepusing(key w2) by(g) unmatched(none)
    assert "`r(keepusing)'" == "key w2"
    assert _N == 1 & key == 3 & w2 == 20
}
local _v157_rc = _rc
clear all
set maxvar `_v157_maxvar0'
if `_v157_rc' {
    local ++FAIL
    display as error "FAIL: T7 using file wider than c(maxvar)"
}
else {
    local ++PASS
    display as result "PASS: T7 using file wider than c(maxvar)"
}

display "RESULT: test_rangematch_v157 tests=`TESTS' pass=`PASS' fail=`FAIL'"
if `FAIL' > 0 exit 1
