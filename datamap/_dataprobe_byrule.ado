*! _dataprobe_byrule Version 2.1.0  2026/11/16
*! dataprobe byrule(): a row-level rule evaluated under Stata's by byvars (sortvars): semantics
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Spec of ONE entry:  byspec: label: expression
// byspec is Stata's own by-grammar: "byvars (sortvars)", "byvars", or
// "(sortvars)" with no groups.  The label may be quoted.  The caller has
// created the 0/1 indicator variable ind(), which this program sets to 1 on
// the rows where the expression is NOT true, exactly as rule() does.
//
// The data are sorted with  sort byvars sortvars, stable  so ties keep the
// caller's order, the expression is evaluated under  by byvars:  (or plainly
// when there are no byvars), and the row order is then restored from a
// tempvar, so the data come back in the order they arrived.  Under by,
// _n, _N and x[_n+k] refer to positions within a group, counted over the
// rows the caller passes in (the if/in scope).  A missing byvars value is
// its own group, as in by.
//
// The expression may hold group aggregates (2.1.0), total(exp) mean(exp)
// gmin(exp) gmax(exp) spread(exp) count(exp), each the value over the rows
// of the row's group (_dataprobe_byagg); a group where one of them has no
// nonmissing value fails.  With gid(newvar) and an aggregate, newvar gets
// the group number (egen group(byvars), missing), so the caller can count
// failing groups.
//
// Returns r(lab), r(exp), r(byvars), r(sortvars), r(agg) (1 when the
// expression holds an aggregate), r(ties) (1 when
// (byvars sortvars) does not uniquely order the rows and the expression
// uses _n, _N or a subscript; the note is printed here and carries no
// count, so it needs no masking).
program define _dataprobe_byrule, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _ordmade = 0
    capture noisily {
        syntax , SPEC(string) IND(varname) [PARSEonly GID(name)]
        // R1 (2.1.0): the spec text is moved with Mata and macval() only, so
        // a $ or backtick in the expression reaches Stata literally (in
        // 2.0.0 s != "a$b" was evaluated as s != "a"); the byspec and the
        // label, which are expanded as names and messages, refuse them
        mata: st_local("part", strtrim(st_local("spec")))
        local cp = strpos(`"`macval(part)'"', ":")
        if `cp' == 0 {
            display as error `"byrule() spec must be "byvars (sortvars): label: expression": `macval(part)'"'
            exit 198
        }
        local bspec = strtrim(substr(`"`macval(part)'"', 1, `cp' - 1))
        local rest = strtrim(substr(`"`macval(part)'"', `cp' + 1, .))
        // only the label may be quoted: "id (t): ..." quoted whole is not a byspec
        if strpos(`"`macval(bspec)'"', char(34)) | strpos(`"`macval(bspec)'"', char(96)) {
            display as error `"byrule() spec must be byvars (sortvars): "label": expression, with only the label in quotes"'
            exit 198
        }
        if strpos(`"`macval(bspec)'"', char(36)) {
            display as error "byrule() byspec must name variables; it cannot hold " char(36)
            exit 198
        }
        // ---- byspec: byvars (sortvars) | byvars | (sortvars) ----
        local byv ""
        local srt ""
        if strpos(`"`bspec'"', "(") | strpos(`"`bspec'"', ")") {
            if !ustrregexm(`"`bspec'"', "^([^()]*)\(([^()]*)\)$") {
                display as error `"byrule() byspec must be "byvars (sortvars)", "byvars", or "(sortvars)": `bspec'"'
                exit 198
            }
            local byv = strtrim(ustrregexs(1))
            local srt = strtrim(ustrregexs(2))
            if "`srt'" == "" {
                display as error "byrule() byspec has empty (sortvars)"
                exit 198
            }
        }
        else local byv "`bspec'"
        if "`byv'" == "" & "`srt'" == "" {
            display as error "byrule() spec has no byvars or (sortvars)"
            exit 198
        }
        if "`byv'" != "" unab byv : `byv'
        if "`srt'" != "" unab srt : `srt'
        // ---- label: expression ----
        if substr(`"`macval(rest)'"', 1, 1) == char(34) {
            local qe = strpos(substr(`"`macval(rest)'"', 2, .), char(34))
            local rlab = substr(`"`macval(rest)'"', 2, `qe' - 1)
            local rexp = strtrim(substr(`"`macval(rest)'"', `qe' + 2, .))
            if `qe' == 0 | substr(`"`macval(rexp)'"', 1, 1) != ":" {
                display as error `"byrule() spec must be "byvars (sortvars): label: expression": `macval(part)'"'
                exit 198
            }
            local rexp = strtrim(substr(`"`macval(rexp)'"', 2, .))
        }
        else {
            local lp = strpos(`"`macval(rest)'"', ":")
            if `lp' == 0 {
                display as error `"byrule() spec must be "byvars (sortvars): label: expression": `macval(part)'"'
                exit 198
            }
            local rlab = strtrim(substr(`"`macval(rest)'"', 1, `lp' - 1))
            local rexp = strtrim(substr(`"`macval(rest)'"', `lp' + 1, .))
        }
        local rlab = strtrim(`"`macval(rlab)'"')
        if `"`macval(rlab)'"' == "" | `"`macval(rexp)'"' == "" {
            display as error `"byrule() spec must be "byvars (sortvars): label: expression": `macval(part)'"'
            exit 198
        }
        if strpos(`"`macval(rlab)'"', char(34)) | strpos(`"`macval(rlab)'"', char(96)) {
            display as error "byrule() label must not contain quotes or backticks"
            exit 198
        }
        if strpos(`"`macval(rlab)'"', char(36)) {
            display as error "byrule() label must not contain " char(36)
            exit 198
        }
        local ties = 0
        // 2.1.0 F9(c): group aggregates (total() spread() mean() count()
        // gmin() gmax(), see _dataprobe_byagg) are computed per group before
        // the rule and stand in the expression as variables
        _dataprobe_byagg scan `"`macval(rexp)'"'
        local _agn = `_ag_n'
        local rexp2 `"`macval(rexp)'"'
        local _agmiss ""
        if "`parseonly'" == "" {
            tempvar ord tie
            quietly generate long `ord' = _n
            local _ordmade = 1
            if `_agn' {
                local _agnames ""
                forvalues i = 1/`_agn' {
                    tempvar ag`i'
                    _dataprobe_byagg make `_ag_k`i'' `ag`i'' `"`macval(_ag_a`i')'"', by(`byv')
                    local _agnames "`_agnames' `ag`i''"
                    // a group with no nonmissing value fails the rule
                    if "`_ag_k`i''" != "count" local _agmiss = cond("`_agmiss'" == "", ///
                        "missing(`ag`i'')", "`_agmiss' | missing(`ag`i'')")
                }
                _dataprobe_byagg rewrite `"`macval(rexp)'"', names(`_agnames')
                local rexp2 `"`macval(_ag_exp)'"'
                // the groups, for the count of failing groups
                if "`gid'" != "" {
                    if "`byv'" != "" quietly egen long `gid' = group(`byv'), missing
                    else quietly generate long `gid' = 1
                }
                // the aggregates sorted the rows: back to the caller's order,
                // so ties below keep it
                quietly sort `ord'
            }
            quietly sort `byv' `srt', stable
            // blocks, not one-line ifs: a one-line if expands its command
            // a second time, which turned "a$b" into "a" (R1)
            if "`byv'" != "" {
                capture quietly by `byv': replace `ind' = 1 if !(`macval(rexp2)')
                local erc = _rc
            }
            else {
                capture quietly replace `ind' = 1 if !(`macval(rexp2)')
                local erc = _rc
            }
            if !`erc' & "`_agmiss'" != "" quietly replace `ind' = 1 if `_agmiss'
            if !`erc' & "`srt'" != "" & ustrregexm(`"`macval(rexp)'"', "(\w\[|\b_n\b|\b_N\b)") {
                quietly by `byv' `srt': generate byte `tie' = _N > 1
                quietly count if `tie'
                if r(N) > 0 {
                    local ties = 1
                    display as text `"  note: byrule(`rlab'): (`byv' `srt') does not uniquely order the rows, so ties keep the data's own order within `byv' groups"'
                }
            }
            quietly sort `ord'
            local _ordmade = 0
            if `erc' {
                display as error `"byrule(`rlab'): cannot evaluate expression `macval(rexp)'"'
                exit `erc'
            }
        }
        return local lab `"`rlab'"'
        return local exp `"`macval(rexp)'"'
        return local byvars "`byv'"
        return local sortvars "`srt'"
        return scalar ties = `ties'
        return scalar agg = (`_agn' > 0)
    }
    local rc = _rc
    if `_ordmade' {
        // Reached only when an error left the data in byvars order: restore
        // the caller's row order, and say so if that too fails
        capture quietly sort `ord'
        local src = _rc
        if `src' {
            display as error "byrule(): could not restore the original row order (rc `src')"
            if !`rc' local rc = `src'
        }
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
