* validation_public_examples.do - hand-computed public-example known answers
*
* Pins exact results for the simple and grouped examples in the official
* data.table::foverlaps documentation and a deterministic subset of the
* official survival::neardate closest-laboratory-date example.
clear all
version 16.1
set varabbrev off

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# data.table simple overlap example
* Public x intervals: [5,8], [31,50], [22,25], [16,18].
* Public y intervals: [10,15], [20,35], [30,45].
* Inclusive matches are exactly (x2,y2), (x2,y3), and (x3,y2).
local ++test_count
capture noisily {
    tempfile simple_using
    clear
    input byte uid double(ystart yend)
    1 10 15
    2 20 35
    3 30 45
    end
    save "`simple_using'", replace

    clear
    input byte mid double(start end)
    1  5  8
    2 31 50
    3 22 25
    4 16 18
    end
    rangematch start end using "`simple_using'", ///
        overlap(ystart yend) keepusing(uid) unmatched(master) ///
        generate(match_status) stats
    assert r(N_matched_pairs) == 3
    assert r(N_unmatched_master) == 2
    assert r(N_pairs) == 5
    sort mid uid
    assert mid[1] == 1 & missing(uid[1]) & match_status[1] == 1
    assert mid[2] == 2 & uid[2] == 2 & match_status[2] == 3
    assert mid[3] == 2 & uid[3] == 3 & match_status[3] == 3
    assert mid[4] == 3 & uid[4] == 2 & match_status[4] == 3
    assert mid[5] == 4 & missing(uid[5]) & match_status[5] == 1
}
if _rc == 0 {
    display as result "PASS: official data.table simple example known answer"
    local ++pass_count
}
else {
    display as error "FAIL: official data.table simple example"
    local ++fail_count
    local failed_tests "`failed_tests' simple_overlap"
}

**# data.table grouped genomics example
* Chr1 [10,20] overlaps gene b [15,18]; Chr2 [1,4], [25,52], and
* [50,60] each overlap gene c [1,55]. Chr1 [5,11] matches no gene.
local ++test_count
capture noisily {
    tempfile genomic_using
    clear
    input str4 chr byte uid double(ystart yend) str1 geneid
    "Chr1" 1 1  4 "a"
    "Chr1" 2 15 18 "b"
    "Chr2" 3 1 55 "c"
    end
    save "`genomic_using'", replace

    clear
    input byte mid str4 chr double(start end)
    1 "Chr1"  5 11
    2 "Chr1" 10 20
    3 "Chr2"  1  4
    4 "Chr2" 25 52
    5 "Chr2" 50 60
    end
    rangematch start end using "`genomic_using'", ///
        overlap(ystart yend) by(chr) keepusing(uid geneid) ///
        unmatched(master) generate(match_status) stats
    assert r(N_matched_pairs) == 4
    assert r(N_unmatched_master) == 1
    assert r(N_pairs) == 5
    sort mid uid
    assert mid[1] == 1 & missing(uid[1]) & geneid[1] == ""
    assert mid[2] == 2 & uid[2] == 2 & geneid[2] == "b"
    assert mid[3] == 3 & uid[3] == 3 & geneid[3] == "c"
    assert mid[4] == 4 & uid[4] == 3 & geneid[4] == "c"
    assert mid[5] == 5 & uid[5] == 3 & geneid[5] == "c"
}
if _rc == 0 {
    display as result "PASS: official data.table grouped example known answer"
    local ++pass_count
}
else {
    display as error "FAIL: official data.table grouped example"
    local ++fail_count
    local failed_tests "`failed_tests' grouped_overlap"
}

**# survival::neardate example subset
* Subject 1 index Jan 5: prior Jan 1 (u1), after Apr 1 (u2).
* Subject 2 index Feb 5: prior Jan 1 (u4), after Mar 1 (u5).
* Subject 3 has no reference observation and remains unmatched.
local ++test_count
capture noisily {
    tempfile date_master date_using
    clear
    input byte master_id byte id str10 date_s
    1 1 "2011-01-05"
    2 2 "2011-02-05"
    3 3 "2011-03-05"
    end
    generate double event_key = daily(date_s, "YMD")
    format event_key %td
    drop date_s
    save "`date_master'", replace

    clear
    input byte using_id byte id str10 date_s
    1 1 "2011-01-01"
    2 1 "2011-04-01"
    3 1 "2011-05-01"
    4 2 "2011-01-01"
    5 2 "2011-03-01"
    end
    generate double event_key = daily(date_s, "YMD")
    format event_key %td
    drop date_s
    save "`date_using'", replace

    use "`date_master'", clear
    rangematch event_key 0 . using "`date_using'", by(id) ///
        nearest(after) ties(first) keepusing(using_id) unmatched(master)
    sort master_id
    assert _N == 3
    assert master_id[1] == 1 & using_id[1] == 2
    assert master_id[2] == 2 & using_id[2] == 5
    assert master_id[3] == 3 & missing(using_id[3])

    use "`date_master'", clear
    rangematch event_key . 0 using "`date_using'", by(id) ///
        nearest(before) ties(first) keepusing(using_id) unmatched(master)
    sort master_id
    assert _N == 3
    assert master_id[1] == 1 & using_id[1] == 1
    assert master_id[2] == 2 & using_id[2] == 4
    assert master_id[3] == 3 & missing(using_id[3])
}
if _rc == 0 {
    display as result "PASS: official survival::neardate subset known answer"
    local ++pass_count
}
else {
    display as error "FAIL: official survival::neardate subset"
    local ++fail_count
    local failed_tests "`failed_tests' neardate"
}

**# Summary
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
}
else {
    display as result "ALL PUBLIC-EXAMPLE KNOWN ANSWERS PASSED"
}
display "RESULT: validation_public_examples tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
