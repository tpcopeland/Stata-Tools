*! regtab Version 2.5.1  2026/10/06
*! Author: Timothy P Copeland, Karolinska Institutet

/*
DESCRIPTION:
	Formats the collected regression tables; exports point estimate, 95% CI, and p-value to excel; and applies excel formatting (column widths, merges cells, sets column widths). Title appears in cell A1. Top left cell of table is B2.

SYNTAX:
	regtab, [xlsx(string) sheet(string) models(string) sep(string) coef(string) title(string) noint nore stats(string) relabel cutlabels(string asis) addrow(string asis)]

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
	        End a row with ", after(term)" to place it after a coefficient row
	        or a factor's block: addrow("P trend" 0.03, after(agecat))
	notestlabel: Label for levels not estimable (default: emptylabel())

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
	if !_rc capture mata: assert(findexternal("_tt_sep_parse()") != NULL)
	* (a session can hold an older _tabtools_common.ado's programs: run,
	* so discard keeps them; this release's Mata must be there too)
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

syntax, [xlsx(string) excel(string) sheet(string)] [sep(string) models(string) coef(string) ///
	title(string) NOINTercept KEEPIntercept NOREeffects stats(string asis) RELABel ///
	digits(integer -1) FOOTnote(string) open zebra HEADERShade HIGHlight(real -1) ///
	BOLDp(real -1) cdisc BORDERstyle(string) FONT(string) FONTSIZE(integer -1) stars ///
	STARSLevels(numlist) HEADERColor(string) ZEBRAColor(string) csv(string) MARKdown(string) MDAPPend ///
	FRAme(string) EPLOTFrame(string asis) keep(string) drop(string) LABELMatch DIMNONsig FACTORLabel ///
	REFcat(string) OMITLabel(string) EMPTYLabel(string) NOTESTLabel(string) ///
	CUTLabels(string) ADDRow(string asis) COMPact NOPvalue ///
	pdp(integer -1) highpdp(integer -1) LABELWidth(integer 0) Level(real -1) ///
	CFormat(string) REFTop CELLNote(string asis) MINCount(integer -1) ///
	TRANSpose EXPOSURELabel(string) CILabel(string) PLabel(string) ///
	ADDCol(string asis) STATLabels(string asis) COLLabels(string asis) ///
	ABSENTLabel(string) CNSLabel(string)]

* Accept excel() as synonym for xlsx()
if "`xlsx'" == "" & "`excel'" != "" local xlsx "`excel'"
* Session destinations (tabtools set workbook/markdown) apply only when
* sheet() asks for a sheet; an explicit option wins. The same rule as corrtab,
* crosstab, desctab, and puttab. The first write to the session workbook
* erases it: _tabtools_xlsx_write runs _tabtools_set_sinks xlsxstart on its
* target, and the Markdown writer clears its own flag.
if `"`macval(sheet)'"' != "" {
	_tabtools_set_sinks resolve, xlsx(`"`xlsx'"') markdown(`"`markdown'"') `mdappend'
	local xlsx `"`_ss_xlsx'"'
	local markdown `"`_ss_md'"'
	local mdappend "`_ss_mdappend'"
	if `"`xlsx'"' == "" {
		display as text "(tabtools: sheet() ignored; no xlsx() and no session workbook)"
	}
}

* stats() e(name) items and statlabels(): see _regtab_statspec
_regtab_statspec `"`macval(stats)'"' `"`macval(statlabels)'"' `"`macval(exposurelabel)'"'
local _user_coef_spec = ("`coef'" != "")
local _user_noint_spec = ("`nointercept'" != "")

* Default reference category label
if `"`refcat'"' == "" local refcat "Reference"
* Labels for coefficients the model constrained but did not estimate. A base
* category, a level dropped for collinearity, and a level that identifies no
* observations all arrive as a zero (a one after eform) with an empty interval;
* they are different facts and are labelled differently.
if `"`omitlabel'"' == "" local omitlabel "Omitted"
* mincount() masks a level by the same label as an empty cell; its default is
* then a dash (U+2013), the convention for a value that is not shown.
local _user_emptylabel = (`"`emptylabel'"' != "")
if `"`emptylabel'"' == "" & `mincount' != -1 local emptylabel = uchar(8211)
if `"`emptylabel'"' == "" local emptylabel "Empty"
* notestlabel(): a level the model holds but could not estimate (a zero or
* missing variance, an empty cell, or, under mincount(), a level omitted or
* absent from the model). Its default is emptylabel(), the label such cells
* carried before notestlabel() existed, so tables without it are unchanged.
if `"`notestlabel'"' == "" {
	local notestlabel : copy local emptylabel
}
if `"`refcat'"' == `"`omitlabel'"' | `"`refcat'"' == `"`emptylabel'"' ///
	| `"`omitlabel'"' == `"`emptylabel'"' {
	display as error ///
		"refcat(), omitlabel(), and emptylabel() must differ from each other"
	exit 198
}
if `"`notestlabel'"' == `"`refcat'"' | `"`notestlabel'"' == `"`omitlabel'"' {
	display as error "notestlabel() must differ from refcat() and omitlabel()"
	exit 198
}
* absentlabel(): under mincount(), a level of a factor a model includes that
* has no observation in that model's estimation sample (left out by design);
* default blank. cnslabel(): the interval text of a coefficient fixed by a
* constraint, as Stata prints it.
if `"`macval(absentlabel)'"' != "" {
	if `mincount' == -1 {
		display as error "absentlabel() requires mincount()"
		exit 198
	}
	if `"`macval(absentlabel)'"' == `"`macval(refcat)'"' {
		display as error "absentlabel() must differ from refcat()"
		exit 198
	}
}
if `"`macval(cnslabel)'"' == "" local cnslabel "(constrained)"
local _has_xlsx = "`xlsx'" != ""
if `_has_xlsx' & `"`macval(sheet)'"' == "" local sheet "Regression"
if !`_has_xlsx' & `"`macval(sheet)'"' == "" local sheet "Regression"

* cformat(): a full numeric display format for the estimate and both CI
* bounds; digits() is the shorthand, so the two cannot both be given. Dates,
* strings and hex formats are refused even where Stata calls them numeric.
local _cfmt `"`cformat'"'
if `"`_cfmt'"' != "" {
	if `digits' != -1 {
		display as error "cformat() and digits() cannot both be specified"
		exit 198
	}
	local _cfmt = strtrim(`"`_cfmt'"')
	capture confirm numeric format `_cfmt'
	local _cf_rc = _rc
	if !`_cf_rc' & !ustrregexm(`"`_cfmt'"', "^%-?0?[0-9]*[.,][0-9]+[fge]c?$") local _cf_rc = 7
	if `_cf_rc' {
		display as error `"cformat() must be a numeric display format such as %9.2f or %12.0fc (got `_cfmt')"'
		exit 198
	}
}
if `mincount' != -1 & `mincount' < 1 {
	display as error "mincount() must be a positive integer"
	exit 198
}

* Resolve persistent defaults
if `digits' == -1 {
    if "$TABTOOLS_DIGITS" != "" local digits = $TABTOOLS_DIGITS
    else local digits = 2
}
if `boldp' == -1 & "$TABTOOLS_BOLDP" != "" local boldp = $TABTOOLS_BOLDP
if `pdp' == -1 local pdp = 3
if `highpdp' == -1 local highpdp = 2
	local _show_pvalues = ("`nopvalue'" == "")

	* frame() and eplotframe() suboptions and target checks: _regtab_frameopts
	_regtab_frameopts `"`eplotframe'"' `"`frame'"'

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
_tabtools_validate_sheet `"`macval(sheet)'"' "sheet()"

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
* cformat() replaces both formats and is applied as given: strtrim(string(x,
* fmt)) for the estimate and both bounds (round(x, 0) is x), the rule every
* tabtools command with cformat() shares.
if `"`_cfmt'"' != "" {
	local coef_fmt `"`_cfmt'"'
	local ci_fmt `"`_cfmt'"'
	local coef_round = 0
}

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
	* _ci_level is the level as shown (header, methods, frame characteristics):
	* at most 15 significant digits, so 99.9 never prints as the double's
	* 17-digit 99.90000000000001. r(ci_level) returns the number itself.
	local _ci_level_num = r(level)
	local _ci_level = strtrim(string(`_ci_level_num', "%21.15g"))
	local _ci_found = r(found)
	* cilabel()/plabel(): the interval and p-value header text. Each replaces
	* the default text verbatim in every layout and sink; the parentheses a
	* transposed header puts around the interval label stay.
	if `"`macval(cilabel)'"' == "" local cilabel "`_ci_level'% CI"
	if `"`macval(plabel)'"' == "" local plabel "p-value"

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
    if `"`csv'"' != "" _tabtools_validate_path "`csv'" "csv()"
    _tabtools_check_sinks, xlsx(`"`xlsx'"') csv(`"`csv'"') markdown(`"`markdown'"')

    * Create temporary file for intermediate processing
    * Pair provenance must distinguish repeated fits with identical metadata.
    * The allocator also guards reusable tempfile names and live frame tokens.
    tempfile temp_export
    _tabtools_companion_id
    local temp_xlsx "`temp_export'.xlsx"

    if "`labelmatch'" != "" & "`keep'`drop'" == "" {
        noisily display as error "labelmatch requires keep() or drop()"
        exit 198
    }
    * transpose prints models as rows and terms as columns; the row-based
    * options have no row to act on there.
    local _tp = ("`transpose'" != "")
    if `_tp' {
        foreach _tpo in addrow dimnonsig {
            if `"``_tpo''"' != "" {
                noisily display as error "transpose cannot be combined with `_tpo'" ///
                    cond("`_tpo'" == "addrow", "(); use addcol() to add a column to a transposed table", "")
                exit 198
            }
        }
        if `has_highlight' | `has_boldp' {
            noisily display as error "transpose cannot be combined with highlight() or boldp()"
            exit 198
        }
        * a transposed table's columns are terms: its rows have no term key
        if `_displayframe_keys' {
            noisily display as error "frame(, flat keys) cannot be combined with transpose; its keys describe the untransposed rows"
            exit 198
        }
    }
    else if `"`macval(addcol)'"' != "" | `"`macval(collabels)'"' != "" {
        noisily display as error cond(`"`macval(addcol)'"' != "", "addcol() requires transpose; use addrow() to add a row", ///
            "collabels() requires transpose; label rows with the variables' labels or factorlabel")
        exit 198
    }
    if `"`exposurelabel'"' != "" & !strpos(" " + strlower("`stats'") + " ", " exposure ") {
        noisily display as error "exposurelabel() requires stats(exposure)"
        exit 198
    }
    if `"`exposurelabel'"' == "" local exposurelabel "Person-time"
    * Validate keep/drop mutual exclusivity
    if "`keep'" != "" & "`drop'" != "" {
        noisily display as error "keep() and drop() cannot be used together"
        exit 198
    }

	* sep() is data (help tabtools##sep): syntax read it as it reads every
	* string option (the rule all tabtools commands share); the default is
	* applied in Mata, and the text then lives in this local only, read by
	* Mata into the tables, never re-expanded or handed to collect.
	mata: st_local("sep", _tt_sep_parse(st_local("sep")))
	* The renderer joins the two bounds with a private delimiter no number
	* holds; regtab splits the rendered numbers on it and joins the bounds
	* with sep() itself, so no user text is ever searched for the delimiter.
	* Two bytes, as long as the default ", ", so the columns the renderer
	* makes keep the storage widths they have under the default.
	local _ci_tok "~|"
	* A comma-decimal cformat() (%9,2f) prints "0,45"; with a comma in the CI
	* separator the two bounds could not be told apart: refused.
	mata: st_local("_sep_comma", strofreal(strpos(st_local("sep"), ",") > 0))
	if `"`_cfmt'"' != "" & `_sep_comma' {
	    if ustrregexm(`"`_cfmt'"', "^%-?0?[0-9]*,") {
	        noisily display as error `"cformat(`_cfmt') uses a decimal comma; choose a sep() without a comma, such as sep(" to ") or sep("; ")"'
	        exit 198
	    }
	}

    * =========================================================================
    * EXTRACT PER-MODEL COMMAND METADATA
    * =========================================================================
    local _meta_models = 0
    local _model_headers_mixed = 0
    local _all_auto_noint = 1
    local _coef_label_return : copy local coef
    local _has_multieq_estimator = 0
    * mi estimate records the prefix and its options only in e(cmdline_mi)
    * and the fitted command in e(cmd_mi); e(vce) decides the AIC/BIC count.
    * Every metadata result is read under its own level name: the labels
    * collect attaches vary (none at all after bs: or bstrap:, "Estimation
    * command" once a svy: fit is present), and the user may have set their
    * own. _regtab_rlabels relabels the present levels with their names and
    * hands back their labels, restored exactly once the table is rendered.
    local _meta_own "cmdline_mi cmd_mi vce"
    _regtab_rlabels cmd cmdline depvar ivars revars redim `_meta_own'
    local _meta_levels "`_rl_present'"
    capture {
        collect layout (cmdset) (result[`_meta_levels'])
    }
    local _meta_layout_rc = _rc
    if "`_meta_levels'" == "" local _meta_layout_rc = 111
    if `_meta_layout_rc' == 0 {
        preserve
        capture {
            _tabtools_collect_render, type(meta) rowdim(cmdset) ///
                results(`_meta_levels') dropempty

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
                local hdr = strtrim(`v'[1])
                foreach _mo of local _meta_levels {
                    if `"`hdr'"' == "`_mo'" local meta_col_`_mo' "`v'"
                }
            }

            local _meta_models = _N - 1
            forvalues m = 1/`_meta_models' {
                local r = `m' + 1
                local model_cmd_`m' = lower(strtrim(`meta_col_cmd'[`r']))
                * F06 (codex audit 2026-09-27): the command line and the
                * outcome are persisted as machine identities, and Stata
                * names are case sensitive (y and Y are different outcomes).
                * They are kept as typed; classification lowercases a copy.
                local model_cmdline_`m' = strtrim(`meta_col_cmdline'[`r'])
                if "`meta_col_depvar'" != "" {
                    local model_depvar_`m' = strtrim(`meta_col_depvar'[`r'])
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
    forvalues _rli = 1/`_rl_n' {
        local _rlv : word `_rli' of `_rl_present'
        quietly collect label levels result `_rlv' `"`macval(_rl_lbl_`_rli')'"', modify
    }

    if !`_user_noint_spec' {
        local nointercept ""
    }

    local _re_family_seen ""
    local _any_gee 0
    if `_meta_models' > 0 {
        local _shared_coef ""
        local _shared_set 0
        local _re_family_mixed 0
        forvalues m = 1/`_meta_models' {
            local _cmdline_lc = lower(`"`model_cmdline_`m''"')
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

            * a cmdset without command metadata (a fit that failed, collected
            * as an empty cmdset or a placeholder) has no scale of its own
            local model_nometa_`m' = (`"`model_cmdline_`m''`model_cmd_`m''"' == "")
            if `model_nometa_`m'' {
            }
            else if !`_shared_set' {
                local _shared_coef `"`model_coef_`m''"'
                local _shared_set 1
            }
            else if "`model_coef_`m''" != "`_shared_coef'" {
                local _model_headers_mixed = 1
            }
            if `model_auto_noint_`m'' == 0 & !`model_nometa_`m'' {
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
            if `model_nometa_`m'' continue
            local _lvl_m = `model_level_`m''
            if `_lvl_m' == -1 local _lvl_m = c(level)
            if missing(`_lvl_first') {
                local _lvl_first = `_lvl_m'
                local _lvl_fm `m'
            }
            else if abs(`_lvl_m' - `_lvl_first') > 1e-8 {
                noisily display as error "collected models use different confidence levels: " ///
                    "`_lvl_first'% (model `_lvl_fm') and `_lvl_m'% (model `m')"
                noisily display as error "refit the models with a common level(), or tabulate them in separate regtab calls"
                exit 198
            }
        }

        if `_re_family_mixed' & "`noreeffects'" == "" {
            noisily display as error "mixed random-effect model families cannot be combined with random-effects rows"
            noisily display as error "Use separate regtab calls, or specify noreeffects to suppress random-effects rows"
            exit 198
        }

        forvalues m = 1/`_meta_models' {
            if `model_nometa_`m'' local model_coef_`m' `"`_shared_coef'"'
        }
        if !`_user_coef_spec' & "`cdisc'" == "" {
            if `_model_headers_mixed' {
                local coef "Estimate"
                local _coef_label_return "mixed"
            }
            else {
                local coef `"`_shared_coef'"'
                local _coef_label_return : copy local coef
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
    * CELLNOTE() SPECIFICATION
    * =========================================================================
    * cellnote("row label" model# "text" [\ ...]): parsed now, so a malformed
    * specification is refused before any rendering; rows are matched later.
    local _cn_n = 0
    if `"`macval(cellnote)'"' != "" {
        _regtab_cellnote `"`macval(cellnote)'"'
    }

    * =========================================================================
    * FIT-TIME RECORDS (tabtools fitcount): COUNTS, NOTES, SAMPLE LEVELS
    * =========================================================================
    * Each model's per-level events and variance status (tt_terms), the fit's
    * own notes for its constrained coefficients (tt_cns), and the levels each
    * factor term holds in e(sample) (tt_levels) were stored with its own
    * cmdset at fit time; the collection keeps neither e(sample) nor the b./o.
    * markers. Model m is row m (_regtab_fitrec). Without mincount() the notes
    * are optional and a failed read leaves them unused.
    local _fct_models = 0
    local _fr_need "tt_cns"
    if `mincount' != -1 local _fr_need "tt_terms tt_cns tt_levels"
    _regtab_fitrec `_fr_need'
    if `_fr_rc' & `mincount' != -1 {
        noisily display as error "mincount(): could not read the fit-time counts from the collection"
        exit `_fr_rc'
    }
    if !`_fr_rc' local _fct_models = `_fr_models'
    forvalues _m = 1/`_fct_models' {
        local _fct_`_m' `"`_fr_tt_terms_`_m''"'
        local _fcn_`_m' `"`_fr_tt_cns_`_m''"'
        local _fcl_`_m' `"`_fr_tt_levels_`_m''"'
    }

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
    * for the colname layout, the number of coefficients with a nonzero
    * standard error outside the derived _diparm equations (the estimated
    * parameters AIC/BIC/QICu fall back on when e(rank) is capped), and the
    * predictor variables for the methods sentence.
    local _sm_n = 0
    local _sm_ckeys ""
    local _sm_seq ""
    local _sm_ancpairs ""
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
            foreach _sl in anc cut reg pred fvk {
                local _sm_`_sl'_`_m' ""
            }
            local _sm_k_`_m' = 0
            local _sm_nb_`_m' = 0
            local _sm_sig_`_m' ""
            local _sm_reg_eqs_`_m' ""
        }
        forvalues _r = 3/`=_N' {
            local _key = strtrim(_raw_colname[`_r'])
            if `"`_key'"' == "" continue
            local _eq = _eq_key[`_r']
            _regtab_role `"`_eq'"' `"`_key'"'
            * Row order of the equation-aware rendering, and every ancillary
            * or cutpoint item with its equation (neither contains a space).
            local _sm_seq `"`_sm_seq' `_eq' `_key'"'
            if inlist("`_role'", "anc", "cut") {
                local _sm_ancpairs `"`_sm_ancpairs' `_eq' `_key'"'
            }
            forvalues _m = 1/`_sm_n' {
                local _vb : word `=2*`_m'-1' of `_sm_vars'
                local _vs : word `=2*`_m'' of `_sm_vars'
                local _cb = strtrim(`_vb'[`_r'])
                local _cs = subinstr(strtrim(`_vs'[`_r']), ",", "", .)
                if `"`_cb'`_cs'"' == "" continue
                if `"`_cb'"' != "" local ++_sm_nb_`_m'
                local _sm_sig_`_m' `"`_sm_sig_`_m''|`_eq':`_key'=`_cb'/`_cs'"'
                if ustrregexm(`"`_key'"', "^[0-9]+\.[A-Za-z_][A-Za-z0-9_]*$") ///
                    local _sm_fvk_`_m' `"`_sm_fvk_`_m'' `_key'"'
                local _sm_depvars `"`model_depvar_`_m''"'
                local _sm_outcome : list _eq in _sm_depvars
                if ("`_role'" == "reg" | ("`_role'" == "cons" & `_sm_outcome')) ///
                    & `"`_eq'"' != "" ///
                    local _sm_reg_eqs_`_m' `"`_sm_reg_eqs_`_m'' `_eq'"'
                if inlist("`_role'", "anc", "cut") {
                    local _sm_`_role'_`_m' `"`_sm_`_role'_`_m'' `_key'"'
                }
                if "`_role'" == "reg" local _sm_reg_`_m' `"`_sm_reg_`_m'' `_key'"'
                if inlist("`_role'", "reg", "scale") {
                    * predictor variables: factor and interaction notation
                    * reduced to the variable names it is built from. The
                    * covariates of a variance (lnsigma) equation, as in
                    * hetprobit's het(), are covariates of the model too.
                    local _kparts = subinstr(`"`_key'"', "#", " ", .)
                    foreach _kp of local _kparts {
                        local _kv = ustrregexra(`"`_kp'"', "^.*\.", "")
                        if `"`_kv'"' != "" local _sm_pred_`_m' `"`_sm_pred_`_m'' `_kv'"'
                    }
                }
                * collect stores a base level's, an omitted level's, a
                * fixed-by-constraint coefficient's and mlogit's base-outcome
                * equation's standard error as 0, not missing: none of them
                * is an estimated parameter.
                local _cs_num = real(`"`_cs'"')
                if !missing(`_cs_num') & !regexm(`"`_eq'"', "^_diparm") {
                    if `_cs_num' > 0 local ++_sm_k_`_m'
                }
            }
        }
        * A name that is an ordinary coefficient in any model and an
        * ancillary or cutpoint item in any model, the same one or another,
        * cannot share one colname row.
        local _sm_reg_all ""
        local _sm_ac_all ""
        forvalues _m = 1/`_sm_n' {
            foreach _sl in anc cut reg pred fvk {
                local _sm_`_sl'_`_m' : list uniq _sm_`_sl'_`_m'
            }
            local _sm_reg_all `"`_sm_reg_all' `_sm_reg_`_m''"'
            local _sm_ac_all `"`_sm_ac_all' `_sm_anc_`_m'' `_sm_cut_`_m''"'
        }
        * Different single-equation outcomes across models still align by
        * term; only several regression equations within one model require
        * equation-qualified rows.
        forvalues _m = 1/`_sm_n' {
            local _sm_reg_eqs_`_m' : list uniq _sm_reg_eqs_`_m'
            if `: word count `_sm_reg_eqs_`_m''' > 1 local _has_multieq_estimator = 1
        }
        local _sm_ckeys : list _sm_reg_all & _sm_ac_all
        local _sm_ckeys : list uniq _sm_ckeys
    }
    local _sm_rc = _rc
    restore
    if `_sm_rc' {
        noisily display as error "Could not map the collected coefficients to their equations"
        exit `_sm_rc'
    }
    * A model whose command line and every collected estimate and standard
    * error equal an earlier model's is that model again: most often a
    * collect get e() right after a fit that failed, which leaves the
    * previous results in e(). Kept, as the user may mean it, with a note.
    forvalues _m = 2/`=min(`_sm_n', `_meta_models')' {
        if `"`macval(_sm_sig_`_m')'"' == "" continue
        forvalues _j = 1/`=`_m' - 1' {
            if `"`macval(model_cmdline_`_m')'"' != `"`macval(model_cmdline_`_j')'"' continue
            if `"`macval(_sm_sig_`_m')'"' != `"`macval(_sm_sig_`_j')'"' continue
            noisily display as text "(regtab: model `_m' repeats model `_j': the same command line and estimates;" ///
                " a collect get e() right after a fit that failed collects the previous model again)"
            continue, break
        }
    }
    * mincount() needs every model's fit-time counts, except a model with no
    * estimate at all: a fit that failed, collected as an empty cmdset
    * (ereturn clear, then collect get e()) or a placeholder. Its column has
    * nothing to mask, so it is accepted and left as it is, with a note.
    if `mincount' != -1 {
        local _fct_missing ""
        local _fct_failed ""
        forvalues _m = 1/`=max(`_fct_models', `_meta_models', `_sm_n')' {
            if `"`_fct_`_m''"' != "" continue
            local _fct_nb = 1
            if `_m' <= `_sm_n' local _fct_nb = `_sm_nb_`_m''
            if `_fct_nb' == 0 local _fct_failed "`_fct_failed' `_m'"
            else local _fct_missing "`_fct_missing' `_m'"
        }
        if "`_fct_missing'" != "" {
            noisily display as error "mincount() requires {bf:tabtools fitcount, events() terms} right after every model's fit" ///
                " (none for model`_fct_missing')"
            exit 198
        }
        if "`_fct_failed'" != "" {
            noisily display as text "(regtab: model`_fct_failed' holds no estimate and no fit-time counts," ///
                " as a fit that failed does; mincount() has nothing to mask there)"
        }
    }
    * Each model's base levels by its own factor specification, read now while
    * the user's data are in memory (see _regtab_fvbase): collect records some
    * fits' base level as "empty", the class of a level that is not estimable.
    forvalues _m = 1/`_sm_n' {
        local _fvbv_`_m' ""
        local _fvb_`_m' ""
        local _fvbs_`_m' ""
        if `_m' > `_meta_models' | `"`_sm_fvk_`_m''"' == "" continue
        _regtab_fvbase `"`model_cmdline_`_m''"' `"`_sm_fvk_`_m''"' `_orig_varabbrev'
        local _fvbv_`_m' `"`_fvb_vars'"'
        local _fvb_`_m' `"`_fvb_keys'"'
        local _fvbs_`_m' `"`_fvb_soft'"'
    }

* stats(): per-model statistics, ICC and e(name) items from the collection: _regtab_mstats.ado
mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
noisily _regtab_mstats
mata: _regtab_nsO = st_dir("local", "macro", "*"); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsO); _regtab_nsI++) st_local(_regtab_nsO[_regtab_nsI], ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])

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

* Random-effects, factor-level, and equation labels, read before rendering: _regtab_remeta.ado
mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
noisily _regtab_remeta
mata: _regtab_nsO = st_dir("local", "macro", "*"); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsO); _regtab_nsI++) st_local(_regtab_nsO[_regtab_nsI], ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])

collect label levels result _r_b `"`macval(coef)'"', modify
collect label levels result _r_ci "`_ci_level'% CI", modify
collect label levels result _r_p "p-value", modify
collect style cell result[_r_b], warn nformat(%4.2fc) halign(center) valign(center)
* The renderer never reads collect's delimiter, and collect re-expands the
* text it is given: sep() is not handed to it (help tabtools##sep).
collect style cell result[_r_ci], warn nformat(%12.8f) sformat("(%s)") cidelimiter(", ") halign(center) valign(center)
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
        mata: st_local("_cnmap_label_`_ci'", st_global("s(label`_ci')"))
    }
}

* A covariate named like an ancillary parameter of its own or another
* model in the collection (alpha in nbreg, ln_p in a Weibull streg, lnsigma
* in a lognormal one, cut1 in ologit) shares its colname level with that
* parameter, so the one-row-per-name layout cannot hold both: within one
* model collect gives the row neither value, across models the row pairs
* one model's covariate with another's ancillary parameter. The
* equation tells them apart (deaths:alpha is the covariate, _diparm1:alpha
* the derived parameter). For the render only, every ancillary or cutpoint
* item with such a name moves to a private colname level __anc_<name>,
* selected by its equation tag and labelled <name>. This happens on a
* temporary copy of the collection, so the user's collection never changes.
* Each such row is then placed beside the ancillary row it follows (or else
* precedes) in the equation-aware order, which keeps the usual covariates-
* ancillary-intercept order, and it keeps its ancillary role.
local _smr_n = 0
if !`_use_coleq_layout' & `"`_sm_ckeys'"' != "" {
    local _pn : word count `_sm_ancpairs'
    forvalues _pi = 1(2)`_pn' {
        local _pe : word `_pi' of `_sm_ancpairs'
        local _pk : word `=`_pi' + 1' of `_sm_ancpairs'
        local _pin : list _pk in _sm_ckeys
        if !`_pin' continue
        local ++_smr_n
        local _smr_eq_`_smr_n' `"`_pe'"'
        local _smr_key_`_smr_n' `"`_pk'"'
    }
    local _seqn : word count `_sm_seq'
    forvalues _i = 1/`_smr_n' {
        local _smr_mode_`_i' "cons"
        local _smr_anchor_`_i' ""
        forvalues _si = 1(2)`_seqn' {
            local _se : word `_si' of `_sm_seq'
            local _sk : word `=`_si' + 1' of `_sm_seq'
            if `"`_se'"' != `"`_smr_eq_`_i''"' | `"`_sk'"' != `"`_smr_key_`_i''"' continue
            * A private row is placed after its preceding ancillary row, which
            * is placed first when it is private too, or else before the next
            * ancillary row that stays put: a private next row is not placed
            * yet, so it is stepped over.
            foreach _dir in prev next {
                if "`_smr_mode_`_i''" != "cons" continue
                local _ai = cond("`_dir'" == "prev", `_si' - 2, `_si' + 2)
                local _awalk = 1
                while `_awalk' {
                    local _awalk = 0
                    if `_ai' < 1 | `_ai' > `_seqn' continue
                    local _ae : word `_ai' of `_sm_seq'
                    local _ak : word `=`_ai' + 1' of `_sm_seq'
                    if !(`"`_ae'"' == "/" | regexm(`"`_ae'"', "^_diparm")) continue
                    local _apriv = 0
                    forvalues _j = 1/`_smr_n' {
                        if `"`_smr_eq_`_j''"' == `"`_ae'"' & `"`_smr_key_`_j''"' == `"`_ak'"' {
                            local _apriv = 1
                        }
                    }
                    if `_apriv' & "`_dir'" == "next" {
                        local _ai = `_ai' + 2
                        local _awalk = 1
                        continue
                    }
                    if `_apriv' local _ak `"__anc_`_ak'"'
                    local _smr_mode_`_i' = cond("`_dir'" == "prev", "after", "before")
                    local _smr_anchor_`_i' `"`_ak'"'
                }
            }
        }
    }
}

* Preserve user data before rendering the collect table into a string dataset
preserve

local _collect_render_rc = 0
local _smr_done = 0
if `_use_coleq_layout' {
    capture _tabtools_collect_render, type(main) rowdim(coleq#colname) ///
        coldim(cmdset) results(_r_b _r_ci _r_p) sep("`_ci_tok'") omitmap rowkeys
    local _collect_render_rc = _rc
}
else {
    local _smr_orig ""
    if `_smr_n' > 0 {
        capture quietly collect dims
        local _collect_render_rc = _rc
        local _smr_orig `"`s(collection)'"'
        if `"`_smr_orig'"' == "" local _collect_render_rc = 459
        * a collection name may not start with "__", so no bare tempname
        tempname _smr_tn
        local _smr_coll = "tt_regtab_anc" + substr("`_smr_tn'", 3, .)
        if `_collect_render_rc' == 0 {
            capture quietly collect copy `_smr_orig' `_smr_coll'
            local _collect_render_rc = _rc
        }
        if `_collect_render_rc' == 0 {
            local _smr_done = 1
            capture quietly collect set `_smr_coll'
            local _collect_render_rc = _rc
        }
    }
    forvalues _i = 1/`_smr_n' {
        if `_collect_render_rc' continue
        capture quietly collect remap colname[`_smr_key_`_i''] = ///
            colname[__anc_`_smr_key_`_i''], fortags(coleq[`_smr_eq_`_i''])
        local _collect_render_rc = _rc
        if _rc == 0 {
            capture quietly collect label levels colname __anc_`_smr_key_`_i'' ///
                `"`_smr_key_`_i''"', modify
            local _collect_render_rc = _rc
        }
    }
    if `_collect_render_rc' == 0 {
        capture _tabtools_collect_render, type(main) rowdim(colname) ///
            coldim(cmdset) results(_r_b _r_ci _r_p) sep("`_ci_tok'") factorparents omitmap rowkeys
        local _collect_render_rc = _rc
    }
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
* Back to the user's collection, after r() is read; drop the remapped copy.
if `_smr_done' {
    capture quietly collect set `_smr_orig'
    capture quietly collect drop `_smr_coll'
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
* both an ordinary and an ancillary coefficient, in one model or across
* models, was rendered as two rows (see above). Under nointercept the multi-equation layout
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
    * the raw equation of every row is kept for frame(, flat keys)
    rename _eq_key _raw_eq
}
else {
    quietly generate strL _raw_eq = ""
    * An ancillary or cutpoint name that is also a covariate of any model
    * was rendered under its private level (see above).
    forvalues _m = 1/`_sm_n' {
        foreach _k of local _sm_anc_`_m' {
            local _in_drop : list _k in _anc_drop_names
            local _rr = cond(`_in_drop', "ancd", "anc")
            local _kr `"`_k'"'
            local _kc : list _k in _sm_ckeys
            if `_kc' & `_smr_n' > 0 local _kr `"__anc_`_k'"'
            quietly replace _role_m`_m' = "`_rr'" if _n > 2 & strtrim(_raw_colname) == `"`_kr'"'
        }
        foreach _k of local _sm_cut_`_m' {
            local _kr `"`_k'"'
            local _kc : list _k in _sm_ckeys
            if `_kc' & `_smr_n' > 0 local _kr `"__anc_`_k'"'
            quietly replace _role_m`_m' = "cut" if _n > 2 & strtrim(_raw_colname) == `"`_kr'"'
        }
        quietly replace _role_m`_m' = "cons" if _n > 2 & strtrim(_raw_colname) == "_cons"
        quietly replace _role_m`_m' = "re" if _n > 2 & ///
            ustrregexm(strtrim(_raw_colname), "^(var|cov|sd|corr)\(")
    }
    * Collect lists a new colname level first; move each private ancillary
    * row beside its anchor (after the ancillary row it follows, before the
    * one it precedes, or else just above the intercept).
    forvalues _i = 1/`_smr_n' {
        quietly generate double _smr_ord = _n
        quietly generate byte _smr_hit = _n > 2 & strtrim(_raw_colname) == `"__anc_`_smr_key_`_i''"'
        quietly summarize _smr_ord if _smr_hit, meanonly
        local _smr_r0 = r(min)
        local _smr_ra = .
        if "`_smr_mode_`_i''" != "cons" {
            quietly summarize _smr_ord if _n > 2 & !_smr_hit & ///
                strtrim(_raw_colname) == `"`_smr_anchor_`_i''"', meanonly
            local _smr_ra = r(min)
        }
        if missing(`_smr_ra') {
            local _smr_mode_`_i' "cons"
            quietly summarize _smr_ord if _n > 2 & strtrim(_raw_colname) == "_cons", meanonly
            local _smr_ra = r(min)
        }
        if !missing(`_smr_r0') & !missing(`_smr_ra') {
            local _smr_off = cond("`_smr_mode_`_i''" == "after", 0.5, -0.5)
            quietly replace _smr_ord = `_smr_ra' + `_smr_off' if _smr_hit
            sort _smr_ord
        }
        drop _smr_ord _smr_hit
    }
    * The rows now carry their roles and order; give each its own name back
    * so cutlabels(), keep(), and drop() address it by the name Stata uses.
    forvalues _i = 1/`_smr_n' {
        quietly replace _raw_colname = `"`_smr_key_`_i''"' ///
            if _n > 2 & strtrim(_raw_colname) == `"__anc_`_smr_key_`_i''"'
    }
}

* Multilevel and multi-equation layouts: flatten coleq#colname rows: _regtab_flatten.ado
mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
noisily _regtab_flatten
mata: _regtab_nsO = st_dir("local", "macro", "*"); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsO); _regtab_nsI++) st_local(_regtab_nsO[_regtab_nsI], ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])

* nointercept drops intercept, cutpoint, and dropped-ancillary cells by their
* structural role. A row goes only when every model with a cell in it has such
* a role; a model's cell is blanked when another model's cell in the same row is
* an ordinary coefficient that must stay.
if "`noint'" != "" {
    quietly ds A _raw_colname _raw_eq `_role_vars', not
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
            local _glbl : copy local re_grouplbl_`_lev'
            replace _re_group_label = `"`macval(_glbl)'"' if A == "var(_cons[`_gvar'])"
            if "`_gpath'" != "`_gvar'" {
                replace _re_group_label = `"`macval(_glbl)'"' if A == "var(_cons[`_gpath'])"
            }
            replace _re_group_label = `"`macval(_glbl)'"' ///
                if _is_re_intercept == 1 & _re_group_label == "" ///
                & (strpos(A, "[`_gvar']") > 0 | strpos(A, ">`_gvar']") > 0)
        }
    }
    if `"`macval(re_grouplbl)'"' != "" {
        replace _re_group_label = `"`macval(re_grouplbl)'"' if _re_group_label == "" & A == "var(_cons)"
    }
}

* relabel: reader-facing random-effects row labels: _regtab_relabel.ado
mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
noisily _regtab_relabel
mata: _regtab_nsO = st_dir("local", "macro", "*"); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsO); _regtab_nsI++) st_local(_regtab_nsO[_regtab_nsI], ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])

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
local _helper_vars "_is_re _is_re_intercept _re_group_label _raw_colname _raw_eq `_role_vars'"
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
* Column blocks of the printed table: one per model, or one per column under
* transpose (set there).
local _n_blocks = `n_models'
* Preserve the raw key through all later display edits and row selections.
rename _raw_colname _raw_A

* A coefficient the model dropped for collinearity keeps its o. marker in the
* colname level whenever the term is not a factor level, so the row rendered as
* "o.flag" instead of the variable's label. Show the variable.
quietly replace A = substr(strtrim(_raw_A), 3, .) ///
	if _n > 2 & strpos(strtrim(_raw_A), "o.") == 1 & strtrim(A) == strtrim(_raw_A)
forvalues _ci = 1/`_cnmap_n' {
	quietly replace A = `"`macval(_cnmap_label_`_ci')'"' ///
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

* Constraint classes collect could not record, per model: _regtab_classes.ado
mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
noisily _regtab_classes
mata: _regtab_nsO = st_dir("local", "macro", "*"); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsO); _regtab_nsI++) st_local(_regtab_nsO[_regtab_nsI], ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])

if "`models'" != "" {
    * Split models string by backslashes
	local models : subinstr local models " \ " "\", all
	local models : subinstr local models "\  " "\", all
	local models : subinstr local models "  \" "\", all
    tokenize `"`macval(models)'"', parse("\")
    local model_idx = 1
    local col_idx = 1

    * Loop through tokenized results
    while `"`macval(`model_idx')'"' != "" {
        if `"`macval(`model_idx')'"' != "\" {
            * Apply label to appropriate column
            replace c`col_idx' = `"`macval(`model_idx')'"' if _n == 1
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

* The estimate header: coef() as typed (collect's own label of _r_b
* re-expanded a $name in it), else each model's own scale.
if `_user_coef_spec' | "`cdisc'" != "" | `_meta_models' == 0 {
    forvalues _hdr_col = 1(3)`n' {
        quietly replace c`_hdr_col' = `"`macval(coef)'"' in 2
    }
}
else {
    local _hdr_m = 0
    forvalues _hdr_col = 1(3)`n' {
        local _hdr_m = `_hdr_m' + 1
        replace c`_hdr_col' = `"`model_coef_`_hdr_m''"' if _n == 2
    }
}
* cilabel()/plabel(): the interval and p-value headers of every model. Every
* sink (console, Excel, CSV, Markdown, frame(), flat frame) reads row 2, and
* compact joins the estimate header to this interval header.
forvalues _hdr_col = 1(3)`n' {
    capture confirm variable c`=`_hdr_col'+1'
    if !_rc {
        quietly replace c`=`_hdr_col'+1' = `"`macval(cilabel)'"' in 2
    }
    capture confirm variable c`=`_hdr_col'+2'
    if !_rc {
        quietly replace c`=`_hdr_col'+2' = `"`macval(plabel)'"' in 2
    }
}

* Apply collect-style factor parent and child labels captured before rendering.
* Parent rows keep the variable label flush-left; child levels are indented.
if `_fvrow_parent_n' > 0 {
    forvalues _fvp = 1/`_fvrow_parent_n' {
        replace A = `"`macval(_fvrow_parent_lab_`_fvp')'"' ///
            if strtrim(A) == `"`_fvrow_parent_var_`_fvp''"' & _n >= 3
    }
}
if `_fvrow_label_n' > 0 {
    forvalues _fvi = 1/`_fvrow_label_n' {
        replace A = `"`macval(_fvrow_lab_`_fvi')'"' ///
            if strtrim(A) == `"`_fvrow_pat_`_fvi''"' & _n >= 3
    }
}

* Apply factor variable value labels if requested
if "`factorlabel'" != "" & "`_fvlabel_cmds'" != "" {
    forvalues _fvc = 1/`_fvlc_n' {
        replace A = `"  `macval(_fvlc_lab_`_fvc')'"' if strtrim(A) == "`_fvlc_pat_`_fvc''" & _n >= 3
    }
}

* Relabel ordered-outcome cutpoint rows (cut1, /cut1, cut2, ...).
* Labels are positional and split on backslashes to match models().
if `"`cutlabels'"' != "" {
    local _cutlabels_rest : copy local cutlabels
    local _cut_bslash = char(92)
    local _cut_n = 0
    while `"`macval(_cutlabels_rest)'"' != "" {
        local _cut_pos = strpos(`"`macval(_cutlabels_rest)'"', "`_cut_bslash'")
        if `_cut_pos' > 0 {
            local _cut_piece = strtrim(substr(`"`macval(_cutlabels_rest)'"', 1, `_cut_pos' - 1))
            local _cutlabels_rest = strtrim(substr(`"`macval(_cutlabels_rest)'"', `_cut_pos' + 1, .))
        }
        else {
            local _cut_piece = strtrim(`"`macval(_cutlabels_rest)'"')
            local _cutlabels_rest ""
        }
        if `"`macval(_cut_piece)'"' != "" {
            local ++_cut_n
            local _cut_label_`_cut_n' : copy local _cut_piece
        }
    }
    * Only rows some model holds as a cutpoint (structural role), so a
    * covariate named cut1 keeps its own label.
    quietly generate byte _cut_row = 0
    foreach _rv of local _role_vars {
        quietly replace _cut_row = 1 if `_rv' == "cut"
    }
    forvalues _cut_i = 1/`_cut_n' {
        replace A = `"`macval(_cut_label_`_cut_i')'"' ///
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
* Save the constraint class before substituting display labels; a numeric
* label can also equal an ordinary coefficient after rounding.
gen str6 _constraint`_model_ix' = ""
if `_omit_ok' {
    replace _constraint`_model_ix' = _omit_type`_model_ix' ///
        if inlist(_omit_type`_model_ix', "base", "omit", "empty", "cns") ///
        & strtrim(c`i') != "" & c`=`i'+1' == "" & _n >= 3
}
* Without a class, a constrained level is known only by its cells: an empty CI
* AND an empty p-value. An estimated level whose interval bound is missing (a
* near-separated fit prints "(0, .)") still has a p-value. Such a level is the
* base (or a dropped level) only when collect holds the constrained value
* itself: 0 on the coefficient scale, 1 when collect holds a ratio. A factor
* level the model did estimate but whose variance is zero or missing (stcox
* after separation: b = 39.8, se = 0) has blank CI and p too; it is not the
* reference and is shown as not estimable, by notestlabel().
* Without per-model metadata the scale collect holds is unknown: 0 or 1.
local _base_cond "inlist(c`i'z, 0, 1)"
if `_model_ix' <= `_meta_models' {
	local _base_val = cond(`_needs_eform', 0, `model_null_`_model_ix'')
	local _base_cond "c`i'z == `_base_val'"
}
gen byte _unclassed = _constraint`_model_ix' == "" ///
    & _is_base_level & strtrim(c`i') != "" & c`=`i'+1' == "" ///
    & strtrim(c`=`i'+2') == "" & _n >= 3
if `_omit_ok' {
	replace _unclassed = 0 if !inlist(_omit_type`_model_ix', "", "mixed")
}
replace _constraint`_model_ix' = "base" if _unclassed ///
    & ((`_base_cond') | missing(c`i'z))
replace _constraint`_model_ix' = "empty" if _unclassed ///
    & !(`_base_cond') & !missing(c`i'z)
if `_omit_ok' {
	replace c`i' = `"`macval(refcat)'"' if _omit_type`_model_ix' == "base" ///
		& strtrim(c`i') != "" & c`=`i'+1' == "" & _n >= 3
	replace c`i' = `"`macval(omitlabel)'"' if _omit_type`_model_ix' == "omit" ///
		& strtrim(c`i') != "" & c`=`i'+1' == "" & _n >= 3
	replace c`i' = `"`macval(notestlabel)'"' if _omit_type`_model_ix' == "empty" ///
		& strtrim(c`i') != "" & c`=`i'+1' == "" & _n >= 3
}
replace c`i' = `"`macval(refcat)'"' if _unclassed & _constraint`_model_ix' == "base"
replace c`i' = `"`macval(notestlabel)'"' if _unclassed & _constraint`_model_ix' == "empty"
drop _unclassed
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
	& inlist(_constraint`_model_ix', "", "cns")
drop _b_had
	gen double _coefnum`i' = c`i'z if _n >= 3
	capture confirm variable _eplot_est`_model_ix'
	if _rc gen double _eplot_est`_model_ix' = .
	replace _eplot_est`_model_ix' = c`i'z if _n >= 3
* Fixed effects: user-specified decimal places (default 2), or cformat().
gen str64 c`i'_fmt = strtrim(string(round(c`i'z, `coef_round'), "`coef_fmt'")) if !_is_re & !missing(c`i'z)
* Transformed random intercept (MOR/MHR): same precision as fixed effects
replace c`i'_fmt = strtrim(string(round(c`i'z, `coef_round'), "`coef_fmt'")) ///
    if _is_re_intercept == 1 & "`re_transform'" != "none" & !missing(c`i'z)
* Other random effects: same decimal places as fixed effects
replace c`i'_fmt = strtrim(string(round(c`i'z, `coef_round'), "`coef_fmt'")) ///
    if _is_re & _is_re_intercept == 0 & !missing(c`i'z)
replace c`i' = c`i'_fmt if c`i'_fmt != "" & _n >= 3 ///
	& inlist(_constraint`_model_ix', "", "cns")
drop c`i'z c`i'_fmt
capture confirm variable c`=`i'+1'
if _rc == 0 replace c`=`i'+1' = "" if _n == 1
capture confirm variable c`=`i'+2'
if _rc == 0 replace c`=`i'+2' = "" if _n == 1
}
drop _is_base_level
capture drop _omit_type*
* Reformat CI columns with appropriate precision
local sep_len = strlen("`_ci_tok'")
* sep() enters the table only as the value of this variable, stored from
* Mata: the text is never part of a command line or an expression
capture drop _ci_sepv
quietly generate strL _ci_sepv = ""
mata: st_sstore(., "_ci_sepv", J(st_nobs(), 1, st_local("sep")))
* Two %32.#f bounds, the parentheses, and sep()
mata: st_local("_ci_fmt_type", strlen(st_local("sep")) + 80 > 2045 ? "strL" : "str" + strofreal(strlen(st_local("sep")) + 80))
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
    * Strip thousands separators (collect's %#.#fc nformat emits "1,234.56"):
    * the bounds are split on the private delimiter, which holds no comma.
    replace _ci_raw = subinstr(_ci_raw, ",", "", .)
    gen int _ci_dpos = strpos(_ci_raw, "`_ci_tok'")
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
	    gen `_ci_fmt_type' _ci_fmt = ""
	    capture confirm variable _eplot_ll`_model_ix'
	    if _rc gen double _eplot_ll`_model_ix' = .
	    capture confirm variable _eplot_ul`_model_ix'
	    if _rc gen double _eplot_ul`_model_ix' = .
	    replace _eplot_ll`_model_ix' = _ci_lo if _n >= 3 & _ci_lo < .
	    replace _eplot_ul`_model_ix' = _ci_hi if _n >= 3 & _ci_hi < .
	    * Fixed effects: user-specified decimal places
    replace _ci_fmt = "(" + strtrim(string(_ci_lo, "`ci_fmt'")) + _ci_sepv + strtrim(string(_ci_hi, "`ci_fmt'")) + ")" ///
        if !_is_re & !missing(_ci_lo) & !missing(_ci_hi) & _n >= 3
    * Transformed random intercept (MOR/MHR): same precision as fixed effects
    replace _ci_fmt = "(" + strtrim(string(_ci_lo, "`ci_fmt'")) + _ci_sepv + strtrim(string(_ci_hi, "`ci_fmt'")) + ")" ///
        if _is_re_intercept == 1 & "`re_transform'" != "none" & !missing(_ci_lo) & !missing(_ci_hi) & _n >= 3
    * Other random effects: same decimal places as fixed effects
    replace _ci_fmt = "(" + strtrim(string(_ci_lo, "`ci_fmt'")) + _ci_sepv + strtrim(string(_ci_hi, "`ci_fmt'")) + ")" ///
        if _is_re & _is_re_intercept == 0 & !missing(_ci_lo) & !missing(_ci_hi) & _n >= 3
    * An interval left as rendered (a bound regtab could not read) takes
    * sep() in place of the private delimiter. Only the renderer's own text
    * is searched, before any cell holds sep(): a sep() that contains the
    * delimiter is never substituted a second time.
    replace c`i' = subinstr(c`i', "`_ci_tok'", _ci_sepv, .) ///
        if _ci_fmt == "" & _n >= 3 & strpos(c`i', "`_ci_tok'")
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
    * A coefficient a constraint fixes: its estimate, then cnslabel() where
    * the interval would be, as Stata prints "(constrained)".
    capture confirm variable _constraint`_model_ix'
    if !_rc {
        quietly replace c`i' = `"`macval(cnslabel)'"' if _constraint`_model_ix' == "cns" & _n >= 3
    }
    * Save non-significance flag for dimnonsig formatting
    if "`dimnonsig'" != "" {
        replace _ci_seen = 1 if !_is_re & !_is_ancillary & !missing(_ci_lo) & !missing(_ci_hi) & _n >= 3
        replace _nonsig = 0 if !_is_re & !_is_ancillary & !missing(_ci_lo) & !missing(_ci_hi) ///
            & (_ci_hi < `_null' | _ci_lo > `_null') & _n >= 3
    }
    drop _ci_raw _ci_dpos _ci_lo_s _ci_hi_s _ci_lo _ci_hi _ci_fmt
}
drop _ci_sepv
if "`dimnonsig'" != "" {
    gen byte _is_refrow = 0
    forvalues _ri = 1(3)`last' {
        replace _is_refrow = 1 if _n >= 3 ///
            & (_constraint`=(`_ri'+2)/3' != "")
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
                * C1: tested on the data, never through a macro holding the
                * label text.
                if substr(A[`_child'], 1, 1) != " " continue, break
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
		& !inlist(_constraint`_model_ix', "", "cns")
	capture confirm variable _eplot_ll`_model_ix'
	if !_rc replace _eplot_ll`_model_ix' = . if _n >= 3 ///
		& (_constraint`_model_ix' != "")
	capture confirm variable _eplot_ul`_model_ix'
	if !_rc replace _eplot_ul`_model_ix' = . if _n >= 3 ///
		& (_constraint`_model_ix' != "")
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

	* =====================================================================
	* REFTOP, MINCOUNT(), CELLNOTE(): row order and cell masks on the body
	* =====================================================================
	* reftop: within each consecutive block of one factor's levels, the level
	* a model holds as its base moves to the top of the block. Models that
	* hold different levels of one block as base are refused, not guessed.
	if "`reftop'" != "" {
		quietly generate double _rt_ord = _n
		quietly generate str244 _rt_par = ""
		forvalues _rr = 3/`=_N' {
			local _rt_key = strtrim(_raw_A[`_rr'])
			_regtab_fvparent `"`_rt_key'"'
			if `"`_fp_parent'"' != "" quietly replace _rt_par = `"`_fp_parent'"' in `_rr'
		}
		quietly generate long _rt_blk = sum(_rt_par != "" & _rt_par != _rt_par[_n - 1])
		quietly replace _rt_blk = 0 if _rt_par == ""
		quietly generate byte _rt_base = 0
		forvalues _m = 1/`n_models' {
			quietly replace _rt_base = 1 if _n >= 3 & _rt_par != "" & _constraint`_m' == "base"
		}
		quietly levelsof _rt_blk if _rt_base, local(_rt_blks)
		foreach _b of local _rt_blks {
			quietly count if _rt_blk == `_b' & _rt_base
			if r(N) > 1 {
				quietly levelsof _rt_par if _rt_blk == `_b', local(_rt_pn) clean
				noisily display as error "reftop: the models use different reference levels of `_rt_pn'"
				noisily display as error "  tabulate them in separate regtab calls, or refit them with one base level"
				restore
				exit 198
			}
			quietly summarize _rt_ord if _rt_blk == `_b', meanonly
			quietly replace _rt_ord = r(min) - 0.5 if _rt_blk == `_b' & _rt_base
		}
		sort _rt_ord
		drop _rt_ord _rt_par _rt_blk _rt_base
	}

	* mincount(#): masks, not-estimable and absent levels: _regtab_mincount.ado
	local _n_masked = 0
	local _n_absent = 0
	if `mincount' != -1 {
mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
noisily _regtab_mincount
mata: _regtab_nsO = st_dir("local", "macro", "*"); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsO); _regtab_nsI++) st_local(_regtab_nsO[_regtab_nsI], ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
	}

	* cellnote(): the model's cell on the one body row whose label is exactly
	* the given text; zero or several matching rows is an error.
	forvalues _ci = 1/`_cn_n' {
		local _m = `_cn_m_`_ci''
		if `_m' > `n_models' {
			noisily display as error "cellnote(): model `_m' does not exist (the table has `n_models' models)"
			restore
			exit 198
		}
		mata: st_local("_cn_rows", invtokens(strofreal(selectindex( ///
			strtrim(st_sdata(., "A")) :== strtrim(st_local("_cn_lab_`_ci'")) :& ///
			(1::st_nobs()) :>= 3))'))
		local _cn_k : word count `_cn_rows'
		if `_cn_k' != 1 {
			mata: st_local("_cn_show", st_local("_cn_lab_`_ci'"))
			noisily display as error `"cellnote(): row label ""' as result `"`macval(_cn_show)'"' ///
				as error `"" matches `_cn_k' coefficient rows; it must match exactly one"'
			restore
			exit 198
		}
		local _ce = (`_m' - 1) * 3 + 1
		* st_sstore() truncates to the variable's width: widen it first
		mata: st_local("_cn_w", strofreal(max((strlen(st_local("_cn_txt_`_ci'")), 1))))
		local _cn_t : type c`_ce'
		if "`_cn_t'" != "strL" {
			if `_cn_w' > real(substr("`_cn_t'", 4, .)) {
				if `_cn_w' <= 2045 quietly recast str`_cn_w' c`_ce'
				else quietly recast strL c`_ce'
			}
		}
		mata: st_sstore(`_cn_rows', "c`_ce'", st_local("_cn_txt_`_ci'"))
		quietly replace c`=`_ce' + 1' = "" in `_cn_rows'
		quietly replace c`=`_ce' + 2' = "" in `_cn_rows'
		quietly replace _constraint`_m' = "note" in `_cn_rows'
		foreach _ev in est ll ul p {
			capture confirm variable _eplot_`_ev'`_m'
			if !_rc quietly replace _eplot_`_ev'`_m' = . in `_cn_rows'
		}
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
	        mata: st_local("_ep_label", st_sdata(`_ep_obs', "A"))
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
	            mata: st_local("_ep_model_label", st_sdata(1, "c`_ep_model_col'"))
	            if `"`macval(_ep_model_label)'"' == "" local _ep_model_label "Model `_ep_m'"
	            local _ep_cell = strtrim(c`_ep_model_col'[`_ep_obs'])
	            local _ep_rowtype "effect"
	            if _constraint`_ep_m'[`_ep_obs'] == "base" local _ep_rowtype "reference"
	            if _constraint`_ep_m'[`_ep_obs'] == "cns" local _ep_rowtype "constrained"
	            if `_ep_est' < . | `_ep_ll' < . | `_ep_ul' < . | `_ep_p' < . | `"`_ep_rowtype'"' == "reference" {
	                * C1 (codex audit 2026-09-26): the row and model labels are stored
	                * in Mata after the post, so they are never expanded as macros.
	                frame post `_eplotframe_name' ("") (`_ep_est') (`_ep_ll') (`_ep_ul') ///
	                    (`_ep_p') (`_ep_m') ("") (`"`_ep_rowtype'"') ("") ///
	                    (`_ep_source_row') ("")
	                frame `_eplotframe_name' {
	                    mata: st_sstore(st_nobs(), "label", st_local("_ep_label"))
	                    mata: st_sstore(st_nobs(), "model_label", st_local("_ep_model_label"))
	                }
	            }
	        }
	    }
	    frame `_eplotframe_name': char _dta[tabtools_source] "regtab"
	    frame `_eplotframe_name': mata: st_global("_dta[tabtools_companion_id]", st_local("_companion_id"))
	    frame `_eplotframe_name': char _dta[tabtools_ci_level] "`_ci_level'"
	    frame `_eplotframe_name': char _dta[tabtools_n_models] "`n_models'"
	    frame `_eplotframe_name': char _dta[tabtools_statistic_ids] "estimate ci pvalue"
	    forvalues _meta_m = 1/`n_models' {
	        local _meta_cmdline `"`model_cmdline_`_meta_m''"'
	        local _meta_depvar `"`model_depvar_`_meta_m''"'
	        local _meta_scale `"`model_coef_`_meta_m''"'
	        if `"`macval(_meta_scale)'"' == "" {
			    local _meta_scale : copy local coef
			}
	        local _meta_label_col = (`_meta_m' - 1) * 3 + 1
	        mata: st_local("_meta_label", st_sdata(1, "c`_meta_label_col'"))
	        frame `_eplotframe_name': char _dta[tabtools_model_id_`_meta_m'] `"`_meta_cmdline'"'
	        frame `_eplotframe_name': char _dta[tabtools_outcome_id_`_meta_m'] `"`_meta_depvar'"'
	        frame `_eplotframe_name': char _dta[tabtools_effect_scale_`_meta_m'] `"`_meta_scale'"'
	        frame `_eplotframe_name': mata: st_global("_dta[tabtools_model_label_`_meta_m']", st_local("_meta_label"))
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
                if inlist(_constraint`=(`_ci'+2)/3'[`_obs'], "", "cns") {
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
                if inlist(_constraint`=(`_ci'+2)/3'[`_obs'], "", "cns") {
                    matrix `_rtable'[`_mr', `_mc'] = `_coefval'
                }
            }
        }
        * C1 (codex audit 2026-09-26): the row name is built in Mata from the
        * label as typed, with the macro characters (backtick, apostrophe,
        * dollar, double quote) replaced, so it can never expand below.
        mata: st_local("_rname", subinstr(subinstr(subinstr(subinstr( ///
            st_sdata(`_obs', "A"), char(96), "_"), char(39), "_"), char(36), "_"), char(34), "_"))
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
        local _rn_back ""
        capture matrix rownames `_rn_probe' = `_rname'
        if _rc == 0 local _rn_back : rownames `_rn_probe'
        if `"`_rn_back'"' != `"`_rname'"' {
            local _rname = substr(ustrregexra(`"`_rname'"', "[^A-Za-z0-9_]", "_"), 1, 32)
            local _rn_back ""
            capture matrix rownames `_rn_probe' = `_rname'
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
* Keep original body row positions for the later title-row shift and
* compact/nopvalue column renumbering, then remove internal status columns.
forvalues _m = 1/`n_models' {
    local _constraint_rows_`_m' ""
    forvalues _cr = 3/`=_N' {
        if !inlist(_constraint`_m'[`_cr'], "", "cns") ///
            local _constraint_rows_`_m' "`_constraint_rows_`_m'' `=`_cr'+1'"
    }
}
* frame(, flat keys): each row's type and term, and the state of each
* model's cell, while the constraint classes are here: _regtab_keys.ado
if `_displayframe_keys' {
mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
noisily _regtab_keys rows
mata: _regtab_nsO = st_dir("local", "macro", "*"); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsO); _regtab_nsI++) st_local(_regtab_nsO[_regtab_nsI], ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
}
capture drop _constraint*
capture drop _coefnum*
drop _is_re _is_re_intercept _is_ancillary
capture drop _role_m*
capture drop _re_group_label
* transpose: each term's column header, "Factor: level" for a factor level,
* taken from the raw key while it is still here.
if `_tp' {
    quietly generate str244 _tp_lab = strtrim(A)
    forvalues _rr = 3/`=_N' {
        local _rt_key = strtrim(_raw_A[`_rr'])
        _regtab_fvparent `"`_rt_key'"'
        if `"`_fp_parent'"' == "" continue
        local _tp_plab `"`_fp_parent'"'
        forvalues _fvp = 1/`_fvrow_parent_n' {
            if `"`_fvrow_parent_var_`_fvp''"' == `"`_fp_parent'"' {
                local _tp_plab : copy local _fvrow_parent_lab_`_fvp'
            }
        }
        * a multi-equation row reads "eq:   level" (the equation prefix, then
        * the level's indent); its header keeps regtab's "eq: " prefix in
        * front: "eq: Factor: level", as the untransposed row reads "eq: level"
        local _tp_eqp ""
        mata: st_local("_tp_lev", strtrim(st_sdata(`_rr', "A")))
        if `_is_multieq' {
            mata: st_local("_tp_hit", strofreal(ustrregexm(st_local("_tp_lev"), "^(.+?): {2,}(\S.*)$")))
            if `_tp_hit' {
                mata: st_local("_tp_eqp", ustrregexra(st_local("_tp_lev"), "^(.+?): {2,}(\S.*)$", "$1") + ": ")
                mata: st_local("_tp_lev", ustrregexra(st_local("_tp_lev"), "^(.+?): {2,}(\S.*)$", "$2"))
            }
        }
        mata: st_local("_tp_new", st_local("_tp_eqp") + st_local("_tp_plab") + ": " + st_local("_tp_lev"))
        mata: st_sstore(`_rr', "_tp_lab", st_local("_tp_new"))
    }
    * collabels(name "label" ...): a term's column header, by raw name
    if `"`macval(collabels)'"' != "" {
        _regtab_collabels `"`macval(collabels)'"' `_is_multieq'
    }
}
capture drop _ci_seen

* stats(): model statistics rows below the table body: _regtab_statrows.ado
local stats_row_ids ""
mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
noisily _regtab_statrows
mata: _regtab_nsO = st_dir("local", "macro", "*"); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsO); _regtab_nsI++) st_local(_regtab_nsO[_regtab_nsI], ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
if `_displayframe_keys' {
mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
noisily _regtab_keys stats
mata: _regtab_nsO = st_dir("local", "macro", "*"); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsO); _regtab_nsI++) st_local(_regtab_nsO[_regtab_nsI], ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
}

* =========================================================================
* TRANSPOSE: MODELS AS ROWS, TERMS AND STATISTICS AS COLUMNS
* =========================================================================
* One column per stats() row (its label over the models' values), then per
* coefficient row with an estimate in any model one "estimate (CI)" column
* and, unless nopvalue, one p-value column. A factor's header row, which holds
* no estimate, is not a column. Every column is its own block downstream.
if `_tp' {
    local _tp_nm1 = `n_models' - 1
    local _tp_end = _N
    if `stats_start_row' > 0 local _tp_end = `stats_start_row' - 1
    local _tp_cvars ""
    forvalues _j = 1/`n' {
        local _tp_cvars "`_tp_cvars' c`_j'"
    }
    local _tp_hdr `"`macval(coef)' (`macval(cilabel)')"'
    mata: _tp_S = st_sdata(., ("A", tokens(st_local("_tp_cvars"))))
    mata: _tp_L = st_sdata(., "_tp_lab")
    mata: _tp_ix = 2 :+ ((0::`_tp_nm1') :* 3)
    mata: _tp_O = J(2 + `n_models', 0, "")
    * _tp_keys: each column's raw coefficient name ("." for a statistic),
    * which addcol(..., after()) places columns by
    local _tp_keys ""
    foreach _sr of local stats_rows {
        mata: _tp_O = _tp_O, (strtrim(_tp_S[`_sr', 1]) \ "" \ strtrim(_tp_S[`_sr', _tp_ix']'))
        local _tp_keys "`_tp_keys' ."
    }
    forvalues _rr = 3/`_tp_end' {
        mata: st_local("_tp_has", strofreal(any(strtrim(_tp_S[`_rr', _tp_ix']) :!= "")))
        if !`_tp_has' continue
        mata: _tp_e = strtrim(_tp_S[`_rr', _tp_ix']')
        mata: _tp_c = strtrim(_tp_S[`_rr', (_tp_ix :+ 1)']')
        mata: _tp_O = _tp_O, (_tp_L[`_rr'] \ st_local("_tp_hdr") \ (_tp_e :+ (" " :* (_tp_c :!= "")) :+ _tp_c))
        local _tp_key = strtrim(_raw_A[`_rr'])
        if `"`_tp_key'"' == "" local _tp_key "."
        local _tp_keys `"`_tp_keys' `_tp_key'"'
        if `_show_pvalues' {
            mata: _tp_O = _tp_O, (_tp_L[`_rr'] \ st_local("plabel") \ strtrim(_tp_S[`_rr', (_tp_ix :+ 2)']'))
            local _tp_keys `"`_tp_keys' `_tp_key'"'
        }
    }
    mata: _tp_A = ("" \ "" \ strtrim(_tp_S[1, _tp_ix']'))
    mata: st_local("_tp_k", strofreal(cols(_tp_O)))
    if `_tp_k' == 0 {
        capture mata: mata drop _tp_S _tp_L _tp_ix _tp_O _tp_A
        noisily display as error "transpose: no coefficient or statistic to show"
        restore
        exit 2000
    }
    clear
    quietly set obs `=2 + `n_models''
    quietly generate str244 A = ""
    local _tp_newc ""
    forvalues _j = 1/`_tp_k' {
        quietly generate str244 c`_j' = ""
        local _tp_newc "`_tp_newc' c`_j'"
    }
    mata: st_sstore(., "A", _tp_A)
    mata: st_sstore(., tokens(st_local("_tp_newc")), _tp_O)
    capture mata: mata drop _tp_S _tp_L _tp_ix _tp_O _tp_A _tp_e _tp_c
    local n = `_tp_k'
    local _n_blocks = `_tp_k'
    local stats_rows ""
    local first_re_row ""
    forvalues _m = 1/`_tp_k' {
        local _constraint_rows_`_m' ""
    }
}
capture drop _tp_lab

* addrow(): custom rows, appended or placed inside the body: _regtab_addrow.ado
mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
noisily _regtab_addrow
mata: _regtab_nsO = st_dir("local", "macro", "*"); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsO); _regtab_nsI++) st_local(_regtab_nsO[_regtab_nsI], ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
* the raw names are kept through addrow(), which places rows by them
capture drop _raw_A _raw_eq

* =========================================================================
* ADD CUSTOM COLUMNS (addcol option, transposed layout)
* =========================================================================
* addcol("label" val1 val2 ... [\ ...]): addrow()'s specification for a
* transposed table, one column per specification after the last column, the
* label as its header and the values given to the models (rows) in order.
if `"`macval(addcol)'"' != "" & `_tp' {
    _regtab_addcol `n' `n_models' `"`macval(addcol)'"' `"`_tp_keys'"'
    forvalues _j = `=`n' + 1'/`_ac_n' {
        local _constraint_rows_`_j' ""
    }
    local _n_blocks = `_n_blocks' + `_ac_n' - `n'
    local n = `_ac_n'
}

if `_displayframe_keys' {
mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
noisily _regtab_keys save
mata: _regtab_nsO = st_dir("local", "macro", "*"); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsO); _regtab_nsI++) st_local(_regtab_nsO[_regtab_nsI], ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
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
replace title = `"`macval(title)'"' if _n == 1

* Save p-value strings before optional layout changes remove p columns.
if `has_boldp' | `has_highlight' {
    forvalues _m = 1/`_n_blocks' {
        local _pvar = (`_m' - 1) * 3 + 3
        forvalues _dr = 4/`=_N' {
            local _bp_m`_m'_r`_dr' = strtrim(c`_pvar'[`_dr'])
        }
    }
}

* =====================================================================
* COMPACT MODE — MERGE ESTIMATE + CI INTO SINGLE COLUMN
* =====================================================================
if "`compact'" != "" & !`_tp' {
    * Merge estimate (c1,c4,c7,...) + CI (c2,c5,c8,...) for data rows
    * Data rows start at dataset row 3 (rows 1-2 are headers)
    forvalues m = 1(3)`n' {
        local _ci_col = `m' + 1
        * Merge: "0.85" + " " + "(0.72, 1.01)" -> "0.85 (0.72, 1.01)"
        qui replace c`m' = c`m' + " " + c`_ci_col' if _n >= 3 & c`_ci_col' != ""
        * The model-name row (row 2 once the title row is in): the same join,
        * as a data expression. Read through a local, a name was re-expanded
        * ($name, a backquote); the statistic headers of row 3 are joined by
        * the rule above. strtrim: no trailing space in the stored cell.
        qui replace c`m' = strtrim(c`m' + " " + c`_ci_col') in 2
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
else if `_tp' {
    * transposed: every column is a block of its own, already merged
    local _cols_per_model = 1
}
else {
    local _cols_per_model = 3
}

* Optional p-value suppression. p-values remain available internally before
* this point for stars and row highlighting, but are removed from all outputs.
* A transposed table left them out when it was built.
if !`_show_pvalues' & !`_tp' {
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
* The width and style code below treats a transposed column as a compact
* block without a p-value column of its own.
if `_tp' {
    local compact "compact"
    local _show_pvalues = 0
}

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

* The methods sentence, r(methods): _regtab_methods.ado
mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
noisily _regtab_methods
mata: _regtab_nsO = st_dir("local", "macro", "*"); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsO); _regtab_nsI++) st_local(_regtab_nsO[_regtab_nsI], ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])

* Return statistics before any file-writing failure can abort the command
if `_mat_nrows' > 0 {
    return matrix table = `_rtable'
}
return scalar N_rows = `num_rows'
return scalar N_cols = `num_cols'
	return scalar N_models = `n_models'
	return scalar ci_level = `_ci_level_num'
	return local coef_label `"`macval(_coef_label_return)'"'
	if `mincount' != -1 return scalar N_masked = `_n_masked'
	if `mincount' != -1 return scalar N_absent = `_n_absent'
	return local stars "`stars'"
	return local methods `"`macval(_methods)'"'
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
        foreach _nt in obs events people exposure mi_m r2_a rmse F fmi {
            if `want_`_nt'' & !missing(`stat_`_nt'_`m'') return scalar `_nt'_`m' = `stat_`_nt'_`m''
        }
    }
    * generic e(name) items as r(e_<name>_<model>), when that name fits
    forvalues _k = 1/`_cst_n' {
        if "`_cst_kind_`_k''" != "e" continue
        forvalues m = 1/`=min(`n_models', max(`_meta_models', 1))' {
            foreach _s in "" 2 {
                local _cst_rn "e_`_cst_nm`_s'_`_k''_`m'"
                if "`_cst_nm`_s'_`_k''" == "" | strlen("`_cst_rn'") > 32 continue
                if !missing(`_cstv`_s'_`_k'_`m'') return scalar `_cst_rn' = `_cstv`_s'_`_k'_`m''
            }
        }
    }
    if "`_cst_anymc'" == "1" return scalar N_stats_masked = `_n_stmask'
    if "`_cst_anylink'" == "1" return scalar N_stats_linked = `_n_stlink'
    if `want_icc' {
        local _ret_icc_models = min(`n_icc_models', `n_models')
        forvalues m = 1/`_ret_icc_models' {
            if !missing(`stat_icc_`m'')              return scalar icc_`m'    = `stat_icc_`m''
        }
    }
}

if `_has_xlsx' {
    capture noisily _tabtools_xlsx_write using "`xlsx'", sheet(`"`macval(sheet)'"') book(`_xlsx_book')
    if _rc {
        local _export_rc = _rc
        noisily display as error `"Failed to export to `xlsx', sheet `macval(sheet)'"'
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
forvalues _mw = 1/`_n_blocks' {
    local _c_first = (`_mw' - 1) * `_cols_per_model' + 1

    local _est_width_`_mw' = `_est_min'
    local _m_hdr_len = 0
    capture confirm variable c`_c_first'
    if !_rc {
        _tabtools_colwidth c`_c_first', scale(1) pad(-0.5) minwidth(`_est_min') ///
            headerrow(2) exclude(`"`refcat'"' `"`omitlabel'"' `"`emptylabel'"' `"`notestlabel'"')
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
gen ref`i' = .
foreach _cr of local _constraint_rows_`_ref_model_ix' {
    replace ref`i' = _n in `_cr'
}
order ref`i', after(c`i')
levelsof ref`i', local(_ref_rows_`_ref_model_ix')
}

* CSV export (F2) — must happen before clear
if "`csv'" != "" {
    _tabtools_csv_write using "`csv'", labelvar(A) reservedrow ///
        title(`"`macval(title)'"') footnote(`"`macval(footnote)'"')
}

* Console display
noisily _tabtools_console_display `n' `"`macval(title)'"', labelvar(A)

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
		forvalues _mdc = 1/`_n_blocks' {
			local _md_first = (`_mdc' - 1) * `_cols_per_model' + 1
			* C1: the model name is used as a data expression, never through a
			* macro holding its text.
			local _md_name "strtrim(c`_md_first'[2])"
			if strtrim(c`_md_first'[2]) != "" {
				forvalues _md_off = 0/`=`_cols_per_model' - 1' {
					local _md_col = `_md_first' + `_md_off'
					capture confirm variable c`_md_col'
					if !_rc {
						quietly replace c`_md_col' = ///
							`_md_name' + ": " + strtrim(c`_md_col') ///
							in 3 if strtrim(c`_md_col') != ""
						quietly replace c`_md_col' = `_md_name' ///
							in 3 if strtrim(c`_md_col') == ""
					}
				}
			}
		}
	}
	capture noisily _tabtools_markdown_write using `"`markdown'"', ///
		`_mdappend_opt' labelvar(A) title(`"`macval(title)'"') footnote(`"`macval(footnote)'"') ///
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
		* Model labels: row 2 of each model's first column, or under transpose
		* the label column of each model's row.
		forvalues _meta_m = 1/`n_models' {
			if `_tp' {
				mata: st_local("_meta_label_`_meta_m'", st_sdata(`_meta_m' + 3, "A"))
			}
			else {
				local _meta_label_col = (`_meta_m' - 1) * `_cols_per_model' + 1
				mata: st_local("_meta_label_`_meta_m'", st_sdata(2, "c`_meta_label_col'"))
			}
		}
		* frame(name, flat): one row per body line, rowlabel then one string
		* variable per printed column labelled with its printed header ("Model
		* 1, HR"); no title, header, or reference-marker rows or columns.
		local _flat_snapshot ""
		if `_displayframe_flat' {
			tempfile _flat_snapshot
			quietly save `"`_flat_snapshot'"', replace
			* short labels: each column labelled with its statistic header alone,
			* as printed under the model name (plabel("P") is "P"); a transposed
			* column's block is its term, so it keeps "term, statistic".
			_tabtools_flatframe `n' `_cols_per_model' `=cond(`_tp', "", "short")'
			if `_displayframe_keys' {
			mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
			noisily _regtab_keys put
			mata: _regtab_nsO = st_dir("local", "macro", "*"); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsO); _regtab_nsI++) st_local(_regtab_nsO[_regtab_nsI], ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
			}
		}
		_tabtools_frame_put `"`frame'"'
		local frame `"`_frame_name'"'
		if `_displayframe_flat' {
			quietly use `"`_flat_snapshot'"', clear
			frame `frame': char _dta[tabtools_layout] "flat"
		}
		frame `frame': char _dta[tabtools_source] "regtab"
		frame `frame': mata: st_global("_dta[tabtools_companion_id]", st_local("_companion_id"))
		frame `frame': char _dta[tabtools_ci_level] "`_ci_level'"
		frame `frame': char _dta[tabtools_n_models] "`n_models'"
		local _frame_stat_ids "estimate ci pvalue"
		if "`compact'" != "" local _frame_stat_ids "estimate_ci pvalue"
		if "`nopvalue'" != "" local _frame_stat_ids : subinstr local _frame_stat_ids " pvalue" "", all
		if `_tp' local _frame_stat_ids "transposed"
		frame `frame': char _dta[tabtools_statistic_ids] "`_frame_stat_ids'"
		forvalues _meta_m = 1/`n_models' {
			local _meta_cmdline `"`model_cmdline_`_meta_m''"'
			local _meta_depvar `"`model_depvar_`_meta_m''"'
			local _meta_scale `"`model_coef_`_meta_m''"'
			if `"`macval(_meta_scale)'"' == "" {
			    local _meta_scale : copy local coef
			}
			mata: st_local("_meta_label", st_local("_meta_label_`_meta_m'"))
			frame `frame': char _dta[tabtools_model_id_`_meta_m'] `"`_meta_cmdline'"'
			frame `frame': char _dta[tabtools_outcome_id_`_meta_m'] `"`_meta_depvar'"'
			frame `frame': char _dta[tabtools_effect_scale_`_meta_m'] `"`_meta_scale'"'
			frame `frame': mata: st_global("_dta[tabtools_model_label_`_meta_m']", st_local("_meta_label"))
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

* Prepare footnote text before Mata block. The text is copied, trimmed and
* tested without macro expansion (copy local, macval(), st_local()), so a
* footnote holding a local-macro reference or a $word reaches the workbook as
* typed.
local _fn_text : copy local footnote
if "`stars'" != "" {
	local _stars_note "* p<`_sl1', ** p<`_sl2', *** p<`_sl3'"
	* Punctuation-aware join: a user footnote that already ends in terminal
	* punctuation must not gain a ";" after it (".;" was shipped in the regtab
	* and other table demo workbooks).
	if `"`macval(_fn_text)'"' != "" {
		mata: st_local("_fn_trim", strtrim(st_local("_fn_text")))
		mata: st_local("_fn_endp", strofreal(strlen(st_local("_fn_trim")) > 0 & ///
			strpos(".;:!?", substr(st_local("_fn_trim"), -1, 1)) > 0))
		if `_fn_endp' {
			local _fn_text `"`macval(_fn_trim)' `_stars_note'"'
		}
		else {
			local _fn_text `"`macval(_fn_trim)'; `_stars_note'"'
		}
	}
	else local _fn_text `"`_stars_note'"'
}

* Prepare p-value/nonsig data vectors for Mata
local _n_bp_entries 0
if `has_boldp' | `has_highlight' {
	forvalues _m = 1/`_n_blocks' {
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
	forvalues _mc = 1/`_n_blocks' {
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
	forvalues _mc = 1/`_n_blocks' {
		local _col_start = 2 + (`_mc' - 1) * `_cols_per_model' + 1
		local _col_end = `_col_start' + `_cols_per_model' - 1
		foreach row of local _ref_rows_`_mc' {
			local _style_rule_rows `"`_style_rule_rows' | 14 `row' `row' `_col_start' `_col_end' 0 0 0 0 | 5 `row' `row' `_col_start' `_col_start' 0 2 0 0 | 6 `row' `row' `_col_start' `_col_start' 0 2 0 0 | 3 `row' `row' `_col_start' `_col_start' 0 1 0 0"'
		}
	}

	forvalues _mc = 1/`_n_blocks' {
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
			forvalues _mc = 1/`_n_blocks' {
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
				forvalues _mc = 1/`_n_blocks' {
					local _ac = 2 + (`_mc' - 1) * `_cols_per_model' + 1
					local _ac_end = `_ac' + `_cols_per_model' - 1
					local _style_rule_rows `"`_style_rule_rows' | 14 `excel_row' `excel_row' `_ac' `_ac_end' 0 0 0 0 | 5 `excel_row' `excel_row' `_ac' `_ac' 0 2 0 0 | 6 `excel_row' `excel_row' `_ac' `_ac' 0 2 0 0"'
					if "`borderstyle'" != "academic" {
						local _style_rule_rows `"`_style_rule_rows' | 11 `excel_row' `excel_row' `_ac_end' `_ac_end' 0 `_vborder_code' 0 0"'
					}
				}
			}
		}
		* addrow(..., after()) rows sit inside the body: their value spans the
		* model's cells as an appended row's does, without the rule above it.
		foreach ar_row of local _ar_in_rows {
			local excel_row = `ar_row' + 1
			forvalues _mc = 1/`_n_blocks' {
				local _ac = 2 + (`_mc' - 1) * `_cols_per_model' + 1
				local _ac_end = `_ac' + `_cols_per_model' - 1
				local _style_rule_rows `"`_style_rule_rows' | 14 `excel_row' `excel_row' `_ac' `_ac_end' 0 0 0 0 | 5 `excel_row' `excel_row' `_ac' `_ac' 0 2 0 0 | 6 `excel_row' `excel_row' `_ac' `_ac' 0 2 0 0"'
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
			forvalues _m = 1/`_n_blocks' {
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
	if `"`macval(_fn_text)'"' != "" {
		* The token " \ " separates footnote paragraphs: one merged, wrapped row
		* per paragraph, as the shared CSV and Markdown writers do, with the same
		* text in every sink.
		local _fn_fontsize = max(`_fontsize' - 2, 6)
		local _fn_rest : copy local _fn_text
		local _fn_k = 0
		local _fn_more = 1
		while `_fn_more' {
			mata: st_local("_fn_pos", strofreal(strpos(st_local("_fn_rest"), " " + char(92) + " ")))
			if `_fn_pos' == 0 {
				mata: st_local("_fn_piece", strtrim(st_local("_fn_rest")))
				local _fn_more = 0
			}
			else {
				mata: st_local("_fn_piece", strtrim(substr(st_local("_fn_rest"), 1, `_fn_pos' - 1)))
				mata: st_local("_fn_rest", substr(st_local("_fn_rest"), `_fn_pos' + 3, .))
			}
			mata: st_local("_fn_empty", strofreal(strtrim(st_local("_fn_piece")) == ""))
			if `_fn_empty' continue
			local ++_fn_k
			local _fn_row = `num_rows' + `_fn_k'
			mata: `_xlsx_book'.put_string(`_fn_row', 2, st_local("_fn_piece"))
			local _style_rule_rows `"`_style_rule_rows' | 14 `_fn_row' `_fn_row' 2 `num_cols' 0 0 0 0 | 5 `_fn_row' `_fn_row' 2 2 0 1 0 0 | 6 `_fn_row' `_fn_row' 2 2 0 2 0 0 | 4 `_fn_row' `_fn_row' 2 2 0 1 0 0 | 1 `_fn_row' `_fn_row' 2 2 `_fn_fontsize' 1 0 0 | 3 `_fn_row' `_fn_row' 2 2 0 1 0 0"'
		}
	}

	_tabtools_xlsx_build_styles, matrix(`_style_rules') ///
		rules(`"`_style_rule_rows'"') cols(9)
	_tabtools_xlsx_apply_styles, defer book(`_xlsx_book') sheet(`"`macval(sheet)'"') ///
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
    noisily display as text "Exported " as result "`num_rows'" as text " rows × " as result "`num_cols'" as text " cols to " as result `"`xlsx'"' as text ", sheet " as result `"`macval(sheet)'"'
}
if `_xlsx_ok' {
    return local xlsx "`xlsx'"
    return local sheet `"`macval(sheet)'"'
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
	    * the keys matrix first: a successful run leaves _rc as 2.4.0 did
	    capture mata: mata drop _regtab_K
	    foreach _nsx in N V O I {
	        capture mata: mata drop _regtab_ns`_nsx'
	    }
	    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
