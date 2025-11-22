*! stratetab | Version 1.0.0
*! Author: Tim Copeland
*! Revised: November 17, 2025

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

    * -------------------------------------------------------
    * 1. PREPARE LABELS
    * -------------------------------------------------------
    local n_files : word count `using'
    if "`labels'" != "" {
        * Normalize whitespace and tokenize by backslash
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

    * -------------------------------------------------------
    * 2. SETUP RESULTS FRAME
    * -------------------------------------------------------
    * Clean up any existing frames from failed runs
    cap frame drop results
    cap frame drop worker
    
    frame create results
    frame results {
        clear
        gen str244 c1 = ""
        gen str244 c2 = ""
        gen str244 c3 = ""
        gen str244 c4 = ""
        gen str244 c5 = ""
        set obs 1
        replace c1 = "`title'" in 1
    }

    * -------------------------------------------------------
    * 3. DETERMINE HEADER (Using first file)
    * -------------------------------------------------------
    frame create worker
    local first_file : word 1 of `using'
    frame worker {
        qui use "`first_file'.dta", clear
        get_categorical_var
        local catvar_name "`catvar'"
        
        * Get variable label
        local varlabel : variable label `catvar_name'
        if "`varlabel'" == "" local varlabel "`catvar_name'"
    }
    * Check if all files have same categorical structure (optional but good practice)
    * (Skipping complex check for speed, assuming user consistency)

    frame results {
        local col1_header "Outcomes by `varlabel'"
        
        * Add Column Headers
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
    }

    * -------------------------------------------------------
    * 4. PROCESS FILES LOOP
    * -------------------------------------------------------
    forvalues f = 1/`n_files' {
        local file : word `f' of `using'
        
        * -- LOAD AND FORMAT IN WORKER FRAME --
        frame worker {
            qui {
                use "`file'.dta", clear
                
                * Check for required variables
                cap confirm var _Rate _Lower _Upper _D _Y
                if _rc {
                    noisily di as err "Error: `file'.dta is missing required strate columns."
                    exit 111
                }

                get_categorical_var
                
                * Ensure string
                cap confirm string var `catvar'
                if _rc {
                    decode `catvar', gen(catvar_str)
                }
                else {
                    gen catvar_str = `catvar'
                }
                
                * Format numbers
                format_strate_data `eventdigits' `pydigits' `digits'
                
                * Extract data to locals to pass across frames
                local data_count = _N
                if `data_count' == 0 {
                    noisily di as text "Warning: File `file'.dta has 0 rows."
                }
                
                forvalues i = 1/`data_count' {
                    local v1_`i' = "    " + catvar_str[`i']
                    local v2_`i' = ev[`i']
                    local v3_`i' = py[`i']
                    local v4_`i' = rt[`i']
                }
            }
        }

        * -- WRITE TO RESULTS FRAME --
        frame results {
            qui {
                * 1. Add Outcome Header
                local current_n = _N
                local new = `current_n' + 1
                set obs `new'
                replace c2 = "`lab`f''" in `new'
                
                * 2. Add Data Rows
                local current_n = _N
                local new_total = `current_n' + `data_count'
                set obs `new_total'
                
                forvalues i = 1/`data_count' {
                    local row = `current_n' + `i'
                    replace c2 = "`v1_`i''" in `row'
                    replace c3 = "`v2_`i''" in `row'
                    replace c4 = "`v3_`i''" in `row'
                    replace c5 = "`v4_`i''" in `row'
                }
            }
        }
    }

    * Cleanup worker frame
    frame drop worker

    * -------------------------------------------------------
    * 5. EXPORT AND FORMAT
    * -------------------------------------------------------
    frame results {
        qui {
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

            * Auto-fit logic
            forvalues i = 1(1)5 {
                gen c`i'_length = length(c`i')
            }
            if "`unitlabel'" != "" {
                replace c4_length = c4_length - length(" (`unitlabel's)") if _n == 2
                replace c5_length = c5_length - length(" per `unitlabel' person-years") if _n == 2 
            }
            forvalues i = 1(1)5 {
                sum c`i'_length
                local max_c`i' = r(max)
            }
            
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
        }
        
        * Apply Mata formatting
        qui {
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
            putexcel (B2:E2), txtwrap bold hcenter vcenter font(Arial,10) border(top,thin) border(bottom,thin)
            putexcel (B2:E`lastrow'), font(Arial,10)
            putexcel (B2:B`lastrow'), left
            putexcel (C2:E`lastrow'), hcenter

            foreach r of local outcome_rows {
                putexcel (B`r':E`r'), border(top,thin) bold left
            }

            putexcel (B2:B`lastrow'), border(left,thin) border(right,thin)
            putexcel (E2:E`lastrow'), border(right,thin)
            putexcel (B`lastrow':E`lastrow'), border(bottom,thin)
            putexcel clear
        }
        
        di as txt "Exported to `xlsx' with `lastrow' rows."
        
        return scalar N_files = `n_files'
        return scalar N_rows = `lastrow'
        return local xlsx "`xlsx'"
        return local sheet "`sht'"
    }
    
    * Close main frame
    frame drop results
end

* --------------------------------------------------------
* HELPER PROGRAMS
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
