*! regtab Version 2.1.11  2026/09/26
*! Author: Timothy P Copeland, Karolinska Institutet

/*
DESCRIPTION:
	Formats the collected regression tables; exports point estimate, 95% CI, and p-value to excel; and applies excel formatting (column widths, merges cells, sets column widths). Title appears in cell A1. Top left cell of table is B2.

SYNTAX:
	regtab, [xlsx(string) sheet(string) models(string) sep(string asis) coef(string) title(string) noint nore stats(string) relabel cutlabels(string asis) addrow(string asis)]

	xlsx:	Optional. Excel file name. Requires .xlsx suffix. Omit for console,
	        frame(), csv(), or markdown() output only
	sheet:	Optional. Excel sheet name (default: "Regression")
	models:	Label models, separating model names using backslash (e.g., Model 1 \ Model 2...)
	coef:	Labels the point estimate (e.g., OR, Coef., HR)
	title:	Gives spreasheet a table name in cell A1
	noint:	Drops intercept row
	        Also drops cutpoint and ancillary-only rows such as cut1, lnalpha,
	        alpha, ln_p, p, and 1/p, identified by their equation in the
	        collection (never by label); use keepintercept to show them.
	nore:	Drops random effects rows
	sep:    character separating 95% CI, default is ", "
	stats:	Model statistics to add at bottom (space-separated): n events groups
	        mi_m aic qic bic ll icc r2 r2_a rmse F fmi
	        - n: Number of observations
	        - aic: Akaike Information Criterion
	        - bic: Bayesian Information Criterion
	        - qic: QICu, Pan's fixed-penalty QIC approximation
	          (xtgee models with dispersion fixed at 1)
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
	        (log-hazard metric) and mecloglog, it becomes Median Hazard Ratio
	        (MHR); mestreg in the time metric keeps the variance. CI bounds
	        are transformed on the same scale. Use nore to suppress.

*/

program define regtab, rclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	tempname _xlsx_book

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
	BOLDp(real -1) cdisc BORDERstyle(string) FONT(string) FONTSIZE(integer -1) stars ///
	STARSLevels(numlist) HEADERColor(string) ZEBRAColor(string) csv(string) MARKdown(string) MDAPPend ///
	FRAme(string) EPLOTFrame(string asis) keep(string) drop(string) LABELMatch DIMNONsig FACTORLabel ///
	REFcat(string) OMITLabel(string) EMPTYLabel(string) ///
	CUTLabels(string) ADDRow(string asis) COMPact NOPvalue ///
	pdp(integer -1) highpdp(integer -1) LABELWidth(integer 0) Level(real -1)]

* Accept excel() as synonym for xlsx()
if "`xlsx'" == "" & "`excel'" != "" local xlsx "`excel'"
local _user_coef_spec = ("`coef'" != "")
local _user_noint_spec = ("`nointercept'" != "")

* Default reference category label
if `"`refcat'"' == "" local refcat "Reference"
* Labels for coefficients the model constrained but did not estimate. A base
* category, a level dropped for collinearity, and a level that identifies no
* observations all arrive as a zero (a one after eform) with an empty interval;
* they are different facts and are labelled differently.
if `"`omitlabel'"' == "" local omitlabel "Omitted"
if `"`emptylabel'"' == "" local emptylabel "Empty"
if `"`refcat'"' == `"`omitlabel'"' | `"`refcat'"' == `"`emptylabel'"' ///
	| `"`omitlabel'"' == `"`emptylabel'"' {
	display as error ///
		"refcat(), omitlabel(), and emptylabel() must differ from each other"
	exit 198
}
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
	    local _ep_spec = subinstr(strtrim(`"`eplotframe'"'), char(34), "", .)
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
			local _fr_spec = subinstr(strtrim(`"`frame'"'), char(34), "", .)
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
		local _displayframe_target `"`_displayframe_name'"'
		local _eplotframe_target `"`_eplotframe_name'"'
		local _displayframe_build ""
		local _eplotframe_build ""
		if `"`_displayframe_target'"' != "" {
			tempname _displayframe_tmp
			local _displayframe_build `"`_displayframe_tmp'"'
			local frame "`_displayframe_build', replace"
		}
		if `"`_eplotframe_target'"' != "" {
			tempname _eplotframe_tmp
			local _eplotframe_build `"`_eplotframe_tmp'"'
			local _eplotframe_name `"`_eplotframe_build'"'
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

* Auto-detect coefficient label from the ambient estimates. This is only the
* fallback for a collection without per-model metadata; the per-model rule in
* _regtab_scale below overrides it whenever metadata exists. Without metadata
* regtab cannot exponentiate the collected values, so the label must name the
* scale Stata displayed: a ratio family shown as coefficients is "Coef.".
if "`coef'" == "" {
	local _ecmd `"`e(cmd)'"'
	local _ecmdline = lower(`"`e(cmdline)'"')
	* Without e(cmdline) the display options are unknown, so no rule is
	* applied and the header stays unlabelled rather than guessed.
	_regtab_optstr _eoptstr `"`_ecmdline'"'
	local _ecmdline `"`_eoptstr_line'"'
	local _ecmdword ""
	gettoken _ecmdword : _ecmdline
	_regtab_scale `"`_ecmdword'"' `"`_ecmd'"' `"`_eoptstr'"'
	if `_rs_known' {
		if `_rs_eform' local coef "Coef."
		else local coef `"`_rs_coef'"'
	}
}

* Auto-detect nointercept for exponentiated models (U4)
* OR/HR/IRR/RRR models rarely report intercept; suppress unless user forces it
if "`nointercept'" == "" & "`keepintercept'" == "" {
	if inlist("`coef'", "OR", "HR", "IRR", "RRR", "SHR", "TR", "AF", "RR", "exp(b)") {
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

* Build format strings from digits (F3). Both widths must be large enough to
* hold the widest representable fixed-point value: Stata silently falls back to
* low-precision scientific notation when a value overflows the field width, so
* a narrow CI field renders two distinct bounds as one indistinguishable
* "1.0e+09". Width 32 covers the full |x| < 1e30 fixed-point range at up to 6
* decimals (digits() is validated to 0-6). No "c" (thousands) flag: the CI
* string must not acquire commas that would collide with a sep(",") request or
* diverge from the comma-free coefficient column.
local coef_fmt "%32.`digits'f"
local ci_fmt "%32.`digits'f"
local coef_round = 10^(-`digits')

* Resolve formatting
_tabtools_resolve_format, font(`"`font'"') fontsize(`fontsize') borderstyle(`borderstyle') headershade(`headershade') zebra(`zebra')

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
	quietly collect dims
	local _collect_dims `"`s(dimnames)'"'
	if strpos(" `_collect_dims' ", " cmdset ") == 0 {
		noisily display as error "No active collect table found"
		noisily display as error "Run regression commands with {bf:collect:} prefix first"
		noisily display as error "Hint: {bf:collect clear} then {bf:collect: regress y x1 x2}"
		exit 119
	}
	* Shared with effecttab: see _tabtools_resolve_ci_level in _tabtools_common.
	* When the collection carries no level provenance and level() was not given,
	* this warns and falls back to the current c(level).
	noisily _tabtools_resolve_ci_level `level'
	local _ci_level = r(level)
	local _ci_found = r(found)

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
    _tabtools_check_sinks, xlsx(`"`xlsx'"') csv(`"`csv'"') markdown(`"`markdown'"')

    * Create temporary file for intermediate processing
    tempfile temp_export
    local temp_xlsx "`temp_export'.xlsx"

    if "`labelmatch'" != "" & "`keep'`drop'" == "" {
        noisily display as error "labelmatch requires keep() or drop()"
        exit 198
    }
    * Validate keep/drop mutual exclusivity
    if "`keep'" != "" & "`drop'" != "" {
        noisily display as error "keep() and drop() cannot be used together"
        exit 198
    }

	if `"`sep'"' != "" {
	    _tabtools_strip_outer_quotes, text(`"`sep'"')
	    local sep `"`r(text)'"'
	}
	if `"`sep'"' == "" local sep ", "      // Default CI delimiter

    * =========================================================================
    * EXTRACT PER-MODEL COMMAND METADATA
    * =========================================================================
    local _meta_models = 0
    local _model_headers_mixed = 0
    local _all_auto_noint = 1
    local _coef_label_return `"`coef'"'
    local _has_multieq_estimator = 0
    * mi estimate records the prefix and its options only in e(cmdline_mi)
    * and the fitted command in e(cmd_mi); e(vce) decides the AIC/BIC count.
    * These are read under their own names (collect's labels for them vary).
    local _meta_own "cmdline_mi cmd_mi vce"
    foreach _mo of local _meta_own {
        local _orig_mlbl_`_mo' ""
        capture local _orig_mlbl_`_mo' : collect label levels result `_mo'
        capture collect label levels result `_mo' "`_mo'", modify
    }
    capture {
        collect layout (cmdset) (result[cmd cmdline depvar ivars revars redim `_meta_own'])
    }
    local _meta_layout_rc = _rc
    foreach _mo of local _meta_own {
        if `"`_orig_mlbl_`_mo''"' != "" {
            capture collect label levels result `_mo' `"`_orig_mlbl_`_mo''"', modify
        }
    }
    if `_meta_layout_rc' == 0 {
        preserve
        capture {
            _tabtools_collect_render, type(meta) rowdim(cmdset) ///
                results(cmd cmdline depvar ivars revars redim `_meta_own') dropempty

            local meta_col_cmd ""
            local meta_col_cmdline ""
            local meta_col_depvar ""
            local meta_col_ivars ""
            local meta_col_revars ""
            local meta_col_redim ""
            local meta_col_cmdline_mi ""
            local meta_col_cmd_mi ""
            local meta_col_vce ""
            ds
            local meta_allvars `r(varlist)'
            foreach v of local meta_allvars {
                local hdr = strlower(strtrim(`v'[1]))
                * collect labels e(cmd) "Estimation command" once a svy:
                * fit is in the collection; missing it dropped the whole
                * metadata path (and every model's scale) silently.
                if inlist("`hdr'", "command", "estimation command") local meta_col_cmd "`v'"
                if "`hdr'" == "command line as typed" local meta_col_cmdline "`v'"
                if "`hdr'" == "dependent variable" local meta_col_depvar "`v'"
                if "`hdr'" == "imputation variables" local meta_col_ivars "`v'"
                if "`hdr'" == "random-effects covariates" local meta_col_revars "`v'"
                if "`hdr'" == "random-effects dimensions" local meta_col_redim "`v'"
                if `"`=strtrim(`v'[1])'"' == "cmdline_mi" local meta_col_cmdline_mi "`v'"
                if `"`=strtrim(`v'[1])'"' == "cmd_mi" local meta_col_cmd_mi "`v'"
                if `"`=strtrim(`v'[1])'"' == "vce" local meta_col_vce "`v'"
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
                if "`meta_col_ivars'" != "" {
                    local model_ivars_`m' = strtrim(`meta_col_ivars'[`r'])
                }
                else local model_ivars_`m' ""
                if "`meta_col_revars'" != "" {
                    local model_revars_`m' = strtrim(`meta_col_revars'[`r'])
                }
                else local model_revars_`m' ""
                if "`meta_col_redim'" != "" {
                    local model_redim_`m' = strtrim(`meta_col_redim'[`r'])
                }
                else local model_redim_`m' ""
                foreach _mo of local _meta_own {
                    local model_`_mo'_`m' ""
                    if "`meta_col_`_mo''" != "" {
                        local model_`_mo'_`m' = lower(strtrim(`meta_col_`_mo''[`r']))
                    }
                }
            }
        }
        if _rc local _meta_models = 0
        restore
    }

    if !`_user_noint_spec' {
        local nointercept ""
    }

    local _re_family_seen ""
    local _any_gee 0
    if `_meta_models' > 0 {
        local _shared_coef ""
        local _re_family_mixed 0
        forvalues m = 1/`_meta_models' {
            local _cmdline_lc `"`model_cmdline_`m''"'
            * mi estimate stores the fitted command's line in e(cmdline) and
            * the prefix, with its options, only in e(cmdline_mi).
            if `"`model_cmdline_mi_`m''"' != "" local _cmdline_lc `"`model_cmdline_mi_`m''"'
            local _ecmd_m `"`model_cmd_`m''"'
            if `"`model_cmd_mi_`m''"' != "" local _ecmd_m `"`model_cmd_mi_`m''"'
            * Option text only: a covariate named "or", or a comma inside an
            * if() expression, must never be read as a display option.
            * Estimation prefixes (svy, bootstrap, jackknife, mi estimate) are
            * set aside, so the estimation command after them is the one
            * classified (_optstr_line); a prefix's own display options come
            * back separately (_optstr_prefopt) and follow the prefix's rule.
            _regtab_optstr _optstr `"`_cmdline_lc'"'
            local _cmdline_lc `"`_optstr_line'"'
            local model_prefix_`m' `"`_optstr_prefix'"'
            local _cmdword ""
            gettoken _cmdword _cmdrest : _cmdline_lc
            if "`_cmdword'" == "" local _cmdword `"`_ecmd_m'"'
            local model_cmdword_`m' `"`_cmdword'"'
            local model_optstr_`m' `"`_optstr'"'
            local _pmode ""
            if strpos(" `_optstr_prefix' ", " mi ") local _pmode "mi"
            else if strpos(" `_optstr_prefix' ", " bootstrap ") | ///
                strpos(" `_optstr_prefix' ", " jackknife ") local _pmode "or"
            _regtab_prefopts `"`_optstr_prefopt'"'

            * Display scale: the estimate header, whether regtab must
            * exponentiate the collected values to reach that scale, the null
            * value for dimnonsig, and default intercept suppression. Shared
            * with the ambient-e() fallback so both paths agree.
            _regtab_scale `"`_cmdword'"' `"`_ecmd_m'"' `"`_optstr'"' ///
                "`_pmode'" "`_rp_eform'"
            local model_coef_`m' `"`_rs_coef'"'
            local model_null_`m' = `_rs_null'
            local model_eform_`m' = `_rs_eform'
            local model_auto_noint_`m' = `_rs_noint'
            local model_level_`m' = `_rs_level'
            if `_rp_level' != -1 local model_level_`m' = `_rp_level'
            local model_re_family_`m' "none"
            local model_is_gee_`m' 0
            * model_icc_undef = 1 means ICC is undefined for this model family
            * (count-data mixed models: mepoisson, menbreg). Set in the
            * inlist branches below so the ICC code path can skip per-model.
            local model_icc_undef_`m' 0
            * Latent response variance used when the model has no estimated
            * level-1 residual variance. Missing means that a residual variance
            * must be recovered from the collected results, not guessed.
            local model_icc_resid_`m' = .

            if "`_cmdword'" == "xtgee" | "`model_cmd_`m''" == "xtgee" {
                local model_is_gee_`m' 1
                local _any_gee 1
            }

            if "`_cmdword'" == "melogit" {
                local model_re_family_`m' "mor"
                local model_icc_resid_`m' = c(pi)^2/3
            }
            else if inlist("`_cmdword'", "mepoisson", "menbreg") {
                local model_re_family_`m' "variance"
                local model_icc_undef_`m' 1
            }
            else if inlist("`_cmdword'", "mlogit", "zip", "zinb", "churdle") {
                local _has_multieq_estimator = 1
            }
            else if inlist("`_cmdword'", "mestreg", "mecloglog") {
                local model_re_family_`m' "mhr"
                if "`_cmdword'" == "mecloglog" {
                    local model_icc_resid_`m' = c(pi)^2/6
                }
                else local model_icc_undef_`m' 1
                * In the time metric the random intercept acts on log time,
                * not log hazard: a median *hazard* ratio would misname it.
                * It stays a variance, as for mixed and meglm.
                if "`_cmdword'" == "mestreg" & "`model_coef_`m''" == "TR" {
                    local model_re_family_`m' "variance"
                }
            }
            else if "`_cmdword'" == "mixed" {
                local model_re_family_`m' "variance"
            }
            else if inlist("`_cmdword'", "meglm", "meintreg", "menl", ///
                "meologit", "meoprobit", "meprobit", "meqrlogit", ///
                "meqrpoisson", "metobit") {
                * These mixed estimators report variance-scale random-effect
                * parameters. Classifying them explicitly prevents a MOR/MHR
                * transform from one model being silently applied to their
                * random-effect rows in a combined collection.
                local model_re_family_`m' "variance"
                if inlist("`_cmdword'", "meologit", "meqrlogit") {
                    local model_icc_resid_`m' = c(pi)^2/3
                }
                else if inlist("`_cmdword'", "meoprobit", "meprobit") {
                    local model_icc_resid_`m' = 1
                }
                else if "`_cmdword'" == "meqrpoisson" {
                    local model_icc_undef_`m' 1
                }
                else if "`_cmdword'" == "meglm" {
                    local _meglm_family ""
                    local _meglm_link ""
                    if regexm(`"`_optstr'"', "family\(([a-z0-9_]+)") {
                        local _meglm_family = lower(regexs(1))
                    }
                    if regexm(`"`_optstr'"', "link\(([a-z0-9_]+)") {
                        local _meglm_link = lower(regexs(1))
                    }
                    if inlist("`_meglm_family'", "bernoulli", "binomial") {
                        if inlist("`_meglm_link'", "", "logit") {
                            local model_icc_resid_`m' = c(pi)^2/3
                        }
                        else if "`_meglm_link'" == "probit" {
                            local model_icc_resid_`m' = 1
                        }
                        else if "`_meglm_link'" == "cloglog" {
                            local model_icc_resid_`m' = c(pi)^2/6
                        }
                        else local model_icc_undef_`m' 1
                    }
                    else if !inlist("`_meglm_family'", "", "gaussian", "normal") {
                        local model_icc_undef_`m' 1
                    }
                }
            }

            if `m' == 1 {
                local _shared_coef `"`model_coef_`m''"'
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

        * One CI header level labels every model. Models fit at different
        * confidence levels would put a false "#% CI" over some columns (collect
        * itself relabels them all with the first model's level), so refuse.
        * A model without level() was fit at the session's set level.
        local _lvl_first = .
        forvalues m = 1/`_meta_models' {
            local _lvl_m = `model_level_`m''
            if `_lvl_m' == -1 local _lvl_m = c(level)
            if `m' == 1 local _lvl_first = `_lvl_m'
            else if abs(`_lvl_m' - `_lvl_first') > 1e-8 {
                noisily display as error "collected models use different confidence levels: " ///
                    "`_lvl_first'% (model 1) and `_lvl_m'% (model `m')"
                noisily display as error "refit the models with a common level(), or tabulate them in separate regtab calls"
                exit 198
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
                local coef `"`_shared_coef'"'
                local _coef_label_return `"`coef'"'
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
    * STRUCTURAL COEFFICIENT MAP
    * =========================================================================
    * Every coefficient's role (intercept, cutpoint, ancillary parameter,
    * regression coefficient, random effect) comes from its equation and name
    * in the collection, never from its display label: a covariate named or
    * labelled p, alpha, constant, or cut1 is an ordinary coefficient. Ancillary
    * parameters live in the "/" equation (lnalpha, ln_p, lnsigma, cut#, ...)
    * and the "_diparm#" equations Stata derives from them (alpha, p, sigma,
    * ...). Per model this records the ancillary, cutpoint, and ordinary names
    * for the colname layout, the number of estimated parameters (coefficients
    * with a standard error, outside the derived _diparm equations) for
    * AIC/BIC/QICu, and the predictor variables for the methods sentence.
    local _sm_n = 0
    local _sm_collide ""
    local _sm_has_coleq = 0
    capture quietly collect levelsof coleq
    if _rc == 0 & `"`s(levels)'"' != "" local _sm_has_coleq = 1
    preserve
    capture noisily {
        if `_sm_has_coleq' {
            _tabtools_collect_render, type(main) rowdim(coleq#colname) ///
                coldim(cmdset) results(_r_b _r_se) rowkeys
            _regtab_eqkeys
        }
        else {
            _tabtools_collect_render, type(main) rowdim(colname) ///
                coldim(cmdset) results(_r_b _r_se) rowkeys
            quietly generate strL _eq_key = ""
        }
        quietly ds A _raw_colname _eq_key, not
        local _sm_vars `r(varlist)'
        local _sm_n : word count `_sm_vars'
        local _sm_n = floor(`_sm_n' / 2)
        forvalues _m = 1/`_sm_n' {
            foreach _sl in anc cut reg pred {
                local _sm_`_sl'_`_m' ""
            }
            local _sm_k_`_m' = 0
        }
        forvalues _r = 3/`=_N' {
            local _key = strtrim(_raw_colname[`_r'])
            if `"`_key'"' == "" continue
            local _eq = _eq_key[`_r']
            _regtab_role `"`_eq'"' `"`_key'"'
            forvalues _m = 1/`_sm_n' {
                local _vb : word `=2*`_m'-1' of `_sm_vars'
                local _vs : word `=2*`_m'' of `_sm_vars'
                local _cb = strtrim(`_vb'[`_r'])
                local _cs = subinstr(strtrim(`_vs'[`_r']), ",", "", .)
                if `"`_cb'`_cs'"' == "" continue
                if inlist("`_role'", "anc", "cut") {
                    local _sm_`_role'_`_m' `"`_sm_`_role'_`_m'' `_key'"'
                }
                else if "`_role'" == "reg" {
                    local _sm_reg_`_m' `"`_sm_reg_`_m'' `_key'"'
                    * predictor variables: factor and interaction notation
                    * reduced to the variable names it is built from
                    local _kparts = subinstr(`"`_key'"', "#", " ", .)
                    foreach _kp of local _kparts {
                        local _kv = ustrregexra(`"`_kp'"', "^.*\.", "")
                        if `"`_kv'"' != "" local _sm_pred_`_m' `"`_sm_pred_`_m'' `_kv'"'
                    }
                }
                if !missing(real(`"`_cs'"')) & !regexm(`"`_eq'"', "^_diparm") {
                    local ++_sm_k_`_m'
                }
            }
        }
        forvalues _m = 1/`_sm_n' {
            foreach _sl in anc cut reg pred {
                local _sm_`_sl'_`_m' : list uniq _sm_`_sl'_`_m'
            }
            local _sm_ac `"`_sm_anc_`_m'' `_sm_cut_`_m''"'
            local _sm_both : list _sm_reg_`_m' & _sm_ac
            foreach _k of local _sm_both {
                local _sm_collide `"`_sm_collide' model `_m' (`_k')"'
            }
        }
    }
    local _sm_rc = _rc
    restore
    if `_sm_rc' {
        noisily display as error "Could not map the collected coefficients to their equations"
        exit `_sm_rc'
    }

    * =========================================================================
    * STORE MODEL STATISTICS BEFORE COLLECT EXPORT
    * =========================================================================
    * Store e() statistics for each model in the collection
    * These may get cleared during processing, so capture them now

    local add_stats = 0
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
        local want_events = 0
        local want_r2_a = 0
        local want_rmse = 0
        local want_F = 0
        local want_mi_m = 0
        local want_fmi = 0

        local stats_lower = " " + strlower("`stats'") + " "
        if strpos("`stats_lower'", " n ") local want_n = 1
        if strpos("`stats_lower'", " aic ") local want_aic = 1
        if strpos("`stats_lower'", " bic ") local want_bic = 1
        if strpos("`stats_lower'", " qic ") local want_qic = 1
        if strpos("`stats_lower'", " icc ") local want_icc = 1
        if strpos("`stats_lower'", " ll ") local want_ll = 1
        if strpos("`stats_lower'", " groups ") local want_groups = 1
        if strpos("`stats_lower'", " r2 ") | strpos("`stats_lower'", " r-squared ") local want_r2 = 1
        if strpos("`stats_lower'", " events ") local want_events = 1
        if strpos("`stats_lower'", " r2_a ") local want_r2_a = 1
        if strpos("`stats_lower'", " rmse ") local want_rmse = 1
        if strpos("`stats_lower'", " f ") local want_F = 1
        if strpos("`stats_lower'", " mi_m ") local want_mi_m = 1
        if strpos("`stats_lower'", " fmi ") local want_fmi = 1

        * Aliases: treat n_sub / subjects as a request for the N row; regtab
        * already prefers N_sub (subjects) over N (rows) for survival models.
        if strpos("`stats_lower'", " n_sub ") | strpos("`stats_lower'", " subjects ") ///
            local want_n = 1

        * Warn (do not silently drop) on unrecognized stats() tokens.
        local _stat_known " n n_sub subjects aic bic qic icc ll groups r2 r-squared events r2_a rmse f mi_m fmi "
        foreach _stok of local stats {
            local _stok_l = strlower("`_stok'")
            if !strpos("`_stat_known'", " `_stok_l' ") {
                noisily display as error ///
                    "warning: stats() token '`_stok'' not recognized and ignored;" ///
                    " valid: n (n_sub/subjects) events groups mi_m aic bic qic ll icc r2 r2_a rmse F fmi"
            }
        }

        * ================================================================
        * EXTRACT PER-MODEL STATS FROM COLLECTION
        * ================================================================
        * The collect framework stores e() scalars per cmdset.
        * Extract via temporary layout + export + import cycle.
        local n_stat_models = 0
        local _qicu_scale_unavailable ""

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
            if `_any_gee' local result_levels "`result_levels' phi"
        }
        if `want_groups' local result_levels "`result_levels' N_g"
        if `want_r2' local result_levels "`result_levels' r2 r2_p r2_a"
        if `want_events' local result_levels "`result_levels' N_fail"
        if `want_r2_a' local result_levels "`result_levels' r2_a"
        if `want_rmse' local result_levels "`result_levels' rmse"
        if `want_F' local result_levels "`result_levels' F"
        if `want_mi_m' local result_levels "`result_levels' M_mi"
        if `want_fmi' local result_levels "`result_levels' fmi_max_mi"
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
                    local stat_col_phi ""
                    local stat_col_N_g ""
                    local stat_col_r2 ""
                    local stat_col_r2_p ""
                    local stat_col_r2_a ""
                    foreach _sx in N_fail rmse F M_mi fmi_max_mi {
                        local stat_col_`_sx' ""
                    }

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
                        if "`hdr'" == "phi" local stat_col_phi "`v'"
                        if "`hdr'" == "N_g" local stat_col_N_g "`v'"
                        if "`hdr'" == "r2" local stat_col_r2 "`v'"
                        if "`hdr'" == "r2_p" local stat_col_r2_p "`v'"
                        if "`hdr'" == "r2_a" local stat_col_r2_a "`v'"
                        foreach _sx in N_fail rmse F M_mi fmi_max_mi {
                            if "`hdr'" == "`_sx'" local stat_col_`_sx' "`v'"
                        }
                    }

                    local n_stat_models = _N - 1

                    forvalues m = 1/`n_stat_models' {
                        local r = `m' + 1

                        * Extract each result level
                        foreach sname in N N_sub ll aic bic rank deviance phi N_g r2 r2_p r2_a ///
                            N_fail rmse F M_mi fmi_max_mi {
                            if "`sname'" == "N_g" local lname "groups"
                            else if "`sname'" == "N_fail" local lname "events"
                            else if "`sname'" == "M_mi" local lname "mi_m"
                            else if "`sname'" == "fmi_max_mi" local lname "fmi"
                            else local lname "`sname'"
                            local stat_`lname'_`m' = .
                            if "`stat_col_`sname''" != "" {
                                local val = `stat_col_`sname''[`r']
                                local val = subinstr("`val'", ",", "", .)
                                local _num = real("`val'")
                                if !missing(`_num') {
                                    local stat_`lname'_`m' = `_num'
                                }
                            }
                        }

                        * Compute QIC_u from deviance + rank only for xtgee
                        * models whose dispersion is fixed at phi=1.
                        * NOTE: this is Pan (2001) QIC_u, the fixed-penalty
                        * approximation, NOT QIC. Pan's QIC penalty is
                        * 2*trace(Omega*Sigma); QIC_u replaces that trace with
                        * the rank. Pan's unknown-dispersion case requires one
                        * common phi across all candidate models; dividing each
                        * model by its own e(phi) would silently invalidate the
                        * comparison. The fixed-phi boundary is therefore
                        * deliberate and conservative.
                        * k, the parameter count of AIC, BIC, and QICu: the
                        * number of estimated parameters, whatever the vce.
                        * Under a model-based vce that is e(rank) (as estat ic
                        * uses; it also nets out linear constraints). Under a
                        * robust-type vce e(rank) is the rank of the sandwich
                        * variance, capped at G-1 with G clusters, while the
                        * model still estimated every coefficient; k is then
                        * the count of collected coefficients carrying a
                        * standard error outside the derived _diparm equations.
                        * Pan (2001) defines QICu's penalty as 2p with p the
                        * number of model parameters, so QICu follows suit.
                        local _k_param = `stat_rank_`m''
                        local _vce_m ""
                        if `m' <= `_meta_models' local _vce_m "`model_vce_`m''"
                        if inlist("`_vce_m'", "robust", "cluster", "bootstrap", ///
                            "jackknife", "linearized", "brr", "sdr") & `m' <= `_sm_n' {
                            if `_sm_k_`m'' > 0 local _k_param = `_sm_k_`m''
                        }
                        local stat_qic_`m' = .
                        local _this_is_gee = 0
                        if `m' <= `_meta_models' {
                            local _this_is_gee = `model_is_gee_`m''
                        }
                        if `_this_is_gee' {
                            * xtgee is quasi-likelihood based: never retain a
                            * backend e(aic)/e(bic) on an incompatible scale.
                            local stat_aic_`m' = .
                            local stat_bic_`m' = .
                            if !missing(`stat_phi_`m'') & abs(`stat_phi_`m'' - 1) <= 1e-10 & ///
                                !missing(`stat_deviance_`m'') & !missing(`_k_param') {
                                local stat_qic_`m' = `stat_deviance_`m'' + 2 * `_k_param'
                            }
                            else if (`want_qic' | `want_aic') {
                                local _qicu_scale_unavailable ///
                                    `"`_qicu_scale_unavailable' `m'"'
                            }
                        }

                        * AIC = -2*ll + 2*k. Always recompute from ll + k when
                        * both are present rather than trusting e(aic): glm (the GEE
                        * backend) stores e(aic) as AIC/N (per observation), ~N times
                        * too small. The formula matches estat ic for every ML/GLM
                        * estimator and keeps glm and mixed models on one scale.
                        if !`_this_is_gee' & !missing(`stat_ll_`m'') & !missing(`_k_param') {
                            local stat_aic_`m' = -2 * `stat_ll_`m'' + 2 * `_k_param'
                        }

                        * BIC = -2*ll + k*ln(N), likewise recomputed from ll + k + N.
                        * glm's e(bic) uses a deviance-based convention that is not
                        * comparable to the likelihood BIC mixed models report.
                        if !`_this_is_gee' & !missing(`stat_ll_`m'') & ///
                            !missing(`_k_param') & !missing(`stat_N_`m'') {
                            local stat_bic_`m' = -2 * `stat_ll_`m'' + `_k_param' * ln(`stat_N_`m'')
                        }

                        * Prefer N_sub (subjects) over N (rows) for survival models
                        if !missing(`stat_N_sub_`m'') {
                            local stat_N_`m' = `stat_N_sub_`m''
                            local _any_N_sub = 1
                        }
                    }
                }
                if _rc local n_stat_models = 0
                restore
            }
        }

        * A requested group count must come from the collection.  Active e()
        * is separate state and may describe a later, unrelated fit.
        if `n_stat_models' > 0 & `want_groups' == 1 {
            local _all_grp_miss = 1
            local _groups_supported = 0
            forvalues m = 1/`n_stat_models' {
                if !missing(`stat_groups_`m'') local _all_grp_miss = 0
                if `m' <= `_meta_models' {
                    if "`model_re_family_`m''" != "none" local _groups_supported = 1
                }
            }
            if `_all_grp_miss' & `_groups_supported' {
                noisily display as error ///
                    "Could not recover requested group counts from the active collection"
                exit 459
            }
        }

        * Model statistics must come from the collection.  Active e() is a
        * separate state surface and cannot identify an exact collected fit.
        if `n_stat_models' == 0 & "`result_levels'" != "" {
            noisily display as error ///
                "Could not recover model statistics from the active collection"
            exit 459
        }
        if `n_stat_models' == 0 local n_stat_models = `_meta_models'

        if "`_qicu_scale_unavailable'" != "" {
            local _qicu_scale_unavailable : list uniq _qicu_scale_unavailable
            local _qicu_scale_unavailable = strtrim("`_qicu_scale_unavailable'")
            noisily display as text ///
                "Note: QICu unavailable for GEE model(s) `_qicu_scale_unavailable': dispersion is not fixed at 1"
            noisily display as text ///
                "      use xtgee, scale(1), or compute all candidates externally with one common scale"
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
            * is skipped and the metadata model count supplies the slots.
            * model_icc_undef is set during cmdline parsing for count-data mixed
            * models (mepoisson, menbreg). Use it here rather than re-parsing
            * model_cmd_`m', which may report a deeper e(cmd) name like "meglm".
            local _icc_skip_list ""
            local _icc_skip_n = 0
            local _icc_supported = 0
            if `_meta_models' > 0 {
                forvalues m = 1/`_meta_models' {
                    if `model_icc_undef_`m'' {
                        local _icc_skip_list `"`_icc_skip_list' `m'"'
                    }
                    else if "`model_re_family_`m''" != "none" {
                        local ++_icc_supported
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

            local _icc_collevels "var(_cons) var(e)"
            capture quietly collect levelsof colname
            if _rc == 0 {
                local _icc_levels `"`s(levels)'"'
                foreach _icl of local _icc_levels {
                    if `"`_icl'"' == "var(_cons)" | ///
                        regexm(`"`_icl'"', "^var\(_cons\[.*\]\)$") | ///
                        inlist(`"`_icl'"', "var(e)", "var(Residual)") {
                        local _icc_collevels `"`_icc_collevels' `_icl'"'
                    }
                }
            }
            local _icc_collevels : list uniq _icc_collevels

            capture {
                collect layout (cmdset) ///
                    (colname[`_icc_collevels']#result[_r_b])
            }

            if _rc == 0 {
                preserve
                capture {
                    _tabtools_collect_render, type(icc) rowdim(cmdset) ///
                        coldim(colname) collevels(`"`_icc_collevels'"') results(_r_b)

                    * Find first data row (column A has cmdset number)
                    local _icc_hdr = 0
                    forvalues _ir = 1/`=_N' {
                        if !missing(real(A[`_ir'])) {
                            local _icc_hdr = `_ir' - 1
                            continue, break
                        }
                    }
                    local n_icc_models = _N - `_icc_hdr'

                    * Find columns for each variance component
                    ds
                    local icc_allvars `r(varlist)'
                    local icc_cols_re ""
                    local icc_cols_resid ""
                    foreach v of local icc_allvars {
                        local hdr = `v'[1]
                        if "`hdr'" == "var(_cons)" | ///
                            regexm("`hdr'", "^var\(_cons\[.*\]\)$") {
                            local icc_cols_re "`icc_cols_re' `v'"
                        }
                        if inlist("`hdr'", "var(e)", "var(Residual)") ///
                            local icc_cols_resid "`icc_cols_resid' `v'"
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
                        local val_re = 0
                        local val_re_found = 0
                        local val_resid = ""

                        foreach _re_col of local icc_cols_re {
                            local val = subinstr(`_re_col'[`r'], ",", "", .)
                            local _num = real("`val'")
                            if !missing(`_num') {
                                local val_re = `val_re' + `_num'
                                local val_re_found = 1
                            }
                        }
                        foreach _res_col of local icc_cols_resid {
                            local val = subinstr(`_res_col'[`r'], ",", "", .)
                            local _num = real("`val'")
                            if !missing(`_num') {
                                local val_resid = `_num'
                                continue, break
                            }
                        }

                        if `val_re_found' & "`val_resid'" != "" {
                            local stat_icc_`m' = `val_re' / (`val_re' + `val_resid')
                        }
                        else if `val_re_found' & "`val_resid'" == "" {
                            * Latent-response models have link-specific
                            * level-1 variances. Never default an unknown model
                            * to the logistic pi^2/3 denominator.
                            local _icc_resid = .
                            if `m' <= `_meta_models' {
                                local _icc_resid = `model_icc_resid_`m''
                            }
                            if !missing(`_icc_resid') {
                                local stat_icc_`m' = `val_re' / (`val_re' + `_icc_resid')
                            }
                        }
                    }
                }
                if _rc local n_icc_models = 0
                restore
            }

            * If the collect path found model rows but all ICC values are still
            * missing, reset so supported but unmappable components produce r(459).
            if `n_icc_models' > 0 {
                local _all_icc_miss = 1
                forvalues _im = 1/`n_icc_models' {
                    local _this_icc `"`stat_icc_`_im''"'
                    if `"`_this_icc'"' != "" {
                        if !missing(real(`"`_this_icc'"')) local _all_icc_miss = 0
                    }
                }
                if `_all_icc_miss' local n_icc_models = 0
            }

            * ICC values must also remain collection-derived.  Count-data
            * mixed models are intentionally blank; supported families error
            * if their variance components cannot be mapped exactly.
            if `n_icc_models' == 0 & `_icc_supported' > 0 {
                noisily display as error ///
                    "Could not recover requested ICC components from the active collection"
                exit 459
            }
        }
    }

    * =========================================================================
    * DETECT MODEL TYPE FOR RANDOM EFFECTS TRANSFORMATION
    * =========================================================================
    * melogit -> Median Odds Ratio (MOR)
    * mestreg / mecloglog -> Median Hazard Ratio (MHR)
    * Note: melogit stores e(cmd)="meglm", mestreg stores e(cmd)="gsem".
    * For multi-model collections, use the per-model command metadata parsed
    * above; ambient e(cmd2) belongs only to the last model and makes the
    * transformation order-dependent when a nonmixed model comes last.
    * Different mixed-effects families are rejected above unless RE rows are
    * suppressed, so the single non-none family applies to every RE row.
    local re_transform = "none"
    if "`_re_family_seen'" == "mor" {
        local re_transform = "mor"
    }
    else if "`_re_family_seen'" == "mhr" {
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

    * Random-effects labels must use metadata stored with the collection.  A
    * later estimation command may have replaced every active e() field.
    local re_groupvars = ""
    local _re_redim = ""
    local _re_meta_ambiguous = 0
    if `_meta_models' > 0 {
        forvalues m = 1/`_meta_models' {
            if `"`model_ivars_`m''"' != "" & `"`model_ivars_`m''"' != "." {
                if "`re_groupvars'" == "" {
                    local re_groupvars `"`model_ivars_`m''"'
                    local re_vars `"`model_revars_`m''"'
                    local _re_redim `"`model_redim_`m''"'
                }
                else if `"`model_ivars_`m''"' != `"`re_groupvars'"' | ///
                    `"`model_revars_`m''"' != `"`re_vars'"' | ///
                    `"`model_redim_`m''"' != `"`_re_redim'"' {
                    local _re_meta_ambiguous = 1
                }
            }
        }
    }
    if `_re_meta_ambiguous' {
        * A shared relabel cannot represent different grouping structures.
        * Keep the original collection labels unless relabel was requested.
        if "`relabel'" != "" & "`noreeffects'" == "" {
            noisily display as error ///
                "Random-effects metadata differ across collected models"
            noisily display as error ///
                "Use separate regtab calls, or omit relabel"
            exit 459
        }
        local re_groupvars ""
        local re_vars ""
        local _re_redim ""
    }
    * Check for empty string AND "." (missing value returned by OLS models)
    if "`re_groupvars'" != "" & "`re_groupvars'" != "." {
        local _n_re_levels : word count `re_groupvars'
        local _is_multilevel = (`_n_re_levels' > 1)
        local _path_so_far ""

        * Store label for each grouping variable
        forvalues _lev = 1/`_n_re_levels' {
            local _gvar : word `_lev' of `re_groupvars'
            local re_groupvar_`_lev' `"`_gvar'"'
            if "`_path_so_far'" == "" local _path_so_far "`_gvar'"
            else local _path_so_far "`_path_so_far'>`_gvar'"
            local re_grouppath_`_lev' `"`_path_so_far'"'
            local _glbl ""
            capture local _glbl : variable label `_gvar'
            if "`_glbl'" == "" local _glbl "`_gvar'"
            local re_grouplbl_`_lev' `"`_glbl'"'
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
                    local re_grouplbl_`_lev' `"`re_groupvar_`_lev''"'
                }
            }
        }

        * Backward compat: single-level vars from first grouping variable
        local re_groupvar : word 1 of `re_groupvars'
        local re_grouplbl `"`re_grouplbl_1'"'

        if "`re_vars'" != "" {
            * Store labels for each random effect variable
            foreach revar of local re_vars {
                if "`revar'" == "_cons" {
                    local lbl_`revar' "Intercept"
                }
                else {
                    capture local lbl_`revar' : variable label `revar'
                    if "`lbl_`revar''" == "" local lbl_`revar' "`revar'"
                }
            }

            * Parse per-level random effects using collected redim metadata.
            if "`_re_redim'" != "" {
                local _re_pos = 1
                forvalues _lev = 1/`_n_re_levels' {
                    local _dim : word `_lev' of `_re_redim'
                    local re_vars_`_lev' = ""
                    forvalues _d = 1/`_dim' {
                        local _rv : word `_re_pos' of `re_vars'
                        local re_vars_`_lev' `"`re_vars_`_lev'' `_rv'"'
                        local _re_pos = `_re_pos' + 1
                    }
                    local re_vars_`_lev' = strtrim("`re_vars_`_lev''")
                }
            }
            else {
                * Assign all revars to level 1 when collected redim is unavailable.
                local re_vars_1 `"`re_vars'"'
                forvalues _lev = 2/`_n_re_levels' {
                    local re_vars_`_lev' ""
                }
            }
        }
    }

    * Labels of every variable named inside a collected random-effects key
    * (var(x[g]), cov(x[g],_cons[g]), sd(x)). The me* estimators record no
    * e(revars) in the collection, and relabel runs on the rendered string
    * data, where the model's variables no longer exist; read them now.
    local _rel_n = 0
    if "`relabel'" != "" {
        capture quietly collect levelsof colname
        if _rc == 0 {
            local _rel_levels `"`s(levels)'"'
            foreach _rk of local _rel_levels {
                if !ustrregexm(`"`_rk'"', "^(var|sd|cov)\(") continue
                local _rk_in = ustrregexra(`"`_rk'"', "^(var|sd|cov)\(|\)$|\[[^\]]*\]", "")
                local _rk_in = subinstr(`"`_rk_in'"', ",", " ", .)
                foreach _rn of local _rk_in {
                    if inlist("`_rn'", "_cons", "e") continue
                    if strtoname("`_rn'") != "`_rn'" continue
                    local _rel_seen = 0
                    forvalues _rli = 1/`_rel_n' {
                        if "`_rel_nm_`_rli''" == "`_rn'" local _rel_seen = 1
                    }
                    if `_rel_seen' continue
                    capture confirm variable `_rn', exact
                    if _rc continue
                    local ++_rel_n
                    local _rel_nm_`_rel_n' "`_rn'"
                    local _rel_lb_`_rel_n' : variable label `_rn'
                    if `"`_rel_lb_`_rel_n''"' == "" local _rel_lb_`_rel_n' "`_rn'"
                }
            }
        }
    }

    * Capture factor variable value labels for factorlabel option
    if "`factorlabel'" != "" {
        local _fvlabel_cmds ""
        local _fv_varlist ""
        capture quietly collect levelsof colname
        if _rc == 0 local _fv_varlist `"`s(levels)'"'
        if "`_fv_varlist'" != "" {
            foreach _fvterm of local _fv_varlist {
                if regexm("`_fvterm'", "^([0-9]+)\.(.+)$") {
                    local _fvval = regexs(1)
                    local _fvvar = regexs(2)
                    * Remove interaction prefix if present (e.g., c.var#1.var2)
                    if strpos("`_fvvar'", "#") > 0 continue
                    local _fvlbl ""
                    capture local _fvlbl : label (`_fvvar') `_fvval'
                    if !_rc {
                        if "`_fvlbl'" != "" & "`_fvlbl'" != "`_fvval'" {
                            local _fvlabel_cmds `"`_fvlabel_cmds' `_fvval'.`_fvvar'=`_fvlbl'"'
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
                    local _fvlbl `"`_fvval'"'
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

* Capture labels for omitted-term display. Raw coefficient identities come
* directly from the renderer and never from this display-label map.
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
        coldim(cmdset) results(_r_b _r_ci _r_p) sep("`sep'") omitmap rowkeys
    local _collect_render_rc = _rc
}
else {
    capture _tabtools_collect_render, type(main) rowdim(colname) ///
        coldim(cmdset) results(_r_b _r_ci _r_p) sep("`sep'") factorparents omitmap rowkeys
    local _collect_render_rc = _rc
}
* Constraint class per model column and raw colname, straight from the saved
* collection. The rendered table cannot recover it: collect reports a base
* level and a dropped level as the same "4.grp" carrying the same zero and the
* same empty interval, so without this map a collinear level is indistinguish-
* able from the reference category. Read it out now, before any other r-class
* command overwrites r().
local _omit_n = 0
if `_collect_render_rc' == 0 {
    * an older installed helper returns no omit_n, which evaluates to missing
    local _omit_n = r(omit_n)
    if `"`_omit_n'"' == "" local _omit_n = 0
    if missing(`_omit_n') local _omit_n = 0
    forvalues _ok = 1/`_omit_n' {
        local _omit_key_`_ok' `"`r(omit_key_`_ok')'"'
        local _omit_val_`_ok' `"`r(omit_val_`_ok')'"'
    }
}
if `_collect_render_rc' {
    restore
    noisily display as error "Could not render the collection with exact row identities"
    exit `_collect_render_rc'
}
* Note: DO NOT TRIM WHITE SPACE--NEED IT FOR LEADING INDENT FOR CATEGORICAL VARIABLE

* Guard against empty collect tables (R3)
if _N < 3 {
	noisily display as error "Collect table appears empty or has insufficient data"
	capture erase "`temp_xlsx'"
	restore
	exit 2000
}

* The renderer carries each raw key alongside its display row. Repeated
* display labels must never participate in coefficient identity recovery.
confirm variable _raw_colname

* Structural row roles, one variable per model column: cons, cut, anc (an
* ancillary parameter shown under nointercept), ancd (one nointercept drops),
* scale, re, or "" (an ordinary coefficient, or no cell). In the coleq layouts
* each row carries its own equation, so the role is exact per row. In the
* colname layout a row is one coefficient name across models, so each model's
* role comes from the structural map built before rendering; a name that is
* both an ordinary and an ancillary coefficient of the same model cannot be
* shown in one row and is refused. Under nointercept the multi-equation layout
* drops every ancillary row (its "Ancillary:" block); otherwise only lnalpha,
* alpha, ln_p, p, and 1/p are dropped, and sigma-type parameters (lnsigma,
* lngamma, ...) stay visible.
if `_sm_n' * 3 + 2 != c(k) {
    restore
    noisily display as error "Could not align the collected models with their coefficient map"
    exit 459
}
local _role_vars ""
forvalues _m = 1/`_sm_n' {
    quietly generate str5 _role_m`_m' = ""
    local _role_vars "`_role_vars' _role_m`_m'"
}
local _anc_drop_names "lnalpha alpha ln_p p 1/p"
if `_use_coleq_layout' {
    capture noisily _regtab_eqkeys
    if _rc {
        local _eqk_rc = _rc
        restore
        exit `_eqk_rc'
    }
    forvalues _r = 3/`=_N' {
        local _key = strtrim(_raw_colname[`_r'])
        if `"`_key'"' == "" continue
        local _eq = _eq_key[`_r']
        _regtab_role `"`_eq'"' `"`_key'"'
        if "`_role'" == "reg" continue
        if "`_role'" == "anc" {
            local _in_drop : list _key in _anc_drop_names
            if `_is_multieq' | `_in_drop' local _role "ancd"
        }
        foreach _rv of local _role_vars {
            quietly replace `_rv' = "`_role'" in `_r'
        }
    }
    drop _eq_key
}
else {
    if `"`_sm_collide'"' != "" {
        restore
        noisily display as error ///
            "A coefficient name is both a covariate and an ancillary parameter of the same model:`_sm_collide'"
        noisily display as error ///
            "One row cannot show both; rename the covariate and refit"
        exit 459
    }
    forvalues _m = 1/`_sm_n' {
        foreach _k of local _sm_anc_`_m' {
            local _in_drop : list _k in _anc_drop_names
            local _rr = cond(`_in_drop', "ancd", "anc")
            quietly replace _role_m`_m' = "`_rr'" if _n > 2 & strtrim(_raw_colname) == `"`_k'"'
        }
        foreach _k of local _sm_cut_`_m' {
            quietly replace _role_m`_m' = "cut" if _n > 2 & strtrim(_raw_colname) == `"`_k'"'
        }
        quietly replace _role_m`_m' = "cons" if _n > 2 & strtrim(_raw_colname) == "_cons"
        quietly replace _role_m`_m' = "re" if _n > 2 & ///
            ustrregexm(strtrim(_raw_colname), "^(var|cov|sd|corr)\(")
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
        * Header rows are the renderer's coleq rows, the only rows without a
        * raw colname key. An empty model-1 cell is not a header: it is a row
        * that only a later model estimates.
        gen byte _q_is_header = _n > 2 & strtrim(_raw_colname) == ""
        drop if _q_is_header
        drop _q_is_header
        forvalues _lev = 1/`_n_re_levels' {
            local _gvar `"`re_groupvar_`_lev''"'
            local _gpath `"`re_grouppath_`_lev''"'
            if "`_gpath'" != "`_gvar'" {
                replace A = subinstr(A, "[`_gpath']", "[`_gvar']", .) ///
                    if _n > 2 & (strpos(A, "var(") > 0 | strpos(A, "cov(") > 0 | strpos(A, "sd(") > 0)
            }
        }
    }
    else {
        * Identify header rows by their empty raw key (see above); an empty
        * model-1 cell marks a row only a later model estimates.
        gen byte _is_header = strtrim(_raw_colname) == "" & _n > 2

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
            local _gvar `"`re_groupvar_`_lev''"'
            local _target_grp = `_fe_grp' + `_lev'
            replace _parent_header = `"`_gvar'"' if _hdr_grp == `_target_grp'
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

    * The coleq#colname renderer builds no factor parent rows, so a factor
    * lost its header row (Sex above Male/Female) as soon as a model had two
    * grouping levels. Insert the parent the colname layout would have
    * rendered: keyed on the raw colname, once per consecutive run of levels.
    quietly generate str244 _fp_par = ""
    forvalues _fpr = 3/`=_N' {
        local _fp_key = strtrim(_raw_colname[`_fpr'])
        _regtab_fvparent `"`_fp_key'"'
        if `"`_fp_parent'"' == "" continue
        quietly replace _fp_par = `"`_fp_parent'"' in `_fpr'
    }
    quietly count if _n > 2 & _fp_par != ""
    if r(N) > 0 {
        quietly generate long _fp_ord = _n
        quietly generate byte _fp_new = _n > 2 & _fp_par != "" & _fp_par != _fp_par[_n - 1]
        quietly expand 2 if _fp_new, generate(_fp_dup)
        quietly ds A _raw_colname _fp_par _fp_ord _fp_new _fp_dup, not
        foreach _fpv in `r(varlist)' {
            capture confirm string variable `_fpv'
            if _rc == 0 quietly replace `_fpv' = "" if _fp_dup
            else quietly replace `_fpv' = . if _fp_dup
        }
        quietly replace A = _fp_par if _fp_dup
        quietly replace _raw_colname = _fp_par if _fp_dup
        gsort _fp_ord -_fp_dup
        drop _fp_ord _fp_new _fp_dup
    }
    drop _fp_par
}
else if `_is_multieq' {
    gen long _orig_row_order = _n
    * Equation header rows carry no raw colname key. Keying on an empty
    * model-1 cell deleted every row model 1 lacks: a covariate only a later
    * model has, and whole equations (zinb's ancillary rows beside zip, a
    * second outcome's equation) absent from model 1.
    gen byte _is_header = strtrim(_raw_colname) == "" & _n > 2
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

    * The rule above removes the o.-marked rows of a base-outcome equation but
    * not its factor levels, which collect reports without the marker. That
    * left half an equation of constrained cells standing beside the estimated
    * ones. An equation in which no coefficient was estimated at all carries no
    * information, so drop it whole - but only while some other equation does
    * have estimates, so a table is never emptied.
    ds
    local _eqvars `r(varlist)'
    local _eqhelpers "A _raw_colname _orig_row_order _is_header _parent_header _A_trim _eq_label `_role_vars'"
    local _eqvars : list _eqvars - _eqhelpers
    local _eq_ci_vars ""
    local _eqpos = 0
    foreach _eqv of local _eqvars {
        local ++_eqpos
        if mod(`_eqpos', 3) == 2 local _eq_ci_vars `"`_eq_ci_vars' `_eqv'"'
    }
    if `"`_eq_ci_vars'"' != "" {
        gen byte _eq_row_data = 0
        foreach _eqv of local _eq_ci_vars {
            quietly replace _eq_row_data = 1 ///
                if !_is_header & _n > 2 & strtrim(`_eqv') != ""
        }
        quietly count if _eq_row_data
        if r(N) > 0 {
            bysort _eq_label (_eq_row_data): gen byte _eq_any_data = _eq_row_data[_N]
            sort _orig_row_order
            quietly count if _n > 2 & !_is_header & _eq_any_data == 0
            if r(N) > 0 {
                drop if _n > 2 & !_is_header & _eq_any_data == 0
            }
            drop _eq_any_data
        }
        drop _eq_row_data
    }

    * Factor covariates: the single-equation layout's parent row ("Sex")
    * above indented level rows ("  Male", "  Female"), once per consecutive
    * run of levels inside each equation block, keyed on the raw colname.
    quietly generate str244 _fp_par = ""
    forvalues _fpr = 3/`=_N' {
        if _is_header[`_fpr'] continue
        local _fp_key = strtrim(_raw_colname[`_fpr'])
        _regtab_fvparent `"`_fp_key'"'
        if `"`_fp_parent'"' == "" continue
        quietly replace _fp_par = `"`_fp_parent'"' in `_fpr'
        forvalues _fvi = 1/`_fvrow_label_n' {
            if `"`_fvrow_pat_`_fvi''"' == `"`_fp_key'"' {
                quietly replace _A_trim = `"`_fvrow_lab_`_fvi''"' in `_fpr'
            }
        }
    }
    quietly count if _n > 2 & _fp_par != ""
    if r(N) > 0 {
        quietly generate long _fp_ord = _n
        quietly generate byte _fp_new = _n > 2 & _fp_par != "" & _fp_par != _fp_par[_n - 1]
        quietly expand 2 if _fp_new, generate(_fp_dup)
        quietly ds A _raw_colname _fp_par _fp_ord _fp_new _fp_dup ///
            _is_header _parent_header _eq_label _orig_row_order, not
        foreach _fpv in `r(varlist)' {
            capture confirm string variable `_fpv'
            if _rc == 0 quietly replace `_fpv' = "" if _fp_dup
            else quietly replace `_fpv' = . if _fp_dup
        }
        quietly replace _raw_colname = _fp_par if _fp_dup
        quietly replace _A_trim = _fp_par if _fp_dup
        forvalues _fvp = 1/`_fvrow_parent_n' {
            quietly replace _A_trim = `"`_fvrow_parent_lab_`_fvp''"' ///
                if _fp_dup & _fp_par == `"`_fvrow_parent_var_`_fvp''"'
        }
        gsort _fp_ord -_fp_dup
        drop _fp_ord _fp_new _fp_dup
    }
    drop _fp_par

    replace A = _eq_label + ": " + _A_trim ///
        if !_is_header & _eq_label != "" & strtrim(_A_trim) != "" & _n > 2
    drop if _is_header
    drop _is_header _parent_header _A_trim _eq_label _orig_row_order
}

* nointercept drops intercept, cutpoint, and dropped-ancillary cells by their
* structural role. A row goes only when every model with a cell in it has such
* a role; a model's cell is blanked when another model's cell in the same row is
* an ordinary coefficient that must stay.
if "`noint'" != "" {
    quietly ds A _raw_colname `_role_vars', not
    local _ni_vars `r(varlist)'
    quietly generate byte _ni_keep = 0
    quietly generate byte _ni_drop = 0
    quietly generate byte _ni_has = 0
    forvalues _m = 1/`_sm_n' {
        local _v1 : word `=3*`_m'-2' of `_ni_vars'
        local _v2 : word `=3*`_m'-1' of `_ni_vars'
        local _v3 : word `=3*`_m'' of `_ni_vars'
        quietly replace _ni_has = strtrim(`_v1') != "" | strtrim(`_v2') != "" | strtrim(`_v3') != ""
        quietly replace _ni_drop = 1 if _n > 2 & _ni_has ///
            & inlist(_role_m`_m', "cons", "cut", "ancd", "scale")
        quietly replace _ni_keep = 1 if _n > 2 & _ni_has ///
            & !inlist(_role_m`_m', "cons", "cut", "ancd", "scale")
        foreach _v in `_v1' `_v2' `_v3' {
            quietly replace `_v' = "" if _n > 2 ///
                & inlist(_role_m`_m', "cons", "cut", "ancd", "scale")
        }
    }
    drop if _n > 2 & _ni_drop & !_ni_keep
    drop _ni_keep _ni_drop _ni_has
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
            local _gvar `"`re_groupvar_`_lev''"'
            local _gpath `"`re_grouppath_`_lev''"'
            local _glbl `"`re_grouplbl_`_lev''"'
            replace _re_group_label = `"`_glbl'"' if A == "var(_cons[`_gvar'])"
            if "`_gpath'" != "`_gvar'" {
                replace _re_group_label = `"`_glbl'"' if A == "var(_cons[`_gpath'])"
            }
            replace _re_group_label = `"`_glbl'"' ///
                if _is_re_intercept == 1 & _re_group_label == "" ///
                & (strpos(A, "[`_gvar']") > 0 | strpos(A, ">`_gvar']") > 0)
        }
    }
    if "`re_grouplbl'" != "" {
        replace _re_group_label = `"`re_grouplbl'"' if _re_group_label == "" & A == "var(_cons)"
    }
}

* Relabel random effects if requested
if "`relabel'" != "" {
    if "`re_groupvars'" != "" & "`re_groupvars'" != "." {

        * --- Per-level relabeling (bracket notation) ---
        * Handles multi-level mixed (flattened) and melogit/mepoisson (native)
        forvalues _lev = 1/`_n_re_levels' {
            local _gvar `"`re_groupvar_`_lev''"'
            local _glbl `"`re_grouplbl_`_lev''"'

            * Random intercept: var(_cons[groupvar]) -> "Variance: GroupLabel (Intercept)"
            replace A = "Variance: `_glbl' (Intercept)" if A == "var(_cons[`_gvar'])"

            * Random slopes: var(varname[groupvar]) -> "Variance: GroupLabel (VarLabel)"
            foreach revar of local re_vars {
                if "`revar'" != "_cons" {
                    local slope_lbl `"`lbl_`revar''"'
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
                    * Extract the two components of cov(v1,v2[g]) (mixed),
                    * cov(v1[g],v2[g]) (me*), or the comma-less
                    * cov(v1[g]v2[g]): every [g] ends a component.
                    local cov_inner = substr(`"`cov_str'"', 5, .)
                    if substr(`"`cov_inner'"', -1, 1) == ")" {
                        local cov_inner = substr(`"`cov_inner'"', 1, strlen(`"`cov_inner'"') - 1)
                    }
                    local cov_inner = subinstr(`"`cov_inner'"', "[`_gvar'],", ",", .)
                    local cov_inner = subinstr(`"`cov_inner'"', "[`_gvar']", ",", .)
                    while substr(`"`cov_inner'"', -1, 1) == "," {
                        local cov_inner = substr(`"`cov_inner'"', 1, strlen(`"`cov_inner'"') - 1)
                    }
                    gettoken cov_v1 cov_v2 : cov_inner, parse(",")
                    local cov_v2 = subinstr("`cov_v2'", ",", "", 1)
                    local cov_v1 = strtrim("`cov_v1'")
                    local cov_v2 = strtrim("`cov_v2'")
                    * Only a key that splits into exactly two plain names is
                    * relabelled; anything else keeps its collect key.
                    if "`cov_v1'" == "" | "`cov_v2'" == "" | ///
                        strpos("`cov_v2'", ",") | strpos("`cov_v1'`cov_v2'", "[") continue
                    forvalues _cvk = 1/2 {
                        local cov_lbl`_cvk' "`cov_v`_cvk''"
                        if "`cov_v`_cvk''" == "_cons" local cov_lbl`_cvk' "Intercept"
                        forvalues _rli = 1/`_rel_n' {
                            if "`_rel_nm_`_rli''" == "`cov_v`_cvk''" {
                                local cov_lbl`_cvk' `"`_rel_lb_`_rli''"'
                            }
                        }
                    }
                    replace A = "Covariance: `_glbl' (`cov_lbl1', `cov_lbl2')" in `row'
                }
                drop _temp_row
            }

            * Standard deviations with brackets
            replace A = `"`_glbl' SD (Intercept)"' if A == "sd(_cons[`_gvar'])"
            foreach revar of local re_vars {
                if "`revar'" != "_cons" {
                    local slope_lbl `"`lbl_`revar''"'
                    replace A = `"`_glbl' SD (`slope_lbl')"' if A == "sd(`revar'[`_gvar'])"
                }
            }

            * Slope variances/SDs the metadata does not name. The me*
            * estimators record no e(revars) in the collection, so their
            * var(x[g]) rows stayed raw while mixed's were relabelled. Take the
            * slope name from the key itself.
            capture drop _temp_row
            gen long _temp_row = _n
            quietly levelsof _temp_row if _n > 2 & ///
                ustrregexm(A, "^(var|sd)\([^\[\]\(\),]+\[`_gvar'\]\)$"), local(_sl_rows)
            foreach row of local _sl_rows {
                local _sl_key = A[`row']
                if !ustrregexm(`"`_sl_key'"', "^(var|sd)\(([^\[\]\(\),]+)\[") continue
                local _sl_kind = ustrregexs(1)
                local _sl_var = ustrregexs(2)
                if "`_sl_var'" == "_cons" continue
                local _sl_lbl "`_sl_var'"
                forvalues _rli = 1/`_rel_n' {
                    if "`_rel_nm_`_rli''" == "`_sl_var'" local _sl_lbl `"`_rel_lb_`_rli''"'
                }
                if "`_sl_kind'" == "var" {
                    replace A = `"Variance: `_glbl' (`_sl_lbl')"' in `row'
                }
                else replace A = `"`_glbl' SD (`_sl_lbl')"' in `row'
            }
            drop _temp_row
        }

        * --- Single-level patterns (no brackets) for single-level mixed ---
        replace A = "Variance: `re_grouplbl' (Intercept)" if A == "var(_cons)"

        foreach revar of local re_vars {
            if "`revar'" != "_cons" {
                local slope_lbl `"`lbl_`revar''"'
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
                local cov_lbl1 `"`lbl_`cov_v1''"'
                if "`cov_lbl1'" == "" local cov_lbl1 "`cov_v1'"
                local cov_lbl2 `"`lbl_`cov_v2''"'
                if "`cov_lbl2'" == "" local cov_lbl2 "`cov_v2'"
                replace A = "Covariance: `re_grouplbl' (`cov_lbl1', `cov_lbl2')" in `row'
            }
            drop _temp_row
        }

        * Residual variance: var(e) -> "Residual Variance"
        replace A = "Residual Variance" if A == "var(e)"

        * Standard deviations without brackets (single-level)
        replace A = `"`re_grouplbl' SD (Intercept)"' if A == "sd(_cons)"
        foreach revar of local re_vars {
            if "`revar'" != "_cons" {
                local slope_lbl `"`lbl_`revar''"'
                replace A = `"`re_grouplbl' SD (`slope_lbl')"' if A == "sd(`revar')"
            }
        }
        replace A = "Residual SD" if A == "sd(e)"

        * Log-scale parameters (raw coefficient names: lns1_1_1, lns2_1_1, ...)
        forvalues _lev = 1/`_n_re_levels' {
            local _glbl `"`re_grouplbl_`_lev''"'
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
local _helper_vars "_is_re _is_re_intercept _re_group_label _raw_colname `_role_vars'"
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
* Preserve the raw key through all later display edits and row selections.
rename _raw_colname _raw_A

* A coefficient the model dropped for collinearity keeps its o. marker in the
* colname level whenever the term is not a factor level, so the row rendered as
* "o.flag" instead of the variable's label. Show the variable.
quietly replace A = substr(strtrim(_raw_A), 3, .) ///
	if _n > 2 & strpos(strtrim(_raw_A), "o.") == 1 & strtrim(A) == strtrim(_raw_A)
forvalues _ci = 1/`_cnmap_n' {
	quietly replace A = `"`_cnmap_label_`_ci''"' ///
		if _n > 2 & strtrim(_raw_A) == `"o.`_cnmap_level_`_ci''"'
}

* Per-model constraint class, keyed by model column index and raw colname.
* Index 0 means the collection carried no model dimension, so the class applies
* to every column. "mixed" (one colname classed differently across equations of
* one model) is left blank so the factor-key heuristic below decides instead.
forvalues _m = 1/`n_models' {
	quietly gen str8 _omit_type`_m' = ""
}
* Some estimators reach the collection with every constrained cell stamped
* "empty": nbreg, zinb, intreg, and streg's ancillary-parameter distributions
* in Stata 17. The base level of i.rep78 after nbreg is 1b. in e(b) and
* "(base)" in nbreg's own table, yet collect records it as empty, and collinear
* drops arrive the same way. A factor model whose classes are genuine carries a
* base or an omitted cell; a model whose only class is "empty" is one collect
* could not classify, so its "empty" is treated as no class at all and the
* factor-key fallback below labels the level.
forvalues _m = 0/`n_models' {
	local _ocls_`_m' ""
}
forvalues _ok = 1/`_omit_n' {
	local _okey `"`_omit_key_`_ok''"'
	local _obar = strpos(`"`_okey'"', "|")
	if `_obar' > 0 {
		local _omi = real(substr(`"`_okey'"', 1, `_obar' - 1))
		if !missing(`_omi') & `_omi' >= 0 & `_omi' <= `n_models' {
			local _ocls_`_omi' `"`_ocls_`_omi'' `_omit_val_`_ok''"'
		}
	}
}
forvalues _m = 0/`n_models' {
	local _ocls_`_m' : list uniq _ocls_`_m'
	local _ounclassed_`_m' = (`"`_ocls_`_m''"' == "empty")
}
forvalues _ok = 1/`_omit_n' {
	local _okey `"`_omit_key_`_ok''"'
	local _oval `"`_omit_val_`_ok''"'
	local _obar = strpos(`"`_okey'"', "|")
	if `_obar' > 0 & inlist(`"`_oval'"', "base", "omit", "empty") {
		local _omi = real(substr(`"`_okey'"', 1, `_obar' - 1))
		if `"`_oval'"' == "empty" & !missing(`_omi') & `_omi' >= 0 ///
			& `_omi' <= `n_models' {
			if `_ounclassed_`_omi'' continue
		}
		local _ocn = substr(`"`_okey'"', `_obar' + 1, .)
		if !missing(`_omi') & `_omi' == 0 {
			forvalues _m = 1/`n_models' {
				quietly replace _omit_type`_m' = `"`_oval'"' ///
					if _n > 2 & strtrim(_raw_A) == `"`_ocn'"'
			}
		}
		else if !missing(`_omi') & `_omi' >= 1 & `_omi' <= `n_models' {
			quietly replace _omit_type`_omi' = `"`_oval'"' ///
				if _n > 2 & strtrim(_raw_A) == `"`_ocn'"'
		}
	}
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
        replace c`_hdr_col' = `"`model_coef_`_hdr_m''"' if _n == 2
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
    * Only rows some model holds as a cutpoint (structural role), so a
    * covariate named cut1 keeps its own label.
    quietly generate byte _cut_row = 0
    foreach _rv of local _role_vars {
        quietly replace _cut_row = 1 if `_rv' == "cut"
    }
    forvalues _cut_i = 1/`_cut_n' {
        replace A = `"`_cut_label_`_cut_i''"' ///
            if _n >= 3 & _cut_row & strtrim(_raw_A) == "cut`_cut_i'"
    }
    drop _cut_row
}

* Match raw names and factor components exactly and case-sensitively.
* labelmatch explicitly requests the historical display-label substring mode.
foreach _selection in keep drop {
    if "``_selection''" == "" continue
    quietly count if _n > 2
    local _nbody_pre = r(N)
    tempvar _matched
    if "`labelmatch'" != "" {
        quietly generate byte `_matched' = 0
        foreach _term in ``_selection'' {
            quietly replace `_matched' = 1 if _n > 2 & ///
                strpos(strlower(A), strlower(`"`_term'"')) > 0
        }
    }
    else {
        _tabtools_match_rows _raw_A, generate(`_matched') terms(`"``_selection''"')
        quietly replace `_matched' = 0 if _n <= 2
    }
    quietly count if `_matched' & _n > 2
    if "`_selection'" == "keep" {
        if `_nbody_pre' > 0 & r(N) == 0 {
            noisily display as error "keep() matched no coefficient rows; check exact names or use labelmatch for display labels"
            exit 198
        }
        drop if !`_matched' & _n > 2
    }
    else {
        if `_nbody_pre' > 0 & r(N) >= `_nbody_pre' {
            noisily display as error "drop() would remove every coefficient row, leaving an empty table; check the drop() spec"
            exit 198
        }
        drop if `_matched' & _n > 2
    }
    drop `_matched'
}

local first_re_row ""
gen long _re_rowid = _n
quietly summarize _re_rowid if _is_re == 1, meanonly
if r(N) > 0 local first_re_row = r(min)
drop _re_rowid

local last = `n' - 2
* Ancillary parameters and cutpoints keep their own scale under any header.
* Set per model inside the loops below from the structural role (R1), so the
* same row can hold one model's ancillary parameter and another's covariate.
gen byte _is_ancillary = 0
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
quietly replace _is_ancillary = 0
capture confirm variable _role_m`_model_ix'
if _rc == 0 quietly replace _is_ancillary = inlist(_role_m`_model_ix', "anc", "ancd", "cut") if _n > 2
* Strip thousands separators (collect's %#.#fc nformat emits "1,234.56") so
* destring can parse coefficients >= 1000 instead of returning missing.
replace c`i' = subinstr(c`i', ",", "", .) if _n >= 3
destring c`i', gen(double c`i'z) force
* Reference categories are identified from collect's factor-level key, not
* from a numerical 0/1 value that may be a legitimate coefficient. The key
* alone only says "this row is a factor level"; whether THIS model constrained
* it comes from the model's own cells. collect emits _r_b (0, or 1 after
* eform) with an empty CI for a level the model constrained, and emits nothing
* at all for a level the model never contained. Requiring a non-empty estimate
* therefore keeps a constrained level labelled and leaves an absent level
* blank, instead of claiming every model uses the same reference category.
local _omit_ok = 0
capture confirm variable _omit_type`_model_ix'
if _rc == 0 local _omit_ok = 1
if `_omit_ok' {
	replace c`i' = `"`refcat'"' if _omit_type`_model_ix' == "base" ///
		& strtrim(c`i') != "" & c`=`i'+1' == "" & _n >= 3
	replace c`i' = `"`omitlabel'"' if _omit_type`_model_ix' == "omit" ///
		& strtrim(c`i') != "" & c`=`i'+1' == "" & _n >= 3
	replace c`i' = `"`emptylabel'"' if _omit_type`_model_ix' == "empty" ///
		& strtrim(c`i') != "" & c`=`i'+1' == "" & _n >= 3
	* Without a class, a constrained level is known only by its cells: an
	* empty CI AND an empty p-value. An estimated level whose interval bound
	* is missing (a near-separated fit prints "(0, .)") still has a p-value.
	replace c`i' = `"`refcat'"' if inlist(_omit_type`_model_ix', "", "mixed") ///
		& _is_base_level & strtrim(c`i') != "" & c`=`i'+1' == "" ///
		& strtrim(c`=`i'+2') == "" & _n >= 3
}
else {
	replace c`i' = `"`refcat'"' if _is_base_level & strtrim(c`i') != "" ///
		& c`=`i'+1' == "" & strtrim(c`=`i'+2') == "" & _n >= 3
}
gen byte _b_had = !missing(c`i'z)
if `_needs_eform' {
    replace c`i'z = exp(c`i'z) if !_is_re & !_is_ancillary & !missing(c`i'z)
}
* MOR/MHR transformation: variance -> exp(sqrt(2*var) * invnormal(0.75))
if "`re_transform'" != "none" {
    replace c`i'z = exp(sqrt(2 * c`i'z) * invnormal(0.75)) ///
        if _is_re_intercept == 1 & !missing(c`i'z) & c`i'z >= 0
}
* A transform that overflows double precision leaves no representable value;
* the cell is blank rather than collect's untransformed text.
replace c`i' = "" if _b_had & missing(c`i'z) & _n >= 3 ///
	& !inlist(strtrim(c`i'), `"`refcat'"', `"`omitlabel'"', `"`emptylabel'"')
drop _b_had
	gen double _coefnum`i' = c`i'z if _n >= 3
	capture confirm variable _eplot_est`_model_ix'
	if _rc gen double _eplot_est`_model_ix' = .
	replace _eplot_est`_model_ix' = c`i'z if _n >= 3
* Fixed effects: user-specified decimal places (default 2)
gen str32 c`i'_fmt = string(round(c`i'z, `coef_round'), "`coef_fmt'") if !_is_re & !missing(c`i'z)
* Transformed random intercept (MOR/MHR): same precision as fixed effects
replace c`i'_fmt = string(round(c`i'z, `coef_round'), "`coef_fmt'") ///
    if _is_re_intercept == 1 & "`re_transform'" != "none" & !missing(c`i'z)
* Other random effects: same decimal places as fixed effects
replace c`i'_fmt = string(round(c`i'z, `coef_round'), "`coef_fmt'") ///
    if _is_re & _is_re_intercept == 0 & !missing(c`i'z)
replace c`i' = c`i'_fmt if c`i'_fmt != "" & _n >= 3 ///
	& !inlist(c`i', `"`refcat'"', `"`omitlabel'"', `"`emptylabel'"')
drop c`i'z c`i'_fmt
capture confirm variable c`=`i'+1'
if _rc == 0 replace c`=`i'+1' = "" if _n == 1
capture confirm variable c`=`i'+2'
if _rc == 0 replace c`=`i'+2' = "" if _n == 1
}
drop _is_base_level
capture drop _omit_type*
* Reformat CI columns with appropriate precision
local sep_len = strlen(`"`sep'"')
local _model_ix = 0
forvalues i = 2(3)`=`last'+1' {
    local _model_ix = `_model_ix' + 1
    local _needs_eform = 0
    local _null = cond(inlist("`coef'", "OR", "HR", "IRR", "RRR", "SHR", "TR", "AF", "RR", "exp(b)"), 1, 0)
    if `_model_ix' <= `_meta_models' {
        local _needs_eform = `model_eform_`_model_ix''
        local _null = `model_null_`_model_ix''
    }
    capture confirm variable c`i'
    if _rc continue
    quietly replace _is_ancillary = 0
    capture confirm variable _role_m`_model_ix'
    if _rc == 0 quietly replace _is_ancillary = inlist(_role_m`_model_ix', "anc", "ancd", "cut") if _n > 2
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
	    * Wide enough for two %32.#f bounds plus parentheses and any sep().
	    gen str244 _ci_fmt = ""
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
    * A row regtab transforms (eform fixed effect, MOR/MHR intercept) whose
    * interval could not be formatted - a bound that overflowed exp(), or one
    * collect left missing - is blank. Its collect text is on the
    * untransformed scale (log odds under an OR header, a variance under a
    * MOR row), and a near-zero variance printed it at full precision, e.g.
    * "(1.83e-35, 2.22e+29)".
    gen byte _ci_xf = 0
    if `_needs_eform' replace _ci_xf = 1 if !_is_re & !_is_ancillary
    if "`re_transform'" != "none" replace _ci_xf = 1 if _is_re_intercept == 1
    replace c`i' = "" if _ci_xf & _ci_fmt == "" & _n >= 3
    drop _ci_xf
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
        replace _is_refrow = 1 if _n >= 3 ///
            & inlist(c`_ri', `"`refcat'"', `"`omitlabel'"', `"`emptylabel'"')
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
	if !_rc replace _eplot_est`_model_ix' = . if _n >= 3 ///
		& inlist(strtrim(c`=`i'-2'), `"`refcat'"', `"`omitlabel'"', `"`emptylabel'"')
	capture confirm variable _eplot_ll`_model_ix'
	if !_rc replace _eplot_ll`_model_ix' = . if _n >= 3 ///
		& inlist(strtrim(c`=`i'-2'), `"`refcat'"', `"`omitlabel'"', `"`emptylabel'"')
	capture confirm variable _eplot_ul`_model_ix'
	if !_rc replace _eplot_ul`_model_ix' = . if _n >= 3 ///
		& inlist(strtrim(c`=`i'-2'), `"`refcat'"', `"`omitlabel'"', `"`emptylabel'"')
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
            local _coefval = _coefnum`_ci'[`_obs']
            local _cicell = strtrim(c`=`_ci'+1'[`_obs'])
            if `_coefval' < . {
                if !inlist(strtrim(c`_ci'[`_obs']), `"`refcat'"', ///
                    `"`omitlabel'"', `"`emptylabel'"') {
                    local _row_has_data = 1
                }
            }
        }
        if `_row_has_data' {
            local _mat_nrows = `_mat_nrows' + 1
            local _keep_obs `"`_keep_obs' `_obs'"'
        }
    }
}
tempname _rtable
if `_mat_nrows' > 0 {
    matrix `_rtable' = J(`_mat_nrows', `n_models', .)
    tempname _rn_probe
    matrix `_rn_probe' = J(1, 1, .)
    local _rnames ""
    local _mr = 0
    foreach _obs of local _keep_obs {
        local _mr = `_mr' + 1
        local _mc = 0
        forvalues _ci = 1(3)`last' {
            local _mc = `_mc' + 1
            local _coefval = _coefnum`_ci'[`_obs']
            local _cicell = strtrim(c`=`_ci'+1'[`_obs'])
            if `_coefval' < . {
                if !inlist(strtrim(c`_ci'[`_obs']), `"`refcat'"', ///
                    `"`omitlabel'"', `"`emptylabel'"') {
                    matrix `_rtable'[`_mr', `_mc'] = `_coefval'
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
        * Each name must survive matrix rownames unchanged. A bracketed key
        * such as var(x[clinic]) was rejected, which sent the whole matrix to
        * r1, r2, ...; a comma-stripped cov(x_cons) was accepted but read back
        * as var(x_cons), naming a covariance as a variance. A name that does
        * not round-trip has every character outside [A-Za-z0-9_] replaced.
        capture matrix rownames `_rn_probe' = `_rname'
        local _rn_back ""
        if _rc == 0 local _rn_back : rownames `_rn_probe'
        if `"`_rn_back'"' != `"`_rname'"' {
            local _rname = substr(ustrregexra(`"`_rname'"', "[^A-Za-z0-9_]", "_"), 1, 32)
            capture matrix rownames `_rn_probe' = `_rname'
            local _rn_back ""
            if _rc == 0 local _rn_back : rownames `_rn_probe'
            if `"`_rn_back'"' != `"`_rname'"' local _rname "row`_mr'"
        }
        * Names must also be unique: two labels that sanitise or truncate to
        * the same name ("Same label" twice, "Age (years)" and "Age [years]",
        * a shared 32-character prefix) made r(table) rows indistinguishable.
        * A repeat takes the first free suffix _2, _3, ... in row order,
        * shortening the base so the name stays within 32 characters.
        local _rn_base `"`_rname'"'
        local _rn_sfx = 1
        local _rn_taken : list _rname in _rnames
        while `_rn_taken' {
            local ++_rn_sfx
            local _rn_tail "_`_rn_sfx'"
            local _rname = substr(`"`_rn_base'"', 1, 32 - strlen("`_rn_tail'")) + "`_rn_tail'"
            local _rn_taken : list _rname in _rnames
        }
        local _rnames `"`_rnames' `_rname'"'
    }
    capture matrix rownames `_rtable' = `_rnames'
}
capture drop _coefnum*
drop _is_re _is_re_intercept _is_ancillary
capture drop _role_m*
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

    * F statistic only for linear-model F tests (regress/anova type); a
    * svy: logit also stores e(F), which is not that statistic.
    forvalues m = 1/`use_models' {
        if `want_F' {
            local _fcmd ""
            if `m' <= `_meta_models' local _fcmd "`model_cmdword_`m''"
            if !inlist("`_fcmd'", "regress", "anova", "areg", "xtreg", "ivregress", "cnsreg") {
                local stat_F_`m' = .
            }
        }
    }
    local _nr_lab_events "Events"
    local _nr_fmt_events "%12.0fc"
    local _nr_lab_mi_m "Imputations"
    local _nr_fmt_mi_m "%12.0fc"
    local _nr_lab_r2_a "Adjusted R²"
    local _nr_fmt_r2_a "%5.3f"
    local _nr_lab_rmse "Root MSE"
    local _nr_fmt_rmse "%9.3f"
    local _nr_lab_F "F statistic"
    local _nr_fmt_F "%9.2f"
    local _nr_lab_fmi "Largest FMI"
    local _nr_fmt_fmi "%6.4f"

    * Add N row
    if `want_n' == 1 {
        local has_val = 0
        forvalues m = 1/`use_models' {
            if !missing(`stat_N_`m'') local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            local _n_label = cond(`_any_N_sub', "Subjects", "Observations")
            replace A = `"`_n_label'"' in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if !missing(`stat_N_`m'') {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_N_`m'', "%12.0fc") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
        }
    }


    foreach _nt in events {
        if `want_`_nt'' != 1 continue
        local has_val = 0
        forvalues m = 1/`use_models' {
            if !missing(`stat_`_nt'_`m'') local has_val = 1
        }
        if !`has_val' continue
        local curr_n = _N
        set obs `=`curr_n'+1'
        replace A = `"`_nr_lab_`_nt''"' in `=`curr_n'+1'
        forvalues m = 1/`use_models' {
            if !missing(`stat_`_nt'_`m'') {
                local col = (`m' - 1) * 3 + 1
                replace c`col' = string(`stat_`_nt'_`m'', "`_nr_fmt_`_nt''") in `=`curr_n'+1'
            }
        }
        local stats_rows = "`stats_rows' `=`curr_n'+1'"
    }

    * Add Groups row
    if `want_groups' == 1 {
        local has_val = 0
        forvalues m = 1/`use_models' {
            if !missing(`stat_groups_`m'') local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = "Groups" in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if !missing(`stat_groups_`m'') {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`stat_groups_`m'', "%12.0fc") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
        }
    }

    foreach _nt in mi_m {
        if `want_`_nt'' != 1 continue
        local has_val = 0
        forvalues m = 1/`use_models' {
            if !missing(`stat_`_nt'_`m'') local has_val = 1
        }
        if !`has_val' continue
        local curr_n = _N
        set obs `=`curr_n'+1'
        replace A = `"`_nr_lab_`_nt''"' in `=`curr_n'+1'
        forvalues m = 1/`use_models' {
            if !missing(`stat_`_nt'_`m'') {
                local col = (`m' - 1) * 3 + 1
                replace c`col' = string(`stat_`_nt'_`m'', "`_nr_fmt_`_nt''") in `=`curr_n'+1'
            }
        }
        local stats_rows = "`stats_rows' `=`curr_n'+1'"
    }

    * Add AIC row (falls back to QICu for fixed-scale GEE models where AIC is
    * undefined). Track that fallback so stats(aic qic) cannot append QICu twice.
    local _qicu_rendered_by_aic 0
    if `want_aic' == 1 {
        local has_val = 0
        local _aic_label "AIC"
        forvalues m = 1/`use_models' {
            if !missing(`stat_aic_`m'') local has_val = 1
        }
        if !`has_val' {
            forvalues m = 1/`use_models' {
                if !missing(`stat_qic_`m'') local has_val = 1
            }
            if `has_val' local _aic_label "QICu"
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = `"`_aic_label'"' in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if "`_aic_label'" == "AIC" {
                    if !missing(`stat_aic_`m'') {
                        local col = (`m' - 1) * 3 + 1
                        replace c`col' = string(`stat_aic_`m'', "%12.2f") in `=`curr_n'+1'
                    }
                }
                else {
                    if !missing(`stat_qic_`m'') {
                        local col = (`m' - 1) * 3 + 1
                        replace c`col' = string(`stat_qic_`m'', "%12.2f") in `=`curr_n'+1'
                    }
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            if "`_aic_label'" == "QICu" local _qicu_rendered_by_aic 1
        }
    }

    * Add QICu row (explicit stats(qic) request — for GEE/xtgee models)
    if `want_qic' == 1 & !`_qicu_rendered_by_aic' {
        local has_val = 0
        forvalues m = 1/`use_models' {
            if !missing(`stat_qic_`m'') local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = "QICu" in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if !missing(`stat_qic_`m'') {
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
            if !missing(`stat_bic_`m'') local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = "BIC" in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if !missing(`stat_bic_`m'') {
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
            if !missing(`stat_ll_`m'') local has_val = 1
        }
        if `has_val' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = "Log-likelihood" in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if !missing(`stat_ll_`m'') {
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
            if !missing(`stat_icc_`m'') local has_icc = 1
        }
        if `has_icc' {
            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = "ICC" in `=`curr_n'+1'
            forvalues m = 1/`use_icc_models' {
                if !missing(`stat_icc_`m'') {
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
            if !missing(`stat_r2_`m'') | !missing(`stat_r2_p_`m'') | !missing(`stat_r2_a_`m'') {
                local has_r2 = 1
            }
        }
        if `has_r2' {
            * Use a generic label when regular and pseudo-R² metrics are mixed.
            local r2_label "R²"
            local _any_r2 = 0
            local _any_pseudo_r2 = 0
            forvalues m = 1/`use_models' {
                if !missing(`stat_r2_`m'') local _any_r2 = 1
                if !missing(`stat_r2_p_`m'') local _any_pseudo_r2 = 1
            }
            if !`_any_r2' & `_any_pseudo_r2' local r2_label "Pseudo R²"
            else if `_any_r2' & `_any_pseudo_r2' local r2_label "R² / Pseudo R²"

            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = `"`r2_label'"' in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                local _r2val = .
                if !missing(`stat_r2_`m'') local _r2val = `stat_r2_`m''
                else if !missing(`stat_r2_p_`m'') local _r2val = `stat_r2_p_`m''
                else if !missing(`stat_r2_a_`m'') local _r2val = `stat_r2_a_`m''
                if !missing(`_r2val') {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = string(`_r2val', "%5.3f") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
        }
    }

    foreach _nt in r2_a rmse F fmi {
        if `want_`_nt'' != 1 continue
        local has_val = 0
        forvalues m = 1/`use_models' {
            if !missing(`stat_`_nt'_`m'') local has_val = 1
        }
        if !`has_val' continue
        local curr_n = _N
        set obs `=`curr_n'+1'
        replace A = `"`_nr_lab_`_nt''"' in `=`curr_n'+1'
        forvalues m = 1/`use_models' {
            if !missing(`stat_`_nt'_`m'') {
                local col = (`m' - 1) * 3 + 1
                replace c`col' = string(`stat_`_nt'_`m'', "`_nr_fmt_`_nt''") in `=`curr_n'+1'
            }
        }
        local stats_rows = "`stats_rows' `=`curr_n'+1'"
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
        replace A = `"`_ar_label'"' in `=`curr_n'+1'

        * Positionally assign values to model estimate columns
        local _ar_m = 0
        local _ar_vals = strtrim(`"`_ar_vals'"')
        while `"`_ar_vals'"' != "" {
            gettoken _ar_v _ar_vals : _ar_vals
            local _ar_m = `_ar_m' + 1
            local col = (`_ar_m' - 1) * 3 + 1
            if `col' <= `n' {
                replace c`col' = `"`_ar_v'"' in `=`curr_n'+1'
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
replace id = 0 if missing(id)
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
        * strtrim: with no CI header to append this leaves a trailing space in
        * the stored cell ("Compact "), which reaches the CSV and the workbook.
        qui replace c`m' = strtrim(`"`_hdr_est' `_hdr_ci'"') in 2
    }

    * Drop CI columns (c2, c5, c8, ...)
    local _drop_cols ""
    forvalues m = 2(3)`n' {
        local _drop_cols `"`_drop_cols' c`m'"'
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
            local _drop_cols `"`_drop_cols' c`m'"'
        }
    }
    else {
        forvalues m = 3(3)`n' {
            local _drop_cols `"`_drop_cols' c`m'"'
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
    * HR headers come from stcox and from the hazard metric of streg,
    * mestreg, and mecloglog; only the first is a Cox model.
    local _methods_coef "Hazard ratios"
    local _methods_model "Cox proportional hazards regression"
    if `_meta_models' > 0 {
        gettoken _methods_word : model_cmdline_1
        if inlist("`_methods_word'", "streg", "mestreg") {
            local _methods_model "parametric proportional hazards survival regression"
        }
        else if "`_methods_word'" == "mecloglog" {
            local _methods_model "mixed-effects complementary log-log regression"
        }
    }
}
else if "`coef'" == "TR" {
    local _methods_coef "Time ratios"
    local _methods_model "accelerated failure-time survival regression"
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
    local _methods_coef `"`coef'"'
    local _methods_model "regression"
}
if `n_models' > 1 local _methods_multi " across `n_models' models"
else local _methods_multi ""
* With per-model metadata the sentence names what each model is: the estimate
* scale the model reports (not a coef()/cdisc relabel of the header), the
* model built from its command, family, link, metric, and prefixes, and
* "univariable" or "multivariable" from the number of predictor variables in
* the collected coefficients (a factor variable counts once). The header-based
* sentence above remains the fallback for a collection without metadata.
if !`_model_headers_mixed' & `_meta_models' > 0 {
    local _mc `"`model_coef_1'"'
    if "`_mc'" == "OR" local _methods_coef "Odds ratios"
    else if "`_mc'" == "HR" local _methods_coef "Hazard ratios"
    else if "`_mc'" == "TR" local _methods_coef "Time ratios"
    else if "`_mc'" == "IRR" local _methods_coef "Incidence rate ratios"
    else if "`_mc'" == "RRR" local _methods_coef "Relative risk ratios"
    else if "`_mc'" == "SHR" local _methods_coef "Subhazard ratios"
    else if "`_mc'" == "RR" local _methods_coef "Risk ratios"
    else if "`_mc'" == "exp(b)" local _methods_coef "Exponentiated coefficients"
    else if "`_mc'" == "Coef." local _methods_coef "Coefficients"
    local _mnouns ""
    local _mn_n = 0
    local _madjs ""
    forvalues m = 1/`_meta_models' {
        _regtab_modelnoun "`model_cmdword_`m''" `"`model_optstr_`m''"' ///
            "`model_coef_`m''" "`model_prefix_`m''"
        local _seen = 0
        forvalues _j = 1/`_mn_n' {
            if `"`_mnoun_`_j''"' == `"`_mnoun'"' local _seen = 1
        }
        if !`_seen' {
            local ++_mn_n
            local _mnoun_`_mn_n' `"`_mnoun'"'
        }
        local _npred = 0
        if `m' <= `_sm_n' local _npred : word count `_sm_pred_`m''
        if `_npred' == 1 local _madjs "`_madjs' univariable"
        else if `_npred' > 1 local _madjs "`_madjs' multivariable"
    }
    local _madjs : list uniq _madjs
    local _madj ""
    local _na : word count `_madjs'
    if `_na' == 1 local _madj "`_madjs' "
    else if `_na' == 2 local _madj "univariable and multivariable "
    local _methods_model `"`_mnoun_1'"'
    forvalues _j = 2/`_mn_n' {
        if `_j' < `_mn_n' local _methods_model `"`_methods_model', `_mnoun_`_j''"'
        else if `_mn_n' == 2 local _methods_model `"`_methods_model' and `_mnoun_`_j''"'
        else local _methods_model `"`_methods_model', and `_mnoun_`_j''"'
    }
    local _methods "`_methods_coef' with `_ci_level'% confidence intervals from `_madj'`_methods_model'`_methods_multi'."
}
if "`_methods'" == "" local _methods "`_methods_coef' with `_ci_level'% confidence intervals from multivariable `_methods_model'`_methods_multi'."
if "`stars'" != "" local _methods "`_methods' Statistical significance denoted as * p<`_sl1', ** p<`_sl2', *** p<`_sl3'."
local _methods "`_methods' Analysis performed in Stata `c(stata_version)' (StataCorp, College Station, TX)."

* Return statistics before any file-writing failure can abort the command
if `_mat_nrows' > 0 {
    return matrix table = `_rtable'
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
        if `want_aic' & !missing(`stat_aic_`m'')          return scalar aic_`m'    = `stat_aic_`m''
        if `want_bic' & !missing(`stat_bic_`m'')          return scalar bic_`m'    = `stat_bic_`m''
        if (`want_qic' | `want_aic') & !missing(`stat_qic_`m'') return scalar qic_`m' = `stat_qic_`m''
        if `want_ll'  & !missing(`stat_ll_`m'')           return scalar ll_`m'     = `stat_ll_`m''
        if `want_n'   & !missing(`stat_N_`m'')            return scalar n_`m'      = `stat_N_`m''
        if `want_groups' & !missing(`stat_groups_`m'')    return scalar groups_`m' = `stat_groups_`m''
        foreach _nt in events mi_m r2_a rmse F fmi {
            if `want_`_nt'' & !missing(`stat_`_nt'_`m'') return scalar `_nt'_`m' = `stat_`_nt'_`m''
        }
    }
    if `want_icc' {
        local _ret_icc_models = min(`n_icc_models', `n_models')
        forvalues m = 1/`_ret_icc_models' {
            if !missing(`stat_icc_`m'')              return scalar icc_`m'    = `stat_icc_`m''
        }
    }
}

if `_has_xlsx' {
    capture noisily _tabtools_xlsx_write using "`xlsx'", sheet("`sheet'") book(`_xlsx_book')
    if _rc {
        local _export_rc = _rc
        noisily display as error "Failed to export to `xlsx', sheet `sheet'"
        noisily display as error "Check file permissions and that file is not open in Excel"
        capture erase "`temp_xlsx'"
        restore
        error `_export_rc'
    }
}

* Column widths come from the shared _tabtools_colwidth helper, PER MODEL,
* from that model's own rendered cells (rows 3+). A single max shared across
* models sized every model's estimate/CI/p column to the widest model, so one
* model with large coefficients (or a long CI string) padded every other
* model's columns out to match it. The console table already sizes each column
* independently; this makes the xlsx agree.
*
* The estimate width ignores the reference/omitted/empty labels: they can
* safely overflow into the adjacent blank cells, while numeric cells should
* stay visually tight. Widths are calibrated to Stata's Excel writer, which
* lands about 0.7 wider than the input width when read back from xlsx
* metadata, hence scale(1) pad(-0.5).
local _p_offset = `_cols_per_model' - 1
local _est_min = cond("`compact'" != "", 10, 7)
forvalues _mw = 1/`n_models' {
    local _c_first = (`_mw' - 1) * `_cols_per_model' + 1

    local _est_width_`_mw' = `_est_min'
    local _m_hdr_len = 0
    capture confirm variable c`_c_first'
    if !_rc {
        _tabtools_colwidth c`_c_first', scale(1) pad(-0.5) minwidth(`_est_min') ///
            headerrow(2) exclude(`"`refcat'"' `"`omitlabel'"' `"`emptylabel'"')
        local _est_width_`_mw' = r(width)
        local _m_hdr_len = r(hlen)
    }

    local _ci_width_`_mw' = 0
    if "`compact'" == "" {
        local _ci_width_`_mw' = 10
        local _c_ci = `_c_first' + 1
        capture confirm variable c`_c_ci'
        if !_rc {
            _tabtools_colwidth c`_c_ci', scale(1) pad(-0.5) minwidth(10)
            local _ci_width_`_mw' = r(width)
        }
    }

    local _p_width_`_mw' = 0
    if `_show_pvalues' {
        local _p_width_`_mw' = 7
        local _c_p = `_c_first' + `_p_offset'
        capture confirm variable c`_c_p'
        if !_rc {
            _tabtools_colwidth c`_c_p', scale(1) pad(-0.5) minwidth(7)
            local _p_width_`_mw' = r(width)
        }
    }

    * Model label sits in row 2, merged across this model's own block, so the
    * wrap depth is set by the block it lives in -- not by the widest block.
    local _m_block_width = `_est_width_`_mw'' + `_ci_width_`_mw'' + `_p_width_`_mw''
    _tabtools_colwidth, hlength(`_m_hdr_len') blockwidth(`_m_block_width')
    local _hdr_lines_`_mw' = r(hlines)
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

drop A_length factor_length

* Reference rows are tracked PER MODEL. A union across models would let one
* model's reference row merge and blank the estimate/CI/p triplet of a
* different model that has a real result on that row.
local _ref_model_ix = 0
forvalues i = 1(`_cols_per_model')`last'{
local _ref_model_ix = `_ref_model_ix' + 1
gen ref`i' = _n if inlist(c`i', `"`refcat'"', `"`omitlabel'"', `"`emptylabel'"')
order ref`i', after(c`i')
levelsof ref`i', local(_ref_rows_`_ref_model_ix')
}

* CSV export (F2) — must happen before clear
if "`csv'" != "" {
    _tabtools_csv_write using "`csv'", labelvar(A) reservedrow ///
        title(`"`title'"') footnote(`"`footnote'"')
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
	* GFM allows exactly one header row, but this table has two semantic header
	* levels: row 2 carries the model names (only in each model's first column,
	* the rest being covered by a merged range in Excel) and row 3 carries the
	* statistic labels. Writing row 2 alone dropped every statistic label into
	* the body and lost the model identity of columns 2 and 3 of each model.
	* Flatten both levels into row 3 -- "Model A: 95% CI" -- and start the body
	* at row 4. Snapshot first: the flatten must not reach frame() or r(table).
	tempfile _md_snapshot
	quietly save `"`_md_snapshot'"', replace
	if _N >= 3 {
		forvalues _mdc = 1/`n_models' {
			local _md_first = (`_mdc' - 1) * `_cols_per_model' + 1
			local _md_name = strtrim(c`_md_first'[2])
			if `"`_md_name'"' != "" {
				forvalues _md_off = 0/`=`_cols_per_model' - 1' {
					local _md_col = `_md_first' + `_md_off'
					capture confirm variable c`_md_col'
					if !_rc {
						quietly replace c`_md_col' = ///
							`"`_md_name': "' + strtrim(c`_md_col') ///
							in 3 if strtrim(c`_md_col') != ""
						quietly replace c`_md_col' = `"`_md_name'"' ///
							in 3 if strtrim(c`_md_col') == ""
					}
				}
			}
		}
	}
	capture noisily _tabtools_markdown_write using `"`markdown'"', ///
		`_mdappend_opt' labelvar(A) title(`"`title'"') footnote(`"`footnote'"') ///
		headerstart(3) datastart(4) strictheaders
	if _rc {
		local _md_rc = _rc
		noisily display as error "Failed to export Markdown to `markdown'"
		restore
		exit `_md_rc'
	}
	local _ret_markdown `"`markdown'"'
	local _ret_markdown_rows = r(n_rows)
	local _ret_markdown_cols = r(n_cols)
	quietly use `"`_md_snapshot'"', clear
	noisily display as text "Markdown exported to `markdown'"
}

* Store output in frame if requested
	if `"`frame'"' != "" {
		_tabtools_frame_put `"`frame'"'
		local frame `"`_frame_name'"'
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
	* Punctuation-aware join: a user footnote that already ends in terminal
	* punctuation must not gain a ";" after it (".;" was shipped in the regtab
	* and other table demo workbooks).
	if `"`_fn_text'"' != "" {
		local _fn_trim = strtrim(`"`_fn_text'"')
		local _fn_last = substr(`"`_fn_trim'"', -1, 1)
		if inlist(`"`_fn_last'"', ".", ";", ":", "!", "?") ///
			local _fn_text `"`_fn_trim' `_stars_note'"'
		else local _fn_text `"`_fn_trim'; `_stars_note'"'
	}
	else local _fn_text `"`_stars_note'"'
}

* Prepare p-value/nonsig data vectors for Mata
local _n_bp_entries 0
if `has_boldp' | `has_highlight' {
	forvalues _m = 1/`n_models' {
		forvalues _dr = 4/`num_rows' {
			local _pstr `"`_bp_m`_m'_r`_dr''"'
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
	local headerheight = 1
	forvalues _mc = 1/`n_models' {
		local _c_first = (`_mc' - 1) * `_cols_per_model' + 1
		local _x_first = `_c_first' + 2
		local _style_rule_rows `"`_style_rule_rows' | 13 1 1 `_x_first' `_x_first' `_est_width_`_mc'' 0 0 0"'
		if "`compact'" == "" {
			local _x_ci = `_x_first' + 1
			local _style_rule_rows `"`_style_rule_rows' | 13 1 1 `_x_ci' `_x_ci' `_ci_width_`_mc'' 0 0 0"'
		}
		if `_show_pvalues' {
			local _x_p = `_x_first' + `_cols_per_model' - 1
			local _style_rule_rows `"`_style_rule_rows' | 13 1 1 `_x_p' `_x_p' `_p_width_`_mc'' 0 0 0"'
		}
		if `_hdr_lines_`_mc'' > `headerheight' local headerheight = `_hdr_lines_`_mc''
	}
	if `headerheight' > 1 {
		local _style_rule_rows `"`_style_rule_rows' | 12 2 2 1 1 `=`headerheight'*15' 0 0 0"'
	}

	* Wrap the label column -- and only the label column -- so labels longer
	* than the capped width (e.g. a verbose random-effects covariance row) flow
	* onto extra lines instead of being clipped by the adjacent estimate cell.
	* Estimate cells are pre-formatted to a known width and must not wrap.
	* Top-align across the whole row, not just the label: with the rule on
	* column B alone, C..N kept Excel's default bottom alignment, so the stated
	* intent -- the label's first line level with the single-line estimate
	* cells -- failed on every single-line row.
	if `num_rows' >= 4 {
		local _style_rule_rows `"`_style_rule_rows' | 4 4 `num_rows' 2 2 0 1 0 0 | 6 4 `num_rows' 2 `num_cols' 0 3 0 0"'
	}

	local _style_rule_rows `"`_style_rule_rows' | 1 1 `num_rows' 1 `num_cols' `_fontsize' 1 0 0 | 1 1 1 1 `num_cols' `=`_fontsize'+2' 1 0 0 | 14 1 1 1 `num_cols' 0 0 0 0 | 4 1 1 1 1 0 1 0 0 | 5 1 1 1 1 0 1 0 0 | 6 1 1 1 1 0 2 0 0 | 2 1 1 1 1 0 1 0 0"'
	if "`headershade'" != "" {
		local _style_rule_rows `"`_style_rule_rows' | 7 2 3 2 `num_cols' 0 -1 0 0"'
	}
	local _style_rule_rows `"`_style_rule_rows' | 2 3 3 2 `num_cols' 0 1 0 0 | 5 3 3 2 `num_cols' 0 2 0 0 | 6 3 3 2 `num_cols' 0 2 0 0"'

	* Merge the estimate/CI/p triplet only for the model that actually holds a
	* reference label on that row. Merging on the union of reference rows
	* across models destroys the CI and p-value of any model with a real
	* result on a row some OTHER model treats as its reference.
	forvalues _mc = 1/`n_models' {
		local _col_start = 2 + (`_mc' - 1) * `_cols_per_model' + 1
		local _col_end = `_col_start' + `_cols_per_model' - 1
		foreach row of local _ref_rows_`_mc' {
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
		mata: `_xlsx_book'.put_string(`_fn_row', 2, `"`_fn_text'"')
		local _style_rule_rows `"`_style_rule_rows' | 14 `_fn_row' `_fn_row' 2 `num_cols' 0 0 0 0 | 5 `_fn_row' `_fn_row' 2 2 0 1 0 0 | 6 `_fn_row' `_fn_row' 2 2 0 2 0 0 | 4 `_fn_row' `_fn_row' 2 2 0 1 0 0 | 1 `_fn_row' `_fn_row' 2 2 `_fn_fontsize' 1 0 0 | 3 `_fn_row' `_fn_row' 2 2 0 1 0 0"'
	}

	_tabtools_xlsx_build_styles, matrix(`_style_rules') ///
		rules(`"`_style_rule_rows'"') cols(9)
	_tabtools_xlsx_apply_styles, book(`_xlsx_book') sheet("`sheet'") ///
		rules(`_style_rules') font("`_font'") ///
		color1("`_headercolor'") color2("`_zebracolor'") ///
		color3("255 255 204")
	mata: `_xlsx_book'.close_book()

	* xl() appends a style record for every styled cell instead of
	* reusing one per distinct format, so collapse the pools here;
	* a workbook that keeps growing would otherwise reach Stata's
	* 65,536-record ceiling and fail with r(16147).
	_tabtools_xlsx_compact_styles using "`xlsx'"
}
if _rc {
	local saved_rc = _rc
	capture mata: `_xlsx_book'.close_book()
	capture mata: mata drop `_xlsx_book'
	noisily display as error "Excel formatting failed with error `saved_rc'"
	capture erase "`temp_xlsx'"
	restore
	error `saved_rc'
}
capture mata: mata drop `_xlsx_book'

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
	local frame `"`_displayframe_target'"'
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

* =============================================================================
* _regtab_modelnoun: the model named in the methods sentence
* =============================================================================
* Usage: _regtab_modelnoun "<command word>" `"<option text>"' "<scale>" "<prefixes>"
* Returns _mnoun in the caller, built from the estimation command, glm/xtgee
* family and link, the survival metric (the scale header: HR or TR), and the
* estimation prefixes; never from a coef() or cdisc relabel.
capture program drop _regtab_modelnoun
program define _regtab_modelnoun, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		gettoken _w 0 : 0
		gettoken _o 0 : 0
		gettoken _sc 0 : 0
		gettoken _pf 0 : 0
		local _w = lower(`"`_w'"')
		local _n ""
		local _me ""
		if inlist("`_w'", "melogit", "meprobit", "mecloglog", "mepoisson", "menbreg", ///
			"meologit", "meoprobit", "mestreg", "meglm") | ///
			inlist("`_w'", "meintreg", "metobit", "meqrlogit", "meqrpoisson") {
			local _me "mixed-effects "
			local _w = substr("`_w'", 3, .)
		}
		if inlist("`_w'", "glm", "xtgee") {
			_regtab_cmdopts "Family(string) Link(string)" `"`_o'"'
			gettoken _fam : _ro_family
			gettoken _lnk : _ro_link
			local _fam = lower(`"`_fam'"')
			local _lnk = lower(`"`_lnk'"')
			local _fl = strlen(`"`_fam'"')
			local _ll = strlen(`"`_lnk'"')
			local _f "other"
			if `_fl' == 0 local _f "gaussian"
			else if `"`_fam'"' == substr("gaussian", 1, max(`_fl', 3)) | ///
				`"`_fam'"' == substr("normal", 1, `_fl') local _f "gaussian"
			else if `"`_fam'"' == substr("igaussian", 1, max(`_fl', 2)) local _f "igaussian"
			else if `"`_fam'"' == substr("binomial", 1, `_fl') | ///
				`"`_fam'"' == substr("bernoulli", 1, `_fl') local _f "binomial"
			else if `"`_fam'"' == substr("poisson", 1, `_fl') local _f "poisson"
			else if `"`_fam'"' == substr("nbinomial", 1, max(2, `_fl')) local _f "nbinomial"
			else if `"`_fam'"' == substr("gamma", 1, max(3, `_fl')) local _f "gamma"
			local _l "other"
			if `_ll' == 0 {
				if "`_f'" == "binomial" local _l "logit"
				else if inlist("`_f'", "poisson", "nbinomial") local _l "log"
				else if "`_f'" == "gaussian" local _l "identity"
				else if "`_f'" == "gamma" local _l "reciprocal"
			}
			else if `"`_lnk'"' == substr("identity", 1, `_ll') local _l "identity"
			else if `"`_lnk'"' == "log" local _l "log"
			else if `"`_lnk'"' == substr("logit", 1, `_ll') local _l "logit"
			else if `"`_lnk'"' == substr("probit", 1, `_ll') local _l "probit"
			else if `"`_lnk'"' == substr("cloglog", 1, `_ll') local _l "cloglog"
			else if `"`_lnk'"' == substr("reciprocal", 1, `_ll') local _l "reciprocal"
			if "`_f'" == "binomial" & "`_l'" == "logit" local _n "logistic regression"
			else if "`_f'" == "binomial" & "`_l'" == "probit" local _n "probit regression"
			else if "`_f'" == "binomial" & "`_l'" == "cloglog" local _n "complementary log-log regression"
			else if "`_f'" == "binomial" & "`_l'" == "log" local _n "log-binomial regression"
			else if "`_f'" == "poisson" & "`_l'" == "log" local _n "Poisson regression"
			else if "`_f'" == "nbinomial" & "`_l'" == "log" local _n "negative binomial regression"
			else if "`_f'" == "gaussian" & "`_l'" == "identity" local _n "linear regression"
			else if "`_f'" == "gamma" & "`_l'" == "log" local _n "gamma regression with a log link"
			else {
				local _fn = cond("`_f'" == "other", `"`_fam'"', "`_f'")
				local _lnn = cond("`_l'" == "other", `"`_lnk'"', "`_l'")
				local _n "generalized linear model (`_fn' family, `_lnn' link)"
			}
			if "`_w'" == "xtgee" local _n "generalized estimating equation (GEE) `_n'"
		}
		else if inlist("`_w'", "logit", "logistic", "qrlogit") local _n "logistic regression"
		else if "`_w'" == "probit" local _n "probit regression"
		else if "`_w'" == "cloglog" local _n "complementary log-log regression"
		else if inlist("`_w'", "poisson", "qrpoisson") local _n "Poisson regression"
		else if "`_w'" == "nbreg" local _n "negative binomial regression"
		else if "`_w'" == "gnbreg" local _n "generalized negative binomial regression"
		else if "`_w'" == "zip" local _n "zero-inflated Poisson regression"
		else if "`_w'" == "zinb" local _n "zero-inflated negative binomial regression"
		else if "`_w'" == "regress" local _n "linear regression"
		else if "`_w'" == "ologit" local _n "ordered logistic regression"
		else if "`_w'" == "oprobit" local _n "ordered probit regression"
		else if "`_w'" == "mlogit" local _n "multinomial logistic regression"
		else if "`_w'" == "mprobit" local _n "multinomial probit regression"
		else if "`_w'" == "stcox" local _n "Cox proportional hazards regression"
		else if "`_w'" == "streg" {
			if "`_sc'" == "HR" local _n "parametric proportional hazards survival regression"
			else local _n "accelerated failure-time survival regression"
		}
		else if inlist("`_w'", "stcrreg", "finegray") local _n "Fine-Gray competing-risks regression"
		else if "`_w'" == "mixed" local _n "linear mixed-effects regression"
		else if "`_w'" == "tobit" local _n "tobit regression"
		else if "`_w'" == "intreg" local _n "interval regression"
		else if "`_w'" == "xtreg" local _n "linear panel-data regression"
		else if "`_w'" == "xtlogit" local _n "panel-data logistic regression"
		else if "`_w'" == "xtpoisson" local _n "panel-data Poisson regression"
		else if "`_w'" == "churdle" local _n "Cragg hurdle regression"
		else local _n "regression"
		local _n "`_me'`_n'"
		if strpos(" `_pf' ", " svy ") local _n "survey-weighted `_n'"
		if strpos(" `_pf' ", " mi ") local _n "`_n' with multiple imputation"
		if strpos(" `_pf' ", " bootstrap ") local _n "`_n' with bootstrap standard errors"
		if strpos(" `_pf' ", " jackknife ") local _n "`_n' with jackknife standard errors"
		c_local _mnoun `"`_n'"'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* =============================================================================
* _regtab_fvparent: factor parent of a raw colname key
* =============================================================================
* Mirrors the renderer's _tt_collect_factor_parent: "2.sex" -> "sex",
* "1.grp#c.x" -> "grp#x". No factor component, or a level that is its own
* parent, returns an empty _fp_parent in the caller.
capture program drop _regtab_fvparent
program define _regtab_fvparent, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		gettoken _fp_key 0 : 0
		local _fp_this ""
		if strpos(`"`_fp_key'"', ".") > 0 {
			local _fp_hasfv 0
			local _fp_bad 0
			local _fp_parts = subinstr(`"`_fp_key'"', "#", " ", .)
			local _fp_i 0
			foreach _fp_p of local _fp_parts {
				local ++_fp_i
				local _fp_dot = strpos(`"`_fp_p'"', ".")
				if `_fp_dot' > 1 & ///
					regexm(substr(`"`_fp_p'"', 1, `_fp_dot' - 1), "^[0-9bon]*[0-9][0-9bon]*$") {
					local _fp_p = substr(`"`_fp_p'"', `_fp_dot' + 1, .)
					local _fp_hasfv 1
				}
				else if `_fp_dot' == 2 & substr(`"`_fp_p'"', 1, 1) == "c" {
					local _fp_p = substr(`"`_fp_p'"', 3, .)
				}
				if `"`_fp_p'"' == "" local _fp_bad 1
				if `_fp_i' == 1 local _fp_this `"`_fp_p'"'
				else local _fp_this `"`_fp_this'#`_fp_p'"'
			}
			if `_fp_bad' | !`_fp_hasfv' | `"`_fp_this'"' == `"`_fp_key'"' local _fp_this ""
		}
		c_local _fp_parent `"`_fp_this'"'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* =============================================================================
* _regtab_eqkeys: equation key of every row of a coleq#colname rendering
* =============================================================================
* The renderer marks an equation's header row with an empty raw key and prints
* its label; headers appear in the order of the coleq levels, one per level
* with data. Walking that order maps each header back to its level (so a
* dependent variable labelled "/" is never read as the ancillary equation),
* and every row below it inherits the level in _eq_key.
capture program drop _regtab_eqkeys
program define _regtab_eqkeys, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		* Same level order and labels as the renderer's dimension helper:
		* collect's level order, purely numeric levels sorted numerically,
		* the .m total level last, and a level's label defaulting to itself.
		quietly collect levelsof coleq
		local _levels `"`s(levels)'"'
		local _ord ""
		local _tot ""
		local _allnum = 1
		foreach _lev of local _levels {
			if "`_lev'" == ".m" local _tot "`_tot' `_lev'"
			else {
				local _ord "`_ord' `_lev'"
				if missing(real("`_lev'")) local _allnum = 0
			}
		}
		if `_allnum' & "`_ord'" != "" {
			local _nn : word count `_ord'
			tempname _lm
			matrix `_lm' = J(`_nn', 1, .)
			forvalues _i = 1/`_nn' {
				local _lev : word `_i' of `_ord'
				matrix `_lm'[`_i', 1] = real("`_lev'")
			}
			mata: st_matrix("`_lm'", sort(st_matrix("`_lm'"), 1))
			local _ord ""
			forvalues _i = 1/`_nn' {
				local _ord "`_ord' `=`_lm'[`_i', 1]'"
			}
		}
		local _levels = strtrim("`_ord' `_tot'")
		local _lk = 0
		capture quietly collect label list coleq
		if _rc == 0 {
			local _lk = real("`s(k)'")
			if missing(`_lk') local _lk = 0
			forvalues _i = 1/`_lk' {
				local _mlev_`_i' `"`s(level`_i')'"'
				local _mlab_`_i' `"`s(label`_i')'"'
			}
		}
		local _en : word count `_levels'
		forvalues _e = 1/`_en' {
			local _elev_`_e' : word `_e' of `_levels'
			local _elab_`_e' `"`_elev_`_e''"'
			forvalues _i = 1/`_lk' {
				if `"`_mlev_`_i''"' == `"`_elev_`_e''"' local _elab_`_e' `"`_mlab_`_i''"'
			}
			local _elab_`_e' = strtrim(`"`_elab_`_e''"')
		}
		quietly generate strL _eq_key = ""
		local _ep = 0
		local _cur ""
		forvalues _r = 3/`=_N' {
			if strtrim(_raw_colname[`_r']) == "" {
				local _hl = strtrim(A[`_r'])
				local _found = 0
				forvalues _e = `=`_ep'+1'/`_en' {
					if `"`_elab_`_e''"' == `"`_hl'"' {
						local _ep = `_e'
						local _cur `"`_elev_`_e''"'
						local _found = 1
						continue, break
					}
				}
				if !`_found' {
					display as error `"equation header "`_hl'" does not match a collected equation"'
					exit 459
				}
			}
			quietly replace _eq_key = `"`_cur'"' in `_r'
		}
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* =============================================================================
* _regtab_role: structural role of one collected coefficient
* =============================================================================
* Usage: _regtab_role "<coleq level>" "<colname level>"
* Returns _role in the caller: cons (_cons in any equation), re (a random-
* effects parameter), cut (cut# in the ancillary equation), anc (any other
* parameter of the "/" or _diparm# equations), scale (a coefficient of an
* lnsigma scale equation), or reg (an ordinary coefficient).
capture program drop _regtab_role
program define _regtab_role, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		gettoken _rr_eq 0 : 0
		gettoken _rr_key 0 : 0
		local _rr_anceq = (`"`_rr_eq'"' == "/" | regexm(`"`_rr_eq'"', "^_diparm"))
		if `"`_rr_key'"' == "_cons" local _rr "cons"
		else if ustrregexm(`"`_rr_key'"', "^(var|cov|sd|corr)\(") local _rr "re"
		else if `_rr_anceq' & regexm(`"`_rr_key'"', "^cut[0-9]+$") local _rr "cut"
		else if `_rr_anceq' local _rr "anc"
		else if lower(`"`_rr_eq'"') == "lnsigma" local _rr "scale"
		else local _rr "reg"
		c_local _role "`_rr'"
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* =============================================================================
* _regtab_optstr: display-option text of a collected command line
* =============================================================================
* Returns, in the caller's local <target>, the text after the option comma of
* every ||-separated equation. A comma or || inside parentheses or a quoted
* string is not a separator, so a comma in an if() expression cannot start the
* option list, and nothing before the option comma (a covariate literally
* named "or", say) is ever read as an option.
* Estimation prefixes ("svy [vcetype][, opts]:", "bootstrap|bs|bstrap
* [, opts]:", "jackknife|jknife [, opts]:", "mi estimate [, opts]:", nested
* in any order, as e(cmdline) and e(cmdline_mi) record them) are set aside
* first: <target>_line receives the command line after the last prefix colon
* (a colon outside parentheses and quotes), so the caller classifies the
* estimation command and a prefix's options are never read as the command's
* display options. <target>_prefix lists the prefixes found (svy, bootstrap,
* jackknife, mi), and <target>_prefopt holds the option text of the
* bootstrap, jackknife, and mi estimate prefixes (svy's options are not
* display options and are not returned). Any other command line is returned
* unchanged in <target>_line with empty prefix locals.
capture program drop _regtab_optstr
program define _regtab_optstr, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		gettoken _ro_target 0 : 0
		gettoken _ro_str 0 : 0
		local _ro_prefix ""
		local _ro_prefopt ""
		local _ro_more 1
		while `_ro_more' {
			local _ro_more 0
			local _ro_str = strtrim(`"`_ro_str'"')
			local _ro_lc = lower(`"`_ro_str'"')
			local _ro_pname ""
			if regexm(`"`_ro_lc'"', "^svy([ ,:]|$)") local _ro_pname "svy"
			else if regexm(`"`_ro_lc'"', "^(bootstrap|bstrap|bs)([ ,:]|$)") local _ro_pname "bootstrap"
			else if regexm(`"`_ro_lc'"', "^(jackknife|jknife)([ ,:]|$)") local _ro_pname "jackknife"
			else if regexm(`"`_ro_lc'"', "^mi +est(i|im|ima|imat|imate)?([ ,:]|$)") local _ro_pname "mi"
			if "`_ro_pname'" == "" continue, break
			local _ro_len = strlen(`"`_ro_str'"')
			local _ro_depth 0
			local _ro_inq 0
			local _ro_comma 0
			local _ro_i 1
			while `_ro_i' <= `_ro_len' {
				* 1 quote, 2 (, 3 ), 4 colon, 5 comma, 0 anything else
				local _ro_k = strpos(char(34) + "():,", ///
					substr(`"`_ro_str'"', `_ro_i', 1))
				if `_ro_inq' {
					if `_ro_k' == 1 local _ro_inq 0
				}
				else if `_ro_k' == 1 local _ro_inq 1
				else if `_ro_k' == 2 local ++_ro_depth
				else if `_ro_k' == 3 & `_ro_depth' > 0 local --_ro_depth
				else if `_ro_k' == 5 & `_ro_depth' == 0 & !`_ro_comma' {
					local _ro_comma = `_ro_i'
				}
				else if `_ro_k' == 4 & `_ro_depth' == 0 {
					if "`_ro_pname'" != "svy" & `_ro_comma' > 0 {
						local _ro_prefopt = `"`_ro_prefopt' "' + ///
							substr(`"`_ro_str'"', `_ro_comma' + 1, `_ro_i' - `_ro_comma' - 1)
					}
					local _ro_prefix `"`_ro_prefix' `_ro_pname'"'
					local _ro_str = strtrim(substr(`"`_ro_str'"', `_ro_i' + 1, .))
					local _ro_more 1
					continue, break
				}
				local ++_ro_i
			}
		}
		c_local `_ro_target'_prefix = strtrim(`"`_ro_prefix'"')
		c_local `_ro_target'_prefopt = strtrim(`"`_ro_prefopt'"')
		c_local `_ro_target'_line `"`_ro_str'"'
		local _ro_len = strlen(`"`_ro_str'"')
		local _ro_depth 0
		local _ro_inq 0
		local _ro_inopt 0
		local _ro_start 0
		local _ro_out ""
		local _ro_i 1
		while `_ro_i' <= `_ro_len' {
			local _ro_step 1
			* Character class by position, so a quote character never has to
			* be held in a macro: 1 quote, 2 (, 3 ), 4 comma, 0 anything else.
			local _ro_k = strpos(char(34) + "(),", ///
				substr(`"`_ro_str'"', `_ro_i', 1))
			if `_ro_inq' {
				if `_ro_k' == 1 local _ro_inq 0
			}
			else if `_ro_k' == 1 local _ro_inq 1
			else if `_ro_k' == 2 local ++_ro_depth
			else if `_ro_k' == 3 & `_ro_depth' > 0 local --_ro_depth
			else if `_ro_depth' == 0 & substr(`"`_ro_str'"', `_ro_i', 2) == "||" {
				if `_ro_inopt' {
					local _ro_out = `"`_ro_out' "' + ///
						substr(`"`_ro_str'"', `_ro_start', `_ro_i' - `_ro_start')
				}
				local _ro_inopt 0
				local _ro_step 2
			}
			else if `_ro_depth' == 0 & !`_ro_inopt' & `_ro_k' == 4 {
				local _ro_inopt 1
				local _ro_start = `_ro_i' + 1
			}
			local _ro_i = `_ro_i' + `_ro_step'
		}
		if `_ro_inopt' {
			local _ro_out = `"`_ro_out' "' + substr(`"`_ro_str'"', `_ro_start', .)
		}
		local _ro_out = strtrim(`"`_ro_out'"')
		c_local `_ro_target' `"`_ro_out'"'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* =============================================================================
* _regtab_cmdopts: parse option text with the estimator's own abbreviations
* =============================================================================
* Usage: _regtab_cmdopts "<syntax option spec>" `"<option text>"'
* Runs -syntax- on the option text so abbreviations resolve exactly as the
* estimator resolves them (glm's EForm accepts ef/efo/efor/eform; Family() and
* Link() accept f()/l()). Every declared option is returned in the caller as
* local _ro_<name>, where <name> is the local -syntax- creates (noHR -> hr),
* empty when the option is absent or the text cannot be parsed.
capture program drop _regtab_cmdopts
program define _regtab_cmdopts, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		gettoken _ro_spec 0 : 0
		gettoken _ro_text 0 : 0
		local _ro_names ""
		foreach _ro_w of local _ro_spec {
			local _ro_nm = lower(regexr(`"`_ro_w'"', "\(.*$", ""))
			if substr(`"`_ro_w'"', 1, 2) == "no" & ///
				regexm(substr(`"`_ro_w'"', 3, 1), "[A-Z]") {
				local _ro_nm = substr(`"`_ro_nm'"', 3, .)
			}
			local _ro_names `_ro_names' `_ro_nm'
		}
		local 0 `", `_ro_text'"'
		capture syntax [, `_ro_spec' *]
		local _ro_ok = (_rc == 0)
		foreach _ro_nm of local _ro_names {
			if !`_ro_ok' local `_ro_nm' ""
			c_local _ro_`_ro_nm' `"``_ro_nm''"'
		}
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* =============================================================================
* _regtab_prefopts: display options given to an estimation prefix
* =============================================================================
* Usage: _regtab_prefopts `"<prefix option text>"'
* Returns in the caller _rp_eform (1 when the text carries an eform option:
* or, hr, shr, irr, rrr, tr, eform, or eform(string)) and _rp_level (the
* level() value, or -1). Text that -syntax- cannot parse returns 0 and -1.
capture program drop _regtab_prefopts
program define _regtab_prefopts, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		gettoken _rp_text 0 : 0
		local _rp_e 0
		local _rp_l = -1
		local 0 `", `_rp_text'"'
		capture syntax [, OR HR SHR IRR RRR TR EFORM Level(string) *]
		if _rc == 0 {
			if "`or'`hr'`shr'`irr'`rrr'`tr'`eform'" != "" local _rp_e 1
			if regexm(lower(`" `options'"'), "[ ]eform[(]") local _rp_e 1
			if `"`level'"' != "" {
				local _rp_l = real(`"`level'"')
				if missing(`_rp_l') local _rp_l = -1
			}
		}
		c_local _rp_eform `_rp_e'
		c_local _rp_level `_rp_l'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* =============================================================================
* _regtab_scale: display scale of one collected model
* =============================================================================
* Usage: _regtab_scale "<command word>" "<e(cmd)>" `"<option text>"'
* Returns in the caller:
*   _rs_coef   estimate header (OR, HR, IRR, RRR, SHR, TR, RR, exp(b), Coef.)
*   _rs_eform  1 when the collected values are coefficients that regtab must
*              exponentiate to reach _rs_coef
*   _rs_null   null value on the displayed scale (1 for ratios, 0 otherwise)
*   _rs_noint  1 when the intercept row is suppressed by default
*   _rs_known  1 when the command has a dedicated rule
*   _rs_level  confidence level requested with level(), or -1 when absent
* Ratio families are always shown on the ratio scale: a fit displayed on the
* coefficient scale (logit without or, stcox with nohr, logistic with coef,
* streg in the time metric without tr) is exponentiated, and a fit Stata
* already exponentiated (or, hr, tr, irr, eform) is left alone. The header
* therefore always names the scale of the numbers printed under it.
* Optional 4th and 5th arguments describe an estimation prefix: mode "mi"
* (mi estimate reports the coefficient metric whatever the command's own
* display options, unless mi estimate itself was given an eform option;
* [MI] mi estimate) or mode "or" (bootstrap/jackknife, whose eform option
* exponentiates as the command's own would), and whether the prefix carried
* an eform option (0/1).
capture program drop _regtab_scale
program define _regtab_scale, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		gettoken _rs_word 0 : 0
		gettoken _rs_ecmd 0 : 0
		gettoken _rs_opt 0 : 0
		gettoken _rs_pmode 0 : 0
		gettoken _rs_peform 0 : 0
		if "`_rs_peform'" == "" local _rs_peform 0
		local _rs_word = lower(`"`_rs_word'"')
		local _rs_ecmd = lower(`"`_rs_ecmd'"')

		local _c "Coef."
		local _e 0
		local _n 0
		local _i 0
		local _k 1

		if inlist("`_rs_word'", "logit", "ologit", "melogit") {
			_regtab_cmdopts "OR" `"`_rs_opt'"'
			local _c "OR"
			local _e = ("`_ro_or'" == "")
			local _n 1
			local _i 1
		}
		else if "`_rs_word'" == "logistic" {
			_regtab_cmdopts "COEF" `"`_rs_opt'"'
			local _c "OR"
			local _e = ("`_ro_coef'" != "")
			local _n 1
			local _i 1
		}
		else if inlist("`_rs_word'", "poisson", "nbreg", "mepoisson", "menbreg") {
			* poisson and nbreg accept ir; the mixed-effects forms need irr.
			local _spec "IRr"
			if inlist("`_rs_word'", "mepoisson", "menbreg") local _spec "IRR"
			_regtab_cmdopts "`_spec'" `"`_rs_opt'"'
			local _c "IRR"
			local _e = ("`_ro_irr'" == "")
			local _n 1
			local _i 1
		}
		else if "`_rs_word'" == "mlogit" {
			_regtab_cmdopts "RRr" `"`_rs_opt'"'
			local _c "RRR"
			local _e = ("`_ro_rrr'" == "")
			local _n 1
			local _i 1
		}
		else if inlist("`_rs_word'", "zip", "zinb", "churdle") {
			local _i 1
		}
		else if inlist("`_rs_word'", "finegray", "stcrreg") {
			_regtab_cmdopts "noSHR" `"`_rs_opt'"'
			local _c "SHR"
			local _e = ("`_ro_shr'" != "")
			local _n 1
			local _i 1
		}
		else if "`_rs_word'" == "stcox" | "`_rs_ecmd'" == "cox" {
			_regtab_cmdopts "noHR" `"`_rs_opt'"'
			local _c "HR"
			local _e = ("`_ro_hr'" != "")
			local _n 1
			local _i 1
		}
		else if inlist("`_rs_word'", "streg", "mestreg") {
			* Metric rules from streg.ado/mestreg.ado: exponential and Weibull
			* fit in the log-hazard metric unless time (or, for streg, tr) is
			* given; Gompertz is log-hazard only; lognormal, loglogistic and
			* (generalized) gamma are log-time only. The hazard metric displays
			* hazard ratios unless nohr; the time metric displays coefficients
			* unless tr.
			_regtab_cmdopts "TIme TRatio noHR Distribution(string)" `"`_rs_opt'"'
			local _aft_opt = ("`_ro_time'`_ro_tratio'" != "")
			if "`_rs_word'" == "mestreg" local _aft_opt = ("`_ro_time'" != "")
			local _ph_capable 0
			local _ph_only 0
			if "`_rs_word'" == "streg" {
				if regexm("`_rs_ecmd'", "^(ereg|weibull)") local _ph_capable 1
				if regexm("`_rs_ecmd'", "^gompertz") local _ph_only 1
			}
			else {
				gettoken _dist : _ro_distribution, parse(" ,")
				local _dist = lower(`"`_dist'"')
				local _dl = strlen(`"`_dist'"')
				if `_dl' > 0 {
					if `"`_dist'"' == substr("exponential", 1, `_dl') | ///
						`"`_dist'"' == substr("weibull", 1, `_dl') local _ph_capable 1
				}
			}
			local _hazard = `_ph_only' | (`_ph_capable' & !`_aft_opt')
			if `_hazard' {
				local _c "HR"
				local _e = ("`_ro_hr'" != "")
			}
			else {
				local _c "TR"
				local _e = ("`_ro_tratio'" == "")
			}
			local _n 1
			local _i 1
		}
		else if "`_rs_word'" == "mecloglog" {
			_regtab_cmdopts "EFORM" `"`_rs_opt'"'
			local _c "HR"
			local _e = ("`_ro_eform'" == "")
			local _n 1
			local _i 1
		}
		else if "`_rs_word'" == "glm" {
			* Family/link abbreviations follow glm.ado's MapFam and MapLink.
			_regtab_cmdopts "EForm Family(string) Link(string)" `"`_rs_opt'"'
			gettoken _fam : _ro_family
			gettoken _lnk : _ro_link
			local _fam = lower(`"`_fam'"')
			local _lnk = lower(`"`_lnk'"')
			local _fl = strlen(`"`_fam'"')
			local _ll = strlen(`"`_lnk'"')
			local _famc "other"
			if `_fl' == 0 local _famc "gaussian"
			else if `"`_fam'"' == substr("gaussian", 1, max(`_fl', 3)) | ///
				`"`_fam'"' == substr("normal", 1, `_fl') local _famc "gaussian"
			else if `"`_fam'"' == substr("binomial", 1, `_fl') | ///
				`"`_fam'"' == substr("bernoulli", 1, `_fl') local _famc "binomial"
			else if `"`_fam'"' == substr("poisson", 1, `_fl') local _famc "poisson"
			else if `"`_fam'"' == substr("nbinomial", 1, max(2, `_fl')) local _famc "nbinomial"
			local _lnkc "other"
			if `_ll' == 0 {
				if "`_famc'" == "binomial" local _lnkc "logit"
				else if inlist("`_famc'", "poisson", "nbinomial") local _lnkc "log"
				else if "`_famc'" == "gaussian" local _lnkc "identity"
			}
			else if `"`_lnk'"' == substr("identity", 1, `_ll') local _lnkc "identity"
			else if `"`_lnk'"' == substr("reciprocal", 1, `_ll') local _lnkc "other"
			else if `"`_lnk'"' == "log" local _lnkc "log"
			else if `"`_lnk'"' == substr("logit", 1, `_ll') local _lnkc "logit"
			local _eopt = ("`_ro_eform'" != "")
			if "`_rs_pmode'" == "mi" local _eopt = `_rs_peform'
			else if "`_rs_pmode'" == "or" local _eopt = `_eopt' | `_rs_peform'
			if "`_famc'" == "binomial" & "`_lnkc'" == "logit" {
				local _c "OR"
				local _e = !`_eopt'
				local _n 1
				local _i 1
			}
			else if "`_famc'" == "poisson" & "`_lnkc'" == "log" {
				local _c "IRR"
				local _e = !`_eopt'
				local _n 1
				local _i 1
			}
			else if `_eopt' {
				* eform on any other family/link: glm already reports exp(b);
				* name it the way glm's own table does.
				local _c "exp(b)"
				if "`_famc'" == "binomial" & "`_lnkc'" == "log" local _c "RR"
				if "`_famc'" == "nbinomial" & "`_lnkc'" == "log" local _c "IRR"
				local _n 1
				local _i 1
			}
		}
		else if !inlist("`_rs_word'", "regress", "mixed", "xtreg") {
			local _k 0
		}

		* level(): glm and the multilevel families also take link(), so their
		* level() needs two letters; every other supported estimator takes l().
		local _lspec "Level(string)"
		if inlist("`_rs_word'", "glm", "meglm", "mestreg") local _lspec "LEvel(string)"
		_regtab_cmdopts "`_lspec'" `"`_rs_opt'"'
		local _lv = -1
		if `"`_ro_level'"' != "" {
			local _lv = real(`"`_ro_level'"')
			if missing(`_lv') local _lv = -1
		}

		* A prefix decides what the collection holds for a ratio family. glm
		* already folded the prefix into _eopt above.
		if "`_rs_word'" != "glm" & `_n' == 1 {
			if "`_rs_pmode'" == "mi" local _e = !`_rs_peform'
			else if "`_rs_pmode'" == "or" & `_rs_peform' local _e 0
		}

		c_local _rs_coef `"`_c'"'
		c_local _rs_eform `_e'
		c_local _rs_null `_n'
		c_local _rs_noint `_i'
		c_local _rs_known `_k'
		c_local _rs_level `_lv'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

