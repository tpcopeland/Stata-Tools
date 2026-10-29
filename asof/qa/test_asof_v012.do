*! test_asof_v012.do - Date-format justification, caller state, sinks, labels, and key types
*! Author: Timothy P Copeland, Karolinska Institutet
*! Requires: Stata 16.0+
clear all
set processors 1
set varabbrev off
version 16.0
capture log close _all
log using "test_asof_v012.log", replace text nomsg
global ASOF_QA_STATUS "fail"
do "_asof_qa_common.do"
quietly _asof_qa_bootstrap
local qa_dir "`r(qa_dir)'"
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_parity.do"
local test_count = 0
local pass_count = 0
local fail_count = 0

**# Left-justified and centered %td/%tc formats keep their units at every site
* A %-tc or %~tc misread as daily turns window(-10 0) into -10 milliseconds and
* the reported gap into milliseconds; the 5-day-old record must still be chosen.
foreach flag in - ~ {
    foreach unit in daily clock {
        foreach site in none using master lower upper all {
            local ++test_count
            capture noisily {
                local fmt = cond("`unit'" == "clock", "tc", "td")
                local scale = cond("`unit'" == "clock", 86400000, 1)
                if "`unit'" == "clock" local base = clock("01jan2020 12:00:00", "DMYhms")
                else local base = mdy(1, 1, 2020)
                tempfile events
                clear
                set obs 3
                generate long id = 1
                generate double off = cond(_n == 1, -20, cond(_n == 2, -5, 3))
                generate double value = abs(off)
                generate double visit = `base' + off * `scale'
                drop off
                format visit %`fmt'
                if inlist("`site'", "using", "all") format visit %`flag'`fmt'
                save `events'
                clear
                set obs 1
                generate long id = 1
                generate double anchor = `base'
                generate double lower = `base' - 30 * `scale'
                generate double upper = `base' + 30 * `scale'
                format anchor lower upper %`fmt'
                if inlist("`site'", "master", "all") format anchor %`flag'`fmt'
                if inlist("`site'", "lower", "all") format lower %`flag'`fmt'
                if inlist("`site'", "upper", "all") format upper %`flag'`fmt'
                asof value using `events', id(id) date(visit) anchor(anchor) ///
                    range(lower upper) direction(onorbefore) select(last) ///
                    window(-10 0) generate(got) datename(gotdate) gapname(gap) nowarn
                assert r(N_matched) == 1
                assert r(gap_min) == -5 & r(gap_max) == -5
                assert got == 5
                assert gap == -5
                assert gotdate == `base' - 5 * `scale'
            }
            if _rc == 0 local ++pass_count
            else {
                local ++fail_count
                display as error "FAIL: justified format flag=`flag' unit=`unit' site=`site'"
            }
        }
    }
}

**# Justified %tC and %tm are refused by the format check, without side effects
* The message is pinned: a unit-mismatch 109 between a misread site and a
* correctly read one must not satisfy these cells.
foreach flag in - ~ {
    foreach bad in tC tm {
        foreach site in using master lower upper all {
            local ++test_count
            capture noisily {
                local good = cond("`bad'" == "tC", "tc", "td")
                if "`bad'" == "tC" local base = clock("01jan2020 00:00:00", "DMYhms")
                else local base = 720
                tempfile events transcript
                clear
                set obs 1
                generate long id = 1
                generate double visit = `base'
                generate double value = 9
                format visit %`good'
                if inlist("`site'", "using", "all") format visit %`flag'`bad'
                save `events'
                clear
                set obs 1
                generate long id = 1
                generate double anchor = `base'
                generate double lower = `base'
                generate double upper = `base'
                format anchor lower upper %`good'
                if inlist("`site'", "master", "all") format anchor %`flag'`bad'
                if inlist("`site'", "lower", "all") format lower %`flag'`bad'
                if inlist("`site'", "upper", "all") format upper %`flag'`bad'
                qa_state_snapshot, tag(refused)
                tempname output fh
                log using `transcript', name(`output') text replace nomsg
                capture noisily asof value using `events', id(id) date(visit) ///
                    anchor(anchor) range(lower upper) direction(both) ///
                    select(nearest) generate(got)
                assert _rc == 109
                log close `output'
                qa_state_compare, tag(refused)
                confirm new variable got
                local format_message = 0
                file open `fh' using `transcript', read text
                file read `fh' line
                while r(eof) == 0 {
                    if strpos(`"`line'"', "must use daily dates or %tc datetimes") local format_message = 1
                    file read `fh' line
                }
                file close `fh'
                assert `format_message' == 1
            }
            if _rc == 0 local ++pass_count
            else {
                local ++fail_count
                capture log close `output'
                display as error "FAIL: refused format flag=`flag' bad=`bad' site=`site'"
            }
        }
    }
}

**# Caller state survives early, mid, and late failures with planted objects
* Planted names mirror internal ones: asof_matchdate/asof_gapdays/asof_matched
* in the master, asof_event1/asof_result1 in the using data, plus a user
* scalar, matrix, global, frame, active estimates, sort order and varabbrev.
tempfile planted_events planted_master
clear
input long id double(visit value asof_event1 asof_result1)
1 90 9 1 1
1 110 11 1 1
end
save `planted_events'
clear
input long id double(anchor asof_matchdate asof_gapdays asof_matched) str2 got
1 100 5 6 7 "x"
2 100 5 6 7 "y"
end
save `planted_master'
foreach path in syntax noframe ties typeclash {
    local ++test_count
    capture noisily {
        local events "`planted_events'"
        use `planted_master', clear
        regress asof_gapdays asof_matchdate
        scalar N_master = 42
        matrix stats = (1, 2)
        global ASOF_USER_GLOBAL "keep"
        capture frame drop asof_user_frame
        frame create asof_user_frame
        gsort -id
        set varabbrev on
        local opts "direction(both) select(nearest) generate(got) replace"
        if "`path'" == "syntax" local opts "direction(sideways) select(nearest) generate(got) replace"
        if "`path'" == "noframe" local opts "`opts' frame(asof_no_such_frame)"
        if "`path'" == "ties" local opts "direction(both) select(nearest) ties(error) generate(got) replace"
        local expected_rc = cond("`path'" == "syntax", 198, ///
            cond("`path'" == "noframe", 111, cond("`path'" == "ties", 459, 109)))
        qa_state_snapshot, tag(errorpath) rreturn
        capture noisily asof value using `events', id(id) date(visit) ///
            anchor(anchor) `opts'
        local call_rc = _rc
        assert `call_rc' == `expected_rc'
        * asof is rclass: a failed call may clear r(); nothing else may change.
        qa_state_compare, tag(errorpath) allow(r)
        assert c(varabbrev) == "on"
        set varabbrev off
        frame drop asof_user_frame
        macro drop ASOF_USER_GLOBAL
    }
    if _rc == 0 local ++pass_count
    else {
        local ++fail_count
        display as error "FAIL: caller state on `path' failure"
        set varabbrev off
        capture frame drop asof_user_frame
    }
}

**# Successful call with planted objects changes only documented outputs
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double(visit value asof_event1 asof_result1 asof_matchdate)
    1 90 9 1 1 1
    1 110 11 1 1 1
    end
    save `events'
    clear
    input long id double(anchor asof_matchdate asof_gapdays asof_matched)
    1 100 5 6 7
    2 100 5 6 7
    end
    regress asof_gapdays asof_matchdate
    scalar N_master = 42
    matrix stats = (1, 2)
    capture frame drop asof_user_frame
    frame create asof_user_frame
    gsort -id
    qa_state_snapshot, tag(success)
    asof value asof_event1 using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(got evgot) nowarn
    * The help file documents new output variables; r() is not fingerprinted.
    qa_state_compare, tag(success) allow(data)
    assert got == cond(id == 1, 9, .)
    assert evgot == cond(id == 1, 1, .)
    assert asof_matchdate == 5 & asof_gapdays == 6 & asof_matched == 7
    frame drop asof_user_frame
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    capture frame drop asof_user_frame
}

**# Reserved output names fail before any user variable is created
* confirm new variable accepts _N, _b, in and _all; creation then fails. Each
* name sits after a valid one, so a late failure would strand the first output.
tempfile reserved_events reserved_master
clear
input long id double(visit v w)
1 90 1 2
end
save `reserved_events'
clear
input long id double anchor
1 100
2 100
end
save `reserved_master'
local reserved_cases `""generate(good _N)" "generate(good in)" "generate(good _all)" "generate(good _b)" "generate(good good2) gapname(_n)" "generate(good good2) datename(if)" "generate(good good2) matchname(_pi)""'
foreach case of local reserved_cases {
    local ++test_count
    capture noisily {
        use `reserved_master', clear
        qa_state_snapshot, tag(reserved)
        capture noisily asof v w using `reserved_events', id(id) date(visit) ///
            anchor(anchor) direction(before) select(last) `case'
        assert _rc == 198
        qa_state_compare, tag(reserved)
        assert c(k) == 2
        confirm new variable good
    }
    if _rc == 0 local ++pass_count
    else {
        local ++fail_count
        display as error "FAIL: reserved output name `case'"
    }
}

**# Match counts agree across r(), the coverage report, the warning, and data
* Design: ids 1-3 match; id 4 is absent from the using data; id 5's only
* record is outside the window; one row has a missing anchor.
tempfile sink_events sink_master
clear
input long id double(visit value)
1 98 1
2 101 2
3 100 3
5 50 5
end
save `sink_events'
clear
input long id double anchor
1 100
2 100
3 100
4 100
5 100
6 .
end
save `sink_master'
foreach mode in noisily default {
    local ++test_count
    capture noisily {
        tempfile transcript
        local events "`sink_events'"
        use `sink_master', clear
        local opts = cond("`mode'" == "noisily", "noisily", "")
        tempname output nm nu
        log using `transcript', name(`output') text replace nomsg
        asof value using `events', id(id) date(visit) anchor(anchor) ///
            direction(both) select(nearest) window(-10 10) ///
            generate(got) matchname(found) `opts'
        scalar `nm' = r(N_matched)
        scalar `nu' = r(N_unmatched)
        log close `output'
        quietly count if found == 1
        assert r(N) == 3
        quietly count if found == 0
        assert r(N) == 2
        if "`mode'" == "noisily" {
            qa_surface_parity, expect(3) name(N_matched) result(`nm') ///
                log(`transcript') logregex("^ +matched: +([0-9,]+)")
            qa_surface_parity, expect(2) name(N_unmatched) result(`nu') ///
                log(`transcript') logregex("^ +unmatched: +([0-9,]+)")
        }
        else {
            qa_surface_parity, expect(2) name(N_unmatched) result(`nu') ///
                log(`transcript') ///
                logregex("^\(([0-9]+) master observations had no eligible")
        }
    }
    if _rc == 0 local ++pass_count
    else local ++fail_count
}

**# Zero-length window(0 0) admits only the exact-anchor record
tempfile zero_events zero_master
clear
input long id double(visit value)
1 99 1
1 100 2
1 101 3
2 99 4
2 101 5
end
save `zero_events'
clear
input long id double anchor
1 100
2 100
end
save `zero_master'
foreach direction in before onorbefore after onorafter both {
    local ++test_count
    capture noisily {
        local events "`zero_events'"
        use `zero_master', clear
        asof value using `events', id(id) date(visit) anchor(anchor) ///
            direction(`direction') select(nearest) window(0 0) ///
            generate(got) nowarn
        if inlist("`direction'", "before", "after") {
            assert missing(got)
            assert r(N_matched) == 0
        }
        else {
            assert got == cond(id == 1, 2, .)
            assert r(N_matched) == 1
            assert r(N_eligible) == 1
        }
    }
    if _rc == 0 local ++pass_count
    else {
        local ++fail_count
        display as error "FAIL: window(0 0) direction(`direction')"
    }
}

**# strL identifiers match on either or both sides
tempfile strl_events strl_master
clear
input str12 sid double(visit value)
"alpha" 90 1
"beta" 90 2
"alpha-long" 90 3
end
save `strl_events'
clear
input str12 sid double anchor
"alpha-long" 100
"beta" 100
"alpha" 100
"gamma" 100
end
save `strl_master'
foreach pair in strL_strL str_strL strL_str {
    local ++test_count
    capture noisily {
        gettoken mtype utype : pair, parse("_")
        local utype = subinstr("`utype'", "_", "", 1)
        tempfile events
        use `strl_events', clear
        if "`utype'" == "strL" recast strL sid
        confirm `=cond("`utype'" == "strL", "strL", "str12")' variable sid
        save `events'
        use `strl_master', clear
        if "`mtype'" == "strL" recast strL sid
        confirm `=cond("`mtype'" == "strL", "strL", "str12")' variable sid
        asof value using `events', id(sid) date(visit) anchor(anchor) ///
            direction(before) select(last) generate(got) nowarn
        assert got[1] == 3 & got[2] == 2 & got[3] == 1 & missing(got[4])
        assert r(N_matched) == 3
    }
    if _rc == 0 local ++pass_count
    else {
        local ++fail_count
        display as error "FAIL: identifier storage `pair'"
    }
}

**# Case, Unicode, whitespace and digit-string identifiers keep their own rows
* The Mata scan walks keys in Stata sort order; any disagreement between
* Stata's byte order and Mata's string comparison would cross-assign values.
local ++test_count
capture noisily {
    tempfile events
    clear
    input str12 sid double(visit value)
    "Z" 90 1
    "a" 90 2
    "é" 90 3
    "B" 90 4
    "b " 90 5
    "b" 90 6
    "Å" 90 7
    "ä" 90 8
    "10" 90 9
    "9" 90 10
    "-1" 90 11
    end
    save `events'
    clear
    input str12 sid double(anchor expected)
    "ä" 100 8
    "9" 100 10
    "b" 100 6
    "Å" 100 7
    "Z" 100 1
    "-1" 100 11
    "B" 100 4
    "b " 100 5
    "10" 100 9
    "é" 100 3
    "a" 100 2
    end
    asof value using `events', id(sid) date(visit) anchor(anchor) ///
        direction(before) select(last) generate(got)
    assert got == expected
    assert r(N_matched) == 11
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# matastrict on with a cleared Mata library compiles and is preserved
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double(visit value)
    1 90 9
    end
    save `events'
    clear
    input long id double anchor
    1 100
    end
    mata: mata clear
    set matastrict on
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(before) select(last) generate(got)
    local strict_after "`c(matastrict)'"
    set matastrict off
    assert "`strict_after'" == "on"
    assert got == 9
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    set matastrict off
}

**# Carrying _all includes the identifier and date variables themselves
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double(visit value)
    1 90 9
    1 95 10
    2 80 8
    end
    save `events'
    clear
    input long id double anchor
    2 100
    1 100
    end
    asof _all using `events', id(id) date(visit) anchor(anchor) ///
        direction(before) select(last)
    assert "`r(varlist)'" == "id visit value"
    assert "`r(generate)'" == "id_asof visit_asof value_asof"
    assert id_asof == id
    assert visit_asof == cond(id == 1, 95, 80)
    assert value_asof == cond(id == 1, 10, 8)
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# New outputs keep carried labels; datename keeps the using date format
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit byte grade str3 code
    1 90 2 "abc"
    end
    label define grade_lbl 2 "two"
    label values grade grade_lbl
    label variable grade "Grade at visit"
    label variable code "Visit code"
    format visit %tdCCYY-NN-DD
    save `events'
    clear
    input long id double anchor
    1 100
    end
    format anchor %td
    asof grade code using `events', id(id) date(visit) anchor(anchor) ///
        direction(before) select(last) datename(seen) gapname(gap) ///
        matchname(found)
    assert "`: value label grade_asof'" == "grade_lbl"
    assert "`: label grade_lbl 2'" == "two"
    assert "`: variable label grade_asof'" == "Grade at visit"
    assert "`: variable label code_asof'" == "Visit code"
    assert "`: format seen'" == "%tdCCYY-NN-DD"
    assert seen == 90 & gap == -10 & found == 1 & code_asof == "abc"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# replace stores full values in narrower existing outputs
* A str3 destination must hold a 7-character value, a float destination an
* integer float cannot represent, and rows outside if/in keep their values.
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double(visit big) str7 code
    1 90 16777217 "abcdefg"
    2 90 16777219 "hijklmn"
    3 90 1 "zzzzzzz"
    end
    save `events'
    clear
    input long id double anchor str3 code_out float big_out byte found
    1 100 "old" 1 9
    2 100 "old" 2 9
    3 100 "out" 3 9
    4 100 "old" 4 9
    end
    asof big code using `events' if id != 3, id(id) date(visit) ///
        anchor(anchor) direction(before) select(last) ///
        generate(big_out code_out) matchname(found) replace nowarn
    assert code_out[1] == "abcdefg" & code_out[2] == "hijklmn"
    assert big_out[1] == 16777217 & big_out[2] == 16777219
    assert code_out[3] == "out" & big_out[3] == 3 & found[3] == 9
    assert code_out[4] == "" & missing(big_out[4]) & found[4] == 0
    assert found[1] == 1 & found[2] == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# replace attaches the carried value and variable labels
* The matastrict test above ran mata clear; reload the state helpers' Mata.
quietly do "`qa_dir'/_qa_state.do"
* Existing outputs: unlabeled, labeled with a conflicting coding, and labeled
* when the carried variable has no value label. Every row is updated, so the
* carried label must replace whatever was attached before.
tempfile lab_events lab_plain_events lab_master
clear
input long id double visit byte(grade score)
1 90 2 7
2 90 1 8
end
label define grade_lbl 1 "mild" 2 "moderate"
label values grade grade_lbl
label variable grade "Grade at visit"
label variable visit "Visit date"
save `lab_events'
clear
input long id double anchor byte(grade_asof score_asof seen)
1 100 9 9 9
2 100 9 9 9
end
label variable grade_asof "stale grade"
label variable score_asof "stale score"
label variable seen "stale date"
save `lab_master'
local ++test_count
capture noisily {
    use `lab_master', clear
    label define score_lbl 7 "seven"
    label values score_asof score_lbl
    asof grade score using `lab_events', id(id) date(visit) anchor(anchor) ///
        direction(before) select(last) datename(seen) replace nowarn
    assert "`: value label grade_asof'" == "grade_lbl"
    assert "`: label (grade_asof) 2'" == "moderate"
    assert "`: variable label grade_asof'" == "Grade at visit"
    assert grade_asof[1] == 2 & grade_asof[2] == 1
    * The carried score has no value label, so the stale one is removed.
    assert "`: value label score_asof'" == ""
    assert "`: variable label score_asof'" == ""
    assert "`: variable label seen'" == "Visit date"
    assert seen == 90
}
if _rc == 0 local ++pass_count
else local ++fail_count

local ++test_count
capture noisily {
    use `lab_master', clear
    label define old_lbl 1 "none" 2 "severe" 9 "not yet"
    label values grade_asof old_lbl
    asof grade using `lab_events', id(id) date(visit) anchor(anchor) ///
        direction(before) select(last) replace nowarn
    assert "`: value label grade_asof'" == "grade_lbl"
    assert "`: label (grade_asof) 2'" == "moderate"
    * The user's own label set is kept, only detached.
    assert "`: label old_lbl 2'" == "severe"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# replace refuses to mix two codings in one output
* Rows outside the update keep old values. When those values carry a
* different value label (or none) than the carried one, no label fits every
* row: refuse before anything changes, extended missing codes included.
* A retained row holding only system missing has no coding to protect.
tempfile mix_master
clear
input long id double anchor byte grade_asof
1 100 1
2 100 9
3 100 .
end
label define old_lbl 1 "none" 2 "severe" 9 "not yet"
label values grade_asof old_lbl
save `mix_master'
local mix_cases `""old_lbl id != 2" "old_lbl_ext id != 2" "none id != 2" "old_lbl id != 3" "same id != 2""'
foreach case of local mix_cases {
    local ++test_count
    capture noisily {
        gettoken kind ifexp : case
        use `mix_master', clear
        if "`kind'" == "old_lbl_ext" replace grade_asof = .a in 2
        if "`kind'" == "none" label values grade_asof
        if "`kind'" == "same" {
            label define grade_lbl 1 "mild" 2 "moderate"
            label values grade_asof grade_lbl
        }
        local refuse = inlist("`kind'", "old_lbl", "old_lbl_ext", "none") ///
            & "`ifexp'" == " id != 2"
        qa_state_snapshot, tag(mix)
        capture noisily asof grade using `lab_events' if `ifexp', id(id) ///
            date(visit) anchor(anchor) direction(before) select(last) ///
            replace nowarn
        if `refuse' {
            assert _rc == 109
            qa_state_compare, tag(mix) allow(r)
        }
        else {
            assert _rc == 0
            assert "`: value label grade_asof'" == "grade_lbl"
            assert grade_asof[1] == 2
        }
    }
    if _rc == 0 local ++pass_count
    else {
        local ++fail_count
        display as error "FAIL: replace label mix `case'"
    }
}

**# A same-named master label with other contents is not the carried coding
* frget renames the carried set (grade_lbl1). An output labeled with the
* master's own grade_lbl therefore conflicts even though the names look alike.
local ++test_count
capture noisily {
    use `mix_master', clear
    label values grade_asof
    label drop old_lbl
    label define grade_lbl 1 "low" 2 "high" 9 "unknown"
    label values grade_asof grade_lbl
    qa_state_snapshot, tag(samename)
    capture noisily asof grade using `lab_events' if id != 2, id(id) ///
        date(visit) anchor(anchor) direction(before) select(last) ///
        replace nowarn
    assert _rc == 109
    qa_state_compare, tag(samename) allow(r)
    drop grade_asof
    asof grade using `lab_events', id(id) date(visit) anchor(anchor) ///
        direction(before) select(last) nowarn
    local newlab : value label grade_asof
    assert "`newlab'" != "grade_lbl" & "`newlab'" != ""
    assert "`: label (grade_asof) 2'" == "moderate"
    assert "`: label grade_lbl 2'" == "high"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Carried label sets do not leak into the master
* frget copies a carried variable's value-label set into the master. A failed
* call must leave none behind, and a date label nobody asked for must go too.
tempfile leak_events
clear
input long id double visit byte grade
1 90 2
end
label define grade_lbl 1 "mild" 2 "moderate"
label values grade grade_lbl
label define visit_lbl 90 "first visit"
label values visit visit_lbl
save `leak_events'
local ++test_count
capture noisily {
    clear
    input long id double anchor str3 grade_asof
    1 100 "abc"
    end
    qa_state_snapshot, tag(leakfail)
    capture noisily asof grade using `leak_events', id(id) date(visit) ///
        anchor(anchor) direction(before) select(last) replace nowarn
    assert _rc == 109
    qa_state_compare, tag(leakfail) allow(r)
    quietly label dir
    assert "`r(names)'" == ""
}
if _rc == 0 local ++pass_count
else local ++fail_count

local ++test_count
capture noisily {
    clear
    input long id double anchor
    1 100
    end
    asof grade using `leak_events', id(id) date(visit) anchor(anchor) ///
        direction(before) select(last) nowarn
    quietly label dir
    assert "`r(names)'" == "grade_lbl"
    drop grade_asof
    asof grade using `leak_events', id(id) date(visit) anchor(anchor) ///
        direction(before) select(last) datename(seen) nowarn
    assert "`: value label seen'" == "visit_lbl"
    assert "`: label (seen) 90'" == "first visit"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Retained-row refusal cells: datename, missing keys, unlabeled carry
* Each cell keeps one row outside the update with a nonmissing old value.
* datename uses a labeled using date; a missing anchor (no if) is a retained
* row too; a carried variable without a value label conflicts with a labeled
* output; two carried variables must each be compared with their own output.
tempfile cell_master
clear
input long id double anchor byte(grade_asof score_asof) double seen
1 100 1 1 50
2 100 9 9 50
3 . 9 9 50
end
save `cell_master'
local ++test_count
capture noisily {
    * datename attach: every keyed row is updated, the retained row is missing.
    use `cell_master', clear
    replace seen = . in 3
    asof grade using `leak_events', id(id) date(visit) anchor(anchor) ///
        direction(before) select(last) datename(seen) generate(g) replace nowarn
    assert "`: value label seen'" == "visit_lbl"
    assert seen[1] == 90 & missing(seen[2]) & missing(seen[3])
}
if _rc == 0 local ++pass_count
else local ++fail_count

local cell_cases "datename missingkey unlabeled pair_ok"
foreach case of local cell_cases {
    local ++test_count
    capture noisily {
        use `cell_master', clear
        label define old_lbl 1 "none" 2 "severe" 9 "not yet"
        local carry "grade"
        local opts "generate(grade_asof)"
        local using "`lab_events'"
        if "`case'" == "datename" {
            label define seen_lbl 50 "old date"
            label values seen seen_lbl
            local using "`leak_events'"
            local opts "generate(g) datename(seen)"
        }
        if "`case'" == "missingkey" label values grade_asof old_lbl
        if "`case'" == "unlabeled" {
            label values score_asof old_lbl
            local carry "score"
            local opts "generate(score_asof)"
        }
        if "`case'" == "pair_ok" {
            label define grade_lbl 1 "mild" 2 "moderate"
            label values grade_asof grade_lbl
            local carry "grade score"
            local opts "generate(grade_asof score_asof)"
        }
        qa_state_snapshot, tag(cell)
        capture noisily asof `carry' using `using', id(id) date(visit) ///
            anchor(anchor) direction(before) select(last) `opts' replace nowarn
        if "`case'" == "pair_ok" {
            assert _rc == 0
            assert "`: value label grade_asof'" == "grade_lbl"
            assert "`: value label score_asof'" == ""
            assert grade_asof[1] == 2 & score_asof[1] == 7
            assert grade_asof[3] == 9 & score_asof[3] == 9
        }
        else {
            assert _rc == 109
            qa_state_compare, tag(cell) allow(r)
        }
    }
    if _rc == 0 local ++pass_count
    else {
        local ++fail_count
        display as error "FAIL: retained-row cell `case'"
    }
}

**# A differently named label set with identical contents is the same coding
local ++test_count
capture noisily {
    use `mix_master', clear
    label values grade_asof
    label drop old_lbl
    label define aaa 1 "mild" 2 "moderate"
    label define zzz 1 "mild" 2 "moderate"
    label values grade_asof zzz
    replace grade_asof = 1 in 2
    asof grade using `lab_events' if id != 2, id(id) date(visit) ///
        anchor(anchor) direction(before) select(last) replace nowarn
    local lab : value label grade_asof
    assert "`: label (grade_asof) 2'" == "moderate"
    assert "`: label (grade_asof) 1'" == "mild"
    assert grade_asof[1] == 2 & grade_asof[2] == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Label languages: a replaced output matches a new output in every language
* The oracle is a fresh output built by clonevar on the same call, read in
* each language; a stale label in another language must refuse when retained
* rows hold values under it.
tempfile lang_master
clear
input long id double anchor byte grade_asof
1 100 1
2 100 9
end
label define old_en 1 "none" 9 "not yet"
label values grade_asof old_en
label variable grade_asof "old en"
label language fr, new
label define old_fr 1 "aucun" 9 "pas encore"
label values grade_asof old_fr
label variable grade_asof "old fr"
label language default
save `lang_master'
local ++test_count
capture noisily {
    use `lang_master', clear
    asof grade using `lab_events', id(id) date(visit) anchor(anchor) ///
        direction(before) select(last) generate(fresh) nowarn
    asof grade using `lab_events', id(id) date(visit) anchor(anchor) ///
        direction(before) select(last) replace nowarn
    assert "`: value label grade_asof'" == "grade_lbl"
    assert "`: variable label grade_asof'" == "Grade at visit"
    label language fr
    assert "`: value label grade_asof'" == "`: value label fresh'"
    assert "`: variable label grade_asof'" == "`: variable label fresh'"
    label language default
    quietly label language
    assert "`r(language)'" == "default"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    capture label language default
}

local ++test_count
capture noisily {
    use `lang_master', clear
    label language fr
    qa_state_snapshot, tag(lang)
    capture noisily asof grade using `lab_events' if id == 1, id(id) ///
        date(visit) anchor(anchor) direction(before) select(last) ///
        replace nowarn
    assert _rc == 109
    qa_state_compare, tag(lang) allow(r)
    quietly label language
    assert "`r(language)'" == "fr"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Near maxvar, a call either completes or changes nothing
* Sweep the free variable slots across the boundary where the outputs (or the
* carried copies) no longer fit. A failure must leave data and value-label
* sets untouched; both outcomes must occur.
local ++test_count
capture noisily {
    local orig_maxvar = c(maxvar)
    * set maxvar refuses while data, matrices or Mata are in memory; the
    * state helpers' Mata is reloaded afterwards.
    clear
    clear matrix
    clear mata
    set maxvar 2048
    quietly do "`qa_dir'/_qa_state.do"
    set obs 2
    generate long id = _n
    generate double anchor = 100
    forvalues j = 1/2040 {
        generate byte f`j' = 0
    }
    tempfile wide
    save `wide'
    local n_ok = 0
    local n_fail = 0
    forvalues drop = 0/16 {
        use `wide', clear
        if `drop' > 0 drop f1-f`drop'
        qa_state_snapshot, tag(wide)
        capture noisily asof grade score using `lab_events', id(id) ///
            date(visit) anchor(anchor) direction(before) select(last) ///
            datename(seen) gapname(gap) matchname(found) nowarn
        if _rc == 0 {
            local ++n_ok
            assert "`: value label grade_asof'" == "grade_lbl"
            assert grade_asof == cond(id == 1, 2, 1) & found == 1
        }
        else {
            local ++n_fail
            assert _rc == 900
            qa_state_compare, tag(wide) allow(r)
        }
    }
    assert `n_ok' >= 1 & `n_fail' >= 1
    clear
    clear matrix
    clear mata
    set maxvar `orig_maxvar'
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    clear
    clear matrix
    clear mata
    capture set maxvar 5000
}

**# frame() may name the current frame for a previous-record self-join
local ++test_count
capture noisily {
    clear
    input long id double(visit value)
    1 100 7
    1 110 8
    1 120 9
    2 100 4
    end
    datasignature
    local sig "`r(datasignature)'"
    asof value using default, frame(default) id(id) date(visit) ///
        anchor(visit) direction(before) select(last) generate(previous) nowarn
    assert previous == cond(id == 1 & visit == 110, 7, ///
        cond(id == 1 & visit == 120, 8, .))
    drop previous
    datasignature
    assert "`r(datasignature)'" == "`sig'"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# A failed call leaves no stale asof results in r()
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double(visit value)
    1 90 9
    end
    save `events'
    clear
    input long id double anchor
    1 100
    end
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(before) select(last) generate(first_got)
    assert r(N_master) == 1
    capture asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(before) select(last) ties(before) generate(second_got)
    assert _rc == 198
    assert missing(r(N_master)) & missing(r(N_matched))
    assert "`r(generate)'" == ""
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_asof_v012 tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
log close _all
