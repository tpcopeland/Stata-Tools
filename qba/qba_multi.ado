*! qba_multi Version 1.0.0  2026/03/13
*! Multi-bias analysis combining misclassification, selection, and confounding
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass

/*
Chains misclassification -> selection -> confounding corrections in a
single Monte Carlo simulation framework.

Only biases with parameters specified are corrected. At least two bias
types should be specified (otherwise use the individual commands).

Default order follows Lash/Fox/Fink (2021) recommendation:
  misclassification -> selection -> confounding

References:
  Lash TL, Fox MP, Fink AK. Applying Quantitative Bias Analysis to
    Epidemiologic Data. 2nd ed. Springer; 2021. Chapter 12.
*/

capture program drop qba_multi
program define qba_multi, rclass
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

    syntax , A(real) B(real) C(real) D(real) Reps(integer) ///
        [MEAsure(string) ///
         SEca(real -1) SPca(real -1) SEcb(real -1) SPcb(real -1) ///
         MCtype(string) ///
         dist_se(string) dist_sp(string) ///
         dist_se1(string) dist_sp1(string) ///
         SELa(real -1) SELb(real -1) SELc(real -1) SELd(real -1) ///
         dist_sela(string) dist_selb(string) ///
         dist_selc(string) dist_seld(string) ///
         P1(real -1) P0(real -1) RRcd(real -1) RRud(real -1) ///
         dist_p1(string) dist_p0(string) dist_rr(string) ///
         ORder(string) ///
         Seed(integer -1) Level(cilevel) ///
         SAving(string)]

    * Validate
    if `a' < 0 | `b' < 0 | `c' < 0 | `d' < 0 {
        display as error "cell counts must be non-negative"
        exit 198
    }
    if `reps' < 100 {
        display as error "reps() should be at least 100"
        exit 198
    }

    if "`measure'" == "" local measure "OR"
    local measure = strupper("`measure'")
    if !inlist("`measure'", "OR", "RR") {
        display as error "measure() must be OR or RR"
        exit 198
    }

    if "`mctype'" == "" local mctype "exposure"
    if !inlist("`mctype'", "exposure", "outcome") {
        display as error "mctype() must be exposure or outcome"
        exit 198
    }

    * Determine which biases are active
    local do_misclass = 0
    local do_selection = 0
    local do_confound = 0

    if `seca' != -1 & `spca' != -1 {
        local do_misclass = 1
    }
    if `sela' != -1 & `selb' != -1 & `selc' != -1 & `seld' != -1 {
        local do_selection = 1
    }
    if `p1' != -1 & `p0' != -1 & (`rrcd' != -1 | `rrud' != -1) {
        local do_confound = 1
    }

    local n_biases = `do_misclass' + `do_selection' + `do_confound'
    if `n_biases' == 0 {
        display as error "no bias parameters specified"
        exit 198
    }

    * Determine correction order
    if "`order'" == "" local order "misclass selection confound"
    local order_clean ""
    foreach w of local order {
        local w = strlower("`w'")
        if !inlist("`w'", "misclass", "selection", "confound") {
            display as error "order() must contain: misclass, selection, confound"
            exit 198
        }
        local order_clean "`order_clean' `w'"
    }
    local order = strtrim("`order_clean'")

    * Differential misclassification
    local mc_differential = 0
    if `do_misclass' & (`secb' != -1 | `spcb' != -1) {
        local mc_differential = 1
        if `secb' == -1 local secb = `seca'
        if `spcb' == -1 local spcb = `spca'
    }

    * Confounding RR choice
    if `do_confound' {
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

    * Compute observed measure
    local obs_or = (`a' * `d') / (`b' * `c')
    local N1 = `a' + `c'
    local N0 = `b' + `d'
    local M1 = `a' + `b'
    local M0 = `c' + `d'
    if "`measure'" == "RR" {
        local obs_rr = (`a' / `N1') / (`b' / `N0')
    }

    * =====================================================================
    * MONTE CARLO SIMULATION
    * =====================================================================
    preserve
    quietly {
        clear
        set obs `reps'

        * Draw all parameters
        if `do_misclass' {
            if "`dist_se'" == "" local dist_se "constant `seca'"
            if "`dist_sp'" == "" local dist_sp "constant `spca'"
            _qba_draw_one, dist("`dist_se'") gen(_mc_se0) n(`reps')
            _qba_draw_one, dist("`dist_sp'") gen(_mc_sp0) n(`reps')
            if `mc_differential' {
                if "`dist_se1'" == "" local dist_se1 "constant `secb'"
                if "`dist_sp1'" == "" local dist_sp1 "constant `spcb'"
                _qba_draw_one, dist("`dist_se1'") gen(_mc_se1) n(`reps')
                _qba_draw_one, dist("`dist_sp1'") gen(_mc_sp1) n(`reps')
            }
        }

        if `do_selection' {
            if "`dist_sela'" == "" local dist_sela "constant `sela'"
            if "`dist_selb'" == "" local dist_selb "constant `selb'"
            if "`dist_selc'" == "" local dist_selc "constant `selc'"
            if "`dist_seld'" == "" local dist_seld "constant `seld'"
            _qba_draw_one, dist("`dist_sela'") gen(_sel_a) n(`reps')
            _qba_draw_one, dist("`dist_selb'") gen(_sel_b) n(`reps')
            _qba_draw_one, dist("`dist_selc'") gen(_sel_c) n(`reps')
            _qba_draw_one, dist("`dist_seld'") gen(_sel_d) n(`reps')
        }

        if `do_confound' {
            if "`dist_p1'" == "" local dist_p1 "constant `p1'"
            if "`dist_p0'" == "" local dist_p0 "constant `p0'"
            if "`dist_rr'" == "" local dist_rr "constant `rr_val'"
            _qba_draw_one, dist("`dist_p1'") gen(_cf_p1) n(`reps')
            _qba_draw_one, dist("`dist_p0'") gen(_cf_p0) n(`reps')
            _qba_draw_one, dist("`dist_rr'") gen(_cf_rr) n(`reps')
        }

        * Initialize working table cells
        gen double _wa = `a'
        gen double _wb = `b'
        gen double _wc = `c'
        gen double _wd = `d'

        * Apply corrections in specified order
        foreach step of local order {
            if "`step'" == "misclass" & `do_misclass' {
                * Compute row/column totals from current working table
                gen double _wM1 = _wa + _wb
                gen double _wM0 = _wc + _wd
                gen double _wN1 = _wa + _wc
                gen double _wN0 = _wb + _wd

                if "`mctype'" == "exposure" {
                    if `mc_differential' == 0 {
                        replace _wa = (_wa - (1 - _mc_sp0) * _wM1) / (_mc_se0 + _mc_sp0 - 1)
                        replace _wb = _wM1 - _wa
                        replace _wc = (_wc - (1 - _mc_sp0) * _wM0) / (_mc_se0 + _mc_sp0 - 1)
                        replace _wd = _wM0 - _wc
                    }
                    else {
                        replace _wa = (_wa - (1 - _mc_sp0) * _wM1) / (_mc_se0 + _mc_sp0 - 1)
                        replace _wb = _wM1 - _wa
                        replace _wc = (_wc - (1 - _mc_sp1) * _wM0) / (_mc_se1 + _mc_sp1 - 1)
                        replace _wd = _wM0 - _wc
                    }
                }
                else {
                    if `mc_differential' == 0 {
                        replace _wa = (_wa - (1 - _mc_sp0) * _wN1) / (_mc_se0 + _mc_sp0 - 1)
                        replace _wc = _wN1 - _wa
                        replace _wb = (_wb - (1 - _mc_sp0) * _wN0) / (_mc_se0 + _mc_sp0 - 1)
                        replace _wd = _wN0 - _wb
                    }
                    else {
                        replace _wa = (_wa - (1 - _mc_sp0) * _wN1) / (_mc_se0 + _mc_sp0 - 1)
                        replace _wc = _wN1 - _wa
                        replace _wb = (_wb - (1 - _mc_sp1) * _wN0) / (_mc_se1 + _mc_sp1 - 1)
                        replace _wd = _wN0 - _wb
                    }
                }
                drop _wM1 _wM0 _wN1 _wN0
            }

            if "`step'" == "selection" & `do_selection' {
                replace _wa = _wa / _sel_a
                replace _wb = _wb / _sel_b
                replace _wc = _wc / _sel_c
                replace _wd = _wd / _sel_d
            }

            if "`step'" == "confound" & `do_confound' {
                * Compute bias factor
                if `use_rrud' {
                    gen double _bf = (_cf_p1 * _cf_rr + (1 - _cf_p1)) / ///
                        (_cf_p0 * _cf_rr + (1 - _cf_p0))
                }
                else {
                    gen double _bf = (_cf_p1 * (_cf_rr - 1) + 1) / ///
                        (_cf_p0 * (_cf_rr - 1) + 1)
                }
                if "`measure'" == "OR" {
                    * OR_corr = OR / bf => dividing cell a by bf achieves this
                    replace _wa = _wa / _bf
                }
                else {
                    * RR_corr = RR / bf. Dividing only cell a doesn't yield RR/bf.
                    * Instead, scale a to achieve the target RR within each column:
                    * RR = (a/(a+c)) / (b/(b+d)), target = RR/bf
                    * Scale a so that a_new/(a_new+c) = (a/(a+c)) / bf
                    * => a_new = c * (a/(a+c)) / (bf - (a/(a+c))) ... complex.
                    * Simpler: scale a and b by 1/bf proportionally within columns.
                    * a_new/(a_new+c) = (a/bf)/((a/bf)+c), b_new/(b_new+d) = (b/bf)/((b/bf)+d)
                    * Then RR_new = [a/bf / (a/bf + c)] / [b/bf / (b/bf + d)]
                    * This reduces bias in both exposure groups equally.
                    replace _wa = _wa / _bf
                    replace _wb = _wb / _bf
                }
                drop _bf
            }
        }

        * Compute final corrected measure
        if "`measure'" == "OR" {
            gen double _result = (_wa * _wd) / (_wb * _wc)
        }
        else {
            gen double _fN1 = _wa + _wc
            gen double _fN0 = _wb + _wd
            gen double _result = (_wa / _fN1) / (_wb / _fN0)
        }

        * Drop invalid
        replace _result = . if _wa < 0 | _wb < 0 | _wc < 0 | _wd < 0
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
            keep _wa _wb _wc _wd _result
            rename _wa a_corr
            rename _wb b_corr
            rename _wc c_corr
            rename _wd d_corr
            rename _result corrected_`=strlower("`measure'")'
            save `saving'
        }
    }
    restore

    * Display
    display as text ""
    display as text "{bf:Multi-Bias Analysis}"
    display as text "{hline 60}"
    display as text ""
    display as text "Replications: " as result %8.0fc `reps' ///
        as text "  (valid: " as result %8.0fc `n_valid' as text ")"
    display as text ""

    display as text "{bf:Bias corrections applied}"
    display as text "  Order: `order'"
    if `do_misclass' {
        display as text "  [x] Misclassification (`mctype')"
    }
    if `do_selection' {
        display as text "  [x] Selection bias"
    }
    if `do_confound' {
        display as text "  [x] Unmeasured confounding"
    }
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
    return scalar n_biases = `n_biases'
    return local measure "`measure'"
    return local method "multi-bias"
    return local order "`order'"
end
