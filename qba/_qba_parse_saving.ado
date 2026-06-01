*! _qba_parse_saving Version 1.0.0  2026/06/02
*! Internal helper: parse qba saving(filename[, replace]) specifications
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

capture program drop _qba_parse_saving
local _drop_rc = _rc
program define _qba_parse_saving, rclass
    version 16.0
    local _saved_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax , SAVing(string asis)

        local savefile ""
        local save_replace ""
        local _saving_spec = strtrim(`"`saving'"')
        local _comma_pos = strrpos(`"`_saving_spec'"', ",")
        if `_comma_pos' > 0 {
            local savefile = strtrim(substr(`"`_saving_spec'"', 1, `_comma_pos' - 1))
            local save_opts = strtrim(substr(`"`_saving_spec'"', `_comma_pos' + 1, .))
        }
        else {
            local savefile `"`_saving_spec'"'
            local save_opts ""
        }
        local _save_len = length(`"`savefile'"')
        if `_save_len' >= 2 {
            if substr(`"`savefile'"', 1, 1) == `"""' & ///
                substr(`"`savefile'"', `_save_len', 1) == `"""' {
                local savefile = substr(`"`savefile'"', 2, `_save_len' - 2)
            }
        }
        if `"`save_opts'"' != "" {
            local save_opts_l = lower(`"`save_opts'"')
            if `"`save_opts_l'"' == "replace" {
                local save_replace "replace"
            }
            else if `"`save_opts_l'"' != "" {
                display as error "saving() supports only the replace suboption"
                exit 198
            }
        }

        return local filename `"`savefile'"'
        return local replace "`save_replace'"

    }
    local rc = _rc
    set varabbrev `_saved_varabbrev'
    if `rc' exit `rc'
end
