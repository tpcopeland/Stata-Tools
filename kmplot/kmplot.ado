*! kmplot Version 1.0.0  2026/10/20
*! Publication-ready Kaplan-Meier survival, cumulative failure and cumulative incidence plots
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  kmplot [if] [in] , [by(varname) failure compete(exp) ci risktable median
                       censor pvalue export(string) options]

Description:
  Kaplan-Meier survival or cumulative failure curves, or Aalen-Johansen
  cumulative incidence curves with a competing event, with confidence bands,
  number-at-risk tables (optionally unweighted and masked), median lines,
  censoring marks, and log-rank p-values.

Method:
  Estimates the Kaplan-Meier product-limit survival function S(t), or 1-S(t)
  with failure. Greenwood standard errors come from sts generate.
  Reference: Kaplan EL, Meier P. JASA 1958;53:457-481.
  With compete(exp): the Aalen-Johansen cumulative incidence of the stset
  failure, F1(t) = sum_{t_j <= t} S(t_j-) d1_j / n_j, with S the all-cause
  Kaplan-Meier (Aalen and Johansen, Scand J Stat 1978;5:141-150).  Variance
  of Marubini and Valsecchi (1995, eq. 10.12) with ln(-ln) bounds (Choudhury,
  Stat Med 2002;21:1129-1140), as in stcompet (Coviello and Boggess, Stata
  Journal 2004;4:103-112).  Computed in _kmplot_cif.ado.

Requires: Data must be stset

See help kmplot for complete documentation
*/

program define kmplot, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _kmplot_preserved = 0
    local _kmplot_side_rc = 0
    forvalues _s = 1/6 {
        local _S_exists`_s' : all globals "S_`_s'"
        local _S_saved`_s' : copy global S_`_s'
    }
    tempname _kmplot_main_graph _kmplot_risk_graph
    capture noisily {

        syntax [if] [in] , [BY(varname) FAILure ///
            CI Level(string) CIStyle(string) CIOpacity(string) CITRansform(string) ///
            MEDian MEDIANAnnotate MEDIANFormat(string) ///
            RISKtable RISKEVents RISKCOMpact RISKMono RISKHeight(string) TIMEpoints(string) ///
            LANDmark(string) ///
            CENsor CENSORThin(string) ///
            PVALue PVALUEPOs(string) PVALUEFormat(string) PVALUEText(string asis) PVALUEAT(string asis) ///
            COLors(string asis) LWidth(string) LPattern(string asis) ///
            TItle(string asis) SUBtitle(string asis) ///
            XTItle(string asis) YTItle(string asis) ///
            XLAbel(string asis) YLAbel(string asis) ///
            LEGend(string asis) NOTE(string asis) ///
            SCHeme(string) NAME(string asis) ASPectratio(string) ///
            EXPort(string asis) SAVing(string asis) RISKSAVing(string asis) ///
            COMPete(string asis) RISKWeight(string) RISKMASK(string asis) NORISKMASK ///
            PERcent YMAX(string) TMAX(string) BYOrder(string) COMBineopts(string asis) *]

        * Validate numlist grammar, retaining double precision through dispatch.
        foreach _times in timepoints landmark {
            if "``_times''" != "" {
                _kmplot_times, values("``_times''")
                local `_times' "`r(times)'"
            }
        }
        local has_compete = (`"`compete'"' != "")
        local st_wt : char _dta[st_wt]
        local is_pweight = ("`st_wt'" == "pweight")
        if `is_pweight' & ("`ci'" != "" | "`pvalue'" != "") {
            noisily display as error "ci and pvalue are not supported with stset probability weights"
            exit 198
        }
        if `has_compete' {
            if "`st_wt'" == "iweight" & ("`ci'" != "" | "`pvalue'" != "") {
                noisily display as error "ci and pvalue are not supported with compete() and stset importance weights"
                exit 198
            }
            if "`pvalue'" != "" {
                noisily display as error "pvalue is not supported with compete(); the log-rank test does not compare cumulative incidence (Gray's test is not implemented)"
                exit 198
            }
            if "`median'" != "" | "`medianannotate'" != "" {
                noisily display as error "median and medianannotate are not supported with compete()"
                exit 198
            }
            * compete() implies a cumulative incidence plot; failure is redundant.
            local failure "failure"
        }
        local estimator = cond(`has_compete', "aalen_johansen", ///
            cond("`failure'" != "", "km_failure", "km"))
        local plot_scale = cond("`percent'" != "", 100, 1)

        * ymax(), tmax()
        local ymax_user = .
        if "`ymax'" != "" {
            capture confirm number `ymax'
            if _rc {
                noisily display as error "ymax() must be numeric"
                exit 198
            }
            local ymax_user = real("`ymax'")
            if `ymax_user' <= 0 {
                noisily display as error "ymax() must be greater than 0"
                exit 198
            }
        }
        local tmax_user = .
        if "`tmax'" != "" {
            capture confirm number `tmax'
            if _rc {
                noisily display as error "tmax() must be numeric"
                exit 198
            }
            local tmax_user = real("`tmax'")
            if `tmax_user' <= 0 {
                noisily display as error "tmax() must be greater than 0"
                exit 198
            }
        }
        * graphregion(), plotregion(), xsize(), ysize() among the passthrough
        * options; reused for the risk-table panel and the combined graph.
        _kmplot_regionopts `macval(options)'
        * nodraw is applied by kmplot to the final graph only (the combined
        * graph with risktable); the main panel is always built with nodraw.
        local user_nodraw = 0
        mata: st_local("_km_opts_nd", ustrregexra(st_local("options"), "(^|\s)nodraw(?=\s|$)", " "))
        if `"`macval(_km_opts_nd)'"' != `"`macval(options)'"' {
            local user_nodraw = 1
            local options `"`macval(_km_opts_nd)'"'
        }
        local nodraw_opt = cond(`user_nodraw', "nodraw", "")
        if `user_nodraw' & `"`export'"' != "" {
            noisily display as error "export() cannot be combined with nodraw: graph export needs a drawn graph"
            noisily display as error "omit nodraw, or run {bf:graph display} and {bf:graph export} afterwards"
            exit 198
        }
        if `"`combineopts'"' != "" & "`risktable'" == "" {
            noisily display as error "combineopts() requires risktable"
            exit 198
        }

        * Risk-table count basis and masking
        local need_rt = ("`risktable'" != "" | `"`risksaving'"' != "")
        if "`riskweight'" != "" & !`need_rt' {
            noisily display as error "riskweight() requires risktable or risksaving()"
            exit 198
        }
        if "`riskweight'" != "" & !inlist("`riskweight'", "none", "stset") {
            noisily display as error "riskweight() must be {bf:none} or {bf:stset}"
            exit 198
        }
        if "`riskweight'" == "" {
            local riskweight = cond("`st_wt'" == "fweight", "stset", "none")
        }
        if "`st_wt'" == "" local riskweight "none"
        if `"`riskmask'"' != "" & "`noriskmask'" != "" {
            noisily display as error "riskmask() and noriskmask may not be combined"
            exit 198
        }
        if (`"`riskmask'"' != "" | "`noriskmask'" != "") & !`need_rt' {
            noisily display as error "riskmask() and noriskmask require risktable or risksaving()"
            exit 198
        }
        local riskmask_k = 0
        local riskmask_text ""
        local riskmask_source ""
        if `"`riskmask'"' != "" {
            _kmplot_parse_mask `riskmask'
            local riskmask_k = `_km_mask_k'
            local riskmask_text `"`_km_mask_text'"'
        }
        else if "`noriskmask'" == "" & `need_rt' & `"$TABTOOLS_set_smallcells"' != "" {
            * Session default set by -tabtools set smallcells #-.
            capture confirm integer number $TABTOOLS_set_smallcells
            if _rc | real(`"$TABTOOLS_set_smallcells"') < 2 {
                noisily display as error `"session smallcells default "$TABTOOLS_set_smallcells" is not an integer of 2 or more; reset it with tabtools set smallcells #"'
                exit 198
            }
            local riskmask_k = real(`"$TABTOOLS_set_smallcells"')
            local riskmask_source "tabtools"
            display as text "(kmplot: using tabtools session smallcells(`riskmask_k') for riskmask())"
        }
        if `riskmask_k' > 0 & "`riskweight'" == "stset" & "`st_wt'" != "fweight" {
            noisily display as error "riskmask() requires people counts; it cannot be combined with riskweight(stset) under `st_wt's"
            if "`riskmask_source'" == "tabtools" {
                noisily display as error "masking comes from the tabtools session default (smallcells(`riskmask_k')); add noriskmask to turn it off for this call, or use riskweight(none)"
            }
            exit 198
        }

        local _level_specified = ("`level'" != "")
        local _ciopacity_specified = ("`ciopacity'" != "")
        local _censorthin_specified = ("`censorthin'" != "")
        local _riskheight_specified = ("`riskheight'" != "")

        * Stata's cilevel rules: default c(level), range [10, 99.99], at most
        * two decimal places.  Checked here rather than by re-running -syntax-,
        * which would reset `if', `in' and `options'.
        if `_level_specified' {
            capture confirm number `level'
            if _rc {
                noisily display as error "level() must be numeric"
                exit 198
            }
            local level = real("`level'")
            if `level' < 10 | `level' > 99.99 {
                noisily display as error "level() must be between 10 and 99.99 inclusive"
                exit 198
            }
            if abs(`level' * 100 - round(`level' * 100)) > 1e-6 {
                noisily display as error "level() can have at most two digits after the decimal point"
                exit 198
            }
        }
        else local level = c(level)

        if `_ciopacity_specified' {
            capture confirm integer number `ciopacity'
            if _rc {
                noisily display as error "ciopacity() must be an integer"
                exit 198
            }
            local ciopacity = real("`ciopacity'")
        }
        else local ciopacity = 12

        if `_censorthin_specified' {
            capture confirm integer number `censorthin'
            if _rc {
                noisily display as error "censorthin() must be an integer"
                exit 198
            }
            local censorthin = real("`censorthin'")
        }
        else local censorthin = 1

        if `_riskheight_specified' {
            capture confirm number `riskheight'
            if _rc {
                noisily display as error "riskheight() must be numeric"
                exit 198
            }
            local riskheight = real("`riskheight'")
        }
        else local riskheight = -1

        * =========================================================================
        * VALIDATE PREREQUISITES
        * =========================================================================

        capture st_is 2 analysis
        if _rc {
            noisily display as error "data not stset"
            noisily display as error ""
            noisily display as error "You must {bf:stset} your data before using kmplot."
            noisily display as error "Example:"
            noisily display as error "  {cmd:stset time, failure(event)}"
            exit 119
        }

        marksample touse, novarlist
        quietly replace `touse' = 0 if _st != 1
        if "`by'" != "" {
            capture confirm numeric variable `by'
            if _rc == 0 {
                markout `touse' `by'
            }
            else {
                quietly replace `touse' = 0 if `by' == ""
            }
        }
        quietly count if `touse'
        if r(N) == 0 {
            noisily display as error "no observations"
            exit 2000
        }
        local N = r(N)

        local has_medians_mat = 0
        local ymax_used = .
        local n_compete = 0
        local has_landmarks_mat = 0
        local has_risktable_mat = 0
        local has_stepband = 0
        local n_landmarks = 0
        local n_timepoints = 0
        local riskheight_used = .
        local risk_timepoints ""
        local export_file ""
        local curve_saved ""
        local risk_saved ""
        local pvalue_label "Log-rank p"
        local pvalue_format "%5.3f"
        local pvalue_y = .
        local pvalue_x = .
        local pvalue_place ""

        tempname medians_mat landmarks_mat risktable_mat risktable_w_mat risktable_f_mat

        * Reject subordinate options that would otherwise be silently ignored
        if "`medianannotate'" != "" & "`median'" == "" {
            noisily display as error "medianannotate requires median"
            exit 198
        }
        if "`medianformat'" != "" & "`median'" == "" {
            noisily display as error "medianformat() requires median"
            exit 198
        }
        if ("`riskevents'" != "" | "`riskcompact'" != "" | ///
            "`riskmono'" != "") & "`risktable'" == "" {
            noisily display as error "riskevents, riskcompact, and riskmono require risktable"
            exit 198
        }
        if "`timepoints'" != "" & "`risktable'" == "" & `"`risksaving'"' == "" {
            noisily display as error "timepoints() requires risktable or risksaving()"
            exit 198
        }
        if `_riskheight_specified' & "`risktable'" == "" {
            noisily display as error "riskheight() requires risktable"
            exit 198
        }
        if `_censorthin_specified' & "`censor'" == "" {
            noisily display as error "censorthin() requires censor"
            exit 198
        }
        if `censorthin' < 1 {
            noisily display as error "censorthin() must be at least 1"
            exit 198
        }
        if "`pvalue'" == "" & ("`pvaluepos'" != "" | "`pvalueformat'" != "" | ///
            `"`macval(pvaluetext)'"' != "" | `"`pvalueat'"' != "") {
            noisily display as error "pvaluepos(), pvalueformat(), pvaluetext(), and pvalueat() require pvalue"
            exit 198
        }
        if "`pvalue'" != "" & "`by'" == "" {
            noisily display as error "pvalue requires by()"
            exit 198
        }
        if "`pvaluepos'" != "" & `"`pvalueat'"' != "" {
            noisily display as error "pvaluepos() and pvalueat() may not be combined"
            exit 198
        }
        if "`ci'" == "" & ("`cistyle'" != "" | "`citransform'" != "" | ///
            `_ciopacity_specified' | `_level_specified') {
            noisily display as error "level(), cistyle(), ciopacity(), and citransform() require ci"
            exit 198
        }
        if "`ci'" != "" & "`cistyle'" == "line" & `_ciopacity_specified' {
            noisily display as error "ciopacity() is not supported with cistyle(line)"
            exit 198
        }

        * Validate cistyle
        if "`cistyle'" != "" & !inlist("`cistyle'", "band", "line") {
            noisily display as error "cistyle() must be {bf:band} or {bf:line}"
            exit 198
        }

        local zcrit = invnormal(1 - (100 - `level') / 200)

        * Validate citransform
        if "`citransform'" != "" & !inlist("`citransform'", "loglog", "log", "plain") {
            noisily display as error "citransform() must be {bf:loglog}, {bf:log}, or {bf:plain}"
            exit 198
        }

        * =========================================================================
        * SET DEFAULTS
        * =========================================================================

        if "`scheme'" == "" local scheme "`c(scheme)'"
        if "`cistyle'" == "" local cistyle "band"
        if "`citransform'" == "" local citransform "loglog"
        if "`lwidth'" == "" local lwidth "medthick"
        if "`pvaluepos'" == "" local pvaluepos "bottomright"
        if "`pvaluepos'" != "" & ///
            !inlist("`pvaluepos'", "topleft", "topright", "bottomleft", "bottomright") {
            noisily display as error "pvaluepos() must be {bf:topleft}, {bf:topright}, {bf:bottomleft}, or {bf:bottomright}"
            exit 198
        }
        if `_riskheight_specified' & (`riskheight' <= 0 | `riskheight' > 80) {
            noisily display as error "riskheight() must be greater than 0 and no more than 80"
            exit 198
        }
        foreach _lm of local landmark {
            if `_lm' < 0 {
                noisily display as error "landmark() timepoints must be nonnegative"
                exit 198
            }
        }
        if "`pvalueformat'" != "" local pvalue_format "`pvalueformat'"
        local median_format "%9.0g"
        if "`medianformat'" != "" {
            capture confirm numeric format `medianformat'
            if _rc | regexm("`medianformat'", "^%-?t") {
                noisily display as error "medianformat() must be a numeric (%f, %g, %e) display format"
                exit 198
            }
            local median_format "`medianformat'"
        }
        capture local _pvalue_fmt_test : display `pvalue_format' 0.123456
        if _rc {
            noisily display as error "pvalueformat() must be a valid numeric display format"
            exit 198
        }
        if `"`macval(pvaluetext)'"' != "" {
            local pvalue_label `"`macval(pvaluetext)'"'
        }
        if `"`pvalueat'"' != "" {
            capture numlist `"`pvalueat'"', min(2) max(2)
            if _rc {
                noisily display as error "pvalueat() must contain exactly two numeric values: y x"
                exit 198
            }
            local pvalueat "`r(numlist)'"
            local pvalue_y : word 1 of `pvalueat'
            local pvalue_x : word 2 of `pvalueat'
            local pvalue_place "c"
        }
        if `ciopacity' < 0 | `ciopacity' > 100 {
            noisily display as error "ciopacity() must be between 0 and 100"
            exit 198
        }

        * Default: Okabe & Ito (2008) colour-universal-design palette (yellow
        * omitted), ordered so that groups stay distinguishable under simulated
        * protanopia and deuteranopia (Machado et al. 2009); see
        * qa/test_kmplot_v140.do.  Colours are quoted at every graph sink so RGB
        * triplets survive as one colour.
        if `"`colors'"' == "" {
            local colors `""0 114 178" "213 94 0" "0 0 0" "86 180 233" "204 121 167" "230 159 0" "0 158 115""'
        }
        local ncolors : word count `colors'
        if `ncolors' == 0 {
            noisily display as error "colors() must contain at least one color"
            exit 198
        }
        if `"`macval(ytitle)'"' == "" {
            if `has_compete' {
                local ytitle "Cumulative incidence"
            }
            else if "`failure'" != "" {
                local ytitle "Cumulative failure"
            }
            else if "`percent'" != "" {
                local ytitle "Survival"
            }
            else {
                local ytitle "Survival probability"
            }
            if "`percent'" != "" local ytitle "`ytitle' (%)"
        }
        if `"`macval(xtitle)'"' == "" local xtitle "Analysis time"
        * Strip outer quotes from string-asis options (asis preserves user quotes)
        foreach _ttl in xtitle ytitle title subtitle note pvalue_label {
            mata: st_local("_text", st_local(st_local("_ttl")))
            mata: st_local("_compound", strofreal(substr(st_local("_text"), 1, 2) == char(96)+char(34) & substr(st_local("_text"), -2, 2) == char(34)+char(39)))
            if `_compound' {
                mata: st_local(st_local("_ttl"), substr(st_local("_text"), 3, strlen(st_local("_text"))-4))
            }
            else {
                mata: st_local("_quoted", strofreal(substr(st_local("_text"), 1, 1) == char(34) & substr(st_local("_text"), -1, 1) == char(34)))
                if `_quoted' {
                    mata: st_local(st_local("_ttl"), substr(st_local("_text"), 2, strlen(st_local("_text"))-2))
                }
            }
        }
        * Parse name option (handle "name, replace" syntax)
        if `"`name'"' == "" {
            local name "kmplot"
        }
        else {
            local cpos = strpos(`"`name'"', ",")
            if `cpos' > 0 {
                local name = strtrim(substr(`"`name'"', 1, `cpos' - 1))
            }
        }

        * =========================================================================
        * COMPUTE P-VALUE (before preserve)
        * =========================================================================

        local pval = .
        local pval_text ""
        if "`pvalue'" != "" {
            quietly tab `by' if `touse'
            if r(r) < 2 {
                noisily display as error "pvalue requires at least two groups in the analysis sample"
                exit 198
            }
            else {
                capture noisily quietly sts test `by' if `touse', logrank
                if _rc {
                    local _pvalue_rc = _rc
                    noisily display as error "p-value computation failed"
                    exit `_pvalue_rc'
                }
                else {
                    local pval = chi2tail(r(df), r(chi2))
                    if `pval' < 0.001 {
                        local pval_text `"`macval(pvalue_label)' < 0.001"'
                    }
                    else {
                        local pval_fmt : display `pvalue_format' `pval'
                        local pval_fmt = strtrim("`pval_fmt'")
                        local pval_text `"`macval(pvalue_label)' = `pval_fmt'"'
                    }
                }
            }
        }
        * =========================================================================
        * PREPARE DATA
        * =========================================================================

        preserve
        local _kmplot_preserved = 1

        quietly keep if `touse'

        tempvar grpid km_s km_se km_lb km_ub km_tmp km_cens km_anchor

        * Create numeric group ID
        if "`by'" != "" {
            tempvar _grpid_tmp
            quietly egen int `_grpid_tmp' = group(`by'), label
            quietly gen int `grpid' = `_grpid_tmp'
            quietly tab `grpid'
            local ngroups = r(r)

            * Get group labels
            local bylbl : value label `by'
            quietly levelsof `by', local(bylevels)
            * Unlabelled numeric levels are shown in the variable's display
            * format, so a float 0.1 reads "x=.1" rather than its binary
            * expansion; if that format would merge two levels, every label
            * keeps the full-precision value instead.
            capture confirm numeric variable `by'
            local by_numeric = (_rc == 0)
            local byfmt : format `by'
            local g = 0
            local lbl_merge = 0
            foreach lev of local bylevels {
                local ++g
                local grpfull`g' "`by'=`lev'"
                if "`bylbl'" != "" {
                    local grplbl`g' : label `bylbl' `lev'
                }
                else if `by_numeric' {
                    local levtxt = strtrim(string(`lev', "`byfmt'"))
                    local grplbl`g' "`by'=`levtxt'"
                    forvalues h = 1/`=`g' - 1' {
                        if `"`grplbl`h''"' == `"`grplbl`g''"' local lbl_merge = 1
                    }
                }
                else {
                    local grplbl`g' "`lev'"
                }
            }
            if `lbl_merge' {
                forvalues h = 1/`g' {
                    local grplbl`h' "`grpfull`h''"
                }
            }
        }
        else {
            quietly gen byte `grpid' = 1
            local ngroups = 1
            local grplbl1 = cond(`has_compete', "Cumulative incidence", "KM estimate")
        }

        * byorder(): renumber the groups so that drawing, legend, colours,
        * patterns and risk-table rows follow the requested level order.
        if "`byorder'" != "" {
            if "`by'" == "" {
                noisily display as error "byorder() requires by()"
                exit 198
            }
            if !`by_numeric' {
                noisily display as error "byorder() requires a numeric by() variable"
                exit 109
            }
            capture numlist "`byorder'"
            if _rc {
                noisily display as error "byorder() must be a numeric list of by() levels"
                exit 198
            }
            local _bo_list "`r(numlist)'"
            local _bo_new ""
            foreach _bo of local _bo_list {
                local _bo_hit = 0
                local g = 0
                foreach lev of local bylevels {
                    local ++g
                    if `lev' == `_bo' | float(`lev') == float(`_bo') local _bo_hit = `g'
                }
                if `_bo_hit' == 0 {
                    noisily display as error "byorder(): `_bo' is not a level of `by' in the analysis sample"
                    exit 198
                }
                if `: list _bo_hit in _bo_new' {
                    noisily display as error "byorder(): level `_bo' is listed more than once"
                    exit 198
                }
                local _bo_new "`_bo_new' `_bo_hit'"
            }
            forvalues g = 1/`ngroups' {
                if !`: list g in _bo_new' local _bo_new "`_bo_new' `g'"
            }
            tempvar _grp_new
            quietly gen int `_grp_new' = .
            local h = 0
            foreach g of local _bo_new {
                local ++h
                quietly replace `_grp_new' = `h' if `grpid' == `g'
                local _bo_lbl`h' `"`grplbl`g''"'
            }
            forvalues h = 1/`ngroups' {
                local grplbl`h' `"`_bo_lbl`h''"'
            }
            quietly replace `grpid' = `_grp_new'
            drop `_grp_new'
        }

        * Skip p-value for single group
        if `ngroups' == 1 & "`pvalue'" != "" {
            display as text "(p-value skipped: only one group)"
            local pvalue ""
            local pval_text ""
        }

        * Time range; tmax() caps the plotted range only
        quietly summarize _t
        local tmax = r(max)
        if `tmax_user' < . local tmax = `tmax_user'

        * =========================================================================
        * COMPETING EVENT INDICATOR
        * =========================================================================
        * A record is a competing event when _d == 0, compete() is true on it,
        * and stset exit() did not cut the record short.

        tempvar km_comp km_sall
        quietly gen byte `km_comp' = 0
        if `has_compete' {
            tempvar _cexp
            capture gen double `_cexp' = (`compete')
            if _rc {
                local _crc = _rc
                noisily display as error `"compete() is not a valid expression: `compete'"'
                exit `_crc'
            }
            quietly count if missing(`_cexp')
            if r(N) > 0 {
                noisily display as error "compete() evaluates to missing for `r(N)' observations"
                exit 416
            }
            quietly count if `_cexp' != 0 & _d == 1
            if r(N) > 0 {
                noisily display as error "compete() is true on `r(N)' records that are also stset failures; an event cannot be both the failure of interest and the competing event"
                exit 459
            }
            local _st_exit : char _dta[st_exit]
            local _st_exexp : char _dta[st_exexp]
            local _st_bt : char _dta[st_bt]
            local _cut ""
            if `"`_st_exit'"' != "" & `"`_st_exit'"' != "failure" {
                if substr(`"`_st_exit'"', 1, 5) == "time " & `"`_st_exexp'"' != "" {
                    local _cut `"& !(`_st_bt' > (`_st_exexp'))"'
                }
                else {
                    noisily display as error `"compete() supports stset exit() only in the form exit(time exp); found exit(`_st_exit')"'
                    exit 198
                }
            }
            quietly replace `km_comp' = 1 if _d == 0 & `_cexp' != 0 `_cut'
            local _st_id_c : char _dta[st_id]
            if `"`_st_id_c'"' != "" {
                tempvar _cnext
                quietly bysort `_st_id_c' (_t0 _t): gen byte `_cnext' = ///
                    (_n < _N & _t0[_n + 1] <= _t)
                quietly count if `km_comp' & `_cnext'
                if r(N) > 0 {
                    noisily display as error "compete() is true on `r(N)' records that are followed by further follow-up for the same `_st_id_c'; a competing event must end follow-up"
                    exit 459
                }
                drop `_cnext'
            }
            drop `_cexp'
            quietly count if `km_comp'
            local n_compete = r(N)
        }

        * =========================================================================
        * GENERATE KM ESTIMATES
        * =========================================================================

        if `has_compete' {
            local _st_wv : char _dta[st_wv]
            local _cif_w ""
            if `"`_st_wv'"' != "" local _cif_w "wvar(`_st_wv')"
            local _cif_se ""
            if !inlist("`st_wt'", "pweight", "iweight") local _cif_se "se(`km_se')"
            _kmplot_cif, grpvar(`grpid') compvar(`km_comp') ///
                generate(`km_s') sall(`km_sall') `_cif_se' `_cif_w'
            capture confirm variable `km_se'
            if _rc quietly gen double `km_se' = .
        }
        else if `ngroups' > 1 {
            quietly sts generate `km_s' = s, by(`grpid')
            if !`is_pweight' quietly sts generate `km_se' = se(s), by(`grpid')
        }
        else {
            quietly sts generate `km_s' = s
            if !`is_pweight' quietly sts generate `km_se' = se(s)
        }

        if `is_pweight' & !`has_compete' quietly gen double `km_se' = .
        * sts generate carries the last Greenwood SE onto rows where S has
        * reached 0; -sts list- reports no SE there, and neither do we.
        quietly replace `km_se' = . if `km_s' == 0

        * Handle all-censored groups (no events -> S = 1)
        forvalues g = 1/`ngroups' {
            quietly count if `grpid' == `g' & !missing(`km_s')
            if r(N) == 0 {
                quietly replace `km_s' = 1 if `grpid' == `g'
            }
        }

        * =========================================================================
        * CONFIDENCE INTERVALS
        * =========================================================================

        if "`ci'" != "" & `has_compete' {
            quietly {
                gen double `km_lb' = .
                gen double `km_ub' = .
                * Bounds for the cumulative incidence F exist where 0 < F < 1.
                * loglog is the ln(-ln F) interval of stcompet (Choudhury 2002,
                * eq. 4): F^exp(-/+ z se / (F ln F)).
                local _fok "`km_s' > 0 & `km_s' < 1 & `km_se' > 0 & !missing(`km_se')"
                if "`citransform'" == "loglog" {
                    replace `km_lb' = `km_s' ^ exp(-`zcrit' * `km_se' / ///
                        (`km_s' * log(`km_s'))) if `_fok'
                    replace `km_ub' = `km_s' ^ exp(`zcrit' * `km_se' / ///
                        (`km_s' * log(`km_s'))) if `_fok'
                }
                else if "`citransform'" == "log" {
                    replace `km_lb' = `km_s' * exp(-`zcrit' * `km_se' / `km_s') if `_fok'
                    replace `km_ub' = `km_s' * exp(`zcrit' * `km_se' / `km_s') if `_fok'
                }
                else {
                    replace `km_lb' = `km_s' - `zcrit' * `km_se' if `_fok'
                    replace `km_ub' = `km_s' + `zcrit' * `km_se' if `_fok'
                }
                replace `km_lb' = 0 if `km_lb' < 0 & !missing(`km_lb')
                replace `km_ub' = 1 if `km_ub' > 1 & !missing(`km_ub')
            }
        }
        else if "`ci'" != "" {
            quietly {
                gen double `km_lb' = .
                gen double `km_ub' = .
                * Bounds exist only where 0 < S(t) < 1.  At S = 1 (before the
                * first event, and the time-zero anchor) and at S = 0 they stay
                * missing under every transform, as in -sts list-.

                if "`citransform'" == "loglog" {
                    * Log-log transformation (Stata default)
                    replace `km_lb' = exp(-exp(log(-log(`km_s')) + ///
                        `zcrit' * `km_se' / ///
                        (`km_s' * abs(log(`km_s'))))) ///
                        if `km_s' > 0 & `km_s' < 1 & `km_se' > 0
                    replace `km_ub' = exp(-exp(log(-log(`km_s')) - ///
                        `zcrit' * `km_se' / ///
                        (`km_s' * abs(log(`km_s'))))) ///
                        if `km_s' > 0 & `km_s' < 1 & `km_se' > 0
                }
                else if "`citransform'" == "log" {
                    replace `km_lb' = `km_s' * ///
                        exp(-`zcrit' * `km_se' / `km_s') ///
                        if `km_s' > 0 & `km_s' < 1 & `km_se' > 0
                    replace `km_ub' = `km_s' * ///
                        exp(`zcrit' * `km_se' / `km_s') ///
                        if `km_s' > 0 & `km_s' < 1 & `km_se' > 0
                }
                else {
                    * Plain (untransformed)
                    replace `km_lb' = `km_s' - `zcrit' * `km_se' ///
                        if `km_s' > 0 & `km_s' < 1 & `km_se' > 0
                    replace `km_ub' = `km_s' + `zcrit' * `km_se' ///
                        if `km_s' > 0 & `km_s' < 1 & `km_se' > 0
                }

                * Clamp to [0, 1]
                replace `km_lb' = 0 if `km_lb' < 0 & !missing(`km_lb')
                replace `km_ub' = 1 if `km_ub' > 1 & !missing(`km_ub')
            }
        }

        * =========================================================================
        * FAILURE MODE (invert S -> 1-S)
        * =========================================================================

        if "`failure'" != "" & !`has_compete' {
            quietly replace `km_s' = 1 - `km_s' if !missing(`km_s')
            if "`ci'" != "" {
                quietly {
                    gen double `km_tmp' = 1 - `km_lb'
                    replace `km_lb' = 1 - `km_ub'
                    replace `km_ub' = `km_tmp'
                    drop `km_tmp'
                }
            }
        }

        * =========================================================================
        * CENSOR MARKS
        * =========================================================================

        if "`censor'" != "" | `"`saving'"' != "" {
            local _st_id : char _dta[st_id]
            if `"`_st_id'"' != "" {
                tempvar km_continues
                quietly bysort `_st_id' (_t0 _t): gen byte `km_continues' = ///
                    (_n < _N & _t0[_n + 1] <= _t & ///
                    `grpid'[_n + 1] == `grpid')
                quietly gen byte `km_cens' = ///
                    (_d == 0 & !`km_comp' & `km_continues' == 0 & !missing(`km_s'))
            }
            else {
                quietly gen byte `km_cens' = (_d == 0 & !`km_comp' & !missing(`km_s'))
            }
            if "`censor'" != "" & `censorthin' > 1 {
                tempvar _ccnt
                quietly bysort `grpid' (_t) : gen double `_ccnt' = ///
                    sum(`km_cens') if `km_cens' == 1
                quietly replace `km_cens' = 0 ///
                    if `km_cens' == 1 & mod(`_ccnt', `censorthin') != 0
            }
        }

        * =========================================================================
        * RISK TABLE (compute before adding anchors)
        * =========================================================================

        * =========================================================================
        * Y AXIS: automatic range, or the numeric positions of a user ylabel()
        * =========================================================================

        local ylab_auto ""
        local ylab_ok = 0
        local ylab_lo = 0
        local ylab_hi = `plot_scale'
        quietly summarize `km_s' if _t <= `tmax', meanonly
        local _ytop = cond(r(N) > 0, r(max), 0)
        if "`ci'" != "" {
            quietly summarize `km_ub' if _t <= `tmax', meanonly
            if r(N) > 0 local _ytop = max(`_ytop', r(max))
        }
        if "`failure'" == "" local _ytop = 1
        if "`median'" != "" local _ytop = max(`_ytop', 0.5)
        local _ytop = `_ytop' * `plot_scale'
        * ymax() can only widen the axis (Stata never clips), so a limit below
        * what is drawn is refused rather than reported as the axis used.
        if `ymax_user' < . & `_ytop' - `ymax_user' > 1e-12 * max(1, `_ytop') {
            local _ytop_s = strtrim(string(`_ytop', "%12.0g"))
            local _yscale_s = cond(`plot_scale' == 100, " on the percent scale", "")
            noisily display as error "ymax(`ymax_user') is below the plotted maximum, `_ytop_s'`_yscale_s' (curves, drawn confidence limits, and median lines up to tmax())"
            exit 198
        }
        if `"`ylabel'"' == "" {
            if "`failure'" == "" & `ymax_user' >= . {
                if `plot_scale' == 100 {
                    local ylab_auto "0(25)100, format(%3.0f) angle(0) nogrid"
                }
                else {
                    local ylab_auto "0(0.25)1, format(%4.2f) angle(0) nogrid"
                }
            }
            else {
                if `ymax_user' < . local _ytop = `ymax_user'
                if !(`_ytop' > 0) local _ytop = `plot_scale'
                _natscale 0 `_ytop' 5
                local _ydelta = r(delta)
                if `ymax_user' < . {
                    local _yhi = `ymax_user'
                }
                else {
                    local _yhi = `_ydelta' * ceil(`_ytop' / `_ydelta' - 1e-9)
                }
                local _ydec = 0
                while `_ydec' < 8 & ///
                    abs(`_ydelta' * 10^`_ydec' - round(`_ydelta' * 10^`_ydec')) > 1e-6 {
                    local ++_ydec
                }
                local _yint = max(1, floor(log10(max(`_yhi', 1))) + 1)
                local _ywid = `_yint' + `_ydec' + (`_ydec' > 0)
                local _yhi_s = strtrim(string(`_yhi', "%12.0g"))
                local _ydel_s = strtrim(string(`_ydelta', "%12.0g"))
                local ylab_auto "0(`_ydel_s')`_yhi_s', format(%`_ywid'.`_ydec'f) angle(0) nogrid"
                local ylab_hi = `_yhi'
            }
            local ylab_ok = 1
            local ymax_used = `ylab_hi'
        }
        else {
            _kmplot_ylabnums `ylabel'
            if `_km_yl_ok' {
                local ylab_ok = 1
                local ylab_lo = `_km_yl_lo'
                local ylab_hi = `_km_yl_hi'
            }
            else {
                local ylab_lo = 0
                local ylab_hi = `_ytop'
                if !(`ylab_hi' > `ylab_lo') local ylab_hi = `plot_scale'
            }
            local ymax_used = max(`ylab_hi', `_ytop')
            if `ymax_user' < . local ymax_used = max(`ylab_hi', `ymax_user')
        }

        local need_risktable_data = ("`risktable'" != "" | `"`risksaving'"' != "")
        if `need_risktable_data' {
            * Store group labels in dataset characteristics
            forvalues g = 1/`ngroups' {
                char _dta[_kmplot_grplbl`g'] `"`grplbl`g''"'
            }

            * If the user supplies explicit x-axis positions with risktable(),
            * use them as the default risk-table timepoints so counts and labels align.
            if "`timepoints'" == "" & `"`xlabel'"' != "" {
                local _rt_posspec `"`xlabel'"'
                local _comma = strpos(`"`_rt_posspec'"', ",")
                if `_comma' > 0 {
                    local _rt_posspec = strtrim(substr(`"`_rt_posspec'"', 1, `_comma' - 1))
                }
                capture _kmplot_times, values(`"`_rt_posspec'"')
                if _rc == 0 {
                    local timepoints `r(times)'
                }
            }

            local tp_opt ""
            if "`timepoints'" != "" {
                local tp_opt "timepoints(`timepoints')"
            }
            local rt_height_opt "riskheight(`riskheight')"
            local rt_xtitle_opt ""
            if `"`macval(xtitle)'"' != "" {
                local rt_xtitle_opt xtitle(`"`macval(xtitle)'"')
            }
            local rt_xlabel_opt ""
            if `"`xlabel'"' != "" {
                local rt_xlabel_opt xlabel(`xlabel')
            }
            local rt_ylabel_opt ""
            if `"`ylabel'"' != "" {
                local rt_ylabel_opt ylabel(`ylabel')
            }
            else {
                local rt_ylabel_opt ylabel(`ylab_auto')
            }

            * Reload the installed helper so an older in-memory definition cannot
            * survive a package update and mix layouts with the current command.
            capture findfile _kmplot_risktable.ado
            if _rc {
                noisily display as error "_kmplot_risktable.ado not found; reinstall kmplot"
                exit 111
            }
            local rt_helper_file `"`r(fn)'"'
            capture program drop _kmplot_risktable
            run `"`rt_helper_file'"'

            * riskcompact is a synonym for riskevents
            local rt_flags ""
            if "`riskcompact'" != "" | "`riskevents'" != "" {
                local rt_flags "`rt_flags' events"
            }
            if "`riskmono'" != "" local rt_flags "`rt_flags' mono"
            local rt_ylabhi_opt ""
            if `ylab_ok' local rt_ylabhi_opt "ylabhi(`ylab_hi')"
            local rt_mask_opt ""
            if `riskmask_k' > 0 {
                local rt_mask_opt `"mask(`riskmask_k') masktext(`riskmask_text')"'
            }

            _kmplot_risktable, grpvar(`grpid') ngroups(`ngroups') ///
                colors(`colors') scheme(`scheme') xmax(`tmax') `tp_opt' ///
                graphname(`_kmplot_risk_graph') ///
                `macval(rt_xtitle_opt)' `rt_xlabel_opt' `rt_ylabel_opt' ///
                `rt_height_opt' `rt_flags' ///
                compvar(`km_comp') riskweight(`riskweight') `rt_mask_opt' ///
                regionopts(`macval(_km_region_only)') `rt_ylabhi_opt' ///
                callerversion("1.0.0") toptimeaxis
            matrix `risktable_mat' = r(risktable)
            matrix `risktable_w_mat' = r(risktable_w)
            matrix `risktable_f_mat' = r(risktable_flag)
            local has_risktable_mat = 1
            local risk_timepoints "`r(timepoints)'"
            local n_timepoints = r(n_timepoints)
            * The height applies only to a drawn table; risksaving() alone
            * draws none, so no height is reported.
            if "`risktable'" != "" local riskheight_used = r(riskheight)
            local risk_plot_left = r(plot_margin_left)
            local risk_plot_right = r(plot_margin_right)
            local risk_row_offset = r(row_offset)
            local risk_row_labgap = r(row_labgap)
            local risk_title_gap = r(title_gap)
            * A helper left over in memory from an older install returns
            * fewer scalars; the layout options would then be built with
            * missing values and Stata would warn about gsize(.) rather
            * than fail.  Refuse the plot instead.
            if missing(`risk_plot_left', `risk_plot_right', ///
                `risk_row_offset', `risk_row_labgap', `risk_title_gap') {
                noisily display as error "kmplot installation contains inconsistent command and helper versions; reinstall kmplot"
                exit 498
            }
        }

        * =========================================================================
        * ADD TIME-ZERO ANCHORS
        * =========================================================================

        quietly gen byte `km_anchor' = 0
        local N_cur = _N
        quietly set obs `=`N_cur' + `ngroups''

        forvalues g = 1/`ngroups' {
            local row = `N_cur' + `g'
            quietly replace `grpid' = `g' in `row'
            quietly replace _t = 0 in `row'
            if "`failure'" != "" {
                quietly replace `km_s' = 0 in `row'
            }
            else {
                quietly replace `km_s' = 1 in `row'
            }
            if "`censor'" != "" {
                quietly replace `km_cens' = 0 in `row'
            }
            if `"`saving'"' != "" & "`censor'" == "" {
                quietly replace `km_cens' = 0 in `row'
            }
            quietly replace `km_anchor' = 1 in `row'
            if `has_compete' quietly replace `km_sall' = 1 in `row'
        }

        sort `grpid' _t

        * tmax(): carry each curve that continues past tmax() to exactly
        * tmax() with a plot-only row (dropped before saving()), and draw
        * nothing beyond it.
        tempvar km_tend km_inplot km_obs_t
        quietly gen byte `km_tend' = 0
        if `tmax_user' < . {
            quietly gen long `km_obs_t' = _n
            local _N_t = _N
            forvalues g = 1/`ngroups' {
                quietly count if `grpid' == `g' & `km_anchor' == 0 & _t > `tmax_user'
                if r(N) == 0 continue
                quietly summarize `km_obs_t' if `grpid' == `g' & ///
                    _t <= `tmax_user' & !missing(`km_s'), meanonly
                if r(N) == 0 continue
                local _src = r(max)
                local ++_N_t
                quietly set obs `_N_t'
                quietly replace `grpid' = `g' in `_N_t'
                quietly replace _t = `tmax_user' in `_N_t'
                foreach _v in `km_s' `km_se' `km_lb' `km_ub' `km_sall' {
                    capture confirm variable `_v'
                    if _rc == 0 quietly replace `_v' = `_v'[`_src'] in `_N_t'
                }
                capture confirm variable `km_cens'
                if _rc == 0 quietly replace `km_cens' = 0 in `_N_t'
                quietly replace `km_anchor' = 0 in `_N_t'
                quietly replace `km_tend' = 1 in `_N_t'
            }
            drop `km_obs_t'
            sort `grpid' _t `km_tend'
            quietly gen byte `km_inplot' = (_t <= `tmax_user')
        }
        else {
            quietly gen byte `km_inplot' = 1
        }

        * =========================================================================
        * LANDMARK ESTIMATES
        * =========================================================================

        if "`landmark'" != "" {
            tempvar km_lm_obs
            quietly gen long `km_lm_obs' = _n
            local n_landmarks : word count `landmark'
            matrix `landmarks_mat' = J(`=`ngroups' * `n_landmarks'', 5, .)
            matrix colnames `landmarks_mat' = group time estimate lower upper
            local _lm_row = 0
            forvalues g = 1/`ngroups' {
                quietly summarize _t if `grpid' == `g' & `km_anchor' == 0, meanonly
                tempname lm_max
                scalar `lm_max' = r(max)
                foreach tp of local landmark {
                    local ++_lm_row
                    matrix `landmarks_mat'[`_lm_row', 1] = `g'
                    matrix `landmarks_mat'[`_lm_row', 2] = `tp'
                    quietly summarize `km_lm_obs' if `grpid' == `g' & ///
                        _t <= `tp' & !missing(`km_s'), meanonly
                    if r(N) > 0 {
                        local _lm_obs = r(max)
                        * Past the group's last time the curve is known only
                        * if it has reached its end state: S = 0 (F = 1), or
                        * all-cause survival 0 for a cumulative incidence.
                        if `has_compete' {
                            if `tp' > scalar(`lm_max') & ///
                                `km_sall'[`_lm_obs'] != 0 continue
                        }
                        else if `tp' > scalar(`lm_max') & ///
                            `km_s'[`_lm_obs'] != ("`failure'" != "") continue
                        matrix `landmarks_mat'[`_lm_row', 3] = `km_s'[`_lm_obs']
                        if "`ci'" != "" {
                            if !missing(`km_lb'[`_lm_obs']) {
                                matrix `landmarks_mat'[`_lm_row', 4] = `km_lb'[`_lm_obs']
                            }
                            if !missing(`km_ub'[`_lm_obs']) {
                                matrix `landmarks_mat'[`_lm_row', 5] = `km_ub'[`_lm_obs']
                            }
                        }
                    }
                }
            }
            local has_landmarks_mat = 1
        }

        * =========================================================================
        * COMPUTE MEDIANS
        * =========================================================================

        forvalues g = 1/`ngroups' {
            local median_`g' = .
        }

        if "`median'" != "" {
            local med_tol = sqrt(c(epsdouble))
            forvalues g = 1/`ngroups' {
                * With tied times the product-limit value can land a rounding
                * error above 0.5 where it is exactly 0.5, so compare within
                * R survival's quantile tolerance, sqrt(double epsilon).
                if "`failure'" != "" {
                    * CIF: first time where F(t) >= 0.5
                    quietly summarize _t if `grpid' == `g' & ///
                        `km_s' >= 0.5 - `med_tol' & !missing(`km_s') & _t > 0
                }
                else {
                    * Survival: first time where S(t) <= 0.5
                    quietly summarize _t if `grpid' == `g' & ///
                        `km_s' <= 0.5 + `med_tol' & !missing(`km_s') & _t > 0
                }
                if r(N) > 0 {
                    local median_`g' = r(min)
                }
            }
            matrix `medians_mat' = J(`ngroups', 2, .)
            matrix colnames `medians_mat' = group median
            forvalues g = 1/`ngroups' {
                matrix `medians_mat'[`g', 1] = `g'
                matrix `medians_mat'[`g', 2] = `median_`g''
            }
            local has_medians_mat = 1
        }

        * Median annotation note: "Median: x" for one group, and
        * "Median: label: x; label: y" when by() is used
        local med_note ""
        if "`median'" != "" & "`medianannotate'" != "" {
            local med_parts ""
            forvalues g = 1/`ngroups' {
                if `median_`g'' < . {
                    local mfmt : display `median_format' `median_`g''
                    local mfmt = strtrim("`mfmt'")
                }
                else {
                    local mfmt "NR"
                }
                if `ngroups' > 1 {
                    local med_sep ""
                    if `g' > 1 local med_sep "; "
                    local med_parts `"`med_parts'`med_sep'`grplbl`g'': `mfmt'"'
                }
                else {
                    local med_parts "`mfmt'"
                }
            }
            local med_note `"Median: `med_parts'"'
        }

        * =========================================================================
        * STEPPED CONFIDENCE-BAND COORDINATES
        * =========================================================================
        * rarea interpolates linearly between points and would cut diagonally across
        * the KM step function. Build explicit stepped coordinates in dedicated
        * columns so the shaded band tracks the staircase: at each event time carry
        * the previous bound forward (horizontal segment), then step to the new
        * bound (vertical riser). Drawn in data order (no sort).

        * Drawn bounds.  The stored bounds stay missing where the curve has
        * reached S = 0 (F = 1 in failure mode), as in -sts list-, but the
        * interval on [t(k-1), t(k)) belongs to S(t(k-1)) > 0.  As -sts graph-
        * does, the drawn band and CI lines carry the last bounds to the time
        * the curve reaches 0, so they end where the curve ends.
        tempvar km_y
        quietly gen double `km_y' = `km_s' * `plot_scale'
        if "`ci'" != "" {
            tempvar plb pub cseen cend cendn cendt clb cub
            quietly {
                gen double `plb' = `km_lb'
                gen double `pub' = `km_ub'
                local s_end = cond("`failure'" != "", 1, 0)
                bysort `grpid' (_t): gen long `cseen' = ///
                    sum(!missing(`km_lb', `km_ub'))
                by `grpid': gen byte `cend' = (`km_s' == `s_end' & ///
                    missing(`km_lb', `km_ub') & `cseen' > 0)
                by `grpid': gen long `cendn' = sum(`cend')
                by `grpid': gen double `cendt' = _t if `cend' & `cendn' == 1
                by `grpid': replace `cendt' = `cendt'[_n - 1] if missing(`cendt')
                gen double `clb' = `km_lb'
                gen double `cub' = `km_ub'
                by `grpid': replace `clb' = `clb'[_n - 1] if missing(`clb')
                by `grpid': replace `cub' = `cub'[_n - 1] if missing(`cub')
                replace `plb' = `clb' if `cend' & _t == `cendt'
                replace `pub' = `cub' if `cend' & _t == `cendt'
                drop `cseen' `cend' `cendn' `cendt' `clb' `cub'
                replace `plb' = `plb' * `plot_scale'
                replace `pub' = `pub' * `plot_scale'
            }
        }

        if "`ci'" != "" & "`cistyle'" == "band" {
            tempvar bgrp btime blo bhi btag
            * Use source row indices; event times and bounds never pass through text.
            quietly bysort `grpid' _t: gen byte `btag' = ///
                (_n == 1 & !missing(`plb', `pub') & `km_inplot' == 1)
            quietly count if `btag'
            local band_pts = 2 * r(N)
            if `band_pts' > 0 {
                local _bbase = _N
                quietly set obs `=`_bbase' + `band_pts''
                quietly gen double `btime' = .
                quietly gen double `blo' = .
                quietly gen double `bhi' = .
                quietly gen long `bgrp' = .
                local _br = `_bbase'
                local _prev = 0
                forvalues _src = 1/`_bbase' {
                    if `btag'[`_src'] != 1 continue
                    local ++_br
                    quietly replace `bgrp' = `grpid'[`_src'] in `_br'
                    quietly replace `btime' = _t[`_src'] in `_br'
                    local _carry = `_src'
                    if `_prev' > 0 {
                        if `grpid'[`_prev'] == `grpid'[`_src'] local _carry = `_prev'
                    }
                    quietly replace `blo' = `plb'[`_carry'] in `_br'
                    quietly replace `bhi' = `pub'[`_carry'] in `_br'
                    local ++_br
                    quietly replace `bgrp' = `grpid'[`_src'] in `_br'
                    quietly replace `btime' = _t[`_src'] in `_br'
                    quietly replace `blo' = `plb'[`_src'] in `_br'
                    quietly replace `bhi' = `pub'[`_src'] in `_br'
                    local _prev = `_src'
                }
                local has_stepband = 1
            }
        }

        * =========================================================================
        * BUILD TWOWAY COMMAND
        * =========================================================================

        local tw_layers ""
        local legend_offset = 0

        * --- CI bands (behind everything); stepped to track the KM staircase ---
        if "`ci'" != "" & "`cistyle'" == "band" & `has_stepband' {
            forvalues g = 1/`ngroups' {
                local colidx = mod(`g' - 1, `ncolors') + 1
                local col : word `colidx' of `colors'
                if "`col'" == "" local col "black"
                * ciopacity() sets the band's opacity; drop any opacity the
                * user gave the line colour so the two are not stacked.
                local bcol = regexr("`col'", "%[0-9.]*$", "")
                local tw_layers `"`macval(tw_layers)' (rarea `bhi' `blo' `btime' if `bgrp' == `g', fcolor("`bcol'%`ciopacity'") lwidth(none))"'
            }
            local legend_offset = `ngroups'
        }

        * --- KM step lines ---
        forvalues g = 1/`ngroups' {
            local colidx = mod(`g' - 1, `ncolors') + 1
            local col : word `colidx' of `colors'
            if "`col'" == "" local col "black"
            local npatterns : word count `lpattern'
            if `npatterns' > 0 {
                local patidx = mod(`g' - 1, `npatterns') + 1
                local pat : word `patidx' of `lpattern'
            }
            else {
                local pat "solid"
            }
            local tw_layers `"`macval(tw_layers)' (line `km_y' _t if `grpid' == `g' & !missing(`km_y') & `km_inplot' == 1, lcolor("`col'") lwidth(`lwidth') lpattern(`pat') sort connect(J))"'
        }

        * --- CI lines (alternative to bands) ---
        if "`ci'" != "" & "`cistyle'" == "line" {
            forvalues g = 1/`ngroups' {
                local colidx = mod(`g' - 1, `ncolors') + 1
                local col : word `colidx' of `colors'
                if "`col'" == "" local col "black"
                local tw_layers `"`macval(tw_layers)' (line `plb' _t if `grpid' == `g' & !missing(`plb') & `km_inplot' == 1, lcolor("`col'") lwidth(thin) lpattern(dash) sort connect(J))"'
                local tw_layers `"`macval(tw_layers)' (line `pub' _t if `grpid' == `g' & !missing(`pub') & `km_inplot' == 1, lcolor("`col'") lwidth(thin) lpattern(dash) sort connect(J))"'
            }
        }

        * --- Censor marks ---
        if "`censor'" != "" {
            forvalues g = 1/`ngroups' {
                local colidx = mod(`g' - 1, `ncolors') + 1
                local col : word `colidx' of `colors'
                if "`col'" == "" local col "black"
                local tw_layers `"`macval(tw_layers)' (scatter `km_y' _t if `grpid' == `g' & `km_cens' == 1 & `km_inplot' == 1, msymbol(pipe) mcolor("`col'") msize(medsmall))"'
            }
        }

        * --- Median reference lines ---
        if "`median'" != "" {
            * Single subtle horizontal reference at y=0.5
            local any_med = 0
            local max_med = 0
            forvalues g = 1/`ngroups' {
                if `median_`g'' < . {
                    local any_med = 1
                    if `median_`g'' > `max_med' local max_med = `median_`g''
                }
            }
            if `any_med' {
                * Thin horizontal line from x=0 to just past the rightmost median
                local tw_layers `"`macval(tw_layers)' (pci `=0.5 * `plot_scale'' 0 `=0.5 * `plot_scale'' `=`max_med' * 1.05', lcolor(gs12) lpattern(shortdash) lwidth(vthin))"'
            }
            * Short vertical drop at each group's median
            forvalues g = 1/`ngroups' {
                if `median_`g'' < . {
                    local colidx = mod(`g' - 1, `ncolors') + 1
                    local col : word `colidx' of `colors'
                    if "`col'" == "" local col "black"
                    local tw_layers `"`macval(tw_layers)' (pci 0 `median_`g'' `=0.5 * `plot_scale'' `median_`g'', lcolor("`col'") lpattern(shortdash) lwidth(vthin))"'
                }
            }
        }

        * --- Legend ---
        if `ngroups' == 1 & `"`legend'"' == "" {
            local legend_cmd "legend(off)"
        }
        else if `"`legend'"' != "" {
            local legend_cmd `"legend(`legend')"'
        }
        else {
            local legend_items ""
            forvalues g = 1/`ngroups' {
                local elem = `legend_offset' + `g'
                local legend_items `"`legend_items' `elem' `"`grplbl`g''"'"'
            }
            local legend_cmd `"legend(order(`legend_items') cols(1) position(1) ring(0) size(vsmall) region(lcolor(none) fcolor(none)) symxsize(8) keygap(1))"'
        }

        * Graph's internal parser expands macros again. Encode macro delimiters
        * only in graph copies; the returned labels retain the original bytes.
        foreach _label in title subtitle xtitle ytitle note pval_text {
            mata: st_local("_plot_"+st_local("_label"), subinstr(subinstr(st_local(st_local("_label")), char(96), "{c 96}"), char(36), "{c 36}"))
        }

        * --- Global options ---
        local tw_opts ""

        if `"`macval(_plot_title)'"' != "" {
            local tw_opts `"`macval(tw_opts)' title(`"`macval(_plot_title)'"', size(medium))"'
        }
        if `"`macval(_plot_subtitle)'"' != "" {
            local tw_opts `"`macval(tw_opts)' subtitle(`"`macval(_plot_subtitle)'"', size(small))"'
        }
        * With a risk table the y title carries the same right margin as the risk
        * panel's, so the two label columns start at the same place.
        local ytitle_margin ""
        if "`risktable'" != "" {
            local ytitle_margin "margin(r=`risk_title_gap')"
        }
        local tw_opts `"`macval(tw_opts)' xtitle(`"`macval(_plot_xtitle)'"', size(small)) ytitle(`"`macval(_plot_ytitle)'"', size(small) `ytitle_margin')"'

        if `"`ylabel'"' != "" {
            local tw_opts `"`macval(tw_opts)' ylabel(`ylabel')"'
        }
        else {
            local tw_opts `"`macval(tw_opts)' ylabel(`ylab_auto')"'
        }
        if `ymax_user' < . {
            local tw_opts `"`macval(tw_opts)' yscale(range(0 `ymax_user'))"'
        }
        if `tmax_user' < . & "`risktable'" == "" {
            local tw_opts `"`macval(tw_opts)' xscale(range(0 `tmax_user'))"'
        }

        if `"`xlabel'"' != "" & "`risktable'" == "" {
            local tw_opts `"`macval(tw_opts)' xlabel(`xlabel')"'
        }

        * Note
        if `"`macval(_plot_note)'"' != "" {
            local tw_opts `"`macval(tw_opts)' note(`"`macval(_plot_note)'"', size(vsmall))"'
        }
        else if "`med_note'" != "" & "`risktable'" == "" {
            * Only show median note when no risktable (avoids clutter between graphs)
            local tw_opts `"`macval(tw_opts)' note(`"`med_note'"', size(vsmall) color(gs5))"'
        }

        * P-value text annotation
        if `"`macval(_plot_pval_text)'"' != "" {
            if `"`pvalueat'"' != "" {
                local p_place "`pvalue_place'"
                local p_y = `pvalue_y'
                local p_x = `pvalue_x'
            }
            else {
                * Keyword positions sit 5% inside the drawn y range, with the
                * text growing away from the nearer x axis edge.  text() at a
                * coordinate outside the axis range is not drawn, and
                * ylabel()/yscale(range()) can only widen that range, so the
                * union of the plotted values and the ylabel() numlist is
                * always on the axis.
                quietly summarize `km_y' if `km_inplot' == 1, meanonly
                local p_ylo = r(min)
                local p_yhi = r(max)
                local p_yvars ""
                if "`ci'" != "" & "`cistyle'" == "band" & `has_stepband' {
                    local p_yvars "`blo' `bhi'"
                }
                else if "`ci'" != "" & "`cistyle'" == "line" {
                    local p_yvars "`plb' `pub'"
                }
                foreach _pv of local p_yvars {
                    quietly summarize `_pv', meanonly
                    if r(N) > 0 {
                        local p_ylo = min(`p_ylo', r(min))
                        local p_yhi = max(`p_yhi', r(max))
                    }
                }
                if "`median'" != "" {
                    if `any_med' {
                        local p_ylo = min(`p_ylo', 0)
                        local p_yhi = max(`p_yhi', 0.5 * `plot_scale')
                    }
                }
                local p_lab_ok = `ylab_ok'
                local p_lab_lo = `ylab_lo'
                local p_lab_hi = `ylab_hi'
                if `p_lab_ok' {
                    local p_ylo = min(`p_ylo', `p_lab_lo')
                    local p_yhi = max(`p_yhi', `p_lab_hi')
                }
                if !(`p_yhi' > `p_ylo') {
                    local p_ylo = min(`p_ylo', 0)
                    local p_yhi = max(`p_yhi', `plot_scale')
                }
                local p_ytop = `p_yhi' - 0.05 * (`p_yhi' - `p_ylo')
                local p_ybot = `p_ylo' + 0.05 * (`p_yhi' - `p_ylo')
                if "`pvaluepos'" == "topleft" {
                    local p_y = `p_ytop'
                    local p_x = `tmax' * 0.05
                    local p_place "e"
                }
                else if "`pvaluepos'" == "bottomleft" {
                    local p_y = `p_ybot'
                    local p_x = `tmax' * 0.05
                    local p_place "ne"
                }
                else if "`pvaluepos'" == "bottomright" {
                    local p_y = `p_ybot'
                    local p_x = `tmax' * 0.98
                    local p_place "nw"
                }
                else {
                    * topright (fallthrough)
                    local p_y = `p_ytop'
                    local p_x = `tmax' * 0.95
                    local p_place "w"
                }
                local pvalue_y = `p_y'
                local pvalue_x = `p_x'
                local pvalue_place "`p_place'"
            }
            local tw_opts `"`macval(tw_opts)' text(`p_y' `p_x' `"`macval(_plot_pval_text)'"', placement(`p_place') size(vsmall) color(gs5))"'
        }

        if "`aspectratio'" != "" {
            local tw_opts `"`macval(tw_opts)' aspectratio(`aspectratio')"'
        }

        local tw_opts `"`macval(tw_opts)' scheme(`scheme') `legend_cmd'"'

        * Passthrough options
        if `"`options'"' != "" {
            local tw_opts `"`macval(tw_opts)' `options'"'
        }

        * =========================================================================
        * EXECUTE PLOT
        * =========================================================================

        if "`risktable'" != "" {
            * Match the risk panel's axis and plot-region geometry.  Invisible
            * labels reserve the same endpoint space while the visible labels sit
            * above the risk table.
            if `"`xlabel'"' != "" {
                if strpos(`"`xlabel'"', ",") {
                    local rt_main_xlabel xlabel(`xlabel' nogrid labcolor(none))
                }
                else {
                    local rt_main_xlabel xlabel(`xlabel', labsize(small) noticks nogrid labcolor(none))
                }
            }
            else {
                local rt_main_xlabel "xlabel(`risk_timepoints', labsize(small) noticks nogrid labcolor(none))"
            }
            * The risk panel prints the group labels in its y-axis label column.
            * Reserve exactly that width here with the same strings, drawn
            * invisibly, so both panels' label columns -- and therefore both time
            * axes -- come out identical without any tuned margin.  Positions are
            * placed inside the main y range at values a user's ylabel() will not
            * land on, since a collision would make ylabel(..., add) replace one
            * of the visible labels.
            local _gy_lo = `ylab_lo'
            local _gy_hi = `ylab_hi'
            if `_gy_hi' <= `_gy_lo' {
                local _gy_lo = 0
                local _gy_hi = `plot_scale'
            }
            local rt_grp_ylabels ""
            forvalues g = 1/`ngroups' {
                local _gy = `_gy_lo' + (0.37 + 0.0137 * `g') * (`_gy_hi' - `_gy_lo')
                local rt_grp_ylabels `"`rt_grp_ylabels' `_gy' `"`grplbl`g''"'"'
            }
            local rt_grp_ylabel_cmd `"ylabel(`rt_grp_ylabels', add custom angle(0) labsize(small) labgap(`risk_row_labgap') labcolor(none) tlcolor(none) nogrid)"'

            local rt_main_opts `"xtitle("") `rt_main_xlabel' `rt_grp_ylabel_cmd' xscale(range(0 `tmax') noextend) plotregion(margin(l=`risk_plot_left' r=`risk_plot_right' t=2 b=0)) graphregion(margin(l=0 t=0 b=0))"'
            twoway `macval(tw_layers)', `macval(tw_opts)' `rt_main_opts' ///
                nodraw name(`_kmplot_main_graph', replace)

            local combine_note `"note("")"'
            if `"`macval(_plot_note)'"' == "" & `"`med_note'"' != "" {
                local combine_note `"note(`"`med_note'"', size(vsmall) color(gs5))"'
            }
            * The user's region and size options also shape the combined
            * graph; combineopts() goes last, so it wins.
            graph combine `_kmplot_main_graph' `_kmplot_risk_graph', ///
                cols(1) xcommon ///
                imargin(0 0 0 0) ///
                name(`name', replace) ///
                scheme(`scheme') `macval(_km_region_opts)' `macval(combine_note)' ///
                `nodraw_opt' `macval(combineopts)'
        }
        else {
            twoway `macval(tw_layers)', `macval(tw_opts)' `nodraw_opt' name(`name', replace)
        }

        * Remove the stepped-band helper rows now that the graph is rendered,
        * so they never leak into saving()/risksaving() output.
        if `has_stepband' {
            quietly drop if !missing(`bgrp')
        }
        quietly drop if `km_tend' == 1

        * =========================================================================
        * EXPORT
        * =========================================================================

        if `"`export'"' != "" {
            local export_file `"`export'"'
            local export_opts ""
            local cpos = 0
            local _inquote = 0
            forvalues _pos = 1/`=strlen(`"`export'"')' {
                local _ch = substr(`"`export'"', `_pos', 1)
                if `"`_ch'"' == char(34) local _inquote = !`_inquote'
                if `"`_ch'"' == "," & !`_inquote' {
                    local cpos = `_pos'
                    continue, break
                }
            }
            if `cpos' > 0 {
                local export_file = strtrim(substr(`"`export'"', 1, `cpos' - 1))
                local export_opts = strtrim(substr(`"`export'"', `cpos' + 1, .))
            }
            local _ef_len = strlen(`"`export_file'"')
            if `_ef_len' >= 2 & ///
                substr(`"`export_file'"', 1, 1) == char(34) & ///
                substr(`"`export_file'"', `_ef_len', 1) == char(34) {
                local export_file = substr(`"`export_file'"', 2, `_ef_len' - 2)
            }
            foreach _bad_ascii in 34 36 38 39 59 60 62 96 124 {
                if strpos(`"`export_file'"', char(`_bad_ascii')) {
                    noisily display as error "export() path contains unsupported shell metacharacters or quote characters"
                    exit 198
                }
            }
            local export_as_opt ""
            local _export_dot = strrpos(`"`export_file'"', ".")
            if `_export_dot' > 0 & `_export_dot' < strlen(`"`export_file'"') & ///
                strpos(lower(`"`export_opts'"'), "as(") == 0 {
                local _export_suffix = lower(substr(`"`export_file'"', `_export_dot' + 1, .))
                if inlist("`_export_suffix'", "ps", "eps", "svg", "emf", "pdf", "png", "tif", "gif", "jpg") {
                    local export_as_opt "as(`_export_suffix')"
                }
            }
            capture noisily quietly graph export `"`export_file'"', ///
                name(`name') `export_as_opt' `export_opts'
            local _kmplot_side_rc = _rc
            if `_kmplot_side_rc' == 0 {
                capture confirm file `"`export_file'"'
            }
            if `_kmplot_side_rc' == 0 & _rc == 0 {
                display as text "Graph saved to: " as result `"`export_file'"'
            }
        }

        * =========================================================================
        * SAVE REUSABLE DATASETS
        * =========================================================================

        if `"`saving'"' != "" {
            local curve_file `"`saving'"'
            local curve_opts ""
            local cpos = 0
            local _inquote = 0
            forvalues _pos = 1/`=strlen(`"`curve_file'"')' {
                local _ch = substr(`"`curve_file'"', `_pos', 1)
                if `"`_ch'"' == char(34) local _inquote = !`_inquote'
                if `"`_ch'"' == "," & !`_inquote' {
                    local cpos = `_pos'
                    continue, break
                }
            }
            if `cpos' > 0 {
                local curve_opts = strtrim(substr(`"`curve_file'"', `cpos' + 1, .))
                local curve_file = strtrim(substr(`"`curve_file'"', 1, `cpos' - 1))
            }
            local _cf_len = strlen(`"`curve_file'"')
            if `_cf_len' >= 2 & ///
                substr(`"`curve_file'"', 1, 1) == char(34) & ///
                substr(`"`curve_file'"', `_cf_len', 1) == char(34) {
                local curve_file = substr(`"`curve_file'"', 2, `_cf_len' - 2)
            }
            if `"`curve_opts'"' != "" & lower(`"`curve_opts'"') != "replace" {
                noisily display as error "saving() only supports the replace suboption"
                exit 198
            }
            foreach _bad_ascii in 34 36 38 39 59 60 62 96 124 {
                if strpos(`"`curve_file'"', char(`_bad_ascii')) {
                    noisily display as error "saving() path contains unsupported shell metacharacters or quote characters"
                    exit 198
                }
            }
            capture confirm variable `km_lb'
            if _rc {
                quietly gen double `km_lb' = .
            }
            capture confirm variable `km_ub'
            if _rc {
                quietly gen double `km_ub' = .
            }
            keep `grpid' _t `km_s' `km_se' `km_lb' `km_ub' `km_cens' `km_anchor'
            rename `grpid' group
            rename _t time
            rename `km_s' estimate
            rename `km_se' se
            rename `km_lb' lower
            rename `km_ub' upper
            rename `km_cens' censor
            rename `km_anchor' anchor
            quietly gen str80 group_label = ""
            forvalues g = 1/`ngroups' {
                quietly replace group_label = `"`grplbl`g''"' if group == `g'
            }
            label variable group "KM group index"
            label variable group_label "KM group label"
            label variable time "Analysis time"
            if `has_compete' {
                label variable estimate "Aalen-Johansen cumulative incidence"
                label variable se "Standard error (Marubini-Valsecchi)"
            }
            else {
                label variable estimate "KM survival or cumulative failure estimate"
                label variable se "Greenwood standard error"
            }
            label variable lower "Lower confidence bound"
            label variable upper "Upper confidence bound"
            label variable censor "Displayed censor marker"
            label variable anchor "Time-zero anchor row"
            order group group_label time estimate se lower upper censor anchor
            if lower(`"`curve_opts'"') == "replace" {
                capture noisily quietly save `"`curve_file'"', replace
            }
            else {
                capture noisily quietly save `"`curve_file'"'
            }
            local _curve_save_rc = _rc
            if `_kmplot_side_rc' == 0 & `_curve_save_rc' != 0 {
                local _kmplot_side_rc = `_curve_save_rc'
            }
            if `_curve_save_rc' == 0 {
                local curve_saved `"`curve_file'"'
                display as text "Curve data saved to: " as result `"`curve_file'"'
            }
        }

        if `"`risksaving'"' != "" {
            local risk_file `"`risksaving'"'
            local risk_opts ""
            local cpos = 0
            local _inquote = 0
            forvalues _pos = 1/`=strlen(`"`risk_file'"')' {
                local _ch = substr(`"`risk_file'"', `_pos', 1)
                if `"`_ch'"' == char(34) local _inquote = !`_inquote'
                if `"`_ch'"' == "," & !`_inquote' {
                    local cpos = `_pos'
                    continue, break
                }
            }
            if `cpos' > 0 {
                local risk_opts = strtrim(substr(`"`risk_file'"', `cpos' + 1, .))
                local risk_file = strtrim(substr(`"`risk_file'"', 1, `cpos' - 1))
            }
            local _rf_len = strlen(`"`risk_file'"')
            if `_rf_len' >= 2 & ///
                substr(`"`risk_file'"', 1, 1) == char(34) & ///
                substr(`"`risk_file'"', `_rf_len', 1) == char(34) {
                local risk_file = substr(`"`risk_file'"', 2, `_rf_len' - 2)
            }
            if `"`risk_opts'"' != "" & lower(`"`risk_opts'"') != "replace" {
                noisily display as error "risksaving() only supports the replace suboption"
                exit 198
            }
            foreach _bad_ascii in 34 36 38 39 59 60 62 96 124 {
                if strpos(`"`risk_file'"', char(`_bad_ascii')) {
                    noisily display as error "risksaving() path contains unsupported shell metacharacters or quote characters"
                    exit 198
                }
            }
            clear
            quietly svmat double `risktable_mat', names(col)
            tempname _rt_extra
            matrix `_rt_extra' = `risktable_w_mat'
            if `riskmask_k' > 0 {
                matrix `_rt_extra' = `_rt_extra', `risktable_f_mat'
            }
            quietly svmat double `_rt_extra', names(col)
            quietly gen str80 group_label = ""
            forvalues g = 1/`ngroups' {
                quietly replace group_label = `"`grplbl`g''"' if group == `g'
            }
            local _rt_basis = cond("`riskweight'" == "stset", "summed stset weight", "people")
            label variable group "KM group index"
            label variable group_label "KM group label"
            label variable time "Analysis time"
            label variable at_risk "Number at risk (`_rt_basis')"
            label variable events "Cumulative events (`_rt_basis')"
            label variable censored "Cumulative censoring exits (`_rt_basis')"
            label variable at_risk_w "Number at risk (summed stset weight)"
            label variable events_w "Cumulative events (summed stset weight)"
            label variable censored_w "Cumulative censoring exits (summed stset weight)"
            local _rt_order "group group_label time at_risk events censored at_risk_w events_w censored_w"
            if `riskmask_k' > 0 {
                foreach _rv in at_risk events censored {
                    quietly recast byte `_rv'_masked
                    label variable `_rv'_masked "`_rv' masked by riskmask(`riskmask_k')"
                }
                local _rt_order "`_rt_order' at_risk_masked events_masked censored_masked"
            }
            order `_rt_order'
            if lower(`"`risk_opts'"') == "replace" {
                capture noisily quietly save `"`risk_file'"', replace
            }
            else {
                capture noisily quietly save `"`risk_file'"'
            }
            local _risk_save_rc = _rc
            if `_kmplot_side_rc' == 0 & `_risk_save_rc' != 0 {
                local _kmplot_side_rc = `_risk_save_rc'
            }
            if `_risk_save_rc' == 0 {
                local risk_saved `"`risk_file'"'
                display as text "Risk-table data saved to: " as result `"`risk_file'"'
            }
        }

        * =========================================================================
        * DISPLAY SUMMARY
        * =========================================================================

        if `has_compete' {
            display as text "Aalen-Johansen cumulative incidence plot"
        }
        else {
            display as text "Kaplan-Meier plot"
        }
        display as text "  Observations: " as result `N'
        display as text "  Groups:       " as result `ngroups'
        if `has_compete' {
            display as text "  Competing:    " as result `"`compete'"' ///
                as text " (" as result `n_compete' as text " records)"
        }
        if "`ci'" != "" {
            display as text "  CI transform: " as result "`citransform'"
        }
        if `"`macval(pval_text)'"' != "" {
            display as text `"  `macval(pval_text)'"'
        }
        if "`median'" != "" {
            forvalues g = 1/`ngroups' {
                if `median_`g'' < . {
                    local mfmt : display `median_format' `median_`g''
                    local mfmt = strtrim("`mfmt'")
                    display as text `"  Median (`grplbl`g''): "' as result "`mfmt'"
                }
                else {
                    display as text `"  Median (`grplbl`g''): "' as result "NR"
                }
            }
        }

        * =========================================================================
        * RETURN RESULTS
        * =========================================================================

        restore
        local _kmplot_preserved = 0

    } // end capture noisily
    local rc = _rc
    capture graph drop `_kmplot_main_graph'
    local _drop_main_rc = _rc
    capture graph drop `_kmplot_risk_graph'
    local _drop_risk_rc = _rc
    if `_kmplot_preserved' {
        capture restore
    }
    forvalues _s = 1/6 {
        if "`_S_exists`_s''" != "" {
            global S_`_s' `"`macval(_S_saved`_s')'"'
        }
        else capture macro drop S_`_s'
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'

    return scalar N = `N'
    return scalar n_groups = `ngroups'
    return scalar level = `level'
    return scalar failure = ("`failure'" != "")
    return scalar ci = ("`ci'" != "")
    return scalar n_landmarks = `n_landmarks'
    return scalar n_timepoints = `n_timepoints'
    if `riskheight_used' < . {
        return scalar riskheight = `riskheight_used'
    }
    if "`pvalue'" != "" {
        return scalar p = `pval'
        if `pvalue_y' < . {
            return scalar pvalue_y = `pvalue_y'
        }
        if `pvalue_x' < . {
            return scalar pvalue_x = `pvalue_x'
        }
    }
    forvalues g = 1/`ngroups' {
        if `median_`g'' < . {
            return scalar median_`g' = `median_`g''
        }
    }
    local group_labels ""
    forvalues g = 1/`ngroups' {
        local group_labels `"`group_labels'`grplbl`g''"'
        if `g' < `ngroups' {
            local group_labels `"`group_labels' | "'
        }
    }
    return local cmd "kmplot"
    return local estimator "`estimator'"
    return local scale = cond(`plot_scale' == 100, "percent", "proportion")
    if `has_compete' return local compete `"`compete'"'
    if `need_rt' return local riskweight "`riskweight'"
    if `riskmask_k' > 0 return scalar riskmask = `riskmask_k'
    if `ymax_used' < . return scalar ymax = `ymax_used'
    if `tmax_user' < . return scalar tmax = `tmax_user'
    return local graph_name `"`name'"'
    local plot_type = cond("`failure'" != "", "failure", "survival")
    return local plot_type "`plot_type'"
    return local scheme "`scheme'"
    return local cistyle "`cistyle'"
    return local citransform "`citransform'"
    return local colors `"`colors'"'
    return local lpattern `"`lpattern'"'
    return local timepoints "`risk_timepoints'"
    return local landmark_times "`landmark'"
    return local group_labels `"`group_labels'"'
    return local xtitle `"`macval(xtitle)'"'
    return local ytitle `"`macval(ytitle)'"'
    if `"`export_file'"' != "" {
        return local export `"`export_file'"'
    }
    if `"`curve_saved'"' != "" {
        return local saving `"`curve_saved'"'
    }
    if `"`risk_saved'"' != "" {
        return local risksaving `"`risk_saved'"'
    }
    if "`pvalue'" != "" {
        return local pvalue_text `"`macval(pval_text)'"'
        return local pvalue_label `"`macval(pvalue_label)'"'
        return local pvalue_format "`pvalue_format'"
        return local pvalue_pos "`pvaluepos'"
        return local pvalue_at `"`pvalueat'"'
        return local pvalue_placement "`pvalue_place'"
    }
    if "`by'" != "" {
        return local by "`by'"
    }
    if `has_medians_mat' {
        return matrix medians = `medians_mat'
    }
    if `has_landmarks_mat' {
        return matrix landmarks = `landmarks_mat'
    }
    if `has_risktable_mat' {
        return matrix risktable = `risktable_mat'
    }
    if `_kmplot_side_rc' exit `_kmplot_side_rc'
end

* Parse riskmask(# [, text(string)]).  Sets _km_mask_k and _km_mask_text in
* the caller; an invalid specification exits with 198 (the caller stops).
program define _kmplot_parse_mask
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local k ""
    local text ""
    capture noisily {
        gettoken k rest : 0, parse(",")
        local k = strtrim(`"`k'"')
        capture confirm integer number `k'
        if _rc | `"`k'"' == "" {
            noisily display as error "riskmask() must be an integer of 2 or more, optionally followed by , text(string)"
            exit 198
        }
        if `k' < 2 {
            noisily display as error "riskmask() must be an integer of 2 or more"
            exit 198
        }
        local 0 `"`rest'"'
        syntax [, TEXT(string)]
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    c_local _km_mask_k `k'
    c_local _km_mask_text `"`text'"'
end

* Numeric positions of a ylabel() specification: the numbers outside quoted
* label text, before the first comma.  Sets _km_yl_ok (1 when a numeric list
* was found) and _km_yl_lo/_km_yl_hi in the caller.
program define _kmplot_ylabnums
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local ok = 0
    local lo = .
    local hi = .
    capture noisily {
        local rest `"`0'"'
        local nums ""
        while `"`rest'"' != "" {
            gettoken tok rest : rest, parse(" ,") quotes
            if `"`tok'"' == "," continue, break
            if `"`tok'"' == "" continue
            mata: st_local("_isq", strofreal(anyof((char(34), char(96)), substr(st_local("tok"), 1, 1))))
            if `_isq' continue
            local nums `"`nums' `tok'"'
        }
        if `"`nums'"' != "" {
            capture numlist `"`nums'"', sort
            if _rc == 0 {
                local vals `r(numlist)'
                local n : word count `vals'
                local lo : word 1 of `vals'
                local hi : word `n' of `vals'
                local ok = 1
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    c_local _km_yl_ok `ok'
    c_local _km_yl_lo `lo'
    c_local _km_yl_hi `hi'
end

* graphregion(), plotregion(), xsize() and ysize() from the passthrough
* options, for graph combine.  Sets _km_region_opts in the caller.
program define _kmplot_regionopts
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local keep ""
    local regs ""
    capture noisily {
        local rest `"`0'"'
        while `"`rest'"' != "" {
            gettoken tok rest : rest, bind
            if `"`tok'"' == "" continue
            local p = strpos(`"`tok'"', "(")
            if `p' < 2 continue
            local nm = lower(substr(`"`tok'"', 1, `p' - 1))
            local l = strlen("`nm'")
            local hit = 0
            if `l' >= 6 & "`nm'" == substr("graphregion", 1, `l') local hit = 1
            if `l' >= 5 & "`nm'" == substr("plotregion", 1, `l') local hit = 1
            if inlist("`nm'", "xsize", "ysize") local hit = 1
            if `hit' local keep `"`macval(keep)' `macval(tok)'"'
            if `hit' & !inlist("`nm'", "xsize", "ysize") {
                local regs `"`macval(regs)' `macval(tok)'"'
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    c_local _km_region_opts `"`macval(keep)'"'
    c_local _km_region_only `"`macval(regs)'"'
end
