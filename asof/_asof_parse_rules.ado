*! _asof_parse_rules Version 0.1.0  2026/08/12
*! Validate and normalize asof selection rules
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _asof_parse_rules, rclass
    version 16.0

    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , DIRection(string) SELect(string) [TIES(string)]

        local direction = lower(strtrim("`direction'"))
        local select = lower(strtrim("`select'"))
        local ties = lower(strtrim("`ties'"))

        if !inlist("`direction'", "before", "onorbefore", "after", ///
            "onorafter", "both") {
            display as error "direction() must be before, onorbefore, after, onorafter, or both"
            exit 198
        }

        if !inlist("`select'", "nearest", "first", "last") {
            display as error "select() must be nearest, first, or last"
            exit 198
        }

        local ties_given = ("`ties'" != "")
        if !`ties_given' {
            if "`select'" == "nearest" local ties "before"
            else local ties "first"
        }

        if !inlist("`ties'", "before", "after", "first", "last", "error") {
            display as error "ties() must be before, after, first, last, or error"
            exit 198
        }

        if "`select'" != "nearest" & inlist("`ties'", "before", "after") {
            display as error "ties(before) and ties(after) are not allowed with select(`select')"
            exit 198
        }

        return local direction "`direction'"
        return local select "`select'"
        return local ties "`ties'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
