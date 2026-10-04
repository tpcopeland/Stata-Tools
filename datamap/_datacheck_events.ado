*! _datacheck_events Version 1.9.0  2026/10/03
*! datacheck events(): every level of a covariate carries enough events
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Evaluated by datacheck once per scope.  For each covariate and each of its
// nonmissing levels in scope, the sum of the event variable (restricted to
// the entry's own if condition) must be at least min().  A missing level is
// skipped because a model drops it; an explicit code such as 99 is a level.
//
// Records are posted to the record frame rf() in datacheck's column order:
// fam kind ok label variable grp observed obsnum expected nscope scope msg
// minshown omasked.  One fail record per failing level; one pass record per
// covariate when every level passes.  A covariate with no nonmissing level
// in scope fails: nothing was tested.
program define _datacheck_events, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local nfail = 0
    local anymask = 0
    capture noisily {
        syntax , RF(name) EV(varname) EVCOND(string) VARS(varlist) MIN(real) ///
            COND(string) KIND(string) [GRP(string) SCOPE(string) PFX(string) ///
            MASK(integer 0) NSCOPE(real 0)]
        local mtxt = strtrim(string(`min', "%12.0g"))
        tempvar tot tg rr
        foreach v of local vars {
            capture drop `tot'
            capture drop `tg'
            capture drop `rr'
            quietly bysort `v': egen double `tot' = total(`ev' * (`evcond')) ///
                if (`cond') & !missing(`v')
            // one tagged row per in-scope level; row numbers are taken after
            // the last sort so they address the rows as they now stand
            quietly egen byte `tg' = tag(`v') if (`cond') & !missing(`v')
            quietly generate long `rr' = _n
            quietly levelsof `rr' if `tg' == 1 & `tot' < `min', local(rows)
            local vlab : value label `v'
            capture confirm string variable `v'
            local isstr = (_rc == 0)
            local nf_v = 0
            foreach r of local rows {
                local k = `tot'[`r']
                if `isstr' local lev = `v'[`r']
                else {
                    local lev = strtrim(string(`v'[`r'], "%16.0g"))
                    if "`vlab'" != "" {
                        local ltxt : label `vlab' `=`v'[`r']', strict
                        if `"`ltxt'"' != "" local lev `"`lev' (`ltxt')"'
                    }
                }
                _datacheck_mcount `k' `mask'
                local ks "`r(s)'"
                local knum = r(num)
                local km = r(masked)
                if `km' local anymask = 1
                local mins = cond(`km' | `k' < 1, ., `k')
                // the ledger records the level's value, not its label
                quietly _datacheck_gtext `v', row(`r')
                local g `"`v' = `r(val)'"'
                if `"`grp'"' != "" local g `"`grp'; `g'"'
                local msg `"`pfx'events(`ev'): `v' = `lev' has `ks' events, expected >= `mtxt'"'
                frame post `rf' ("events") ("`kind'") (0) ("`ev'") ("`v'") ///
                    (`"`macval(g)'"') ("`ks' events") (`knum') (">= `mtxt'") ///
                    (`nscope') (`"`macval(scope)'"') (`"`macval(msg)'"') (`mins') (`km')
                local ++nfail
                local ++nf_v
            }
            quietly count if `tg' == 1
            if `nf_v' == 0 & r(N) == 0 {
                // no nonmissing level in scope: nothing was tested, and a
                // model would drop every row, so this is not a pass
                local g `"`v'"'
                if `"`grp'"' != "" local g `"`grp'; `g'"'
                local msg `"`pfx'events(`ev'): `v' has no nonmissing level in scope"'
                frame post `rf' ("events") ("`kind'") (0) ("`ev'") ("`v'") ///
                    (`"`macval(g)'"') ("no nonmissing levels") (.) (">= `mtxt'") ///
                    (`nscope') (`"`macval(scope)'"') (`"`macval(msg)'"') (.) (0)
                local ++nfail
            }
            else if `nf_v' == 0 {
                quietly summarize `tot' if `tg' == 1, meanonly
                local nlev = r(N)
                local k = cond(r(N) > 0, r(min), 0)
                _datacheck_mcount `k' `mask'
                local ks "`r(s)'"
                local knum = r(num)
                local km = r(masked)
                if `km' local anymask = 1
                local mins = cond(`km' | `k' < 1, ., `k')
                local msg `"`pfx'events(`ev'): `v' has at least `ks' events in each of `nlev' levels"'
                frame post `rf' ("events") ("`kind'") (1) ("`ev'") ("`v'") ///
                    (`"`macval(grp)'"') ("min `ks' events") (`knum') (">= `mtxt'") ///
                    (`nscope') (`"`macval(scope)'"') (`"`macval(msg)'"') (`mins') (`km')
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return scalar nfail = `nfail'
    return scalar masked = `anymask'
end
