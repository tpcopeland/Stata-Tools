* test_review_2026_09_26_fixes.do - fixes from the independent review of 2.1.12
* Regression suite, written against the uncommitted 2.1.12 draft on top of
* 40e28488 before any fix:
*   V1  AIC/BIC/QICu count the estimated free parameters under robust-type
*       vce: base levels, omitted levels and mlogit's base equation are not
*       parameters (their collected SE is 0), and e(rank) is kept unless it is
*       capped by the cluster, panel or replication count
*   V2  linear constraints stay netted out under robust vce (e(rank), as
*       estat ic); the few-cluster case with constraints is pinned as
*       documented in regtab.sthlp
*   V3  collect: bs/bstrap/bootstrap/jknife/jackknife fits are classified from
*       the collected command, whatever labels collect attached to it
*   V4  regtab leaves the labels (and the level set) of the collection's
*       result dimension as it found them, with and without stats()
*   V5  methods sentence: hetprobit counts its variance-equation covariates
*       and is named; qreg and ivregress get their own model nouns
*   V6  a "~" in a Markdown cell renders literally under GFM strikethrough
* Expected values come from estat ic, from the fitted model's own e(b)/e()
* under a model-based vce, from collect label list read before the call, and
* from markdown-it-py rendering, never from the output under test.

clear all
set more off
set varabbrev off
version 17.0

capture log close _rvf
log using "test_review_2026_09_26_fixes.log", replace text name(_rvf)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local md_checker "`qa_dir'/tools/check_md_render.py"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

* Trimmed contents of column `col' on the one body row whose trimmed label is
* `label'. Errors when the row is absent or duplicated.
capture program drop _rvf_cell
program define _rvf_cell, rclass
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
    }
    return local cell `"`cell'"'
end

* Number of body rows whose trimmed label is `label'.
capture program drop _rvf_nrow
program define _rvf_nrow, rclass
    version 17.0
    args frname label
    frame `frname' {
        quietly count if strtrim(A) == `"`label'"' & _n >= 4
        local n = r(N)
    }
    return scalar n = `n'
end

* Assert the cell of `label' in column `col' shows x at digits(2).
capture program drop _rvf_is
program define _rvf_is
    version 17.0
    args frname label col x
    local want = strtrim(string(round(`x', 0.01), "%32.2f"))
    _rvf_cell `frname' `"`label'"' `col'
    if `"`r(cell)'"' != "`want'" {
        display as error `"`label' `col': got "`r(cell)'", want "`want'""'
        exit 9
    }
end

* The first sentence of r(methods) must equal `want' exactly.
capture program drop _rvf_methods
program define _rvf_methods
    version 17.0
    args got want
    if strpos(`"`got'"', `"`want' Analysis performed in Stata"') != 1 {
        display as error `"methods: got  "`got'""'
        display as error `"       want "`want'""'
        exit 9
    }
end

* estat ic of the active estimates: r(aic), r(bic), r(df).
capture program drop _rvf_ic
program define _rvf_ic, rclass
    version 17.0
    quietly estat ic
    tempname S
    matrix `S' = r(S)
    return scalar df = `S'[1, 4]
    return scalar aic = `S'[1, 5]
    return scalar bic = `S'[1, 6]
end

* Snapshot of the current collection's result dimension: every level with its
* label ("" when it has none), except _r_b, _r_ci and _r_p, which regtab
* relabels on purpose to build its table; and the level list itself.
capture program drop _rvf_lblsnap
program define _rvf_lblsnap, rclass
    version 17.0
    quietly collect label list result, all
    mata: st_local("snap", _rvf_snap())
    quietly collect levelsof result
    local lv `"`s(levels)'"'
    return local levels `"`lv'"'
    return local snap `"`macval(snap)'"'
end

mata:
string scalar _rvf_snap()
{
    real scalar i, k
    string scalar lv, out

    k = strtoreal(st_global("s(k)"))
    out = ""
    for (i = 1; i <= k; i++) {
        lv = st_global("s(level" + strofreal(i) + ")")
        if (anyof(("_r_b", "_r_ci", "_r_p"), lv)) continue
        out = out + lv + "=" + st_global("s(label" + strofreal(i) + ")") + char(10)
    }
    return(out)
}

void _rvf_put_lines(string scalar path, string scalar var)
{
    real scalar fh, i
    string colvector s

    s = st_sdata(., var)
    if (fileexists(path)) unlink(path)
    fh = fopen(path, "w")
    for (i = 1; i <= rows(s); i++) fput(fh, s[i])
    fclose(fh)
}
end

**# V1 parameter count of AIC/BIC/QICu under robust-type vce

* V1a: many clusters, factor base level (reviewer probe: 60.96, estat ic 58.96)
capture noisily {
    sysuse auto, clear
    generate cl = mod(_n, 36)
    quietly logit foreign i.rep78 mpg if rep78 >= 3, vce(cluster cl)
    _rvf_ic
    local aic = r(aic)
    local bic = r(bic)
    assert r(df) == 4
    assert abs(`aic' - 58.95657) < 1e-5
    collect clear
    quietly collect: logit foreign i.rep78 mpg if rep78 >= 3, vce(cluster cl)
    quietly regtab, stats(aic bic)
    display as text "  V1a regtab AIC " %10.5f r(aic_1) ", estat ic " %10.5f `aic'
    assert !missing(r(aic_1), `aic') & reldif(r(aic_1), `aic') < 1e-8
    assert !missing(r(bic_1), `bic') & reldif(r(bic_1), `bic') < 1e-8
}
if _rc == 0 {
    display as result "  PASS: V1a logit i.factor vce(cluster), 35 clusters: AIC/BIC equal estat ic"
    local ++pass_count
}
else {
    display as error "  FAIL: V1a logit i.factor vce(cluster) AIC/BIC (rc=`=_rc')"
    local ++fail_count
}

* V1b: poisson with a factor base level under vce(robust) (reviewer: k=4)
capture noisily {
    sysuse auto, clear
    quietly poisson rep78 i.foreign mpg, vce(robust)
    _rvf_ic
    local aic = r(aic)
    local bic = r(bic)
    assert r(df) == 3
    collect clear
    quietly collect: poisson rep78 i.foreign mpg, vce(robust)
    quietly regtab, stats(aic bic)
    display as text "  V1b regtab AIC " %10.5f r(aic_1) ", estat ic " %10.5f `aic'
    assert !missing(r(aic_1), `aic') & reldif(r(aic_1), `aic') < 1e-8
    assert !missing(r(bic_1), `bic') & reldif(r(bic_1), `bic') < 1e-8
}
if _rc == 0 {
    display as result "  PASS: V1b poisson i.factor vce(robust): k = 3, AIC/BIC equal estat ic"
    local ++pass_count
}
else {
    display as error "  FAIL: V1b poisson i.factor vce(robust) AIC/BIC (rc=`=_rc')"
    local ++fail_count
}

* V1c: mlogit's base-outcome equation is not estimated (reviewer: k=6)
capture noisily {
    sysuse auto, clear
    quietly mlogit rep78 mpg if rep78 >= 3, vce(robust)
    _rvf_ic
    local aic = r(aic)
    local bic = r(bic)
    assert r(df) == 4
    collect clear
    quietly collect: mlogit rep78 mpg if rep78 >= 3, vce(robust)
    quietly regtab, stats(aic bic)
    display as text "  V1c regtab AIC " %10.5f r(aic_1) ", estat ic " %10.5f `aic'
    assert !missing(r(aic_1), `aic') & reldif(r(aic_1), `aic') < 1e-8
    assert !missing(r(bic_1), `bic') & reldif(r(bic_1), `bic') < 1e-8
}
if _rc == 0 {
    display as result "  PASS: V1c mlogit vce(robust): base equation not counted, AIC/BIC equal estat ic"
    local ++pass_count
}
else {
    display as error "  FAIL: V1c mlogit vce(robust) AIC/BIC (rc=`=_rc')"
    local ++fail_count
}

* V1d: xtgee with a factor under vce(robust): QICu = deviance + 2*p with p
* the model-based rank of the same fit (reviewer: QICu +2)
capture program drop _rvf_geedata
program define _rvf_geedata
    version 17.0
    clear
    set seed 12
    quietly set obs 240
    generate id = ceil(_n/4)
    bysort id: generate t = _n
    generate race = 1 + mod(id, 3)
    generate age = 20 + mod(id*7, 40) + t
    generate y = runiform() < invlogit(-2 + 0.03*age + 0.4*(race == 2) - 0.3*(race == 3))
    quietly xtset id t
end
capture noisily {
    _rvf_geedata
    quietly xtgee y i.race age, family(binomial) link(logit) corr(exchangeable)
    local p = e(rank)
    local dev = e(deviance)
    assert `p' == 4
    quietly xtgee y i.race age, family(binomial) link(logit) corr(exchangeable) vce(robust)
    assert !missing(e(deviance), `dev') & reldif(e(deviance), `dev') < 1e-12
    collect clear
    quietly collect: xtgee y i.race age, family(binomial) link(logit) corr(exchangeable) vce(robust)
    quietly regtab, stats(qic)
    display as text "  V1d regtab QICu " %10.5f r(qic_1) ", deviance + 2p " %10.5f `dev' + 2*`p'
    assert !missing(r(qic_1), `dev' + 2*`p') & reldif(r(qic_1), `dev' + 2*`p') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: V1d xtgee i.factor vce(robust): QICu = deviance + 2*rank"
    local ++pass_count
}
else {
    display as error "  FAIL: V1d xtgee i.factor vce(robust) QICu (rc=`=_rc')"
    local ++fail_count
}

* V1e: guard - the capped cases still count every estimated coefficient:
* 2 clusters and 4 coefficients (e(rank) = 1), a bootstrap with 3
* replications (e(rank) = 2), and 3 GEE panels. Expected: the model-based fit.
capture noisily {
    sysuse auto, clear
    generate cl2 = mod(_n, 2)
    quietly logit foreign mpg weight price
    _rvf_ic
    local aic = r(aic)
    local bic = r(bic)
    local ll = e(ll)
    assert r(df) == 4
    quietly logit foreign mpg weight price, vce(cluster cl2)
    assert e(rank) == 1
    collect clear
    quietly collect: logit foreign mpg weight price, vce(cluster cl2)
    quietly regtab, stats(aic bic)
    assert !missing(r(aic_1), -2*`ll' + 2*4) & reldif(r(aic_1), -2*`ll' + 2*4) < 1e-10
    assert !missing(r(aic_1), `aic') & reldif(r(aic_1), `aic') < 1e-8
    assert !missing(r(bic_1), `bic') & reldif(r(bic_1), `bic') < 1e-8

    quietly bootstrap, reps(3) seed(1): logit foreign mpg weight price
    assert e(rank) == 2 & e(N_reps) == 3
    collect clear
    quietly collect: bootstrap, reps(3) seed(1): logit foreign mpg weight price
    quietly regtab, stats(aic bic)
    assert !missing(r(aic_1), `aic') & reldif(r(aic_1), `aic') < 1e-8
    assert !missing(r(bic_1), `bic') & reldif(r(bic_1), `bic') < 1e-8

    _rvf_geedata
    quietly replace id = mod(id, 3) + 1
    bysort id: replace t = _n
    quietly xtset id t
    quietly xtgee y i.race age, family(binomial) link(logit) corr(independent)
    local p = e(rank)
    local dev = e(deviance)
    quietly xtgee y i.race age, family(binomial) link(logit) corr(independent) vce(robust)
    assert e(rank) < `p'
    collect clear
    quietly collect: xtgee y i.race age, family(binomial) link(logit) corr(independent) vce(robust)
    quietly regtab, stats(qic)
    assert !missing(r(qic_1), `dev' + 2*`p') & reldif(r(qic_1), `dev' + 2*`p') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: V1e capped e(rank) (2 clusters, 3 bootstrap reps, 3 panels) still counts every coefficient"
    local ++pass_count
}
else {
    display as error "  FAIL: V1e capped e(rank) cases (rc=`=_rc')"
    local ++fail_count
}

**# V2 linear constraints under robust-type vce

* V2a: constraints(1) vce(robust) and vce(cluster) on 36 clusters: e(rank) = 3
* nets out the constraint, as estat ic (reviewer: 43.79776 vs 41.79776)
capture noisily {
    sysuse auto, clear
    generate cl = mod(_n, 36)
    constraint define 1 mpg = weight
    quietly logit foreign mpg weight price, constraints(1)
    _rvf_ic
    local aic = r(aic)
    local bic = r(bic)
    assert r(df) == 3
    assert abs(`aic' - 41.79776) < 1e-5
    collect clear
    quietly collect: logit foreign mpg weight price, constraints(1) vce(robust)
    quietly collect: logit foreign mpg weight price, constraints(1) vce(cluster cl)
    quietly regtab, stats(aic bic)
    display as text "  V2a regtab AIC " %10.5f r(aic_1) " / " %10.5f r(aic_2) ", estat ic " %10.5f `aic'
    assert !missing(r(aic_1), `aic') & reldif(r(aic_1), `aic') < 1e-8
    assert !missing(r(bic_1), `bic') & reldif(r(bic_1), `bic') < 1e-8
    assert !missing(r(aic_2), `aic') & reldif(r(aic_2), `aic') < 1e-8
    assert !missing(r(bic_2), `bic') & reldif(r(bic_2), `bic') < 1e-8
    constraint drop 1
}
if _rc == 0 {
    display as result "  PASS: V2a constraints netted out under vce(robust) and many-cluster vce(cluster)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2a constraints under robust vce (rc=`=_rc')"
    local ++fail_count
}

* V2b: constraints plus a binding cluster cap (2 clusters), the documented
* rule: k counts the coefficients with a nonzero standard error. A constraint
* fixing a coefficient (price = 0) leaves it with SE 0, so it is netted out
* and AIC equals the model-based fit; an equality constraint (mpg = weight)
* leaves both coefficients with a standard error and the collection holds no
* e(Cns), so k = 4, one more than the model-based e(rank) = 3.
capture noisily {
    sysuse auto, clear
    generate cl2 = mod(_n, 2)
    constraint define 1 mpg = weight
    constraint define 2 price = 0
    quietly logit foreign mpg weight price, constraints(2)
    _rvf_ic
    local aic_fix = r(aic)
    assert r(df) == 3
    quietly logit foreign mpg weight price, constraints(1)
    local ll_eq = e(ll)
    local N_eq = e(N)
    quietly logit foreign mpg weight price, constraints(1) vce(cluster cl2)
    assert e(rank) == 1
    collect clear
    quietly collect: logit foreign mpg weight price, constraints(2) vce(cluster cl2)
    quietly collect: logit foreign mpg weight price, constraints(1) vce(cluster cl2)
    quietly regtab, stats(aic bic)
    assert !missing(r(aic_1), `aic_fix') & reldif(r(aic_1), `aic_fix') < 1e-8
    assert !missing(r(aic_2), -2*`ll_eq' + 2*4) & reldif(r(aic_2), -2*`ll_eq' + 2*4) < 1e-10
    assert !missing(r(bic_2), -2*`ll_eq' + 4*ln(`N_eq')) & reldif(r(bic_2), -2*`ll_eq' + 4*ln(`N_eq')) < 1e-10
    constraint drop 1 2
}
if _rc == 0 {
    display as result "  PASS: V2b constraints plus 2 clusters follow the documented nonzero-SE count"
    local ++pass_count
}
else {
    display as error "  FAIL: V2b constraints plus few clusters (rc=`=_rc')"
    local ++fail_count
}

**# V3 bootstrap and jackknife prefixes, however spelled

* collect attaches no default labels to e(cmd)/e(cmdline) after bs: and
* bstrap:, which sent the fit to the Coef. scale with its intercept shown.
capture noisily {
    sysuse auto, clear
    quietly logit foreign mpg weight
    local bm = _b[mpg]
    local bw = _b[weight]
    local n 0
    foreach pf in "bs, reps(20) seed(1)" "bstrap, reps(20) seed(1)" ///
        "bootstrap, reps(20) seed(1)" "jknife" "jackknife" {
        collect clear
        quietly collect: `pf': logit foreign mpg weight
        capture frame drop _rv3
        quietly regtab, frame(_rv3, replace)
        frame _rv3: local hdr = strtrim(c1[3])
        if "`hdr'" != "OR" {
            display as error "`pf': header `hdr', want OR"
            exit 9
        }
        _rvf_is _rv3 "Mileage (mpg)" c1 `=exp(`bm')'
        _rvf_is _rv3 "Weight (lbs.)" c1 `=exp(`bw')'
        _rvf_nrow _rv3 "Intercept"
        assert r(n) == 0
        local ++n
    }
    assert `n' == 5
}
if _rc == 0 {
    display as result "  PASS: V3 bs/bstrap/bootstrap/jknife/jackknife logit shown as OR = exp(b)"
    local ++pass_count
}
else {
    display as error "  FAIL: V3 bootstrap/jackknife prefix spellings (rc=`=_rc')"
    local ++fail_count
}

**# V4 regtab leaves the collection's result labels as it found them

capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg weight
    quietly collect: logit foreign mpg
    quietly collect label levels result vce `"My "q" VCE"', modify
    quietly collect label levels result N "My N", modify
    quietly collect label levels result ll "My LL", modify
    quietly collect label levels result rank "My rank", modify
    quietly collect label levels result cmd "My cmd", modify
    quietly collect label levels result cmdline "My cmdline", modify
    quietly collect label levels result depvar "My depvar", modify
    * one level with its label removed: it must stay unlabelled
    quietly collect label levels result title "", modify
    _rvf_lblsnap
    local snap0 `"`r(snap)'"'
    local lev0 `"`r(levels)'"'
    assert strpos(`"`snap0'"', `"vce=My "q" VCE"') > 0
    assert strpos(`"`snap0'"', "title=" + char(10)) > 0

    quietly regtab
    _rvf_lblsnap
    if `"`r(snap)'"' != `"`snap0'"' {
        display as error "labels changed by plain regtab:"
        display as error `"`r(snap)'"'
        exit 9
    }
    assert `"`r(levels)'"' == `"`lev0'"'

    quietly regtab, stats(n ll aic bic)
    _rvf_lblsnap
    if `"`r(snap)'"' != `"`snap0'"' {
        display as error "labels changed by regtab, stats():"
        display as error `"`r(snap)'"'
        exit 9
    }
    assert `"`r(levels)'"' == `"`lev0'"'
}
if _rc == 0 {
    display as result "  PASS: V4 result labels and levels unchanged by regtab with and without stats()"
    local ++pass_count
}
else {
    display as error "  FAIL: V4 regtab changed the collection's result labels (rc=`=_rc')"
    local ++fail_count
}

**# V5 methods sentence nouns

local _ci "with 95% confidence intervals from"
local n5 0
capture noisily {
    sysuse auto, clear
    foreach pair in ///
        "hetprobit foreign mpg, het(weight)|Coefficients `_ci' multivariable heteroskedastic probit regression." ///
        "qreg price mpg weight|Coefficients `_ci' multivariable quantile regression." ///
        "qreg price mpg|Coefficients `_ci' univariable quantile regression." ///
        "ivregress 2sls price (mpg = weight) turn|Coefficients `_ci' multivariable instrumental-variables regression." {
        gettoken spec want : pair, parse("|")
        local want = substr(`"`want'"', 2, .)
        collect clear
        quietly collect: `spec'
        quietly regtab
        _rvf_methods `"`r(methods)'"' `"`want'"'
        local ++n5
    }
    assert `n5' == 4
}
if _rc == 0 {
    display as result "  PASS: V5 hetprobit, qreg and ivregress methods sentences"
    local ++pass_count
}
else {
    display as error "  FAIL: V5 methods nouns (rc=`=_rc')"
    local ++fail_count
}

**# V6 tilde in Markdown cells

capture noisily {
    local md "`output_dir'/rvf_tilde.md"
    capture erase "`md'"
    clear
    quietly set obs 2
    generate strL a = ""
    generate strL b = ""
    quietly replace a = "Arm" in 1
    quietly replace b = "Value" in 1
    quietly replace a = "a ~~struck~~ b" in 2
    quietly replace b = "~one~ and x~y" in 2
    quietly puttab a b, markdown("`md'") title("Title ~~t~~")
    * source level: each tilde is backslash-escaped
    mata: st_local("_rv_src", strofreal(sum(cat(st_local("md")) :== ///
        "| a \~\~struck\~\~ b | \~one\~ and x\~y |")))
    assert `_rv_src' == 1
    * rendered level, GFM strikethrough on: the visible text is the source
    clear
    quietly set obs 7
    generate strL e = ""
    quietly replace e = "h3" + char(9) + "Title ~~t~~" in 1
    quietly replace e = "th" + char(9) + "a" in 2
    quietly replace e = "th" + char(9) + "b" in 3
    quietly replace e = "td" + char(9) + "Arm" in 4
    quietly replace e = "td" + char(9) + "Value" in 5
    quietly replace e = "td" + char(9) + "a ~~struck~~ b" in 6
    quietly replace e = "td" + char(9) + "~one~ and x~y" in 7
    tempfile expect result
    mata: _rvf_put_lines(st_local("expect"), "e")
    capture erase "`result'"
    shell python3 "`md_checker'" "`md'" "`expect'" "`result'"
    confirm file "`result'"
    tempname fh
    file open `fh' using "`result'", read text
    file read `fh' line
    file close `fh'
    type "`result'"
    assert "`line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: V6 tilde renders literally with GFM strikethrough enabled"
    local ++pass_count
}
else {
    display as error "  FAIL: V6 tilde in Markdown cells (rc=`=_rc')"
    local ++fail_count
}

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_review_2026_09_26_fixes tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _rvf
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_review_2026_09_26_fixes tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _rvf
