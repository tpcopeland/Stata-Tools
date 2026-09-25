*! _tabtools_match_rows Version 2.1.9  2026/09/25
*! Match raw coefficient identities and factor components
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

program define _tabtools_match_rows, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varname(string), GENerate(name) TERMS(string)
        confirm new variable `generate'
        quietly generate byte `generate' = 0
        mata: _tabtools_match_rows_mata(st_local("varlist"), ///
            st_local("generate"), st_local("terms"))
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture mata: mata drop _tabtools_match_rows_mata()
capture mata: mata drop _tabtools_match_normalize()

mata:
mata set matastrict on

// Normalize only factor operators, leaving identifiers and numeric levels
// intact. For example, 2b.arm#c.age becomes 2.arm#age, never arm#age.
string scalar _tabtools_match_normalize(string scalar term)
{
    string rowvector parts
    string scalar part, prefix, suffix
    real scalar j, dot
    parts = tokens(subinstr(term, "#", " "))
    for (j = 1; j <= cols(parts); j++) {
        part = parts[j]
        dot = strpos(part, ".")
        if (dot > 0) {
            prefix = substr(part, 1, dot - 1)
            suffix = substr(part, dot + 1, .)
            if (regexm(prefix, "^(i|c|o|b|bn|ib[0-9]+|ibn)$")) part = suffix
            else if (regexm(prefix, "^([0-9]+)(b|bn|o)$")) {
                part = regexs(1) + "." + suffix
            }
        }
        parts[j] = part
    }
    return(invtokens(parts, "#"))
}

void _tabtools_match_rows_mata(string scalar rawvar,
    string scalar matchvar, string scalar spec)
{
    string colvector raw
    real colvector matched
    string rowvector terms, parts
    string scalar term, key, component
    real scalar i, j, k, dot
    raw = st_sdata(., rawvar)
    st_view(matched, ., matchvar)
    terms = tokens(spec)
    for (j = 1; j <= cols(terms); j++) {
        terms[j] = _tabtools_match_normalize(terms[j])
    }
    for (i = 1; i <= rows(raw); i++) {
        if (raw[i] == "") continue
        key = _tabtools_match_normalize(strtrim(raw[i]))
        parts = tokens(subinstr(key, "#", " "))
        for (j = 1; j <= cols(terms); j++) {
            term = terms[j]
            if (key == term) matched[i] = 1
            if (strpos(term, "#")) continue
            for (k = 1; k <= cols(parts); k++) {
                component = parts[k]
                if (component == term) matched[i] = 1
                // A bare variable selects its levels and interactions. An
                // explicit level (2.arm) cannot select another level (20.arm).
                dot = strpos(component, ".")
                if (dot > 0 & !strpos(term, ".")) {
                    if (regexm(substr(component, 1, dot - 1), "^[0-9]+$") &
                        substr(component, dot + 1, .) == term) matched[i] = 1
                }
            }
        }
    }
}
end
