*! qba_confound Version 1.0.1  2026/06/19
*! Unmeasured confounding bias analysis
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
Corrects an observed measure of association (OR, RR) for a single
binary unmeasured confounder using the Schneeweiss (2006) or
Greenland (1996) approach. Optionally computes E-values.

For ratio measures (OR, RR): corrected = observed / bias_factor
For linear coefficients (from_model with linear models):
  corrected = observed - (p1 - p0) * confounder_effect

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
    local _saved_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    _qba_require_distributions

    syntax , [ESTimate(real -999) ///
	        MEAsure(string) ///
	        P1(real -1) P0(real -1) ///
	        RRcd(real -1) RRud(real -1) CONFeffect(real -999) ///
	        Reps(integer 0) ///
	        dist_p1(string) dist_p0(string) dist_rr(string) ///
	        dist_confeffect(string) ///
	        Seed(integer -1) Level(cilevel) ///
	        EVAlue CI_bound(real -999) ///
	        from_model COEF(string) ///
	        SAving(string asis)]

	    if `reps' < 0 {
	        display as error "reps() must be a nonnegative integer"
	        exit 198
	    }
	    if `ci_bound' != -999 & "`evalue'" == "" {
	        display as error "ci_bound() requires evalue"
	        exit 198
	    }
	    if `reps' == 0 {
	        if `"`saving'"' != "" {
	            display as error "saving() requires reps()"
	            exit 198
	        }
	        if `"`dist_p1'"' != "" | `"`dist_p0'"' != "" | ///
	            `"`dist_rr'"' != "" | `"`dist_confeffect'"' != "" {
	            display as error "dist_*() options require reps()"
	            exit 198
	        }
	        if `seed' != -1 {
	            display as error "seed() requires reps()"
	            exit 198
	        }
	    }

    local savefile ""
    local save_replace ""
    if `"`saving'"' != "" {
        _qba_parse_saving, saving(`saving')
        local savefile `"`r(filename)'"'
        local save_replace "`r(replace)'"
    }

    * Get estimate from model, active estimator contract, or option
    local is_linear = 0
    local contract_flag = 0
    local contract_source ""
    local contract_cmd ""
    local contract_outcome ""
    local contract_treatment ""
    local contract_estimand ""
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
        * Get treatment variable: eligible coefficients are the main-equation
        * terms only. Ancillary parameters (streg /ln_p, /lnsigma, /lngamma;
        * nbreg /lnalpha; melogit variance components; etc.) sit in a separate
        * equation (coleq "/") and must never be treated as the treatment.
        local names : colnames e(b)
        local eqs   : coleq e(b)
        local main_eq : word 1 of `eqs'
        local ncols  : word count `names'
        local n_coefs = 0
        local first_coef ""
        local eligible_names ""
        forvalues i = 1/`ncols' {
            local v  : word `i' of `names'
            local eq : word `i' of `eqs'
            local _is_omitted = (strpos("`v'", "b.") > 0 | strpos("`v'", "o.") > 0)
            if "`v'" != "_cons" & !`_is_omitted' & "`eq'" == "`main_eq'" {
                local ++n_coefs
                if "`first_coef'" == "" local first_coef "`v'"
                local eligible_names "`eligible_names' `v'"
            }
        }
        if `n_coefs' == 0 {
            display as error "no treatment variable found in estimation results"
            exit 198
        }
        if "`coef'" != "" {
            * coef() must name an eligible main-equation coefficient
            local found = 0
            foreach v of local eligible_names {
                if "`v'" == "`coef'" {
                    local found = 1
                    continue, break
                }
            }
            if !`found' {
                * Distinguish "not in the model" from "ineligible column"
                * (constant, base, omitted, or ancillary parameter)
                local in_model = 0
                foreach v of local names {
                    if "`v'" == "`coef'" local in_model = 1
                }
                if `in_model' {
                    display as error ///
                        "coef(`coef') is a constant, base, omitted, or ancillary coefficient"
                }
                else {
                    display as error "coef(`coef') not found in estimation results"
                }
                exit 198
            }
            local treat_var "`coef'"
        }
        else if `n_coefs' == 1 {
            local treat_var "`first_coef'"
        }
        else {
            display as error "multiple coefficients found; specify coef(coefname)"
            display as error "available: `eligible_names'"
            exit 198
        }
        local b_treat = _b[`treat_var']
        local se_treat = _se[`treat_var']
        * Exponentiate only for log-scale models (logistic, Cox, Poisson, etc.)
        * For the st-family, e(cmd) holds the distribution ("cox", "weibull",
        * "lnormal", ...) while e(cmd2) holds the st-command ("stcox"/"streg"/
        * "stcrreg"); key survival detection off e(cmd2).
        local ecmd "`e(cmd)'"
        local ecmd2 "`e(cmd2)'"
        local st_cmd ""
        if inlist("`ecmd2'", "stcox", "streg", "stcrreg") local st_cmd "`ecmd2'"
        if "`ecmd'" == "cloglog" {
            if "`measure'" == "" {
                display as error "cloglog from_model requires explicit measure(RR)"
                exit 198
            }
            if strupper("`measure'") != "RR" {
                display as error "cloglog from_model supports measure(RR) only"
                exit 198
            }
        }
        * streg accelerated-failure-time distributions (lognormal, loglogistic,
        * gamma) report a time ratio, not a hazard ratio (e(frm2)=="time"). The
        * confounding bias factor corrects a risk/rate/hazard ratio; a time ratio
        * is a different scale and cannot be corrected here.
        if "`st_cmd'" == "streg" & "`e(frm2)'" == "time" {
            display as error ///
                "streg accelerated-failure-time models report a time ratio, not a hazard ratio"
            display as error ///
                "qba_confound corrects ratio measures (OR/RR/HR); refit with a proportional-hazards distribution (e.g. dist(weibull), dist(exponential))"
            exit 198
        }
        local is_logscale = 0
        if inlist("`ecmd'", "logistic", "logit", "stcox", "poisson", "nbreg", "cloglog") {
            local is_logscale = 1
        }
        if inlist("`ecmd'", "clogit", "xtlogit", "xtpoisson", "xtnbreg", "melogit", "mepoisson") {
            local is_logscale = 1
        }
        if inlist("`ecmd'", "streg", "stcrreg") {
            local is_logscale = 1
        }
        * st-family via e(cmd2): stcox/stcrreg are always hazard-scale, and any
        * streg reaching here is a proportional-hazards parameterization.
        if inlist("`st_cmd'", "stcox", "streg", "stcrreg") {
            local is_logscale = 1
        }
        if "`ecmd'" == "glm" {
            local elink = strlower("`e(link)'")
            if inlist("`elink'", "log", "logit", "glim_l02", "glim_l03") {
                local is_logscale = 1
            }
        }
        if `is_logscale' {
            local estimate = exp(`b_treat')
            local est_lo = exp(`b_treat' - invnormal((100+`level')/200) * `se_treat')
            local est_hi = exp(`b_treat' + invnormal((100+`level')/200) * `se_treat')
        }
        else {
            * Linear model: use coefficient directly
            local estimate = `b_treat'
            local est_lo = `b_treat' - invnormal((100+`level')/200) * `se_treat'
            local est_hi = `b_treat' + invnormal((100+`level')/200) * `se_treat'
            local is_linear = 1
            * Estimators without a recognized log/linear scale (probit, ologit,
            * ...) fall through to the additive-coefficient path. Flag it so the
            * user can confirm the coefficient really is an additive contrast.
            if !inlist("`ecmd'", "regress", "areg", "cnsreg", "") {
                display as text ///
                    "note: `ecmd' coefficient is corrected on the linear (additive) scale"
            }
        }
        local from_model_flag = 1

        * Auto-detect measure from e(cmd) if not specified
        if "`measure'" == "" {
            if inlist("`ecmd'", "logistic", "logit", "clogit", "xtlogit", "melogit") {
                local measure "OR"
            }
            else if inlist("`ecmd'", "poisson", "stcox", "streg", "stcrreg") {
                local measure "RR"
            }
            else if inlist("`ecmd'", "nbreg", "xtpoisson", "xtnbreg", "mepoisson") {
                local measure "RR"
            }
            else if "`ecmd'" == "glm" {
                local elink2 = strlower("`e(link)'")
                if inlist("`elink2'", "logit", "glim_l02") local measure "OR"
                else if inlist("`elink2'", "log", "glim_l03") local measure "RR"
            }
            * st-family point measure is a hazard ratio, carried as RR
            if "`measure'" == "" & inlist("`st_cmd'", "stcox", "streg", "stcrreg") {
                local measure "RR"
            }
        }
    }
    else {
        if `estimate' == -999 {
            _qba_detect_contract
            if r(has_contract) {
                local estimate = r(estimate)
                local est_lo = r(ci_lo)
                local est_hi = r(ci_hi)
                local se_treat = r(se)
                local contract_flag = 1
                local contract_source "`r(source)'"
                local contract_cmd "`r(cmd)'"
                local contract_outcome "`r(outcome)'"
                local contract_treatment "`r(treatment)'"
                local contract_estimand "`r(estimand)'"
                local contract_measure "`r(measure)'"
                local ecmd "`contract_cmd'"
                local from_model_flag = 0
                if "`contract_measure'" == "OR" | "`contract_measure'" == "RR" {
                    if "`measure'" == "" local measure "`contract_measure'"
                }
                else {
                    local is_linear = 1
                }
            }
            else {
                display as error "must specify estimate() or from_model"
                exit 198
            }
        }
        else {
	            if missing(`estimate') | `estimate' <= 0 {
	                display as error "estimate() must be > 0"
	                exit 198
	            }
            local from_model_flag = 0
        }
    }

    * Reject coef() without from_model
    if "`coef'" != "" & "`from_model'" == "" {
        display as error "coef() requires from_model"
        exit 198
    }

    * Defaults
    if "`measure'" == "" local measure "RR"
    local measure = strupper("`measure'")
    if !inlist("`measure'", "OR", "RR") {
        display as error "measure() must be OR or RR"
        exit 198
    }
    if `is_linear' local measure "coefficient"
    if !`is_linear' & (missing(`estimate') | `estimate' <= 0) {
        display as error "ratio-measure estimates must be > 0"
        exit 198
    }
    local has_est_ci = 0
    if `from_model_flag' {
        local has_est_ci = 1
    }
    else if `contract_flag' {
        if `est_lo' < . & `est_hi' < . local has_est_ci = 1
    }

	    * Need confounding parameters for correction (not for E-value only)
	    local do_correction = 0
	    if `is_linear' {
	        if `rrcd' != -1 | `rrud' != -1 | `"`dist_rr'"' != "" {
	            display as error "linear from_model corrections require confeffect(), not rrcd()/rrud()"
	            exit 198
	        }
	        if `confeffect' != -999 | `"`dist_confeffect'"' != "" | ///
	            `p1' != -1 | `p0' != -1 {
	            if `p1' == -1 | `p0' == -1 | `confeffect' == -999 {
	                display as error "linear confounding requires p1(), p0(), and confeffect()"
	                exit 198
	            }
	            local do_correction = 1
	        }
	    }
	    else {
	        if `confeffect' != -999 | `"`dist_confeffect'"' != "" {
	            display as error "confeffect() is only supported with linear from_model"
	            exit 198
	        }
	        if `p1' != -1 & `p0' != -1 & (`rrcd' != -1 | `rrud' != -1) {
	            local do_correction = 1
	        }
	        else if `p1' != -1 | `p0' != -1 | `rrcd' != -1 | `rrud' != -1 {
	            display as error "confounding correction requires p1(), p0(), and rrcd() or rrud()"
	            exit 198
	        }
	    }
	    if `do_correction' == 0 & "`evalue'" == "" {
	        display as error "specify confounding parameters or evalue"
	        exit 198
	    }

    * Validate confounding parameters
    if `do_correction' {
	        if missing(`p1') | `p1' < 0 | `p1' > 1 {
	            display as error "p1() must be in [0, 1]"
	            exit 198
	        }
	        if missing(`p0') | `p0' < 0 | `p0' > 1 {
	            display as error "p0() must be in [0, 1]"
	            exit 198
	        }
	        if `rrcd' != -1 & (missing(`rrcd') | `rrcd' <= 0) {
	            display as error "rrcd() must be > 0"
	            exit 198
	        }
	        if `rrud' != -1 & (missing(`rrud') | `rrud' <= 0) {
	            display as error "rrud() must be > 0"
	            exit 198
	        }
        * Reject specifying both rrcd and rrud
	        if !`is_linear' & `rrcd' != -1 & `rrud' != -1 {
	            display as error "specify rrcd() or rrud(), not both"
	            exit 198
	        }
	        if `is_linear' {
	            if missing(`confeffect') {
	                display as error "confeffect() must be nonmissing"
	                exit 198
	            }
	        }
	        else {
	            if `rrud' != -1 {
	                local use_rrud = 1
	                local rr_val = `rrud'
	            }
	            else {
	                local use_rrud = 0
	                local rr_val = `rrcd'
	            }
	        }
	    }

    if `seed' != -1 {
        set seed `seed'
    }

	    * E-VALUE
    if "`evalue'" != "" {
        if `is_linear' {
            display as text ""
            display as text "{bf:Note:} E-value requires a ratio measure (OR or RR)."
            display as text "The estimate from `ecmd' is a linear coefficient."
            display as text "E-value computation is skipped for linear models."
            display as text ""
            local evalue ""
        }
        else {
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
	                if missing(`ci_bound') | `ci_bound' <= 0 {
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
            else if `has_est_ci' {
                * Use CI from model or estimator contract
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
    }

    * Label for display: linear models show "Coefficient" instead of OR/RR
    if `is_linear' {
        local meas_label "Coefficient"
    }
    else {
        local meas_label "`measure'"
    }

	    * SIMPLE BIAS ANALYSIS
    if `reps' == 0 {
        if `do_correction' {
	            if `is_linear' {
	                * Subtractive correction for linear coefficients
	                * MD_adj = MD_obs - (p1 - p0) * confounder_effect
	                local corrected = `estimate' - (`p1' - `p0') * `confeffect'
            }
            else {
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
        }

        * Display
        display as text ""
        display as text "{bf:Quantitative Bias Analysis: Unmeasured Confounding}"
        display as text ""
        display as text "  Observed `meas_label': " as result %9.4f `estimate'

        if `has_est_ci' {
            display as text "  `level'% CI:     " as result %9.4f `est_lo' ///
                as text " - " as result %9.4f `est_hi'
            if `from_model_flag' {
                display as text "  (from last estimation command)"
            }
            else {
                display as text "  (from active `contract_source' contract)"
                if "`contract_estimand'" != "" {
                    display as text "  Estimand:     " as result "`contract_estimand'"
                }
            }
        }
        display as text ""

        if `do_correction' {
            display as text "{bf:Confounding parameters}"
            display as text "  P(U=1 | E=1): " as result %6.4f `p1'
            display as text "  P(U=1 | E=0): " as result %6.4f `p0'
	            if `is_linear' {
	                display as text "  Confounder effect: " as result %9.4f `confeffect'
	            }
	            else if `use_rrud' {
	                display as text "  RR(U->D):     " as result %6.4f `rrud'
	            }
            else {
                display as text "  RR(C->D):     " as result %6.4f `rrcd'
            }
            display as text ""
            display as text "{bf:Results}"
	            if `is_linear' {
	                display as text "  Correction:  " as result %9.4f ///
	                    -(`p1' - `p0') * `confeffect'
	                display as text "  Corrected `meas_label':  " as result %9.4f `corrected'
            }
            else {
                display as text "  Bias factor:     " as result %9.4f `bf'
                display as text "  Corrected `meas_label':  " as result %9.4f `corrected'
                if `estimate' != 0 & `estimate' < . {
                    local ratio = `corrected' / `estimate'
                    display as text "  Ratio (corrected/observed): " as result %6.4f `ratio'
                }
            }
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

        * Store results
        return scalar observed = `estimate'
        return local measure "`measure'"
        return local method "simple"
        if `is_linear' {
            return local correction_type "subtractive"
        }
        if `do_correction' {
            return scalar corrected = `corrected'
            if !`is_linear' {
                return scalar bias_factor = `bf'
            }
            return scalar p1 = `p1'
            return scalar p0 = `p0'
	            if `is_linear' {
	                return scalar confeffect = `confeffect'
	            }
	            else if `use_rrud' {
	                return scalar rrud = `rrud'
	            }
            else {
                return scalar rrcd = `rrcd'
            }
            if !`is_linear' & "`ratio'" != "" {
                return scalar ratio = `ratio'
            }
        }
        if "`evalue'" != "" {
            return scalar evalue = `eval_point'
            if `eval_ci' < . {
                return scalar evalue_ci = `eval_ci'
            }
        }
        if `has_est_ci' {
            return scalar ci_lower = `est_lo'
            return scalar ci_upper = `est_hi'
        }
        if `contract_flag' {
            if `se_treat' < . return scalar se = `se_treat'
            return local source "`contract_source'"
            return local cmd "`contract_cmd'"
            return local outcome "`contract_outcome'"
            return local treatment "`contract_treatment'"
            return local estimand "`contract_estimand'"
        }
    }

	    * PROBABILISTIC BIAS ANALYSIS
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
	        if `is_linear' {
	            if "`dist_confeffect'" == "" local dist_confeffect "constant `confeffect'"
	        }
	        else {
	            if "`dist_rr'" == "" local dist_rr "constant `rr_val'"
	        }

        preserve
	        quietly {
	            clear
	            set obs `reps'

		            gen byte _draw_invalid = 0
		            _qba_draw_checked, dist(`"`dist_p1'"') gen(_p1) n(`reps') ///
		                invalid(_draw_invalid) lower(0) upper(1)
		            _qba_draw_checked, dist(`"`dist_p0'"') gen(_p0) n(`reps') ///
		                invalid(_draw_invalid) lower(0) upper(1)
		            if `is_linear' {
		                _qba_draw_checked, dist(`"`dist_confeffect'"') gen(_conf_eff) ///
		                    n(`reps') invalid(_draw_invalid)
		            }
		            else {
		                _qba_draw_checked, dist(`"`dist_rr'"') gen(_rr) n(`reps') ///
		                    invalid(_draw_invalid) lower(0) loweropen
		            }
		            count if _draw_invalid == 1
		            local n_draw_invalid = r(N)

	            if `is_linear' {
	                * Subtractive correction for linear coefficients
	                gen double _result = `estimate' - (_p1 - _p0) * _conf_eff
	                replace _result = . if _draw_invalid == 1
	                replace _result = . if _result >= .
            }
            else {
                if `use_rrud' {
                    gen double _bf = (_p1 * _rr + (1 - _p1)) / (_p0 * _rr + (1 - _p0))
                }
                else {
                    gen double _bf = (_p1 * (_rr - 1) + 1) / (_p0 * (_rr - 1) + 1)
                }
                gen double _result = `estimate' / _bf
                replace _result = . if _draw_invalid == 1
                replace _result = . if _result <= 0 | _result >= .
            }

            count if _result < .
            local n_valid = r(N)
        }

        if `n_valid' == 0 {
            restore
            display as error "all replicates produced invalid results"
            exit 198
        }

        local pct_invalid = round(100 * (1 - `n_valid'/`reps'), 0.1)
        if `pct_invalid' > 20 {
            display as text "{bf:Warning:} `pct_invalid'% of replicates produced" ///
                " invalid results."
            if `n_draw_invalid' > 0 {
                display as text "  (`n_draw_invalid' had out-of-support parameter draws)"
            }
            display as text "Consider narrowing the bias parameter distributions."
        }

	        local save_rc = 0
	        quietly {
		            _qba_mc_summary _result, level(`level')
		            local mc_mean = r(mean)
	            local mc_median = r(median)
	            local mc_sd = r(sd)
	            local mc_lo = r(ci_lower)
	            local mc_hi = r(ci_upper)

	            if `"`saving'"' != "" {
	                if `is_linear' {
	                    keep _p1 _p0 _conf_eff _result
	                }
	                else {
	                    keep _p1 _p0 _rr _bf _result
	                    rename _bf bias_factor
                }
	                rename _result corrected_`=strlower("`measure'")'
	                rename _p1 p1
	                rename _p0 p0
	                if `is_linear' {
	                    rename _conf_eff confounder_effect
	                }
	                else {
	                    rename _rr rr_confounder
	                }
	                if "`save_replace'" != "" {
	                    capture noisily save `"`savefile'"', replace
	                }
	                else {
	                    capture noisily save `"`savefile'"'
	                }
	                local save_rc = _rc
	            }
	        }
	        restore

        * Display
        display as text ""
        display as text "{bf:Probabilistic Bias Analysis: Unmeasured Confounding}"
        display as text ""
        display as text "Replications: " as result %8.0fc `reps' ///
            as text "  (valid: " as result %8.0fc `n_valid' as text ")"
        display as text ""
        display as text "  Observed `meas_label':  " as result %9.4f `estimate'
        display as text ""
        display as text "{bf:Corrected `meas_label' (Monte Carlo)}"
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

        * Store results
        return scalar observed = `estimate'
        return scalar corrected = `mc_median'
        return scalar mean = `mc_mean'
        return scalar sd = `mc_sd'
        return scalar ci_lower = `mc_lo'
        return scalar ci_upper = `mc_hi'
        return scalar reps = `reps'
        return scalar n_valid = `n_valid'
        return scalar n_draw_invalid = `n_draw_invalid'
        return local measure "`measure'"
        return local method "probabilistic"
        if `contract_flag' {
            if `se_treat' < . return scalar se = `se_treat'
            return local source "`contract_source'"
            return local cmd "`contract_cmd'"
            return local outcome "`contract_outcome'"
            return local treatment "`contract_treatment'"
            return local estimand "`contract_estimand'"
        }
        if `is_linear' {
            return local correction_type "subtractive"
        }
	        if "`evalue'" != "" {
	            return scalar evalue = `eval_point'
	            if `eval_ci' < . {
	                return scalar evalue_ci = `eval_ci'
	            }
	        }
	        if `save_rc' {
	            display as error "saving() failed; analytical results are posted in r()"
	            exit `save_rc'
	        }
	    }

    }
    local rc = _rc
    set varabbrev `_saved_varabbrev'
    if `rc' exit `rc'
end
