*! validation_smallcells.do  2026-08-11
*! Independent reconstruction oracles for tabtools small-cell suppression
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set processors 1
set varabbrev off
version 16.0

capture log close _vsmallcells
log using "validation_smallcells.log", replace text name(_vsmallcells)

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# Bootstrap

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

capture program drop _vsc_record
program define _vsc_record
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

**# Independent exhaustive oracle

capture mata: mata drop _vsc_ok()
capture mata: mata drop _vsc_base_ok()
capture mata: mata drop _vsc_ranges_2x2()
capture mata: mata drop _vsc_ranges_2x3()
capture mata: mata drop _vsc_assert_primary_ranges()

mata:
real scalar _vsc_ok(real scalar candidate, real scalar actual, real scalar code, real scalar k)
{
    if (code == 0) return(candidate == actual)
    if (code == 1) return(candidate >= 1 & candidate < k)
    if (code == 2) return(candidate >= k)
    return(0)
}

real scalar _vsc_base_ok(
    real scalar candidate,
    real scalar actual,
    real scalar code,
    real scalar exact,
    real scalar k)
{
    if (code == 0 & !exact) return(1)
    return(_vsc_ok(candidate, actual, code, k))
}

real matrix _vsc_ranges_2x2(
    real matrix actual,
    real matrix mask,
    real matrix exact,
    real colvector rowmask,
    real rowvector colmask,
    real scalar totalmask,
    real scalar k,
    real scalar maxv)
{
    real scalar a, b, c, d, i, j, total
    real matrix candidate, ranges
    real colvector arows, crows
    real rowvector acols, ccols

    ranges = J(4, 2, .)
    arows = rowsum(actual)
    acols = colsum(actual)
    for (a = 0; a <= maxv; a++) {
        for (b = 0; b <= maxv; b++) {
            for (c = 0; c <= maxv; c++) {
                for (d = 0; d <= maxv; d++) {
                    candidate = (a, b \ c, d)
                    if (!_vsc_base_ok(a, actual[1, 1], mask[1, 1], exact[1, 1], k)) continue
                    if (!_vsc_base_ok(b, actual[1, 2], mask[1, 2], exact[1, 2], k)) continue
                    if (!_vsc_base_ok(c, actual[2, 1], mask[2, 1], exact[2, 1], k)) continue
                    if (!_vsc_base_ok(d, actual[2, 2], mask[2, 2], exact[2, 2], k)) continue
                    crows = rowsum(candidate)
                    ccols = colsum(candidate)
                    if (!_vsc_ok(crows[1], arows[1], rowmask[1], k)) continue
                    if (!_vsc_ok(crows[2], arows[2], rowmask[2], k)) continue
                    if (!_vsc_ok(ccols[1], acols[1], colmask[1], k)) continue
                    if (!_vsc_ok(ccols[2], acols[2], colmask[2], k)) continue
                    total = sum(candidate)
                    if (!_vsc_ok(total, sum(actual), totalmask, k)) continue
                    for (i = 1; i <= 2; i++) {
                        for (j = 1; j <= 2; j++) {
                            if (missing(ranges[i, j]) | candidate[i, j] < ranges[i, j]) ranges[i, j] = candidate[i, j]
                            if (missing(ranges[i + 2, j]) | candidate[i, j] > ranges[i + 2, j]) ranges[i + 2, j] = candidate[i, j]
                        }
                    }
                }
            }
        }
    }
    return(ranges)
}

real matrix _vsc_ranges_2x3(
    real matrix actual,
    real matrix mask,
    real matrix exact,
    real colvector rowmask,
    real rowvector colmask,
    real scalar totalmask,
    real scalar k,
    real scalar maxv)
{
    real scalar a, b, c, d, e, f, i, j, total
    real matrix candidate, ranges
    real colvector arows, crows
    real rowvector acols, ccols

    ranges = J(4, 3, .)
    arows = rowsum(actual)
    acols = colsum(actual)
    for (a = 0; a <= maxv; a++) {
        for (b = 0; b <= maxv; b++) {
            for (c = 0; c <= maxv; c++) {
                for (d = 0; d <= maxv; d++) {
                    for (e = 0; e <= maxv; e++) {
                        for (f = 0; f <= maxv; f++) {
                            candidate = (a, b, c \ d, e, f)
                            if (any((mask :== 0) :& (exact :== 1) :& (candidate :!= actual))) continue
                            if (any((mask :== 1) :& ((candidate :< 1) :| (candidate :>= k)))) continue
                            if (any((mask :== 2) :& (candidate :< k))) continue
                            crows = rowsum(candidate)
                            ccols = colsum(candidate)
                            if (!_vsc_ok(crows[1], arows[1], rowmask[1], k)) continue
                            if (!_vsc_ok(crows[2], arows[2], rowmask[2], k)) continue
                            if (!_vsc_ok(ccols[1], acols[1], colmask[1], k)) continue
                            if (!_vsc_ok(ccols[2], acols[2], colmask[2], k)) continue
                            if (!_vsc_ok(ccols[3], acols[3], colmask[3], k)) continue
                            total = sum(candidate)
                            if (!_vsc_ok(total, sum(actual), totalmask, k)) continue
                            for (i = 1; i <= 2; i++) {
                                for (j = 1; j <= 3; j++) {
                                    if (missing(ranges[i, j]) | candidate[i, j] < ranges[i, j]) ranges[i, j] = candidate[i, j]
                                    if (missing(ranges[i + 2, j]) | candidate[i, j] > ranges[i + 2, j]) ranges[i + 2, j] = candidate[i, j]
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return(ranges)
}

void _vsc_assert_primary_ranges(real matrix mask, real matrix ranges)
{
    real scalar i, j, nr

    nr = rows(mask)
    for (i = 1; i <= nr; i++) {
        for (j = 1; j <= cols(mask); j++) {
            if (mask[i, j] == 1) assert(ranges[i, j] < ranges[i + nr, j])
        }
    }
}
end

**# V1: false-green 2x2 table

local ++test_count
capture noisily {
    matrix C = (1, 5 \ 6, 1)
    matrix E = J(2, 2, 1)
    matrix S = J(2, 2, 1)
    matrix RE = J(2, 1, 1)
    matrix RS = J(2, 1, 1)
    matrix CE = J(1, 2, 1)
    matrix CS = J(1, 2, 1)
    _tabtools_smallcells, counts(C) exact(E) sensitive(S) ///
        rowexact(RE) rowsensitive(RS) colexact(CE) colsensitive(CS) ///
        grandexact(1) grandsensitive(1) smallcells(5)
    matrix M = r(mask)
    matrix RM = r(rowmask)
    matrix CM = r(colmask)
    scalar GM = r(totalmask)
    mata: R = _vsc_ranges_2x2(st_matrix("C"), st_matrix("M"), st_matrix("E"), ///
        st_matrix("RM"), st_matrix("CM"), st_numscalar("GM"), 5, 9)
    mata: _vsc_assert_primary_ranges(st_matrix("M"), R)
    mata: assert(any(st_matrix("RM") :> 0) | any(st_matrix("CM") :> 0) | st_numscalar("GM") > 0)
}
_vsc_record "2x2 tight bounds defeat structural closure but pass the oracle" `=_rc' `pass_count' `fail_count'

**# V2: ordinary protected 2x2 table

local ++test_count
capture noisily {
    matrix C = (2, 8 \ 6, 4)
    matrix E = J(2, 2, 1)
    matrix S = J(2, 2, 1)
    matrix RE = J(2, 1, 1)
    matrix RS = J(2, 1, 1)
    matrix CE = J(1, 2, 1)
    matrix CS = J(1, 2, 1)
    _tabtools_smallcells, counts(C) exact(E) sensitive(S) ///
        rowexact(RE) rowsensitive(RS) colexact(CE) colsensitive(CS) ///
        grandexact(1) grandsensitive(1) smallcells(5)
    matrix M = r(mask)
    matrix RM = r(rowmask)
    matrix CM = r(colmask)
    scalar GM = r(totalmask)
    assert M[1, 1] == 1
    assert M[2, 2] == 1
    assert M[1, 2] == 2 | M[2, 1] == 2
    mata: R = _vsc_ranges_2x2(st_matrix("C"), st_matrix("M"), st_matrix("E"), ///
        st_matrix("RM"), st_matrix("CM"), st_numscalar("GM"), 5, 14)
    mata: _vsc_assert_primary_ranges(st_matrix("M"), R)
}
_vsc_record "2x2 engine decisions satisfy independent enumeration" `=_rc' `pass_count' `fail_count'

**# V3: 2x3 structural-zero table

local ++test_count
capture noisily {
    matrix C = (1, 5, 0 \ 4, 0, 6)
    matrix E = J(2, 3, 1)
    matrix S = J(2, 3, 1)
    matrix RE = J(2, 1, 1)
    matrix RS = J(2, 1, 1)
    matrix CE = J(1, 3, 1)
    matrix CS = J(1, 3, 1)
    _tabtools_smallcells, counts(C) exact(E) sensitive(S) ///
        rowexact(RE) rowsensitive(RS) colexact(CE) colsensitive(CS) ///
        grandexact(1) grandsensitive(1) smallcells(5)
    matrix M = r(mask)
    matrix RM = r(rowmask)
    matrix CM = r(colmask)
    scalar GM = r(totalmask)
    assert M[1, 3] == 0
    assert M[2, 2] == 0
    mata: R = _vsc_ranges_2x3(st_matrix("C"), st_matrix("M"), st_matrix("E"), ///
        st_matrix("RM"), st_matrix("CM"), st_numscalar("GM"), 5, 7)
    mata: _vsc_assert_primary_ranges(st_matrix("M"), R)
}
_vsc_record "2x3 oracle agrees and structural zeros stay visible" `=_rc' `pass_count' `fail_count'

**# V4: hidden cells provide bounded residual capacity

local ++test_count
capture noisily {
    matrix C = (1, 4 \ 3, 2)
    matrix E = (1, 1 \ 0, 0)
    matrix S = (1, 1 \ 0, 0)
    matrix RE = (1 \ 0)
    matrix RS = (1 \ 0)
    matrix CE = J(1, 2, 1)
    matrix CS = J(1, 2, 1)
    _tabtools_smallcells, counts(C) exact(E) sensitive(S) ///
        rowexact(RE) rowsensitive(RS) colexact(CE) colsensitive(CS) ///
        grandexact(1) grandsensitive(1) smallcells(5)
    matrix M = r(mask)
    matrix RM = r(rowmask)
    matrix CM = r(colmask)
    scalar GM = r(totalmask)
    assert M[1, 1] == 1
    assert M[2, 1] == 0
    assert M[2, 2] == 0
    mata: R = _vsc_ranges_2x2(st_matrix("C"), st_matrix("M"), st_matrix("E"), ///
        st_matrix("RM"), st_matrix("CM"), st_numscalar("GM"), 5, 10)
    mata: _vsc_assert_primary_ranges(st_matrix("M"), R)
}
_vsc_record "unreleased logical cells are not exposed as complementary markers" `=_rc' `pass_count' `fail_count'

**# V5: truthful full-block fallback and threshold boundaries

local ++test_count
capture noisily {
    * One released equation, no eligible >=k interior complement.  The
    * conservative fallback must never label an actual 1 as >=5 merely
    * because that cell was initially outside the sensitive map.
    matrix C = (1, 1, 1, 1, 1)
    matrix E = J(1, 5, 1)
    matrix S = (1, 0, 0, 0, 0)
    matrix RE = (1)
    matrix RS = (1)
    matrix CE = J(1, 5, 0)
    matrix CS = J(1, 5, 0)
    _tabtools_smallcells, counts(C) exact(E) sensitive(S) ///
        rowexact(RE) rowsensitive(RS) colexact(CE) colsensitive(CS) ///
        smallcells(5)
    matrix M = r(mask)
    matrix RM = r(rowmask)
    mata: assert(all(st_matrix("M") :== 1))
    assert RM[1, 1] == 2
    forvalues j = 1/5 {
        matrix B = C
        matrix B[1, `j'] = 2
        mata: assert(all((st_matrix("B") :>= 1) :& (st_matrix("B") :< 5)))
        mata: assert(sum(st_matrix("B")) >= 5)
        assert B[1, `j'] != C[1, `j']
    }

    * Exact threshold boundary: 0 stays visible; 1 and k-1 are primary;
    * k and k+1 remain visible when no released margin determines them.
    matrix C = (0, 1, 4, 5, 6)
    matrix E = J(1, 5, 1)
    matrix S = J(1, 5, 1)
    matrix RE = (0)
    matrix RS = (0)
    _tabtools_smallcells, counts(C) exact(E) sensitive(S) ///
        rowexact(RE) rowsensitive(RS) smallcells(5)
    matrix M = r(mask)
    matrix M_expected = (0, 1, 1, 0, 0)
    assert mreldif(M, M_expected) == 0
}
_vsc_record "full-block fallback markers are truthful at 0/1/k-1/k/k+1" `=_rc' `pass_count' `fail_count'

**# V6: validation and safe numeric rendering

local ++test_count
capture noisily {
    matrix Cneg = (1, -1)
    matrix Eneg = J(1, 2, 1)
    capture noisily _tabtools_smallcells, counts(Cneg) exact(Eneg) ///
        sensitive(Eneg) smallcells(5)
    assert _rc == 198

    matrix Cfrac = (1, 2.5)
    capture noisily _tabtools_smallcells, counts(Cfrac) exact(Eneg) ///
        sensitive(Eneg) smallcells(5)
    assert _rc == 198

    _tabtools_smallcells_render, value(2) mask(1) smallcells(5)
    assert `"`r(display)'"' == "<5"
    assert r(value) == .p
    _tabtools_smallcells_render, value(8) mask(2) smallcells(5)
    assert `"`r(display)'"' == "≥5"
    assert r(value) == .s
    _tabtools_smallcells_render, value(8) mask(3) smallcells(5)
    assert `"`r(display)'"' == "Suppressed"
    assert r(value) == .d
    _tabtools_smallcells_render, value(0) mask(0) smallcells(5) format(%9.0f)
    assert strtrim(`"`r(display)'"') == "0"
    assert r(value) == 0
}
_vsc_record "engine input guards and .p/.s/.d rendering contract" `=_rc' `pass_count' `fail_count'

**# Summary

display as result "Small-cells validation: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: validation_smallcells tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _vsmallcells
if `fail_count' > 0 exit 1
