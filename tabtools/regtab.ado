*! regtab Version 1.9.8  2026/07/13
*! Author: Timothy P Copeland, Karolinska Institutet

/*
DESCRIPTION:
	Formats the collected regression tables; exports point estimate, 95% CI, and p-value to excel; and applies excel formatting (column widths, merges cells, sets column widths). Title appears in cell A1. Top left cell of table is B2.

SYNTAX:
	regtab, xlsx(string) sheet(string) [models(string) sep(string asis) coef(string) title(string) noint nore stats(string) relabel cutlabels(string asis) addrow(string asis)]

	xlsx:	Required option. Excel file name. Requires .xlsx suffix
	sheet:	Required option. Excel sheet name.
	models:	Label models, separating model names using backslash (e.g., Model 1 \ Model 2...)
	coef:	Labels the point estimate (e.g., OR, Coef., HR)
	title:	Gives spreasheet a table name in cell A1
	noint:	Drops intercept row
	        Also drops cutpoint and ancillary-only rows such as cut1, lnalpha,
	        alpha, and /sigma; use keepintercept to show them.
	nore:	Drops random effects rows
	sep:    character separating 95% CI, default is ", "
	stats:	Model statistics to add at bottom (space-separated): n aic bic qic icc ll groups
	        - n: Number of observations
	        - aic: Akaike Information Criterion
	        - bic: Bayesian Information Criterion
	        - qic: Quasi-likelihood Information Criterion (for GEE/xtgee models)
	        - icc: Intraclass Correlation Coefficient (for mixed models)
	        - ll: Log-likelihood
	        - groups: Number of groups (for mixed models)
	relabel: Relabel random effects nicely (e.g., "var(_cons)" -> "Variance (Intercept)")
	cutlabels: Relabel ordered-outcome cutpoints, separated by backslashes.
	        Example: cutlabels("Low/Mid \ Mid/High")
	addrow: Append custom rows below the table body. Format: addrow("Label" val1 val2).
	        Use backslash to separate multiple rows:
	        addrow("P trend" 0.032 0.041 \ "P interaction" 0.15 0.22)

	Automatic MOR/MHR: For melogit models, random intercept variance is
	        automatically converted to Median Odds Ratio (MOR). For mestreg
	        and mecloglog, it becomes Median Hazard Ratio (MHR). CI bounds
	        are transformed on the same scale. Use nore to suppress.

*/

program define regtab, rclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off

capture noisily {

	capture putexcel close

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

syntax, [xlsx(string) excel(string) sheet(string)] [sep(string asis) models(string) coef(string) ///
	title(string) NOINTercept KEEPIntercept NOREeffects stats(string) RELABel ///
	digits(integer -1) FOOTnote(string) open zebra HEADERShade HIGHlight(real -1) ///
	BOLDp(real -1) cdisc BORDERstyle(string) stars THEme(string) ///
	STARSLevels(numlist) HEADERColor(string) ZEBRAColor(string) csv(string) MARKdown(string) MDAPPend ///
	FRAme(string) EPLOTFrame(string asis) keep(string) drop(string) DIMNONsig FACTORLabel ///
	REFcat(string) CUTLabels(string) ADDRow(string asis) COMPact NOPvalue ///
	pdp(integer -1) highpdp(integer -1) LABELWidth(integer 0) Level(real -1)]

* Accept excel() as synonym for xlsx()
if "`xlsx'" == "" & "`excel'" != "" local xlsx "`excel'"
local _user_coef_spec = ("`coef'" != "")
local _user_noint_spec = ("`nointercept'" != "")

* Default reference category label
if "`refcat'" == "" local refcat "Reference"
local _has_xlsx = "`xlsx'" != ""
if `_has_xlsx' & "`sheet'" == "" local sheet "Regression"
if !`_has_xlsx' & "`sheet'" == "" local sheet "Regression"

* Resolve persistent defaults
if `digits' == -1 {
    if "$TABTOOLS_DIGITS" != "" local digits = $TABTOOLS_DIGITS
    else local digits = 2
}
if `boldp' == -1 & "$TABTOOLS_BOLDP" != "" local boldp = $TABTOOLS_BOLDP
if `pdp' == -1 local pdp = 3
if `highpdp' == -1 local highpdp = 2
	local _show_pvalues = ("`nopvalue'" == "")

	local _eplotframe_name ""
	local _eplotframe_replace 0
		if `"`eplotframe'"' != "" {
	    local _ep_spec = strtrim(`"`eplotframe'"')
	    gettoken _eplotframe_name _ep_rest : _ep_spec, parse(",")
	    local _eplotframe_name = strtrim(`"`_eplotframe_name'"')
	    if `"`_eplotframe_name'"' == "" {
	        noisily display as error "eplotframe() requires a frame name"
	        exit 198
	    }
	    capture confirm name `_eplotframe_name'
	    if _rc {
	        noisily display as error "eplotframe() must start with a valid Stata frame name"
	        exit 198
	    }
	    local _ep_rest : subinstr local _ep_rest "," "", all
	    local _ep_rest = lower(strtrim(`"`_ep_rest'"'))
	    if `"`_ep_rest'"' != "" {
	        if `"`_ep_rest'"' == "replace" {
	            local _eplotframe_replace 1
	        }
	        else {
	            noisily display as error "eplotframe() only allows the replace suboption"
	            exit 198
	        }
		    }
		}
		local _displayframe_name ""
		local _displayframe_replace 0
		if `"`frame'"' != "" {
			local _fr_spec = subinstr(strtrim(`"`frame'"'), `""""', "", .)
			gettoken _displayframe_name _fr_rest : _fr_spec, parse(",")
			local _displayframe_name = strtrim(`"`_displayframe_name'"')
			local _fr_rest : subinstr local _fr_rest "," "", all
			local _fr_rest = lower(strtrim(`"`_fr_rest'"'))
			capture confirm name `_displayframe_name'
			if _rc {
				noisily display as error "frame() must start with a valid Stata frame name"
				exit 198
			}
			if `"`_fr_rest'"' != "" {
				if `"`_fr_rest'"' == "replace" local _displayframe_replace 1
				else {
					noisily display as error "frame() only allows the replace suboption"
					exit 198
				}
			}
		}
		if `"`_displayframe_name'"' != "" & ///
			`"`_eplotframe_name'"' != "" & ///
			lower(`"`_displayframe_name'"') == lower(`"`_eplotframe_name'"') {
			noisily display as error "frame() and eplotframe() must name different frames"
			exit 198
		}
		foreach _dest in _displayframe_name _eplotframe_name {
			if `"``_dest''"' != "" & ///
				lower(`"``_dest''"') == lower(`"`c(frame)'"') {
				noisily display as error "output frames cannot replace the current frame"
				exit 198
			}
		}
		if `"`_displayframe_name'"' != "" {
			capture confirm frame `_displayframe_name'
			if !_rc & !`_displayframe_replace' {
				noisily display as error "frame `_displayframe_name' already exists; specify frame(`_displayframe_name', replace)"
				exit 110
			}
		}
		if `"`_eplotframe_name'"' != "" {
			capture confirm frame `_eplotframe_name'
			if !_rc & !`_eplotframe_replace' {
				noisily display as error "frame `_eplotframe_name' already exists; specify eplotframe(`_eplotframe_name', replace)"
				exit 110
			}
		}

		* Stage both frame sinks under temporary names. Caller-visible targets are
		* swapped only after every requested file export has succeeded.
		local _displayframe_target "`_displayframe_name'"
		local _eplotframe_target "`_eplotframe_name'"
		local _displayframe_build ""
		local _eplotframe_build ""
		if `"`_displayframe_target'"' != "" {
			tempname _displayframe_tmp
			local _displayframe_build "`_displayframe_tmp'"
			local frame "`_displayframe_build', replace"
		}
		if `"`_eplotframe_target'"' != "" {
			tempname _eplotframe_tmp
			local _eplotframe_build "`_eplotframe_tmp'"
			local _eplotframe_name "`_eplotframe_build'"
			local _eplotframe_replace 1
		}

	* Label-column width cap. 0 (default) resolves to 45 chars: wide enough for
* ordinary predictor labels, narrow enough that a lone verbose random-effects
* row wraps instead of stretching the whole column.
local _label_width_cap = `labelwidth'
if `_label_width_cap' <= 0 local _label_width_cap = 45

* Validate sheet name for Excel constraints
_tabtools_validate_sheet "`sheet'" "sheet()"

* Map option names for internal use
local noint `nointercept'
local nore `noreeffects'

* Validate digits range
if `digits' < 0 | `digits' > 6 {
	noisily display as error "digits() must be between 0 and 6"
	exit 198
}
if `pdp' < 1 | `pdp' > 10 {
	noisily display as error "pdp() must be between 1 and 10"
	exit 198
}
if `highpdp' < 1 | `highpdp' > 10 {
	noisily display as error "highpdp() must be between 1 and 10"
	exit 198
}
if `level' != -1 & (`level' <= 0 | `level' >= 100) {
	noisily display as error "level() must be between 0 and 100"
	exit 198
}
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

* Auto-detect coefficient label from model type
if "`coef'" == "" {
	local _ecmd2 "`e(cmd2)'"
	local _ecmd "`e(cmd)'"
	if "`_ecmd2'" != "" local _ecmd "`_ecmd2'"
	if inlist("`_ecmd'", "logit", "logistic", "melogit", "meoprobit", "ologit") {
		local coef "OR"
	}
	else if inlist("`_ecmd'", "stcox", "mestreg", "mecloglog") {
		local coef "HR"
	}
	else if inlist("`_ecmd'", "poisson", "mepoisson", "nbreg", "menbreg", "glm") {
		local coef "IRR"
	}
	else if "`_ecmd'" == "mlogit" {
		local coef "RRR"
	}
	else if inlist("`_ecmd'", "finegray", "stcrreg") {
		local coef "SHR"
	}
	else if inlist("`_ecmd'", "streg") {
		if "`e(frm2)'" == "time" local coef "TR"
		else local coef "AF"
	}
	else if inlist("`_ecmd'", "regress", "mixed", "xtreg") {
		local coef "Coef."
	}
	* Refine glm auto-detection based on family
	if "`coef'" == "IRR" & "`_ecmd'" == "glm" {
		local _efam = lower("`e(varfunct)'")
		local _elink = lower("`e(linkt)'")
		if (strpos("`_efam'", "bernoulli") | strpos("`_efam'", "binomial")) & ///
			strpos("`_elink'", "logit") local coef "OR"
		else if strpos("`_efam'", "poisson") & ///
			strpos("`_elink'", "log") local coef "IRR"
		else local coef "Coef."
	}
}

* Auto-detect nointercept for exponentiated models (U4)
* OR/HR/IRR/RRR models rarely report intercept; suppress unless user forces it
if "`nointercept'" == "" & "`keepintercept'" == "" {
	if inlist("`coef'", "OR", "HR", "IRR", "RRR", "SHR", "TR", "AF") {
		local nointercept "nointercept"
	}
}

* CDISC mode overrides (C4)
if "`cdisc'" != "" {
	if `digits' == 2 local digits 4
	if !`_user_coef_spec' local coef "Estimate"
	if "`stats'" == "" local stats "n"
}

* Parse starslevels (O5): default 0.05 0.01 0.001
local _sl1 0.05
local _sl2 0.01
local _sl3 0.001
if "`starslevels'" != "" {
	local _sl_n : word count `starslevels'
	if `_sl_n' != 3 {
		noisily display as error "starslevels() requires exactly 3 values (e.g., starslevels(0.05 0.01 0.001))"
		exit 198
	}
	local _sl1 : word 1 of `starslevels'
	local _sl2 : word 2 of `starslevels'
	local _sl3 : word 3 of `starslevels'
}

* Build format strings from digits (F3)
local coef_fmt "%21.`digits'f"
local ci_fmt "%`=`digits'+3'.`digits'fc"
local coef_round = 10^(-`digits')

* Resolve formatting
_tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle') headershade(`headershade') zebra(`zebra')

_tabtools_resolve_colors, headercolor(`"`headercolor'"') zebracolor(`"`zebracolor'"')

* Validate highlight
local has_highlight = `highlight' != -1
if `has_highlight' & (`highlight' <= 0 | `highlight' >= 1) {
	noisily display as error "highlight() must be between 0 and 1"
	exit 198
}

* Validate boldp
local has_boldp = `boldp' != -1
if `has_boldp' & (`boldp' <= 0 | `boldp' >= 1) {
	noisily display as error "boldp() must be between 0 and 1"
	exit 198
}

quietly{
    * Validation: Check if collect table exists
    capture quietly collect query row
    if _rc {
        noisily display as error "No active collect table found"
        noisily display as error "Run regression commands with {bf:collect:} prefix first"
        noisily display as error "Hint: {bf:collect clear} then {bf:collect: regress y x1 x2}"
        exit 119
    }
	_tabtools_collect_ci_level
	local _stored_ci_level = r(level)
	local _ci_level = `_stored_ci_level'
	if `level' != -1 {
		if abs(`level' - `_stored_ci_level') > 1e-8 {
			noisily display as error "level(`level') conflicts with the active collection's `_stored_ci_level'% intervals"
			exit 198
		}
		local _ci_level = `level'
	}

    * Validation: Check xlsx if specified
    if `_has_xlsx' {
        if !strmatch("`xlsx'", "*.xlsx") {
            noisily display as error "Excel filename must have .xlsx extension"
            exit 198
        }
        _tabtools_validate_path "`xlsx'" "xlsx()"
    }
    if "`open'" != "" & !`_has_xlsx' {
        noisily display as error "open requires xlsx() or excel()"
        exit 198
    }

    * Create temporary file for intermediate processing
    tempfile temp_export
    local temp_xlsx "`temp_export'.xlsx"

    * Validate keep/drop mutual exclusivity
    if "`keep'" != "" & "`drop'" != "" {
        noisily display as error "keep() and drop() cannot be used together"
        exit 198
    }

	if `"`sep'"' == "" local sep ", "      // Default CI delimiter

    * =========================================================================
    * EXTRACT PER-MODEL COMMAND METADATA
    * =========================================================================
    local _meta_models = 0
    local _model_headers_mixed = 0
    local _all_auto_noint = 1
    local _coef_label_return "`coef'"
    local _has_multieq_estimator = 0
    capture {
        collect layout (cmdset) (result[cmd cmdline depvar])
    }
    if _rc == 0 {
        preserve
        capture {
            _tabtools_collect_render, type(meta) rowdim(cmdset) ///
                results(cmd cmdline depvar) dropempty

            local meta_col_cmd ""
            local meta_col_cmdline ""
            local meta_col_depvar ""
            ds
            local meta_allvars `r(varlist)'
            foreach v of local meta_allvars {
                local hdr = strlower(strtrim(`v'[1]))
                if "`hdr'" == "command" local meta_col_cmd "`v'"
                if "`hdr'" == "command line as typed" local meta_col_cmdline "`v'"
                if "`hdr'" == "dependent variable" local meta_col_depvar "`v'"
            }

            local _meta_models = _N - 1
            forvalues m = 1/`_meta_models' {
                local r = `m' + 1
                local model_cmd_`m' = lower(strtrim(`meta_col_cmd'[`r']))
                local model_cmdline_`m' = lower(strtrim(`meta_col_cmdline'[`r']))
                if "`meta_col_depvar'" != "" {
                    local model_depvar_`m' = lower(strtrim(`meta_col_depvar'[`r']))
                }
                else local model_depvar_`m' ""
            }
        }
        if _rc local _meta_models = 0
        restore
    }

    if !`_user_noint_spec' {
        local nointercept ""
    }

    if `_meta_models' > 0 {
        local _shared_coef ""
        local _re_family_seen ""
        local _re_family_mixed 0
        forvalues m = 1/`_meta_models' {
            local _cmdline_lc `"`model_cmdline_`m''"'
            local _cmdword ""
            gettoken _cmdword _cmdrest : _cmdline_lc
            if "`_cmdword'" == "" local _cmdword `"`model_cmd_`m''"'

            local _has_irr = regexm(`"`_cmdline_lc'"', "(^|[, ])irr([ ,]|$)")
            local _has_or = regexm(`"`_cmdline_lc'"', "(^|[, ])or([ ,]|$)")
            local _has_rrr = regexm(`"`_cmdline_lc'"', "(^|[, ])rrr([ ,]|$)")
            local _has_eform = regexm(`"`_cmdline_lc'"', "(^|[, ])eform([ ,]|$)")
            local _optstr ""
            local _comma_pos = strpos(`"`_cmdline_lc'"', ",")
            if `_comma_pos' > 0 {
                local _optstr = lower(strtrim(substr(`"`_cmdline_lc'"', `_comma_pos' + 1, .)))
            }

            local model_coef_`m' "Coef."
            local model_null_`m' 0
            local model_eform_`m' 0
            local model_auto_noint_`m' 0
            local model_re_family_`m' "none"
            * model_icc_undef = 1 means ICC is undefined for this model family
            * (count-data mixed models: mepoisson, menbreg). Set in the
            * inlist branches below so the ICC code path can skip per-model.
            local model_icc_undef_`m' 0

            if inlist("`_cmdword'", "logit", "ologit") {
                local model_coef_`m' "OR"
                local model_null_`m' 1
                local model_eform_`m' = !`_has_or'
                local model_auto_noint_`m' 1
            }
            else if "`_cmdword'" == "logistic" {
                local model_coef_`m' "OR"
                local model_null_`m' 1
                local model_auto_noint_`m' 1
            }
            else if "`_cmdword'" == "melogit" {
                local model_coef_`m' "OR"
                local model_null_`m' 1
                local model_eform_`m' = !`_has_or'
                local model_auto_noint_`m' 1
                local model_re_family_`m' "mor"
            }
            else if inlist("`_cmdword'", "poisson", "nbreg", "mepoisson", "menbreg") {
                local model_coef_`m' "IRR"
                local model_null_`m' 1
                local model_eform_`m' = !`_has_irr'
                local model_auto_noint_`m' 1
                if inlist("`_cmdword'", "mepoisson", "menbreg") {
                    local model_re_family_`m' "variance"
                    local model_icc_undef_`m' 1
                }
            }
            else if "`_cmdword'" == "mlogit" {
                local model_coef_`m' "RRR"
                local model_null_`m' 1
                local model_eform_`m' = !`_has_rrr'
                local model_auto_noint_`m' 1
                local _has_multieq_estimator = 1
            }
            else if inlist("`_cmdword'", "zip", "zinb", "churdle") {
                local model_auto_noint_`m' 1
                local _has_multieq_estimator = 1
            }
            else if inlist("`_cmdword'", "finegray", "stcrreg") {
                local model_coef_`m' "SHR"
                local model_null_`m' 1
                local model_auto_noint_`m' 1
            }
            else if inlist("`_cmdword'", "stcox") | "`model_cmd_`m''" == "cox" {
                local model_coef_`m' "HR"
                local model_null_`m' 1
                local model_auto_noint_`m' 1
            }
            else if inlist("`_cmdword'", "streg") {
                if regexm(`"`_optstr'"', "(^| )time( |$)") local model_coef_`m' "TR"
                else local model_coef_`m' "AF"
                local model_null_`m' 1
                local model_auto_noint_`m' 1
            }
            else if inlist("`_cmdword'", "mestreg", "mecloglog") {
                local model_coef_`m' "HR"
                local model_null_`m' 1
                local model_auto_noint_`m' 1
                local model_re_family_`m' "mhr"
            }
            else if "`_cmdword'" == "mixed" {
                local model_re_family_`m' "variance"
            }
            else if "`_cmdword'" == "glm" {
                local _glm_family ""
                local _glm_link ""
                if regexm(`"`_optstr'"', "family\(([a-z0-9_]+)") {
                    local _glm_family = lower(regexs(1))
                }
                if regexm(`"`_optstr'"', "link\(([a-z0-9_]+)") {
                    local _glm_link = lower(regexs(1))
                }
                if inlist("`_glm_family'", "bernoulli", "binomial") & ///
                    inlist("`_glm_link'", "", "logit") {
                    local model_coef_`m' "OR"
                    local model_null_`m' 1
                    local model_eform_`m' = !`_has_eform'
                    local model_auto_noint_`m' 1
                }
                else if "`_glm_family'" == "poisson" & ///
                    inlist("`_glm_link'", "", "log") {
                    local model_coef_`m' "IRR"
                    local model_null_`m' 1
                    local model_eform_`m' = !`_has_eform'
                    local model_auto_noint_`m' 1
                }
                else {
                    local model_coef_`m' "Coef."
                }
            }

            if `m' == 1 {
                local _shared_coef "`model_coef_`m''"
            }
            else if "`model_coef_`m''" != "`_shared_coef'" {
                local _model_headers_mixed = 1
            }
            if `model_auto_noint_`m'' == 0 {
                local _all_auto_noint = 0
            }
            if "`model_re_family_`m''" != "none" {
                if "`_re_family_seen'" == "" local _re_family_seen "`model_re_family_`m''"
                else if "`model_re_family_`m''" != "`_re_family_seen'" local _re_family_mixed 1
            }
        }

        if `_re_family_mixed' & "`noreeffects'" == "" {
            noisily display as error "mixed random-effect model families cannot be combined with random-effects rows"
            noisily display as error "Use separate regtab calls, or specify noreeffects to suppress random-effects rows"
            exit 198
        }

        if !`_user_coef_spec' & "`cdisc'" == "" {
            if `_model_headers_mixed' {
                local coef "Estimate"
                local _coef_label_return "mixed"
            }
            else {
                local coef "`_shared_coef'"
                local _coef_label_return "`coef'"
            }
        }
        if !`_user_noint_spec' & "`keepintercept'" == "" & `_all_auto_noint' {
            local nointercept "nointercept"
        }
    }
    else {
        if !`_user_noint_spec' {
            local nointercept ""
        }
    }
    local noint `nointercept'

    * =========================================================================
    * STORE MODEL STATISTICS BEFORE COLLECT EXPORT
    * =========================================================================
    * Store e() statistics for each model in the collection
    * These may get cleared during processing, so capture them now

    local add_stats = 0
    tempname temp_b
    if "`stats'" != "" {
        local add_stats = 1

        * Parse requested statistics
        local want_n = 0
        local want_aic = 0
        local want_bic = 0
        local want_qic = 0
        local want_icc = 0
        local want_ll = 0
        local want_groups = 0
        local want_r2 = 0

        local stats_lower = " " + strlower("`stats'") + " "
        if strpos("`stats_lower'", " n ") local want_n = 1
        if strpos("`stats_lower'", " aic ") local want_aic = 1
        if strpos("`stats_lower'", " bic ") local want_bic = 1
        if strpos("`stats_lower'", " qic ") local want_qic = 1
        if strpos("`stats_lower'", " icc ") local want_icc = 1
        if strpos("`stats_lower'", " ll ") local want_ll = 1
        if strpos("`stats_lower'", " groups ") local want_groups = 1
        if strpos("`stats_lower'", " r2 ") | strpos("`stats_lower'", " r-squared ") local want_r2 = 1

        * Aliases: treat n_sub / subjects as a request for the N row; regtab
        * already prefers N_sub (subjects) over N (rows) for survival models.
        if strpos("`stats_lower'", " n_sub ") | strpos("`stats_lower'", " subjects ") ///
            local want_n = 1

        * Warn (do not silently drop) on unrecognized stats() tokens.
        local _stat_known " n n_sub subjects aic bic qic icc ll groups r2 r-squared "
        foreach _stok of local stats {
            local _stok_l = strlower("`_stok'")
            if !strpos("`_stat_known'", " `_stok_l' ") {
                noisily display as error ///
                    "warning: stats() token '`_stok'' not recognized and ignored;" ///
                    " valid: n (n_sub/subjects) aic bic qic icc ll groups r2"
            }
        }

        * ================================================================
        * EXTRACT PER-MODEL STATS FROM COLLECTION
        * ================================================================
        * The collect framework stores e() scalars per cmdset.
        * Extract via temporary layout + export + import cycle.
        local n_stat_models = 0

        * Build list of result levels needed
        * Note: N is always collected when BIC is requested — BIC requires N
        * even if the user didn't ask for the N row in the output.
        local result_levels ""
        local _any_N_sub = 0
        if `want_n' | `want_bic' local result_levels "N N_sub"
        if `want_ll' | `want_aic' | `want_bic' {
            local result_levels "`result_levels' ll"
        }
        if `want_aic' local result_levels "`result_levels' aic"
        if `want_bic' local result_levels "`result_levels' bic"
        if `want_aic' | `want_bic' | `want_qic' {
            local result_levels "`result_levels' rank"
        }
        if `want_qic' | `want_aic' {
            local result_levels "`result_levels' deviance"
        }
        if `want_groups' local result_levels "`result_levels' N_g"
        if `want_r2' local result_levels "`result_levels' r2 r2_p r2_a"
        local result_levels : list uniq result_levels

        if "`result_levels'" != "" {
            * Save original labels, set short labels for export headers
            foreach rlevel of local result_levels {
                capture local _orig_lbl_`rlevel' : collect label levels result `rlevel'
                capture collect label levels result `rlevel' "`rlevel'", modify
            }

            capture {
                collect layout (cmdset) (result[`result_levels'])
            }
            local _stats_rc = _rc

            * Restore original labels
            foreach rlevel of local result_levels {
                if `"`_orig_lbl_`rlevel''"' != "" {
                    capture collect label levels result `rlevel' `"`_orig_lbl_`rlevel''"', modify
                }
            }

            if `_stats_rc' == 0 {
                preserve
                capture {
                    _tabtools_collect_render, type(stats) rowdim(cmdset) ///
                        results(`result_levels') dropempty

                    * Map header row to column positions
                    local stat_col_N ""
                    local stat_col_N_sub ""
                    local stat_col_ll ""
                    local stat_col_aic ""
                    local stat_col_bic ""
                    local stat_col_rank ""
                    local stat_col_deviance ""
                    local stat_col_N_g ""
                    local stat_col_r2 ""
                    local stat_col_r2_p ""
                    local stat_col_r2_a ""

                    ds
                    local stat_allvars `r(varlist)'
                    foreach v of local stat_allvars {
                        local hdr = `v'[1]
                        if "`hdr'" == "N" local stat_col_N "`v'"
                        if "`hdr'" == "N_sub" local stat_col_N_sub "`v'"
                        if "`hdr'" == "ll" local stat_col_ll "`v'"
                        if "`hdr'" == "aic" local stat_col_aic "`v'"
                        if "`hdr'" == "bic" local stat_col_bic "`v'"
                        if "`hdr'" == "rank" local stat_col_rank "`v'"
                        if "`hdr'" == "deviance" local stat_col_deviance "`v'"
                        if "`hdr'" == "N_g" local stat_col_N_g "`v'"
                        if "`hdr'" == "r2" local stat_col_r2 "`v'"
                        if "`hdr'" == "r2_p" local stat_col_r2_p "`v'"
                        if "`hdr'" == "r2_a" local stat_col_r2_a "`v'"
                    }

                    local n_stat_models = _N - 1

                    forvalues m = 1/`n_stat_models' {
                        local r = `m' + 1

                        * Extract each result level
                        foreach sname in N N_sub ll aic bic rank deviance N_g r2 r2_p r2_a {
                            if "`sname'" == "N_g" local lname "groups"
                            else local lname "`sname'"
                            local stat_`lname'_`m' = .
                            if "`stat_col_`sname''" != "" {
                                local val = `stat_col_`sname''[`r']
                                local val = subinstr("`val'", ",", "", .)
                                if "`val'" != "" & "`val'" != "." {
                                    local stat_`lname'_`m' = real("`val'")
                                }
                            }
                        }

                        * Compute QIC from deviance + rank (GEE models)
                        local stat_qic_`m' = .
                        if `stat_deviance_`m'' != . & `stat_rank_`m'' != . {
                            local stat_qic_`m' = `stat_deviance_`m'' + 2 * `stat_rank_`m''
                        }

                        * AIC = -2*ll + 2*k. Always recompute from ll + rank when
                        * both are present rather than trusting e(aic): glm (the GEE
                        * backend) stores e(aic) as AIC/N (per observation), ~N times
                        * too small. The formula matches estat ic for every ML/GLM
                        * estimator and keeps glm and mixed models on one scale.
                        if `stat_ll_`m'' != . & `stat_rank_`m'' != . {
                            local stat_aic_`m' = -2 * `stat_ll_`m'' + 2 * `stat_rank_`m''
                        }

                        * BIC = -2*ll + k*ln(N), likewise recomputed from ll + rank + N.
                        * glm's e(bic) uses a deviance-based convention that is not
                        * comparable to the likelihood BIC mixed models report.
                        if `stat_ll_`m'' != . & `stat_rank_`m'' != . & `stat_N_`m'' != . {
                            local stat_bic_`m' = -2 * `stat_ll_`m'' + `stat_rank_`m'' * ln(`stat_N_`m'')
                        }

                        * Prefer N_sub (subjects) over N (rows) for survival models
                        if `stat_N_sub_`m'' != . {
                            local stat_N_`m' = `stat_N_sub_`m''
                            local _any_N_sub = 1
                        }
                    }
                }
                if _rc local n_stat_models = 0
                restore
            }
        }

        * Backfill groups from e() when collection extraction found none
        * (mixed stores N_g as matrix, not scalar — invisible to collect)
        if `n_stat_models' > 0 & `want_groups' == 1 {
            local _all_grp_miss = 1
            forvalues m = 1/`n_stat_models' {
                if `stat_groups_`m'' != . local _all_grp_miss = 0
            }
            if `_all_grp_miss' {
                local _grp = .
                capture local _grp = e(N_g)
                if `_grp' == . {
                    capture {
                        tempname ng_mat
                        matrix `ng_mat' = e(N_g)
                        local _grp = `ng_mat'[1,1]
                    }
                }
                if `_grp' == . capture local _grp = e(N_clust)
                if `_grp' != . {
                    local stat_groups_`n_stat_models' = `_grp'
                }
            }
        }

        * Fallback: if collection extraction failed, use e() for c1 only
        if `n_stat_models' == 0 {
            local stat_N_1 = .
            local stat_aic_1 = .
            local stat_bic_1 = .
            local stat_qic_1 = .
            local stat_ll_1 = .
            local stat_groups_1 = .
            local stat_k_1 = .
            local stat_r2_1 = .
            local stat_r2_p_1 = .
            local stat_r2_a_1 = .

            capture local stat_N_1 = e(N)
            capture {
                local _nsub = e(N_sub)
                if `_nsub' != . {
                    local stat_N_1 = `_nsub'
                    local _any_N_sub = 1
                }
            }
            capture local stat_ll_1 = e(ll)

            capture {
                local stat_groups_1 = e(N_g)
            }
            if `stat_groups_1' == . {
                capture {
                    tempname ng_mat
                    matrix `ng_mat' = e(N_g)
                    local stat_groups_1 = `ng_mat'[1,1]
                }
            }
            if `stat_groups_1' == . {
                capture local stat_groups_1 = e(N_clust)
            }

            capture local stat_r2_1 = e(r2)
            capture local stat_r2_p_1 = e(r2_p)
            capture local stat_r2_a_1 = e(r2_a)

            capture local stat_aic_1 = e(aic)
            capture local stat_bic_1 = e(bic)

            * AIC = -2*ll + 2*k / BIC = -2*ll + k*ln(N): recompute from ll + rank
            * whenever available, overriding e(aic)/e(bic). glm stores e(aic) as
            * AIC/N (per observation) and a deviance-based e(bic); both are
            * incomparable to the likelihood values mixed reports. Matches estat ic.
            if `stat_ll_1' != . {
                capture local stat_k_1 = e(rank)
                if `stat_k_1' == . {
                    capture local stat_k_1 = e(k)
                }
                if `stat_k_1' != . {
                    local stat_aic_1 = -2 * `stat_ll_1' + 2 * `stat_k_1'
                }
            }

            if `stat_ll_1' != . & `stat_N_1' != . {
                if `stat_k_1' == . {
                    capture local stat_k_1 = e(rank)
                    if `stat_k_1' == . {
                        capture local stat_k_1 = e(k)
                    }
                }
                if `stat_k_1' != . {
                    local stat_bic_1 = -2 * `stat_ll_1' + `stat_k_1' * ln(`stat_N_1')
                }
            }

            * QIC for GEE models: deviance + 2*rank
            local _deviance = .
            capture local _deviance = e(deviance)
            if `_deviance' != . {
                if `stat_k_1' == . {
                    capture local stat_k_1 = e(rank)
                }
                if `stat_k_1' != . {
                    local stat_qic_1 = `_deviance' + 2 * `stat_k_1'
                }
            }

            * Flag as single-model fallback. For multi-model collections this
            * places the active e() (typically the LAST fitted model) under
            * model 1's column and leaves the other model columns blank, which
            * is a known and documented limitation. Warn the user when the
            * fallback triggers under a multi-model layout so misattribution
            * is visible at runtime, not just buried in the help file.
            local n_stat_models = 1
            if `_meta_models' > 1 {
                noisily display as text "Note: per-model stats extraction failed; falling back to active e() for model 1 only"
                noisily display as text "      remaining model columns will be blank for stats() rows"
            }
        }

        * ICC: extract variance components per model from collection
        * Collection stores var(_cons) = random intercept variance,
        * var(e) = residual variance (continuous), not log-SD values
        local n_icc_models = 0
        if `want_icc' == 1 {
            local _icc_slots = max(`n_stat_models', `_meta_models')
            if `_icc_slots' < 1 local _icc_slots = 1
            forvalues m = 1/`_icc_slots' {
                local stat_icc_`m' = .
            }

            * Count data models (mepoisson, menbreg) have no closed-form
            * level-1 variance — ICC is not defined for those rows. Decision is
            * per-model so a multi-model collection containing mepoisson plus
            * melogit still recovers ICC for the binary-outcome model. Build a
            * skip list and a notice list now; values stay missing for skipped
            * positions while non-skipped positions flow through extraction.
            * Iterate over _meta_models (not n_stat_models): when stats(icc)
            * is the ONLY stats option, the per-model stats extraction path
            * is skipped, n_stat_models falls back to 1, and a loop bounded by
            * n_stat_models would miss positions 2+ in a multi-model collection.
            * model_icc_undef is set during cmdline parsing for count-data mixed
            * models (mepoisson, menbreg). Use it here rather than re-parsing
            * model_cmd_`m', which may report a deeper e(cmd) name like "meglm".
            local _icc_skip_list ""
            if `_meta_models' > 0 {
                forvalues m = 1/`_meta_models' {
                    if `model_icc_undef_`m'' {
                        local _icc_skip_list "`_icc_skip_list' `m'"
                    }
                }
            }
            if "`_icc_skip_list'" != "" {
                local _icc_skip_list = strtrim("`_icc_skip_list'")
                local _icc_skip_n : word count `_icc_skip_list'
                * "all skipped" is measured against the meta-known model count,
                * not the (possibly fallback-shrunk) n_stat_models.
                local _icc_total = cond(`_meta_models' > 0, `_meta_models', `n_stat_models')
                if `_icc_skip_n' == `_icc_total' {
                    noisily display as text "Note: ICC not computed (no closed-form level-1 variance for the requested model family)"
                }
                else {
                    noisily display as text "Note: ICC not computed for model(s) `_icc_skip_list' (no closed-form level-1 variance)"
                }
            }

            capture {
                collect layout (cmdset) (colname[var(_cons) var(e)]#result[_r_b])
            }

            if _rc == 0 {
                preserve
                capture {
                    _tabtools_collect_render, type(icc) rowdim(cmdset) ///
                        coldim(colname) collevels("var(_cons) var(e)") results(_r_b)

                    * Find first data row (column A has cmdset number)
                    local _icc_hdr = 0
                    forvalues _ir = 1/`=_N' {
                        if real(A[`_ir']) != . {
                            local _icc_hdr = `_ir' - 1
                            continue, break
                        }
                    }
                    local n_icc_models = _N - `_icc_hdr'

                    * Find columns for each variance component
                    ds
                    local icc_allvars `r(varlist)'
                    local icc_col_re ""
                    local icc_col_resid ""
                    foreach v of local icc_allvars {
                        local hdr = `v'[1]
                        if strpos("`hdr'", "var(_cons)") local icc_col_re "`v'"
                        if strpos("`hdr'", "var(e)") local icc_col_resid "`v'"
                    }

                    forvalues m = 1/`n_icc_models' {
                        * Per-model skip: count families have no closed-form ICC.
                        local _icc_this_skip = 0
                        if "`_icc_skip_list'" != "" {
                            foreach _ism of local _icc_skip_list {
                                if `_ism' == `m' local _icc_this_skip = 1
                            }
                        }
                        if `_icc_this_skip' continue

                        local r = `m' + `_icc_hdr'
                        local val_re = ""
                        local val_resid = ""

                        if "`icc_col_re'" != "" {
                            local val = subinstr(`icc_col_re'[`r'], ",", "", .)
                            if "`val'" != "" & "`val'" != "." {
                                local val_re = real("`val'")
                            }
                        }
                        if "`icc_col_resid'" != "" {
                            local val = subinstr(`icc_col_resid'[`r'], ",", "", .)
                            if "`val'" != "" & "`val'" != "." {
                                local val_resid = real("`val'")
                            }
                        }

                        if "`val_re'" != "" & "`val_resid'" != "" {
                            local stat_icc_`m' = `val_re' / (`val_re' + `val_resid')
                        }
                        else if "`val_re'" != "" & "`val_resid'" == "" {
                            * Binary outcome (melogit): use pi^2/3 for level-1 variance
                            local stat_icc_`m' = `val_re' / (`val_re' + c(pi)^2/3)
                        }
                    }
                }
                if _rc local n_icc_models = 0
                restore
            }

            * If the primary collect path found model rows but all ICC values are
            * still missing (e.g., multi-level models where colname[var(_cons)]
            * doesn't match the qualified labels like var(_cons[school])),
            * reset to trigger the fallback path.
            if `n_icc_models' > 0 {
                local _all_icc_miss = 1
                forvalues _im = 1/`n_icc_models' {
                    local _this_icc `"`stat_icc_`_im''"'
                    if `"`_this_icc'"' != "" {
                        if real(`"`_this_icc'"') != . local _all_icc_miss = 0
                    }
                }
                if `_all_icc_miss' local n_icc_models = 0
            }

            * Fallback: e(b) for last model only (backward compat)
            * Handles two parameterizations:
            *   mixed:   lns1_1_1:, lns2_1_1:, ... = log-SD (needs exp(2*x))
            *   melogit: /var(_cons[group]): = variance directly (no conversion)
            * Accumulates ALL random intercept levels so multi-level ICC sums
            * all grouping-level variances. Skip when the last model is a count
            * family (mepoisson/menbreg) since ICC is undefined for those rows.
            local _icc_fallback_skip = 0
            if `_meta_models' > 0 {
                if `n_stat_models' <= `_meta_models' {
                    if `model_icc_undef_`n_stat_models'' {
                        local _icc_fallback_skip = 1
                    }
                }
            }
            if `n_icc_models' == 0 & !`_icc_fallback_skip' {
                local var_re = 0
                local var_re_found = 0
                local var_resid = ""
                capture {
                    matrix `temp_b' = e(b)
                    local colnames : colfullnames `temp_b'
                    local col = 1
                    foreach colname of local colnames {
                        * mixed parameterization: lns1_1_1, lns2_1_1, lns3_1_1, etc.
                        if regexm("`colname'", "^lns[0-9]+_1_1:") {
                            local log_sd = `temp_b'[1,`col']
                            local var_re = `var_re' + exp(2 * `log_sd')
                            local var_re_found = 1
                        }
                        * melogit/meprobit parameterization: /var(_cons[group]) = variance directly
                        if regexm("`colname'", "^/var\(_cons") {
                            local var_re = `var_re' + `temp_b'[1,`col']
                            local var_re_found = 1
                        }
                        if strpos("`colname'", "lnsig_e:") {
                            local log_sd = `temp_b'[1,`col']
                            local var_resid = exp(2 * `log_sd')
                        }
                        local col = `col' + 1
                    }
                }
                if `var_re_found' & "`var_resid'" != "" {
                    local stat_icc_`n_stat_models' = `var_re' / (`var_re' + `var_resid')
                }
                else if `var_re_found' {
                    * Binary outcome (melogit): use pi^2/3 for level-1 variance
                    local stat_icc_`n_stat_models' = `var_re' / (`var_re' + c(pi)^2/3)
                }
                local n_icc_models = `n_stat_models'
            }
        }
    }

    * =========================================================================
    * DETECT MODEL TYPE FOR RANDOM EFFECTS TRANSFORMATION
    * =========================================================================
    * melogit -> Median Odds Ratio (MOR)
    * mestreg / mecloglog -> Median Hazard Ratio (MHR)
    * Note: melogit stores e(cmd)="meglm", mestreg stores e(cmd)="gsem"
    * The original command name is in e(cmd2)
    * For multi-model tables, e(cmd2) reflects the last model only.
    * RE rows only exist for mixed-effects models, so if the last model
    * is melogit/mestreg, MOR/MHR applies to its RE rows. Mixing
    * different mixed-effects model types (e.g., mixed + melogit) in one
    * table is not supported for MOR/MHR — use separate tables instead.
    local re_transform = "none"
    local model_cmd2 = ""
    capture local model_cmd2 = e(cmd2)
    if "`model_cmd2'" == "melogit" {
        local re_transform = "mor"
    }
    else if inlist("`model_cmd2'", "mecloglog", "mestreg") {
        local re_transform = "mhr"
    }

    * =========================================================================
    * STORE RANDOM EFFECTS LABELS BEFORE COLLECT EXPORT (for relabel option)
    * =========================================================================
    local re_groupvar = ""
    local re_grouplbl = ""
    local re_vars = ""
    local _n_re_levels = 0
    local _is_multilevel = 0

    * Always capture grouping variable info (needed for relabel AND MOR/MHR)
    local re_groupvars = ""
    capture local re_groupvars = e(ivars)
    * Check for empty string AND "." (missing value returned by OLS models)
    if "`re_groupvars'" != "" & "`re_groupvars'" != "." {
        local _n_re_levels : word count `re_groupvars'
        local _is_multilevel = (`_n_re_levels' > 1)
        local _path_so_far ""

        * Store label for each grouping variable
        forvalues _lev = 1/`_n_re_levels' {
            local _gvar : word `_lev' of `re_groupvars'
            local re_groupvar_`_lev' "`_gvar'"
            if "`_path_so_far'" == "" local _path_so_far "`_gvar'"
            else local _path_so_far "`_path_so_far'>`_gvar'"
            local re_grouppath_`_lev' "`_path_so_far'"
            local _glbl : variable label `_gvar'
            if "`_glbl'" == "" local _glbl "`_gvar'"
            local re_grouplbl_`_lev' "`_glbl'"
        }

        * Detect duplicate labels: if two levels share a label, fall back to
        * variable names so relabeled output is unambiguous
        if `_n_re_levels' > 1 {
            * First pass: flag which levels have duplicate labels
            forvalues _lev = 1/`_n_re_levels' {
                local _lbl_is_dup_`_lev' = 0
                forvalues _other = 1/`_n_re_levels' {
                    if `_other' != `_lev' & "`re_grouplbl_`_other''" == "`re_grouplbl_`_lev''" {
                        local _lbl_is_dup_`_lev' = 1
                    }
                }
            }
            * Second pass: apply fallback for flagged levels
            forvalues _lev = 1/`_n_re_levels' {
                if `_lbl_is_dup_`_lev'' {
                    local re_grouplbl_`_lev' "`re_groupvar_`_lev''"
                }
            }
        }

        * Backward compat: single-level vars from first grouping variable
        local re_groupvar : word 1 of `re_groupvars'
        local re_grouplbl "`re_grouplbl_1'"

        * Get random effects variables
        capture local re_vars = e(revars)
        if "`re_vars'" != "" {
            * Store labels for each random effect variable
            foreach revar of local re_vars {
                if "`revar'" == "_cons" {
                    local lbl_`revar' "Intercept"
                }
                else {
                    local lbl_`revar' : variable label `revar'
                    if "`lbl_`revar''" == "" local lbl_`revar' "`revar'"
                }
            }

            * Parse per-level random effects using e(redim)
            local _re_redim = ""
            capture local _re_redim = e(redim)
            if "`_re_redim'" != "" {
                local _re_pos = 1
                forvalues _lev = 1/`_n_re_levels' {
                    local _dim : word `_lev' of `_re_redim'
                    local re_vars_`_lev' = ""
                    forvalues _d = 1/`_dim' {
                        local _rv : word `_re_pos' of `re_vars'
                        local re_vars_`_lev' "`re_vars_`_lev'' `_rv'"
                        local _re_pos = `_re_pos' + 1
                    }
                    local re_vars_`_lev' = strtrim("`re_vars_`_lev''")
                }
            }
            else {
                * Fallback: assign all revars to level 1 when e(redim) unavailable
                local re_vars_1 "`re_vars'"
                forvalues _lev = 2/`_n_re_levels' {
                    local re_vars_`_lev' ""
                }
            }
        }
    }

    * Capture factor variable value labels for factorlabel option
    if "`factorlabel'" != "" {
        local _fvlabel_cmds ""
        capture local _fv_varlist : colnames e(b)
        if "`_fv_varlist'" != "" {
            foreach _fvterm of local _fv_varlist {
                if regexm("`_fvterm'", "^([0-9]+)\.(.+)$") {
                    local _fvval = regexs(1)
                    local _fvvar = regexs(2)
                    * Remove interaction prefix if present (e.g., c.var#1.var2)
                    if strpos("`_fvvar'", "#") > 0 continue
                    capture {
                        local _fvlbl : label (`_fvvar') `_fvval'
                        if "`_fvlbl'" != "" & "`_fvlbl'" != "`_fvval'" {
                            local _fvlabel_cmds "`_fvlabel_cmds' `_fvval'.`_fvvar'=`_fvlbl'"
                        }
                    }
                }
            }
        }
    }

    * collect export renders factor-variable children using value labels under
    * their parent row. The raw .stjson items only carry levels like 2.agecat,
    * so capture the same display labels before preserve switches to the
    * rendered string dataset.
    local _fvrow_label_n = 0
    local _fvrow_parent_n = 0
    capture quietly collect levelsof colname
    if _rc == 0 {
        local _fv_collevels `s(levels)'
        foreach _fvterm of local _fv_collevels {
            if regexm("`_fvterm'", "^([0-9]+)\.(.+)$") {
                local _fvval = regexs(1)
                local _fvvar = regexs(2)
                if strpos("`_fvvar'", "#") > 0 continue
                capture confirm variable `_fvvar'
                if _rc == 0 {
                    local _fvrow_parent_seen = 0
                    if `_fvrow_parent_n' > 0 {
                        forvalues _fvp = 1/`_fvrow_parent_n' {
                            if `"`_fvrow_parent_var_`_fvp''"' == `"`_fvvar'"' {
                                local _fvrow_parent_seen = 1
                            }
                        }
                    }
                    if !`_fvrow_parent_seen' {
                        local _fvplbl : variable label `_fvvar'
                        if `"`_fvplbl'"' == "" local _fvplbl `"`_fvvar'"'
                        local ++_fvrow_parent_n
                        local _fvrow_parent_var_`_fvrow_parent_n' `"`_fvvar'"'
                        local _fvrow_parent_lab_`_fvrow_parent_n' `"`_fvplbl'"'
                    }
                    local _fvlbl "`_fvval'"
                    capture local _fvlbl : label (`_fvvar') `_fvval'
                    if `"`_fvlbl'"' == "" local _fvlbl "`_fvval'"
                    local ++_fvrow_label_n
                    local _fvrow_pat_`_fvrow_label_n' `"`_fvterm'"'
                    local _fvrow_lab_`_fvrow_label_n' `"  `_fvlbl'"'
                }
            }
        }
    }

    * Multi-equation estimators (for example mlogit, zip, zinb, churdle)
    * need coleq#colname rows; colname alone collapses outcome/equation-specific
    * coefficients that share the same term name.
    local _is_multieq = 0
    local _use_coleq_layout = `_is_multilevel'
    local _coleq_label_n = 0
    capture quietly collect levelsof coleq
    if _rc == 0 {
        local _coleq_levels `"`s(levels)'"'
        local _coleq_n : word count `_coleq_levels'
        if `_coleq_n' > 1 & ("`re_groupvars'" == "" | "`re_groupvars'" == ".") ///
            & `_has_multieq_estimator' {
            local _is_multieq = 1
            local _use_coleq_layout = 1
        }

        * If the dependent variable has value labels, map equation names such
        * as Partial_response or 2 back to reader-facing outcome labels.
        local _depvar ""
        local _dep_label ""
        capture local _depvar "`e(depvar)'"
        local _depvar_rc = _rc
        if "`_depvar'" != "" {
            capture local _dep_label : variable label `_depvar'
            local _dep_label_rc = _rc
            local _dep_vallab ""
            capture local _dep_vallab : value label `_depvar'
            local _dep_vallab_rc = _rc
            if "`_dep_vallab'" != "" {
                capture levelsof `_depvar' if e(sample), local(_dep_levels_for_eq)
                local _dep_levels_rc = _rc
                if `_dep_levels_rc' == 0 {
                    foreach _dlev of local _dep_levels_for_eq {
                        local _dlbl ""
                        capture local _dlbl : label `_dep_vallab' `_dlev'
                        if `"`_dlbl'"' != "" {
                            local ++_coleq_label_n
                            local _coleq_key_`_coleq_label_n' `"`_dlev'"'
                            local _coleq_key2_`_coleq_label_n' `"`=strtoname(`"`_dlbl'"')'"'
                            local _coleq_lab_`_coleq_label_n' `"`_dlbl'"'
                        }
                    }
                }
            }
        }
    }

collect label levels result _r_b "`coef'", modify
collect label levels result _r_ci "`_ci_level'% CI", modify
collect label levels result _r_p "p-value", modify
collect style cell result[_r_b], warn nformat(%4.2fc) halign(center) valign(center)
collect style cell result[_r_ci], warn nformat(%12.8f) sformat("(%s)") cidelimiter("`sep'") halign(center) valign(center)
collect style cell result[_r_p], warn nformat(%5.4f) halign(center) valign(center)
collect style column, dups(center)
collect style row stack, nodelimiter nospacer indent length(.) wrapon(word) noabbreviate wrap(.) truncate(tail)

* Multi-level mixed models: use coleq#colname to preserve per-level RE rows
* (colname layout collapses duplicate var(_cons) across levels)
if `_use_coleq_layout' {
    collect layout (coleq#colname) (cmdset#result[_r_b _r_ci _r_p]) ()
}
else {
    collect layout (colname) (cmdset#result[_r_b _r_ci _r_p]) ()
}

* Capture the colname level<->label map while collect is still active.
* collect renders the variable LABEL into column A, so keep()/drop() by raw
* variable name cannot match A directly. This map lets us reconstruct the raw
* coefficient name per row (see _raw_colname construction after rendering).
local _cnmap_n = 0
capture quietly collect label list colname
if _rc == 0 {
    local _cnmap_n = real("`s(k)'")
    if missing(`_cnmap_n') local _cnmap_n = 0
    forvalues _ci = 1/`_cnmap_n' {
        local _cnmap_level_`_ci' `"`s(level`_ci')'"'
        local _cnmap_label_`_ci' `"`s(label`_ci')'"'
    }
}

* Preserve user data before rendering the collect table into a string dataset
preserve

local _collect_render_rc = 0
if `_use_coleq_layout' {
    capture _tabtools_collect_render, type(main) rowdim(coleq#colname) ///
        coldim(cmdset) results(_r_b _r_ci _r_p) sep("`sep'")
    local _collect_render_rc = _rc
}
else {
    capture _tabtools_collect_render, type(main) rowdim(colname) ///
        coldim(cmdset) results(_r_b _r_ci _r_p) sep("`sep'") factorparents
    local _collect_render_rc = _rc
}
if `_collect_render_rc' {
    * Keep the workbook import path as a defensive fallback if raw .stjson
    * parsing cannot represent a collect layout emitted by this Stata build.
    restore
    capture collect export "`temp_xlsx'", sheet(temp,replace) modify
    if _rc {
        noisily display as error "Failed to export collect table to temporary Excel file"
        noisily display as error "Check that collect table is properly structured"
        exit _rc
    }
    preserve
    capture _tabtools_xlsx_read using "`temp_xlsx'", sheet(temp)
    if _rc {
        noisily display as error "Failed to import temporary Excel file"
        capture erase "`temp_xlsx'"
        restore
        exit _rc
    }
}
* Note: DO NOT TRIM WHITE SPACE--NEED IT FOR LEADING INDENT FOR CATEGORICAL VARIABLE

* Guard against empty collect tables (R3)
if _N < 3 {
	noisily display as error "Collect table appears empty or has insufficient data"
	capture erase "`temp_xlsx'"
	restore
	exit 2000
}

* Build the raw coefficient-name column BEFORE any A relabeling/flattening, so
* keep()/drop() can match by variable name. Column A holds the rendered label
* (collect substitutes variable labels); default _raw_colname to A (correct for
* unlabeled coefficients, where A already is the raw name) and reverse-map the
* labeled levels back to their raw colname using the map captured above. This
* rides along through all subsequent row drops/sorts as a real variable.
capture confirm variable _raw_colname
if _rc {
	quietly gen strL _raw_colname = ""
	quietly replace _raw_colname = strtrim(A) if _n > 2
	forvalues _ci = 1/`_cnmap_n' {
		quietly replace _raw_colname = `"`_cnmap_level_`_ci''"' ///
			if _n > 2 & strtrim(A) == `"`_cnmap_label_`_ci''"'
	}
}

* Flatten coleq#colname hierarchical layout for multi-level models
* In coleq#colname layout, the exported structure is:
*   Header rows: coleq values (equation labels: "y", "District", "School", "Residual")
*   Data rows:   colname values (indented: "  x", "  var(_cons)", "  var(e)")
* Goal: merge each data row with its parent header into bracket notation:
*   header="District" + data="  var(_cons)" -> "var(_cons[district])"
*   header="y" + data="  x" -> "x"
if `_is_multilevel' {
    quietly count if _n > 2 ///
        & strpos(A, "[") > 0 & strpos(A, "]") > 0 ///
        & (strpos(A, "var(") > 0 | strpos(A, "cov(") > 0 | strpos(A, "sd(") > 0)
    local _qualified_re_layout = (r(N) > 0)

    if `_qualified_re_layout' {
        * Newer collect exports already encode multi-level RE rows with
        * bracketed group paths (for example var(_cons[district>school])).
        * Normalize nested paths to the terminal grouping variable so the
        * downstream relabel/MOR logic can match them reliably.
        replace A = strtrim(A) if _n > 2
        gen byte _q_is_header = _n > 2 & (strtrim(B) == "" | B == ".")
        drop if _q_is_header
        drop _q_is_header
        forvalues _lev = 1/`_n_re_levels' {
            local _gvar "`re_groupvar_`_lev''"
            local _gpath "`re_grouppath_`_lev''"
            if "`_gpath'" != "`_gvar'" {
                replace A = subinstr(A, "[`_gpath']", "[`_gvar']", .) ///
                    if _n > 2 & (strpos(A, "var(") > 0 | strpos(A, "cov(") > 0 | strpos(A, "sd(") > 0)
            }
        }
    }
    else {
        * Identify header rows: rows > 2 where B (data column) is empty
        gen byte _is_header = (strtrim(B) == "" | B == ".") & _n > 2

        * Propagate coleq header label down to each data row
        gen str244 _parent_header = A if _is_header
        replace _parent_header = _parent_header[_n-1] if _parent_header == "" & _n > 2

        * Trim once for reuse: strip coleq indent from A and whitespace from header
        gen str244 _A_trim = strtrim(A) if _n > 2
        replace _parent_header = strtrim(_parent_header) if _n > 2

        * Map coleq labels to variable names using POSITIONAL group IDs
        * (avoids label collisions when two grouping vars share the same label)
        * Each header row starts a new group via running sum of _is_header:
        *   group 1 = FE equation ("y"), group 2 = RE level 1, group 3 = RE level 2, ...
        gen int _hdr_grp = sum(_is_header)
        * The FE equation is always group 1; RE levels follow in order
        local _fe_grp = 1
        forvalues _lev = 1/`_n_re_levels' {
            local _gvar "`re_groupvar_`_lev''"
            local _target_grp = `_fe_grp' + `_lev'
            replace _parent_header = "`_gvar'" if _hdr_grp == `_target_grp'
        }
        * Residual group is after all RE levels — leave as-is (handled below)
        drop _hdr_grp

        * Check if the DATA row (colname) contains an RE pattern
        gen byte _data_is_re = (strpos(_A_trim, "var(") > 0 | ///
            strpos(_A_trim, "cov(") > 0 | strpos(_A_trim, "sd(") > 0) & !_is_header

        * RE data rows (not Residual): splice header groupvar into bracket notation
        * "  var(_cons)" + header "district" -> "var(_cons[district])"
        replace A = subinstr(_A_trim, ")", "[" + _parent_header + "])", 1) ///
            if _data_is_re & _parent_header != "Residual" & _n > 2

        * Residual data row: just trim indent
        replace A = _A_trim if _data_is_re & _parent_header == "Residual" & _n > 2

        * FE data rows: use data row's own colname (strip coleq indent)
        replace A = _A_trim if !_is_header & !_data_is_re & _n > 2

        * Drop the coleq header rows (no data)
        drop if _is_header
        drop _is_header _parent_header _data_is_re _A_trim
    }
}
else if `_is_multieq' {
    gen byte _is_header = (strtrim(B) == "" | B == ".") & _n > 2
    gen str244 _parent_header = A if _is_header
    replace _parent_header = _parent_header[_n-1] if _parent_header == "" & _n > 2
    replace _parent_header = strtrim(_parent_header) if _n > 2

    gen str244 _A_trim = strtrim(A) if _n > 2
    gen str244 _eq_label = _parent_header if _n > 2
    if `_coleq_label_n' > 0 {
        forvalues _eqi = 1/`_coleq_label_n' {
            replace _eq_label = `"`_coleq_lab_`_eqi''"' ///
                if _eq_label == `"`_coleq_key_`_eqi''"' ///
                | _eq_label == `"`_coleq_key2_`_eqi''"'
        }
    }
    if `"`_dep_label'"' != "" {
        replace _eq_label = `"`_dep_label'"' if _eq_label == `"`_depvar'"'
    }
    replace _eq_label = "Inflation equation" if strlower(_eq_label) == "inflate"
    replace _eq_label = "Selection equation" ///
        if inlist(strlower(_eq_label), "selection_ll", "selection_ul", "selection")
    replace _eq_label = "Scale" if strlower(_eq_label) == "lnsigma"
    replace _eq_label = "Ancillary" ///
        if strlower(_eq_label) == "/" | regexm(strlower(_eq_label), "^_diparm")
    replace _eq_label = subinstr(_eq_label, "_", " ", .) if _n > 2
    replace _A_trim = "Intercept" if inlist(strlower(_A_trim), "_cons", "constant", "intercept")

    * Omitted rows from base outcomes add noise and can masquerade as
    * reference-category coefficients for every covariate.
    gen byte _drop_omitted_eq = !_is_header & _n > 2 & ///
        (substr(_A_trim, 1, 2) == "o." | strpos(_A_trim, "o.") == 1)
    drop if _drop_omitted_eq
    drop _drop_omitted_eq

    replace A = _eq_label + ": " + _A_trim ///
        if !_is_header & _eq_label != "" & _A_trim != "" & _n > 2
    drop if _is_header
    drop _is_header _parent_header _A_trim _eq_label
}

if "`noint'" != "" {
    gen str244 _noint_row = strlower(strtrim(A)) if _n > 2
    drop if _n > 2 & ( ///
        regexm(_noint_row, "^(intercept|_cons|constant)$") ///
        | regexm(_noint_row, ": +(intercept|_cons|constant)$") ///
        | regexm(_noint_row, "^/?cut[0-9]+$") ///
        | regexm(_noint_row, ": +/?cut[0-9]+$") ///
        | regexm(_noint_row, "^(/|alpha$|lnalpha$|ln_p$|p$|1/p$)") ///
        | regexm(_noint_row, ": +(/|alpha|lnalpha|ln_p|p|1/p)$") ///
        | regexm(_noint_row, "^ancillary:") ///
        | regexm(_noint_row, "^scale:") ///
    )
    capture drop _noint_row
}

if "`nore'" != "" {
	drop if strpos(A,"var(") > 0 | strpos(A,"cov(") > 0 | strpos(A,"sd(") > 0
}

* Reorder: fixed effects first, then random effects (collect may interleave them)
gen _orig_order = _n
gen byte _is_re_sort = (strpos(A, "var(") > 0) | (strpos(A, "cov(") > 0) | (strpos(A, "sd(") > 0)
* Row 1 is header — keep at top
replace _is_re_sort = 0 if _n <= 2
sort _is_re_sort _orig_order
drop _orig_order _is_re_sort

* Persist RE markers so keep()/drop() cannot desynchronize them from the
* filtered table body later in the pipeline.
gen byte _is_re = _n > 2 & (strpos(A, "var(") > 0 | strpos(A, "cov(") > 0 | strpos(A, "sd(") > 0)
gen byte _is_re_intercept = 0
gen str244 _re_group_label = ""
if "`re_transform'" != "none" & "`nore'" == "" {
    replace _is_re_intercept = strpos(A, "var(_cons") > 0 if _n > 2
    if "`re_groupvars'" != "" & "`re_groupvars'" != "." {
        forvalues _lev = 1/`_n_re_levels' {
            local _gvar "`re_groupvar_`_lev''"
            local _gpath "`re_grouppath_`_lev''"
            local _glbl "`re_grouplbl_`_lev''"
            replace _re_group_label = "`_glbl'" if A == "var(_cons[`_gvar'])"
            if "`_gpath'" != "`_gvar'" {
                replace _re_group_label = "`_glbl'" if A == "var(_cons[`_gpath'])"
            }
            replace _re_group_label = "`_glbl'" ///
                if _is_re_intercept == 1 & _re_group_label == "" ///
                & (strpos(A, "[`_gvar']") > 0 | strpos(A, ">`_gvar']") > 0)
        }
    }
    if "`re_grouplbl'" != "" {
        replace _re_group_label = "`re_grouplbl'" if _re_group_label == "" & A == "var(_cons)"
    }
}

* Relabel random effects if requested
if "`relabel'" != "" {
    if "`re_groupvars'" != "" & "`re_groupvars'" != "." {

        * --- Per-level relabeling (bracket notation) ---
        * Handles multi-level mixed (flattened) and melogit/mepoisson (native)
        forvalues _lev = 1/`_n_re_levels' {
            local _gvar "`re_groupvar_`_lev''"
            local _glbl "`re_grouplbl_`_lev''"

            * Random intercept: var(_cons[groupvar]) -> "Variance: GroupLabel (Intercept)"
            replace A = "Variance: `_glbl' (Intercept)" if A == "var(_cons[`_gvar'])"

            * Random slopes: var(varname[groupvar]) -> "Variance: GroupLabel (VarLabel)"
            foreach revar of local re_vars {
                if "`revar'" != "_cons" {
                    local slope_lbl "`lbl_`revar''"
                    replace A = "Variance: `_glbl' (`slope_lbl')" if A == "var(`revar'[`_gvar'])"
                }
            }

            * Covariances: cov(var1,var2[groupvar]) -> "Covariance: GroupLabel (Label1, Label2)"
            count if strpos(A, "cov(") > 0 & strpos(A, "[`_gvar']") > 0
            if r(N) > 0 {
                gen _temp_row = _n
                levelsof _temp_row if strpos(A, "cov(") > 0 & strpos(A, "[`_gvar']") > 0, local(cov_rows)
                foreach row of local cov_rows {
                    local cov_str = A[`row']
                    * Extract: cov(var1,var2[groupvar]) -> inner = var1,var2
                    local cov_inner = subinstr("`cov_str'", "cov(", "", 1)
                    local cov_inner = subinstr("`cov_inner'", "[`_gvar'])", "", 1)
                    gettoken cov_v1 cov_v2 : cov_inner, parse(",")
                    local cov_v2 = subinstr("`cov_v2'", ",", "", 1)
                    local cov_v1 = strtrim("`cov_v1'")
                    local cov_v2 = strtrim("`cov_v2'")
                    local cov_lbl1 "`lbl_`cov_v1''"
                    if "`cov_lbl1'" == "" local cov_lbl1 "`cov_v1'"
                    local cov_lbl2 "`lbl_`cov_v2''"
                    if "`cov_lbl2'" == "" local cov_lbl2 "`cov_v2'"
                    replace A = "Covariance: `_glbl' (`cov_lbl1', `cov_lbl2')" in `row'
                }
                drop _temp_row
            }

            * Standard deviations with brackets
            replace A = "`_glbl' SD (Intercept)" if A == "sd(_cons[`_gvar'])"
            foreach revar of local re_vars {
                if "`revar'" != "_cons" {
                    local slope_lbl "`lbl_`revar''"
                    replace A = "`_glbl' SD (`slope_lbl')" if A == "sd(`revar'[`_gvar'])"
                }
            }
        }

        * --- Single-level patterns (no brackets) for single-level mixed ---
        replace A = "Variance: `re_grouplbl' (Intercept)" if A == "var(_cons)"

        foreach revar of local re_vars {
            if "`revar'" != "_cons" {
                local slope_lbl "`lbl_`revar''"
                replace A = "Variance: `re_grouplbl' (`slope_lbl')" if A == "var(`revar')"
            }
        }

        * Covariances without brackets (single-level mixed)
        count if strpos(A, "cov(") > 0
        if r(N) > 0 {
            gen _temp_row = _n
            levelsof _temp_row if strpos(A, "cov(") > 0, local(cov_rows)
            foreach row of local cov_rows {
                local cov_str = A[`row']
                local cov_inner = subinstr("`cov_str'", "cov(", "", 1)
                local cov_inner = subinstr("`cov_inner'", ")", "", 1)
                gettoken cov_v1 cov_v2 : cov_inner, parse(",")
                local cov_v2 = subinstr("`cov_v2'", ",", "", 1)
                local cov_v1 = strtrim("`cov_v1'")
                local cov_v2 = strtrim("`cov_v2'")
                local cov_lbl1 "`lbl_`cov_v1''"
                if "`cov_lbl1'" == "" local cov_lbl1 "`cov_v1'"
                local cov_lbl2 "`lbl_`cov_v2''"
                if "`cov_lbl2'" == "" local cov_lbl2 "`cov_v2'"
                replace A = "Covariance: `re_grouplbl' (`cov_lbl1', `cov_lbl2')" in `row'
            }
            drop _temp_row
        }

        * Residual variance: var(e) -> "Residual Variance"
        replace A = "Residual Variance" if A == "var(e)"

        * Standard deviations without brackets (single-level)
        replace A = "`re_grouplbl' SD (Intercept)" if A == "sd(_cons)"
        foreach revar of local re_vars {
            if "`revar'" != "_cons" {
                local slope_lbl "`lbl_`revar''"
                replace A = "`re_grouplbl' SD (`slope_lbl')" if A == "sd(`revar')"
            }
        }
        replace A = "Residual SD" if A == "sd(e)"

        * Log-scale parameters (raw coefficient names: lns1_1_1, lns2_1_1, ...)
        forvalues _lev = 1/`_n_re_levels' {
            local _glbl "`re_grouplbl_`_lev''"
            replace A = subinstr(A, "lns`_lev'_1_1", "`_glbl' Log SD (Intercept)", .)
        }
        replace A = subinstr(A, "lnsig_e", "Residual Log SD", .)
    }
    else {
        * Fallback: no random effects info, use generic labels
        replace A = subinstr(A, "var(_cons)", "Variance (Intercept)", .)
        replace A = subinstr(A, "var(e.", "Variance (Residual", .)
        replace A = subinstr(A, "var(e)", "Residual Variance", .)
        replace A = subinstr(A, "var(", "Variance (", .)
        replace A = subinstr(A, "cov(", "Covariance (", .)
        replace A = subinstr(A, "sd(_cons)", "SD (Intercept)", .)
        replace A = subinstr(A, "sd(e.", "SD (Residual", .)
        replace A = subinstr(A, "sd(", "SD (", .)
        * Log-scale parameters: handle all levels (lns1_1_1, lns2_1_1, ...)
        if `_n_re_levels' > 0 {
            forvalues _lev = 1/`_n_re_levels' {
                replace A = subinstr(A, "lns`_lev'_1_1", "Log SD (Level `_lev' Intercept)", .)
            }
        }
        else {
            replace A = subinstr(A, "lns1_1_1", "Log SD (Intercept)", .)
        }
        replace A = subinstr(A, "lnsig_e", "Log SD (Residual)", .)
    }

    * Clean up _cons in fixed effects (Intercept row)
    replace A = subinstr(A, "_cons", "Intercept", .)
}

* Apply MOR/MHR labels using row-level group metadata.
if "`re_transform'" == "mor" & "`nore'" == "" {
    replace A = "Median Odds Ratio (" + _re_group_label + ")" ///
        if _is_re_intercept == 1 & _re_group_label != ""
    replace A = "Median Odds Ratio" ///
        if _is_re_intercept == 1 & _re_group_label == ""
}
else if "`re_transform'" == "mhr" & "`nore'" == "" {
    replace A = "Median Hazard Ratio (" + _re_group_label + ")" ///
        if _is_re_intercept == 1 & _re_group_label != ""
    replace A = "Median Hazard Ratio" ///
        if _is_re_intercept == 1 & _re_group_label == ""
}

* Get all variables - first variable is row labels, rest are data columns
ds
local allvars `r(varlist)'
local _helper_vars "_is_re _is_re_intercept _re_group_label _raw_colname"
local allvars : list allvars - _helper_vars

* Get the first variable name (row labels column)
gettoken firstvar allvars : allvars

* Rename the first variable to A if it's not already named A
if "`firstvar'" != "A" {
	rename `firstvar' A
}

* Rename remaining variables to c1, c2, c3, etc.
local n 1
foreach var of local allvars {
	rename `var' c`n'
	replace c`n' = "" if _n == 1
	local n `=`n'+1'
}
local n2 `=`n'-3'
local n `=`n'-1'
* Model count (used by stats() and ICC placement)
local n_models = `n' / 3
* _raw_colname carries the true coefficient name (built before A was relabeled);
* use it so keep()/drop() match by variable name. Fall back to A for the xlsx
* import path, which bypasses the collect renderer and has no _raw_colname.
capture confirm variable _raw_colname
if _rc == 0 {
	rename _raw_colname _raw_A
}
else {
	clonevar _raw_A = A
}

if "`models'" != "" {
    * Split models string by backslashes
	local models : subinstr local models " \ " "\", all
	local models : subinstr local models "\  " "\", all
	local models : subinstr local models "  \" "\", all
    tokenize `"`models'"', parse("\")
    local model_idx = 1
    local col_idx = 1

    * Loop through tokenized results
    while "``model_idx''" != "" {
        if "``model_idx''" != "\" {
            * Apply label to appropriate column
            replace c`col_idx' = "``model_idx''" if _n == 1
            local col_idx = `col_idx' + 3
        }
        local model_idx = `model_idx' + 1
    }
}
else {
    * Auto-generate model headers: "Model 1", "Model 2", ...
    local col_idx = 1
    forvalues _mi = 1/`n_models' {
        if `n_models' == 1 {
            replace c`col_idx' = "Model" if _n == 1
        }
        else {
            replace c`col_idx' = "Model `_mi'" if _n == 1
        }
        local col_idx = `col_idx' + 3
    }
}

if !`_user_coef_spec' & "`cdisc'" == "" & `_meta_models' > 0 {
    local _hdr_m = 0
    forvalues _hdr_col = 1(3)`n' {
        local _hdr_m = `_hdr_m' + 1
        replace c`_hdr_col' = "`model_coef_`_hdr_m''" if _n == 2
    }
}

* Apply collect-style factor parent and child labels captured before rendering.
* Parent rows keep the variable label flush-left; child levels are indented.
if `_fvrow_parent_n' > 0 {
    forvalues _fvp = 1/`_fvrow_parent_n' {
        replace A = `"`_fvrow_parent_lab_`_fvp''"' ///
            if strtrim(A) == `"`_fvrow_parent_var_`_fvp''"' & _n >= 3
    }
}
if `_fvrow_label_n' > 0 {
    forvalues _fvi = 1/`_fvrow_label_n' {
        replace A = `"`_fvrow_lab_`_fvi''"' ///
            if strtrim(A) == `"`_fvrow_pat_`_fvi''"' & _n >= 3
    }
}

* Apply factor variable value labels if requested
if "`factorlabel'" != "" & "`_fvlabel_cmds'" != "" {
    foreach _fvcmd of local _fvlabel_cmds {
        local _fvpat = substr("`_fvcmd'", 1, strpos("`_fvcmd'", "=") - 1)
        local _fvlbl = substr("`_fvcmd'", strpos("`_fvcmd'", "=") + 1, .)
        replace A = "  `_fvlbl'" if strtrim(A) == "`_fvpat'" & _n >= 3
    }
}

* Relabel ordered-outcome cutpoint rows (cut1, /cut1, cut2, ...).
* Labels are positional and split on backslashes to match models().
if `"`cutlabels'"' != "" {
    local _cutlabels_rest `"`cutlabels'"'
    local _cut_bslash = char(92)
    local _cut_n = 0
    while `"`_cutlabels_rest'"' != "" {
        local _cut_pos = strpos(`"`_cutlabels_rest'"', "`_cut_bslash'")
        if `_cut_pos' > 0 {
            local _cut_piece = strtrim(substr(`"`_cutlabels_rest'"', 1, `_cut_pos' - 1))
            local _cutlabels_rest = strtrim(substr(`"`_cutlabels_rest'"', `_cut_pos' + 1, .))
        }
        else {
            local _cut_piece = strtrim(`"`_cutlabels_rest'"')
            local _cutlabels_rest ""
        }
        if `"`_cut_piece'"' != "" {
            local ++_cut_n
            local _cut_label_`_cut_n' `"`_cut_piece'"'
        }
    }
    forvalues _cut_i = 1/`_cut_n' {
        replace A = `"`_cut_label_`_cut_i''"' ///
            if _n >= 3 & regexm(strlower(strtrim(A)), "^/?cut`_cut_i'$")
    }
}

* Filter rows by keep/drop list
* A holds the rendered label; _raw_A holds the raw coefficient/variable name.
* Match tokens against either, by exact value or substring (covers factor
* prefixes like 2.arm and label substrings).
* Each token is matched as typed and with leading/embedded factor operators
* (i. c. o.) stripped, so natural fvvarlist notation -- keep(i.foreign),
* keep(1.foreign#c.mpg) -- matches the rendered coefficient name (foreign,
* 1.foreign#mpg). A keep()/drop() that empties the body is almost always a
* mis-typed token; refuse it loudly rather than writing a headers-only table.
if "`keep'" != "" {
    quietly count if _n > 2
    local _nbody_pre = r(N)
    gen byte _keep = 0
    replace _keep = 1 if _n <= 2
    foreach _kvar in `keep' {
        local _kt = strlower("`_kvar'")
        local _kn : subinstr local _kt "i." "", all
        local _kn : subinstr local _kn "c." "", all
        local _kn : subinstr local _kn "o." "", all
        foreach _kk in `"`_kt'"' `"`_kn'"' {
            if "`_kk'" == "" continue
            replace _keep = 1 if strtrim(strlower(A)) == "`_kk'"
            replace _keep = 1 if strpos(strlower(A), "`_kk'") > 0
            replace _keep = 1 if strtrim(strlower(_raw_A)) == "`_kk'"
            replace _keep = 1 if strpos(strlower(_raw_A), "`_kk'") > 0
        }
    }
    quietly count if _keep & _n > 2
    if `_nbody_pre' > 0 & r(N) == 0 {
        drop _keep
        noisily display as error ///
            "keep() matched no coefficient rows; matching is by variable name or label substring -- check the keep() spec"
        exit 198
    }
    drop if !_keep
    drop _keep
}
if "`drop'" != "" {
    quietly count if _n > 2
    local _nbody_pre = r(N)
    gen byte _dropflag = 0
    foreach _dvar in `drop' {
        local _dt = strlower("`_dvar'")
        local _dn : subinstr local _dt "i." "", all
        local _dn : subinstr local _dn "c." "", all
        local _dn : subinstr local _dn "o." "", all
        foreach _dk in `"`_dt'"' `"`_dn'"' {
            if "`_dk'" == "" continue
            replace _dropflag = 1 if strtrim(strlower(A)) == "`_dk'" & _n > 2
            replace _dropflag = 1 if strpos(strlower(A), "`_dk'") > 0 & _n > 2
            replace _dropflag = 1 if strtrim(strlower(_raw_A)) == "`_dk'" & _n > 2
            replace _dropflag = 1 if strpos(strlower(_raw_A), "`_dk'") > 0 & _n > 2
        }
    }
    quietly count if _dropflag
    if `_nbody_pre' > 0 & r(N) >= `_nbody_pre' {
        drop _dropflag
        noisily display as error ///
            "drop() would remove every coefficient row, leaving an empty table; check the drop() spec"
        exit 198
    }
    drop if _dropflag
    drop _dropflag
}

local first_re_row ""
gen long _re_rowid = _n
quietly summarize _re_rowid if _is_re == 1, meanonly
if r(N) > 0 local first_re_row = r(min)
drop _re_rowid

local last = `n' - 2
gen byte _is_ancillary = 0
replace _is_ancillary = 1 if _n > 2 & regexm(strlower(strtrim(A)), "^(/|alpha$|lnalpha$|ln_p$|p$|1/p$)")
replace _is_ancillary = 1 if _n > 2 & ///
    regexm(strlower(strtrim(A)), ": +(/|alpha|lnalpha|ln_p|p|1/p)$")
replace _is_ancillary = 1 if _n > 2 & regexm(strlower(strtrim(_raw_A)), "^/?cut[0-9]+$")
replace _is_ancillary = 1 if _n > 2 & regexm(strlower(strtrim(A)), "^/?cut[0-9]+$")
if "`dimnonsig'" != "" {
    capture drop _nonsig _ci_seen
    gen byte _nonsig = (_n >= 3)
    gen byte _ci_seen = 0
}
local _model_ix = 0
gen byte _is_base_level = regexm(strlower(strtrim(_raw_A)), ///
	"(^|#)[-0-9]+(b|bn)?\.") if _n >= 3
replace _is_base_level = 0 if missing(_is_base_level)
forvalues i = 1(3)`last'{
local _model_ix = `_model_ix' + 1
local _needs_eform = 0
if `_model_ix' <= `_meta_models' local _needs_eform = `model_eform_`_model_ix''
* Strip thousands separators (collect's %#.#fc nformat emits "1,234.56") so
* destring can parse coefficients >= 1000 instead of returning missing.
replace c`i' = subinstr(c`i', ",", "", .) if _n >= 3
destring c`i', gen(double c`i'z) force
* Reference categories are identified from collect's factor-level key, not
* from a numerical 0/1 value that may be a legitimate coefficient.
replace c`i' = "`refcat'" if _is_base_level & c`=`i'+1' == "" & _n >= 3
if `_needs_eform' {
    replace c`i'z = exp(c`i'z) if !_is_re & !_is_ancillary & !missing(c`i'z)
}
* MOR/MHR transformation: variance -> exp(sqrt(2*var) * invnormal(0.75))
if "`re_transform'" != "none" {
    replace c`i'z = exp(sqrt(2 * c`i'z) * invnormal(0.75)) ///
        if _is_re_intercept == 1 & !missing(c`i'z) & c`i'z >= 0
}
	gen double _coefnum`i' = c`i'z if _n >= 3
	capture confirm variable _eplot_est`_model_ix'
	if _rc gen double _eplot_est`_model_ix' = .
	replace _eplot_est`_model_ix' = c`i'z if _n >= 3
* Fixed effects: user-specified decimal places (default 2)
gen str20 c`i'_fmt = string(round(c`i'z, `coef_round'), "`coef_fmt'") if !_is_re & !missing(c`i'z)
* Transformed random intercept (MOR/MHR): same precision as fixed effects
replace c`i'_fmt = string(round(c`i'z, `coef_round'), "`coef_fmt'") ///
    if _is_re_intercept == 1 & "`re_transform'" != "none" & !missing(c`i'z)
* Other random effects: same decimal places as fixed effects
replace c`i'_fmt = string(round(c`i'z, `coef_round'), "`coef_fmt'") ///
    if _is_re & _is_re_intercept == 0 & !missing(c`i'z)
replace c`i' = c`i'_fmt if c`i'_fmt != "" & c`i' != "`refcat'" & _n >= 3
drop c`i'z c`i'_fmt
capture confirm variable c`=`i'+1'
if _rc == 0 replace c`=`i'+1' = "" if _n == 1
capture confirm variable c`=`i'+2'
if _rc == 0 replace c`=`i'+2' = "" if _n == 1
}
drop _is_base_level
* Reformat CI columns with appropriate precision
local sep_len = strlen(`"`sep'"')
local _model_ix = 0
forvalues i = 2(3)`=`last'+1' {
    local _model_ix = `_model_ix' + 1
    local _needs_eform = 0
    local _null = cond(inlist("`coef'", "OR", "HR", "IRR", "RRR", "SHR", "TR"), 1, 0)
    if `_model_ix' <= `_meta_models' {
        local _needs_eform = `model_eform_`_model_ix''
        local _null = `model_null_`_model_ix''
    }
    capture confirm variable c`i'
    if _rc continue
    gen _ci_raw = strtrim(c`i') if _n >= 3
    replace _ci_raw = subinstr(subinstr(_ci_raw, "(", "", 1), ")", "", 1)
    * Strip thousands separators (collect's %#.#fc nformat emits "(1,234.56,
    * 2,345.67)"). Only safe when sep contains whitespace: a sep "comma+space"
    * disambiguates from a thousands "comma+digit". For exotic sep values
    * without whitespace we leave the string untouched and rely on the user
    * having matched the format precision in their collect style.
    if strpos(`"`sep'"', " ") > 0 {
        replace _ci_raw = subinstr(_ci_raw, `"`sep'"', "|||SEP|||", 1)
        replace _ci_raw = subinstr(_ci_raw, ",", "", .)
        replace _ci_raw = subinstr(_ci_raw, "|||SEP|||", `"`sep'"', 1)
    }
    gen int _ci_dpos = strpos(_ci_raw, `"`sep'"')
    gen _ci_lo_s = strtrim(substr(_ci_raw, 1, _ci_dpos - 1)) if _ci_dpos > 0
    gen _ci_hi_s = strtrim(substr(_ci_raw, _ci_dpos + `sep_len', .)) if _ci_dpos > 0
    destring _ci_lo_s, gen(double _ci_lo) force
    destring _ci_hi_s, gen(double _ci_hi) force
    if `_needs_eform' {
        replace _ci_lo = exp(_ci_lo) if !_is_re & !_is_ancillary & !missing(_ci_lo)
        replace _ci_hi = exp(_ci_hi) if !_is_re & !_is_ancillary & !missing(_ci_hi)
    }
    * MOR/MHR transformation of CI bounds
    if "`re_transform'" != "none" {
        replace _ci_lo = exp(sqrt(2 * _ci_lo) * invnormal(0.75)) ///
            if _is_re_intercept == 1 & !missing(_ci_lo) & _ci_lo >= 0
        replace _ci_hi = exp(sqrt(2 * _ci_hi) * invnormal(0.75)) ///
            if _is_re_intercept == 1 & !missing(_ci_hi) & _ci_hi >= 0
    }
	    gen str50 _ci_fmt = ""
	    capture confirm variable _eplot_ll`_model_ix'
	    if _rc gen double _eplot_ll`_model_ix' = .
	    capture confirm variable _eplot_ul`_model_ix'
	    if _rc gen double _eplot_ul`_model_ix' = .
	    replace _eplot_ll`_model_ix' = _ci_lo if _n >= 3 & _ci_lo < .
	    replace _eplot_ul`_model_ix' = _ci_hi if _n >= 3 & _ci_hi < .
	    * Fixed effects: user-specified decimal places
    replace _ci_fmt = "(" + string(_ci_lo, "`ci_fmt'") + `"`sep'"' + string(_ci_hi, "`ci_fmt'") + ")" ///
        if !_is_re & !missing(_ci_lo) & !missing(_ci_hi) & _n >= 3
    * Transformed random intercept (MOR/MHR): same precision as fixed effects
    replace _ci_fmt = "(" + string(_ci_lo, "`ci_fmt'") + `"`sep'"' + string(_ci_hi, "`ci_fmt'") + ")" ///
        if _is_re_intercept == 1 & "`re_transform'" != "none" & !missing(_ci_lo) & !missing(_ci_hi) & _n >= 3
    * Other random effects: same decimal places as fixed effects
    replace _ci_fmt = "(" + string(_ci_lo, "`ci_fmt'") + `"`sep'"' + string(_ci_hi, "`ci_fmt'") + ")" ///
        if _is_re & _is_re_intercept == 0 & !missing(_ci_lo) & !missing(_ci_hi) & _n >= 3
    replace c`i' = _ci_fmt if _ci_fmt != ""
    * Save non-significance flag for dimnonsig formatting
    if "`dimnonsig'" != "" {
        replace _ci_seen = 1 if !_is_re & !_is_ancillary & !missing(_ci_lo) & !missing(_ci_hi) & _n >= 3
        replace _nonsig = 0 if !_is_re & !_is_ancillary & !missing(_ci_lo) & !missing(_ci_hi) ///
            & (_ci_hi < `_null' | _ci_lo > `_null') & _n >= 3
    }
    drop _ci_raw _ci_dpos _ci_lo_s _ci_hi_s _ci_lo _ci_hi _ci_fmt
}
if "`dimnonsig'" != "" {
    gen byte _is_refrow = 0
    forvalues _ri = 1(3)`last' {
        replace _is_refrow = 1 if c`_ri' == "`refcat'" & _n >= 3
    }
    gen byte _is_cathead = (_ci_seen == 0 & !_is_refrow & _n >= 3)
    forvalues _ri = 1(3)`last' {
        replace _is_cathead = 0 if _is_cathead == 1 & strtrim(c`_ri') != "" & _n >= 3
    }
    replace _nonsig = 0 if _ci_seen == 0 & !_is_refrow & !_is_cathead & _n >= 3
    forvalues _obs = 3/`=_N' {
        if _is_cathead[`_obs'] == 1 {
            local _hdr_obs = `_obs'
            local _any_sig = 0
            local _has_ref = 0
            local _child = `_obs' + 1
            while `_child' <= _N {
                if _is_cathead[`_child'] == 1 continue, break
                local _child_A = A[`_child']
                if substr("`_child_A'", 1, 1) != " " continue, break
                if _is_refrow[`_child'] == 1 local _has_ref = 1
                if _nonsig[`_child'] == 0 local _any_sig = 1
                local _child = `_child' + 1
            }
            if `_has_ref' & `_any_sig' {
                replace _nonsig = 0 in `_hdr_obs'
            }
            else if !`_has_ref' {
                replace _nonsig = 0 in `_hdr_obs'
            }
        }
    }
    drop _is_refrow _is_cathead
}
forvalues i = 3(3)`n'{
* Store original string value to detect genuinely missing p-values
gen str20 c`i'_orig = c`i'
	* Convert to numeric - force will set non-numeric to missing
	destring c`i', gen(c`i'z) force
	local _model_ix = `i' / 3
	capture confirm variable _eplot_p`_model_ix'
	if _rc gen double _eplot_p`_model_ix' = .
	replace _eplot_p`_model_ix' = c`i'z if _n >= 3 & c`i'z < .
	capture confirm variable _eplot_est`_model_ix'
	if !_rc replace _eplot_est`_model_ix' = . if strtrim(c`=`i'-2') == "`refcat'" & _n >= 3
	capture confirm variable _eplot_ll`_model_ix'
	if !_rc replace _eplot_ll`_model_ix' = . if strtrim(c`=`i'-2') == "`refcat'" & _n >= 3
	capture confirm variable _eplot_ul`_model_ix'
	if !_rc replace _eplot_ul`_model_ix' = . if strtrim(c`=`i'-2') == "`refcat'" & _n >= 3
gen str20 c`i'_fmt = ""
* Handle genuinely missing p-values (e.g., omitted variables, base categories)
* If original string was "." or empty or converted to missing, leave blank
replace c`i'_fmt = "" if missing(c`i'z) & (strtrim(c`i'_orig) == "." | strtrim(c`i'_orig) == "")
* Format p-values using pdp/highpdp
local _pmin = 10^(-`pdp')
local _pmax = 1 - 10^(-`highpdp')
local _pfmt_lo = "%`=`pdp'+2'.`pdp'f"
local _pfmt_hi = "%`=`highpdp'+2'.`highpdp'f"
replace c`i'_fmt = "<" + string(`_pmin', "`_pfmt_lo'") if c`i'z < `_pmin' & !missing(c`i'z)
replace c`i'_fmt = string(c`i'z, "`_pfmt_lo'") if c`i'z >= `_pmin' & c`i'z < 0.10 & !missing(c`i'z)
replace c`i'_fmt = string(c`i'z, "`_pfmt_hi'") if c`i'z >= 0.10 & !missing(c`i'z)
replace c`i'_fmt = ">" + string(`_pmax', "`_pfmt_hi'") if c`i'z > `_pmax' & c`i'z < 1 & !missing(c`i'z)
replace c`i'_fmt = "<" + string(`_pmin', "`_pfmt_lo'") if c`i'z == 0 & !missing(c`i'z)
* Add leading zero if missing (e.g., .123 -> 0.123)
replace c`i'_fmt = "0" + c`i'_fmt if substr(c`i'_fmt, 1, 1) == "."
* Apply formatting - only if we have a non-missing formatted value
replace c`i' = c`i'_fmt if c`i'_fmt != "" & _n >= 3
* Leave blank for missing p-values (omitted/base categories)
replace c`i' = "" if missing(c`i'z) & _n >= 3
* Significance stars (O3) — append *, **, *** to coefficient column
if "`stars'" != "" {
	local _coef_col = `i' - 2
	replace c`_coef_col' = c`_coef_col' + "***" if c`i'z < `_sl3' & !missing(c`i'z) & _n >= 3
	replace c`_coef_col' = c`_coef_col' + "**" if c`i'z >= `_sl3' & c`i'z < `_sl2' & !missing(c`i'z) & _n >= 3
	replace c`_coef_col' = c`_coef_col' + "*" if c`i'z >= `_sl2' & c`i'z < `_sl1' & !missing(c`i'z) & _n >= 3
}
	drop c`i'z c`i'_fmt c`i'_orig
	}

	if `"`_eplotframe_name'"' != "" {
	    capture frame `_eplotframe_name': quietly count
	    if _rc == 0 {
	        if `_eplotframe_replace' {
	            frame drop `_eplotframe_name'
	        }
	        else {
	            noisily display as error "frame `_eplotframe_name' already exists; specify eplotframe(`_eplotframe_name', replace)"
	            exit 110
	        }
	    }
	    frame create `_eplotframe_name' str244 label double estimate double ll double ul ///
	        double pvalue int model str244 model_label str24 rowtype str244 section ///
	        long source_row str32 source_frame
	    forvalues _ep_obs = 3/`=_N' {
	        local _ep_source_row = `_ep_obs' - 2
	        local _ep_label = A[`_ep_obs']
	        forvalues _ep_m = 1/`n_models' {
	            local _ep_est = .
	            local _ep_ll = .
	            local _ep_ul = .
	            local _ep_p = .
	            capture local _ep_est = _eplot_est`_ep_m'[`_ep_obs']
	            capture local _ep_ll = _eplot_ll`_ep_m'[`_ep_obs']
	            capture local _ep_ul = _eplot_ul`_ep_m'[`_ep_obs']
	            capture local _ep_p = _eplot_p`_ep_m'[`_ep_obs']
	            local _ep_model_col = (`_ep_m' - 1) * 3 + 1
	            local _ep_model_label = c`_ep_model_col'[1]
	            if `"`_ep_model_label'"' == "" local _ep_model_label "Model `_ep_m'"
	            local _ep_cell = strtrim(c`_ep_model_col'[`_ep_obs'])
	            local _ep_rowtype "effect"
	            if lower(`"`_ep_cell'"') == lower(`"`refcat'"') local _ep_rowtype "reference"
	            if `_ep_est' < . | `_ep_ll' < . | `_ep_ul' < . | `_ep_p' < . | `"`_ep_rowtype'"' == "reference" {
	                frame post `_eplotframe_name' (`"`_ep_label'"') (`_ep_est') (`_ep_ll') (`_ep_ul') ///
	                    (`_ep_p') (`_ep_m') (`"`_ep_model_label'"') (`"`_ep_rowtype'"') ("") ///
	                    (`_ep_source_row') ("")
	            }
	        }
	    }
	    frame `_eplotframe_name': char _dta[tabtools_source] "regtab"
	    frame `_eplotframe_name': char _dta[tabtools_ci_level] "`_ci_level'"
	    frame `_eplotframe_name': char _dta[tabtools_n_models] "`n_models'"
	    frame `_eplotframe_name': char _dta[tabtools_statistic_ids] "estimate ci pvalue"
	    forvalues _meta_m = 1/`n_models' {
	        local _meta_cmdline `"`model_cmdline_`_meta_m''"'
	        local _meta_depvar `"`model_depvar_`_meta_m''"'
	        local _meta_scale `"`model_coef_`_meta_m''"'
	        if `"`_meta_scale'"' == "" local _meta_scale `"`coef'"'
	        local _meta_label_col = (`_meta_m' - 1) * 3 + 1
	        local _meta_label = c`_meta_label_col'[1]
	        frame `_eplotframe_name': char _dta[tabtools_model_id_`_meta_m'] `"`_meta_cmdline'"'
	        frame `_eplotframe_name': char _dta[tabtools_outcome_id_`_meta_m'] `"`_meta_depvar'"'
	        frame `_eplotframe_name': char _dta[tabtools_effect_scale_`_meta_m'] `"`_meta_scale'"'
	        frame `_eplotframe_name': char _dta[tabtools_model_label_`_meta_m'] `"`_meta_label'"'
	    }
	}
	capture drop _eplot_est* _eplot_ll* _eplot_ul* _eplot_p*

	* Build r(table) from the numeric coefficient body before stats()/addrow(),
* title rows, compact mode, and significance stars change the display strings.
local _mat_nrows = 0
local _keep_obs ""
if `n_models' > 0 {
    forvalues _obs = 3/`=_N' {
        local _row_has_data = 0
        forvalues _ci = 1(3)`last' {
            capture {
                local _coefval = _coefnum`_ci'[`_obs']
                local _cicell = strtrim(c`=`_ci'+1'[`_obs'])
                if `_coefval' < . {
                    if strtrim(c`_ci'[`_obs']) != "`refcat'" {
                        local _row_has_data = 1
                    }
                }
            }
        }
        if `_row_has_data' {
            local _mat_nrows = `_mat_nrows' + 1
            local _keep_obs "`_keep_obs' `_obs'"
        }
    }
}
tempname _rtable
if `_mat_nrows' > 0 {
    matrix `_rtable' = J(`_mat_nrows', `n_models', .)
    local _rnames ""
    local _mr = 0
    foreach _obs of local _keep_obs {
        local _mr = `_mr' + 1
        local _mc = 0
        forvalues _ci = 1(3)`last' {
            local _mc = `_mc' + 1
            capture {
                local _coefval = _coefnum`_ci'[`_obs']
                local _cicell = strtrim(c`=`_ci'+1'[`_obs'])
                if `_coefval' < . {
                    if strtrim(c`_ci'[`_obs']) != "`refcat'" {
                        matrix `_rtable'[`_mr', `_mc'] = `_coefval'
                    }
                }
            }
        }
        local _rname = A[`_obs']
        local _rname = subinstr("`_rname'", ".", "_", .)
        local _rname = subinstr("`_rname'", " ", "_", .)
        local _rname = subinstr("`_rname'", ",", "", .)
        local _rname = subinstr("`_rname'", ":", "", .)
        local _rname = substr("`_rname'", 1, 32)
        if "`_rname'" == "" local _rname "row`_mr'"
        local _rnames "`_rnames' `_rname'"
    }
    capture matrix rownames `_rtable' = `_rnames'
}
capture drop _coefnum*
drop _is_re _is_re_intercept _is_ancillary
capture drop _re_group_label
capture drop _raw_A
capture drop _ci_seen

*
* =========================================================================
* ADD MODEL STATISTICS ROWS (if requested)
* =========================================================================
local stats_start_row = 0
local stats_rows = ""
if `add_stats' == 1 {
    local stats_start_row = _N + 1
    local use_models = min(`n_stat_models', `n_models')

    * Add N row
    if `want_n' == 1 {
        local has_val = 0
        forvalues m = 1/`use_models' {
            if `stat_N_`m'' != . local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            local _n_label = cond(`_any_N_sub', "Subjects", "Observations")
            replace A = "`_n_label'" in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if `stat_N_`m'' != . {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_N_`m'', "%12.0fc") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
        }
    }

    * Add Groups row
    if `want_groups' == 1 {
        local has_val = 0
        forvalues m = 1/`use_models' {
            if `stat_groups_`m'' != . local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = "Groups" in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if `stat_groups_`m'' != . {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_groups_`m'', "%12.0fc") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
        }
    }

    * Add AIC row (falls back to QIC for GEE models where AIC is undefined)
    if `want_aic' == 1 {
        local has_val = 0
        local _aic_label "AIC"
        forvalues m = 1/`use_models' {
            if `stat_aic_`m'' != . local has_val = 1
        }
        if !`has_val' {
            forvalues m = 1/`use_models' {
                if `stat_qic_`m'' != . local has_val = 1
            }
            if `has_val' local _aic_label "QIC"
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = "`_aic_label'" in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if "`_aic_label'" == "AIC" {
                    if `stat_aic_`m'' != . {
                        local col = (`m' - 1) * 3 + 1
                        replace c`col' = string(`stat_aic_`m'', "%12.2f") in `=`curr_n'+1'
                    }
                }
                else {
                    if `stat_qic_`m'' != . {
                        local col = (`m' - 1) * 3 + 1
                        replace c`col' = string(`stat_qic_`m'', "%12.2f") in `=`curr_n'+1'
                    }
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
        }
    }

    * Add QIC row (explicit request — for GEE/xtgee models)
    if `want_qic' == 1 {
        local has_val = 0
        forvalues m = 1/`use_models' {
            if `stat_qic_`m'' != . local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = "QIC" in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if `stat_qic_`m'' != . {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_qic_`m'', "%12.2f") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
        }
    }

    * Add BIC row
    if `want_bic' == 1 {
        local has_val = 0
        forvalues m = 1/`use_models' {
            if `stat_bic_`m'' != . local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = "BIC" in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if `stat_bic_`m'' != . {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_bic_`m'', "%12.2f") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
        }
    }

    * Add Log-likelihood row
    if `want_ll' == 1 {
        local has_val = 0
        forvalues m = 1/`use_models' {
            if `stat_ll_`m'' != . local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = "Log-likelihood" in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if `stat_ll_`m'' != . {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_ll_`m'', "%12.2f") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
        }
    }

    * Add ICC row (per model)
    if `want_icc' == 1 {
        local has_icc = 0
        local use_icc_models = min(`n_icc_models', `n_models')
        forvalues m = 1/`use_icc_models' {
            if `stat_icc_`m'' != . local has_icc = 1
        }
        if `has_icc' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = "ICC" in `=`curr_n'+1'
            forvalues m = 1/`use_icc_models' {
                if `stat_icc_`m'' != . {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_icc_`m'', "%5.3f") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
        }
    }

    * Add R² / Pseudo R² row (F6)
    if `want_r2' == 1 {
        local has_r2 = 0
        forvalues m = 1/`use_models' {
            * Prefer r2, fallback to r2_p (pseudo), then r2_a (adjusted)
            if `stat_r2_`m'' != . | `stat_r2_p_`m'' != . | `stat_r2_a_`m'' != . {
                local has_r2 = 1
            }
        }
        if `has_r2' {
            * Use a generic label when regular and pseudo-R² metrics are mixed.
            local r2_label "R²"
            local _any_r2 = 0
            local _any_pseudo_r2 = 0
            forvalues m = 1/`use_models' {
                if `stat_r2_`m'' != . local _any_r2 = 1
                if `stat_r2_p_`m'' != . local _any_pseudo_r2 = 1
            }
            if !`_any_r2' & `_any_pseudo_r2' local r2_label "Pseudo R²"
            else if `_any_r2' & `_any_pseudo_r2' local r2_label "R² / Pseudo R²"

            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = "`r2_label'" in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                local _r2val = .
                if `stat_r2_`m'' != . local _r2val = `stat_r2_`m''
                else if `stat_r2_p_`m'' != . local _r2val = `stat_r2_p_`m''
                else if `stat_r2_a_`m'' != . local _r2val = `stat_r2_a_`m''
                if `_r2val' != . {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`_r2val', "%5.3f") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
        }
    }

    local stats_rows = strtrim("`stats_rows'")
}

*
* =========================================================================
* ADD CUSTOM ROWS (addrow option)
* =========================================================================
local addrow_rows = ""
if `"`addrow'"' != "" {
    * Split on backslash to get individual rows
    local _ar_rest `"`addrow'"'
    while `"`_ar_rest'"' != "" {
        * Split on backslash using string position (gettoken + parse
        * breaks quoted strings — it returns "P trend" as a separate
        * token from "0.032 0.041" instead of keeping them together)
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

        * Parse the chunk: first token is the label (quoted OK), rest are values
        gettoken _ar_label _ar_vals : _ar_chunk
        * Remove one balanced outer quote layer; embedded quotation marks are data.
        _tabtools_strip_outer_quotes, text(`"`_ar_label'"')
        local _ar_label `"`r(text)'"'

        local curr_n = _N
        set obs `=`curr_n'+1'
        replace A = "`_ar_label'" in `=`curr_n'+1'

        * Positionally assign values to model estimate columns
        local _ar_m = 0
        local _ar_vals = strtrim(`"`_ar_vals'"')
        while `"`_ar_vals'"' != "" {
            gettoken _ar_v _ar_vals : _ar_vals
            local _ar_m = `_ar_m' + 1
            local col = (`_ar_m' - 1) * 3 + 1
            if `col' <= `n' {
                replace c`col' = "`_ar_v'" in `=`curr_n'+1'
            }
        }
        local addrow_rows = "`addrow_rows' `=`curr_n'+1'"
    }
    local addrow_rows = strtrim("`addrow_rows'")
}

gen id = _n
count
local count `=`r(N)'+1'
set obs `count'
replace id = 0 if id == .
sort id
drop id
gen title = ""
order title
replace title = `"`title'"' if _n == 1

* Save p-value strings before optional layout changes remove p columns.
if `has_boldp' | `has_highlight' {
    forvalues _m = 1/`n_models' {
        local _pvar = (`_m' - 1) * 3 + 3
        forvalues _dr = 4/`=_N' {
            local _bp_m`_m'_r`_dr' = strtrim(c`_pvar'[`_dr'])
        }
    }
}

* =====================================================================
* COMPACT MODE — MERGE ESTIMATE + CI INTO SINGLE COLUMN
* =====================================================================
if "`compact'" != "" {
    * Merge estimate (c1,c4,c7,...) + CI (c2,c5,c8,...) for data rows
    * Data rows start at dataset row 3 (rows 1-2 are headers)
    forvalues m = 1(3)`n' {
        local _ci_col = `m' + 1
        * Merge: "0.85" + " " + "(0.72, 1.01)" -> "0.85 (0.72, 1.01)"
        qui replace c`m' = c`m' + " " + c`_ci_col' if _n >= 3 & c`_ci_col' != ""
        * Update column header to combined label
        local _hdr_est = c`m'[2]
        local _hdr_ci = c`_ci_col'[2]
        qui replace c`m' = "`_hdr_est' `_hdr_ci'" in 2
    }

    * Drop CI columns (c2, c5, c8, ...)
    local _drop_cols ""
    forvalues m = 2(3)`n' {
        local _drop_cols "`_drop_cols' c`m'"
    }
    drop `_drop_cols'

    * Renumber remaining c-columns sequentially
    qui ds c*
    local _remaining `r(varlist)'
    local _new_idx = 1
    foreach v of local _remaining {
        if "`v'" != "c`_new_idx'" {
            rename `v' c`_new_idx'
        }
        local _new_idx = `_new_idx' + 1
    }

    local n = `_new_idx' - 1
    local _cols_per_model = 2
}
else {
    local _cols_per_model = 3
}

* Optional p-value suppression. p-values remain available internally before
* this point for stars and row highlighting, but are removed from all outputs.
if !`_show_pvalues' {
    local _drop_cols ""
    if "`compact'" != "" {
        forvalues m = 2(2)`n' {
            local _drop_cols "`_drop_cols' c`m'"
        }
    }
    else {
        forvalues m = 3(3)`n' {
            local _drop_cols "`_drop_cols' c`m'"
        }
    }
    if "`_drop_cols'" != "" drop `_drop_cols'

    qui ds c*
    local _remaining `r(varlist)'
    local _new_idx = 1
    foreach v of local _remaining {
        if "`v'" != "c`_new_idx'" {
            rename `v' c`_new_idx'
        }
        local _new_idx = `_new_idx' + 1
    }
    local n = `_new_idx' - 1
    local _cols_per_model = `_cols_per_model' - 1
}

local last = `n' - `_cols_per_model' + 1

* Save _nonsig values before dropping (needed for formatting after export)
if "`dimnonsig'" != "" {
    capture confirm variable _nonsig
    if !_rc {
        local _nonsig_N = _N
        forvalues _nsi = 1/`_nonsig_N' {
            local _nonsig_v`_nsi' = _nonsig[`_nsi']
        }
        drop _nonsig
    }
}

local num_rows = _N
local num_cols = c(k)
local _xlsx_ok 0

* Build methods description (I2)
local _methods_coef ""
local _methods_model ""
if `_model_headers_mixed' {
    local _methods "Collected regression estimates with `_ci_level'% confidence intervals across `n_models' models."
}
else if "`coef'" == "OR" {
    local _methods_coef "Odds ratios"
    local _methods_model "logistic regression"
}
else if "`coef'" == "HR" {
    local _methods_coef "Hazard ratios"
    local _methods_model "Cox proportional hazards regression"
}
else if "`coef'" == "IRR" {
    local _methods_coef "Incidence rate ratios"
    local _methods_model "Poisson regression"
}
else if "`coef'" == "RRR" {
    local _methods_coef "Relative risk ratios"
    local _methods_model "multinomial logistic regression"
}
else if "`coef'" == "Coef." {
    local _methods_coef "Coefficients"
    local _methods_model "linear regression"
}
else {
    local _methods_coef "`coef'"
    local _methods_model "regression"
}
if `n_models' > 1 local _methods_multi " across `n_models' models"
else local _methods_multi ""
if "`_methods'" == "" local _methods "`_methods_coef' with `_ci_level'% confidence intervals from multivariable `_methods_model'`_methods_multi'."
if "`stars'" != "" local _methods "`_methods' Statistical significance denoted as * p<`_sl1', ** p<`_sl2', *** p<`_sl3'."
local _methods "`_methods' Analysis performed in Stata `c(stata_version)' (StataCorp, College Station, TX)."

* Return statistics before any file-writing failure can abort the command
if `_mat_nrows' > 0 {
    capture return matrix table = `_rtable'
}
return scalar N_rows = `num_rows'
return scalar N_cols = `num_cols'
	return scalar N_models = `n_models'
	return scalar ci_level = `_ci_level'
	return local coef_label "`_coef_label_return'"
	return local stars "`stars'"
	return local methods "`_methods'"
	if `"`_eplotframe_name'"' != "" return local eplotframe "`_eplotframe_name'"

* Per-model computed model-fit statistics, returned at full precision. These
* mirror the stats() rows written to the table but expose the unrounded values
* (the table strings are formatted to %12.2f / %5.3f) for downstream use and
* programmatic checks. Naming follows survtab's <name>_<index> convention; the
* column index matches the model order in r(table).
if `add_stats' == 1 {
    forvalues m = 1/`use_models' {
        if `want_aic' & `stat_aic_`m'' != .          return scalar aic_`m'    = `stat_aic_`m''
        if `want_bic' & `stat_bic_`m'' != .          return scalar bic_`m'    = `stat_bic_`m''
        if (`want_qic' | `want_aic') & `stat_qic_`m'' != . return scalar qic_`m' = `stat_qic_`m''
        if `want_ll'  & `stat_ll_`m''  != .          return scalar ll_`m'     = `stat_ll_`m''
        if `want_n'   & `stat_N_`m''   != .          return scalar n_`m'      = `stat_N_`m''
        if `want_groups' & `stat_groups_`m'' != .    return scalar groups_`m' = `stat_groups_`m''
    }
    if `want_icc' {
        local _ret_icc_models = min(`n_icc_models', `n_models')
        forvalues m = 1/`_ret_icc_models' {
            if `stat_icc_`m'' != .                   return scalar icc_`m'    = `stat_icc_`m''
        }
    }
}

if `_has_xlsx' {
    capture noisily _tabtools_xlsx_write using "`xlsx'", sheet("`sheet'") book(b)
    if _rc {
        local _export_rc = _rc
        noisily display as error "Failed to export to `xlsx', sheet `sheet'"
        noisily display as error "Check file permissions and that file is not open in Excel"
        capture erase "`temp_xlsx'"
        restore
        error `_export_rc'
    }
}

forvalues i = 1(1)`n'{
gen c`i'_length = length(c`i')
}
* Compute max header length from row 2 only (model labels)
local max_header_length = 0
forvalues i = 1/`n' {
    local _h2len = strlen(c`i'[2])
    if `_h2len' > `max_header_length' local max_header_length = `_h2len'
}
forvalues i = 1(1)`n'{
replace c`i'_length = . if _n == 2
egen c`i'_max = max(c`i'_length)
}
* Compute estimate width from rendered numeric/stat rows, not the reference label.
* "Reference" can safely overflow into adjacent blank cells, while numeric cells
* should stay visually tight.
local est_max = 0
forvalues i = 1(`_cols_per_model')`last' {
    sum c`i'_length if _n >= 3 & c`i' != "`refcat'", meanonly
    if r(N) > 0 & `r(max)' > `est_max' local est_max = `r(max)'
}
local ci_max = 0
local p_max = 0
if "`compact'" == "" {
    forvalues i = 2(`_cols_per_model')`n' {
        capture confirm variable c`i'
        if _rc continue
        sum c`i'_max, meanonly
        if `r(max)' > `ci_max' local ci_max = `r(max)'
    }
}
if `_show_pvalues' {
    local _p_offset = `_cols_per_model' - 1
    forvalues i = 1(`_cols_per_model')`last' {
        local _p_col = `i' + `_p_offset'
        capture confirm variable c`_p_col'
        if _rc continue
        sum c`_p_col'_max, meanonly
        if `r(max)' > `p_max' local p_max = `r(max)'
    }
}
else local p_max = 0

* Calibrate widths to Stata's Excel writer, which lands about 0.7 wider than
* the input width when read back from xlsx metadata.
local est_width = max(`est_max' - 0.5, 7)
if "`compact'" != "" {
    if `est_width' < 10 local est_width = 10
}

local ci_width = 0
if "`compact'" == "" {
    local ci_width = max(`ci_max' - 0.5, 10)
}

local p_width = 0
if `_show_pvalues' {
    local p_width = max(`p_max' - 0.5, 7)
}

gen A_length = length(A)
egen factor_length = max(A_length)
sum factor_length, d
local factor_length = ceil(r(max) * 0.95) + 2
* Cap the label column so a single verbose label (e.g. an unstructured
* random-effects "Covariance: ... (slope, Intercept)" row) cannot blow the
* whole column out to 60-76 chars. Labels longer than the cap wrap onto
* multiple lines (text-wrap rule below) instead of forcing a wide column.
if `factor_length' > `_label_width_cap' local factor_length = `_label_width_cap'

drop A_length factor_length c*_max c*_length

forvalues i = 1(`_cols_per_model')`last'{
gen ref`i' = _n if c`i' == "`refcat'"
order ref`i', after(c`i')
levelsof ref`i', local(ref`i'_levels)
}
local ref_rows ""
forvalues i = 1(`_cols_per_model')`last'{
local ref_rows "`ref_rows' `ref`i'_levels'"
}
local ref_rows: list uniq ref_rows

* CSV export (F2) — must happen before clear
if "`csv'" != "" {
    _tabtools_csv_write using "`csv'", labelvar(A)
}

* Console display
noisily _tabtools_console_display `n' `"`title'"', labelvar(A)

* Markdown export
local _ret_markdown ""
local _ret_markdown_rows .
local _ret_markdown_cols .
if `"`markdown'"' != "" {
	local _mdappend_opt ""
	if "`mdappend'" != "" local _mdappend_opt "append"
	capture noisily _tabtools_markdown_write using `"`markdown'"', ///
		`_mdappend_opt' labelvar(A) title(`"`title'"') footnote(`"`footnote'"') strictheaders
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

* Store output in frame if requested
	if `"`frame'"' != "" {
		_tabtools_frame_put `"`frame'"'
		local frame "`_frame_name'"
		frame `frame': char _dta[tabtools_source] "regtab"
		frame `frame': char _dta[tabtools_ci_level] "`_ci_level'"
		frame `frame': char _dta[tabtools_n_models] "`n_models'"
		local _frame_stat_ids "estimate ci pvalue"
		if "`compact'" != "" local _frame_stat_ids "estimate_ci pvalue"
		if "`nopvalue'" != "" local _frame_stat_ids : subinstr local _frame_stat_ids " pvalue" "", all
		frame `frame': char _dta[tabtools_statistic_ids] "`_frame_stat_ids'"
		forvalues _meta_m = 1/`n_models' {
			local _meta_cmdline `"`model_cmdline_`_meta_m''"'
			local _meta_depvar `"`model_depvar_`_meta_m''"'
			local _meta_scale `"`model_coef_`_meta_m''"'
			if `"`_meta_scale'"' == "" local _meta_scale `"`coef'"'
			local _meta_label_col = (`_meta_m' - 1) * `_cols_per_model' + 1
			local _meta_label = c`_meta_label_col'[2]
			frame `frame': char _dta[tabtools_model_id_`_meta_m'] `"`_meta_cmdline'"'
			frame `frame': char _dta[tabtools_outcome_id_`_meta_m'] `"`_meta_depvar'"'
			frame `frame': char _dta[tabtools_effect_scale_`_meta_m'] `"`_meta_scale'"'
			frame `frame': char _dta[tabtools_model_label_`_meta_m'] `"`_meta_label'"'
		}
			if `"`_eplotframe_name'"' != "" {
			    frame `frame': char _dta[tabtools_eplotframe] "`_eplotframe_target'"
			}
			return local frame "`frame'"
		}
	if `"$TABTOOLS_QA_REG_STAGE_FAIL"' == "1" {
		restore
		error 459
	}
	if `"`_ret_markdown'"' != "" {
	return local markdown `"`_ret_markdown'"'
	return scalar markdown_rows = `_ret_markdown_rows'
	return scalar markdown_cols = `_ret_markdown_cols'
}

clear

if `_has_xlsx' {

* Prepare footnote text before Mata block
local _fn_text `"`footnote'"'
if "`stars'" != "" {
	local _stars_note "* p<`_sl1', ** p<`_sl2', *** p<`_sl3'"
	if `"`_fn_text'"' != "" local _fn_text `"`_fn_text'; `_stars_note'"'
	else local _fn_text `"`_stars_note'"'
}

* Prepare p-value/nonsig data vectors for Mata
local _n_bp_entries 0
if `has_boldp' | `has_highlight' {
	forvalues _m = 1/`n_models' {
		forvalues _dr = 4/`num_rows' {
			local _pstr "`_bp_m`_m'_r`_dr''"
			if substr("`_pstr'", 1, 1) == "<" {
				local _bp_m`_m'_r`_dr'_num = 0
			}
			else {
				local _bp_m`_m'_r`_dr'_num = real("`_pstr'")
			}
		}
	}
}

local _n_nonsig_entries 0
if "`dimnonsig'" != "" {
	forvalues _dr = 4/`num_rows' {
		capture local _ns_`_dr' = `_nonsig_v`_dr''
		if _rc local _ns_`_dr' = 0
	}
}

* All formatting in a single shared style-rule backend call
capture {
	local _hborder_code = 1
	if "`_hborder'" == "medium" local _hborder_code = 2
	if "`_hborder'" == "thick" local _hborder_code = 3
	if "`_hborder'" == "none" local _hborder_code = 4
	local _vborder_code = 1
	if "`borderstyle'" == "medium" local _vborder_code = 2
	if "`borderstyle'" == "thick" local _vborder_code = 3
	if "`borderstyle'" == "none" local _vborder_code = 4

	tempname _style_rules
	local _style_rule_rows "12 1 1 1 1 30 0 0 0 | 13 1 1 1 1 1 0 0 0 | 13 1 1 2 2 `factor_length' 0 0 0"
	local _total_model_width = `est_width'
	if "`compact'" == "" local _total_model_width = `_total_model_width' + `ci_width'
	if `_show_pvalues' local _total_model_width = `_total_model_width' + `p_width'
	forvalues _mc = 1/`n_models' {
		local _c_first = (`_mc' - 1) * `_cols_per_model' + 1
		local _x_first = `_c_first' + 2
		local _style_rule_rows `"`_style_rule_rows' | 13 1 1 `_x_first' `_x_first' `est_width' 0 0 0"'
		if "`compact'" == "" {
			local _x_ci = `_x_first' + 1
			local _style_rule_rows `"`_style_rule_rows' | 13 1 1 `_x_ci' `_x_ci' `ci_width' 0 0 0"'
		}
		if `_show_pvalues' {
			local _x_p = `_x_first' + `_cols_per_model' - 1
			local _style_rule_rows `"`_style_rule_rows' | 13 1 1 `_x_p' `_x_p' `p_width' 0 0 0"'
		}
	}
	if `=`max_header_length'*.9' > `_total_model_width' {
		local headerheight = ceil(`=`max_header_length'*.9'/`_total_model_width')
		local _style_rule_rows `"`_style_rule_rows' | 12 2 2 1 1 `=`headerheight'*15' 0 0 0"'
	}

	* Wrap the label column so labels longer than the capped width (e.g. a
	* verbose random-effects covariance row) flow onto extra lines instead of
	* being clipped by the adjacent estimate cell. Top-align the label rows so
	* the first line stays level with the single-line estimate cells.
	if `num_rows' >= 4 {
		local _style_rule_rows `"`_style_rule_rows' | 4 4 `num_rows' 2 2 0 1 0 0 | 6 4 `num_rows' 2 2 0 3 0 0"'
	}

	local _style_rule_rows `"`_style_rule_rows' | 1 1 `num_rows' 1 `num_cols' `_fontsize' 1 0 0 | 1 1 1 1 `num_cols' `=`_fontsize'+2' 1 0 0 | 14 1 1 1 `num_cols' 0 0 0 0 | 4 1 1 1 1 0 1 0 0 | 5 1 1 1 1 0 1 0 0 | 6 1 1 1 1 0 2 0 0 | 2 1 1 1 1 0 1 0 0"'
	if "`headershade'" != "" {
		local _style_rule_rows `"`_style_rule_rows' | 7 2 3 2 `num_cols' 0 -1 0 0"'
	}
	local _style_rule_rows `"`_style_rule_rows' | 2 3 3 2 `num_cols' 0 1 0 0 | 5 3 3 2 `num_cols' 0 2 0 0 | 6 3 3 2 `num_cols' 0 2 0 0"'

	foreach row of local ref_rows {
		forvalues _mc = 1/`n_models' {
			local _col_start = 2 + (`_mc' - 1) * `_cols_per_model' + 1
			local _col_end = `_col_start' + `_cols_per_model' - 1
			local _style_rule_rows `"`_style_rule_rows' | 14 `row' `row' `_col_start' `_col_end' 0 0 0 0 | 5 `row' `row' `_col_start' `_col_start' 0 2 0 0 | 6 `row' `row' `_col_start' `_col_start' 0 2 0 0 | 3 `row' `row' `_col_start' `_col_start' 0 1 0 0"'
		}
	}

	forvalues _mc = 1/`n_models' {
		local _col_start = 2 + (`_mc' - 1) * `_cols_per_model' + 1
		local _col_end = `_col_start' + `_cols_per_model' - 1
		local _style_rule_rows `"`_style_rule_rows' | 14 2 2 `_col_start' `_col_end' 0 0 0 0 | 5 2 2 `_col_start' `_col_start' 0 2 0 0 | 6 2 2 `_col_start' `_col_start' 0 2 0 0 | 2 2 2 `_col_start' `_col_start' 0 1 0 0 | 4 2 2 `_col_start' `_col_start' 0 1 0 0"'
		if "`borderstyle'" != "academic" {
			local _style_rule_rows `"`_style_rule_rows' | 11 2 `num_rows' `_col_end' `_col_end' 0 `_vborder_code' 0 0"'
		}
	}

	local _style_rule_rows `"`_style_rule_rows' | 8 2 2 2 `num_cols' 0 `_hborder_code' 0 0 | 8 2 2 3 `num_cols' 0 `_hborder_code' 0 0 | 8 3 3 3 `num_cols' 0 `_hborder_code' 0 0 | 9 3 3 2 `num_cols' 0 `_hborder_code' 0 0 | 9 `num_rows' `num_rows' 2 `num_cols' 0 `_hborder_code' 0 0"'
	if "`borderstyle'" != "academic" {
		local _style_rule_rows `"`_style_rule_rows' | 11 2 `num_rows' `num_cols' `num_cols' 0 `_vborder_code' 0 0 | 10 2 `num_rows' 2 2 0 `_vborder_code' 0 0 | 11 2 `num_rows' 2 2 0 `_vborder_code' 0 0"'
	}
	if "`first_re_row'" != "" {
		local re_excel_row = `first_re_row' + 1
		local _style_rule_rows `"`_style_rule_rows' | 8 `re_excel_row' `re_excel_row' 2 `num_cols' 0 `_hborder_code' 0 0"'
	}
	if "`stats_rows'" != "" {
		local first_stat = 1
		foreach stat_row of local stats_rows {
			local excel_row = `stat_row' + 1
			if `first_stat' == 1 {
				local _style_rule_rows `"`_style_rule_rows' | 8 `excel_row' `excel_row' 2 `num_cols' 0 `_hborder_code' 0 0"'
				local first_stat = 0
			}
			local _style_rule_rows `"`_style_rule_rows' | 9 `excel_row' `excel_row' 2 `num_cols' 0 `_hborder_code' 0 0"'
			forvalues _mc = 1/`n_models' {
				local _sc = 2 + (`_mc' - 1) * `_cols_per_model' + 1
				local _sc_end = `_sc' + `_cols_per_model' - 1
				local _style_rule_rows `"`_style_rule_rows' | 14 `excel_row' `excel_row' `_sc' `_sc_end' 0 0 0 0 | 5 `excel_row' `excel_row' `_sc' `_sc' 0 2 0 0 | 6 `excel_row' `excel_row' `_sc' `_sc' 0 2 0 0"'
				if "`borderstyle'" != "academic" {
					local _style_rule_rows `"`_style_rule_rows' | 11 `excel_row' `excel_row' `_sc_end' `_sc_end' 0 `_vborder_code' 0 0"'
				}
			}
		}
	}
		if "`addrow_rows'" != "" {
			local first_ar = 1
			foreach ar_row of local addrow_rows {
				local excel_row = `ar_row' + 1
				if `first_ar' == 1 {
					local _style_rule_rows `"`_style_rule_rows' | 8 `excel_row' `excel_row' 2 `num_cols' 0 `_hborder_code' 0 0"'
					local first_ar = 0
				}
				local _style_rule_rows `"`_style_rule_rows' | 9 `excel_row' `excel_row' 2 `num_cols' 0 `_hborder_code' 0 0"'
				forvalues _mc = 1/`n_models' {
					local _ac = 2 + (`_mc' - 1) * `_cols_per_model' + 1
					local _ac_end = `_ac' + `_cols_per_model' - 1
					local _style_rule_rows `"`_style_rule_rows' | 14 `excel_row' `excel_row' `_ac' `_ac_end' 0 0 0 0 | 5 `excel_row' `excel_row' `_ac' `_ac' 0 2 0 0 | 6 `excel_row' `excel_row' `_ac' `_ac' 0 2 0 0"'
					if "`borderstyle'" != "academic" {
						local _style_rule_rows `"`_style_rule_rows' | 11 `excel_row' `excel_row' `_ac_end' `_ac_end' 0 `_vborder_code' 0 0"'
					}
				}
			}
		}
		if "`zebra'" != "" {
			forvalues _zr = 5(2)`num_rows' {
				local _style_rule_rows `"`_style_rule_rows' | 7 `_zr' `_zr' 2 `num_cols' 0 -2 0 0"'
			}
		}
		if `num_rows' >= 4 {
			local _style_rule_rows `"`_style_rule_rows' | 5 4 `num_rows' 3 `num_cols' 0 2 0 0"'
		}
		if `has_boldp' | `has_highlight' {
			forvalues _m = 1/`n_models' {
				local _pcol = 2 + `_m' * `_cols_per_model'
				forvalues _dr = 4/`num_rows' {
					local _pnum = `_bp_m`_m'_r`_dr'_num'
					if `_pnum' < . {
						if `has_boldp' & `_show_pvalues' & `_pnum' < `boldp' {
							local _style_rule_rows `"`_style_rule_rows' | 2 `_dr' `_dr' `_pcol' `_pcol' 0 1 0 0"'
						}
						if `has_highlight' & `_pnum' < `highlight' {
							local _style_rule_rows `"`_style_rule_rows' | 7 `_dr' `_dr' 2 `num_cols' 0 -3 0 0"'
						}
					}
				}
			}
		}
	if "`dimnonsig'" != "" {
		forvalues _dr = 4/`num_rows' {
			if `_ns_`_dr'' == 1 {
				local _style_rule_rows `"`_style_rule_rows' | 15 `_dr' `_dr' 2 `num_cols' `_fontsize' 160 160 160"'
			}
		}
	}
	if `"`_fn_text'"' != "" {
		local _fn_row = `num_rows' + 1
		local _fn_fontsize = max(`_fontsize' - 2, 6)
		mata: b.put_string(`_fn_row', 2, `"`_fn_text'"')
		local _style_rule_rows `"`_style_rule_rows' | 14 `_fn_row' `_fn_row' 2 `num_cols' 0 0 0 0 | 5 `_fn_row' `_fn_row' 2 2 0 1 0 0 | 6 `_fn_row' `_fn_row' 2 2 0 2 0 0 | 4 `_fn_row' `_fn_row' 2 2 0 1 0 0 | 1 `_fn_row' `_fn_row' 2 2 `_fn_fontsize' 1 0 0 | 3 `_fn_row' `_fn_row' 2 2 0 1 0 0"'
	}

	_tabtools_xlsx_build_styles, matrix(`_style_rules') ///
		rules(`"`_style_rule_rows'"') cols(9)
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
	capture erase "`temp_xlsx'"
	restore
	error `saved_rc'
}
capture mata: mata drop b

} // end if _has_xlsx (Excel formatting)

* Clean up temporary file
capture erase "`temp_xlsx'"

* Restore user data
restore

* Console confirmation (O1)
if `_has_xlsx' {
    capture confirm file "`xlsx'"
    if _rc {
        noisily display as error "Export command succeeded but file not found"
        exit 601
    }
    local _xlsx_ok 1
    noisily display as text "Exported " as result "`num_rows'" as text " rows × " as result "`num_cols'" as text " cols to " as result `"`xlsx'"' as text ", sheet " as result `"`sheet'"'
}
if `_xlsx_ok' {
    return local xlsx "`xlsx'"
    return local sheet "`sheet'"
}

* Open file if requested (W3)
if `_xlsx_ok' & "`open'" != "" _tabtools_open_file "`xlsx'"

* Commit staged frame sinks only after all other requested outputs succeeded.
if `"`_eplotframe_build'"' != "" {
	capture confirm frame `_eplotframe_target'
	if !_rc frame drop `_eplotframe_target'
	frame rename `_eplotframe_build' `_eplotframe_target'
	local _eplotframe_build ""
	return local eplotframe "`_eplotframe_target'"
}
if `"`_displayframe_build'"' != "" {
	capture confirm frame `_displayframe_target'
	if !_rc frame drop `_displayframe_target'
	frame rename `_displayframe_build' `_displayframe_target'
	local _displayframe_build ""
	local frame "`_displayframe_target'"
	return local frame "`_displayframe_target'"
}
}

	    } // end capture noisily
	    local _rc = _rc
	    if `_rc' {
	        if `"`_displayframe_build'"' != "" capture frame drop `_displayframe_build'
	        if `"`_eplotframe_build'"' != "" capture frame drop `_eplotframe_build'
	    }
	    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
*
