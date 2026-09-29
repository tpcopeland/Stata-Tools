*! _psdash_label_text Version 1.7.3  2026/09/29
*! Inert, verbatim display text for a treatment level's value label
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Internal helper

* Returns r(text): the value label of level() on variable(), or default()
* (else the level itself) when the level is unlabelled. A value label is
* user data and must print exactly as written. Console display and graph
* text both interpret SMCL, and Stata's graph commands re-expand option text,
* so braces, backquotes, $ and double quotes are rewritten as SMCL character
* codes. The result contains none of those characters and is therefore safe
* in any macro expansion, compound-quoted option, or display/graph string.

program define _psdash_label_text, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , VARiable(varname) LEVel(string) [DEFault(string asis)]

        local text : label (`variable') `level', strict
        if `"`macval(text)'"' == "" local text `"`macval(default)'"'
        if `"`macval(text)'"' == "" local text "`level'"

        * Mata reads and writes the macro without expanding it. Placeholders
        * keep the second pass from rewriting braces the first pass added.
        mata: st_local("text", ///
            subinstr(subinstr(subinstr(subinstr(subinstr( ///
            subinstr(subinstr(subinstr(subinstr(subinstr( ///
            st_local("text"), ///
            char(123), char(1)), char(125), char(2)), ///
            char(96), char(3)), char(36), char(4)), ///
            char(34), char(5)), ///
            char(1), "{c -(}"), char(2), "{c )-}"), ///
            char(3), "{c 96}"), char(4), "{c 36}"), ///
            char(5), "{c 34}"))

        return local text `"`text'"'
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
