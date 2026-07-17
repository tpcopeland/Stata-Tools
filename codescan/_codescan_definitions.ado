*! _codescan_definitions Version 4.0.0  2026/07/17
*! Private definition helpers for codescan
*! Author: Timothy P Copeland, Karolinska Institutet

capture program drop _codescan_parse_define
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

capture program drop _codescan_apply_generate
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

capture program drop _codescan_validate_def_regex
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

capture program drop _codescan_apply_level
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

capture program drop _codescan_validate_def_prefix
program define _codescan_validate_def_prefix
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , NAME(string asis) PATtern(string asis) [EXCLusion(string asis)]

    foreach _kind in pattern exclusion {
        local _value `"``_kind''"'
        local _value = subinstr(`"`macval(_value)'"', char(3), ",", .)
        local _value = subinstr(`"`macval(_value)'"', char(2), ")", .)
        local _value = subinstr(`"`macval(_value)'"', char(4), "(", .)
        local _value = subinstr(`"`macval(_value)'"', char(1), `"""', .)
        if `"`_value'"' == "" & "`_kind'" == "exclusion" continue

        local _remaining `"`_value'"'
        while `"`_remaining'"' != "" {
            local _pipe = strpos(`"`_remaining'"', "|")
            if `_pipe' > 0 {
                local _token = strtrim(substr(`"`_remaining'"', 1, `_pipe' - 1))
                local _remaining = substr(`"`_remaining'"', `_pipe' + 1, .)
            }
            else {
                local _token = strtrim(`"`_remaining'"')
                local _remaining ""
            }
            if `"`_token'"' == "" | (`_pipe' > 0 & `"`_remaining'"' == "") {
                display as error "`_kind' for `name': empty prefix alternative in pattern: `_value'"
                exit 198
            }
        }
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

* Drop first so a reload of this bundled file (loader re-runs it on partial-load)
* does not crash with "_codescan_validate_regex() already exists" (r3000).
capture mata: mata drop _codescan_validate_regex()
mata:
void _codescan_validate_regex(string scalar pat, string scalar cname, string scalar ptype)
{
    real scalar i, n, depth_paren, depth_bracket, escaped
    string scalar ch
    real scalar j, sp, db, esc
    real colvector cur_nonempty, has_alt
    string scalar c2
    real scalar k

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
        // An unclosed '[' silently matches nothing under the matching engine —
        // a false-zero cohort, not a cosmetic issue. Treat it as an error.
        errprintf("{err}" + ptype + " for %s: unclosed '[' in pattern: %s\n", cname, pat)
        exit(198)
    }

    // ── Empty-alternation-branch check (match-everything false-cohort guard) ──
    // An empty branch in an alternation — "E11|", "|E11", "E11||E12", "(E11|)" —
    // anchors as ^(...|...) with an empty operand. The empty branch matches the
    // start of EVERY code, so ustrregexm() returns 1 (valid, not -1) for every
    // value: a silent match-everything cohort for a pattern, or a match-
    // everything drop for an exclusion. The compile-probe below cannot catch it
    // (ICU accepts empty alternations), so detect it structurally here. Parens
    // are already known balanced at this point, so the frame stack (one slot per
    // open group plus the top level) cannot underflow. '|' inside '[...]' or an
    // escaped '\|' is a literal and is never treated as an alternation.
    cur_nonempty = J(n + 1, 1, 0)
    has_alt      = J(n + 1, 1, 0)
    sp = 1
    db = 0
    esc = 0
    for (j = 1; j <= n; j++) {
        c2 = substr(pat, j, 1)
        if (esc) {
            esc = 0
            cur_nonempty[sp] = 1
            continue
        }
        if (c2 == "\") {
            esc = 1
            continue
        }
        if (db > 0) {
            if (c2 == "]") db = db - 1
            cur_nonempty[sp] = 1
            continue
        }
        if (c2 == "[") {
            db = db + 1
            cur_nonempty[sp] = 1
            continue
        }
        if (c2 == "(") {
            cur_nonempty[sp] = 1
            sp = sp + 1
            cur_nonempty[sp] = 0
            has_alt[sp] = 0
            continue
        }
        if (c2 == ")") {
            if (has_alt[sp] & !cur_nonempty[sp]) {
                errprintf("{err}" + ptype + " for %s: empty alternation branch (matches every code) in pattern: %s\n", cname, pat)
                exit(198)
            }
            if (sp > 1) sp = sp - 1
            continue
        }
        if (c2 == "|") {
            if (!cur_nonempty[sp]) {
                errprintf("{err}" + ptype + " for %s: empty alternation branch (matches every code) in pattern: %s\n", cname, pat)
                exit(198)
            }
            has_alt[sp] = 1
            cur_nonempty[sp] = 0
            continue
        }
        cur_nonempty[sp] = 1
    }
    if (has_alt[sp] & !cur_nonempty[sp]) {
        errprintf("{err}" + ptype + " for %s: empty alternation branch (matches every code) in pattern: %s\n", cname, pat)
        exit(198)
    }

    // Runtime compile-probe (catch-all). The structural checks above only
    // balance delimiters and reject empty alternations; malformed quantifiers
    // ({2,1}, leading *) and bad groups still slip through and make regexm()
    // silently return 0 (a false-zero cohort). ustrregexm() returns -1 (not a
    // Stata error) on a structurally invalid ICU pattern, so probe the
    // *anchored* form the scanner actually uses ("^(...)" — see
    // _codescan_mata_scan) and reject -1.
    if (ustrregexm("__codescan_probe__", "^(" + pat + ")") == -1) {
        errprintf("{err}" + ptype + " for %s: invalid regex pattern: %s\n", cname, pat)
        exit(198)
    }

    // ── Empty-match guard (match-everything false-cohort catch-all) ──────────
    // The structural checks above reject empty alternation branches, but many
    // other patterns can also match the empty string: "()", "(())", "A*", "A?",
    // "A{0}", nested empty groups. ICU compiles every one of them, so neither
    // the structural pass nor the compile probe rejects them. Anchored as
    // "^(pat)" — the form _codescan_mata_scan actually applies — an
    // empty-capable pattern matches the start of EVERY nonempty code: as an
    // inclusion it silently yields a cohort of everyone, as an exclusion it
    // silently removes every match. Both are analytic-validity failures that
    // return rc=0. Probe the anchored form against "" and reject a match.
    if (ustrregexm("", "^(" + pat + ")") == 1) {
        errprintf("{err}" + ptype + " for %s: pattern can match an empty string (matches every code): %s\n", cname, pat)
        // Mata string literals have no backslash escape for a double quote, so
        // this message is written without embedded quotes on purpose.
        errprintf("{err}  to match any non-empty code use the pattern . instead (not .* or empty groups)\n")
        exit(198)
    }

    // ── Zero-length-match guard (zero-width assertions) ──────────────────────
    // The probe above asks whether the pattern matches an EMPTY subject. A
    // zero-width assertion needing surrounding context answers no and is still
    // match-everything: "^(\b)" finds no boundary in "" (score 0, passes) but
    // matches a zero-length string at the start of every real code, so
    // define(x "\b") returned a 100% cohort at rc=0 in 3.0.0 — the exact defect
    // C2 exists to prevent, reached on an axis an empty subject cannot expose.
    //
    // A zero-length match is never meaningful here: this scanner matches codes,
    // so a hit that consumes no characters has identified nothing — the pattern
    // matched the position before the code, not the code itself. (matched_code()
    // would still record the whole cell, so the match is vacuous, not empty.)
    // Probe the anchored form against one code per leading
    // character and reject any zero-length hit. Per-leading-char (not one probe
    // string) is what catches an assertion keyed to a specific character, e.g.
    // "(?=E)".
    //
    // The probe alphabet spans printable ASCII (32-126) rather than just
    // [A-Za-z0-9._-]. 3.0.1 used the narrow alphabet and was breached the same
    // way 3.0.0 was: "(?=/)" is keyed to a character the alphabet omitted, so it
    // scored 0 on every probe and returned a 100% cohort at rc=0 on codes
    // beginning "/". Printable ASCII covers every character real code systems
    // use (ICD "." and "+", NDC "-", Read "%", padded codes with spaces).
    // char() builds each subject, so the double-quote probe costs nothing to
    // express — Mata string literals have no backslash escape for a quote.
    //
    // This remains a domain guard, not a proof: an assertion keyed to a
    // non-ASCII character (e.g. "(?=å)") on non-ASCII codes still slips,
    // which is why the help file claims rejection of patterns that can match
    // empty at the start of a code rather than completeness. Exact coverage
    // needs the data's own leading characters, which are not available at
    // option-validation time — and validating before any work is a C5 contract.
    // Legitimate patterns are untouched: "\bE11" consumes E11 on every probe it
    // matches, so it never trips this.
    for (k = 32; k <= 126; k++) {
        if (ustrregexm(char(k) + "00", "^(" + pat + ")") == 1) {
            if (ustrregexs(0) == "") {
                errprintf("{err}" + ptype + " for %s: pattern matches without consuming any characters (zero-width): %s\n", cname, pat)
                // No backslash in this literal on purpose: Mata printf-style
                // escapes make a literal backslash in a message a silent hazard.
                errprintf("{err}  a zero-width assertion (word boundary, lookahead) matches a position, not a code, so it identifies nothing\n")
                errprintf("{err}  write the required leading characters literally (E for codes starting E), or . to match any non-empty code\n")
                exit(198)
            }
        }
    }
}
end
