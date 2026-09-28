*! qa-lib _qa_route_grid 1.0.0 sha256:4ba3ebd75e4789876ccb448ce3fa21b4bfd2221d8c135cbcb1d9cdc3f7b796d8
* _qa_route_grid.do -- route x condition contract grid for estimation suites
*
* Load from a suite with: do "`qa_dir'/_qa_route_grid.do"
*
* A grid enumerates inference/execution routes x sample-altering conditions.
* Every cell must end in exactly one of two states, declared up front:
*   EQUAL    the fit matched an oracle built without the package's own marker
*   REFUSED  the route was refused with the documented rc
* A cell that is skipped, never declared, exits nonzero, or returns rc 0
* without declaring an outcome is a FAIL. That is the forcing function: a new
* route or condition adds a whole row or column of cells that must be filled.
*
* API
*   qa_grid_init, routes(list) conditions(list)
*       Start a grid (replacing any earlier one). Names are words without "|".
*   qa_grid_expect route cond, equal | refused(#)
*       The contract for one cell. Declare every cell once, at the top of
*       the suite, so a reviewer reads the contract in one place. A route or
*       condition may be "*" to declare a whole row or column.
*   qa_grid_cell route cond, run(progname)
*       Runs "progname route cond" under capture noisily. The program must
*       end by calling exactly one of qa_grid_equal or qa_grid_refused.
*       Prints one line with the cell verdict; never exits nonzero itself, so
*       every cell runs. Running a cell twice is a usage error (rc 198).
*   qa_grid_equal
*   qa_grid_refused rc
*       Declare the current cell's outcome (only inside a cell program).
*       Typical refusal: capture cmd ... / if _rc { qa_grid_refused `=_rc' ... }
*   qa_grid_assert_eq a b [, tol(#) name(text)]
*   qa_grid_assert_eq A B, matrix [tol(#) name(text)]
*       a and b are names or expressions (T[1,1] and el(T, 1, 1) work);
*       blanks and commas may appear only inside () or []. Asserts both
*       sides are non-missing
*       (!matmissing() for matrices, plus conformability), then reldif /
*       mreldif <= tol (default 1e-10).
*       Exits 9 with the name and both values, which fails the cell.
*   qa_grid_assert_sample oraclevar
*       Asserts e(sample) equals the 0/1 oracle marker row by row (not just
*       in count); exits 9 with the number of disagreeing rows.
*   qa_grid_status route cond                                        rclass
*       r(status) EQUAL|REFUSED|FAIL|SKIPPED|UNDECLARED and r(reason).
*   qa_grid_receipt
*       Prints the route rows x condition columns receipt (= EQUAL,
*       R REFUSED, FAIL, - skipped, ? undeclared), every failing cell with its
*       reason, and exits 9 if any cell is not EQUAL or REFUSED.
*
* Errors: rc 9 for a failed receipt or assertion; rc 198 for usage errors
* (unknown route/condition, duplicate expectation, outcome outside a cell).
*
* Deliberately NOT done: building oracles (package-specific), choosing the
* axes, or timing cells. Grid state lives in the Mata external __qa_grid;
* qa_grid_init replaces it.

capture program drop qa_grid_init
program define qa_grid_init
    version 16.0
    syntax , ROUTEs(string) CONDitions(string)
    mata: _qa_grid_init(st_local("routes"), st_local("conditions"))
end

capture program drop qa_grid_expect
program define qa_grid_expect
    version 16.0
    gettoken route 0 : 0, parse(" ,")
    gettoken cond 0 : 0, parse(" ,")
    syntax , [EQUAL REFUSED(integer 0)]
    if ("`equal'" != "") + (`refused' != 0) != 1 {
        display as error "qa_grid_expect: give exactly one of equal or refused(#) (# nonzero)"
        exit 198
    }
    local want = cond("`equal'" != "", "equal", "refused `refused'")
    mata: _qa_grid_expect("`route'", "`cond'", "`want'")
end

capture program drop qa_grid_cell
program define qa_grid_cell
    version 16.0
    gettoken route 0 : 0, parse(" ,")
    gettoken cond 0 : 0, parse(" ,")
    syntax , RUN(name)
    mata: _qa_grid_begin("`route'", "`cond'")
    capture noisily `run' `route' `cond'
    local rc = _rc
    mata: _qa_grid_end(`rc')
end

capture program drop qa_grid_equal
program define qa_grid_equal
    version 16.0
    mata: _qa_grid_outcome("equal")
end

capture program drop qa_grid_refused
program define qa_grid_refused
    version 16.0
    args rc
    confirm integer number `rc'
    mata: _qa_grid_outcome("refused `rc'")
end

capture program drop qa_grid_assert_eq
program define qa_grid_assert_eq
    version 16.0
    mata: _qa_grid_split(st_local("0"))
    if `nargs' != 2 {
        display as error "qa_grid_assert_eq: expected two names or expressions before the comma"
        exit 198
    }
    local 0 `"`opts'"'
    syntax [, TOL(real 1e-10) NAME(string) MATrix]
    if `"`name'"' == "" local name "`a' vs `b'"
    tempname va vb
    if "`matrix'" != "" {
        matrix `va' = `a'
        matrix `vb' = `b'
        if matmissing(`va') | matmissing(`vb') {
            display as error "qa_grid_assert_eq: `name': a matrix holds missing values"
            exit 9
        }
        if rowsof(`va') != rowsof(`vb') | colsof(`va') != colsof(`vb') {
            display as error "qa_grid_assert_eq: `name': " rowsof(`va') "x" colsof(`va') ///
                " vs " rowsof(`vb') "x" colsof(`vb')
            exit 9
        }
        if mreldif(`va', `vb') > `tol' {
            display as error "qa_grid_assert_eq: `name': mreldif " ///
                strtrim(string(mreldif(`va', `vb'), "%9.3g")) " > " strtrim(string(`tol', "%9.3g"))
            exit 9
        }
        exit
    }
    scalar `va' = `a'
    scalar `vb' = `b'
    if missing(`va') | missing(`vb') {
        display as error "qa_grid_assert_eq: `name': missing value (" `va' " vs " `vb' ")"
        exit 9
    }
    if reldif(`va', `vb') > `tol' {
        * Values that agree to 15 digits are shown in %21x, where they differ.
        local sa = strtrim(string(`va', "%21.15g"))
        local sb = strtrim(string(`vb', "%21.15g"))
        if "`sa'" == "`sb'" {
            local sa : display %21x `va'
            local sb : display %21x `vb'
        }
        display as error "qa_grid_assert_eq: `name': `sa' vs `sb' (reldif " ///
            strtrim(string(reldif(`va', `vb'), "%9.3g")) " > " strtrim(string(`tol', "%9.3g")) ")"
        exit 9
    }
end

capture program drop qa_grid_assert_sample
program define qa_grid_assert_sample
    version 16.0
    syntax varname(numeric)
    tempvar es
    quietly generate byte `es' = e(sample)
    quietly count if `es' != (`varlist' != 0) | missing(`varlist')
    if r(N) {
        local bad = r(N)
        quietly count if `es'
        local ne = r(N)
        quietly count if `varlist' != 0 & !missing(`varlist')
        display as error "qa_grid_assert_sample: e(sample) disagrees with `varlist' on `bad' row(s) (e(sample) " ///
            "`ne' rows, oracle " r(N) " rows)"
        exit 9
    }
end

capture program drop qa_grid_status
program define qa_grid_status, rclass
    version 16.0
    args route cond
    mata: _qa_grid_status("`route'", "`cond'")
    return local status "`status'"
    return local reason `"`reason'"'
end

capture program drop qa_grid_receipt
program define qa_grid_receipt
    version 16.0
    mata: _qa_grid_receipt()
    if `nbad' exit 9
end

capture mata: mata drop _qa_grid_p()
capture mata: mata drop _qa_grid_get()
capture mata: mata drop _qa_grid_init()
capture mata: mata drop _qa_grid_check()
capture mata: mata drop _qa_grid_expect()
capture mata: mata drop _qa_grid_begin()
capture mata: mata drop _qa_grid_outcome()
capture mata: mata drop _qa_grid_end()
capture mata: mata drop _qa_grid_state()
capture mata: mata drop _qa_grid_status()
capture mata: mata drop _qa_grid_receipt()
capture mata: mata drop _qa_grid_split()

mata:
pointer(transmorphic scalar) scalar _qa_grid_p()
{
    pointer(transmorphic scalar) scalar p

    if ((p = findexternal("__qa_grid")) == NULL) {
        errprintf("qa_grid: no grid; call qa_grid_init first\n")
        exit(198)
    }
    return(p)
}

string scalar _qa_grid_get(string scalar key)
{
    pointer(transmorphic scalar) scalar p

    p = _qa_grid_p()
    if (!asarray_contains(*p, key)) return("")
    return(asarray(*p, key))
}

void _qa_grid_init(string scalar routes, string scalar conds)
{
    pointer(transmorphic scalar) scalar p
    string rowvector all

    all = tokens(routes), tokens(conds)
    if (cols(tokens(routes)) == 0 | cols(tokens(conds)) == 0) {
        errprintf("qa_grid_init: routes() and conditions() must be non-empty\n")
        exit(198)
    }
    if (any(strpos(all, "|")) | anyof(all, "*")) {
        errprintf("qa_grid_init: names may not contain | or be *\n")
        exit(198)
    }
    if (cols(uniqrows(tokens(routes)')') != cols(tokens(routes))
        | cols(uniqrows(tokens(conds)')') != cols(tokens(conds))) {
        errprintf("qa_grid_init: duplicate route or condition name\n")
        exit(198)
    }
    if ((p = findexternal("__qa_grid")) == NULL) p = crexternal("__qa_grid")
    *p = asarray_create()
    asarray(*p, "routes", routes)
    asarray(*p, "conds", conds)
    asarray(*p, "current", "")
}

void _qa_grid_check(string scalar route, string scalar cond)
{
    if (!anyof(tokens(_qa_grid_get("routes")), route)) {
        errprintf("qa_grid: unknown route %s\n", route)
        exit(198)
    }
    if (!anyof(tokens(_qa_grid_get("conds")), cond)) {
        errprintf("qa_grid: unknown condition %s\n", cond)
        exit(198)
    }
}

void _qa_grid_expect(string scalar route, string scalar cond, string scalar want)
{
    pointer(transmorphic scalar) scalar p
    string rowvector rs, cs
    real scalar i, j

    p = _qa_grid_p()
    rs = (route == "*" ? tokens(_qa_grid_get("routes")) : route)
    cs = (cond == "*" ? tokens(_qa_grid_get("conds")) : cond)
    for (i = 1; i <= cols(rs); i++) {
        for (j = 1; j <= cols(cs); j++) {
            _qa_grid_check(rs[i], cs[j])
            if (asarray_contains(*p, "expect|" + rs[i] + "|" + cs[j])) {
                errprintf("qa_grid_expect: cell %s x %s declared twice\n", rs[i], cs[j])
                exit(198)
            }
            asarray(*p, "expect|" + rs[i] + "|" + cs[j], want)
        }
    }
}

void _qa_grid_begin(string scalar route, string scalar cond)
{
    pointer(transmorphic scalar) scalar p
    string scalar cell

    p = _qa_grid_p()
    _qa_grid_check(route, cond)
    cell = route + "|" + cond
    if (asarray_contains(*p, "status|" + cell)) {
        errprintf("qa_grid_cell: cell %s x %s already ran\n", route, cond)
        exit(198)
    }
    if (_qa_grid_get("current") != "") {
        errprintf("qa_grid_cell: cells do not nest\n")
        exit(198)
    }
    asarray(*p, "current", cell)
    asarray(*p, "outcome|" + cell, "")
    asarray(*p, "noutcome|" + cell, "0")
}

void _qa_grid_outcome(string scalar what)
{
    pointer(transmorphic scalar) scalar p
    string scalar cell

    p = _qa_grid_p()
    cell = _qa_grid_get("current")
    if (cell == "") {
        errprintf("qa_grid_equal/qa_grid_refused: called outside qa_grid_cell\n")
        exit(198)
    }
    asarray(*p, "outcome|" + cell, what)
    asarray(*p, "noutcome|" + cell,
        strofreal(strtoreal(asarray(*p, "noutcome|" + cell)) + 1))
}

void _qa_grid_end(real scalar rc)
{
    pointer(transmorphic scalar) scalar p
    string scalar cell, want, got, status, reason
    real scalar n

    p = _qa_grid_p()
    cell = _qa_grid_get("current")
    want = _qa_grid_get("expect|" + cell)
    got = _qa_grid_get("outcome|" + cell)
    n = strtoreal(_qa_grid_get("noutcome|" + cell))
    status = "FAIL"
    if (want == "") reason = "no contract declared with qa_grid_expect"
    else if (rc) reason = "cell program exited rc " + strofreal(rc)
    else if (n == 0) reason = "rc 0 without qa_grid_equal or qa_grid_refused"
    else if (n > 1) reason = "declared " + strofreal(n) + " outcomes"
    else if (got != want) reason = "expected " + want + ", got " + got
    else {
        status = (want == "equal" ? "EQUAL" : "REFUSED")
        reason = got
    }
    asarray(*p, "status|" + cell, status)
    asarray(*p, "reason|" + cell, reason)
    asarray(*p, "current", "")
    if (status == "FAIL") {
        displayas("error")
        printf("qa_grid cell %s: FAIL: %s\n", subinstr(cell, "|", " x "), reason)
    }
    else {
        displayas("text")
        printf("qa_grid cell %s: %s\n", subinstr(cell, "|", " x "), status)
    }
}

// status and reason of one cell, including cells that never ran.
string rowvector _qa_grid_state(string scalar cell)
{
    string scalar s

    s = _qa_grid_get("status|" + cell)
    if (s != "") return((s, _qa_grid_get("reason|" + cell)))
    if (_qa_grid_get("expect|" + cell) == "") {
        return(("UNDECLARED", "no contract declared and never run"))
    }
    return(("SKIPPED", "declared " + _qa_grid_get("expect|" + cell) + " but never run"))
}

void _qa_grid_status(string scalar route, string scalar cond)
{
    string rowvector s

    _qa_grid_check(route, cond)
    s = _qa_grid_state(route + "|" + cond)
    st_local("status", s[1])
    st_local("reason", s[2])
}

void _qa_grid_receipt()
{
    string rowvector rs, cs, s
    string colvector bad
    string scalar line, sym
    real scalar i, j, wr, wc, neq, nref, nfail, nskip, nund

    rs = tokens(_qa_grid_get("routes"))
    cs = tokens(_qa_grid_get("conds"))
    wr = max((strlen(rs), 5)) + 1
    wc = max((strlen(cs), 4)) + 1
    neq = nref = nfail = nskip = nund = 0
    bad = J(0, 1, "")
    line = sprintf("%-" + strofreal(wr) + "s|", "route")
    for (j = 1; j <= cols(cs); j++) line = line + sprintf(" %-" + strofreal(wc) + "s", cs[j])
    displayas("text")
    printf("\nqa_grid receipt (= EQUAL, R REFUSED, FAIL, - skipped, ? undeclared)\n")
    printf("%s\n", line)
    for (i = 1; i <= cols(rs); i++) {
        line = sprintf("%-" + strofreal(wr) + "s|", rs[i])
        for (j = 1; j <= cols(cs); j++) {
            s = _qa_grid_state(rs[i] + "|" + cs[j])
            if (s[1] == "EQUAL") { sym = "="; neq++; }
            else if (s[1] == "REFUSED") { sym = "R"; nref++; }
            else if (s[1] == "SKIPPED") { sym = "-"; nskip++; }
            else if (s[1] == "UNDECLARED") { sym = "?"; nund++; }
            else { sym = "FAIL"; nfail++; }
            if (sym != "=" & sym != "R") {
                bad = bad \ (s[1] + " " + rs[i] + " x " + cs[j] + ": " + s[2])
            }
            line = line + sprintf(" %-" + strofreal(wc) + "s", sym)
        }
        printf("%s\n", line)
    }
    printf("cells: %f = %f EQUAL + %f REFUSED + %f FAIL + %f skipped + %f undeclared\n",
        cols(rs) * cols(cs), neq, nref, nfail, nskip, nund)
    if (rows(bad)) {
        displayas("error")
        printf("qa_grid_receipt: %f cell(s) not EQUAL or REFUSED\n", rows(bad))
        for (i = 1; i <= rows(bad); i++) printf("  %s\n", bad[i])
    }
    st_local("nbad", strofreal(rows(bad)))
}
// Split "a b [, options]" at top-level blanks and the first top-level
// comma, respecting (), [] and double quotes, so T[1,1] and el(T, 1, 1)
// arrive whole. Sets locals nargs, a, b and opts (from the comma on).
void _qa_grid_split(string scalar s)
{
    string rowvector parts
    string scalar c, cur
    real scalar i, n, depth, inq

    parts = J(1, 0, "")
    cur = ""
    depth = inq = 0
    n = strlen(s)
    for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (c == char(34)) inq = !inq
        if (!inq) {
            if (c == "(" | c == "[") depth++
            else if (c == ")" | c == "]") depth--
            else if (depth == 0 & c == ",") break
            else if (depth == 0 & (c == " " | c == char(9))) {
                if (cur != "") parts = parts, cur
                cur = ""
                continue
            }
        }
        cur = cur + c
    }
    if (cur != "") parts = parts, cur
    st_local("opts", (i <= n ? substr(s, i, .) : ""))
    st_local("nargs", strofreal(cols(parts)))
    st_local("a", (cols(parts) >= 1 ? parts[1] : ""))
    st_local("b", (cols(parts) >= 2 ? parts[2] : ""))
}
end
