*! tabcell Version 2.5.5  2026/10/07
*! One formatter for publication cells: estimate (CI), p, n, n (%), e/n (%), median (IQR), rate (CI)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
SYNTAX
    tabcell est [coef] [, eform scale(#) format(%fmt) sep(str) level(#) missing(str)]
        sources (exactly one):
          coef             a coefficient of the active e(): _b[coef], _se[coef];
                           t interval when e(df_r) exists, else normal
          lincom           the last lincom: r(estimate), r(se), r(lb), r(ub)
          nlcom            the last nlcom: r(b), r(V) (coef names the column)
          matrix(M row)    a row of a matrix, e.g. matrix(r(table)' mpg); its
                           columns b, ll, ul, or cols(# # #)
          b() ll() ul()    explicit numbers; or b() se() for a normal interval
    tabcell p ,   p(#) [pdp(#) highpdp(#) pstyle(table|footnote|Pfootnote) missing(str)]
    tabcell n ,   n(#) [mincell(#) nformat() missing(str)]
    tabcell np ,  n(#) d(#) [ci(exact) level(#) sep(str) nocount mincell(#) nformat() pformat() missing(str)]
    tabcell enp , e(#) n(#) [mincell(#) nformat() pformat() missing(str)]
    tabcell iqr , median(#) q1(#) q3(#) [format() sep() missing(str)]
    tabcell rate, e(#) pt(#) per(#) [ci(exact|poisson) level(#) format() sep() mincell(#) missing(str)]

    digits(#) is format(%9.#f) wherever format() applies (est, iqr, rate).

    generate(newvar) [if] [in]: the numeric options are expressions in the
    data and a string variable is filled in one vectorised pass. Data are
    never written unless generate() is given.

    local(name) / global(name) (scalar forms): also store the cell text in a
    local of the caller (c_local) or a global; on error the macro is cleared,
    so a captured failure never leaves a stale cell behind.

    ci(exact) (np): the exact binomial (Clopper-Pearson 1934) interval for the
    percentage, n (pct; lo, hi), with lo = invibeta(n, d-n+1, a/2) and
    hi = invibetatail(n+1, d-n, a/2); lo = 0 when n = 0 and hi = 1 when n = d,
    as in [R] ci, Methods and formulas, and Thulin (2014, eq. 4).
    nocount (np): the percentage alone, pct, or pct (lo, hi) with ci(exact);
    a masked count prints the withheld-value text, never its percentage.

    rate: the incidence rate e/pt*per with ratetab's limits ([R] ci, Methods
    and formulas, Poisson mean; [ST] strate; rate-intervals.notes.md):
      ci(exact)   (default) invpoissontail(e, a/2)/pt*per (0 when e = 0),
                  invpoisson(e, a/2)/pt*per
      ci(poisson) rate*exp(-/+ z/sqrt(e)), the log-rate Wald limits of
                  strate; at e = 0 the exact limits (0, -ln(a/2)/pt*per)
    mincell(#) withholds a rate with 1 to #-1 events: the cell prints
    "–" (en dash), as ratetab and stratetab print a withheld rate.

A missing or non-finite value is refused (rc 459) unless missing("text")
is given; a failed fit can never print as ". (., .)".
*/

capture program drop tabcell
program define tabcell, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    tempname _cframe _M _sb _sll _sul _sse _sq _s1 _s2 _s3
    local _frame_made 0
    local _set_local ""
    local _set_global ""
    capture noisily {
        **# local()/global() names first, from a copy of the command line,
        * so a call that fails anywhere later (a bad form word, an unknown
        * option, a failed syntax) still clears the macros it named. A name
        * that fails these same rules is not recorded and clears nothing.
        local _cl0 : copy local 0
        _parse comma _cl_lhs _cl_rhs : _cl0
        local 0 : copy local _cl_rhs
        capture syntax [, LOCal(name) GLOBal(name) *]
        if !_rc {
            if "`local'" != "" & ustrlen("`local'") <= 31 local _set_local "`local'"
            if "`global'" != "" & substr("`global'", 1, 1) != "_" local _set_global "`global'"
        }
        local local ""
        local global ""
        local options ""
        local 0 : copy local _cl0
        gettoken form 0 : 0, parse(" ,")
        local form = lower(strtrim(`"`form'"'))
        if !inlist(`"`form'"', "est", "p", "n", "np", "enp", "iqr", "rate") {
            display as error `"tabcell: the first word must be est, p, n, np, enp, iqr, or rate"'
            exit 198
        }
        syntax [anything(name=coef)] [if] [in] [, ///
            Format(string) CFormat(string) SEP(string) Level(real -1) EFORM ///
            MISSing(string asis) GENerate(name) ///
            B(string) LL(string) UL(string) SE(string) ///
            LINcom NLcom MATrix(string) COLs(numlist min=3 max=3 integer >0) ///
            P(string) PDP(integer 3) HIGHPDP(integer 2) PSTYle(string) ///
            N(string) D(string) E(string) MEDian(string) Q1(string) Q3(string) ///
            MINcell(integer 0) NFormat(string) PFormat(string) SCALE(string) ///
            LOCal(name) GLOBal(name) CI(string) PT(string) PER(string) NOCount ///
            DIGits(integer -1)]
        * sep() is data (help tabtools##sep): read and written in Mata only,
        * never re-expanded; _sep_opt hands it to _tabcell_render unchanged
        mata: st_local("_sep_given", strofreal(st_local("sep") != ""))

        **# local()/global(): validate the names before anything else, so the
        * cleanup zone clears only a macro the caller could have named.
        if "`local'" != "" {
            if ustrlen("`local'") > 31 {
                display as error "local(): `local' is longer than 31 characters"
                exit 198
            }
            local _set_local "`local'"
        }
        if "`global'" != "" {
            if substr("`global'", 1, 1) == "_" {
                display as error "global(): a global macro name may not begin with an underscore"
                exit 198
            }
            local _set_global "`global'"
        }

        **# Source capture first: r() and e() belong to the caller until the
        * first rclass call below.
        local _src ""
        local _nsrc = (`"`coef'"' != "" & "`nlcom'" == "") + ("`lincom'" != "") + ///
            ("`nlcom'" != "") + (`"`matrix'"' != "") + (`"`b'"' != "")
        if "`form'" == "est" & `_nsrc' != 1 {
            display as error "tabcell est: give exactly one source: a coefficient name, lincom, nlcom, matrix(), or b()"
            exit 198
        }
        if "`form'" != "est" & (`"`coef'"' != "" | "`lincom'`nlcom'" != "" | `"`matrix'"' != "") {
            display as error "tabcell `form': coefficient, lincom, nlcom and matrix() belong to tabcell est"
            exit 198
        }
        if `level' == -1 local _level_given 0
        else {
            local _level_given 1
            if `level' < 10 | `level' > 99.99 {
                display as error "level() must be between 10 and 99.99"
                exit 198
            }
        }
        local _gen = ("`generate'" != "")
        if `_gen' & "`local'`global'" != "" {
            display as error "local() and global() store one cell; with generate() the cells are a variable"
            exit 198
        }
        local ci = strtrim(lower(`"`ci'"'))
        * rate: the exact Poisson limits unless ci(poisson) is asked for
        if "`form'" == "rate" & `"`ci'"' == "" local ci "exact"
        if `"`ci'"' != "" {
            if !inlist("`form'", "np", "rate") {
                display as error "ci() belongs to tabcell np and tabcell rate"
                exit 198
            }
            if "`form'" == "np" & `"`ci'"' != "exact" {
                display as error `"ci(): "`ci'" is not supported; the interval is ci(exact) (Clopper-Pearson)"'
                exit 198
            }
            if "`form'" == "rate" & !inlist(`"`ci'"', "exact", "poisson") {
                display as error `"ci(): "`ci'" is not supported; give ci(exact) or ci(poisson)"'
                exit 198
            }
            if !`_level_given' local level = c(level)
        }
        if `_gen' & "`form'" == "est" & `"`b'"' == "" {
            display as error "tabcell est, generate() takes its numbers from b() with ll()/ul() or se()"
            exit 198
        }

        if "`form'" == "est" & `"`b'"' == "" {
            if `"`ll'`ul'`se'"' != "" {
                display as error "ll(), ul() and se() go with b()"
                exit 198
            }
            if "`lincom'" != "" {
                local _src "lincom"
                capture confirm scalar r(estimate)
                local _rc1 = _rc
                capture confirm scalar r(se)
                if `_rc1' | _rc {
                    display as error "tabcell est, lincom: no lincom results in r(); run lincom immediately before tabcell"
                    exit 301
                }
                * r() left by an earlier tabcell (it now carries r(se) and
                * r(p)) is not lincom's: its estimate may be scaled or
                * exponentiated. lincom posts no r(form).
                if `"`r(form)'"' != "" {
                    display as error "tabcell est, lincom: r() holds tabcell's own results, not lincom's; run lincom immediately before tabcell"
                    exit 301
                }
                * keep every scalar lincom left (estimate, se, lb, ub, level,
                * df, t or z, p): tabcell is rclass and clears r() on return
                local _lc_names : r(scalars)
                foreach _nm of local _lc_names {
                    tempname _lc_`_nm'
                    scalar `_lc_`_nm'' = r(`_nm')
                }
                scalar `_sb' = r(estimate)
                scalar `_sse' = r(se)
                local _rlevel = r(level)
                local _rdf = r(df)
                * lincom, eform (or, irr, hr, ...) stores exp(b), the delta-method
                * se exp(b)*se_b and exponentiated limits: the interval is then
                * geometric, not arithmetic, about the estimate
                local _lexp 0
                if !missing(r(lb)) & !missing(r(ub)) & `_sb' > 0 & r(ub) > r(lb) {
                    if reldif((r(lb) + r(ub)) / 2, `_sb') > 1e-8 & ///
                        reldif(sqrt(r(lb) * r(ub)), `_sb') < 1e-8 local _lexp 1
                }
                if `_lexp' & "`eform'" != "" {
                    display as error "tabcell est, lincom: the last lincom is already exponentiated (eform, or, irr, ...); drop eform"
                    exit 198
                }
                if !`_level_given' {
                    local level = cond(missing(`_rlevel'), c(level), `_rlevel')
                }
                if !missing(`_rlevel') & abs(`level' - `_rlevel') < 1e-8 & ///
                    !missing(r(lb)) & !missing(r(ub)) {
                    scalar `_sll' = r(lb)
                    scalar `_sul' = r(ub)
                }
                else {
                    if !missing(`_rdf') scalar `_sq' = invttail(`_rdf', (1 - `level' / 100) / 2)
                    else scalar `_sq' = invnormal(1 - (1 - `level' / 100) / 2)
                    if `_lexp' {
                        * back to the coefficient scale: b = ln(est), se_b = se/est
                        scalar `_sll' = exp(ln(`_sb') - `_sq' * `_sse' / `_sb')
                        scalar `_sul' = exp(ln(`_sb') + `_sq' * `_sse' / `_sb')
                    }
                    else {
                        scalar `_sll' = `_sb' - `_sq' * `_sse'
                        scalar `_sul' = `_sb' + `_sq' * `_sse'
                    }
                }
            }
            else if "`nlcom'" != "" {
                local _src "nlcom"
                capture confirm matrix r(b)
                local _rc1 = _rc
                capture confirm matrix r(V)
                if `_rc1' | _rc {
                    display as error "tabcell est, nlcom: no nlcom results in r(); run nlcom immediately before tabcell"
                    exit 301
                }
                matrix `_M' = r(b)
                local _rdf = r(df)
                local _j = 1
                if `"`coef'"' != "" {
                    local _j = colnumb(`_M', `"`coef'"')
                    if missing(`_j') {
                        display as error `"tabcell est, nlcom: "`coef'" is not an nlcom result"'
                        exit 111
                    }
                }
                scalar `_sb' = el(`_M', 1, `_j')
                matrix `_M' = r(V)
                scalar `_sse' = el(`_M', `_j', `_j')
                scalar `_sse' = cond(`_sse' > 0 & !missing(`_sse'), sqrt(`_sse'), .)
                if !`_level_given' local level = c(level)
                if !missing(`_rdf') scalar `_sq' = invttail(`_rdf', (1 - `level' / 100) / 2)
                else scalar `_sq' = invnormal(1 - (1 - `level' / 100) / 2)
                scalar `_sll' = `_sb' - `_sq' * `_sse'
                scalar `_sul' = `_sb' + `_sq' * `_sse'
            }
            else if `"`matrix'"' != "" {
                local _src "matrix"
                local _mspec = strtrim(`"`matrix'"')
                local _nw : word count `_mspec'
                if `_nw' < 2 {
                    display as error "matrix() takes a matrix and a row: matrix(name row)"
                    exit 198
                }
                local _row : word `_nw' of `_mspec'
                local _mexp = strtrim(substr(`"`_mspec'"', 1, strrpos(`"`_mspec'"', `"`_row'"') - 1))
                capture matrix `_M' = `_mexp'
                if _rc {
                    display as error `"matrix(): "`_mexp'" is not a matrix expression"'
                    exit 111
                }
                if regexm(`"`_row'"', "^[0-9]+$") local _i = real(`"`_row'"')
                else local _i = rownumb(`_M', `"`_row'"')
                if missing(`_i') | `_i' < 1 | `_i' > rowsof(`_M') {
                    display as error `"matrix(): row "`_row'" not found"'
                    exit 111
                }
                if "`cols'" != "" {
                    local _cb : word 1 of `cols'
                    local _cl : word 2 of `cols'
                    local _cu : word 3 of `cols'
                }
                else {
                    local _cb = colnumb(`_M', "b")
                    local _cl = colnumb(`_M', "ll")
                    local _cu = colnumb(`_M', "ul")
                    if missing(`_cb') | missing(`_cl') | missing(`_cu') {
                        display as error "matrix(): columns b, ll and ul not found; give cols(# # #)"
                        exit 111
                    }
                }
                foreach _c in `_cb' `_cl' `_cu' {
                    if `_c' > colsof(`_M') {
                        display as error "cols(): column `_c' is beyond the matrix"
                        exit 198
                    }
                }
                scalar `_sb' = el(`_M', `_i', `_cb')
                scalar `_sll' = el(`_M', `_i', `_cl')
                scalar `_sul' = el(`_M', `_i', `_cu')
                if `_level_given' {
                    display as error "level() cannot be applied to matrix(): the limits are read as stored"
                    exit 198
                }
            }
            else {
                local _src "e()"
                if `"`e(cmd)'"' == "" {
                    display as error "tabcell est: no estimation results; fit a model or give lincom, nlcom, matrix() or b()"
                    exit 301
                }
                capture scalar `_sb' = _b[`coef']
                if _rc {
                    display as error `"tabcell est: coefficient "`coef'" not found in e(b)"'
                    exit 111
                }
                scalar `_sse' = _se[`coef']
                * An omitted or base term has se 0: not an estimate.
                if !(`_sse' > 0) | missing(`_sse') {
                    scalar `_sb' = .
                    scalar `_sse' = .
                }
                if !`_level_given' local level = c(level)
                if !missing(e(df_r)) scalar `_sq' = invttail(e(df_r), (1 - `level' / 100) / 2)
                else scalar `_sq' = invnormal(1 - (1 - `level' / 100) / 2)
                scalar `_sll' = `_sb' - `_sq' * `_sse'
                scalar `_sul' = `_sb' + `_sq' * `_sse'
            }
        }
        else if "`form'" == "est" {
            local _src "numbers"
            if `"`se'"' != "" & `"`ll'`ul'"' != "" {
                display as error "give ll() and ul(), or se(), not both"
                exit 198
            }
            if `"`se'"' == "" & (`"`ll'"' == "" | `"`ul'"' == "") {
                display as error "b() needs ll() and ul(), or se()"
                exit 198
            }
            if `"`se'"' != "" & !`_level_given' local level = c(level)
            if `_level_given' & `"`se'"' == "" {
                display as error "level() applies only to b() se(); ll() and ul() are printed as given"
                exit 198
            }
        }

        **# Option ownership per form
        if `"`format'"' != "" & `"`cformat'"' != "" {
            display as error "format() and cformat() are synonyms; give one"
            exit 198
        }
        if `"`cformat'"' != "" local format `"`cformat'"'
        * digits(#): shorthand for format(%9.#f)
        if `digits' != -1 {
            if `"`format'"' != "" {
                display as error "digits() and format() may not be combined"
                exit 198
            }
            if `digits' < 0 | `digits' > 10 {
                display as error "digits() must be between 0 and 10"
                exit 198
            }
            if !inlist("`form'", "est", "iqr", "rate") {
                display as error "tabcell `form' does not take: digits()"
                exit 198
            }
            local format "%9.`digits'f"
        }
        local _not_est ""
        if "`form'" != "est" {
            if "`eform'" != "" local _not_est "`_not_est' eform"
            if `_level_given' & `"`ci'"' == "" local _not_est "`_not_est' level()"
            if `"`b'`ll'`ul'`se'"' != "" local _not_est "`_not_est' b()/ll()/ul()/se()"
        }
        if !inlist("`form'", "est", "iqr", "rate") {
            if `"`format'"' != "" local _not_est "`_not_est' format()"
            if `_sep_given' & `"`ci'"' == "" local _not_est "`_not_est' sep()"
        }
        if "`form'" != "p" & (`pdp' != 3 | `highpdp' != 2 | `"`p'`pstyle'"' != "") local _not_est "`_not_est' p()/pdp()/highpdp()/pstyle()"
        if !inlist("`form'", "n", "np", "enp", "rate") & `mincell' != 0 local _not_est "`_not_est' mincell()"
        if !inlist("`form'", "n", "np", "enp") & `"`nformat'"' != "" local _not_est "`_not_est' nformat()"
        if !inlist("`form'", "np", "enp") & `"`pformat'"' != "" local _not_est "`_not_est' pformat()"
        if !inlist("`form'", "n", "np", "enp") & `"`n'"' != "" local _not_est "`_not_est' n()"
        if "`form'" != "est" & `"`scale'"' != "" local _not_est "`_not_est' scale()"
        if "`form'" != "np" & `"`d'"' != "" local _not_est "`_not_est' d()"
        if !inlist("`form'", "enp", "rate") & `"`e'"' != "" local _not_est "`_not_est' e()"
        if "`form'" != "rate" & `"`pt'`per'"' != "" local _not_est "`_not_est' pt()/per()"
        if "`form'" != "np" & "`nocount'" != "" local _not_est "`_not_est' nocount"
        if "`form'" != "iqr" & `"`median'`q1'`q3'"' != "" local _not_est "`_not_est' median()/q1()/q3()"
        if `"`_not_est'"' != "" {
            display as error "tabcell `form' does not take:`_not_est'"
            exit 198
        }
        if `mincell' < 0 {
            display as error "mincell() must be a nonnegative integer"
            exit 198
        }
        if "`form'" == "p" & `"`p'"' == "" {
            display as error "tabcell p requires p()"
            exit 198
        }
        * pstyle(footnote): p = 0.012, p < 0.001, p > 0.99 (prose);
        * pstyle(Pfootnote): the same with a capital P (P = 0.012); the
        * default, table, is the bare regtab text
        local pstyle = strtrim(lower(`"`pstyle'"'))
        if !inlist(`"`pstyle'"', "", "table", "footnote", "pfootnote") {
            display as error "pstyle() must be table, footnote, or Pfootnote"
            exit 198
        }
        if "`pstyle'" == "" local pstyle "table"
        if "`form'" == "n" & `"`n'"' == "" {
            display as error "tabcell n requires n()"
            exit 198
        }
        * scale(#): multiplies the estimate and both limits (after eform),
        * e.g. scale(1000) for a rate per 1,000; tabcell est only
        local _scale 1
        if `"`scale'"' != "" {
            capture confirm number `scale'
            if _rc {
                display as error `"scale(): "`scale'" is not a number"'
                exit 198
            }
            if !(`scale' > 0) | missing(`scale') {
                display as error "scale() must be a positive number"
                exit 198
            }
            local _scale = `scale'
        }
        if "`form'" == "np" & (`"`n'"' == "" | `"`d'"' == "") {
            display as error "tabcell np requires n() and d()"
            exit 198
        }
        if "`form'" == "enp" & (`"`e'"' == "" | `"`n'"' == "") {
            display as error "tabcell enp requires e() and n()"
            exit 198
        }
        if "`form'" == "iqr" & (`"`median'"' == "" | `"`q1'"' == "" | `"`q3'"' == "") {
            display as error "tabcell iqr requires median(), q1() and q3()"
            exit 198
        }
        * rate: per() is a positive number, never an expression in the data;
        * required, so a rate never prints without the unit it is per
        local _per 1
        if "`form'" == "rate" {
            if `"`e'"' == "" | `"`pt'"' == "" | `"`per'"' == "" {
                display as error "tabcell rate requires e(), pt() and per()"
                exit 198
            }
            capture confirm number `per'
            if _rc {
                display as error `"per(): "`per'" is not a number"'
                exit 198
            }
            if !(`per' > 0) | missing(`per') {
                display as error "per() must be a positive number"
                exit 198
            }
            * the number as typed, never re-rounded through a local
            local _per : copy local per
        }
        if !`_gen' & `"`if'`in'"' != "" {
            display as error "if and in require generate()"
            exit 198
        }

        **# Formats
        * rate: one decimal by default, as ratetab prints its rates
        if `"`format'"' == "" local format = cond("`form'" == "rate", "%9.1f", "%9.2f")
        if `"`nformat'"' == "" local nformat "%12.0fc"
        if `"`pformat'"' == "" local pformat "%4.1f"
        foreach _f in format nformat pformat {
            local _fv `"``_f''"'
            capture confirm numeric format `_fv'
            if _rc | regexm(`"`_fv'"', "^%-?t") {
                display as error `"`_f'(): "`_fv'" is not a numeric display format"'
                exit 198
            }
        }
        mata: st_local("sep", st_local("sep") == "" ? ", " : st_local("sep"))
        mata: st_local("_sep_opt", "sep(" + (strpos(st_local("sep"), char(34)) ? char(96) + char(34) + st_local("sep") + char(34) + char(39) : char(34) + st_local("sep") + char(34)) + ")")
        * A decimal-comma format (%9,2f) for the limits with a comma in sep():
        * printed as before, with a warning (regtab and effecttab refuse it)
        local _lim_opt = cond("`form'" == "np", "pformat", "format")
        local _lim_fmt `"``_lim_opt''"'
        mata: st_local("_sep_comma", strofreal(strpos(st_local("sep"), ",") > 0))
        if `_sep_comma' & (inlist("`form'", "est", "iqr", "rate") | ("`form'" == "np" & "`ci'" != "")) {
            if ustrregexm(`"`_lim_fmt'"', "^%-?0?[0-9]*,") {
                display as text "(tabcell: `_lim_opt'(`_lim_fmt') writes a decimal comma and the interval separator holds a comma: the two limits are hard to tell apart (help tabtools##sep))"
            }
        }

        **# missing(): present (even as "") or absent
        local _hasmiss = (`"`macval(missing)'"' != "")
        if `_hasmiss' {
            * one layer of simple or compound quotes is removed; unquoted
            * text is taken whole
            * The text is data: copied, never re-expanded. A one-line
            * "if ... local missing `"`macval(_m1)'"'" re-expanded it, so a
            * $name in missing() printed the global's value.
            gettoken _m1 _m2 : missing, qed(_mq)
            if `_mq' & strtrim(`"`macval(_m2)'"') == "" {
                local missing : copy local _m1
            }
            else {
                mata: st_local("missing", strtrim(st_local("missing")))
            }
        }

        **# The numbers, as named expressions
        if "`form'" == "est" local _exps `"`b' \ `ll' \ `ul'"'
        if "`form'" == "p" local _exps `"`p'"'
        if "`form'" == "n" local _exps `"`n'"'
        if "`form'" == "np" local _exps `"`n' \ `d'"'
        if "`form'" == "enp" local _exps `"`e' \ `n'"'
        if "`form'" == "iqr" local _exps `"`median' \ `q1' \ `q3'"'
        if "`form'" == "rate" local _exps `"`e' \ `pt'"'
        local _names "v1 v2 v3"

        if `_gen' {
            confirm new variable `generate'
            marksample touse, novarlist
            quietly count if `touse'
            if r(N) == 0 {
                display as error "tabcell, generate(): no observations"
                exit 2000
            }
            local _vlist ""
            if "`form'" == "est" & `"`se'"' != "" {
                tempvar v1 v2 v3 vse
                quietly gen double `v1' = (`b') if `touse'
                quietly gen double `vse' = (`se') if `touse'
                quietly replace `vse' = . if !(`vse' > 0)
                scalar `_sq' = invnormal(1 - (1 - `level' / 100) / 2)
                quietly gen double `v2' = `v1' - `_sq' * `vse' if `touse'
                quietly gen double `v3' = `v1' + `_sq' * `vse' if `touse'
                local _vlist "`v1' `v2' `v3'"
            }
            else {
                local _k = 0
                local _rest `"`_exps'"'
                while `"`_rest'"' != "" {
                    gettoken _x _rest : _rest, parse("\")
                    if `"`_x'"' == "\" continue
                    local ++_k
                    tempvar v`_k'
                    capture quietly gen double `v`_k'' = (`_x') if `touse'
                    if _rc {
                        display as error `"tabcell: "`_x'" is not a numeric expression in the data"'
                        exit 198
                    }
                    local _vlist "`_vlist' `v`_k''"
                }
            }
            if "`eform'" != "" {
                foreach _v of local _vlist {
                    quietly replace `_v' = exp(`_v') if `touse'
                }
            }
            if `"`scale'"' != "" {
                foreach _v of local _vlist {
                    quietly replace `_v' = `_v' * `_scale' if `touse'
                }
            }
            tempvar _out
            _tabcell_render `form' `_vlist', touse(`touse') generate(`_out') ///
                fmt(`format') `macval(_sep_opt)' missing(`"`macval(missing)'"') ///
                hasmissing(`_hasmiss') pdp(`pdp') highpdp(`highpdp') pstyle(`pstyle') ///
                nformat(`nformat') pformat(`pformat') mincell(`mincell') ///
                ci(`ci') level(`level') per(`_per') `nocount'
            local _N = r(N)
            local _N_missing = r(N_missing)
            rename `_out' `generate'  // stata-dev-ignore: unchecked-commit — tabcell refuses an empty sample (exit 2000) at its marksample count, and _tabcell_render refuses non-estimable cells (exit 459) unless missing() is given
            quietly compress `generate'
            return local varname "`generate'"
            return scalar N = `_N'
            return scalar N_missing = `_N_missing'
            return local form "`form'"
        }
        else {
            **# Scalar path: post the numbers to a one-row frame and render there
            if "`form'" == "est" & "`_src'" == "numbers" {
                foreach _o in b ll ul se {
                    if `"``_o''"' == "" continue
                    capture confirm variable ``_o'', exact
                    if !_rc {
                        display as error `"`_o'() names a variable; use generate() to format a variable"'
                        exit 198
                    }
                    capture scalar `_s1' = (``_o'')
                    if _rc {
                        display as error `"`_o'(): "``_o''" is not a number"'
                        exit 198
                    }
                }
                scalar `_sb' = (`b')
                if `"`se'"' != "" {
                    scalar `_sse' = (`se')
                    if !(`_sse' > 0) scalar `_sse' = .
                    scalar `_sq' = invnormal(1 - (1 - `level' / 100) / 2)
                    scalar `_sll' = `_sb' - `_sq' * `_sse'
                    scalar `_sul' = `_sb' + `_sq' * `_sse'
                }
                else {
                    scalar `_sll' = (`ll')
                    scalar `_sul' = (`ul')
                }
            }
            if "`form'" == "est" {
                scalar `_s1' = `_sb'
                scalar `_s2' = `_sll'
                scalar `_s3' = `_sul'
                local _k = 3
            }
            else {
                local _k = 0
                local _rest `"`_exps'"'
                while `"`_rest'"' != "" {
                    gettoken _x _rest : _rest, parse("\")
                    if `"`_x'"' == "\" continue
                    local ++_k
                    capture confirm variable `_x', exact
                    if !_rc {
                        display as error `"tabcell: "`_x'" is a variable; use generate() to format a variable"'
                        exit 198
                    }
                    capture scalar `_s`_k'' = (`_x')
                    if _rc {
                        display as error `"tabcell: "`_x'" is not a number"'
                        exit 198
                    }
                }
            }
            if "`eform'" != "" {
                forvalues _j = 1/`_k' {
                    scalar `_s`_j'' = exp(`_s`_j'')
                }
            }
            if `"`scale'"' != "" {
                forvalues _j = 1/`_k' {
                    scalar `_s`_j'' = `_s`_j'' * `_scale'
                }
            }
            frame create `_cframe'
            local _frame_made 1
            frame `_cframe' {
                quietly set obs 1
                local _vlist ""
                forvalues _j = 1/`_k' {
                    quietly gen double v`_j' = `_s`_j''
                    local _vlist "`_vlist' v`_j'"
                }
                quietly gen byte touse = 1
                _tabcell_render `form' `_vlist', touse(touse) generate(cell) ///
                    fmt(`format') `macval(_sep_opt)' missing(`"`macval(missing)'"') ///
                    hasmissing(`_hasmiss') pdp(`pdp') highpdp(`highpdp') pstyle(`pstyle') ///
                    nformat(`nformat') pformat(`pformat') mincell(`mincell') ///
                    ci(`ci') level(`level') per(`_per') `nocount' ///
                    cilimits(`=cond("`ci'" != "", "cilb ciub ciest", "")')
                local _isbad = r(N_missing)
                mata: st_local("_cell", st_sdata(1, "cell"))
                if "`ci'" != "" {
                    scalar `_s1' = cilb[1]
                    scalar `_s2' = ciub[1]
                    scalar `_s3' = ciest[1]
                }
            }
            display as result `"`macval(_cell)'"'
            return local cell `"`macval(_cell)'"'
            return local form "`form'"
            return scalar missing = `_isbad'
            if "`ci'" != "" & "`form'" == "np" {
                * the percentage and limits as printed (missing when the
                * cell prints none: a 0 denominator, a masked or missing cell)
                return scalar pct = `_s3'
                return scalar lb = `_s1'
                return scalar ub = `_s2'
                return scalar level = `level'
                return local citype "exact"
            }
            if "`form'" == "rate" {
                * the rate and limits per per() as printed (missing when the
                * cell prints none: masked, missing, or no person-time)
                return scalar rate = `_s3'
                return scalar lb = `_s1'
                return scalar ub = `_s2'
                return scalar level = `level'
                return scalar per = `_per'
                return local citype "`ci'"
            }
            * copied, never re-expanded (a one-line if re-expands its command)
            if "`local'" != "" {
                c_local `local' : copy local _cell
            }
            if "`global'" != "" {
                global `global' : copy local _cell
            }
            if "`form'" == "est" {
                return local source "`_src'"
                return scalar estimate = `_s1'
                return scalar lb = `_s2'
                return scalar ub = `_s3'
                if "`_src'" != "matrix" & !("`_src'" == "numbers" & `"`se'"' == "") {
                    return scalar level = `level'
                }
                if `"`scale'"' != "" return scalar scale = `_scale'
                if "`_src'" == "lincom" {
                    * lincom's own results, kept: names tabcell does not use
                    * (p, se, df, t or z) as lincom stored them; estimate, lb,
                    * ub and level, which tabcell reports as printed, under
                    * lincom_*
                    foreach _nm of local _lc_names {
                        if inlist("`_nm'", "estimate", "lb", "ub", "level", "missing", "scale") {
                            return scalar lincom_`_nm' = `_lc_`_nm''
                        }
                        else return scalar `_nm' = `_lc_`_nm''
                    }
                }
            }
        }
    }
    local rc = _rc
    if `_frame_made' capture frame drop `_cframe'
    * a failed call clears the requested macro: never a stale cell
    if `rc' & "`_set_local'" != "" c_local `_set_local'
    if `rc' & "`_set_global'" != "" global `_set_global'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
