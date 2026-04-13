*! tablex Version 1.0.2  2026/04/12
*! Export Stata tables to formatted Excel
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
DESCRIPTION:
    Exports the active collect table to Excel with professional formatting.
    Works with Stata 17+ table command and collect infrastructure.
    Applies consistent formatting: column widths, borders, fonts, merged headers.

SYNTAX:
    tablex using filename.xlsx, sheet(string) [title(string) replace ///
           font(string) fontsize(integer) borderstyle(string) headerrows(integer)]

    using:        Required. Excel file name (must have .xlsx extension)
    sheet:        Required. Excel sheet name
    title:        Table title for cell A1
    replace:      Replace existing sheet
    font:         Font name (default: Arial)
    fontsize:     Font size in points (default: 10)
    borderstyle:  Border style: thin or medium (default: thin)
    headerrows:   Number of header rows to format specially (default: auto-detect)

PREREQUISITES:
    Run table or collect commands first to create a collection:

    * Using table command
    table var1 var2, statistic(mean outcome) statistic(sd outcome)
    tablex using results.xlsx, sheet("Summary") title("Table 1")

    * Using collect prefix
    collect: summarize price mpg weight
    tablex using results.xlsx, sheet("Descriptives")

    * Multiple tables in one collection
    collect create mytab
    collect: table rep78, statistic(mean price)
    collect: table foreign, statistic(mean price)
    tablex using results.xlsx, sheet("Combined")

EXAMPLES:
    * Basic frequency table
    sysuse auto, clear
    table foreign rep78
    tablex using auto_freq.xlsx, sheet("Frequencies") title("Car Frequencies")

    * Summary statistics
    table foreign, statistic(mean price mpg) statistic(sd price mpg)
    tablex using auto_stats.xlsx, sheet("Stats") title("Summary by Origin")

    * Custom formatting
    table foreign, statistic(mean price)
    tablex using results.xlsx, sheet("Table1") title("Mean Price") ///
           font(Calibri) fontsize(11) borderstyle(medium)
*/

program define tablex, rclass
    version 17.0
    local _prev_varabbrev = c(varabbrev)
    set varabbrev off

    * Auto-load shared helper programs if not already in memory
    capture program list _tabtools_validate_path
    if _rc {
        capture findfile _tabtools_common.ado
        if _rc == 0 {
            run "`r(fn)'"
        }
        else {
            display as error "_tabtools_common.ado not found; reinstall tabtools"
            set varabbrev `_prev_varabbrev'
            exit 111
        }
    }

    capture noisily {

    syntax using/, [sheet(string)] [title(string) replace ///
           font(string) fontsize(integer 10) borderstyle(string) headerrows(integer 0) ///
           nformat(string) FOOTnote(string) open zebra ///
           HEADERColor(string) ZEBRAColor(string) THEme(string) csv(string) FRAme(string)]

    if "`sheet'" == "" local sheet "Table"

    * Validate sheet name for Excel constraints
    _tabtools_validate_sheet "`sheet'" "sheet()"

quietly {

    * =========================================================================
    * VALIDATION
    * =========================================================================

    * Check if collect table exists
    capture quietly collect query row
    if _rc {
        noisily display as error "No active collect table found"
        noisily display as error "Run table or collect commands with {bf:collect:} prefix first"
        noisily display as error "Hint: {bf:collect clear} then {bf:collect: table ...}"
        noisily display as error ""
        noisily display as error "Example:"
        noisily display as error "    table foreign rep78"
        noisily display as error "    tablex using results.xlsx, sheet(Table1)"
        exit 119
    }

    * Extract filename from using
    local xlsx = "`using'"

    * Check if file name has .xlsx extension
    if !strmatch("`xlsx'", "*.xlsx") {
        noisily display as error "Excel filename must have .xlsx extension"
        exit 198
    }

    * Validate paths for dangerous characters
    _tabtools_validate_path "`xlsx'" "using"
    _tabtools_validate_path "`sheet'" "sheet()"
    if "`csv'" != "" _tabtools_validate_path "`csv'" "csv()"

    * Set defaults (W4: check globals first)
    if "`font'" == "" {
        if "$TABTOOLS_FONT" != "" local font "$TABTOOLS_FONT"
        else local font "Arial"
    }
    if `fontsize' == 10 & "$TABTOOLS_FONTSIZE" != "" {
        local fontsize $TABTOOLS_FONTSIZE
    }
    if "`borderstyle'" == "" & "$TABTOOLS_BORDER" != "" {
        local borderstyle "$TABTOOLS_BORDER"
    }
    if "`borderstyle'" == "" local borderstyle "thin"
    if "`borderstyle'" == "default" local borderstyle "thin"

    * Validate borderstyle
    if !inlist("`borderstyle'", "thin", "medium", "academic") {
        noisily display as error "borderstyle() must be thin, medium, or academic"
        exit 198
    }
    local _hborder = cond("`borderstyle'" == "academic", "medium", "`borderstyle'")

    * Apply theme: explicit option overrides global
    if "`theme'" == "" & "$TABTOOLS_THEME" != "" local theme "$TABTOOLS_THEME"
    if "`theme'" != "" {
        _tabtools_apply_theme "`theme'"
        if "`font'" == "Arial" local font "`_theme_font'"
        if `fontsize' == 10 local fontsize `_theme_fontsize'
        if "`borderstyle'" == "thin" local borderstyle "`_theme_border'"
    }

    * Resolve header/zebra colors (O4)
    local _headercolor "219 229 241"
    local _zebracolor "237 242 249"
    if "$TABTOOLS_HEADERCOLOR" != "" local _headercolor "$TABTOOLS_HEADERCOLOR"
    if "$TABTOOLS_ZEBRACOLOR" != "" local _zebracolor "$TABTOOLS_ZEBRACOLOR"
    if "`headercolor'" != "" local _headercolor "`headercolor'"
    if "`zebracolor'" != "" local _zebracolor "`zebracolor'"

    * Validate fontsize
    if `fontsize' < 6 | `fontsize' > 72 {
        noisily display as error "fontsize() must be between 6 and 72"
        exit 198
    }

    * Create temporary file for intermediate processing
    tempfile temp_export
    local temp_xlsx "`temp_export'.xlsx"

    * Store return values
    return local using "`xlsx'"
    return local sheet "`sheet'"

    * =========================================================================
    * EXPORT COLLECT TABLE
    * =========================================================================

    * Apply minimal styling to preserve user's table structure
    collect style column, dups(center)

    * Export to temporary file first
    local sheet_opt = cond("`replace'" != "", "replace", "")
    capture collect export "`temp_xlsx'", sheet("temp", replace)
    if _rc {
        noisily display as error "Failed to export collect table"
        noisily display as error "Check that collect table is properly structured"
        exit _rc
    }

    * Preserve user data before import
    preserve

    * Import for processing
    capture import excel "`temp_xlsx'", sheet("temp") clear allstring
    if _rc {
        noisily display as error "Failed to import temporary Excel file"
        capture erase "`temp_xlsx'"
        restore
        exit _rc
    }

    * Guard against empty collect tables (R3)
    if _N < 3 {
        noisily display as error "Collect table appears empty or has insufficient data"
        capture erase "`temp_xlsx'"
        restore
        exit 2000
    }

    * =========================================================================
    * PROCESS DATA
    * =========================================================================

    * Get dimensions
    local num_rows = _N
    local num_cols = c(k)

    * Rename variables to standard names (A, B, C, ...)
    local col = 1
    foreach var of varlist * {
        _tabtools_col_letter `col'
        local letter = "`result'"
        if "`var'" != "`letter'" {
            capture rename `var' `letter'
        }
        local col = `col' + 1
    }

    * Auto-detect header rows if not specified
    * Header rows typically have values in first few cells but data starts with numbers
    if `headerrows' == 0 {
        * Default to 1 header row, but check for multi-level headers
        local headerrows = 1

        * Check if row 2 looks like a continuation header (text in most cells)
        if `num_rows' >= 2 {
            local row2_numeric = 0
            foreach var of varlist * {
                capture confirm number `=`var'[2]'
                if _rc == 0 local row2_numeric = `row2_numeric' + 1
            }
            * If row 2 is mostly text, treat it as header
            if `row2_numeric' < (`num_cols' / 2) {
                local headerrows = 2
            }
        }
    }

    * =========================================================================
    * CALCULATE COLUMN WIDTHS
    * =========================================================================

    * Calculate max content length for each column
    local col = 1
    foreach var of varlist * {
        gen `var'_len = length(`var')
        sum `var'_len, meanonly
        local max_len_`col' = r(max)
        drop `var'_len
        local col = `col' + 1
    }

    * First column (row labels) - typically wider
    local col1_width = ceil(`max_len_1' * 0.9)
    if `col1_width' < 12 local col1_width = 12
    if `col1_width' > 50 local col1_width = 50

    * Data columns - find max across all
    local max_data_len = 0
    forvalues c = 2/`num_cols' {
        if `max_len_`c'' > `max_data_len' local max_data_len = `max_len_`c''
    }
    local data_width = ceil(`max_data_len' * 0.85)
    if `data_width' < 8 local data_width = 8
    if `data_width' > 25 local data_width = 25

    * =========================================================================
    * ADD TITLE ROW
    * =========================================================================

    if "`title'" != "" {
        * Add row for title
        gen _id = _n
        local new_obs = `num_rows' + 1
        set obs `new_obs'
        replace _id = 0 if _id == .
        sort _id
        drop _id

        * Create title column and set title
        gen _title = ""
        order _title
        replace _title = "`title'" in 1

        local num_rows = `num_rows' + 1
        local num_cols = `num_cols' + 1
        local headerrows = `headerrows' + 1
    }

    * Optional CSV export from the finalized table dataset
    if "`csv'" != "" {
        export delimited using "`csv'", replace
    }

    * =========================================================================
    * EXPORT TO FINAL EXCEL FILE
    * =========================================================================

    local sheet_replace = cond("`replace'" != "", "sheetreplace", "")
    capture export excel using "`xlsx'", sheet("`sheet'") `sheet_replace'
    if _rc {
        noisily display as error "Failed to export to `xlsx', sheet `sheet'"
        noisily display as error "Check file permissions and that file is not open in Excel"
        capture erase "`temp_xlsx'"
        restore
        exit _rc
    }

    * =========================================================================
    * APPLY MATA FORMATTING (Column widths, row heights)
    * =========================================================================

    capture {
        mata: b = xl()
        mata: b.load_book("`xlsx'")
        mata: b.set_sheet("`sheet'")

        * Title row height
        if "`title'" != "" {
            mata: b.set_row_height(1, 1, 30)
            mata: b.set_column_width(1, 1, 2)  // Title column narrow
            mata: b.set_column_width(2, 2, `col1_width')  // First data column
            mata: b.set_column_width(3, `num_cols', `data_width')  // Remaining columns
        }
        else {
            mata: b.set_column_width(1, 1, `col1_width')  // First column
            mata: b.set_column_width(2, `num_cols', `data_width')  // Remaining columns
        }

        * Overwrite string cells containing numbers with proper Excel numeric cells
        local _data_start = `headerrows' + 1
        local _col_start = cond("`title'" != "", 2, 1)

        forvalues _r = `_data_start'/`num_rows' {
            local _c_idx = 0
            foreach _var of varlist * {
                local _c_idx = `_c_idx' + 1
                if `_c_idx' < `_col_start' continue
                local _cellstr = `_var'[`_r']
                if "`_cellstr'" == "" | "`_cellstr'" == "." continue
                local _cellclean = subinstr("`_cellstr'", ",", "", .)
                local _cellnum = real("`_cellclean'")
                if `_cellnum' != . {
                    mata: b.put_number(`_r', `_c_idx', `_cellnum')
                    if `"`nformat'"' != "" {
                        mata: b.set_number_format(`_r', `_c_idx', "`nformat'")
                    }
                }
            }
        }

        mata: b.close_book()
    }
    if _rc {
        local saved_rc = _rc
        capture mata: b.close_book()
        capture mata: mata drop b
        noisily display as error "Excel formatting (Mata) failed with error `saved_rc'"
        capture erase "`temp_xlsx'"
        restore
        exit `saved_rc'
    }
    capture mata: mata drop b

    * =========================================================================
    * APPLY PUTEXCEL FORMATTING (Borders, fonts, merging)
    * =========================================================================

    * Build column letters
    _tabtools_build_col_letters `num_cols'
    local col_letters = "`result'"

    * Get key column letters
    local first_col : word 1 of `col_letters'
    local last_col : word `num_cols' of `col_letters'

    * Determine table start column (B if title, A otherwise)
    if "`title'" != "" {
        local table_start = "B"
        local table_start_num = 2
    }
    else {
        local table_start = "A"
        local table_start_num = 1
    }

    capture {
        putexcel set "`xlsx'", sheet("`sheet'") modify

        * Title formatting (if present)
        if "`title'" != "" {
            putexcel (A1:`last_col'1), merge txtwrap left vcenter bold font(`font', `=`fontsize'+2')
        }

        * Header row formatting
        local header_start = cond("`title'" != "", 2, 1)
        local header_end = `headerrows'
        local data_start = `headerrows' + 1

        * Bold headers with background
        putexcel (`table_start'`header_start':`last_col'`header_end'), bold font(`font', `fontsize')
        putexcel (`table_start'`header_start':`last_col'`header_end'), fpattern(solid, "`_headercolor'")

        * Top border
        putexcel (`table_start'`header_start':`last_col'`header_start'), border(top, `_hborder')

        * Bottom of header
        putexcel (`table_start'`header_end':`last_col'`header_end'), border(bottom, `_hborder')

        * Left and right borders
        if "`borderstyle'" != "academic" {
            putexcel (`table_start'`header_start':`table_start'`num_rows'), border(left, `borderstyle')
            putexcel (`last_col'`header_start':`last_col'`num_rows'), border(right, `borderstyle')
        }

        * Bottom border
        putexcel (`table_start'`num_rows':`last_col'`num_rows'), border(bottom, `_hborder')

        * Data font
        if `data_start' <= `num_rows' {
            putexcel (`table_start'`data_start':`last_col'`num_rows'), font(`font', `fontsize')
        }

        * Center-align data columns
        if `data_start' <= `num_rows' {
            putexcel (`table_start'`data_start':`last_col'`num_rows'), hcenter
        }

        * Zebra striping (O3)
        if "`zebra'" != "" & `data_start' <= `num_rows' {
            forvalues _zr = `=`data_start'+1'(2)`num_rows' {
                putexcel (`table_start'`_zr':`last_col'`_zr'), fpattern(solid, "`_zebracolor'")
            }
        }

        * Footnote (F2)
        if `"`footnote'"' != "" {
            _tabtools_footnote `"`footnote'"' "`last_col'" `num_rows' "`font'" `fontsize'
        }

        putexcel clear
    }
    if _rc {
        local saved_rc = _rc
        noisily display as error "Excel formatting (putexcel) failed with error `saved_rc'"
        capture erase "`temp_xlsx'"
        restore
        exit `saved_rc'
    }

    * =========================================================================
    * CLEANUP
    * =========================================================================

    capture erase "`temp_xlsx'"

    * Store output in frame if requested
    if `"`frame'"' != "" {
        _tabtools_frame_put `"`frame'"'
        local frame "`_frame_name'"
    }

    * Restore user data
    restore

    * Return statistics
    return scalar N_rows = `num_rows'
    return scalar N_cols = `num_cols'
    return scalar header_rows = `headerrows'
    if "`frame'" != "" return local frame "`frame'"

}

    noisily display as text "Exported to `xlsx', sheet `sheet'"

    * Open file if requested (W3)
    if "`open'" != "" _tabtools_open_file "`xlsx'"

    } // end capture noisily
    local _rc = _rc
    set varabbrev `_prev_varabbrev'
    if `_rc' exit `_rc'
end

*
