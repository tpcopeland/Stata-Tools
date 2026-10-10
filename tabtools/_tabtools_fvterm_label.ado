*! _tabtools_fvterm_label Version 2.6.2  2026/10/10
*! reader-facing label for an interaction or margins at() row key
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

/*
collect names an interaction row by its raw key ("1.foreign#c.weight",
"0.female#1.highbp") and a margins at() scenario by "2._at". This turns such
a key into the label a reader can use, from the variable and value labels of
the data in memory; call it before the data are replaced.

  1.foreign#c.weight   parent "Car origin # Weight (lbs.)",
                       child "Foreign # Weight (lbs.)"
  0.female#1.highbp    parent "Female # High BP", child "Male # Yes"
  c.mpg#c.weight       no parent, label "Mileage (mpg) # Weight (lbs.)"
  2._at                parent "at()", child "Age (years) = 60"

A factor level with no value label reads "<variable label> = <level>". An
_at component needs atmatrix() and atcols() from _tabtools_collect_atmatrix;
without them, or for an operator this does not know (L., o.), every output is
empty and the caller keeps collect's own label.

Usage: _tabtools_fvterm_label "<key>" [, atmatrix(name) atcols(string)
       atstats(string)]
Returns in the caller:
  _fvt_label    the row label ("" = leave the row as it is)
  _fvt_parent   the raw parent key, as the renderer prints it ("" = none)
  _fvt_plabel   the parent row's label
*/

capture program drop _tabtools_fvterm_label
program define _tabtools_fvterm_label, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    c_local _fvt_label ""
    c_local _fvt_parent ""
    c_local _fvt_plabel ""
    capture noisily {
        gettoken _key 0 : 0
        syntax [, ATMatrix(name) ATCols(string) ATStats(string)]
        local _parts = subinstr(`"`_key'"', "#", " ", .)
        local _nf 0
        local _np 0
        local _child ""
        local _all ""
        local _plab ""
        local _praw ""
        local _ok 1
        foreach _p of local _parts {
            local ++_np
            local _isfv 0
            if regexm(`"`_p'"', "^([0-9]+)[bon]*\.([A-Za-z_][A-Za-z0-9_]*)$") {
                local _lev = regexs(1)
                local _var = regexs(2)
                local _isfv 1
            }
            else if regexm(`"`_p'"', "^c\.([A-Za-z_][A-Za-z0-9_]*)$") {
                local _var = regexs(1)
            }
            else if regexm(`"`_p'"', "^([A-Za-z_][A-Za-z0-9_]*)$") {
                local _var = regexs(1)
            }
            else {
                local _ok 0
                continue, break
            }

            * the term's own text: a factor level, an at() scenario, or a
            * continuous variable
            if "`_var'" == "_at" {
                if "`atmatrix'" == "" | !`_isfv' {
                    local _ok 0
                    continue, break
                }
                _tabtools_fvterm_atrow `_lev', atmatrix(`atmatrix') atcols(`"`atcols'"') ///
                    atstats(`"`atstats'"')
                if `"`macval(_fvt_atlab)'"' == "" {
                    local _ok 0
                    continue, break
                }
                local _text : copy local _fvt_atlab
                local _ptext "at()"
            }
            else {
                capture confirm variable `_var', exact
                if _rc {
                    local _ok 0
                    continue, break
                }
                local _ptext : variable label `_var'
                if `"`macval(_ptext)'"' == "" local _ptext "`_var'"
                if `_isfv' {
                    local _vl : value label `_var'
                    local _text ""
                    if "`_vl'" != "" local _text : label `_vl' `_lev', strict
                    if `"`macval(_text)'"' == "" local _text `"`macval(_ptext)' = `_lev'"'
                }
                else local _text : copy local _ptext
            }

            if `_isfv' {
                local ++_nf
                if `_nf' == 1 local _child : copy local _text
                else local _child `"`macval(_child)' # `macval(_text)'"'
            }
            if `_np' == 1 {
                local _all : copy local _text
                local _plab : copy local _ptext
                local _praw "`_var'"
            }
            else {
                local _all `"`macval(_all)' # `macval(_text)'"'
                local _plab `"`macval(_plab)' # `macval(_ptext)'"'
                local _praw "`_praw'#`_var'"
            }
        }
        if `_ok' & `_np' > 0 {
            * a factor level sits under its parent row, indented as regtab's
            * single-factor levels are; a purely continuous product has none.
            * The row names every component ("Foreign # Weight (lbs.)", not
            * "Foreign"), so it never repeats a main-effect row's label: an
            * exact label match (cellnote(), comptab rows) must stay unique.
            if `_nf' > 0 {
                if `_np' > 1 local _child : copy local _all
                c_local _fvt_label `"  `macval(_child)'"'
                c_local _fvt_parent "`_praw'"
                c_local _fvt_plabel `"`macval(_plab)'"'
            }
            else if `_np' > 1 {
                c_local _fvt_label `"`macval(_all)'"'
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

* The scenario text of row j of an at() matrix: "Age (years) = 40, Male".
* atstats() holds each scenario's r(atstats#) words, scenarios separated by
* "|"; they say how each column was set, as margins prints it. A covariate
* left as observed is not named; one set to a statistic carries it
* ("Age (years) = 47.58 (mean)"); a factor at its proportions lists each
* level ("Sex (mean): Male = 0.4748, Female = 0.5252"), and an asbalanced factor
* reads "Female (asbalanced)". A scenario that fixes nothing reads "as
* observed".
capture program drop _tabtools_fvterm_atrow
program define _tabtools_fvterm_atrow, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    c_local _fvt_atlab ""
    capture noisily {
    syntax anything(name=row), ATMatrix(name) ATCols(string) [ATStats(string)]
    local _k : word count `atcols'
    local _out ""
    if `row' < 1 | `row' > rowsof(`atmatrix') | `_k' != colsof(`atmatrix') local _k 0
    * this scenario's words; none (or a count that does not match) reads
    * every fixed cell as a given value
    mata: _tt_fvt_rowstats(st_local("atstats"), `row')
    if `: word count `_rowstats'' != `_k' local _rowstats ""
    local _done ""
    forvalues j = 1/`_k' {
        local _c : word `j' of `atcols'
        local _st : word `j' of `_rowstats'
        if inlist("`_st'", "", "value") local _st "values"
        local _text ""
        if regexm("`_c'", "^([0-9]+)[bon]*\.([A-Za-z_][A-Za-z0-9_]*)$") {
            local _var = regexs(2)
            if strpos(" `_done' ", " `_var' ") continue
            local _done "`_done' `_var'"
            local _vlab "`_var'"
            local _vl ""
            capture confirm variable `_var', exact
            if !_rc {
                local _vlab : variable label `_var'
                if `"`macval(_vlab)'"' == "" local _vlab "`_var'"
                local _vl : value label `_var'
            }
            if "`_st'" == "asobserved" continue
            if "`_st'" == "asbalanced" {
                local _text `"`macval(_vlab)' (asbalanced)"'
            }
            else {
                * every level of this factor: one level at 1 and the rest at
                * 0 is a fixed level; anything else is listed level by level
                local _set ""
                local _nset 0
                local _frac 0
                local _fracs ""
                forvalues jj = `j'/`_k' {
                    local _cc : word `jj' of `atcols'
                    if !regexm("`_cc'", "^([0-9]+)[bon]*\.`_var'$") continue
                    local _ll = regexs(1)
                    local _v = `atmatrix'[`row', `jj']
                    if missing(`_v') continue
                    if `_v' == 1 {
                        local ++_nset
                        local _set `_ll'
                    }
                    else if `_v' != 0 local _frac 1
                    _tabtools_fvterm_num `_v'
                    local _lt ""
                    if "`_vl'" != "" local _lt : label `_vl' `_ll', strict
                    if `"`macval(_lt)'"' == "" local _lt `"`macval(_vlab)' = `_ll'"'
                    if `"`macval(_fracs)'"' == "" local _fracs `"`macval(_lt)' = `_fvt_num'"'
                    else local _fracs `"`macval(_fracs)', `macval(_lt)' = `_fvt_num'"'
                }
                if `_nset' == 1 & !`_frac' & "`_st'" == "values" {
                    if "`_vl'" != "" local _text : label `_vl' `_set', strict
                    if `"`macval(_text)'"' == "" local _text `"`macval(_vlab)' = `_set'"'
                }
                else if `"`macval(_fracs)'"' != "" {
                    * the statistic heads the factor's level list, so it
                    * reads as applying to every level
                    local _text : copy local _fracs
                    if "`_st'" != "values" local _text `"`macval(_vlab)' (`_st'): `macval(_fracs)'"'
                }
            }
        }
        else {
            local _v = `atmatrix'[`row', `j']
            if missing(`_v') | "`_st'" == "asobserved" continue
            local _vlab "`_c'"
            capture confirm variable `_c', exact
            if !_rc {
                local _vlab : variable label `_c'
                if `"`macval(_vlab)'"' == "" local _vlab "`_c'"
            }
            _tabtools_fvterm_num `_v'
            local _text `"`macval(_vlab)' = `_fvt_num'"'
            if "`_st'" != "values" local _text `"`macval(_text)' (`_st')"'
        }
        if `"`macval(_text)'"' == "" continue
        if `"`macval(_out)'"' == "" local _out : copy local _text
        else local _out `"`macval(_out)', `macval(_text)'"'
    }
    if `"`macval(_out)'"' == "" & `_k' > 0 local _out "as observed"
    c_local _fvt_atlab `"`macval(_out)'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

* A scenario value as text: up to seven significant digits, with a leading
* zero (0.4748333, not .4748333)
capture program drop _tabtools_fvterm_num
program define _tabtools_fvterm_num, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    c_local _fvt_num ""
    capture noisily {
        args v
        local _vs = strtrim(string(`v', "%9.0g"))
        if substr("`_vs'", 1, 1) == "." local _vs "0`_vs'"
        if substr("`_vs'", 1, 2) == "-." local _vs = "-0" + substr("`_vs'", 2, .)
        c_local _fvt_num "`_vs'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

* _rowstats in the caller: the words of scenario `row' in a "|"-separated
* list (empty pieces allowed)
capture mata: mata drop _tt_fvt_rowstats()
mata:
void _tt_fvt_rowstats(string scalar all, real scalar row)
{
    string rowvector t
    real scalar i, k

    st_local("_rowstats", "")
    if (all == "") return
    t = tokens(all, "|")
    k = 1
    for (i = 1; i <= cols(t); i++) {
        if (t[i] == "|") k++
        else if (k == row) st_local("_rowstats", t[i])
    }
}
end
