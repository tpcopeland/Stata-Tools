*! test_eplot_v142.do - Regression tests for eplot 1.4.2
*! Covers matrix row-stripe identity (spaces, repeated names), returned-result
*! existence, zero-variance vs tiny-variance coefficients, parameter-specific
*! degrees of freedom, weighted-box scale under sigcolors, eform axis titles
*! from e(cmd2), the null() sentinel, estimates-mode console noise, and
*! drawn colors (multi-model mcolor()/cicolor(), RGB colors in every mode).

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_eplot_v142.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

* Posts b, V and an optional parameter-specific df vector so the df route
* can be checked against hand-computed t intervals.
capture program drop _v142_post
program define _v142_post, eclass
    version 16.0
    syntax, B(name) V(name) [DOF(real 0) DFMI(name)]
    tempname bb VV
    matrix `bb' = `b'
    matrix `VV' = `v'
    if `dof' > 0 ereturn post `bb' `VV', dof(`dof')
    else ereturn post `bb' `VV'
    if "`dfmi'" != "" {
        tempname dd
        matrix `dd' = `dfmi'
        ereturn matrix df_mi = `dd'
    }
    ereturn local cmd "v142fake"
end

* Resolved RGB of plot layer i of graph g, read from the drawn graph
* object rather than from r(cmd): "fill" is a marker fill, "line" a line.
capture program drop _v142_rgb
program define _v142_rgb, rclass
    version 16.0
    args g i kind
    if "`kind'" == "fill" {
        return local rgb "`.`g'.plotregion1.plot`i'.style.marker.fillcolor.setting'"
    }
    else {
        return local rgb "`.`g'.plotregion1.plot`i'.style.line.color.setting'"
    }
end

**# Matrix-mode row identity

**## Row names containing spaces stay on their own rows
* Pre-1.4.2 the names were split into words: row 2 (b=2) was labeled
* "group" and row 3 (b=3) "Sex", so every later label sat on the wrong effect.
local ++test_count
capture noisily {
    matrix Q = (1, .5, 1.5 \ 2, 1.5, 2.5 \ 3, 2.5, 3.5)
    matrix rownames Q = "Age group" "Sex" "BMI"
    eplot, matrix(Q) nodraw
    matrix T = r(table)
    local rn : rownames T
    assert `"`rn'"' == `"Age group Sex BMI"'
    assert rowsof(T) == 3
    assert T[1,1] == 1 & T[2,1] == 2 & T[3,1] == 3
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', `"1 `"Age group"'"') > 0
    assert strpos(`"`cmd'"', `"2 `"Sex"'"') > 0
    assert strpos(`"`cmd'"', `"3 `"BMI"'"') > 0
    assert strpos(`"`cmd'"', `"`"group"'"') == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**## Repeated row names keep their equation prefix and are selectable
local ++test_count
capture noisily {
    matrix M = (0.09, 0.06 \ -2.35, 1.30 \ 0.24, 0.07 \ -6.39, 1.80)
    matrix rownames M = mpg _cons mpg _cons
    matrix roweq M = 4 4 5 5
    eplot, matrix(M) nodraw
    matrix T = r(table)
    local rn : rowfullnames T
    assert `"`rn'"' == "4:mpg 4:_cons 5:mpg 5:_cons"
    eplot, matrix(M) nodraw keep(5:mpg)
    matrix T = r(table)
    assert rowsof(T) == 1
    local rn : rowfullnames T
    assert "`rn'" == "5:mpg"
    assert T[1,1] == M[3,1]
    * Unique names keep the short form, as in estimates mode.
    matrix U = (1, .2 \ 2, .3)
    matrix rownames U = x z
    matrix roweq U = a b
    eplot, matrix(U) nodraw keep(z)
    matrix T = r(table)
    assert rowsof(T) == 1 & T[1,1] == 2
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# Returned-result existence

**## r(pvalues) is absent whenever no p-values exist
* Pre-1.4.2 every mode posted a 1 x 1 missing r(pvalues) because
* `matrix X = r(pvalues)' succeeds when r(pvalues) does not exist.
local ++test_count
capture noisily {
    clear
    input str4 lab double(es lci uci)
    "A" 0.1 -0.1 0.3
    "B" 0.2 0.0 0.4
    end
    eplot es lci uci, labels(lab) nodraw
    local m : r(matrices)
    assert "`m'" == "table"

    matrix R = (1, .5, 1.5 \ 2, 1.5, 2.5)
    eplot, matrix(R) nodraw
    local m : r(matrices)
    assert "`m'" == "table"

    frame put lab es lci uci, into(v142_f)
    frame v142_f: rename (lab es lci uci) (label estimate ll ul)
    eplot, frame(v142_f) nodraw
    local m : r(matrices)
    assert "`m'" == "table"
    frame drop v142_f

    sysuse auto, clear
    quietly regress price mpg weight
    estimates store v142_a
    quietly regress price mpg weight length
    estimates store v142_b
    eplot v142_a v142_b, noconstant nodraw
    local m : r(matrices)
    assert "`m'" == "table"
    estimates drop v142_a v142_b

    * Where p-values do exist they are still returned.
    quietly regress price mpg weight
    eplot ., noconstant nodraw
    local m : r(matrices)
    assert `: list posof "pvalues" in m' > 0
    assert rowsof(r(pvalues)) == 2
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}
capture frame drop v142_f

**## A failed call posts no r() results
local ++test_count
capture noisily {
    clear
    input str4 lab double(es lci uci) str8 t
    "A" 0.1 -0.1 0.3 "bogus"
    end
    capture eplot es lci uci, labels(lab) type(t) nodraw
    assert _rc == 198
    local s : r(scalars)
    local m : r(matrices)
    local mc : r(macros)
    assert "`s'" == ""
    assert "`m'" == ""
    assert "`mc'" == ""
    capture eplot, frame(v142_nosuch) nodraw
    assert _rc == 111
    local s : r(scalars)
    assert "`s'" == ""
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**# Coefficient selection by variance

**## A tiny but positive standard error is plotted
* Pre-1.4.2 any coefficient with SE < 1e-15 was skipped as if omitted.
local ++test_count
capture noisily {
    clear
    set seed 14201
    set obs 200
    gen double x = rnormal() * 1e15
    gen double z = rnormal()
    gen double y = 2e-15 * x + z + rnormal()
    quietly regress y x z
    matrix b = e(b)
    matrix V = e(V)
    local df = e(df_r)
    assert sqrt(V[1,1]) < 1e-15
    eplot ., noconstant nodraw
    assert r(k) == 2
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "x z"
    local crit = invttail(`df', 0.025)
    assert !missing(T[1,2], b[1,1])
    assert T[1,1] == b[1,1]
    assert !missing(T[1,2], b[1,1] - `crit' * sqrt(V[1,1]))
    assert reldif(T[1,2], b[1,1] - `crit' * sqrt(V[1,1])) < 1e-12
    assert !missing(T[1,3], b[1,1] + `crit' * sqrt(V[1,1]))
    assert reldif(T[1,3], b[1,1] + `crit' * sqrt(V[1,1])) < 1e-12
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**## Base and omitted terms (exactly zero variance) are still dropped
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg i.rep78
    matrix b = e(b)
    matrix V = e(V)
    * Column 2 is the 1b.rep78 base level with exactly zero variance.
    assert V[2,2] == 0
    eplot ., noconstant nodraw
    matrix T = r(table)
    assert r(k) == 5
    assert rowsof(T) == 5
    assert T[1,1] == b[1,1]
    forvalues j = 3/6 {
        assert T[`j' - 1, 1] == b[1, `j']
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

**# Parameter-specific degrees of freedom

**## e(df_mi) with a matching stripe sets each coefficient's t reference
local ++test_count
capture noisily {
    matrix b0 = (1.5, -0.4)
    matrix colnames b0 = x1 x2
    matrix V0 = (0.25, 0 \ 0, 0.09)
    matrix colnames V0 = x1 x2
    matrix rownames V0 = x1 x2
    matrix D0 = (5, 60)
    matrix colnames D0 = x1 x2
    _v142_post, b(b0) v(V0) dof(200) dfmi(D0)
    eplot ., nodraw
    matrix T = r(table)
    matrix P = r(pvalues)
    assert !missing(T[1,2], 1.5 - invttail(5, 0.025) * 0.5)
    assert reldif(T[1,2], 1.5 - invttail(5, 0.025) * 0.5) < 1e-12
    assert !missing(T[1,3], 1.5 + invttail(5, 0.025) * 0.5)
    assert reldif(T[1,3], 1.5 + invttail(5, 0.025) * 0.5) < 1e-12
    assert !missing(T[2,2], -0.4 - invttail(60, 0.025) * 0.3)
    assert reldif(T[2,2], -0.4 - invttail(60, 0.025) * 0.3) < 1e-12
    assert !missing(P[1,1], 2 * ttail(5, 1.5 / 0.5))
    assert reldif(P[1,1], 2 * ttail(5, 1.5 / 0.5)) < 1e-12
    assert !missing(P[2,1], 2 * ttail(60, 0.4 / 0.3))
    assert reldif(P[2,1], 2 * ttail(60, 0.4 / 0.3)) < 1e-12

    * A df vector whose stripe does not match e(b) is not trusted: the
    * model-wide e(df_r) applies instead.
    matrix colnames D0 = x2 x1
    _v142_post, b(b0) v(V0) dof(200) dfmi(D0)
    eplot ., nodraw
    matrix T = r(table)
    assert !missing(T[1,2], 1.5 - invttail(200, 0.025) * 0.5)
    assert reldif(T[1,2], 1.5 - invttail(200, 0.025) * 0.5) < 1e-12
    assert !missing(T[2,2], -0.4 - invttail(200, 0.025) * 0.3)
    assert reldif(T[2,2], -0.4 - invttail(200, 0.025) * 0.3) < 1e-12
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

**## mi estimate, post agrees with Stata's own coefficient table
* Pre-1.4.2 eplot used the complete-data e(df_r) for every coefficient,
* giving intervals narrower than mi estimate reports.
local ++test_count
capture noisily {
    sysuse auto, clear
    keep price mpg weight foreign
    set seed 14202
    replace mpg = . if runiform() < 0.35
    mi set wide
    mi register imputed mpg
    mi impute regress mpg price weight foreign, add(5) rseed(14203)
    quietly mi estimate, post: regress price mpg weight foreign
    matrix S = r(table)
    matrix Dmi = e(df_mi)
    assert !missing(Dmi[1,1], e(df_r))
    assert Dmi[1,1] < e(df_r)
    eplot ., noconstant nodraw
    matrix T = r(table)
    matrix P = r(pvalues)
    forvalues j = 1/3 {
        assert !missing(T[`j',2], S[5,`j'])
        assert reldif(T[`j',2], S[5,`j']) < 1e-10
        assert !missing(T[`j',3], S[6,`j'])
        assert reldif(T[`j',3], S[6,`j']) < 1e-10
        assert !missing(P[`j',1], S[4,`j'])
        assert reldif(P[`j',1], S[4,`j']) < 1e-10
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

**## mixed, dfmethod() agrees with Stata's own coefficient table
local ++test_count
capture noisily {
    clear
    set seed 14204
    set obs 12
    gen int id = _n
    gen double u = rnormal()
    expand 5
    bysort id: gen int t = _n
    gen double y = 1 + 0.5 * t + u + rnormal()
    foreach m in kroger satterthwaite {
        quietly mixed y t || id:, reml dfmethod(`m')
        matrix S = r(table)
        eplot ., nodraw keep(y:*)
        matrix T = r(table)
        forvalues j = 1/2 {
            assert !missing(T[`j',2], S[5,`j'])
            assert reldif(T[`j',2], S[5,`j']) < 1e-10
            assert !missing(T[`j',3], S[6,`j'])
            assert reldif(T[`j',3], S[6,`j']) < 1e-10
        }
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}

**## mi estimate without post is refused with a clear error
local ++test_count
capture noisily {
    sysuse auto, clear
    keep price mpg weight
    set seed 14205
    replace mpg = . if runiform() < 0.3
    mi set wide
    mi register imputed mpg
    mi impute regress mpg price weight, add(3) rseed(14206)
    quietly mi estimate: regress price mpg weight
    capture eplot ., nodraw
    assert _rc == 498
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}

**# Weighted boxes under sigcolors

**## Both split box layers share the overall weight range
* twoway scales weighted markers by each layer's own weight range; before
* 1.4.2 a weight-1 significant box was drawn larger than a weight-1
* non-significant box.  Each weighted layer's serset must span min..max.
local ++test_count
capture noisily {
    clear
    input str12 study double(es lci uci w)
    "Sig-small"    1.0  0.5 1.5   1
    "Insig-big"    0.2 -0.3 0.7 100
    "Insig-small"  0.1 -0.4 0.6   1
    end
    graph drop _all
    serset clear
    eplot es lci uci, labels(study) weights(w) sigcolors name(v142_w, replace)
    assert _N == 3
    * serset use renames columns, so weighted layers are identified by
    * content: column 1 holds row positions, column 2 the fixture estimates.
    * The interval layers (lower, upper, position) fail both tests.
    preserve
    local n_weighted 0
    forvalues s = 0/40 {
        capture serset set `s'
        if _rc continue
        serset use, clear
        if c(k) != 3 continue
        unab sv : _all
        tokenize `sv'
        quietly count if !missing(`1') & !inlist(`1', 1, 2, 3)
        if r(N) continue
        quietly count if !missing(`2') & !inlist(`2', 1.0, 0.2, 0.1)
        if r(N) continue
        local ++n_weighted
        summarize `3', meanonly
        assert r(min) == 1
        assert r(max) == 100
    }
    restore
    assert `n_weighted' == 2
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 11"
}
capture graph drop v142_w

**# eform axis titles

**## stcox and proportional-hazards streg are labeled hazard ratios
* stcox posts e(cmd)=cox and streg the distribution name; the user-facing
* command is in e(cmd2).
local ++test_count
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    quietly stcox age drug
    eplot ., eform nodraw
    assert strpos(`"`r(cmd)'"', "Hazard Ratio (95% CI)") > 0
    quietly streg age drug, distribution(weibull)
    eplot ., eform nodraw
    assert strpos(`"`r(cmd)'"', "Hazard Ratio (95% CI)") > 0
    * Accelerated failure time: exp(b) is a time ratio, not a hazard ratio.
    quietly streg age drug, distribution(lognormal)
    eplot ., eform nodraw
    assert strpos(`"`r(cmd)'"', "Hazard Ratio") == 0
    assert strpos(`"`r(cmd)'"', "Effect (95% CI)") > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 12"
}

**## melogit and mepoisson are labeled from e(cmd2)
local ++test_count
capture noisily {
    clear
    set seed 14207
    set obs 30
    gen int g = _n
    gen double u = rnormal() * 0.5
    expand 20
    gen double x = rnormal()
    gen byte yb = runiform() < invlogit(-0.2 + 0.6 * x + u)
    gen int yc = rpoisson(exp(0.3 + 0.4 * x + u))
    quietly melogit yb x || g:
    eplot ., eform nodraw keep(x)
    assert strpos(`"`r(cmd)'"', "Odds Ratio (95% CI)") > 0
    quietly mepoisson yc x || g:
    eplot ., eform nodraw keep(x)
    assert strpos(`"`r(cmd)'"', "IRR (95% CI)") > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 13"
}

**# null() parsing

**## null(-999) is a position, not the default sentinel
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., null(-999) noconstant nodraw
    assert strpos(`"`r(cmd)'"', "xline(-999,") > 0
    matrix R = (1, .5, 1.5)
    eplot, matrix(R) null(-999) nodraw
    assert strpos(`"`r(cmd)'"', "xline(-999,") > 0
    clear
    input double(es lci uci)
    0.1 -0.1 0.3
    end
    eplot es lci uci, null(-999) nodraw
    assert strpos(`"`r(cmd)'"', "xline(-999,") > 0
    capture eplot es lci uci, null(.) nodraw
    assert _rc == 198
    capture eplot es lci uci, null(abc) nodraw
    assert _rc == 198
    * The defaults are unchanged.
    eplot es lci uci, nodraw
    assert strpos(`"`r(cmd)'"', "xline(0,") > 0
    eplot es lci uci, eform nodraw
    assert strpos(`"`r(cmd)'"', "xline(1,") > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 14"
}

**# Console output

**## Estimates mode prints no internal postfile or keep notes
local ++test_count
capture noisily {
    tempfile noise
    sysuse auto, clear
    quietly regress price mpg weight
    log using "`noise'", text replace name(v142_noise)
    eplot ., noconstant nodraw
    log close v142_noise
    tempname fh
    local bad 0
    file open `fh' using "`noise'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "not found)") | ///
            strpos(`"`macval(line)'"', "observations deleted") {
            local bad 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `bad' == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 15"
}
capture log close v142_noise

**# values column gap

**## vgap() places the values column at a known offset
* Right edge = max(upper limit, null, last tick) = 0.3 and the span from
* the lower limit is 0.4, so the column sits at 0.3 + vgap * 0.4.
local ++test_count
capture noisily {
    clear
    input str4 lab double(es lci uci)
    "A" 0.1 -0.1 0.3
    "B" 0.2  0.0 0.25
    end
    foreach g in 0.15 0.5 {
        if "`g'" == "0.15" eplot es lci uci, labels(lab) values nodraw
        else eplot es lci uci, labels(lab) values vgap(`g') nodraw
        assert regexm(`"`r(cmd)'"', "xscale\(range\(([^ ]+) ([^)]+)\)\)")
        local xr = real(regexs(2))
        assert !missing(`xr', 0.3 + `g' * 0.4)
        assert reldif(`xr', 0.3 + `g' * 0.4) < 1e-9
    }
    capture eplot es lci uci, labels(lab) values vgap(-0.1) nodraw
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 16"
}

**# Colors in the drawn graph

**## Multi-model mcolor() and cicolor() apply to the drawn layers
* Pre-1.4.2 both options were silently ignored with several models.  Layer
* order per model is interval then marker: plots 1-2 model 1, 3-4 model 2.
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store v142_m1
    quietly regress price mpg weight length
    estimates store v142_m2

    * One color: every model's markers, and intervals by default.
    eplot v142_m1 v142_m2, noconstant mcolor(red) name(v142_c1, replace)
    foreach i in 2 4 {
        _v142_rgb v142_c1 `i' fill
        assert "`r(rgb)'" == "255 0 0"
    }
    foreach i in 1 3 {
        _v142_rgb v142_c1 `i' line
        assert "`r(rgb)'" == "255 0 0"
    }

    * One color per model for markers; one interval color for all.
    eplot v142_m1 v142_m2, noconstant mcolor(red blue) cicolor(gs10) ///
        name(v142_c2, replace)
    _v142_rgb v142_c2 2 fill
    assert "`r(rgb)'" == "255 0 0"
    _v142_rgb v142_c2 4 fill
    assert "`r(rgb)'" == "0 0 255"
    foreach i in 1 3 {
        _v142_rgb v142_c2 `i' line
        assert "`r(rgb)'" == "160 160 160"
    }

    * One interval color per model; markers keep the default palette.
    eplot v142_m1 v142_m2, noconstant cicolor(gs10 gs4) name(v142_c3, replace)
    _v142_rgb v142_c3 1 line
    assert "`r(rgb)'" == "160 160 160"
    _v142_rgb v142_c3 3 line
    assert "`r(rgb)'" == "64 64 64"
    _v142_rgb v142_c3 2 fill
    assert "`r(rgb)'" == "26 71 111"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 17"
}
capture graph drop v142_c1 v142_c2 v142_c3

**## Unusable multi-model color combinations are refused
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store v142_m1
    quietly regress price mpg weight length
    estimates store v142_m2
    capture eplot v142_m1 v142_m2, noconstant mcolor(red blue green) nodraw
    assert _rc == 198
    capture eplot v142_m1 v142_m2, noconstant cicolor(red blue green) nodraw
    assert _rc == 198
    * palette() and mcolor() both set per-model marker colors.
    capture eplot v142_m1 v142_m2, noconstant palette(navy maroon) mcolor(red) nodraw
    assert _rc == 198
    * palette() with cicolor() is a valid split: markers and intervals.
    eplot v142_m1 v142_m2, noconstant palette(red blue) cicolor(gs10) ///
        name(v142_c4, replace)
    _v142_rgb v142_c4 4 fill
    assert "`r(rgb)'" == "0 0 255"
    _v142_rgb v142_c4 3 line
    assert "`r(rgb)'" == "160 160 160"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 18"
}
capture graph drop v142_c4

**## RGB colors are drawn as specified in every mode
* Pre-1.4.2 a plain string option stripped the user's quotes and twoway read
* mcolor(0 128 0) as a list, drawing black at rc=0.
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store v142_m1
    quietly regress price mpg weight length
    estimates store v142_m2
    eplot v142_m1, noconstant mcolor("0 128 0") name(v142_r1, replace)
    _v142_rgb v142_r1 2 fill
    assert "`r(rgb)'" == "0 128 0"
    _v142_rgb v142_r1 1 line
    assert "`r(rgb)'" == "0 128 0"

    eplot v142_m1 v142_m2, noconstant mcolor("255 0 0" "0 0 255") ///
        name(v142_r2, replace)
    _v142_rgb v142_r2 2 fill
    assert "`r(rgb)'" == "255 0 0"
    _v142_rgb v142_r2 4 fill
    assert "`r(rgb)'" == "0 0 255"
    eplot v142_m1 v142_m2, noconstant palette("255 0 0" "0 0 255") ///
        name(v142_r3, replace)
    _v142_rgb v142_r3 4 fill
    assert "`r(rgb)'" == "0 0 255"

    clear
    input str4 lab double(es lci uci)
    "A" 0.5  0.2 0.8
    "B" 0.1 -0.2 0.4
    end
    eplot es lci uci, labels(lab) mcolor("0 128 0") cicolor("255 0 255") ///
        name(v142_r4, replace)
    _v142_rgb v142_r4 2 fill
    assert "`r(rgb)'" == "0 128 0"
    _v142_rgb v142_r4 1 line
    assert "`r(rgb)'" == "255 0 255"
    eplot es lci uci, labels(lab) sigcolors sigcolor("0 128 0") ///
        insigncolor("255 0 255") name(v142_r5, replace)
    _v142_rgb v142_r5 3 fill
    assert "`r(rgb)'" == "0 128 0"
    _v142_rgb v142_r5 4 fill
    assert "`r(rgb)'" == "255 0 255"

    matrix R = (1, .5, 1.5 \ 2, 1.5, 2.5)
    eplot, matrix(R) mcolor("0 128 0") name(v142_r6, replace)
    _v142_rgb v142_r6 2 fill
    assert "`r(rgb)'" == "0 128 0"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 19"
}
capture graph drop v142_r1 v142_r2 v142_r3 v142_r4 v142_r5 v142_r6

**## A style() preset's colors still yield to the multi-model palette
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store v142_m1
    quietly regress price mpg weight length
    estimates store v142_m2
    eplot v142_m1 v142_m2, noconstant name(v142_s0, replace)
    _v142_rgb v142_s0 2 fill
    local p1 "`r(rgb)'"
    _v142_rgb v142_s0 4 fill
    local p2 "`r(rgb)'"
    assert "`p1'" != "`p2'"
    eplot v142_m1 v142_m2, noconstant style(lancet) name(v142_s1, replace)
    _v142_rgb v142_s1 2 fill
    assert "`r(rgb)'" == "`p1'"
    _v142_rgb v142_s1 4 fill
    assert "`r(rgb)'" == "`p2'"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 20"
}
capture graph drop v142_s0 v142_s1
capture estimates drop v142_m1 v142_m2

**## A color option holding more than one color, or an unknown name, is refused
* twoway does not refuse these: it prints a note and draws the default
* color at rc=0.  Pre-1.4.2 eplot passed them through in every mode.
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store v142_m1
    quietly regress price mpg weight length
    estimates store v142_m2
    foreach o in mcolor cicolor {
        foreach c in "red blue" "nosuch" "0 128" "navy blue*.5" {
            capture eplot v142_m1, noconstant nodraw `o'(`c')
            assert _rc == 198
        }
    }
    foreach o in sigcolor insigncolor {
        capture eplot v142_m1, noconstant nodraw sigcolors `o'(red blue)
        assert _rc == 198
        * Without sigcolors these colors would never be drawn.
        capture eplot v142_m1, noconstant nodraw `o'(red)
        assert _rc == 198
    }
    capture eplot v142_m1 v142_m2, noconstant nodraw mcolor(red nosuch)
    assert _rc == 198
    capture eplot v142_m1 v142_m2, noconstant nodraw palette(red nosuch)
    assert _rc == 198

    clear
    input str4 lab double(es lci uci)
    "A" 0.5  0.2 0.8
    "B" 0.1 -0.2 0.4
    end
    foreach o in mcolor cicolor {
        capture eplot es lci uci, labels(lab) nodraw `o'(red blue)
        assert _rc == 198
        capture eplot es lci uci, labels(lab) nodraw `o'(nosuch)
        assert _rc == 198
    }
    capture eplot es lci uci, labels(lab) nodraw sigcolors sigcolor(red blue)
    assert _rc == 198
    capture eplot es lci uci, labels(lab) nodraw insigncolor(red)
    assert _rc == 198

    frame put lab es lci uci, into(v142_cf)
    frame v142_cf: rename (lab es lci uci) (label estimate ll ul)
    capture eplot, frame(v142_cf) nodraw mcolor(red blue)
    assert _rc == 198
    frame drop v142_cf

    matrix R = (1, .5, 1.5 \ 2, 1.5, 2.5)
    capture eplot, matrix(R) nodraw mcolor(red blue)
    assert _rc == 198
    capture eplot, matrix(R) nodraw cicolor(nosuch)
    assert _rc == 198
    capture eplot, matrix(R) nodraw sigcolors insigncolor(red blue)
    assert _rc == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 21"
}
capture frame drop v142_cf

**## Every documented single-color form is accepted in every mode
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store v142_m1
    matrix R = (1, .5, 1.5 \ 2, 1.5, 2.5)
    clear
    input str4 lab double(es lci uci)
    "A" 0.5  0.2 0.8
    "B" 0.1 -0.2 0.4
    end
    foreach c in navy "0 128 0" "navy%50" "navy*.5" "0 128 0%50" ///
        "hsv 240 1 .5" "0 0 255 0" gs10 none bg "*.5" {
        * The form twoway needs: multi-word values quoted, others bare.
        local nw : word count `c'
        local q "`c'"
        if `nw' > 1 local q `""`c'""'
        eplot v142_m1, noconstant nodraw mcolor("`c'") cicolor("`c'")
        assert strpos(`"`r(cmd)'"', `"mcolor(`q')"') > 0
        assert strpos(`"`r(cmd)'"', `"lcolor(`q')"') > 0
        eplot es lci uci, labels(lab) nodraw mcolor("`c'") cicolor("`c'")
        assert strpos(`"`r(cmd)'"', `"mcolor(`q')"') > 0
        assert strpos(`"`r(cmd)'"', `"lcolor(`q')"') > 0
        eplot es lci uci, labels(lab) nodraw sigcolors sigcolor("`c'") ///
            insigncolor("`c'")
        assert strpos(`"`r(cmd)'"', `"mcolor(`q')"') > 0
        eplot, matrix(R) nodraw mcolor("`c'") cicolor("`c'")
        assert strpos(`"`r(cmd)'"', `"mcolor(`q')"') > 0
    }
    * Forms with a fixed RGB value are checked in the drawn graph.
    foreach pair in "navy|26 71 111" "0 128 0|0 128 0" "gs10|160 160 160" {
        gettoken c want : pair, parse("|")
        local want = substr("`want'", 2, .)
        eplot, matrix(R) mcolor("`c'") cicolor("`c'") name(v142_a1, replace)
        _v142_rgb v142_a1 2 fill
        assert "`r(rgb)'" == "`want'"
        _v142_rgb v142_a1 1 line
        assert "`r(rgb)'" == "`want'"
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 22"
}
capture graph drop v142_a1
capture estimates drop v142_m1 v142_m2

**# Summary

**## No call in this suite reached twoway's unknown-style note
* twoway reports an unusable style only as a note, so the suite's own log is
* scanned for it.  The phrase is assembled from pieces so that echoed
* source lines cannot match it.
local ++test_count
capture log close
local _note_hits 0
local _p1 "not found "
local _p2 "in class"
tempname lfh
file open `lfh' using "test_eplot_v142.log", read text
file read `lfh' _lline
while r(eof) == 0 {
    if strpos(`"`macval(_lline)'"', "`_p1'`_p2'") local ++_note_hits
    file read `lfh' _lline
}
file close `lfh'
log using "test_eplot_v142.log", append text nomsg
display as text "unknown-style notes in this log: `_note_hits'"
if `_note_hits' == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 23"
}

capture graph drop _all
capture estimates drop _all
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
_eplot_qa_result test_eplot_v142, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    capture log close
    exit 1
}
capture log close
