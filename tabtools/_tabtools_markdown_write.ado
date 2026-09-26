*! _tabtools_markdown_write Version 2.1.12  2026/09/26
*! Write the current dataset as a GitHub-Flavored Markdown table
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _tabtools_markdown_write, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax using/ , [APPEND LABELVar(name) HEADERStart(integer 2) ///
            DATAStart(integer 3) DATAEnd(integer -1) TITLE(string) FOOTnote(string) ///
            NOVARNAMES STRICTHeaders]

        capture _tabtools_helpers_ready
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

        quietly ds
        local _allvars `r(varlist)'
        if "`_allvars'" == "" {
            noisily display as error "No variables available for Markdown export"
            exit 111
        }
        quietly count
        if r(N) == 0 {
            noisily display as error "No observations available for Markdown export"
            exit 2000
        }

        local _path_lower = lower(`"`using'"')
        if !(strmatch(`"`_path_lower'"', "*.md") | ///
             strmatch(`"`_path_lower'"', "*.markdown") | ///
             strmatch(`"`_path_lower'"', "*.qmd") | ///
             strmatch(`"`_path_lower'"', "*.rmd")) {
            noisily display as error "markdown() must specify a .md, .markdown, .qmd, or .rmd file"
            exit 198
        }

        capture _tabtools_validate_path `"`using'"' "markdown()"
        if _rc exit _rc

        local _visible_opts ""
        if `"`labelvar'"' != "" local _visible_opts "labelvar(`labelvar')"
        _tabtools_visible_vars, `_visible_opts'
        local _vars `"`_tabtools_visible_vars'"'
        local _k : word count `_vars'
        if `_k' == 0 {
            noisily display as error "No output columns available for Markdown export"
            exit 111
        }

        if `headerstart' < 1 local headerstart = 1
        if `datastart' < 1 local datastart = 1

        * A Markdown heading is emitted ONLY for an explicit title(). The writer
        * used to scan row 1 for the first non-empty cell when no title was
        * given, which promoted table DATA into a fabricated heading: for
        * table1_tc, row 1 holds the group labels, so a by(foreign) table with
        * no title() was headed "### Domestic". Header-shaped data must never
        * become a heading.
        *
        * Every piece of text -- title, headers, body cells, footnote -- is
        * read, escaped and written inside Mata. The writer used to move each
        * cell into a local macro and expand it again in an if-condition and
        * in -file write-, so data was parsed as macro syntax: a cell quoted
        * as a local-macro reference vanished, an unbalanced backtick stopped
        * with r(132) after a partial file, and a dollar-prefixed word was
        * replaced by a global. st_local(), st_sdata() and fput() never
        * expand anything. The table is built in full before the file is
        * opened, so an error cannot leave a partial file behind.
        *
        * The default replaces an existing file, as README and every help
        * file describe; mdappend (append) adds to it. The new text is staged
        * in a tempfile and copied over the target only once complete.
        local _append = ("`append'" != "")
        local _append_existing = 0
        if `_append' {
            capture confirm file `"`using'"'
            if !_rc local _append_existing = 1
        }
        tempfile _stage
        mata: _tt_md_write(st_local("_stage"), st_local("_vars"), ///
            `headerstart', `datastart', `dataend', ///
            "`novarnames'" != "", "`strictheaders'" != "", `_append_existing')
        local _n_body = `_tt_md_nbody'
        if `_append' {
            mata: _tt_md_append(st_local("_stage"), st_local("using"))
        }
        else {
            quietly copy `"`_stage'"' `"`using'"', replace
        }

        return scalar n_rows = `_n_body'
        return scalar n_cols = `_k'
        return local markdown `"`using'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 17.0
capture mata: mata drop _tt_md_escape()
capture mata: mata drop _tt_md_cell()
capture mata: mata drop _tt_md_body_cell()
capture mata: mata drop _tt_md_write()
capture mata: mata drop _tt_md_append()

mata:
mata set matastrict on

string scalar _tt_md_escape(string scalar x)
{
    x = strtrim(x)
    x = subinstr(x, "\", "\\")
    x = subinstr(x, "|", "\|")
    x = subinstr(x, "*", "\*")
    x = subinstr(x, "_", "\_")
    // Literal text, not markup: raw HTML and comments (< >), entities (&),
    // link, image and reference syntax ([ ]), GFM strikethrough (~) and code
    // spans (backtick) were rendered as markup, so "<b>Drug</b> &copy;
    // [arm](url)" displayed as bold text, a copyright sign and a hyperlink,
    // and "~~x~~" as struck-through text. A backslash before ASCII
    // punctuation is a literal in CommonMark/GFM. This runs before <br> is
    // inserted below, and _tt_md_body_cell() prepends &nbsp; indentation
    // after escaping, so helper-generated markup stays live. The backtick is
    // spelled char(96): lines of an .ado file are macro-expanded, Mata
    // blocks included.
    x = subinstr(x, char(96), "\" + char(96))
    x = subinstr(x, "<", "\<")
    x = subinstr(x, ">", "\>")
    x = subinstr(x, "&", "\&")
    x = subinstr(x, "[", "\[")
    x = subinstr(x, "]", "\]")
    x = subinstr(x, "~", "\~")
    x = subinstr(x, char(13) + char(10), "<br>")
    x = subinstr(x, char(13), "<br>")
    x = subinstr(x, char(10), "<br>")
    return(x)
}

string scalar _tt_md_cell(string scalar v, real scalar i)
{
    real scalar j
    real scalar x

    j = st_varindex(v)
    if (st_isstrvar(j)) {
        return(strtrim(st_sdata(i, j)))
    }
    x = st_data(i, j)
    if (x >= .) return("")
    return(strtrim(strofreal(x, st_varformat(j))))
}

// Escaped body cell. With indent != 0, each leading space of a string cell
// becomes one &nbsp; so row-label indentation survives GFM cell trimming.
// The entity is prepended after escaping, so it can never combine with the
// escaped content (e.g. a leading "|" is written as &nbsp;\|). Trailing
// blanks are trimmed; interior spaces are unchanged; an all-blank cell is
// empty. Numeric cells keep the trimmed display-format rendering.
string scalar _tt_md_body_cell(string scalar v, real scalar i, real scalar indent)
{
    real scalar j, n
    string scalar raw, core

    j = st_varindex(v)
    if (!indent | !st_isstrvar(j)) return(_tt_md_escape(_tt_md_cell(v, i)))
    raw = st_sdata(i, j)
    // Count before escaping: Mata passes arguments by reference and
    // _tt_md_escape() trims its argument in place.
    n = strlen(raw) - strlen(strltrim(raw))
    core = _tt_md_escape(raw)
    if (core == "") return("")
    return(n * "&nbsp;" + core)
}


// Build the whole Markdown table and write it to the fresh file stage.
// Text is read from the data and from the title/footnote locals with
// st_sdata()/st_local() and written with fput(), so nothing is ever macro-
// expanded. Posts the number of body rows written to local _tt_md_nbody.
void _tt_md_write(string scalar stage, string scalar varlist,
    real scalar hs, real scalar ds, real scalar de,
    real scalar novarnames, real scalar strict, real scalar lead_blank)
{
    string rowvector vars
    string colvector out
    string scalar h, line, cell, title, foot
    real scalar j, i, k, nobs, body_end, has_text, nbody, fh

    vars = tokens(varlist)
    k = cols(vars)
    nobs = st_nobs()
    out = J(0, 1, "")
    if (lead_blank) out = out \ ""

    title = st_local("title")
    if (title != "") out = out \ ("### " + _tt_md_escape(title)) \ ""

    line = "|"
    for (j = 1; j <= k; j++) {
        h = ""
        if (!novarnames & hs >= 1 & hs <= nobs) h = _tt_md_cell(vars[j], hs)
        if (h == "" & !strict & !novarnames) {
            h = st_varlabel(vars[j])
            if (h == "") h = vars[j]
            if (h == "") h = "Column " + strofreal(j)
        }
        line = line + " " + _tt_md_escape(h) + " |"
    }
    out = out \ line
    line = "|"
    for (j = 1; j <= k; j++) line = line + " --- |"
    out = out \ line

    nbody = 0
    body_end = (de < 0 ? nobs : min((de, nobs)))
    for (i = ds; i <= body_end; i++) {
        line = "|"
        has_text = 0
        for (j = 1; j <= k; j++) {
            // Column 1 is the row-label (stub) column: its leading spaces are
            // the hierarchy and are written as &nbsp; entities, because GFM
            // trims cell whitespace. Value columns are trimmed.
            cell = _tt_md_body_cell(vars[j], i, j == 1)
            if (cell != "") has_text = 1
            line = line + " " + cell + " |"
        }
        if (has_text) {
            out = out \ line
            nbody++
        }
    }

    foot = st_local("footnote")
    if (foot != "") out = out \ "" \ ("*" + _tt_md_escape(foot) + "*")

    fh = fopen(stage, "w")
    for (i = 1; i <= rows(out); i++) fput(fh, out[i])
    fclose(fh)
    st_local("_tt_md_nbody", strofreal(nbody))
}

// Append the staged table to target (created when absent). The stage is
// complete before target is opened.
void _tt_md_append(string scalar stage, string scalar target)
{
    string colvector lines
    real scalar fh, i

    lines = cat(stage)
    fh = fopen(target, "a")
    for (i = 1; i <= rows(lines); i++) fput(fh, lines[i])
    fclose(fh)
}

end
