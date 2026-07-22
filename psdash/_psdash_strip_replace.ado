*! _psdash_strip_replace Version 1.5.0  2026/07/22
*! Strip a redundant trailing ", replace" from a name()/saving() value
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Internal helper

program define _psdash_strip_replace, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , OPTion(string) [ VALue(string) ]

        * psdash always appends ", replace" to name()/saving() internally. A user
        * who copies twoway-style name(g, replace) / saving(f.png, replace) would
        * otherwise hit a cryptic r(198). Strip a redundant trailing ", replace"
        * (case-insensitive) so the call just works, with a friendly note.
        local _re "^(.*[^ ]) *, *[Rr][Ee][Pp][Ll][Aa][Cc][Ee] *$"
        if ustrregexm(`"`value'"', "`_re'") {
            local value `"`=ustrregexs(1)'"'
            noisily display as text ///
                "note: `option'() adds replace automatically; ignoring redundant replace suboption"
            return scalar stripped = 1
        }
        else {
            return scalar stripped = 0
        }
        return local value `"`value'"'
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
