*! gcomptab Version 1.4.4  2026/07/10
*! Format gcomp mediation or time-varying dose-response results for Excel export
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
DESCRIPTION:
    Formats gcomp (parametric g-formula) results into polished Excel tables.
    Two modes:

    MEDIATION (default): formats causal-mediation output - total causal effect
    (TCE), natural direct effect (NDE), natural indirect effect (NIE), proportion
    mediated (PM), and controlled direct effect (CDE).

    DOSE-RESPONSE: formats time-varying confounding output (gcomp ...,
    interventions(...)) into a per-strategy table - one row per intervention with
    the counterfactual risk (PO), its 95% CI, an optional implied mean cumulative
    exposure-years column, and a risk-difference-vs-reference column. Selected with
    the doseresponse option, or auto-detected when e(b) has PO# columns and no tce
    column.

SYNTAX:
    gcomptab, xlsx(string) sheet(string) [ci(string) effect(string) title(string)
              labels(string) decimal(integer) font(string) fontsize(integer)
              borderstyle(string) zebra footnote(string) open boldp(real)
              highlight(real)
              doseresponse strategylabels(string) expyears(numlist)
              reference(integer) nord]

    xlsx:    Required. Excel file name (requires .xlsx suffix)
    sheet:   Required. Excel sheet name
    ci:      CI type: normal, percentile, bc, or bca (default: normal)
    effect:  Label for effect column (mediation default "Estimate";
             dose-response default "Risk")
    title:   Table title for cell A1
    labels:  Custom labels for mediation effects, separated by backslash
             (default: "TCE \ NDE \ NIE \ PM \ CDE")
    decimal: Decimal places for estimates (default: 3)

    Dose-response only:
    doseresponse:    Force the dose-response branch.
    strategylabels:  Backslash-separated strategy labels, one per PO# column;
                     unlabeled columns default to "PO#".
    expyears:        Implied mean cumulative exposure-years, one per PO# column
                     (adds a "Mean exposure-years" column when supplied).
    reference:       PO index used as the risk-difference reference (default 1).
    nord:            Suppress the risk-difference-vs-reference column.

PREREQUISITES:
    Run gcomp first. gcomptab reads from e() results posted by gcomp.

    Mediation mode:
    - e(b)[1,N]          - point estimates (cols: tce, nde, nie, pm, [cde])
    - e(se)[1,N]         - standard errors
    - e(ci_normal)[2,N]  - normal CIs (row 1=lower, row 2=upper)
    - e(ci_percentile), e(ci_bc), e(ci_bca) - alternative CI matrices
    - e(cmd) == "gcomp", e(analysis_type) == "mediation"

    Dose-response mode:
    - e(b)[1,N]          - contains PO1..POk counterfactual mean outcomes (the
                           last PO column is the simulated observed regime, so
                           k = #interventions + 1)
    - e(ci_normal)[2,N]  - matching CIs (or e(ci_percentile) with ci(percentile))
    - e(cmd) == "gcomp", e(analysis_type) == "time_varying"

EXAMPLES:
    * After running gcomp
    gcomp ... , ... bootstrap(500)
    gcomptab, xlsx("mediation_results.xlsx") sheet("Mediation") ///
        title("Causal Mediation Analysis")

    * With percentile CIs
    gcomptab, xlsx("mediation_results.xlsx") sheet("Mediation") ci(percentile)

    * Custom labels for specific analysis
    gcomptab, xlsx("mediation_results.xlsx") sheet("Table 2") ///
        labels("Total Effect \ Direct Effect \ Indirect Effect \ % Mediated") ///
        title("Table 2. Mediation Analysis Results")
*/

program define gcomptab, rclass
    version 16.0
    local _gc_varabbrev = c(varabbrev)
    set varabbrev off

capture noisily {
    return clear

    syntax [, xlsx(string) sheet(string) ci(string) effect(string) title(string) ///
            labels(string) decimal(integer 3) Font(string) FONTSize(integer 10) ///
            BORDERstyle(string) THEme(string) HEADERShade NOSHAde ///
            HEADERColor(string) ZEBRA ZEBRAColor(string) NOZEbra ///
            FOOTnote(string) OPEN BOLDp(real 0) ///
            HIGHlight(real 0) DOSEresponse STRATEGYlabels(string) ///
            EXPYears(numlist) REFerence(integer 1) noRD ///
            MODELS USEMODels(string) MODELLabels(string) TERMLabels(string) ///
            MARKDown(string) CSV(string) COEF(string) EFORM NOEFORM RAW ///
            SE COMPact NOPValue STARS STARSLevels(numlist) ///
            NOINTercept KEEPINTercept KEEP(string) DROP(string) ///
            DIGits(integer -1) STATs(string) DISPlay]

    if `digits' >= 0 local decimal = `digits'

    * Auto-load bundled Excel helpers on demand
    capture _gcomp_xl_helpers_ready
    if _rc {
        capture findfile _gcomp_xl_common.ado
        if _rc {
            noisily display as error "_gcomp_xl_common.ado not found; reinstall gcomp"
            exit 111
        }
        capture noisily run "`r(fn)'"
        if _rc {
            noisily display as error "_gcomp_xl_common.ado could not be loaded; reinstall gcomp"
            exit 111
        }
        capture _gcomp_xl_helpers_ready
        if _rc {
            noisily display as error "_gcomp_xl_common.ado failed to load fully; reinstall gcomp"
            exit 111
        }
    }
    _gcomp_xl_require_helpers

    if "`theme'" != "" {
        local theme = lower("`theme'")
        if !inlist("`theme'", "lancet", "nejm", "bmj", "apa", "jama", ///
            "plos", "nature", "cell", "annals") {
            noisily display as error "theme() must be lancet, nejm, bmj, apa, jama, plos, nature, cell, or annals"
            exit 198
        }
        if "`font'" == "" local font = cond("`theme'" == "apa", "Times New Roman", "Arial")
        if `fontsize' == 10 {
            if inlist("`theme'", "lancet", "nejm") local fontsize 9
            else if "`theme'" == "apa" local fontsize 12
            else if "`theme'" == "nature" local fontsize 7
            else if "`theme'" == "cell" local fontsize 8
        }
        if "`borderstyle'" == "" {
            if "`theme'" == "plos" local borderstyle "thin"
            else local borderstyle "academic"
        }
        if "`theme'" == "nejm" local zebra "zebra"
    }
    if "`noshade'" != "" local headershade ""
    if "`nozebra'" != "" local zebra ""
    if `"`headercolor'"' == "" local headercolor "219 229 241"
    if `"`zebracolor'"' == "" local zebracolor "237 242 249"

    * ----- Models mode (regtab-lite): explicit switch, never auto-detected -----
    if "`models'" != "" {
        if "`doseresponse'" != "" {
            noisily display as error "models and doseresponse are mutually exclusive"
            exit 198
        }
        if `"`ci'"' != "" | `"`effect'"' != "" | `"`labels'"' != "" {
            noisily display as error "ci(), effect(), and labels() are mediation-mode options; in models mode use se, modellabels(), and termlabels()"
            exit 198
        }
        _gcomptab_models, usemodels(`"`usemodels'"') modellabels(`"`modellabels'"') ///
            termlabels(`"`termlabels'"') xlsx(`"`xlsx'"') sheet(`"`sheet'"') ///
            markdown(`"`markdown'"') csv(`"`csv'"') coef(`"`coef'"') ///
            `eform' `noeform' `raw' `se' `compact' `nopvalue' `stars' ///
            starslevels(`starslevels') `nointercept' `keepintercept' ///
            keep(`"`keep'"') drop(`"`drop'"') decimal(`decimal') stats(`"`stats'"') ///
            title(`"`title'"') footnote(`"`footnote'"') font(`"`font'"') ///
            fontsize(`fontsize') borderstyle(`"`borderstyle'"') `zebra' ///
            zebracolor(`"`zebracolor'"') `headershade' headercolor(`"`headercolor'"') ///
            boldp(`boldp') highlight(`highlight') `open' `display'
        return add
    }
    else {
    if `"`xlsx'"' == "" | `"`sheet'"' == "" {
        noisily display as error "xlsx() and sheet() are required"
        exit 198
    }
    * Validate optional Markdown/CSV companion-export paths (both modes)
    _gcomptab_text_paths, markdown(`"`markdown'"') csv(`"`csv'"')

    * ----- Mode detection: dose-response (time-varying PO#) vs mediation -----
    local _drmode 0
    capture confirm matrix e(b)
    if _rc == 0 {
        tempname _eb_peek
        matrix `_eb_peek' = e(b)
        local _has_po1 = (colnumb(`_eb_peek', "PO1") != .)
        local _has_tce = (colnumb(`_eb_peek', "tce") != .)
        if "`doseresponse'" != "" local _drmode 1
        else if `_has_po1' & !`_has_tce' local _drmode 1
    }
    else if "`doseresponse'" != "" {
        local _drmode 1
    }

    if `_drmode' {
        _gcomptab_doseresponse, xlsx(`"`xlsx'"') sheet(`"`sheet'"') ci(`"`ci'"') ///
            effect(`"`effect'"') title(`"`title'"') decimal(`decimal') ///
            font(`"`font'"') fontsize(`fontsize') borderstyle(`"`borderstyle'"') ///
            reference(`reference') `rd' strategylabels(`"`strategylabels'"') ///
            expyears(`expyears') `headershade' headercolor(`"`headercolor'"') ///
            `zebra' zebracolor(`"`zebracolor'"') footnote(`"`footnote'"') `open' ///
            markdown(`"`markdown'"') csv(`"`csv'"')
        return add
    }
    else {
quietly {
    _gcomptab_validate, xlsx(`"`xlsx'"') sheet(`"`sheet'"') ci(`"`ci'"') ///
        effect(`"`effect'"') decimal(`decimal') font(`"`font'"') ///
        fontsize(`fontsize') borderstyle(`"`borderstyle'"') ///
        boldp(`boldp') highlight(`highlight')
    local ci "`r(ci)'"
    local effect "`r(effect)'"
    local font "`r(font)'"
    local borderstyle "`r(borderstyle)'"
    local _hborder "`r(hborder)'"
    local n_cols = r(n_cols)

    _gcomptab_extract, ci(`"`ci'"') ncols(`n_cols')
    local has_cde = r(has_cde)
    local N_effects = r(N_effects)
    local tce = r(tce)
    local nde = r(nde)
    local nie = r(nie)
    local pm = r(pm)
    local cde = r(cde)
    local se_tce = r(se_tce)
    local se_nde = r(se_nde)
    local se_nie = r(se_nie)
    local se_pm = r(se_pm)
    local se_cde = r(se_cde)
    local ci_tce_lo = r(ci_tce_lo)
    local ci_tce_hi = r(ci_tce_hi)
    local ci_nde_lo = r(ci_nde_lo)
    local ci_nde_hi = r(ci_nde_hi)
    local ci_nie_lo = r(ci_nie_lo)
    local ci_nie_hi = r(ci_nie_hi)
    local ci_pm_lo = r(ci_pm_lo)
    local ci_pm_hi = r(ci_pm_hi)
    local ci_cde_lo = r(ci_cde_lo)
    local ci_cde_hi = r(ci_cde_hi)
    local p_tce = r(p_tce)
    local p_nde = r(p_nde)
    local p_nie = r(p_nie)
    local p_pm = r(p_pm)
    local p_cde = r(p_cde)

    local _gt_preserved 0
    preserve
    local _gt_preserved 1
    capture noisily {
        _gcomptab_build_dataset, title(`"`title'"') effect(`"`effect'"') labels(`"`labels'"') ///
            decimal(`decimal') hascde(`has_cde') tce(`tce') nde(`nde') nie(`nie') ///
            pm(`pm') cde(`cde') setce(`se_tce') sende(`se_nde') senie(`se_nie') ///
            sepm(`se_pm') secde(`se_cde') citcelo(`ci_tce_lo') citcehi(`ci_tce_hi') ///
            cindelo(`ci_nde_lo') cindehi(`ci_nde_hi') cinielo(`ci_nie_lo') ///
            ciniehi(`ci_nie_hi') cipmlo(`ci_pm_lo') cipmhi(`ci_pm_hi') ///
            cicdelo(`ci_cde_lo') cicdehi(`ci_cde_hi')
        local num_rows = r(num_rows)
        local num_cols = r(num_cols)
        local label_width = r(label_width)
        local ci_width = r(ci_width)

        * Companion Markdown/CSV exports (same cells as the Excel table)
        if `"`markdown'"' != "" | `"`csv'"' != "" {
            _gcomptab_text_export, colvars(effect_label estimate ci_95 se) ///
                title(`"`title'"') markdown(`"`markdown'"') csv(`"`csv'"')
            if `"`markdown'"' != "" noisily display as text "Markdown table written to `markdown'"
            if `"`csv'"' != "" noisily display as text "CSV table written to `csv'"
        }

        _gcomptab_write_excel, xlsx(`"`xlsx'"') sheet(`"`sheet'"')

        _gcomptab_style_excel, xlsx(`"`xlsx'"') sheet(`"`sheet'"') rows(`num_rows') ///
            cols(`num_cols') labelwidth(`label_width') ciwidth(`ci_width') ///
            font(`"`font'"') fontsize(`fontsize') borderstyle(`"`borderstyle'"') ///
            hborder(`"`_hborder'"') `headershade' headercolor(`"`headercolor'"') ///
            `zebra' zebracolor(`"`zebracolor'"') footnote(`"`footnote'"') ///
            boldp(`boldp') highlight(`highlight') pvaltce(`"`p_tce'"') ///
            pvalnde(`"`p_nde'"') pvalnie(`"`p_nie'"') pvalpm(`"`p_pm'"') ///
            pvalcde(`"`p_cde'"')
    }
    local _gt_rc = _rc
    if `_gt_preserved' {
        restore
    }
    if `_gt_rc' exit `_gt_rc'

    _gcomptab_post_returns, xlsx(`"`xlsx'"') sheet(`"`sheet'"') ci(`"`ci'"') ///
        hascde(`has_cde') neffects(`N_effects') tce(`tce') nde(`nde') ///
        nie(`nie') pm(`pm') cde(`cde') markdown(`"`markdown'"') csv(`"`csv'"')
    return add

    * The workbook is already complete and the analytical result contract is
    * established.  An optional OS open failure must not strand r().
    if "`open'" != "" {
        _gcomp_xl_open "`xlsx'"
    }
}
    }
    } /* end: else (non-models modes) */
} /* end capture noisily */
local _gc_rc = _rc
set varabbrev `_gc_varabbrev'
if `_gc_rc' exit `_gc_rc'
end

capture program drop _gcomptab_validate
program define _gcomptab_validate, rclass
    version 16.0
    syntax, XLSX(string) SHEET(string) DECimal(integer) FONTSize(integer) ///
        BOLDp(real) HIGHlight(real) [CI(string) EFFECT(string) ///
        Font(string) BORDERstyle(string)]

    if "`ci'" == "" local ci "normal"
    if "`effect'" == "" local effect "Estimate"
    if "`font'" == "" local font "Arial"
    if "`borderstyle'" == "" local borderstyle "thin"
    local hborder = cond("`borderstyle'" == "academic", "medium", "`borderstyle'")

    if "`e(cmd)'" != "gcomp" {
        noisily display as error "No gcomp mediation results found"
        noisily display as error "Run {bf:gcomp} with {bf:mediation} option first"
        exit 119
    }
    if "`e(analysis_type)'" != "mediation" {
        noisily display as error "gcomp results are not from a mediation analysis"
        noisily display as error "Run {bf:gcomp} with {bf:mediation} option"
        exit 119
    }
    if "`e(mediation_type)'" == "oce" {
        noisily display as error "gcomptab does not support oce mediation results"
        noisily display as error "Use obe, linexp, or specific mediation type instead"
        exit 198
    }

    capture confirm matrix e(b)
    if _rc != 0 {
        noisily display as error "No gcomp mediation results found"
        noisily display as error "Run {bf:gcomp} with {bf:mediation} option first"
        exit 119
    }
    tempname eb ese
    matrix `eb' = e(b)
    local n_cols = colsof(`eb')
    if `n_cols' < 4 | `n_cols' > 5 {
        noisily display as error "Unexpected matrix dimensions from gcomp"
        noisily display as error "Expected 4-5 columns, found `n_cols'"
        exit 198
    }
    foreach _col in tce nde nie pm {
        if colnumb(`eb', "`_col'") == . {
            noisily display as error "e(b) matrix missing expected column '`_col''"
            noisily display as error "gcomp results may be from an incompatible version"
            exit 198
        }
    }
    if `n_cols' == 5 & colnumb(`eb', "cde") == . {
        noisily display as error "e(b) matrix missing expected column 'cde'"
        noisily display as error "gcomp results may be from an incompatible version"
        exit 198
    }

    capture confirm matrix e(se)
    if _rc != 0 {
        noisily display as error "No standard error matrix found in gcomp results"
        exit 119
    }
    matrix `ese' = e(se)
    if rowsof(`ese') != 1 | colsof(`ese') != `n_cols' {
        noisily display as error "e(se) matrix has unexpected dimensions"
        noisily display as error "Expected 1 x `n_cols', found " rowsof(`ese') " x " colsof(`ese')
        exit 198
    }
    foreach _col in tce nde nie pm {
        if colnumb(`ese', "`_col'") == . {
            noisily display as error "e(se) matrix missing expected column '`_col''"
            noisily display as error "gcomp results may be from an incompatible version"
            exit 198
        }
    }
    if `n_cols' == 5 & colnumb(`ese', "cde") == . {
        noisily display as error "e(se) matrix missing expected column 'cde'"
        noisily display as error "gcomp results may be from an incompatible version"
        exit 198
    }

    if !strmatch("`xlsx'", "*.xlsx") {
        noisily display as error "Excel filename must have .xlsx extension"
        exit 198
    }
    _gcomp_validate_path "`xlsx'" "xlsx()"
    _gcomp_validate_path "`sheet'" "sheet()"
    _gcomp_xl_validate_sheet "`sheet'" "sheet()"

    if !inlist("`ci'", "normal", "percentile", "bc", "bca") {
        noisily display as error "ci() must be normal, percentile, bc, or bca"
        exit 198
    }
    if `decimal' < 1 | `decimal' > 6 {
        noisily display as error "decimal() must be between 1 and 6"
        exit 198
    }
    _gcomp_validate_path "`font'" "font()"
    if `fontsize' < 1 | `fontsize' > 72 {
        noisily display as error "fontsize() must be between 1 and 72"
        exit 198
    }
    if !inlist("`borderstyle'", "academic", "thin", "medium") {
        noisily display as error "borderstyle() must be academic, thin, or medium"
        exit 198
    }
    if `boldp' != 0 & (`boldp' <= 0 | `boldp' >= 1) {
        noisily display as error "boldp() must be between 0 and 1"
        exit 198
    }
    if `highlight' != 0 & (`highlight' <= 0 | `highlight' >= 1) {
        noisily display as error "highlight() must be between 0 and 1"
        exit 198
    }

    return scalar n_cols = `n_cols'
    return local ci "`ci'"
    return local effect "`effect'"
    return local font "`font'"
    return local borderstyle "`borderstyle'"
    return local hborder "`hborder'"
end

capture program drop _gcomptab_extract
program define _gcomptab_extract, rclass
    version 16.0
    syntax, CI(string) NCOLS(integer)

    tempname eb ese ci_mat
    matrix `eb' = e(b)
    matrix `ese' = e(se)

    capture confirm matrix e(ci_`ci')
    if _rc != 0 {
        noisily display as error "CI matrix ci_`ci' not found"
        noisily display as error "Available CI types depend on gcomp bootstrap options"
        exit 111
    }
    matrix `ci_mat' = e(ci_`ci')
    if rowsof(`ci_mat') != 2 | colsof(`ci_mat') != `ncols' {
        noisily display as error "CI matrix ci_`ci' has unexpected dimensions"
        noisily display as error "Expected 2 x `ncols', found " rowsof(`ci_mat') " x " colsof(`ci_mat')
        exit 198
    }
    foreach _col in tce nde nie pm {
        if colnumb(`ci_mat', "`_col'") == . {
            noisily display as error "CI matrix ci_`ci' missing expected column '`_col''"
            noisily display as error "gcomp results may be from an incompatible version"
            exit 198
        }
    }
    if `ncols' == 5 & colnumb(`ci_mat', "cde") == . {
        noisily display as error "CI matrix ci_`ci' missing expected column 'cde'"
        noisily display as error "gcomp results may be from an incompatible version"
        exit 198
    }

    local tce = `eb'[1, colnumb(`eb', "tce")]
    local nde = `eb'[1, colnumb(`eb', "nde")]
    local nie = `eb'[1, colnumb(`eb', "nie")]
    local pm = `eb'[1, colnumb(`eb', "pm")]
    if `ncols' >= 5 local cde = `eb'[1, colnumb(`eb', "cde")]
    else local cde = .

    local se_tce = `ese'[1, colnumb(`ese', "tce")]
    local se_nde = `ese'[1, colnumb(`ese', "nde")]
    local se_nie = `ese'[1, colnumb(`ese', "nie")]
    local se_pm = `ese'[1, colnumb(`ese', "pm")]
    if `ncols' >= 5 local se_cde = `ese'[1, colnumb(`ese', "cde")]
    else local se_cde = .

    local ci_tce_lo = `ci_mat'[1, colnumb(`ci_mat', "tce")]
    local ci_tce_hi = `ci_mat'[2, colnumb(`ci_mat', "tce")]
    local ci_nde_lo = `ci_mat'[1, colnumb(`ci_mat', "nde")]
    local ci_nde_hi = `ci_mat'[2, colnumb(`ci_mat', "nde")]
    local ci_nie_lo = `ci_mat'[1, colnumb(`ci_mat', "nie")]
    local ci_nie_hi = `ci_mat'[2, colnumb(`ci_mat', "nie")]
    local ci_pm_lo = `ci_mat'[1, colnumb(`ci_mat', "pm")]
    local ci_pm_hi = `ci_mat'[2, colnumb(`ci_mat', "pm")]
    if `ncols' >= 5 {
        local ci_cde_lo = `ci_mat'[1, colnumb(`ci_mat', "cde")]
        local ci_cde_hi = `ci_mat'[2, colnumb(`ci_mat', "cde")]
    }
    else {
        local ci_cde_lo = .
        local ci_cde_hi = .
    }

    local has_cde = (`cde' != .)
    local p_tce = 2 * normal(-abs(`tce' / `se_tce'))
    local p_nde = 2 * normal(-abs(`nde' / `se_nde'))
    local p_nie = 2 * normal(-abs(`nie' / `se_nie'))
    local p_pm = 2 * normal(-abs(`pm' / `se_pm'))
    if `has_cde' local p_cde = 2 * normal(-abs(`cde' / `se_cde'))
    else local p_cde = .

    return scalar N_effects = cond(`has_cde', 5, 4)
    return scalar has_cde = `has_cde'
    return scalar tce = `tce'
    return scalar nde = `nde'
    return scalar nie = `nie'
    return scalar pm = `pm'
    return scalar cde = `cde'
    return scalar se_tce = `se_tce'
    return scalar se_nde = `se_nde'
    return scalar se_nie = `se_nie'
    return scalar se_pm = `se_pm'
    return scalar se_cde = `se_cde'
    return scalar ci_tce_lo = `ci_tce_lo'
    return scalar ci_tce_hi = `ci_tce_hi'
    return scalar ci_nde_lo = `ci_nde_lo'
    return scalar ci_nde_hi = `ci_nde_hi'
    return scalar ci_nie_lo = `ci_nie_lo'
    return scalar ci_nie_hi = `ci_nie_hi'
    return scalar ci_pm_lo = `ci_pm_lo'
    return scalar ci_pm_hi = `ci_pm_hi'
    return scalar ci_cde_lo = `ci_cde_lo'
    return scalar ci_cde_hi = `ci_cde_hi'
    return scalar p_tce = `p_tce'
    return scalar p_nde = `p_nde'
    return scalar p_nie = `p_nie'
    return scalar p_pm = `p_pm'
    return scalar p_cde = `p_cde'
end

capture program drop _gcomptab_build_dataset
program define _gcomptab_build_dataset, rclass
    version 16.0
    syntax, DECimal(integer) HASCDE(integer) TCE(real) NDE(real) NIE(real) PM(real) CDE(real) ///
        SETCE(real) SENDE(real) SENIE(real) SEPM(real) SECDE(real) CITCELO(real) CITCEHI(real) ///
        CINDELO(real) CINDEHI(real) CINIELO(real) CINIEHI(real) CIPMLO(real) CIPMHI(real) ///
        CICDELO(real) CICDEHI(real) [TITLE(string) EFFECT(string) LABELS(string)]

    if "`effect'" == "" local effect "Estimate"
    if "`labels'" == "" {
        local labels "Total Causal Effect (TCE) \ Natural Direct Effect (NDE) \ Natural Indirect Effect (NIE) \ Proportion Mediated (PM) \ Controlled Direct Effect (CDE)"
    }

    local labels : subinstr local labels " \ " "\", all
    local labels : subinstr local labels "\  " "\", all
    local labels : subinstr local labels "  \" "\", all
    tokenize `"`labels'"', parse("\")

    local lab1 "`1'"
    local lab2 "`3'"
    local lab3 "`5'"
    local lab4 "`7'"
    local lab5 "`9'"

    if "`lab1'" == "" local lab1 "Total Causal Effect (TCE)"
    if "`lab2'" == "" local lab2 "Natural Direct Effect (NDE)"
    if "`lab3'" == "" local lab3 "Natural Indirect Effect (NIE)"
    if "`lab4'" == "" local lab4 "Proportion Mediated (PM)"
    if "`lab5'" == "" local lab5 "Controlled Direct Effect (CDE)"

    clear
    if `hascde' set obs 7
    else set obs 6

    gen str100 title_col = ""
    gen str60 effect_label = ""
    gen str20 estimate = ""
    gen str30 ci_95 = ""
    gen str20 se = ""

    replace title_col = `"`title'"' in 1

    replace effect_label = "Effect" in 2
    replace estimate = "`effect'" in 2
    replace ci_95 = "95% CI" in 2
    replace se = "SE" in 2

    local fmt "%9.`decimal'f"

    replace effect_label = "`lab1'" in 3
    replace estimate = string(`tce', "`fmt'") in 3
    replace ci_95 = "(" + string(`citcelo', "`fmt'") + ", " + string(`citcehi', "`fmt'") + ")" in 3
    replace se = string(`setce', "`fmt'") in 3

    replace effect_label = "`lab2'" in 4
    replace estimate = string(`nde', "`fmt'") in 4
    replace ci_95 = "(" + string(`cindelo', "`fmt'") + ", " + string(`cindehi', "`fmt'") + ")" in 4
    replace se = string(`sende', "`fmt'") in 4

    replace effect_label = "`lab3'" in 5
    replace estimate = string(`nie', "`fmt'") in 5
    replace ci_95 = "(" + string(`cinielo', "`fmt'") + ", " + string(`ciniehi', "`fmt'") + ")" in 5
    replace se = string(`senie', "`fmt'") in 5

    replace effect_label = "`lab4'" in 6
    replace estimate = string(`pm', "`fmt'") in 6
    replace ci_95 = "(" + string(`cipmlo', "`fmt'") + ", " + string(`cipmhi', "`fmt'") + ")" in 6
    replace se = string(`sepm', "`fmt'") in 6

    if `hascde' {
        replace effect_label = "`lab5'" in 7
        replace estimate = string(`cde', "`fmt'") in 7
        replace ci_95 = "(" + string(`cicdelo', "`fmt'") + ", " + string(`cicdehi', "`fmt'") + ")" in 7
        replace se = string(`secde', "`fmt'") in 7
    }

    local num_rows = _N
    local num_cols = 5

    gen len_label = length(effect_label)
    gen len_ci = length(ci_95)

    quietly summarize len_label
    local label_width = max(`r(max)', 15)
    quietly summarize len_ci
    local ci_width = max(`r(max)', 15)

    drop len_*

    return scalar num_rows = `num_rows'
    return scalar num_cols = `num_cols'
    return scalar label_width = `label_width'
    return scalar ci_width = `ci_width'
end

capture program drop _gcomptab_write_excel
program define _gcomptab_write_excel
    version 16.0
    syntax, XLSX(string) SHEET(string)

    capture export excel using "`xlsx'", sheet("`sheet'") sheetreplace
    if _rc {
        local saved_rc = _rc
        noisily display as error "Failed to export to `xlsx', sheet `sheet'"
        noisily display as error "Check file permissions and that file is not open in Excel"
        exit `saved_rc'
    }
    capture confirm file "`xlsx'"
    if _rc {
        noisily display as error `"Workbook not found after export: `xlsx'"'
        exit 601
    }
end

capture program drop _gcomptab_style_excel
program define _gcomptab_style_excel
    version 16.0
    syntax, XLSX(string) SHEET(string) ROWS(integer) COLS(integer) ///
        LABELWIDTH(real) CIWIDTH(real) Font(string) FONTSize(integer) ///
        BORDERstyle(string) HBORDER(string) [HEADERShade HEADERColor(string) ///
        ZEBRA ZEBRAColor(string) FOOTnote(string) ///
        BOLDp(real 0) HIGHlight(real 0) PVALTCE(string) PVALNDE(string) ///
        PVALNIE(string) PVALPM(string) PVALCDE(string)]

    if "`pvaltce'" == "" local _pval_3 .
    else local _pval_3 = real("`pvaltce'")
    if "`pvalnde'" == "" local _pval_4 .
    else local _pval_4 = real("`pvalnde'")
    if "`pvalnie'" == "" local _pval_5 .
    else local _pval_5 = real("`pvalnie'")
    if "`pvalpm'" == "" local _pval_6 .
    else local _pval_6 = real("`pvalpm'")
    if "`pvalcde'" == "" local _pval_7 .
    else local _pval_7 = real("`pvalcde'")
    if `"`headercolor'"' == "" local headercolor "219 229 241"
    if `"`zebracolor'"' == "" local zebracolor "237 242 249"

    capture {
        mata: b = xl()
        mata: b.load_book("`xlsx'")
        mata: b.set_sheet("`sheet'")

        mata: b.set_row_height(1, 1, 30)
        mata: b.set_column_width(1, 1, 1)
        mata: b.set_column_width(2, 2, `=`labelwidth' * 0.9')
        mata: b.set_column_width(3, 3, 12)
        mata: b.set_column_width(4, 4, `=`ciwidth' * 0.85')
        mata: b.set_column_width(5, 5, 10)

        local _varlist "title_col effect_label estimate ci_95 se"
        forvalues _r = 3/`rows' {
            forvalues _c = 3/`cols' {
                local _vname : word `_c' of `_varlist'
                local _cellstr = `_vname'[`_r']
                if `"`_cellstr'"' == "" | `"`_cellstr'"' == "." continue
                if strpos(`"`_cellstr'"', "(") > 0 continue
                if strpos(`"`_cellstr'"', "%") > 0 continue
                if strpos(`"`_cellstr'"', "<") > 0 continue
                if `"`_cellstr'"' == "(omitted)" continue
                local _cellclean = subinstr(`"`_cellstr'"', ",", "", .)
                local _cellnum = real("`_cellclean'")
                if `_cellnum' != . {
                    mata: b.put_number(`_r', `_c', `_cellnum')
                }
            }
        }

        mata: b.set_font((1,`rows'), (1,`cols'), "`font'", `fontsize')
        mata: b.set_font((1,1), (1,`cols'), "`font'", `=`fontsize' + 2')

        mata: b.set_sheet_merge("`sheet'", (1,1), (1,`cols'))
        mata: b.set_text_wrap(1, 1, "on")
        mata: b.set_horizontal_align(1, 1, "left")
        mata: b.set_vertical_align(1, 1, "center")
        mata: b.set_font_bold(1, 1, "on")

        mata: b.set_font_bold(2, (2,`cols'), "on")
        mata: b.set_horizontal_align(2, (2,`cols'), "center")
        mata: b.set_top_border(2, (2,`cols'), "`hborder'")
        mata: b.set_bottom_border(2, (2,`cols'), "`hborder'")
        if "`headershade'" != "" {
            mata: b.set_fill_pattern(2, (2,`cols'), "solid", "`headercolor'")
        }

        mata: b.set_bottom_border(`rows', (2,`cols'), "`hborder'")

        if "`borderstyle'" != "academic" {
            mata: b.set_left_border((2,`rows'), 2, "`hborder'")
            mata: b.set_right_border((2,`rows'), `cols', "`hborder'")
        }

        if `rows' >= 3 & `cols' >= 3 {
            mata: b.set_horizontal_align((3,`rows'), (3,`cols'), "center")
        }

        if "`zebra'" != "" {
            forvalues _zr = 4(2)`rows' {
                mata: b.set_fill_pattern(`_zr', (2,`cols'), "solid", "`zebracolor'")
            }
        }

        if `boldp' > 0 {
            forvalues _br = 3/`rows' {
                if `_pval_`_br'' < . & `_pval_`_br'' < `boldp' {
                    mata: b.set_font_bold(`_br', (3,`cols'), "on")
                }
            }
        }

        if `highlight' > 0 {
            forvalues _hr = 3/`rows' {
                if `_pval_`_hr'' < . & `_pval_`_hr'' < `highlight' {
                    mata: b.set_fill_pattern(`_hr', (2,`cols'), "solid", "255 255 204")
                }
            }
        }

        if `"`footnote'"' != "" {
            local _fn_row = `rows' + 1
            local _fn_fontsize = max(`fontsize' - 2, 6)
            mata: b.put_string(`_fn_row', 2, `"`footnote'"')
            mata: b.set_sheet_merge("`sheet'", (`_fn_row',`_fn_row'), (2,`cols'))
            mata: b.set_horizontal_align(`_fn_row', 2, "left")
            mata: b.set_vertical_align(`_fn_row', 2, "center")
            mata: b.set_text_wrap(`_fn_row', 2, "on")
            mata: b.set_font(`_fn_row', 2, "`font'", `_fn_fontsize')
            mata: b.set_font_italic(`_fn_row', 2, "on")
        }

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
end

capture program drop _gcomptab_post_returns
program define _gcomptab_post_returns, rclass
    version 16.0
    syntax, XLSX(string) SHEET(string) CI(string) HASCDE(integer) ///
        NEFFECTS(integer) TCE(real) NDE(real) NIE(real) PM(real) CDE(real) ///
        [MARKDown(string) CSV(string)]

    return scalar N_effects = `neffects'
    return scalar tce = `tce'
    return scalar nde = `nde'
    return scalar nie = `nie'
    return scalar pm = `pm'
    if `hascde' {
        return scalar cde = `cde'
    }
    return local xlsx "`xlsx'"
    return local sheet "`sheet'"
    return local ci "`ci'"
    if `"`markdown'"' != "" return local markdown `"`markdown'"'
    if `"`csv'"' != "" return local csv `"`csv'"'
end

* =============================================================================
* Shared Markdown/CSV writer (mediation + dose-response modes)
* =============================================================================
* Operates on the in-memory export dataset already built for the Excel output,
* so the text tables carry identical cells. Geometry assumed (both modes):
*   row 2      = column headers
*   rows 3.._N = table body
* for the variables named in colvars(), left-to-right display order. The first
* (pad/title) dataset column is excluded by the caller; title() supplies the
* Markdown heading.
capture program drop _gcomptab_text_export
program define _gcomptab_text_export
    version 16.0
    syntax, COLVars(string) [MARKDown(string) CSV(string) TITLE(string)]

    local _nc : word count `colvars'
    if `_nc' == 0 exit 198

    if `"`markdown'"' != "" {
        tempname _fh
        file open `_fh' using `"`markdown'"', write replace text
        if `"`title'"' != "" file write `_fh' "### `title'" _n _n
        local _hdr "|"
        local _sep "|"
        forvalues j = 1/`_nc' {
            local _v : word `j' of `colvars'
            local _cell = `_v'[2]
            local _hdr `"`_hdr' `_cell' |"'
            local _sep "`_sep' --- |"
        }
        file write `_fh' `"`_hdr'"' _n `"`_sep'"' _n
        forvalues _r = 3/`=_N' {
            local _line "|"
            forvalues j = 1/`_nc' {
                local _v : word `j' of `colvars'
                local _cell = `_v'[`_r']
                local _line `"`_line' `_cell' |"'
            }
            file write `_fh' `"`_line'"' _n
        }
        file close `_fh'
    }

    if `"`csv'"' != "" {
        tempname _fc
        file open `_fc' using `"`csv'"', write replace text
        local _line ""
        forvalues j = 1/`_nc' {
            local _v : word `j' of `colvars'
            local _cell = `_v'[2]
            if `j' > 1 local _line `"`_line',"'
            local _line `"`_line'"`_cell'""'
        }
        file write `_fc' `"`_line'"' _n
        forvalues _r = 3/`=_N' {
            local _line ""
            forvalues j = 1/`_nc' {
                local _v : word `j' of `colvars'
                local _cell = `_v'[`_r']
                if `j' > 1 local _line `"`_line',"'
                local _line `"`_line'"`_cell'""'
            }
            file write `_fc' `"`_line'"' _n
        }
        file close `_fc'
    }
end

* =============================================================================
* Markdown/CSV path + extension validation (mediation + dose-response modes)
* =============================================================================
capture program drop _gcomptab_text_paths
program define _gcomptab_text_paths
    version 16.0
    syntax, [MARKDown(string) CSV(string)]
    if `"`markdown'"' != "" {
        _gcomp_validate_path `"`markdown'"' "markdown()"
        local _mdl = lower(`"`markdown'"')
        if !(strmatch(`"`_mdl'"', "*.md") | strmatch(`"`_mdl'"', "*.markdown") | ///
             strmatch(`"`_mdl'"', "*.qmd") | strmatch(`"`_mdl'"', "*.rmd")) {
            noisily display as error "markdown() must specify a .md, .markdown, .qmd, or .rmd file"
            exit 198
        }
    }
    if `"`csv'"' != "" {
        _gcomp_validate_path `"`csv'"' "csv()"
        if !strmatch(lower(`"`csv'"'), "*.csv") {
            noisily display as error "csv() must specify a .csv file"
            exit 198
        }
    }
end

* =============================================================================
* Time-varying dose-response branch
* =============================================================================

capture program drop _gcomptab_doseresponse
program define _gcomptab_doseresponse, rclass
    version 16.0
    syntax, XLSX(string) SHEET(string) REFerence(integer) DECimal(integer) ///
        FONTSize(integer) [CI(string) EFFECT(string) TITLE(string) Font(string) ///
        BORDERstyle(string) STRATEGYlabels(string) EXPYears(numlist) noRD ///
        HEADERShade HEADERColor(string) ZEBRA ZEBRAColor(string) ///
        FOOTnote(string) OPEN MARKDown(string) CSV(string)]

    _gcomptab_dr_validate, xlsx(`"`xlsx'"') sheet(`"`sheet'"') ci(`"`ci'"') ///
        effect(`"`effect'"') decimal(`decimal') font(`"`font'"') ///
        fontsize(`fontsize') borderstyle(`"`borderstyle'"')
    local ci "`r(ci)'"
    local effect "`r(effect)'"
    local font "`r(font)'"
    local borderstyle "`r(borderstyle)'"
    local _hborder "`r(hborder)'"
    local k = r(k)

    if `reference' < 1 | `reference' > `k' {
        noisily display as error "reference() must be between 1 and `k' (number of PO# columns)"
        exit 198
    }

    tempname _drtab
    local _pres 0
    preserve
    local _pres 1
    capture noisily {
        _gcomptab_dr_build, ci(`"`ci'"') k(`k') decimal(`decimal') ///
            reference(`reference') effect(`"`effect'"') title(`"`title'"') ///
            strategylabels(`"`strategylabels'"') expyears(`expyears') `rd'
        local num_rows = r(num_rows)
        local num_cols = r(num_cols)
        local strat_width = r(strat_width)
        local risk_width = r(risk_width)
        local has_exp = r(has_exp)
        local has_rd = r(has_rd)
        local ref_label `"`r(ref_label)'"'
        matrix `_drtab' = r(table)

        * Default footnote: g-formula MC settings + reference strategy
        if `"`footnote'"' == "" {
            local _fn "Counterfactual cumulative incidence under each sustained-treatment strategy from the parametric g-formula"
            if "`e(MC_sims)'" != "" {
                local _fn `"`_fn' (`e(MC_sims)' Monte Carlo simulations"'
                if "`e(samples)'" != "" local _fn `"`_fn', `e(samples)' bootstrap samples"'
                local _fn `"`_fn')"'
            }
            local _fn `"`_fn'. Risk difference shown versus reference strategy: `ref_label'."'
            local footnote `"`_fn'"'
        }

        * Companion Markdown/CSV exports (same cells as the Excel table)
        if `"`markdown'"' != "" | `"`csv'"' != "" {
            local _drcolvars "strat"
            if `has_exp' local _drcolvars "`_drcolvars' expcol"
            local _drcolvars "`_drcolvars' riskcol"
            if `has_rd' local _drcolvars "`_drcolvars' rdcol"
            _gcomptab_text_export, colvars(`_drcolvars') ///
                title(`"`title'"') markdown(`"`markdown'"') csv(`"`csv'"')
            if `"`markdown'"' != "" noisily display as text "Markdown table written to `markdown'"
            if `"`csv'"' != "" noisily display as text "CSV table written to `csv'"
        }

        _gcomptab_write_excel, xlsx(`"`xlsx'"') sheet(`"`sheet'"')
        _gcomptab_dr_style, xlsx(`"`xlsx'"') sheet(`"`sheet'"') rows(`num_rows') ///
            cols(`num_cols') stratwidth(`strat_width') riskwidth(`risk_width') ///
            hasexp(`has_exp') hasrd(`has_rd') font(`"`font'"') fontsize(`fontsize') ///
            borderstyle(`"`borderstyle'"') hborder(`"`_hborder'"') ///
            `headershade' headercolor(`"`headercolor'"') ///
            `zebra' zebracolor(`"`zebracolor'"') footnote(`"`footnote'"')
    }
    local _dr_rc = _rc
    if `_pres' capture restore
    if `_dr_rc' exit `_dr_rc'

    return scalar k = `k'
    return scalar reference = `reference'
    return local xlsx "`xlsx'"
    return local sheet "`sheet'"
    return local ci "`ci'"
    return local ref_label `"`ref_label'"'
    if `"`markdown'"' != "" return local markdown `"`markdown'"'
    if `"`csv'"' != "" return local csv `"`csv'"'
    return matrix table = `_drtab'

    * Preserve the completed analytical payload if the optional OS open fails.
    if "`open'" != "" {
        _gcomp_xl_open "`xlsx'"
    }
end

capture program drop _gcomptab_dr_validate
program define _gcomptab_dr_validate, rclass
    version 16.0
    syntax, XLSX(string) SHEET(string) DECimal(integer) FONTSize(integer) ///
        [CI(string) EFFECT(string) Font(string) BORDERstyle(string)]

    if "`ci'" == "" local ci "normal"
    if "`effect'" == "" local effect "Risk"
    if "`font'" == "" local font "Arial"
    if "`borderstyle'" == "" local borderstyle "thin"
    local hborder = cond("`borderstyle'" == "academic", "medium", "`borderstyle'")

    if "`e(cmd)'" != "gcomp" {
        noisily display as error "No gcomp results found"
        noisily display as error "Run {bf:gcomp} with {bf:interventions()} first"
        exit 119
    }
    capture confirm matrix e(b)
    if _rc != 0 {
        noisily display as error "No gcomp results found in e(b)"
        exit 119
    }

    tempname eb
    matrix `eb' = e(b)
    local k 0
    local _i 1
    while colnumb(`eb', "PO`_i'") != . {
        local k = `_i'
        local ++_i
    }
    if `k' == 0 {
        noisily display as error "e(b) has no PO# columns"
        noisily display as error "doseresponse requires a time-varying gcomp result (interventions())"
        noisily display as error "For mediation output, omit doseresponse"
        exit 198
    }

    if !inlist("`ci'", "normal", "percentile", "bc", "bca") {
        noisily display as error "ci() must be normal, percentile, bc, or bca"
        exit 198
    }
    capture confirm matrix e(ci_`ci')
    if _rc != 0 {
        noisily display as error "CI matrix ci_`ci' not found in e()"
        noisily display as error "Available CI types depend on gcomp bootstrap options"
        exit 111
    }
    tempname cimat
    matrix `cimat' = e(ci_`ci')
    if rowsof(`cimat') != 2 | colnumb(`cimat', "PO1") == . {
        noisily display as error "CI matrix ci_`ci' has unexpected shape"
        exit 198
    }

    if !strmatch("`xlsx'", "*.xlsx") {
        noisily display as error "Excel filename must have .xlsx extension"
        exit 198
    }
    _gcomp_validate_path "`xlsx'" "xlsx()"
    _gcomp_validate_path "`sheet'" "sheet()"
    _gcomp_xl_validate_sheet "`sheet'" "sheet()"
    if `decimal' < 1 | `decimal' > 6 {
        noisily display as error "decimal() must be between 1 and 6"
        exit 198
    }
    _gcomp_validate_path "`font'" "font()"
    if `fontsize' < 1 | `fontsize' > 72 {
        noisily display as error "fontsize() must be between 1 and 72"
        exit 198
    }
    if !inlist("`borderstyle'", "academic", "thin", "medium") {
        noisily display as error "borderstyle() must be academic, thin, or medium"
        exit 198
    }

    return scalar k = `k'
    return local ci "`ci'"
    return local effect "`effect'"
    return local font "`font'"
    return local borderstyle "`borderstyle'"
    return local hborder "`hborder'"
end

capture program drop _gcomptab_dr_build
program define _gcomptab_dr_build, rclass
    version 16.0
    syntax, CI(string) K(integer) DECimal(integer) REFerence(integer) ///
        [EFFECT(string) TITLE(string) STRATEGYlabels(string) EXPYears(numlist) noRD]

    if "`effect'" == "" local effect "Risk"
    local has_rd = ("`rd'" != "nord")

    tempname eb cimat
    matrix `eb' = e(b)
    matrix `cimat' = e(ci_`ci')

    * Strategy labels (backslash-delimited; unlabeled columns default to PO#)
    local labels : subinstr local strategylabels " \ " "\", all
    local labels : subinstr local labels "\  " "\", all
    local labels : subinstr local labels "  \" "\", all
    tokenize `"`labels'"', parse("\")
    forvalues i = 1/`k' {
        local _p = 2*`i' - 1
        local lab`i' `"``_p''"'
        if `"`lab`i''"' == "" local lab`i' "PO`i'"
    }

    * Implied mean exposure-years (optional, one per PO#)
    local n_exp : word count `expyears'
    if `n_exp' > `k' {
        noisily display as error "expyears() has `n_exp' value(s) but the result has `k' PO# column(s)"
        exit 198
    }
    local has_exp = (`n_exp' > 0)

    * Reference risk
    local _ref_col = colnumb(`eb', "PO`reference'")
    local risk_ref = `eb'[1, `_ref_col']
    local ref_label `"`lab`reference''"'

    * r(table): one row per strategy
    tempname _T
    matrix `_T' = J(`k', 5, .)
    local _rn ""
    forvalues i = 1/`k' {
        local _col = colnumb(`eb', "PO`i'")
        matrix `_T'[`i', 1] = `eb'[1, `_col']
        matrix `_T'[`i', 2] = `cimat'[1, `_col']
        matrix `_T'[`i', 3] = `cimat'[2, `_col']
        local _ev = .
        if `i' <= `n_exp' {
            local _evtok : word `i' of `expyears'
            local _ev = `_evtok'
        }
        matrix `_T'[`i', 4] = `_ev'
        matrix `_T'[`i', 5] = `eb'[1, `_col'] - `risk_ref'
        local _rn "`_rn' PO`i'"
    }
    matrix colnames `_T' = risk ci_lower ci_upper exp_years rd
    matrix rownames `_T' = `=strtrim("`_rn'")'

    * Export dataset (mirrors mediation geometry: A1 title, row 2 header, data)
    local fmt "%9.`decimal'f"
    clear
    set obs `=`k' + 2'
    gen str244 pad = ""
    gen str244 strat = ""
    gen str40 expcol = ""
    gen str60 riskcol = ""
    gen str30 rdcol = ""

    replace pad = `"`title'"' in 1

    replace strat = "Strategy" in 2
    if `has_exp' replace expcol = "Mean exposure-years" in 2
    replace riskcol = "`effect' (95% CI)" in 2
    if `has_rd' replace rdcol = "RD vs ref" in 2

    forvalues i = 1/`k' {
        local _r = `i' + 2
        replace strat = `"`lab`i''"' in `_r'
        local _risk = `_T'[`i', 1]
        local _ll = `_T'[`i', 2]
        local _ul = `_T'[`i', 3]
        replace riskcol = string(`_risk', "`fmt'") + " (" + string(`_ll', "`fmt'") + ", " + string(`_ul', "`fmt'") + ")" in `_r'
        if `has_exp' {
            local _ev = `_T'[`i', 4]
            if `_ev' != . replace expcol = string(`_ev', "%9.0g") in `_r'
        }
        if `has_rd' {
            local _rdv = `_T'[`i', 5]
            replace rdcol = string(`_rdv', "`fmt'") in `_r'
        }
    }

    if !`has_exp' drop expcol
    if !`has_rd' drop rdcol

    gen _ls = length(strat)
    quietly summarize _ls
    local strat_width = max(`r(max)', 12)
    gen _lr = length(riskcol)
    quietly summarize _lr
    local risk_width = max(`r(max)', 18)
    drop _ls _lr

    return scalar num_rows = _N
    return scalar num_cols = 3 + `has_exp' + `has_rd'
    return scalar strat_width = `strat_width'
    return scalar risk_width = `risk_width'
    return scalar has_exp = `has_exp'
    return scalar has_rd = `has_rd'
    return scalar k = `k'
    return local ref_label `"`ref_label'"'
    return matrix table = `_T'
end

capture program drop _gcomptab_dr_style
program define _gcomptab_dr_style
    version 16.0
    syntax, XLSX(string) SHEET(string) ROWS(integer) COLS(integer) ///
        STRATWIDTH(real) RISKWIDTH(real) HASEXP(integer) HASRD(integer) ///
        Font(string) FONTSize(integer) BORDERstyle(string) HBORDER(string) ///
        [HEADERShade HEADERColor(string) ZEBRA ZEBRAColor(string) FOOTnote(string)]

    if `"`headercolor'"' == "" local headercolor "219 229 241"
    if `"`zebracolor'"' == "" local zebracolor "237 242 249"

    * Column positions (col 1 = thin pad, col 2 = strategy label)
    local c_strat 2
    if `hasexp' {
        local c_exp 3
        local c_risk 4
    }
    else {
        local c_risk 3
    }
    if `hasrd' local c_rd = `c_risk' + 1

    * Reconstruct varlist matching column order for numeric conversion
    local _varlist "pad strat"
    if `hasexp' local _varlist "`_varlist' expcol"
    local _varlist "`_varlist' riskcol"
    if `hasrd' local _varlist "`_varlist' rdcol"

    capture {
        mata: b = xl()
        mata: b.load_book("`xlsx'")
        mata: b.set_sheet("`sheet'")

        mata: b.set_row_height(1, 1, 30)
        mata: b.set_column_width(1, 1, 1)
        mata: b.set_column_width(`c_strat', `c_strat', `=`stratwidth' * 0.9')
        if `hasexp' mata: b.set_column_width(`c_exp', `c_exp', 18)
        mata: b.set_column_width(`c_risk', `c_risk', `=`riskwidth' * 0.95')
        if `hasrd' mata: b.set_column_width(`c_rd', `c_rd', 12)

        forvalues _r = 3/`rows' {
            forvalues _c = 3/`cols' {
                local _vname : word `_c' of `_varlist'
                local _cellstr = `_vname'[`_r']
                if `"`_cellstr'"' == "" | `"`_cellstr'"' == "." continue
                if strpos(`"`_cellstr'"', "(") > 0 continue
                local _cellclean = subinstr(`"`_cellstr'"', ",", "", .)
                local _cellnum = real("`_cellclean'")
                if `_cellnum' != . {
                    mata: b.put_number(`_r', `_c', `_cellnum')
                }
            }
        }

        mata: b.set_font((1,`rows'), (1,`cols'), "`font'", `fontsize')
        mata: b.set_font((1,1), (1,`cols'), "`font'", `=`fontsize' + 2')

        mata: b.set_sheet_merge("`sheet'", (1,1), (1,`cols'))
        mata: b.set_text_wrap(1, 1, "on")
        mata: b.set_horizontal_align(1, 1, "left")
        mata: b.set_vertical_align(1, 1, "center")
        mata: b.set_font_bold(1, 1, "on")

        mata: b.set_font_bold(2, (2,`cols'), "on")
        mata: b.set_horizontal_align(2, (2,`cols'), "center")
        mata: b.set_top_border(2, (2,`cols'), "`hborder'")
        mata: b.set_bottom_border(2, (2,`cols'), "`hborder'")
        if "`headershade'" != "" {
            mata: b.set_fill_pattern(2, (2,`cols'), "solid", "`headercolor'")
        }

        mata: b.set_bottom_border(`rows', (2,`cols'), "`hborder'")

        if "`borderstyle'" != "academic" {
            mata: b.set_left_border((2,`rows'), 2, "`hborder'")
            mata: b.set_right_border((2,`rows'), `cols', "`hborder'")
        }

        if `rows' >= 3 & `cols' >= 3 {
            mata: b.set_horizontal_align((3,`rows'), (3,`cols'), "center")
        }
        mata: b.set_horizontal_align((3,`rows'), `c_strat', "left")

        if "`zebra'" != "" {
            forvalues _zr = 4(2)`rows' {
                mata: b.set_fill_pattern(`_zr', (2,`cols'), "solid", "`zebracolor'")
            }
        }

        if `"`footnote'"' != "" {
            local _fn_row = `rows' + 1
            local _fn_fontsize = max(`fontsize' - 2, 6)
            mata: b.put_string(`_fn_row', 2, `"`footnote'"')
            mata: b.set_sheet_merge("`sheet'", (`_fn_row',`_fn_row'), (2,`cols'))
            mata: b.set_horizontal_align(`_fn_row', 2, "left")
            mata: b.set_vertical_align(`_fn_row', 2, "center")
            mata: b.set_text_wrap(`_fn_row', 2, "on")
            mata: b.set_font(`_fn_row', 2, "`font'", `_fn_fontsize')
            mata: b.set_font_italic(`_fn_row', 2, "on")
        }

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
end

* =============================================================================
* _gcomptab_models: regtab-lite component-model table (models mode)
* =============================================================================
* Harvests the stored component models captured by gcomp (savemodels), builds a
* multi-model coefficient table with scale auto-detection, row union/alignment,
* and writes it to xlsx (putexcel), markdown, csv, and/or the Results window.
capture program drop _gcomptab_models
program define _gcomptab_models, rclass
    version 16.0
    local _orig_va = c(varabbrev)
    set varabbrev off
    local _est_held 0
    tempname _esthold
capture noisily {
    syntax , [USEMODels(string) MODELLabels(string) TERMLabels(string) ///
        XLSX(string) SHEET(string) MARKDown(string) CSV(string) COEF(string) ///
        EFORM NOEFORM RAW SE COMPact NOPValue STARS STARSLevels(numlist) ///
        NOINTercept KEEPINTercept KEEP(string) DROP(string) DECimal(integer 3) ///
        STATs(string) TITLE(string) FOOTnote(string) Font(string) ///
        FONTSize(integer 10) BORDERstyle(string) ZEBRA ZEBRAColor(string) ///
        HEADERShade HEADERColor(string) BOLDp(real 0) HIGHlight(real 0) ///
        OPEN DISPlay]

    if `decimal' < 0 | `decimal' > 12 local decimal 3
    if "`font'" == "" local font "Arial"
    if `"`headercolor'"' == "" local headercolor "219 229 241"
    if `"`zebracolor'"' == "" local zebracolor "237 242 249"
    if "`starslevels'" == "" local starslevels "0.05 0.01 0.001"
    * scale override precedence: raw/noeform > eform ; coef() overrides label only
    if "`raw'" != "" local noeform noeform

    * ----- Resolve and validate the model list -----
    if `"`usemodels'"' != "" local _names "`usemodels'"
    else local _names "`e(model_names)'"
    if "`_names'" == "" {
        noisily display as error "models: no stored component models found."
        noisily display as error "  Rerun gcomp with savemodels (or showmodels), or pass usemodels()."
        exit 198
    }
    * Preserve the caller's active e() across our estimates restore calls so a
    * chained gcomptab (or anything reading e(model_names)) still works afterwards.
    _estimates hold `_esthold', restore copy nullok
    local _est_held 1
    foreach _nm of local _names {
        capture estimates restore `_nm'
        if _rc {
            noisily display as error "models: stored estimate `_nm' not found (rerun gcomp with savemodels)"
            exit 301
        }
    }

    * ----- Output targets -----
    if `"`xlsx'"' == "" & `"`markdown'"' == "" & `"`csv'"' == "" & "`display'" == "" {
        noisily display as error "models: specify at least one of xlsx(), markdown(), csv(), or display"
        exit 198
    }
    if `"`xlsx'"' != "" {
        _gcomp_validate_path `"`xlsx'"' "xlsx"
        if `"`sheet'"' == "" local sheet "Models"
        _gcomp_xl_validate_sheet "`sheet'" "sheet"
    }
    if `"`markdown'"' != "" _gcomp_validate_path `"`markdown'"' "markdown"
    if `"`csv'"' != ""      _gcomp_validate_path `"`csv'"' "csv"

    local _M : word count `_names'

    * ----- Harvest each model: terms, estimates, scale -----
    local _keys ""           // ordered union of term keys
    local _do_n = (strpos(" `stats' ", " n ") > 0)
    forvalues k = 1/`_M' {
        local _nm : word `k' of `_names'
        qui estimates restore `_nm'
        tempname b`k' V`k'
        matrix `b`k'' = e(b)
        matrix `V`k'' = e(V)
        local cmd`k'    "`e(cmd)'"
        local depvar`k' "`e(depvar)'"
        local N`k'      = e(N)

        * Scale + label per command (auto), then apply overrides
        if "`cmd`k''" == "logit"       local _sc "OR"
        else if "`cmd`k''" == "mlogit" local _sc "RRR"
        else if "`cmd`k''" == "ologit" local _sc "OR"
        else                            local _sc "Coef."
        local _ef = ("`cmd`k''" != "regress")
        if "`noeform'" != "" {
            local _ef 0
            local _sc "Coef."
        }
        else if "`eform'" != "" {
            local _ef 1
            if "`_sc'" == "Coef." local _sc "exp(b)"
        }
        if `"`coef'"' != "" local _sc "`coef'"
        local eform`k' = `_ef'
        local scale`k' "`_sc'"

        * Column meta
        local _cn : colnames `b`k''
        local _eq : coleq `b`k''
        local _nc = colsof(`b`k'')
        local nc`k' = `_nc'
        forvalues j = 1/`_nc' {
            local _vn : word `j' of `_cn'
            local _en : word `j' of `_eq'
            * skip Stata-omitted/base-level coefficients (e.g. mlogit base outcome)
            if strpos("`_vn'", "o.") > 0 continue
            * key for cross-model alignment
            local _cut = (strpos("`_vn'", "cut") > 0) | ("`_en'" == "/")
            if "`cmd`k''" == "mlogit" | "`cmd`k''" == "ologit" {
                local _key "`_en'::`_vn'"
                if "`_en'" == "" | "`_en'" == "_" local _key "`_vn'"
            }
            else local _key "`_vn'"
            * sanitize key so it is a legal local-macro-name fragment
            local _key = subinstr("`_key'", ":", "_", .)
            local _key = subinstr("`_key'", ".", "_", .)
            local _key = subinstr("`_key'", "#", "_", .)
            * display label
            local _lab "`_vn'"
            if ("`cmd`k''" == "mlogit" | "`cmd`k''" == "ologit") & ///
               "`_en'" != "" & "`_en'" != "_" & "`_en'" != "`depvar`k''" {
                local _lab "`_en': `_vn'"
            }
            * stash per (k, key)
            local val_`k'_`_key' = `b`k''[1, `j']
            local var_`k'_`_key' = `V`k''[`j', `j']
            local lab_`_key' "`_lab'"
            local cut_`_key' = `_cut'
            local cons_`_key' = ("`_vn'" == "_cons")
            * base var name for keep/drop matching
            local _bv = "`_vn'"
            local _bv = regexr("`_bv'", "^[0-9bo]+\.", "")
            local bv_`_key' "`_bv'"
            local has_`_key'_`k' 1
            * add to ordered union on first sight
            local _seen : list posof "`_key'" in _keys
            if `_seen' == 0 local _keys "`_keys' `_key'"
        }
    }
    local _keys : list clean _keys

    * ----- Filter rows: intercept/cutpoints, keep(), drop() -----
    local _rows ""
    foreach _key of local _keys {
        if "`nointercept'" != "" & "`keepintercept'" == "" {
            if `cons_`_key'' | `cut_`_key'' continue
        }
        if `"`keep'"' != "" {
            local _ok 0
            foreach _t of local keep {
                if "`_t'" == "`bv_`_key''" | "`_t'" == "`lab_`_key''" local _ok 1
            }
            if !`_ok' continue
        }
        if `"`drop'"' != "" {
            local _skip 0
            foreach _t of local drop {
                if "`_t'" == "`bv_`_key''" | "`_t'" == "`lab_`_key''" local _skip 1
            }
            if `_skip' continue
        }
        local _rows "`_rows' `_key'"
    }
    local _rows : list clean _rows
    local _T : word count `_rows'
    if `_T' == 0 {
        noisily display as error "models: no rows remain after keep()/drop()/nointercept filtering"
        exit 198
    }

    * ----- Model column labels (modellabels backslash-separated) -----
    if `"`modellabels'"' != "" {
        local _mi 0
        local _ml `"`modellabels'"'
        while `"`_ml'"' != "" {
            gettoken _one _ml : _ml, parse("\")
            if `"`_one'"' == "\" continue
            local ++_mi
            local _userml`_mi' = strtrim(`"`_one'"')
        }
    }
    forvalues k = 1/`_M' {
        if `"`modellabels'"' != "" & "`_userml`k''" != "" local mlab`k' "`_userml`k''"
        else local mlab`k' "`depvar`k''"
    }

    * ----- Term row labels (termlabels overrides, backslash-separated) -----
    if `"`termlabels'"' != "" {
        local _ti 0
        local _tl `"`termlabels'"'
        * split on backslash
        while `"`_tl'"' != "" {
            gettoken _one _tl : _tl, parse("\")
            if `"`_one'"' == "\" continue
            local ++_ti
            local rlbl`_ti' = strtrim(`"`_one'"')
        }
    }

    * ----- Assemble formatted cells -----
    local _efmt "%14.`decimal'f"
    local _pdec = `decimal'
    tempname _rtab
    matrix `_rtab' = J(`_T', `_M', .)
    * safe matrix names (no ':' or leading digits)
    local _rn ""
    foreach _key of local _rows {
        local _s = subinstr("`_key'", ":", "_", .)
        local _s = subinstr("`_s'", ".", "_", .)
        if regexm("`_s'", "^[0-9]") local _s "t`_s'"
        local _rn "`_rn' `_s'"
    }
    local _cn_mat ""
    forvalues k = 1/`_M' {
        local _cn_mat "`_cn_mat' `depvar`k''"
    }
    matrix rownames `_rtab' = `_rn'
    matrix colnames `_rtab' = `_cn_mat'
    local _coeflbl ""
    local _coefmixed 0
    forvalues k = 1/`_M' {
        if "`_coeflbl'" == "" local _coeflbl "`scale`k''"
        else if "`_coeflbl'" != "`scale`k''" local _coefmixed 1
    }
    if `_coefmixed' local _coeflbl "mixed"

    forvalues i = 1/`_T' {
        local _key : word `i' of `_rows'
        * row label
        if `"`termlabels'"' != "" & "`rlbl`i''" != "" local tlab`i' "`rlbl`i''"
        else local tlab`i' "`lab_`_key''"
        forvalues k = 1/`_M' {
            local est`i'_`k' ""
            local unc`i'_`k' ""
            local p`i'_`k'   ""
            local pn`i'_`k'  = .
            if "`has_`_key'_`k''" == "" continue   // term absent in this model
            local _b = `val_`k'_`_key''
            local _v = `var_`k'_`_key''
            if `_v' <= 0 | `_v' >= . {
                local est`i'_`k' "(omitted)"
                continue
            }
            local _se = sqrt(`_v')
            local _z  = `_b' / `_se'
            local _p  = 2 * normal(-abs(`_z'))
            local _lo = `_b' - 1.959964 * `_se'
            local _hi = `_b' + 1.959964 * `_se'
            local _docut = `cut_`_key''
            if `eform`k'' & !`_docut' {
                local _pt = exp(`_b')
                local _lo = exp(`_lo')
                local _hi = exp(`_hi')
                local _sed = `_pt' * `_se'
            }
            else {
                local _pt = `_b'
                local _sed = `_se'
            }
            matrix `_rtab'[`i', `k'] = `_pt'
            local pn`i'_`k' = `_p'
            * estimate (+ stars)
            local _es : display `_efmt' `_pt'
            local _es = strtrim("`_es'")
            if "`stars'" != "" {
                local _st ""
                foreach _lv of numlist `starslevels' {
                    if `_p' < `_lv' local _st "`_st'*"
                }
                local _es "`_es'`_st'"
            }
            local est`i'_`k' "`_es'"
            * uncertainty
            if "`se'" != "" {
                local _ss : display `_efmt' `_sed'
                local unc`i'_`k' "(`=strtrim("`_ss'")')"
            }
            else {
                local _ls : display `_efmt' `_lo'
                local _hs : display `_efmt' `_hi'
                local unc`i'_`k' "[`=strtrim("`_ls'")', `=strtrim("`_hs'")']"
            }
            * p-value
            local _thr = 10^(-`_pdec')
            if `_p' < `_thr' {
                local p`i'_`k' "<0.`=substr("0000000000", 1, `_pdec'-1)'1"
            }
            else {
                local _ps : display %12.`_pdec'f `_p'
                local p`i'_`k' = strtrim("`_ps'")
            }
        }
    }

    * ----- Column geometry -----
    * per model: compact -> 1 col; else est + unc (+ p unless nopvalue)
    if "`compact'" != "" local _percol 1
    else {
        local _percol 2
        if "`nopvalue'" == "" local _percol 3
    }
    local _ncols = 1 + `_M' * `_percol'

    * ----- Methods sentence -----
    local _methods "Component models fit on the analytic sample."
    forvalues k = 1/`_M' {
        local _mm "`cmd`k'' (`scale`k'')"
        local _seen : list posof "`_mm'" in _methodseen
        if `_seen' == 0 {
            local _methodseen "`_methodseen' `_mm'"
            local _methods "`_methods' `depvar`k'': `cmd`k'' reported as `scale`k''."
        }
    }

    * Uncertainty header label
    if "`se'" != "" local _unchdr "SE"
    else local _unchdr "95% CI"

    * ===================== XLSX (putexcel) =====================
    if `"`xlsx'"' != "" {
        _gcomp_xl_require_helpers
        * Preserve peer sheets: replace the whole file only if it does not exist;
        * otherwise modify it and replace just our sheet.
        capture confirm file `"`xlsx'"'
        if _rc {
            putexcel set `"`xlsx'"', sheet(`"`sheet'"') replace
        }
        else {
            putexcel set `"`xlsx'"', modify sheet(`"`sheet'"', replace)
        }
        local _r 1
        if `"`title'"' != "" {
            putexcel A1 = `"`title'"', bold
            _gcomp_col_letter `_ncols'
            putexcel (A1:`result'1), merge
            local _r = 2
        }
        local _hA = `_r'          // model-label header row
        local _hB = `_r' + 1      // content header row
        putexcel A`_hB' = "Term", bold
        forvalues k = 1/`_M' {
            local _c0 = 2 + (`k'-1)*`_percol'
            local _c1 = `_c0' + `_percol' - 1
            _gcomp_col_letter `_c0'
            local _L0 "`result'"
            _gcomp_col_letter `_c1'
            local _L1 "`result'"
            putexcel `_L0'`_hA' = "`mlab`k''", bold hcenter
            if `_percol' > 1 putexcel (`_L0'`_hA':`_L1'`_hA'), merge hcenter
            * content sub-headers
            if "`compact'" != "" {
                putexcel `_L0'`_hB' = "`scale`k'' [`_unchdr']", bold hcenter
            }
            else {
                putexcel `_L0'`_hB' = "`scale`k''", bold hcenter
                _gcomp_col_letter `=`_c0'+1'
                putexcel `result'`_hB' = "`_unchdr'", bold hcenter
                if "`nopvalue'" == "" {
                    _gcomp_col_letter `=`_c0'+2'
                    putexcel `result'`_hB' = "p", bold hcenter
                }
            }
        }
        * header shade
        if "`headershade'" != "" {
            _gcomp_col_letter `_ncols'
            putexcel (A`_hA':`result'`_hB'), fpattern(solid, "`headercolor'")
        }
        * body
        local _br = `_hB' + 1
        forvalues i = 1/`_T' {
            local _row = `_br' + `i' - 1
            putexcel A`_row' = "`tlab`i''"
            forvalues k = 1/`_M' {
                local _c0 = 2 + (`k'-1)*`_percol'
                _gcomp_col_letter `_c0'
                if "`compact'" != "" {
                    local _cell = strtrim("`est`i'_`k'' `unc`i'_`k''")
                    putexcel `result'`_row' = "`_cell'"
                }
                else {
                    local _bold ""
                    if `boldp' > 0 & `pn`i'_`k'' < `boldp' & `pn`i'_`k'' < . local _bold ", bold"
                    putexcel `result'`_row' = "`est`i'_`k''"`_bold'
                    _gcomp_col_letter `=`_c0'+1'
                    putexcel `result'`_row' = "`unc`i'_`k''"
                    if "`nopvalue'" == "" {
                        _gcomp_col_letter `=`_c0'+2'
                        putexcel `result'`_row' = "`p`i'_`k''"
                    }
                }
            }
            if "`zebra'" != "" & mod(`i',2)==0 {
                _gcomp_col_letter `_ncols'
                putexcel (A`_row':`result'`_row'), fpattern(solid, "`zebracolor'")
            }
            * highlight rows with a significant p (overrides zebra)
            if `highlight' > 0 {
                local _rowsig 0
                forvalues k = 1/`_M' {
                    if `pn`i'_`k'' < `highlight' & `pn`i'_`k'' < . local _rowsig 1
                }
                if `_rowsig' {
                    _gcomp_col_letter `_ncols'
                    putexcel (A`_row':`result'`_row'), fpattern(solid, "255 255 153")
                }
            }
        }
        local _lastrow = `_br' + `_T' - 1
        * stats: N row
        if `_do_n' {
            local ++_lastrow
            putexcel A`_lastrow' = "N", italic
            forvalues k = 1/`_M' {
                local _c0 = 2 + (`k'-1)*`_percol'
                _gcomp_col_letter `_c0'
                putexcel `result'`_lastrow' = `N`k''
            }
        }
        * borders + font
        _gcomp_col_letter `_ncols'
        local _lastL "`result'"
        if "`borderstyle'" != "none" {
            putexcel (A`_hA':`_lastL'`_lastrow'), border(all, thin)
        }
        putexcel (A`_hA':`_lastL'`_lastrow'), font("`font'", `fontsize')
        * footnote
        if `"`footnote'"' != "" {
            _gcomp_xl_footnote `"`footnote'"' "`_lastL'" `_lastrow' "`font'" "`fontsize'"
        }
        putexcel close
        if "`open'" != "" _gcomp_xl_open "`xlsx'"
    }

    * ===================== Markdown =====================
    if `"`markdown'"' != "" {
        tempname _fh
        file open `_fh' using `"`markdown'"', write replace text
        if `"`title'"' != "" {
            file write `_fh' "### `title'" _n _n
        }
        * header
        local _hdr "| Term "
        local _sep "| --- "
        forvalues k = 1/`_M' {
            if "`compact'" != "" {
                local _hdr "`_hdr'| `mlab`k'' (`scale`k'') "
                local _sep "`_sep'| --- "
            }
            else {
                local _hdr "`_hdr'| `mlab`k'' `scale`k'' | `mlab`k'' `_unchdr' "
                local _sep "`_sep'| --- | --- "
                if "`nopvalue'" == "" {
                    local _hdr "`_hdr'| `mlab`k'' p "
                    local _sep "`_sep'| --- "
                }
            }
        }
        file write `_fh' "`_hdr'|" _n "`_sep'|" _n
        forvalues i = 1/`_T' {
            local _line "| `tlab`i'' "
            forvalues k = 1/`_M' {
                if "`compact'" != "" {
                    local _line "`_line'| `=strtrim("`est`i'_`k'' `unc`i'_`k''")' "
                }
                else {
                    local _line "`_line'| `est`i'_`k'' | `unc`i'_`k'' "
                    if "`nopvalue'" == "" local _line "`_line'| `p`i'_`k'' "
                }
            }
            file write `_fh' "`_line'|" _n
        }
        if `_do_n' {
            local _line "| N "
            forvalues k = 1/`_M' {
                local _line "`_line'| `N`k'' "
                if "`compact'" == "" {
                    local _line "`_line'|  "
                    if "`nopvalue'" == "" local _line "`_line'|  "
                }
            }
            file write `_fh' "`_line'|" _n
        }
        if `"`footnote'"' != "" file write `_fh' _n "_`footnote'_" _n
        file close `_fh'
    }

    * ===================== CSV =====================
    if `"`csv'"' != "" {
        tempname _fc
        file open `_fc' using `"`csv'"', write replace text
        local _hdr `""Term""'
        forvalues k = 1/`_M' {
            if "`compact'" != "" {
                local _hdr `"`_hdr',"`mlab`k'' (`scale`k'')""'
            }
            else {
                local _hdr `"`_hdr',"`mlab`k'' `scale`k''","`mlab`k'' `_unchdr'""'
                if "`nopvalue'" == "" local _hdr `"`_hdr',"`mlab`k'' p""'
            }
        }
        file write `_fc' `"`_hdr'"' _n
        forvalues i = 1/`_T' {
            local _line `""`tlab`i''""'
            forvalues k = 1/`_M' {
                if "`compact'" != "" {
                    local _line `"`_line',"`=strtrim("`est`i'_`k'' `unc`i'_`k''")'""'
                }
                else {
                    local _line `"`_line',"`est`i'_`k''","`unc`i'_`k''""'
                    if "`nopvalue'" == "" local _line `"`_line',"`p`i'_`k''""'
                }
            }
            file write `_fc' `"`_line'"' _n
        }
        if `_do_n' {
            local _line `""N""'
            forvalues k = 1/`_M' {
                local _line `"`_line',"`N`k''""'
                if "`compact'" == "" {
                    local _line `"`_line',"""'
                    if "`nopvalue'" == "" local _line `"`_line',"""'
                }
            }
            file write `_fc' `"`_line'"' _n
        }
        file close `_fc'
    }

    * ===================== Results window =====================
    if "`display'" != "" {
        noi di
        if `"`title'"' != "" noi di as text "   `title'"
        forvalues k = 1/`_M' {
            noi di as text "   " as result "`mlab`k''" as text " (`cmd`k'', `scale`k'')" _cont
            if `k' < `_M' noi di as text "    " _cont
        }
        noi di
        forvalues i = 1/`_T' {
            noi di as result "   " %-18s abbrev("`tlab`i''",18) _cont
            forvalues k = 1/`_M' {
                if "`est`i'_`k''" == "" {
                    noi di as result "  ." _cont
                }
                else if "`compact'" != "" {
                    noi di as result "  " "`est`i'_`k'' `unc`i'_`k''" _cont
                }
                else {
                    noi di as result "  " "`est`i'_`k'' `unc`i'_`k''" _cont
                    if "`nopvalue'" == "" noi di as result " p=`p`i'_`k''" _cont
                }
            }
            noi di
        }
        if `_do_n' {
            noi di as text "   " %-18s "N" _cont
            forvalues k = 1/`_M' {
                noi di as result "  `N`k''" _cont
            }
            noi di
        }
        if `"`footnote'"' != "" noi di as text "   `footnote'"
    }

    * ----- Returns -----
    return scalar N_models = `_M'
    return scalar N_rows   = `_T'
    return scalar N_cols   = `_ncols'
    return local coef_label "`_coeflbl'"
    return local methods `"`_methods'"'
    if `"`xlsx'"' != "" {
        return local xlsx  `"`xlsx'"'
        return local sheet `"`sheet'"'
    }
    if `"`markdown'"' != "" return local markdown `"`markdown'"'
    if `"`csv'"' != ""      return local csv `"`csv'"'
    return matrix table = `_rtab'
}
    local _rc = _rc
    if `_est_held' {
        capture _estimates unhold `_esthold'
        if `_rc' == 0 & _rc local _rc = _rc
    }
    set varabbrev `_orig_va'
    if `_rc' exit `_rc'
end

*
