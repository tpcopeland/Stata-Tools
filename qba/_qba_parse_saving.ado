*! _qba_parse_saving Version 1.2.1  2026/11/17
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
        * Never hold a lone quote character in a macro: expanding it inside
        * a compound-quoted string would unbalance the quotes.
        if substr(`"`_saving_spec'"', 1, 1) == char(34) | ///
            substr(`"`_saving_spec'"', 1, 2) == char(96) + char(34) {
            * Quoted filename, simple ("...") or compound (`"..."'): the
            * closing quote ends the filename, so a comma inside the quotes
            * (e.g. "my, file.dta") is part of the name and only a comma
            * after the closing quote separates options. gettoken honours
            * both quote forms and strips one wrapper per call.
            local _spec : copy local _saving_spec
            local _done = 0
            forvalues _pass = 1/3 {
                if `_done' continue
                gettoken _tok _rest : _spec, parse(",") qed(_was_quoted)
                local _rest = strtrim(`"`_rest'"')
                local _tok_quoted = (substr(`"`_tok'"', 1, 1) == char(34) | ///
                    substr(`"`_tok'"', 1, 2) == char(96) + char(34))
                if `_was_quoted' & `_tok_quoted' & `"`_rest'"' == "" {
                    * One wrapper enclosed filename AND options, as in
                    * `"file.dta", replace"': reparse its contents.
                    local _spec : copy local _tok
                    continue
                }
                if `_tok_quoted' {
                    * A quoted name inside a compound wrapper: `""a b.dta""'
                    gettoken _tok : _tok
                }
                local savefile : copy local _tok
                if substr(`"`_rest'"', 1, 1) == "," {
                    local save_opts = strtrim(substr(`"`_rest'"', 2, .))
                }
                else if `"`_rest'"' != "" {
                    display as error "saving() specification has text after the filename that is not a comma-separated option"
                    exit 198
                }
                local _done = 1
            }
            if !`_done' {
                display as error "saving() filename is nested in too many quote wrappers"
                exit 198
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
        if `"`savefile'"' == "" {
            display as error "saving() requires a filename"
            exit 198
        }
        * A double quote left inside the name means the quotes were not
        * balanced around the filename alone (e.g. `"file.dta", replace"').
        if strpos(`"`savefile'"', char(34)) {
            display as error `"saving() filename contains a double-quote character; quote the filename alone, as in saving("my file.dta", replace)"'
            exit 198
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
