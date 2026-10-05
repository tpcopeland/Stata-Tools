*! _tabtools_csv_write Version 2.4.0  2026/10/05
*! Write visible table columns as CSV without Stata variable names
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

program define _tabtools_csv_write, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _restore_needed = 0
    capture noisily {
        syntax using/ [, LABELVar(name) TITLE(string) FOOTnote(string) RESERVEDRow]

        capture program list _tabtools_validate_path
        if _rc {
            capture findfile _tabtools_common.ado
            if _rc == 0 {
                run "`r(fn)'"
            }
            else {
                noisily display as error "_tabtools_common.ado not found; reinstall tabtools"
                exit 111
            }
        }

        _tabtools_validate_path `"`using'"' "csv()"

        local _visible_opts ""
        if `"`labelvar'"' != "" local _visible_opts "labelvar(`labelvar')"
        _tabtools_visible_vars, `_visible_opts'
        local _vars `"`_tabtools_visible_vars'"'

        * The collect-style callers reserve data row 1 for the title and park
        * the text in a variable that is not one of the exported columns, and
        * they render footnote() only into the workbook. Exporting the visible
        * columns alone therefore dropped both and shipped an all-empty first
        * row. Materialise them into the first exported column here, once, so
        * every command's CSV has the same shape as its workbook: title row,
        * table body, note row. Callers whose title/footnote already occupy a
        * body cell (puttab) passes neither option and is unaffected.
        preserve
        local _restore_needed = 1

        * Drop leading rows that carry nothing in any exported column. Those are
        * the reserved title rows; their text lives outside `_vars'.
        *
        * Only a caller that actually reserves such a row may ask for this.
        * The rule "a leading row blank in every exported column is structural"
        * is true for a rendered table and false for a raw export: `puttab' and
        * Some callers hand this helper the user's own observations, where a first
        * row blank in every column is data. Dropping it there silently shipped
        * a CSV with one row fewer than the workbook -- so the drop is opt-in,
        * declared by the caller that built the reserved row, never inferred
        * from the contents of row 1.
        if "`reservedrow'" != "" {
            tempvar _tt_filled
            quietly generate byte `_tt_filled' = 0
            foreach _v of local _vars {
                capture confirm string variable `_v'
                if !_rc quietly replace `_tt_filled' = 1 if strtrim(`_v') != ""
                else    quietly replace `_tt_filled' = 1 if !missing(`_v')
            }
            quietly count if `_tt_filled'
            if r(N) > 0 {
                tempvar _tt_rowid
                quietly generate long `_tt_rowid' = _n
                quietly summarize `_tt_rowid' if `_tt_filled', meanonly
                local _tt_first_filled = r(min)
                if `_tt_first_filled' > 1 quietly drop in 1/`=`_tt_first_filled' - 1'
            }
        }

        * Title and footnote can only be written into a string column. Every
        * table-building command makes its first column a string; the guard
        * matters for puttab-style exports of a raw numeric varlist, which pass
        * neither option anyway.
        local _tt_first : word 1 of `_vars'
        capture confirm string variable `_tt_first'
        if !_rc & _N > 0 {
            * macval(): the text is data, never macro syntax, so a quoted
            * local-macro reference or a $word in it is written as typed.
            if `"`macval(title)'"' != "" {
                quietly insobs 1, before(1)
                quietly replace `_tt_first' = `"`macval(title)'"' in 1
            }
            * One row per footnote paragraph (" \ " separates them); a
            * footnote without the token is one row, written as typed.
            if `"`macval(footnote)'"' != "" {
                mata: _tt_csv_fn_rows(st_local("footnote"))
                forvalues _tt_j = 1/`_tt_fn_n' {
                    quietly insobs 1
                    quietly replace `_tt_first' = `"`macval(_tt_fn_p`_tt_j')'"' in `=_N'
                }
            }
        }

        * quietly: export delimited announces "(file X not found)" and "file X
        * saved" from its own replace handling. Each caller prints its own
        * "CSV exported to ..." line, so that is internal chatter.
        quietly export delimited `_vars' using `"`using'"', replace novarnames

        * nclass: the row-trim above runs count/summarize, whose r() would
        * otherwise survive into the caller and read as the caller's own.
        quietly version
    }
    local rc = _rc
    if `_restore_needed' capture restore
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 17.0
capture mata: mata drop _tt_csv_fn_rows()
capture mata: mata drop _tt_csv_fn_paras()

* matastrict is a session setting: save the caller's value here and
* restore it after the block, so loading this file never leaks it.
local _tt_ms0 = c(matastrict)
mata:
mata set matastrict on

// Split footnote text into paragraphs on the literal token " \ " (space,
// backslash, space). Text without the token is returned unchanged; otherwise
// each piece is trimmed and empty pieces are dropped. Same rule in every
// tabtools writer.
string colvector _tt_csv_fn_paras(string scalar s)
{
    string colvector out
    string scalar rest, piece
    real scalar pos

    if (!strpos(s, " " + char(92) + " ")) return(s)
    out = J(0, 1, "")
    rest = s
    while ((pos = strpos(rest, " " + char(92) + " ")) > 0) {
        piece = strtrim(substr(rest, 1, pos - 1))
        if (piece != "") out = out \ piece
        rest = substr(rest, pos + 3, .)
    }
    piece = strtrim(rest)
    if (piece != "") out = out \ piece
    if (rows(out) == 0) out = ""
    return(out)
}

// Footnote paragraphs into locals _tt_fn_n and _tt_fn_p1, _tt_fn_p2, ...;
// the caller writes them with -replace-, which widens the column as needed.
void _tt_csv_fn_rows(string scalar foot)
{
    string colvector paras
    real scalar j

    paras = _tt_csv_fn_paras(foot)
    for (j = 1; j <= rows(paras); j++) st_local("_tt_fn_p" + strofreal(j), paras[j])
    st_local("_tt_fn_n", strofreal(rows(paras)))
}

end
mata: mata set matastrict `_tt_ms0'
