*! _psdash_term_label Version 1.9.0  2026/10/29
*! Readable Love-plot labels for covariate design terms
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Internal helper

* Takes the design terms _psdash_expand_fv returns (age, c.age, 2.race,
* c.age#c.bmi, ...) and returns r(label_1) ... r(label_k), one per term:
*   - a plain or c.-prefixed variable  -> its variable label, else its name
*   - a factor level  #.var            -> "<variable label or name>: <value
*                                          label of #, else #>"
*   - anything else (interactions)     -> the term unchanged
* Labels are shortened to 40 characters with "...", and a label shared by
* two terms gets the term name appended. With varnames every label is the
* term itself. Variable and value labels are
* user data, so they pass through _psdash_label_text and come back inert
* (no braces, backquotes, $ or double quotes) and safe in graph text.

program define _psdash_term_label, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax anything(name=terms) [, VARNames]

        local k = 0
        foreach t of local terms {
            local ++k
            local text "`t'"
            if "`varnames'" == "" {
                local vname ""
                local level ""
                if regexm("`t'", "^(c\.)?([A-Za-z_][A-Za-z0-9_]*)$") {
                    local vname = regexs(2)
                }
                else if regexm("`t'", "^([0-9]+)[a-z]*\.([A-Za-z_][A-Za-z0-9_]*)$") {
                    local level = regexs(1)
                    local vname = regexs(2)
                }
                if "`vname'" != "" {
                    capture confirm variable `vname', exact
                    if !_rc {
                        * Long labels are shortened so a row label cannot
                        * squeeze the plot region or push the title off
                        * the canvas: 40 characters in all.
                        local vmax = cond("`level'" == "", 40, 24)
                        _psdash_label_text, variable(`vname') varlabel ///
                            default(`vname') maxlen(`vmax')
                        local text `"`r(text)'"'
                        if "`level'" != "" {
                            _psdash_label_text, variable(`vname') ///
                                level(`level') maxlen(14)
                            local text `"`text': `r(text)'"'
                        }
                    }
                }
            }
            local lab_`k' `"`text'"'
            local term_`k' "`t'"
        }
        * Two terms with the same label (duplicate or truncated variable
        * labels) would give identical rows; name the term in each of them.
        forvalues i = 1/`k' {
            local dup = 0
            forvalues j = 1/`k' {
                if `i' != `j' & `"`lab_`i''"' == `"`lab_`j''"' local dup = 1
            }
            local out `"`lab_`i''"'
            if `dup' & `"`lab_`i''"' != "`term_`i''" {
                local out `"`out' (`term_`i'')"'
            }
            return local label_`i' `"`out'"'
        }
        return scalar k = `k'
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
