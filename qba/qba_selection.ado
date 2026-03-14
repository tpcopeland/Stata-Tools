*! qba_selection Version 1.0.0  2026/03/13
*! Selection bias analysis for 2x2 tables
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass

/*
Corrects 2x2 table cell counts and measures of association (OR, RR)
for selection bias using selection probabilities for each cell.

Table layout:
              Exposed   Unexposed
  Cases         a          b
  Non-cases     c          d

Simple mode: fixed selection probabilities correct the table.
Probabilistic mode (reps()): Monte Carlo draws from distributions.

References:
  Lash TL, Fox MP, Fink AK. Applying Quantitative Bias Analysis to
    Epidemiologic Data. 2nd ed. Springer; 2021. Chapter 7.
  Greenland S. Basic methods for sensitivity analysis of biases.
    Int J Epidemiol. 1996;25(6):1107-1116.
*/

capture program drop qba_selection
program define qba_selection, rclass
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
        SELa(real) SELb(real) SELc(real) SELd(real) ///
        [MEAsure(string) ///
         Reps(integer 0) ///
         dist_sela(string) dist_selb(string) ///
         dist_selc(string) dist_seld(string) ///
         Seed(integer -1) Level(cilevel) ///
         SAving(string)]

    * Validate cell counts
    if `a' < 0 | `b' < 0 | `c' < 0 | `d' < 0 {
        display as error "cell counts must be non-negative"
        exit 198
    }

    * Validate selection probabilities
    foreach s in sela selb selc seld {
        if ``s'' <= 0 | ``s'' > 1 {
            display as error "`s'() must be in (0, 1]"
            exit 198
        }
    }

    * Defaults
    if "`measure'" == "" local measure "OR"
    local measure = strupper("`measure'")
    if !inlist("`measure'", "OR", "RR") {
        display as error "measure() must be OR or RR"
        exit 198
    }

    if `seed' != -1 {
        set seed `seed'
    }

    * Compute observed measure
    local obs_or = (`a' * `d') / (`b' * `c')
    local N1 = `a' + `c'
    local N0 = `b' + `d'
    if "`measure'" == "RR" {
        local obs_rr = (`a' / `N1') / (`b' / `N0')
    }

    * =====================================================================
    * SIMPLE BIAS ANALYSIS
    * =====================================================================
    if `reps' == 0 {
        * Correct by dividing each cell by its selection probability
        local a_corr = `a' / `sela'
        local b_corr = `b' / `selb'
        local c_corr = `c' / `selc'
        local d_corr = `d' / `seld'

        * Corrected measures
        local corr_or = (`a_corr' * `d_corr') / (`b_corr' * `c_corr')
        if "`measure'" == "RR" {
            local N1_corr = `a_corr' + `c_corr'
            local N0_corr = `b_corr' + `d_corr'
            local corr_rr = (`a_corr' / `N1_corr') / (`b_corr' / `N0_corr')
        }

        * Selection bias factor
        local sbf = (`sela' * `seld') / (`selb' * `selc')

        * Display
        display as text ""
        display as text "{bf:Quantitative Bias Analysis: Selection Bias}"
        display as text "{hline 60}"
        display as text ""

        display as text "{bf:Observed 2x2 table}"
        display as text "              Exposed   Unexposed"
        display as text "  Cases    " as result %10.1f `a' as result %10.1f `b'
        display as text "  Non-cases" as result %10.1f `c' as result %10.1f `d'
        display as text ""

        display as text "{bf:Selection probabilities}"
        display as text "              Exposed   Unexposed"
        display as text "  Cases    " as result %10.4f `sela' as result %10.4f `selb'
        display as text "  Non-cases" as result %10.4f `selc' as result %10.4f `seld'
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
            local ratio = `corr_or' / `obs_or'
        }
        else {
            display as text "  Observed RR:  " as result %9.4f `obs_rr'
            display as text "  Corrected RR: " as result %9.4f `corr_rr'
            local ratio = `corr_rr' / `obs_rr'
        }
        display as text "  Selection bias factor (OR scale): " as result %6.4f `sbf'
        display as text "  Ratio (corrected/observed): " as result %6.4f `ratio'
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
        return scalar bias_factor = `sbf'
        return scalar ratio = `ratio'
        return scalar sela = `sela'
        return scalar selb = `selb'
        return scalar selc = `selc'
        return scalar seld = `seld'
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

        * Defaults
        if "`dist_sela'" == "" local dist_sela "constant `sela'"
        if "`dist_selb'" == "" local dist_selb "constant `selb'"
        if "`dist_selc'" == "" local dist_selc "constant `selc'"
        if "`dist_seld'" == "" local dist_seld "constant `seld'"

        preserve
        quietly {
            clear
            set obs `reps'

            _qba_draw_one, dist("`dist_sela'") gen(_sa) n(`reps')
            _qba_draw_one, dist("`dist_selb'") gen(_sb) n(`reps')
            _qba_draw_one, dist("`dist_selc'") gen(_sc) n(`reps')
            _qba_draw_one, dist("`dist_seld'") gen(_sd) n(`reps')

            gen double _a_corr = `a' / _sa
            gen double _b_corr = `b' / _sb
            gen double _c_corr = `c' / _sc
            gen double _d_corr = `d' / _sd

            if "`measure'" == "OR" {
                gen double _result = (_a_corr * _d_corr) / (_b_corr * _c_corr)
            }
            else {
                gen double _N1c = _a_corr + _c_corr
                gen double _N0c = _b_corr + _d_corr
                gen double _result = (_a_corr / _N1c) / (_b_corr / _N0c)
            }

            replace _result = . if _result <= 0 | _result >= .

            count if _result < .
            local n_valid = r(N)

            if `n_valid' == 0 {
                display as error "all Monte Carlo replicates produced invalid results"
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
                keep _sa _sb _sc _sd _a_corr _b_corr _c_corr _d_corr _result
                rename _result corrected_`=strlower("`measure'")'
                rename _a_corr a_corr
                rename _b_corr b_corr
                rename _c_corr c_corr
                rename _d_corr d_corr
                rename _sa sel_a
                rename _sb sel_b
                rename _sc sel_c
                rename _sd sel_d
                save `saving'
            }
        }
        restore

        * Display
        display as text ""
        display as text "{bf:Probabilistic Bias Analysis: Selection Bias}"
        display as text "{hline 60}"
        display as text ""
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
        return local measure "`measure'"
        return local method "probabilistic"
    }
end
