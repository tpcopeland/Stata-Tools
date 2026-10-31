*! _tabtools_latex_write Version 1.1.0  2026/10/31
*! Write the current dataset as a LaTeX table float (booktabs rules)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
    _tabtools_latex_write using file.tex , [append document labelvar(name)
        headerstart(#) datastart(#) dataend(#) title(text) footnote(text)
        novarnames strictheaders keepblank boldrows(numlist)
        spans(numlist)]

    document: a new (or replaced) file is a complete document --
    \documentclass{article}, \usepackage{booktabs}, \begin{document} ...
    \end{document} -- that compiles on its own. Without it the file holds
    the table float only, for \input. append into a file with an
    \end{document} line puts the table just before the last such line,
    with or without document; append document into an existing file with
    no such line is r(198) with nothing written.

    Header block: observations headerstart() .. datastart()-1, one LaTeX row
    each, then \midrule. novarnames, or headerstart() >= datastart(), means
    no header block. In the last header row an empty cell falls back to the
    variable label, then the variable name (not with strictheaders).
    spans() is triples "row c1 c2": observation number of a header row and
    the first/last visible-column index of a column spanner. The spanner is
    declared by the caller, never inferred from blank cells. Every other
    cell of a span must be blank or equal the spanned text, and spans in one
    row may not overlap; a violation is r(198) with nothing written. A span
    in any header row but the last gets \cmidrule(lr){c1-c2} under it.
    Body: observations datastart() .. dataend(). A body row whose only
    text is in column 1 (k > 1) is one \multicolumn{k}{l}{...} cell, so a
    test or note line does not widen the stub column (the workbook lets it
    overflow into the empty cells to its right). Requires only booktabs.

    Caption: \caption carries title() less one leading table-number prefix,
    because LaTeX numbers the table itself ("Table 1: Table 1. ..."
    otherwise). The prefix is, case-insensitively, "Table", spaces, an id
    (an optional letter, digits, an optional letter: 1, S1, A2, 2a), then
    "." (followed by a space or the end), ":", or spaces and one to three
    hyphens, an en dash or an em dash, then spaces. "Table of outcomes", "Tables 1 and 2", "Table 1
    shows" and "Table 1.2 Results" are kept whole; a title that is only the
    prefix ("Table 1.") is written unchanged. The \label stem is the file
    name, never the title.

    texopts(): layout sub-options, parsed by _tabtools_texopts (see there);
    empty means the session value from tabtools set texopts, if any. The
    float is [\begin{landscape}] \begin{table}[placement] [\centering]
    [\captionsetup{...} \caption \label] [size] [\resizebox{..}{!}{%]
    tabular [}] [notes] [caption below] \end{table} [\end{landscape}]. The
    packages the layout needs are named in a second comment line, loaded in a
    document this writer creates, and added before \begin{document} of an
    existing document the table is inserted into when it lacks them.

    Returns r(n_rows) (body rows written; blank rows count only with
    keepblank, exactly as _tabtools_markdown_write counts them), r(n_cols),
    r(latex).
*/

program define _tabtools_latex_write, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax using/ , [APPEND DOCument LABELVar(name) HEADERStart(integer 2) ///
            DATAStart(integer 3) DATAEnd(integer -1) TITLE(string) FOOTnote(string) ///
            NOVARNAMES STRICTHeaders KEEPBlank BOLDRows(numlist >0 integer) ///
            SPANs(numlist >0 integer) texopts(string asis)]

        capture _tabtools_helpers_ready
        if !_rc capture mata: assert(findexternal("_tt_sep_parse()") != NULL)
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
            noisily display as error "No variables available for LaTeX export"
            exit 111
        }
        quietly count
        if r(N) == 0 {
            noisily display as error "No observations available for LaTeX export"
            exit 2000
        }

        if !strmatch(lower(`"`using'"'), "*.tex") {
            noisily display as error "latex() must specify a .tex file"
            exit 198
        }

        * Not captured: the refusal names the option ("latex() contains
        * invalid characters") instead of failing with a bare r(198).
        _tabtools_validate_path `"`using'"' "latex()"

        local _visible_opts ""
        if `"`labelvar'"' != "" local _visible_opts "labelvar(`labelvar')"
        _tabtools_visible_vars, `_visible_opts'
        local _vars `"`_tabtools_visible_vars'"'
        local _k : word count `_vars'
        if `_k' == 0 {
            noisily display as error "No output columns available for LaTeX export"
            exit 111
        }

        if `headerstart' < 1 local headerstart = 1
        if `datastart' < 1 local datastart = 1

        * A labelvar() that names no variable used to be dropped silently by
        * _tabtools_visible_vars, shifting every column (and spans()) by one.
        if `"`labelvar'"' != "" {
            capture confirm variable `labelvar', exact
            if _rc {
                noisily display as error "labelvar(): variable `labelvar' not found; nothing was written"
                exit 111
            }
        }
        * datastart() past the data made every row a header row, and a
        * header block that starts after the body is no layout at all.
        quietly count
        local _nobs = r(N)
        if `datastart' > `_nobs' + 1 {
            noisily display as error "datastart(`datastart') is beyond the last observation (`_nobs'); nothing was written"
            exit 198
        }
        if "`novarnames'" == "" & `headerstart' > `datastart' {
            noisily display as error "headerstart(`headerstart') is after datastart(`datastart'); nothing was written"
            exit 198
        }

        * Every piece of text -- title, headers, body cells, footnote -- is
        * read, escaped and written inside Mata (st_sdata(), st_local(),
        * fput()), never through a macro: a cell holding a local-macro
        * reference, a dollar-prefixed word or an unbalanced backtick is
        * written as typed. Escaping is one left-to-right pass per character,
        * so a replacement can never be escaped again. The whole table, spans
        * validation included, is built before the stage file is opened, and
        * the stage is copied over (or appended to) the target only once
        * complete, so an error leaves the target untouched.
        * Layout: the command's texopts(), else the session value. Parsed
        * before anything is staged; a bad sub-option writes nothing.
        * st_global: the session value is copied, never macro-expanded again.
        if `"`macval(texopts)'"' == "" mata: st_local("texopts", st_global("TABTOOLS_set_texopts"))
        _tabtools_texopts `"`macval(texopts)'"'
        foreach _f in captionleft captionbelow nocentering fit landscape npreamble {
            local _tx_`_f' = r(`_f')
        }
        foreach _f in placement size label packages docclass classopts {
            local _tx_`_f' `"`r(`_f')'"'
        }
        * captionleft, captionbelow and label() act on the caption: with no
        * title there is none, and the caption package is not needed.
        if strtrim(`"`macval(title)'"') == "" {
            local _capk "caption"
            local _tx_packages : list _tx_packages - _capk
        }
        forvalues _i = 1/`_tx_npreamble' {
            mata: st_local("_tx_pre`_i'", st_global("r(preamble`_i')"))
        }

        local _append = ("`append'" != "")
        local _append_existing = 0
        if `_append' {
            capture confirm file `"`using'"'
            if !_rc local _append_existing = 1
        }
        local _tt_tex_err ""
        tempfile _stage
        mata: _tt_tex_write(st_local("_stage"), st_local("using"), ///
            st_local("_vars"), `headerstart', `datastart', `dataend', ///
            "`novarnames'" != "", "`strictheaders'" != "", `_append_existing', ///
            "`keepblank'" != "", "`boldrows'", "`spans'")
        if `"`_tt_tex_err'"' != "" {
            noisily display as error `"`_tt_tex_err'"'
            noisily display as error "nothing was written"
            exit 198
        }
        local _n_body = `_tt_tex_nbody'
        * A complete document receives the table before its \end{document}
        * line; appending after it would compile with the table silently
        * dropped.
        local _enddoc = 0
        if `_append_existing' {
            mata: st_local("_enddoc", strofreal(_tt_tex_enddoc(st_local("using"))))
        }
        if "`document'" != "" & `_append_existing' & !`_enddoc' {
            noisily display as error `"texdocument: the existing LaTeX file has no \end{document} line, so it is not a complete document; drop texdocument to append the table to it"'
            noisily display as error "nothing was written"
            exit 198
        }
        tempfile _final
        if `_enddoc' {
            mata: _tt_tex_insert(st_local("_stage"), st_local("using"), ///
                st_local("_final"), `_enddoc', "booktabs `_tx_packages'")
            quietly copy `"`_final'"' `"`using'"', replace
        }
        else if "`document'" != "" {
            mata: _tt_tex_wrap(st_local("_stage"), st_local("_final"))
            quietly copy `"`_final'"' `"`using'"', replace
        }
        else if `_append' {
            mata: _tt_tex_append(st_local("_stage"), st_local("using"))
        }
        else {
            quietly copy `"`_stage'"' `"`using'"', replace
        }
        * A table-only file goes into the user's own preamble: name what the
        * layout needs beyond booktabs.
        if !`_enddoc' & "`document'" == "" & "`_tx_packages'" != "" {
            local _need ""
            foreach _pk of local _tx_packages {
                local _need "`_need' \usepackage{`_pk'}"
            }
            noisily display as text "note: this LaTeX table needs" as result "`_need'" ///
                as text " in the preamble of the document that inputs it"
        }
        * tabtools set latex: once the session file has been written by any
        * command, later session writes append to it.
        _tabtools_set_sinks texdone, path(`"`using'"')

        return scalar n_rows = `_n_body'
        return scalar n_cols = `_k'
        return local latex `"`using'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 17.0
capture mata: mata drop _tt_tex_amap()
capture mata: mata drop _tt_tex_umap()
capture mata: mata drop _tt_tex_esc()
capture mata: mata drop _tt_tex_cell()
capture mata: mata drop _tt_tex_guard()
capture mata: mata drop _tt_tex_capnum()
capture mata: mata drop _tt_tex_fn_paras()
capture mata: mata drop _tt_tex_write()
capture mata: mata drop _tt_tex_append()
capture mata: mata drop _tt_tex_code()
capture mata: mata drop _tt_tex_enddoc()
capture mata: mata drop _tt_tex_insert()
capture mata: mata drop _tt_tex_wrap()

* matastrict is a session setting: save the caller's value here and
* restore it after the block, so loading this file never leaks it.
local _tt_ms0 = c(matastrict)
mata:
mata set matastrict on

// Lines of an .ado file are macro-expanded, Mata blocks included, so the
// backslash before a dollar sign, the dollar sign and the backtick are
// spelled char(92), char(36) and char(96) wherever they occur together.

// Replacement for every ASCII byte (index = byte + 1). CR and LF are
// handled in _tt_tex_esc(); other control characters become a space.
string rowvector _tt_tex_amap()
{
    string rowvector m
    string scalar bs
    real scalar b

    bs = char(92)
    m = J(1, 128, "")
    for (b = 0; b <= 127; b++) m[b + 1] = (b < 32 | b == 127 ? " " : char(b))
    m[92 + 1]  = bs + "textbackslash{}"
    m[123 + 1] = bs + "{"
    m[125 + 1] = bs + "}"
    m[36 + 1]  = bs + char(36)
    m[38 + 1]  = bs + "&"
    m[35 + 1]  = bs + "#"
    m[37 + 1]  = bs + "%"
    m[95 + 1]  = bs + "_"
    m[94 + 1]  = bs + "textasciicircum{}"
    m[126 + 1] = bs + "textasciitilde{}"
    m[60 + 1]  = bs + "textless{}"
    m[62 + 1]  = bs + "textgreater{}"
    m[124 + 1] = bs + "textbar{}"
    // A straight double quote: OT1 has none in roman (" prints as a closing
    // curly quote and \textquotedbl needs T1), so it comes from the
    // typewriter font, which has one.
    m[34 + 1]  = bs + "texttt{" + char(34) + "}"
    return(m)
}

// Non-ASCII characters with a pdflatex rendering, keyed by their UTF-8
// bytes. Anything not listed passes through as UTF-8.
transmorphic scalar _tt_tex_umap()
{
    transmorphic scalar a
    string scalar bs, em
    string rowvector gl, gu
    real rowvector cl, cu
    real scalar i

    bs = char(92)
    em = bs + "ensuremath{" + bs
    a = asarray_create()
    asarray(a, uchar(177), em + "pm}")
    asarray(a, uchar(215), em + "times}")
    asarray(a, uchar(247), em + "div}")
    asarray(a, uchar(178), bs + "textsuperscript{2}")
    asarray(a, uchar(179), bs + "textsuperscript{3}")
    asarray(a, uchar(185), bs + "textsuperscript{1}")
    asarray(a, uchar(8211), "--")
    asarray(a, uchar(8212), "---")
    asarray(a, uchar(8722), bs + "ensuremath{-}")
    asarray(a, uchar(8805), em + "geq}")
    asarray(a, uchar(8804), em + "leq}")
    asarray(a, uchar(8800), em + "neq}")
    asarray(a, uchar(8776), em + "approx}")
    asarray(a, uchar(8594), em + "rightarrow}")
    asarray(a, uchar(8592), em + "leftarrow}")
    asarray(a, uchar(183), em + "cdot}")
    asarray(a, uchar(176), bs + "ensuremath{^" + bs + "circ}")
    asarray(a, uchar(181), em + "mu}")
    asarray(a, uchar(8230), bs + "ldots{}")
    asarray(a, uchar(8216), char(96))
    asarray(a, uchar(8217), char(39))
    asarray(a, uchar(8220), char(96) + char(96))
    asarray(a, uchar(8221), char(39) + char(39))
    asarray(a, uchar(160), bs + "nobreakspace{}")
    asarray(a, uchar(8224), bs + "dag{}")
    asarray(a, uchar(8225), bs + "ddag{}")
    asarray(a, uchar(167), bs + "S{}")
    asarray(a, uchar(8226), bs + "textbullet{}")
    // spaces; zero-width characters are dropped
    asarray(a, uchar(8194), bs + "enspace{}")
    asarray(a, uchar(8195), bs + "quad{}")
    asarray(a, uchar(8201), bs + ",")
    asarray(a, uchar(8202), bs + ",")
    asarray(a, uchar(8239), bs + ",")
    asarray(a, uchar(8203), "")
    asarray(a, uchar(65279), "")
    // primes, symbols, arrows, signs (textcomp symbols are in the LaTeX
    // kernel since 2020)
    asarray(a, uchar(8242), bs + "ensuremath{" + char(39) + "}")
    asarray(a, uchar(8243), bs + "ensuremath{" + char(39) + char(39) + "}")
    asarray(a, uchar(8734), em + "infty}")
    asarray(a, uchar(8727), em + "ast}")
    asarray(a, uchar(8730), em + "surd}")
    asarray(a, uchar(8240), bs + "textperthousand{}")
    asarray(a, uchar(189), bs + "textonehalf{}")
    asarray(a, uchar(188), bs + "textonequarter{}")
    asarray(a, uchar(190), bs + "textthreequarters{}")
    asarray(a, uchar(174), bs + "textregistered{}")
    asarray(a, uchar(8482), bs + "texttrademark{}")
    asarray(a, uchar(169), bs + "textcopyright{}")
    asarray(a, uchar(172), em + "neg}")
    asarray(a, uchar(182), bs + "P{}")
    asarray(a, uchar(8658), em + "Rightarrow}")
    asarray(a, uchar(8593), em + "uparrow}")
    asarray(a, uchar(8595), em + "downarrow}")
    asarray(a, uchar(8596), em + "leftrightarrow}")
    asarray(a, uchar(8723), em + "mp}")
    asarray(a, uchar(8801), em + "equiv}")
    asarray(a, uchar(8733), em + "propto}")

    // Greek: only letters with a LaTeX math command (no omicron, no
    // capitals that look Latin). U+03B5 and U+03C6 are the shapes LaTeX
    // calls varepsilon and varphi; U+03F5 and U+03D5 are epsilon and phi.
    cl = (945, 946, 947, 948, 949, 950, 951, 952, 953, 954, 955, 956, 957,
        958, 960, 961, 962, 963, 964, 965, 966, 967, 968, 969,
        977, 981, 982, 1009, 1013)
    gl = ("alpha", "beta", "gamma", "delta", "varepsilon", "zeta", "eta",
        "theta", "iota", "kappa", "lambda", "mu", "nu", "xi", "pi", "rho",
        "varsigma", "sigma", "tau", "upsilon", "varphi", "chi", "psi",
        "omega", "vartheta", "phi", "varpi", "varrho", "epsilon")
    for (i = 1; i <= cols(cl); i++) asarray(a, uchar(cl[i]), em + gl[i] + "}")
    cu = (915, 916, 920, 923, 926, 928, 931, 933, 934, 936, 937)
    gu = ("Gamma", "Delta", "Theta", "Lambda", "Xi", "Pi", "Sigma",
        "Upsilon", "Phi", "Psi", "Omega")
    for (i = 1; i <= cols(cu); i++) asarray(a, uchar(cu[i]), em + gu[i] + "}")
    return(a)
}

// Escape text for a LaTeX cell, caption or note: one left-to-right pass
// over the bytes; a UTF-8 sequence is looked up whole. CR, LF and CRLF
// become one space. Bytes that are not valid UTF-8 lead bytes pass through.
// Text renders as typed: where one piece ends in "-" and the next starts
// with "-", one ends in an apostrophe or backtick and the next starts with
// the same character, or one ends in "?" or "!" and the next starts with a
// backtick, an empty group goes between them, so "1--2" is not an en dash,
// two apostrophes are not a closing double quote and "?" before a backtick
// is not an inverted question mark. A piece is one input character's
// replacement, so the "--" an en dash maps to (and the quote pair a curly
// double quote maps to) stays a ligature. A single apostrophe or backtick
// still prints as a curly single quote, the OT1 rendering.
string scalar _tt_tex_esc(string scalar s, string rowvector amap,
    transmorphic scalar umap)
{
    real rowvector b
    string rowvector out
    string scalar seq, piece, last, first
    real scalar i, n, c, len, m

    if (s == "") return("")
    b = ascii(s)
    n = cols(b)
    out = J(1, n, "")
    m = 0
    i = 1
    last = ""
    while (i <= n) {
        c = b[i]
        if (c < 128) {
            if (c == 13 & i < n) {
                if (b[i + 1] == 10) i++
            }
            piece = amap[c + 1]
            i++
        }
        else {
            len = (c >= 240 ? 4 : (c >= 224 ? 3 : (c >= 192 ? 2 : 1)))
            if (i + len - 1 > n) len = 1
            seq = substr(s, i, len)
            piece = (asarray_contains(umap, seq) ? asarray(umap, seq) : seq)
            i = i + len
        }
        // a dropped (zero-width) character neither breaks nor joins
        if (piece == "") continue
        first = substr(piece, 1, 1)
        if ((last == "-" & first == "-") |
            (last == char(39) & first == char(39)) |
            (last == char(96) & first == char(96)) |
            ((last == "?" | last == "!") & first == char(96))) piece = "{}" + piece
        m++
        out[m] = piece
        last = substr(piece, -1, 1)
    }
    return(m ? invtokens(out[|1 \ m|], "") : "")
}

// Untrimmed display text of observation i of variable index j: a string
// cell as stored, a numeric cell in its display format with the Markdown
// writer's negative-zero cleanup, a missing value as "".
string scalar _tt_tex_cell(real scalar j, real scalar i)
{
    real scalar x

    if (st_isstrvar(j)) return(st_sdata(i, j))
    x = st_data(i, j)
    if (x >= .) return("")
    return(strtrim(ustrregexra(strofreal(x, st_varformat(j)), "-(?=[0.,]+\z)", "")))
}

// A tabular row that begins with "[" or "*" would be read as the optional
// argument of the preceding \\, \toprule, \midrule or \addlinespace (or as
// the star of \\*): an empty group in front ends that look-ahead.
string scalar _tt_tex_guard(string scalar line)
{
    string scalar c
    c = substr(line, 1, 1)
    return(c == "[" | c == "*" ? "{}" + line : line)
}

// Caption text: title less one leading table-number prefix (see the header
// comment). Unchanged when nothing matches or nothing would be left.
string scalar _tt_tex_capnum(string scalar title)
{
    string scalar rest

    rest = ustrregexra(title, "^(?i:table)\s+[A-Za-z]?[0-9]+[A-Za-z]?" +
        "(?:\.(?=\s|\z)|:|\s+(?:-{1,3}|[" + uchar(8211) + uchar(8212) + "]))\s*", "")
    return(strtrim(rest) == "" ? title : rest)
}

// Footnote paragraphs: split on the literal token " \ " (space, backslash,
// space); pieces are trimmed and empty pieces dropped. Same rule in every
// tabtools writer.
string colvector _tt_tex_fn_paras(string scalar s)
{
    string colvector out
    string scalar rest, piece
    real scalar pos

    if (!strpos(s, " " + char(92) + " ")) return(strtrim(s))
    out = J(0, 1, "")
    rest = s
    while ((pos = strpos(rest, " " + char(92) + " ")) > 0) {
        piece = strtrim(substr(rest, 1, pos - 1))
        if (piece != "") out = out \ piece
        rest = substr(rest, pos + 3, .)
    }
    piece = strtrim(rest)
    if (piece != "") out = out \ piece
    return(out)
}

// Build the whole LaTeX table and write it to the stage file. On a spans()
// violation nothing is written and local _tt_tex_err holds the message;
// otherwise local _tt_tex_nbody holds the number of body rows written.
void _tt_tex_write(string scalar stage, string scalar target,
    string scalar varlist, real scalar hs, real scalar ds, real scalar de,
    real scalar novarnames, real scalar strict, real scalar lead_blank,
    real scalar keepblank, string scalar boldrows, string scalar spans)
{
    string rowvector vars, amap, cells
    string colvector out, paras, prior, cap
    string rowvector pk
    string matrix H
    string scalar bs, eol, line, txt, raw, title, foot, stem, label, trip,
        rules, err
    real rowvector idx, bold, sp
    real matrix S, owner
    real scalar k, nobs, hend, nh, nsp, t, r, c1, c2, h, c, j, i, last, n,
        body_end, has_text, pending, started, nbody, fh, isbold, ntab, isstr,
        stubonly, capbelow, fit
    transmorphic scalar umap

    bs = char(92)
    eol = " " + bs + bs
    st_local("_tt_tex_err", "")
    st_local("_tt_tex_nbody", "0")
    vars = tokens(varlist)
    k = cols(vars)
    idx = J(1, k, .)
    for (j = 1; j <= k; j++) idx[j] = st_varindex(vars[j])
    nobs = st_nobs()
    amap = _tt_tex_amap()
    umap = _tt_tex_umap()

    // Header block: observations hs .. min(ds - 1, nobs).
    hend = min((ds - 1, nobs))
    nh = (!novarnames & hs <= hend ? hend - hs + 1 : 0)
    H = J(nh, k, "")
    for (h = 1; h <= nh; h++) {
        for (j = 1; j <= k; j++) H[h, j] = strtrim(_tt_tex_cell(idx[j], hs + h - 1))
    }

    // spans(): validate every triple before anything is built.
    sp = (spans != "" ? strtoreal(tokens(spans)) : J(1, 0, .))
    if (mod(cols(sp), 3)) {
        st_local("_tt_tex_err", "spans() takes triples (row c1 c2); " +
            strofreal(cols(sp)) + " numbers were given")
        return
    }
    nsp = cols(sp) / 3
    S = J(nsp, 3, .)
    owner = J(nh, k, 0)
    err = ""
    for (t = 1; t <= nsp & err == ""; t++) {
        r = sp[3 * t - 2]
        c1 = sp[3 * t - 1]
        c2 = sp[3 * t]
        S[t, .] = (r, c1, c2)
        trip = "spans() triple (" + strofreal(r) + " " + strofreal(c1) +
            " " + strofreal(c2) + ")"
        if (nh == 0) {
            err = trip + ": the table has no header rows"
        }
        else if (r < hs | r > hend) {
            err = trip + ": row " + strofreal(r) + " is not a header row (" +
                strofreal(hs) + " to " + strofreal(hend) + ")"
        }
        else if (c1 < 1 | c2 < c1 | c2 > k) {
            err = trip + ": columns must satisfy 1 <= c1 <= c2 <= " +
                strofreal(k)
        }
        else {
            h = r - hs + 1
            for (c = c1; c <= c2 & err == ""; c++) {
                if (owner[h, c]) {
                    n = owner[h, c]
                    err = trip + " overlaps spans() triple (" +
                        strofreal(S[n, 1]) + " " + strofreal(S[n, 2]) + " " +
                        strofreal(S[n, 3]) + ") in row " + strofreal(r)
                }
                else if (c > c1 & H[h, c] != "" & H[h, c] != H[h, c1]) {
                    err = trip + ": column " + strofreal(c) +
                        " of row " + strofreal(r) +
                        " is not blank and differs from the spanned text in column " +
                        strofreal(c1)
                }
                else owner[h, c] = t
            }
        }
    }
    if (err != "") {
        st_local("_tt_tex_err", err)
        return
    }

    out = J(0, 1, "")
    if (lead_blank) out = out \ ""
    out = out \ ("% tabtools LaTeX table; requires " + bs + "usepackage{booktabs}")
    pk = tokens(st_local("_tx_packages"))
    if (cols(pk)) {
        out = out \ ("% texopts() also requires " + bs + "usepackage{" +
            invtokens(pk, "} " + bs + "usepackage{") + "}")
    }
    if (st_local("_tx_landscape") == "1") out = out \ (bs + "begin{landscape}")
    out = out \ (bs + "begin{table}[" + st_local("_tx_placement") + "]")
    if (st_local("_tx_nocentering") != "1") out = out \ (bs + "centering")

    cap = J(0, 1, "")
    title = strtrim(st_local("title"))
    if (title != "") {
        stem = pathrmsuffix(pathbasename(target))
        stem = ustrregexra(stem, "[^A-Za-z0-9_:.-]", "-")
        ntab = 1
        if (lead_blank) {
            fh = _fopen(target, "r")
            if (fh >= 0) {
                fclose(fh)
                prior = cat(target)
                for (i = 1; i <= rows(prior); i++) {
                    if (substr(prior[i], 1, 13) == bs + "begin{table}") ntab++
                }
            }
        }
        label = "tab:" + stem + (ntab > 1 ? "-" + strofreal(ntab) : "")
        if (st_local("_tx_label") != "") label = st_local("_tx_label")
        if (st_local("_tx_captionleft") == "1") {
            cap = cap \ (bs + "captionsetup{justification=raggedright,singlelinecheck=false}")
        }
        cap = cap \ (bs + "caption{" + _tt_tex_esc(_tt_tex_capnum(title), amap, umap) + "}")
        cap = cap \ (bs + "label{" + label + "}")
    }
    capbelow = (st_local("_tx_captionbelow") == "1")
    if (!capbelow) out = out \ cap

    if (st_local("_tx_size") != "") out = out \ (bs + st_local("_tx_size"))
    fit = (st_local("_tx_fit") == "1")
    // shrink to the line width only when wider; never enlarge
    if (fit) out = out \ (bs + "resizebox{" + bs + "ifdim" + bs + "width>" + bs +
        "linewidth" + bs + "linewidth" + bs + "else" + bs + "width" + bs + "fi}{!}{%")
    out = out \ (bs + "begin{tabular}{l" + (k - 1) * "c" + "}") \ (bs + "toprule")

    for (h = 1; h <= nh; h++) {
        last = (h == nh)
        cells = J(1, 0, "")
        rules = ""
        c = 1
        while (c <= k) {
            txt = H[h, c]
            if (last & txt == "" & !strict) {
                txt = st_varlabel(vars[c])
                if (txt == "") txt = vars[c]
            }
            t = owner[h, c]
            if (t) {
                n = S[t, 3] - S[t, 2] + 1
                cells = cells, (bs + "multicolumn{" + strofreal(n) + "}{c}{" +
                    _tt_tex_esc(txt, amap, umap) + "}")
                if (!last) {
                    rules = rules + (rules != "" ? " " : "") + bs +
                        "cmidrule(lr){" + strofreal(S[t, 2]) + "-" +
                        strofreal(S[t, 3]) + "}"
                }
                c = S[t, 3] + 1
            }
            else {
                cells = cells, _tt_tex_esc(txt, amap, umap)
                c++
            }
        }
        out = out \ _tt_tex_guard(invtokens(cells, " & ") + eol)
        if (rules != "") out = out \ rules
    }
    if (nh) out = out \ (bs + "midrule")

    // Body. A row blank in every column is a spacer: \addlinespace between
    // text rows (leading and trailing ones dropped, runs collapsed), or an
    // empty row with keepblank. Column 1's leading spaces are the stub
    // hierarchy: \hspace*{0.5em} per space before the escaped text.
    bold = (boldrows != "" ? strtoreal(tokens(boldrows)) : J(1, 0, .))
    nbody = 0
    pending = 0
    started = 0
    body_end = (de < 0 ? nobs : min((de, nobs)))
    for (i = ds; i <= body_end; i++) {
        cells = J(1, k, "")
        has_text = 0
        isbold = (cols(bold) > 0 ? any(bold :== i) : 0)
        for (j = 1; j <= k; j++) {
            raw = _tt_tex_cell(idx[j], i)
            txt = strtrim(raw)
            if (txt == "") continue
            has_text = 1
            isstr = st_isstrvar(idx[j])
            cells[j] = _tt_tex_esc(txt, amap, umap)
            if (isbold) cells[j] = bs + "textbf{" + cells[j] + "}"
            if (j == 1 & isstr) {
                n = strlen(raw) - strlen(strltrim(raw))
                if (n > 0) cells[j] = bs + "hspace*{" + strofreal(n * 0.5) +
                    "em}" + cells[j]
            }
        }
        if (has_text) {
            if (pending & started) out = out \ (bs + "addlinespace")
            pending = 0
            started = 1
            // Text in column 1 only: one cell across the row. (Mata's &
            // evaluates both sides, so k > 1 guards the subscript first.)
            stubonly = 0
            if (k > 1) stubonly = (cells[1] != "" & all(cells[|2 \ k|] :== ""))
            if (stubonly) {
                out = out \ (bs + "multicolumn{" + strofreal(k) + "}{l}{" +
                    cells[1] + "}" + eol)
            }
            else out = out \ _tt_tex_guard(invtokens(cells, " & ") + eol)
            nbody++
        }
        else if (keepblank) {
            out = out \ ((k - 1) * "& " + bs + bs)
            nbody++
        }
        else pending = 1
    }
    out = out \ (bs + "bottomrule") \ (bs + "end{tabular}" + (fit ? "}" : ""))

    foot = st_local("footnote")
    paras = (strtrim(foot) != "" ? _tt_tex_fn_paras(foot) : J(0, 1, ""))
    if (rows(paras)) {
        out = out \ (bs + "par" + bs + "smallskip")
        out = out \ ("{" + bs + "footnotesize" + bs + "raggedright")
        for (i = 1; i <= rows(paras); i++) {
            out = out \ (_tt_tex_esc(paras[i], amap, umap) + bs + "par" +
                (i == rows(paras) ? "}" : ""))
        }
    }
    if (capbelow) out = out \ cap
    out = out \ (bs + "end{table}")
    if (st_local("_tx_landscape") == "1") out = out \ (bs + "end{landscape}")

    fh = fopen(stage, "w")
    for (i = 1; i <= rows(out); i++) fput(fh, out[i])
    fclose(fh)
    st_local("_tt_tex_nbody", strofreal(nbody))
}

// Append the staged table to target (created when absent). The stage is
// complete before target is opened.
void _tt_tex_append(string scalar stage, string scalar target)
{
    string colvector lines
    real scalar fh, i

    lines = cat(stage)
    fh = fopen(target, "a")
    for (i = 1; i <= rows(lines); i++) fput(fh, lines[i])
    fclose(fh)
}

// A line without its comment: from the first % not escaped as \%.
string scalar _tt_tex_code(string scalar line)
{
    return(ustrregexra(line, "(?<!" + char(92) + char(92) + ")%.*$", ""))
}

// Line number of the last line of target that is \end{document} (blanks
// and a trailing comment allowed), or 0.
real scalar _tt_tex_enddoc(string scalar target)
{
    string colvector lines
    real scalar i

    lines = cat(target)
    for (i = rows(lines); i >= 1; i--) {
        if (strtrim(_tt_tex_code(lines[i])) == char(92) + "end{document}") return(i)
    }
    return(0)
}

// Write target with the staged table inserted before line at (its
// \end{document}) to out; the caller copies out over target.
void _tt_tex_insert(string scalar stage, string scalar target,
    string scalar out, real scalar at, string scalar pkgs)
{
    string colvector lines, add, miss
    string rowvector need, have
    string scalar bs, pat, code
    real scalar fh, i, j, b, p

    lines = cat(target)
    add = cat(stage)
    // Packages the table needs that the preamble does not load go in just
    // before \begin{document} (first such line before \end{document}).
    bs = char(92)
    b = 0
    for (i = 1; i < at; i++) {
        code = strtrim(_tt_tex_code(lines[i]))
        if (substr(code, 1, 16) == bs + "begin{document}") {
            b = i
            break
        }
    }
    miss = J(0, 1, "")
    if (b) {
        have = J(1, 0, "")
        pat = bs + bs + "(usepackage|RequirePackage)[ ]*(" + bs + "[[^" + bs +
            "]]*" + bs + "])?[ ]*" + bs + "{([^}]*)" + bs + "}"
        // every \usepackage on a line, comments excluded
        for (i = 1; i < b; i++) {
            code = _tt_tex_code(lines[i])
            while (ustrregexm(code, pat)) {
                have = have, tokens(subinstr(ustrregexs(3), ",", " "))
                code = usubstr(code, ustrpos(code, ustrregexs(0)) +
                    ustrlen(ustrregexs(0)), .)
            }
        }
        need = tokens(pkgs)
        for (p = 1; p <= cols(need); p++) {
            if (!anyof(have, need[p])) {
                miss = miss \ (bs + "usepackage{" + need[p] + "}")
                have = have, need[p]
            }
        }
    }
    // one blank line between tables: drop the stage's leading blank when
    // the line above \end{document} is already blank
    j = 1
    if (at > 1) {
        if (strtrim(lines[at - 1]) == "") {
            while (j <= rows(add)) {
                if (add[j] != "") break
                j++
            }
        }
    }
    fh = fopen(out, "w")
    for (i = 1; i < at; i++) {
        if (i == b) {
            for (p = 1; p <= rows(miss); p++) fput(fh, miss[p])
        }
        fput(fh, lines[i])
    }
    for (i = j; i <= rows(add); i++) fput(fh, add[i])
    fput(fh, "")
    for (i = at; i <= rows(lines); i++) fput(fh, lines[i])
    fclose(fh)
}

// Write the staged table to out as a complete document.
void _tt_tex_wrap(string scalar stage, string scalar out)
{
    string colvector add
    string rowvector pk
    string scalar bs, copts
    real scalar fh, i, np

    bs = char(92)
    add = cat(stage)
    copts = st_local("_tx_classopts")
    pk = tokens(st_local("_tx_packages"))
    np = strtoreal(st_local("_tx_npreamble"))
    fh = fopen(out, "w")
    fput(fh, bs + "documentclass" + (copts != "" ? "[" + copts + "]" : "") +
        "{" + st_local("_tx_docclass") + "}")
    fput(fh, bs + "usepackage{booktabs}")
    for (i = 1; i <= cols(pk); i++) fput(fh, bs + "usepackage{" + pk[i] + "}")
    for (i = 1; i <= np; i++) fput(fh, st_local("_tx_pre" + strofreal(i)))
    fput(fh, bs + "begin{document}")
    fput(fh, "")
    for (i = 1; i <= rows(add); i++) fput(fh, add[i])
    fput(fh, "")
    fput(fh, bs + "end{document}")
    fclose(fh)
}

end
mata: mata set matastrict `_tt_ms0'
