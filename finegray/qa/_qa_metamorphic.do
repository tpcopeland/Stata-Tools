*! qa-lib _qa_metamorphic 1.1.1 sha256:181ccadd980e83759d83681a188c4e7d8d0bd560762c8b35c01bab6c80ccf73b
* _qa_metamorphic.do -- oracles that are relations between two runs
*
* Load from a suite with: do "`qa_dir'/_qa_metamorphic.do"
*
* Each program runs a command more than once and asserts a relation between
* the runs, so it needs no truth of its own and works on any data, including
* realistic (R-tier) data. Every violation exits 9 with the relation named.
* A refusal where the relation expects a result is a violation: an INVARIANT
* check fails on a refusal, and a REFUSED check fails on success.
*
* Command templates: command() is run as written after substituting the
* placeholders @var@ (var()), @list@ (the numlist under test), @w@ (weight()),
* @v@ (the option value under test), @fw@ and @cl@ (identity-resample
* variables). Returned items in returns() are r(name), e(name), _b[name],
* scalar expressions, or var:varname (an order-sensitive digest of a
* variable); matrices are compared element by element (values, not names).
* Missing values match only an identical missing code.
*
* API
*   qa_metamorphic relation , command(template) returns(items)
*       [var(varname) weight(varname) id(varname) list(numlist)
*        irrelevant(exp) map(old=new ...) factor(#) shift(#) tol(#) seed(#)]
*                                                                    rclass
*     relation (the U operator it covers):
*       unsorted          random row order                         identical
*       unsorted_list     @list@ given descending instead of ascending
*       dup_list          @list@ with every element repeated
*       codes_multidigit  var() levels relabelled 1 11 111 ... (map() overrides)
*       codes_sparse      var() levels relabelled 1 5 17 37 ...
*       long_names        var() renamed to a 32-character name (@var@)
*       miss_irrelevant   var() set missing where irrelevant() is true
*       weight_scale      weight() multiplied by factor() (default 3)
*       replicate         every id() cluster duplicated under a new id
*       scale_shift       delegates to qa_shift_invariance (load _qa_hostile.do)
*     tol() is a reldif tolerance, default 1e-10 (scale_shift: the
*     qa_shift_invariance default). r(maxreldif), r(n_items).
*   qa_identity_resample , point(template) replicate(template) returns(items)
*       cluster(varname) [design(items) tol(#)]                          rclass
*     Runs point(), then replicate() with @fw@ = a frequency variable of ones
*     and @cl@ = the cluster index in original order (an identity bootstrap
*     draw: every cluster once). Asserts every returns() and design() item is
*     equal (tol default 1e-12). design() lists the data-derived design
*     quantities (grid, horizons, support, knots, levels): a replicate that
*     recomputes them instead of inheriting them is the N2 class.
*   qa_option_domain , command(template with @v@) [inside(values)
*       outside(values) range(# #) integer eps(#) special(values)
*       setup(command) check(command)]                                   rclass
*     Every inside cell (inside(), special(), and the range() endpoints) must
*     return rc 0 and pass check() when given. Every outside cell (outside(),
*     and the range() endpoints -/+ eps, eps 1 under integer) must refuse
*     with a nonzero rc other than 9, before any change to the data, _dta[]
*     and variable chars, sort order, e(cmd), e(N) or e(b). setup() rebuilds
*     the fixture before each cell (default: the data as found). Outside
*     cells need at least one inside cell (the control). Values are
*     separated by ";" when one contains a blank (e.g. inside(1 99;0 99)).
*     r(n_cells), r(n_violations), r(cells) (value:class:rc ...).
*   qa_option_effect , command(template with @v@) values(v1;v2...)
*       returns(items) [setup(command) inert refused control(value)
*       cause(text) tol(#)]                                              rclass
*     Default (consumed): some item differs between the first value and some
*     later value. inert: no item differs (declare inert-by-design options
*     with the outputs they must not change). refused: every value refuses
*     with the state unchanged (an option this route does not consume); it
*     needs a positive control -- control(value), a value of the same
*     template that must succeed, and/or cause(text), which the refusal
*     output must contain -- because a bare refusal passes on any error.
*
* Errors: rc 9 for a violated relation; rc 198 for bad arguments.
*
* Deliberately NOT provided: comparison of text output, graphs or files
* (use _qa_parity.do), and the choice of which returns are invariant -- the
* suite declares them.

capture program drop qa_metamorphic
program define qa_metamorphic, rclass
    version 16.0
    gettoken rel 0 : 0, parse(" ,")
    syntax , COMmand(string asis) RETurns(string) [VAR(varname) ///
        WEIGHT(varname) ID(varname) LIST(numlist) IRRelevant(string) ///
        MAP(string) FACTOR(real 3) SHIFT(real 1e8) TOL(real -1) ///
        SEED(integer 12345)]
    local rels unsorted unsorted_list dup_list codes_multidigit codes_sparse ///
        long_names miss_irrelevant weight_scale replicate scale_shift
    if "`rel'" == "identity_resample" {
        display as error "qa_metamorphic: use qa_identity_resample for identity_resample"
        exit 198
    }
    if !`: list rel in rels' {
        display as error "qa_metamorphic: unknown relation `rel' (known: `rels')"
        exit 198
    }
    local need_var codes_multidigit codes_sparse long_names miss_irrelevant scale_shift
    if `: list rel in need_var' & "`var'" == "" {
        display as error "qa_metamorphic `rel': var() required"
        exit 198
    }
    if inlist("`rel'", "unsorted_list", "dup_list") & "`list'" == "" {
        display as error "qa_metamorphic `rel': list() required"
        exit 198
    }
    if "`rel'" == "weight_scale" & "`weight'" == "" {
        display as error "qa_metamorphic weight_scale: weight() required"
        exit 198
    }
    if "`rel'" == "replicate" & "`id'" == "" {
        display as error "qa_metamorphic replicate: id() required"
        exit 198
    }
    if "`rel'" == "miss_irrelevant" & `"`irrelevant'"' == "" {
        display as error "qa_metamorphic miss_irrelevant: irrelevant() required"
        exit 198
    }

    if "`rel'" == "scale_shift" {
        capture program list qa_shift_invariance
        if _rc {
            display as error "qa_metamorphic scale_shift: load _qa_hostile.do (qa_shift_invariance)"
            exit 198
        }
        local cmd : subinstr local command "@var@" "`var'", all
        local t = cond(`tol' < 0, "", "tol(`tol')")
        qa_shift_invariance `var', command(`cmd') returns(`returns') ///
            shift(`shift') `t'
        return add
        exit
    }
    if `tol' < 0 local tol = 1e-10

    * Base run.
    local sorted : list sort list
    local base_list `sorted'
    local cmd0 `"`command'"'
    local cmd0 : subinstr local cmd0 "@var@" "`var'", all
    local cmd0 : subinstr local cmd0 "@w@" "`weight'", all
    local cmd0 : subinstr local cmd0 "@list@" "`base_list'", all
    local cmd1 `"`cmd0'"'

    tempname est
    _estimates hold `est', restore nullok
    local rng `c(rngstate)'
    preserve

    capture noisily _qa_mm_run 0 `"`cmd0'"' `"`returns'"'
    local rc0 = _rc
    if `rc0' {
        display as error "qa_metamorphic `rel': the base run failed (rc `rc0'); nothing to compare"
        exit 9
    }
    restore, preserve

    * Perturbed run.
    if "`rel'" == "unsorted" {
        set seed `seed'
        tempvar u ord
        quietly generate double `u' = runiform()
        quietly generate long `ord' = _n
        sort `u'
        quietly count if `ord' != _n
        if r(N) == 0 {
            display as error "qa_metamorphic unsorted: the shuffle did not move a row"
            exit 9
        }
        drop `u' `ord'
    }
    else if "`rel'" == "unsorted_list" {
        local rev ""
        foreach v of local sorted {
            local rev `v' `rev'
        }
        if "`rev'" == "`sorted'" {
            display as error "qa_metamorphic unsorted_list: list() needs two distinct values"
            exit 198
        }
        local cmd1 `"`command'"'
        local cmd1 : subinstr local cmd1 "@var@" "`var'", all
        local cmd1 : subinstr local cmd1 "@w@" "`weight'", all
        local cmd1 : subinstr local cmd1 "@list@" "`rev'", all
    }
    else if "`rel'" == "dup_list" {
        local dup ""
        foreach v of local sorted {
            local dup `dup' `v' `v'
        }
        local cmd1 `"`command'"'
        local cmd1 : subinstr local cmd1 "@var@" "`var'", all
        local cmd1 : subinstr local cmd1 "@w@" "`weight'", all
        local cmd1 : subinstr local cmd1 "@list@" "`dup'", all
    }
    else if inlist("`rel'", "codes_multidigit", "codes_sparse") {
        capture confirm numeric variable `var'
        if _rc {
            display as error "qa_metamorphic `rel': var() must be numeric"
            exit 198
        }
        quietly levelsof `var', local(levels)
        if `"`map'"' == "" {
            local j = 0
            foreach l of local levels {
                local ++j
                if "`rel'" == "codes_multidigit" local nv = (10^`j' - 1) / 9
                else local nv = 1 + 4*(`j' - 1)^2
                local map `map' `l'=`nv'
            }
        }
        local lbl : value label `var'
        tempvar new
        quietly generate double `new' = .
        tempname nl
        local changed = 0
        foreach pair of local map {
            gettoken o n : pair, parse("=")
            local n = substr("`n'", 2, .)
            quietly replace `new' = `n' if `var' == `o'
            if `o' != `n' local changed = 1
            if "`lbl'" != "" {
                local t : label `lbl' `o'
                label define `nl' `n' `"`t'"', add
            }
        }
        quietly count if missing(`new') & !missing(`var')
        if r(N) > 0 | !`changed' {
            display as error "qa_metamorphic `rel': map() does not cover every level of `var' or changes nothing"
            exit 198
        }
        quietly replace `var' = `new'
        if "`lbl'" != "" label values `var' `nl'
        drop `new'
        return local map "`map'"
    }
    else if "`rel'" == "long_names" {
        local long = substr("qa_metamorphic_long_name_`var'" + 32*"x", 1, 32)
        capture confirm new variable `long'
        if _rc {
            display as error "qa_metamorphic long_names: `long' already exists"
            exit 198
        }
        rename `var' `long'
        local cmd1 `"`command'"'
        local cmd1 : subinstr local cmd1 "@var@" "`long'", all
        local cmd1 : subinstr local cmd1 "@w@" "`weight'", all
        local cmd1 : subinstr local cmd1 "@list@" "`base_list'", all
    }
    else if "`rel'" == "miss_irrelevant" {
        quietly count if `irrelevant'
        if r(N) == 0 {
            display as error "qa_metamorphic miss_irrelevant: irrelevant() selects no row"
            exit 9
        }
        capture confirm string variable `var'
        if _rc quietly replace `var' = . if `irrelevant'
        else quietly replace `var' = "" if `irrelevant'
    }
    else if "`rel'" == "weight_scale" {
        quietly replace `weight' = `weight' * `factor'
    }
    else if "`rel'" == "replicate" {
        capture confirm numeric variable `id'
        if _rc {
            display as error "qa_metamorphic replicate: id() must be numeric"
            exit 198
        }
        quietly summarize `id', meanonly
        local off = 10^ceil(log10(max(abs(r(min)), abs(r(max))) + 1) + 1)
        tempvar copy
        quietly expand 2, generate(`copy')
        quietly replace `id' = `id' + `off' if `copy'
        drop `copy'
    }

    capture noisily _qa_mm_run 1 `"`cmd1'"' `"`returns'"'
    local rc1 = _rc
    restore
    set rngstate `rng'
    if `rc1' {
        display as error "qa_metamorphic `rel': property violated: the perturbed run refused (rc `rc1') where the relation expects a result"
        exit 9
    }
    _qa_mm_compare "`rel'" `"`returns'"' `tol'
    return scalar maxreldif = r(maxreldif)
    return scalar n_items = r(n_items)
end

* Run a command and store every item of returns() as matrices __qa_mm<k>_<i>.
capture program drop _qa_mm_run
program define _qa_mm_run
    version 16.0
    args k cmd items
    capture quietly `cmd'
    local rc = _rc
    if `rc' exit `rc'
    local i = 0
    foreach it of local items {
        local ++i
        capture matrix drop __qa_mm`k'_`i'
        if substr("`it'", 1, 4) == "var:" {
            local v = substr("`it'", 5, .)
            capture confirm variable `v', exact
            if _rc {
                display as error "returned item `it': no such variable after the run"
                exit 459
            }
            mata: st_matrix("__qa_mm`k'_`i'", _qa_mm_vdigest(st_local("v")))
            continue
        }
        capture matrix __qa_mm`k'_`i' = `it'
        if _rc {
            tempname s
            capture scalar `s' = `it'
            if _rc {
                display as error "returned item `it' cannot be read after the run"
                exit 459
            }
            matrix __qa_mm`k'_`i' = (`s')
        }
    }
end

capture program drop _qa_mm_compare
program define _qa_mm_compare, rclass
    version 16.0
    args rel items tol
    local i = 0
    local bad ""
    tempname d dd
    scalar `d' = 0
    foreach it of local items {
        local ++i
        mata: st_numscalar("`dd'", _qa_mm_diff(st_matrix("__qa_mm0_`i'"), ///
            st_matrix("__qa_mm1_`i'")))
        if scalar(`dd') > `tol' local bad `bad' `it'
        if scalar(`dd') > scalar(`d') scalar `d' = scalar(`dd')
        matrix drop __qa_mm0_`i' __qa_mm1_`i'
    }
    if "`bad'" != "" {
        display as error "qa_metamorphic `rel': property violated: results changed under `rel': `bad' (max reldif " %10.3g scalar(`d') ")"
        exit 9
    }
    return scalar maxreldif = scalar(`d')
    return scalar n_items = `i'
end

capture program drop qa_identity_resample
program define qa_identity_resample, rclass
    version 16.0
    syntax , POINT(string asis) REPLicate(string asis) RETurns(string) ///
        CLuster(varname) [DESign(string) TOL(real 1e-12)]
    local items `returns' `design'
    tempname est
    _estimates hold `est', restore nullok
    preserve
    capture noisily _qa_mm_run 0 `"`point'"' `"`items'"'
    if _rc {
        display as error "qa_identity_resample: the point run failed (rc `=_rc')"
        exit 9
    }
    restore, preserve
    tempvar fw cl
    quietly generate double `fw' = 1
    quietly egen long `cl' = group(`cluster')
    local cmd : subinstr local replicate "@fw@" "`fw'", all
    local cmd : subinstr local cmd "@cl@" "`cl'", all
    capture noisily _qa_mm_run 1 `"`cmd'"' `"`items'"'
    local rc1 = _rc
    restore
    if `rc1' {
        display as error "qa_identity_resample: property violated: the identity replicate refused (rc `rc1')"
        exit 9
    }
    local i = 0
    local bad ""
    tempname d dd
    scalar `d' = 0
    foreach it of local items {
        local ++i
        mata: st_numscalar("`dd'", _qa_mm_diff(st_matrix("__qa_mm0_`i'"), ///
            st_matrix("__qa_mm1_`i'")))
        if scalar(`dd') > `tol' {
            local kind = cond(`: list it in design', "design quantity", "estimate")
            local bad `bad' `it'(`kind')
        }
        if scalar(`dd') > scalar(`d') scalar `d' = scalar(`dd')
        matrix drop __qa_mm0_`i' __qa_mm1_`i'
    }
    if "`bad'" != "" {
        display as error "qa_identity_resample: property violated: identity replicate differs from the point estimate: `bad'"
        exit 9
    }
    return scalar maxreldif = scalar(`d')
    return scalar n_items = `i'
end

capture program drop _qa_mm_values
program define _qa_mm_values, sclass
    version 16.0
    * Split a value list on ";" when present, else on blanks; returns s(v1..)
    args list
    local n = 0
    if strpos(`"`list'"', ";") {
        local rest `"`list'"'
        local more = 1
        while `more' {
            local p = strpos(`"`rest'"', ";")
            if `p' == 0 {
                local v `"`rest'"'
                local more = 0
            }
            else {
                local v = substr(`"`rest'"', 1, `p' - 1)
                local rest = substr(`"`rest'"', `p' + 1, .)
            }
            local ++n
            sreturn local v`n' = strtrim(`"`v'"')
        }
    }
    else {
        foreach v of local list {
            local ++n
            sreturn local v`n' `"`v'"'
        }
    }
    sreturn local n `n'
end

capture program drop _qa_mm_fingerprint
program define _qa_mm_fingerprint, rclass
    version 16.0
    local ecmd `"`e(cmd)'"'
    local eN = e(N)
    tempname eb
    capture matrix `eb' = e(b)
    if _rc matrix `eb' = (.)
    mata: st_local("fp", _qa_mm_fp(st_matrix("`eb'")))
    return local fp `"`fp'|`ecmd'|`eN'|`: sortedby'"'
end

capture program drop _qa_mm_cell
program define _qa_mm_cell, rclass
    version 16.0
    * Run one option cell; want = inside | outside. cause: text the refusal
    * output must contain. acceptmsg: the finding when an outside cell runs.
    args want cmd setup check cause acceptmsg
    if `"`acceptmsg'"' == "" local acceptmsg "accepted an out-of-domain value"
    * Remove estimates from an earlier cell before setup. A postestimation
    * setup explicitly fits the model the candidate must then consume.
    if "`want'" == "outside" ereturn clear
    if `"`setup'"' != "" {
        capture noisily quietly `setup'
        if _rc {
            display as error "setup() failed (rc `=_rc')"
            exit 198
        }
    }
    _qa_mm_fingerprint
    local fp0 `"`r(fp)'"'
    local hit = 0
    if `"`cause'"' != "" {
        tempfile clog
        quietly log using "`clog'", text name(__qa_mm_cause) replace
        capture noisily `cmd'
        local rc = _rc
        quietly log close __qa_mm_cause
        mata: st_local("hit", strofreal(_qa_mm_logfind(st_local("clog"), st_local("cause"))))
    }
    else {
        capture noisily quietly `cmd'
        local rc = _rc
    }
    local ok = 1
    local why ""
    if "`want'" == "inside" {
        if `rc' {
            local ok = 0
            local why "refused a documented value (rc `rc')"
        }
        else if `"`check'"' != "" {
            capture noisily quietly `check'
            if _rc {
                local ok = 0
                local why "check() failed (rc `=_rc')"
            }
        }
    }
    else {
        _qa_mm_fingerprint
        if `rc' == 0 {
            local ok = 0
            local why "`acceptmsg'"
        }
        else if `rc' == 9 {
            local ok = 0
            local why "refused with rc 9 (an assertion, not a validation)"
        }
        else if `"`r(fp)'"' != `"`fp0'"' {
            local ok = 0
            local why "refused (rc `rc') after changing state"
        }
        else if `"`cause'"' != "" & !`hit' {
            local ok = 0
            local why "refused (rc `rc') without naming the cause"
        }
    }
    return scalar rc = `rc'
    return scalar ok = `ok'
    return local why "`why'"
end

capture program drop qa_option_domain
program define qa_option_domain, rclass
    version 16.0
    syntax , COMmand(string asis) [INside(string) OUTside(string) ///
        RANGE(numlist min=2 max=2) INTeger EPS(real -1) SPECial(string) ///
        SETup(string asis) CHECK(string asis)]
    local ins ""
    local outs ""
    local nin = 0
    local nout = 0
    foreach src in inside special {
        _qa_mm_values `"``src''"'
        forvalues j = 1/`s(n)' {
            local ++nin
            local in`nin' `"`s(v`j')'"'
        }
    }
    _qa_mm_values `"`outside'"'
    forvalues j = 1/`s(n)' {
        local ++nout
        local out`nout' `"`s(v`j')'"'
    }
    if "`range'" != "" {
        gettoken lo hi : range
        local hi = strtrim("`hi'")
        if `eps' < 0 local eps = cond("`integer'" != "", 1, 1e-6*max(1, abs(`lo'), abs(`hi')))
        local ++nin
        local in`nin' "`lo'"
        local ++nin
        local in`nin' "`hi'"
        local ++nout
        local out`nout' = "`: display %21.0g `lo' - `eps''"
        local out`nout' = strtrim("`out`nout''")
        local ++nout
        local out`nout' = "`: display %21.0g `hi' + `eps''"
        local out`nout' = strtrim("`out`nout''")
    }
    if `nin' + `nout' == 0 {
        display as error "qa_option_domain: no cells (give inside(), outside(), special() or range())"
        exit 198
    }
    if `nout' > 0 & `nin' == 0 {
        display as error "qa_option_domain: outside cells need at least one inside cell as the control; a bare refusal passes on any error"
        exit 198
    }
    tempname est
    _estimates hold `est', restore nullok
    preserve
    local cells ""
    local bad ""
    local nbad = 0
    foreach want in inside outside {
        local nn = cond("`want'" == "inside", `nin', `nout')
        forvalues j = 1/`nn' {
            local v = cond("`want'" == "inside", `"`in`j''"', `"`out`j''"')
            local cmd : subinstr local command "@v@" `"`v'"', all
            restore, preserve
            _qa_mm_cell `want' `"`cmd'"' `"`setup'"' `"`check'"'
            local cells `"`cells' `v':`want':`r(rc)'"'
            if !r(ok) {
                local ++nbad
                local bad `"`bad'; [`v'] `r(why)'"'
                display as error `"option cell [`v'] `want': `r(why)'"'
            }
            else display as text `"option cell [`v'] `want': ok, rc `r(rc)'"'
        }
    }
    restore
    if `nbad' {
        display as error `"qa_option_domain: property violated: declared domain not honoured`bad'"'
        exit 9
    }
    return scalar n_cells = `nin' + `nout'
    return scalar n_violations = `nbad'
    return local cells `"`cells'"'
end

capture program drop qa_option_effect
program define qa_option_effect, rclass
    version 16.0
    syntax , COMmand(string asis) VALues(string) RETurns(string) ///
        [SETup(string asis) INert REFused CONTrol(string asis) ///
        CAUSE(string) TOL(real 0)]
    if "`inert'" != "" & "`refused'" != "" {
        display as error "qa_option_effect: inert and refused are exclusive"
        exit 198
    }
    if "`refused'" != "" & `"`control'"' == "" & `"`cause'"' == "" {
        display as error "qa_option_effect: refused needs control() or cause(); a bare refusal passes on any error"
        exit 198
    }
    if "`refused'" == "" & (`"`control'"' != "" | `"`cause'"' != "") {
        display as error "qa_option_effect: control() and cause() apply to refused only"
        exit 198
    }
    _qa_mm_values `"`values'"'
    local nv = s(n)
    forvalues j = 1/`nv' {
        local v`j' `"`s(v`j')'"'
    }
    if `nv' < 2 & "`refused'" == "" {
        display as error "qa_option_effect: values() needs at least two values"
        exit 198
    }
    tempname est
    _estimates hold `est', restore nullok
    preserve
    if "`refused'" != "" {
        local bad ""
        if `"`control'"' != "" {
            local cmd : subinstr local command "@v@" `"`control'"', all
            restore, preserve
            if `"`setup'"' != "" {
                capture noisily quietly `setup'
                if _rc {
                    display as error "qa_option_effect: setup() failed (rc `=_rc')"
                    exit 198
                }
            }
            capture noisily quietly `cmd'
            if _rc {
                local crc = _rc
                restore
                display as error `"qa_option_effect: the control value [`control'] failed (rc `crc'); a refusal cannot be attributed to the option"'
                exit 9
            }
        }
        forvalues j = 1/`nv' {
            local cmd : subinstr local command "@v@" `"`v`j''"', all
            restore, preserve
            _qa_mm_cell outside `"`cmd'"' `"`setup'"' "" `"`cause'"' "accepted where this route must refuse"
            if !r(ok) local bad `"`bad'; [`v`j''] `r(why)'"'
        }
        restore
        if `"`bad'"' != "" {
            display as error `"qa_option_effect: property violated: option not refused on this route`bad'"'
            exit 9
        }
        return scalar n_values = `nv'
        exit
    }
    forvalues j = 1/`nv' {
        local cmd : subinstr local command "@v@" `"`v`j''"', all
        restore, preserve
        if `"`setup'"' != "" {
            capture noisily quietly `setup'
            if _rc {
                display as error "qa_option_effect: setup() failed (rc `=_rc')"
                exit 198
            }
        }
        capture noisily _qa_mm_run `j' `"`cmd'"' `"`returns'"'
        if _rc {
            local rcj = _rc
            restore
            display as error `"qa_option_effect: property violated: value [`v`j''] refused (rc `rcj') on a route that consumes it"'
            exit 9
        }
    }
    restore
    local nit : word count `returns'
    tempname d dd
    scalar `d' = 0
    local moved ""
    forvalues j = 2/`nv' {
        forvalues i = 1/`nit' {
            mata: st_numscalar("`dd'", _qa_mm_diff(st_matrix("__qa_mm1_`i'"), ///
                st_matrix("__qa_mm`j'_`i'")))
            if scalar(`dd') > `tol' local moved `moved' `: word `i' of `returns''
            if scalar(`dd') > scalar(`d') scalar `d' = scalar(`dd')
        }
    }
    forvalues j = 1/`nv' {
        forvalues i = 1/`nit' {
            capture matrix drop __qa_mm`j'_`i'
        }
    }
    local moved : list uniq moved
    if "`inert'" == "" & "`moved'" == "" {
        display as error "qa_option_effect: property violated: option is inert -- no declared output changed across values (`values')"
        exit 9
    }
    if "`inert'" != "" & "`moved'" != "" {
        display as error "qa_option_effect: property violated: inert-by-design option changed `moved'"
        exit 9
    }
    return scalar maxreldif = scalar(`d')
    return local changed "`moved'"
end

capture mata: mata drop _qa_mm_diff()
capture mata: mata drop _qa_mm_vdigest()
capture mata: mata drop _qa_mm_fp()
capture mata: mata drop _qa_mm_colfp()
capture mata: mata drop _qa_mm_chars()
capture mata: mata drop _qa_mm_logfind()
mata:
// Does a text log contain needle once wrapped lines ("> " continuations)
// are rejoined?
real scalar _qa_mm_logfind(string scalar path, string scalar needle)
{
    string colvector lines
    string scalar t
    real scalar i

    lines = cat(path)
    t = ""
    for (i = 1; i <= rows(lines); i++) {
        if (substr(lines[i], 1, 2) == "> ") t = t + substr(lines[i], 3, .)
        else t = t + char(10) + lines[i]
    }
    return(strpos(t, needle) > 0)
}

// Digest of every characteristic attached to one variable or _dta.
string scalar _qa_mm_chars(string scalar owner)
{
    string colvector ch
    string scalar t
    real scalar k

    ch = st_dir("char", owner, "*")
    if (rows(ch)) ch = sort(ch, 1)
    t = ""
    for (k = 1; k <= rows(ch); k++) {
        t = t + ch[k] + "=" + st_global(owner + "[" + ch[k] + "]") + ";"
    }
    return(strofreal(hash1(t, 2147483647)))
}

// Largest reldif between two equally shaped matrices; missing values match
// only an identical missing code; a shape mismatch is +infinity (maxdouble).
real scalar _qa_mm_diff(real matrix A, real matrix B)
{
    real scalar i, j, d, m

    if (rows(A) != rows(B) | cols(A) != cols(B)) return(maxdouble())
    m = 0
    for (i = 1; i <= rows(A); i++) {
        for (j = 1; j <= cols(A); j++) {
            if (missing(A[i, j]) | missing(B[i, j])) {
                if (A[i, j] != B[i, j]) return(maxdouble())
                continue
            }
            d = reldif(A[i, j], B[i, j])
            if (d > m) m = d
        }
    }
    return(m)
}

// Order-sensitive digest of one column: sum of value * cos(row).
real rowvector _qa_mm_colfp(real colvector x)
{
    real colvector w, v
    w = cos(1::rows(x))
    v = editmissing(x, 0)
    return((quadsum(v :* w), quadsum(missing(x) :* w), rows(x)))
}

real rowvector _qa_mm_vdigest(string scalar v)
{
    string colvector s
    real colvector h
    real scalar i
    if (st_isstrvar(v)) {
        s = st_sdata(., v)
        h = J(rows(s), 1, .)
        for (i = 1; i <= rows(s); i++) h[i] = hash1(s[i], 2147483647)
        return(_qa_mm_colfp(h))
    }
    return(_qa_mm_colfp(st_data(., v)))
}

// Data fingerprint: variable names and types, every column's digest, and
// every _dta[] and variable characteristic.
string scalar _qa_mm_fp(real matrix eb)
{
    real scalar j
    real rowvector d
    string scalar s, nm
    string colvector ch

    s = strofreal(st_nobs()) + "/" + strofreal(st_nvar())
    for (j = 1; j <= st_nvar(); j++) {
        nm = st_varname(j)
        d = _qa_mm_vdigest(nm)
        s = s + "|" + nm + ":" + st_vartype(j) + ":" +
            strofreal(d[1], "%21x") + ":" + strofreal(d[2], "%21x")
        s = s + ":" + _qa_mm_chars(nm)
    }
    s = s + "|_dta:" + _qa_mm_chars("_dta")
    s = s + "|eb:" + strofreal(hash1(invtokens(strofreal(vec(eb)', "%21x")), 2147483647))
    return(s)
}
end
