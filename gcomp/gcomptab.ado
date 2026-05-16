*! gcomptab Version 1.1.2  2026/05/06
*! Format gcomp mediation analysis results for Excel export
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
DESCRIPTION:
    Formats gcomp (parametric g-formula for causal mediation) results into
    polished Excel tables. Exports point estimates, 95% CIs, and standard errors
    with professional formatting.

    gcomp is a user-written command for causal mediation analysis that uses
    Monte Carlo simulation to estimate total causal effects (TCE), natural direct
    effects (NDE), natural indirect effects (NIE), proportion mediated (PM),
    and controlled direct effects (CDE).

SYNTAX:
    gcomptab, xlsx(string) sheet(string) [ci(string) effect(string) title(string)
              labels(string) decimal(integer) font(string) fontsize(integer)
              borderstyle(string) zebra footnote(string) open boldp(real)
              highlight(real)]

    xlsx:    Required. Excel file name (requires .xlsx suffix)
    sheet:   Required. Excel sheet name
    ci:      CI type: normal, percentile, bc, or bca (default: normal)
    effect:  Label for effect column (default: "Estimate")
    title:   Table title for cell A1
    labels:  Custom labels for effects, separated by backslash
             (default: "TCE \ NDE \ NIE \ PM \ CDE")
    decimal: Decimal places for estimates (default: 3)

PREREQUISITES:
    Run gcomp first. gcomptab reads from e() results posted by gcomp:
    - e(b)[1,N]          - point estimates (cols: tce, nde, nie, pm, [cde])
    - e(se)[1,N]         - standard errors
    - e(ci_normal)[2,N]  - normal CIs (row 1=lower, row 2=upper)
    - e(ci_percentile), e(ci_bc), e(ci_bca) - alternative CI matrices
    - e(cmd) == "gcomp", e(analysis_type) == "mediation"

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
            BORDERstyle(string) ZEBRA FOOTnote(string) OPEN BOLDp(real 0) ///
            HIGHlight(real 0)]

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
            hborder(`"`_hborder'"') `zebra' footnote(`"`footnote'"') ///
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
} /* end capture noisily */
local _gc_rc = _rc
set varabbrev `_gc_varabbrev'
if `_gc_rc' exit `_gc_rc'
end

capture program drop _gcomptab_validate
program define _gcomptab_validate, rclass
    version 16.0
    syntax, XLSX(string) SHEET(string) DECimal(integer) FONTSIZE(integer) ///
        BOLDP(real) HIGHLIGHT(real) [CI(string) EFFECT(string) ///
        FONT(string) BORDERSTYLE(string)]

    if "`ci'" == "" local ci "normal"
    if "`effect'" == "" local effect "Estimate"
    if "`font'" == "" local font "Arial"
    if "`borderstyle'" == "" local borderstyle "academic"
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
        LABELWIDTH(real) CIWIDTH(real) FONT(string) FONTSIZE(integer) ///
        BORDERSTYLE(string) HBORDER(string) [ZEBRA FOOTNOTE(string) ///
        BOLDP(real 0) HIGHLIGHT(real 0) PVALTCE(string) PVALNDE(string) ///
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
        mata: b.set_fill_pattern(2, (2,`cols'), "solid", "219 229 241")

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
                mata: b.set_fill_pattern(`_zr', (2,`cols'), "solid", "237 242 249")
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

*
