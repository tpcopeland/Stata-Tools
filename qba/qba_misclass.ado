*! qba_misclass Version 1.1.2  2026/08/09
*! Misclassification bias analysis for 2x2 tables
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
Corrects 2x2 table cell counts and measures of association (OR, RR)
for exposure or outcome misclassification.

Table layout:
              Exposed   Unexposed
  Cases         a          b
  Non-cases     c          d

Simple mode: fixed Se/Sp values correct the table analytically.

Probabilistic mode (reps()): Monte Carlo draws from Se/Sp distributions.
Percentiles of the resulting bias-adjusted measures form a SYSTEMATIC-ERROR
simulation interval (Fox, MacLehose & Lash 2023): they propagate uncertainty
in the bias parameters only, and are not corrected confidence intervals.

totalerror adds the two further uncertainty sources of the authors' revised
summary-level algorithm, giving a TOTAL-ERROR simulation interval:
  1. bias-adjusted cells                            (systematic error)
  2. exposure/outcome prevalence drawn Beta(cell, cell), converted to
     PPV/NPV, and the observed cells reallocated by binomial draws
                                                    (reclassification error)
  3. log measure perturbed by z * SE computed from the reallocated cells
                                                    (random error)
A random-error-only arm (observed measure perturbed by its own log SE) is
reported alongside, so the three interval widths are comparable.

Estimands:
  measure(OR) -- odds ratio (a*d)/(b*c) on bias-adjusted cells
  measure(RR) -- risk ratio (a/(a+c))/(b/(b+d)) on bias-adjusted cells

References:
  Lash TL, Fox MP, Fink AK. Applying Quantitative Bias Analysis to
    Epidemiologic Data. 2nd ed. Springer; 2021.
  Fox MP, Lash TL, Greenland S. A method to automate probabilistic
    sensitivity analyses of misclassified binary variables. Int J
    Epidemiol. 2005;34(6):1370-1376.
  Fox MP, MacLehose RF, Lash TL. SAS and R code for probabilistic
    quantitative bias analysis for misclassified binary variables and
    binary unmeasured confounders. Int J Epidemiol. 2023;52(5):1624-1633.
    (systematic- vs total-error simulation intervals; correlated Se/Sp
    draws; case-control sampling-fraction adjustment)
*/

capture program drop qba_misclass
program define qba_misclass, rclass
    version 16.0
    local _saved_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    _qba_require_distributions

	    syntax , A(real) B(real) C(real) D(real) ///
	        SEca(real) SPca(real) ///
	        [SEcb(real -1) SPcb(real -1) ///
         TYpe(string) MEAsure(string) ///
         Reps(integer 0) ///
         dist_se(string) dist_sp(string) ///
	         dist_se1(string) dist_sp1(string) ///
	         CORR(real 0) TOtalerror ///
	         FCASe(real 1) FCTRl(real 1) ///
	         Seed(integer -1) Level(cilevel) ///
	         SAving(string asis)]

	    if missing(`reps') | `reps' < 0 {
	        display as error "reps() must be a nonnegative integer"
	        exit 198
	    }
	    if `seed' != -1 & missing(`seed') {
	        display as error "seed() must be a nonmissing integer"
	        exit 198
	    }
	    if `reps' == 0 {
	        if `"`saving'"' != "" {
	            display as error "saving() requires reps()"
	            exit 198
	        }
	        if `"`dist_se'"' != "" | `"`dist_sp'"' != "" | ///
	            `"`dist_se1'"' != "" | `"`dist_sp1'"' != "" {
	            display as error "dist_*() options require reps()"
	            exit 198
	        }
	        if `seed' != -1 {
	            display as error "seed() requires reps()"
	            exit 198
	        }
	        if `corr' != 0 {
	            display as error "corr() requires reps()"
	            exit 198
	        }
	        if "`totalerror'" != "" {
	            display as error "totalerror requires reps()"
	            exit 198
	        }
	    }
	    if missing(`corr') | `corr' < -1 | `corr' > 1 {
	        display as error "corr() must be in [-1, 1]"
	        exit 198
	    }

	    * Case-control sampling fractions (Fox, MacLehose & Lash 2023): outcome
	    * misclassification in a case-control study must be corrected on the
	    * source-population table, so the sampled cells are divided by the
	    * fraction of cases and of controls that were sampled.
	    foreach _f in fcase fctrl {
	        if missing(``_f'') | ``_f'' <= 0 | ``_f'' > 1 {
	            display as error "`_f'() must be in (0, 1]"
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

	    * Validate cell counts
	    foreach _cell in a b c d {
	        if missing(``_cell'') {
	            display as error "`_cell'() must be nonmissing"
	            exit 198
	        }
	        if ``_cell'' < 0 {
	            display as error "cell counts must be non-negative"
	            exit 198
	        }
	    }
    if `a' + `b' + `c' + `d' == 0 {
        display as error "cell counts must include at least one observation"
        exit 2000
    }

    * Validate Se/Sp
	    if missing(`seca') | `seca' <= 0 | `seca' > 1 {
	        display as error "seca() must be in (0, 1]"
	        exit 198
	    }
	    if missing(`spca') | `spca' <= 0 | `spca' > 1 {
	        display as error "spca() must be in (0, 1]"
	        exit 198
	    }
    if `seca' + `spca' <= 1 {
        display as error "seca() + spca() must be > 1 for identifiability"
        exit 198
    }

    * Defaults
	    if "`type'" == "" local type "exposure"
	    local type = strlower("`type'")
	    if !inlist("`type'", "exposure", "outcome") {
	        display as error "type() must be exposure or outcome"
	        exit 198
    }
    if "`measure'" == "" local measure "OR"
    local measure = strupper("`measure'")
    if !inlist("`measure'", "OR", "RR") {
        display as error "measure() must be OR or RR"
        exit 198
    }
    if "`type'" == "exposure" & (`fcase' != 1 | `fctrl' != 1) {
        display as error ///
            "fcase()/fctrl() apply to type(outcome); exposure misclassification is corrected within outcome strata and needs no sampling-fraction adjustment"
        exit 198
    }

    * Differential misclassification
    local differential = 0
    if `secb' != -1 | `spcb' != -1 {
        local differential = 1
        if `secb' == -1 local secb = `seca'
        if `spcb' == -1 local spcb = `spca'
	        if missing(`secb') | `secb' <= 0 | `secb' > 1 {
	            display as error "secb() must be in (0, 1]"
	            exit 198
	        }
	        if missing(`spcb') | `spcb' <= 0 | `spcb' > 1 {
	            display as error "spcb() must be in (0, 1]"
	            exit 198
	        }
        if `secb' + `spcb' <= 1 {
            display as error "secb() + spcb() must be > 1 for identifiability"
            exit 198
        }
    }

    * Reject dist_se1/dist_sp1 without differential mode
    if "`dist_se1'" != "" & `differential' == 0 {
        display as error "dist_se1() requires secb() or spcb() to enable differential mode"
        exit 198
    }
    if "`dist_sp1'" != "" & `differential' == 0 {
        display as error "dist_sp1() requires secb() or spcb() to enable differential mode"
        exit 198
    }
    * corr() induces dependence BETWEEN the two strata's bias parameters. Under
    * nondifferential misclassification there is one Se and one Sp, applied to
    * both strata, so there is no second parameter to correlate with.
    if `corr' != 0 & `differential' == 0 {
        display as error ///
            "corr() requires secb() or spcb() to enable differential mode; nondifferential draws share one Se and one Sp"
        exit 198
    }

    * Set seed
    if `seed' != -1 {
        set seed `seed'
    }

    * Inflate the sampled table to the source population before correcting
    * outcome misclassification in a case-control study.
    local cc_sampling = 0
    local a_obs = `a'
    local b_obs = `b'
    local c_obs = `c'
    local d_obs = `d'
    if `fcase' != 1 | `fctrl' != 1 {
        local cc_sampling = 1
        local a = `a' / `fcase'
        local b = `b' / `fcase'
        local c = `c' / `fctrl'
        local d = `d' / `fctrl'
    }

    * Compute observed measure (guard division by zero)
    local M1 = `a' + `b'
    local M0 = `c' + `d'
    local N1 = `a' + `c'
    local N0 = `b' + `d'
    if `b' * `c' != 0 {
        local obs_or = (`a' * `d') / (`b' * `c')
    }
    else {
        local obs_or = .
    }
    if "`measure'" == "RR" {
        if `N1' != 0 & `N0' != 0 & `b' != 0 {
            local obs_rr = (`a' / `N1') / (`b' / `N0')
        }
        else {
            local obs_rr = .
        }
    }

    * SIMPLE BIAS ANALYSIS
    if `reps' == 0 {
        if "`type'" == "exposure" {
            * Correct exposure misclassification within disease strata
            if `differential' == 0 {
                * Nondifferential: same Se/Sp in cases and non-cases
                local a_corr = (`a' - (1 - `spca') * `M1') / (`seca' + `spca' - 1)
                local b_corr = `M1' - `a_corr'
                local c_corr = (`c' - (1 - `spca') * `M0') / (`seca' + `spca' - 1)
                local d_corr = `M0' - `c_corr'
            }
            else {
                * Differential: Se1/Sp1 for cases, Se0/Sp0 for non-cases
                local a_corr = (`a' - (1 - `spca') * `M1') / (`seca' + `spca' - 1)
                local b_corr = `M1' - `a_corr'
                local c_corr = (`c' - (1 - `spcb') * `M0') / (`secb' + `spcb' - 1)
                local d_corr = `M0' - `c_corr'
            }
        }
        else {
            * Correct outcome misclassification within exposure strata
            if `differential' == 0 {
                local a_corr = (`a' - (1 - `spca') * `N1') / (`seca' + `spca' - 1)
                local c_corr = `N1' - `a_corr'
                local b_corr = (`b' - (1 - `spca') * `N0') / (`seca' + `spca' - 1)
                local d_corr = `N0' - `b_corr'
            }
            else {
                local a_corr = (`a' - (1 - `spca') * `N1') / (`seca' + `spca' - 1)
                local c_corr = `N1' - `a_corr'
                local b_corr = (`b' - (1 - `spcb') * `N0') / (`secb' + `spcb' - 1)
                local d_corr = `N0' - `b_corr'
            }
        }

        * Warn if any corrected cell is not strictly positive. Zero counts as
        * incompatible, not as a valid table: the worked example in Fox,
        * MacLehose & Lash (2023) discards simulations with negative OR zero
        * bias-adjusted cells, and the probabilistic arm below does the same.
        local n_bad = 0
        foreach _cell in a_corr b_corr c_corr d_corr {
            if ``_cell'' <= 0 local ++n_bad
        }
        if `n_bad' > 0 {
            display as text ""
            display as text "{bf:Warning:} `n_bad' corrected cell(s) are not positive."
            display as text "The bias parameters are incompatible with these observed data."
        }

        * Compute corrected measure
        if `n_bad' > 0 {
            local corr_or = .
        }
        else if `b_corr' * `c_corr' != 0 {
            local corr_or = (`a_corr' * `d_corr') / (`b_corr' * `c_corr')
        }
        else {
            local corr_or = .
        }
        if "`measure'" == "RR" {
            local N1_corr = `a_corr' + `c_corr'
            local N0_corr = `b_corr' + `d_corr'
            if `n_bad' > 0 {
                local corr_rr = .
            }
            else if `N1_corr' != 0 & `N0_corr' != 0 {
                local corr_rr = (`a_corr' / `N1_corr') / (`b_corr' / `N0_corr')
            }
            else {
                local corr_rr = .
            }
        }

        * Display results
        display as text ""
        display as text "{bf:Quantitative Bias Analysis: Misclassification}"
        display as text ""

        if `differential' {
            display as text "Type: Differential `type' misclassification"
        }
        else {
            display as text "Type: Nondifferential `type' misclassification"
        }
        display as text ""

        display as text "{bf:Observed 2x2 table}"
        display as text "              Exposed   Unexposed"
        display as text "  Cases    " as result %10.1f `a_obs' as result %10.1f `b_obs'
        display as text "  Non-cases" as result %10.1f `c_obs' as result %10.1f `d_obs'
        display as text ""
        if `cc_sampling' {
            display as text "{bf:Source-population 2x2 table}" ///
                as text " (fcase = " as result %6.4f `fcase' ///
                as text ", fctrl = " as result %6.4f `fctrl' as text ")"
            display as text "              Exposed   Unexposed"
            display as text "  Cases    " as result %10.1f `a' as result %10.1f `b'
            display as text "  Non-cases" as result %10.1f `c' as result %10.1f `d'
            display as text ""
        }

        display as text "{bf:Bias parameters}"
        if `differential' {
            if "`type'" == "exposure" {
                display as text "  Se (cases):     " as result %6.4f `seca'
                display as text "  Sp (cases):     " as result %6.4f `spca'
                display as text "  Se (non-cases): " as result %6.4f `secb'
                display as text "  Sp (non-cases): " as result %6.4f `spcb'
            }
            else {
                display as text "  Se (exposed):     " as result %6.4f `seca'
                display as text "  Sp (exposed):     " as result %6.4f `spca'
                display as text "  Se (unexposed):   " as result %6.4f `secb'
                display as text "  Sp (unexposed):   " as result %6.4f `spcb'
            }
        }
        else {
            display as text "  Sensitivity: " as result %6.4f `seca'
            display as text "  Specificity: " as result %6.4f `spca'
        }
        display as text ""

        display as text "{bf:Corrected 2x2 table}"
        display as text "              Exposed   Unexposed"
        display as text "  Cases    " as result %10.1f `a_corr' as result %10.1f `b_corr'
        display as text "  Non-cases" as result %10.1f `c_corr' as result %10.1f `d_corr'
        display as text ""

        display as text "{bf:Measures of association}"
        if "`measure'" == "OR" {
            display as text "  Observed OR:  " as result %9.4f `obs_or'
            if `corr_or' < . {
                display as text "  Corrected OR: " as result %9.4f `corr_or'
            }
            else {
                display as text "  Corrected OR: " as result "undefined"
            }
            if `obs_or' != 0 & `obs_or' < . & `corr_or' < . {
                local ratio = `corr_or' / `obs_or'
                display as text "  Ratio (corrected/observed): " as result %6.4f `ratio'
            }
        }
        else {
            display as text "  Observed RR:  " as result %9.4f `obs_rr'
            if `corr_rr' < . {
                display as text "  Corrected RR: " as result %9.4f `corr_rr'
            }
            else {
                display as text "  Corrected RR: " as result "undefined"
            }
            if `obs_rr' != 0 & `obs_rr' < . & `corr_rr' < . {
                local ratio = `corr_rr' / `obs_rr'
                display as text "  Ratio (corrected/observed): " as result %6.4f `ratio'
            }
        }
        if `n_bad' > 0 {
            display as text "  Corrected measure: undefined; bias parameters are incompatible with observed data"
        }

        * Store results
        return scalar a = `a_obs'
        return scalar b = `b_obs'
        return scalar c = `c_obs'
        return scalar d = `d_obs'
        if `cc_sampling' {
            return scalar fcase = `fcase'
            return scalar fctrl = `fctrl'
            return scalar adj_a = `a'
            return scalar adj_b = `b'
            return scalar adj_c = `c'
            return scalar adj_d = `d'
        }
        return scalar corrected_a = `a_corr'
        return scalar corrected_b = `b_corr'
        return scalar corrected_c = `c_corr'
        return scalar corrected_d = `d_corr'
        if "`measure'" == "OR" {
            return scalar observed = `obs_or'
            return scalar corrected = `corr_or'
        }
        else {
            return scalar observed = `obs_rr'
            return scalar corrected = `corr_rr'
        }
        if "`ratio'" != "" {
            return scalar ratio = `ratio'
        }
        return scalar seca = `seca'
        return scalar spca = `spca'
        if `differential' {
            return scalar secb = `secb'
            return scalar spcb = `spcb'
        }
        return local type "`type'"
        return local measure "`measure'"
        return local method "simple"
    }

    * PROBABILISTIC BIAS ANALYSIS
    else {
        if `reps' < 100 {
            display as error "reps() must be at least 100"
            display as error ///
                "100 is a floor, not a stability guarantee; Fox, MacLehose & Lash (2023) use 10^5-10^6 replications"
            exit 198
        }
        if "`totalerror'" != "" {
            * The reclassification step reallocates the OBSERVED cells with
            * binomial draws, so the observed table must be whole counts.
            foreach _cell in a b c d {
                if abs(``_cell'' - round(``_cell'')) > 1e-8 {
                    display as error ///
                        "totalerror requires integer cell counts; `_cell' is ``_cell''"
                    if `cc_sampling' {
                        display as error ///
                            "(cells were divided by fcase()/fctrl(); the source-population table must also be whole counts)"
                    }
                    exit 198
                }
                local `_cell' = round(``_cell'')
            }
            if `a' == 0 | `b' == 0 | `c' == 0 | `d' == 0 {
                display as error ///
                    "totalerror requires all four cells > 0; the Beta prevalence and binomial reallocation steps are undefined on an empty cell"
                exit 198
            }
            * Margins must agree with the snapped cells: the reallocation
            * derives one cell per stratum as (margin - drawn cell).
            local M1 = `a' + `b'
            local M0 = `c' + `d'
            local N1 = `a' + `c'
            local N0 = `b' + `d'
        }

        * Set default distributions if not specified
        if "`dist_se'" == "" local dist_se "constant `seca'"
        if "`dist_sp'" == "" local dist_sp "constant `spca'"
        if `differential' {
            if "`dist_se1'" == "" local dist_se1 "constant `secb'"
            if "`dist_sp1'" == "" local dist_sp1 "constant `spcb'"
        }

        preserve
        quietly {
            clear
            set obs `reps'

            gen byte _draw_invalid = 0

            * Gaussian copula: correlate the case-stratum and non-case-stratum
            * bias parameters by inverting each marginal at a pair of dependent
            * uniforms. Se and Sp get independent copula pairs, matching the
            * author reference code (which uses rho = 0.80 in its examples).
            if `corr' != 0 {
                gen double _z_a = rnormal()
                gen double _u_se0 = normal(_z_a)
                gen double _u_se1 = normal(`corr' * _z_a + ///
                    sqrt(1 - `corr' * `corr') * rnormal())
                gen double _z_b = rnormal()
                gen double _u_sp0 = normal(_z_b)
                gen double _u_sp1 = normal(`corr' * _z_b + ///
                    sqrt(1 - `corr' * `corr') * rnormal())
                drop _z_a _z_b
                local u_se0 "u(_u_se0)"
                local u_sp0 "u(_u_sp0)"
                local u_se1 "u(_u_se1)"
                local u_sp1 "u(_u_sp1)"
            }

            _qba_draw_checked, dist(`"`dist_se'"') gen(_se0) n(`reps') ///
                invalid(_draw_invalid) lower(0) upper(1) loweropen `u_se0'
            _qba_draw_checked, dist(`"`dist_sp'"') gen(_sp0) n(`reps') ///
                invalid(_draw_invalid) lower(0) upper(1) loweropen `u_sp0'
            _qba_flag_misclass_pair, se(_se0) sp(_sp0) invalid(_draw_invalid)

            if `differential' {
                _qba_draw_checked, dist(`"`dist_se1'"') gen(_se1) n(`reps') ///
                    invalid(_draw_invalid) lower(0) upper(1) loweropen `u_se1'
                _qba_draw_checked, dist(`"`dist_sp1'"') gen(_sp1) n(`reps') ///
                    invalid(_draw_invalid) lower(0) upper(1) loweropen `u_sp1'
                _qba_flag_misclass_pair, se(_se1) sp(_sp1) invalid(_draw_invalid)
            }
            if `corr' != 0 {
                drop _u_se0 _u_sp0 _u_se1 _u_sp1
            }

            count if _draw_invalid == 1
            local n_draw_invalid = r(N)

            * Correct table for each rep
            gen double _a_corr = .
            gen double _b_corr = .
            gen double _c_corr = .
            gen double _d_corr = .

            if "`type'" == "exposure" {
                if `differential' == 0 {
                    replace _a_corr = (`a' - (1 - _sp0) * `M1') / (_se0 + _sp0 - 1)
                    replace _b_corr = `M1' - _a_corr
                    replace _c_corr = (`c' - (1 - _sp0) * `M0') / (_se0 + _sp0 - 1)
                    replace _d_corr = `M0' - _c_corr
                }
                else {
                    replace _a_corr = (`a' - (1 - _sp0) * `M1') / (_se0 + _sp0 - 1)
                    replace _b_corr = `M1' - _a_corr
                    replace _c_corr = (`c' - (1 - _sp1) * `M0') / (_se1 + _sp1 - 1)
                    replace _d_corr = `M0' - _c_corr
                }
            }
            else {
                if `differential' == 0 {
                    replace _a_corr = (`a' - (1 - _sp0) * `N1') / (_se0 + _sp0 - 1)
                    replace _c_corr = `N1' - _a_corr
                    replace _b_corr = (`b' - (1 - _sp0) * `N0') / (_se0 + _sp0 - 1)
                    replace _d_corr = `N0' - _b_corr
                }
                else {
                    replace _a_corr = (`a' - (1 - _sp0) * `N1') / (_se0 + _sp0 - 1)
                    replace _c_corr = `N1' - _a_corr
                    replace _b_corr = (`b' - (1 - _sp1) * `N0') / (_se1 + _sp1 - 1)
                    replace _d_corr = `N0' - _b_corr
                }
            }

            * Compute corrected measure
            if "`measure'" == "OR" {
                gen double _result = (_a_corr * _d_corr) / (_b_corr * _c_corr)
            }
            else {
                gen double _N1c = _a_corr + _c_corr
                gen double _N0c = _b_corr + _d_corr
                gen double _result = (_a_corr / _N1c) / (_b_corr / _N0c)
            }

            * A bias-adjusted cell of exactly zero is as incompatible with the
            * observed data as a negative one; the reference worked example
            * discards both. Screening only on "< 0" let a zero-cell replicate
            * through whenever the measure stayed finite and positive.
            gen byte _cells_bad = (_a_corr <= 0 | _b_corr <= 0 | ///
                _c_corr <= 0 | _d_corr <= 0 | missing(_a_corr) | ///
                missing(_b_corr) | missing(_c_corr) | missing(_d_corr))

            * Drop invalid (nonpositive cells or undefined measure)
            replace _result = . if _draw_invalid == 1
            replace _result = . if _cells_bad
            replace _result = . if _result <= 0 | _result >= .

            count if _result < .
            local n_valid = r(N)

            * TOTAL-ERROR ARM
            if "`totalerror'" != "" {
                * Per-stratum bias parameters. Stratum 0 is the cases row for
                * type(exposure) and the exposed column for type(outcome);
                * nondifferential misclassification reuses one Se/Sp pair.
                gen double _se_s0 = _se0
                gen double _sp_s0 = _sp0
                if `differential' {
                    gen double _se_s1 = _se1
                    gen double _sp_s1 = _sp1
                }
                else {
                    gen double _se_s1 = _se0
                    gen double _sp_s1 = _sp0
                }

                * Source (2): classified-variable prevalence within each
                * stratum drawn Beta(bias-adjusted cell, complement), then
                * converted to PPV/NPV and used to reallocate the OBSERVED
                * cells by binomial draws.
                if "`type'" == "exposure" {
                    gen double _prev0 = rbeta(_a_corr, _b_corr)
                    gen double _prev1 = rbeta(_c_corr, _d_corr)
                }
                else {
                    gen double _prev0 = rbeta(_a_corr, _c_corr)
                    gen double _prev1 = rbeta(_b_corr, _d_corr)
                }

                gen double _ppv0 = (_se_s0 * _prev0) / ///
                    ((_se_s0 * _prev0) + (1 - _sp_s0) * (1 - _prev0))
                gen double _npv0 = (_sp_s0 * (1 - _prev0)) / ///
                    ((1 - _se_s0) * _prev0 + _sp_s0 * (1 - _prev0))
                gen double _ppv1 = (_se_s1 * _prev1) / ///
                    ((_se_s1 * _prev1) + (1 - _sp_s1) * (1 - _prev1))
                gen double _npv1 = (_sp_s1 * (1 - _prev1)) / ///
                    ((1 - _se_s1) * _prev1 + _sp_s1 * (1 - _prev1))

                gen double _ab = .
                gen double _bb = .
                gen double _cb = .
                gen double _db = .
                if "`type'" == "exposure" {
                    replace _ab = rbinomial(`a', _ppv0) + rbinomial(`b', 1 - _npv0)
                    replace _bb = `M1' - _ab
                    replace _cb = rbinomial(`c', _ppv1) + rbinomial(`d', 1 - _npv1)
                    replace _db = `M0' - _cb
                }
                else {
                    replace _ab = rbinomial(`a', _ppv0) + rbinomial(`c', 1 - _npv0)
                    replace _cb = `N1' - _ab
                    replace _bb = rbinomial(`b', _ppv1) + rbinomial(`d', 1 - _npv1)
                    replace _db = `N0' - _bb
                }

                * Source (3): random error, from the SE of the log measure
                * computed on the reallocated cells.
                if "`measure'" == "OR" {
                    gen double _result_bb = (_ab * _db) / (_bb * _cb)
                    gen double _se_log = sqrt(1/_ab + 1/_bb + 1/_cb + 1/_db)
                }
                else {
                    gen double _result_bb = (_ab / (_ab + _cb)) / (_bb / (_bb + _db))
                    gen double _se_log = sqrt(1/_ab + 1/_bb - ///
                        1/(_ab + _cb) - 1/(_bb + _db))
                }
                gen double _result_te = exp(ln(_result_bb) - rnormal() * _se_log)

                replace _result_te = . if _draw_invalid == 1
                replace _result_te = . if _cells_bad
                replace _result_te = . if _ab <= 0 | _bb <= 0 | _cb <= 0 | _db <= 0
                replace _result_te = . if _result_te <= 0 | _result_te >= .
                count if _result_te < .
                local n_valid_te = r(N)

                * Random-error-only arm: the observed measure perturbed by its
                * own log SE, for a like-for-like interval-width comparison.
                if "`measure'" == "OR" {
                    local se_log_obs = sqrt(1/`a' + 1/`b' + 1/`c' + 1/`d')
                    local obs_meas = `obs_or'
                }
                else {
                    local se_log_obs = sqrt(1/`a' + 1/`b' - 1/`N1' - 1/`N0')
                    local obs_meas = `obs_rr'
                }
                gen double _result_re = ///
                    exp(ln(`obs_meas') - rnormal() * `se_log_obs')
            }
        }

        if `n_valid' == 0 {
            restore
            display as error "all Monte Carlo replicates produced invalid results"
            exit 198
        }

        local pct_invalid = round(100 * (1 - `n_valid'/`reps'), 0.1)
        if `pct_invalid' > 20 {
            display as text "{bf:Warning:} `pct_invalid'% of replicates produced" ///
                " invalid results (negative cells or undefined measure)."
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

            if "`totalerror'" != "" {
                if `n_valid_te' > 0 {
                    _qba_mc_summary _result_te, level(`level')
                    local te_mean = r(mean)
                    local te_median = r(median)
                    local te_sd = r(sd)
                    local te_lo = r(ci_lower)
                    local te_hi = r(ci_upper)
                }
                _qba_mc_summary _result_re, level(`level')
                local re_median = r(median)
                local re_lo = r(ci_lower)
                local re_hi = r(ci_upper)
            }

            * Save if requested
            if `"`saving'"' != "" {
                local keepvars "_se0 _sp0"
                if `differential' local keepvars "`keepvars' _se1 _sp1"
                local keepvars "`keepvars' _a_corr _b_corr _c_corr _d_corr _result"
                if "`totalerror'" != "" {
                    local keepvars ///
                        "`keepvars' _ab _bb _cb _db _result_bb _result_te _result_re"
                }
                keep `keepvars'
                rename _result corrected_`=strlower("`measure'")'
                rename _a_corr a_corr
                rename _b_corr b_corr
                rename _c_corr c_corr
	                rename _d_corr d_corr
	                rename _se0 se
	                rename _sp0 sp
	                if `differential' {
	                    rename _se1 se1
	                    rename _sp1 sp1
	                }
	                if "`totalerror'" != "" {
	                    rename _ab a_realloc
	                    rename _bb b_realloc
	                    rename _cb c_realloc
	                    rename _db d_realloc
	                    rename _result_bb reclass_`=strlower("`measure'")'
	                    rename _result_te total_`=strlower("`measure'")'
	                    rename _result_re random_`=strlower("`measure'")'
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

        * Display results
        display as text ""
        display as text "{bf:Probabilistic Bias Analysis: Misclassification}"
        display as text ""

        if `differential' {
            display as text "Type: Differential `type' misclassification"
        }
        else {
            display as text "Type: Nondifferential `type' misclassification"
        }
        display as text "Replications: " as result %8.0fc `reps' ///
            as text "  (valid: " as result %8.0fc `n_valid' as text ")"
        display as text ""

        display as text "{bf:Observed 2x2 table}"
        display as text "              Exposed   Unexposed"
        display as text "  Cases    " as result %10.1f `a_obs' as result %10.1f `b_obs'
        display as text "  Non-cases" as result %10.1f `c_obs' as result %10.1f `d_obs'
        display as text ""
        if `cc_sampling' {
            display as text "{bf:Source-population 2x2 table}" ///
                as text " (fcase = " as result %6.4f `fcase' ///
                as text ", fctrl = " as result %6.4f `fctrl' as text ")"
            display as text "              Exposed   Unexposed"
            display as text "  Cases    " as result %10.1f `a' as result %10.1f `b'
            display as text "  Non-cases" as result %10.1f `c' as result %10.1f `d'
            display as text ""
        }

        if "`measure'" == "OR" {
            display as text "  Observed OR:  " as result %9.4f `obs_or'
        }
        else {
            display as text "  Observed RR:  " as result %9.4f `obs_rr'
        }
        display as text ""

        display as text "{bf:Corrected `measure' (Monte Carlo)}"
        display as text "  Median:   " as result %9.4f `mc_median'
        display as text "  Mean:     " as result %9.4f `mc_mean'
        display as text "  SD:       " as result %9.4f `mc_sd'
        display as text "  `level'% simulation interval: " as result %9.4f `mc_lo' ///
            as text " - " as result %9.4f `mc_hi'
        display as text "  (systematic error only: percentiles over bias-parameter draws,"
        display as text "   not a corrected confidence interval)"
        if `corr' != 0 {
            display as text "  Se and Sp correlated across strata: rho = " ///
                as result %6.3f `corr'
        }

        if "`totalerror'" != "" {
            display as text ""
            display as text "{bf:Simulation intervals by error source}"
            display as text "  Error source          Median      Lower      Upper"
            display as text "  Random error     " ///
                as result %10.4f `re_median' %11.4f `re_lo' %11.4f `re_hi'
            display as text "  Systematic error " ///
                as result %10.4f `mc_median' %11.4f `mc_lo' %11.4f `mc_hi'
            if `n_valid_te' > 0 {
                display as text "  Total error      " ///
                    as result %10.4f `te_median' %11.4f `te_lo' %11.4f `te_hi'
                display as text "  (total-error valid replicates: " ///
                    as result %8.0fc `n_valid_te' as text ")"
            }
            else {
                display as text "  Total error      " as result "  undefined" ///
                    as text "  (no valid replicates)"
            }
        }

        * Store results
        if "`measure'" == "OR" {
            return scalar observed = `obs_or'
        }
        else {
            return scalar observed = `obs_rr'
        }
        return scalar corrected = `mc_median'
        return scalar mean = `mc_mean'
        return scalar sd = `mc_sd'
        return scalar ci_lower = `mc_lo'
        return scalar ci_upper = `mc_hi'
        return scalar reps = `reps'
        return scalar n_valid = `n_valid'
        if `corr' != 0 {
            return scalar corr = `corr'
        }
        if `cc_sampling' {
            return scalar fcase = `fcase'
            return scalar fctrl = `fctrl'
            return scalar adj_a = `a'
            return scalar adj_b = `b'
            return scalar adj_c = `c'
            return scalar adj_d = `d'
        }
        if "`totalerror'" != "" {
            return scalar n_valid_te = `n_valid_te'
            if `n_valid_te' > 0 {
                return scalar te_median = `te_median'
                return scalar te_mean = `te_mean'
                return scalar te_sd = `te_sd'
                return scalar te_lower = `te_lo'
                return scalar te_upper = `te_hi'
            }
            return scalar re_median = `re_median'
            return scalar re_lower = `re_lo'
            return scalar re_upper = `re_hi'
        }
        return local type "`type'"
        return local measure "`measure'"
	        return local method "probabilistic"
	        return local interval "systematic-error simulation interval"
	        return local dist_se "`dist_se'"
	        return local dist_sp "`dist_sp'"
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
