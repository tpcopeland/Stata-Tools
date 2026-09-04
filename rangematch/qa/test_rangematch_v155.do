* test_rangematch_v155.do
* v1.5.5 regression suite: the three rc=0 corruption paths closed in this
* release, plus the Mata-helper handshake failure contracts.
*
* Every test here is red on 1.5.4. What they have in common is that the wrong
* answer arrived at rc=0 with no diagnostic:
*
*   T1-T6   a FINITE scalar offset added to a FINITE key can leave the double
*           range. Stata stores the result as missing, and a missing derived
*           bound is exactly the token both backends normalize to
*           mindouble()/maxdouble() -- so an interval that should contain
*           nothing matched everything. r(N_missing_bounds) could not report it
*           because it counts missing bound VARIABLES, and no variable was
*           missing.
*   T7-T11  Stata lets a variable stay attached to a value-label name that was
*           never defined. Collision allocation asked only whether a DEFINITION
*           existed, so it treated such a name as free and defined its own map
*           there -- and the pre-existing variable silently acquired the new
*           meanings.
*   T12-T13 a matched pair whose signed distance leaves the double range stored
*           missing, which is the value the help reserves for an UNMATCHED row.
*   T14-T15 the helper handshake: a missing or stale _rangematch_mata.ado must
*           abort with r(111) and leave the caller's data alone.
*
* Only the POSITIVE direction overflows. Stata reserves the doubles above
* maxdouble() for its missing codes, so 8e307 + 8e307 is missing, while
* -8e307 + -8e307 evaluates to -1.6e308 and is kept -- and that value is
* mathematically correct, since no using key can sit below it. T6 pins that
* asymmetry so a later "symmetric" guard does not start rejecting valid data.

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"
local qa_dir  "`r(qa_dir)'"
clear all
version 16.1

local TESTS 0
local PASS 0
local FAIL 0

* Shared using data: keys at both ends of the range and one at the origin.
tempfile U_extreme
clear
set obs 3
gen double key = cond(_n == 1, -8e307, cond(_n == 2, 0, 8e307))
gen long uid = _n
save "`U_extreme'"

capture program drop _rm155_master
program define _rm155_master
    args k
    clear
    set obs 1
    gen double key = `k'
    gen long mid = _n
end

**# T1: positive offset overflow on the LOWER bound aborts instead of matching
* 1.5.4: key + low = 1.6e308 -> missing -> read as "open below", so all three
* using rows matched an interval that mathematically contains none of them.
local ++TESTS
capture noisily {
    _rm155_master 8e307
    capture rangematch key 8e307 8e307 using "`U_extreme'", unmatched(none)
    assert _rc == 459
    * The caller must be untouched: no output columns, no dropped rows.
    assert _N == 1
    assert c(k) == 2
    confirm variable key mid
}
if _rc {
    local ++FAIL
    display as error "FAIL: T1 scalar-offset overflow on low aborts and preserves the caller"
}
else {
    local ++PASS
    display as result "PASS: T1 scalar-offset overflow on low aborts and preserves the caller"
}

**# T2: overflow on the UPPER bound alone also aborts
* The upper bound overflowing is harmless to the pair set (every representable
* using key is below the true bound either way), but a bound the command cannot
* represent is still a bound it cannot honour, and reporting it as open is a
* claim about data it never checked. Fail closed in both directions.
local ++TESTS
capture noisily {
    _rm155_master 8e307
    capture rangematch key -1 8e307 using "`U_extreme'", unmatched(none)
    assert _rc == 459
    assert _N == 1 & c(k) == 2
}
if _rc {
    local ++FAIL
    display as error "FAIL: T2 scalar-offset overflow on high aborts"
}
else {
    local ++PASS
    display as result "PASS: T2 scalar-offset overflow on high aborts"
}

**# T3: the binary backend is not exempt
* nearest() selects the binary backend, which does the same missing-to-infinity
* normalization in its own loop. The reproduction in the audit landed on sweep;
* this pins the other route.
local ++TESTS
capture noisily {
    _rm155_master 8e307
    capture rangematch key 8e307 8e307 using "`U_extreme'", nearest(both)
    assert _rc == 459
    assert _N == 1 & c(k) == 2
}
if _rc {
    local ++FAIL
    display as error "FAIL: T3 scalar-offset overflow aborts on the binary backend"
}
else {
    local ++PASS
    display as result "PASS: T3 scalar-offset overflow aborts on the binary backend"
}

**# T4: dryrun and count abort too, and create nothing
* dryrun/count report the counts the join WOULD produce. Reporting a count
* derived from an interval the command could not represent is the same defect
* wearing a different output route.
local ++TESTS
capture noisily {
    foreach opt in dryrun count {
        _rm155_master 8e307
        capture rangematch key 8e307 8e307 using "`U_extreme'", `opt'
        assert _rc == 459
        assert _N == 1 & c(k) == 2
    }
}
if _rc {
    local ++FAIL
    display as error "FAIL: T4 scalar-offset overflow aborts under dryrun and count"
}
else {
    local ++PASS
    display as result "PASS: T4 scalar-offset overflow aborts under dryrun and count"
}

**# T5: frame() and saving() routes abort without creating their output
local ++TESTS
capture noisily {
    capture frame drop v155_ovf
    _rm155_master 8e307
    capture rangematch key 8e307 8e307 using "`U_extreme'", frame(v155_ovf)
    assert _rc == 459
    capture frame drop v155_ovf
    assert _rc != 0

    tempfile ovf_out
    _rm155_master 8e307
    capture rangematch key 8e307 8e307 using "`U_extreme'", saving("`ovf_out'")
    assert _rc == 459
    capture confirm file "`ovf_out'.dta"
    assert _rc != 0
}
if _rc {
    local ++FAIL
    display as error "FAIL: T5 overflow abort creates no frame and no saved file"
}
else {
    local ++PASS
    display as result "PASS: T5 overflow abort creates no frame and no saved file"
}

**# T6: the negative direction is representable and must still match
* -8e307 + -8e307 = -1.6e308, which Stata keeps. Every using key is above it,
* so an open-below interval and the true interval give the same answer. A guard
* that rejected this would be a false positive on valid data.
local ++TESTS
capture noisily {
    _rm155_master -8e307
    rangematch key -8e307 8e307 using "`U_extreme'", unmatched(none) ///
        usingid(uobs)
    * The command ran uncaptured, so reaching here IS rc=0; `_rc' would only
    * report the last -capture-, not this line.
    * key + high = 0, so the interval is [-1.6e308, 0]: the two using keys at
    * or below zero match and 8e307 does not.
    assert _N == 2
    sort uobs
    assert uobs[1] == 1 & uobs[2] == 2
}
if _rc {
    local ++FAIL
    display as error "FAIL: T6 representable negative offsets still match"
}
else {
    local ++PASS
    display as result "PASS: T6 representable negative offsets still match"
}

**# T7: a master variable dangling on __rm_merge keeps its own (empty) meaning
* 1.5.4: the generate() allocator picked the first name `label list' failed on,
* which includes any name that is ATTACHED but undefined. It then defined the
* merge map there, and the master variable decoded as "master only".
local ++TESTS
capture noisily {
    tempfile U7
    clear
    set obs 1
    gen double key = 5
    save "`U7'"

    clear
    set obs 1
    gen double key = 5
    gen byte code = 1
    label values code __rm_merge
    rangematch key . . using "`U7'", generate(mrg)
    * The dangling attachment survives, and decoding still yields the number.
    assert "`: value label code'" == "__rm_merge"
    assert "`: label (code) 1'" == "1"
    * The merge map went somewhere else and still says what it should.
    assert "`: value label mrg'" != "__rm_merge"
    assert "`: label (mrg) 3'" == "matched"
}
if _rc {
    local ++FAIL
    display as error "FAIL: T7 generate() does not populate a dangling __rm_merge"
}
else {
    local ++PASS
    display as result "PASS: T7 generate() does not populate a dangling __rm_merge"
}

**# T8: dangling MASTER attachment, defined USING label of the same name
* 1.5.4: the using definition was created under the shared name because no
* definition existed yet, and the master variable inherited it.
local ++TESTS
capture noisily {
    tempfile U8
    clear
    set obs 1
    gen double key = 5
    gen byte flag = 1
    label define v155_foo 1 "using-one"
    label values flag v155_foo
    save "`U8'"

    clear
    set obs 1
    gen double key = 5
    gen byte code = 1
    label values code v155_foo
    rangematch key . . using "`U8'", keepusing(flag)
    assert "`: label (code) 1'" == "1"
    assert "`: label (flag) 1'" == "using-one"
    assert "`: value label code'" != "`: value label flag'"
}
if _rc {
    local ++FAIL
    display as error "FAIL: T8 dangling master attachment does not inherit the using map"
}
else {
    local ++PASS
    display as result "PASS: T8 dangling master attachment does not inherit the using map"
}

**# T9: the reverse -- defined MASTER label, dangling USING attachment
local ++TESTS
capture noisily {
    tempfile U9
    clear
    set obs 1
    gen double key = 5
    gen byte flag = 1
    label values flag v155_bar
    save "`U9'"

    clear
    set obs 1
    gen double key = 5
    gen byte code = 1
    label define v155_bar 1 "master-one"
    label values code v155_bar
    rangematch key . . using "`U9'", keepusing(flag)
    assert "`: label (code) 1'" == "master-one"
    assert "`: label (flag) 1'" == "1"
    assert "`: value label code'" != "`: value label flag'"
}
if _rc {
    local ++FAIL
    display as error "FAIL: T9 dangling using attachment does not inherit the master map"
}
else {
    local ++PASS
    display as result "PASS: T9 dangling using attachment does not inherit the master map"
}

**# T10: the collision fix must not break the ordinary shared-label case
* Two variables carrying the SAME definition under the same name still share
* it -- renaming every colliding name would be its own regression.
local ++TESTS
capture noisily {
    tempfile U10
    clear
    set obs 2
    gen double key = _n
    gen byte ug = 1
    label define v155_shr 1 "one"
    label values ug v155_shr
    save "`U10'"

    clear
    set obs 1
    gen double key = 1
    gen byte mg = 1
    label define v155_shr 1 "one"
    label values mg v155_shr
    rangematch key . . using "`U10'", keepusing(ug)
    assert "`: value label mg'" == "v155_shr"
    assert "`: value label ug'" == "v155_shr"
    assert "`: label (mg) 1'" == "one" & "`: label (ug) 1'" == "one"

    * ... while genuinely different definitions still get renamed apart.
    tempfile U10b
    clear
    set obs 2
    gen double key = _n
    gen byte ug = 1
    label define v155_dif 1 "using-one"
    label values ug v155_dif
    save "`U10b'"

    clear
    set obs 1
    gen double key = 1
    gen byte mg = 1
    label define v155_dif 1 "master-one"
    label values mg v155_dif
    rangematch key . . using "`U10b'", keepusing(ug)
    assert "`: label (mg) 1'" == "master-one"
    assert "`: label (ug) 1'" == "using-one"
}
if _rc {
    local ++FAIL
    display as error "FAIL: T10 identical maps still share, different maps still rename"
}
else {
    local ++PASS
    display as result "PASS: T10 identical maps still share, different maps still rename"
}

**# T11: the dangling-collision contract holds on the frame() and saving() routes
* The default route rebuilds the caller frame; frame() renames the output frame
* and saving() writes it. All three read their labels from the same output
* frame, so the fix has to hold in the frame the other two hand on.
local ++TESTS
capture noisily {
    tempfile U11 out11
    clear
    set obs 1
    gen double key = 5
    gen byte flag = 1
    label define v155_rt 1 "using-one"
    label values flag v155_rt
    save "`U11'"

    capture frame drop v155_frame
    clear
    set obs 1
    gen double key = 5
    gen byte code = 1
    label values code v155_rt
    rangematch key . . using "`U11'", keepusing(flag) frame(v155_frame)
    frame v155_frame {
        assert "`: label (code) 1'" == "1"
        assert "`: label (flag) 1'" == "using-one"
    }
    frame drop v155_frame

    clear
    set obs 1
    gen double key = 5
    gen byte code = 1
    label values code v155_rt
    rangematch key . . using "`U11'", keepusing(flag) saving("`out11'")
    use "`out11'", clear
    assert "`: label (code) 1'" == "1"
    assert "`: label (flag) 1'" == "using-one"
}
if _rc {
    local ++FAIL
    display as error "FAIL: T11 label collision contract holds on frame() and saving()"
}
else {
    local ++PASS
    display as result "PASS: T11 label collision contract holds on frame() and saving()"
}

**# T12: distance() aborts when a matched pair's gap is unrepresentable
* 1.5.4: the row was marked matched (mrg==3) while distance() held missing --
* the exact value the help reserves for an unmatched row.
local ++TESTS
capture noisily {
    tempfile U12
    clear
    set obs 1
    gen double key = 8e307
    save "`U12'"

    clear
    set obs 1
    gen double key = -8e307
    capture rangematch key . . using "`U12'", distance(delta) generate(mrg)
    assert _rc == 459
    assert _N == 1 & c(k) == 1
    capture confirm variable delta
    assert _rc != 0
    capture confirm variable mrg
    assert _rc != 0
}
if _rc {
    local ++FAIL
    display as error "FAIL: T12 unrepresentable distance aborts and creates nothing"
}
else {
    local ++PASS
    display as result "PASS: T12 unrepresentable distance aborts and creates nothing"
}

**# T13: ordinary and near-limit distances are unaffected
* The guard fires on unrepresentable gaps only. A large but representable gap,
* and a small ordinary one, must both still be reported.
local ++TESTS
capture noisily {
    tempfile U13
    clear
    set obs 3
    gen double key = cond(_n == 1, -1e307, cond(_n == 2, 0, 1e307))
    save "`U13'"

    clear
    set obs 1
    gen double key = 0
    rangematch key . . using "`U13'", distance(delta) usingid(uobs)
    assert _N == 3
    sort uobs
    assert delta[1] == -1e307 & delta[2] == 0 & delta[3] == 1e307
    assert !missing(delta[1]) & !missing(delta[3])

    clear
    set obs 3
    gen double key = _n
    tempfile U13b
    save "`U13b'"
    clear
    set obs 1
    gen double key = 2
    rangematch key -1 1 using "`U13b'", distance(delta) usingid(uobs)
    sort uobs
    assert delta[1] == -1 & delta[2] == 0 & delta[3] == 1
}
if _rc {
    local ++FAIL
    display as error "FAIL: T13 representable distances still reported"
}
else {
    local ++PASS
    display as result "PASS: T13 representable distances still reported"
}

**# T14: a missing _rangematch_mata.ado aborts with r(111)
* The handshake is the only thing standing between a partial install and a
* command that silently resolves half its backend. Driving it needs a real ado
* tree with the helper absent, so PLUS and PERSONAL are pointed at empty
* directories for the duration and restored unconditionally afterwards --
* including on failure, which is why the probe runs inside its own capture.
local ++TESTS
capture noisily {
    local old_plus "`c(sysdir_plus)'"
    local old_personal "`c(sysdir_personal)'"
    tempfile tok_probe
    mata: st_local("tok", subinstr(pathbasename(st_local("tok_probe")), ".", "_"))
    local empty_dir "`c(tmpdir)'/rm155_empty_`tok'"
    local solo_dir  "`c(tmpdir)'/rm155_solo_`tok'"
    mkdir "`empty_dir'"
    mkdir "`solo_dir'"
    copy "`pkg_dir'/rangematch.ado" "`solo_dir'/rangematch.ado", replace

    clear all
    capture noisily {
        sysdir set PLUS "`empty_dir'"
        sysdir set PERSONAL "`empty_dir'"
        adopath ++ "`solo_dir'"
        clear
        set obs 1
        gen double key = 1
        gen double lo = 0
        gen double hi = 2
        tempfile U14
        save "`U14'"
        capture noisily rangematch key lo hi using "`U14'"
        local probe_rc = _rc
        * The caller's data must be exactly as it was.
        assert _N == 1 & c(k) == 3
        confirm variable key lo hi
    }
    local body_rc = _rc
    capture adopath - "`solo_dir'"
    sysdir set PLUS "`old_plus'"
    sysdir set PERSONAL "`old_personal'"
    capture erase "`solo_dir'/rangematch.ado"
    assert `body_rc' == 0
    assert `probe_rc' == 111
}
if _rc {
    local ++FAIL
    display as error "FAIL: T14 absent Mata helper aborts with r(111)"
}
else {
    local ++PASS
    display as result "PASS: T14 absent Mata helper aborts with r(111)"
}

**# T15: a STALE _rangematch_mata.ado aborts with r(111) rather than running
* An in-session user who updates the package keeps whatever backend is already
* loaded unless the version strings disagree. A helper that loads but reports
* the wrong version must be refused, not used.
local ++TESTS
capture noisily {
    tempfile tok_probe2
    mata: st_local("tok2", subinstr(pathbasename(st_local("tok_probe2")), ".", "_"))
    local stale_dir "`c(tmpdir)'/rm155_stale_`tok2'"
    mkdir "`stale_dir'"

    * Copy the shipped helper with its version function rewritten. Everything
    * else is byte-identical, so the only reason to refuse it is the version.
    tempname fin fout
    file open `fin' using "`pkg_dir'/_rangematch_mata.ado", read text
    file open `fout' using "`stale_dir'/_rangematch_mata.ado", write text replace
    file read `fin' mline
    while r(eof) == 0 {
        local outline `"`mline'"'
        if strpos(`"`mline'"', `"return(""') > 0 & ///
            strpos(`"`mline'"', `"."') > 0 & `"`stale_seen'"' == "" {
            local outline `"    return("0.0.0")"'
            local stale_seen "1"
        }
        file write `fout' `"`outline'"' _n
        file read `fin' mline
    }
    file close `fin'
    file close `fout'
    assert "`stale_seen'" == "1"

    clear all
    capture noisily {
        adopath ++ "`stale_dir'"
        clear
        set obs 1
        gen double key = 1
        gen double lo = 0
        gen double hi = 2
        tempfile U15
        save "`U15'"
        capture noisily rangematch key lo hi using "`U15'"
        local probe_rc = _rc
        assert _N == 1 & c(k) == 3
    }
    local body_rc = _rc
    capture adopath - "`stale_dir'"
    capture erase "`stale_dir'/_rangematch_mata.ado"
    assert `body_rc' == 0
    assert `probe_rc' == 111
}
if _rc {
    local ++FAIL
    display as error "FAIL: T15 stale Mata helper aborts with r(111)"
}
else {
    local ++PASS
    display as result "PASS: T15 stale Mata helper aborts with r(111)"
}

**# T16: leading and trailing whitespace in prefix()/suffix() is rejected
* `word count' sees only INTERNAL spaces and `confirm name' quietly ignores
* edge whitespace, so prefix(" p") passed both screens and built `px' -- the
* affix applied was not the affix typed.
local ++TESTS
capture noisily {
    tempfile U16
    clear
    set obs 2
    gen double key = _n
    gen double dup1 = 100 + _n
    save "`U16'"

    clear
    set obs 2
    gen double key = _n
    gen double lo = _n - .5
    gen double hi = _n + .5
    gen double dup1 = _n
    capture rangematch key lo hi using "`U16'", keepusing(dup1) prefix(" p")
    assert _rc == 198
    capture rangematch key lo hi using "`U16'", keepusing(dup1) suffix("s ")
    assert _rc == 198
    capture rangematch key lo hi using "`U16'", keepusing(dup1) prefix("p q")
    assert _rc == 198
    * An ordinary affix still works.
    rangematch key lo hi using "`U16'", keepusing(dup1) prefix(p)
    confirm variable pdup1
}
if _rc {
    local ++FAIL
    display as error "FAIL: T16 whitespace-padded affixes rejected"
}
else {
    local ++PASS
    display as result "PASS: T16 whitespace-padded affixes rejected"
}

**# T17: seed() accepts a full seed-state token, not only an integer
* The parser declares SEED(string) and passes the value straight to `set seed',
* which takes an integer OR a state token. The help advertised only seed(#), so
* the accepted grammar was wider than the documented one and nothing tested the
* wider half. Both forms must select reproducibly, and the caller's RNG state
* must come back either way.
local ++TESTS
capture noisily {
    tempfile U17
    clear
    set obs 6
    gen double key = 10
    gen long uid = _n
    save "`U17'"

    clear
    set obs 1
    gen double key = 10
    save "`U17'_m", replace

    * Integer seed: two runs agree.
    use "`U17'_m", clear
    rangematch key -1 1 using "`U17'", keepusing(uid) nearest(both) ///
        ties(random) seed(24601)
    local int_first = uid[1]
    use "`U17'_m", clear
    rangematch key -1 1 using "`U17'", keepusing(uid) nearest(both) ///
        ties(random) seed(24601)
    assert uid[1] == `int_first'

    * Seed-state token: accepted, and reproducible on its own terms.
    set seed 24601
    local state "`c(rngstate)'"
    use "`U17'_m", clear
    rangematch key -1 1 using "`U17'", keepusing(uid) nearest(both) ///
        ties(random) seed(`state')
    local tok_first = uid[1]
    use "`U17'_m", clear
    rangematch key -1 1 using "`U17'", keepusing(uid) nearest(both) ///
        ties(random) seed(`state')
    assert uid[1] == `tok_first'

    * A state captured immediately after `set seed 24601' is the same stream
    * position the integer form starts from, so both forms pick the same row.
    assert `tok_first' == `int_first'

    * The caller's stream is restored under both forms.
    set seed 13
    local before "`c(rngstate)'"
    use "`U17'_m", clear
    rangematch key -1 1 using "`U17'", keepusing(uid) nearest(both) ///
        ties(random) seed(`state')
    assert "`c(rngstate)'" == "`before'"
}
if _rc {
    local ++FAIL
    display as error "FAIL: T17 seed() accepts integer and seed-state forms"
}
else {
    local ++PASS
    display as result "PASS: T17 seed() accepts integer and seed-state forms"
}

display "RESULT: test_rangematch_v155 tests=`TESTS' pass=`PASS' fail=`FAIL'"
if `FAIL' > 0 exit 1
