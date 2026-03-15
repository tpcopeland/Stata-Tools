*! _kmplot_risktable Version 1.1.0  2026/03/15
*! Risk table helper for kmplot
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet

/*
Internal helper program. Generates a number-at-risk table graph
to be combined with the main KM plot via graph combine.

Options:
  events  - show cumulative events in compact "N (E)" format
  mono    - display all numbers in black (default: match line colors)

Called from kmplot.ado. Not intended for direct use.
*/

program define _kmplot_risktable
    version 16.0
    set varabbrev off

    syntax , GRPvar(varname) NGRoups(integer) ///
        [TIMEpoints(numlist sort) ///
         COLors(string asis) SCHeme(string) XMax(real -1) ///
         EVents MONO]

    if "`scheme'" == "" local scheme "plotplainblind"

    * Read group labels from dataset characteristics (set by kmplot)
    forvalues g = 1/`ngroups' {
        local grplbl`g' : char _dta[_kmplot_grplbl`g']
        if `"`grplbl`g''"' == "" local grplbl`g' "Group `g'"
    }

    * Determine time range
    if `xmax' <= 0 {
        quietly summarize _t
        local xmax = r(max)
    }

    * Auto timepoints if not specified
    if "`timepoints'" == "" {
        local step = `xmax' / 5
        if `step' >= 100 {
            local step = round(`step', 50)
        }
        else if `step' >= 10 {
            local step = round(`step', 5)
        }
        else if `step' >= 1 {
            local step = round(`step', 1)
        }
        else {
            local step = round(`step', 0.5)
        }
        if `step' <= 0 local step = `xmax' / 5
        numlist "0(`step')`xmax'"
        local timepoints `r(numlist)'
    }

    local ntp : word count `timepoints'

    * =====================================================================
    * COMPUTE AT-RISK COUNTS (before preserve)
    * =====================================================================

    capture confirm variable _t0
    local has_t0 = (_rc == 0)

    forvalues g = 1/`ngroups' {
        local j = 0
        foreach tp of local timepoints {
            local ++j
            if `has_t0' & `tp' > 0 {
                quietly count if _t >= `tp' & _t0 < `tp' & `grpvar' == `g'
            }
            else {
                quietly count if _t >= `tp' & `grpvar' == `g'
            }
            local nrisk_`g'_`j' = r(N)
        }
    }

    * =====================================================================
    * COMPUTE CUMULATIVE EVENTS (before preserve, if requested)
    * =====================================================================

    if "`events'" != "" {
        forvalues g = 1/`ngroups' {
            local j = 0
            foreach tp of local timepoints {
                local ++j
                quietly count if _t <= `tp' & _d == 1 & `grpvar' == `g'
                local nevt_`g'_`j' = r(N)
            }
        }
    }

    * =====================================================================
    * BUILD SCATTER DATASET
    * =====================================================================

    preserve
    clear

    local nobs = `ngroups' * `ntp'
    quietly set obs `nobs'

    quietly gen double _rt_time = .
    quietly gen double _rt_ypos = .
    quietly gen str30 _rt_label = ""
    quietly gen int _rt_grp = .

    local row = 0

    forvalues g = 1/`ngroups' {
        local j = 0
        foreach tp of local timepoints {
            local ++j
            local ++row
            quietly replace _rt_time = `tp' in `row'
            quietly replace _rt_ypos = `ngroups' - `g' + 1 in `row'
            if "`events'" != "" {
                * Compact "N (E)" format
                local nr = `nrisk_`g'_`j''
                local ne = `nevt_`g'_`j''
                quietly replace _rt_label = "`nr' (`ne')" in `row'
            }
            else {
                quietly replace _rt_label = "`nrisk_`g'_`j''" in `row'
            }
            quietly replace _rt_grp = `g' in `row'
        }
    }

    * =====================================================================
    * BUILD SCATTER COMMAND
    * =====================================================================

    local scatcmd ""
    forvalues g = 1/`ngroups' {
        if "`mono'" != "" {
            local col "black"
        }
        else {
            local colidx = mod(`g' - 1, 8) + 1
            local col : word `colidx' of `colors'
            if "`col'" == "" local col "black"
        }
        local scatcmd `"`scatcmd' (scatter _rt_ypos _rt_time if _rt_grp == `g', msymbol(none) mlabel(_rt_label) mlabposition(0) mlabcolor(`col') mlabsize(vsmall))"'
    }

    * =====================================================================
    * Y-AXIS LABELS
    * =====================================================================

    local ylabels ""

    forvalues g = 1/`ngroups' {
        local yval = `ngroups' - `g' + 1
        local lbl `"`grplbl`g''"'
        local ylabels `"`ylabels' `yval' `"`lbl'"'"'
    }

    local ymin = 0.5
    local ymax = `ngroups' + 0.5
    local fysize = 25

    if "`events'" != "" {
        local ytitle_rt "No. at risk (events)"
    }
    else {
        local ytitle_rt "No. at risk"
    }

    * =====================================================================
    * DRAW RISK TABLE
    * =====================================================================

    local tp_first : word 1 of `timepoints'

    * Offset xscale start to separate ylabel from first data point
    local xstart = `tp_first' - (`xmax' - `tp_first') * 0.02

    twoway `scatcmd', ///
        ylabel(`ylabels', angle(0) labsize(vsmall) noticks nogrid) ///
        xlabel(`timepoints', labsize(vsmall) noticks) ///
        yscale(range(`ymin' `ymax') noline) ///
        xscale(range(`xstart' `xmax') noline) ///
        xtitle("Analysis time", size(vsmall)) ///
        ytitle("`ytitle_rt'", size(vsmall)) ///
        title("") subtitle("") ///
        scheme(`scheme') ///
        name(_kmplot_risktable, replace) nodraw ///
        plotregion(margin(l=3 r=0 t=2 b=0)) ///
        graphregion(margin(t=0 b=0)) ///
        legend(off) ///
        fysize(`fysize')

    restore
end
