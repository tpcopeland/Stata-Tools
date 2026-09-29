*! qa-lib _qa_hostile 1.0.0 sha256:9b419b12b262ac484373841f68ab63869c20e5dcd2aebb29f2b28931aa65a56b
* _qa_hostile.do -- fixtures on the hostile side by default, plus the two
* assertions they are meant to feed
*
* Load from a suite with: do "`qa_dir'/_qa_hostile.do"
*
* A fixture generator cannot fail by itself: it goes red through the oracle a
* suite points at it. So every generator (a) re-verifies on the spot that its
* values still have the hostile property, exiting 9 if not, and (b) returns
* the design truth in r() so the oracle does not have to come from the
* command under test. qa_assert_equal and qa_assert_text are those oracles:
* missing-guarded, and their rc 9 message names the property.
*
* API
*   qa_hostile_times [, generate(newvar)]                            rclass
*       Doubles that do not survive decimal transport, as %21x literals:
*         r(down) .12345678901234564  (a decimal macro rounds it down)
*         r(up) .12345678912345678  (a decimal macro rounds it up)
*       and a final jump with requests closer than 1e-12 on either side:
*         r(before) 1                   (request just before the jump)
*         r(jump) 1.0000000000005     (the event time)
*         r(after) 1.000000000001      (request just after the jump)
*       r(values) lists the five literals in that order. generate() fills a
*       new double variable with them, row i getting value mod(i-1,5)+1.
*       Use a literal as  count if t == `r(down)'  -- never through  local t = x.
*   qa_hostile_missing, clear                                        rclass
*       group (1, 2) and x: values 1 2 3 in both groups plus four missing
*       values each, allocated differently -- group 1: . . .a .b; group 2:
*       .a .b .z .z -- so the missing TOTALS are equal (r(nmiss1) = r(nmiss2)
*       = 4) and a collapsed Missing column is identical across groups while
*       the raw codes are not. r(codes) = ". .a .b .z".
*   qa_hostile_codes, clear                                          rclass
*       code (double) with five groups of three rows: 3000000000 and
*       3000000001 (above c(maxlong)), -7, and the prefix pair 2 / 20; y is
*       the row number. r(ngroups) = 5, r(codes) lists them.
*   qa_hostile_names, clear                                          rclass
*       Case twins y and Y (different values: y = 1 +- 1, Y = 1 +- 10) and two
*       32-character names that differ only in character 32. r(twins),
*       r(long), r(mean_y), r(mean_Y) (equal, 1) and r(sd_y) < r(sd_Y).
*   qa_hostile_strings [, check(progname) result(name)]              rclass
*       Defines the corpus globals QA_HS_* (lifted from the tabtools
*       2026-09-26 audit suite and extended) plus the bait global
*       QA_HS_GLB = "EXPANDED", so a wrongly expanded $QA_HS_GLB shows up.
*       r(names) lists the corpus globals. Pass one into an option intact:
*           mata: st_local("s", st_global("QA_HS_TICK"))
*           mycmd ..., title(`"`macval(s)'"')
*       With check(progname): for every corpus global g, runs "progname g"
*       (the program does the two lines above) and asserts that result()
*       -- r(title), e(title), a global or a characteristic, read with
*       st_global() -- is byte-identical to g. Reports every string that
*       fails or errors, then exits 9.
*   qa_shift_invariance varname, command(cmd) returns(list) [shift(#) tol(#)]
*       Runs cmd on a copy of the data (in a temporary frame), then again
*       with varname + shift (default 1e8), and asserts every expression in
*       returns() (e.g. r(sd) r(Var) e(rmse), no spaces inside one) is
*       unchanged within reldif tol (default 1e-6). varname is recast to
*       double first. Caller data, r() and e() are left as found. rclass:
*       r(maxreldif).
*   qa_counterfeit_twin, kind(scale|weightswap|case) twin(a|b) clear rclass
*       Twin datasets that agree on every proxy -- N, b of the natural fit,
*       coefficient names, the weight multiset, lowercased names -- and
*       differ in substance:
*         scale       y = 1 +- 1 (a) vs y = 1 +- 10 (b): same mean and N,
*                     different variance (iivw F04)
*         weightswap  the same weight values assigned to different rows,
*                     weighted mean 1 in both (finegray F03)
*         case        the same data holding y and Y; twin a analyses y,
*                     twin b analyses Y (tabtools F06)
*       r(depvar) and r(weight) say what to fit; r(proxies) and r(differs)
*       describe the pair. A "same analysis" check must call the twins
*       different.
*   qa_assert_equal a b, property(text) [tol(#)]
*       a and b are expressions (%21x literals, r(), scalars, T[1,1],
*       el(T, 1, 1)); blanks and commas may appear only inside () or [].
*       Exits 9 if
*       either is missing or reldif(a, b) > tol (default 0, i.e. exact),
*       printing "property violated: text".
*   qa_assert_text wantname gotname, property(text)
*       Both are names readable with st_global() (a global, r(x), e(x),
*       _dta[x]). Exits 9 unless the two texts are byte-identical.
*
* Errors: rc 9 for a violation or a fixture that lost its hostile property;
* rc 198 for bad arguments; clear is required where a generator replaces the
* data.
*
* Deliberately NOT provided: hostile dates/datetimes, strL payloads, file
* names, and value-label texts; a generator does not know which command
* option a string belongs in.

capture program drop qa_hostile_times
program define qa_hostile_times, rclass
    version 16.0
    syntax [, GENerate(name)]
    tempname down up before jump after
    scalar `down' = .12345678901234564
    scalar `up' = .12345678912345678
    scalar `before' = 1
    scalar `jump' = 1.0000000000005
    scalar `after' = 1.000000000001
    foreach s in down up {
        local dec = ``s''
        if `dec' == ``s'' {
            display as error "qa_hostile_times: `s' survives decimal transport; fixture is not hostile"
            exit 9
        }
    }
    if !(`jump' - `before' > 0 & `jump' - `before' < 1e-12 ///
        & `after' - `jump' > 0 & `after' - `jump' < 1e-12) {
        display as error "qa_hostile_times: requests are not within 1e-12 of the jump"
        exit 9
    }
    local values ""
    foreach s in down up before jump after {
        local x : display %21x ``s''
        return local `s' "`x'"
        local values "`values' `x'"
    }
    return local values = strtrim("`values'")
    if "`generate'" != "" {
        confirm new variable `generate'
        quietly generate double `generate' = .
        local i 0
        foreach s in down up before jump after {
            quietly replace `generate' = ``s'' if mod(_n - 1, 5) == `i'
            local ++i
        }
    }
end

capture program drop qa_hostile_missing
program define qa_hostile_missing, rclass
    version 16.0
    syntax , CLEAR
    clear
    quietly {
        set obs 14
        generate byte group = 1 + (_n > 7)
        generate double x = mod(_n - 1, 7) + 1
        replace x = cond(x == 4, ., cond(x == 5, ., cond(x == 6, .a, .b))) ///
            if group == 1 & x > 3
        replace x = cond(x == 4, .a, cond(x == 5, .b, .z)) if group == 2 & x > 3
    }
    quietly count if missing(x) & group == 1
    local m1 = r(N)
    quietly count if missing(x) & group == 2
    local m2 = r(N)
    quietly count if x == . & group == 1
    local d1 = r(N)
    quietly count if x == . & group == 2
    local d2 = r(N)
    if `m1' != `m2' | `d1' == `d2' {
        display as error "qa_hostile_missing: totals unequal or allocations equal; fixture is not hostile"
        exit 9
    }
    return scalar nmiss1 = `m1'
    return scalar nmiss2 = `m2'
    return scalar N = _N
    return local codes ". .a .b .z"
end

capture program drop qa_hostile_codes
program define qa_hostile_codes, rclass
    version 16.0
    syntax , CLEAR
    clear
    local codes "3000000000 3000000001 -7 2 20"
    quietly {
        set obs 15
        generate double code = .
        local i 0
        foreach c of local codes {
            replace code = `c' if ceil(_n / 3) == `i' + 1
            local ++i
        }
        generate double y = _n
    }
    quietly count if code > c(maxlong)
    if r(N) < 6 {
        display as error "qa_hostile_codes: no codes above c(maxlong); fixture is not hostile"
        exit 9
    }
    return scalar ngroups = 5
    return scalar maxlong = c(maxlong)
    return local codes "`codes'"
end

capture program drop qa_hostile_names
program define qa_hostile_names, rclass
    version 16.0
    syntax , CLEAR
    clear
    local base "abcdefghijklmnopqrstuvwxyz_1234"
    quietly {
        set obs 20
        generate double y = 1 + cond(mod(_n, 2), 1, -1)
        generate double Y = 1 + 10 * cond(mod(_n, 2), 1, -1)
        generate double `base'a = _n
        generate double `base'b = -_n
    }
    if strlen("`base'a") != 32 {
        display as error "qa_hostile_names: long names are not 32 characters"
        exit 9
    }
    quietly summarize y
    return scalar mean_y = r(mean)
    return scalar sd_y = r(sd)
    quietly summarize Y
    return scalar mean_Y = r(mean)
    return scalar sd_Y = r(sd)
    return local twins "y Y"
    return local long "`base'a `base'b"
end

capture program drop qa_hostile_strings
program define qa_hostile_strings, rclass
    version 16.0
    syntax [, CHECK(name) RESult(string)]
    if ("`check'" == "") != (`"`result'"' == "") {
        display as error "qa_hostile_strings: check() and result() go together"
        exit 198
    }
    global QA_HS_GLB "EXPANDED"
    * The first three are the tabtools 2026-09-26 audit corpus (CA_L, CA_U,
    * CA_P); the rest add one hazard each.
    mata: st_global("QA_HS_TICKPAIR", "V " + char(36) + "QA_HS_GLB " + char(96) + "lit" + char(39) + " " + char(34) + "dq" + char(34) + " end")
    mata: st_global("QA_HS_TICK", "U " + char(96) + "tick end")
    mata: st_global("QA_HS_DOLLAR", "P " + char(36) + "QA_HS_GLB " + char(96) + "q")
    mata: st_global("QA_HS_APOS", "HR " + char(39) + "adj" + char(39))
    mata: st_global("QA_HS_DQ", "A" + char(34) + "B")
    mata: st_global("QA_HS_BSLASH", "Ratio " + char(92) + " CI")
    mata: st_global("QA_HS_COMMA", "left, right")
    mata: st_global("QA_HS_LEAD", " leading space")
    mata: st_global("QA_HS_UNICODE", "M" + uchar(228) + "nner " + uchar(8805) + " 65")
    local names "QA_HS_TICKPAIR QA_HS_TICK QA_HS_DOLLAR QA_HS_APOS QA_HS_DQ QA_HS_BSLASH QA_HS_COMMA QA_HS_LEAD QA_HS_UNICODE"

    if "`check'" != "" {
        local nbad 0
        local report ""
        foreach g of local names {
            capture noisily `check' `g'
            local rc = _rc
            if `rc' {
                local ++nbad
                local report `"`report' "`g': `check' exited rc `rc'""'
                continue
            }
            mata: st_local("same", strofreal(st_global("`g'") == st_global(`"`result'"')))
            if !`same' {
                local ++nbad
                local report `"`report' "`g': `result' is not the text sent""'
            }
        }
        if `nbad' {
            display as error "qa_hostile_strings: user text not preserved by `check': `nbad' of `: word count `names'' corpus string(s)"
            foreach line of local report {
                display as error `"  `macval(line)'"'
            }
            exit 9
        }
    }
    return local names "`names'"
    return scalar n = `: word count `names''
end

capture program drop qa_shift_invariance
program define qa_shift_invariance, rclass
    version 16.0
    syntax varname(numeric), COMmand(string) RETurns(string) ///
        [SHIFT(real 1e8) TOL(real 1e-6)]
    tempname fr ehold
    _estimates hold `ehold', copy nullok restore
    frame copy `c(frame)' `fr'
    capture noisily frame `fr': _qa_shift_body `varlist' `shift' `tol' ///
        `"`returns'"' `"`command'"'
    local rc = _rc
    capture frame drop `fr'
    _estimates unhold `ehold'
    if `rc' exit `rc'
    return scalar maxreldif = `worst'
end

* Runs inside the temporary frame; hands the largest reldif back to the
* caller's worst local.
capture program drop _qa_shift_body
program define _qa_shift_body
    args var shift tol returns command
    tempname now worst
    scalar `worst' = 0
    quietly recast double `var'
    capture noisily quietly `command'
    if _rc {
        display as error "qa_shift_invariance: command failed on the unshifted data (rc `=_rc')"
        exit 198
    }
    local i 0
    foreach r of local returns {
        local ++i
        tempname b`i'
        scalar `b`i'' = `r'
    }
    quietly replace `var' = `var' + `shift'
    capture noisily quietly `command'
    if _rc {
        display as error "qa_shift_invariance: command failed on `var' + `shift' (rc `=_rc')"
        exit 9
    }
    local i 0
    local nbad 0
    foreach r of local returns {
        local ++i
        scalar `now' = `r'
        if missing(`b`i'') | missing(`now') {
            local ++nbad
            display as error "qa_shift_invariance: `r' is missing (unshifted " `b`i'' ", shifted " `now' ")"
            continue
        }
        scalar `worst' = max(`worst', reldif(`b`i'', `now'))
        if reldif(`b`i'', `now') > `tol' {
            local ++nbad
            display as error "qa_shift_invariance: `r' is not shift-invariant: " ///
                strtrim(string(`b`i'', "%21.15g")) " at `var', " ///
                strtrim(string(`now', "%21.15g")) " at `var' + `shift' (reldif " ///
                strtrim(string(reldif(`b`i'', `now'), "%9.3g")) ")"
        }
    }
    if `nbad' exit 9
    c_local worst = `worst'
end

capture program drop qa_counterfeit_twin
program define qa_counterfeit_twin, rclass
    version 16.0
    syntax , KIND(string) TWIN(string) CLEAR
    if !inlist("`kind'", "scale", "weightswap", "case") {
        display as error "qa_counterfeit_twin: kind() is scale, weightswap or case"
        exit 198
    }
    if !inlist("`twin'", "a", "b") {
        display as error "qa_counterfeit_twin: twin() is a or b"
        exit 198
    }
    clear
    quietly set obs 20
    quietly generate long id = _n
    local weight ""
    if "`kind'" == "scale" {
        local k = cond("`twin'" == "a", 1, 10)
        quietly generate double y = 1 + `k' * cond(mod(_n, 2), 1, -1)
        local depvar "y"
        local proxies "N, mean of y, b and coefficient names of regress y"
        local differs "variance of y (1 vs 100)"
    }
    else if "`kind'" == "weightswap" {
        * Rows cycle through (y, w) = (0, 1) (2, 3) (0, 3) (2, 1) in twin a and
        * (0, 3) (2, 1) (0, 1) (2, 3) in twin b: the weight multiset and the
        * weighted mean of y (1) are the same, the row assignment is not.
        quietly generate double y = 2 * mod(_n + 1, 2)
        if "`twin'" == "a" quietly generate double w = cond(inlist(mod(_n - 1, 4), 0, 3), 1, 3)
        else quietly generate double w = cond(inlist(mod(_n - 1, 4), 0, 3), 3, 1)
        local depvar "y"
        local weight "w"
        local proxies "N, weight multiset, weighted mean of y, b of regress y [pw=w]"
        local differs "which row carries which weight"
    }
    else {
        quietly generate double y = 1 + cond(mod(_n, 2), 1, -1)
        quietly generate double Y = 1 + 10 * cond(mod(_n, 2), 1, -1)
        local depvar = cond("`twin'" == "a", "y", "Y")
        local proxies "N, mean, b, lower(depvar)"
        local differs "the variable analysed (y vs Y)"
    }
    return local kind "`kind'"
    return local twin "`twin'"
    return local depvar "`depvar'"
    return local weight "`weight'"
    return local proxies "`proxies'"
    return local differs "`differs'"
end

capture program drop qa_assert_equal
program define qa_assert_equal
    version 16.0
    mata: _qa_hs_split(st_local("0"))
    if `nargs' != 2 {
        display as error "qa_assert_equal: expected two expressions before the comma"
        exit 198
    }
    local 0 `"`opts'"'
    syntax , PROPerty(string) [TOL(real 0)]
    tempname va vb
    scalar `va' = `a'
    scalar `vb' = `b'
    if missing(`va') | missing(`vb') {
        display as error "qa_assert_equal: property violated: `property'"
        display as error "  a missing value is never equal: " `va' " vs " `vb'
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
        display as error "qa_assert_equal: property violated: `property'"
        display as error "  `sa' vs `sb' (reldif " strtrim(string(reldif(`va', `vb'), "%9.3g")) ///
            ", tol " strtrim(string(`tol', "%9.3g")) ")"
        exit 9
    }
end

capture program drop qa_assert_text
program define qa_assert_text
    version 16.0
    gettoken want 0 : 0, parse(" ,")
    gettoken got 0 : 0, parse(" ,")
    syntax , PROPerty(string)
    mata: st_local("same", strofreal(st_global(`"`want'"') == st_global(`"`got'"')))
    if !`same' {
        display as error "qa_assert_text: property violated: `property'"
        display as error "  `got' is not byte-identical to `want'"
        exit 9
    }
end

capture mata: mata drop _qa_hs_split()
mata:
// Split "a b [, options]" at top-level blanks and the first top-level
// comma, respecting (), [] and double quotes, so T[1,1] and el(T, 1, 1)
// arrive whole. Sets locals nargs, a, b and opts (from the comma on).
void _qa_hs_split(string scalar s)
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
