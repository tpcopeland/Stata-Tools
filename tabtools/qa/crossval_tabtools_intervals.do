* crossval_tabtools_intervals.do - reference parity for the intervals tabtools
* computes itself and no other crossval suite compares as package output
*
* XI1 stratetab rateratio: IRR and its log-normal limits, from strate output
*     files, against Stata's poisson (saturated two-group model, exposure
*     offset, irr), at 95% and 90%
* XI2 survtab rmst(): RMST, its standard error and limits per group against
*     R survRM2::rmst2
* XI3 survtab difference: S1(t) - S2(t) and its limits against R
*     survival::survfit (Greenwood standard errors, summed in quadrature)
*
* Needs Rscript with the survival and survRM2 packages. Run from tabtools/qa.

clear all
version 17.0
set more off
set varabbrev off
set linesize 255

capture log close _xint
log using "crossval_tabtools_intervals.log", replace text name(_xint)

local test_count = 0
local pass_count = 0
local failed ""

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

tempfile scratch
local wd "`scratch'_d"
capture mkdir "`wd'"

capture program drop _xint_result
program define _xint_result, rclass
    args rc label
    if `rc' == 0 display as result "  PASS: `label'"
    else display as error "  FAIL: `label' (rc=`rc')"
    return scalar pass = (`rc' == 0)
end

* reference versions, for the receipt
local rver "`wd'/rver.txt"
shell Rscript -e "cat(paste0('R ', getRversion(), '; survival ', packageVersion('survival'), '; survRM2 ', packageVersion('survRM2')), file='`rver'')"
capture confirm file "`rver'"
if _rc {
    display as error "Rscript with survival and survRM2 is required"
    exit 601
}
file open _xv using "`rver'", read text
file read _xv rline
file close _xv
display as text "REFERENCE: `rline'; Stata `c(stata_version)' poisson"

* _xint_cohort: a two-cohort stset dataset with a three-level stratum
capture program drop _xint_cohort
program define _xint_cohort
    version 17.0
    clear
    set seed 61012
    quietly set obs 3000
    gen long id = _n
    gen byte cohort = 1 + (_n > 1500)
    gen byte stratum = 1 + mod(_n, 3)
    label define _xint_s 1 "Low" 2 "Middle" 3 "High", replace
    label values stratum _xint_s
    gen double t = -ln(runiform()) / (0.08 * cond(cohort == 2, 1.4, 1) * (0.7 + 0.3 * stratum))
    gen double c = 12 * runiform()
    gen byte d = t <= c
    quietly replace t = min(t, c)
    quietly stset t, failure(d) id(id)
end

**# XI1: stratetab rateratio against poisson, irr
local ++test_count
capture noisily {
    _xint_cohort
    foreach lv in 95 90 {
        * strate files carry their own level; make one pair per level
        forvalues k = 1/2 {
            preserve
            quietly keep if cohort == `k'
            quietly strate stratum, output("`wd'/coh`k'_`lv'", replace) level(`lv')
            restore
        }
        quietly stratetab, using("`wd'/coh1_`lv'" "`wd'/coh2_`lv'") outcomes(1) rateratio ///
            ratiodigits(8) level(`lv') frame(xi_s, replace)
        matrix xi_R = r(ratios)
        assert rowsof(xi_R) == 3
        forvalues s = 1/3 {
            * converged far past the default so the reference itself is exact to
            * well below the printed digit
            quietly poisson _d i.cohort if stratum == `s', exposure(_t) irr level(`lv') nrtolerance(1e-13) tolerance(1e-12)
            local b = exp(_b[2.cohort])
            local z = invnormal(1 - (1 - `lv' / 100) / 2)
            local lo = exp(_b[2.cohort] - `z' * _se[2.cohort])
            local hi = exp(_b[2.cohort] + `z' * _se[2.cohort])
            assert !missing(xi_R[`s', 1], `b', `lo', `hi')
            assert reldif(xi_R[`s', 1], `b') < 1e-8
            local lab : label _xint_s `s'
            frame xi_s {
                quietly count if strtrim(c1) == "`lab'" & ustrregexm(c5, "^[0-9.]+ \(")
                assert r(N) == 1
                quietly levelsof c5 if strtrim(c1) == "`lab'" & ustrregexm(c5, "^[0-9.]+ \("), local(cell) clean
            }
            assert ustrregexm(`"`cell'"', "^([0-9.]+) \(([0-9.]+), ([0-9.]+)\)$")
            local glo = real(ustrregexs(2))
            local ghi = real(ustrregexs(3))
            display as text "  XI1 `lv'% `lab': stratetab (" %10.8f `glo' ", " %10.8f `ghi' ") poisson (" %10.8f `lo' ", " %10.8f `hi' ")"
            * printed at 8 decimals: half a unit of the last digit, plus 2e-9
            * for the reference's own ML convergence error (a true value next
            * to a rounding boundary can print either side of it)
            assert abs(`glo' - `lo') <= 7e-9 & abs(`ghi' - `hi') <= 7e-9
        }
    }
}
_xint_result `=_rc' "XI1 stratetab IRR and limits equal poisson, irr (95% and 90%)"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' XI1"

**# XI2 / XI3: survtab RMST and survival difference against R
local ++test_count
capture noisily {
    sysuse cancer, clear
    quietly keep if inlist(drug, 1, 2)
    quietly stset studytime, failure(died)
    local tau 20
    local tt 10
    local csv "`wd'/surv.csv"
    local rout "`wd'/surv_r.csv"
    local rs "`wd'/surv.R"
    capture erase "`rout'"
    quietly export delimited studytime died drug using "`csv'", nolabel replace
    file open _rf using "`rs'", write replace text
    file write _rf `"suppressMessages({library(survival); library(survRM2)})"' _n
    file write _rf `"d <- read.csv("`csv'")"' _n
    file write _rf `"r <- rmst2(d\$studytime, d\$died, as.integer(d\$drug == 2), tau = `tau')"' _n
    file write _rf `"g1 <- r\$RMST.arm0\$result[1, ]; g2 <- r\$RMST.arm1\$result[1, ]"' _n
    file write _rf `"s <- summary(survfit(Surv(studytime, died) ~ drug, data = d), times = `tt')"' _n
    file write _rf `"out <- data.frame(rmst1 = g1[1], se1 = g1[2], lb1 = g1[3], ub1 = g1[4], rmst2 = g2[1], se2 = g2[2], lb2 = g2[3], ub2 = g2[4], s1 = s\$surv[1], e1 = s\$std.err[1], s2 = s\$surv[2], e2 = s\$std.err[2])"' _n
    file write _rf `"write.csv(out, "`rout'", row.names = FALSE)"' _n
    file close _rf
    shell Rscript "`rs'"
    confirm file "`rout'"
    quietly survtab, times(`tt') by(drug) rmst(`tau') difference digits(6) frame(xi_v, replace)
    forvalues g = 1/2 {
        local rm`g' = r(rmst_`g')
        local rs`g' = r(rmst_se_`g')
        local rl`g' = r(rmst_lb_`g')
        local ru`g' = r(rmst_ub_`g')
    }
    frame xi_v {
        local dc ""
        foreach v of varlist c* {
            if strpos(`v'[2], "Difference") == 1 local dc `v'
        }
        assert "`dc'" != ""
        * the survival-difference row at t (the RMST row has a difference too)
        quietly levelsof `dc' if strtrim(c1) == "`tt' years" & ustrregexm(`dc', "^-?[0-9.]+ \("), local(cell) clean
    }
    assert ustrregexm(`"`cell'"', "^(-?[0-9.]+) \((-?[0-9.]+), (-?[0-9.]+)\)$")
    local gd = real(ustrregexs(1))
    local gl = real(ustrregexs(2))
    local gu = real(ustrregexs(3))
    preserve
    import delimited using "`rout'", clear varnames(1) asdouble
    forvalues g = 1/2 {
        display as text "  XI2 drug group `g': survtab RMST " %10.6f `rm`g'' " SE " %9.6f `rs`g'' "; survRM2 " %10.6f rmst`g'[1] " SE " %9.6f se`g'[1]
        assert !missing(`rm`g'', rmst`g'[1]) & reldif(`rm`g'', rmst`g'[1]) < 1e-8
        assert !missing(`rs`g'', se`g'[1]) & reldif(`rs`g'', se`g'[1]) < 1e-8
        assert !missing(`rl`g'', lb`g'[1]) & reldif(`rl`g'', lb`g'[1]) < 1e-8
        assert !missing(`ru`g'', ub`g'[1]) & reldif(`ru`g'', ub`g'[1]) < 1e-8
    }
    local z = invnormal(0.975)
    local d = 100 * (s1[1] - s2[1])
    local hw = 100 * `z' * sqrt(e1[1]^2 + e2[1]^2)
    display as text "  XI3 S1-S2 at `tt': survtab " %10.6f `gd' " (" %10.6f `gl' ", " %10.6f `gu' "); survival " %10.6f `d' " (" %10.6f `d' - `hw' ", " %10.6f `d' + `hw' ")"
    * printed at 6 decimals (percent): half a unit of the last digit
    assert abs(`gd' - `d') <= 5.1e-7
    assert abs(`gl' - (`d' - `hw')) <= 5.1e-7
    assert abs(`gu' - (`d' + `hw')) <= 5.1e-7
    restore
}
_xint_result `=_rc' "XI2/XI3 survtab RMST (survRM2) and survival difference (survival) agree"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' XI2/XI3"

**# Summary
capture shell rm -rf "`wd'"
capture frame drop xi_s
capture frame drop xi_v
capture matrix drop xi_R
local fail_count = `test_count' - `pass_count'
if `fail_count' display as error "failed:`failed'"
display as text "RESULT: crossval_tabtools_intervals tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _xint
if `fail_count' > 0 exit 1
exit 0
