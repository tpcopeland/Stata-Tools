*! _datamap_missby Version 1.9.1  2026/10/04
*! Missing counts and shares of a varlist by group
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Syntax: _datamap_missby varlist, by(varlist) touse(varname)
//
// The single computation of missingness by group in the package: datamvp
// bytable() and datacheck groupstat(pmiss ...) both read it, so the two
// cannot disagree.  Groups are the nonmissing combinations of by() among
// rows with touse == 1 (egen group order).
//
// Returns r(G), matrices r(nmiss) and r(pmiss) (variables x groups; pmiss is
// a share, 0-1), r(ngroup) (1 x groups, rows per group), and r(lab1) ...
// r(labG), the group labels.
program define _datamap_missby, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _fr_made = 0
    tempname fr nm pm ng
    capture noisily {
        syntax varlist, BY(varlist) TOUSE(varname)
        local vars "`varlist'"
        local nv : word count `vars'
        tempvar g
        quietly egen long `g' = group(`by') if `touse', label
        quietly summarize `g', meanonly
        local G = cond(r(N) > 0, r(max), 0)
        if `G' == 0 {
            display as error "no nonmissing groups of `by' in the sample"
            exit 2000
        }
        local glab : value label `g'
        forvalues k = 1/`G' {
            local lab`k' "`k'"
            if "`glab'" != "" {
                local _t : label `glab' `k'
                if `"`_t'"' != "" local lab`k' `"`_t'"'
            }
        }
        local mlist ""
        local j = 0
        foreach v of local vars {
            local ++j
            tempvar m`j'
            quietly generate byte `m`j'' = missing(`v') if `touse' & !missing(`g')
            local mlist "`mlist' `m`j''"
        }
        tempvar one
        quietly generate byte `one' = 1
        frame put `g' `one' `mlist' if `touse' & !missing(`g'), into(`fr')
        local _fr_made = 1
        matrix `nm' = J(`nv', `G', 0)
        matrix `pm' = J(`nv', `G', .)
        matrix `ng' = J(1, `G', 0)
        frame `fr' {
            quietly collapse (sum) `one' `mlist', by(`g')
            local R = _N
            forvalues r = 1/`R' {
                local k = `g'[`r']
                matrix `ng'[1, `k'] = `one'[`r']
                local j = 0
                foreach mv of local mlist {
                    local ++j
                    matrix `nm'[`j', `k'] = `mv'[`r']
                    matrix `pm'[`j', `k'] = `mv'[`r'] / `one'[`r']
                }
            }
        }
        local cn ""
        forvalues k = 1/`G' {
            local cn "`cn' g`k'"
        }
        matrix rownames `nm' = `vars'
        matrix rownames `pm' = `vars'
        matrix colnames `nm' = `cn'
        matrix colnames `pm' = `cn'
        matrix colnames `ng' = `cn'
    }
    local rc = _rc
    if `_fr_made' capture frame drop `fr'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return scalar G = `G'
    forvalues k = 1/`G' {
        return local lab`k' `"`lab`k''"'
    }
    return matrix nmiss = `nm'
    return matrix pmiss = `pm'
    return matrix ngroup = `ng'
end
