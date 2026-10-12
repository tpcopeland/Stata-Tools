*! qa-lib _qa_lifecycle 1.0.0 sha256:0cd64af74c211c4a6246f2aac006ef99443855d65de370f88a0fd952d3a09f21
* _qa_lifecycle.do -- stored results, caches and files across a lifecycle
*
* Load from a suite with: do "`qa_dir'/_qa_lifecycle.do"
*
* Output must describe the fit, pool or shard it claims to describe, not an
* earlier or later one. These two scenarios make that a single call.
*
* API
*   qa_lifecycle, fita(cmd) fitb(cmd) post(cmd; cmd; ...) [refusal(#)]
*       1. runs fit A and stores it (estimates store, temporary name);
*       2. runs every postestimation command, recording its rc, every r()
*          macro/scalar/matrix, and every variable it creates (name, type
*          and %21x values), then drops those variables;
*       3. runs fit B (give it replace and a different design, support or
*          reference level);
*       4. restores A;
*       5. reruns every postestimation command and asserts it reproduces
*          step 2 exactly, or exits with refusal(#) (the documented rc for
*          "these results are no longer usable").
*       Exits 9 listing every command whose output changed or that failed
*       with an undocumented rc. Fit A, the data and e() are left as after
*       step 4 (A restored); the temporary store is dropped.
*   qa_lifecycle_pool, shard(prog) pool(prog) expect(list) [id(varlist)]
*       For pooling/sharding packages. The caller supplies two programs:
*         shard: prog label file [fail]
*                 writes the shard for label (A, B, C or D) to file; the same
*                 label must give the same draws every time. With fail it
*                 must simulate a worker that fails on this run.
*         pool: prog outfile infile [infile ...]
*                 pools the input files into outfile.
*       and declares the outcome of every scenario in expect(), as
*       scenario=accept or scenario=refuse (all seven are required):
*         A+B       pool shard files A and B into AB
*         AB        pool AB alone
*         AB+B      pool AB with its own constituent B
*         AB+A      pool AB with its own constituent A
*         AB+CD     pool AB with CD (itself pooled from C and D)
*         stale     rerun shard A with fail, then pool A and B
*         neighbour write shard A to x.dta while an unrelated x.dta.dta
*                   exists, then pool x.dta and B
*       accept means: the pool exits 0, and the output's rows are exactly the
*       distinct rows of the constituent shards, with no duplicates (so a
*       pool that re-pools a constituent must deduplicate to be accepted).
*       refuse means the pool (for neighbour: the shard) exits nonzero.
*       neighbour also requires x.dta to hold shard A and x.dta.dta to be
*       untouched. Distinctness is over id() if given, else every variable.
*       Files live in a private directory under c(tmpdir), removed at the end.
*       Exits 9 listing every scenario whose outcome differs.
*
* Errors: rc 9 for a lifecycle violation; rc 198 for bad arguments, a fit or
* first-run postestimation command that fails, a shard program that ignores
* fail, or an expect() list that omits a scenario.
*
* Deliberately NOT done: choosing fit B (the suite knows which design change
* matters), comparing console output, or timing. Graph and file outputs of
* postestimation commands are not captured; wrap them so they return r().

capture program drop qa_lifecycle
program define qa_lifecycle
    version 16.0
    syntax , FITA(string) FITB(string) POST(string) [REFusal(integer 0)]
    tempname store
    local posts ""
    local np 0
    local rest `"`post'"'
    while `"`rest'"' != "" {
        gettoken one rest : rest, parse(";")
        if `"`one'"' == ";" continue
        local one = strtrim(`"`one'"')
        if `"`one'"' == "" continue
        local ++np
        local post`np' `"`one'"'
    }
    if !`np' {
        display as error "qa_lifecycle: post() names no command"
        exit 198
    }

    capture noisily quietly `fita'
    if _rc {
        display as error "qa_lifecycle: fit A failed (rc `=_rc')"
        exit 198
    }
    quietly estimates store `store'
    mata: _qa_lc_reset()
    forvalues k = 1/`np' {
        _qa_lc_post 1 `k' `"`post`k''"'
        if `rc' {
            display as error `"qa_lifecycle: post command `k' failed on fit A (rc `rc'): `post`k''"'
            capture estimates drop `store'
            exit 198
        }
    }
    capture noisily quietly `fitb'
    if _rc {
        display as error "qa_lifecycle: fit B failed (rc `=_rc')"
        capture estimates drop `store'
        exit 198
    }
    quietly estimates restore `store'
    local nbad 0
    forvalues k = 1/`np' {
        _qa_lc_post 2 `k' `"`post`k''"'
        if `rc' {
            if `rc' == `refusal' continue
            local ++nbad
            local bad`nbad' `"post `k' (`post`k''): rc `rc' after restore, not the documented refusal`=cond(`refusal', " `refusal'", "")'"'
            continue
        }
        mata: st_local("diff", _qa_lc_diff(`k'))
        if `"`diff'"' != "" {
            local ++nbad
            local bad`nbad' `"post `k' (`post`k''): `diff'"'
        }
    }
    quietly estimates restore `store'
    quietly estimates drop `store'
    capture mata: rmexternal("__qa_lifecycle")
    if `nbad' {
        display as error "qa_lifecycle: restored fit A no longer reproduces its postestimation output: `nbad' of `np' command(s)"
        forvalues i = 1/`nbad' {
            display as error `"  `bad`i''"'
        }
        exit 9
    }
    display as text "qa_lifecycle: `np' postestimation command(s) reproduce fit A after fit B and restore"
end

* Run one post command; record rc, r() and new variables under run/k, then
* drop the new variables. Hands rc back to the caller.
capture program drop _qa_lc_post
program define _qa_lc_post
    args run k cmd
    mata: st_local("before", invtokens(st_varname(1..st_nvar())))
    * Start from an empty r(), so a command that is not rclass is judged on
    * what it creates, not on whatever an earlier command left in r().
    _qa_lc_rclear
    capture noisily quietly `cmd'
    local rc = _rc
    mata: _qa_lc_record(`run', `k', `rc', st_local("before"))
    c_local rc `rc'
end

capture program drop _qa_lc_rclear
program define _qa_lc_rclear, rclass
    version 16.0
end

capture program drop qa_lifecycle_pool
program define qa_lifecycle_pool
    version 16.0
    syntax , SHARD(name) POOL(name) EXPect(string) [ID(string)]
    * Scenario names hold "+", so declared outcomes are kept by position.
    local scen "A+B AB AB+B AB+A AB+CD stale neighbour"
    forvalues i = 1/7 {
        local w`i' ""
    }
    foreach pair of local expect {
        gettoken s v : pair, parse("=")
        gettoken eq v : v, parse("=")
        local i : list posof "`s'" in scen
        if !`i' | !inlist("`v'", "accept", "refuse") {
            display as error "qa_lifecycle_pool: expect() takes scenario=accept|refuse; bad: `pair'"
            exit 198
        }
        local w`i' "`v'"
    }
    forvalues i = 1/7 {
        if "`w`i''" == "" {
            display as error "qa_lifecycle_pool: expect() must declare every scenario; missing `: word `i' of `scen''"
            display as error "  scenarios: `scen'"
            exit 198
        }
    }
    if "`w1'" == "refuse" {
        display as error "qa_lifecycle_pool: A+B=refuse leaves nothing to pool in the AB scenarios"
        exit 198
    }

    tempfile base
    local dir "`base'_lcpool"
    mkdir "`dir'"
    capture noisily _qa_lcp_run "`dir'" `shard' `pool' "`id'" ///
        `w1' `w2' `w3' `w4' `w5' `w6' `w7'
    local rc = _rc
    local files : dir "`dir'" files "*"
    foreach f of local files {
        capture erase "`dir'/`f'"
    }
    capture rmdir "`dir'"
    exit `rc'
end

capture program drop _qa_lcp_run
program define _qa_lcp_run
    args dir shard pool id w_ab w_abalone w_abb w_aba w_abcd w_stale w_nb
    foreach l in A B C D {
        capture noisily `shard' `l' "`dir'/`l'.dta"
        if _rc {
            display as error "qa_lifecycle_pool: shard `l' failed (rc `=_rc')"
            exit 198
        }
        confirm file "`dir'/`l'.dta"
        copy "`dir'/`l'.dta" "`dir'/first_`l'.dta"
    }
    local nbad 0

    _qa_lcp_case "`dir'" `pool' "`id'" "A+B" `w_ab' "AB.dta" "A.dta B.dta" "first_A first_B"
    if `bad' {
        local ++nbad
        local bad`nbad' `"`why'"'
    }
    capture confirm file "`dir'/AB.dta"
    if _rc {
        display as error "qa_lifecycle_pool: A+B produced no AB.dta; the AB scenarios cannot run"
        exit 9
    }
    foreach c in "AB|`w_abalone'|AB.dta" "AB+B|`w_abb'|AB.dta B.dta" "AB+A|`w_aba'|AB.dta A.dta" {
        gettoken s c : c, parse("|")
        gettoken bar c : c, parse("|")
        gettoken w c : c, parse("|")
        gettoken bar ins : c, parse("|")
        _qa_lcp_case "`dir'" `pool' "`id'" "`s'" `w' "out_`s'.dta" "`ins'" "first_A first_B"
        if `bad' {
            local ++nbad
            local bad`nbad' `"`why'"'
        }
    }

    capture noisily `pool' "`dir'/CD.dta" "`dir'/C.dta" "`dir'/D.dta"
    if _rc {
        display as error "qa_lifecycle_pool: pooling C and D failed (rc `=_rc'); AB+CD cannot run"
        exit 198
    }
    _qa_lcp_case "`dir'" `pool' "`id'" "AB+CD" `w_abcd' "out_ABCD.dta" "AB.dta CD.dta" ///
        "first_A first_B first_C first_D"
    if `bad' {
        local ++nbad
        local bad`nbad' `"`why'"'
    }

    capture noisily `shard' A "`dir'/A.dta" fail
    if !_rc {
        display as error "qa_lifecycle_pool: shard A with fail exited 0; the stale scenario needs an injected failure"
        exit 198
    }
    _qa_lcp_case "`dir'" `pool' "`id'" "stale" `w_stale' "out_stale.dta" "A.dta B.dta" "first_A first_B"
    if `bad' {
        local ++nbad
        local bad`nbad' `"`why'"'
    }

    * neighbour: an unrelated x.dta.dta must survive a shard written to x.dta.
    tempname sfr
    frame create `sfr'
    frame `sfr' {
        quietly set obs 1
        quietly generate byte __qa_sentinel = 1
        quietly save "`dir'/x.dta.dta"
    }
    frame drop `sfr'
    _qa_lcp_sig "`dir'/x.dta.dta"
    local sentinel "`sig'"
    capture noisily `shard' A "`dir'/x.dta"
    local src = _rc
    local why ""
    _qa_lcp_sig "`dir'/x.dta.dta"
    if "`sig'" != "`sentinel'" local why "x.dta.dta was overwritten or removed"
    if "`w_nb'" == "refuse" {
        if !`src' & "`why'" == "" local why "shard exited 0 where refuse was declared"
    }
    else if `src' local why "`why'`=cond("`why'" != "", "; ", "")'shard to x.dta exited rc `src'"
    else {
        capture confirm file "`dir'/x.dta"
        if _rc local why "`why'`=cond("`why'" != "", "; ", "")'shard asked for x.dta did not write x.dta"
        else {
            _qa_lcp_sig "`dir'/x.dta"
            local sx "`sig'"
            _qa_lcp_sig "`dir'/first_A.dta"
            if "`sx'" != "`sig'" local why "`why'`=cond("`why'" != "", "; ", "")'x.dta does not hold shard A"
        }
    }
    if "`why'" != "" {
        display as text "qa_lifecycle_pool: neighbour (declared `w_nb'): FAIL: `why'"
        local ++nbad
        local bad`nbad' "neighbour: `why'"
    }
    else if "`w_nb'" == "accept" {
        _qa_lcp_case "`dir'" `pool' "`id'" "neighbour" accept "out_nb.dta" "x.dta B.dta" "first_A first_B"
        if `bad' {
            local ++nbad
            local bad`nbad' `"`why'"'
        }
    }
    else display as text "qa_lifecycle_pool: neighbour (declared refuse): ok"

    if `nbad' {
        display as error "qa_lifecycle_pool: `nbad' of 7 scenario(s) did not have their declared outcome"
        forvalues i = 1/`nbad' {
            display as error `"  `bad`i''"'
        }
        exit 9
    }
    display as text "qa_lifecycle_pool: all 7 scenarios have their declared outcome"
end

* One pooling scenario: run the pool, then judge accept/refuse against the
* distinct rows of the constituent (first-run) shards. Sets bad and why in
* the caller.
capture program drop _qa_lcp_case
program define _qa_lcp_case
    args dir pool id scen want out ins truth
    local paths ""
    foreach f of local ins {
        local paths `"`paths' "`dir'/`f'""'
    }
    capture noisily `pool' "`dir'/`out'" `paths'
    local prc = _rc
    local why ""
    if "`want'" == "refuse" {
        if !`prc' local why "pool exited 0 where refuse was declared"
    }
    else if `prc' local why "pool exited rc `prc' where accept was declared"
    else {
        capture confirm file "`dir'/`out'"
        if _rc local why "pool exited 0 but wrote no `out'"
        else {
            _qa_lcp_count "`dir'" "`id'" "`out'" ""
            local n_out = `n'
            local u_out = `u'
            _qa_lcp_count "`dir'" "`id'" "`truth'" ""
            local u_truth = `u'
            _qa_lcp_count "`dir'" "`id'" "`truth'" "`out'"
            local u_both = `u'
            if `n_out' != `u_out' local why "output has `n_out' rows but `u_out' distinct (duplicated draws)"
            else if `u_out' != `u_truth' | `u_both' != `u_truth' {
                local why "output has `u_out' distinct rows; the constituents have `u_truth'`=cond(`u_both' != `u_truth', " and the output holds rows from outside them", "")'"
            }
        }
    }
    display as text "qa_lifecycle_pool: `scen' (declared `want'): " cond("`why'" == "", "ok", "FAIL: `why'")
    c_local bad = ("`why'" != "")
    c_local why "`scen': `why'"
end

* Rows (n) and distinct rows (u) of the appended files.
capture program drop _qa_lcp_count
program define _qa_lcp_count
    args dir id files extra
    tempname fr
    frame create `fr'
    frame `fr' {
        local first 1
        foreach f in `files' `extra' {
            local f = subinstr("`f'", ".dta", "", .)
            if `first' quietly use "`dir'/`f'.dta", clear
            else quietly append using "`dir'/`f'.dta"
            local first 0
        }
        local n = _N
        if "`id'" != "" quietly duplicates report `id'
        else quietly duplicates report
        local u = r(unique_value)
    }
    frame drop `fr'
    c_local n `n'
    c_local u `u'
end

* datasignature of a file, or "absent".
capture program drop _qa_lcp_sig
program define _qa_lcp_sig
    args file
    capture confirm file "`file'"
    if _rc {
        c_local sig "absent"
        exit
    }
    tempname fr
    frame create `fr'
    frame `fr' {
        quietly use "`file'", clear
        quietly _datasignature
        local s "`r(datasignature)'"
    }
    frame drop `fr'
    c_local sig "`s'"
end

capture mata: mata drop _qa_lc_reset()
capture mata: mata drop _qa_lc_put()
capture mata: mata drop _qa_lc_record()
capture mata: mata drop _qa_lc_diff()

mata:
void _qa_lc_reset()
{
    pointer(transmorphic scalar) scalar p

    if ((p = findexternal("__qa_lifecycle")) == NULL) p = crexternal("__qa_lifecycle")
    *p = asarray_create()
}

void _qa_lc_put(string scalar key, transmorphic matrix val)
{
    pointer(transmorphic scalar) scalar p

    p = findexternal("__qa_lifecycle")
    asarray(*p, key, val)
}

// Record rc, every r() entry and every new variable of post command k on
// run 1 or 2 as "name=value" lines, then drop the new variables.
void _qa_lc_record(real scalar run, real scalar k, real scalar rc,
    string scalar before)
{
    string colvector n, lines
    string rowvector old
    string scalar v
    real matrix m
    real scalar i

    lines = J(0, 1, "")
    n = st_dir("r()", "macro", "*")
    for (i = 1; i <= rows(n); i++) lines = lines \ ("r(" + n[i] + ")=" + st_global("r(" + n[i] + ")"))
    n = st_dir("r()", "numscalar", "*")
    for (i = 1; i <= rows(n); i++) {
        lines = lines \ ("r(" + n[i] + ")=" + strofreal(st_numscalar("r(" + n[i] + ")"), "%21x"))
    }
    n = st_dir("r()", "matrix", "*")
    for (i = 1; i <= rows(n); i++) {
        m = st_matrix("r(" + n[i] + ")")
        v = strofreal(rows(m)) + "x" + strofreal(cols(m))
        if (rows(m) * cols(m)) v = v + ":" + invtokens(strofreal(vec(m)', "%21x"), ",")
        lines = lines \ ("r(" + n[i] + ")=" + v)
    }
    old = tokens(before)
    for (i = 1; i <= st_nvar(); i++) {
        if (anyof(old, st_varname(i))) continue
        if (st_isstrvar(i)) v = invtokens(st_sdata(., i)', char(31))
        else v = invtokens(strofreal(st_data(., i)', "%21x"), ",")
        lines = lines \ ("new variable " + st_varname(i) + " (" + st_vartype(i) + ")=" +
            strofreal(hash1(v), "%12.0f") + ":" + strofreal(hash1(strreverse(v)), "%12.0f"))
    }
    for (i = st_nvar(); i >= 1; i--) {
        if (!anyof(old, st_varname(i))) st_dropvar(i)
    }
    _qa_lc_put(strofreal(run) + "|" + strofreal(k) + "|rc", strofreal(rc))
    _qa_lc_put(strofreal(run) + "|" + strofreal(k), (rows(lines) ? sort(lines, 1) : J(0, 1, "")))
}

// First differences between run 1 and run 2 of post command k, or "".
string scalar _qa_lc_diff(real scalar k)
{
    pointer(transmorphic scalar) scalar p
    string colvector a, b
    string rowvector names
    string scalar key, out
    real scalar i, n

    p = findexternal("__qa_lifecycle")
    key = "|" + strofreal(k)
    a = asarray(*p, "1" + key)
    b = asarray(*p, "2" + key)
    names = J(1, 0, "")
    for (i = 1; i <= rows(a); i++) {
        if (!anyof(b, a[i])) names = names, substr(a[i], 1, strpos(a[i], "=") - 1)
    }
    for (i = 1; i <= rows(b); i++) {
        if (!anyof(a, b[i])) names = names, substr(b[i], 1, strpos(b[i], "=") - 1)
    }
    if (cols(names) == 0) return("")
    names = uniqrows(names')'
    n = cols(names)
    out = invtokens(names[1..min((n, 4))], ", ")
    if (n > 4) out = out + " and " + strofreal(n - 4) + " more"
    return("changed after restore: " + out)
}
end
