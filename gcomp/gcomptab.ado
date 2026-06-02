*! gcomptab Version 1.2.0  2026/05/29
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

    syntax, xlsx(string) sheet(string) [ci(string) effect(string) title(string) ///
            labels(string) decimal(integer 3) Font(string) FONTSize(integer 10) ///
            BORDERstyle(string) THEme(string) HEADERShade NOSHAde ///
            HEADERColor(string) ZEBRA ZEBRAColor(string) NOZEbra ///
            FOOTnote(string) OPEN BOLDp(real 0) ///
            HIGHlight(real 0) DOSEresponse STRATEGYlabels(string) ///
            EXPYears(numlist) REFerence(integer 1) noRD]

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
            `zebra' zebracolor(`"`zebracolor'"') footnote(`"`footnote'"') `open'
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

    if "`open'" != "" {
        _gcomp_xl_open "`xlsx'"
    }

    _gcomptab_post_returns, xlsx(`"`xlsx'"') sheet(`"`sheet'"') ci(`"`ci'"') ///
        hascde(`has_cde') neffects(`N_effects') tce(`tce') nde(`nde') ///
        nie(`nie') pm(`pm') cde(`cde')
    return add
}
    }
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
        NEFFECTS(integer) TCE(real) NDE(real) NIE(real) PM(real) CDE(real)

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
        FOOTnote(string) OPEN]

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

    if "`open'" != "" {
        _gcomp_xl_open "`xlsx'"
    }

    return scalar k = `k'
    return scalar reference = `reference'
    return local xlsx "`xlsx'"
    return local sheet "`sheet'"
    return local ci "`ci'"
    return local ref_label `"`ref_label'"'
    return matrix table = `_drtab'
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

*
