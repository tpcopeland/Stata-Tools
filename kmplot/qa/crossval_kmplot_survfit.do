* crossval_kmplot_survfit.do
* External cross-validation of kmplot against R survival::survfit
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-12
*
* Seed: 20261012.  Two scenarios x 40 replicates x 2 groups:
*   cont  continuous event times, 40% delayed entry, administrative censoring
*   ties  the same draws rounded up to multiples of 0.5 (tied event times)
* Each group is compared at landmarks 1-4 (inside follow-up by design) for
* the KM estimate, the log-log 95% bounds, and the number at risk with
* delayed entry; medians are compared in both scenarios, with R's
* plateau-midpoint convention mapped to Stata's plateau-start convention.
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
tempfile sim rin rout
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

shell Rscript "`qa_dir'/crossval_kmplot_survfit.R" "`rin'.csv" "`rout'.csv" "`times'" > "`rout'.txt" 2>&1
capture confirm file "`rout'.csv"
if _rc {
    type "`rout'.txt"
    display as error "Rscript did not produce reference output; install R and the survival package"
    exit 601
}
type "`rout'.txt"
import delimited using "`rout'.csv", clear case(preserve) stringcols(1) asdouble
tempfile ref
save "`ref'"

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
        tempname L R
        matrix `L' = r(landmarks)
        matrix `R' = r(risktable)
        forvalues g = 1/2 {
            local med_`g' = .
            capture local med_`g' = r(median_`g')
        }
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
capture erase "`c(tmpdir)'/kmcv_risk.dta"
display as text "exact S = 0.5 plateaus mapped: `n_plateau'"
assert `n_plateau' > 0
display as result "RESULT: crossval_kmplot_survfit tests=`test_count' pass=`pass_count' fail=0 skip=0"
