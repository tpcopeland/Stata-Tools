*! stratetab | Version 1.0.1
*! Author: Tim Copeland
*! Revised: November 21, 2025

program define stratetab, rclass
version 17

    if "`_byvars'" != "" {
        di as err "stratetab may not be combined with by:"
        exit 190
    }

    syntax, using(namelist) xlsx(string) [sheet(string) title(string) ///
        labels(string) digits(integer 1) eventdigits(integer 0) pydigits(integer 0) unitlabel(string)]

    * Validation: Check if xlsx has .xlsx extension
    if !strmatch("`xlsx'", "*.xlsx") {
        di as err "xlsx must have .xlsx extension"
        exit 198
    }

    * Validation: Check digit ranges
    if `digits' < 0 | `digits' > 10 | `eventdigits' < 0 | `eventdigits' > 10 | `pydigits' < 0 | `pydigits' > 10 {
        di as err "digit options must be 0-10"
        exit 125
    }

    qui {
        * Parse labels
        local n_files : word count `using'
        if "`labels'" != "" {
            * Normalize whitespace around backslash separators
            local labels = ustrregexra("`labels'", " *\\ *", "\")
            tokenize "`labels'", parse("\")
            forvalues i = 1/`n_files' {
                local j = (`i'-1)*2 + 1
                local lab`i' "``j''"
            }
        }
        else {
            forvalues i = 1/`n_files' {
                local lab`i' "Outcome `i'"
            }
        }

        * Build output dataset structure
        clear
        gen str244 c1 = ""
        gen str244 c2 = ""
        gen str244 c3 = ""
        gen str244 c4 = ""
        gen str244 c5 = ""
        set obs 1

        * Title row (in column A)
        replace c1 = "`title'" in 1
    }

    * Identify categorical variable(s)
    local catvar_list ""
    qui {
        forvalues f = 1/`n_files' {
            local file : word `f' of `using'
            preserve
            cap use "`file'.dta", clear
            if _rc {
                di as err "File not found: `file'.dta"
                restore
                exit 601
            }

            * Find the categorical variable using helper
            get_categorical_var
            local catvar_list "`catvar_list' `catvar'"

            * Store value label name for validation
            local vallabel_`f' : value label `catvar'
            restore
        }

        * Validation: Warn if value labels don't match
        if `n_files' > 1 {
            local first_catvar : word 1 of `catvar_list'
            local first_vallabel `vallabel_1'
            forvalues i = 2/`n_files' {
                local this_catvar : word `i' of `catvar_list'
                local this_vallabel `vallabel_`i''
                if "`first_catvar'" == "`this_catvar'" & "`first_vallabel'" != "`this_vallabel'" {
                    noisily di as text "Warning: Variable `first_catvar' has different value labels across files"
                    noisily di as text "  File 1: `first_vallabel'"
                    noisily di as text "  File `i': `this_vallabel'"
                }
            }
        }
    }

    qui {
        * Determine header label
        local catvar_unique : list uniq catvar_list
        local n_unique : word count `catvar_unique'

        if `n_files' == 1 {
            local firstcat : word 1 of `catvar_unique'
            preserve
            local file : word 1 of `using'
            use "`file'.dta", clear
            local varlabel : variable label `firstcat'
            if "`varlabel'" == "" local varlabel "`firstcat'"
            restore
            local col1_header "Outcome by `varlabel'"
        }
        else if `n_unique' == 1 {
            local firstcat : word 1 of `catvar_unique'
            preserve
            local file : word 1 of `using'
            use "`file'.dta", clear
            local varlabel : variable label `firstcat'
            if "`varlabel'" == "" local varlabel "`firstcat'"
            restore
            local col1_header "Outcomes by `varlabel'"
        }
        else {
            local col1_header "Outcomes by Group"
        }

        * Header row setup
        local new = _N + 1
        set obs `new'
        replace c2 = "`col1_header'" in `new'
        replace c3 = "Events" in `new'
        if "`unitlabel'" != "" {
            replace c4 = "Person-years" + char(10) + "(`unitlabel's)" in `new'
            replace c5 = "Rate per `unitlabel'" + char(10) + "person-years (95% CI)" in `new'
        }
        else {
            replace c4 = "Person-years" in `new'
            replace c5 = "Rate (95% CI)" in `new'
        }

        * PROCESS FILES
        forvalues f = 1/`n_files' {
            local file : word `f' of `using'

            * Load file
            preserve
            use "`file'.dta", clear

            cap confirm var _Rate _Lower _Upper _D _Y
            if _rc {
                di as err "`file'.dta missing required columns"
                restore
                exit 111
            }

            get_categorical_var

            cap confirm string var `catvar'
            if _rc {
                decode `catvar', gen(catvar_str)
            }
            else {
                gen catvar_str = `catvar'
            }

            * Call helper to format variables
            format_strate_data `eventdigits' `pydigits' `digits'

            * Extract data to locals
            local data_rows = _N
            forvalues i = 1/`data_rows' {
                local v1_`i' = "    " + catvar_str[`i']
                local v2_`i' = ev[`i']
                local v3_`i' = py[`i']
                local v4_`i' = rt[`i']
            }
            restore

            * Outcome header row
            local new = _N + 1
            set obs `new'
            replace c2 = "`lab`f''" in `new'

            * Add data rows
            local current_n = _N
            local new_n = `current_n' + `data_rows'
            set obs `new_n'

            forvalues i = 1/`data_rows' {
                local row_num = `current_n' + `i'
                replace c2 = "`v1_`i''" in `row_num'
                replace c3 = "`v2_`i''" in `row_num'
                replace c4 = "`v3_`i''" in `row_num'
                replace c5 = "`v4_`i''" in `row_num'
            }
        }

        * EXPORT
        local lastrow = _N
        gen outcome_row = (c3 == "" & c2 != "" & _n > 2)
        local outcome_rows ""
        forvalues r = 3/`lastrow' {
            if outcome_row[`r'] == 1 {
                local outcome_rows "`outcome_rows' `r'"
            }
        }

        local sht = cond("`sheet'" != "", "`sheet'", "Results")
        export excel c1-c5 using "`xlsx'", sheet("`sht'") sheetreplace

        * Column widths logic
        forvalues i = 1(1)5 {
            gen c`i'_length = length(c`i')
        }
        if "`unitlabel'" != "" {
            replace c4_length = c4_length - length(" (`unitlabel's)") if _n == 2
            replace c5_length = c5_length - length(" per `unitlabel' person-years") if _n == 2
        }
        forvalues i = 1(1)5 {
            qui sum c`i'_length
            local max_c`i' = r(max)
        }

        local col_a_width = max(min(`max_c1' + 2, 50), 10)
        local col_b_width = max(ceil(`max_c2' * 1.2), 12)
        local col_c_width = max(ceil(`max_c3' * 1.15), 10)

        if "`unitlabel'" != "" {
            local col_d_width = max(ceil(`max_c4' * 1.1), 13)
            local col_e_width = max(ceil(`max_c5' * 1.2), 15)
        }
        else {
            local col_d_width = max(ceil(`max_c4' * 1.15), 13)
            local col_e_width = max(ceil(`max_c5' * 1.1), 20)
        }
        drop c*_length outcome_row
    }

    * Formatting with Mata
    qui {
        clear
        mata: b = xl()
        mata: b.load_book("`xlsx'")
        mata: b.set_sheet("`sht'")
        mata: b.set_row_height(1,1,30)
        mata: b.set_row_height(2,2,30)
        mata: b.set_column_width(2,2,`col_b_width')
        mata: b.set_column_width(3,3,`col_c_width')
        mata: b.set_column_width(4,4,`col_d_width')
        mata: b.set_column_width(5,5,`col_e_width')
        mata: b.close_book()

        putexcel set "`xlsx'", sheet("`sht'") modify
        putexcel (A1:E1), merge txtwrap left top bold font(Arial,10)
        putexcel (B2:E2), txtwrap bold hcenter vcenter font(Arial,10) border(top,thin) 
        putexcel (B2:E2), border(bottom,thin)
        putexcel (B2:E`lastrow'), font(Arial,10)
        putexcel (B2:B`lastrow'), left
        putexcel (C2:E`lastrow'), hcenter

        foreach r of local outcome_rows {
            putexcel (B`r':E`r'), border(top,thin) bold left
        }

        putexcel (B2:B`lastrow'), border(left,thin)
        putexcel (B2:B`lastrow'), border(right,thin)
        putexcel (E2:E`lastrow'), border(right,thin)
        putexcel (B`lastrow':E`lastrow'), border(bottom,thin)
        putexcel clear
    }

    di as txt "Exported to `xlsx'"

    return scalar N_files = `n_files'
    return scalar N_rows = `lastrow'
    return local xlsx "`xlsx'"
    return local sheet "`sht'"

end

* --------------------------------------------------------
* HELPER PROGRAMS (Must be OUTSIDE the main program block)
* --------------------------------------------------------

program format_strate_data
    args eventdigits pydigits digits

    if `eventdigits' == 0 {
        gen ev = string(_D, "%11.0fc")
    }
    else {
        gen ev = string(_D, "%11.`eventdigits'fc")
    }

    if `pydigits' == 0 {
        gen py = string(round(_Y,1), "%11.0fc")
    }
    else {
        gen py = string(_Y, "%11.`pydigits'fc")
    }

    * Changed strtrim to trim for compatibility
    gen rt = trim(string(round(_Rate,10^(-`digits')), "%11.`digits'f")) + " (" + ///
             trim(string(round(_Lower,10^(-`digits')), "%11.`digits'f")) + "-" + ///
             trim(string(round(_Upper,10^(-`digits')), "%11.`digits'f")) + ")"
end

program get_categorical_var
    unab allvars : *
    foreach v of local allvars {
        if !inlist("`v'", "_D", "_Y", "_Rate", "_Lower", "_Upper") {
            c_local catvar "`v'"
            exit
        }
    }
end
