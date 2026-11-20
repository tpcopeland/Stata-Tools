*! regtab Version 1.2.1  2026/11/20
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
	        exp(sqrt(2*var) * invnormal(0.75)): MOR, austin-merlo-2017
	        (Stat Med 36:3257), sec. 4.5.2 eq. (5); MHR, austin-wagner-merlo-2017
	        (Stat Med 36:928), sec. 2.2 eq. (4).
	ICC (latent response): sigma2_u / (sigma2_u + gamma), gamma = pi^2/3
	        (logit), 1 (probit), pi^2/6 (cloglog): [ME] estat icc, Methods and
	        formulas; logit and probit also austin-merlo-2017, sec. 4.5.1.
	        QICu = deviance + 2p: Cui 2007, Stata J 7:209, eq. (2).

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
	if !_rc capture mata: assert(_tt_bundle_build() == "1.2.1")
	* (a session can hold an older _tabtools_common.ado's programs: run,
	* so discard keeps them; this release's Mata must be there too)
	if _rc {
		capture findfile _tabtools_common.ado
		if _rc == 0 {
			run "`r(fn)'"
			capture _tabtools_helpers_ready
			if !_rc capture mata: assert(_tt_bundle_build() == "1.2.1")
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
	digits(string) FOOTnote(string) open zebra HEADERShade HIGHlight(string) ///
	BOLDp(string) cdisc BORDERstyle(string) FONT(string) FONTSIZE(string) stars ///
	STARSLevels(numlist) HEADERColor(string) ZEBRAColor(string) csv(string) MARKdown(string) MDAPPend ///
	LATEX(string) TEXAPPend texdocument texopts(string asis) FRAme(string) EPLOTFrame(string asis) keep(string) drop(string) LABELMatch DIMNONsig FACTORLabel ///
	REFcat(string) OMITLabel(string) EMPTYLabel(string) NOTESTLabel(string) ///
	CUTLabels(string) ADDRow(string asis) COMPact NOPvalue ///
	pdp(string) highpdp(string) LABELWidth(integer 0) Level(string) ///
	CFormat(string) REFTop CELLNote(string asis) MINCount(string) ///
	TRANSpose EXPOSURELabel(string) CILabel(string) PLabel(string) ///
	ADDCol(string asis) STATLabels(string asis) COLLabels(string asis) ///
	ABSENTLabel(string) CNSLabel(string)]

* digits(), boldp(), highlight(), pdp(), highpdp(), level() and
* mincount() are read as text so that an option not given (-1 below)
* cannot collide with a typed value: with -1 defaults, a typed -1 was
* taken as no option at rc 0. Every typed value is range-checked below.
foreach _nopt in digits boldp highlight pdp highpdp level mincount {
	local _nval = strtrim(`"``_nopt''"')
	if `"`_nval'"' == "" {
		local `_nopt' -1
		continue
	}
	capture confirm number `_nval'
	if _rc {
		noisily display as error "option `_nopt'() incorrectly specified"
		exit 198
	}
	if `_nval' == -1 {
		local _nmsg "between 0 and 6"
		if inlist("`_nopt'", "boldp", "highlight") local _nmsg "between 0 and 1"
		if inlist("`_nopt'", "pdp", "highpdp") local _nmsg "between 1 and 10"
		if "`_nopt'" == "level" local _nmsg "between 0 and 100"
		if "`_nopt'" == "mincount" local _nmsg "a positive integer"
		noisily display as error "`_nopt'() must be `_nmsg'"
		exit 198
	}
	* an integer typed with a decimal point (2.0, 1e0) is accepted, as
	* the integer syntax type did
	if inlist("`_nopt'", "digits", "pdp", "highpdp", "mincount") & `_nval' != int(`_nval') {
		noisily display as error "`_nopt'() must be an integer"
		exit 198
	}
	local `_nopt' = `_nval'
}

* Accept excel() as synonym for xlsx(); two different workbooks are two
* destinations, so the pair is refused rather than one silently dropped.
if `"`xlsx'"' != "" & `"`excel'"' != "" & `"`xlsx'"' != `"`excel'"' {
	noisily display as error "xlsx() and excel() are synonyms; specify one"
	exit 198
}
if "`xlsx'" == "" & "`excel'" != "" local xlsx "`excel'"
if "`nointercept'" != "" & "`keepintercept'" != "" {
	noisily display as error "nointercept and keepintercept cannot be combined"
	exit 198
}
* Session destinations (tabtools set workbook/markdown/latex) apply only when
* sheet() asks for a sheet; an explicit option wins. The same rule as
* crosstab, desctab, and puttab. The first write to the session workbook
* erases it: _tabtools_xlsx_write runs _tabtools_set_sinks xlsxstart on its
* target, and the Markdown writer clears its own flag.
if `"`macval(sheet)'"' != "" {
	_tabtools_set_sinks resolve, xlsx(`"`xlsx'"') markdown(`"`markdown'"') `mdappend' ///
		latex(`"`latex'"') `texappend'
	local xlsx `"`_ss_xlsx'"'
	local markdown `"`_ss_md'"'
	local mdappend "`_ss_mdappend'"
	local latex `"`_ss_tex'"'
	local texappend "`_ss_texappend'"
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
if "`texappend'" != "" & `"`latex'"' == "" {
	noisily display as error "texappend requires latex()"
	exit 198
}
if "`texdocument'" != "" & `"`latex'"' == "" {
	noisily display as error "texdocument requires latex()"
	exit 198
}
if `"`macval(texopts)'"' != "" & `"`latex'"' == "" {
	noisily display as error "texopts() requires latex()"
	exit 198
}
if `"`latex'"' != "" _tabtools_validate_path `"`latex'"' "latex()"
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
local _amb_ratio 0
if "`coef'" == "" {
	local _ecmd `"`e(cmd)'"'
	* stata-dev-ignore: identity-fold — lowered copy is parsed only for the command word and display options; no identity is stored or compared
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
	* A collection without command metadata (collect: on a replay) may hold
	* another display scale than e(cmdline) names: the collected values decide
	* when the active e(b) proves them coefficients or their exponents.
	capture quietly collect levelsof result
	if _rc == 0 & !strpos(" `s(levels)' ", " cmd ") & ///
		!strpos(" `s(levels)' ", " cmdline ") {
		_regtab_ambscale
		local _rs_ratio = `_rs_known' & `_rs_null' == 1
		if "`_ax_state'" == "exp" {
			if `_rs_ratio' local coef `"`_rs_coef'"'
			else local coef "exp(b)"
			local _amb_ratio 1
		}
		else if "`_ax_state'" == "b" & `_rs_ratio' local coef "Coef."
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
	* The star rules assume one, two, and three stars for ever smaller p:
	* any other order, or a level outside (0,1), stars the wrong rows.
	if !(0 < `_sl3' & `_sl3' < `_sl2' & `_sl2' < `_sl1' & `_sl1' < 1) {
		noisily display as error "starslevels() must be three decreasing values between 0 and 1 (e.g., starslevels(0.05 0.01 0.001))"
		exit 198
	}
	if "`stars'" == "" {
		noisily display as error "starslevels() requires stars"
		exit 198
	}
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
* A CI bound takes the estimate's rounding, round(), so one value prints alike
* in both cells: string() alone rounds an exact binary tie (0.125 at 2, 2.25 at
* 1) to even where the estimate rounds it up, and a decimal that is only
* nearly a tie in binary (0.85 at 1) the other way again. Defined after the
* cformat() block: under cformat() coef_round is 0 and round(x, 0) is x.
* A bound that rounds to zero keeps its own text, so a negative one still
* prints as -0.00 and shows the interval crossing zero, as in 2.5.1.
local _ci_lo_r "cond(round(_ci_lo, `coef_round') == 0, _ci_lo, round(_ci_lo, `coef_round'))"
local _ci_hi_r "cond(round(_ci_hi, `coef_round') == 0, _ci_hi, round(_ci_hi, `coef_round'))"

* Resolve formatting
_tabtools_resolve_format, font(`"`font'"') fontsize(`fontsize') fsexplicit borderstyle(`borderstyle') headershade(`headershade') zebra(`zebra')

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
	local _ci_level = strtrim(ustrregexra(string(`_ci_level_num', "%21.15g"), "-(?=[0.,]+\z)", ""))
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
    _tabtools_check_sinks, xlsx(`"`xlsx'"') csv(`"`csv'"') markdown(`"`markdown'"') ///
        latex(`"`latex'"') `texappend' `texdocument' texopts(`macval(texopts)')

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
    * group: the grouping variable of a matched or grouped fit that posts no
    * group count (clogit); stats(groups) needs it to refuse rather than omit.
    _regtab_rlabels cmd cmdline depvar ivars revars redim group `_meta_own'
    local _meta_levels "`_rl_present'"
    capture {
        collect layout (cmdset) (result[`_meta_levels'])
    }
    local _meta_layout_rc = _rc
    if "`_meta_levels'" == "" local _meta_layout_rc = 111
    if `_meta_layout_rc' == 0 {
        preserve
        * stata-dev-ignore: capture-rc — a braced capture stops at its first error; _rc is read on the first line after the closing brace
        capture {
            _tabtools_collect_render, type(meta) rowdim(cmdset) ///
                results(`_meta_levels') dropempty

            local meta_col_cmd ""
            local meta_col_cmdline ""
            local meta_col_depvar ""
            local meta_col_ivars ""
            local meta_col_revars ""
            local meta_col_redim ""
            local meta_col_group ""
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
                if "`meta_col_group'" != "" {
                    local model_groupvar_`m' = strtrim(`meta_col_group'[`r'])
                }
                else local model_groupvar_`m' ""
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
            * stata-dev-ignore: identity-fold — _cmdline_lc is a lowered working copy for classification; the identity model_cmdline_# is kept as typed
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
            local model_known_`m' = `_rs_known'
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
        * proven ratios (see _regtab_ambscale): the intercept is hidden by
        * default, as for every ratio family with metadata
        if !`_user_noint_spec' & "`keepintercept'" == "" & `_amb_ratio' {
            local nointercept "nointercept"
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
            * stata-dev-ignore: hardcoded-tempname — column of the rendered frame inside preserve, discarded by restore; its name is the contract with _regtab_eqkeys
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
                * Every equation that holds a regression, scale (lnsigma) or
                * intercept term counts, not only those named for an outcome:
                * an equation of _cons alone (gnbreg's lnalpha:, betareg's
                * scale:, cmclogit's alternative intercepts) or of lnsigma
                * terms (hetprobit, intreg het()) shares colnames with the
                * main equation, and the colname layout would merge the rows.
                * The "/" and _diparm equations are ancillary, never counted.
                if inlist("`_role'", "reg", "scale", "cons") & `"`_eq'"' != "" ///
                    & `"`_eq'"' != "/" & !regexm(`"`_eq'"', "^_diparm") ///
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
    if _rc noisily display as text "(regtab: could not return to collection `_smr_orig')"
    capture quietly collect drop `_smr_coll'
    if _rc noisily display as text "(regtab: could not drop its temporary collection `_smr_coll')"
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

* A random-effects row is known by its raw coefficient name (var(), cov(),
* sd(), corr()), the structural role _regtab_role assigns, never by its
* display label: a covariate labelled "BMI per sd(5)" is a fixed effect, kept
* by nore, exponentiated under a ratio header, and left in place.
gen byte _is_re = _n > 2 & ustrregexm(strtrim(_raw_colname), "^(var|cov|sd|corr)\(")

if "`nore'" != "" {
	drop if _is_re
}

* Reorder: fixed effects first, then random effects (collect may interleave them)
gen _orig_order = _n
sort _is_re _orig_order
drop _orig_order

* The RE markers persist so keep()/drop() cannot desynchronize them from the
* filtered table body later in the pipeline.
gen byte _is_re_intercept = 0
gen str244 _re_group_label = ""
if "`re_transform'" != "none" & "`nore'" == "" {
    replace _is_re_intercept = _is_re & strpos(A, "var(_cons") > 0 if _n > 2
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

* A collection without per-model metadata (collect: on a replay, which
* collects r(table) alone) keeps a constrained cell's missing interval and
* p-value as "(., .)" and "."; a fit's own collection leaves them empty. Both
* missing is the same cell as both empty.
if `_meta_models' == 0 {
    forvalues _m = 1/`n_models' {
        local _cb = 3 * `_m' - 2
        capture confirm variable c`=`_cb' + 2'
        if _rc continue
        quietly replace c`=`_cb' + 1' = "" if _n >= 3 & strtrim(c`_cb') != "" ///
            & ustrregexm(c`=`_cb' + 1', "^\s*\(\s*\.\s*~\|\s*\.\s*\)\s*$") ///
            & inlist(strtrim(c`=`_cb' + 2'), "", ".")
        quietly replace c`=`_cb' + 2' = "" if _n >= 3 & strtrim(c`_cb') != "" ///
            & strtrim(c`=`_cb' + 1') == "" & strtrim(c`=`_cb' + 2') == "."
    }
}

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

if `"`macval(models)'"' != "" {
    * Split on backslashes in Mata, so a label keeps its double quotes and
    * backticks as typed (tokenize stripped every pair of double quotes, so
    * models(`"Adj "full" \ B"') printed Adj full). Each label is trimmed of
    * blanks; a label wholly enclosed in "..." or `"..."' loses that wrapper
    * only, as before. Empty labels (\ \) are skipped, as before.
    mata: _regtab_mtok = tokeninit("", char(92), "")
    mata: tokenset(_regtab_mtok, st_local("models"))
    mata: _regtab_mdl = strtrim(tokengetall(_regtab_mtok))
    mata: _regtab_mdl = select(_regtab_mdl, (_regtab_mdl :!= char(92)) :& (_regtab_mdl :!= ""))
    mata: for (_regtab_mi = 1; _regtab_mi <= cols(_regtab_mdl); _regtab_mi++) { ///
        _regtab_ms = _regtab_mdl[_regtab_mi]; ///
        if (strlen(_regtab_ms) >= 4 & substr(_regtab_ms, 1, 2) == char(96) + char(34) & substr(_regtab_ms, -2, 2) == char(34) + char(39)) _regtab_mdl[_regtab_mi] = substr(_regtab_ms, 3, strlen(_regtab_ms) - 4); ///
        else if (strlen(_regtab_ms) >= 2 & substr(_regtab_ms, 1, 1) == char(34) & substr(_regtab_ms, -1, 1) == char(34) & !strpos(substr(_regtab_ms, 2, strlen(_regtab_ms) - 2), char(34))) _regtab_mdl[_regtab_mi] = substr(_regtab_ms, 2, strlen(_regtab_ms) - 2); ///
    }
    mata: st_local("_ml_n", strofreal(cols(_regtab_mdl)))
    * Count the labels first: more labels than models has no column to go
    * to (it ran off the table as "variable c# not found"), and is refused.
    if `_ml_n' > `n_models' {
        capture mata: mata drop _regtab_mdl _regtab_mtok _regtab_mi _regtab_ms
        noisily display as error "models() has `_ml_n' labels for `n_models' model" ///
            cond(`n_models' == 1, "", "s") "; give at most one label per model"
        restore
        exit 198
    }
    local col_idx = 1
    forvalues _mi = 1/`_ml_n' {
        * st_sstore() cuts to the variable's width; widen it first
        mata: st_local("_mlen", strofreal(strlen(_regtab_mdl[`_mi'])))
        local _mtyp : type c`col_idx'
        if "`_mtyp'" != "strL" {
            if `_mlen' > real(substr("`_mtyp'", 4, .)) {
                if `_mlen' <= 2045 recast str`_mlen' c`col_idx'
                else recast strL c`col_idx'
            }
        }
        mata: st_sstore(1, "c`col_idx'", _regtab_mdl[`_mi'])
        local col_idx = `col_idx' + 3
    }
    capture mata: mata drop _regtab_mdl _regtab_mtok _regtab_mi _regtab_ms
    * Fewer labels than models: the models after the last label take the
    * automatic "Model #" header rather than an empty one.
    forvalues _mi = `=`_ml_n' + 1'/`n_models' {
        replace c`col_idx' = "Model `_mi'" if _n == 1
        local col_idx = `col_idx' + 3
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
        * an interaction row is matched on its raw key while it still shows
        * collect's default text ("0.foreign#weight" for 0.foreign#c.weight),
        * so a label the caller set on the collection is kept
        local _fv_dflt = ustrregexra(`"`_fvrow_pat_`_fvi''"', "(^|#)c\.", "$1")
        replace A = `"`macval(_fvrow_lab_`_fvi')'"' ///
            if (strtrim(A) == `"`_fvrow_pat_`_fvi''"' | ///
            (strtrim(_raw_A) == `"`_fvrow_pat_`_fvi''"' & strtrim(A) == `"`_fv_dflt'"')) & _n >= 3
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
* A command without a scale rule (no dedicated rule, no eform display option)
* may still display ratios by default; its scale is not known either.
if `_model_ix' <= `_meta_models' {
	if `model_known_`_model_ix'' {
		local _base_val = cond(`_needs_eform', 0, `model_null_`_model_ix'')
		local _base_cond "c`i'z == `_base_val'"
	}
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
gen str64 c`i'_fmt = strtrim(ustrregexra(string(round(c`i'z, `coef_round'), "`coef_fmt'"), "-(?=[0.,]+\z)", "")) if !_is_re & !missing(c`i'z)
* Transformed random intercept (MOR/MHR): same precision as fixed effects
replace c`i'_fmt = strtrim(ustrregexra(string(round(c`i'z, `coef_round'), "`coef_fmt'"), "-(?=[0.,]+\z)", "")) ///
    if _is_re_intercept == 1 & "`re_transform'" != "none" & !missing(c`i'z)
* Other random effects: same decimal places as fixed effects
replace c`i'_fmt = strtrim(ustrregexra(string(round(c`i'z, `coef_round'), "`coef_fmt'"), "-(?=[0.,]+\z)", "")) ///
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
    replace _ci_fmt = "(" + strtrim(ustrregexra(string(`_ci_lo_r', "`ci_fmt'"), "-(?=[0.,]+\z)", "")) + _ci_sepv + strtrim(ustrregexra(string(`_ci_hi_r', "`ci_fmt'"), "-(?=[0.,]+\z)", "")) + ")" ///
        if !_is_re & !missing(_ci_lo) & !missing(_ci_hi) & _n >= 3
    * Transformed random intercept (MOR/MHR): same precision as fixed effects
    replace _ci_fmt = "(" + strtrim(ustrregexra(string(`_ci_lo_r', "`ci_fmt'"), "-(?=[0.,]+\z)", "")) + _ci_sepv + strtrim(ustrregexra(string(`_ci_hi_r', "`ci_fmt'"), "-(?=[0.,]+\z)", "")) + ")" ///
        if _is_re_intercept == 1 & "`re_transform'" != "none" & !missing(_ci_lo) & !missing(_ci_hi) & _n >= 3
    * Other random effects: same decimal places as fixed effects
    replace _ci_fmt = "(" + strtrim(ustrregexra(string(`_ci_lo_r', "`ci_fmt'"), "-(?=[0.,]+\z)", "")) + _ci_sepv + strtrim(ustrregexra(string(`_ci_hi_r', "`ci_fmt'"), "-(?=[0.,]+\z)", "")) + ")" ///
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
	* boldp() and highlight() decide on this same numeric p as the stars,
	* not on the rounded display string (p = 0.0497 prints 0.050 under
	* pdp(3) but is below 0.05 for all three). It moves with its row.
	if `has_boldp' | `has_highlight' {
		quietly generate double _bpn`_model_ix' = c`i'z if _n >= 3
	}
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
replace c`i'_fmt = "<" + ustrregexra(string(`_pmin', "`_pfmt_lo'"), "-(?=[0.,]+\z)", "") if c`i'z < `_pmin' & !missing(c`i'z)
replace c`i'_fmt = ustrregexra(string(c`i'z, "`_pfmt_lo'"), "-(?=[0.,]+\z)", "") if c`i'z >= `_pmin' & c`i'z < 0.10 & !missing(c`i'z)
replace c`i'_fmt = ustrregexra(string(c`i'z, "`_pfmt_hi'"), "-(?=[0.,]+\z)", "") if c`i'z >= 0.10 & !missing(c`i'z)
replace c`i'_fmt = ">" + ustrregexra(string(`_pmax', "`_pfmt_hi'"), "-(?=[0.,]+\z)", "") if c`i'z > `_pmax' & c`i'z < 1 & !missing(c`i'z)
replace c`i'_fmt = "<" + ustrregexra(string(`_pmin', "`_pfmt_lo'"), "-(?=[0.,]+\z)", "") if c`i'z == 0 & !missing(c`i'z)
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
	            * stata-dev-ignore: capture-rc — preset to missing above; a model without this column keeps the missing value
	            capture local _ep_est = _eplot_est`_ep_m'[`_ep_obs']
	            * stata-dev-ignore: capture-rc — preset to missing above; a model without this column keeps the missing value
	            capture local _ep_ll = _eplot_ll`_ep_m'[`_ep_obs']
	            * stata-dev-ignore: capture-rc — preset to missing above; a model without this column keeps the missing value
	            capture local _ep_ul = _eplot_ul`_ep_m'[`_ep_obs']
	            * stata-dev-ignore: capture-rc — preset to missing above; a model without this column keeps the missing value
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
    * stata-dev-ignore: capture-rc — row names are cosmetic; on failure r(table) keeps its default row names
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
            * the numeric p of a shown p-value cell (a masked, noted, added,
            * or statistics row shows none and is never flagged)
            local _bp_m`_m'_r`_dr'_num = .
            if `"`_bp_m`_m'_r`_dr''"' != "" {
                capture confirm variable _bpn`_m'
                * stata-dev-ignore: double-macro-transport — the macro keeps 17 significant digits, which only a p equal to the threshold to that precision could tie
                if !_rc local _bp_m`_m'_r`_dr'_num = _bpn`_m'[`_dr']
            }
        }
    }
}
capture drop _bpn*

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
* (the table strings are formatted to %20.2f / %5.3f) for downstream use and
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
        if `want_obs'      & !missing(`stat_obs_`m'')      return scalar obs_`m'      = `stat_obs_`m''
        if `want_events'   & !missing(`stat_events_`m'')   return scalar events_`m'   = `stat_events_`m''
        if `want_people'   & !missing(`stat_people_`m'')   return scalar people_`m'   = `stat_people_`m''
        if `want_exposure' & !missing(`stat_exposure_`m'') return scalar exposure_`m' = `stat_exposure_`m''
        if `want_mi_m'     & !missing(`stat_mi_m_`m'')     return scalar mi_m_`m'     = `stat_mi_m_`m''
        if `want_r2_a'     & !missing(`stat_r2_a_`m'')     return scalar r2_a_`m'     = `stat_r2_a_`m''
        if `want_rmse'     & !missing(`stat_rmse_`m'')     return scalar rmse_`m'     = `stat_rmse_`m''
        if `want_F'        & !missing(`stat_F_`m'')        return scalar F_`m'        = `stat_F_`m''
        if `want_fmi'      & !missing(`stat_fmi_`m'')      return scalar fmi_`m'      = `stat_fmi_`m''
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

* LaTeX export. It runs before the Markdown block below, so it sees the table
* as the workbook shows it, never the flattened "Model: statistic" row. LaTeX
* keeps both header levels: row 2 (model names, or a transposed table's terms)
* over row 3 (statistic labels), body from row 4. Each model's name spans its
* own block of _cols_per_model columns, the range the workbook merges in row 2;
* a one-column block (compact nopvalue, transpose) is a plain cell, as a
* one-cell merge is in the workbook. Visible column 1 is the label column A,
* so block m covers visible columns (m-1)*_cols_per_model+2 .. m*_cols_per_model+1.
* A row 2 empty in every column drops to a single header row.
local _ret_latex ""
local _ret_latex_rows .
local _ret_latex_cols .
if `"`latex'"' != "" {
	local _texdocument_opt ""
	if "`texdocument'" != "" local _texdocument_opt "document"
	local _texappend_opt ""
	if "`texappend'" != "" local _texappend_opt "append"
	local _tex_hs 3
	local _tex_spans ""
	if _N >= 3 {
		forvalues _texc = 1/`n' {
			capture confirm variable c`_texc'
			if !_rc {
				if strtrim(c`_texc'[2]) != "" local _tex_hs 2
			}
		}
	}
	if `_tex_hs' == 2 & `_cols_per_model' > 1 {
		forvalues _texb = 1/`_n_blocks' {
			local _tex_first = (`_texb' - 1) * `_cols_per_model' + 1
			capture confirm variable c`_tex_first'
			if !_rc {
				if strtrim(c`_tex_first'[2]) != "" {
					local _tex_spans "`_tex_spans' 2 `=`_tex_first' + 1' `=`_tex_first' + `_cols_per_model''"
				}
			}
		}
	}
	local _tex_spans_opt ""
	if "`_tex_spans'" != "" local _tex_spans_opt "spans(`_tex_spans')"
	capture noisily _tabtools_latex_write using `"`latex'"', ///
		`_texappend_opt' `_texdocument_opt' texopts(`macval(texopts)') labelvar(A) title(`"`macval(title)'"') footnote(`"`macval(footnote)'"') ///
		headerstart(`_tex_hs') datastart(4) strictheaders `_tex_spans_opt'
	if _rc {
		local _tex_rc = _rc
		noisily display as error "Failed to export LaTeX to `latex'"
		restore
		exit `_tex_rc'
	}
	local _ret_latex `"`latex'"'
	local _ret_latex_rows = r(n_rows)
	local _ret_latex_cols = r(n_cols)
	noisily display as text "LaTeX exported to `latex'"
}

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
	if `"`_ret_latex'"' != "" {
	return local latex `"`_ret_latex'"'
	return scalar latex_rows = `_ret_latex_rows'
	return scalar latex_cols = `_ret_latex_cols'
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
* (the numeric p of each shown p-value cell was saved with its string above)

local _n_nonsig_entries 0
if "`dimnonsig'" != "" {
	forvalues _dr = 4/`num_rows' {
		capture local _ns_`_dr' = `_nonsig_v`_dr''
		if _rc local _ns_`_dr' = 0
	}
}

* All formatting in a single shared style-rule backend call
* stata-dev-ignore: capture-rc — a braced capture stops at its first error; _rc is read on the first line after the closing brace
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
	* stata-dev-ignore: capture-rc — cleanup after the failing rc was saved in saved_rc
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
    noisily _tabtools_export_done using `"`xlsx'"', sheet(`"`macval(sheet)'"')
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
    capture mata: mata drop _regtab_mdl _regtab_mtok _regtab_mi _regtab_ms
	    foreach _nsx in N V O I {
	        capture mata: mata drop _regtab_ns`_nsx'
	    }
	    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end

* =============================================================================
* _regtab_ambscale: scale of a metadata-less collection, from the active e(b)
* =============================================================================
* A collection with no cmd or cmdline result (collect: on a replay, which
* collects r(table) alone) does not say how the command displayed it: the
* active e(cmdline) is the original fit's, whose display options a replay can
* change (logit, or). The collected _r_b are compared with the active e(b):
* every collected coefficient that e(b) also holds equal to its exponent
* (reldif < 1e-12) means the collection holds ratios ("exp"), every one equal
* to its coefficient means coefficients ("b"); anything else ("") leaves the
* scale unproven. Returns _ax_state in the caller.
capture program drop _regtab_ambscale
program define _regtab_ambscale, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	local _st ""
	capture noisily {
		capture confirm matrix e(b)
		if !_rc {
			tempfile _cjf
			local _cjs `"`_cjf'.stjson"'
			quietly collect save `"`_cjs'"', replace
			mata: _rt_ax_L = cat(st_local("_cjs"))
			mata: _rt_ax_h = selectindex(ustrregexm(_rt_ax_L, `"[#"]result\[_r_b\][#"]"'))
			mata: _rt_ax_kk = _rt_ax_L[_rt_ax_h]
			mata: _rt_ax_d = rows(_rt_ax_h) ? strtoreal(ustrregexra(_rt_ax_L[_rt_ax_h :+ 1], `"^\s*"d":\s*([^,]*),?\s*$"', "$1")) : J(0, 1, .)
			mata: _rt_ax_ce = ustrregexra(_rt_ax_kk, `"^.*[#"]coleq\[([^\]]*)\][#"].*$"', "$1") :* ustrregexm(_rt_ax_kk, `"[#"]coleq\["')
			mata: _rt_ax_cn = ustrregexra(_rt_ax_kk, `"^.*?[#"]colname\[(.+?)\][#"].*$"', "$1")
			mata: _rt_ax_s = st_matrixcolstripe("e(b)")
			mata: _rt_ax_b = st_matrix("e(b)")'
			mata: _rt_ax_bn = ustrregexra(ustrregexra(_rt_ax_s[., 2], "(^|#)([0-9]+)[a-z]+\.", "$1$2."), "(^|#)co?\.", "$1")
			mata: _rt_ax_q = all((_rt_ax_s[., 1] :== "") :| (_rt_ax_s[., 1] :== "_"))
			mata: _rt_ax_bk = _rt_ax_q ? _rt_ax_bn : (_rt_ax_s[., 1] :+ ":" :+ _rt_ax_bn)
			mata: _rt_ax_ck = _rt_ax_q ? _rt_ax_cn : (_rt_ax_ce :+ ":" :+ _rt_ax_cn)
			mata: _rt_ax_m = 0; _rt_ax_nb = 0; _rt_ax_ne = 0
			mata: for (_rt_ax_j = 1; _rt_ax_j <= rows(_rt_ax_bk); _rt_ax_j++) { _rt_ax_i = selectindex(_rt_ax_ck :== _rt_ax_bk[_rt_ax_j]); if (rows(_rt_ax_i) != 1) continue; if (missing(_rt_ax_d[_rt_ax_i]) | missing(_rt_ax_b[_rt_ax_j])) continue; _rt_ax_m++; if (reldif(_rt_ax_d[_rt_ax_i], _rt_ax_b[_rt_ax_j]) < 1e-12) _rt_ax_nb++; else if (reldif(_rt_ax_d[_rt_ax_i], exp(_rt_ax_b[_rt_ax_j])) < 1e-12) _rt_ax_ne++; }
			mata: st_local("_st", _rt_ax_m == 0 ? "" : (_rt_ax_ne == _rt_ax_m ? "exp" : (_rt_ax_nb == _rt_ax_m ? "b" : "")))
			capture mata: mata drop _rt_ax_*
			capture erase `"`_cjs'"'
		}
		c_local _ax_state "`_st'"
	}
	local _rc = _rc
	* also on the error path: no Mata globals or collection file left behind
	capture mata: mata drop _rt_ax_*
	if `"`_cjs'"' != "" capture erase `"`_cjs'"'
	capture mata: mata drop _rt_ax_*
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* Folded from _tabtools_match_rows.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _tabtools_match_rows Version 1.2.0  2026/11/19
* Match raw coefficient identities and factor components
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

capture program drop _tabtools_match_rows
program define _tabtools_match_rows, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varname(string), GENerate(name) TERMS(string)
        confirm new variable `generate'
        quietly generate byte `generate' = 0
        mata: _tabtools_match_rows_mata(st_local("varlist"), ///
            st_local("generate"), st_local("terms"))
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture mata: mata drop _tabtools_match_rows_mata()
capture mata: mata drop _tabtools_match_normalize()

* matastrict is a session setting: save the caller's value here and
* restore it after the block, so loading this file never leaks it.
local _tt_ms0 = c(matastrict)
mata:
mata set matastrict on

// Normalize only factor operators, leaving identifiers and numeric levels
// intact. For example, 2b.arm#c.age becomes 2.arm#age, never arm#age.
string scalar _tabtools_match_normalize(string scalar term)
{
    string rowvector parts
    string scalar part, prefix, suffix
    real scalar j, dot
    parts = tokens(subinstr(term, "#", " "))
    for (j = 1; j <= cols(parts); j++) {
        part = parts[j]
        dot = strpos(part, ".")
        if (dot > 0) {
            prefix = substr(part, 1, dot - 1)
            suffix = substr(part, dot + 1, .)
            if (regexm(prefix, "^(i|c|o|b|bn|ib[0-9]+|ibn)$")) part = suffix
            else if (regexm(prefix, "^([0-9]+)(b|bn|o)$")) {
                part = regexs(1) + "." + suffix
            }
        }
        parts[j] = part
    }
    return(invtokens(parts, "#"))
}

void _tabtools_match_rows_mata(string scalar rawvar,
    string scalar matchvar, string scalar spec)
{
    string colvector raw
    real colvector matched
    string rowvector terms, parts
    string scalar term, key, component
    real scalar i, j, k, dot
    raw = st_sdata(., rawvar)
    st_view(matched, ., matchvar)
    terms = tokens(spec)
    for (j = 1; j <= cols(terms); j++) {
        terms[j] = _tabtools_match_normalize(terms[j])
    }
    for (i = 1; i <= rows(raw); i++) {
        if (raw[i] == "") continue
        key = _tabtools_match_normalize(strtrim(raw[i]))
        parts = tokens(subinstr(key, "#", " "))
        for (j = 1; j <= cols(terms); j++) {
            term = terms[j]
            if (key == term) matched[i] = 1
            if (strpos(term, "#")) continue
            for (k = 1; k <= cols(parts); k++) {
                component = parts[k]
                if (component == term) matched[i] = 1
                // A bare variable selects its levels and interactions. An
                // explicit level (2.arm) cannot select another level (20.arm).
                dot = strpos(component, ".")
                if (dot > 0 & !strpos(term, ".")) {
                    if (regexm(substr(component, 1, dot - 1), "^[0-9]+$") &
                        substr(component, dot + 1, .) == term) matched[i] = 1
                }
            }
        }
    }
}
end
mata: mata set matastrict `_tt_ms0'

* Folded from _regtab_activeb.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_activeb Version 1.2.0  2026/11/19
* constraint notes of a collected model that is the active fit
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* =============================================================================
* _regtab_activeb: the fit's own notes from the active e(b), when it is the model
* =============================================================================
* Usage: _regtab_activeb <cmdset level> `"<command line>"'
* The collection keeps no b./o. markers (collect's own "omit-type" class is
* "empty" for every constrained cell of some fits). When the active
* estimation results are exactly the collected model - the same command line,
* and every e(b) coefficient the collection also holds equal to its collected
* _r_b (or its exponent) to reldif < 1e-12, the identity tabtools fitcount
* checks - its e(b) column stripe is the fit's own record. Returns in the
* caller:
*   _ab_ok     1 when the active fit is the model, else 0
*   _ab_notes  when _ab_ok, the notes of _regtab_bnotes: key=b|e|o|c tokens
*              for the base, empty, omitted, and constrained coefficients
capture program drop _regtab_activeb
program define _regtab_activeb, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	gettoken _k 0 : 0
	gettoken _cl 0 : 0
	local _ok = 0
	local _notes ""
	capture noisily {
		capture confirm matrix e(b)
		local _hasb = !_rc
		if `_hasb' & `"`e(cmdline)'"' == `"`_cl'"' & `"`_cl'"' != "" {
			tempfile _cjf
			local _cjs `"`_cjf'.stjson"'
			quietly collect save `"`_cjs'"', replace
			mata: _rt_ab_L = cat(st_local("_cjs"))
			mata: _rt_ab_h = selectindex(ustrregexm(_rt_ab_L, `"[#"]cmdset\[`_k'\][#"]"') :& ustrregexm(_rt_ab_L, `"[#"]result\[_r_b\][#"]"'))
			mata: _rt_ab_kk = _rt_ab_L[_rt_ab_h]
			mata: _rt_ab_d = rows(_rt_ab_h) ? strtoreal(ustrregexra(_rt_ab_L[_rt_ab_h :+ 1], `"^\s*"d":\s*([^,]*),?\s*$"', "$1")) : J(0, 1, .)
			mata: _rt_ab_ce = ustrregexra(_rt_ab_kk, `"^.*[#"]coleq\[([^\]]*)\][#"].*$"', "$1") :* ustrregexm(_rt_ab_kk, `"[#"]coleq\["')
			mata: _rt_ab_cn = ustrregexra(_rt_ab_kk, `"^.*?[#"]colname\[(.+?)\][#"].*$"', "$1")
			mata: _rt_ab_s = st_matrixcolstripe("e(b)")
			mata: _rt_ab_b = st_matrix("e(b)")'
			mata: _rt_ab_bn = ustrregexra(ustrregexra(_rt_ab_s[., 2], "(^|#)([0-9]+)[a-z]+\.", "$1$2."), "(^|#)co?\.", "$1")
			mata: _rt_ab_q = all((_rt_ab_s[., 1] :== "") :| (_rt_ab_s[., 1] :== "_"))
			mata: _rt_ab_bk = _rt_ab_q ? _rt_ab_bn : (_rt_ab_s[., 1] :+ ":" :+ _rt_ab_bn)
			mata: _rt_ab_ck = _rt_ab_q ? _rt_ab_cn : (_rt_ab_ce :+ ":" :+ _rt_ab_cn)
			mata: _rt_ab_m = 0; _rt_ab_x = 0
			mata: for (_rt_ab_j = 1; _rt_ab_j <= rows(_rt_ab_bk); _rt_ab_j++) { _rt_ab_i = selectindex(_rt_ab_ck :== _rt_ab_bk[_rt_ab_j]); if (rows(_rt_ab_i) != 1) continue; if (missing(_rt_ab_d[_rt_ab_i])) continue; _rt_ab_m++; if (!(reldif(_rt_ab_d[_rt_ab_i], _rt_ab_b[_rt_ab_j]) < 1e-12 | reldif(_rt_ab_d[_rt_ab_i], exp(_rt_ab_b[_rt_ab_j])) < 1e-12)) _rt_ab_x++; }
			mata: st_local("_m", strofreal(_rt_ab_m)); st_local("_x", strofreal(_rt_ab_x))
			capture mata: mata drop _rt_ab_*
			capture erase `"`_cjs'"'
			if `_m' > 0 & `_x' == 0 {
				local _ok = 1
				_regtab_bnotes
				local _notes `"`_bn_notes'"'
			}
		}
		c_local _ab_ok `_ok'
		c_local _ab_notes `"`_notes'"'
	}
	local _rc = _rc
	capture mata: mata drop _rt_ab_*
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* Folded from _regtab_addcol.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_addcol Version 1.2.0  2026/11/19
* addcol() columns of a transposed table
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* =============================================================================
* _regtab_addcol: addcol() columns of a transposed table
* =============================================================================
* Usage: _regtab_addcol <n> <models> `"<spec>"' `"<keys>"'
* addcol("label" val1 val2 ... [, after(term)] [\ ...]): addrow()'s
* specification for a transposed table, one column per specification after
* column c<n>, the label as its header (row 1) and the values given to the
* models (rows 3 on) in order. after(term) places the column after the last
* column of coefficient term (its raw name, as keep() takes it), after any
* column already placed there; <keys> holds each column's raw name ("." for
* a statistic). Returns the new column count in _ac_n in the caller.
* Labels and values are data: copied with macval() and copy local, written
* to the dataset through Mata, never re-expanded ($name, a backquote).
capture program drop _regtab_addcol
program define _regtab_addcol, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	gettoken n 0 : 0
	gettoken n_models 0 : 0
	gettoken _ac_rest 0 : 0
	gettoken _ac_keys 0 : 0
	capture noisily {
		_regtab_unwrap `"`macval(_ac_rest)'"'
		local _ac_rest : copy local _uw_spec
		while `"`macval(_ac_rest)'"' != "" {
			mata: st_local("_bs_pos", strofreal(strpos(st_local("_ac_rest"), char(92))))
			if `_bs_pos' > 0 {
				mata: st_local("_ac_chunk", substr(st_local("_ac_rest"), 1, `_bs_pos' - 1))
				mata: st_local("_ac_rest", substr(st_local("_ac_rest"), `_bs_pos' + 1, .))
			}
			else {
				local _ac_chunk : copy local _ac_rest
				local _ac_rest ""
			}
			mata: st_local("_ac_chunk", strtrim(st_local("_ac_chunk")))
			if `"`macval(_ac_chunk)'"' == "" continue
			gettoken _ac_label _ac_vals : _ac_chunk
			mata: st_local("_ac_label", _tt_strip_outer_quotes(st_local("_ac_label")))
			* placement: a trailing ", after(term)", as in addrow()
			local _ac_after ""
			local _ac_pos = 0
			mata: st_local("_ac_hasaf", strofreal(ustrregexm(st_local("_ac_vals"), "^(.*),[ ]*after\(([^()]*)\)[ ]*$")))
			if `_ac_hasaf' {
				mata: st_local("_ac_after", strtrim(ustrregexs(2))); st_local("_ac_vals", ustrregexs(1))
				* keep()'s form: c. and level markers (1b.) do not matter
				local _ac_after = ustrregexra(ustrregexra(`"`_ac_after'"', "(^|#)c\.", "$1"), ///
					"(^|#)([0-9]+)[a-z]+\.", "$1$2.")
				local _ac_j = 0
				foreach _ac_k of local _ac_keys {
					local ++_ac_j
					local _ac_kn = ustrregexra(ustrregexra(`"`_ac_k'"', "(^|#)c\.", "$1"), ///
						"(^|#)([0-9]+)[a-z]+\.", "$1$2.")
					if `"`_ac_kn'"' == `"`_ac_after'"' | `"`_ac_k'"' == `"+`_ac_after'"' local _ac_pos = `_ac_j'
				}
				if `_ac_pos' == 0 {
					display as error `"addcol(): after(`_ac_after') matches no column of the transposed table (give a raw coefficient name, as keep() takes it)"'
					exit 198
				}
			}
			local ++n
			quietly generate str244 c`n' = ""
			quietly replace c`n' = `"`macval(_ac_label)'"' in 1
			if `_ac_pos' > 0 {
				* move the new column right after column c<pos>
				rename c`n' _ac_new
				forvalues _j = `=`n' - 1'(-1)`=`_ac_pos' + 1' {
					rename c`_j' c`=`_j' + 1'
				}
				rename _ac_new c`=`_ac_pos' + 1'
				order c*, sequential after(A)
				local _ac_k2 ""
				local _ac_j = 0
				foreach _ac_k of local _ac_keys {
					local ++_ac_j
					local _ac_k2 `"`_ac_k2' `_ac_k'"'
					if `_ac_j' == `_ac_pos' local _ac_k2 `"`_ac_k2' +`_ac_after'"'
				}
				local _ac_keys `"`_ac_k2'"'
				local _ac_col = `_ac_pos' + 1
			}
			else {
				local _ac_keys `"`_ac_keys' ."'
				local _ac_col = `n'
			}
			local _ac_m = 0
			mata: st_local("_ac_vals", strtrim(st_local("_ac_vals")))
			while `"`macval(_ac_vals)'"' != "" {
				gettoken _ac_v _ac_vals : _ac_vals
				local ++_ac_m
				if `_ac_m' > `n_models' {
					* one as-error string: under regtab's quietly an "as result"
					* segment is not shown, which printed an empty label
					noisily display as error `"addcol(): "`macval(_ac_label)'" has more values than the `n_models' models"'
					exit 198
				}
				quietly replace c`_ac_col' = `"`macval(_ac_v)'"' in `=2 + `_ac_m''
			}
		}
		c_local _ac_n `n'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* Folded from _regtab_addrow.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_addrow Version 1.2.0  2026/11/19
* regtab block: addrow() rows, appended or placed inside a factor block
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end, so
* it reads and writes regtab's locals exactly as before. regtab calls it as
* "noisily _regtab_addrow" from inside its quietly block and the body is quietly
* again, so only the block's own noisily lines print. Data in memory, frames,
* and the collection are shared state and need no transport.
capture program drop _regtab_addrow
program define _regtab_addrow, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
* =========================================================================
* ADD CUSTOM ROWS (addrow option)
* =========================================================================
* addrow("label" val1 val2 ... [, after(term)] [\ ...]): one row per
* specification, its values in the models' estimate columns in order. A
* row without after() is appended below the table body (and any stats()
* rows). after(term) places it inside the body instead, right after the
* coefficient row whose raw name is term (exact and case-sensitive, as
* keep() matches: after(1.drug), after(age)), or, when term is a factor
* variable, after the last level of that factor's block (after(drug)).
* Several rows after one anchor keep their order. An inserted row takes the
* indentation of the row it follows. A term that matches no row, several
* rows, or several blocks of one factor is an error (r(198)).
local addrow_rows = ""
local _ar_in_rows = ""
if `"`macval(addrow)'"' != "" {
    * Split on backslash to get individual rows
    local _ar_rest : copy local addrow
    * A specification wrapped whole in one more layer of quotes (addrow(`"`spec'"')
    * from a program) is unwrapped: it used to become one row labelled with
    * the whole specification.
    _regtab_unwrap `"`macval(_ar_rest)'"'
    local _ar_rest : copy local _uw_spec
    * The coefficient rows an after() can name, and each row's factor block.
    local _ar_end = _N
    if `stats_start_row' > 0 local _ar_end = `stats_start_row' - 1
    quietly generate double _ar_ord = _n
    quietly generate str244 _ar_par = ""
    * raw names in keep()'s form: c. and the b/o/n markers of a level dropped,
    * so after(1.foreign#c.mpg) and after(1b.rep78) name the row keep() would
    quietly generate str244 _ar_nk = ustrregexra(ustrregexra(strtrim(_raw_A), ///
        "(^|#)c\.", "$1"), "(^|#)([0-9]+)[a-z]+\.", "$1$2.")
    forvalues _rr = 3/`_ar_end' {
        local _rt_key = strtrim(_raw_A[`_rr'])
        if `"`_rt_key'"' == "" continue
        _regtab_fvparent `"`_rt_key'"'
        if `"`_fp_parent'"' != "" quietly replace _ar_par = `"`_fp_parent'"' in `_rr'
    }
    local _ar_ins = 0
    local _ar_spec = 0
    while `"`macval(_ar_rest)'"' != "" {
        * Split on backslash using string position (gettoken + parse
        * breaks quoted strings — it returns "P trend" as a separate
        * token from "0.032 0.041" instead of keeping them together)
        local _bs_pos = strpos(`"`macval(_ar_rest)'"', "\")
        if `_bs_pos' > 0 {
            local _ar_chunk = substr(`"`macval(_ar_rest)'"', 1, `_bs_pos' - 1)
            local _ar_rest = substr(`"`macval(_ar_rest)'"', `_bs_pos' + 1, .)
        }
        else {
            local _ar_chunk : copy local _ar_rest
            local _ar_rest ""
        }
        local _ar_chunk = strtrim(`"`macval(_ar_chunk)'"')
        if `"`macval(_ar_chunk)'"' == "" continue

        * Parse the chunk: first token is the label (quoted OK), rest are values
        gettoken _ar_label _ar_vals : _ar_chunk
        * Remove one balanced outer quote layer; embedded quotation marks are data.
        mata: st_local("_ar_label", _tt_strip_outer_quotes(st_local("_ar_label")))
        * placement: a trailing ", after(term)" after the values
        local _ar_after ""
        local _ar_hasafter = ustrregexm(`"`macval(_ar_vals)'"', "^(.*),[ ]*after\(([^()]*)\)[ ]*$")
        if `_ar_hasafter' {
            local _ar_after = strtrim(ustrregexs(2))
            local _ar_vals = ustrregexs(1)
            local _ar_nkey = ustrregexra(ustrregexra(`"`_ar_after'"', ///
                "(^|#)c\.", "$1"), "(^|#)([0-9]+)[a-z]+\.", "$1$2.")
            if `"`_ar_after'"' == "" {
                noisily display as error "addrow(): after() requires a coefficient or factor name"
                exit 198
            }
        }
        local _ar_anchor = .
        local _ar_indent ""
        if `_ar_hasafter' {
            * a factor variable: the end of its block of levels
            quietly count if _n >= 3 & _n <= `_ar_end' & _ar_par == `"`_ar_after'"'
            if r(N) > 0 {
                quietly count if _n >= 3 & _n <= `_ar_end' & _ar_par == `"`_ar_after'"' ///
                    & _ar_par[_n - 1] != `"`_ar_after'"'
                if r(N) > 1 {
                    noisily display as error `"addrow(): after(`_ar_after') matches `r(N)' blocks of levels; name the level to follow, such as after(1.`_ar_after')"'
                    exit 198
                }
                quietly summarize _ar_ord if _n >= 3 & _n <= `_ar_end' & _ar_par == `"`_ar_after'"', meanonly
                local _ar_anchor = r(max)
            }
            else {
                quietly count if _n >= 3 & _n <= `_ar_end' & _ar_nk == `"`_ar_nkey'"'
                if r(N) != 1 {
                    noisily display as error `"addrow(): after(`_ar_after') matches `r(N)' coefficient rows; it must match exactly one (raw names such as 1.drug or age, or a factor variable)"'
                    if r(N) > 1 noisily display as error "  a multi-equation table lists a term once per equation, so after() cannot place a row there"
                    exit 198
                }
                quietly summarize _ar_ord if _n >= 3 & _n <= `_ar_end' & _ar_nk == `"`_ar_nkey'"', meanonly
                local _ar_anchor = r(min)
            }
            mata: st_local("_ar_indent", ustrregexra(st_sdata(`_ar_anchor', "A"), "^( *).*$", "$1"))
        }

        local curr_n = _N
        set obs `=`curr_n'+1'
        replace A = `"`_ar_indent'`macval(_ar_label)'"' in `=`curr_n'+1'
        * frame(, flat keys): the row's key is its position in addrow()
        local ++_ar_spec
        capture confirm variable _kty
        if !_rc {
            quietly replace _kty = "addrow" in `=`curr_n'+1'
            quietly replace _ktm = "addrow:`_ar_spec'" in `=`curr_n'+1'
        }

        * Positionally assign values to model estimate columns
        local _ar_m = 0
        local _ar_vals = strtrim(`"`macval(_ar_vals)'"')
        while `"`macval(_ar_vals)'"' != "" {
            gettoken _ar_v _ar_vals : _ar_vals
            local _ar_m = `_ar_m' + 1
            * a value beyond the last model has no column: refused, as
            * addcol() refuses it, never dropped
            if `_ar_m' > `n_models' {
                noisily display as error `"addrow(): "`macval(_ar_label)'" has more values than the `n_models' models"'
                exit 198
            }
            local col = (`_ar_m' - 1) * 3 + 1
            if `col' <= `n' {
                replace c`col' = `"`macval(_ar_v)'"' in `=`curr_n'+1'
            }
        }
        if `_ar_hasafter' {
            * right after the anchor and after the rows already placed there
            if "`_ar_k_`_ar_anchor''" == "" local _ar_k_`_ar_anchor' = 0
            local _ar_k_`_ar_anchor' = `_ar_k_`_ar_anchor'' + 1
            quietly replace _ar_ord = `_ar_anchor' + `_ar_k_`_ar_anchor'' / 1000 in `=`curr_n'+1'
            local _ar_in_rows "`_ar_in_rows' `=`curr_n'+1'"
            local ++_ar_ins
        }
        else {
            quietly replace _ar_ord = `curr_n' + 1 in `=`curr_n'+1'
            local addrow_rows = "`addrow_rows' `=`curr_n'+1'"
        }
    }
    if `_ar_ins' > 0 {
        * Move the inserted rows into place and carry every row position
        * already taken (header and constraint rows, stats() rows, appended
        * addrow() rows, the eplotframe() source rows) to the new order.
        quietly generate long _ar_old = _n
        sort _ar_ord, stable
        quietly generate long _ar_new = _n
        foreach _arl in first_re_row stats_rows addrow_rows _ar_in_rows stats_start_row {
            local _ar_map ""
            foreach _r of local `_arl' {
                if `_r' <= 0 {
                    local _ar_map "`_ar_map' `_r'"
                    continue
                }
                quietly summarize _ar_new if _ar_old == `_r', meanonly
                * stata-dev-ignore: double-macro-transport — row numbers are integers; their decimal expansion is exact
                local _ar_map "`_ar_map' `=cond(r(N), r(min), `_r')'"
            }
            local `_arl' = strtrim("`_ar_map'")
        }
        forvalues _m = 1/`n_models' {
            local _ar_map ""
            foreach _r of local _constraint_rows_`_m' {
                quietly summarize _ar_new if _ar_old == `_r' - 1, meanonly
                * stata-dev-ignore: double-macro-transport — row numbers are integers; their decimal expansion is exact
                local _ar_map "`_ar_map' `=r(min) + 1'"
            }
            local _constraint_rows_`_m' = strtrim("`_ar_map'")
        }
        if `"`_eplotframe_name'"' != "" {
            mata: _regtab_arM = st_data(., ("_ar_old", "_ar_new"))
            frame `_eplotframe_name' {
                mata: _regtab_arS = st_data(., "source_row")
                mata: for (_regtab_arI = 1; _regtab_arI <= rows(_regtab_arS); _regtab_arI++) _regtab_arS[_regtab_arI] = select(_regtab_arM[., 2], _regtab_arM[., 1] :== _regtab_arS[_regtab_arI] + 2) - 2
                mata: st_store(., "source_row", _regtab_arS)
            }
            capture mata: mata drop _regtab_arM _regtab_arS _regtab_arI
        }
        drop _ar_old _ar_new
    }
    drop _ar_ord _ar_par _ar_nk
    local addrow_rows = strtrim("`addrow_rows'")
    local _ar_in_rows = strtrim("`_ar_in_rows'")
}
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end

* Folded from _regtab_cellnote.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_cellnote Version 1.2.0  2026/11/19
* parse cellnote("row label" model# "text" [\ ...])
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* =============================================================================
* _regtab_cellnote: parse cellnote("row label" model# "text" [\ ...])
* =============================================================================
* Usage: _regtab_cellnote `"<cellnote>"'
* Tokens are read quote-aware, so a label or text may hold spaces,
* backslashes, and embedded quotes, and \ may touch its neighbours
* ("a"\"b"), the forms addrow() takes. A specification wrapped whole in one
* more layer of quotes is unwrapped first. Each specification is exactly three
* tokens. Returns _cn_n, _cn_lab_#, _cn_m_#, _cn_txt_# in the caller.
capture program drop _regtab_cellnote
program define _regtab_cellnote, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	gettoken _cn_rest 0 : 0
	capture noisily {
		local _cn_n = 0
		_regtab_unwrap `"`macval(_cn_rest)'"'
		local _cn_rest : copy local _uw_spec
		local _cn_k = 0
		local _cn_more = 1
		local _cn_msg `"cellnote() expects "row label" model# "text" [\ ...]"'
		while `_cn_more' {
			local _cn_rest = strtrim(`"`macval(_cn_rest)'"')
			local _cn_tok ""
			if `"`macval(_cn_rest)'"' != "" gettoken _cn_tok _cn_rest : _cn_rest, parse("\ ") quotes
			local _cn_end = (`"`macval(_cn_rest)'"' == "" & `"`macval(_cn_tok)'"' != "\")
			if `"`macval(_cn_tok)'"' != "\" & `"`macval(_cn_tok)'"' != "" {
				local ++_cn_k
				local _cn_tk_`_cn_k' : copy local _cn_tok
				if !`_cn_end' continue
			}
			* a specification is complete: at a \ or at the end
			if `_cn_k' != 3 {
				display as error `"`_cn_msg'"'
				exit 198
			}
			gettoken _cn_lab : _cn_tk_1
			gettoken _cn_m : _cn_tk_2
			gettoken _cn_txt : _cn_tk_3
			capture confirm integer number `_cn_m'
			local _cn_bad = _rc
			if !`_cn_bad' {
				if `_cn_m' < 1 local _cn_bad = 1
			}
			if `_cn_bad' | `"`macval(_cn_lab)'"' == "" {
				display as error `"`_cn_msg'"'
				exit 198
			}
			local ++_cn_n
			c_local _cn_lab_`_cn_n' `"`macval(_cn_lab)'"'
			c_local _cn_m_`_cn_n' `_cn_m'
			c_local _cn_txt_`_cn_n' `"`macval(_cn_txt)'"'
			local _cn_k = 0
			if `_cn_end' local _cn_more = 0
			else if strtrim(`"`macval(_cn_rest)'"') == "" {
				display as error "cellnote(): nothing follows the last separator"
				exit 198
			}
		}
		c_local _cn_n `_cn_n'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* Folded from _regtab_classes.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_classes Version 1.2.0  2026/11/19
* regtab block: constraint classes collect could not record, per model
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end, so
* it reads and writes regtab's locals exactly as before. regtab calls it as
* "noisily _regtab_classes" from inside its quietly block and the body is
* quietly again, so only the block's own noisily lines print.
*
* It works on the rendered table: per model m, _omit_type<m> holds collect's
* class of each row (base, omit, empty, or blank), and a row is constrained
* in that model when its cell has an estimate with neither interval nor
* p-value. The block sets the class of such rows where collect could not:
* - The fit's own notes decide whenever they are known: the record tabtools
*   fitcount stored with the model (tt_cns), or the active e(b) when the
*   active fit is the model (_regtab_activeb proves it). They are the notes
*   Stata's own table prints - (base), (empty), (omitted), for main effects
*   and interaction cells alike - and "constrained" for a coefficient a
*   constraint fixes (class cns: its estimate is shown with cnslabel()).
* - Otherwise, in a model whose only recorded class is "empty" or that
*   records none (nbreg, zinb, intreg, streg, stintreg in Stata 17), the
*   model's specification decides a factor main effect's base
*   (_regtab_fvbase): its b. level is the reference and every other
*   constrained level of the factor omitted; a base that only fvset names
*   (it may postdate the fit) decides nothing when the factor has two or more
*   constrained levels: none of them is called the reference, all are not
*   estimable, and a note says so; with one constrained level, that level is
*   the base. An interaction cell is a base cell when one of its factor
*   levels is the base this model holds for that factor's main effect, and
*   is otherwise empty or omitted: not estimable. A cell whose factors have
*   no decided base here cannot be told: not estimable, and a note says so.
* - Only a cell holding the constrained value itself (0, or 1 where collect
*   holds a ratio) can be a base, omitted, or empty coefficient; any other
*   value is an estimate (fixed by a constraint, or estimated with a zero
*   variance) and is never called the reference.
* - Elsewhere collect's "empty" on the b. level stands when another level of
*   the factor is constrained too; when it is the factor's only constrained
*   level the base has observations (the stamp nbreg gives a base beside an
*   omitted continuous term): the reference.
* - At most one reference per factor in a model collect could not classify.
capture program drop _regtab_classes
program define _regtab_classes, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
* column m is the m-th cmdset in column order (_regtab_cmdsets)
_regtab_cmdsets
local _ab_levels `"`_cs_levels'"'
forvalues _m = 1/`n_models' {
	if `_m' > `_sm_n' continue
	local _unc = inlist(`"`_ocls_`_m''"', "", "empty") & `"`_ocls_0'"' == ""
	local _cm = 3 * `_m' - 2
	local _cc `"_n > 2 & strtrim(c`_cm') != "" & strtrim(c`=`_cm' + 1') == "" & strtrim(c`=`_cm' + 2') == """'
	quietly count if `_cc'
	if r(N) == 0 continue
	* the constrained value on the scale collect holds
	local _cv `"real(subinstr(strtrim(c`_cm'), ",", "", .))"'
	local _ccv `"`_cc' & inlist(`_cv', 0, 1)"'
	* a command with no scale rule may display ratios by default: 0 or 1
	if `_m' <= `_meta_models' {
		if `model_known_`_m'' {
			local _bv = cond(`model_eform_`_m'', 0, `model_null_`_m'')
			local _ccv `"`_cc' & `_cv' == `_bv'"'
		}
	}
	* The fit's own notes: fitcount's record, else the active fit. A classed
	* model asks the active fit only for a cell collect left without class
	* (a coefficient a constraint fixes).
	local _bn `"`_fcn_`_m''"'
	if `"`_bn'"' == "" & `_m' <= `_meta_models' {
		quietly count if `_cc' & _omit_type`_m' == ""
		if `_unc' | r(N) > 0 {
			_regtab_activeb `: word `_m' of `_ab_levels'' `"`model_cmdline_`_m''"'
			if `_ab_ok' local _bn `"`_ab_notes'"'
		}
	}
	if `"`_bn'"' != "" {
		if `"`_bn'"' != "-" {
			foreach _t of local _bn {
				local _eq = strrpos(`"`_t'"', "=")
				local _k = substr(`"`_t'"', 1, `_eq' - 1)
				local _c = substr(`"`_t'"', `_eq' + 1, .)
				local _cls = cond("`_c'" == "b", "base", cond("`_c'" == "o", "omit", ///
					cond("`_c'" == "e", "empty", "cns")))
				if "`_cls'" == "cns" {
					quietly replace _omit_type`_m' = "cns" if `_cc' & strtrim(_raw_A) == `"`_k'"'
				}
				else {
					quietly replace _omit_type`_m' = "`_cls'" if `_ccv' & strtrim(_raw_A) == `"`_k'"'
				}
			}
		}
		* the notes are the fit's whole record: a constrained factor level of
		* an unclassed model they do not mark was estimated (zero variance)
		if `_unc' {
			quietly replace _omit_type`_m' = "empty" if `_cc' & _omit_type`_m' == "" ///
				& regexm(strtrim(_raw_A), "(^|#)[0-9]+\.")
		}
		continue
	}
	foreach _fv of local _fvbv_`_m' {
		local _bk ""
		foreach _k of local _fvb_`_m' {
			if ustrregexm(`"`_k'"', "^[0-9]+\.`_fv'$") local _bk `"`_k'"'
		}
		local _fvrow `"ustrregexm(strtrim(_raw_A), "^[0-9]+\.`_fv'$")"'
		if `"`_bk'"' != "" {
			quietly count if `_ccv' & strtrim(_raw_A) == `"`_bk'"'
			if r(N) == 0 continue
		}
		quietly count if `_ccv' & `_fvrow'
		local _ncon = r(N)
		local _soft : list _fv in _fvbs_`_m'
		if `_unc' {
			if `_soft' & `_ncon' > 1 {
				quietly replace _omit_type`_m' = "empty" if `_ccv' & `_fvrow' & inlist(_omit_type`_m', "", "empty")
				noisily display as text "(regtab: model `_m': the base level of `_fv' cannot be told from its" ///
					" omitted levels, as fvset may have changed since the fit; they are shown as not estimable." ///
					" Fit with ib#.`_fv', run tabtools fitcount after the fit, or tabulate while the fit is active)"
				continue
			}
			quietly replace _omit_type`_m' = "omit" if `_ccv' & `_fvrow' & _omit_type`_m' == ""
			if `_soft' & `_ncon' == 1 {
				quietly replace _omit_type`_m' = "base" if `_ccv' & `_fvrow'
				continue
			}
		}
		if `"`_bk'"' == "" continue
		if `_unc' {
			quietly replace _omit_type`_m' = "base" if _n > 2 ///
				& strtrim(_raw_A) == `"`_bk'"' & inlist(_omit_type`_m', "empty", "omit")
		}
		else if `_ncon' == 1 {
			quietly replace _omit_type`_m' = "base" if _n > 2 ///
				& strtrim(_raw_A) == `"`_bk'"' & _omit_type`_m' == "empty"
		}
	}
	* The model's main-effect factors, and the bases its command line names
	* outright (ib#.x): those hold without the data in memory.
	local _ivs ""
	foreach _k of local _sm_fvk_`_m' {
		if ustrregexm(`"`_k'"', "^[0-9]+\.([A-Za-z_][A-Za-z0-9_]*)$") {
			local _iv = ustrregexs(1)
			local _ivs : list _ivs | _iv
		}
	}
	local _ibx ""
	if `_m' <= `_meta_models' {
		local _clp = subinstr(subinstr(subinstr(`"`model_cmdline_`_m''"', "#", " ", .), "(", " ", .), ")", " ", .)
		foreach _p of local _clp {
			if ustrregexm(`"`_p'"', "^ib([0-9]+)\.([A-Za-z_][A-Za-z0-9_]*)$") {
				local _ibx "`_ibx' `=ustrregexs(1)'.`=ustrregexs(2)'"
			}
		}
	}
	* A model collect could classify: a constrained level it left without a
	* class (a coefficient a constraint fixes at the constrained value; Stata
	* prints it "(omitted)") is the reference only when it is the factor's
	* base - the base the specification resolves (_regtab_fvbase), or an
	* ib#. of the command line, or, with neither, the factor's only
	* constrained level. Any other is omitted when the factor's base is
	* known, and not estimable, with a note, when it is not.
	if !`_unc' {
		foreach _fv of local _ivs {
			local _fvrow `"ustrregexm(strtrim(_raw_A), "^[0-9]+\.`_fv'$")"'
			quietly count if `_ccv' & `_fvrow' & _omit_type`_m' == ""
			if r(N) == 0 continue
			local _bk ""
			foreach _k of local _fvb_`_m' {
				if ustrregexm(`"`_k'"', "^[0-9]+\.`_fv'$") local _bk `"`_k'"'
			}
			local _infv : list _fv in _fvbv_`_m'
			if !`_infv' {
				foreach _k of local _ibx {
					if ustrregexm(`"`_k'"', "^[0-9]+\.`_fv'$") local _bk `"`_k'"'
				}
			}
			* a base the model estimated means the data no longer describe
			* the fit: it decides nothing
			if `"`_bk'"' != "" {
				quietly count if `_cc' & strtrim(_raw_A) == `"`_bk'"'
				if r(N) == 0 local _bk ""
			}
			quietly count if _n > 2 & `_fvrow' & _omit_type`_m' == "base"
			local _nb = r(N)
			if `"`_bk'"' != "" | `_nb' > 0 {
				if `"`_bk'"' != "" {
					quietly replace _omit_type`_m' = "base" if `_ccv' & strtrim(_raw_A) == `"`_bk'"' & _omit_type`_m' == ""
				}
				quietly replace _omit_type`_m' = "omit" if `_ccv' & `_fvrow' & _omit_type`_m' == ""
				continue
			}
			quietly count if `_cc' & `_fvrow'
			if r(N) < 2 continue
			quietly replace _omit_type`_m' = "empty" if `_ccv' & `_fvrow' & _omit_type`_m' == ""
			noisily display as text "(regtab: model `_m': which level of `_fv' is the base cannot be told" ///
				" (its specification is not in memory); its constrained levels without a class are shown as" ///
				" not estimable. Fit with ib#.`_fv', run tabtools fitcount after the fit, or tabulate while the fit is active)"
		}
		* collect classes every constrained interaction cell of such a model:
		* one it left without a class is fixed by a constraint, never a base
		quietly replace _omit_type`_m' = "omit" if `_ccv' & _omit_type`_m' == "" ///
			& strpos(_raw_A, "#") & regexm(strtrim(_raw_A), "(^|#)[0-9]+\.")
		continue
	}
	* At most one reference per factor. A constrained main-effect level still
	* without a class goes to the value rule, which calls it the reference.
	* Two or more of them in one factor (the base unverifiable: the data in
	* memory no longer hold the fit's levels), or one beside a decided base,
	* are not estimable instead. An ib#. of the command line decides first.
	foreach _fv of local _ivs {
		local _fvrow `"ustrregexm(strtrim(_raw_A), "^[0-9]+\.`_fv'$")"'
		local _infv : list _fv in _fvbv_`_m'
		if !`_infv' {
			foreach _k of local _ibx {
				if !ustrregexm(`"`_k'"', "^[0-9]+\.`_fv'$") continue
				quietly count if `_ccv' & strtrim(_raw_A) == `"`_k'"' & _omit_type`_m' == ""
				if r(N) == 0 continue
				quietly replace _omit_type`_m' = "base" if `_ccv' & strtrim(_raw_A) == `"`_k'"' & _omit_type`_m' == ""
				quietly replace _omit_type`_m' = "omit" if `_ccv' & `_fvrow' & _omit_type`_m' == ""
			}
		}
		quietly count if _n > 2 & `_fvrow' & _omit_type`_m' == "base"
		local _nb = r(N)
		quietly count if `_ccv' & `_fvrow' & _omit_type`_m' == ""
		local _nf = r(N)
		if (`_nb' == 0 & `_nf' < 2) | `_nf' == 0 continue
		quietly replace _omit_type`_m' = "empty" if `_ccv' & `_fvrow' & _omit_type`_m' == ""
		if `_nb' == 0 {
			noisily display as text "(regtab: model `_m': the base level of `_fv' cannot be told from its" ///
				" omitted levels; they are shown as not estimable. Fit with ib#.`_fv', run tabtools" ///
				" fitcount after the fit, or tabulate while the fit is active)"
		}
	}
	* Interaction cells: a base cell has a factor level that is the base this
	* model holds for that factor's main effect (one decided above, or a lone
	* constrained main-effect level, which the value rule calls the base).
	quietly count if `_ccv' & _omit_type`_m' == "" & strpos(_raw_A, "#") ///
		& regexm(strtrim(_raw_A), "(^|#)[0-9]+\.")
	if r(N) == 0 continue
	local _mbase ""
	local _mvars ""
	foreach _fv of local _ivs {
		local _fvrow `"ustrregexm(strtrim(_raw_A), "^[0-9]+\.`_fv'$")"'
		quietly levelsof _raw_A if _n > 2 & `_fvrow' & _omit_type`_m' == "base", local(_bl) clean
		if `: word count `_bl'' != 1 {
			quietly levelsof _raw_A if `_ccv' & `_fvrow' & _omit_type`_m' == "", local(_bl) clean
		}
		if `: word count `_bl'' != 1 continue
		local _mbase "`_mbase' `_bl'"
		local _mvars "`_mvars' `_fv'"
	}
	quietly levelsof _raw_A if `_ccv' & _omit_type`_m' == "" & strpos(_raw_A, "#") ///
		& regexm(strtrim(_raw_A), "(^|#)[0-9]+\."), local(_ikeys) clean
	local _iund ""
	foreach _k of local _ikeys {
		local _anyb = 0
		local _und = 0
		foreach _p in `=subinstr(`"`_k'"', "#", " ", .)' {
			if !ustrregexm(`"`_p'"', "^[0-9]+\.([A-Za-z_][A-Za-z0-9_]*)$") continue
			local _pv = ustrregexs(1)
			local _in : list _pv in _mvars
			local _isb : list _p in _mbase
			if !`_in' local _und = 1
			else if `_isb' local _anyb = 1
		}
		local _cls = cond(`_anyb', "base", "empty")
		quietly replace _omit_type`_m' = "`_cls'" if `_ccv' & strtrim(_raw_A) == `"`_k'"' & _omit_type`_m' == ""
		if !`_anyb' & `_und' local _iund "`_iund' `_k'"
	}
	if "`_iund'" != "" {
		noisily display as text "(regtab: model `_m': the base cells of`_iund' cannot be told from" ///
			" empty cells, as the model holds no decided base for one of their factors; they are shown" ///
			" as not estimable. Run tabtools fitcount after the fit, or tabulate while the fit is active)"
	}
}
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end

* Folded from _regtab_cmdopts.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_cmdopts Version 1.2.0  2026/11/19
* parse option text with the estimator's own abbreviations
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

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

* Folded from _regtab_cmdsets.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_cmdsets Version 1.2.0  2026/11/19
* cmdset levels in the order regtab's columns use
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* =============================================================================
* _regtab_cmdsets: the collection's cmdset levels in column order
* =============================================================================
* Usage: _regtab_cmdsets
* collect levelsof lists levels in string order ("1 10 11 2 ..."); the
* renderer (_tt_collect_dim_locals in _tabtools_collect_render) orders a
* purely numeric dimension numerically, and leaves .m (a total) out. Column m
* of the table is the m-th level of that order, so anything matched to a
* model by its cmdset reads the levels from here. Returns _cs_levels in the
* caller.
capture program drop _regtab_cmdsets
program define _regtab_cmdsets, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		quietly collect levelsof cmdset
		local _lv `"`s(levels)'"'
		local _ord ""
		local _num = 1
		foreach _l of local _lv {
			if "`_l'" == ".m" continue
			local _ord "`_ord' `_l'"
			if missing(real("`_l'")) local _num = 0
		}
		if `_num' & `"`_ord'"' != "" {
			mata: st_local("_ord", invtokens(ustrregexra(strofreal(sort(strtoreal(tokens(st_local("_ord")))', 1)', "%21.0g"), "-(?=[0.,]+\z)", "")))
		}
		local _ord = strtrim(`"`_ord'"')
		c_local _cs_levels `"`_ord'"'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* Folded from _regtab_collabels.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_collabels Version 1.2.0  2026/11/19
* collabels(): column headers of a transposed table, by raw coefficient name
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* =============================================================================
* _regtab_collabels: collabels() for a transposed table
* =============================================================================
* Usage: _regtab_collabels `"<spec>"' <multi-equation 0|1>
* <spec> is name "label" [name "label" ...], name a raw coefficient name
* matched exactly and case-sensitively, as keep() matches (mpg, 1.foreign).
* Works on regtab's display dataset before it is transposed: the label
* replaces _tp_lab, the first header of that term's estimate and p-value
* columns, on every row with that raw name (_raw_A). A name that matches no
* row, or a name without a label, is an error (r(198)). In a multi-equation
* table each row reads "eq: label" and keeps its equation; eq:name selects
* one equation, eq as the rows show it.
capture program drop _regtab_collabels
program define _regtab_collabels, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	gettoken _cl_rest 0 : 0
	gettoken _cl_meq 0 : 0
	capture noisily {
		_regtab_unwrap `"`macval(_cl_rest)'"'
		local _cl_rest : copy local _uw_spec
		capture drop _cl_nkv
		capture drop _cl_pre
		quietly generate str244 _cl_nkv = ustrregexra(ustrregexra(strtrim(_raw_A), ///
			"(^|#)c\.", "$1"), "(^|#)([0-9]+)[a-z]+\.", "$1$2.")
		* a multi-equation row reads "eq: label": the equation is kept
		quietly generate str244 _cl_pre = ""
		if "`_cl_meq'" == "1" {
			quietly replace _cl_pre = ustrregexs(1) if ustrregexm(_tp_lab, "^(.+?): ")
		}
		local _cl_rest = strtrim(`"`macval(_cl_rest)'"')
		while `"`macval(_cl_rest)'"' != "" {
			gettoken _cl_k _cl_rest : _cl_rest
			local _cl_rest = strtrim(`"`macval(_cl_rest)'"')
			if `"`macval(_cl_rest)'"' == "" {
				display as error `"collabels(): `_cl_k' has no label; give collabels(name "label" [name "label" ...])"'
				exit 198
			}
			gettoken _cl_l _cl_rest : _cl_rest
			local _cl_rest = strtrim(`"`macval(_cl_rest)'"')
			* eq:name selects one equation of a multi-equation table, eq as
			* its rows show it ("4: Mileage (mpg)" is 4:mpg)
			local _cl_eq ""
			if "`_cl_meq'" == "1" & ustrregexm(`"`_cl_k'"', "^(.+):([^:]+)$") {
				local _cl_eq = ustrregexs(1)
				local _cl_k = ustrregexs(2)
			}
			* keep()'s form: c. and level markers (1b.) do not matter
			local _cl_nk = ustrregexra(ustrregexra(`"`_cl_k'"', "(^|#)c\.", "$1"), ///
				"(^|#)([0-9]+)[a-z]+\.", "$1$2.")
			local _cl_if `"_n >= 3 & _cl_nkv == `"`_cl_nk'"'"'
			if `"`_cl_eq'"' != "" local _cl_if `"`_cl_if' & _cl_pre == `"`_cl_eq'"'"'
			quietly count if `_cl_if'
			if r(N) == 0 {
				display as error `"collabels(): `=cond(`"`_cl_eq'"' != "", `"`_cl_eq':"', "")'`_cl_k' matches no coefficient row (give raw names, as keep() takes them, eq:name in a multi-equation table)"'
				exit 198
			}
			tempvar _cl_hit
			quietly generate byte `_cl_hit' = `_cl_if'
			mata: _rt_cl_i = selectindex(st_data(., "`_cl_hit'")); _rt_cl_p = st_sdata(_rt_cl_i, "_cl_pre"); st_sstore(_rt_cl_i, "_tp_lab", _rt_cl_p :+ ((_rt_cl_p :!= "") :* ": ") :+ st_local("_cl_l"))
			capture mata: mata drop _rt_cl_i _rt_cl_p
			drop `_cl_hit'
		}
	}
	local _rc = _rc
	capture drop _cl_nkv
	capture drop _cl_pre
	capture mata: mata drop _rt_cl_i _rt_cl_p
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* Folded from _regtab_eqkeys.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_eqkeys Version 1.2.0  2026/11/19
* equation key of every row of a coleq#colname rendering
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

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
			* sorted on the numeric value, the level strings themselves kept
			* (never rebuilt from a number): the order is a permutation
			mata: _rg_s = tokens(st_local("_ord"))'; st_local("_ord", invtokens((_rg_s[order((strtoreal(_rg_s), (1::rows(_rg_s))), (1, 2))])'))
			capture mata: mata drop _rg_s
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

* Folded from _regtab_estats.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_estats Version 1.2.0  2026/11/19
* generic stats() e(name) values from the collection
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* =============================================================================
* _regtab_estats: generic stats() e(name) values from the collection
* =============================================================================
* Usage: _regtab_estats <models> <name> [<name> ...]
* Read from the collection, never from the active e(). Models are matched by
* their cmdset level, in regtab's column order (_regtab_cmdsets), so a model
* without the scalar stays blank (missing). A name no collected model holds
* is an error. Returns _cstv_<k>_<m> and _cst_int_<k> (1 when every value is
* an integer) in the caller, k indexing the names as given.
capture program drop _regtab_estats
program define _regtab_estats, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	gettoken _nmod 0 : 0
	local _names `0'
	local _nn : word count `_names'
	local _rl_n 0
	local _rl_present ""
	capture noisily {
		forvalues _k = 1/`_nn' {
			forvalues m = 1/`_nmod' {
				local _v_`_k'_`m' = .
			}
		}
		* column order, not collect's string order (1 10 11 2 ...)
		_regtab_cmdsets
		local _levels `"`_cs_levels'"'
		_regtab_rlabels `_names'
		local _present "`_rl_present'"
		if "`_present'" != "" {
			quietly collect layout (cmdset) (result[`_present'])
			preserve
			_tabtools_collect_render, type(stats) rowdim(cmdset) results(`_present')
			quietly ds A, not
			local _vars `r(varlist)'
			forvalues _k = 1/`_nn' {
				local _nm : word `_k' of `_names'
				local _col_`_k' ""
				foreach v of local _vars {
					if strtrim(`v'[1]) == "`_nm'" local _col_`_k' "`v'"
				}
			}
			forvalues _r = 2/`=_N' {
				local _lev = strtrim(A[`_r'])
				local m : list posof "`_lev'" in _levels
				if `m' < 1 | `m' > `_nmod' continue
				forvalues _k = 1/`_nn' {
					if "`_col_`_k''" == "" continue
					local _x = real(subinstr(strtrim(`_col_`_k''[`_r']), ",", "", .))
					if !missing(`_x') local _v_`_k'_`m' = `_x'
				}
			}
			restore
		}
	}
	local _rc = _rc
	forvalues _rli = 1/`_rl_n' {
		local _rlv : word `_rli' of `_rl_present'
		capture quietly collect label levels result `_rlv' `"`macval(_rl_lbl_`_rli')'"', modify
	}
	if `_rc' {
		display as error "stats(): could not read the e() statistics from the collection"
	}
	else {
		forvalues _k = 1/`_nn' {
			local _any = 0
			local _int = 1
			forvalues m = 1/`_nmod' {
				c_local _cstv_`_k'_`m' `_v_`_k'_`m''
				if !missing(`_v_`_k'_`m'') {
					local _any = 1
					if `_v_`_k'_`m'' != round(`_v_`_k'_`m'') local _int = 0
				}
			}
			c_local _cst_int_`_k' `_int'
			if !`_any' & !`_rc' {
				local _nm : word `_k' of `_names'
				display as error "stats(): e(`_nm') is not in any collected model"
				local _rc = 111
			}
		}
	}
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* Folded from _regtab_fitrec.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_fitrec Version 1.2.0  2026/11/19
* fit-time records of tabtools fitcount, per model column
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* =============================================================================
* _regtab_fitrec: string results tabtools fitcount stored with each model
* =============================================================================
* Usage: _regtab_fitrec <result> [<result> ...]   (tt_terms tt_cns tt_levels)
* Each model's records were stored with its own cmdset at fit time; the
* collection itself keeps neither e(sample) nor the b./o. markers of e(b).
* The rows of the rendered (cmdset) layout are every cmdset level in the
* renderer's numeric order, the order of the table's model columns, so row m
* is model m (a cmdset without the result, such as a failed fit, has an empty
* row). Returns in the caller: _fr_present (the results the collection
* holds), _fr_models (the number of cmdset rows), _fr_rc (0, or the error of
* the read), and _fr_<result>_<m> for every result asked for and model m.
* The labels of the result levels are restored exactly as found.
capture program drop _regtab_fitrec
program define _regtab_fitrec, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	local _want `0'
	c_local _fr_present ""
	c_local _fr_models 0
	c_local _fr_rc 0
	capture noisily {
		_regtab_rlabels `_want'
		local _pres "`_rl_present'"
		local _nm = 0
		local _frc = 0
		if "`_pres'" != "" {
			capture {
				collect layout (cmdset) (result[`_pres'])
			}
			local _frc = _rc
			if !`_frc' {
				preserve
				* stata-dev-ignore: capture-rc — a braced capture stops at its first error; _rc is read on the first line after the closing brace
				capture {
					_tabtools_collect_render, type(meta) rowdim(cmdset) results(`_pres')
					local _nm = _N - 1
					foreach _r of local _pres {
						local _col ""
						foreach _v of varlist _all {
							if strtrim(`_v'[1]) == "`_r'" local _col "`_v'"
						}
						forvalues _m = 1/`_nm' {
							local _val ""
							if "`_col'" != "" mata: st_local("_val", strtrim(st_sdata(`_m' + 1, "`_col'")))
							c_local _fr_`_r'_`_m' `"`_val'"'
						}
					}
				}
				local _frc = _rc
				restore
			}
		}
		forvalues _rli = 1/`_rl_n' {
			local _rlv : word `_rli' of `_rl_present'
			quietly collect label levels result `_rlv' `"`macval(_rl_lbl_`_rli')'"', modify
		}
		c_local _fr_present "`_pres'"
		c_local _fr_models `_nm'
		c_local _fr_rc `_frc'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* Folded from _regtab_flatten.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_flatten Version 1.2.0  2026/11/19
* regtab block: flatten coleq#colname rows (multilevel and multi-equation)
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end, so
* it reads and writes regtab's locals exactly as before. regtab calls it as
* "noisily _regtab_flatten" from inside its quietly block and the body is quietly
* again, so only the block's own noisily lines print. Data in memory, frames,
* and the collection are shared state and need no transport.
capture program drop _regtab_flatten
program define _regtab_flatten, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
* Flatten coleq#colname hierarchical layout for multi-level models
* In coleq#colname layout, the exported structure is:
*   Header rows: coleq values (equation labels: "y", "District", "School", "Residual")
*   Data rows:   colname values (indented: "  x", "  var(_cons)", "  var(e)")
* Goal: merge each data row with its parent header into bracket notation:
*   header="District" + data="  var(_cons)" -> "var(_cons[district])"
*   header="y" + data="  x" -> "x"
if `_is_multilevel' {
    * Random-effects rows are known by their raw coefficient name, never by
    * the display label: a covariate labelled "Age per sd(10)" is not one.
    quietly count if _n > 2 ///
        & strpos(A, "[") > 0 & strpos(A, "]") > 0 ///
        & ustrregexm(strtrim(_raw_colname), "^(var|cov|sd|corr)\(")
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
                    if _n > 2 & ustrregexm(strtrim(_raw_colname), "^(var|cov|sd|corr)\(")
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

        * A DATA row is a random-effects row when its raw coefficient name
        * is one (var(), cov(), sd(), corr()); the display label is never
        * consulted, so a covariate labelled "Age per sd(10)" keeps its label.
        gen byte _data_is_re = ustrregexm(strtrim(_raw_colname), "^(var|cov|sd|corr)\(") & !_is_header

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
        quietly ds A _raw_colname _raw_eq _fp_par _fp_ord _fp_new _fp_dup, not
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
            replace _eq_label = `"`macval(_coleq_lab_`_eqi')'"' ///
                if _eq_label == `"`_coleq_key_`_eqi''"' ///
                | _eq_label == `"`macval(_coleq_key2_`_eqi')'"'
        }
    }
    if `"`macval(_dep_label)'"' != "" {
        replace _eq_label = `"`macval(_dep_label)'"' if _eq_label == `"`_depvar'"'
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
    * reference-category coefficients for every covariate. The o. marker is
    * read from the raw coefficient key, never from the rendered label: a
    * covariate labelled "o.d. of the sample" was dropped from every equation.
    gen byte _drop_omitted_eq = !_is_header & _n > 2 & ///
        strpos(strtrim(_raw_colname), "o.") == 1
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
    local _eqhelpers "A _raw_colname _raw_eq _orig_row_order _is_header _parent_header _A_trim _eq_label `_role_vars'"
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
                quietly replace _A_trim = `"`macval(_fvrow_lab_`_fvi')'"' in `_fpr'
            }
        }
    }
    quietly count if _n > 2 & _fp_par != ""
    if r(N) > 0 {
        quietly generate long _fp_ord = _n
        quietly generate byte _fp_new = _n > 2 & _fp_par != "" & _fp_par != _fp_par[_n - 1]
        quietly expand 2 if _fp_new, generate(_fp_dup)
        quietly ds A _raw_colname _raw_eq _fp_par _fp_ord _fp_new _fp_dup ///
            _is_header _parent_header _eq_label _orig_row_order, not
        foreach _fpv in `r(varlist)' {
            capture confirm string variable `_fpv'
            if _rc == 0 quietly replace `_fpv' = "" if _fp_dup
            else quietly replace `_fpv' = . if _fp_dup
        }
        quietly replace _raw_colname = _fp_par if _fp_dup
        quietly replace _A_trim = _fp_par if _fp_dup
        forvalues _fvp = 1/`_fvrow_parent_n' {
            quietly replace _A_trim = `"`macval(_fvrow_parent_lab_`_fvp')'"' ///
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
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end

* Folded from _regtab_frameopts.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_frameopts Version 1.2.0  2026/11/19
* parse and check frame() and eplotframe()
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* =============================================================================
* _regtab_frameopts: parse and check frame() and eplotframe()
* =============================================================================
* Usage: _regtab_frameopts `"<eplotframe>"' `"<frame>"'
* Returns _eplotframe_name, _eplotframe_replace, _displayframe_name,
* _displayframe_replace, _displayframe_flat, and _displayframe_keys in the
* caller.
capture program drop _regtab_frameopts
program define _regtab_frameopts, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	gettoken eplotframe 0 : 0
	gettoken frame 0 : 0
	capture noisily {

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
		local _displayframe_flat 0
		local _displayframe_keys 0
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
			* Suboptions replace, flat, and keys, in any order. flat writes one
			* row per body line with the printed headers as variable labels;
			* keys adds the key variables (_order, _term, _rowtype, _state#)
			* to a flat frame.
			foreach _fr_w of local _fr_rest {
				if `"`_fr_w'"' == "replace" local _displayframe_replace 1
				else if `"`_fr_w'"' == "flat" local _displayframe_flat 1
				else if `"`_fr_w'"' == "keys" local _displayframe_keys 1
				else {
					noisily display as error "frame() only allows the replace, flat, and keys suboptions"
					exit 198
				}
			}
			if `_displayframe_keys' & !`_displayframe_flat' {
				noisily display as error "frame(): keys requires flat, as in frame(`_displayframe_name', flat keys)"
				exit 198
			}
		}
		if `"`_displayframe_name'"' != "" & ///
			`"`_eplotframe_name'"' != "" & ///
			`"`_displayframe_name'"' == `"`_eplotframe_name'"' {
			noisily display as error "frame() and eplotframe() must name different frames"
			exit 198
		}
		foreach _dest in _displayframe_name _eplotframe_name {
			if `"``_dest''"' != "" & ///
				`"``_dest''"' == `"`c(frame)'"' {
				noisily display as error "output frames cannot replace the current frame"
				exit 198
			}
			* The default frame holds the user's data too: from another
			* frame, frame(default, replace) dropped it for the table.
			if `"``_dest''"' == "default" {
				noisily display as error "output frames cannot replace the default frame"
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
		c_local _eplotframe_name `"`_eplotframe_name'"'
		c_local _eplotframe_replace `_eplotframe_replace'
		c_local _displayframe_name `"`_displayframe_name'"'
		c_local _displayframe_replace `_displayframe_replace'
		c_local _displayframe_flat `_displayframe_flat'
		c_local _displayframe_keys `_displayframe_keys'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* Folded from _regtab_fvbase.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_fvbase Version 1.2.0  2026/11/19
* base levels of a model's factor variables, from its own specification
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* =============================================================================
* _regtab_fvbase: base levels of a model's factor variables
* =============================================================================
* Usage: _regtab_fvbase `"<command line>"' `"<keys>"' <varabbrev>
* <varabbrev> is the caller's own setting: e(cmdline) is expanded under it,
* so a varlist the user typed with abbreviations still expands.
* <keys> are the main-effect factor-level keys the model holds in the
* collection ("0.drug 1.drug 1.rep78 ..."). Returns, in the caller:
*   _fvb_vars  the factor variables whose base level was decided
*   _fvb_keys  the keys of those factors that are the model's base level
*   _fvb_soft  the factors whose base came from fvset (char _fv_base), not
*              from the command line: fvset may postdate the fit
* regtab asks only for a model whose classes collect could not record: Stata
* 17 stamps every constrained cell of nbreg, zinb, intreg, and some streg fits
* "empty", so their base level and a level dropped as collinear look alike,
* and both used to read "Reference". The base follows
* Stata's own rule instead: the model's varlist, as typed in e(cmdline), is
* expanded with fvexpand over the observations holding the levels the model
* holds, so the default (lowest level), ib#., ib(first|last)., ibn., and
* fvset base all resolve as they did at fit time; the level fvexpand marks
* "b." is the base. A factor is left undecided (absent from _fvb_vars, so the
* caller keeps collect's classes) when the varlist cannot be expanded on the
* data in memory, when its base depends on frequencies in the estimation
* sample (ib(freq)., fvset base frequent), when the model holds fewer than two
* of its levels, or when the expansion names no single base among them.
capture program drop _regtab_fvbase
program define _regtab_fvbase, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		gettoken _cl 0 : 0
		gettoken _keys 0 : 0
		gettoken _vab 0 : 0
		if !inlist("`_vab'", "on", "off") local _vab "off"
		local _vars_out ""
		local _soft_out ""
		local _keys_out ""
		* varlist: up to "||" (mixed-model random parts), if, in, weights, or
		* the options; after any prefix ("svy:", "bootstrap, ...:"); without
		* the command word
		local _vl `"`_cl'"'
		foreach _cut in "||" " if " " in " "[" "," {
			local _p = strpos(`"`_vl'"', "`_cut'")
			if `_p' > 0 local _vl = substr(`"`_vl'"', 1, `_p' - 1)
		}
		local _p = strrpos(`"`_vl'"', ":")
		if `_p' > 0 local _vl = substr(`"`_vl'"', `_p' + 1, .)
		gettoken _cmd _vl : _vl
		local _vl = strtrim(`"`_vl'"')
		if `"`_vl'"' != "" & !strpos(`"`_vl'"', "freq") {
			* the factor variables this model holds levels of
			local _fvs ""
			foreach _k of local _keys {
				if ustrregexm(`"`_k'"', "^[0-9]+\.([A-Za-z_][A-Za-z0-9_]*)$") {
					local _fv = ustrregexs(1)
					local _fvs : list _fvs | _fv
				}
			}
			* each factor operator as typed, with its variable resolved under
			* the user's varabbrev: which factors name their base in the command
			* line itself (ib#., ib(last).); fvunab would fold fvset in
			local _vu ""
			local _vp = subinstr(`"`_vl'"', "#", " ", .)
			foreach _pt of local _vp {
				if !ustrregexm(`"`_pt'"', "^([^.]*)\.([A-Za-z_][A-Za-z0-9_]*)$") continue
				local _op = ustrregexs(1)
				local _nm = ustrregexs(2)
				if !strpos("`_op'", "b") continue
				set varabbrev `_vab'
				capture unab _nm : `_nm'
				local _urc = _rc
				set varabbrev off
				if !`_urc' local _vu "`_vu' `_nm'"
			}
			foreach _fv of local _fvs {
				local _levs ""
				foreach _k of local _keys {
					if ustrregexm(`"`_k'"', "^([0-9]+)\.`_fv'$") {
						local _levs `"`_levs' `=ustrregexs(1)'"'
					}
				}
				capture confirm numeric variable `_fv', exact
				if _rc continue
				local _fvb : char `_fv'[_fv_base]
				if strpos(`"`_fvb'"', "freq") continue
				if `: word count `_levs'' < 2 continue
				tempvar _in
				quietly generate byte `_in' = 0
				foreach _lv of local _levs {
					quietly replace `_in' = 1 if `_fv' == `_lv'
				}
				set varabbrev `_vab'
				capture fvexpand `_vl' if `_in'
				local _xrc = _rc
				set varabbrev off
				local _xl `"`r(varlist)'"'
				drop `_in'
				if `_xrc' continue
				local _main = 0
				local _base ""
				foreach _t of local _xl {
					if !ustrregexm(`"`_t'"', "^([0-9]+)([a-z]*)\.`_fv'$") continue
					local _lv = ustrregexs(1)
					local _op = ustrregexs(2)
					local _held : list _lv in _levs
					if !`_held' continue
					local ++_main
					if "`_op'" == "b" local _base "`_base' `_lv'.`_fv'"
				}
				if `_main' == 0 | `: word count `_base'' > 1 continue
				local _vars_out "`_vars_out' `_fv'"
				local _keys_out "`_keys_out'`_base'"
				* a base from fvset (char _fv_base) and not from the command
				* line may have been set after the fit
				local _expl : list _fv in _vu
				if `"`_fvb'"' != "" & !`_expl' local _soft_out "`_soft_out' `_fv'"
			}
		}
		local _vars_out = strtrim("`_vars_out'")
		local _keys_out = strtrim("`_keys_out'")
		c_local _fvb_vars "`_vars_out'"
		c_local _fvb_keys "`_keys_out'"
		local _soft_out = strtrim("`_soft_out'")
		c_local _fvb_soft "`_soft_out'"
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* Folded from _regtab_fvparent.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_fvparent Version 1.2.0  2026/11/19
* factor parent of a raw colname key
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

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

* Folded from _regtab_keys.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_keys Version 1.2.0  2026/11/19
* regtab block: key variables of frame(name, flat keys)
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end.
* regtab calls it as "noisily _regtab_keys <step>" from inside its quietly
* block, only for frame(name, flat keys).
*
* Steps:
*   rows   on the coefficient body (rows 3 on, while each model's constraint
*          class _constraint# is still there), creates _kty (row type),
*          _ktm (term), and _kst1, _kst2, ... (the state of each model's cell)
*   stats  marks the stats() rows: _kty "stat", _ktm "stat:<item>"
*   save   (before the title row is added) gives every row without a state
*          one from its printed cell, copies rows 3 on into the Mata matrix
*          _regtab_K, and drops the variables
*   put    on the flat frame's data (one row per body line, in the same
*          order), adds _order, _term, _rowtype, and _state1 ... _state<n>
*          for the n printed columns, each marked char <var>[tabtools_key] 1
*
* _term is the row's raw coefficient name in keep()'s form (factor operators
* and b./o./n markers dropped: 9.edss_t, 1.a#2.b, age, 1.g#x), preceded in a
* multi-equation table by its equation as the collection names it (4:mpg),
* and for a random-effects row by its level (district:var(_cons)). A factor's
* heading row carries the factor (edss_t, a#b), a stats() row
* stat:<item>, an addrow() row addrow:<k> (its position in addrow()).
* _rowtype is factor, level, var, re, stat, or addrow. _state# is the state of
* the model cell that printed column c# belongs to: est (an estimate), ref
* (refcat()), omit (omitlabel()), notest (notestlabel()), masked
* (emptylabel() under mincount(), too few events), absent (absentlabel()), constrained (the
* estimate with cnslabel()), note (cellnote()), stat (a stats() value), text
* (an addrow() value), or empty (a blank cell: no such coefficient).
capture program drop _regtab_keys
program define _regtab_keys, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	gettoken _rtns_step 0 : 0
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
if "`_rtns_step'" == "rows" {
	quietly generate str8 _kty = ""
	quietly generate strL _ktm = ""
	forvalues _ky_mm = 1/`n_models' {
		quietly generate str11 _kst`_ky_mm' = ""
	}
	* the factor headings: every parent of a level row
	local _ky_par ""
	forvalues _ky_r = 3/`=_N' {
		local _ky_key = strtrim(_raw_A[`_ky_r'])
		if `"`_ky_key'"' == "" continue
		_regtab_fvparent `"`_ky_key'"'
		if `"`_fp_parent'"' != "" local _ky_par : list _ky_par | _fp_parent
	}
	forvalues _ky_r = 3/`=_N' {
		local _ky_key = strtrim(_raw_A[`_ky_r'])
		local _ky_eq = strtrim(_raw_eq[`_ky_r'])
		local _ky_ty "var"
		local _ky_hl = ustrregexm(`"`_ky_key'"', "(^|#)[0-9]+[a-z]*\.")
		local _ky_ip : list _ky_key in _ky_par
		if `"`_ky_key'"' == "" local _ky_ty "header"
		else if `_ky_hl' local _ky_ty "level"
		else if `_ky_ip' local _ky_ty "factor"
		else if _is_re[`_ky_r'] == 1 local _ky_ty "re"
		* keep()'s form: factor operators and level markers dropped
		local _ky_t = ustrregexra(ustrregexra(`"`_ky_key'"', ///
			"(^|#)(i|c|o|b|bn|ibn|ib[0-9]+)\.", "$1"), "(^|#)([0-9]+)(b|bn|o)\.", "$1$2.")
		if `"`_ky_eq'"' != "" & (`_is_multieq' | "`_ky_ty'" == "re") local _ky_t `"`_ky_eq':`_ky_t'"'
		quietly replace _kty = "`_ky_ty'" in `_ky_r'
		mata: st_sstore(`_ky_r', "_ktm", st_local("_ky_t"))
		if inlist("`_ky_ty'", "factor", "header") continue
		forvalues _ky_mm = 1/`n_models' {
			local _ky_cs = _constraint`_ky_mm'[`_ky_r']
			local _ky_ce = 3 * `_ky_mm' - 2
			local _ky_ab : list _ky_r in _mc_ab_`_ky_mm'
			local _ky_st = cond(strtrim(c`_ky_ce'[`_ky_r']) != "", "est", "empty")
			if "`_ky_cs'" == "base" local _ky_st "ref"
			else if "`_ky_cs'" == "omit" local _ky_st "omit"
			else if inlist("`_ky_cs'", "empty", "mk_ne") local _ky_st "notest"
			else if "`_ky_cs'" == "cns" local _ky_st "constrained"
			else if "`_ky_cs'" == "note" local _ky_st "note"
			else if "`_ky_cs'" == "mk_th" local _ky_st "masked"
			else if "`_ky_cs'" == "mk_ab" | `_ky_ab' local _ky_st "absent"
			quietly replace _kst`_ky_mm' = "`_ky_st'" in `_ky_r'
		}
	}
}
else if "`_rtns_step'" == "stats" {
	* stats_row_ids, when the stats() block names its rows, holds one item
	* per row of stats_rows; otherwise a row is known by its position
	local _ky_sn : word count `stats_rows'
	local _ky_nmd = (`: word count `stats_row_ids'' == `_ky_sn')
	local _ky_si = 0
	foreach _ky_r of local stats_rows {
		local ++_ky_si
		local _ky_id = cond(`_ky_nmd', "`: word `_ky_si' of `stats_row_ids''", "`_ky_si'")
		quietly replace _kty = "stat" in `_ky_r'
		mata: st_sstore(`_ky_r', "_ktm", "stat:" + st_local("_ky_id"))
	}
}
else if "`_rtns_step'" == "save" {
	forvalues _ky_mm = 1/`n_models' {
		local _ky_ce = 3 * `_ky_mm' - 2
		quietly replace _kst`_ky_mm' = cond(strtrim(c`_ky_ce') != "", cond(_kty == "stat", "stat", "text"), "empty") ///
			if _n >= 3 & inlist(_kty, "stat", "addrow")
		quietly replace _kst`_ky_mm' = "empty" if _n >= 3 & _kst`_ky_mm' == ""
	}
	local _ky_v "_kty _ktm"
	forvalues _ky_mm = 1/`n_models' {
		local _ky_v "`_ky_v' _kst`_ky_mm'"
	}
	mata: _regtab_K = st_sdata((3::st_nobs()), tokens(st_local("_ky_v")))
	drop `_ky_v'
}
else if "`_rtns_step'" == "put" {
	mata: st_local("_ky_n", strofreal(rows(_regtab_K)))
	if `_ky_n' != _N {
		noisily display as error "frame(, flat keys): the keys do not align with the frame's rows"
		exit 459
	}
	quietly generate double _order = _n
	label variable _order "row order (sort on it)"
	local _ky_cols "2 1"
	local _ky_names "_term _rowtype"
	local _ky_lab `""term: coefficient name, keep() form" "row type""'
	forvalues _ky_j = 1/`n' {
		local _ky_m = ceil(`_ky_j' / `_cols_per_model')
		local _ky_cols "`_ky_cols' `=2 + `_ky_m''"
		local _ky_names "`_ky_names' _state`_ky_j'"
		local _ky_lab `"`_ky_lab' "state of c`_ky_j'""'
	}
	local _ky_k : word count `_ky_names'
	forvalues _ky_i = 1/`_ky_k' {
		local _ky_vn : word `_ky_i' of `_ky_names'
		local _ky_c : word `_ky_i' of `_ky_cols'
		mata: st_local("_ky_w", strofreal(max((max(strlen(_regtab_K[., `_ky_c'])), 1))))
		if `_ky_w' > 2045 quietly generate strL `_ky_vn' = ""
		else quietly generate str`_ky_w' `_ky_vn' = ""
		mata: st_sstore(., st_local("_ky_vn"), _regtab_K[., `_ky_c'])
		local _ky_l : word `_ky_i' of `_ky_lab'
		label variable `_ky_vn' `"`_ky_l'"'
	}
	foreach _ky_vn in _order `_ky_names' {
		char `_ky_vn'[tabtools_key] 1
	}
	char _dta[tabtools_keys] "_order `_ky_names'"
}
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end

* Folded from _regtab_methods.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_methods Version 1.2.0  2026/11/19
* regtab block: the methods sentence (r(methods))
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end, so
* it reads and writes regtab's locals exactly as before. regtab calls it as
* "noisily _regtab_methods" from inside its quietly block and the body is quietly
* again, so only the block's own noisily lines print. Data in memory, frames,
* and the collection are shared state and need no transport.
capture program drop _regtab_methods
program define _regtab_methods, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
* Build methods description (I2)
local _methods_coef ""
local _methods_model ""
if `_model_headers_mixed' {
    local _methods "Collected regression estimates with `_ci_level'% confidence intervals across `n_models' models."
}
else if `"`macval(coef)'"' == "OR" {
    local _methods_coef "Odds ratios"
    local _methods_model "logistic regression"
}
else if `"`macval(coef)'"' == "HR" {
    * HR headers come from stcox and from the hazard metric of streg,
    * mestreg, and mecloglog; only the first is a Cox model.
    local _methods_coef "Hazard ratios"
    local _methods_model "Cox proportional hazards regression"
    if `_meta_models' > 0 {
        gettoken _methods_word : model_cmdline_1
        local _methods_word = lower(`"`_methods_word'"')
        if inlist("`_methods_word'", "streg", "stintreg", "mestreg") {
            local _methods_model "parametric proportional hazards survival regression"
        }
        else if "`_methods_word'" == "mecloglog" {
            local _methods_model "mixed-effects complementary log-log regression"
        }
    }
}
else if `"`macval(coef)'"' == "TR" {
    local _methods_coef "Time ratios"
    local _methods_model "accelerated failure-time survival regression"
}
else if `"`macval(coef)'"' == "IRR" {
    local _methods_coef "Incidence rate ratios"
    local _methods_model "Poisson regression"
}
else if `"`macval(coef)'"' == "RRR" {
    local _methods_coef "Relative risk ratios"
    local _methods_model "multinomial logistic regression"
}
else if `"`macval(coef)'"' == "Coef." {
    local _methods_coef "Coefficients"
    local _methods_model "linear regression"
}
else {
    local _methods_coef : copy local coef
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
        * a cmdset without command metadata (a failed fit) names no model
        if `"`model_cmdline_`m''`model_cmd_`m''"' == "" continue
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
    local _methods `"`macval(_methods_coef)' with `_ci_level'% confidence intervals from `_madj'`_methods_model'`_methods_multi'."'
}
if `"`macval(_methods)'"' == "" {
    local _methods `"`macval(_methods_coef)' with `_ci_level'% confidence intervals from multivariable `_methods_model'`_methods_multi'."'
}
if "`stars'" != "" {
    local _methods `"`macval(_methods)' Statistical significance denoted as * p<`_sl1', ** p<`_sl2', *** p<`_sl3'."'
}
local _methods `"`macval(_methods)' Analysis performed in Stata `c(stata_version)' (StataCorp, College Station, TX)."'
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end

* Folded from _regtab_mincount.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_mincount Version 1.2.0  2026/11/19
* regtab block: mincount() masks, not-estimable and absent levels
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end, so
* it reads and writes regtab's locals exactly as before. regtab calls it as
* "noisily _regtab_mincount" from inside its quietly block (only when
* mincount() is given) and the body is quietly again, so only the block's own
* noisily lines print.
*
* mincount(#): a factor level (or a 0/1 indicator) the model could not
* estimate - its variance is zero or missing, or collect records it as
* omitted or empty - is shown as notestlabel(); one whose events (tabtools
* fitcount, terms) are fewer than # as emptylabel(); both with the interval
* and p-value blank. A model's own base level keeps its reference label, and
* a coefficient a constraint fixes keeps its fixed value (nothing is
* estimated). Every level a model shows must be covered by that model's
* counts. A level of a factor block the model includes that is missing from
* the model's e(b) altogether is told apart by the levels its estimation
* sample holds (tt_levels, stored by tabtools fitcount, terms): a level with
* no observation there was left out by design (an if restriction, a
* subgroup) and is shown as absentlabel(), blank by default; a level the
* sample holds that the model does not estimate is shown as notestlabel().
* When the counts record no sample levels (tt_levels from an older
* fitcount), the level is shown as notestlabel(), the reading that does not
* claim the model left it out, and a note names it. r(N_absent) counts the
* levels missing from a model either way; r(N_masked) keeps its 2.3.1
* meaning, the cells of levels a model holds.
capture program drop _regtab_mincount
program define _regtab_mincount, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
* the factor block of every row: one id per consecutive run of levels
quietly generate str244 _mc_par = ""
forvalues _rr = 3/`=_N' {
	local _rt_key = strtrim(_raw_A[`_rr'])
	if `"`_rt_key'"' == "" continue
	_regtab_fvparent `"`_rt_key'"'
	if `"`_fp_parent'"' != "" quietly replace _mc_par = `"`_fp_parent'"' in `_rr'
}
quietly generate long _mc_blk = sum(_mc_par != "" & _mc_par != _mc_par[_n - 1])
quietly replace _mc_blk = 0 if _mc_par == ""
forvalues _m = 1/`n_models' {
	local _fct_s `";`_fct_`_m'';"'
	local _fcl_s `"`_fcl_`_m''"'
	local _mc_unk ""
	local _mc_ab_`_m' ""
	local _ce = (`_m' - 1) * 3 + 1
	quietly levelsof _mc_blk if _n >= 3 & _mc_blk > 0 & strtrim(c`_ce') != "", local(_mc_in)
	forvalues _rr = 3/`=_N' {
		local _rt_key = strtrim(_raw_A[`_rr'])
		if `"`_rt_key'"' == "" continue
		local _mc_b = _mc_blk[`_rr']
		if strtrim(c`_ce'[`_rr']) == "" {
			local _mc_has : list _mc_b in _mc_in
			if `_mc_b' == 0 | !`_mc_has' continue
			* missing from the model: did its estimation sample hold the level?
			local _sig = ustrregexra(`"`_rt_key'"', "(^|#)[0-9]+\.", "$1*.")
			local _pos = strpos(`"`_fcl_s'"', `";`_sig'="')
			if `_pos' > 0 {
				local _frag = substr(`"`_fcl_s'"', `_pos' + strlen(`";`_sig'="'), .)
				local _frag = substr(`"`_frag'"', 1, strpos(`"`_frag'"', ";") - 1)
				local _held : list _rt_key in _frag
			}
			else {
				local _held = 1
				local _mc_unk "`_mc_unk' `_rt_key'"
			}
			local ++_n_absent
			local _mc_ab_`_m' "`_mc_ab_`_m'' `_rr'"
			if `_held' {
				local _mc_lbl : copy local notestlabel
				local _mc_kind "mk_ne"
			}
			else {
				if `"`macval(absentlabel)'"' == "" continue
				local _mc_lbl : copy local absentlabel
				local _mc_kind "mk_ab"
			}
		}
		else {
			if inlist(_constraint`_m'[`_rr'], "base", "cns") continue
			local _pos = strpos(`"`_fct_s'"', `";`_rt_key'="')
			* a term that is not a factor level is masked only when the
			* counts cover it (a 0/1 indicator); others have no count
			if `_mc_b' == 0 & `_pos' == 0 continue
			if `_pos' == 0 {
				noisily display as error "mincount(): the fit-time counts of model `_m' do not cover `_rt_key';" ///
					" run tabtools fitcount, terms right after that model's fit"
				exit 459
			}
			local _frag = substr(`"`_fct_s'"', `_pos' + strlen(`";`_rt_key'="'), .)
			local _frag = substr(`"`_frag'"', 1, strpos(`"`_frag'"', ";") - 1)
			local _bar = strpos(`"`_frag'"', "|")
			local _tev = real(substr(`"`_frag'"', 1, `_bar' - 1))
			local _tvok = real(substr(`"`_frag'"', `_bar' + 1, .))
			if missing(`_tev') | missing(`_tvok') {
				noisily display as error "mincount(): unreadable fit-time count for `_rt_key' in model `_m'"
				exit 459
			}
			local _mc_kind "mk_ne"
			if `_tvok' != 1 | _constraint`_m'[`_rr'] != "" local _mc_lbl : copy local notestlabel
			else if `_tev' < `mincount' {
				local _mc_lbl : copy local emptylabel
				local _mc_kind "mk_th"
			}
			else continue
			local ++_n_masked
		}
		quietly replace c`_ce' = `"`macval(_mc_lbl)'"' in `_rr'
		quietly replace c`=`_ce' + 1' = "" in `_rr'
		quietly replace c`=`_ce' + 2' = "" in `_rr'
		quietly replace _constraint`_m' = "`_mc_kind'" in `_rr'
		foreach _ev in est ll ul p {
			capture confirm variable _eplot_`_ev'`_m'
			if !_rc quietly replace _eplot_`_ev'`_m' = . in `_rr'
		}
	}
	if "`_mc_unk'" != "" {
		noisily display as text "(regtab: model `_m': the fit-time counts do not record which levels its" ///
			" estimation sample holds, so`_mc_unk' missing from it" ///
			" are shown as notestlabel(); rerun tabtools fitcount, terms after the fit to tell" ///
			" levels it leaves out, shown as absentlabel())"
	}
}
drop _mc_par _mc_blk
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end

* Folded from _regtab_modelnoun.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_modelnoun Version 1.2.0  2026/11/19
* the model named in the methods sentence
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

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
		else if "`_w'" == "clogit" local _n "conditional logistic regression"
		else if "`_w'" == "probit" local _n "probit regression"
		else if "`_w'" == "hetprobit" local _n "heteroskedastic probit regression"
		else if inlist("`_w'", "qreg", "bsqreg", "sqreg") local _n "quantile regression"
		else if "`_w'" == "ivregress" local _n "instrumental-variables regression"
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
		else if inlist("`_w'", "streg", "stintreg") {
			if "`_sc'" == "HR" local _n "parametric proportional hazards survival regression"
			else local _n "accelerated failure-time survival regression"
			if "`_w'" == "stintreg" local _n "interval-censored `_n'"
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

* Folded from _regtab_mstats.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_mstats Version 1.2.0  2026/11/19
* regtab block: per-model statistics for stats() from the collection
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end, so
* it reads and writes regtab's locals exactly as before. regtab calls it as
* "noisily _regtab_mstats" from inside its quietly block and the body is quietly
* again, so only the block's own noisily lines print. Data in memory, frames,
* and the collection are shared state and need no transport.
capture program drop _regtab_mstats
program define _regtab_mstats, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
    * =========================================================================
    * STORE MODEL STATISTICS BEFORE COLLECT EXPORT
    * =========================================================================
    * Store e() statistics for each model in the collection
    * These may get cleared during processing, so capture them now

    local add_stats = 0
    if "`stats'" != "" | `_cst_n' > 0 {
        local add_stats = 1

        * Parse requested statistics
        local want_n = 0
        local want_obs = 0
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
        local want_people = 0
        local want_exposure = 0

        local stats_lower = " " + strlower("`stats'") + " "
        if strpos("`stats_lower'", " n ") local want_n = 1
        * obs: e(N), the observations (records, intervals) even where n
        * reports subjects (e(N_sub)) for a survival model
        if strpos("`stats_lower'", " obs ") local want_obs = 1
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
        * people and exposure come only from tabtools fitcount; events from
        * fitcount when the model has it, else from e(N_fail)
        if strpos("`stats_lower'", " people ") local want_people = 1
        if strpos("`stats_lower'", " exposure ") local want_exposure = 1

        * Aliases: treat n_sub / subjects as a request for the N row; regtab
        * already prefers N_sub (subjects) over N (rows) for survival models.
        if strpos("`stats_lower'", " n_sub ") | strpos("`stats_lower'", " subjects ") ///
            local want_n = 1

        * Warn (do not silently drop) on unrecognized stats() tokens.
        local _stat_known " n n_sub subjects obs aic bic qic icc ll groups r2 r-squared events people exposure r2_a rmse f mi_m fmi "
        foreach _stok of local stats {
            local _stok_l = strlower("`_stok'")
            if !strpos("`_stat_known'", " `_stok_l' ") {
                noisily display as error ///
                    "warning: stats() token '`_stok'' not recognized and ignored;" ///
                    " valid: n (n_sub/subjects) obs events people exposure groups mi_m aic bic qic ll icc r2 r2_a rmse F fmi"
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
        * N_mi: mi estimate, esampvaryok leaves e(N) missing and reports the
        * average number of observations, as its own header prints it
        if `want_n' | `want_bic' | `want_obs' local result_levels "N N_sub N_mi"
        if `want_ll' | `want_aic' | `want_bic' {
            local result_levels "`result_levels' ll"
        }
        if `want_aic' local result_levels "`result_levels' aic"
        * N_ic: the N of BIC when the command sets it ([R] IC note: the cm
        * choice models set it to the number of cases)
        if `want_bic' local result_levels "`result_levels' bic N_ic"
        if `want_aic' | `want_bic' | `want_qic' {
            * e(rank) and the counts that can cap it under a robust-type vce
            local result_levels "`result_levels' rank N_clust N_reps"
            if `_any_gee' local result_levels "`result_levels' N_g"
        }
        if `want_qic' | `want_aic' {
            local result_levels "`result_levels' deviance"
            if `_any_gee' local result_levels "`result_levels' phi"
        }
        if `want_groups' local result_levels "`result_levels' N_g"
        if `want_r2' local result_levels "`result_levels' r2 r2_p r2_a"
        if `want_events' local result_levels "`result_levels' N_fail tt_events"
        if `want_people' local result_levels "`result_levels' tt_people"
        if `want_exposure' local result_levels "`result_levels' tt_exposure"
        if `want_r2_a' local result_levels "`result_levels' r2_a"
        if `want_rmse' local result_levels "`result_levels' rmse"
        if `want_F' local result_levels "`result_levels' F"
        if `want_mi_m' local result_levels "`result_levels' M_mi"
        if `want_fmi' local result_levels "`result_levels' fmi_max_mi"
        local result_levels : list uniq result_levels

        if "`result_levels'" != "" {
            * Export headers are the level names: relabel the present levels
            * with their names and restore their labels exactly afterwards.
            * Absent levels stay out of the layout, which would add them to
            * the user's collection.
            _regtab_rlabels `result_levels'
            local result_levels "`_rl_present'"
            if "`result_levels'" == "" {
                * none of the requested statistics is in the collection:
                * every model's statistics are blank
                local n_stat_models = `_meta_models'
                forvalues m = 1/`n_stat_models' {
                    foreach lname in N N_sub ll aic bic qic rank deviance phi groups r2 ///
                        r2_p r2_a events rmse F mi_m fmi N_clust N_reps people exposure ///
                        tt_events N_mi N_ic obs {
                        local stat_`lname'_`m' = .
                    }
                }
            }
        }
        if "`result_levels'" != "" {
            capture {
                collect layout (cmdset) (result[`result_levels'])
            }
            local _stats_rc = _rc
            if `_stats_rc' == 0 {
                preserve
                * stata-dev-ignore: capture-rc — a braced capture stops at its first error; _rc is read on the first line after the closing brace
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
                    foreach _sx in N_fail rmse F M_mi fmi_max_mi N_clust N_reps ///
                        tt_events tt_people tt_exposure N_mi N_ic {
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
                        foreach _sx in N_fail rmse F M_mi fmi_max_mi N_clust N_reps ///
                            tt_events tt_people tt_exposure N_mi N_ic {
                            if "`hdr'" == "`_sx'" local stat_col_`_sx' "`v'"
                        }
                    }

                    local n_stat_models = _N - 1

                    forvalues m = 1/`n_stat_models' {
                        local r = `m' + 1

                        * Extract each result level
                        foreach sname in N N_sub ll aic bic rank deviance phi N_g r2 r2_p r2_a ///
                            N_fail rmse F M_mi fmi_max_mi N_clust N_reps ///
                            tt_events tt_people tt_exposure N_mi N_ic {
                            if "`sname'" == "N_g" local lname "groups"
                            else if "`sname'" == "N_fail" local lname "events"
                            else if "`sname'" == "M_mi" local lname "mi_m"
                            else if "`sname'" == "fmi_max_mi" local lname "fmi"
                            else if "`sname'" == "tt_people" local lname "people"
                            else if "`sname'" == "tt_exposure" local lname "exposure"
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

                        * Fit-time counts from tabtools fitcount take precedence
                        * over e(N_fail): they are what the user asked to count.
                        if !missing(`stat_tt_events_`m'') local stat_events_`m' = `stat_tt_events_`m''
                        if missing(`stat_N_`m'') & !missing(`stat_N_mi_`m'') {
                            local stat_N_`m' = `stat_N_mi_`m''
                        }
                        * obs keeps e(N) (or e(N_mi)); n may switch to N_sub below
                        local stat_obs_`m' = `stat_N_`m''

                        * Compute QIC_u from deviance + rank only for xtgee
                        * models whose dispersion is fixed at phi=1.
                        * NOTE: this is Pan's QIC_u (Cui 2007, eq. 2), the fixed-penalty
                        * approximation, NOT QIC. Pan's QIC penalty is
                        * 2*trace(Omega*Sigma); QIC_u replaces that trace with
                        * the rank. Pan's unknown-dispersion case requires one
                        * common phi across all candidate models; dividing each
                        * model by its own e(phi) would silently invalidate the
                        * comparison. The fixed-phi boundary is therefore
                        * deliberate and conservative.
                        * k, the parameter count of AIC, BIC, and QICu: the
                        * number of estimated free parameters, whatever the
                        * vce. That is e(rank), as estat ic uses: it leaves out
                        * base, omitted and constrained coefficients and nets
                        * out linear constraints, under a robust-type vce too.
                        * The one exception is a robust-type vce over too few
                        * clusters, GEE panels or replications: the sandwich
                        * variance has rank at most G-1 (R-1), so when that cap
                        * is below the count of collected coefficients with a
                        * nonzero standard error, e(rank) cannot reach the
                        * number the model estimated, and k is that count. The
                        * collection holds no e(Cns), so equality constraints
                        * are not netted out in that capped case (a constraint
                        * fixing a coefficient is: its SE is 0).
                        * Pan's QICu penalty is 2p (Cui 2007, eq. 2), with p the
                        * number of model parameters, so QICu follows suit.
                        local _k_param = `stat_rank_`m''
                        local _vce_m ""
                        if `m' <= `_meta_models' local _vce_m "`model_vce_`m''"
                        local stat_qic_`m' = .
                        local _this_is_gee = 0
                        if `m' <= `_meta_models' {
                            local _this_is_gee = `model_is_gee_`m''
                        }
                        if inlist("`_vce_m'", "robust", "cluster", "bootstrap", ///
                            "jackknife", "linearized", "brr", "sdr") & `m' <= `_sm_n' & ///
                            !missing(`_k_param') {
                            local _k_cap = .
                            if !missing(`stat_N_clust_`m'') local _k_cap = `stat_N_clust_`m'' - 1
                            if !missing(`stat_N_reps_`m'') local _k_cap = min(`_k_cap', `stat_N_reps_`m'' - 1)
                            if `_this_is_gee' & !missing(`stat_groups_`m'') {
                                local _k_cap = min(`_k_cap', `stat_groups_`m'' - 1)
                            }
                            if !missing(`_k_cap') & `_k_cap' < `_sm_k_`m'' & ///
                                `_k_param' < `_sm_k_`m'' {
                                local _k_param = `_sm_k_`m''
                            }
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
                        * N is e(N), unless the command set e(N_ic); then it is
                        * e(N_ic), as estat ic uses ([R] IC note).
                        local _n_bic = `stat_N_`m''
                        if !missing(`stat_N_ic_`m'') local _n_bic = `stat_N_ic_`m''
                        if !`_this_is_gee' & !missing(`stat_ll_`m'') & ///
                            !missing(`_k_param') & !missing(`_n_bic') {
                            local stat_bic_`m' = -2 * `stat_ll_`m'' + `_k_param' * ln(`_n_bic')
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
            * the table is rendered: back to the collection's own labels
            forvalues _rli = 1/`_rl_n' {
                local _rlv : word `_rli' of `_rl_present'
                quietly collect label levels result `_rlv' `"`macval(_rl_lbl_`_rli')'"', modify
            }
        }

        * A requested group count must come from the collection.  Active e()
        * is separate state and may describe a later, unrelated fit.
        * A model that names a grouping variable (e(group): clogit) but
        * posts no group count has one that cannot be read back from the
        * collection, which holds neither e(N_g) nor the data's e(sample).
        * The table still renders.  When no model reports a count the Groups
        * row is left out and a note names the models and the remedy; when
        * another model does report one, the model without it has a blank
        * cell, as for any statistic a model does not report, and a note
        * names it.
        if `n_stat_models' > 0 & `want_groups' == 1 {
            local _all_grp_miss = 1
            local _groups_supported = 0
            local _grp_nocount ""
            forvalues m = 1/`n_stat_models' {
                if !missing(`stat_groups_`m'') local _all_grp_miss = 0
                if `m' <= `_meta_models' {
                    if "`model_re_family_`m''" != "none" local _groups_supported = 1
                    if missing(`stat_groups_`m'') & `"`model_groupvar_`m''"' != "" {
                        local _grp_nocount "`_grp_nocount' `m'"
                    }
                }
            }
            local _grp_nocount = strtrim("`_grp_nocount'")
            if `_all_grp_miss' & `_groups_supported' {
                noisily display as error ///
                    "Could not recover requested group counts from the active collection"
                exit 459
            }
            if "`_grp_nocount'" != "" {
                local _gm : word 1 of `_grp_nocount'
                if `_all_grp_miss' {
                    local _gdesc ""
                    local _gsep ""
                    foreach _gi of local _grp_nocount {
                        local _gdesc `"`_gdesc'`_gsep'model `_gi' (`model_cmdword_`_gi'', group variable `model_groupvar_`_gi'')"'
                        local _gsep "; "
                    }
                    noisily display as text ///
                        `"Note: stats(groups) left out: no model stores a group count; `_gdesc'"'
                    noisily display as text ///
                        `"      run tabtools fitcount, events(`model_depvar_`_gm'') people(`model_groupvar_`_gm'') right after the fit, then request stats(people) with statlabels(people "Groups")"'
                    * the row is left out here, so the generic left-out note
                    * has nothing to add for it
                    local want_groups = 0
                }
                else {
                    noisily display as text ///
                        `"(regtab: stats(groups) is blank for model(s) `_grp_nocount': the fit stores no group count; see tabtools fitcount, people())"'
                }
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
                * stata-dev-ignore: capture-rc — a braced capture stops at its first error; _rc is read on the first line after the closing brace
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

        * Generic e(name) items: see _regtab_estats. Each distinct name is
        * read once; item # then holds its first name's values in _cstv_#_m
        * (and integer flag _cst_int_#), a pair's second in _cstv2_#_m.
        if `_cst_n' > 0 {
            local _cst_nmod = max(`_meta_models', 1)
            local _cst_names ""
            forvalues _k = 1/`_cst_n' {
                if "`_cst_kind_`_k''" != "e" continue
                local _cst_names : list _cst_names | _cst_nm_`_k'
                if "`_cst_nm2_`_k''" != "" local _cst_names : list _cst_names | _cst_nm2_`_k'
            }
            if "`_cst_names'" != "" {
                _regtab_estats `_cst_nmod' `_cst_names'
                local _cst_np : word count `_cst_names'
                forvalues _p = 1/`_cst_np' {
                    local _cei_`_p' = `_cst_int_`_p''
                    forvalues m = 1/`_cst_nmod' {
                        local _cev_`_p'_`m' = `_cstv_`_p'_`m''
                    }
                }
            }
            forvalues _k = 1/`_cst_n' {
                local _cst_int_`_k' = 1
                local _cst_int2_`_k' = 1
                forvalues m = 1/`_cst_nmod' {
                    local _cstv_`_k'_`m' = .
                    local _cstv2_`_k'_`m' = .
                }
                if "`_cst_kind_`_k''" != "e" continue
                foreach _s in "" 2 {
                    if "`_cst_nm`_s'_`_k''" == "" continue
                    local _p : list posof "`_cst_nm`_s'_`_k''" in _cst_names
                    local _cst_int`_s'_`_k' = `_cei_`_p''
                    forvalues m = 1/`_cst_nmod' {
                        local _cstv`_s'_`_k'_`m' = `_cev_`_p'_`m''
                    }
                }
            }
        }
    }
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end

* Folded from _regtab_optstr.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_optstr Version 1.2.0  2026/11/19
* display-option text of a collected command line
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

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

* Folded from _regtab_prefopts.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_prefopts Version 1.2.0  2026/11/19
* display options given to an estimation prefix
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

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

* Folded from _regtab_relabel.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_relabel Version 1.2.0  2026/11/19
* regtab block: relabel random-effects rows (relabel)
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end, so
* it reads and writes regtab's locals exactly as before. regtab calls it as
* "noisily _regtab_relabel" from inside its quietly block and the body is quietly
* again, so only the block's own noisily lines print. Data in memory, frames,
* and the collection are shared state and need no transport.
capture program drop _regtab_relabel
program define _regtab_relabel, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
* Relabel random effects if requested
if "`relabel'" != "" {
    * Equation-qualified residual terms (tobit, intreg, meglm, ...):
    * var(e.y) / sd(e.y) are one token; relabel the whole token so the
    * depvar stays in its own parentheses.
    * Substring rewrites touch only random-effects rows (_is_re, keyed on the
    * raw coefficient name) or a whole parameter token, never part of a
    * covariate's name or label: has_consent became hasInterceptent and a
    * label "Log sd(income)" became "Log SD (income)".
    replace A = ustrregexra(A, "var\(e\.([^()]+)\)", "Residual Variance (\$1)") if _is_re
    replace A = ustrregexra(A, "sd\(e\.([^()]+)\)", "Residual SD (\$1)") if _is_re
    if "`re_groupvars'" != "" & "`re_groupvars'" != "." {

        * --- Per-level relabeling (bracket notation) ---
        * Handles multi-level mixed (flattened) and melogit/mepoisson (native)
        forvalues _lev = 1/`_n_re_levels' {
            local _gvar `"`re_groupvar_`_lev''"'
            local _glbl : copy local re_grouplbl_`_lev'

            * Random intercept: var(_cons[groupvar]) -> "Variance: GroupLabel (Intercept)"
            replace A = `"Variance: `macval(_glbl)' (Intercept)"' if _is_re & A == "var(_cons[`_gvar'])"

            * Random slopes: var(varname[groupvar]) -> "Variance: GroupLabel (VarLabel)"
            foreach revar of local re_vars {
                if "`revar'" != "_cons" {
                    local slope_lbl : copy local lbl_`revar'
                    replace A = `"Variance: `macval(_glbl)' (`macval(slope_lbl)')"' if _is_re & A == "var(`revar'[`_gvar'])"
                }
            }

            * Covariances: cov(var1,var2[groupvar]) -> "Covariance: GroupLabel (Label1, Label2)"
            count if _is_re & strpos(A, "cov(") > 0 & strpos(A, "[`_gvar']") > 0
            if r(N) > 0 {
                gen _temp_row = _n
                levelsof _temp_row if _is_re & strpos(A, "cov(") > 0 & strpos(A, "[`_gvar']") > 0, local(cov_rows)
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
                                local cov_lbl`_cvk' : copy local _rel_lb_`_rli'
                            }
                        }
                    }
                    replace A = `"Covariance: `macval(_glbl)' (`macval(cov_lbl1)', `macval(cov_lbl2)')"' in `row'
                }
                drop _temp_row
            }

            * Standard deviations with brackets
            replace A = `"`macval(_glbl)' SD (Intercept)"' if _is_re & A == "sd(_cons[`_gvar'])"
            foreach revar of local re_vars {
                if "`revar'" != "_cons" {
                    local slope_lbl : copy local lbl_`revar'
                    replace A = `"`macval(_glbl)' SD (`macval(slope_lbl)')"' if _is_re & A == "sd(`revar'[`_gvar'])"
                }
            }

            * Slope variances/SDs the metadata does not name. The me*
            * estimators record no e(revars) in the collection, so their
            * var(x[g]) rows stayed raw while mixed's were relabelled. Take the
            * slope name from the key itself.
            capture drop _temp_row
            gen long _temp_row = _n
            quietly levelsof _temp_row if _n > 2 & _is_re & ///
                ustrregexm(A, "^(var|sd)\([^\[\]\(\),]+\[`_gvar'\]\)$"), local(_sl_rows)
            foreach row of local _sl_rows {
                local _sl_key = A[`row']
                if !ustrregexm(`"`_sl_key'"', "^(var|sd)\(([^\[\]\(\),]+)\[") continue
                local _sl_kind = ustrregexs(1)
                local _sl_var = ustrregexs(2)
                if "`_sl_var'" == "_cons" continue
                local _sl_lbl "`_sl_var'"
                forvalues _rli = 1/`_rel_n' {
                    if "`_rel_nm_`_rli''" == "`_sl_var'" local _sl_lbl : copy local _rel_lb_`_rli'
                }
                if "`_sl_kind'" == "var" {
                    replace A = `"Variance: `macval(_glbl)' (`macval(_sl_lbl)')"' in `row'
                }
                else {
                    replace A = `"`macval(_glbl)' SD (`macval(_sl_lbl)')"' in `row'
                }
            }
            drop _temp_row
        }

        * --- Single-level patterns (no brackets) for single-level mixed ---
        * Every rewrite in this block is gated on _is_re (the raw coefficient
        * name), so a covariate label such as "Dose cov(x)" is never touched.
        replace A = `"Variance: `macval(re_grouplbl)' (Intercept)"' if _is_re & A == "var(_cons)"

        foreach revar of local re_vars {
            if "`revar'" != "_cons" {
                local slope_lbl : copy local lbl_`revar'
                replace A = `"Variance: `macval(re_grouplbl)' (`macval(slope_lbl)')"' if _is_re & A == "var(`revar')"
            }
        }

        * Covariances without brackets (single-level mixed)
        count if _is_re & strpos(A, "cov(") > 0
        if r(N) > 0 {
            gen _temp_row = _n
            levelsof _temp_row if _is_re & strpos(A, "cov(") > 0, local(cov_rows)
            foreach row of local cov_rows {
                local cov_str = A[`row']
                local cov_inner = subinstr("`cov_str'", "cov(", "", 1)
                local cov_inner = subinstr("`cov_inner'", ")", "", 1)
                gettoken cov_v1 cov_v2 : cov_inner, parse(",")
                local cov_v2 = subinstr("`cov_v2'", ",", "", 1)
                local cov_v1 = strtrim("`cov_v1'")
                local cov_v2 = strtrim("`cov_v2'")
                local cov_lbl1 : copy local lbl_`cov_v1'
                if `"`macval(cov_lbl1)'"' == "" local cov_lbl1 "`cov_v1'"
                local cov_lbl2 : copy local lbl_`cov_v2'
                if `"`macval(cov_lbl2)'"' == "" local cov_lbl2 "`cov_v2'"
                replace A = `"Covariance: `macval(re_grouplbl)' (`macval(cov_lbl1)', `macval(cov_lbl2)')"' in `row'
            }
            drop _temp_row
        }

        * Residual variance: var(e) -> "Residual Variance"
        replace A = "Residual Variance" if _is_re & A == "var(e)"

        * Standard deviations without brackets (single-level)
        replace A = `"`macval(re_grouplbl)' SD (Intercept)"' if _is_re & A == "sd(_cons)"
        foreach revar of local re_vars {
            if "`revar'" != "_cons" {
                local slope_lbl : copy local lbl_`revar'
                replace A = `"`macval(re_grouplbl)' SD (`macval(slope_lbl)')"' if _is_re & A == "sd(`revar')"
            }
        }
        replace A = "Residual SD" if _is_re & A == "sd(e)"

        * Log-scale parameters (raw coefficient names: lns1_1_1, lns2_1_1, ...)
        forvalues _lev = 1/`_n_re_levels' {
            local _glbl : copy local re_grouplbl_`_lev'
            replace A = ustrregexra(A, "(?<![A-Za-z0-9_])lns`_lev'_1_1(?![A-Za-z0-9_])", `"`macval(_glbl)' Log SD (Intercept)"')
        }
        replace A = ustrregexra(A, "(?<![A-Za-z0-9_])lnsig_e(?![A-Za-z0-9_])", "Residual Log SD")
    }
    else {
        * Fallback: no random effects info, use generic labels
        replace A = subinstr(A, "var(_cons)", "Variance (Intercept)", .) if _is_re
        replace A = subinstr(A, "var(e)", "Residual Variance", .) if _is_re
        replace A = subinstr(A, "var(", "Variance (", .) if _is_re
        replace A = subinstr(A, "cov(", "Covariance (", .) if _is_re
        replace A = subinstr(A, "sd(_cons)", "SD (Intercept)", .) if _is_re
        replace A = subinstr(A, "sd(", "SD (", .) if _is_re
        * Log-scale parameters: handle all levels (lns1_1_1, lns2_1_1, ...)
        if `_n_re_levels' > 0 {
            forvalues _lev = 1/`_n_re_levels' {
                replace A = ustrregexra(A, "(?<![A-Za-z0-9_])lns`_lev'_1_1(?![A-Za-z0-9_])", "Log SD (Level `_lev' Intercept)")
            }
        }
        else {
            replace A = ustrregexra(A, "(?<![A-Za-z0-9_])lns1_1_1(?![A-Za-z0-9_])", "Log SD (Intercept)")
        }
        replace A = ustrregexra(A, "(?<![A-Za-z0-9_])lnsig_e(?![A-Za-z0-9_])", "Log SD (Residual)")
    }

    * Clean up _cons in fixed effects (Intercept row): the whole token only
    replace A = ustrregexra(A, "(?<![A-Za-z0-9_])_cons(?![A-Za-z0-9_])", "Intercept")
}
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end

* Folded from _regtab_remeta.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_remeta Version 1.2.0  2026/11/19
* regtab block: random-effects, factor, and equation labels before rendering
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end, so
* it reads and writes regtab's locals exactly as before. regtab calls it as
* "noisily _regtab_remeta" from inside its quietly block and the body is quietly
* again, so only the block's own noisily lines print. Data in memory, frames,
* and the collection are shared state and need no transport.
capture program drop _regtab_remeta
program define _regtab_remeta, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
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
            * C1 (codex audit 2026-09-26): labels are data. Every copy,
            * test and write of a label below is macval()/Mata protected, so a
            * $word or a backtick in a label is never expanded.
            * stata-dev-ignore: capture-rc — a missing label is the expected case; the default label is set on the next line
            capture local _glbl : variable label `_gvar'
            if `"`macval(_glbl)'"' == "" local _glbl "`_gvar'"
            local re_grouplbl_`_lev' : copy local _glbl
        }

        * Detect duplicate labels: if two levels share a label, fall back to
        * variable names so relabeled output is unambiguous
        if `_n_re_levels' > 1 {
            * First pass: flag which levels have duplicate labels
            forvalues _lev = 1/`_n_re_levels' {
                local _lbl_is_dup_`_lev' = 0
                forvalues _other = 1/`_n_re_levels' {
                    mata: st_local("_same", strofreal(st_local("re_grouplbl_`_other'") == st_local("re_grouplbl_`_lev'")))
                    if `_other' != `_lev' & `_same' {
                        local _lbl_is_dup_`_lev' = 1
                    }
                }
            }
            * Second pass: apply fallback for flagged levels
            forvalues _lev = 1/`_n_re_levels' {
                if `_lbl_is_dup_`_lev'' {
                    local re_grouplbl_`_lev' : copy local re_groupvar_`_lev'
                }
            }
        }

        * Backward compat: single-level vars from first grouping variable
        local re_groupvar : word 1 of `re_groupvars'
        local re_grouplbl : copy local re_grouplbl_1

        if "`re_vars'" != "" {
            * Store labels for each random effect variable
            foreach revar of local re_vars {
                if "`revar'" == "_cons" {
                    local lbl_`revar' "Intercept"
                }
                else {
                    * stata-dev-ignore: capture-rc — a missing label is the expected case; the default label is set on the next line
                    capture local lbl_`revar' : variable label `revar'
                    if `"`macval(lbl_`revar')'"' == "" local lbl_`revar' "`revar'"
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
                    if `"`macval(_rel_lb_`_rel_n')'"' == "" local _rel_lb_`_rel_n' "`_rn'"
                }
            }
        }
    }

    * Capture factor variable value labels for factorlabel option
    if "`factorlabel'" != "" {
        local _fvlabel_cmds ""
        local _fvlc_n = 0
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
                        mata: st_local("_same", strofreal(st_local("_fvlbl") == st_local("_fvval")))
                        if `"`macval(_fvlbl)'"' != "" & !`_same' {
                            * Indexed, not packed into one list: a label is
                            * never split on its spaces or expanded.
                            local ++_fvlc_n
                            local _fvlc_pat_`_fvlc_n' "`_fvval'.`_fvvar'"
                            local _fvlc_lab_`_fvlc_n' : copy local _fvlbl
                            local _fvlabel_cmds "set"
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
            * An interaction ("1.foreign#c.weight", "c.mpg#c.weight") gets its
            * labels from the components' variable and value labels; collect
            * would print the raw key.
            if strpos("`_fvterm'", "#") > 0 {
                _tabtools_fvterm_label `"`_fvterm'"'
                if `"`macval(_fvt_label)'"' == "" continue
                local ++_fvrow_label_n
                local _fvrow_pat_`_fvrow_label_n' `"`_fvterm'"'
                local _fvrow_lab_`_fvrow_label_n' : copy local _fvt_label
                if `"`_fvt_parent'"' == "" continue
                local _fvrow_parent_seen = 0
                forvalues _fvp = 1/`_fvrow_parent_n' {
                    if `"`_fvrow_parent_var_`_fvp''"' == `"`_fvt_parent'"' ///
                        local _fvrow_parent_seen = 1
                }
                if !`_fvrow_parent_seen' {
                    local ++_fvrow_parent_n
                    local _fvrow_parent_var_`_fvrow_parent_n' `"`_fvt_parent'"'
                    local _fvrow_parent_lab_`_fvrow_parent_n' : copy local _fvt_plabel
                }
                continue
            }
            if regexm("`_fvterm'", "^([0-9]+)\.(.+)$") {
                local _fvval = regexs(1)
                local _fvvar = regexs(2)
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
                        if `"`macval(_fvplbl)'"' == "" local _fvplbl `"`_fvvar'"'
                        local ++_fvrow_parent_n
                        local _fvrow_parent_var_`_fvrow_parent_n' `"`_fvvar'"'
                        local _fvrow_parent_lab_`_fvrow_parent_n' : copy local _fvplbl
                    }
                    local _fvlbl `"`_fvval'"'
                    * stata-dev-ignore: capture-rc — a missing label is the expected case; the default label is set on the next line
                    capture local _fvlbl : label (`_fvvar') `_fvval'
                    if `"`macval(_fvlbl)'"' == "" local _fvlbl "`_fvval'"
                    local ++_fvrow_label_n
                    local _fvrow_pat_`_fvrow_label_n' `"`_fvterm'"'
                    local _fvrow_lab_`_fvrow_label_n' `"  `macval(_fvlbl)'"'
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
        * Outcome labels belong to the collected model. Ambient e() may
        * describe a later fit, so use an unambiguous collected identity.
        if `_meta_models' > 0 {
            local _depvar `"`model_depvar_1'"'
            forvalues _m = 2/`_meta_models' {
                if `"`model_depvar_`_m''"' != `"`_depvar'"' local _depvar ""
            }
        }
        if "`_depvar'" != "" {
            capture local _dep_label : variable label `_depvar'
            local _dep_label_rc = _rc
            local _dep_vallab ""
            capture local _dep_vallab : value label `_depvar'
            local _dep_vallab_rc = _rc
            if "`_dep_vallab'" != "" {
                capture levelsof `_depvar', local(_dep_levels_for_eq)
                local _dep_levels_rc = _rc
                if `_dep_levels_rc' == 0 {
                    foreach _dlev of local _dep_levels_for_eq {
                        local _dlbl ""
                        * stata-dev-ignore: capture-rc — a missing label is the expected case; the default label is set on the next line
                        capture local _dlbl : label `_dep_vallab' `_dlev'
                        if `"`macval(_dlbl)'"' != "" {
                            local ++_coleq_label_n
                            local _coleq_key_`_coleq_label_n' `"`_dlev'"'
                            mata: st_local("_coleq_key2_`_coleq_label_n'", strtoname(st_local("_dlbl")))
                            local _coleq_lab_`_coleq_label_n' : copy local _dlbl
                        }
                    }
                }
            }
        }
    }
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end

* Folded from _regtab_rlabels.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_rlabels Version 1.2.0  2026/11/19
* hand result levels to a layout under their own names
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* =============================================================================
* _regtab_rlabels: hand result levels to a layout under their own names
* =============================================================================
* Usage: _regtab_rlabels <level> [<level> ...]
* Keeps the listed result levels present in the current collection (a layout
* naming an absent level adds that level to the user's collection), records
* each one's current label, and relabels it with its level name, so a layout
* of them exports the level names as column headers. Returns in the caller:
* _rl_present (the present levels, in collection order), _rl_n, and _rl_lbl_#
* (the label of the #th present level, "" when it had none). The caller
* restores each with collect label levels result <level> `"<label>"', modify;
* an empty label removes the one set here, as collect label documents. The
* labels are read from collect label list's s() results through Mata, so no
* label text is macro-expanded.
capture program drop _regtab_rlabels
program define _regtab_rlabels, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	c_local _rl_present ""
	c_local _rl_n 0
	capture noisily {
		local _want `0'
		local _k ""
		capture quietly collect label list result, all
		if _rc == 0 mata: st_local("_k", st_global("s(k)"))
		if "`_k'" == "" local _k 0
		local _n 0
		local _present ""
		forvalues _i = 1/`_k' {
			mata: st_local("_lv", st_global("s(level`_i')"))
			local _hit : list _lv in _want
			if !`_hit' continue
			local ++_n
			local _present `_present' `_lv'
			mata: st_local("_lb`_n'", st_global("s(label`_i')"))
		}
		forvalues _j = 1/`_n' {
			local _lv : word `_j' of `_present'
			quietly collect label levels result `_lv' "`_lv'", modify
			c_local _rl_lbl_`_j' `"`macval(_lb`_j')'"'
		}
		c_local _rl_present "`_present'"
		c_local _rl_n `_n'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* Folded from _regtab_role.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_role Version 1.2.0  2026/11/19
* structural role of one collected coefficient
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

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

* Folded from _regtab_scale.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_scale Version 1.2.0  2026/11/19
* display scale of one collected model
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

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
*   _rs_known  1 when the command has a dedicated rule, or an eform display
*              option (or, irr, hr, rrr, rr, shr, tr, eform) names the scale
*   _rs_level  confidence level requested with level(), or -1 when absent
* Ratio families are always shown on the ratio scale: a fit displayed on the
* coefficient scale (logit without or, stcox with nohr, logistic with coef,
* streg or stintreg in the time metric without tratio) is exponentiated, and a fit Stata
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

		if inlist("`_rs_word'", "logit", "ologit", "melogit", "clogit") {
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
			* zip and zinb, irr exponentiate the count equation only; the
			* inflation equation stays on the logit or probit scale, so
			* regtab never exponentiates these itself (under mi estimate the
			* command's irr does not apply, and the values stay coefficients).
			if "`_rs_word'" != "churdle" & "`_rs_pmode'" != "mi" {
				_regtab_cmdopts "IRr" `"`_rs_opt'"'
				if "`_ro_irr'" != "" {
					local _c "IRR"
					local _n 1
				}
			}
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
		else if inlist("`_rs_word'", "streg", "stintreg", "mestreg") {
			* Metric rules from streg.ado/stintreg.ado/mestreg.ado: exponential
			* and Weibull fit in the log-hazard metric unless time (or, for
			* streg and stintreg, tratio) is given; Gompertz is log-hazard
			* only; lognormal, loglogistic and (generalized) gamma are log-time
			* only. The hazard metric displays hazard ratios unless nohr; the
			* time metric displays coefficients unless tratio. stintreg, like
			* streg, names its distribution in e(cmd) (ereg, weibull,
			* gompertz, lnormal, llogistic, gamma; e(cmd2) is stintreg).
			_regtab_cmdopts "TIme TRatio noHR Distribution(string)" `"`_rs_opt'"'
			local _aft_opt = ("`_ro_time'`_ro_tratio'" != "")
			if "`_rs_word'" == "mestreg" local _aft_opt = ("`_ro_time'" != "")
			local _ph_capable 0
			local _ph_only 0
			if inlist("`_rs_word'", "streg", "stintreg") {
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
		else if inlist("`_rs_word'", "glm", "xtgee") {
			* Family/link abbreviations follow glm.ado's MapFam and MapLink;
			* xtgee takes the same Family(), Link() and EForm options and the
			* same defaults (binomial -> logit, poisson -> log), so a GEE fit
			* is shown on the scale glm gives the same family and link.
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
			* No dedicated rule. The collection holds _r_b as the command
			* displayed it ([R] table: "coefficients or transformed
			* coefficients reported by command"), so an eform display option
			* (xtlogit, or; xtpoisson, irr; cloglog, eform; meologit, or;
			* gnbreg, irr; meglm, eform; ...) means the values are already
			* ratios: named by the option, null 1, never exponentiated again.
			* Under mi estimate the command's own display options do not
			* apply ([MI] mi estimate); the prefix's do.
			_regtab_cmdopts "OR IRr HR RRR RR SHR TR EForm" `"`_rs_opt'"'
			local _gc ""
			if "`_ro_or'" != "" local _gc "OR"
			else if "`_ro_irr'" != "" local _gc "IRR"
			else if "`_ro_rrr'" != "" local _gc "RRR"
			else if "`_ro_shr'" != "" local _gc "SHR"
			else if "`_ro_hr'" != "" local _gc "HR"
			else if "`_ro_rr'" != "" local _gc "RR"
			else if "`_ro_tr'" != "" local _gc "TR"
			else if "`_ro_eform'" != "" | ///
				regexm(lower(`" `_rs_opt'"'), "[ ,]eform[(]") local _gc "exp(b)"
			if "`_rs_pmode'" == "mi" local _gc = cond(`_rs_peform', cond("`_gc'" == "", "exp(b)", "`_gc'"), "")
			else if "`_rs_pmode'" == "or" & `_rs_peform' & "`_gc'" == "" local _gc "exp(b)"
			if "`_gc'" != "" {
				local _c "`_gc'"
				local _n 1
				local _i 1
			}
			else local _k 0
		}

		* level(): glm and the multilevel families also take link(), so their
		* level() needs two letters; every other supported estimator takes l().
		local _lspec "Level(string)"
		if inlist("`_rs_word'", "glm", "xtgee", "meglm", "mestreg") local _lspec "LEvel(string)"
		_regtab_cmdopts "`_lspec'" `"`_rs_opt'"'
		local _lv = -1
		if `"`_ro_level'"' != "" {
			local _lv = real(`"`_ro_level'"')
			if missing(`_lv') local _lv = -1
		}

		* A prefix decides what the collection holds for a ratio family. glm
		* and xtgee already folded the prefix into _eopt above.
		if !inlist("`_rs_word'", "glm", "xtgee", "zip", "zinb") & `_n' == 1 {
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

* Folded from _regtab_statrows.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_statrows Version 1.2.0  2026/11/19
* regtab block: model statistics rows below the table body (stats())
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* A block of regtab's main program, kept in its own file so that regtab.ado
* stays well inside Stata's ado-file size limit. It is not a command of its
* own. regtab copies all its local macros to Mata (_regtab_nsN, _regtab_nsV)
* just before the call; the block loads them first, runs regtab's code as it
* was written inline, and hands every local back the same way at the end, so
* it reads and writes regtab's locals exactly as before. regtab calls it as
* "noisily _regtab_statrows" from inside its quietly block and the body is quietly
* again, so only the block's own noisily lines print. Data in memory, frames,
* and the collection are shared state and need no transport.
capture program drop _regtab_statrows
program define _regtab_statrows, nclass
	version 17.0
	local _rtns_vab = c(varabbrev)
	set varabbrev off
	capture noisily {
	mata: for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) st_local(_regtab_nsN[_regtab_nsI], _regtab_nsV[_regtab_nsI])
quietly {
*
* =========================================================================
* ADD MODEL STATISTICS ROWS (if requested)
* =========================================================================
local stats_start_row = 0
local stats_rows = ""
* stats_row_ids: one id per stats_rows entry, in the same order, for
* frame(, flat keys) (_term "stat:<id>"): the built-in word (n for
* n/n_sub/subjects, aic also when the row shows QICu, F), e(name) or
* e(name1|name2) for a generic item as typed without options or label, and
* text(#) for the #th text() item. Built-in words hold no parenthesis and
* generic e() items are unique, so no two rows share an id.
local stats_row_ids ""
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
    * Widths are wide enough that string() never falls back to e-notation
    * (Root MSE 962345.123 printed as 9.62e+05 under %9.3f) or drops the
    * thousands separator (1,234,567,890 under %12.0fc).
    local _nr_lab_obs "Observations"
    local _nr_fmt_obs "%20.0fc"
    local _nr_lab_events "Events"
    local _nr_fmt_events "%20.0fc"
    local _nr_lab_people "People"
    local _nr_fmt_people "%20.0fc"
    local _nr_lab_exposure : copy local exposurelabel
    local _nr_fmt_exposure "%20.0fc"
    local _nr_lab_mi_m "Imputations"
    local _nr_fmt_mi_m "%20.0fc"
    local _nr_lab_r2_a "Adjusted R²"
    local _nr_fmt_r2_a "%5.3f"
    local _nr_lab_rmse "Root MSE"
    local _nr_fmt_rmse "%20.3f"
    local _nr_lab_F "F statistic"
    local _nr_fmt_F "%20.2f"
    local _nr_lab_fmi "Largest FMI"
    local _nr_fmt_fmi "%6.4f"
    * statlabels(): a row label the user gave replaces the default
    foreach _nt in obs events people mi_m r2_a rmse fmi {
        if `"`macval(_stl_`_nt')'"' != "" {
        	local _nr_lab_`_nt' `"`macval(_stl_`_nt')'"'
        }
    }
    if `"`macval(_stl_f)'"' != "" {
    	local _nr_lab_F `"`macval(_stl_f)'"'
    }

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
            if `"`macval(_stl_n)'"' != "" {
            	local _n_label `"`macval(_stl_n)'"'
            }
            replace A = `"`macval(_n_label)'"' in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if !missing(`stat_N_`m'') {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = ustrregexra(string(`stat_N_`m'', "%20.0fc"), "-(?=[0.,]+\z)", "") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            local stats_row_ids "`stats_row_ids' n"
        }
    }


    foreach _nt in obs events people exposure {
        if `want_`_nt'' != 1 continue
        local has_val = 0
        forvalues m = 1/`use_models' {
            if !missing(`stat_`_nt'_`m'') local has_val = 1
        }
        if !`has_val' continue
        local curr_n = _N
        set obs `=`curr_n'+1'
        replace A = `"`macval(_nr_lab_`_nt')'"' in `=`curr_n'+1'
        forvalues m = 1/`use_models' {
            if !missing(`stat_`_nt'_`m'') {
                local col = (`m' - 1) * 3 + 1
                replace c`col' = ustrregexra(string(`stat_`_nt'_`m'', "`_nr_fmt_`_nt''"), "-(?=[0.,]+\z)", "") in `=`curr_n'+1'
            }
        }
        local stats_rows = "`stats_rows' `=`curr_n'+1'"
        local stats_row_ids "`stats_row_ids' `_nt'"
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
            local _grp_label "Groups"
            if `"`macval(_stl_groups)'"' != "" {
            	local _grp_label `"`macval(_stl_groups)'"'
            }
            replace A = `"`macval(_grp_label)'"' in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if !missing(`stat_groups_`m'') {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = ustrregexra(string(`stat_groups_`m'', "%20.0fc"), "-(?=[0.,]+\z)", "") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            local stats_row_ids "`stats_row_ids' groups"
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
        replace A = `"`macval(_nr_lab_`_nt')'"' in `=`curr_n'+1'
        forvalues m = 1/`use_models' {
            if !missing(`stat_`_nt'_`m'') {
                local col = (`m' - 1) * 3 + 1
                replace c`col' = ustrregexra(string(`stat_`_nt'_`m'', "`_nr_fmt_`_nt''"), "-(?=[0.,]+\z)", "") in `=`curr_n'+1'
            }
        }
        local stats_rows = "`stats_rows' `=`curr_n'+1'"
        local stats_row_ids "`stats_row_ids' `_nt'"
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
            local _aic_shown `"`_aic_label'"'
            if "`_aic_label'" == "AIC" & `"`macval(_stl_aic)'"' != "" {
            	local _aic_shown `"`macval(_stl_aic)'"'
            }
            if "`_aic_label'" == "QICu" & `"`macval(_stl_qic)'"' != "" {
            	local _aic_shown `"`macval(_stl_qic)'"'
            }
            replace A = `"`macval(_aic_shown)'"' in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if "`_aic_label'" == "AIC" {
                    if !missing(`stat_aic_`m'') {
                        local col = (`m' - 1) * 3 + 1
                        replace c`col' = ustrregexra(string(`stat_aic_`m'', "%20.2f"), "-(?=[0.,]+\z)", "") in `=`curr_n'+1'
                    }
                }
                else {
                    if !missing(`stat_qic_`m'') {
                        local col = (`m' - 1) * 3 + 1
                        replace c`col' = ustrregexra(string(`stat_qic_`m'', "%20.2f"), "-(?=[0.,]+\z)", "") in `=`curr_n'+1'
                    }
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            local stats_row_ids "`stats_row_ids' aic"
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
            local _qic_shown "QICu"
            if `"`macval(_stl_qic)'"' != "" {
            	local _qic_shown `"`macval(_stl_qic)'"'
            }
            replace A = `"`macval(_qic_shown)'"' in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if !missing(`stat_qic_`m'') {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = ustrregexra(string(`stat_qic_`m'', "%20.2f"), "-(?=[0.,]+\z)", "") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            local stats_row_ids "`stats_row_ids' qic"
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
            local _bic_shown "BIC"
            if `"`macval(_stl_bic)'"' != "" {
            	local _bic_shown `"`macval(_stl_bic)'"'
            }
            replace A = `"`macval(_bic_shown)'"' in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if !missing(`stat_bic_`m'') {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = ustrregexra(string(`stat_bic_`m'', "%20.2f"), "-(?=[0.,]+\z)", "") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            local stats_row_ids "`stats_row_ids' bic"
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
            local _ll_shown "Log-likelihood"
            if `"`macval(_stl_ll)'"' != "" {
            	local _ll_shown `"`macval(_stl_ll)'"'
            }
            replace A = `"`macval(_ll_shown)'"' in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                if !missing(`stat_ll_`m'') {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = ustrregexra(string(`stat_ll_`m'', "%20.2f"), "-(?=[0.,]+\z)", "") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            local stats_row_ids "`stats_row_ids' ll"
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
            local _icc_shown "ICC"
            if `"`macval(_stl_icc)'"' != "" {
            	local _icc_shown `"`macval(_stl_icc)'"'
            }
            replace A = `"`macval(_icc_shown)'"' in `=`curr_n'+1'
            forvalues m = 1/`use_icc_models' {
                if !missing(`stat_icc_`m'') {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = ustrregexra(string(`stat_icc_`m'', "%5.3f"), "-(?=[0.,]+\z)", "") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            local stats_row_ids "`stats_row_ids' icc"
        }
    }

    * Add R² / Pseudo R² row (F6)
    if `want_r2' == 1 {
        local has_r2 = 0
        forvalues m = 1/`use_models' {
            * Prefer r2, fallback to r2_p (pseudo), then r2_a (adjusted).
            * e(r2_a) is a different statistic ([XT] xtreg, Stored results:
            * e(r2) R², e(r2_a) adjusted R²), so it is used only while the
            * Adjusted R² row is not requested, and the label then says so.
            local _r2a_ok_`m' = !`want_r2_a' & missing(`stat_r2_`m'') & ///
                missing(`stat_r2_p_`m'') & !missing(`stat_r2_a_`m'')
            if !missing(`stat_r2_`m'') | !missing(`stat_r2_p_`m'') | `_r2a_ok_`m'' {
                local has_r2 = 1
            }
        }
        if `has_r2' {
            * The label names every kind of R² the row holds: R², Pseudo R²,
            * Adjusted R², joined by " / " when the models mix them.
            local _any_r2 = 0
            local _any_pseudo_r2 = 0
            local _any_adj_r2 = 0
            forvalues m = 1/`use_models' {
                if !missing(`stat_r2_`m'') local _any_r2 = 1
                if !missing(`stat_r2_p_`m'') local _any_pseudo_r2 = 1
                if `_r2a_ok_`m'' local _any_adj_r2 = 1
            }
            local r2_label ""
            if `_any_r2' local r2_label "R²"
            if `_any_pseudo_r2' local r2_label = cond("`r2_label'" == "", "Pseudo R²", "`r2_label' / Pseudo R²")
            if `_any_adj_r2' local r2_label = cond("`r2_label'" == "", "Adjusted R²", "`r2_label' / Adjusted R²")
            if `"`macval(_stl_r2)'"' != "" {
            	local r2_label `"`macval(_stl_r2)'"'
            }

            local curr_n = _N
            set obs `=`curr_n'+1'
            replace A = `"`macval(r2_label)'"' in `=`curr_n'+1'
            forvalues m = 1/`use_models' {
                local _r2val = .
                if !missing(`stat_r2_`m'') local _r2val = `stat_r2_`m''
                else if !missing(`stat_r2_p_`m'') local _r2val = `stat_r2_p_`m''
                else if `_r2a_ok_`m'' local _r2val = `stat_r2_a_`m''
                if !missing(`_r2val') {
                    local col = (`m' - 1) * 3 + 1
                    replace c`col' = ustrregexra(string(`_r2val', "%5.3f"), "-(?=[0.,]+\z)", "") in `=`curr_n'+1'
                }
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            local stats_row_ids "`stats_row_ids' r2"
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
        replace A = `"`macval(_nr_lab_`_nt')'"' in `=`curr_n'+1'
        forvalues m = 1/`use_models' {
            if !missing(`stat_`_nt'_`m'') {
                local col = (`m' - 1) * 3 + 1
                replace c`col' = ustrregexra(string(`stat_`_nt'_`m'', "`_nr_fmt_`_nt''"), "-(?=[0.,]+\z)", "") in `=`curr_n'+1'
            }
        }
        local stats_rows = "`stats_rows' `=`curr_n'+1'"
        local stats_row_ids "`stats_row_ids' `_nt'"
    }

    * A built-in row that no collected model reports is left out of the
    * table; the console says which, so a requested row is never dropped
    * without a word.
    local _omit_ids ""
    foreach _nt in n obs events people exposure groups mi_m aic qic bic ll icc ///
        r2 r2_a rmse F fmi {
        if `want_`_nt'' != 1 continue
        local _shown : list _nt in stats_row_ids
        if "`_nt'" == "qic" & `_qicu_rendered_by_aic' local _shown 1
        if !`_shown' local _omit_ids "`_omit_ids' `_nt'"
    }
    local _omit_ids = strtrim("`_omit_ids'")
    if "`_omit_ids'" != "" {
        noisily display as text "(regtab: no model reports " ///
            `"`: word count `_omit_ids'' requested statistic(s), left out of the table: `_omit_ids')"'
    }

    * Generic rows, in the order given. e(name): integers with thousands
    * separators, other values to three decimals, or the item's own format;
    * blank where a model lacks it. mincell(#) prints a value from 1 to #-1
    * as "<#", the package's small-cell text (tabcell, ratetab); a name in
    * several items takes the strictest mincell() given for it
    * (_cst_mc_#, _cst_mc2_#, from _regtab_statspec). e(a|b) prints
    * "a (b)", each part formatted and masked alone; "a" alone when b is
    * missing, and a blank cell when a is. text(): the values as given, one
    * per model; more values than models is an error.
    * maskwith() (complementary masking, this table only): names in one
    * group are masked together. In a model where any member prints <#
    * (primary), every other member with a value prints the withheld text,
    * the en dash, never a number, so no member gives a masked count back.
    local _n_stmask = 0
    local _n_stlink = 0
    local _cst_tk = 0
    local _cst_anymc = 0
    local _cst_dash = uchar(8211)
    local _cst_mods = min(`n_models', max(`_meta_models', 1))
    * primary masks first, so a group knows in which models it is masked
    forvalues _k = 1/`_cst_n' {
        if "`_cst_kind_`_k''" != "e" continue
        forvalues m = 1/`_cst_mods' {
            foreach _s in "" 2 {
                if "`_s'" == "2" & "`_cst_nm2_`_k''" == "" continue
                local _x = `_cstv`_s'_`_k'_`m''
                local _cst_pm`_s'_`_k'_`m' = (`_cst_mc`_s'_`_k'' > 0 & !missing(`_x') & `_x' >= 1 & `_x' < `_cst_mc`_s'_`_k'')
                if `_cst_pm`_s'_`_k'_`m'' & `_cst_g`_s'_`_k'' > 0 {
                    local _cst_trig_`_cst_g`_s'_`_k''_`m' = 1
                }
            }
        }
    }
    forvalues _k = 1/`_cst_n' {
        if "`_cst_kind_`_k''" == "text" & `_cst_tn_`_k'' > `n_models' {
            noisily display as error `"stats(): text("`macval(_cst_lb_`_k')'" ...) has `_cst_tn_`_k'' values for `n_models' models"'
            exit 198
        }
        local curr_n = _N
        set obs `=`curr_n'+1'
        replace A = `"`macval(_cst_lb_`_k')'"' in `=`curr_n'+1'
        if "`_cst_kind_`_k''" == "text" {
            local ++_cst_tk
            forvalues m = 1/`_cst_tn_`_k'' {
                local col = (`m' - 1) * 3 + 1
                replace c`col' = `"`macval(_cst_tv_`_k'_`m')'"' in `=`curr_n'+1'
            }
            local stats_rows = "`stats_rows' `=`curr_n'+1'"
            local stats_row_ids "`stats_row_ids' text(`_cst_tk')"
            continue
        }
        if `_cst_mc_`_k'' > 0 | `_cst_mc2_`_k'' > 0 local _cst_anymc = 1
        forvalues m = 1/`_cst_mods' {
            local _cst_cell ""
            foreach _s in "" 2 {
                if "`_s'" == "2" & "`_cst_nm2_`_k''" == "" continue
                local _x = `_cstv`_s'_`_k'_`m''
                local _cst_txt ""
                if !missing(`_x') {
                    local _cst_fmt "`_cst_fmt_`_k''"
                    if "`_cst_fmt'" == "" local _cst_fmt = cond(`_cst_int`_s'_`_k'', "%20.0fc", "%20.3f")
                    local _cst_txt = strtrim(ustrregexra(string(`_x', "`_cst_fmt'"), "-(?=[0.,]+\z)", ""))
                    local _cst_gs = `_cst_g`_s'_`_k''
                    if `_cst_pm`_s'_`_k'_`m'' {
                        local _cst_txt "<`_cst_mc`_s'_`_k''"
                        local ++_n_stmask
                    }
                    else if `_cst_gs' > 0 {
                        if "`_cst_trig_`_cst_gs'_`m''" == "1" {
                            local _cst_txt "`_cst_dash'"
                            local ++_n_stlink
                        }
                    }
                }
                if "`_s'" == "" local _cst_cell `"`_cst_txt'"'
                * a missing first value leaves the cell blank, never "(b)"
                else if `"`_cst_txt'"' != "" & `"`_cst_cell'"' != "" {
                    local _cst_cell = strtrim(`"`_cst_cell' (`_cst_txt')"')
                }
            }
            if `"`_cst_cell'"' != "" {
                local col = (`m' - 1) * 3 + 1
                replace c`col' = `"`_cst_cell'"' in `=`curr_n'+1'
            }
        }
        local stats_rows = "`stats_rows' `=`curr_n'+1'"
        local stats_row_ids "`stats_row_ids' e(`_cst_nm_`_k''`=cond("`_cst_nm2_`_k''" != "", "|`_cst_nm2_`_k''", "")')"
    }

    local stats_rows = strtrim("`stats_rows'")
}
}
	mata: _regtab_nsN = st_dir("local", "macro", "*"); _regtab_nsN = select(_regtab_nsN, !strmatch(_regtab_nsN, "_rtns_*")); _regtab_nsV = J(rows(_regtab_nsN), 1, ""); for (_regtab_nsI = 1; _regtab_nsI <= rows(_regtab_nsN); _regtab_nsI++) _regtab_nsV[_regtab_nsI] = st_local(_regtab_nsN[_regtab_nsI])
	}
	local _rtns_rc = _rc
	set varabbrev `_rtns_vab'
	if `_rtns_rc' exit `_rtns_rc'
end

* Folded from _regtab_statspec.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_statspec Version 1.2.0  2026/11/19
* parse stats() e(name) items and statlabels()
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* =============================================================================
* _regtab_statspec: parse stats() e(name) items and statlabels()
* =============================================================================
* Usage: _regtab_statspec `"<stats>"' `"<statlabels>"' `"<exposurelabel>"'
* stats(): generic items e(name) or e(name)="label" (also =`"label"'), with
* options e(name, %fmt mincell(#) maskwith(names)) and a pair e(name1|name2),
* and text rows text("label" value ...), are taken out of stats(), before any
* code reads stats() as plain words; each becomes its own row, in the order
* given, after the built-in rows.
* maskwith(names): the item's own names and the names listed (other e()
* names in stats()) are masked together: in a model where one of them prints
* <# under its mincell(), the others print the withheld text. Links close
* transitively into groups; a pair's two parts are linked only through
* maskwith().
* statlabels(): key "label" pairs relabelling built-in stats() rows.
* Returns in the caller: stats (the built-in words), _cst_n and per item #:
* _cst_kind_# (e or text), _cst_nm_#, _cst_nm2_# (the pair's second name),
* _cst_lb_#, _cst_fmt_#, _cst_mc_# and _cst_mc2_# (the mincell() of the
* first and second name, 0: none; a name in several items takes the
* strictest mincell() any of them gives it), _cst_g_# and _cst_g2_#
* (mask group of the first and second name, 0: none), _cst_tn_# and
* _cst_tv_#_j (text values); _cst_anylink (1 when any maskwith() was given);
* _stl_<key> for every built-in key, and exposurelabel.
capture program drop _regtab_statspec
program define _regtab_statspec, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	gettoken stats 0 : 0
	gettoken statlabels 0 : 0
	gettoken exposurelabel 0 : 0
	capture noisily {
		* stats() and statlabels() are asis: a list quoted whole is unquoted
		foreach _o in stats statlabels {
			gettoken _t _r : `_o', quotes
			if `"`_r'"' == "" gettoken `_o' : `_o'
		}
		* Generic items, in the order given: e(name[, opts])[="label"] and
		* text("label" value1 value2 ...). opts: a display format, as a bare
		* %fmt or fmt(%fmt), and mincell(#). e(a|b) is one row "a (b)".
		local _cst_n = 0
		local _cst_re "(e\((?:[^()]|\([^()]*\))*\)(?:\s*=\s*(?:\x60\x22.*?\x22'|\x22[^\x22]*\x22))?|text\((?:\x22[^\x22]*\x22|\x60\x22.*?\x22'|[^()\x22\x60])*\))"
		local _cst_ere "^e\(((?:[^()]|\([^()]*\))*)\)(?:\s*=\s*(?:\x60\x22(.*?)\x22'|\x22([^\x22]*)\x22))?$"
		local _cst_keys ""
		* every e() name, for maskwith()
		local _cst_allnm ""
		local _cst_anylink = 0
		while ustrregexm(`"`macval(stats)'"', "`_cst_re'") {
			local _cst_all = ustrregexs(0)
			local stats = subinstr(`"`macval(stats)'"', `"`macval(_cst_all)'"', " ", 1)
			local ++_cst_n
			local _k = `_cst_n'
			foreach _x in kind nm nm2 lb fmt mw {
				local _cst_`_x'_`_k' ""
			}
			local _cst_mc_`_k' = 0
			local _cst_tn_`_k' = 0
			if substr(`"`macval(_cst_all)'"', 1, 5) == "text(" {
				local _cst_kind_`_k' "text"
				local _in = substr(`"`macval(_cst_all)'"', 6, strlen(`"`macval(_cst_all)'"') - 6)
				* gettoken takes one layer of quotes ("" or compound) off
				gettoken _lb _in : _in
				local _cst_lb_`_k' : copy local _lb
				if `"`macval(_cst_lb_`_k')'"' == "" {
					display as error "stats(): text() needs a row label, as in text(" _char(34) "Weighting" _char(34) " " _char(34) "None" _char(34) " " _char(34) "IPW" _char(34) ")"
					exit 198
				}
				local _in = strtrim(`"`macval(_in)'"')
				while `"`macval(_in)'"' != "" {
					gettoken _v _in : _in
					local ++_cst_tn_`_k'
					local _cst_tv_`_k'_`_cst_tn_`_k'' : copy local _v
					local _in = strtrim(`"`macval(_in)'"')
				}
				continue
			}
			local _cst_kind_`_k' "e"
			if !ustrregexm(`"`macval(_cst_all)'"', "`_cst_ere'") {
				display as error `"stats(): could not read `macval(_cst_all)'"'
				exit 198
			}
			local _in = ustrregexs(1)
			local _cst_lb_`_k' = ustrregexs(2) + ustrregexs(3)
			local _cm = strpos(`"`_in'"', ",")
			local _nms `"`_in'"'
			local _opts ""
			if `_cm' > 0 {
				local _nms = substr(`"`_in'"', 1, `_cm' - 1)
				local _opts = strtrim(substr(`"`_in'"', `_cm' + 1, .))
			}
			local _nms = strtrim(`"`_nms'"')
			if !ustrregexm(`"`_nms'"', "^([A-Za-z_][A-Za-z0-9_]*)(?:\s*\|\s*([A-Za-z_][A-Za-z0-9_]*))?$") {
				display as error `"stats(): `macval(_cst_all)': give e(name) or e(name1|name2)"'
				exit 198
			}
			local _cst_nm_`_k' = ustrregexs(1)
			local _cst_nm2_`_k' = ustrregexs(2)
			if `"`_cst_lb_`_k''"' == "" {
				local _cst_lb_`_k' "`_cst_nm_`_k''"
				if "`_cst_nm2_`_k''" != "" local _cst_lb_`_k' "`_cst_nm_`_k'' (`_cst_nm2_`_k'')"
			}
			local _key "`_cst_nm_`_k''|`_cst_nm2_`_k''"
			local _dup : list _key in _cst_keys
			if `_dup' {
				display as error "stats(): e(`_cst_nm_`_k''`=cond("`_cst_nm2_`_k''" != "", "|`_cst_nm2_`_k''", "")') is requested more than once"
				exit 198
			}
			local _cst_keys "`_cst_keys' `_key'"
			local _cst_allnm : list _cst_allnm | _cst_nm_`_k'
			if "`_cst_nm2_`_k''" != "" local _cst_allnm : list _cst_allnm | _cst_nm2_`_k'
			* options: a bare %fmt first, then fmt(%fmt), mincell(#) and
			* maskwith(names)
			if substr(`"`_opts'"', 1, 1) == "%" {
				gettoken _cst_fmt_`_k' _opts : _opts, parse(" ")
				local _opts = strtrim(`"`_opts'"')
			}
			if `"`_opts'"' != "" {
				local 0 `", `_opts'"'
				local maskwith ""
				capture syntax , [Fmt(string) MINCell(integer 0) MASKwith(string)]
				if _rc {
					display as error `"stats(): e(`_nms', `_opts'): the options are a display format (%9.0fc or fmt(%9.0fc)), mincell(#) and maskwith(names)"'
					exit 198
				}
				local maskwith = strtrim(`"`maskwith'"')
				if `"`maskwith'"' != "" {
					foreach _mw of local maskwith {
						if !ustrregexm(`"`_mw'"', "^[A-Za-z_][A-Za-z0-9_]*$") {
							display as error `"stats(): e(`_nms'): maskwith(): "`_mw'" is not a name"'
							exit 198
						}
					}
					local _cst_mw_`_k' : list uniq maskwith
					local _cst_anylink = 1
				}
				if `"`fmt'"' != "" {
					if "`_cst_fmt_`_k''" != "" {
						display as error `"stats(): e(`_nms'): give one display format"'
						exit 198
					}
					local _cst_fmt_`_k' `"`fmt'"'
				}
				local _cst_mc_`_k' = `mincell'
				if `mincell' != 0 & `mincell' < 2 {
					display as error "stats(): e(`_nms'): mincell() must be an integer of 2 or more"
					exit 198
				}
			}
			if "`_cst_fmt_`_k''" != "" {
				local _cst_fmt_`_k' = strtrim("`_cst_fmt_`_k''")
				capture confirm numeric format `_cst_fmt_`_k''
				if _rc | !ustrregexm("`_cst_fmt_`_k''", "^%-?0?[0-9]*[.,][0-9]+[fge]c?$") {
					display as error "stats(): e(`_nms'): `_cst_fmt_`_k'' is not a numeric display format such as %9.0fc or %6.3f"
					exit 198
				}
			}
		}
		* One statistic, one threshold: a name requested in several items (as
		* e(ev, mincell(5)) and e(ev|tot)) is masked in every row with the
		* strictest mincell() any of them gives it, so no row prints a count
		* another row masks. _cst_mc_# and _cst_mc2_# hold the threshold of
		* the item's first and second name.
		* (_mcn_<i> is indexed by the name's position in _cst_allnm: a name
		* of 32 characters would not fit in a macro name)
		local _nall : word count `_cst_allnm'
		forvalues _i = 1/`_nall' {
			local _mcn_`_i' = 0
		}
		forvalues _k = 1/`_cst_n' {
			if "`_cst_kind_`_k''" != "e" continue
			foreach _s in "" 2 {
				if "`_cst_nm`_s'_`_k''" == "" continue
				local _i : list posof "`_cst_nm`_s'_`_k''" in _cst_allnm
				local _mcn_`_i' = max(`_mcn_`_i'', `_cst_mc_`_k'')
			}
		}
		forvalues _k = 1/`_cst_n' {
			local _cst_mc2_`_k' = 0
			if "`_cst_kind_`_k''" != "e" continue
			if "`_cst_nm2_`_k''" != "" {
				local _i : list posof "`_cst_nm2_`_k''" in _cst_allnm
				local _cst_mc2_`_k' = `_mcn_`_i''
			}
			local _i : list posof "`_cst_nm_`_k''" in _cst_allnm
			local _cst_mc_`_k' = `_mcn_`_i''
		}
		* maskwith(): every name must be an e() item of stats(); the links
		* close into groups (connected components of the declared links).
		* Group ids are the position of the group's first name.
		forvalues _k = 1/`_cst_n' {
			local _cst_g_`_k' = 0
			local _cst_g2_`_k' = 0
		}
		if `_cst_anylink' {
			local _gn : word count `_cst_allnm'
			forvalues _i = 1/`_gn' {
				local _gid_`_i' = 0
			}
			forvalues _k = 1/`_cst_n' {
				if `"`_cst_mw_`_k''"' == "" continue
				foreach _mw of local _cst_mw_`_k' {
					local _ok : list _mw in _cst_allnm
					if !`_ok' {
						display as error "stats(): maskwith(`_mw'): `_mw' is not an e() item in stats()"
						exit 198
					}
				}
				* the set: the item's own names and the names listed
				local _set "`_cst_nm_`_k'' `_cst_nm2_`_k'' `_cst_mw_`_k''"
				local _set : list uniq _set
				* one group: the smallest position among the set and every
				* group a member already belongs to
				local _new = .
				local _old ""
				foreach _mw of local _set {
					local _i : list posof "`_mw'" in _cst_allnm
					local _new = min(`_new', `_i')
					if `_gid_`_i'' > 0 {
						local _new = min(`_new', `_gid_`_i'')
						local _old "`_old' `_gid_`_i''"
					}
				}
				foreach _mw of local _set {
					local _i : list posof "`_mw'" in _cst_allnm
					local _gid_`_i' = `_new'
				}
				forvalues _i = 1/`_gn' {
					local _gi = `_gid_`_i''
					local _hit : list _gi in _old
					if `_gi' > 0 & `_hit' local _gid_`_i' = `_new'
				}
			}
			forvalues _k = 1/`_cst_n' {
				if "`_cst_kind_`_k''" != "e" continue
				local _i : list posof "`_cst_nm_`_k''" in _cst_allnm
				local _cst_g_`_k' = `_gid_`_i''
				if "`_cst_nm2_`_k''" != "" {
					local _i : list posof "`_cst_nm2_`_k''" in _cst_allnm
					local _cst_g2_`_k' = `_gid_`_i''
				}
			}
			* a group none of whose names has a mincell() masks nothing: say so
			local _gseen ""
			forvalues _i = 1/`_gn' {
				local _gi = `_gid_`_i''
				if `_gi' == 0 continue
				local _gdone : list _gi in _gseen
				if `_gdone' continue
				local _gseen "`_gseen' `_gi'"
				local _gnames ""
				local _gmc = 0
				forvalues _j = 1/`_gn' {
					if `_gid_`_j'' != `_gi' continue
					local _nmx : word `_j' of `_cst_allnm'
					local _gnames "`_gnames' `_nmx'"
					local _gmc = max(`_gmc', `_mcn_`_j'')
				}
				if `_gmc' == 0 {
					noisily display as text "(regtab: stats(): no mincell() is given for the maskwith() group`_gnames', so nothing in it is masked)"
				}
			}
		}
		if ustrregexm(`"`macval(stats)'"', "[\x22\x60=()]") {
			display as error `"stats(): could not read `macval(stats)'"'
			display as error `"  give built-in statistics as words and others as e(name) or e(name)="label""'
			exit 198
		}
		local stats = strtrim(`"`stats'"')

		local _stl_keys "n obs events people exposure groups mi_m aic qic bic ll icc r2 r2_a rmse f fmi"
		foreach _k of local _stl_keys {
			local _stl_`_k' ""
		}
		if `"`macval(statlabels)'"' != "" {
			local _stl_rest `"`macval(statlabels)'"'
			local _stl_sl = " " + strlower("`stats'") + " "
			foreach _al in n_sub subjects {
				local _stl_sl : subinstr local _stl_sl " `_al' " " n ", all
			}
			local _stl_sl : subinstr local _stl_sl " r-squared " " r2 ", all
			while `"`macval(_stl_rest)'"' != "" {
				gettoken _stl_k _stl_rest : _stl_rest
				local _stl_rest = strtrim(`"`macval(_stl_rest)'"')
				if `"`macval(_stl_rest)'"' == "" {
					display as error `"statlabels(): `_stl_k' has no label; give statlabels(stat "label" [stat "label" ...])"'
					exit 198
				}
				gettoken _stl_l _stl_rest : _stl_rest
				local _stl_k = strlower(`"`_stl_k'"')
				local _stl_ok : list _stl_k in _stl_keys
				if !`_stl_ok' {
					display as error `"statlabels(): `_stl_k' is not a built-in statistic (`_stl_keys')"'
					exit 198
				}
				if !strpos("`_stl_sl'", " `_stl_k' ") {
					display as error `"statlabels(): `_stl_k' is not requested in stats()"'
					exit 198
				}
				local _stl_`_stl_k' `"`macval(_stl_l)'"'
				local _stl_rest = strtrim(`"`macval(_stl_rest)'"')
			}
			if `"`macval(_stl_exposure)'"' != "" & `"`macval(exposurelabel)'"' != "" {
				display as error "exposurelabel() and statlabels(exposure ...) cannot both be specified"
				exit 198
			}
			if `"`macval(_stl_exposure)'"' != "" {
				local exposurelabel `"`macval(_stl_exposure)'"'
			}
		}
		c_local stats `"`stats'"'
		c_local exposurelabel `"`macval(exposurelabel)'"'
		c_local _cst_n `_cst_n'
		c_local _cst_anylink `_cst_anylink'
		forvalues _k = 1/`_cst_n' {
			foreach _x in kind nm nm2 fmt mc mc2 tn g g2 {
				c_local _cst_`_x'_`_k' "`_cst_`_x'_`_k''"
			}
			c_local _cst_lb_`_k' `"`macval(_cst_lb_`_k')'"'
			forvalues _j = 1/`_cst_tn_`_k'' {
				c_local _cst_tv_`_k'_`_j' `"`macval(_cst_tv_`_k'_`_j')'"'
			}
		}
		foreach _k of local _stl_keys {
			c_local _stl_`_k' `"`macval(_stl_`_k')'"'
		}
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* Folded from _regtab_unwrap.ado (formerly a separately autoloaded helper; see tabtools 1.2.1 changelog)
* _regtab_unwrap Version 1.2.0  2026/11/19
* one extra quote layer around a whole specification
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* =============================================================================
* _regtab_unwrap: one extra quote layer around a whole specification
* =============================================================================
* Usage: _regtab_unwrap `"<spec>"'
* Returns _uw_spec in the caller: <spec> itself, or, when <spec> is a single
* quoted token whose content starts with a quote (addrow(`"`spec'"') written
* by a program around "label" ...), that content.
capture program drop _regtab_unwrap
program define _regtab_unwrap, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	gettoken _spec 0 : 0
	capture noisily {
		gettoken _t _r2 : _spec, quotes
		if `"`macval(_r2)'"' == "" {
			gettoken _in : _spec
			local _in = strtrim(`"`macval(_in)'"')
			if substr(`"`macval(_in)'"', 1, 1) == char(34) | ///
				substr(`"`macval(_in)'"', 1, 2) == char(96) + char(34) local _spec : copy local _in
		}
	}
	local _rc = _rc
	c_local _uw_spec `"`macval(_spec)'"'
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end
