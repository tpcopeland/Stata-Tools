*! crossval_multigroup_published_twang.do Version 1.0.0  2026/11/17
*! Published reproduction: psdash balance (multi-group) vs the printed twang mnps AOD tutorial
*! Author: Timothy P Copeland, Karolinska Institutet
* Usage: cd psdash/qa && stata-mp -b do crossval_multigroup_published_twang.do
*
* Source (printed numbers): Burgette L, Griffin BA, McCaffrey D. "Propensity scores
*   for multiple treatments: A tutorial for the mnps function in the twang package".
*   RAND Corporation; twang 2.6.2 vignette mnps.pdf (December 22, 2025), sec. 2.3.
*   The vignette applies McCaffrey et al. (2013, Stat Med 32(19):3388-3414,
*   doi:10.1002/sim.5753) to the AOD data. The journal article's own Table 3 is NOT
*   reproducible (non-public CSAT/GAIN data; AOD is a 600-youth, 5-covariate
*   subset), so the printed numbers asserted here are those of the tutorial.
* Data: qa/data/multigroup/ (printed tables, SOURCE.md). The frozen twang weights
*   (aod_twang_ate_weights.csv, rows of twang's AOD data plus weights) are not
*   distributed with the repository: _psdash_qa_extdata.do uses a copy under
*   $STATA_QA_DATA when set, else regenerates the file with
*   _multigroup_reference_twang.R (Rscript and twang 2.6.2), and either way
*   requires the recorded byte length and checksum CRC. The suite exits 77
*   (skipped, dependency unavailable) when neither is possible. No network is used.
*
* Mapping (twang -> psdash balance, three-arm ATE, every pair via reference(0)
*   and reference(1)):
*   mean1/mean2 (bal.table)  -> Mean_a/Mean_b (unweighted) or MnAdj_a/MnAdj_b
*                               (wvar), a<b the two compared arms
*   ks                       -> KS_<oth>v<ref> (unweighted) or KSAdj_<oth>v<ref>
*   summary() max.ks         -> maximum of KS/KSAdj over the 3 pairs and 5 covariates
*   bal.table(collapse.to='covariate') max.ks -> maximum over the 3 pairs, per covariate
*
* NOT asserted (definition mismatch): std.eff.sz, p, max.std.eff.sz. twang scales
*   the mean difference by pop.sd, the unweighted SD of all 600 youth across the
*   three arms; psdash uses the unweighted pooled SD of the two compared arms
*   (psdash.sthlp, "SMD denominator"). They agree only to rounding in some cells.
*   VR is not printed by twang. The twang pop.sd formula is used ONLY in the
*   guard that the frozen fixture is the vignette's fit (it never touches psdash).
*
* Tolerances: bal.table(digits = 2) prints mean1, mean2 and ks to 2 decimals, so a
*   psdash value matches when it rounds to the printed digit: |diff| <= 0.005 + 1e-6
*   (1e-6 absorbs binary ties, e.g. a KS of 0.085 prints as 0.09). The 4-digit
*   collapse.to='covariate' KS cells use 0.00005 + 1e-8; the 8-digit summary()
*   values use 1e-8.

clear all
version 16.0
set more off
set varabbrev off

capture log close _all
log using "crossval_multigroup_published_twang.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

global PSDASH_MGP_TESTS = 0
global PSDASH_MGP_PASS = 0
global PSDASH_MGP_FAIL = 0
global PSDASH_MGP_SKIP = 0
global PSDASH_MGP_FAILED ""

run "`qa_dir'/_psdash_qa_extdata.do"
capture noisily _psdash_qa_extfile multigroup aod_twang_ate_weights.csv, ///
    len(58045) crc(3078753458) regen("`qa_dir'/_multigroup_reference_twang.R")
local ext_rc = _rc
if `ext_rc' {
    display as error "FAIL: aod_twang_ate_weights.csv integrity check (rc=`ext_rc')"
    display as text "RESULT: crossval_multigroup_published_twang tests=1 pass=0 fail=1 skip=0"
    macro drop PSDASH_MGP_TESTS PSDASH_MGP_PASS PSDASH_MGP_FAIL PSDASH_MGP_SKIP PSDASH_MGP_FAILED
    _psdash_qa_cleanup
    capture log close _all
    exit 9
}
local fixture `"`r(path)'"'
local fixsrc "`r(source)'"
local regen_dir `"`r(regen_dir)'"'
if `"`fixture'"' == "" {
    display as text "SKIP: aod_twang_ate_weights.csv unavailable (no STATA_QA_DATA copy; Rscript with twang 2.6.2 not available)"
    display as text "RESULT: crossval_multigroup_published_twang tests=0 pass=0 fail=0 skip=1 skipped=dependency_unavailable"
    macro drop PSDASH_MGP_TESTS PSDASH_MGP_PASS PSDASH_MGP_FAIL PSDASH_MGP_SKIP PSDASH_MGP_FAILED
    _psdash_qa_cleanup
    capture log close _all
    exit 77
}
display as text "aod_twang_ate_weights.csv source: `fixsrc' (length and CRC verified)"

capture program drop _psdash_mgp_record
program define _psdash_mgp_record
    args id rc
    global PSDASH_MGP_TESTS = $PSDASH_MGP_TESTS + 1
    if `rc' == 0 {
        display as result "PASS: `id'"
        global PSDASH_MGP_PASS = $PSDASH_MGP_PASS + 1
    }
    else if `rc' == 77 {
        display as text "SKIP: `id'"
        global PSDASH_MGP_SKIP = $PSDASH_MGP_SKIP + 1
    }
    else {
        display as error "FAIL: `id' (rc=`rc')"
        global PSDASH_MGP_FAIL = $PSDASH_MGP_FAIL + 1
        global PSDASH_MGP_FAILED "$PSDASH_MGP_FAILED `id'"
    }
end

* Run psdash balance for the three weight sets and post one row per
* (weight set, pair, covariate): sm 0 = unweighted (raw Mean_/KS_ columns; the
* multi-group route needs some wvar, so a variable of ones is supplied and the
* raw, weight-independent columns are read), 1 = es.mean weights, 2 = ks.mean
* weights (MnAdj_/KSAdj_ columns).
capture program drop _psdash_mgp_collect
program define _psdash_mgp_collect
    args fixture outfile
    quietly import delimited using "`fixture'", varnames(1) asdouble clear
    generate byte one = 1
    local vars illact crimjust subprob subdep white
    tempname H
    postfile `H' byte sm byte a byte b str10 var double(g1 g2 gks) ///
        using "`outfile'", replace
    local sm = -1
    foreach w in one w_es w_ks {
        local ++sm
        foreach pr in "0 1 0" "0 2 0" "1 2 1" {
            tokenize `pr'
            local a `1'
            local b `2'
            local ref `3'
            local oth = cond(`ref' == `a', `b', `a')
            quietly psdash balance tnum, covariates(`vars') wvar(`w') reference(`ref')
            if "`w'" == "one" {
                local c1 "Mean_`a'"
                local c2 "Mean_`b'"
                local ck "KS_`oth'v`ref'"
            }
            else {
                local c1 "MnAdj_`a'"
                local c2 "MnAdj_`b'"
                local ck "KSAdj_`oth'v`ref'"
            }
            matrix B = r(balance)
            local i = 0
            foreach v of local vars {
                local ++i
                post `H' (`sm') (`a') (`b') ("`v'") (B[`i', "`c1'"]) ///
                    (B[`i', "`c2'"]) (B[`i', "`ck'"])
            }
        }
    }
    postclose `H'
end

local dd "`qa_dir'/data/multigroup"
local btol = 0.005 + 1e-6

tempfile got printed_bt printed_cov printed_3d marker
local refdir "`marker'_twangref"

**# Setup: frozen fixture, printed tables, psdash output

capture noisily {
    confirm file `"`fixture'"'
    foreach f in twang_mnps_aod_baltable_printed.csv ///
        twang_mnps_aod_summary_printed.csv twang_mnps_aod_covariate_ks_printed.csv ///
        twang_mnps_aod_baltable_3digit_printed.csv {
        confirm file "`dd'/`f'"
    }

    * printed bal.table(mnps.AOD, digits = 2), vignette sec. 2.3, pp. 10-12 (rows 1-45)
    import delimited using "`dd'/twang_mnps_aod_baltable_printed.csv", ///
        varnames(1) stringcols(2/5) asdouble clear
    assert _N == 45
    generate byte sm = cond(stop == "unw", 0, cond(stop == "es.mean", 1, 2))
    generate byte a = cond(tmt1 == "community", 0, cond(tmt1 == "metcbt5", 1, .))
    generate byte b = cond(tmt2 == "metcbt5", 1, cond(tmt2 == "scy", 2, .))
    assert !missing(sm, a, b)
    keep sm a b var mean1 mean2 ks
    rename (mean1 mean2 ks) (p1 p2 pks)
    save "`printed_bt'", replace

    * printed bal.table(collapse.to = 'covariate', digits = 4), vignette p. 12
    import delimited using "`dd'/twang_mnps_aod_covariate_ks_printed.csv", ///
        varnames(1) stringcols(2/3) asdouble clear
    assert _N == 15
    generate byte sm = cond(stop == "unw", 0, cond(stop == "es.mean", 1, 2))
    assert !missing(sm)
    keep sm var max_ks
    rename max_ks pmaxks
    save "`printed_cov'", replace

    * printed 3-decimal subsets of bal.table (subset.treat/subset.var call, p. 13;
    * es.cutoff = 0.1 call, p. 14): 14 distinct rows keyed by the table row number
    import delimited using "`dd'/twang_mnps_aod_baltable_3digit_printed.csv", ///
        varnames(1) stringcols(2/4) asdouble clear
    assert _N == 14
    generate byte sm = cond(row <= 15, 0, cond(row <= 30, 1, 2))
    generate byte a = cond(tmt1 == "community", 0, cond(tmt1 == "metcbt5", 1, .))
    generate byte b = cond(tmt2 == "metcbt5", 1, cond(tmt2 == "scy", 2, .))
    assert !missing(sm, a, b)
    keep sm a b var mean1 mean2 ks
    rename (mean1 mean2 ks) (p1 p2 pks)
    save "`printed_3d'", replace

    _psdash_mgp_collect "`fixture'" "`got'"
    use "`got'", clear
    assert _N == 45
}
_psdash_mgp_record setup_fixture_tables_and_psdash_output `=_rc'

**# Fixture integrity

capture noisily {
    import delimited using "`fixture'", varnames(1) asdouble clear
    assert _N == 600
    * AOD: 200 youth in each of community / metcbt5 / scy; tnum codes follow
    * the alphabetical factor order used by twang and by the printed table
    quietly count if treat == "community" & tnum == 0
    assert r(N) == 200
    quietly count if treat == "metcbt5" & tnum == 1
    assert r(N) == 200
    quietly count if treat == "scy" & tnum == 2
    assert r(N) == 200
    foreach v in illact crimjust subprob subdep white w_es w_ks {
        quietly count if missing(`v')
        assert r(N) == 0
    }
    assert w_es > 0 & !missing(w_es)
    assert w_ks > 0 & !missing(w_ks)
    * binary covariate really is 0/1 (white), the other four are continuous
    assert inlist(white, 0, 1)
}
_psdash_mgp_record fixture_integrity `=_rc'

**# Guard: the frozen weights ARE the vignette's mnps fit (no R, no psdash)
**## ESS by arm (vignette p. 14, summary(mnps.AOD), 4 printed decimals) and
**## twang max.std.eff.sz (8 printed decimals) recomputed from the fixture weights

capture noisily {
    import delimited using "`dd'/twang_mnps_aod_summary_printed.csv", ///
        varnames(1) stringcols(1) asdouble clear
    assert _N == 3
    foreach k in unw es.mean ks.mean {
        local kk = subinstr("`k'", ".", "", .)
        quietly summarize max_std_eff_sz if stop == "`k'", meanonly
        local pub_msd_`kk' = r(mean)
        quietly summarize max_ks if stop == "`k'", meanonly
        local pub_mks_`kk' = r(mean)
        assert !missing(`pub_msd_`kk'', `pub_mks_`kk'')
    }
    foreach nm in community_es metcbt5_es scy_es community_ks metcbt5_ks scy_ks {
        quietly summarize ess_`nm', meanonly
        local pub_ess_`nm' = r(mean)
        assert !missing(`pub_ess_`nm'')
    }

    import delimited using "`fixture'", varnames(1) asdouble clear
    * ESS = (sum w)^2 / sum w^2 within each arm (Kish; twang summary ESS)
    foreach w in w_es w_ks {
        local s = substr("`w'", 3, 2)
        generate double `w'2 = `w'^2
        forvalues t = 0/2 {
            local nm : word `=`t' + 1' of community metcbt5 scy
            quietly summarize `w' if tnum == `t', meanonly
            local sw = r(sum)
            quietly summarize `w'2 if tnum == `t', meanonly
            local ess = (`sw')^2 / r(sum)
            assert !missing(`ess')
            assert abs(`ess' - `pub_ess_`nm'_`s'') <= 0.00005 + 1e-9
        }
    }

    * twang std.eff.sz = |weighted mean1 - weighted mean2| / pop.sd, pop.sd the
    * unweighted SD of all 600 youth; max over the 3 pairs and 5 covariates
    generate double w_unw = 1
    foreach w in w_unw w_es w_ks {
        local mx = 0
        foreach v in illact crimjust subprob subdep white {
            quietly summarize `v'
            local psd = r(sd)
            forvalues t = 0/2 {
                quietly summarize `v' [aw = `w'] if tnum == `t', meanonly
                local m`t' = r(mean)
            }
            foreach pr in "0 1" "0 2" "1 2" {
                tokenize `pr'
                local d = abs(`m`1'' - `m`2'') / `psd'
                if `d' > `mx' local mx = `d'
            }
        }
        local kk = cond("`w'" == "w_unw", "unw", cond("`w'" == "w_es", "esmean", "ksmean"))
        assert !missing(`mx')
        assert abs(`mx' - `pub_msd_`kk'') <= 1e-8
    }
}
_psdash_mgp_record guard_fixture_reproduces_vignette_ess_and_twang_asmd `=_rc'

**# psdash max KS over all pairs and covariates equals printed summary()

capture noisily {
    import delimited using "`dd'/twang_mnps_aod_summary_printed.csv", ///
        varnames(1) stringcols(1) asdouble clear
    generate byte sm = cond(stop == "unw", 0, cond(stop == "es.mean", 1, 2))
    keep sm max_ks
    rename max_ks pub_maxks
    tempfile pubmax
    save "`pubmax'", replace

    use "`got'", clear
    * summary(mnps.AOD) max.ks, vignette p. 14: 0.13000000 / 0.06650091 / 0.06526362
    collapse (max) psd_maxks = gks, by(sm)
    merge 1:1 sm using "`pubmax'", assert(match) nogenerate
    assert _N == 3
    assert !missing(psd_maxks) & !missing(pub_maxks)
    assert abs(psd_maxks - pub_maxks) <= 1e-8
}
_psdash_mgp_record maxks_matches_printed_summary `=_rc'

**# psdash pairwise means and KS vs printed bal.table(digits = 2), 135 cells

capture noisily {
    use "`got'", clear
    merge 1:1 sm a b var using "`printed_bt'", assert(match) nogenerate
    assert _N == 45
    assert !missing(g1, g2, gks, p1, p2, pks)
    * 45 rows x {mean1, mean2, ks} = 135 printed cells, each within half a printed unit
    generate double d1 = abs(g1 - p1)
    generate double d2 = abs(g2 - p2)
    generate double dk = abs(gks - pks)
    assert !missing(d1, d2, dk)
    assert d1 <= `btol'
    assert d2 <= `btol'
    assert dk <= `btol'
    * the weighted rows must carry the weighting: es.mean and ks.mean rows are
    * not the unweighted table (see the discrimination test below)
}
_psdash_mgp_record baltable_135_cells_within_rounding `=_rc'

**## Three-decimal subsets: 14 rows x {mean1, mean2, ks} = 42 cells, half a unit at 3 decimals

capture noisily {
    use "`got'", clear
    merge 1:1 sm a b var using "`printed_3d'", keep(match) nogenerate
    assert _N == 14
    assert !missing(g1, g2, gks, p1, p2, pks)
    generate double d1 = abs(g1 - p1)
    generate double d2 = abs(g2 - p2)
    generate double dk = abs(gks - pks)
    assert !missing(d1, d2, dk)
    assert d1 <= 0.0005 + 1e-6
    assert d2 <= 0.0005 + 1e-6
    assert dk <= 0.0005 + 1e-6
}
_psdash_mgp_record baltable_3digit_subsets_42_cells `=_rc'

**## Discrimination: the 0.005 tolerance still tells weighted from unweighted

capture noisily {
    use "`got'", clear
    * psdash WEIGHTED values compared with the printed UNWEIGHTED rows must fail
    * in many cells, otherwise the 135-cell check could not detect a lost wvar
    keep if sm > 0
    replace sm = 0
    merge m:1 sm a b var using "`printed_bt'", keep(match) nogenerate
    assert _N == 30
    assert !missing(g1, g2, gks, p1, p2, pks)
    generate byte bad = abs(g1 - p1) > `btol' | abs(g2 - p2) > `btol' | abs(gks - pks) > `btol'
    quietly count if bad
    local nbad = r(N)
    assert !missing(`nbad')
    assert `nbad' >= 10
}
_psdash_mgp_record tolerance_discriminates_weighting `=_rc'

**# psdash per-covariate max KS vs printed collapse.to = 'covariate' (4 digits)

capture noisily {
    use "`got'", clear
    * max over the three pairs for each covariate: vignette p. 12
    collapse (max) psd_maxks = gks, by(sm var)
    merge 1:1 sm var using "`printed_cov'", assert(match) nogenerate
    assert _N == 15
    assert !missing(psd_maxks, pmaxks)
    assert abs(psd_maxks - pmaxks) <= 0.00005 + 1e-8
}
_psdash_mgp_record covariate_maxks_matches_printed_4digits `=_rc'

**# Unit weights: adjusted columns equal the raw columns exactly

capture noisily {
    import delimited using "`fixture'", varnames(1) asdouble clear
    generate byte one = 1
    foreach ref in 0 1 {
        quietly psdash balance tnum, covariates(illact crimjust subprob subdep white) ///
            wvar(one) reference(`ref')
        matrix M = r(balance)
        local oth = cond(`ref' == 0, "1 2", "0 2")
        foreach o of local oth {
            forvalues i = 1/5 {
                assert !missing(M[`i', "KS_`o'v`ref'"], M[`i', "KSAdj_`o'v`ref'"])
                assert abs(M[`i', "KS_`o'v`ref'"] - M[`i', "KSAdj_`o'v`ref'"]) < 1e-12
                assert abs(M[`i', "Mean_`o'"] - M[`i', "MnAdj_`o'"]) < 1e-12
            }
        }
    }
}
_psdash_mgp_record unit_weights_adjusted_equals_raw_columns `=_rc'

**# Regeneration guard: R twang refits the vignette model and matches the frozen fixture

* When the fixture itself was regenerated by R in this run (source regenerated), its
* equality with the recorded original is already established by the length and CRC
* check above; comparing it with the output of the same run would compare the file
* with itself, so only the vignette-summary assertions below run in that case.
local r_ok = 0
tempfile r_dep_ok r_run_ok
if "`fixsrc'" == "regenerated" {
    local r_ok = 1
    local refdir `"`regen_dir'"'
}
else {
    capture erase "`r_dep_ok'"
    shell Rscript -e "quit(status=ifelse(requireNamespace('twang', quietly=TRUE), 0, 1))" > /dev/null 2>&1 && touch "`r_dep_ok'"
    capture confirm file "`r_dep_ok'"
    if !_rc local r_ok = 1
}

if `r_ok' {
    capture noisily {
        if "`fixsrc'" != "regenerated" {
            capture mkdir "`refdir'"
            capture erase "`r_run_ok'"
            shell Rscript "`qa_dir'/_multigroup_reference_twang.R" "`refdir'" && touch "`r_run_ok'"
            confirm file "`r_run_ok'"
        }
        confirm file "`refdir'/aod_twang_ate_weights.csv"
        confirm file "`refdir'/twang_summary_regen.csv"

        import delimited using "`refdir'/twang_summary_regen.csv", ///
            varnames(1) stringcols(_all) clear
        forvalues i = 1/`=_N' {
            local key = key[`i']
            local rv_`key' = value[`i']
        }
        * the vignette is twang 2.6.2; a different version may legitimately move
        * the GBM fit, so only that version is pinned
        if "`rv_twang_version'" != "2.6.2" {
            display as text "twang `rv_twang_version' != 2.6.2: regeneration pin not applicable"
            exit 77
        }
        * regenerated summary() equals the printed vignette values (8 digits)
        assert abs(real("`rv_msd_unw'") - 0.20266446) <= 1e-8
        assert abs(real("`rv_msd_es'") - 0.06494694) <= 1e-8
        assert abs(real("`rv_msd_ks'") - 0.07219687) <= 1e-8
        assert abs(real("`rv_mks_unw'") - 0.13) <= 1e-8
        assert abs(real("`rv_mks_es'") - 0.06650091) <= 1e-8
        assert abs(real("`rv_mks_ks'") - 0.06526362) <= 1e-8

        if "`fixsrc'" == "regenerated" {
            display as text "fixture is the regenerated file: byte-identical to the recorded original (length and CRC verified), not compared with itself"
        }
        else {
        * regenerated data and weights equal the frozen fixture row for row
        import delimited using "`refdir'/aod_twang_ate_weights.csv", ///
            varnames(1) asdouble clear
        rename (treat tnum illact crimjust subprob subdep white w_es w_ks) ///
            (r_treat r_tnum r_illact r_crimjust r_subprob r_subdep r_white r_es r_ks)
        generate long ord = _n
        tempfile regen
        save "`regen'", replace
        import delimited using "`fixture'", varnames(1) asdouble clear
        generate long ord = _n
        merge 1:1 ord using "`regen'", assert(match) nogenerate
        assert _N == 600
        assert !missing(w_es, r_es, w_ks, r_ks)
        assert abs(w_es - r_es) < 1e-6
        assert abs(w_ks - r_ks) < 1e-6
        assert treat == r_treat & tnum == r_tnum
        foreach v in illact crimjust subprob subdep white {
            assert !missing(`v', r_`v')
            assert abs(`v' - r_`v') < 1e-12
        }
        }
    }
    _psdash_mgp_record twang_regeneration_matches_fixture `=_rc'
}
else {
    display as text "SKIP (dependency): Rscript or twang unavailable; regeneration guard not run"
    _psdash_mgp_record twang_regeneration_matches_fixture 77
}

**# Summary

display as text "RESULT: crossval_multigroup_published_twang tests=$PSDASH_MGP_TESTS pass=$PSDASH_MGP_PASS fail=$PSDASH_MGP_FAIL skip=$PSDASH_MGP_SKIP"

local final_fail = $PSDASH_MGP_FAIL
local failed "$PSDASH_MGP_FAILED"
macro drop PSDASH_MGP_TESTS PSDASH_MGP_PASS PSDASH_MGP_FAIL PSDASH_MGP_SKIP PSDASH_MGP_FAILED
_psdash_qa_cleanup
capture shell rm -rf "`refdir'"
capture log close _all

if `final_fail' {
    display as error "Failed tests:`failed'"
    exit 9
}
