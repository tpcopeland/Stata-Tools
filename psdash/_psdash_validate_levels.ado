*! _psdash_validate_levels Version 1.4.0  2026/07/01
*! Validate multi-group treatment levels for psdash result-name contracts
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

program define _psdash_validate_levels
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax , LEVELS(string asis)

        foreach _lv of local levels {
            capture confirm integer number `_lv'
            local _int_rc = _rc
            capture confirm name ps_`_lv'
            local _name_rc = _rc
            if `_int_rc' | `_name_rc' | real("`_lv'") < 0 {
                display as error "multi-group treatment levels must be nonnegative integers"
                display as error "  unsupported level: `_lv'"
                display as error "  recode treatment levels before using psdash multi-group diagnostics"
                exit 198
            }
        }
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
