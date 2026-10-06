* test_bugfix_2026_10_06_l.do - tabtools 2.5.2, bug reports 2026-10-06 (slice L)
* (1) Table 1 centered sum of squares: sum(wdev)^2 overflowed to missing for
*     rescaled huge weights although the variance is finite; now s * (s / swg).
* (2) xlsx SMD column width: fixed at 8, so a named-pair header was clipped; now
*     max(8, ceil(0.85 * header length) + 2), body cells never widen it.
* Oracles: summarize [aw=w/scale] (SD is scale-invariant in the weights), a
* Mata two-pass SD, and column widths read back from the workbook with
* openpyxl (tools/xlsx_facts.py).

clear all
set more off
set varabbrev off
version 17.0

capture log close _bfl
log using "test_bugfix_2026_10_06_l.log", replace text name(_bfl)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global BFL_OUT "`output_dir'"
global BFL_TOOLS "`qa_dir'/tools"
local _old : dir "`output_dir'" files "bfl_*"
foreach _f of local _old {
    capture erase "`output_dir'/`_f'"
}
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear
global TABTOOLS_set_smallcells

local pass_count = 0
local fail_count = 0

* relative closeness of two numbers, both required to be nonmissing
capture program drop _bfl_close
program define _bfl_close
    version 17.0
    args a b tol
    assert !missing(`a') & !missing(`b')
    assert reldif(`a', `b') < `tol'
end

* SD of a "mean±SD" cell of the table in memory: row, column variable
capture program drop _bfl_sd
program define _bfl_sd, rclass
    version 17.0
    args row col
    local cell = `col'[`row']
    local sd = ustrregexra(`"`cell'"', "^.*±", "")
    return scalar sd = real(strtrim("`sd'"))
    return scalar mean = real(strtrim(ustrregexra(`"`cell'"', "±.*$", "")))
end

* width of the workbook column holding the cell text; r(width), r(col)
capture program drop _bfl_width
program define _bfl_width, rclass
    version 17.0
    args book sheet needle
    tempfile out
    capture erase `"`out'"'
    quietly shell python3 "$BFL_TOOLS/xlsx_facts.py" "`book'" "`sheet'" "`out'"
    confirm file `"`out'"'
    tempname h
    local col ""
    local w .
    file open `h' using `"`out'"', read text
    file read `h' line
    while r(eof) == 0 {
        if substr(`"`macval(line)'"', 1, 6) == "value " {
            local rest = substr(`"`macval(line)'"', 7, .)
            gettoken cell txt : rest
            if strtrim(`"`macval(txt)'"') == `"`needle'"' {
                local col = regexr("`cell'", "[0-9]+$", "")
                local row = regexr("`cell'", "^[A-Z]+", "")
            }
        }
        file read `h' line
    }
    file close `h'
    file open `h' using `"`out'"', read text
    file read `h' line
    while r(eof) == 0 {
        if substr(`"`macval(line)'"', 1, 6) == "width " {
            tokenize `"`macval(line)'"'
            * the writer adds a fixed 0.71 of padding to every width it stores
            if "`2'" == "`col'" local w = round(real("`3'") - 0.71, 0.01)
        }
        file read `h' line
    }
    file close `h'
    return scalar width = `w'
    return local col "`col'"
    return local hrow "`row'"
end

**# L1 report repro: three rows, weights 1e40, values ~1e133
capture noisily {
    clear
    input double y double w
     2.9026338025909847e133 1e40
    -1.3002621865103486e133 1e40
     1.7015272624644451e133 1e40
    end
    * Oracle: the SD is scale-invariant in the weights and in y
    mata: yy = (2.9026338025909847, -1.3002621865103486, 1.7015272624644451)'
    mata: st_numscalar("orsd", sqrt(sum((yy :- mean(yy)):^2) / 2) * 1e133)
    table1_tc, vars(y contn %24.15g) wt(w) clear
    _bfl_sd 4 Total
    assert r(sd) > 0 & r(sd) < .
    _bfl_close `=r(sd)' `=scalar(orsd)' 1e-8
    assert abs(r(sd) / 2.16478372714671e+133 - 1) < 1e-8
}
if _rc == 0 {
    display as result "  PASS: L1 3-row 1e40-weight repro prints a finite SD equal to the oracle"
    local ++pass_count
}
else {
    display as error "  FAIL: L1 3-row 1e40-weight repro (rc=`=_rc')"
    local ++fail_count
}

**# L2 report addendum: uniform 1e200 weights, by(g); SD scale-invariant
capture noisily {
    clear
    set obs 20
    gen double x = _n
    gen g = cond(_n <= 10, 1, 2)
    gen b = mod(_n, 2)
    gen double w = 1e200
    quietly summarize x if g == 1
    local sd1 = r(sd)
    quietly summarize x if g == 2
    local sd2 = r(sd)
    foreach sc in 1e200 1e160 1e154 1 {
        replace w = `sc'
        preserve
        table1_tc, by(g) vars(x contn %24.15g \ b bin) wt(w) smd clear
        * the by() columns are the second and third variables
        unab cols : _all
        local c1 : word 2 of `cols'
        local c2 : word 3 of `cols'
        _bfl_sd 4 `c1'
        _bfl_close `=r(sd)' `sd1' 1e-9
        _bfl_close `=r(mean)' 5.5 1e-9
        _bfl_sd 4 `c2'
        _bfl_close `=r(sd)' `sd2' 1e-9
        _bfl_close `=r(mean)' 15.5 1e-9
        assert r(sd) > 0 & r(sd) < .
        restore
    }
}
if _rc == 0 {
    display as result "  PASS: L2 1e200/1e160/1e154/1 uniform weights give the same finite SDs as summarize"
    local ++pass_count
}
else {
    display as error "  FAIL: L2 uniform-weight scale invariance (rc=`=_rc')"
    local ++fail_count
}

**# L3 random heavy weights: every group SD equals summarize [aw=w/scale]
capture noisily {
    clear
    set seed 20261006
    set obs 60
    gen double x = rnormal(30, 7)
    gen g = 1 + (_n > 20) + (_n > 40)
    gen double u = runiform(0.2, 5)
    foreach sc in 1e170 1e200 1e250 {
        gen double w = u * `sc'
        gen double ws = w / `sc'
        forvalues k = 1/3 {
            quietly summarize x [aw=ws] if g == `k'
            local sd`k' = r(sd)
            local mn`k' = r(mean)
        }
        preserve
        table1_tc, by(g) vars(x contn %24.15g) wt(w) clear
        unab cols : _all
        forvalues k = 1/3 {
            local c : word `=`k'+1' of `cols'
            _bfl_sd 4 `c'
            _bfl_close `=r(sd)' `sd`k'' 1e-9
            _bfl_close `=r(mean)' `mn`k'' 1e-9
            assert r(sd) > 0 & r(sd) < .
        }
        restore
        drop w ws
    }
}
if _rc == 0 {
    display as result "  PASS: L3 random 1e170-1e250 weights match summarize [aw] on rescaled weights"
    local ++pass_count
}
else {
    display as error "  FAIL: L3 random heavy weights (rc=`=_rc')"
    local ++fail_count
}

**# L4 ordinary weights: SD matches summarize [aw] (unchanged by the fix)
capture noisily {
    clear
    set seed 77
    set obs 200
    gen double x = rnormal(50, 10)
    gen byte g = 1 + (_n > 90)
    gen double w = runiform(0.5, 3)
    forvalues k = 1/2 {
        quietly summarize x [aw=w] if g == `k'
        local sd`k' = r(sd)
    }
    table1_tc, by(g) vars(x contn %24.15g) wt(w) clear
    unab cols : _all
    forvalues k = 1/2 {
        local c : word `=`k'+1' of `cols'
        _bfl_sd 4 `c'
        _bfl_close `=r(sd)' `sd`k'' 1e-9
        assert r(sd) > 0 & r(sd) < .
    }
}
if _rc == 0 {
    display as result "  PASS: L4 ordinary weighted SDs match summarize [aw]"
    local ++pass_count
}
else {
    display as error "  FAIL: L4 ordinary weighted SDs (rc=`=_rc')"
    local ++fail_count
}

**# L7 a sum of finite weighted products overflows (x near 3000, w near 1e300)
* No single w*x^2 overflows, but their sum does; 2.5.1 and the first 2.5.2
* fix printed the SD as missing. SD is scale-invariant in the weights.
capture noisily {
    clear
    set seed 1300
    set obs 40
    gen double x = rnormal(3000, 50)
    gen g = 1 + (_n > 20)
    gen double u = runiform(0.2, 1)
    gen double w = u * 1e300
    forvalues k = 1/2 {
        quietly summarize x [aw=u] if g == `k'
        local sd`k' = r(sd)
        local mn`k' = r(mean)
    }
    table1_tc, by(g) vars(x contn %24.15g) wt(w) clear
    unab cols : _all
    forvalues k = 1/2 {
        local c : word `=`k'+1' of `cols'
        _bfl_sd 4 `c'
        assert r(sd) > 0 & r(sd) < .
        _bfl_close `=r(sd)' `sd`k'' 1e-9
        _bfl_close `=r(mean)' `mn`k'' 1e-9
    }
}
if _rc == 0 {
    display as result "  PASS: L7 1e300 weights: an overflowing sum of products is rescaled"
    local ++pass_count
}
else {
    display as error "  FAIL: L7 1e300 weights (rc=`=_rc')"
    local ++fail_count
}

**# L5 SMD column width follows the header text, floor 8
capture noisily {
    clear
    set seed 20261006
    set obs 30
    gen str20 arm = cond(_n <= 10, "LongGroupNameA", cond(_n <= 20, "LongGroupNameB", "LongGroupNameC"))
    gen double age = rnormal(50, 10)
    local book "$BFL_OUT/bfl_smd3.xlsx"

    * three groups, default pair: the header names the first two groups
    table1_tc, by(arm) vars(age contn) smd excel("`book'") sheet(t1)
    local hdr "SMD (LongGroupNameA vs LongGroupNameB)"
    local want = ceil(strlen("`hdr'") * 0.85) + 2
    assert `want' == 35
    _bfl_width "`book'" t1 "`hdr'"
    assert r(width) == `want'

    * the group columns keep their own sizes: the SMD width did not leak
    _bfl_width "`book'" t1 "LongGroupNameC"
    assert r(width) < `want'

    * bare SMD, two groups: exactly 8
    keep if arm != "LongGroupNameC"
    local book2 "$BFL_OUT/bfl_smd2.xlsx"
    table1_tc, by(arm) vars(age contn) smd excel("`book2'") sheet(t1)
    _bfl_width "`book2'" t1 "SMD"
    assert r(width) == 8
}
if _rc == 0 {
    display as result "  PASS: L5 named-pair SMD header sets width 35; bare SMD stays 8"
    local ++pass_count
}
else {
    display as error "  FAIL: L5 SMD column width (rc=`=_rc')"
    local ++fail_count
}

**# L6 other SMD headers: Pop. SB and Max SMD stay at 8; smdpair() on two groups is measured
capture noisily {
    clear
    set seed 20261006
    set obs 90
    gen str20 arm = cond(_n <= 30, "LongGroupNameA", cond(_n <= 60, "LongGroupNameB", "LongGroupNameC"))
    gen double age = rnormal(50, 10)
    local book "$BFL_OUT/bfl_pop.xlsx"
    table1_tc, by(arm) vars(age contn) smd smdtype(population) excel("`book'") sheet(t1)
    _bfl_width "`book'" t1 "Pop. SB"
    assert r(width) == 8
    local book "$BFL_OUT/bfl_max.xlsx"
    table1_tc, by(arm) vars(age contn) smd smdtype(maxpair) excel("`book'") sheet(t1)
    _bfl_width "`book'" t1 "Max SMD"
    assert r(width) == 8
    * smdpair() names the pair even on the 3 groups; the 2nd and 3rd group
    local book "$BFL_OUT/bfl_pair.xlsx"
    table1_tc, by(arm) vars(age contn) smd smdpair(LongGroupNameB LongGroupNameC) ///
        excel("`book'") sheet(t1)
    local hdr "SMD (LongGroupNameB vs LongGroupNameC)"
    _bfl_width "`book'" t1 "`hdr'"
    assert r(width) == ceil(strlen("`hdr'") * 0.85) + 2
}
if _rc == 0 {
    display as result "  PASS: L6 Pop. SB / Max SMD stay 8; smdpair() header is measured"
    local ++pass_count
}
else {
    display as error "  FAIL: L6 other SMD header widths (rc=`=_rc')"
    local ++fail_count
}

local _tc = `pass_count' + `fail_count'
display "RESULT: test_bugfix_2026_10_06_l tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _bfl
if `fail_count' > 0 exit 1
