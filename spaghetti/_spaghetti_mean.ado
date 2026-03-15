*! _spaghetti_mean Version 1.0.0  2026/03/15
*! Group mean and CI computation for spaghetti plots
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet

program define _spaghetti_mean
    version 16.0
    syntax , outcome(varname numeric) time(varname numeric) ///
        SAVEfile(string) [by(varname) smooth(string) CI]

    preserve

    * Collapse to mean/sd/count by time (and by-group)
    if "`by'" != "" {
        collapse (mean) _spag_mean_y=`outcome' ///
                 (sd) _spag_mean_sd=`outcome' ///
                 (count) _spag_mean_n=`outcome', ///
                 by(`time' `by')
    }
    else {
        collapse (mean) _spag_mean_y=`outcome' ///
                 (sd) _spag_mean_sd=`outcome' ///
                 (count) _spag_mean_n=`outcome', ///
                 by(`time')
    }

    * Compute CI bounds
    if "`ci'" != "" {
        gen double _spag_mean_se = _spag_mean_sd / sqrt(_spag_mean_n)
        * SD is missing for single-observation groups; set SE to 0
        quietly count if _spag_mean_n == 1
        if r(N) > 0 {
            quietly replace _spag_mean_se = 0 if _spag_mean_n == 1
        }
        gen double _spag_mean_lo = _spag_mean_y ///
            - invnormal(0.975) * _spag_mean_se
        gen double _spag_mean_hi = _spag_mean_y ///
            + invnormal(0.975) * _spag_mean_se
        drop _spag_mean_se
    }

    * Apply smoothing if requested
    if "`smooth'" == "lowess" | "`smooth'" == "linear" {

        if "`by'" != "" {
            * Use numeric group for iteration
            tempvar _grp
            egen int `_grp' = group(`by')
            quietly summarize `_grp', meanonly
            local n_grps = r(max)

            gen double _smooth_tmp = .

            forvalues g = 1/`n_grps' {
                quietly count if `_grp' == `g'
                if r(N) < 3 continue

                if "`smooth'" == "lowess" {
                    tempvar _lw
                    lowess _spag_mean_y `time' if `_grp' == `g', ///
                        gen(`_lw') nograph
                    quietly replace _smooth_tmp = `_lw' if `_grp' == `g'
                    drop `_lw'
                }
                else {
                    quietly regress _spag_mean_y `time' if `_grp' == `g'
                    tempvar _pr
                    quietly predict double `_pr' if `_grp' == `g'
                    quietly replace _smooth_tmp = `_pr' if `_grp' == `g'
                    drop `_pr'
                }
            }

            quietly replace _spag_mean_y = _smooth_tmp ///
                if !missing(_smooth_tmp)
            drop _smooth_tmp `_grp'
        }
        else {
            quietly count
            if r(N) >= 3 {
                if "`smooth'" == "lowess" {
                    tempvar _lw
                    lowess _spag_mean_y `time', gen(`_lw') nograph
                    quietly replace _spag_mean_y = `_lw'
                    drop `_lw'
                }
                else {
                    quietly regress _spag_mean_y `time'
                    tempvar _pr
                    quietly predict double `_pr'
                    quietly replace _spag_mean_y = `_pr'
                    drop `_pr'
                }
            }
        }
    }

    * Mark as mean data
    gen byte _spag_is_mean = 1

    * Clean up intermediate variables
    drop _spag_mean_sd _spag_mean_n

    * Sort for correct line drawing
    if "`by'" != "" {
        sort `by' `time'
    }
    else {
        sort `time'
    }

    save `"`savefile'"', replace

    restore
end
