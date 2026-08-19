*! _gcomp_parse_structural Version 1.6.0  2026/08/19
*! Parse deterministic structural rules for gcomp modelled variables
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

capture program drop _gcomp_parse_structural
program define _gcomp_parse_structural, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, VARS(varlist) [RULES(string)]

        local _gc_nvars : word count `vars'
        forvalues _gc_i = 1/`_gc_nvars' {
            return local condition`_gc_i' ""
            return local value`_gc_i' ""
        }
        if `"`rules'"' == "" {
            return scalar n_rules = 0
        }
        else {
            if !strpos(`"`rules'"', ":") {
                noisily display as error "structural() rules must be keyed, for example structural(y: m == 0 => 0)"
                exit 198
            }
            _gcomp_detangle `"`rules'"' structural `"`vars'"'
            local _gc_nrules = 0
            forvalues _gc_i = 1/`_gc_nvars' {
                local _gc_clause `"`r(value`_gc_i')'"'
                if `"`_gc_clause'"' == "" continue

                local _gc_arrow = strpos(`"`_gc_clause'"', "=>")
                if `_gc_arrow' == 0 | strpos(substr(`"`_gc_clause'"', `_gc_arrow' + 2, .), "=>") {
                    local _gc_target : word `_gc_i' of `vars'
                    noisily display as error "structural(): rule for `_gc_target' must contain exactly one =>"
                    exit 198
                }
                local _gc_condition = strtrim(substr(`"`_gc_clause'"', 1, `_gc_arrow' - 1))
                local _gc_value = strtrim(substr(`"`_gc_clause'"', `_gc_arrow' + 2, .))
                if `"`_gc_condition'"' == "" | `"`_gc_value'"' == "" {
                    local _gc_target : word `_gc_i' of `vars'
                    noisily display as error "structural(): rule for `_gc_target' requires a condition and a forced value"
                    exit 198
                }
                capture confirm number `_gc_value'
                if _rc {
                    local _gc_target : word `_gc_i' of `vars'
                    noisily display as error "structural(): forced value for `_gc_target' must be one nonmissing number"
                    exit 198
                }
                if missing(`_gc_value') {
                    local _gc_target : word `_gc_i' of `vars'
                    noisily display as error "structural(): forced value for `_gc_target' must be one nonmissing number"
                    exit 198
                }
                local ++_gc_nrules
                return local condition`_gc_i' `"`_gc_condition'"'
                return local value`_gc_i' `"`_gc_value'"'
            }
            return scalar n_rules = `_gc_nrules'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
