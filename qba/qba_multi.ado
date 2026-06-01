*! qba_multi Version 1.0.0  2026/06/02
*! Multi-bias analysis combining misclassification, selection, and confounding
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
Chains misclassification -> selection -> confounding corrections in a
single Monte Carlo simulation framework.

Only biases with parameters specified are corrected. At least one bias
type should be specified.

Default order follows Lash/Fox/Fink (2021) recommendation:
  misclassification -> selection -> confounding

Confounding is a measure-level correction (divides the final measure
by the bias factor) and is always applied after cell-level corrections
(misclassification, selection), regardless of position in order().

References:
  Lash TL, Fox MP, Fink AK. Applying Quantitative Bias Analysis to
    Epidemiologic Data. 2nd ed. Springer; 2021. Chapter 12.
*/

capture program drop qba_multi
program define qba_multi, rclass
    version 16.0
    local _saved_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    _qba_require_distributions

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
	         SAving(string asis)]

	    if missing(`reps') {
	        display as error "reps() must be a nonmissing integer"
	        exit 198
	    }
	    if `seed' != -1 & missing(`seed') {
	        display as error "seed() must be a nonmissing integer"
	        exit 198
	    }

    local savefile ""
    local save_replace ""
    if `"`saving'"' != "" {
        _qba_parse_saving, saving(`saving')
        local savefile `"`r(filename)'"'
        local save_replace "`r(replace)'"
    }

	    * Validate
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
	    local mctype = strlower("`mctype'")
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

    if `rrcd' != -1 & `rrud' != -1 {
        display as error "specify rrcd() or rrud(), not both"
        exit 198
    }

    * Reject incomplete bias parameter pairs
    if (`seca' != -1 & `spca' == -1) | (`seca' == -1 & `spca' != -1) {
        display as error "misclassification requires both seca() and spca()"
        exit 198
    }
	    if (`secb' != -1 | `spcb' != -1) & !`do_misclass' {
	        display as error "secb()/spcb() require seca() and spca()"
	        exit 198
	    }
	    if !`do_misclass' & (`"`dist_se'"' != "" | `"`dist_sp'"' != "") {
	        display as error "dist_se()/dist_sp() require seca() and spca()"
	        exit 198
	    }
	    if ("`dist_se1'" != "" | "`dist_sp1'" != "") & !(`secb' != -1 | `spcb' != -1) {
	        display as error "dist_se1()/dist_sp1() requires secb() or spcb()"
	        exit 198
    }
	    if (`sela' != -1 | `selb' != -1 | `selc' != -1 | `seld' != -1) & ///
	       !(`sela' != -1 & `selb' != -1 & `selc' != -1 & `seld' != -1) {
	        display as error "selection bias requires all of sela() selb() selc() seld()"
	        exit 198
	    }
	    if !`do_selection' & (`"`dist_sela'"' != "" | `"`dist_selb'"' != "" | ///
	        `"`dist_selc'"' != "" | `"`dist_seld'"' != "") {
	        display as error "dist_sela()/dist_selb()/dist_selc()/dist_seld() require selection probabilities"
	        exit 198
	    }
	    if (`p1' != -1 | `p0' != -1 | `rrcd' != -1 | `rrud' != -1) & !`do_confound' {
	        display as error "confounding requires p1(), p0(), and rrcd() or rrud()"
	        exit 198
	    }
	    if !`do_confound' & (`"`dist_p1'"' != "" | `"`dist_p0'"' != "" | `"`dist_rr'"' != "") {
	        display as error "dist_p1()/dist_p0()/dist_rr() require confounding parameters"
	        exit 198
	    }

    local n_biases = `do_misclass' + `do_selection' + `do_confound'
    if `n_biases' == 0 {
        display as error "no bias parameters specified"
        exit 198
    }

    * Validate parameters for active biases
    if `do_misclass' {
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
    }
	    if `do_selection' {
	        foreach s in sela selb selc seld {
	            if missing(``s'') | ``s'' <= 0 | ``s'' > 1 {
	                display as error "`s'() must be in (0, 1]"
	                exit 198
            }
        }
    }
    if `do_confound' {
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
    }

    * Determine correction order for cell-level biases
    * Confounding is always applied last at measure level
    if "`order'" == "" {
        * Default order: misclass then selection (only active biases)
        local order ""
        if `do_misclass' local order "misclass"
        if `do_selection' local order "`order' selection"
        local order = strtrim("`order'")
    }
    else {
        local order_clean ""
        foreach w of local order {
            local w = strlower("`w'")
            if "`w'" == "confound" {
                display as error "order() controls cell-level bias sequence only;"
                display as error "confounding is always applied last at measure level"
                exit 198
            }
            if !inlist("`w'", "misclass", "selection") {
                display as error "order() entries must be: misclass, selection"
                exit 198
            }
            if strpos("`order_clean'", "`w'") > 0 {
                display as error "order() contains duplicate entry: `w'"
                exit 198
            }
            local order_clean "`order_clean' `w'"
        }
        local order = strtrim("`order_clean'")
        * Verify all active cell-level biases appear
        if `do_misclass' & strpos("`order'", "misclass") == 0 {
            display as error "misclassification is active; it must appear in order()"
            exit 198
        }
        if `do_selection' & strpos("`order'", "selection") == 0 {
            display as error "selection bias is active; it must appear in order()"
            exit 198
        }
        if !`do_misclass' & strpos(" `order' ", " misclass ") > 0 {
            display as error "misclassification is not active; remove misclass from order()"
            exit 198
        }
        if !`do_selection' & strpos(" `order' ", " selection ") > 0 {
            display as error "selection bias is not active; remove selection from order()"
            exit 198
        }
    }

    * Differential misclassification
    local mc_differential = 0
    if `do_misclass' & (`secb' != -1 | `spcb' != -1) {
        local mc_differential = 1
        if `secb' == -1 local secb = `seca'
        if `spcb' == -1 local spcb = `spca'
    }

    if `mc_differential' {
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

    * Compute observed measure (guard division by zero)
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

    * MONTE CARLO SIMULATION
    preserve
    quietly {
        clear
        set obs `reps'

        gen byte _draw_invalid = 0

        * Draw all parameters
        if `do_misclass' {
            if "`dist_se'" == "" local dist_se "constant `seca'"
            if "`dist_sp'" == "" local dist_sp "constant `spca'"
            _qba_draw_checked, dist(`"`dist_se'"') gen(_mc_se0) n(`reps') ///
                invalid(_draw_invalid) lower(0) upper(1) loweropen
            _qba_draw_checked, dist(`"`dist_sp'"') gen(_mc_sp0) n(`reps') ///
                invalid(_draw_invalid) lower(0) upper(1) loweropen
            _qba_flag_misclass_pair, se(_mc_se0) sp(_mc_sp0) invalid(_draw_invalid)
            if `mc_differential' {
                if "`dist_se1'" == "" local dist_se1 "constant `secb'"
                if "`dist_sp1'" == "" local dist_sp1 "constant `spcb'"
                _qba_draw_checked, dist(`"`dist_se1'"') gen(_mc_se1) n(`reps') ///
                    invalid(_draw_invalid) lower(0) upper(1) loweropen
                _qba_draw_checked, dist(`"`dist_sp1'"') gen(_mc_sp1) n(`reps') ///
                    invalid(_draw_invalid) lower(0) upper(1) loweropen
                _qba_flag_misclass_pair, se(_mc_se1) sp(_mc_sp1) invalid(_draw_invalid)
            }
        }

        if `do_selection' {
            if "`dist_sela'" == "" local dist_sela "constant `sela'"
            if "`dist_selb'" == "" local dist_selb "constant `selb'"
            if "`dist_selc'" == "" local dist_selc "constant `selc'"
            if "`dist_seld'" == "" local dist_seld "constant `seld'"
            _qba_draw_checked, dist(`"`dist_sela'"') gen(_sel_a) n(`reps') ///
                invalid(_draw_invalid) lower(0) upper(1) loweropen
            _qba_draw_checked, dist(`"`dist_selb'"') gen(_sel_b) n(`reps') ///
                invalid(_draw_invalid) lower(0) upper(1) loweropen
            _qba_draw_checked, dist(`"`dist_selc'"') gen(_sel_c) n(`reps') ///
                invalid(_draw_invalid) lower(0) upper(1) loweropen
            _qba_draw_checked, dist(`"`dist_seld'"') gen(_sel_d) n(`reps') ///
                invalid(_draw_invalid) lower(0) upper(1) loweropen
        }

        if `do_confound' {
            if "`dist_p1'" == "" local dist_p1 "constant `p1'"
            if "`dist_p0'" == "" local dist_p0 "constant `p0'"
            if "`dist_rr'" == "" local dist_rr "constant `rr_val'"
            _qba_draw_checked, dist(`"`dist_p1'"') gen(_cf_p1) n(`reps') ///
                invalid(_draw_invalid) lower(0) upper(1)
            _qba_draw_checked, dist(`"`dist_p0'"') gen(_cf_p0) n(`reps') ///
                invalid(_draw_invalid) lower(0) upper(1)
            _qba_draw_checked, dist(`"`dist_rr'"') gen(_cf_rr) n(`reps') ///
                invalid(_draw_invalid) lower(0) loweropen
        }

        count if _draw_invalid == 1
        local n_draw_invalid = r(N)

        * Initialize working table cells
        gen double _wa = `a'
        gen double _wb = `b'
        gen double _wc = `c'
        gen double _wd = `d'

        * Apply cell-level corrections in specified order
        * (confounding is measure-level, applied after computing the measure)
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
        }

        * Compute final corrected measure from cells
        if "`measure'" == "OR" {
            gen double _result = (_wa * _wd) / (_wb * _wc)
        }
        else {
            gen double _fN1 = _wa + _wc
            gen double _fN0 = _wb + _wd
            gen double _result = (_wa / _fN1) / (_wb / _fN0)
        }

        * Apply confounding correction at measure level (divide by bias factor)
        if `do_confound' {
            if `use_rrud' {
                gen double _bf = (_cf_p1 * _cf_rr + (1 - _cf_p1)) / ///
                    (_cf_p0 * _cf_rr + (1 - _cf_p0))
            }
            else {
                gen double _bf = (_cf_p1 * (_cf_rr - 1) + 1) / ///
                    (_cf_p0 * (_cf_rr - 1) + 1)
            }
            replace _result = _result / _bf
        }

        * Drop invalid
        replace _result = . if _draw_invalid == 1
        replace _result = . if _wa < 0 | _wb < 0 | _wc < 0 | _wd < 0
        replace _result = . if _result <= 0 | _result >= .

        count if _result < .
        local n_valid = r(N)
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

        if `"`saving'"' != "" {
            keep _wa _wb _wc _wd _result
            rename _wa a_corr
            rename _wb b_corr
            rename _wc c_corr
	            rename _wd d_corr
	            rename _result corrected_`=strlower("`measure'")'
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
    display as text "{bf:Multi-Bias Analysis}"
    display as text ""
    display as text "Replications: " as result %8.0fc `reps' ///
        as text "  (valid: " as result %8.0fc `n_valid' as text ")"
    display as text ""

    display as text "{bf:Bias corrections applied}"
    display as text "  Cell-level order: `order'"
    if `do_misclass' {
        display as text "  [x] Misclassification (`mctype')"
    }
    if `do_selection' {
        display as text "  [x] Selection bias"
    }
    if `do_confound' {
        display as text "  [x] Unmeasured confounding (measure-level, applied last)"
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
    return scalar n_draw_invalid = `n_draw_invalid'
	    return scalar n_biases = `n_biases'
	    return local measure "`measure'"
	    return local method "multi-bias"
	    return local order "`order'"
	    if `save_rc' {
	        display as error "saving() failed; analytical results are posted in r()"
	        exit `save_rc'
	    }

	    }
    local rc = _rc
    set varabbrev `_saved_varabbrev'
    if `rc' exit `rc'
end
