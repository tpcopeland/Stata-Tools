*! qa-lib _qa_parity 1.0.0 sha256:77f5af8c04598be16fd9ab24bd1f04d7f921ea92fd7945bb3124838c0d381650
* _qa_parity.do -- one quantity, every sink
*
* Load from a suite with: do "`qa_dir'/_qa_parity.do"
*
* A command that writes the same decision to several sinks (r()/e(), the
* console, a frame, CSV/Markdown, a workbook, a graph) must write the same
* value to each, or withhold it everywhere. This asserts that for one value.
*
* API
*   qa_surface_parity, expect(exp | withheld) [name(text) tol(#)
*       textscale(#) result(exp) log(file) logregex(regex)
*       frame(frame var obs) csv(file row col) md(file row col)
*       xlsx(file sheet cell) serset(# var obs)]
*
*   expect() the oracle value (an expression, e.g. a %21x literal or a
*                scalar), or the word withheld. Evaluated first, before any
*                sink is read, so r() may be used.
*   result() r()/e() sink, an expression such as r(share) or
*                el(e(b),1,1) (no spaces); also evaluated first.
*   log()/logregex() console sink: the first line of the (closed) text log
*                that matches the ICU regex. With a capture group the sink is
*                group 1, otherwise the whole line. log close clears r():
*                copy the r() value into a scalar before closing the log.
*   frame() a cell of a frame.
*   csv()/md() a cell of a CSV file (RFC 4180, row 1 = header line) or a
*                Markdown table (row 1 = header row; separator lines skipped).
*   xlsx() a workbook cell read with import excel in a temporary frame
*                (no Python needed); a cell outside the used range is empty.
*   serset() a value of graph serset # (serset use in a temporary frame).
*
* Comparison
*   Numeric sinks (result, frame, workbook number, serset) must be
*   non-missing and within reldif tol (default 1e-10) of expect. Text sinks
*   (console, CSV, Markdown, workbook text, string frame cells) must contain
*   a number; the first number (1,234.5 and 1.2e-05 forms accepted) times
*   textscale (default 1; 0.01 for percentages) must be within half a unit of
*   its last displayed digit of expect. An empty or absent sink fails.
*   withheld: result() and numeric sinks must be missing, text sinks must
*   hold no number, and empty or absent sinks pass -- a withheld value is
*   never a number anywhere.
*
* Errors: rc 9 when any sink disagrees (every disagreeing sink is listed,
* each named by its kind and address); rc 198 for bad arguments or no sink;
* rc 601 for a missing file or worksheet. r() is left as found.
*
* Deliberately NOT done: locating a sink (the suite names the cell), reading
* .docx/.tex/.smcl, or interpreting labelled text such as "p < 0.001" (the
* number found is 0.001; name a different cell or regex group).

capture program drop qa_surface_parity
program define qa_surface_parity
    version 16.0
    syntax , EXPect(string) [NAME(string) TOL(real 1e-10) TEXTScale(real 1) ///
        RESult(string) LOG(string) LOGRegex(string) FRAME(string) CSV(string) ///
        MD(string) XLSX(string) SERset(string)]
    local withheld = (`"`expect'"' == "withheld")
    tempname ev rv rhold fr
    if `withheld' scalar `ev' = .
    else {
        scalar `ev' = `expect'
        if missing(`ev') {
            display as error "qa_surface_parity: expect() is missing; use expect(withheld)"
            exit 198
        }
    }
    if `"`result'"' != "" scalar `rv' = `result'
    if (`"`log'"' == "") != (`"`logregex'"' == "") {
        display as error "qa_surface_parity: log() and logregex() go together"
        exit 198
    }
    if `"`result'`log'`frame'`csv'`md'`xlsx'`serset'"' == "" {
        display as error "qa_surface_parity: name at least one sink"
        exit 198
    }
    if `"`name'"' == "" local name = cond(`withheld', "withheld value", `"`expect'"')

    * Validate every sink address before r() is held.
    foreach s in csv md xlsx serset frame {
        if `"``s''"' == "" continue
        local n : word count ``s''
        if `n' != 3 {
            display as error "qa_surface_parity: `s'() takes three arguments"
            exit 198
        }
    }
    if `"`log'"' != "" confirm file `"`log'"'
    foreach s in csv md {
        if `"``s''"' == "" continue
        gettoken `s'_file rest : `s'
        gettoken `s'_row rest : rest
        gettoken `s'_col rest : rest
        confirm file `"``s'_file'"'
        confirm integer number ``s'_row'
        confirm integer number ``s'_col'
    }
    if `"`frame'"' != "" {
        gettoken fr_name rest : frame
        gettoken fr_var rest : rest
        gettoken fr_obs rest : rest
        confirm integer number `fr_obs'
        frame `fr_name': confirm variable `fr_var', exact
    }
    if `"`xlsx'"' != "" {
        gettoken x_file rest : xlsx
        gettoken x_sheet rest : rest
        gettoken x_cell rest : rest
        confirm file `"`x_file'"'
    }
    if `"`serset'"' != "" {
        gettoken ss_id rest : serset
        gettoken ss_var rest : rest
        gettoken ss_obs rest : rest
        confirm integer number `ss_id'
        confirm integer number `ss_obs'
    }

    _return hold `rhold'
    mata: _qa_par_reset()
    if `"`result'"' != "" mata: _qa_par_add(`"result `result'"', "num", st_numscalar("`rv'"), "")
    if `"`log'"' != "" mata: _qa_par_log(st_local("log"), st_local("logregex"))
    foreach s in csv md {
        if `"``s''"' == "" continue
        mata: _qa_par_table(st_local("`s'_file"), ``s'_row', ``s'_col', "`s'")
    }
    if `"`frame'"' != "" {
        frame `fr_name': mata: _qa_par_cell("frame `fr_name' `fr_var'[`fr_obs']", "`fr_var'", `fr_obs')
    }
    local rc 0
    if `"`xlsx'"' != "" {
        frame create `fr'
        capture frame `fr': import excel using `"`x_file'"', sheet(`"`x_sheet'"') ///
            cellrange(`x_cell':`x_cell') clear
        local rc = _rc
        if `rc' == 198 {
            mata: _qa_par_add(`"xlsx `x_sheet'!`x_cell'"', "empty", ., "")
            local rc 0
        }
        else if `rc' == 601 {
            display as error `"qa_surface_parity: worksheet `x_sheet' not found in `x_file'"'
        }
        else if !`rc' frame `fr': mata: _qa_par_first(`"xlsx `x_sheet'!`x_cell'"')
        capture frame drop `fr'
    }
    if `"`serset'"' != "" & !`rc' {
        quietly serset
        local cur = r(id)
        frame create `fr'
        capture noisily frame `fr': _qa_par_serset `ss_id' `ss_var' `ss_obs'
        local rc = _rc
        capture frame drop `fr'
        if !inlist("`cur'", "", ".") capture serset set `cur'
    }
    if !`rc' {
        mata: _qa_par_judge(`withheld', st_numscalar("`ev'"), `tol', `textscale', st_local("name"))
    }
    capture mata: rmexternal("__qa_parity")
    capture mata: rmexternal("__qa_parityv")
    _return restore `rhold'
    if `rc' exit `rc'
    if `nbad' exit 9
end

capture program drop _qa_par_serset
program define _qa_par_serset
    args id var obs
    serset set `id'
    serset use, clear
    confirm variable `var', exact
    mata: _qa_par_cell("serset `id' `var'[`obs']", "`var'", `obs')
end

capture mata: mata drop _qa_par_reset()
capture mata: mata drop _qa_par_add()
capture mata: mata drop _qa_par_log()
capture mata: mata drop _qa_par_fields()
capture mata: mata drop _qa_par_table()
capture mata: mata drop _qa_par_cell()
capture mata: mata drop _qa_par_first()
capture mata: mata drop _qa_par_num()
capture mata: mata drop _qa_par_fmt()
capture mata: mata drop _qa_par_judge()

mata:
// Sinks collected for one call: label, kind (num text empty absent), value, text.
void _qa_par_reset()
{
    pointer(transmorphic scalar) scalar p

    if ((p = findexternal("__qa_parity")) == NULL) p = crexternal("__qa_parity")
    *p = J(0, 3, "")
    if ((p = findexternal("__qa_parityv")) == NULL) p = crexternal("__qa_parityv")
    *p = J(0, 1, .)
}

void _qa_par_add(string scalar label, string scalar kind, real scalar v,
    string scalar text)
{
    pointer(transmorphic scalar) scalar p

    p = findexternal("__qa_parity")
    *p = *p \ (label, kind, text)
    p = findexternal("__qa_parityv")
    *p = *p \ v
}

void _qa_par_log(string scalar path, string scalar re)
{
    string colvector lines
    real scalar i

    lines = cat(path)
    for (i = 1; i <= rows(lines); i++) {
        if (ustrregexm(lines[i], re)) {
            if (strpos(re, "(") & ustrregexs(1) != "") {
                _qa_par_add("console", "text", ., ustrregexs(1))
            }
            else _qa_par_add("console", "text", ., lines[i])
            return
        }
    }
    _qa_par_add("console", "absent", ., "no line matches " + re)
}

// Cells of one CSV record (RFC 4180, no embedded newlines) or Markdown row.
string rowvector _qa_par_fields(string scalar line, string scalar kind)
{
    string rowvector out
    string scalar cur, c, t
    real scalar i, n, inq

    if (kind == "md") {
        t = strtrim(subinstr(line, "\|", char(1)))
        if (substr(t, 1, 1) == "|") t = substr(t, 2, .)
        if (substr(t, strlen(t), 1) == "|") t = substr(t, 1, strlen(t) - 1)
        out = strtrim(subinstr(tokens(t, "|"), char(1), "|"))
        return(select(out, out :!= "|"))
    }
    out = J(1, 0, "")
    cur = ""
    inq = 0
    n = strlen(line)
    for (i = 1; i <= n; i++) {
        c = substr(line, i, 1)
        if (inq) {
            if (c == char(34)) {
                if (substr(line, i + 1, 1) == char(34)) {
                    cur = cur + c
                    i++
                }
                else inq = 0
            }
            else cur = cur + c
        }
        else if (c == char(34)) inq = 1
        else if (c == ",") {
            out = out, cur
            cur = ""
        }
        else cur = cur + c
    }
    return((out, cur))
}

void _qa_par_table(string scalar path, real scalar row, real scalar col,
    string scalar kind)
{
    string colvector lines
    string rowvector f
    string scalar label
    real colvector keep
    real scalar i

    label = kind + " " + path + " row " + strofreal(row) + " col " + strofreal(col)
    lines = cat(path)
    if (kind == "md") {
        keep = J(rows(lines), 1, 0)
        for (i = 1; i <= rows(lines); i++) {
            keep[i] = ustrregexm(lines[i], "^\s*\|") &
                !ustrregexm(lines[i], "^[\s|:-]*-{3,}[\s|:-]*$")
        }
        lines = select(lines, keep)
    }
    if (row < 1 | row > rows(lines)) {
        _qa_par_add(label, "absent", ., "no such row")
        return
    }
    f = _qa_par_fields(lines[row], kind)
    if (col < 1 | col > cols(f)) {
        _qa_par_add(label, "absent", ., "no such column")
        return
    }
    if (strtrim(f[col]) == "") _qa_par_add(label, "empty", ., "")
    else _qa_par_add(label, "text", ., f[col])
}

void _qa_par_cell(string scalar label, string scalar var, real scalar obs)
{
    string scalar s
    real scalar v

    if (obs < 1 | obs > st_nobs()) {
        _qa_par_add(label, "absent", ., "no such observation")
        return
    }
    if (st_isstrvar(var)) {
        s = st_sdata(obs, var)
        if (strtrim(s) == "") _qa_par_add(label, "empty", ., "")
        else _qa_par_add(label, "text", ., s)
    }
    else {
        v = st_data(obs, var)
        _qa_par_add(label, (missing(v) ? "empty" : "num"), v, "")
    }
}

void _qa_par_first(string scalar label)
{
    if (st_nvar() == 0 | st_nobs() == 0) _qa_par_add(label, "empty", ., "")
    else _qa_par_cell(label, st_varname(1), 1)
}

// First number in text and half a unit of its last displayed digit.
real rowvector _qa_par_num(string scalar text)
{
    string scalar m, mant
    real scalar e, d, j

    if (!ustrregexm(text, "[-+]?(?:(?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][-+]?[0-9]+)?")) {
        return((., .))
    }
    m = subinstr(ustrregexs(0), ",", "")
    mant = m
    e = 0
    j = max((strpos(m, "e"), strpos(m, "E")))
    if (j) {
        mant = substr(m, 1, j - 1)
        e = strtoreal(substr(m, j + 1, .))
    }
    d = (strpos(mant, ".") ? strlen(mant) - strpos(mant, ".") : 0)
    return((strtoreal(m), 0.5 * 10^(e - d)))
}

string scalar _qa_par_fmt(real scalar v)
{
    return(strtrim(strofreal(v, "%21.15g")))
}

void _qa_par_judge(real scalar withheld, real scalar ev, real scalar tol,
    real scalar scale, string scalar name)
{
    pointer(transmorphic scalar) scalar p
    string matrix s
    string colvector bad
    string scalar kind, why
    real colvector vals
    real rowvector nv
    real scalar i, v

    p = findexternal("__qa_parity")
    s = *p
    p = findexternal("__qa_parityv")
    vals = *p
    bad = J(0, 1, "")
    for (i = 1; i <= rows(s); i++) {
        kind = s[i, 2]
        v = vals[i]
        why = ""
        if (withheld) {
            if (kind == "num" & !missing(v)) why = "a number (" + _qa_par_fmt(v) + ") where the value is withheld"
            if (kind == "text") {
                nv = _qa_par_num(s[i, 3])
                if (!missing(nv[1])) why = "a number in " + char(34) + s[i, 3] + char(34) + " where the value is withheld"
            }
        }
        else if (kind == "num") {
            if (missing(v)) why = "missing where " + _qa_par_fmt(ev) + " was expected"
            else if (reldif(v, ev) > tol) {
                why = _qa_par_fmt(v) + " vs expected " + _qa_par_fmt(ev) + " (reldif " +
                    strtrim(strofreal(reldif(v, ev), "%9.3g")) + ")"
            }
        }
        else if (kind == "text") {
            nv = _qa_par_num(s[i, 3])
            if (missing(nv[1])) why = "no number in " + char(34) + s[i, 3] + char(34)
            else if (abs(nv[1] * scale - ev) > nv[2] * abs(scale) * (1 + 1e-9) + tol * abs(ev)) {
                why = char(34) + s[i, 3] + char(34) + " vs expected " + _qa_par_fmt(ev) +
                    " (display tolerance " + strtrim(strofreal(nv[2] * abs(scale), "%9.3g")) + ")"
            }
        }
        else {
            why = (kind == "empty" ? "empty" : s[i, 3]) + " where " + _qa_par_fmt(ev) + " was expected"
        }
        if (why != "") bad = bad \ (s[i, 1] + ": " + why)
    }
    st_local("nbad", strofreal(rows(bad)))
    if (rows(bad) == 0) {
        displayas("text")
        printf("qa_surface_parity [%s]: %f sink(s) agree\n", name, rows(s))
        return
    }
    displayas("error")
    printf("qa_surface_parity [%s]: %f of %f sink(s) disagree\n", name, rows(bad), rows(s))
    for (i = 1; i <= rows(bad); i++) printf("  %s\n", bad[i])
}
end
