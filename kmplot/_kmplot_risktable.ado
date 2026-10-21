*! _kmplot_risktable Version 1.0.0  2026/10/20
*! Risk table helper for kmplot
*! Author: Timothy P Copeland, Karolinska Institutet

/*
Internal helper program. Generates a number-at-risk table graph
to be combined with the main KM plot via graph combine.

Options:
  events        - show cumulative events in compact "N (E)" format
  mono          - display all numbers in black (default: match line colors)
  compvar()     - competing-event indicator; those exits are not censored
  riskweight()  - none (count records/people) or stset (sum the stset weight)
  mask(#)       - counts 1 to #-1 print as masktext() (default <#) and are
                  missing in r(risktable) and r(risktable_w)

Returns r(risktable) (displayed basis), r(risktable_w) (summed stset weight)
and r(risktable_flag) (1 = cell masked), all in the same row order.

Called from kmplot.ado. Not intended for direct use.
*/

program define _kmplot_risktable, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _kmplot_rt_preserved = 0
    capture noisily {

        syntax , GRPvar(varname) NGRoups(integer) GRAPHName(name) ///
            [TIMEpoints(string) ///
            COLors(string asis) SCHeme(string) XMax(real -1) RISKHeight(real -1) ///
            XTItle(string asis) XTOPts(string asis) XTSize(string) ///
            XLAbel(string asis) YLAbel(string asis) ///
            EVents MONO TOPTimeaxis CALLERVersion(string) ///
            COMPvar(varname) RISKWeight(string) MASK(integer 0) MASKText(string) ///
            REGIONopts(string asis) YLABHi(real -1)]
        if "`riskweight'" == "" local riskweight "stset"
        if !inlist("`riskweight'", "none", "stset") {
            noisily display as error "riskweight() must be none or stset"
            exit 198
        }
        if `"`masktext'"' == "" local masktext "<`mask'"

        * Layout is split across two files: this one places the row labels and
        * reports the reserves, kmplot mirrors them onto the main panel.  A
        * package update mid-session leaves the old kmplot.ado in memory while
        * this file is reloaded from disk, which would silently misalign the two
        * panels.  Refuse rather than draw a wrong graph.  This file is always
        * run fresh from disk, so its version is read from its own header;
        * only the caller's literal (kmplot.ado) is baked into memory.
        local rt_this_version ""
        capture findfile _kmplot_risktable.ado
        if _rc == 0 {
            tempname rt_fh
            file open `rt_fh' using `"`r(fn)'"', read text
            file read `rt_fh' rt_header
            file close `rt_fh'
            if regexm(`"`rt_header'"', "Version ([0-9]+[.][0-9]+[.][0-9]+)") {
                local rt_this_version = regexs(1)
            }
        }
        if "`rt_this_version'" == "" local rt_this_version "unknown"
        if "`callerversion'" != "`rt_this_version'" {
            noisily display as error ///
                "kmplot and _kmplot_risktable versions differ (helper `rt_this_version')"
            noisily display as error ///
                "type -discard- and rerun, or reinstall kmplot"
            exit 498
        }

        if "`scheme'" == "" local scheme "`c(scheme)'"
        local ncolors : word count `colors'
        if `ncolors' == 0 & "`mono'" == "" {
            noisily display as error "colors() must contain at least one color"
            exit 198
        }
        * xtitle() arrives ready for graph: one or more compound-quoted
        * strings with macro characters already encoded, or empty for no
        * title (kmplot resolves the default).  xtopts() and xtsize() are the
        * user's sub-options and size() (default vsmall below the table,
        * small for the title drawn above it with toptimeaxis).
        local xtsize_low = cond("`xtsize'" == "", "vsmall", "`xtsize'")
        local xtsize_top = cond("`xtsize'" == "", "small", "`xtsize'")

        * Read group labels from dataset characteristics (set by kmplot)
        * The labels are kept literal (macval() at every use); the graph copy
        * _glbl# encodes macro characters for graph's second parse.
        forvalues g = 1/`ngroups' {
            mata: st_local("grplbl`g'", st_global("_dta[_kmplot_grplbl`g']"))
            if `"`macval(grplbl`g')'"' == "" local grplbl`g' "Group `g'"
            mata: st_local("_glbl`g'", subinstr(subinstr(st_local("grplbl`g'"), char(96), "{c 96}"), char(36), "{c 36}"))
        }

        * Row labels are drawn as y-axis labels.  Offsetting the rows off the
        * integer grid keeps them from colliding with the main panel's y-axis
        * label values, which are added here invisibly to reserve column width.
        * A collision would make ylabel(..., add) replace one of those reserved
        * labels and shrink this panel's label column below the main panel's.
        local rt_row_offset = 0.137

        * The main panel's y labels are added here invisibly to reserve the
        * same label-column width.  When they reach above this panel's own
        * range (a percent or other large-valued axis) they would stretch it,
        * so every y coordinate of the table is then scaled by rt_yk to span
        * the main axis instead.
        local rt_ytop = `ngroups' + 0.5 + `rt_row_offset'
        if "`toptimeaxis'" != "" local rt_ytop = `ngroups' + 1.50 + `rt_row_offset'
        local rt_yk = 1
        if `ylabhi' > `rt_ytop' local rt_yk = `ylabhi' / `rt_ytop'

        * Determine time range
        if `xmax' <= 0 {
            quietly summarize _t
            local xmax = r(max)
        }

        * Auto timepoints if not specified
        if "`timepoints'" == "" {
            if `xmax' <= 0 {
                * All events at time 0 — use single timepoint
                local timepoints "0"
            }
            else {
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
                if `step' <= 0 local step = `xmax'
                numlist "0(`step')`xmax'"
                local timepoints `r(numlist)'
            }
        }

        * cmptimes: each timepoint at the precision of the stset data,
        * used for every comparison with _t and _t0.
        _kmplot_times, values("`timepoints'") stmatch
        local timepoints "`r(times)'"
        local cmptimes "`r(cmptimes)'"
        local ntp : word count `timepoints'

        * =====================================================================
        * COMPUTE AT-RISK COUNTS (before preserve)
        * =====================================================================

        capture confirm variable _t0
        local has_t0 = (_rc == 0)

        local st_id : char _dta[st_id]
        local st_wv : char _dta[st_wv]
        tempvar rt_weight rt_loss rt_tag
        quietly gen double `rt_weight' = 1
        if `"`st_wv'"' != "" {
            quietly replace `rt_weight' = `st_wv'
        }

        tempvar rt_comp
        quietly gen byte `rt_comp' = 0
        if "`compvar'" != "" quietly replace `rt_comp' = (`compvar' == 1)
        if `"`st_id'"' != "" {
            quietly bysort `st_id' (_t0 _t): gen byte `rt_loss' = ///
                (_d == 0 & !`rt_comp' & (_n == _N | _t < _t0[_n + 1] | ///
                `grpvar' != `grpvar'[_n + 1]))
        }
        else {
            quietly gen byte `rt_loss' = (_d == 0 & !`rt_comp')
        }

        tempname rtmat rtwmat rtfmat
        matrix `rtmat' = J(`ngroups' * `ntp', 5, .)
        matrix colnames `rtmat' = group time at_risk events censored
        matrix `rtwmat' = J(`ngroups' * `ntp', 3, .)
        matrix colnames `rtwmat' = at_risk_w events_w censored_w
        matrix `rtfmat' = J(`ngroups' * `ntp', 3, 0)
        matrix colnames `rtfmat' = at_risk_masked events_masked censored_masked

        forvalues g = 1/`ngroups' {
            forvalues j = 1/`ntp' {
                local tp : word `j' of `timepoints'
                local tc : word `j' of `cmptimes'
                if `"`st_id'"' != "" {
                    if `has_t0' {
                        quietly egen byte `rt_tag' = tag(`st_id') ///
                            if _t >= `tc' & ///
                            (_t0 < `tc' | (_t0 == 0 & `tp' == 0)) & ///
                            `grpvar' == `g'
                    }
                    else {
                        quietly egen byte `rt_tag' = tag(`st_id') ///
                            if _t >= `tc' & `grpvar' == `g'
                    }
                    quietly summarize `rt_weight' if `rt_tag' == 1, meanonly
                    local wrisk_`g'_`j' = r(sum)
                    quietly count if `rt_tag' == 1
                    local prisk_`g'_`j' = r(N)
                    quietly drop `rt_tag'
                }
                else {
                    if `has_t0' {
                        quietly summarize `rt_weight' ///
                            if _t >= `tc' & ///
                            (_t0 < `tc' | (_t0 == 0 & `tp' == 0)) & ///
                            `grpvar' == `g', meanonly
                    }
                    else {
                        quietly summarize `rt_weight' ///
                            if _t >= `tc' & `grpvar' == `g', meanonly
                    }
                    local wrisk_`g'_`j' = r(sum)
                    local prisk_`g'_`j' = r(N)
                }
            }
        }

        * =====================================================================
        * COMPUTE CUMULATIVE EVENTS (before preserve, if requested)
        * =====================================================================

        forvalues g = 1/`ngroups' {
            forvalues j = 1/`ntp' {
                local tc : word `j' of `cmptimes'
                quietly summarize `rt_weight' ///
                    if _t <= `tc' & _d == 1 & `grpvar' == `g', meanonly
                local wevt_`g'_`j' = r(sum)
                local pevt_`g'_`j' = r(N)
                quietly summarize `rt_weight' ///
                    if _t <= `tc' & `rt_loss' == 1 & `grpvar' == `g', meanonly
                local wcens_`g'_`j' = r(sum)
                local pcens_`g'_`j' = r(N)
                * Displayed basis, then masking of people counts 1 .. mask-1.
                * A masked cell's exact value is kept nowhere past this point.
                foreach _q in risk evt cens {
                    if "`riskweight'" == "stset" {
                        local n`_q'_`g'_`j' = `w`_q'_`g'_`j''
                    }
                    else {
                        local n`_q'_`g'_`j' = `p`_q'_`g'_`j''
                    }
                    local m`_q'_`g'_`j' = 0
                    if `mask' > 0 {
                        if `n`_q'_`g'_`j'' > 0 & `n`_q'_`g'_`j'' < `mask' {
                            local m`_q'_`g'_`j' = 1
                            local n`_q'_`g'_`j' = .
                            local w`_q'_`g'_`j' = .
                            local p`_q'_`g'_`j' = .
                        }
                    }
                }
            }
        }

        local _rt_row = 0
        forvalues g = 1/`ngroups' {
            local j = 0
            foreach tp of local timepoints {
                local ++j
                local ++_rt_row
                matrix `rtmat'[`_rt_row', 1] = `g'
                matrix `rtmat'[`_rt_row', 2] = `tp'
                matrix `rtmat'[`_rt_row', 3] = `nrisk_`g'_`j''
                matrix `rtmat'[`_rt_row', 4] = `nevt_`g'_`j''
                matrix `rtmat'[`_rt_row', 5] = `ncens_`g'_`j''
                matrix `rtwmat'[`_rt_row', 1] = `wrisk_`g'_`j''
                matrix `rtwmat'[`_rt_row', 2] = `wevt_`g'_`j''
                matrix `rtwmat'[`_rt_row', 3] = `wcens_`g'_`j''
                matrix `rtfmat'[`_rt_row', 1] = `mrisk_`g'_`j''
                matrix `rtfmat'[`_rt_row', 2] = `mevt_`g'_`j''
                matrix `rtfmat'[`_rt_row', 3] = `mcens_`g'_`j''
            }
        }

        * =====================================================================
        * BUILD SCATTER DATASET
        * =====================================================================

        preserve
        local _kmplot_rt_preserved = 1
        clear

        local nobs = `ngroups' * `ntp'
        quietly set obs `nobs'

        tempvar rt_time rt_ypos rt_label rt_grp
        quietly gen double `rt_time' = .
        quietly gen double `rt_ypos' = .
        quietly gen str60 `rt_label' = ""
        quietly gen int `rt_grp' = .

        local row = 0
        local rt_first_width = 0
        local rt_last_width = 0

        forvalues g = 1/`ngroups' {
            local j = 0
            foreach tp of local timepoints {
                local ++j
                local ++row
                quietly replace `rt_time' = `tp' in `row'
                quietly replace `rt_ypos' = ///
                    (`ngroups' - `g' + 1 + `rt_row_offset') * `rt_yk' in `row'
                * Unweighted and frequency-weighted counts are whole numbers;
                * probability and importance weights give fractional ones,
                * printed to one decimal place (r(risktable) keeps the value).
                local nr = `nrisk_`g'_`j''
                * A weighted sum that is whole up to rounding error prints as
                * an integer, not as 3.0.
                if `mrisk_`g'_`j'' {
                    local nr `"`masktext'"'
                }
                else if abs(`nr' - round(`nr')) < 1e-9 * max(1, abs(`nr')) {
                    local nr = strtrim(string(round(`nr'), "%21.0fc"))
                }
                else {
                    local nr = strtrim(string(`nr', "%21.1fc"))
                }
                if "`events'" != "" {
                    * Compact "N (E)" format
                    local ne = `nevt_`g'_`j''
                    if `mevt_`g'_`j'' {
                        local ne `"`masktext'"'
                    }
                    else if abs(`ne' - round(`ne')) < 1e-9 * max(1, abs(`ne')) {
                        local ne = strtrim(string(round(`ne'), "%21.0fc"))
                    }
                    else {
                        local ne = strtrim(string(`ne', "%21.1fc"))
                    }
                    local _celltext "`nr' (`ne')"
                }
                else {
                    local _celltext "`nr'"
                }
                quietly replace `rt_label' = "`_celltext'" in `row'
                quietly replace `rt_grp' = `g' in `row'
                if `j' == 1 | `j' == `ntp' {
                    * Helvetica advance widths, in thousandths of an em.
                    * The first column's count is centred on the y axis and so
                    * reaches back into the row-label column; the last one
                    * overhangs the graph boundary.  Both reserves are sized
                    * from the text actually drawn.
                    local _cw = 0
                    local _cn = strlen("`_celltext'")
                    forvalues _c = 1/`_cn' {
                        local _ch = substr("`_celltext'", `_c', 1)
                        if "`_ch'" == " " | "`_ch'" == "," | "`_ch'" == "." {
                            local _cw = `_cw' + 278
                        }
                        else if "`_ch'" == "(" | "`_ch'" == ")" {
                            local _cw = `_cw' + 333
                        }
                        else {
                            local _cw = `_cw' + 556
                        }
                    }
                    if `j' == 1 & `_cw' > `rt_first_width' {
                        local rt_first_width = `_cw'
                    }
                    if `j' == `ntp' & `_cw' > `rt_last_width' {
                        local rt_last_width = `_cw'
                    }
                }
            }
        }

        * =====================================================================
        * BUILD SCATTER COMMAND
        * =====================================================================

        local scatcmd ""
        local xaxis_cmd ""
        if "`toptimeaxis'" != "" local xaxis_cmd "xaxis(1 2)"
        forvalues g = 1/`ngroups' {
            if "`mono'" != "" {
                local col "black"
            }
            else {
                local colidx = mod(`g' - 1, `ncolors') + 1
                local col : word `colidx' of `colors'
                if "`col'" == "" local col "black"
            }
            local scatcmd `"`scatcmd' (scatter `rt_ypos' `rt_time' if `rt_grp' == `g', `xaxis_cmd' msymbol(none) mlabel(`rt_label') mlabposition(0) mlabcolor("`col'") mlabsize(small))"'
        }

        * =====================================================================
        * Y-AXIS LABELS
        * =====================================================================

        * Keep breathing room below the final risk-table row.
        local ymin = 0.0
        local ymax = (`ngroups' + 0.5 + `rt_row_offset') * `rt_yk'
        if `riskheight' > 0 {
            local fysize = `riskheight'
        }
        else {
            local fysize = 25
            if `ngroups' > 3 {
                local fysize = 25 + (`ngroups' - 3) * 4
                if `fysize' > 60 local fysize = 60
            }
        }

        if "`events'" != "" {
            local ytitle_rt "No. at risk (events)"
        }
        else {
            local ytitle_rt "No. at risk"
        }

        * Stata packs the vertical title hard against the y-axis label column and
        * sizes that column with a text metric narrower than what it then paints,
        * so a long row label runs over the title.  The shortfall grows with the
        * label, so reserve a title margin that grows with it too.  kmplot applies
        * the same margin to the main panel's title, keeping the panels aligned.
        local rt_widest = 0
        forvalues g = 1/`ngroups' {
            if strlen(`"`macval(grplbl`g')'"') > `rt_widest' {
                local rt_widest = strlen(`"`macval(grplbl`g')'"')
            }
        }
        local rt_title_gap = ceil(0.1111 * `rt_widest') + 1
        if `rt_title_gap' < 2 local rt_title_gap = 2

        * =====================================================================
        * DRAW RISK TABLE
        * =====================================================================

        * Match the main plot's time-zero origin so table columns align with it.
        local xstart = 0

        local xlabel_cmd ""

        * ---------------------------------------------------------------------
        * PLOT-REGION MARGINS
        * ---------------------------------------------------------------------
        * The left margin must stay at zero.  Anything positive is blank space
        * *inside* the plotting region, and kmplot applies the same value to the
        * main panel to keep the two time axes aligned, which would push the KM
        * curve's time origin away from the main y-axis.  Row labels are drawn
        * as y-axis labels instead, i.e. outside the plotting region entirely.
        local plot_margin_left = 0

        * The final column's count is centred on the last timepoint and so
        * overhangs the plotting region by half its width.  Reserve that much.
        * Derivation (measured, scale invariant -- see qa/test_kmplot_v130.do):
        * in the combined graph one margin unit is 0.75% of graph height and
        * label text is 2.0833% of graph height, so half of a label `w' em wide
        * is w * 0.5 * 2.0833 / 0.75 = w * 1.3889 margin units.  Helvetica
        * advance widths: digits .556 em, space/comma/period .278, parens .333.
        local plot_margin_right = ceil(`rt_last_width' / 1000 * 1.3889)
        if `plot_margin_right' < 4 local plot_margin_right = 4
        if `"`xlabel'"' != "" {
            * Append nogrid to the user spec: into the existing suboption group if
            * one is present (a comma), otherwise as a new suboption group.
            if strpos(`"`xlabel'"', ",") {
                local xlabel_cmd xlabel(`xlabel' nogrid)
            }
            else {
                local xlabel_cmd xlabel(`xlabel', nogrid)
            }
        }
        else {
            local xlabel_cmd xlabel(`timepoints', labsize(vsmall) noticks nogrid)
        }

        * Reserve the same left-axis width as the main plot without displaying a
        * second set of y labels.  graph combine aligns whole graphs, not their
        * plot regions, so both panels must carry the same axis geometry.
        if `"`ylabel'"' != "" {
            if strpos(`"`ylabel'"', ",") {
                local ylabel_cmd ylabel(`ylabel' labcolor(none) tlcolor(none) nogrid)
            }
            else {
                local ylabel_cmd ylabel(`ylabel', labcolor(none) tlcolor(none) nogrid)
            }
        }
        else {
            local ylabel_cmd "ylabel(0(0.25)1, format(%4.2f) angle(0) labcolor(none) tlcolor(none) nogrid)"
        }

        * The time-zero count is centred on the y axis, so half of it sits to the
        * left of the plotting region, in the row-label column.  Push the row
        * labels out by that much.  labgap widens the label column rather than
        * the plotting region, so the main panel's time origin stays on its axis
        * when kmplot applies the same gap there.  Same unit conversion as
        * plot_margin_right above.
        local rt_row_labgap = ceil(`rt_first_width' / 1000 * 1.3889) + 1
        if `rt_row_labgap' < 2 local rt_row_labgap = 2

        * Row labels occupy the y-axis label column, clear of both the time-zero
        * counts (which sit inside the plotting region) and the vertical table
        * title (which sits outside the label column).  kmplot adds the same
        * strings invisibly to the main panel so the two label columns, and
        * therefore the two time axes, come out the same width.
        local grp_ylabels ""
        forvalues g = 1/`ngroups' {
            local _gy = (`ngroups' - `g' + 1 + `rt_row_offset') * `rt_yk'
            local grp_ylabels `"`macval(grp_ylabels)' `_gy' `"`macval(_glbl`g')'"'"'
        }
        * custom scopes these style options to the row labels alone, so the
        * labcolor(none) that hides the reserved numeric labels above does not
        * take them with it.  Custom labels must be given as explicit
        * value/"text" pairs -- a rule such as 0(0.25)1 is rejected there.
        local grp_ylabel_cmd `"ylabel(`macval(grp_ylabels)', add custom angle(0) labsize(small) labgap(`rt_row_labgap') labcolor(black) tlcolor(none) nogrid)"'

        if `"`macval(xtitle)'"' != "" {
            local xtitle_cmd `"xtitle(`macval(xtitle)', size(`xtsize_low') `macval(xtopts)')"'
        }
        else local xtitle_cmd `"xtitle("")"'
        local xscale_cmd "xscale(range(`xstart' `xmax') noextend noline)"
        local separator_cmd ""
        local time_title_cmd ""
        if "`toptimeaxis'" != "" {
            if `"`xlabel'"' != "" {
                if strpos(`"`xlabel'"', ",") {
                    local top_xlabel_cmd xlabel(`xlabel' nogrid axis(2))
                }
                else {
                    local top_xlabel_cmd xlabel(`xlabel', labsize(small) noticks nogrid axis(2))
                }
            }
            else {
                local top_xlabel_cmd xlabel(`timepoints', labsize(small) noticks nogrid axis(2))
            }
            local xlabel_cmd `"xlabel(, nolabels noticks nogrid axis(1)) `top_xlabel_cmd'"'
            local xtitle_cmd `"xtitle("", axis(1)) xtitle("", axis(2))"'
            local xscale_cmd `"xscale(range(`xstart' `xmax') noextend noline axis(1)) xscale(range(`xstart' `xmax') noextend noline axis(2))"'
            local ymax = (`ngroups' + 1.50 + `rt_row_offset') * `rt_yk'
            local time_title_y = (`ngroups' + 1.025 + `rt_row_offset') * `rt_yk'
            local time_title_x = (`xstart' + `xmax') / 2
            if `"`macval(xtitle)'"' != "" {
                local time_title_cmd `"text(`time_title_y' `time_title_x' `macval(xtitle)', placement(c) size(`xtsize_top') `macval(xtopts)')"'
            }
            local separator_y = (`ngroups' + 0.55 + `rt_row_offset') * `rt_yk'
            local separator_cmd "yline(`separator_y', lcolor(gs8) lpattern(solid) lwidth(thin))"
        }

        twoway `scatcmd', ///
            `ylabel_cmd' ///
            `macval(grp_ylabel_cmd)' ///
            `xlabel_cmd' ///
            yscale(range(`ymin' `ymax') noline) ///
            `xscale_cmd' ///
            `macval(xtitle_cmd)' ///
            ytitle("`ytitle_rt'", size(small) margin(r=`rt_title_gap')) ///
            `macval(time_title_cmd)' ///
            `separator_cmd' ///
            title("") subtitle("") ///
            scheme(`scheme') ///
            `macval(regionopts)' ///
            name(`graphname', replace) nodraw ///
            plotregion(margin(l=`plot_margin_left' r=`plot_margin_right' t=2 b=0) lcolor(none) lwidth(none)) ///
            graphregion(margin(l=0 t=0 b=0)) ///
            legend(off) ///
            fysize(`fysize')

        restore
        local _kmplot_rt_preserved = 0

    } // end capture noisily
    local rc = _rc
    if `_kmplot_rt_preserved' {
        capture restore
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return scalar riskheight = `fysize'
    return scalar n_timepoints = `ntp'
    return scalar plot_margin_left = `plot_margin_left'
    return scalar plot_margin_right = `plot_margin_right'
    return scalar row_offset = `rt_row_offset'
    return scalar row_labgap = `rt_row_labgap'
    return scalar title_gap = `rt_title_gap'
    return local timepoints "`timepoints'"
    return matrix risktable_flag = `rtfmat'
    return matrix risktable_w = `rtwmat'
    return matrix risktable = `rtmat'
end
