# Pweight interpretation: censoring selection counterexample

Audit: 2026-09-08, finegray 1.3.1, Stata/MP 17. This is a method-boundary probe, not a validation claim or an additional automatic lane. The routine reference comparisons establish agreement with the frozen R weighted-score computation.

Wogu et al. (2021, §3 p.167) estimate the censoring survivor using the full cohort. This package estimates it without weights using the analysis sample. If every observed cause-1 case is selected and other subjects have selection probability α, the sampled censoring hazard has expected numerator proportional to α dN_C(t) and denominator α Y(t) + (1−α) Y_future-observed-case1(t). It generally differs from the cohort censoring hazard. Applying inverse-probability weights to the subsequent score cannot correct that nuisance estimate. This argument is an inference from the paper's design, independently reviewed during the audit.

Population interpretation therefore requires that sampling preserve the required censoring distribution and independent censoring, alongside correct sampling weights, positivity, and the model assumptions. General outcome-dependent case-cohort sampling is not covered. The package's fixed-weight sandwich also omits censoring-estimation uncertainty. See `help finegray_methods`, Design weights.

The following reproducible draw uses the published F1 generator (§5 pp.170–172), with a stronger selection/censoring configuration. The exact population CIF at t=.8 and Z=(1,0) is **.48380307**. The sampled fit returned **.46274470**, fixed-weight SE **.00564069**, n=140265; coefficients were .51497559 and .52644592 (truth .5 each). This finite-sample example illustrates the boundary; the risk-set argument explains why general consistency is not established. Earlier, milder recovery scenarios passed their tolerances, demonstrating why those checks cannot prove general validity.

For a comparison within the supported scope, replace `alpha` with `cond(z1 > 0, ahi, alo)` in the generator (using the local macros shown below), and use `ahi(.1) alo(.3)`. This selects only by baseline covariates; censoring remains common and independent. With the same seed and cohort, n=100084, CIF=.47892089 (SE=.00411147). This one draw is illustrative, not a coverage study.

Use an isolated package copy and its `qa/` working directory. No R fitting is involved. To reproduce the originally observed values, use Stata/MP 17 and the stated seed; other versions may use different random-number details.

```stata
clear all
set more off
set linesize 255
set varabbrev off
* Run from finegray/qa in an isolated source copy.
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
adopath ++ "`pkg_dir'"
set processors 1
capture program drop _vpw_gen
program define _vpw_gen
    version 16.0
    syntax , n(integer) p(real) b11(real) b12(real) b21(real) b22(real) ///
        cmax(real) ahi(real) alo(real)
    quietly {
        clear
        set obs `n'
        gen long id = _n
        gen double z1 = rnormal()
        gen double z2 = rnormal()
        gen double r1 = exp(`b11' * z1 + `b12' * z2)
        gen double u = runiform()
        gen double f1inf = 1 - (1 - `p')^r1
        gen byte cause1 = (u < f1inf)
        * invert F1 exactly on cause-1 rows
        gen double t1 = -ln(1 - (1 - (1 - u)^(1 / r1)) / `p') if cause1
        gen double t2 = -ln(runiform()) / exp(`b21' * z1 + `b22' * z2) if !cause1
        gen double tc = `cmax' * runiform()
        gen double tev = cond(cause1, t1, t2)
        gen double time = min(tev, tc)
        replace time = 1e-8 if time <= 0
        gen byte status = cond(tev <= tc, cond(cause1, 1, 2), 0)
        * the design: cases certain, non-cases Bernoulli with a Z1-dependent rate
        gen double alpha = cond(status == 1, 1, cond(z1 > 0, `ahi', `alo'))
        gen byte keep = (runiform() < alpha)
        gen double pw = 1 / alpha
        keep if keep
        stset time, failure(status) id(id)
    }
end


foreach cm in 1 {
    set seed 283345
    _vpw_gen, n(500000) p(.6) b11(.5) b12(.5) b21(-.5) b22(-.5) cmax(`cm') ahi(.02) alo(.06)
    finegray z1 z2 [pw=pw], compete(status) cause(1) nolog
    quietly finegray_cif, at(z1=1 z2=0) attime(.8) ci nograph
    matrix c = r(table)
    display "CIF|cmax=`cm'|true=" 1-(1-.6*(1-exp(-.8)))^exp(.5) "|est=" c[1,2] "|se=" c[1,3]
    display "PROBE|cmax=`cm'|n=" e(N) "|b1=" %12.8f _b[z1] "|se1=" %12.8f _se[z1] "|b2=" %12.8f _b[z2] "|se2=" %12.8f _se[z2]
}

```

Source: [Wogu et al., published full text](https://article.sciencepublishinggroup.com/pdf/ajam.20210905.12), DOI 10.11648/j.ajam.20210905.12, American Journal of Applied Mathematics 9(5):165–185.
