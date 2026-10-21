*! test_eplot_review_2026_10_20.do - Regression tests for the 2026-10-20 review
*! Each block reproduces one confirmed review finding and asserts the fixed
*! behaviour against an oracle the code does not share: Stata's own r(table)
*! (proportion and svy: proportion logit limits, citype() and level()
*! forwarding, the fixed effects of meqrlogit/meqrpoisson/xtmelogit and
*! xtreg, mle, and the trailing e(k_aux) ancillary equations of intreg,
*! frontier and xtologit), hand-written expected rows (mlogit base-outcome
*! reference rows, drop() of omitted and base terms, rename() target labels,
*! order() and headers() with duplicate labels, groups() with spaced labels,
*! frame-mode auto-detected weight/type columns, r(table) row names and Row
*! labels under if, matrix-mode r(pvalues) and export()), drawn text read back
*! from SVG and PNG exports (values column and header inside the graph,
*! measured in pixels; a literal "}" in bold text), and
*! the refusals of msize(), ciwidth(), scheme(), RGB components, dp() and
*! export() names that twoway would accept at rc=0 or fail on late.

clear all
set varabbrev off
set graphics off
version 16.0

capture log close _all
log using "test_eplot_review_2026_10_20.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

**# Helpers

* Counts the lines of a text file that contain TEXT (literal, and AND too
* when given) or match REGEX.
capture program drop _r20_grep
program define _r20_grep, rclass
    version 16.0
    syntax , File(string) [Text(string asis) REGex(string asis) AND(string asis)]
    gettoken text : text
    gettoken regex : regex
    gettoken and : and
    tempname fh
    local n 0
    file open `fh' using `"`file'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if `"`text'"' != "" {
            if strpos(`"`macval(line)'"', `"`text'"') & ///
                strpos(`"`macval(line)'"', `"`and'"') local ++n
        }
        else if regexm(`"`macval(line)'"', `"`regex'"') local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end

* Width in pixels between the rightmost non-background pixel of a PNG and
* its right edge (background = the top-right pixel; a channel difference
* above 40 counts as drawn, which ignores antialiasing haze).  The Python
* function is defined by test 23 itself, so a missing Python or Pillow fails
* that test only.
capture program drop _r20_pngedge
program define _r20_pngedge, rclass
    version 16.0
    syntax , File(string)
    python: import __main__; __main__._r20_edge(r"`file'")
    return scalar gap = scalar(_r20_gap)
    scalar drop _r20_gap
end

* Runs a command and logs its output to FILE; the command's r() results
* are held across log close, which would otherwise clear them.
capture program drop _r20_logrun
program define _r20_logrun
    version 16.0
    gettoken file 0 : 0
    capture log close _r20
    quietly log using `"`file'"', text replace name(_r20)
    capture noisily `0'
    local rc = _rc
    tempname hold
    _return hold `hold'
    quietly log close _r20
    _return restore `hold'
    c_local _r20_rc `rc'
end

* Asserts that the b/ll/ul columns of eplot's r(table) equal rows ll and ul
* of a Stata r(table) S (columns in the same order), both nonmissing.
capture program drop _r20_ci_equal
program define _r20_ci_equal
    version 16.0
    args E S tol
    if "`tol'" == "" local tol 1e-10
    assert rowsof(`E') == colsof(`S')
    forvalues j = 1/`=rowsof(`E')' {
        assert !missing(`E'[`j', 2]) & !missing(`S'[rownumb(`S', "ll"), `j'])
        assert !missing(`E'[`j', 3]) & !missing(`S'[rownumb(`S', "ul"), `j'])
        assert reldif(`E'[`j', 1], `S'[rownumb(`S', "b"), `j']) < `tol'
        assert reldif(`E'[`j', 2], `S'[rownumb(`S', "ll"), `j']) < `tol'
        assert reldif(`E'[`j', 3], `S'[rownumb(`S', "ul"), `j']) < `tol'
    }
end

**# OPUS-1: proportion limits are Stata's (logit by default), not b +/- t*se

**## 1. proportion: eplot . reproduces Stata's logit limits
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly proportion rep78
    matrix S = r(table)
    eplot ., nodraw
    matrix E = r(table)
    _r20_ci_equal E S
    * The Wald limit of 1.rep78 is negative; the logit limit is not.
    assert E[1, 2] > 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_1"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1"
    display as error "FAIL: R20_1 (rc=" _rc ")"
}

**## 2. svy: proportion reproduces the survey logit limits
local ++test_count
capture noisily {
    webuse nhanes2f, clear
    quietly svyset psuid [pweight=finalwgt], strata(stratid)
    quietly svy: proportion race
    matrix S = r(table)
    eplot ., nodraw
    matrix E = r(table)
    _r20_ci_equal E S
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_2"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2"
    display as error "FAIL: R20_2 (rc=" _rc ")"
}

**## 3. citype() given at estimation is honoured (exact, wilson, wald)
local ++test_count
capture noisily {
    sysuse auto, clear
    foreach ct in exact wilson wald agresti jeffreys {
        quietly proportion rep78, citype(`ct')
        matrix S = r(table)
        eplot ., nodraw
        matrix E = r(table)
        _r20_ci_equal E S
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_3"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3"
    display as error "FAIL: R20_3 (rc=" _rc ")"
}

**## 4. eplot's level() reaches the transformed limits
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly proportion rep78, citype(exact)
    quietly proportion, citype(exact) level(90)
    matrix S = r(table)
    eplot ., level(90) nodraw
    matrix E = r(table)
    _r20_ci_equal E S
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_4"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4"
    display as error "FAIL: R20_4 (rc=" _rc ")"
}

**## 5. A stored proportion beside an active regress: limits and e() intact
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly proportion foreign, over(rep78)
    matrix S = r(table)
    estimates store r20_p
    quietly regress price mpg
    matrix B0 = e(b)
    eplot r20_p, nodraw
    matrix E = r(table)
    * Cells with zero variance (a 0 or 1 proportion) are not plotted.
    local j 0
    forvalues c = 1/`=colsof(S)' {
        if S[rownumb(S, "se"), `c'] > 0 & !missing(S[rownumb(S, "se"), `c']) {
            local ++j
            assert reldif(E[`j', 2], S[rownumb(S, "ll"), `c']) < 1e-10
            assert reldif(E[`j', 3], S[rownumb(S, "ul"), `c']) < 1e-10
        }
    }
    assert `j' == rowsof(E) & `j' > 0
    assert "`e(cmd)'" == "regress"
    assert mreldif(e(b), B0) == 0
    estimates drop r20_p
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_5"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 5"
    display as error "FAIL: R20_5 (rc=" _rc ")"
}

**## 6. guard: mean keeps Wald limits (b +/- t*se equals Stata's table)
local ++test_count
* guard: expected green at HEAD too
capture noisily {
    sysuse auto, clear
    quietly mean price mpg
    matrix S = r(table)
    eplot ., nodraw
    matrix E = r(table)
    _r20_ci_equal E S
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_6"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 6"
    display as error "FAIL: R20_6 (rc=" _rc ")"
}

**# OPUS-2: variance components of meqrlogit, meqrpoisson, xtmelogit

**## 7. only the e(k_f) fixed effects are plotted, without eq1: prefixes
local ++test_count
capture noisily {
    webuse bangladesh, clear
    foreach c in "meqrlogit c_use urban age || district:" ///
        "meqrpoisson children urban age || district:" ///
        "xtmelogit c_use urban age || district:" {
        quietly `c'
        local kf = e(k_f)
        assert `kf' == 3
        quietly `e(cmd)'
        matrix S = r(table)
        eplot ., nodraw
        matrix E = r(table)
        assert rowsof(E) == `kf'
        forvalues j = 1/`kf' {
            assert reldif(E[`j', 1], S[1, `j']) < 1e-10
            assert reldif(E[`j', 2], S[rownumb(S, "ll"), `j']) < 1e-10
            assert reldif(E[`j', 3], S[rownumb(S, "ul"), `j']) < 1e-10
        }
        local rn : rownames E
        assert strpos(`"`rn'"', "eq1") == 0
        assert strpos(`"`rn'"', "lns1") == 0
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_7"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 7"
    display as error "FAIL: R20_7 (rc=" _rc ")"
}

**## 8. a named meqrlogit result beside a regress in one plot
local ++test_count
capture noisily {
    webuse bangladesh, clear
    quietly meqrlogit c_use urban age || district:
    estimates store r20_me
    quietly logit c_use urban age
    estimates store r20_lg
    eplot r20_me r20_lg, nodraw
    matrix E = r(table)
    * urban, age and _cons, aligned across both models; no lns1_1_1 row.
    assert rowsof(E) == 3
    assert colsof(E) == 6
    assert !missing(E[1, 1]) & !missing(E[1, 4])
    estimates drop r20_me r20_lg
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_8"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 8"
    display as error "FAIL: R20_8 (rc=" _rc ")"
}

**# OPUS-3: ancillary equations that are not named "/"

**## 9. xtreg, mle: sigma_u and sigma_e are not plotted
local ++test_count
capture noisily {
    webuse nlswork, clear
    quietly keep in 1/3000
    quietly xtset idcode
    quietly xtreg ln_wage age grade, mle
    matrix S = r(table)
    eplot ., nodraw
    matrix E = r(table)
    assert rowsof(E) == 3
    forvalues j = 1/3 {
        assert reldif(E[`j', 2], S[rownumb(S, "ll"), `j']) < 1e-10
        assert reldif(E[`j', 3], S[rownumb(S, "ul"), `j']) < 1e-10
    }
    local rn : rownames E
    assert strpos(`"`rn'"', "sigma") == 0
    assert strpos(`"`rn'"', "ln_wage:") == 0
    eplot ., keep(age grade) nodraw
    assert rowsof(r(table)) == 2
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_9"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 9"
    display as error "FAIL: R20_9 (rc=" _rc ")"
}

**## 10. the last e(k_aux) equations are ancillary (intreg, frontier, xtologit)
local ++test_count
capture noisily {
    webuse nlswork, clear
    quietly keep in 1/3000
    quietly xtset idcode
    gen byte hi = ln_wage > 1.7
    * command | expected plotted rows | text no row name may contain
    quietly intreg ln_wage ln_wage age grade
    eplot ., nodraw
    assert rowsof(r(table)) == 3
    local rn : rownames r(table)
    assert strpos(`"`rn'"', "lnsigma") == 0
    quietly frontier ln_wage age grade
    eplot ., nodraw
    assert rowsof(r(table)) == 3
    local rn : rownames r(table)
    assert strpos(`"`rn'"', "lnsig2") == 0
    quietly xtologit hi age
    eplot ., nodraw
    assert rowsof(r(table)) == 1
    local rn : rownames r(table)
    assert strpos(`"`rn'"', "cut1") == 0 & strpos(`"`rn'"', "sigma2_u") == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_10"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 10"
    display as error "FAIL: R20_10 (rc=" _rc ")"
}

**## 11. guard: estimators already handled keep their rows
local ++test_count
* guard: expected green at HEAD too
capture noisily {
    webuse nlswork, clear
    quietly keep in 1/3000
    quietly xtset idcode
    gen byte hi = ln_wage > 1.7
    quietly xttobit ln_wage age grade, ll(0)
    eplot ., nodraw
    assert rowsof(r(table)) == 3
    quietly heckman ln_wage age, select(hi = grade)
    eplot ., nodraw
    assert rowsof(r(table)) == 4
    quietly zinb hours age, inflate(grade)
    eplot ., nodraw
    assert rowsof(r(table)) == 4
    quietly sureg (ln_wage age) (hours age)
    eplot ., nodraw
    assert rowsof(r(table)) == 4
    quietly gnbreg hours age
    eplot ., nodraw
    assert rowsof(r(table)) == 3
    quietly mixed ln_wage age || idcode:
    eplot ., nodraw
    assert rowsof(r(table)) == 2
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_11"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 11"
    display as error "FAIL: R20_11 (rc=" _rc ")"
}

**# OPUS-4: baselevels adds no reference row to mlogit's base outcome

**## 12. no "3:" reference row; the other outcomes keep theirs
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly mlogit rep78 mpg i.foreign if rep78 >= 3, baseoutcome(3)
    eplot ., baselevels nodraw export(r20_fb, replace) drop(_cons)
    frame r20_fb {
        quietly count if substr(label, 1, 2) == "3:"
        assert r(N) == 0
        quietly count if type == 2
        assert r(N) == 2
        quietly count if label == "4: Domestic" & type == 2
        assert r(N) == 1
        quietly count if label == "5: Domestic" & type == 2
        assert r(N) == 1
    }
    frame drop r20_fb
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_12"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 12"
    display as error "FAIL: R20_12 (rc=" _rc ")"
}

**# OPUS-5: drop() of an omitted or base term is not an error

**## 13. drop(c2) for o.c2 and drop(1.rep78) for 1b.rep78
local ++test_count
capture noisily {
    sysuse auto, clear
    gen c2 = 2 * mpg
    quietly regress price mpg i.rep78 c2
    eplot ., drop(c2) nodraw
    assert rowsof(r(table)) == 6
    eplot ., drop(1.rep78) nodraw
    assert rowsof(r(table)) == 6
    eplot ., drop(c2 1.rep78 _cons) nodraw
    assert rowsof(r(table)) == 5
    capture eplot ., drop(nosuch) nodraw
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_13"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 13"
    display as error "FAIL: R20_13 (rc=" _rc ")"
}

**# OPUS-6: a rename() target takes its variable label

**## 14. rename(mpg = weight) is labelled "Weight (lbs.)"
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg turn
    eplot ., rename(mpg = weight) drop(_cons) nodraw
    local lbl : variable label weight
    mata: st_local("r1", st_matrixrowstripe("r(table)")[1, 2])
    assert `"`r1'"' == `"`lbl'"'
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_14"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 14"
    display as error "FAIL: R20_14 (rc=" _rc ")"
}

**# SONA-1: order() keeps rows that share a label in input order

**## 15. five "Study B" rows stay .2 .7 .9 1.1 1.3, on every call
local ++test_count
capture noisily {
    clear
    input str40 lab double(b lo hi) byte ty
    "Study A" 0.5 0.1 0.9 1
    "Study B" 0.2 -0.1 0.5 1
    "Study B" 0.7 0.3 1.1 1
    "Study B" 0.9 0.3 1.1 1
    "Study B" 1.1 0.3 1.5 1
    "Study C" 0.1 -0.2 0.4 1
    "Study B" 1.3 0.3 1.5 1
    "Overall" 0.35 0.2 0.5 5
    end
    forvalues rep = 1/4 {
        eplot b lo hi, labels(lab) type(ty) order("Study B" "Study A") nodraw
        matrix E = r(table)
        local k 0
        foreach v in .2 .7 .9 1.1 1.3 .5 .1 .35 {
            local ++k
            assert reldif(E[`k', 1], `v') < 1e-12
        }
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_15"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 15"
    display as error "FAIL: R20_15 (rc=" _rc ")"
}

**# SONA-2: groups() names data-mode rows whose labels contain spaces

**## 16. groups("Study A" "Study B" = "G1" "Study C" = "G2")
local ++test_count
capture noisily {
    clear
    input str20 lab double(b lo hi)
    "Study A" 0.1 -0.2 0.4
    "Study B" 0.3 0 0.6
    "Study C" 0.5 0.2 0.9
    "Study D" 0.6 0.2 0.9
    end
    eplot b lo hi, labels(lab) groups("Study A" "Study B" = "G1" "Study C" = "G2") ///
        nodraw export(r20_g, replace)
    frame r20_g {
        sort pos
        assert label[1] == "G1" & type[1] == 0
        assert label[2] == "Study A" & label[3] == "Study B"
        assert label[4] == "G2" & type[4] == 0
        assert label[5] == "Study C" & label[6] == "Study D"
    }
    frame drop r20_g
    * A spaced label in two groups is still refused.
    capture eplot b lo hi, labels(lab) groups("Study A" = "G1" "Study A" = "G2") nodraw
    assert _rc == 198
    * A spaced label that matches nothing names the whole label.
    capture eplot b lo hi, labels(lab) groups("Study Z" = "G1") nodraw
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_16"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 16"
    display as error "FAIL: R20_16 (rc=" _rc ")"
}

**# SONA-3: headers() on a duplicated label goes above its first row

**## 17. three and two "B" rows
local ++test_count
capture noisily {
    clear
    input str20 lab double(b lo hi)
    "A" 0.1 -0.2 0.4
    "B" 0.3 0 0.6
    "B" 0.4 0 0.6
    "B" 0.45 0 0.6
    "C" 0.5 0.2 0.9
    end
    eplot b lo hi, labels(lab) headers(B = "HDR") nodraw export(r20_h, replace)
    frame r20_h {
        sort pos
        assert label[1] == "A"
        assert label[2] == "HDR" & type[2] == 0
        assert label[3] == "B" & label[4] == "B" & label[5] == "B"
    }
    frame drop r20_h
    drop in 4
    forvalues rep = 1/4 {
        eplot b lo hi, labels(lab) headers(B = "HDR") nodraw export(r20_h, replace)
        frame r20_h {
            sort pos
            assert label[2] == "HDR" & label[3] == "B" & label[4] == "B"
        }
    }
    frame drop r20_h
    * Two headers on one row keep the order given.
    eplot b lo hi, labels(lab) headers(A = "H1" A = "H2") nodraw export(r20_h, replace)
    frame r20_h {
        sort pos
        assert label[1] == "H1" & label[2] == "H2" & label[3] == "A"
    }
    frame drop r20_h
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_17"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 17"
    display as error "FAIL: R20_17 (rc=" _rc ")"
}

**# SONA-4: frame-mode auto-detected weight/type columns are escapable

**## 18. an unusable auto-detected weight or type column is ignored with a note
local ++test_count
capture noisily {
    clear
    frame create r20_res
    frame r20_res {
        input str20 label double(estimate ll ul weight)
        "A" 0.1 -0.2 0.4 .
        "B" 0.3 0 0.6 .
        end
    }
    tempfile lf
    _r20_logrun `"`lf'"' eplot, frame(r20_res) nodraw
    assert `_r20_rc' == 0
    assert r(k) == 2
    _r20_grep, file(`"`lf'"') text("weight")
    assert r(n) >= 1
    * Named explicitly, the same column is still refused.
    capture eplot, frame(r20_res) weights(weight) nodraw
    assert _rc == 198
    * The hand-off from frame to data mode is not a user option: the old
    * frameauto() spelling is refused, and an explicit refusal stands.
    frame r20_res {
        capture eplot estimate ll ul, labels(label) weights(weight) ///
            frameauto(weights) nodraw
        assert _rc == 198
        gen str8 t = "linear"
        capture eplot estimate ll ul, labels(label) type(t) frameauto(type) nodraw
        assert _rc == 198
        * A characteristic set by hand on an ordinary frame claims nothing.
        char _dta[_eplot_frameauto] "r20_res weights type"
        capture eplot estimate ll ul, labels(label) weights(weight) nodraw
        assert _rc == 198
        char _dta[_eplot_frameauto] "`c(frame)' weights"
        capture eplot estimate ll ul, labels(label) weights(weight) nodraw
        assert _rc == 198
        char _dta[_eplot_frameauto]
        drop t
    }
    * Route (a): a characteristic on the source frame is not inherited by
    * the work frame, whatever token it names.
    frame r20_res: gen str8 type = "linear"
    forvalues j = 1/40 {
        local tok = "__" + string(`j', "%06.0f")
        frame r20_res: char _dta[_eplot_frameauto] "`tok' type weights"
        capture eplot, frame(r20_res) type(type) weights(weight) nodraw
        assert _rc == 198
    }
    frame r20_res: char _dta[_eplot_frameauto]
    frame r20_res: drop type
    * Route (b): a user frame named like a tempname, with the characteristic
    * naming that frame, claims nothing in data mode.
    capture frame drop __000ZZZ
    frame copy r20_res __000ZZZ
    frame __000ZZZ {
        char _dta[_eplot_frameauto] "__000ZZZ weights"
        capture eplot estimate ll ul, labels(label) weights(weight) nodraw
        assert _rc == 198
    }
    frame drop __000ZZZ
    assert `"$EPLOT_FRAMEAUTO_TOKEN"' == ""
    frame drop r20_res

    frame create r20_res3
    frame r20_res3 {
        input str20 label double(estimate ll ul) str10 type
        "A" 0.1 -0.2 0.4 "linear"
        "B" 0.3 0 0.6 "logistic"
        end
    }
    _r20_logrun `"`lf'"' eplot, frame(r20_res3) nodraw
    assert `_r20_rc' == 0
    assert r(k) == 2
    _r20_grep, file(`"`lf'"') text("type")
    assert r(n) >= 1
    capture eplot, frame(r20_res3) type(type) nodraw
    assert _rc == 198
    frame drop r20_res3
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_18"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 18"
    display as error "FAIL: R20_18 (rc=" _rc ")"
}

**# SONA-6: r(table) row names, one row at a time

**## 19. an unusable label loses only its own name; ` and $ are kept
local ++test_count
capture noisily {
    clear
    input str60 lab double(b lo hi)
    "Smith 2010.x" 0.1 -0.2 0.4
    "B" 0.3 0 0.6
    "A very long study label exceeding thirty-two chars" 0.2 0 0.4
    "C" 0.4 0.1 0.7
    end
    eplot b lo hi, labels(lab) nodraw
    mata: st_local("n2", st_matrixrowstripe("r(table)")[2, 2])
    mata: st_local("n4", st_matrixrowstripe("r(table)")[4, 2])
    assert "`n2'" == "B" & "`n4'" == "C"
    mata: st_local("n1", st_matrixrowstripe("r(table)")[1, 2])
    assert "`n1'" != "B" & "`n1'" != ""

    clear
    set obs 2
    gen str40 lab = "Cost " + char(96) + "y' z " + char(36) + "w" in 1
    replace lab = "plain" in 2
    gen double b = _n / 10
    gen double lo = b - .1
    gen double hi = b + .1
    eplot b lo hi, labels(lab) nodraw
    mata: st_numscalar("r20_ok", st_matrixrowstripe("r(table)")[1, 2] == ///
        "Cost " + char(96) + "y' z " + char(36) + "w")
    assert scalar(r20_ok) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_19"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 19"
    display as error "FAIL: R20_19 (rc=" _rc ")"
}

**# SONA-8: default Row labels carry the observation number

**## 20. eplot b lo hi if _n >= 3 labels rows "Row 3", "Row 4"
local ++test_count
capture noisily {
    clear
    input double(b lo hi)
    0.1 -0.2 0.4
    0.3 0 0.6
    0.5 0.2 0.9
    0.7 0.2 0.9
    end
    eplot b lo hi if _n >= 3, nodraw nonull
    local rn : rownames r(table)
    assert `"`rn'"' == "Row 3" | `"`rn'"' == `""Row 3" "Row 4""' | ///
        `"`rn'"' == "Row 3 Row 4"
    mata: st_local("n1", st_matrixrowstripe("r(table)")[1, 2])
    mata: st_local("n2", st_matrixrowstripe("r(table)")[2, 2])
    assert "`n1'" == "Row 3" & "`n2'" == "Row 4"
    eplot b lo hi in 2/4, keep("Row 3") nodraw nonull
    assert rowsof(r(table)) == 1 & reldif(r(table)[1, 1], .5) < 1e-12
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_20"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 20"
    display as error "FAIL: R20_20 (rc=" _rc ")"
}

**# SONA-9: an estimate outside its own interval is named in a note

**## 21. b = .9 with [.1, .4]
local ++test_count
capture noisily {
    clear
    input str4 lab double(b lo hi)
    "out" 0.9 0.1 0.4
    "in" 0.3 0 0.6
    end
    tempfile lf
    _r20_logrun `"`lf'"' eplot b lo hi, labels(lab) nodraw
    assert `_r20_rc' == 0
    _r20_grep, file(`"`lf'"') regex("outside .*interval.*: out")
    assert r(n) == 1
    _r20_logrun `"`lf'"' eplot b lo hi in 2, labels(lab) nodraw
    _r20_grep, file(`"`lf'"') text("outside")
    assert r(n) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_21"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 21"
    display as error "FAIL: R20_21 (rc=" _rc ")"
}

**# SONA-10: more rows than a matrix can hold

**## 22. 66,000 rows at the default maxvar: an up-front r(920) naming the limit
* Past c(macrolen) the axis-label list cannot be built; this used to surface
* as a bare "line too long" deep in the graph build.  (With set maxvar 20000
* the same data draw at rc 0 with a note that r(table) exceeds the
* c(max_matdim)-row matrix limit; that run takes about ten minutes, because
* labels are accumulated in one growing macro, so it is not part of the
* suite.)
local ++test_count
capture noisily {
    clear
    quietly set obs 66000
    gen double b = _n / 1e5
    gen double lo = b - .1
    gen double hi = b + .1
    tempfile lf
    _r20_logrun `"`lf'"' eplot b lo hi, nodraw nonull
    assert `_r20_rc' == 920
    _r20_grep, file(`"`lf'"') text("too many rows to label")
    assert r(n) == 1
    assert _N == 66000
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_22"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 22"
    display as error "FAIL: R20_22 (rc=" _rc ")"
}

**# SONB-1: the values column fits inside the graph

**## 23. values text and header stay inside the graph, measured in pixels
* The oracle is the exported PNG, not a width table: the rightmost column
* holding any non-background pixel must lie left of the graph's right edge.
* Each configuration must also draw its values text (counted in the SVG), so
* the check cannot pass on a graph without a column.
local ++test_count
capture noisily {
    * Stata's Python with Pillow is required: a hard failure, not a skip.
    capture python: from PIL import Image
    if _rc {
        display as error "test 23 requires Pillow in Stata's Python (pip install pillow into the interpreter that python query reports)"
        exit 198
    }
    python: exec("def _r20_edge(fn):\n    from PIL import Image\n    from sfi import Scalar\n    im = Image.open(fn).convert('RGB')\n    w, h = im.size\n    px = im.load()\n    bg = px[w - 1, 0]\n    right = -1\n    for x in range(w - 1, -1, -1):\n        if any(max(abs(px[x, y][0] - bg[0]), abs(px[x, y][1] - bg[1]), abs(px[x, y][2] - bg[2])) > 40 for y in range(h)):\n            right = x\n            break\n    Scalar.setValue('_r20_gap', w - 1 - right)\n", globals())
    local nbad 0
    local nshown 0
    local ncap 0
    local cfgs ""
    foreach mag in 1 1000 100000 {
        foreach dp in 2 4 {
            foreach s in vsmall small medium large vlarge {
                local cfgs `"`cfgs' "`mag' `dp' `s' -""'
            }
        }
    }
    local cfgs `"`cfgs' "1 2 medium WWWWWWWWWWWWWWWWWWWW" "1 2 medium MMMMMMMMMMMMmmmmwwww@@" "1 2 large &&&&&&&&&&&&&&&&&&&&&&&&&&&&""'
    local cjk "效果量和置信区间估计值分析表"
    local cfgs `"`cfgs' "1 2 vsmall WWWWWWWWWWWWWWWWWWWW" "1 2 vsmall &&&&&&&&&&&&&&&&&&&&&&&&&&&&""'
    local cfgs `"`cfgs' "1 2 small CJK" "1 2 medium CJK""'
    local k 0
    foreach cfg of local cfgs {
        local ++k
        tokenize `"`cfg'"'
        local mag `1'
        local dp `2'
        local s `3'
        local vt `"`4'"'
        if `"`vt'"' == "CJK" local vt `"`cjk'"'
        if `"`vt'"' == "`cjk'" assert ustrlen(`"`vt'"') == 14
        local vopt ""
        if `"`vt'"' != "-" local vopt `"vtitle(`"`vt'"')"'
        clear
        quietly set obs 3
        gen str14 group = "Row " + string(_n)
        gen double tr = `mag' * (1.2345 + _n / 10)
        gen double lci = -`mag' * (1.11111 + _n / 10)
        gen double uci = `mag' * (2.33333 + _n / 10)
        tempfile lf
        _r20_logrun `"`lf'"' eplot tr lci uci, labels(group) values dp(`dp') ///
            vsize(`s') `vopt' nonull name(r20_v, replace)
        assert `_r20_rc' == 0
        * A column wider than half the graph is capped with a note (test
        * 33); every other column must fit.
        _r20_grep, file(`"`lf'"') text("smaller vsize()")
        local capped = r(n) > 0
        local fn "`c(tmpdir)'/r20_values_`k'"
        quietly graph export "`fn'.svg", name(r20_v) as(svg) replace
        quietly graph export "`fn'.png", name(r20_v) as(png) width(1600) replace
        _r20_grep, file("`fn'.svg") text("fill:#404040") and("</text>")
        if r(n) >= 3 local ++nshown
        _r20_pngedge, file("`fn'.png")
        if `capped' local ++ncap
        else if r(gap) < 2 {
            local ++nbad
            display as error `"text at the right edge: `cfg' gap=`r(gap)' px"'
        }
        capture erase "`fn'.svg"
        capture erase "`fn'.png"
    }
    display as text "R20_23: `k' configurations, `ncap' capped with a note"
    assert `nshown' == `k'
    assert `nbad' == 0
    assert `ncap' <= `k' / 3
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_23"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 23"
    display as error "FAIL: R20_23 (rc=" _rc ")"
}
capture graph drop r20_v

**# SONB-2: a literal "}" in bold row labels and in vtitle()

**## 24. "A}B hdr", "Overall a}b", vtitle("OR a}b") are drawn whole
local ++test_count
capture noisily {
    clear
    input str30 lab double(es lo hi) byte type
    "Group (n={5})" . . . 0
    "a" 1.1 .9 1.3 1
    "A}B hdr" . . . 0
    "b" 1.2 1 1.4 1
    "Overall a}b" 1.15 1 1.3 5
    end
    eplot es lo hi, labels(lab) type(type) nonull values vtitle("OR a}b") ///
        name(r20_b, replace)
    local fn "`c(tmpdir)'/r20_brace.svg"
    quietly graph export "`fn'", name(r20_b) as(svg) replace
    foreach t in "A}B hdr" "Overall a}b" "OR a}b" "Group (n={5})" {
        _r20_grep, file("`fn'") text(`">`t'</text>"') and("font-weight:bold;")
        assert r(n) == 1
    }
    _r20_grep, file("`fn'") text("<tspan")
    assert r(n) == 0
    capture erase "`fn'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_24"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 24"
    display as error "FAIL: R20_24 (rc=" _rc ")"
}
capture graph drop r20_b

**# SONB-3: msize(), ciwidth() and scheme() are validated

**## 25. bogus and multi-word values exit r(198) in data, estimates and matrix modes
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    matrix R = (1, .5, 1.5 \ 2, 1.5, 2.5)
    clear
    set obs 3
    gen double es = 1 + _n / 10
    gen double lo = es - .2
    gen double hi = es + .2
    local bad `" "msize(bogus)" "msize(medium small)" "msize(-1)" "msize(12-px)" "msize(1 pt)" "msize(1e400)" "ciwidth(1e400)" "ciwidth(1 pt)" "ciwidth(bogus)" "ciwidth(thick thin)" "scheme(bogus)" "'
    foreach o of local bad {
        capture eplot es lo hi, `o' nonull nodraw
        assert _rc == 198
        capture eplot ., `o' nodraw
        assert _rc == 198
        capture eplot, matrix(R) `o' nodraw
        assert _rc == 198
    }
    * guard: documented forms are accepted
    local good `" "msize(*1.5)" "msize(2pt)" "msize(vsmall)" "msize(3)" "msize(12-pt)" "msize(1.)" "msize(.5cm)" "ciwidth(medthick)" "ciwidth(0.5)" "ciwidth(1.)" "ciwidth(*2)" "scheme(s1mono)" "'
    foreach o of local good {
        eplot es lo hi, `o' nonull nodraw
        eplot ., `o' nodraw
        eplot, matrix(R) `o' nodraw
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_25"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 25"
    display as error "FAIL: R20_25 (rc=" _rc ")"
}

**# SONB-4: RGB, CMYK and HSV components are range-checked

**## 26. out-of-range or non-integer components exit r(198)
local ++test_count
capture noisily {
    clear
    set obs 3
    gen double es = 1 + _n / 10
    gen double lo = es - .2
    gen double hi = es + .2
    foreach c in `""256 0 0""' `""1e2 0 0""' `""-1 0 0""' `""12.5 0 0""' ///
        `""300 0 0 0""' `""hsv 400 1 1""' `""hsv 120 2 1""' {
        capture eplot es lo hi, mcolor(`c') nonull nodraw
        assert _rc == 198
    }
    * guard: valid RGB, CMYK (integers or proportions) and HSV
    foreach c in `""0 0 255""' `""255 255 255""' `""0 0 255 0""' ///
        `"".334 .157 0 .565""' `""hsv 120 .5 .5""' {
        eplot es lo hi, mcolor(`c') nonull nodraw
    }
    eplot es lo hi, mcolor(0 0 255) nonull nodraw
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_26"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 26"
    display as error "FAIL: R20_26 (rc=" _rc ")"
}

**# SONB-5: values text formats

**## 27. dp() above 20 is refused; date formats are refused; %-9.2f has no trailing blank
local ++test_count
capture noisily {
    clear
    set obs 2
    gen double es = 1.23456789 + _n / 10
    gen double lo = es - .2
    gen double hi = es + .2
    foreach d in 21 30 200 {
        capture eplot es lo hi, values dp(`d') nonull nodraw
        assert _rc == 198
    }
    eplot es lo hi, values dp(20) nonull nodraw export(r20_dp, replace)
    frame r20_dp: assert strpos(values[1], "1.334567889999999") == 1 & strpos(values[1], "e") == 0
    frame drop r20_dp
    foreach f in %td %tc %21x {
        capture eplot es lo hi, values vformat(`f') nonull nodraw
        assert _rc == 198
    }
    eplot es lo hi, values vformat(%-9.2f) nonull nodraw export(r20_dp, replace)
    frame r20_dp: assert values[1] == "1.33 (1.13, 1.53)"
    frame drop r20_dp
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_27"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 27"
    display as error "FAIL: R20_27 (rc=" _rc ")"
}

**## 28. %9,2f rounds half away from zero; exponent text shows unrounded values
local ++test_count
capture noisily {
    clear
    input double(es lo hi)
    2.675 .125 3.125
    end
    eplot es lo hi, values vformat(%9,2f) nonull nodraw export(r20_dp, replace)
    frame r20_dp: assert values[1] == "2,68 (0,13, 3,13)"
    frame drop r20_dp
    clear
    input double(es lo hi)
    1e22 .004 2e22
    end
    eplot es lo hi, values nonull nodraw export(r20_dp, replace)
    frame r20_dp: assert strpos(values[1], "(4.00e-03,") > 0
    frame drop r20_dp
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_28"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 28"
    display as error "FAIL: R20_28 (rc=" _rc ")"
}

**# SONB-6: export() with two names is refused before drawing

**## 29. export(a b) exits r(198) and writes no frame
local ++test_count
capture noisily {
    clear
    set obs 2
    gen double es = _n
    gen double lo = es - .5
    gen double hi = es + .5
    capture frame drop r20a
    capture frame drop r20b
    * A successful call first, so stale r() would show.
    eplot es lo hi, nodraw nonull
    assert r(N) == 2
    capture noisily eplot es lo hi, export(r20a r20b) nodraw
    assert _rc == 198
    capture confirm frame r20a
    assert _rc != 0
    capture confirm frame r20b
    assert _rc != 0
    assert missing(r(N)) & missing(r(k))
    local m : r(matrices)
    assert "`m'" == ""
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_29"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 29"
    display as error "FAIL: R20_29 (rc=" _rc ")"
}

**# SONB-7(c) and cross-scope: matrix-mode p-values

**## 30. r(pvalues) aligns with r(table); export() carries pvalue
local ++test_count
capture noisily {
    matrix S = (1, .5 \ 2, 1 \ 3, 1 \ 1, 0)
    matrix rownames S = a b c d
    eplot, matrix(S) values stars export(r20_sy, replace) nodraw
    assert rowsof(r(pvalues)) == rowsof(r(table))
    assert rowsof(r(pvalues)) == 4
    assert missing(r(pvalues)[4, 1])
    assert reldif(r(pvalues)[1, 1], 2 * normal(-2)) < 1e-12
    frame r20_sy {
        confirm numeric variable pvalue
        assert reldif(pvalue[3], 2 * normal(-3)) < 1e-12
        assert missing(pvalue[4])
    }
    frame drop r20_sy
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_30"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 30"
    display as error "FAIL: R20_30 (rc=" _rc ")"
}

**# Cross-scope: no s() left behind; matrix() with frame() refused up front

**## 31. s() is empty after eplot; matrix() + frame() exits 198 with no r()
local ++test_count
capture noisily {
    matrix M = (.1, -.2, .4 \ .3, 0, .6)
    eplot, matrix(M) nodraw
    local s : s(macros)
    assert "`s'" == ""
    return clear
    capture eplot, matrix(M) frame(r20_res) nodraw
    assert _rc == 198
    local m : r(scalars)
    assert "`m'" == ""
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_31"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 31"
    display as error "FAIL: R20_31 (rc=" _rc ")"
}

**# SONA-5: names that are stored estimates and variables are noted

**## 32. data mode is kept (documented precedence) and a note names the clash
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store x1
    quietly regress price weight
    estimates store x2
    quietly regress price length
    estimates store x3
    gen x1 = 1
    gen x2 = 0
    gen x3 = 2
    tempfile lf
    _r20_logrun `"`lf'"' eplot x1 x2 x3, nodraw nonull
    assert `_r20_rc' == 0
    assert missing(r(n_models))
    _r20_grep, file(`"`lf'"') regex("stored estimat")
    assert r(n) >= 1
    eplot x1 x2 x3, nodraw nonull
    estimates drop x1 x2 x3
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_32"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 32"
    display as error "FAIL: R20_32 (rc=" _rc ")"
}

**# RC-2: a values column too wide for the graph is capped, with a note

**## 33. a long vtitle() at large sizes leaves the plot region intact
* Oracle: the drawn effect axis (lowest horizontal line in the SVG) keeps at
* least a quarter of the graph width, every marker lies on it, no text starts
* left of the graph, the right margin stays within half the width, and the
* note names the remedy.
local ++test_count
capture noisily {
    foreach s in medium large vlarge {
        clear
        quietly set obs 3
        gen str14 group = "Row " + string(_n)
        gen double tr = 1.2345 + _n / 10
        gen double lci = tr - .3
        gen double uci = tr + .3
        tempfile lf
        _r20_logrun `"`lf'"' eplot tr lci uci, labels(group) values vsize(`s') ///
            vtitle("Adjusted hazard ratio (95% confidence interval)") nonull ///
            name(r20_l, replace)
        assert `_r20_rc' == 0
        local cmd `"`r(cmd)'"'
        assert regexm(`"`cmd'"', "margin\(l\+2 r\+([0-9]+)")
        assert real(regexs(1)) <= floor(0.5 * 100 * 5.5 / 4)
        if "`s'" != "medium" {
            _r20_grep, file(`"`lf'"') text("smaller vsize()")
            assert r(n) == 1
        }
        local fn "`c(tmpdir)'/r20_long_`s'.svg"
        quietly graph export "`fn'", name(r20_l) as(svg) replace
        tempname fh
        local width .
        local axy -1
        local ax1 .
        local ax2 .
        local minx 1e9
        local ncirc 0
        local cxs ""
        file open `fh' using "`fn'", read text
        file read `fh' line
        while r(eof) == 0 {
            if regexm(`"`macval(line)'"', `"viewBox="0 0 ([0-9.]+) "') local width = real(regexs(1))
            if regexm(`"`macval(line)'"', `"<line x1="(-?[0-9.]+)" y1="(-?[0-9.]+)" x2="(-?[0-9.]+)" y2="(-?[0-9.]+)""') {
                local _x1 = real(regexs(1))
                local _y1 = real(regexs(2))
                local _x2 = real(regexs(3))
                local _y2 = real(regexs(4))
                if abs(`_y1' - `_y2') < 0.01 & abs(`_x2' - `_x1') > 1 & `_y1' > `axy' {
                    local axy = `_y1'
                    local ax1 = min(`_x1', `_x2')
                    local ax2 = max(`_x1', `_x2')
                }
            }
            if regexm(`"`macval(line)'"', `"<circle cx="(-?[0-9.]+)""') {
                local ++ncirc
                local cxs "`cxs' `=regexs(1)'"
            }
            if regexm(`"`macval(line)'"', `"<text x="(-?[0-9.]+)""') {
                local minx = min(`minx', real(regexs(1)))
            }
            file read `fh' line
        }
        file close `fh'
        capture erase "`fn'"
        display as text "R20_33 vsize(`s'): axis `ax1'-`ax2' of `width', markers `cxs', min text x `minx'"
        assert `ax2' - `ax1' >= 0.25 * `width'
        * Each marker is a fill and an outline circle.
        assert `ncirc' >= 3
        foreach cx of local cxs {
            assert `cx' >= `ax1' & `cx' <= `ax2'
        }
        assert `minx' >= 0
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: R20_33"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 33"
    display as error "FAIL: R20_33 (rc=" _rc ")"
}
capture graph drop r20_l

capture graph drop _all
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
_eplot_qa_result test_eplot_review_2026_10_20, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    capture log close
    exit 1
}
capture log close
