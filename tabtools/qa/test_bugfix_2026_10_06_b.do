* test_bugfix_2026_10_06_b.do - desctab two-group test provenance and the
* desctab smdtype()/smdpair()/nosmallcells/cellreplace surfaces
*
* Bug 1.3 (2026-10-06 report): the two-group t row took its p-value and df
* from a separate anova fit, and no fit's e(sample) was compared with the
* tabulated sample. Fixed: the label, t, df and p come from one regress fit
* weighted by the materialized weight variable, with a two-directional
* e(sample) check.
*
* Gaps 3.1/3.2: desctab smdtype() (pair, population, maxpair), smdpair(),
* nosmallcells, and r(smdtype), r(smdnote), r(n_cellreplace) had no
* value-checking assertions. The SMD oracles are computed here from
* summarize output (McCaffrey et al. 2013 eq. 5 and sec. 4.2 for population;
* Lopez and Gutman 2017 eq. 27 for maxpair; Yang and Dalton 2012 for pair)
* and from hand-derived constants on a nine-row fixture.
*
* Run from tabtools/qa.

clear all
version 17.0
set more off
set varabbrev off

capture log close _bfb
log using "test_bugfix_2026_10_06_b.log", replace text name(_bfb)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local pass_count = 0
local fail_count = 0
local test_count = 0
tempfile outtoken

* _b_cell FRAME FACTOR VAR: r(s) = string value of VAR on the row whose
* trimmed factor label is FACTOR (exactly one such row).
capture program drop _b_cell
program define _b_cell, rclass
    version 17.0
    args fr fac var
    frame `fr' {
        tempvar rn
        quietly generate long `rn' = _n if strtrim(factor) == `"`fac'"'
        quietly summarize `rn'
        if r(N) != 1 {
            display as error `"row `fac' found `=r(N)' times"'
            exit 9
        }
        local r = r(min)
        return local s = strtrim(`var'[`r'])
    }
end

* _b_fmt X: r(s) = X as display %6.2f formats it (desctab's statistic text)
capture program drop _b_fmt
program define _b_fmt, rclass
    version 17.0
    args x
    local s : display %6.2f `x'
    return local s "`s'"
end

* _b_grep FILE TEXT: exit 9 unless FILE contains TEXT (literal)
capture program drop _b_grep
program define _b_grep
    version 17.0
    args file text
    mata: st_local("_hit", strofreal(any(strpos(cat(st_local("file")), st_local("text")))))
    if !`_hit' exit 9
end

* _b_smd_oracle: population and maxpair SMD for one variable by group,
* from summarize. args: var by kind(cont|bin). Returns r(pop), r(maxpair),
* r(pair12) (first two groups) as scalars.
capture program drop _b_smd_oracle
program define _b_smd_oracle, rclass
    version 17.0
    args v by kind
    quietly levelsof `by' if !missing(`v') & !missing(`by'), local(lv)
    local K : word count `lv'
    quietly summarize `v' if !missing(`by')
    local mp = r(mean)
    local sdp = r(sd)
    if "`kind'" == "bin" local sdp = sqrt(`mp' * (1 - `mp'))
    local k 0
    local sumvar 0
    local maxpop 0
    foreach g of local lv {
        local ++k
        quietly summarize `v' if `by' == `g'
        local m`k' = r(mean)
        local var`k' = cond("`kind'" == "bin", r(mean) * (1 - r(mean)), r(Var))
        local sumvar = `sumvar' + `var`k''
        local maxpop = max(`maxpop', abs(`m`k'' - `mp') / `sdp')
    }
    local den = sqrt(`sumvar' / `K')
    local maxdiff 0
    forvalues a = 1/`K' {
        forvalues b = `=`a'+1'/`K' {
            local maxdiff = max(`maxdiff', abs(`m`a'' - `m`b''))
        }
    }
    return scalar pop = `maxpop'
    return scalar maxpair = `maxdiff' / `den'
    return scalar pair12 = abs(`m1' - `m2') / sqrt((`var1' + `var2') / 2)
end

tabtools set clear

**# T1 two-group t row against ttest (equal variance), unweighted and if
local ++test_count
capture noisily {
    sysuse auto, clear
    foreach spec in "price contn" "mpg contn" "mpg contln" "weight contln" {
        gettoken v typ : spec
        local typ = strtrim("`typ'")
        foreach cond in "" "if rep78 < ." {
            sysuse auto, clear
            desctab `v' `cond', by(foreign) vars(`v' `typ' %9.2f) test statistic ///
                frame(_bf1, replace)
            matrix _T = r(table)
            local pdt = _T[1, colnumb(_T, "p_value")]
            tempvar y
            if "`typ'" == "contln" quietly generate double `y' = ln(`v')
            else quietly generate double `y' = `v'
            quietly ttest `y' `cond', by(foreign)
            local tt = r(t)
            local dft = r(df_t)
            assert !missing(`pdt') & !missing(r(p))
            assert reldif(`pdt', r(p)) < 1e-9
            local vlab : variable label `v'
            _b_cell _bf1 `"`vlab'"' statistic
            local stat "`r(s)'"
            _b_fmt `tt'
            local want = strtrim("t(`dft')=`r(s)'")
            assert "`stat'" == "`want'"
            _b_cell _bf1 `"`vlab'"' test
            local lab = cond("`typ'" == "contln", "Ind. t test, logged data", "Ind. t test")
            assert "`r(s)'" == "`lab'"
        }
    }
    frame drop _bf1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T1 t, df, p and label agree with ttest"
}
else {
    local ++fail_count
    display as error "  FAIL: T1 t-test oracle (rc=`=_rc')"
}

**# T2 frequency weights, zero weights, missing test values vs expand + ttest
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 20261006
    generate int w = ceil(runiform() * 4)
    replace w = 0 in 1/5
    replace price = . in 20/24
    desctab price mpg [fw=w], by(foreign) vars(price contn %9.1f \ mpg contln %9.2f) ///
        test statistic frame(_bf2, replace)
    matrix _T = r(table)
    preserve
    drop if w == 0
    expand w
    generate double lmpg = ln(mpg)
    quietly ttest price, by(foreign)
    local t1 = r(t)
    local d1 = r(df_t)
    local p1 = r(p)
    quietly ttest lmpg, by(foreign)
    local t2 = r(t)
    local d2 = r(df_t)
    local p2 = r(p)
    restore
    assert !missing(_T[1, 1]) & !missing(`p1')
    assert reldif(_T[1, 1], `p1') < 1e-9
    assert !missing(_T[2, 1]) & !missing(`p2')
    assert reldif(_T[2, 1], `p2') < 1e-9
    _b_fmt `t1'
    local want1 = strtrim("t(`d1')=`r(s)'")
    _b_fmt `t2'
    local want2 = strtrim("t(`d2')=`r(s)'")
    _b_cell _bf2 Price statistic
    assert "`r(s)'" == "`want1'"
    _b_cell _bf2 "Mileage (mpg)" statistic
    assert "`r(s)'" == "`want2'"
    frame drop _bf2
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T2 fweight t row equals expanded-data ttest"
}
else {
    local ++fail_count
    display as error "  FAIL: T2 weighted t-test oracle (rc=`=_rc')"
}

**# T3 a random weight expression is materialized once: df and p follow the table
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 11
    desctab price [fw=floor(runiform() * 3) + 1], by(foreign) ///
        vars(price contn %9.1f) test statistic frame(_bf3, replace)
    matrix _T = r(table)
    local pdt = _T[1, 1]
    _b_cell _bf3 "Mean±SD" foreign_0
    local n0 = real(subinstr("`r(s)'", "N=", "", 1))
    _b_cell _bf3 "Mean±SD" foreign_1
    local n1 = real(subinstr("`r(s)'", "N=", "", 1))
    assert `n0' < . & `n1' < .
    _b_cell _bf3 Price statistic
    local stat "`r(s)'"
    * t(df)= t: df is the tabulated weighted N less two
    local df = `n0' + `n1' - 2
    assert substr("`stat'", 1, length("t(`df')=")) == "t(`df')="
    * p is the two-sided p of the printed t, to the printed rounding
    local tprt = real(substr("`stat'", strpos("`stat'", "=") + 1, .))
    assert `pdt' >= 2 * ttail(`df', abs(`tprt') + 0.005) - 1e-12
    assert `pdt' <= 2 * ttail(`df', max(abs(`tprt') - 0.005, 0)) + 1e-12
    frame drop _bf3
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T3 df and p come from the tabulated weights"
}
else {
    local ++fail_count
    display as error "  FAIL: T3 materialized weight (rc=`=_rc')"
}

**# T4 three-group ANOVA row against oneway, unweighted and fweight
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 4
    generate int w = ceil(runiform() * 3)
    quietly generate byte g3 = cond(rep78 <= 3, 0, cond(rep78 == 4, 1, 2)) if rep78 < .
    foreach wspec in "" "[fw=w]" {
        desctab price mpg `wspec', by(g3) vars(price contn %9.1f \ mpg contln %9.2f) ///
            test statistic frame(_bf4, replace)
        matrix _T = r(table)
        quietly oneway price g3 `wspec'
        local F1 = r(F)
        local d1m = r(df_m)
        local d1r = r(df_r)
        assert !missing(_T[1, 1]) & !missing(Ftail(`d1m', `d1r', `F1'))
        assert reldif(_T[1, 1], Ftail(`d1m', `d1r', `F1')) < 1e-9
        _b_fmt `F1'
        local wantF = strtrim("F(`d1m',`d1r')=`r(s)'")
        _b_cell _bf4 Price statistic
        assert "`r(s)'" == "`wantF'"
        _b_cell _bf4 Price test
        assert "`r(s)'" == "ANOVA"
        quietly generate double lm = ln(mpg)
        quietly oneway lm g3 `wspec'
        assert !missing(_T[2, 1]) & !missing(Ftail(r(df_m), r(df_r), r(F)))
        assert reldif(_T[2, 1], Ftail(r(df_m), r(df_r), r(F))) < 1e-9
        _b_cell _bf4 "Mileage (mpg)" test
        assert "`r(s)'" == "ANOVA, logged data"
        drop lm
    }
    frame drop _bf4
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T4 ANOVA row agrees with oneway"
}
else {
    local ++fail_count
    display as error "  FAIL: T4 ANOVA oracle (rc=`=_rc')"
}

**# T5 degenerate two-group shapes keep the 2.5.1 row and publish no p
local ++test_count
capture noisily {
    clear
    quietly set obs 2
    generate byte g = _n - 1
    generate double x = _n * 2.5
    desctab x, by(g) vars(x contn %9.2f) test statistic frame(_bf5, replace)
    matrix _T = r(table)
    assert missing(_T[1, 1])
    _b_cell _bf5 x statistic
    assert "`r(s)'" == "t(0)=     ."
    clear
    quietly set obs 12
    generate byte g = _n > 6
    generate double x = 3
    desctab x, by(g) vars(x contn %9.2f) test statistic frame(_bf5, replace)
    matrix _T = r(table)
    assert missing(_T[1, 1])
    _b_cell _bf5 x statistic
    assert "`r(s)'" == "t(10)=     ."
    frame drop _bf5
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T5 degenerate t rows keep df and publish a missing p"
}
else {
    local ++fail_count
    display as error "  FAIL: T5 degenerate shapes (rc=`=_rc')"
}

**# T6 smdtype() and smdpair() against hand-derived constants
* g: A 1,2,3 / B 3,4,5 / C 5,6,7 ; sex: A 0,0,1 / B 0,1,1 / C 1,1,1
* x: group means 2,4,6, every group variance 1, overall mean 4, overall
*    variance 30/8, so pair(A,B)=2, population=2/sqrt(3.75), maxpair=4/1
* sex: p = 1/3, 2/3, 1; overall p = 2/3, sd_pop = sqrt(2/9)
*    pair(A,B) = (1/3)/sqrt(2/9); population = (1/3)/sqrt(2/9);
*    maxpair = (2/3)/sqrt(mean(2/9, 2/9, 0)); pair(C,A) = (2/3)/sqrt(1/9)
local ++test_count
capture noisily {
    clear
    input byte g byte x byte sex
    0 1 0
    0 2 0
    0 3 1
    1 3 0
    1 4 1
    1 5 1
    2 5 1
    2 6 1
    2 7 1
    end
    label define _bgl 0 "A" 1 "B" 2 "C"
    label values g _bgl
    local sqrt3 = sqrt(3.75)
    * default: pair of the first two groups
    desctab x sex, by(g) vars(x contn %9.2f \ sex bin) smd nopvalue frame(_bf6, replace)
    assert "`r(smdtype)'" == "pair"
    assert `"`r(smdnote)'"' == "SMD compares A vs B only (the first two of 3 groups)."
    matrix _S = r(table)
    local cn : colnames _S
    assert "`cn'" == "smd"
    assert !missing(_S[1, 1]) & !missing(2)
    assert reldif(_S[1, 1], 2) < 1e-12
    assert !missing(_S[2, 1]) & !missing((1/3) / sqrt(2/9))
    assert reldif(_S[2, 1], (1/3) / sqrt(2/9)) < 1e-12
    frame _bf6: local _lb : variable label smd_str
    assert "`_lb'" == "SMD (A vs B)"
    * population
    desctab x sex, by(g) vars(x contn %9.2f \ sex bin) smd smdtype(population) ///
        nopvalue frame(_bf6, replace)
    assert "`r(smdtype)'" == "population"
    assert `"`r(smdnote)'"' == "Pop. SB: largest absolute difference between a group mean and the overall mean, in overall-sample SDs, across the 3 groups (McCaffrey et al. 2013)."
    matrix _S = r(table)
    assert !missing(_S[1, 1]) & !missing(2 / `sqrt3')
    assert reldif(_S[1, 1], 2 / `sqrt3') < 1e-12
    assert !missing(_S[2, 1]) & !missing((1/3) / sqrt(2/9))
    assert reldif(_S[2, 1], (1/3) / sqrt(2/9)) < 1e-12
    frame _bf6: local _lb : variable label smd_str
    assert "`_lb'" == "Pop. SB"
    _b_cell _bf6 x smd_str
    assert "`r(s)'" == "1.033"
    * maxpair
    desctab x sex, by(g) vars(x contn %9.2f \ sex bin) smd smdtype(maxpair) ///
        nopvalue frame(_bf6, replace)
    assert "`r(smdtype)'" == "maxpair"
    assert `"`r(smdnote)'"' == "Max SMD: largest absolute pairwise difference across the 3 groups, in the root-mean of the group variances."
    matrix _S = r(table)
    assert !missing(_S[1, 1]) & !missing(4)
    assert reldif(_S[1, 1], 4) < 1e-12
    assert !missing(_S[2, 1]) & !missing((2/3) / sqrt((2/9 + 2/9 + 0) / 3))
    assert reldif(_S[2, 1], (2/3) / sqrt((2/9 + 2/9 + 0) / 3)) < 1e-12
    frame _bf6: local _lb : variable label smd_str
    assert "`_lb'" == "Max SMD"
    * smdpair() picks C vs A (order given), also with an explicit smdtype(pair)
    foreach extra in "" "smdtype(pair)" {
        desctab x sex, by(g) vars(x contn %9.2f \ sex bin) smd smdpair(C A) `extra' ///
            nopvalue frame(_bf6, replace)
        assert "`r(smdtype)'" == "pair"
        assert `"`r(smdnote)'"' == "SMD compares C vs A only (2 of 3 groups, chosen with smdpair())."
        matrix _S = r(table)
        assert !missing(_S[1, 1]) & !missing(4)
        assert reldif(_S[1, 1], 4) < 1e-12
        assert !missing(_S[2, 1]) & !missing((2/3) / sqrt(1/9))
        assert reldif(_S[2, 1], (2/3) / sqrt(1/9)) < 1e-12
        frame _bf6: local _lb : variable label smd_str
        assert "`_lb'" == "SMD (C vs A)"
    }
    * two groups: pair, no note; the type is still returned
    desctab x sex if g < 2, by(g) vars(x contn %9.2f \ sex bin) smd nopvalue
    assert "`r(smdtype)'" == "pair"
    assert `"`r(smdnote)'"' == ""
    matrix _S = r(table)
    assert !missing(_S[1, 1]) & !missing(2)
    assert reldif(_S[1, 1], 2) < 1e-12
    * without smd neither result is posted
    desctab x sex, by(g) vars(x contn %9.2f \ sex bin) nopvalue
    assert "`r(smdtype)'" == ""
    assert `"`r(smdnote)'"' == ""
    frame drop _bf6
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T6 smdtype/smdpair values, header, r(smdtype), r(smdnote)"
}
else {
    local ++fail_count
    display as error "  FAIL: T6 SMD constants (rc=`=_rc')"
}

**# T7 smdtype()/smdpair() on unequal groups against a summarize-based oracle
local ++test_count
capture noisily {
    sysuse auto, clear
    generate byte hi = trunk >= 9
    * five rep78 groups of 2, 8, 30, 18 and 11 cars; hi is binary
    _b_smd_oracle mpg rep78 cont
    local mpg_pop = r(pop)
    local mpg_max = r(maxpair)
    local mpg_p12 = r(pair12)
    _b_smd_oracle hi rep78 bin
    local for_pop = r(pop)
    local for_max = r(maxpair)
    local for_p12 = r(pair12)
    desctab mpg hi, by(rep78) vars(mpg contn %9.2f \ hi bin) smd nopvalue
    assert "`r(smdtype)'" == "pair"
    matrix _S = r(table)
    assert !missing(_S[1, 1]) & !missing(`mpg_p12')
    assert reldif(_S[1, 1], `mpg_p12') < 1e-9
    assert !missing(_S[2, 1]) & !missing(`for_p12')
    assert reldif(_S[2, 1], `for_p12') < 1e-9
    desctab mpg hi, by(rep78) vars(mpg contn %9.2f \ hi bin) smd ///
        smdtype(population) nopvalue
    matrix _S = r(table)
    assert !missing(_S[1, 1]) & !missing(`mpg_pop')
    assert reldif(_S[1, 1], `mpg_pop') < 1e-9
    assert !missing(_S[2, 1]) & !missing(`for_pop')
    assert reldif(_S[2, 1], `for_pop') < 1e-9
    assert `"`r(smdnote)'"' == "Pop. SB: largest absolute difference between a group mean and the overall mean, in overall-sample SDs, across the 5 groups (McCaffrey et al. 2013)."
    desctab mpg hi, by(rep78) vars(mpg contn %9.2f \ hi bin) smd ///
        smdtype(maxpair) nopvalue
    matrix _S = r(table)
    assert !missing(_S[1, 1]) & !missing(`mpg_max')
    assert reldif(_S[1, 1], `mpg_max') < 1e-9
    assert !missing(_S[2, 1]) & !missing(`for_max')
    assert reldif(_S[2, 1], `for_max') < 1e-9
    * smdpair(3 5): groups 3 and 5 by hand from summarize
    quietly summarize mpg if rep78 == 3
    local m3 = r(mean)
    local v3 = r(Var)
    quietly summarize mpg if rep78 == 5
    local m5 = r(mean)
    local v5 = r(Var)
    quietly summarize hi if rep78 == 3
    local q3 = r(mean)
    quietly summarize hi if rep78 == 5
    local q5 = r(mean)
    desctab mpg hi, by(rep78) vars(mpg contn %9.2f \ hi bin) smd ///
        smdpair(3 5) nopvalue
    matrix _S = r(table)
    assert !missing(_S[1, 1]) & !missing(abs(`m3' - `m5') / sqrt((`v3' + `v5') / 2))
    assert reldif(_S[1, 1], abs(`m3' - `m5') / sqrt((`v3' + `v5') / 2)) < 1e-9
    assert !missing(_S[2, 1]) & !missing(abs(`q3' - `q5') / sqrt((`q3' * (1 - `q3') + `q5' * (1 - `q5')) / 2))
    assert reldif(_S[2, 1], abs(`q3' - `q5') / sqrt((`q3' * (1 - `q3') + `q5' * (1 - `q5')) / 2)) < 1e-9
    assert `"`r(smdnote)'"' == "SMD compares 3 vs 5 only (2 of 5 groups, chosen with smdpair())."
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T7 smdtype/smdpair match summarize-based oracle on five groups"
}
else {
    local ++fail_count
    display as error "  FAIL: T7 SMD oracle (rc=`=_rc')"
}

**# T8 smdtype()/smdpair() refusals
local ++test_count
capture noisily {
    sysuse auto, clear
    capture desctab mpg, by(rep78) vars(mpg contn) smdtype(population)
    assert _rc == 198
    capture desctab mpg, by(rep78) vars(mpg contn) smd smdtype(bogus)
    assert _rc == 198
    capture desctab mpg, by(rep78) vars(mpg contn) smd smdtype(population) smdpair(3 5)
    assert _rc == 198
    capture desctab mpg, by(rep78) vars(mpg contn) smd smdpair(3 9)
    assert _rc == 198
    capture desctab mpg, by(rep78) vars(mpg contn) smd smdpair(3)
    assert _rc == 198
    * a refused call leaves no stale return
    assert "`r(smdtype)'" == ""
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T8 smdtype()/smdpair() refusals"
}
else {
    local ++fail_count
    display as error "  FAIL: T8 SMD refusals (rc=`=_rc')"
}

**# T9 nosmallcells overrides the session default; smallcells() conflicts
local ++test_count
capture noisily {
    clear
    input byte g byte x byte sex
    0 1 0
    0 2 0
    0 3 1
    1 3 0
    1 4 1
    1 5 1
    2 5 1
    2 6 1
    2 7 1
    end
    tabtools set smallcells 5
    * session default masks all three groups (N=3 < 5) and echoes itself
    local lg "`c(tmpdir)'/_bfb_sc_on.log"
    capture log close _bfsc
    log using "`lg'", replace text name(_bfsc)
    desctab x sex, by(g) vars(x contn %9.2f \ sex bin) nopvalue frame(_bf9, replace)
    local _k = r(smallcells)
    local _np = r(N_primary_suppressed)
    capture confirm matrix r(suppression)
    local _zon = _rc
    matrix _Z = r(suppression)
    log close _bfsc
    assert `_zon' == 0
    assert `_k' == 5
    assert `_np' == 9
    assert rowsof(_Z) == 4
    _b_grep "`lg'" "(tabtools: using session smallcells(5))"
    _b_cell _bf9 sex g_0
    assert "`r(s)'" == "<5"
    * nosmallcells: exact cells, no suppression results, no echo
    local lg "`c(tmpdir)'/_bfb_sc_off.log"
    capture log close _bfsc
    log using "`lg'", replace text name(_bfsc)
    desctab x sex, by(g) vars(x contn %9.2f \ sex bin) nopvalue nosmallcells ///
        frame(_bf9, replace)
    local _k = r(smallcells)
    local _np = r(N_primary_suppressed)
    capture confirm matrix r(suppression)
    local _zrc = _rc
    log close _bfsc
    assert missing(`_k')
    assert missing(`_np')
    assert `_zrc' != 0
    capture _b_grep "`lg'" "using session smallcells"
    assert _rc == 9
    _b_cell _bf9 sex g_0
    assert "`r(s)'" == "1 (33)"
    _b_cell _bf9 x g_2
    assert "`r(s)'" == "6.00±1.00"
    _b_cell _bf9 "No. (Column %) or Mean±SD" g_1
    assert "`r(s)'" == "N=3"
    * conflict with an explicit threshold
    capture desctab x sex, by(g) vars(x contn \ sex bin) smallcells(5) nosmallcells
    assert _rc == 198
    * explicit smallcells() still works alongside the session default
    desctab x sex, by(g) vars(x contn %9.2f \ sex bin) nopvalue smallcells(4) ///
        frame(_bf9, replace)
    assert r(smallcells) == 4
    frame drop _bf9
}
local _rc9 = _rc
tabtools set clear
if `_rc9' == 0 {
    local ++pass_count
    display as result "  PASS: T9 nosmallcells overrides the session threshold"
}
else {
    local ++fail_count
    display as error "  FAIL: T9 nosmallcells (rc=`_rc9')"
}

**# T10 r(n_cellreplace) counts the replaced cells
local ++test_count
capture noisily {
    clear
    input byte g byte x byte sex
    0 1 0
    0 2 0
    0 3 1
    1 3 0
    1 4 1
    1 5 1
    end
    desctab x sex, by(g) vars(x contn %9.2f \ sex bin) nopvalue frame(_bf10, replace)
    assert missing(r(n_cellreplace))
    desctab x sex, by(g) vars(x contn %9.2f \ sex bin) nopvalue ///
        cellreplace("sex" 1 "n/a") frame(_bf10, replace)
    assert r(n_cellreplace) == 1
    _b_cell _bf10 sex g_0
    assert "`r(s)'" == "n/a"
    _b_cell _bf10 sex g_1
    assert "`r(s)'" == "2 (67)"
    desctab x sex, by(g) vars(x contn %9.2f \ sex bin) nopvalue ///
        cellreplace("sex" 1 "n/a" \ "x" 2 "none" \ "sex" 2 "n/a") frame(_bf10, replace)
    assert r(n_cellreplace) == 3
    _b_cell _bf10 x g_1
    assert "`r(s)'" == "none"
    _b_cell _bf10 sex g_1
    assert "`r(s)'" == "n/a"
    _b_cell _bf10 x g_0
    assert "`r(s)'" == "2.00±1.00"
    * a spec that names no row is refused and posts nothing
    capture desctab x sex, by(g) vars(x contn \ sex bin) nopvalue ///
        cellreplace("nothing" 1 "n/a")
    assert _rc == 198
    assert missing(r(n_cellreplace))
    frame drop _bf10
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T10 r(n_cellreplace)"
}
else {
    local ++fail_count
    display as error "  FAIL: T10 n_cellreplace (rc=`=_rc')"
}

tabtools set clear
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
local pf = `pass_count' + `fail_count'
assert `pf' == `test_count'
display "RESULT: test_bugfix_2026_10_06_b tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _bfb
if `fail_count' > 0 exit 1
