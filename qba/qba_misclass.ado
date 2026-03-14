*! qba_misclass Version 1.0.0  2026/03/13
*! Misclassification bias analysis for 2x2 tables
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
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

References:
  Lash TL, Fox MP, Fink AK. Applying Quantitative Bias Analysis to
    Epidemiologic Data. 2nd ed. Springer; 2021.
  Fox MP, Lash TL, Greenland S. A method to automate probabilistic
    sensitivity analyses of misclassified binary variables. Int J
    Epidemiol. 2005;34(6):1370-1376.
*/

capture program drop qba_misclass
program define qba_misclass, rclass
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

    syntax , A(real) B(real) C(real) D(real) ///
        SEca(real) SPca(real) ///
        [SEcb(real -1) SPcb(real -1) ///
         TYpe(string) MEAsure(string) ///
         Reps(integer 0) ///
         dist_se(string) dist_sp(string) ///
         dist_se1(string) dist_sp1(string) ///
         Seed(integer -1) Level(cilevel) ///
         SAving(string)]

    * Validate cell counts
    if `a' < 0 | `b' < 0 | `c' < 0 | `d' < 0 {
        display as error "cell counts must be non-negative"
        exit 198
    }

    * Validate Se/Sp
    if `seca' <= 0 | `seca' > 1 {
        display as error "seca() must be in (0, 1]"
        exit 198
    }
    if `spca' <= 0 | `spca' > 1 {
        display as error "spca() must be in (0, 1]"
        exit 198
    }
    if `seca' + `spca' <= 1 {
        display as error "seca() + spca() must be > 1 for identifiability"
        exit 198
    }

    * Defaults
    if "`type'" == "" local type "exposure"
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

    * Differential misclassification
    local differential = 0
    if `secb' != -1 | `spcb' != -1 {
        local differential = 1
        if `secb' == -1 local secb = `seca'
        if `spcb' == -1 local spcb = `spca'
        if `secb' <= 0 | `secb' > 1 {
            display as error "secb() must be in (0, 1]"
            exit 198
        }
        if `spcb' <= 0 | `spcb' > 1 {
            display as error "spcb() must be in (0, 1]"
            exit 198
        }
        if `secb' + `spcb' <= 1 {
            display as error "secb() + spcb() must be > 1 for identifiability"
            exit 198
        }
    }

    * Set seed
    if `seed' != -1 {
        set seed `seed'
    }

    * Compute observed measure
    local obs_or = (`a' * `d') / (`b' * `c')
    local M1 = `a' + `b'
    local M0 = `c' + `d'
    local N1 = `a' + `c'
    local N0 = `b' + `d'
    if "`measure'" == "RR" {
        local obs_rr = (`a' / `N1') / (`b' / `N0')
    }

    * =====================================================================
    * SIMPLE BIAS ANALYSIS
    * =====================================================================
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

        * Compute corrected measure
        if `b_corr' * `c_corr' != 0 {
            local corr_or = (`a_corr' * `d_corr') / (`b_corr' * `c_corr')
        }
        else {
            local corr_or = .
        }
        if "`measure'" == "RR" {
            local N1_corr = `a_corr' + `c_corr'
            local N0_corr = `b_corr' + `d_corr'
            if `N1_corr' != 0 & `N0_corr' != 0 {
                local corr_rr = (`a_corr' / `N1_corr') / (`b_corr' / `N0_corr')
            }
            else {
                local corr_rr = .
            }
        }

        * Display results
        display as text ""
        display as text "{bf:Quantitative Bias Analysis: Misclassification}"
        display as text "{hline 60}"
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
        display as text "  Cases    " as result %10.1f `a' as result %10.1f `b'
        display as text "  Non-cases" as result %10.1f `c' as result %10.1f `d'
        display as text ""

        display as text "{bf:Bias parameters}"
        if `differential' {
            display as text "  Se (cases):     " as result %6.4f `seca'
            display as text "  Sp (cases):     " as result %6.4f `spca'
            display as text "  Se (non-cases): " as result %6.4f `secb'
            display as text "  Sp (non-cases): " as result %6.4f `spcb'
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
            display as text "  Corrected OR: " as result %9.4f `corr_or'
            if `obs_or' != 0 & `obs_or' < . {
                local ratio = `corr_or' / `obs_or'
                display as text "  Ratio (corrected/observed): " as result %6.4f `ratio'
            }
        }
        else {
            display as text "  Observed RR:  " as result %9.4f `obs_rr'
            display as text "  Corrected RR: " as result %9.4f `corr_rr'
            if `obs_rr' != 0 & `obs_rr' < . {
                local ratio = `corr_rr' / `obs_rr'
                display as text "  Ratio (corrected/observed): " as result %6.4f `ratio'
            }
        }
        display as text "{hline 60}"

        * Store results
        return scalar a = `a'
        return scalar b = `b'
        return scalar c = `c'
        return scalar d = `d'
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

    * =====================================================================
    * PROBABILISTIC BIAS ANALYSIS
    * =====================================================================
    else {
        if `reps' < 100 {
            display as error "reps() should be at least 100 for stable results"
            exit 198
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

            * Draw Se/Sp values
            _qba_draw_one, dist("`dist_se'") gen(_se0) n(`reps')
            _qba_draw_one, dist("`dist_sp'") gen(_sp0) n(`reps')

            if `differential' {
                _qba_draw_one, dist("`dist_se1'") gen(_se1) n(`reps')
                _qba_draw_one, dist("`dist_sp1'") gen(_sp1) n(`reps')
            }

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

            * Drop invalid (negative cells or undefined)
            replace _result = . if _a_corr < 0 | _b_corr < 0 | _c_corr < 0 | _d_corr < 0
            replace _result = . if _result <= 0 | _result >= .

            count if _result < .
            local n_valid = r(N)

            if `n_valid' == 0 {
                display as error "all Monte Carlo replicates produced invalid results"
                exit 198
            }

            * Summary statistics
            summarize _result, detail
            local mc_mean = r(mean)
            local mc_median = r(p50)
            local mc_sd = r(sd)

            local alpha = (100 - `level') / 2
            _pctile _result, percentiles(`alpha' `=100-`alpha'')
            local mc_lo = r(r1)
            local mc_hi = r(r2)

            * Save if requested
            if `"`saving'"' != "" {
                if `differential' {
                    keep _se0 _sp0 _se1 _sp1 _a_corr _b_corr _c_corr _d_corr _result
                }
                else {
                    keep _se0 _sp0 _a_corr _b_corr _c_corr _d_corr _result
                }
                rename _result corrected_`=strlower("`measure'")'
                rename _a_corr a_corr
                rename _b_corr b_corr
                rename _c_corr c_corr
                rename _d_corr d_corr
                rename _se0 se
                rename _sp0 sp
                save `saving'
            }
        }
        restore

        * Display results
        display as text ""
        display as text "{bf:Probabilistic Bias Analysis: Misclassification}"
        display as text "{hline 60}"
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
        display as text "  Cases    " as result %10.1f `a' as result %10.1f `b'
        display as text "  Non-cases" as result %10.1f `c' as result %10.1f `d'
        display as text ""

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
        display as text "  `level'% CI:  " as result %9.4f `mc_lo' ///
            as text " - " as result %9.4f `mc_hi'
        display as text "{hline 60}"

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
        return local type "`type'"
        return local measure "`measure'"
        return local method "probabilistic"
        return local dist_se "`dist_se'"
        return local dist_sp "`dist_sp'"
    }
end
