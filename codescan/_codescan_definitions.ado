*! _codescan_definitions Version 1.1.1  2026/05/28
*! Private definition helpers for codescan
*! Author: Timothy P Copeland

program define _codescan_parse_define, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , DEFine(string asis)

    local define = subinstr(`"`macval(define)'"', char(3), ",", .)
    local define = subinstr(`"`macval(define)'"', char(2), ")", .)
    local define = subinstr(`"`macval(define)'"', char(4), "(", .)
    local define = subinstr(`"`macval(define)'"', char(1), `"""', .)
    local n_conditions = 0
    local all_names ""

    * tokenize respects quotes: "I2[0-5]|I6[0-9]" stays as one token
    * Unquoted | becomes a separate token (space-separated)
    * Format: name "pattern" [~ "excl" ...] | name "pattern" | ...
    tokenize `"`define'"'

    local i = 1
    while `"``i''"' != "" {
        * Skip | delimiter tokens
        if `"``i''"' == "|" {
            local ++i
            continue
        }

        * Expect: name pattern [~ excl ...]
        local ++n_conditions
        local def_name_`n_conditions' `"``i''"'
        local ++i
        if `"``i''"' == "" | `"``i''"' == "|" {
            display as error "define(): condition `def_name_`n_conditions'' has no pattern"
            display as error "  Expected format: define(name {c 34}pattern{c 34} | name2 {c 34}pattern2{c 34})"
            exit 198
        }
        local def_pattern_`n_conditions' `"``i''"'
        local ++i

        * Parse optional exclusion patterns (~ "pattern" ~ "pattern" ...)
        local def_excl_`n_conditions' ""
        while `"``i''"' == "~" {
            local ++i
            if `"``i''"' == "" | `"``i''"' == "|" | `"``i''"' == "~" {
                display as error "define(): ~ must be followed by an exclusion pattern"
                exit 198
            }
            if `"`def_excl_`n_conditions''"' == "" {
                local def_excl_`n_conditions' `"``i''"'
            }
            else {
                local def_excl_`n_conditions' `"`def_excl_`n_conditions''|``i''"'
            }
            local ++i
        }

        local def_weight_`n_conditions' = 0
        local all_names "`all_names' `def_name_`n_conditions''"
    }
    local all_names = trim("`all_names'")

    if `n_conditions' == 0 {
        display as error "define() is empty"
        exit 198
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return scalar n_conditions = `n_conditions'
    return local all_names "`all_names'"
    forvalues i = 1/`n_conditions' {
        return local def_name_`i' "`def_name_`i''"
        return local def_pattern_`i' `"`def_pattern_`i''"'
        return local def_excl_`i' `"`def_excl_`i''"'
        return local def_weight_`i' "`def_weight_`i''"
    }
end

program define _codescan_apply_generate, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , PREFix(string) NAME(string asis) SUFFIXLen(integer)

    if strlen("`prefix'") + strlen("`name'") + `suffixlen' > 32 {
        display as error "generate(): prefix + longest condition name + suffix exceeds 32 characters"
        exit 198
    }
    local name "`prefix'`name'"

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local name "`name'"
end

program define _codescan_validate_def_regex
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , NAME(string asis) PATtern(string asis) [EXCLusion(string asis)]

    local pattern = subinstr(`"`macval(pattern)'"', char(3), ",", .)
    local pattern = subinstr(`"`macval(pattern)'"', char(2), ")", .)
    local pattern = subinstr(`"`macval(pattern)'"', char(4), "(", .)
    local pattern = subinstr(`"`macval(pattern)'"', char(1), `"""', .)
    local exclusion = subinstr(`"`macval(exclusion)'"', char(3), ",", .)
    local exclusion = subinstr(`"`macval(exclusion)'"', char(2), ")", .)
    local exclusion = subinstr(`"`macval(exclusion)'"', char(4), "(", .)
    local exclusion = subinstr(`"`macval(exclusion)'"', char(1), `"""', .)
    mata: _codescan_validate_regex(`"`pattern'"', `"`name'"', "pattern")
    if `"`exclusion'"' != "" {
        mata: _codescan_validate_regex(`"`exclusion'"', `"`name'"', "exclusion")
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

program define _codescan_apply_level, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , PATtern(string asis) LEVel(integer)

    local pattern = subinstr(`"`macval(pattern)'"', char(3), ",", .)
    local pattern = subinstr(`"`macval(pattern)'"', char(2), ")", .)
    local pattern = subinstr(`"`macval(pattern)'"', char(4), "(", .)
    local pattern = subinstr(`"`macval(pattern)'"', char(1), `"""', .)
    * Truncate each pipe-separated prefix to level() characters
    local _lv_remaining `"`pattern'"'
    local _lv_result ""
    while `"`_lv_remaining'"' != "" {
        local _lv_pos = strpos(`"`_lv_remaining'"', "|")
        if `_lv_pos' > 0 {
            local _lv_tok = substr(`"`_lv_remaining'"', 1, `_lv_pos' - 1)
            local _lv_remaining = substr(`"`_lv_remaining'"', `_lv_pos' + 1, .)
        }
        else {
            local _lv_tok `"`_lv_remaining'"'
            local _lv_remaining ""
        }
        local _lv_tok = strtrim(`"`_lv_tok'"')
        if `"`_lv_tok'"' != "" {
            local _lv_tok = substr(`"`_lv_tok'"', 1, `level')
            if `"`_lv_result'"' == "" {
                local _lv_result `"`_lv_tok'"'
            }
            else {
                local _lv_result `"`_lv_result'|`_lv_tok'"'
            }
        }
    }
    local pattern `"`_lv_result'"'

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local pattern `"`pattern'"'
end

mata:
void _codescan_validate_regex(string scalar pat, string scalar cname, string scalar ptype)
{
    real scalar i, n, depth_paren, depth_bracket, escaped
    string scalar ch

    n = strlen(pat)
    depth_paren = 0
    depth_bracket = 0
    escaped = 0

    for (i = 1; i <= n; i++) {
        ch = substr(pat, i, 1)
        if (escaped) {
            escaped = 0
            continue
        }
        if (ch == "\") {
            escaped = 1
            continue
        }
        if (depth_bracket == 0) {
            if (ch == "(") depth_paren = depth_paren + 1
            else if (ch == ")") {
                depth_paren = depth_paren - 1
                if (depth_paren < 0) {
                    errprintf("{err}" + ptype + " for %s: unmatched ')' in pattern: %s\n", cname, pat)
                    exit(198)
                }
            }
            else if (ch == "[") depth_bracket = depth_bracket + 1
        }
        else {
            if (ch == "]") depth_bracket = depth_bracket - 1
        }
    }
    if (depth_paren != 0) {
        errprintf("{err}" + ptype + " for %s: unmatched '(' in pattern: %s\n", cname, pat)
        exit(198)
    }
    if (depth_bracket != 0) {
        printf("{txt}(note: " + ptype + " for %s has unclosed '[' in pattern: %s)\n", cname, pat)
    }
}
end
