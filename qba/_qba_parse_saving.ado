*! _qba_parse_saving Version 1.0.1  2026/06/19
*! Internal helper: parse qba saving(filename[, replace]) specifications
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

capture program drop _qba_parse_saving
program define _qba_parse_saving, rclass
    version 16.0
    local _saved_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax , SAVing(string asis)

        local savefile ""
        local save_replace ""
        local save_opts ""
        local _saving_spec = strtrim(`"`saving'"')
        if substr(`"`_saving_spec'"', 1, 1) == `"""' {
            * Quoted filename: the closing quote ends the filename, so a comma
            * is only an option separator when it follows that closing quote.
            * This keeps commas inside the quoted name (e.g. "my, file.dta") intact.
            local _close = strpos(substr(`"`_saving_spec'"', 2, .), `"""')
            if `_close' > 0 {
                local savefile = substr(`"`_saving_spec'"', 2, `_close' - 1)
                local _rest = strtrim(substr(`"`_saving_spec'"', `_close' + 2, .))
                if substr(`"`_rest'"', 1, 1) == "," {
                    local save_opts = strtrim(substr(`"`_rest'"', 2, .))
                }
            }
            else {
                * Unbalanced quote: treat the whole spec as the filename
                local savefile `"`_saving_spec'"'
            }
        }
        else {
            * Unquoted spec: a comma separates the filename from its options
            local _comma_pos = strrpos(`"`_saving_spec'"', ",")
            if `_comma_pos' > 0 {
                local savefile = strtrim(substr(`"`_saving_spec'"', 1, `_comma_pos' - 1))
                local save_opts = strtrim(substr(`"`_saving_spec'"', `_comma_pos' + 1, .))
            }
            else {
                local savefile `"`_saving_spec'"'
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
