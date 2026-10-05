*! _datacheck_byrule Version 1.9.2  2026/10/05
*! datacheck byrule(): a row-level rule evaluated under Stata's by byvars (sortvars): semantics
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
// Returns r(lab), r(exp), r(byvars), r(sortvars), r(ties) (1 when
// (byvars sortvars) does not uniquely order the rows and the expression
// uses _n, _N or a subscript; the note is printed here and carries no
// count, so it needs no masking).
program define _datacheck_byrule, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _ordmade = 0
    capture noisily {
        syntax , SPEC(string) IND(varname) [PARSEonly]
        local part = strtrim(`"`spec'"')
        local cp = strpos(`"`part'"', ":")
        if `cp' == 0 {
            display as error `"byrule() spec must be "byvars (sortvars): label: expression": `part'"'
            exit 198
        }
        local bspec = strtrim(substr(`"`part'"', 1, `cp' - 1))
        local rest = strtrim(substr(`"`part'"', `cp' + 1, .))
        // only the label may be quoted: "id (t): ..." quoted whole is not a byspec
        if strpos(`"`bspec'"', char(34)) | strpos(`"`bspec'"', char(96)) {
            display as error `"byrule() spec must be byvars (sortvars): "label": expression, with only the label in quotes"'
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
        if substr(`"`rest'"', 1, 1) == char(34) {
            local qe = strpos(substr(`"`rest'"', 2, .), char(34))
            local rlab = substr(`"`rest'"', 2, `qe' - 1)
            local rexp = strtrim(substr(`"`rest'"', `qe' + 2, .))
            if `qe' == 0 | substr(`"`rexp'"', 1, 1) != ":" {
                display as error `"byrule() spec must be "byvars (sortvars): label: expression": `part'"'
                exit 198
            }
            local rexp = strtrim(substr(`"`rexp'"', 2, .))
        }
        else {
            local lp = strpos(`"`rest'"', ":")
            if `lp' == 0 {
                display as error `"byrule() spec must be "byvars (sortvars): label: expression": `part'"'
                exit 198
            }
            local rlab = strtrim(substr(`"`rest'"', 1, `lp' - 1))
            local rexp = strtrim(substr(`"`rest'"', `lp' + 1, .))
        }
        local rlab = strtrim(`"`rlab'"')
        if `"`rlab'"' == "" | `"`rexp'"' == "" {
            display as error `"byrule() spec must be "byvars (sortvars): label: expression": `part'"'
            exit 198
        }
        if strpos(`"`rlab'"', char(34)) | strpos(`"`rlab'"', char(96)) {
            display as error "byrule() label must not contain quotes or backticks"
            exit 198
        }
        local ties = 0
        if "`parseonly'" == "" {
            tempvar ord tie
            quietly generate long `ord' = _n
            local _ordmade = 1
            quietly sort `byv' `srt', stable
            if "`byv'" != "" capture quietly by `byv': replace `ind' = 1 if !(`rexp')
            else capture quietly replace `ind' = 1 if !(`rexp')
            local erc = _rc
            if !`erc' & "`srt'" != "" & ustrregexm(`"`rexp'"', "(\w\[|\b_n\b|\b_N\b)") {
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
                display as error `"byrule(`rlab'): cannot evaluate expression `rexp'"'
                exit `erc'
            }
        }
        return local lab `"`rlab'"'
        return local exp `"`macval(rexp)'"'
        return local byvars "`byv'"
        return local sortvars "`srt'"
        return scalar ties = `ties'
    }
    local rc = _rc
    if `_ordmade' capture quietly sort `ord'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
