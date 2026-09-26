* test_regtab_multieq_mixed.do - regtab mixed-model and multi-equation output
* Regression suite for the output problems the R-tabtools port found in 2.1.9
* (mixed-model and multi-equation quirks), re-probed on 2.1.10 before any fix:
*   item 1  factor header row lost with several grouping levels (mixed)
*   item 2  raw collect text in a CI cell when a transformed bound overflows
*           (three-level melogit MOR; eform fixed effects)
*   item 3  relabel leaves me* slope variances as raw keys
*   item 4  relabel keeps a bracket in me* covariance labels; r(table) row
*           names fall back to r1, r2, ... or are rewritten by Stata
*   item 5  a covariate only model 2 has is dropped (two mlogit models)
*   item 6  zip + zinb, keepintercept drops zinb's ancillary rows
*   item 7  mecloglog/mestreg/streg time: header and scale agree (already
*           fixed in 2.1.10; guard tests)
*   item 8  equations absent from model 1 are dropped (zip + poisson of a
*           different outcome; ologit + mlogit)
*   item 9  svy:-prefixed models are not classified
* Items 1-6, 8 and 9 fail on 2.1.10; item 7's tests pass there. Every
* expected estimate comes from the fitted model's own e(b), never from the
* collection regtab reads.

clear all
set more off
set varabbrev off
version 17.0

capture log close _regtab_multieq
log using "test_regtab_multieq_mixed.log", replace text name(_regtab_multieq)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

* Trimmed contents of column `col' on the one body row whose trimmed label is
* `label'. Errors when the row is absent or duplicated, so a dropped or
* doubled row cannot pass a cell assertion by accident.
capture program drop _rtm_cell
program define _rtm_cell, rclass
    version 17.0
    args frname label col
    frame `frname' {
        tempvar rn
        quietly generate long `rn' = _n
        quietly count if strtrim(A) == `"`label'"' & _n >= 4
        if r(N) != 1 {
            display as error `"frame `frname': `r(N)' rows labelled "`label'""'
            exit 459
        }
        quietly summarize `rn' if strtrim(A) == `"`label'"' & _n >= 4, meanonly
        local row = r(min)
        local cell = strtrim(`col'[`row'])
        local raw = A[`row']
    }
    return local cell `"`cell'"'
    return local raw `"`raw'"'
    return scalar row = `row'
end

* Number of body rows whose trimmed label is `label'.
capture program drop _rtm_nrow
program define _rtm_nrow, rclass
    version 17.0
    args frname label
    frame `frname' {
        quietly count if strtrim(A) == `"`label'"' & _n >= 4
        local n = r(N)
    }
    return scalar n = `n'
end

* The value regtab must print for x at digits(2).
capture program drop _rtm_fmt
program define _rtm_fmt, rclass
    version 17.0
    args x
    return local s = strtrim(string(round(`x', 0.01), "%32.2f"))
end

* Every body CI cell of a frame is either empty or a (lo, hi) pair of
* fixed-point numbers with `digits' decimals: never raw collect text.
capture program drop _rtm_ci_clean
program define _rtm_ci_clean
    version 17.0
    args frname digits
    frame `frname' {
        quietly ds c*
        local cols `r(varlist)'
        foreach v of local cols {
            if !ustrregexm("`v'", "^c[0-9]+$") continue
            if mod(real(substr("`v'", 2, .)), 3) != 2 continue
            quietly count if _n >= 4 & strtrim(`v') != "" & ///
                !ustrregexm(strtrim(`v'), ///
                "^\(-?[0-9]+\.[0-9]{`digits'}, -?[0-9]+\.[0-9]{`digits'}\)$")
            if r(N) > 0 {
                list A `v' if _n >= 4 & strtrim(`v') != "" & ///
                    !ustrregexm(strtrim(`v'), ///
                    "^\(-?[0-9]+\.[0-9]{`digits'}, -?[0-9]+\.[0-9]{`digits'}\)$"), noobs
                display as error "frame `frname': unformatted CI text in `v'"
                exit 459
            }
        }
    }
end

* Two-level nested data: zone > location, a labelled binary factor.
capture program drop _rtm_mixed_data
program define _rtm_mixed_data
    version 17.0
    clear
    set obs 2000
    generate int zone = mod(_n - 1, 8) + 1
    generate int location = mod(_n - 1, 40) + 1
    label variable zone "Zone"
    label variable location "Location"
    * stata-dev-ignore: unseeded-draw — generator program; every call site seeds first
    generate byte sex = 1 + (runiform() < 0.5)
    label define RTM_SX 1 "Male" 2 "Female", replace
    label values sex RTM_SX
    label variable sex "Sex"
    generate age = 20 + 50 * runiform()
    label variable age "Age"
    generate u_loc = rnormal(0, 0.6)
    bysort location (u_loc): replace u_loc = u_loc[1]
    generate bmi = 22 + 0.05 * age + 0.8 * (sex == 2) + u_loc + rnormal(0, 1.5)
    drop u_loc
end

* Three-level logit data. Seed 3 drives the class-level variance to the
* boundary, where the upper bound of the variance CI is ~2e+29 and its MOR
* transform overflows double precision.
capture program drop _rtm_3lvl_data
program define _rtm_3lvl_data
    version 17.0
    clear
    set seed 3
    set obs 20
    generate school = _n
    generate u = rnormal(0, 1)
    expand 3
    bysort school: generate class = _n
    expand 15
    generate x = rnormal()
    generate byte y = runiform() < invlogit(-0.2 + 0.5 * x + u)
    egen clsid = group(school class)
    label variable clsid "Class"
    label variable school "School"
    label variable x "Exposure"
end

* Random-slope data (the R-tabtools Phase 5b fixture recipe).
capture program drop _rtm_slope_data
program define _rtm_slope_data
    version 17.0
    clear
    set seed 12345
    set obs 40
    generate clinic = _n
    label variable clinic "Clinic ID"
    generate u0 = rnormal(0, 0.8)
    generate u1 = rnormal(0, 0.5)
    expand 60
    sort clinic, stable
    generate x = rnormal()
    label variable x "Exposure score"
    generate z = rnormal()
    generate byte yb = runiform() < invlogit(-0.3 + u0 + (0.7 + u1) * x + 0.2 * z)
    generate yc = 1 + u0 + (0.7 + u1) * x + 0.2 * z + rnormal()
    drop u0 u1
end

* Three-outcome multinomial data with two binary covariates.
capture program drop _rtm_mlogit_data
program define _rtm_mlogit_data
    version 17.0
    clear
    set seed 505
    set obs 1500
    generate age = rnormal(50, 10)
    label variable age "Age"
    generate byte female = runiform() < 0.5
    label variable female "Female"
    generate byte diabetes = runiform() < 0.2
    label variable diabetes "Diabetes"
    generate xb2 = -1 + 0.02 * (age - 50) + 0.4 * female + 0.5 * diabetes
    generate xb3 = -1.5 + 0.03 * (age - 50) - 0.3 * female + 0.8 * diabetes
    generate p1 = 1 / (1 + exp(xb2) + exp(xb3))
    generate p2 = exp(xb2) * p1
    generate r = runiform()
    generate byte educ = cond(r < p1, 1, cond(r < p1 + p2, 2, 3))
    label define RTM_ED 1 "Low" 2 "Mid" 3 "High", replace
    label values educ RTM_ED
    drop xb2 xb3 p1 p2 r
end

* Zero-inflated overdispersed counts and a second, unrelated count.
capture program drop _rtm_count_data
program define _rtm_count_data
    version 17.0
    clear
    set seed 606
    set obs 1500
    generate byte treat = runiform() < 0.5
    label variable treat "Treatment"
    generate agez = rnormal()
    label variable agez "Age (z)"
    generate zr = rnormal()
    label variable zr "Zero risk"
    generate mu = exp(0.5 - 0.4 * treat + 0.2 * agez)
    generate g = rgamma(1 / 0.8, 0.8)
    generate cnt = cond(runiform() < invlogit(-1 + zr), 0, rpoisson(mu * g))
    generate cnt2 = rpoisson(exp(0.2 + 0.3 * treat))
    drop mu g
end

**# Test 1: multilevel mixed keeps the factor header row (item 1)
* The oracle is the one-level fit of the same model: its fixed-effect block
* (header row, indented level rows, Reference) must be reproduced exactly.
capture noisily {
    set seed 101
    _rtm_mixed_data
    collect clear
    quietly collect: mixed bmi age i.sex || zone:
    capture frame drop _rtm1a
    quietly regtab, frame(_rtm1a, replace)
    collect clear
    quietly collect: mixed bmi age i.sex || zone: || location:
    capture frame drop _rtm1b
    quietly regtab, frame(_rtm1b, replace)

    * the header row exists, carries no values, and sits right above Male
    _rtm_cell _rtm1b "Sex" c1
    assert "`r(cell)'" == ""
    local hdr_row = r(row)
    _rtm_cell _rtm1b "Male" c1
    assert "`r(cell)'" == "Reference"
    assert r(row) == `hdr_row' + 1
    _rtm_cell _rtm1b "Female" c1
    assert r(row) == `hdr_row' + 2
    assert real("`r(cell)'") < .

    * the fixed-effect labels, including indentation, match the 1-level fit
    forvalues r = 4/8 {
        frame _rtm1a: local a1 = A[`r']
        frame _rtm1b: local a2 = A[`r']
        assert `"`a1'"' == `"`a2'"'
    }
    frame _rtm1b: assert strtrim(A[8]) == "Intercept"
}
if _rc == 0 {
    display as result "  PASS: multilevel mixed keeps the Sex header row"
    local ++pass_count
}
else {
    display as error "  FAIL: multilevel mixed factor header (rc=`=_rc')"
    local ++fail_count
}

**# Test 2: multilevel models keep rows only model 2 estimates (item 1/8)
* The multilevel flatten found equation headers by an empty model-1 cell, so a
* covariate absent from model 1 was taken for a header and deleted.
capture noisily {
    set seed 101
    _rtm_mixed_data
    collect clear
    quietly collect: mixed bmi age || zone: || location:
    quietly collect: mixed bmi age i.sex || zone: || location:
    matrix b2 = e(b)
    capture frame drop _rtm2
    quietly regtab, frame(_rtm2, replace)

    _rtm_cell _rtm2 "Sex" c4
    assert "`r(cell)'" == ""
    _rtm_cell _rtm2 "Male" c4
    assert "`r(cell)'" == "Reference"
    _rtm_cell _rtm2 "Male" c1
    assert "`r(cell)'" == ""
    _rtm_cell _rtm2 "Female" c4
    _rtm_fmt `=b2[1, colnumb(b2, "bmi:2.sex")]'
    assert "`r(s)'" != ""
    local want "`r(s)'"
    _rtm_cell _rtm2 "Female" c4
    assert "`r(cell)'" == "`want'"
    _rtm_cell _rtm2 "Female" c1
    assert "`r(cell)'" == ""
    * both models still carry their per-level variance rows
    _rtm_cell _rtm2 "var(_cons[location])" c1
    assert real("`r(cell)'") < .
    _rtm_cell _rtm2 "var(_cons[location])" c4
    assert real("`r(cell)'") < .
}
if _rc == 0 {
    display as result "  PASS: multilevel layout keeps model-2-only rows"
    local ++pass_count
}
else {
    display as error "  FAIL: multilevel layout drops model-2-only rows (rc=`=_rc')"
    local ++fail_count
}

**# Test 3: boundary variance in a three-level melogit (item 2)
* The class variance sits at ~0.002 with a CI of (1.8e-35, 2.2e+29); the MOR
* of the upper bound overflows. Rule: a CI whose transformed bound is not
* representable is blank; it is never the untransformed collect text.
capture noisily {
    _rtm_3lvl_data
    collect clear
    quietly collect: melogit y x || school: || clsid:
    matrix b = e(b)
    local v_cls = b[1, colnumb(b, "/:var(_cons[school>clsid])")]
    local v_sch = b[1, colnumb(b, "/:var(_cons[school])")]
    assert `v_cls' < 0.01
    capture frame drop _rtm3
    quietly regtab, frame(_rtm3, replace)

    * estimates: the MOR of the collected variance, formatted
    _rtm_fmt `=exp(sqrt(2 * `v_cls') * invnormal(0.75))'
    local want "`r(s)'"
    _rtm_cell _rtm3 "Median Odds Ratio (Class)" c1
    assert "`r(cell)'" == "`want'"
    _rtm_cell _rtm3 "Median Odds Ratio (Class)" c2
    assert "`r(cell)'" == ""
    * the well-estimated level keeps a formatted interval
    _rtm_cell _rtm3 "Median Odds Ratio (School)" c2
    assert ustrregexm("`r(cell)'", "^\([0-9]+\.[0-9]{2}, [0-9]+\.[0-9]{2}\)$")
    _rtm_fmt `=exp(sqrt(2 * `v_sch') * invnormal(0.75))'
    local want "`r(s)'"
    _rtm_cell _rtm3 "Median Odds Ratio (School)" c1
    assert "`r(cell)'" == "`want'"
    _rtm_ci_clean _rtm3 2

    * digits() governs the surviving intervals; the Excel sink agrees
    capture erase "`output_dir'/_rtm3.xlsx"
    capture frame drop _rtm3d
    quietly regtab, frame(_rtm3d, replace) digits(3) ///
        xlsx("`output_dir'/_rtm3.xlsx") sheet("MOR")
    _rtm_ci_clean _rtm3d 3
    _rtm_cell _rtm3d "Median Odds Ratio (Class)" c2
    assert "`r(cell)'" == ""
    * the workbook row holds exactly the label and the MOR, and no cell of
    * the sheet carries e-notation
    preserve
    quietly import excel using "`output_dir'/_rtm3.xlsx", sheet("MOR") ///
        clear allstring
    quietly ds
    local xcols `r(varlist)'
    generate byte _hit = 0
    generate byte _sci = 0
    foreach v of local xcols {
        quietly replace _hit = 1 if strtrim(`v') == "Median Odds Ratio (Class)"
        quietly replace _sci = 1 if ustrregexm(`v', "[0-9]e[-+][0-9]")
    }
    quietly count if _hit
    assert r(N) == 1
    quietly count if _sci
    assert r(N) == 0
    egen _nfill = rownonmiss(`xcols'), strok
    quietly summarize _nfill if _hit, meanonly
    assert r(min) == 2
    restore
}
if _rc == 0 {
    display as result "  PASS: overflowed MOR interval is blank, never raw text"
    local ++pass_count
}
else {
    display as error "  FAIL: boundary MOR interval (rc=`=_rc')"
    local ++fail_count
}

**# Test 4: exp() overflow of a fixed-effect bound (item 2, same rule)
* logit, asis keeps a perfectly predicting level at b ~ 17 with a CI of
* (-1357, 1391): exp(1391) is not representable. The OR column must not show
* the log-odds interval under the OR header.
capture noisily {
    clear
    set obs 200
    set seed 44
    generate byte g = _n <= 20
    label variable g "Group"
    generate x = rnormal()
    label variable x "Exposure"
    generate byte y = cond(g, 1, runiform() < 0.4)
    collect clear
    quietly collect: logit y g x, asis
    matrix b = e(b)
    capture frame drop _rtm4
    quietly regtab, frame(_rtm4, replace)

    _rtm_cell _rtm4 "Group" c2
    assert "`r(cell)'" == ""
    _rtm_fmt `=exp(b[1, colnumb(b, "y:g")])'
    local want "`r(s)'"
    _rtm_cell _rtm4 "Group" c1
    assert "`r(cell)'" == "`want'"
    _rtm_fmt `=exp(b[1, colnumb(b, "y:x")])'
    local want "`r(s)'"
    _rtm_cell _rtm4 "Exposure" c1
    assert "`r(cell)'" == "`want'"
    _rtm_cell _rtm4 "Exposure" c2
    assert ustrregexm("`r(cell)'", "^\([0-9]+\.[0-9]{2}, [0-9]+\.[0-9]{2}\)$")
    _rtm_ci_clean _rtm4 2
}
if _rc == 0 {
    display as result "  PASS: overflowed eform interval is blank"
    local ++pass_count
}
else {
    display as error "  FAIL: overflowed eform interval (rc=`=_rc')"
    local ++fail_count
}

**# Test 5: relabel names me* slope variances like mixed (item 3)
capture noisily {
    _rtm_slope_data
    collect clear
    quietly collect: melogit yb x z || clinic: x, cov(unstructured) intmethod(laplace)
    matrix b = e(b)
    capture frame drop _rtm5
    quietly regtab, relabel frame(_rtm5, replace)

    _rtm_fmt `=b[1, colnumb(b, "/:var(x[clinic])")]'
    local want "`r(s)'"
    _rtm_cell _rtm5 "Variance: Clinic ID (Exposure score)" c1
    assert "`r(cell)'" == "`want'"
    _rtm_nrow _rtm5 "var(x[clinic])"
    assert r(n) == 0
    frame _rtm5: quietly count if _n >= 4 & strpos(A, "var(")
    assert r(N) == 0
    * the intercept variance keeps its MOR row
    _rtm_nrow _rtm5 "Median Odds Ratio (Clinic ID)"
    assert r(n) == 1

    * the mixed form of the same model is unchanged
    collect clear
    quietly collect: mixed yc x z || clinic: x, cov(unstructured)
    capture frame drop _rtm5m
    quietly regtab, relabel frame(_rtm5m, replace)
    _rtm_nrow _rtm5m "Variance: Clinic ID (Exposure score)"
    assert r(n) == 1
    _rtm_nrow _rtm5m "Variance: Clinic ID (Intercept)"
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: me* slope variance relabelled"
    local ++pass_count
}
else {
    display as error "  FAIL: me* slope variance relabel (rc=`=_rc')"
    local ++fail_count
}

**# Test 6: relabel strips every bracket from me* covariances (item 4)
capture noisily {
    _rtm_slope_data
    collect clear
    quietly collect: melogit yb x z || clinic: x, cov(unstructured) intmethod(laplace)
    matrix b = e(b)
    capture frame drop _rtm6
    quietly regtab, relabel frame(_rtm6, replace)

    _rtm_fmt `=b[1, colnumb(b, "/:cov(x[clinic],_cons[clinic])")]'
    local want "`r(s)'"
    _rtm_cell _rtm6 "Covariance: Clinic ID (Exposure score, Intercept)" c1
    assert "`r(cell)'" == "`want'"
    frame _rtm6: quietly count if _n >= 4 & (strpos(A, "[") | strpos(A, "]"))
    assert r(N) == 0

    * mixed: identical covariance label
    collect clear
    quietly collect: mixed yc x z || clinic: x, cov(unstructured)
    capture frame drop _rtm6m
    quietly regtab, relabel frame(_rtm6m, replace)
    _rtm_nrow _rtm6m "Covariance: Clinic ID (Exposure score, Intercept)"
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: me* covariance label has no bracket"
    local ++pass_count
}
else {
    display as error "  FAIL: me* covariance label (rc=`=_rc')"
    local ++fail_count
}

**# Test 7: r(table) row names survive bracketed and covariance keys (item 4)
* A bracketed key made matrix rownames fail for the whole matrix (r1, r2,
* ...). A comma-stripped "cov(x_cons)" is silently rewritten by Stata to
* "var(x_cons)", naming the covariance row as a variance.
capture noisily {
    _rtm_slope_data
    collect clear
    quietly collect: melogit yb x z || clinic: x, cov(unstructured) intmethod(laplace)
    quietly regtab
    tempname T
    matrix `T' = r(table)
    local rn : rownames `T'
    assert rowsof(`T') == 5
    local n_generic 0
    foreach nm of local rn {
        if ustrregexm("`nm'", "^r[0-9]+$") local ++n_generic
    }
    assert `n_generic' == 0
    local nm1 : word 1 of `rn'
    assert "`nm1'" == "Exposure_score"
    local nm3 : word 3 of `rn'
    assert strpos("`nm3'", "var") == 1 & strpos("`nm3'", "clinic")
    local nm5 : word 5 of `rn'
    assert strpos("`nm5'", "cov") == 1 & strpos("`nm5'", "clinic")
    * row values stay aligned with their names
    matrix b = e(b)
    assert reldif(`T'[3, 1], b[1, colnumb(b, "/:var(x[clinic])")]) < 1e-12

    * relabelled melogit: names come from the display labels
    quietly regtab, relabel
    matrix `T' = r(table)
    local rn : rownames `T'
    local nm5 : word 5 of `rn'
    assert strpos("`nm5'", "Covariance_Clinic_ID") == 1

    * mixed without relabel: the covariance row is not named var(...)
    collect clear
    quietly collect: mixed yc x z || clinic: x, cov(unstructured)
    quietly regtab
    matrix `T' = r(table)
    local rn : rownames `T'
    assert rowsof(`T') == 7
    local nm4 : word 4 of `rn'
    assert "`nm4'" == "var(x)"
    local nm6 : word 6 of `rn'
    assert strpos("`nm6'", "cov") == 1
    local nm7 : word 7 of `rn'
    assert "`nm7'" == "var(e)"
}
if _rc == 0 {
    display as result "  PASS: r(table) row names are specific and faithful"
    local ++pass_count
}
else {
    display as error "  FAIL: r(table) row names (rc=`=_rc')"
    local ++fail_count
}

**# Test 8: mlogit models with different covariates keep the union (item 5)
capture noisily {
    _rtm_mlogit_data
    collect clear
    quietly collect: mlogit educ age female, baseoutcome(1)
    matrix b1 = e(b)
    quietly collect: mlogit educ age diabetes female, baseoutcome(1)
    matrix b2 = e(b)
    capture frame drop _rtm8
    quietly regtab, frame(_rtm8, replace)

    foreach eq in Mid High {
        _rtm_fmt `=exp(b2[1, colnumb(b2, "`eq':diabetes")])'
        local want "`r(s)'"
        _rtm_cell _rtm8 "`eq': Diabetes" c4
        assert "`r(cell)'" == "`want'"
        _rtm_cell _rtm8 "`eq': Diabetes" c1
        assert "`r(cell)'" == ""
        _rtm_cell _rtm8 "`eq': Diabetes" c5
        assert ustrregexm("`r(cell)'", "^\([0-9]+\.[0-9]{2}, [0-9]+\.[0-9]{2}\)$")
        * shared rows keep both models' own estimates
        _rtm_fmt `=exp(b1[1, colnumb(b1, "`eq':female")])'
        local want "`r(s)'"
        _rtm_cell _rtm8 "`eq': Female" c1
        assert "`r(cell)'" == "`want'"
        _rtm_fmt `=exp(b2[1, colnumb(b2, "`eq':female")])'
        local want "`r(s)'"
        _rtm_cell _rtm8 "`eq': Female" c4
        assert "`r(cell)'" == "`want'"
    }
    * the base outcome equation stays out
    frame _rtm8: quietly count if _n >= 4 & strpos(A, "Low:") == 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: mlogit row union keeps model 2's covariate"
    local ++pass_count
}
else {
    display as error "  FAIL: mlogit row union (rc=`=_rc')"
    local ++fail_count
}

**# Test 9: zip + zinb, keepintercept keeps zinb's ancillary rows (item 6)
capture noisily {
    _rtm_count_data
    collect clear
    quietly collect: zip cnt treat agez, inflate(zr)
    matrix b1 = e(b)
    quietly collect: zinb cnt treat agez, inflate(zr)
    matrix b2 = e(b)
    capture frame drop _rtm9
    quietly regtab, keepintercept frame(_rtm9, replace)

    _rtm_fmt `=b2[1, colnumb(b2, "/:lnalpha")]'
    local want "`r(s)'"
    _rtm_cell _rtm9 "Ancillary: lnalpha" c4
    assert "`r(cell)'" == "`want'"
    _rtm_cell _rtm9 "Ancillary: lnalpha" c1
    assert "`r(cell)'" == ""
    _rtm_fmt `=exp(b2[1, colnumb(b2, "/:lnalpha")])'
    local want "`r(s)'"
    _rtm_cell _rtm9 "Ancillary: alpha" c4
    assert "`r(cell)'" == "`want'"
    _rtm_cell _rtm9 "Ancillary: alpha" c1
    assert "`r(cell)'" == ""
    * both models keep their intercepts
    _rtm_fmt `=b1[1, colnumb(b1, "cnt:_cons")]'
    local want "`r(s)'"
    _rtm_cell _rtm9 "cnt: Intercept" c1
    assert "`r(cell)'" == "`want'"
    _rtm_fmt `=b2[1, colnumb(b2, "inflate:_cons")]'
    local want "`r(s)'"
    _rtm_cell _rtm9 "Inflation equation: Intercept" c4
    assert "`r(cell)'" == "`want'"
}
if _rc == 0 {
    display as result "  PASS: zinb ancillary rows kept beside zip"
    local ++pass_count
}
else {
    display as error "  FAIL: zinb ancillary rows beside zip (rc=`=_rc')"
    local ++fail_count
}

**# Test 10: zip + poisson of another outcome keeps both equations (item 8)
capture noisily {
    _rtm_count_data
    collect clear
    quietly collect: zip cnt treat agez, inflate(zr)
    matrix b1 = e(b)
    quietly collect: poisson cnt2 treat agez
    matrix b2 = e(b)
    capture frame drop _rtm10
    quietly regtab, frame(_rtm10, replace)

    frame _rtm10: assert strtrim(c1[3]) == "Coef." & strtrim(c4[3]) == "IRR"
    _rtm_fmt `=exp(b2[1, colnumb(b2, "cnt2:treat")])'
    local want "`r(s)'"
    _rtm_cell _rtm10 "cnt2: Treatment" c4
    assert "`r(cell)'" == "`want'"
    _rtm_cell _rtm10 "cnt2: Treatment" c1
    assert "`r(cell)'" == ""
    _rtm_cell _rtm10 "cnt2: Age (z)" c4
    assert real("`r(cell)'") < .
    _rtm_fmt `=b1[1, colnumb(b1, "cnt:treat")]'
    local want "`r(s)'"
    _rtm_cell _rtm10 "cnt: Treatment" c1
    assert "`r(cell)'" == "`want'"
    _rtm_cell _rtm10 "cnt: Treatment" c4
    assert "`r(cell)'" == ""
}
if _rc == 0 {
    display as result "  PASS: zip + poisson keeps the poisson equation"
    local ++pass_count
}
else {
    display as error "  FAIL: zip + poisson equation union (rc=`=_rc')"
    local ++fail_count
}

**# Test 11: ologit + mlogit keeps the mlogit equations (item 8)
capture noisily {
    _rtm_mlogit_data
    collect clear
    quietly collect: ologit educ age female
    matrix b1 = e(b)
    quietly collect: mlogit educ age female, baseoutcome(1)
    matrix b2 = e(b)
    capture frame drop _rtm11
    quietly regtab, frame(_rtm11, replace)

    frame _rtm11: assert strtrim(c1[3]) == "OR" & strtrim(c4[3]) == "RRR"
    foreach eq in Mid High {
        _rtm_fmt `=exp(b2[1, colnumb(b2, "`eq':age")])'
        local want "`r(s)'"
        _rtm_cell _rtm11 "`eq': Age" c4
        assert "`r(cell)'" == "`want'"
        _rtm_cell _rtm11 "`eq': Age" c1
        assert "`r(cell)'" == ""
    }
    _rtm_fmt `=exp(b1[1, colnumb(b1, "educ:female")])'
    local want "`r(s)'"
    _rtm_cell _rtm11 "educ: Female" c1
    assert "`r(cell)'" == "`want'"
    _rtm_cell _rtm11 "educ: Female" c4
    assert "`r(cell)'" == ""
}
if _rc == 0 {
    display as result "  PASS: ologit + mlogit keeps every equation"
    local ++pass_count
}
else {
    display as error "  FAIL: ologit + mlogit equation union (rc=`=_rc')"
    local ++fail_count
}

**# Test 12: mecloglog and mestreg print the scale their header names (item 7)
* Guard: 2.1.10 already exponentiates these. The oracle is exp(e(b)).
capture noisily {
    clear
    set seed 707
    set obs 30
    generate site = _n
    generate u = rnormal(0, 0.5)
    expand 50
    generate x = rnormal()
    label variable x "Dose (mg)"
    generate byte female = runiform() < 0.5
    label variable female "Female"
    generate byte y = runiform() < 1 - exp(-exp(-1 + 0.5 * x + 0.2 * female + u))
    collect clear
    quietly collect: mecloglog y x female || site:
    matrix b = e(b)
    capture frame drop _rtm12
    quietly regtab, frame(_rtm12, replace)
    frame _rtm12: assert strtrim(c1[3]) == "HR"
    _rtm_fmt `=exp(b[1, colnumb(b, "y:x")])'
    local want "`r(s)'"
    _rtm_cell _rtm12 "Dose (mg)" c1
    assert "`r(cell)'" == "`want'"

    generate t = -ln(runiform()) / exp(-1 + 0.5 * x + u)
    generate byte d = runiform() < 0.8
    quietly stset t, failure(d)
    foreach metric in ph time {
        local topt = cond("`metric'" == "time", "time", "")
        local hdr = cond("`metric'" == "time", "TR", "HR")
        collect clear
        quietly collect: mestreg x female || site:, distribution(weibull) `topt'
        matrix b = e(b)
        capture frame drop _rtm12s
        quietly regtab, frame(_rtm12s, replace)
        frame _rtm12s: assert strtrim(c1[3]) == "`hdr'"
        _rtm_fmt `=exp(b[1, colnumb(b, "_t:x")])'
        local want "`r(s)'"
        _rtm_cell _rtm12s "Dose (mg)" c1
        assert "`r(cell)'" == "`want'"
    }
}
if _rc == 0 {
    display as result "  PASS: mecloglog/mestreg estimates on the header's scale"
    local ++pass_count
}
else {
    display as error "  FAIL: mecloglog/mestreg header scale (rc=`=_rc')"
    local ++fail_count
}

**# Test 13: streg, time shows time ratios under TR (item 7)
capture noisily {
    sysuse cancer, clear
    label variable age "Age"
    quietly stset studytime, failure(died)
    collect clear
    quietly collect: streg age i.drug, distribution(weibull) time
    matrix b = e(b)
    capture frame drop _rtm13
    quietly regtab, frame(_rtm13, replace)
    frame _rtm13: assert strtrim(c1[3]) == "TR"
    _rtm_fmt `=exp(b[1, colnumb(b, "_t:age")])'
    local want "`r(s)'"
    _rtm_cell _rtm13 "Age" c1
    assert "`r(cell)'" == "`want'"
    _rtm_nrow _rtm13 "Intercept"
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: streg time metric shows TR"
    local ++pass_count
}
else {
    display as error "  FAIL: streg time metric TR (rc=`=_rc')"
    local ++fail_count
}

**# Test 14: svy: logit is classified like logit (item 9)
capture noisily {
    clear
    set seed 909
    set obs 1000
    generate x = rnormal()
    label variable x "Exposure"
    generate byte female = runiform() < 0.5
    generate psu = mod(_n, 50)
    generate w = 1 + runiform()
    generate byte y = runiform() < invlogit(-0.5 + 0.7 * x)
    quietly svyset psu [pw=w]

    * alone
    collect clear
    quietly collect: svy: logit y x
    matrix bs = e(b)
    capture frame drop _rtm14
    quietly regtab, frame(_rtm14, replace)
    assert "`r(coef_label)'" == "OR"
    frame _rtm14: assert strtrim(c1[3]) == "OR"
    _rtm_fmt `=exp(bs[1, colnumb(bs, "y:x")])'
    local want_s "`r(s)'"
    _rtm_cell _rtm14 "Exposure" c1
    assert "`r(cell)'" == "`want_s'"
    _rtm_nrow _rtm14 "Intercept"
    assert r(n) == 0

    * next to a plain logit
    collect clear
    quietly collect: svy: logit y x
    quietly collect: logit y x
    matrix bp = e(b)
    capture frame drop _rtm14b
    quietly regtab, frame(_rtm14b, replace)
    frame _rtm14b: assert strtrim(c1[3]) == "OR" & strtrim(c4[3]) == "OR"
    _rtm_cell _rtm14b "Exposure" c1
    assert "`r(cell)'" == "`want_s'"
    _rtm_fmt `=exp(bp[1, colnumb(bp, "y:x")])'
    local want_p "`r(s)'"
    _rtm_cell _rtm14b "Exposure" c4
    assert "`r(cell)'" == "`want_p'"
    _rtm_nrow _rtm14b "Intercept"
    assert r(n) == 0

    * svy options before the colon never reach the model's options; the
    * model's own or is honoured (collect already holds odds ratios)
    collect clear
    quietly collect: svy, subpop(female): logit y x, or
    matrix bo = e(b)
    quietly collect: svy linearized: poisson y x
    matrix bq = e(b)
    capture frame drop _rtm14c
    quietly regtab, frame(_rtm14c, replace)
    frame _rtm14c: assert strtrim(c1[3]) == "OR" & strtrim(c4[3]) == "IRR"
    _rtm_fmt `=exp(bo[1, colnumb(bo, "y:x")])'
    local want "`r(s)'"
    _rtm_cell _rtm14c "Exposure" c1
    assert "`r(cell)'" == "`want'"
    _rtm_fmt `=exp(bq[1, colnumb(bq, "y:x")])'
    local want "`r(s)'"
    _rtm_cell _rtm14c "Exposure" c4
    assert "`r(cell)'" == "`want'"
}
if _rc == 0 {
    display as result "  PASS: svy-prefixed models classified like plain fits"
    local ++pass_count
}
else {
    display as error "  FAIL: svy-prefixed classification (rc=`=_rc')"
    local ++fail_count
}

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_regtab_multieq_mixed tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _regtab_multieq
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_regtab_multieq_mixed tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _regtab_multieq
