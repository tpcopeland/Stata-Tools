* test_ratetab_v230_review.do - independent review regressions for ratetab, tabtools 2.3.0
* Oracles: hand-computed person-time, ratetab run one grouping variable at a
* time, the closed-form cluster sandwich of the saturated Poisson model
* (Var b_j = G/(G-1) * sum_c (d_cj - Y_cj D_j/Y_j)^2 / D_j^2), and R
* (stats::poisson.test exact limits; glm + sandwich::vcovCL HC0 with the
* G/(G-1) adjustment) run through Rscript.

clear all
set more off
set varabbrev off
version 17.0

capture log close _rtr
log using "test_ratetab_v230_review.log", replace text name(_rtr)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear
global TABTOOLS_set_smallcells

local pass_count = 0
local fail_count = 0

* Recurrent events; level 4 has one event, all in one person among four
capture program drop _rtr_data
program define _rtr_data
    version 17.0
    clear
    set seed 20261005
    set obs 60
    gen long id = _n
    gen double frail = rgamma(0.5, 2)
    expand 3
    bysort id: gen byte k = _n
    gen byte grp = 1 + mod(id, 3)
    replace grp = 4 if id <= 4
    gen double pt = runiform(0.2, 2)
    gen long ev = rpoisson(0.4 * frail * pt * grp)
    replace ev = 0 if grp == 4
    replace ev = 1 if id == 1 & k == 1
end

**# RV1: pyscale() scales the printed person-time, not only the rate
capture noisily {
    clear
    set obs 4
    gen byte g = _n <= 2
    gen long ev = cond(_n == 1, 3, cond(_n == 2, 2, cond(_n == 3, 4, 1)))
    gen double ptd = 365.25 * cond(_n <= 2, 10, 20)
    ratetab g, events(ev) exposure(ptd) pyscale(365.25) per(1) frame(_rv1, replace)
    matrix E = r(estimates)
    assert !missing(E[1, 5], E[2, 5])
    assert reldif(E[1, 5], 40) < 1e-12 & reldif(E[2, 5], 20) < 1e-12
    * printed person-time is in person-years, matching r(estimates)
    frame _rv1: assert strtrim(c3[5]) == "40" & strtrim(c3[6]) == "20"
    frame _rv1: assert strpos(c4[5], "0.1 (") == 1 & strpos(c4[6], "0.3 (") == 1
    frame drop _rv1
}
if _rc == 0 {
    display as result "  PASS: RV1 pyscale() person-time is printed in pyscale units"
    local ++pass_count
}
else {
    display as error "  FAIL: RV1 pyscale() printed person-time (rc=`=_rc')"
    local ++fail_count
}

**# RV2: a missing value in one grouping variable leaves the others' tables alone
capture noisily {
    foreach ci in exact cluster(id) {
        _rtr_data
        gen byte h = mod(_n, 2) if _n > 30
        ratetab grp, events(ev) exposure(pt) per(1) ci(`ci')
        matrix A = r(estimates)
        local NA = r(N)
        ratetab grp h, events(ev) exposure(pt) per(1) ci(`ci')
        matrix B = r(estimates)
        assert r(N) == `NA'
        assert rowsof(B) == rowsof(A) + 2
        matrix B1 = B[1..rowsof(A), 1...]
        assert mreldif(A, B1) < 1e-10
        * h's own table: only the rows with h observed
        ratetab h, events(ev) exposure(pt) per(1) ci(`ci')
        matrix H = r(estimates)
        matrix B2 = B[rowsof(A) + 1..., 4...]
        matrix H2 = H[1..., 4...]
        assert mreldif(H2, B2) < 1e-10
    }
    * a grouping variable missing in every row is refused
    _rtr_data
    gen byte allmiss = .
    capture ratetab grp allmiss, events(ev) exposure(pt)
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: RV2 each grouping variable keeps its own nonmissing sample"
    local ++pass_count
}
else {
    display as error "  FAIL: RV2 missing values across grouping variables (rc=`=_rc')"
    local ++fail_count
}

**# RV3: clustered limits equal the closed-form saturated-model sandwich
capture restore
capture noisily {
    _rtr_data
    ratetab grp, events(ev) exposure(pt) per(1) ci(cluster(id)) level(95)
    matrix C = r(estimates)
    assert el(r(clusters), 1, 1) == 60
    * closed form, by hand
    preserve
    collapse (sum) dc = ev yc = pt, by(grp id)
    bysort grp: egen double D = total(dc)
    bysort grp: egen double Y = total(yc)
    gen double u2 = (dc - yc * D / Y)^2
    bysort grp: egen double U = total(u2)
    quietly levelsof id if D > 0
    local G : word count `r(levels)'
    bysort grp: keep if _n == 1
    gen double se = sqrt(`G' / (`G' - 1) * U) / D
    gen double lb = exp(ln(D / Y) - invnormal(0.975) * se)
    gen double ub = exp(ln(D / Y) + invnormal(0.975) * se)
    sort grp
    forvalues j = 1/4 {
        assert !missing(C[`j', 6], D[`j'] / Y[`j'])
        assert reldif(C[`j', 6], D[`j'] / Y[`j']) < 1e-12
        assert !missing(C[`j', 7], lb[`j'])
        assert reldif(C[`j', 7], lb[`j']) < 1e-9
        assert !missing(C[`j', 8], ub[`j'])
        assert reldif(C[`j', 8], ub[`j']) < 1e-9
    }
    restore
}
if _rc == 0 {
    display as result "  PASS: RV3 clustered limits equal the closed-form sandwich at the exact MLE (1e-9)"
    local ++pass_count
}
else {
    display as error "  FAIL: RV3 clustered limits vs closed form (rc=`=_rc')"
    local ++fail_count
}

**# RV4: R cross-check: exact (poisson.test) and clustered (glm + vcovCL)
capture restore
capture noisily {
    _rtr_data
    local csv "`output_dir'/_rtr_data.csv"
    local rout "`output_dir'/_rtr_r.csv"
    local rs "`output_dir'/_rtr.R"
    capture erase "`rout'"
    export delimited id grp pt ev using "`csv'", replace
    file open _rf using "`rs'", write replace text
    file write _rf `"suppressMessages(library(sandwich))"' _n
    file write _rf `"d <- read.csv("`csv'"); d\$grp <- factor(d\$grp)"' _n
    file write _rf `"out <- NULL"' _n
    file write _rf `"for (lv in c(0.95, 0.90)) {"' _n
    file write _rf `"  z <- qnorm(1 - (1 - lv) / 2)"' _n
    file write _rf `"  m <- glm(ev ~ 0 + grp, offset = log(pt), family = poisson, data = d, control = glm.control(epsilon = 1e-14, maxit = 100))"' _n
    file write _rf `"  se <- sqrt(diag(vcovCL(m, cluster = ~id, type = "HC0", cadjust = TRUE)))"' _n
    file write _rf `"  a <- aggregate(cbind(ev, pt) ~ grp, d, sum)"' _n
    file write _rf `"  ex <- t(sapply(seq_len(nrow(a)), function(i) poisson.test(a\$ev[i], a\$pt[i], conf.level = lv)\$conf.int))"' _n
    file write _rf `"  out <- rbind(out, data.frame(level = lv * 100, grp = a\$grp, clb = exp(coef(m) - z * se), cub = exp(coef(m) + z * se), elb = ex[, 1], eub = ex[, 2]))"' _n
    file write _rf `"}"' _n
    file write _rf `"write.csv(out, "`rout'", row.names = FALSE)"' _n
    file close _rf
    shell Rscript "`rs'"
    confirm file "`rout'"
    foreach lv in 95 90 {
        ratetab grp, events(ev) exposure(pt) per(1) ci(cluster(id)) level(`lv')
        matrix C`lv' = r(estimates)
        ratetab grp, events(ev) exposure(pt) per(1) level(`lv')
        matrix E`lv' = r(estimates)
    }
    preserve
    import delimited using "`rout'", clear varnames(1) asdouble
    sort level grp
    forvalues j = 1/4 {
        * 90% rows come first after sorting
        assert !missing(C90[`j', 7], clb[`j'], C90[`j', 8], cub[`j'])
        assert reldif(C90[`j', 7], clb[`j']) < 1e-8 & reldif(C90[`j', 8], cub[`j']) < 1e-8
        assert !missing(E90[`j', 7], elb[`j'], E90[`j', 8], eub[`j'])
        assert reldif(E90[`j', 7], elb[`j']) < 1e-8 & reldif(E90[`j', 8], eub[`j']) < 1e-8
        assert !missing(C95[`j', 7], clb[`j' + 4], C95[`j', 8], cub[`j' + 4])
        assert reldif(C95[`j', 7], clb[`j' + 4]) < 1e-8 & reldif(C95[`j', 8], cub[`j' + 4]) < 1e-8
        assert !missing(E95[`j', 7], elb[`j' + 4], E95[`j', 8], eub[`j' + 4])
        assert reldif(E95[`j', 7], elb[`j' + 4]) < 1e-8 & reldif(E95[`j', 8], eub[`j' + 4]) < 1e-8
    }
    restore
}
if _rc == 0 {
    display as result "  PASS: RV4 exact and clustered limits equal R (poisson.test; glm + vcovCL) at 95% and 90%"
    local ++pass_count
}
else {
    display as error "  FAIL: RV4 R cross-check (rc=`=_rc')"
    local ++fail_count
}

local _tc = `pass_count' + `fail_count'
display "RESULT: test_ratetab_v230_review tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _rtr
if `fail_count' > 0 exit 1
