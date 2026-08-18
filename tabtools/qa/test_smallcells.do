*! test_smallcells.do  2026-08-11
*! Functional and sink-contract QA for table1_tc, smallcells()
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set processors 1
set varabbrev off
version 16.0

capture log close _smallcells
log using "test_smallcells.log", replace text name(_smallcells)

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# Bootstrap

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

capture program drop _sc_record
program define _sc_record
    args label rc passed failed
    if `rc' == 0 {
        display as result "  PASS: `label'"
        c_local pass_count = `passed' + 1
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        c_local fail_count = `failed' + 1
        c_local failed_tests "`failed_tests' `label'"
    }
end

capture program drop _sc_build_2x2
program define _sc_build_2x2
    version 16.0
    clear
    quietly set obs 4
    generate byte group = floor((_n - 1) / 2)
    generate byte category = mod(_n - 1, 2)
    generate int frequency = cond(_n == 1, 2, cond(_n == 2, 8, cond(_n == 3, 6, 4)))
    expand frequency
    drop frequency
end

**# Parsing and failure atomicity

local ++test_count
capture noisily {
    sysuse auto, clear
    foreach bad in 0 1 2 {
        capture noisily table1_tc foreign, by(foreign) smallcells(`bad')
        assert _rc == 198
    }
    capture noisily table1_tc foreign, by(foreign) smallcells(3.5)
    assert _rc == 198
    capture noisily table1_tc foreign, by(foreign) smallcells(nonnumeric)
    assert _rc == 198
}
_sc_record "invalid thresholds fail with rc 198" `=_rc' `pass_count' `fail_count'

local ++test_count
capture noisily {
    clear
    input byte(group category)
        0 0
        0 1
        0 2
        0 3
    end
    datasignature clear
    quietly datasignature set
    set varabbrev on
    capture frame drop sc_should_not_exist
    capture erase "`output_dir'/smallcells_uncertified.xlsx"
    capture noisily table1_tc category, by(group) smallcells(5) ///
        frame(sc_should_not_exist) xlsx("`output_dir'/smallcells_uncertified.xlsx")
    assert _rc == 498
    assert "`c(varabbrev)'" == "on"
    datasignature confirm
    capture confirm frame sc_should_not_exist
    assert _rc == 111
    capture confirm file "`output_dir'/smallcells_uncertified.xlsx"
    assert _rc == 601
}
_sc_record "uncertifiable marker bounds fail before every sink" `=_rc' `pass_count' `fail_count'

**# Public behavior and stored results

local ++test_count
capture noisily {
    _sc_build_2x2
    capture frame drop sc_basic
    table1_tc category, by(group) vars(category cat) total(after) ///
        test statistic smd smallcells(5) frame(sc_basic)

    assert r(smallcells) == 5
    assert r(N_primary_suppressed) == 2
    assert r(N_secondary_suppressed) == 2
    assert r(N_derived_suppressed) >= 2
    matrix _S = r(suppression)
    mata: st_numscalar("_sc_has_primary", any(st_matrix("_S") :== 1))
    mata: st_numscalar("_sc_has_secondary", any(st_matrix("_S") :== 2))
    mata: st_numscalar("_sc_has_derived", any(st_matrix("_S") :== 3))
    assert scalar(_sc_has_primary) == 1
    assert scalar(_sc_has_secondary) == 1
    assert scalar(_sc_has_derived) == 1

    matrix _T = r(table)
    mata: st_numscalar("_sc_has_d", any(st_matrix("_T") :== .d))
    assert scalar(_sc_has_d) == 1

    frame sc_basic {
        local threshold : char _dta[tabtools_smallcells]
        local codes : char _dta[tabtools_suppression_codes]
        local scope : char _dta[tabtools_suppression_scope]
        assert "`threshold'" == "5"
        assert strpos("`codes'", "1 primary") > 0
        assert strpos("`scope'", "single invocation") > 0
        capture ds _sc*
        assert _rc == 111
        ds factor, not
        local public_cells "`r(varlist)'"
        gen byte _has_primary = 0
        gen byte _has_secondary = 0
        gen byte _has_derived = 0
        foreach v of local public_cells {
            capture confirm string variable `v'
            if !_rc {
                replace _has_primary = 1 if strpos(`v', "<5") > 0
                replace _has_secondary = 1 if strpos(`v', "≥5") > 0
                replace _has_derived = 1 if `v' == "Suppressed"
            }
        }
        count if _has_primary
        assert r(N) >= 2
        count if _has_secondary
        assert r(N) >= 2
        count if _has_derived
        assert r(N) >= 1
    }
}
_sc_record "primary/complementary/derived masks and frame metadata" `=_rc' `pass_count' `fail_count'

local ++test_count
capture noisily {
    clear
    input byte group byte category int frequency
        0 1 1
        1 0 1
        1 1 4
    end
    expand frequency
    drop frequency
    capture frame drop sc_irredundant
    table1_tc category, by(group) vars(category cat) total(after) ///
        smallcells(5) frame(sc_irredundant)
    assert r(N_primary_suppressed) == 5
    assert r(N_secondary_suppressed) == 1
    frame sc_irredundant {
        local nsecondary = 0
        ds
        foreach v of varlist `r(varlist)' {
            capture confirm string variable `v'
            if !_rc {
                quietly count if strpos(`v', "≥5") > 0
                local nsecondary = `nsecondary' + r(N)
            }
        }
    }
    assert `nsecondary' == 1
}
_sc_record "redundant complementary margins are absent" `=_rc' `pass_count' `fail_count'
capture frame drop sc_irredundant

local ++test_count
capture noisily {
    _sc_build_2x2
    capture frame drop sc_legacy
    table1_tc category, by(group) vars(category cat) total(after) ///
        frame(sc_legacy)
    capture confirm scalar r(smallcells)
    assert _rc == 111
    frame sc_legacy {
        ds factor, not
        local public_cells "`r(varlist)'"
        gen byte _saw_two = 0
        gen byte _saw_four = 0
        gen byte _saw_marker = 0
        foreach v of local public_cells {
            capture confirm string variable `v'
            if !_rc {
                replace _saw_two = 1 if regexm(strtrim(`v'), "^2 ")
                replace _saw_four = 1 if regexm(strtrim(`v'), "^4 ")
                replace _saw_marker = 1 if strpos(`v', "<5") > 0 | strpos(`v', "≥5") > 0
            }
        }
        count if _saw_two
        assert r(N) == 1
        count if _saw_four
        assert r(N) == 1
        count if _saw_marker
        assert r(N) == 0
    }
}
_sc_record "omitted smallcells() preserves legacy rendered counts" `=_rc' `pass_count' `fail_count'

**# Continuous, missingness, and weight contracts

local ++test_count
capture noisily {
    clear
    input byte(group) double value byte category
        0 10 0
        0 12 1
        0 .  1
        0 .a 0
        1 20 0
        1 21 0
        1 22 0
        1 23 1
        1 24 1
        1 25 1
    end
    capture frame drop sc_cont
    table1_tc, by(group) vars(value contn \ category cat) ///
        missingsummary test statistic smd smallcells(5) frame(sc_cont)
    frame sc_cont {
        ds factor, not
        local public_cells "`r(varlist)'"
        gen byte _value_primary = 0
        gen byte _derived = 0
        foreach v of local public_cells {
            capture confirm string variable `v'
            if !_rc {
                replace _value_primary = 1 if factor == "value" & `v' == "<5"
                replace _derived = 1 if factor == "value" & `v' == "Suppressed"
            }
        }
        count if _value_primary
        assert r(N) == 1
        count if _derived
        assert r(N) >= 1
    }
}
_sc_record "continuous contributing N and dependent statistics are suppressed" `=_rc' `pass_count' `fail_count'

local ++test_count
capture noisily {
    clear
    input byte(group category) double wt long fw
        0 0 10 2
        0 1  1 6
        1 0  1 6
        1 1 10 4
    end
    expand 2
    replace fw = 1
    capture frame drop sc_wt
    table1_tc category, by(group) vars(category cat) wt(wt) wtn ///
        smallcells(5) frame(sc_wt)
    frame sc_wt {
        ds factor, not
        local public_cells "`r(varlist)'"
        gen byte _marker = 0
        foreach v of local public_cells {
            capture confirm string variable `v'
            if !_rc replace _marker = 1 if strpos(`v', "<5") > 0
        }
        count if _marker
        assert r(N) >= 2
    }

    clear
    input byte(group category) long fw
        0 0 2
        0 1 8
        1 0 6
        1 1 4
    end
    capture frame drop sc_fw
    table1_tc category [fweight=fw], by(group) vars(category cat) ///
        total(after) smallcells(5) frame(sc_fw)
    frame sc_fw {
        ds factor, not
        local public_cells "`r(varlist)'"
        gen byte _marker = 0
        foreach v of local public_cells {
            capture confirm string variable `v'
            if !_rc replace _marker = 1 if strpos(`v', "<5") > 0
        }
        count if _marker
        assert r(N) == 2
    }
}
_sc_record "wt() uses records and fweights use integer frequencies" `=_rc' `pass_count' `fail_count'

local ++test_count
capture noisily {
    clear
    input byte(group category) double wt int frequency
        0 0 1.0 2
        0 1 1.5 8
        0 . 0.8 1
        1 0 1.2 6
        1 1 0.9 4
        1 . 1.1 2
    end
    expand frequency
    drop frequency
    capture frame drop sc_composed
    table1_tc category, by(group) vars(category cat) wt(wt) wtcompare wtn ///
        total(after) slashN headerperc missingsummary smallcells(5) ///
        frame(sc_composed)
    frame sc_composed {
        ds factor, not
        local public_cells "`r(varlist)'"
        gen byte _saw_marker = 0
        gen byte _saw_raw_nonmissing_den = 0
        foreach v of local public_cells {
            capture confirm string variable `v'
            if !_rc {
                replace _saw_marker = 1 if strpos(`v', "<5") > 0 | ///
                    strpos(`v', "≥5") > 0 | `v' == "Suppressed"
                replace _saw_raw_nonmissing_den = 1 if strpos(`v', "/10") > 0
            }
        }
        count if _saw_marker
        assert r(N) >= 2
        count if _saw_raw_nonmissing_den
        assert r(N) == 0
        capture ds _sc*
        assert _rc == 111
    }
}
_sc_record "slashN/headerperc/missingsummary/wtcompare share protected denominators" `=_rc' `pass_count' `fail_count'

**# Sink parity and raw-leak attacks

local ++test_count
capture noisily {
    local xlsx "`output_dir'/smallcells_all_sinks.xlsx"
    local csv "`output_dir'/smallcells_all_sinks.csv"
    local md "`output_dir'/smallcells_all_sinks.md"
    capture erase "`xlsx'"
    capture erase "`csv'"
    capture erase "`md'"
    _sc_build_2x2
    capture frame drop sc_all
    table1_tc category, by(group) vars(category cat) total(after) ///
        test statistic smd smallcells(5) frame(sc_all) ///
        xlsx("`xlsx'") csv("`csv'") markdown("`md'") title("Synthetic small cells")

    assert r(smallcells) == 5
    assert r(N_primary_suppressed) > 0
    assert r(N_secondary_suppressed) > 0
    assert r(N_derived_suppressed) > 0
    matrix _S_all = r(suppression)
    mata: assert(any(st_matrix("_S_all") :== 1))
    mata: assert(any(st_matrix("_S_all") :== 2))
    mata: assert(any(st_matrix("_S_all") :== 3))

    foreach f in "`xlsx'" "`csv'" "`md'" {
        confirm file `f'
    }

    tempfile csvcopy mdcopy
    copy "`csv'" "`csvcopy'", replace
    copy "`md'" "`mdcopy'", replace
    foreach textfile in "`csvcopy'" "`mdcopy'" {
        tempname fh
        file open `fh' using `textfile', read text
        local saw_primary 0
        local saw_secondary 0
        local saw_raw 0
        file read `fh' line
        while r(eof) == 0 {
            if strpos(`"`line'"', "<5") > 0 local saw_primary 1
            if strpos(`"`line'"', "≥5") > 0 local saw_secondary 1
            if strpos(`"`line'"', "2 (20") > 0 | strpos(`"`line'"', "4 (40") > 0 local saw_raw 1
            file read `fh' line
        }
        file close `fh'
        assert `saw_primary' == 1
        assert `saw_secondary' == 1
        assert `saw_raw' == 0
    }

    import excel using "`xlsx'", sheet("Table 1") allstring clear
    ds
    local xvars "`r(varlist)'"
    gen byte _saw_primary = 0
    gen byte _saw_secondary = 0
    gen byte _saw_raw = 0
    foreach v of local xvars {
        capture confirm string variable `v'
        if !_rc {
            replace _saw_primary = 1 if strpos(`v', "<5") > 0
            replace _saw_secondary = 1 if strpos(`v', "≥5") > 0
            replace _saw_raw = 1 if strpos(`v', "2 (20") > 0 | strpos(`v', "4 (40") > 0
        }
    }
    count if _saw_primary
    assert r(N) >= 1
    count if _saw_secondary
    assert r(N) >= 1
    count if _saw_raw
    assert r(N) == 0
}
_sc_record "Excel/CSV/Markdown/frame share one redacted source" `=_rc' `pass_count' `fail_count'

local ++test_count
capture noisily {
    _sc_build_2x2
    capture noisily table1_tc category, by(group) vars(category cat) ///
        total(after) smallcells(5) ///
        xlsx("`output_dir'/missing_subdirectory/smallcells.xlsx")
    assert _rc != 0
    capture matrix list r(categorical)
    assert _rc != 0
    capture matrix list r(sample)
    assert _rc != 0
    capture matrix list r(continuous_n)
    assert _rc != 0
}
_sc_record "failed export strands no raw collector matrices" `=_rc' `pass_count' `fail_count'

**# Additional option compositions and state contracts

local ++test_count
capture noisily {
    clear
    input byte(group category) int frequency
        0 0 2
        0 1 8
        0 . 5
        1 0 6
        1 1 4
        1 . 5
    end
    expand frequency
    drop frequency
    * 1.15.0: this call used to carry `percent' as well. A percent-only display
    * publishes nothing BUT the percentage, and a published percentage releases
    * its own denominator, so a protected block has nothing left it can safely
    * show; the combination is refused now rather than shipped reconstructable.
    * Assert the refusal here, then exercise the remaining compositions.
    capture table1_tc category, by(group) vars(category cat) missing ///
        total(before) percent catrowperc smallcells(3) clear
    assert _rc == 198
    table1_tc category, by(group) vars(category cat) missing ///
        total(before) catrowperc smallcells(3) clear
    confirm variable factor
    ds factor, not
    local public_cells "`r(varlist)'"
    gen byte _marker = 0
    foreach v of local public_cells {
        capture confirm string variable `v'
        if !_rc replace _marker = 1 if strpos(`v', "<3") > 0 | strpos(`v', "≥3") > 0
    }
    count if _marker
    assert r(N) > 0

    clear
    set obs 6
    gen byte group = _n > 2
    gen double allmissing = .
    capture frame drop sc_allmissing
    table1_tc, by(group) vars(allmissing contn) missingsummary ///
        percent_n smallcells(3) frame(sc_allmissing)
    frame sc_allmissing {
        ds factor, not
        local public_cells "`r(varlist)'"
        gen byte _marker = 0
        foreach v of local public_cells {
            capture confirm string variable `v'
            if !_rc replace _marker = 1 if strpos(`v', "<3") > 0 | ///
                strpos(`v', "≥3") > 0 | `v' == "Suppressed"
        }
        count if _marker
        assert r(N) > 0
    }
}
_sc_record "smallcells(3), percent/catrowperc/missing/total-before/clear/all-missing paths" `=_rc' `pass_count' `fail_count'

local ++test_count
capture noisily {
    _sc_build_2x2
    generate long caller_order = _n
    datasignature clear
    quietly datasignature set
    set varabbrev on
    capture frame drop sc_state1
    table1_tc category if caller_order <= _N, by(group) vars(category cat) ///
        total(after) smallcells(5) frame(sc_state1)
    assert "`c(varabbrev)'" == "on"
    datasignature confirm

    capture noisily table1_tc category, by(group) vars(category cat) smallcells(2)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
    datasignature confirm

    capture frame drop sc_state2
    table1_tc category, by(group) vars(category cat) total(after) ///
        smallcells(5) frame(sc_state2)
    assert r(smallcells) == 5
    discard
    capture frame drop sc_state3
    table1_tc category, by(group) vars(category cat) total(after) ///
        smallcells(5) frame(sc_state3)
    assert r(smallcells) == 5
    assert "`c(varabbrev)'" == "on"
    datasignature confirm
}
_sc_record "if, repeated calls, discard, caller data, and varabbrev are stable" `=_rc' `pass_count' `fail_count'

**# Threshold above sample size

local ++test_count
capture noisily {
    clear
    input byte group byte category int frequency
        0 0 2
        0 1 3
        1 0 3
        1 1 2
    end
    expand frequency
    drop frequency
    capture frame drop sc_highk
    table1_tc category, by(group) vars(category cat) smallcells(10) ///
        frame(sc_highk)
    assert r(smallcells) == 10
    frame sc_highk {
        ds factor, not
        local public_cells "`r(varlist)'"
        gen byte _raw_positive = 0
        local marker_cells 0
        foreach v of local public_cells {
            capture confirm string variable `v'
            if !_rc {
                replace _raw_positive = 1 if regexm(`v', "^[1-9][0-9]* ")
                count if strpos(`v', "<10") > 0 | strpos(`v', "≥10") > 0
                local marker_cells = `marker_cells' + r(N)
            }
        }
        count if _raw_positive
        assert r(N) == 0
        assert `marker_cells' >= 4
    }
}
_sc_record "k above N is legal and suppresses positive count cells" `=_rc' `pass_count' `fail_count'

**# Summary

display as result "Small-cells tests: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_smallcells tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _smallcells
if `fail_count' > 0 exit 1
