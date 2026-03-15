*! aft_rpsftm Version 1.1.0  2026/03/15
*! Rank-Preserving Structural Failure Time Model (g-estimation)
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: eclass (returns results in e())

/*
Basic syntax:
  aft_rpsftm [if] [in] , RANDomization(varname) TREATment(varname) [options]

Description:
  Estimates the causal acceleration factor (psi) under treatment switching
  using the Rank-Preserving Structural Failure Time Model. Finds psi by
  grid search where the log-rank test of counterfactual untreated times
  by randomization arm is zero.

See help aft_rpsftm for complete documentation
*/

program define aft_rpsftm, eclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax [if] [in] , RANDomization(varname) TREATment(varname) ///
        [TREATTime(varname) ///
         GRIDrange(numlist min=2 max=2) GRIDpoints(integer 200) ///
         TESTtype(string) RECensor ///
         BOOTstrap REPS(integer 1000) SEED(integer -1) ///
         Level(cilevel) PLot SAVing(string) SCHeme(passthru) noLOG]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================
    _aft_check_stset

    marksample touse
    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    * Count failures
    quietly count if `touse' & _d == 1
    local n_events = r(N)
    if `n_events' == 0 {
        display as error "no events in sample"
        exit 2000
    }

    * =========================================================================
    * VALIDATE INPUTS
    * =========================================================================

    * Randomization must be binary (0/1)
    quietly tabulate `randomization' if `touse'
    if r(r) != 2 {
        display as error "randomization() must be a binary (0/1) variable"
        exit 198
    }
    quietly summarize `randomization' if `touse', meanonly
    if r(min) != 0 | r(max) != 1 {
        display as error "randomization() must be coded 0/1"
        exit 198
    }

    * Treatment must be binary or proportion
    quietly summarize `treatment' if `touse', meanonly
    if r(min) < 0 | r(max) > 1 {
        display as error "treatment() must be in [0, 1] (binary or proportion)"
        exit 198
    }

    * Grid range
    if "`gridrange'" == "" {
        local grid_lo = -2
        local grid_hi = 2
    }
    else {
        local grid_lo : word 1 of `gridrange'
        local grid_hi : word 2 of `gridrange'
        if `grid_lo' >= `grid_hi' {
            display as error "gridrange() must specify lo < hi"
            exit 198
        }
    }

    * Test type
    if "`testtype'" == "" local testtype "logrank"
    local testtype = lower("`testtype'")
    if !inlist("`testtype'", "logrank", "wilcoxon") {
        display as error "testtype() must be logrank or wilcoxon"
        exit 198
    }

    * Level
    if "`level'" == "" local level = c(level)
    local z_alpha = invnormal(1 - (100 - `level') / 200)

    * Seed
    if `seed' >= 0 {
        set seed `seed'
    }

    * Count switchers
    quietly count if `touse' & `randomization' == 0 & `treatment' > 0
    local n_switched = r(N)

    * Administrative censoring time (max follow-up) for re-censoring
    quietly summarize _t if `touse', meanonly
    local admin_censor = r(max)

    * =========================================================================
    * COMPUTE TREATMENT EXPOSURE
    * =========================================================================

    tempvar exposure
    if "`treattime'" != "" {
        * Use explicit treatment time variable
        * Normalize to proportion of total follow-up
        quietly gen double `exposure' = `treattime' / _t if `touse'
        quietly replace `exposure' = min(`exposure', 1) if `touse'
        quietly replace `exposure' = max(`exposure', 0) if `touse'
    }
    else {
        * Binary treatment: exposure = treatment indicator
        quietly gen double `exposure' = `treatment' if `touse'
    }

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================
    _aft_display_header "aft_rpsftm" "Structural AFT: RPSFTM G-Estimation"

    display as text "Observations:     " as result %10.0fc `N'
    display as text "Events:           " as result %10.0fc `n_events'
    display as text "Switchers:        " as result %10.0fc `n_switched'
    display as text "Grid range:       " as result "[`grid_lo', `grid_hi']"
    display as text "Grid points:      " as result "`gridpoints'"
    display as text "Test:             " as result "`testtype'"
    if "`recensor'" != "" {
        display as text "Re-censoring:     " as result "yes"
    }
    display as text ""

    * =========================================================================
    * GRID SEARCH
    * =========================================================================

    if "`log'" != "nolog" {
        display as text "Grid search " _continue
    }

    local grid_step = (`grid_hi' - `grid_lo') / (`gridpoints' - 1)

    * Store grid results
    tempname grid_mat
    matrix `grid_mat' = J(`gridpoints', 2, .)

    * Save current stset settings
    local st_t = "`:char _dta[st_bt]'"
    local st_d = "`:char _dta[st_bd]'"
    local st_t0 = "`:char _dta[st_bt0]'"
    local st_id = "`:char _dta[st_id]'"

    forvalues g = 1/`gridpoints' {
        local psi_g = `grid_lo' + (`g' - 1) * `grid_step'
        matrix `grid_mat'[`g', 1] = `psi_g'

        * Compute counterfactual untreated times
        preserve

        tempvar utime uevent
        quietly gen double `utime' = _t * exp(-`psi_g' * `exposure') if `touse'
        quietly replace `utime' = max(`utime', 0.0001) if `touse'
        quietly gen byte `uevent' = _d if `touse'

        * Apply re-censoring if requested
        * Re-censoring prevents administrative censoring from becoming
        * informative under the counterfactual. Use the max follow-up
        * time as the admin censoring bound for all subjects (conservative).
        * C*_i = admin_censor * exp(-psi * d_i)
        if "`recensor'" != "" {
            tempvar cstar
            quietly gen double `cstar' = `admin_censor' * exp(-`psi_g' * `exposure') if `touse'
            quietly replace `uevent' = 0 if `utime' > `cstar' & `touse'
            quietly replace `utime' = min(`utime', `cstar') if `touse'
        }

        * Re-stset on counterfactual times
        quietly stset `utime' if `touse', failure(`uevent')

        * Run test
        if "`testtype'" == "logrank" {
            capture quietly sts test `randomization', logrank
        }
        else {
            capture quietly sts test `randomization', wilcoxon
        }

        if _rc == 0 {
            * Extract Z statistic from chi2 (chi2 = Z^2 for 1 df)
            * Sign: positive if experimental arm has better survival
            local chi2_g = r(chi2)
            local z_g = sqrt(`chi2_g')

            * Determine sign: compare observed vs expected in experimental arm
            * The sts test stores observed and expected by group
            * Positive Z means experimental arm has more events than expected
            * (i.e., counterfactual survival is WORSE for experimental arm)
            * We want the sign convention where positive psi = treatment beneficial

            * Use the sign from the test: if psi too low, Z > 0
            * (treatment not fully adjusted); if psi too high, Z < 0
            * Standard RPSFTM: Z decreases as psi increases
            * So we negate: Z_signed = -Z for "experimental better" convention

            * Actually, use a consistent approach: compute KM median difference
            * or use the raw Z direction from sts test
            * sts test logrank: chi2 statistic, need direction

            * Get direction from comparing observed survival
            quietly sts generate _aft_km = s if `touse', by(`randomization')
            quietly summarize _aft_km if `randomization' == 1 & `touse', meanonly
            local mean_exp = r(mean)
            quietly summarize _aft_km if `randomization' == 0 & `touse', meanonly
            local mean_ctrl = r(mean)
            quietly drop _aft_km

            * If experimental mean survival > control: Z should be positive
            * (experimental is doing better even after subtracting psi effect)
            * meaning psi is too low
            if `mean_exp' >= `mean_ctrl' {
                local z_g = `z_g'
            }
            else {
                local z_g = -`z_g'
            }

            matrix `grid_mat'[`g', 2] = `z_g'
        }
        else {
            matrix `grid_mat'[`g', 2] = .
        }

        restore

        * Progress dots
        if "`log'" != "nolog" {
            if mod(`g', 20) == 0 {
                display as text "." _continue
            }
        }
    }

    if "`log'" != "nolog" {
        display as text " done"
    }

    * =========================================================================
    * FIND PSI BY INTERPOLATION
    * =========================================================================

    * Find where Z crosses zero
    local psi_hat = .
    local found_zero = 0

    forvalues g = 1/`=`gridpoints'-1' {
        local z1 = `grid_mat'[`g', 2]
        local z2 = `grid_mat'[`=`g'+1', 2]
        local p1 = `grid_mat'[`g', 1]
        local p2 = `grid_mat'[`=`g'+1', 1]

        if !missing(`z1') & !missing(`z2') {
            if (`z1' >= 0 & `z2' <= 0) | (`z1' <= 0 & `z2' >= 0) {
                * Linear interpolation
                local psi_hat = `p1' + (`p2' - `p1') * `z1' / (`z1' - `z2')
                local found_zero = 1
                continue, break
            }
        }
    }

    if `found_zero' == 0 {
        display as error ""
        display as error "Z(psi) did not cross zero in [`grid_lo', `grid_hi']"
        display as error ""
        display as error "Possible solutions:"
        display as error "  1. Widen {bf:gridrange()}"
        display as error "  2. Increase {bf:gridpoints()}"
        display as error "  3. Check that treatment switching actually occurred"
        display as text ""

        * Still store grid and return what we have
        char _dta[_aft_rpsftm] "0"
        ereturn clear
        ereturn post, obs(`N')
        ereturn scalar psi = .
        ereturn scalar af = .
        ereturn scalar N = `N'
        ereturn scalar n_events = `n_events'
        ereturn scalar n_switched = `n_switched'
        ereturn local cmd "aft_rpsftm"
        ereturn matrix grid = `grid_mat'

        set varabbrev `_vaset'
        exit 498
    }

    * Find CI bounds (where Z crosses +/- z_alpha)
    local ci_lo = .
    local ci_hi = .

    forvalues g = 1/`=`gridpoints'-1' {
        local z1 = `grid_mat'[`g', 2]
        local z2 = `grid_mat'[`=`g'+1', 2]
        local p1 = `grid_mat'[`g', 1]
        local p2 = `grid_mat'[`=`g'+1', 1]

        if !missing(`z1') & !missing(`z2') {
            * Lower CI: where Z crosses +z_alpha
            if missing(`ci_lo') {
                if (`z1' >= `z_alpha' & `z2' <= `z_alpha') | ///
                   (`z1' <= `z_alpha' & `z2' >= `z_alpha') {
                    local ci_lo = `p1' + (`p2' - `p1') * (`z1' - `z_alpha') / (`z1' - `z2')
                }
            }

            * Upper CI: where Z crosses -z_alpha
            if missing(`ci_hi') {
                if (`z1' >= -`z_alpha' & `z2' <= -`z_alpha') | ///
                   (`z1' <= -`z_alpha' & `z2' >= -`z_alpha') {
                    local ci_hi = `p1' + (`p2' - `p1') * (`z1' + `z_alpha') / (`z1' - `z2')
                }
            }
        }
    }

    * Acceleration factor = exp(psi)
    local af = exp(`psi_hat')
    local af_lo = .
    local af_hi = .
    if !missing(`ci_lo') local af_lo = exp(`ci_lo')
    if !missing(`ci_hi') local af_hi = exp(`ci_hi')

    * Variance from CI width (if both bounds found)
    local se_psi = .
    if !missing(`ci_lo') & !missing(`ci_hi') {
        local se_psi = (`ci_hi' - `ci_lo') / (2 * `z_alpha')
    }

    * =========================================================================
    * BOOTSTRAP (OPTIONAL)
    * =========================================================================

    if "`bootstrap'" != "" {
        display as text ""
        display as text "Bootstrap (" as result "`reps'" as text " replications) " _continue

        tempname boot_psi
        matrix `boot_psi' = J(`reps', 1, .)

        * Get subject IDs for resampling
        tempvar subj_id
        quietly gen long `subj_id' = _n if `touse'

        forvalues rep = 1/`reps' {
            preserve

            * Resample with replacement, stratified by randomization arm
            quietly bsample if `touse', strata(`randomization')

            * Mini grid search on bootstrapped data
            local best_z = .
            local best_psi = .
            local prev_z = .

            forvalues g = 1/`gridpoints' {
                local psi_g = `grid_lo' + (`g' - 1) * `grid_step'

                tempvar utime_b uevent_b
                quietly gen double `utime_b' = _t * exp(-`psi_g' * `exposure')
                quietly replace `utime_b' = max(`utime_b', 0.0001)
                quietly gen byte `uevent_b' = _d

                if "`recensor'" != "" {
                    tempvar cstar_b
                    quietly gen double `cstar_b' = `admin_censor' * exp(-`psi_g' * `exposure')
                    quietly replace `uevent_b' = 0 if `utime_b' > `cstar_b'
                    quietly replace `utime_b' = min(`utime_b', `cstar_b')
                }

                quietly stset `utime_b', failure(`uevent_b')

                if "`testtype'" == "logrank" {
                    capture quietly sts test `randomization', logrank
                }
                else {
                    capture quietly sts test `randomization', wilcoxon
                }

                if _rc == 0 {
                    local z_g = sqrt(r(chi2))

                    * Direction
                    quietly sts generate _aft_km_b = s, by(`randomization')
                    quietly summarize _aft_km_b if `randomization' == 1, meanonly
                    local me = r(mean)
                    quietly summarize _aft_km_b if `randomization' == 0, meanonly
                    local mc = r(mean)
                    quietly drop _aft_km_b
                    if `me' < `mc' local z_g = -`z_g'

                    * Check for zero crossing
                    if !missing(`prev_z') {
                        if (`prev_z' >= 0 & `z_g' <= 0) | (`prev_z' <= 0 & `z_g' >= 0) {
                            local prev_psi = `grid_lo' + (`g' - 2) * `grid_step'
                            local best_psi = `prev_psi' + `grid_step' * `prev_z' / (`prev_z' - `z_g')
                            matrix `boot_psi'[`rep', 1] = `best_psi'

                            * Drop tempvars before breaking
                            capture drop `utime_b'
                            capture drop `uevent_b'
                            if "`recensor'" != "" capture drop `cstar_b'
                            continue, break
                        }
                    }
                    local prev_z = `z_g'
                }

                capture drop `utime_b'
                capture drop `uevent_b'
                if "`recensor'" != "" capture drop `cstar_b'
            }

            restore

            if mod(`rep', 50) == 0 {
                display as text "." _continue
            }
        }

        display as text " done"

        * Compute bootstrap SE
        mata: st_local("boot_se", strofreal(sqrt(variance(st_matrix("`boot_psi'")))))
        if "`boot_se'" != "." & "`boot_se'" != "" {
            local se_psi = real("`boot_se'")
            * Update CIs from bootstrap SE
            local ci_lo = `psi_hat' - `z_alpha' * `se_psi'
            local ci_hi = `psi_hat' + `z_alpha' * `se_psi'
            local af_lo = exp(`ci_lo')
            local af_hi = exp(`ci_hi')
        }
    }

    * =========================================================================
    * DISPLAY RESULTS
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as text "{bf:RPSFTM Results}"
    display as text "{hline 70}"
    display as text ""

    display as text "Acceleration factor (psi):  " ///
        as result %10.4f `psi_hat'
    display as text "exp(psi):                   " ///
        as result %10.4f `af'

    if !missing(`ci_lo') & !missing(`ci_hi') {
        display as text "`level'% CI for psi:         " ///
            as result "[" %8.4f `ci_lo' ", " %8.4f `ci_hi' "]"
        display as text "`level'% CI for exp(psi):    " ///
            as result "[" %8.4f `af_lo' ", " %8.4f `af_hi' "]"
    }
    else {
        display as text "`level'% CI:                 " ///
            as result "(bounds not found within grid range)"
    }

    if !missing(`se_psi') {
        display as text "SE(psi):                    " ///
            as result %10.4f `se_psi'
    }

    display as text ""
    display as text "N:                          " as result %10.0fc `N'
    display as text "Events:                     " as result %10.0fc `n_events'
    display as text "Treatment switches:         " as result %10.0fc `n_switched'

    display as text ""
    display as text "{bf:Interpretation:}"
    if `af' > 1 {
        display as text "  exp(psi) = " as result %6.4f `af' ///
            as text " > 1: treatment {bf:extends} survival time by a"
        display as text "  factor of " as result %6.4f `af' ///
            as text " (after adjusting for treatment switching)"
    }
    else if `af' < 1 {
        display as text "  exp(psi) = " as result %6.4f `af' ///
            as text " < 1: treatment {bf:shortens} survival time by a"
        display as text "  factor of " as result %6.4f `af'
    }
    else {
        display as text "  exp(psi) = 1: no treatment effect detected"
    }

    display as text ""
    display as text "Next step: {cmd:aft_counterfactual, plot} for survival curves"
    display as text "{hline 70}"

    * =========================================================================
    * PLOT Z-CURVE
    * =========================================================================

    if "`plot'" != "" {
        if `"`scheme'"' == "" local scheme `"scheme(plotplainblind)"'

        preserve
        clear
        quietly set obs `gridpoints'
        quietly gen double psi = .
        quietly gen double z = .

        forvalues g = 1/`gridpoints' {
            quietly replace psi = `grid_mat'[`g', 1] in `g'
            quietly replace z = `grid_mat'[`g', 2] in `g'
        }

        twoway (line z psi, lcolor(navy) lwidth(medium)) ///
            , yline(0, lcolor(gs8) lpattern(solid)) ///
            yline(`z_alpha', lcolor(cranberry) lpattern(dash)) ///
            yline(-`z_alpha', lcolor(cranberry) lpattern(dash)) ///
            xline(`psi_hat', lcolor(forest_green) lpattern(shortdash)) ///
            xtitle("psi") ytitle("Z statistic") ///
            title("RPSFTM: Z(psi) Curve") ///
            subtitle("psi = `=string(`psi_hat', "%6.4f")'") ///
            legend(off) `scheme' ///
            name(_aft_rpsftm_z, replace)

        restore
    }

    * =========================================================================
    * STORE CHARACTERISTICS
    * =========================================================================

    char _dta[_aft_rpsftm] "1"
    char _dta[_aft_rpsftm_psi] "`psi_hat'"
    char _dta[_aft_rpsftm_se] "`se_psi'"
    char _dta[_aft_rpsftm_ci_lo] "`ci_lo'"
    char _dta[_aft_rpsftm_ci_hi] "`ci_hi'"
    char _dta[_aft_rpsftm_af] "`af'"
    char _dta[_aft_rpsftm_rand] "`randomization'"
    char _dta[_aft_rpsftm_treat] "`treatment'"
    char _dta[_aft_rpsftm_recensor] "`recensor'"

    * =========================================================================
    * STORE E-CLASS RESULTS
    * =========================================================================

    * Post b and V matrices
    tempname b V
    matrix `b' = (`psi_hat')
    matrix colnames `b' = psi
    if !missing(`se_psi') {
        matrix `V' = (`se_psi' * `se_psi')
    }
    else {
        matrix `V' = (.)
    }
    matrix colnames `V' = psi
    matrix rownames `V' = psi

    ereturn post `b' `V', obs(`N')

    ereturn scalar psi = `psi_hat'
    ereturn scalar af = `af'
    ereturn scalar se_psi = `se_psi'
    ereturn scalar ci_lo = `ci_lo'
    ereturn scalar ci_hi = `ci_hi'
    ereturn scalar af_lo = `af_lo'
    ereturn scalar af_hi = `af_hi'
    ereturn scalar N = `N'
    ereturn scalar n_events = `n_events'
    ereturn scalar n_switched = `n_switched'
    ereturn scalar level = `level'
    ereturn matrix grid = `grid_mat'
    ereturn local cmd "aft_rpsftm"
    ereturn local testtype "`testtype'"
    ereturn local randomization "`randomization'"
    ereturn local treatment "`treatment'"

    * =========================================================================
    * SAVE RESULTS
    * =========================================================================

    if "`saving'" != "" {
        preserve
        clear
        quietly set obs `gridpoints'
        quietly gen double psi = .
        quietly gen double z = .

        forvalues g = 1/`gridpoints' {
            quietly replace psi = `grid_mat'[`g', 1] in `g'
            quietly replace z = `grid_mat'[`g', 2] in `g'
        }

        quietly save `saving'
        restore
    }

    set varabbrev `_vaset'
end
