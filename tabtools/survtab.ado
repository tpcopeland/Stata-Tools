*! survtab Version 1.8.9  2026/07/01
*! Survival summary table with Kaplan-Meier estimates, medians, and RMST
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
DESCRIPTION:
    Generates a publication-ready survival summary table with Kaplan-Meier
    estimates at specified timepoints. Supports group comparisons (log-rank
    test), median survival, restricted mean survival time, number at risk,
    and cumulative incidence. Exports to Excel with professional formatting.

SYNTAX:
    survtab, times(numlist) [by(varname) rmst(real) median riskset
        timeunit(string) reverse difference
        xlsx(filename) sheet(string) title(string)
        footnote(string) theme(string) borderstyle(string)
        boldp(real) zebra highlight(real)
        csv(filename) frame(name) open]

    times:      REQUIRED. Timepoints for KM estimates (e.g., 1 3 5)
    by:         Group comparison variable with log-rank test
    rmst:       Restricted mean survival time truncated at specified time
    median:     Include median survival with CI (auto-on when by() used)
    riskset:    Number-at-risk rows at each timepoint
    reverse:    Cumulative incidence (1 - S(t)) instead of survival
    difference: Between-group difference column with CI
    timeunit:   Label: "years", "months", "days" (default: "years")
*/

program define survtab, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

capture noisily {

    capture putexcel close

    return clear

    * Auto-load shared helper programs
    capture _tabtools_helpers_ready
    if _rc {
        capture findfile _tabtools_common.ado
        if _rc == 0 {
            run "`r(fn)'"
            capture _tabtools_helpers_ready
            if _rc {
                display as error "_tabtools_common.ado failed to load fully; reinstall tabtools"
                exit 111
            }
        }
        else {
            display as error "_tabtools_common.ado not found; reinstall tabtools"
            exit 111
        }
    }
    _tabtools_require_helpers

**# Syntax and Validation
    syntax, times(numlist >0) [by(varname) RMST(real -1) MEDian RISKset ///
        TIMEUnit(string) REVerse DIFFerence EVents ///
        xlsx(string) excel(string) sheet(string) title(string) ///
        FOOTnote(string) THEme(string) BORDERstyle(string) ///
        HEADERShade HEADERColor(string) ZEBRAColor(string) ///
        BOLDp(real -1) zebra HIGHlight(real -1) DIGits(integer -1) ///
        csv(string) MARKdown(string) MDAPPend FRAme(string) open pdp(integer -1) highpdp(integer -1) ///
        ADDRow(string asis)]

    * Accept excel() as synonym for xlsx()
    if "`xlsx'" == "" & "`excel'" != "" local xlsx "`excel'"
    local _has_xlsx = "`xlsx'" != ""

    * Resolve persistent defaults
    if `boldp' == -1 & "$TABTOOLS_BOLDP" != "" local boldp = $TABTOOLS_BOLDP
    if `pdp' == -1 local pdp = 3
    if `highpdp' == -1 local highpdp = 2
    if `pdp' < 0 | `pdp' > 10 {
        noisily display as error "pdp() must be between 0 and 10"
        exit 198
    }
    if `highpdp' < 0 | `highpdp' > 10 {
        noisily display as error "highpdp() must be between 0 and 10"
        exit 198
    }

    if `digits' == -1 {
        if "$TABTOOLS_DIGITS" != "" local digits = $TABTOOLS_DIGITS
        else local digits = 1
    }
    if `digits' < 0 | `digits' > 6 {
        noisily display as error "digits() must be between 0 and 6"
        exit 198
    }

    * Validate stset
    capture st_is 2 analysis
    if _rc {
        noisily display as error "data not st set"
        noisily display as error "Hint: run {bf:stset timevar, failure(eventvar)} before calling survtab"
        exit 119
    }
    local st_id : char _dta[st_id]
    if "`st_id'" != "" {
        capture confirm variable `st_id'
        if _rc local st_id ""
    }

    * Default options
    if "`timeunit'" == "" local timeunit "years"
    if !inlist("`timeunit'", "years", "months", "days", "weeks") {
        noisily display as error "timeunit() must be years, months, days, or weeks"
        exit 198
    }
    local tu_abbrev = substr("`timeunit'", 1, 2)
    if "`tu_abbrev'" == "ye" local tu_short "yr"
    else if "`tu_abbrev'" == "mo" local tu_short "mo"
    else if "`tu_abbrev'" == "da" local tu_short "d"
    else if "`tu_abbrev'" == "we" local tu_short "wk"

    * Sheet default
    if "`sheet'" == "" local sheet "Survival"
    _tabtools_validate_sheet "`sheet'" "sheet()"

    * Path validation
    if "`open'" != "" & !`_has_xlsx' {
        noisily display as error "open requires xlsx() or excel()"
        exit 198
    }
    if `_has_xlsx' & !strmatch(lower("`xlsx'"), "*.xlsx") {
        noisily display as error "Excel filename must have .xlsx extension"
        exit 198
    }
    if `_has_xlsx' _tabtools_validate_path "`xlsx'" "xlsx()"
    if "`csv'" != "" _tabtools_validate_path "`csv'" "csv()"
    if "`mdappend'" != "" & `"`markdown'"' == "" {
        noisily display as error "mdappend requires markdown()"
        exit 198
    }
    if `"`markdown'"' != "" {
        _tabtools_validate_path `"`markdown'"' "markdown()"
        local _md_lower = lower(`"`markdown'"')
        if !(strmatch(`"`_md_lower'"', "*.md") | ///
             strmatch(`"`_md_lower'"', "*.markdown") | ///
             strmatch(`"`_md_lower'"', "*.qmd") | ///
             strmatch(`"`_md_lower'"', "*.rmd")) {
            noisily display as error "markdown() must specify a .md, .markdown, .qmd, or .rmd file"
            exit 198
        }
    }

    * Auto-enable median when by() is specified
    if "`by'" != "" & "`median'" == "" local median "median"

    * Validate boldp
    local has_boldp = `boldp' != -1
    if `has_boldp' & (`boldp' <= 0 | `boldp' >= 1) {
        noisily display as error "boldp() must be between 0 and 1"
        exit 198
    }
    local has_highlight = `highlight' != -1
    if `has_highlight' & (`highlight' <= 0 | `highlight' >= 1) {
        noisily display as error "highlight() must be between 0 and 1"
        exit 198
    }

    * Difference requires by()
    if "`difference'" != "" & "`by'" == "" {
        noisily display as error "difference requires by()"
        exit 198
    }

    * RMST validation
    if `rmst' != -1 & `rmst' <= 0 {
        noisily display as error "rmst() must be greater than 0"
        exit 198
    }
    local has_rmst = `rmst' != -1

    * Resolve formatting
    _tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle') headershade(`headershade') zebra(`zebra')
    _tabtools_resolve_colors, headercolor(`"`headercolor'"') zebracolor(`"`zebracolor'"')

    * Count timepoints
    local n_times : word count `times'

**# Determine Groups
    local n_groups 1
    local group_levels ""
    local has_by = "`by'" != ""
    tempvar groupvar
    if `has_by' {
        capture confirm numeric variable `by'
        if !_rc {
            qui clonevar `groupvar' = `by'
        }
        else {
            qui encode `by', gen(`groupvar')
        }
        qui levelsof `groupvar' if _st, local(group_levels)
        local n_groups : word count `group_levels'
        if `n_groups' < 2 {
            noisily display as error "by() variable must have at least 2 levels"
            exit 198
        }
        if "`difference'" != "" & `n_groups' != 2 {
            noisily display as error "difference requires exactly 2 groups in by()"
            exit 198
        }
    }
    else {
        qui gen byte `groupvar' = 1
        local group_levels "1"
    }

    * Build group labels and counts
    forvalues g = 1/`n_groups' {
        local _glv : word `g' of `group_levels'
        if `has_by' {
            local _glabel : label (`groupvar') `_glv'
        }
        else {
            local _glabel "Overall"
        }
        local glabel_`g' "`_glabel'"
        if "`st_id'" != "" {
            tempvar _gn_tag
            qui egen byte `_gn_tag' = tag(`st_id') if `groupvar' == `_glv' & _st
            qui count if `_gn_tag'
        }
        else {
            qui count if `groupvar' == `_glv' & _st
        }
        local gn_`g' = r(N)
    }

**# Compute Events and At-Risk Counts
    if "`events'" != "" {
        forvalues g = 1/`n_groups' {
            local _glv : word `g' of `group_levels'
            if "`st_id'" != "" {
                tempvar _event_tag
                qui egen byte `_event_tag' = tag(`st_id') ///
                    if `groupvar' == `_glv' & _st & _d == 1
                qui count if `_event_tag'
            }
            else {
                if `has_by' {
                    qui count if `groupvar' == `_glv' & _st & _d == 1
                }
                else {
                    qui count if _st & _d == 1
                }
            }
            local events_g`g' = r(N)
            local atrisk_g`g' = `gn_`g''
        }
    }

**# Compute KM Estimates at Specified Timepoints
    * Use sts generate for reliable KM function extraction
    forvalues g = 1/`n_groups' {
        local _glv : word `g' of `group_levels'
        tempvar _surv_fn _se_fn
        qui sts generate `_surv_fn' = s if `groupvar' == `_glv'
        qui sts generate `_se_fn' = se(s) if `groupvar' == `_glv'
        forvalues t = 1/`n_times' {
            local _time : word `t' of `times'
            * Get last KM estimate at or before this timepoint
            qui su `_surv_fn' if _t <= `_time' & `groupvar' == `_glv' & _st
            if r(N) > 0 {
                * Find the survival value at the largest time <= _time
                tempvar _at_time
                qui gen byte `_at_time' = (_t <= `_time' & `groupvar' == `_glv' & _st & !missing(`_surv_fn'))
                qui su _t if `_at_time', meanonly
                local _max_t = r(max)
                qui su `_surv_fn' if _t == `_max_t' & `groupvar' == `_glv' & _st, meanonly
                local _surv = r(min)
                qui su `_se_fn' if _t == `_max_t' & `groupvar' == `_glv' & _st, meanonly
                local _se = r(min)
                drop `_at_time'
            }
            else {
                * No events before this time — survival is 1
                local _surv = 1
                local _se = 0
            }
            local surv_g`g'_t`t' = `_surv'
            local se_g`g'_t`t' = `_se'

            * Number at risk (accounts for delayed entry via _t0)
            if "`riskset'" != "" {
                if "`st_id'" != "" {
                    tempvar _risk_tag
                    qui egen byte `_risk_tag' = tag(`st_id') ///
                        if _t >= `_time' & _t0 < `_time' & `groupvar' == `_glv' & _st
                    qui count if `_risk_tag'
                }
                else {
                    qui count if _t >= `_time' & _t0 < `_time' & `groupvar' == `_glv' & _st
                }
                local nrisk_g`g'_t`t' = r(N)
            }
        }
        drop `_surv_fn' `_se_fn'
    }

**# Compute Median Survival
    if "`median'" != "" {
        forvalues g = 1/`n_groups' {
            local _glv : word `g' of `group_levels'
            capture qui stci if `groupvar' == `_glv'
            if !_rc {
                local med_g`g' = r(p50)
                local med_lo_g`g' = r(lb)
                local med_hi_g`g' = r(ub)
            }
            else {
                local med_g`g' = .
                local med_lo_g`g' = .
                local med_hi_g`g' = .
            }
        }
    }

**# Log-Rank Test
    local logrank_p .
    local logrank_chi2 .
    local logrank_df .
    local _logrank_row = 0
    if `has_by' {
        qui sts test `groupvar' if _st
        local logrank_chi2 = r(chi2)
        local logrank_df = r(df)
        local logrank_p = chi2tail(`logrank_df', `logrank_chi2')
    }

**# Compute RMST
    if `has_rmst' {
        forvalues g = 1/`n_groups' {
            local _glv : word `g' of `group_levels'
            preserve
            qui keep if `groupvar' == `_glv' & _st
            qui sort _t
            tempvar _rmst_surv _event _event_tag _d_count _surv_at_event _surv_event ///
                _risk_tag
            qui sts generate `_rmst_surv' = s
            qui gen byte `_event' = (_d == 1 & _t <= `rmst')
            qui egen byte `_event_tag' = tag(_t) if `_event'
            qui bysort _t: egen double `_d_count' = total(_d) if `_event'
            qui gen double `_surv_at_event' = `_rmst_surv' if `_event'
            qui bysort _t: egen double `_surv_event' = max(`_surv_at_event')

            qui count if `_event_tag'
            if r(N) == 0 {
                local rmst_g`g' = `rmst'
                local rmst_se_g`g' = 0
                local rmst_lb_g`g' = `rmst'
                local rmst_ub_g`g' = `rmst'
                restore
                continue
            }

            tempname _evtmat
            qui mkmat _t `_surv_event' `_d_count' if `_event_tag', matrix(`_evtmat')

            local _n_evt = rowsof(`_evtmat')
            local _rmst_area = min(`_evtmat'[1,1], `rmst')
            forvalues k = 1/`_n_evt' {
                local _this_t = `_evtmat'[`k',1]
                if `k' < `_n_evt' {
                    local _next_row = `k' + 1
                    local _next_t = `_evtmat'[`_next_row',1]
                    if `_next_t' > `rmst' local _next_t = `rmst'
                }
                else {
                    local _next_t = `rmst'
                }
                local _dt = `_next_t' - `_this_t'
                if `_dt' > 0 {
                    local _rmst_area = `_rmst_area' + (`_evtmat'[`k',2] * `_dt')
                }
            }
            local rmst_g`g' = `_rmst_area'

            local _rmst_var = 0
            forvalues k = 1/`_n_evt' {
                local _this_t = `_evtmat'[`k',1]
                local _d_j = `_evtmat'[`k',3]
                local _tail = 0
                forvalues m = `k'/`_n_evt' {
                    local _seg_t = `_evtmat'[`m',1]
                    if `m' < `_n_evt' {
                        local _seg_next_row = `m' + 1
                        local _seg_next_t = `_evtmat'[`_seg_next_row',1]
                        if `_seg_next_t' > `rmst' local _seg_next_t = `rmst'
                    }
                    else {
                        local _seg_next_t = `rmst'
                    }
                    local _seg_dt = `_seg_next_t' - `_seg_t'
                    if `_seg_dt' > 0 {
                        local _tail = `_tail' + (`_evtmat'[`m',2] * `_seg_dt')
                    }
                }
                if "`st_id'" != "" {
                    qui egen byte `_risk_tag' = tag(`st_id') if _t0 < `_this_t' & _t >= `_this_t'
                    qui count if `_risk_tag'
                    drop `_risk_tag'
                }
                else {
                    qui count if _t0 < `_this_t' & _t >= `_this_t'
                }
                local _n_j = r(N)
                if `_d_j' > 0 & `_n_j' > `_d_j' {
                    local _rmst_var = `_rmst_var' + ///
                        (`_d_j' / (`_n_j' * (`_n_j' - `_d_j'))) * (`_tail'^2)
                }
            }
            local rmst_se_g`g' = sqrt(`_rmst_var')
            local rmst_lb_g`g' = `rmst_g`g'' - invnormal(0.975) * `rmst_se_g`g''
            local rmst_ub_g`g' = `rmst_g`g'' + invnormal(0.975) * `rmst_se_g`g''

            restore
        }
        if `has_by' & `n_groups' == 2 {
            local rmst_diff = `rmst_g1' - `rmst_g2'
        }
    }

**# Build Output Dataset
    preserve
    clear

    * Determine number of columns
    local ncols = 1 + `n_groups'
    if "`difference'" != "" & `n_groups' == 2 local ncols = `ncols' + 1
    if `has_by' local ncols = `ncols' + 1

    * Generate string columns
    forvalues c = 1/`ncols' {
        qui gen str244 c`c' = ""
    }
    qui gen str244 title = ""

    * Row counter
    local row 0

    * Row 1: Title
    local row = `row' + 1
    qui set obs `row'
    qui replace title = "`title'" in `row'

    * Row 2: Column headers
    local row = `row' + 1
    qui set obs `row'
    qui replace c1 = "" in `row'
    forvalues g = 1/`n_groups' {
        local col = 1 + `g'
        qui replace c`col' = "`glabel_`g'' (N=`gn_`g'')" in `row'
    }
    local _diff_col = 0
    local _p_col = 0
    if "`difference'" != "" & `n_groups' == 2 {
        local _diff_col = `n_groups' + 2
        qui replace c`_diff_col' = "Difference" in `row'
    }
    if `has_by' {
        local _p_col = `ncols'
        qui replace c`_p_col' = "p" in `row'
    }

    * Median survival rows
    if "`median'" != "" {
        local row = `row' + 1
        qui set obs `row'
        qui replace c1 = "Median survival, `tu_short'" in `row'
        forvalues g = 1/`n_groups' {
            local col = 1 + `g'
            if !missing(`med_g`g'') {
                qui replace c`col' = string(`med_g`g'', "%5.`digits'f") in `row'
            }
            else {
                qui replace c`col' = "NR" in `row'
            }
        }
        * Difference for median
        if "`difference'" != "" & `n_groups' == 2 {
            if !missing(`med_g1') & !missing(`med_g2') {
                local _md = `med_g1' - `med_g2'
                qui replace c`_diff_col' = string(`_md', "%5.`digits'f") in `row'
            }
        }

        * CI row for median
        local row = `row' + 1
        qui set obs `row'
        qui replace c1 = "  (95% CI)" in `row'
        forvalues g = 1/`n_groups' {
            local col = 1 + `g'
            if !missing(`med_lo_g`g'') & !missing(`med_hi_g`g'') {
                qui replace c`col' = "(" + string(`med_lo_g`g'', "%5.`digits'f") + ", " + string(`med_hi_g`g'', "%5.`digits'f") + ")" in `row'
            }
        }
    }

    * Events / N row
    if "`events'" != "" {
        local row = `row' + 1
        qui set obs `row'
        qui replace c1 = "Events / N" in `row'
        forvalues g = 1/`n_groups' {
            local col = 1 + `g'
            qui replace c`col' = string(`events_g`g'', "%11.0fc") + " / " + string(`atrisk_g`g'', "%11.0fc") in `row'
        }
    }

    * Survival probability header
    local row = `row' + 1
    qui set obs `row'
    local _prob_label = cond("`reverse'" != "", "Cumulative incidence", "Survival probability")
    qui replace c1 = "`_prob_label'" in `row'

    * Survival probability rows at each timepoint
    forvalues t = 1/`n_times' {
        local _time : word `t' of `times'
        local row = `row' + 1
        qui set obs `row'
        * Time label
        if `_time' == 1 {
            qui replace c1 = "  `_time' `tu_short'" in `row'
        }
        else {
            qui replace c1 = "  `_time' `timeunit'" in `row'
        }

        forvalues g = 1/`n_groups' {
            local col = 1 + `g'
            local _s = `surv_g`g'_t`t''
            if !missing(`_s') {
                if "`reverse'" != "" local _s = 1 - `_s'
                qui replace c`col' = string(`_s' * 100, "%5.`digits'f") + "%" in `row'
            }
        }

        * Difference column
        if "`difference'" != "" & `n_groups' == 2 {
            local _s1 = `surv_g1_t`t''
            local _s2 = `surv_g2_t`t''
            local _se1 = `se_g1_t`t''
            local _se2 = `se_g2_t`t''
            if !missing(`_s1') & !missing(`_s2') {
                if "`reverse'" != "" {
                    local _d = (1 - `_s1') - (1 - `_s2')
                }
                else {
                    local _d = (`_s1' - `_s2')
                }
                local _d_pct = `_d' * 100
                * SE of difference (independent groups)
                if !missing(`_se1') & !missing(`_se2') {
                    local _se_d = sqrt(`_se1'^2 + `_se2'^2) * 100
                    local _lo = `_d_pct' - invnormal(0.975) * `_se_d'
                    local _hi = `_d_pct' + invnormal(0.975) * `_se_d'
                    qui replace c`_diff_col' = string(`_d_pct', "%5.`digits'f") + " (" + string(`_lo', "%5.`digits'f") + ", " + string(`_hi', "%5.`digits'f") + ")" in `row'
                }
                else {
                    qui replace c`_diff_col' = string(`_d_pct', "%5.`digits'f") in `row'
                }
            }
        }
    }

    * RMST rows
    if `has_rmst' {
        local row = `row' + 1
        qui set obs `row'
        local _rmst_str = cond(mod(`rmst', 1) == 0, string(`rmst', "%3.0f"), string(`rmst', "%5.1f"))
        qui replace c1 = "RMST (`_rmst_str'-`tu_short'), `tu_short' (95% CI)" in `row'
        forvalues g = 1/`n_groups' {
            local col = 1 + `g'
            if !missing(`rmst_g`g'') {
                if !missing(`rmst_lb_g`g'') & !missing(`rmst_ub_g`g'') {
                    qui replace c`col' = string(`rmst_g`g'', "%5.`=`digits'+1'f") + ///
                        " (" + string(`rmst_lb_g`g'', "%5.`=`digits'+1'f") + ///
                        ", " + string(`rmst_ub_g`g'', "%5.`=`digits'+1'f") + ")" in `row'
                }
                else {
                    qui replace c`col' = string(`rmst_g`g'', "%5.`=`digits'+1'f") in `row'
                }
            }
        }
        if "`difference'" != "" & `n_groups' == 2 & !missing(`rmst_diff') {
            qui replace c`_diff_col' = string(`rmst_diff', "%5.`=`digits'+1'f") in `row'
        }
    }

    * Number at risk rows
    if "`riskset'" != "" {
        local row = `row' + 1
        qui set obs `row'
        qui replace c1 = "Number at risk" in `row'

        forvalues t = 1/`n_times' {
            local _time : word `t' of `times'
            local row = `row' + 1
            qui set obs `row'
            if `_time' == 1 {
                qui replace c1 = "  `_time' `tu_short'" in `row'
            }
            else {
                qui replace c1 = "  `_time' `timeunit'" in `row'
            }
            forvalues g = 1/`n_groups' {
                local col = 1 + `g'
                qui replace c`col' = string(`nrisk_g`g'_t`t'', "%11.0fc") in `row'
            }
        }
    }

    * Log-rank test row
    if `has_by' & !missing(`logrank_p') {
        local row = `row' + 1
        qui set obs `row'
        local _logrank_row = `row'
        local _lr_chi2_str = string(`logrank_chi2', "%6.2f")
        local _pmin = 10^(-`pdp')
        local _pfmt_lo = "%`=`pdp'+2'.`pdp'f"
        local _pfmt_hi = "%`=`highpdp'+2'.`highpdp'f"
        if `logrank_p' < `_pmin' {
            local _lr_p_str = "<" + string(`_pmin', "`_pfmt_lo'")
        }
        else if `logrank_p' < 0.10 {
            local _lr_p_str = string(`logrank_p', "`_pfmt_lo'")
        }
        else {
            local _lr_p_str = string(`logrank_p', "`_pfmt_hi'")
        }
        qui replace c1 = "Log-rank test: chi2(`=string(`logrank_df',"%1.0f")') = `_lr_chi2_str', p = `_lr_p_str'" in `row'

        * Write p-value in the p column on the first data row (row 3)
        if `_p_col' > 0 {
            qui replace c`_p_col' = "`_lr_p_str'" in 3
        }
    }

    * =========================================================================
    * ADD CUSTOM ROWS (addrow option)
    * =========================================================================
    if `"`addrow'"' != "" {
        local _ar_rest `"`addrow'"'
        while `"`_ar_rest'"' != "" {
            local _bs_pos = strpos(`"`_ar_rest'"', "\")
            if `_bs_pos' > 0 {
                local _ar_chunk = substr(`"`_ar_rest'"', 1, `_bs_pos' - 1)
                local _ar_rest = substr(`"`_ar_rest'"', `_bs_pos' + 1, .)
            }
            else {
                local _ar_chunk `"`_ar_rest'"'
                local _ar_rest ""
            }
            local _ar_chunk = strtrim(`"`_ar_chunk'"')
            if `"`_ar_chunk'"' == "" continue

            gettoken _ar_label _ar_vals : _ar_chunk
            local _ar_label : subinstr local _ar_label `"""' "", all

            local curr_n = _N
            qui set obs `=`curr_n'+1'
            qui replace c1 = "`_ar_label'" in `=`curr_n'+1'

            local _ar_c = 1
            local _ar_vals = strtrim(`"`_ar_vals'"')
            while `"`_ar_vals'"' != "" {
                gettoken _ar_v _ar_vals : _ar_vals
                local _ar_c = `_ar_c' + 1
                if `_ar_c' <= `ncols' {
                    qui replace c`_ar_c' = "`_ar_v'" in `=`curr_n'+1'
                }
            }
        }
    }

    local num_rows = _N
    local _header_row = 2
    local _data_start = `_header_row' + 1
    local _p_value_row = 3

**# Build Return Matrix
    * Build r(table): rows = timepoints, cols = groups (survival estimates)
    tempname _rtable
    matrix `_rtable' = J(`n_times', `n_groups', .)
    forvalues t = 1/`n_times' {
        forvalues g = 1/`n_groups' {
            local _s = `surv_g`g'_t`t''
            if !missing(`_s') {
                if "`reverse'" != "" local _s = 1 - `_s'
                matrix `_rtable'[`t', `g'] = `_s'
            }
        }
    }
    local _rnames ""
    forvalues t = 1/`n_times' {
        local _time : word `t' of `times'
        local _rnames "`_rnames' t`_time'"
    }
    local _cnames ""
    forvalues g = 1/`n_groups' {
        local _cnames "`_cnames' `glabel_`g''"
    }
    capture matrix rownames `_rtable' = `_rnames'
    capture matrix colnames `_rtable' = `_cnames'

**# Console Display
    noisily _tabtools_console_display `ncols' `"`title'"'
    if "`reverse'" != "" {
        noisily display as text "Note: 1-KM is shown. For competing risks, use stcrreg-based CIF."
    }

**# CSV Export
    if "`csv'" != "" {
        _tabtools_csv_write using "`csv'"
        capture confirm file "`csv'"
        if _rc {
            noisily display as error "CSV export command succeeded but file not found"
            exit 601
        }
        noisily display as text "CSV exported to `csv'"
    }

    local _ret_markdown ""
    local _ret_markdown_rows .
    local _ret_markdown_cols .
    if `"`markdown'"' != "" {
        local _mdappend_opt ""
        if "`mdappend'" != "" local _mdappend_opt "append"
        capture noisily _tabtools_markdown_write using `"`markdown'"', ///
            `_mdappend_opt' title(`"`title'"') footnote(`"`footnote'"') strictheaders
        if _rc {
            local _md_rc = _rc
            noisily display as error "Failed to export Markdown to `markdown'"
            restore
            exit `_md_rc'
        }
        local _ret_markdown `"`markdown'"'
        local _ret_markdown_rows = r(n_rows)
        local _ret_markdown_cols = r(n_cols)
        noisily display as text "Markdown exported to `markdown'"
    }

**# Frame Output
    if `"`frame'"' != "" {
        _tabtools_frame_put `"`frame'"'
        local frame "`_frame_name'"
    }

**# Return Results
    capture return matrix table = `_rtable'
    return scalar N_rows = `num_rows'
    if "`median'" != "" {
        forvalues g = 1/`n_groups' {
            capture return scalar median_`g' = `med_g`g''
        }
    }
    if "`events'" != "" {
        forvalues g = 1/`n_groups' {
            return scalar events_`g' = `events_g`g''
            return scalar atrisk_`g' = `atrisk_g`g''
        }
    }
    if `has_by' {
        return scalar logrank_p = `logrank_p'
        return scalar logrank_chi2 = `logrank_chi2'
    }
    if `has_rmst' {
        forvalues g = 1/`n_groups' {
            capture return scalar rmst_`g' = `rmst_g`g''
            capture return scalar rmst_se_`g' = `rmst_se_g`g''
            capture return scalar rmst_lb_`g' = `rmst_lb_g`g''
            capture return scalar rmst_ub_`g' = `rmst_ub_g`g''
        }
        if `n_groups' >= 2 {
            capture return scalar rmst_diff = `rmst_diff'
        }
    }
    if "`frame'" != "" return local frame "`frame'"

    * Build methods paragraph
    local _methods "Survival was estimated using the Kaplan-Meier method."
    if "`reverse'" != "" {
        local _methods "`_methods' Cumulative incidence (1 minus survival) is reported."
    }
    if `has_by' {
        local _methods "`_methods' Groups were compared using the log-rank test."
    }
    if "`median'" != "" {
        local _methods "`_methods' Median survival time with 95% confidence intervals is reported."
    }
    if `has_rmst' {
        local _rmst_mstr = cond(mod(`rmst', 1) == 0, string(`rmst', "%3.0f"), string(`rmst', "%5.1f"))
        local _methods "`_methods' Restricted mean survival time was computed up to `_rmst_mstr' `timeunit' with 95% confidence intervals based on the Greenwood variance formula."
    }
    local _methods "`_methods' Analysis performed in Stata `c(stata_version)' (StataCorp, College Station, TX)."
    return local methods "`_methods'"

**# Excel Export
    local num_cols = `ncols' + 1
    local _xlsx_ok 0
    if `_has_xlsx' {
        order title c*
        capture noisily _tabtools_xlsx_write using "`xlsx'", sheet("`sheet'") book(b)
        if _rc {
            local _export_rc = _rc
            noisily display as error "Failed to export to `xlsx'"
            noisily display as error "Hint: ensure the xlsx file is not open in another application"
            restore
            exit `_export_rc'
        }

        * Apply formatting through the shared rule backend.
        capture {
            local _hborder_code = 1
            if "`_hborder'" == "medium" local _hborder_code = 2
            if "`_hborder'" == "thick" local _hborder_code = 3
            if "`_hborder'" == "none" local _hborder_code = 4

            tempname _style_rules
            matrix `_style_rules' = (13, 1, 1, 1, 1, 1, 0, 0, 0)
            matrix `_style_rules' = `_style_rules' \ ///
                (13, 1, 1, 2, 2, 22, 0, 0, 0)
            forvalues _wc = 3/`num_cols' {
                matrix `_style_rules' = `_style_rules' \ ///
                    (13, 1, 1, `_wc', `_wc', 18, 0, 0, 0)
            }

            matrix `_style_rules' = `_style_rules' \ ///
                (1, 1, `num_rows', 1, `num_cols', `_fontsize', 1, 0, 0) \ ///
                (1, 1, 1, 1, `num_cols', `=`_fontsize'+2', 1, 0, 0) \ ///
                (14, 1, 1, 1, `num_cols', 0, 0, 0, 0) \ ///
                (2, 1, 1, 1, 1, 0, 1, 0, 0) \ ///
                (4, 1, 1, 1, 1, 0, 1, 0, 0) \ ///
                (5, 1, 1, 1, 1, 0, 1, 0, 0) \ ///
                (6, 1, 1, 1, 1, 0, 2, 0, 0) \ ///
                (8, `_header_row', `_header_row', 2, `num_cols', 0, `_hborder_code', 0, 0) \ ///
                (9, `_header_row', `_header_row', 2, `num_cols', 0, `_hborder_code', 0, 0) \ ///
                (2, `_header_row', `_header_row', 2, `num_cols', 0, 1, 0, 0) \ ///
                (5, `_header_row', `_header_row', 2, `num_cols', 0, 2, 0, 0)
            if "`headershade'" != "" {
                matrix `_style_rules' = `_style_rules' \ ///
                    (7, `_header_row', `_header_row', 2, `num_cols', 0, -1, 0, 0)
            }
            if `num_rows' >= `_data_start' & `num_cols' >= 3 {
                matrix `_style_rules' = `_style_rules' \ ///
                    (5, `_data_start', `num_rows', 3, `num_cols', 0, 2, 0, 0)
            }
            matrix `_style_rules' = `_style_rules' \ ///
                (9, `num_rows', `num_rows', 2, `num_cols', 0, `_hborder_code', 0, 0)
            if "`zebra'" != "" {
                forvalues _zr = `=`_data_start'+1'(2)`num_rows' {
                    matrix `_style_rules' = `_style_rules' \ ///
                        (7, `_zr', `_zr', 2, `num_cols', 0, -2, 0, 0)
                }
            }
            if `has_boldp' & `has_by' & !missing(`logrank_p') & `logrank_p' < `boldp' {
                if `_p_col' > 0 {
                    local _excel_p_col = `_p_col' + 1
                    matrix `_style_rules' = `_style_rules' \ ///
                        (2, `_p_value_row', `_p_value_row', `_excel_p_col', `_excel_p_col', 0, 1, 0, 0)
                }
                if `_logrank_row' > 0 {
                    matrix `_style_rules' = `_style_rules' \ ///
                        (2, `_logrank_row', `_logrank_row', 2, `num_cols', 0, 1, 0, 0)
                }
            }
            if `has_highlight' & `has_by' & !missing(`logrank_p') & `logrank_p' < `highlight' & `_logrank_row' > 0 {
                matrix `_style_rules' = `_style_rules' \ ///
                    (7, `_logrank_row', `_logrank_row', 2, `num_cols', 0, -3, 0, 0)
            }
            if `_logrank_row' > 0 {
                matrix `_style_rules' = `_style_rules' \ ///
                    (14, `_logrank_row', `_logrank_row', 2, `num_cols', 0, 0, 0, 0) \ ///
                    (5, `_logrank_row', `_logrank_row', 2, 2, 0, 1, 0, 0) \ ///
                    (6, `_logrank_row', `_logrank_row', 2, 2, 0, 2, 0, 0)
            }
            if `"`footnote'"' != "" {
                local _fn_row = `num_rows' + 1
                local _fn_fontsize = max(`_fontsize' - 2, 6)
                mata: b.put_string(`_fn_row', 2, `"`footnote'"')
                matrix `_style_rules' = `_style_rules' \ ///
                    (14, `_fn_row', `_fn_row', 2, `num_cols', 0, 0, 0, 0) \ ///
                    (5, `_fn_row', `_fn_row', 2, 2, 0, 1, 0, 0) \ ///
                    (6, `_fn_row', `_fn_row', 2, 2, 0, 2, 0, 0) \ ///
                    (4, `_fn_row', `_fn_row', 2, 2, 0, 1, 0, 0) \ ///
                    (1, `_fn_row', `_fn_row', 2, 2, `_fn_fontsize', 1, 0, 0) \ ///
                    (3, `_fn_row', `_fn_row', 2, 2, 0, 1, 0, 0)
            }

            _tabtools_xlsx_apply_styles, book(b) sheet("`sheet'") ///
                rules(`_style_rules') font("`_font'") ///
                color1("`_headercolor'") color2("`_zebracolor'") ///
                color3("255 255 204")
            mata: b.close_book()
        }
        if _rc {
            local saved_rc = _rc
            capture mata: b.close_book()
            capture mata: mata drop b
            noisily display as error "Excel formatting failed with error `saved_rc'"
            exit `saved_rc'
        }
        capture mata: mata drop b

        capture confirm file "`xlsx'"
        if _rc {
            noisily display as error "Export command succeeded but file not found"
            exit 601
        }
        local _xlsx_ok 1
        noisily display as text "Exported to " as result `"`xlsx'"' as text ", sheet " as result `"`sheet'"'
    }

    restore

    if `_xlsx_ok' {
        return local xlsx "`xlsx'"
        return local sheet "`sheet'"
    }
    if "`csv'" != "" {
        return local csv "`csv'"
    }
    if `"`_ret_markdown'"' != "" {
        return local markdown `"`_ret_markdown'"'
        return scalar markdown_rows = `_ret_markdown_rows'
        return scalar markdown_cols = `_ret_markdown_cols'
    }
    if "`open'" != "" & `_xlsx_ok' _tabtools_open_file "`xlsx'"

} // end capture noisily
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
