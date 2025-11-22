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
    cap frame drop results
    cap frame drop worker
    
    frame create results
    frame results {
        clear
        quietly gen str244 c1 = ""
        quietly gen str244 c2 = ""
        quietly gen str244 c3 = ""
        quietly gen str244 c4 = ""
        quietly gen str244 c5 = ""
        
        * Tracking variable for formatting (1=Title, 2=Label, 3=Header, 4=Data)
        quietly gen byte row_type = . 
        
        quietly set obs 1
        quietly replace c1 = "`title'" in 1
        quietly replace row_type = 1 in 1
    }

    * -------------------------------------------------------
    * 3. PROCESS FILES LOOP
    * -------------------------------------------------------
    forvalues f = 1/`n_files' {
        local file : word `f' of `using'
        
        frame create worker
        frame worker {
            qui {
                quietly use "`file'.dta", clear
                
                cap confirm var _Rate _Lower _Upper _D _Y
                if _rc {
                    noisily di as err "Error: `file'.dta is missing required strate columns."
                    exit 111
                }

                get_categorical_var
                local catvar_name "`catvar'"
                local varlabel : variable label `catvar_name'
                if "`varlabel'" == "" local varlabel "`catvar_name'"

                cap confirm string var `catvar'
                if _rc {
                    decode `catvar', gen(catvar_str)
                }
                else {
                    gen catvar_str = `catvar'
                }
                
                format_strate_data `eventdigits' `pydigits' `digits'
                
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
        frame drop worker

        * -- WRITE TO RESULTS FRAME --
        frame results {
            qui {
                local current_n = _N
                
                * A. Add File Label
                local new = `current_n' + 1
                quietly set obs `new'
                quietly replace c2 = "`lab`f''" in `new'
                quietly replace row_type = 2 in `new'
                
                * B. Add Column Headers
                local header_row = `new' + 1
                quietly set obs `header_row'
                
                local col1_header "Outcomes by `varlabel'"
                quietly replace c2 = "`col1_header'" in `header_row'
                quietly replace c3 = "Events" in `header_row'
                
                if "`unitlabel'" != "" {
                    quietly replace c4 = "Person-years" + char(10) + "(`unitlabel's)" in `header_row'
                    quietly replace c5 = "Rate per `unitlabel'" + char(10) + "person-years (95% CI)" in `header_row'
                }
                else {
                    quietly replace c4 = "Person-years" in `header_row'
                    quietly replace c5 = "Rate (95% CI)" in `header_row'
                }
                quietly replace row_type = 3 in `header_row'
                
                * C. Add Data Rows
                local current_n = _N
                local new_total = `current_n' + `data_count'
                quietly set obs `new_total'
                
                forvalues i = 1/`data_count' {
                    local row = `current_n' + `i'
                    quietly replace c2 = "`v1_`i''" in `row'
                    quietly replace c3 = "`v2_`i''" in `row'
                    quietly replace c4 = "`v3_`i''" in `row'
                    quietly replace c5 = "`v4_`i''" in `row'
                    quietly replace row_type = 4 in `row'
                }
                
                local spacer = `new_total' + 1
                quietly set obs `spacer'
                quietly replace row_type = 0 in `spacer'
            }
        }
    }

    * -------------------------------------------------------
    * 4. EXPORT AND FORMAT
    * -------------------------------------------------------
    frame results {
        qui {
            local lastrow = _N
            local sht = cond("`sheet'" != "", "`sheet'", "Results")
            
            forvalues i = 1(1)5 {
                quietly gen c`i'_length = length(c`i')
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

            export excel c1-c5 using "`xlsx'", sheet("`sht'") sheetreplace

            mata: b = xl()
            mata: b.load_book("`xlsx'")
            mata: b.set_sheet("`sht'")
            mata: b.set_row_height(1, `lastrow', 15)
            mata: b.set_column_width(2,2,`col_b_width')
            mata: b.set_column_width(3,3,`col_c_width')
            mata: b.set_column_width(4,4,`col_d_width')
            mata: b.set_column_width(5,5,`col_e_width')
            mata: b.close_book()

            putexcel set "`xlsx'", sheet("`sht'") modify
            
            putexcel (A1:E1), merge txtwrap left top bold font(Arial,10) 
            
            forvalues r = 1/`lastrow' {
                local rt = row_type[`r']
                
                * Type 2: File Label
                if `rt' == 2 {
                    putexcel (B`r':E`r'), bold left font(Arial,10) border(top, thin)
                    putexcel (B`r':E`r'), border(bottom, thin)
                }
                
                * Type 3: Column Headers
                if `rt' == 3 {
                    putexcel (B`r':E`r'), bold hcenter vcenter txtwrap font(Arial,10) border(bottom, thin)
                    mata: b = xl()
                    mata: b.load_book("`xlsx'")
                    mata: b.set_sheet("`sht'")
                    mata: b.set_row_height(`r',`r',30)
                    mata: b.close_book()
                }
                
                * Type 4: Data
                if `rt' == 4 {
                    putexcel (B`r'), left font(Arial,10) border(left, thin) border(right, thin)
                    putexcel (C`r':E`r'), hcenter font(Arial,10) border(right, thin)
                }
            }
            putexcel clear
        }
        
        di as txt "Exported to `xlsx' with `lastrow' rows."
        
        return scalar N_files = `n_files'
        return scalar N_rows = `lastrow'
        return local xlsx "`xlsx'"
        return local sheet "`sht'"
    }
    frame drop results
end

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
