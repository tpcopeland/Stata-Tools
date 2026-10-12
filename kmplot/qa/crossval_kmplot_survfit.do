* crossval_kmplot_survfit.do
* External cross-validation of kmplot against R survival::survfit
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-12
*
* Seed: 20261012.  Two scenarios x 40 replicates x 2 groups:
*   cont  continuous event times, 40% delayed entry, administrative censoring
*   ties  the same draws rounded up to multiples of 0.5 (tied event times)
* Each group is compared at landmarks 1-4 (inside follow-up by design) for
* the KM estimate, the 95% bounds under every citransform() (loglog, log,
* plain; R's conf.type log-log, log, plain), and the number at risk with
* delayed entry; medians are compared in both scenarios, with R's
* plateau-midpoint convention mapped to Stata's plateau-start convention.
* The log-rank p-value (pvalue) is compared with R survdiff(rho = 0) on the
* same draws with entry times ignored (survdiff refuses delayed entry), so
* it is checked on right-censored data with and without tied times.
* Requires Rscript on the PATH with the survival package
* (install.packages("survival")).

clear all
version 16.0
set varabbrev off
local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

local times "1 2 3 4"
local nrep 40
tempfile sim rin rout rlr
set seed 20261012
clear
set obs `=`nrep' * 60'
gen int rep = ceil(_n / 60)
gen byte grp = mod(_n, 2) + 1
gen double t0 = cond(runiform() < .4, runiform() * .5, 0)
gen double tev = t0 + rexponential(1 / cond(grp == 1, .15, .25))
gen double tcen = t0 + 1 + runiform() * 12
gen double t = min(tev, tcen, 5)
gen byte d = (tev <= min(tcen, 5))
* Every group reaches the last landmark, so no comparison is out of support.
bysort rep grp (t): assert t[_N] > 4
gen str4 scenario = "cont"
expand 2, generate(dup)
replace scenario = "ties" if dup
replace t = ceil(t * 2) / 2 if dup
replace t0 = floor(t0 * 2) / 2 if dup
assert t > t0
drop dup tev tcen
order scenario rep grp t0 t d
save "`sim'"
export delimited scenario rep grp t0 t d using "`rin'.csv", replace

shell Rscript "`qa_dir'/crossval_kmplot_survfit.R" "`rin'.csv" "`rout'.csv" "`times'" "`rlr'.csv" > "`rout'.txt" 2>&1
capture confirm file "`rout'.csv"
if _rc == 0 capture confirm file "`rlr'.csv"
if _rc {
    type "`rout'.txt"
    display as error "Rscript did not produce reference output; install R and the survival package"
    exit 601
}
type "`rout'.txt"
import delimited using "`rout'.csv", clear case(preserve) stringcols(1) asdouble
tempfile ref lrref
save "`ref'"
import delimited using "`rlr'.csv", clear case(preserve) stringcols(1) asdouble
save "`lrref'"

local test_count = 0
local pass_count = 0
local n_plateau = 0
foreach sc in cont ties {
    forvalues r = 1/`nrep' {
        use "`sim'", clear
        quietly keep if scenario == "`sc'" & rep == `r'
        quietly stset t, failure(d) enter(time t0)
        kmplot, by(grp) ci landmark(`times') median ///
            risksaving("`c(tmpdir)'/kmcv_risk.dta", replace) timepoints(`times') ///
            name(kmcv, replace)
        tempname L R Llog Lpl
        matrix `L' = r(landmarks)
        matrix `R' = r(risktable)
        forvalues g = 1/2 {
            local med_`g' = .
            capture local med_`g' = r(median_`g')
        }
        quietly kmplot, by(grp) ci citransform(log) landmark(`times') ///
            nodraw name(kmcv, replace)
        matrix `Llog' = r(landmarks)
        quietly kmplot, by(grp) ci citransform(plain) landmark(`times') ///
            nodraw name(kmcv, replace)
        matrix `Lpl' = r(landmarks)
        use "`ref'", clear
        quietly keep if scenario == "`sc'" & rep == `r'
        sort grp time
        assert _N == 8
        forvalues i = 1/8 {
            * Rows are ordered group then time in all three sources.
            assert grp[`i'] == `L'[`i', 1] & time[`i'] == `L'[`i', 2]
            assert !missing(surv[`i'], lower[`i'], upper[`i'])
            assert !missing(`L'[`i', 3], `L'[`i', 4], `L'[`i', 5])
            assert abs(`L'[`i', 3] - surv[`i']) < 1e-10
            assert abs(`L'[`i', 4] - lower[`i']) < 1e-8
            assert abs(`L'[`i', 5] - upper[`i']) < 1e-8
            assert !missing(lower_log[`i'], upper_log[`i'], lower_plain[`i'], upper_plain[`i'])
            assert abs(`Llog'[`i', 4] - lower_log[`i']) < 1e-8
            assert abs(`Llog'[`i', 5] - upper_log[`i']) < 1e-8
            assert abs(`Lpl'[`i', 4] - lower_plain[`i']) < 1e-8
            assert abs(`Lpl'[`i', 5] - upper_plain[`i']) < 1e-8
            assert `R'[`i', 3] == n_risk[`i']
            local ++test_count
            local ++pass_count
        }
        forvalues g = 1/2 {
            quietly summarize r_median if grp == `g', meanonly
            local rmed = r(mean)
            quietly summarize plateau_start if grp == `g', meanonly
            local plat = r(mean)
            quietly summarize first_le_half if grp == `g', meanonly
            local first = r(mean)
            if missing(`plat') {
                * No exact 0.5 plateau: R's median is the first time S <= 0.5.
                assert (missing(`rmed') & missing(`med_`g'')) | ///
                    abs(`med_`g'' - `rmed') < 1e-10
            }
            else {
                * Exact plateau: R reports its midpoint, Stata its start.
                local ++n_plateau
                assert abs(`med_`g'' - `plat') < 1e-10
                assert `rmed' > `plat'
            }
            assert (missing(`first') & missing(`med_`g'')) | ///
                abs(`med_`g'' - `first') < 1e-10
            local ++test_count
            local ++pass_count
        }
    }
}
* Log-rank p-value against survdiff on right-censored data (entry ignored).
local n_lr = 0
foreach sc in cont ties {
    forvalues r = 1/`nrep' {
        use "`lrref'", clear
        quietly keep if scenario == "`sc'" & rep == `r'
        assert _N == 1
        local p_ref = p[1]
        local chi_ref = chisq[1]
        use "`sim'", clear
        quietly keep if scenario == "`sc'" & rep == `r'
        quietly stset t, failure(d)
        kmplot, by(grp) pvalue name(kmcv, replace)
        assert !missing(r(p), `p_ref')
        assert reldif(r(p), `p_ref') < 1e-8
        quietly sts test grp
        assert !missing(r(chi2), `chi_ref')
        assert reldif(r(chi2), `chi_ref') < 1e-8
        local ++n_lr
        local ++test_count
        local ++pass_count
    }
}
display as text "log-rank p-values matched to survdiff: `n_lr'"
assert `n_lr' == 2 * `nrep'
capture erase "`c(tmpdir)'/kmcv_risk.dta"
display as text "exact S = 0.5 plateaus mapped: `n_plateau'"
assert `n_plateau' > 0
display as result "RESULT: crossval_kmplot_survfit tests=`test_count' pass=`pass_count' fail=0 skip=0"
