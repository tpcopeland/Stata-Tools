*! qba_confound Version 1.0.0  2026/03/13
*! Unmeasured confounding bias analysis
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass

/*
Corrects an observed measure of association (OR, RR) for a single
binary unmeasured confounder using the Schneeweiss (2006) or
Greenland (1996) approach. Optionally computes E-values.

Simple mode: fixed confounding parameters.
Probabilistic mode (reps()): Monte Carlo draws from distributions.

References:
  Lash TL, Fox MP, Fink AK. Applying Quantitative Bias Analysis to
    Epidemiologic Data. 2nd ed. Springer; 2021. Chapter 8.
  Schneeweiss S. Sensitivity analysis and external adjustment for
    unmeasured confounders. Pharmacoepidemiol Drug Saf. 2006;15:291-303.
  VanderWeele TJ, Ding P. Sensitivity Analysis in Observational
    Research: Introducing the E-Value. Ann Intern Med. 2017;167:268-274.
*/

capture program drop qba_confound
program define qba_confound, rclass
    version 16.0
    set varabbrev off
    set more off

    * Load distribution helper
    capture program list _qba_draw_one
    if _rc {
        capture findfile _qba_distributions.ado
        if _rc == 0 {
            run "`r(fn)'"
        }
        else {
            display as error "_qba_distributions.ado not found; reinstall qba"
            exit 111
        }
    }

    syntax , [ESTimate(real -999) ///
        MEAsure(string) ///
        P1(real -1) P0(real -1) ///
        RRcd(real -1) RRud(real -1) ///
        Reps(integer 0) ///
        dist_p1(string) dist_p0(string) dist_rr(string) ///
        Seed(integer -1) Level(cilevel) ///
        EVAlue CI_bound(real -999) ///
        from_model ///
        SAving(string)]

    * Get estimate from model or option
    if "`from_model'" != "" {
        if `estimate' != -999 {
            display as error "cannot specify both estimate() and from_model"
            exit 198
        }
        * Check for estimation results
        capture confirm matrix e(b)
        if _rc {
            display as error "no estimation results found; run a model first"
            exit 301
        }
        * Get treatment variable (first non-constant coefficient)
        local names : colnames e(b)
        local treat_var ""
        foreach v of local names {
            if "`v'" != "_cons" {
                local treat_var "`v'"
                continue, break
            }
        }
        if "`treat_var'" == "" {
            display as error "no treatment variable found in estimation results"
            exit 198
        }
        local b_treat = _b[`treat_var']
        local se_treat = _se[`treat_var']
        * Exponentiate only for log-scale models (logistic, Cox, Poisson)
        local ecmd "`e(cmd)'"
        if inlist("`ecmd'", "logistic", "logit", "stcox", "poisson", "nbreg", "cloglog") {
            local estimate = exp(`b_treat')
            local est_lo = exp(`b_treat' - invnormal((100+`level')/200) * `se_treat')
            local est_hi = exp(`b_treat' + invnormal((100+`level')/200) * `se_treat')
        }
        else {
            * Linear model: use coefficient directly
            local estimate = `b_treat'
            local est_lo = `b_treat' - invnormal((100+`level')/200) * `se_treat'
            local est_hi = `b_treat' + invnormal((100+`level')/200) * `se_treat'
        }
        local from_model_flag = 1
    }
    else {
        if `estimate' == -999 {
            display as error "must specify estimate() or from_model"
            exit 198
        }
        if `estimate' <= 0 {
            display as error "estimate() must be > 0"
            exit 198
        }
        local from_model_flag = 0
    }

    * Defaults
    if "`measure'" == "" local measure "RR"
    local measure = strupper("`measure'")
    if !inlist("`measure'", "OR", "RR") {
        display as error "measure() must be OR or RR"
        exit 198
    }

    * Need confounding parameters for correction (not for E-value only)
    local do_correction = 0
    if `p1' != -1 & `p0' != -1 & (`rrcd' != -1 | `rrud' != -1) {
        local do_correction = 1
    }
    if `do_correction' == 0 & "`evalue'" == "" {
        display as error "specify confounding parameters (p1, p0, rrcd/rrud) or evalue"
        exit 198
    }

    * Validate confounding parameters
    if `do_correction' {
        if `p1' < 0 | `p1' > 1 {
            display as error "p1() must be in [0, 1]"
            exit 198
        }
        if `p0' < 0 | `p0' > 1 {
            display as error "p0() must be in [0, 1]"
            exit 198
        }
        if `rrcd' != -1 & `rrcd' <= 0 {
            display as error "rrcd() must be > 0"
            exit 198
        }
        if `rrud' != -1 & `rrud' <= 0 {
            display as error "rrud() must be > 0"
            exit 198
        }
        * Use rrcd if both specified, prefer rrud if given
        if `rrud' != -1 {
            local use_rrud = 1
            local rr_val = `rrud'
        }
        else {
            local use_rrud = 0
            local rr_val = `rrcd'
        }
    }

    if `seed' != -1 {
        set seed `seed'
    }

    * =====================================================================
    * E-VALUE
    * =====================================================================
    if "`evalue'" != "" {
        * Use OR as approximate RR (conservative, VanderWeele 2017)
        local rr_for_eval = `estimate'

        * E-value for point estimate
        if `rr_for_eval' >= 1 {
            local eval_point = `rr_for_eval' + sqrt(`rr_for_eval' * (`rr_for_eval' - 1))
        }
        else {
            local rr_inv = 1 / `rr_for_eval'
            local eval_point = `rr_inv' + sqrt(`rr_inv' * (`rr_inv' - 1))
        }

        * E-value for CI bound
        local eval_ci = .
        if `ci_bound' != -999 {
            if `ci_bound' <= 0 {
                display as error "ci_bound() must be > 0"
                exit 198
            }
            if (`estimate' >= 1 & `ci_bound' <= 1) | (`estimate' < 1 & `ci_bound' >= 1) {
                * CI crosses null
                local eval_ci = 1
            }
            else {
                local rr_ci = `ci_bound'
                if `rr_ci' < 1 {
                    local rr_ci = 1 / `rr_ci'
                }
                local eval_ci = `rr_ci' + sqrt(`rr_ci' * (`rr_ci' - 1))
            }
        }
        else if `from_model_flag' {
            * Use CI from model
            if `estimate' >= 1 {
                local ci_use = `est_lo'
            }
            else {
                local ci_use = `est_hi'
            }
            if (`estimate' >= 1 & `ci_use' <= 1) | (`estimate' < 1 & `ci_use' >= 1) {
                local eval_ci = 1
            }
            else {
                local rr_ci = `ci_use'
                if `rr_ci' < 1 {
                    local rr_ci = 1 / `rr_ci'
                }
                local eval_ci = `rr_ci' + sqrt(`rr_ci' * (`rr_ci' - 1))
            }
        }
    }

    * =====================================================================
    * SIMPLE BIAS ANALYSIS
    * =====================================================================
    if `reps' == 0 {
        if `do_correction' {
            if `use_rrud' {
                * Greenland/Schneeweiss: BF = (p1*RRud + (1-p1)) / (p0*RRud + (1-p0))
                local bf = (`p1' * `rr_val' + (1 - `p1')) / (`p0' * `rr_val' + (1 - `p0'))
            }
            else {
                * Schneeweiss: BF = (p1*(RRcd-1) + 1) / (p0*(RRcd-1) + 1)
                local bf = (`p1' * (`rr_val' - 1) + 1) / (`p0' * (`rr_val' - 1) + 1)
            }
            local corrected = `estimate' / `bf'
        }

        * Display
        display as text ""
        display as text "{bf:Quantitative Bias Analysis: Unmeasured Confounding}"
        display as text "{hline 60}"
        display as text ""
        display as text "  Observed `measure': " as result %9.4f `estimate'

        if `from_model_flag' {
            display as text "  `level'% CI:     " as result %9.4f `est_lo' ///
                as text " - " as result %9.4f `est_hi'
            display as text "  (from last estimation command)"
        }
        display as text ""

        if `do_correction' {
            display as text "{bf:Confounding parameters}"
            display as text "  P(U=1 | E=1): " as result %6.4f `p1'
            display as text "  P(U=1 | E=0): " as result %6.4f `p0'
            if `use_rrud' {
                display as text "  RR(U->D):     " as result %6.4f `rrud'
            }
            else {
                display as text "  RR(C->D):     " as result %6.4f `rrcd'
            }
            display as text ""
            display as text "{bf:Results}"
            display as text "  Bias factor:     " as result %9.4f `bf'
            display as text "  Corrected `measure':  " as result %9.4f `corrected'
            local ratio = `corrected' / `estimate'
            display as text "  Ratio (corrected/observed): " as result %6.4f `ratio'
        }

        if "`evalue'" != "" {
            display as text ""
            display as text "{bf:E-value (VanderWeele & Ding 2017)}"
            display as text "  E-value (point):  " as result %9.4f `eval_point'
            if `eval_ci' < . {
                display as text "  E-value (CI):     " as result %9.4f `eval_ci'
            }
            display as text ""
            if `eval_point' < 2 {
                display as text "  A relatively weak confounder could explain the effect."
            }
            else if `eval_point' < 3 {
                display as text "  A moderately strong confounder would be needed."
            }
            else {
                display as text "  A strong confounder would be needed."
            }
        }
        display as text "{hline 60}"

        * Store results
        return scalar observed = `estimate'
        return local measure "`measure'"
        return local method "simple"
        if `do_correction' {
            return scalar corrected = `corrected'
            return scalar bias_factor = `bf'
            return scalar p1 = `p1'
            return scalar p0 = `p0'
            if `use_rrud' {
                return scalar rrud = `rrud'
            }
            else {
                return scalar rrcd = `rrcd'
            }
            return scalar ratio = `ratio'
        }
        if "`evalue'" != "" {
            return scalar evalue = `eval_point'
            if `eval_ci' < . {
                return scalar evalue_ci = `eval_ci'
            }
        }
        if `from_model_flag' {
            return scalar ci_lower = `est_lo'
            return scalar ci_upper = `est_hi'
        }
    }

    * =====================================================================
    * PROBABILISTIC BIAS ANALYSIS
    * =====================================================================
    else {
        if !`do_correction' {
            display as error "confounding parameters required for probabilistic analysis"
            exit 198
        }
        if `reps' < 100 {
            display as error "reps() should be at least 100 for stable results"
            exit 198
        }

        if "`dist_p1'" == "" local dist_p1 "constant `p1'"
        if "`dist_p0'" == "" local dist_p0 "constant `p0'"
        if "`dist_rr'" == "" local dist_rr "constant `rr_val'"

        preserve
        quietly {
            clear
            set obs `reps'

            _qba_draw_one, dist("`dist_p1'") gen(_p1) n(`reps')
            _qba_draw_one, dist("`dist_p0'") gen(_p0) n(`reps')
            _qba_draw_one, dist("`dist_rr'") gen(_rr) n(`reps')

            if `use_rrud' {
                gen double _bf = (_p1 * _rr + (1 - _p1)) / (_p0 * _rr + (1 - _p0))
            }
            else {
                gen double _bf = (_p1 * (_rr - 1) + 1) / (_p0 * (_rr - 1) + 1)
            }

            gen double _result = `estimate' / _bf
            replace _result = . if _result <= 0 | _result >= .

            count if _result < .
            local n_valid = r(N)

            if `n_valid' == 0 {
                display as error "all replicates produced invalid results"
                exit 198
            }

            summarize _result, detail
            local mc_mean = r(mean)
            local mc_median = r(p50)
            local mc_sd = r(sd)

            local alpha = (100 - `level') / 2
            _pctile _result, percentiles(`alpha' `=100-`alpha'')
            local mc_lo = r(r1)
            local mc_hi = r(r2)

            if `"`saving'"' != "" {
                keep _p1 _p0 _rr _bf _result
                rename _result corrected_`=strlower("`measure'")'
                rename _bf bias_factor
                rename _p1 p1
                rename _p0 p0
                rename _rr rr_confounder
                save `saving'
            }
        }
        restore

        * Display
        display as text ""
        display as text "{bf:Probabilistic Bias Analysis: Unmeasured Confounding}"
        display as text "{hline 60}"
        display as text ""
        display as text "Replications: " as result %8.0fc `reps' ///
            as text "  (valid: " as result %8.0fc `n_valid' as text ")"
        display as text ""
        display as text "  Observed `measure':  " as result %9.4f `estimate'
        display as text ""
        display as text "{bf:Corrected `measure' (Monte Carlo)}"
        display as text "  Median:   " as result %9.4f `mc_median'
        display as text "  Mean:     " as result %9.4f `mc_mean'
        display as text "  SD:       " as result %9.4f `mc_sd'
        display as text "  `level'% CI:  " as result %9.4f `mc_lo' ///
            as text " - " as result %9.4f `mc_hi'

        if "`evalue'" != "" {
            display as text ""
            display as text "{bf:E-value (VanderWeele & Ding 2017)}"
            display as text "  E-value (point):  " as result %9.4f `eval_point'
            if `eval_ci' < . {
                display as text "  E-value (CI):     " as result %9.4f `eval_ci'
            }
        }
        display as text "{hline 60}"

        * Store results
        return scalar observed = `estimate'
        return scalar corrected = `mc_median'
        return scalar mean = `mc_mean'
        return scalar sd = `mc_sd'
        return scalar ci_lower = `mc_lo'
        return scalar ci_upper = `mc_hi'
        return scalar reps = `reps'
        return scalar n_valid = `n_valid'
        return local measure "`measure'"
        return local method "probabilistic"
        if "`evalue'" != "" {
            return scalar evalue = `eval_point'
            if `eval_ci' < . {
                return scalar evalue_ci = `eval_ci'
            }
        }
    }
end
