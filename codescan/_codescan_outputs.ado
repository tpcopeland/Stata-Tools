*! _codescan_outputs Version 2.0.1  2026/06/25
*! Private output-name helpers for codescan
*! Author: Timothy P Copeland

capture program drop _codescan_plan_outputs
program define _codescan_plan_outputs, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , CONDITIONS(string asis) SCANVars(string asis) ///
        [PROTected(string asis) COLLapse MERge EARLIESTdate LATESTdate ///
         COUNTdate COUNTRows REPlace ///
         UNMatched(string) MATCHed_code(string)]

    local _conditions `"`conditions'"'
    if strlen(`"`_conditions'"') >= 2 {
        if substr(`"`_conditions'"', 1, 1) == char(34) & ///
            substr(`"`_conditions'"', strlen(`"`_conditions'"'), 1) == char(34) {
            local _conditions = substr(`"`_conditions'"', 2, strlen(`"`_conditions'"') - 2)
        }
    }
    local _scanvars `"`scanvars'"'
    if strlen(`"`_scanvars'"') >= 2 {
        if substr(`"`_scanvars'"', 1, 1) == char(34) & ///
            substr(`"`_scanvars'"', strlen(`"`_scanvars'"'), 1) == char(34) {
            local _scanvars = substr(`"`_scanvars'"', 2, strlen(`"`_scanvars'"') - 2)
        }
    }
    local _protected `"`protected'"'
    if strlen(`"`_protected'"') >= 2 {
        if substr(`"`_protected'"', 1, 1) == char(34) & ///
            substr(`"`_protected'"', strlen(`"`_protected'"'), 1) == char(34) {
            local _protected = substr(`"`_protected'"', 2, strlen(`"`_protected'"') - 2)
        }
    }

    local _n_outputs = 0
    local _outputs ""
    foreach _cond of local _conditions {
        local ++_n_outputs
        local _output_`_n_outputs' "`_cond'"
        local _outputs "`_outputs' `_output_`_n_outputs''"
        if "`collapse'" != "" | "`merge'" != "" {
            if "`earliestdate'" != "" {
                local ++_n_outputs
                local _output_`_n_outputs' "`_cond'_first"
                local _outputs "`_outputs' `_output_`_n_outputs''"
            }
            if "`latestdate'" != "" {
                local ++_n_outputs
                local _output_`_n_outputs' "`_cond'_last"
                local _outputs "`_outputs' `_output_`_n_outputs''"
            }
            if "`countdate'" != "" {
                local ++_n_outputs
                local _output_`_n_outputs' "`_cond'_count"
                local _outputs "`_outputs' `_output_`_n_outputs''"
            }
            if "`countrows'" != "" {
                local ++_n_outputs
                local _output_`_n_outputs' "`_cond'_nrows"
                local _outputs "`_outputs' `_output_`_n_outputs''"
            }
        }
    }
    if "`unmatched'" != "" {
        local ++_n_outputs
        local _output_`_n_outputs' "`unmatched'"
        local _outputs "`_outputs' `_output_`_n_outputs''"
    }
    if "`matched_code'" != "" {
        local ++_n_outputs
        local _output_`_n_outputs' "`matched_code'"
        local _outputs "`_outputs' `_output_`_n_outputs''"
    }
    local _outputs = trim("`_outputs'")

    forvalues i = 1/`_n_outputs' {
        local _out_nm "`_output_`i''"
        foreach v of local _scanvars {
            if "`_out_nm'" == "`v'" {
                display as error "output name `_out_nm' conflicts with a varlist variable"
                exit 198
            }
        }
        foreach v of local _protected {
            if "`v'" != "" & "`_out_nm'" == "`v'" {
                display as error "output name `_out_nm' conflicts with id(), date(), or refdate() variable"
                exit 198
            }
        }
        forvalues j = 1/`=`i'-1' {
            if "`_out_nm'" == "`_output_`j''" {
                display as error "output name `_out_nm' is specified more than once; choose distinct names"
                exit 198
            }
        }
        if "`replace'" == "" {
            capture confirm new variable `_out_nm'
            if _rc {
                display as error "variable `_out_nm' already exists; use replace option"
                exit 110
            }
        }
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return scalar n_outputs = `_n_outputs'
    return local outputs "`_outputs'"
    forvalues i = 1/`_n_outputs' {
        return local output_`i' "`_output_`i''"
    }
end

capture program drop _codescan_cleanup_outputs
program define _codescan_cleanup_outputs
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , OUTputs(string asis) SCANVars(string asis) [PROTected(string asis)]

    local _outputs `"`outputs'"'
    if strlen(`"`_outputs'"') >= 2 {
        if substr(`"`_outputs'"', 1, 1) == char(34) & ///
            substr(`"`_outputs'"', strlen(`"`_outputs'"'), 1) == char(34) {
            local _outputs = substr(`"`_outputs'"', 2, strlen(`"`_outputs'"') - 2)
        }
    }
    local _scanvars `"`scanvars'"'
    if strlen(`"`_scanvars'"') >= 2 {
        if substr(`"`_scanvars'"', 1, 1) == char(34) & ///
            substr(`"`_scanvars'"', strlen(`"`_scanvars'"'), 1) == char(34) {
            local _scanvars = substr(`"`_scanvars'"', 2, strlen(`"`_scanvars'"') - 2)
        }
    }
    local _protected `"`protected'"'
    if strlen(`"`_protected'"') >= 2 {
        if substr(`"`_protected'"', 1, 1) == char(34) & ///
            substr(`"`_protected'"', strlen(`"`_protected'"'), 1) == char(34) {
            local _protected = substr(`"`_protected'"', 2, strlen(`"`_protected'"') - 2)
        }
    }

    foreach _drop_nm of local _outputs {
        local _drop_protected = 0
        foreach v of local _scanvars {
            if "`_drop_nm'" == "`v'" local _drop_protected = 1
        }
        foreach v of local _protected {
            if "`v'" != "" & "`_drop_nm'" == "`v'" {
                local _drop_protected = 1
            }
        }
        if !`_drop_protected' capture drop `_drop_nm'
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
