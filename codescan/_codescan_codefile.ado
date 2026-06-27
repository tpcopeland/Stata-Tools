*! _codescan_codefile Version 2.0.2  2026/06/26
*! Private codefile helpers for codescan
*! Author: Timothy P Copeland

capture program drop _codescan_parse_codefile
program define _codescan_parse_codefile, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _did_preserve = 0
    capture noisily {

    syntax , CODEFile(string)

    local resolved_codefile `"`codefile'"'
    local ext = lower(substr(`"`resolved_codefile'"', -4, .))
    if "`ext'" != ".csv" & "`ext'" != ".dta" {
        display as error "codefile() must be a .csv or .dta file"
        exit 198
    }
    capture confirm file `"`resolved_codefile'"'
    if _rc {
        display as error `"codefile(): file not found: `resolved_codefile'"'
        exit 601
    }

    preserve
    local _did_preserve = 1
    quietly {
        if "`ext'" == ".csv" {
            import delimited `"`resolved_codefile'"', clear stringcols(_all) varnames(1)
        }
        else {
            use `"`resolved_codefile'"', clear
        }
    }

    * R2: Case-tolerant column name matching
    foreach _cfcol in name pattern label exclusion {
        capture confirm variable `_cfcol'
        if _rc {
            * Try case-insensitive match
            foreach _v of varlist * {
                if lower("`_v'") == "`_cfcol'" & "`_v'" != "`_cfcol'" {
                    rename `_v' `_cfcol'
                    continue, break
                }
            }
        }
    }

    * Validate required columns
    capture confirm string variable name
    if _rc {
        display as error "codefile(): file must contain a string variable {bf:name}"
        exit 198
    }
    capture confirm string variable pattern
    if _rc {
        display as error "codefile(): file must contain a string variable {bf:pattern}"
        exit 198
    }

    * Optional columns
    capture confirm string variable label
    local _cf_has_label = (_rc == 0)
    capture confirm string variable exclusion
    local _cf_has_excl = (_rc == 0)

    quietly count
    local n_conditions = r(N)
    if `n_conditions' == 0 {
        display as error "codefile(): file is empty"
        exit 198
    }

    local all_names ""
    local n_labels = 0
    forvalues i = 1/`n_conditions' {
        local def_name_`i' = name[`i']
        local def_pattern_`i' = pattern[`i']
        local def_excl_`i' ""
        local all_names "`all_names' `def_name_`i''"

        if `_cf_has_label' {
            local _lbl = label[`i']
            if `"`_lbl'"' != "" {
                local ++n_labels
                local lab_name_`n_labels' "`def_name_`i''"
                local lab_label_`n_labels' `"`_lbl'"'
            }
        }
        if `_cf_has_excl' {
            local _excl = exclusion[`i']
            if `"`_excl'"' != "" {
                local def_excl_`i' `"`_excl'"'
            }
        }
    }
    local all_names = trim("`all_names'")

    * R3: Codefile schema validation — batch all errors
    local _cf_errors ""
    local _cf_nerr = 0
    forvalues i = 1/`n_conditions' {
        if "`def_name_`i''" == "" {
            local ++_cf_nerr
            local _cf_errors `"`_cf_errors'"row `i': empty name" "'
        }
        if `"`def_pattern_`i''"' == "" {
            local ++_cf_nerr
            local _cf_errors `"`_cf_errors'"row `i': empty pattern" "'
        }
        if "`def_name_`i''" != "" {
            capture confirm name `def_name_`i''
            if _rc {
                local ++_cf_nerr
                local _bad_nm "`def_name_`i''"
                local _cf_errors `"`_cf_errors'"row `i': [`_bad_nm'] is not a valid Stata name" "'
            }
        }
        forvalues j = 1/`=`i'-1' {
            if "`def_name_`i''" == "`def_name_`j''" & "`def_name_`i''" != "" {
                local ++_cf_nerr
                local _dup_nm "`def_name_`i''"
                local _cf_errors `"`_cf_errors'"row `i': duplicate name [`_dup_nm'] (same as row `j')" "'
                continue, break
            }
        }
    }
    if `_cf_nerr' > 0 {
        display as error "codefile(): `_cf_nerr' validation error(s):"
        local _cf_remain `"`_cf_errors'"'
        forvalues _ei = 1/`_cf_nerr' {
            gettoken _emsg _cf_remain : _cf_remain
            display as error "  `_emsg'"
        }
        exit 198
    }

    }
    local rc = _rc
    if `_did_preserve' capture restore
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return scalar n_conditions = `n_conditions'
    return scalar n_labels = `n_labels'
    return local all_names "`all_names'"
    return local resolved_codefile `"`resolved_codefile'"'
    forvalues i = 1/`n_conditions' {
        return local def_name_`i' "`def_name_`i''"
        return local def_pattern_`i' `"`def_pattern_`i''"'
        return local def_excl_`i' `"`def_excl_`i''"'
    }
    if `n_labels' > 0 {
        forvalues i = 1/`n_labels' {
            return local lab_name_`i' "`lab_name_`i''"
            return local lab_label_`i' `"`lab_label_`i''"'
        }
    }
end
