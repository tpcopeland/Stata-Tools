*! comorbidity Version 1.0.0  2026/06/19
*! Charlson and Elixhauser comorbidity indices from wide-format ICD code fields
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Requires: Stata 16.0+; codescan

program define comorbidity, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _restore_needed = 0

    capture noisily {
        syntax varlist [if] [in] , ID(varname) ///
            [ CHARLson(string) ELIXhauser(string) CUSTom(string) ///
              COLLapse MERge DATE(varname) REFDate(varname) ///
              LOOKBack(integer -1) LOOKForward(integer -1) INCLusive ///
              GENerate(string) REPlace NOHIERarchy BAND NOIsily ]

        capture which codescan
        if _rc {
            display as error "comorbidity requires codescan; install it with:"
            display as error `"net install codescan, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/codescan") replace"'
            exit 199
        }

        marksample touse, novarlist
        markout `touse' `id'
        quietly count if `touse'
        if r(N) == 0 {
            display as error "no observations"
            exit 2000
        }

        if "`collapse'" != "" & "`merge'" != "" {
            display as error "collapse and merge cannot both be specified"
            exit 198
        }
        if "`collapse'" == "" & "`merge'" == "" {
            local collapse "collapse"
        }
        local shape "`collapse' `merge'"

        local nidx = (`"`charlson'"' != "") + (`"`elixhauser'"' != "") + (`"`custom'"' != "")
        if `nidx' == 0 {
            display as error "specify one of charlson(), elixhauser(), or custom()"
            exit 198
        }
        if `nidx' > 1 {
            display as error "specify only one of charlson(), elixhauser(), or custom()"
            exit 198
        }

        local index ""
        local scheme ""
        local dict ""
        if `"`charlson'"' != "" {
            local index "charlson"
            local scheme = lower(strtrim(`"`charlson'"'))
            if !inlist("`scheme'", "original", "quan2011") {
                display as error "charlson() scheme must be original or quan2011"
                exit 198
            }
            local dict "charlson"
        }
        else if `"`elixhauser'"' != "" {
            local index "elixhauser"
            local scheme = lower(strtrim(`"`elixhauser'"'))
            if "`scheme'" == "vanwalraven" {
                local dict "elixhauser_vw"
            }
            else if inlist("`scheme'", "ahrq_mortality", "ahrq_readmission") {
                display as error "elixhauser(`scheme') is not yet implemented; AHRQ value sets and weights require source curation"
                exit 198
            }
            else {
                display as error "elixhauser() scheme must be vanwalraven, ahrq_mortality, or ahrq_readmission"
                exit 198
            }
        }
        else {
            local index "custom"
            local scheme "custom"
            local custom = strtrim(`"`custom'"')
            if `"`custom'"' == "" {
                display as error "custom() requires a .csv or .dta codefile"
                exit 198
            }
            foreach ch in ";" "&" "|" ">" "<" "$" {
                if strpos(`"`custom'"', "`ch'") {
                    display as error "custom(): file path contains unsupported shell metacharacter `ch'"
                    exit 198
                }
            }
            if strpos(`"`custom'"', char(34)) | strpos(`"`custom'"', char(39)) | ///
                strpos(`"`custom'"', char(96)) {
                display as error "custom(): file path cannot contain quote characters"
                exit 198
            }
        }

        local prefix `"`generate'"'
        local scorevar = cond(`"`prefix'"' != "", `"`prefix'score"', "`index'")
        capture confirm name `scorevar'
        if _rc {
            display as error "generate() creates invalid score variable name: `scorevar'"
            exit 198
        }
        local protected "`id' `varlist' `date' `refdate'"
        foreach protected_var of local protected {
            if strlower("`scorevar'") == strlower("`protected_var'") {
                display as error "score variable `scorevar' conflicts with structural input `protected_var'"
                exit 198
            }
        }
        if "`replace'" == "" {
            capture confirm new variable `scorevar'
            if _rc {
                display as error "variable `scorevar' already exists; use replace"
                exit 110
            }
        }

        local codefile_arg ""
        local custom_names ""
        local custom_weights ""
        if "`index'" != "custom" {
            tempfile dictfile
            local dictpath `"`dictfile'.dta"'
            _comorbidity_dictionary, index(`dict') target(`"`dictpath'"')
            local codefile_arg `"`dictpath'"'
        }
        else {
            local ext = lower(substr(`"`custom'"', -4, .))
            if "`ext'" != ".csv" & "`ext'" != ".dta" {
                display as error "custom() codefile must be .csv or .dta"
                exit 198
            }

            tempfile custom_snapshot
            local custom_snapshot_path `"`custom_snapshot'.dta"'
            preserve
            local _restore_needed = 1
            quietly {
                if "`ext'" == ".csv" {
                    import delimited `"`custom'"', clear varnames(1) stringcols(_all)
                }
                else {
                    use `"`custom'"', clear
                }
            }

            foreach required in name pattern weight {
                capture confirm variable `required'
                if _rc {
                    local case_match ""
                    foreach candidate of varlist * {
                        if strlower("`candidate'") == "`required'" {
                            local case_match "`candidate'"
                            continue, break
                        }
                    }
                    if "`case_match'" != "" {
                        rename `case_match' `required'
                    }
                }
                capture confirm variable `required'
                if _rc {
                    display as error "custom() codefile must contain a `required' column"
                    exit 198
                }
            }
            foreach required in name pattern {
                capture confirm string variable `required'
                if _rc {
                    display as error "custom() column `required' must be a string variable"
                    exit 198
                }
            }

            quietly count
            local custom_n = r(N)
            if `custom_n' == 0 {
                display as error "custom() codefile is empty"
                exit 198
            }

            capture confirm numeric variable weight
            if _rc {
                capture confirm string variable weight
                if _rc {
                    display as error "custom() column weight must be numeric or numeric text"
                    exit 198
                }
                tempvar parsed_weight
                quietly gen double `parsed_weight' = real(strtrim(weight))
                quietly count if missing(`parsed_weight')
                if r(N) > 0 {
                    display as error "custom() weights must be nonmissing numeric values"
                    exit 198
                }
                quietly drop weight
                quietly rename `parsed_weight' weight
            }
            else {
                quietly count if missing(weight)
                if r(N) > 0 {
                    display as error "custom() weights must be nonmissing numeric values"
                    exit 198
                }
            }

            forvalues i = 1/`custom_n' {
                local custom_name_`i' = name[`i']
                local custom_pattern = pattern[`i']
                if "`custom_name_`i''" == "" | `"`custom_pattern'"' == "" {
                    display as error "custom() row `i' has an empty name or pattern"
                    exit 198
                }
                capture confirm name `custom_name_`i''
                if _rc {
                    display as error "custom() row `i' has invalid condition name `custom_name_`i''"
                    exit 198
                }
                forvalues j = 1/`=`i' - 1' {
                    if strlower("`custom_name_`i''") == strlower("`custom_name_`j''") {
                        display as error "custom() condition names must be unique ignoring case"
                        exit 198
                    }
                }

                local output_name `"`prefix'`custom_name_`i''"'
                capture confirm name `output_name'
                if _rc {
                    display as error "custom() condition `custom_name_`i'' creates invalid variable name `output_name'"
                    exit 198
                }
                if strlower("`output_name'") == strlower("`scorevar'") {
                    display as error "custom() condition `custom_name_`i'' conflicts with score variable `scorevar'"
                    exit 198
                }
                foreach protected_var of local protected {
                    if strlower("`output_name'") == strlower("`protected_var'") {
                        display as error "custom() condition `custom_name_`i'' conflicts with structural input `protected_var'"
                        exit 198
                    }
                }

                local custom_names "`custom_names' `custom_name_`i''"
                local custom_weight = weight[`i']
                local custom_weights "`custom_weights' `custom_weight'"
            }
            quietly save `"`custom_snapshot_path'"', replace
            restore
            local _restore_needed = 0
            local codefile_arg `"`custom_snapshot_path'"'
        }

        local winopts ""
        if "`date'" != "" {
            local winopts "`winopts' date(`date')"
        }
        if "`refdate'" != "" {
            local winopts "`winopts' refdate(`refdate')"
        }
        if `lookback' >= 0 {
            local winopts "`winopts' lookback(`lookback')"
        }
        if `lookforward' >= 0 {
            local winopts "`winopts' lookforward(`lookforward')"
        }
        if "`inclusive'" != "" {
            local winopts "`winopts' inclusive"
        }

        local genopt ""
        if `"`prefix'"' != "" {
            local genopt `"generate(`prefix')"'
        }

        codescan `varlist' if `touse', codefile(`"`codefile_arg'"') id(`id') ///
            `shape' `winopts' `genopt' `replace' `noisily'

        local conditions "`r(conditions)'"
        local N = r(N)
        if `N' == 0 {
            display as error "no patient-level observations after scanning"
            exit 2000
        }
        tempname csummary

        local hier = 0
        if "`nohierarchy'" == "" & "`index'" != "custom" {
            _comorbidity_hierarchy, index(`index') prefix(`"`prefix'"')
            local hier = 1
        }

        local weights ""
        if "`index'" != "custom" {
            _comorbidity_weights, index(`index') scheme(`scheme') ///
                names("`conditions'") prefix(`"`prefix'"')
            local weights "`r(weights)'"
        }
        else {
            foreach nm of local conditions {
                local lookup "`nm'"
                if `"`prefix'"' != "" {
                    local plen = strlen(`"`prefix'"')
                    if substr("`lookup'", 1, `plen') == `"`prefix'"' {
                        local lookup = substr("`lookup'", `plen' + 1, .)
                    }
                }
                local wt ""
                local i = 0
                foreach custom_name of local custom_names {
                    local ++i
                    if "`lookup'" == "`custom_name'" {
                        local wt : word `i' of `custom_weights'
                        continue, break
                    }
                }
                if "`wt'" == "" {
                    display as error "custom() internal weight alignment failed for `lookup'"
                    exit 498
                }
                local weights "`weights' `wt'"
            }
        }

        if "`replace'" != "" {
            capture drop `scorevar'
            local _drop_rc = _rc
            if `_drop_rc' & `_drop_rc' != 111 {
                exit `_drop_rc'
            }
        }
        quietly gen double `scorevar' = 0

        tempname wmat
        local ncond : word count `conditions'
        matrix `wmat' = J(`ncond', 1, .)
        local rownames ""
        local i = 0
        foreach nm of local conditions {
            local ++i
            local wt : word `i' of `weights'
            if "`wt'" == "" {
                display as error "internal weight alignment failed for condition `nm'"
                exit 498
            }
            quietly replace `scorevar' = `scorevar' + (`wt') * sign(`nm')
            matrix `wmat'[`i', 1] = `wt'
            local rownames "`rownames' `nm'"
        }
        matrix rownames `wmat' = `rownames'
        matrix colnames `wmat' = weight
        label variable `scorevar' "`index' (`scheme') comorbidity score"

        tempvar score_order patient_tag
        quietly gen long `score_order' = _n
        quietly egen byte `patient_tag' = tag(`id') if !missing(`scorevar')
        quietly sort `score_order'
        quietly count if `patient_tag' == 1
        if r(N) != `N' {
            display as error "internal patient count mismatch after scoring"
            exit 498
        }

        matrix `csummary' = J(`ncond', 4, .)
        local i = 0
        foreach nm of local conditions {
            local ++i
            quietly count if `patient_tag' == 1 & `nm' == 1
            matrix `csummary'[`i', 1] = r(N)
            matrix `csummary'[`i', 2] = 100 * r(N) / `N'
            matrix `csummary'[`i', 3] = .
            matrix `csummary'[`i', 4] = r(N)
        }
        matrix rownames `csummary' = `rownames'
        matrix colnames `csummary' = count prevalence total_hits positive_units

        quietly summarize `scorevar' if `patient_tag' == 1
        local score_mean = r(mean)
        local score_min = r(min)
        local score_max = r(max)

        display as text _n "comorbidity: " as result "`index'" ///
            as text " (" as result "`scheme'" as text "), N = " ///
            as result %10.0fc `N'
        display as text "  score: mean = " as result %6.2f `score_mean' ///
            as text ", range = [" as result %9.2f `score_min' ///
            as text ", " as result %9.2f `score_max' as text "]"

        local has_bands = 0
        if "`band'" != "" {
            tempvar cmband
            tempname bands
            quietly gen byte `cmband' = 0 if `scorevar' < 0
            quietly replace `cmband' = 1 if `scorevar' == 0
            quietly replace `cmband' = 2 if `scorevar' > 0 & `scorevar' < 3
            quietly replace `cmband' = 3 if `scorevar' >= 3 & `scorevar' < 5
            quietly replace `cmband' = 4 if `scorevar' >= 5 & !missing(`scorevar')
            matrix `bands' = J(5, 2, .)
            forvalues b = 0/4 {
                quietly count if `patient_tag' == 1 & `cmband' == `b'
                matrix `bands'[`b' + 1, 1] = r(N)
                matrix `bands'[`b' + 1, 2] = 100 * r(N) / `N'
            }
            matrix rownames `bands' = score_negative score0 score1_2 score3_4 score5plus
            matrix colnames `bands' = n percent
            display as text "  bands n (<0 / 0 / >0-<3 / 3-<5 / 5+): " ///
                as result %9.0fc el(`bands', 1, 1) " " ///
                as result %9.0fc el(`bands', 2, 1) " " ///
                as result %9.0fc el(`bands', 3, 1) " " ///
                as result %9.0fc el(`bands', 4, 1) " " ///
                as result %9.0fc el(`bands', 5, 1)
            local has_bands = 1
        }

        return local index "`index'"
        return local scheme "`scheme'"
        return local scorevar "`scorevar'"
        return local conditions "`conditions'"
        return scalar N = `N'
        return scalar hierarchy = `hier'
        return matrix weights = `wmat', copy
        return matrix summary = `csummary', copy
        if `has_bands' {
            return matrix bands = `bands', copy
        }
    }
    local rc = _rc
    if `_restore_needed' {
        capture restore
        local _restore_rc = _rc
        if `rc' == 0 & `_restore_rc' {
            local rc = `_restore_rc'
        }
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
