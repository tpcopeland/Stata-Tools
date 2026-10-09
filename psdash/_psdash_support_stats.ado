*! _psdash_support_stats Version 1.7.5  2026/10/09
*! Common support bounds and outside-count statistics
*! Author: Timothy P Copeland, Karolinska Institutet
*! Internal helper

program define _psdash_support_stats, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , TREATment(varname numeric) SAMPLEvar(varname) N(real) ///
            [PSVar(varname numeric) OBSps(varname numeric) ///
             LEVELS(string asis) GROUPPSVars(varlist numeric) ///
             MULTIgroup(string) QTRIM(real -1) GPSFLOOR(real 0.01)]

        return clear

        * Bounds are data values (group minima/maxima or quantiles). They are
        * kept in scalars, never in decimal locals: a double does not survive
        * the round trip through a macro's decimal text for roughly a third of
        * values, so the observation that DEFINES a bound could be counted
        * outside the support it defines, at rc 0.
        tempname lb ub min_t min_c max_t max_c q_lo q_hi
        if "`multigroup'" == "" | "`multigroup'" == "0" {
            quietly {
                summarize `psvar' if `treatment' == 1 & `samplevar'
                local n_treated = r(N)
                local mean_ps_t = r(mean)
                scalar `min_t' = r(min)
                scalar `max_t' = r(max)
                local sd_ps_t = r(sd)

                summarize `psvar' if `treatment' == 0 & `samplevar'
                local n_control = r(N)
                local mean_ps_c = r(mean)
                scalar `min_c' = r(min)
                scalar `max_c' = r(max)
                local sd_ps_c = r(sd)

                if `qtrim' >= 0 {
                    * Quantile-based common support: robust to single-observation
                    * tails that drag the raw min/max overlap region.
                    local _qhi = 100 - `qtrim'
                    _pctile `psvar' if `treatment' == 1 & `samplevar', p(`qtrim' `_qhi')
                    scalar `q_lo' = r(r1)
                    scalar `q_hi' = r(r2)
                    _pctile `psvar' if `treatment' == 0 & `samplevar', p(`qtrim' `_qhi')
                    scalar `lb' = max(`q_lo', r(r1))
                    scalar `ub' = min(`q_hi', r(r2))
                }
                else {
                    scalar `lb' = max(`min_t', `min_c')
                    scalar `ub' = min(`max_t', `max_c')
                }

                count if (`psvar' < `lb' | `psvar' > `ub') & `samplevar'
                local n_outside = r(N)
                local pct_outside = 100 * `n_outside' / `n'

                count if (`psvar' < `lb' | `psvar' > `ub') ///
                    & `treatment' == 1 & `samplevar'
                local n_outside_t = r(N)

                count if (`psvar' < `lb' | `psvar' > `ub') ///
                    & `treatment' == 0 & `samplevar'
                local n_outside_c = r(N)
            }

            return scalar n_treated = `n_treated'
            return scalar n_control = `n_control'
            return scalar mean_ps_t = `mean_ps_t'
            return scalar min_ps_t = `min_t'
            return scalar max_ps_t = `max_t'
            return scalar sd_ps_t = `sd_ps_t'
            return scalar mean_ps_c = `mean_ps_c'
            return scalar min_ps_c = `min_c'
            return scalar max_ps_c = `max_c'
            return scalar sd_ps_c = `sd_ps_c'
            return scalar lower_bound = `lb'
            return scalar upper_bound = `ub'
            return scalar overlap_lower = `lb'
            return scalar overlap_upper = `ub'
            return scalar n_outside = `n_outside'
            return scalar pct_outside = `pct_outside'
            return scalar n_outside_t = `n_outside_t'
            return scalar n_outside_c = `n_outside_c'
            return scalar qtrim = `qtrim'
        }
        else {
            local n_levels : word count `levels'
            local n_group_ps : word count `grouppsvars'
            if `n_group_ps' != `n_levels' {
                display as error "internal error: multigroup propensity score mapping incomplete"
                exit 498
            }
            if "`obsps'" == "" {
                display as error "internal error: observed-treatment propensity score required"
                exit 498
            }

            tempname gps_means
            quietly {
                * McCaffrey et al. (2013) assess multi-treatment overlap by
                * evaluating each e_j(X) for every unit and comparing that same
                * component across observed treatment groups. tabstat computes
                * the full K-by-K mean table in one grouped pass.
                matrix `gps_means' = J(`n_levels', `n_levels', .)
                tabstat `grouppsvars' if `samplevar', ///
                    by(`treatment') statistics(mean) save
                forvalues ridx = 1/`n_levels' {
                    forvalues cidx = 1/`n_levels' {
                        matrix `gps_means'[`ridx', `cidx'] = ///
                            r(Stat`ridx')[1, `cidx']
                    }
                }
                local gps_rownames ""
                local gps_colnames ""
                foreach lev of local levels {
                    local gps_rownames "`gps_rownames' group_`lev'"
                    local gps_colnames "`gps_colnames' e_`lev'"
                }
                matrix rownames `gps_means' = `gps_rownames'
                matrix colnames `gps_means' = `gps_colnames'

                local idx = 1
                foreach lev of local levels {
                    local lev_ps : word `idx' of `grouppsvars'
                    summarize `lev_ps' if `treatment' == `lev' & `samplevar'
                    local n_group_`lev' = r(N)
                    local mean_ps_`lev' = r(mean)
                    tempname min_ps_`lev' max_ps_`lev'
                    scalar `min_ps_`lev'' = r(min)
                    scalar `max_ps_`lev'' = r(max)
                    local sd_ps_`lev' = r(sd)
                    local idx = `idx' + 1
                }

                * Scalars, not decimal locals: see the binary branch.
                scalar `lb' = 0
                scalar `ub' = 1
                foreach lev of local levels {
                    if `min_ps_`lev'' > `lb' scalar `lb' = `min_ps_`lev''
                    if `max_ps_`lev'' < `ub' scalar `ub' = `max_ps_`lev''
                }

                count if (`obsps' < `lb' | `obsps' > `ub') & `samplevar'
                local n_outside = r(N)
                local pct_outside = 100 * `n_outside' / `n'

                foreach lev of local levels {
                    count if (`obsps' < `lb' | `obsps' > `ub') ///
                        & `treatment' == `lev' & `samplevar'
                    local n_outside_`lev' = r(N)
                }

                * GENERALIZED-PROPENSITY-SCORE POSITIVITY (full vector).
                * Practical positivity for K treatments is a property of the
                * WHOLE GPS vector, not the observed-arm scalar: a unit satisfies
                * it only if min_j e_j(X) is bounded away from zero (Li & Li 2019,
                * Assumption 2; McCaffrey et al. 2013 evaluate each e_j over all
                * units regardless of assignment). min_j e_j(X) is also the
                * generalized matching-weight tilt (Yoshida et al. 2017). A unit
                * with a healthy observed-arm probability but a near-zero
                * probability of some OTHER arm is a positivity violation the old
                * observed-arm min-max rule could not see (audit probe M1).
                tempvar _min_gps _max_gps
                egen double `_min_gps' = rowmin(`grouppsvars') if `samplevar'
                egen double `_max_gps' = rowmax(`grouppsvars') if `samplevar'
                summarize `_min_gps' if `samplevar'
                local min_gps = r(min)
                count if `_min_gps' < `gpsfloor' & `samplevar'
                local n_gps_violate = r(N)
                local pct_gps_violate = 100 * `n_gps_violate' / `n'
                count if (`_min_gps' == 0 | `_max_gps' == 1) & `samplevar'
                local n_ps_boundary = r(N)
                count if (`_min_gps' < 0.01 | `_max_gps' > 0.99) & ///
                    `_min_gps' != 0 & `_max_gps' != 1 & `samplevar'
                local n_ps_near = r(N)

                * Componentwise floor: min of each e_j over ALL in-sample units
                * (McCaffrey: e_j for every unit, regardless of received arm).
                local gidx = 1
                foreach lev of local levels {
                    local lev_ps : word `gidx' of `grouppsvars'
                    summarize `lev_ps' if `samplevar'
                    local min_gps_`lev' = r(min)
                    local gidx = `gidx' + 1
                }
            }

            foreach lev of local levels {
                return scalar n_group_`lev' = `n_group_`lev''
                return scalar mean_ps_`lev' = `mean_ps_`lev''
                return scalar min_ps_`lev' = `min_ps_`lev''
                return scalar max_ps_`lev' = `max_ps_`lev''
                return scalar sd_ps_`lev' = `sd_ps_`lev''
                return scalar n_outside_`lev' = `n_outside_`lev''
                return scalar min_gps_`lev' = `min_gps_`lev''
            }
            return scalar lower_bound = `lb'
            return scalar upper_bound = `ub'
            return scalar overlap_lower = `lb'
            return scalar overlap_upper = `ub'
            return scalar n_outside = `n_outside'
            return scalar pct_outside = `pct_outside'
            * Full-vector GPS positivity (RB-02)
            return scalar min_gps = `min_gps'
            return scalar n_gps_violate = `n_gps_violate'
            return scalar pct_gps_violate = `pct_gps_violate'
            return scalar gps_floor = `gpsfloor'
            return scalar n_ps_boundary = `n_ps_boundary'
            return scalar n_ps_near = `n_ps_near'
            return matrix gps_means = `gps_means'
        }
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
