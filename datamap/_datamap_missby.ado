*! _datamap_missby Version 1.10.6  2026/10/21
*! Missing counts and shares of a varlist by group
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Syntax: _datamap_missby varlist, by(varlist) touse(varname)
//
// The single computation of missingness by group in the package: datamvp
// bytable() and dataprobe groupstat(pmiss ...) both read it, so the two
// cannot disagree.  Groups are the nonmissing combinations of by() among
// rows with touse == 1 (egen group order).
//
// Returns r(G), matrices r(nmiss) and r(pmiss) (variables x groups; pmiss is
// a share, 0-1), r(ngroup) (1 x groups, rows per group), and r(lab1) ...
// r(labG), the group labels.
// All-numeric varlist: the counts in one pass over the touse rows (no
// indicator variables, frame copy or collapse); the shares are the same
// count / rows quotients.
capture mata: mata drop _dm_missby_m()
mata:
void _dm_missby_m(string scalar vars, string scalar gv, string scalar touse,
    real scalar G, string scalar nmn, string scalar pmn, string scalar ngn)
{
    real matrix V, nm, pm, u
    real colvector g, keep
    real matrix m, gk
    real rowvector ng, pos
    real scalar j, K, k
    st_view(V, ., tokens(vars), touse)
    st_view(g, ., gv, touse)
    keep = g :< .
    K = cols(V)
    nm = J(K, G, 0)
    ng = J(1, G, 0)
    // length(), not rows(): select() on one row can give 1 x 0
    gk = select(g, keep)
    if (length(gk)) {
        u = uniqrows(vec(gk), 1)
        ng[u[., 1]'] = u[., 2]'
    }
    for (j = 1; j <= K; j++) {
        m = select(g, keep :& (V[., j] :>= .))
        if (length(m)) {
            m = vec(m)
            u = uniqrows(m, 1)
            nm[j, u[., 1]'] = u[., 2]'
        }
    }
    pm = J(K, G, .)
    pos = selectindex(ng :> 0)
    for (k = 1; k <= cols(pos); k++) pm[., pos[k]] = nm[., pos[k]] :/ ng[pos[k]]
    st_matrix(nmn, nm)
    st_matrix(pmn, pm)
    st_matrix(ngn, ng)
}
end

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
        capture confirm numeric variable `vars'
        if !_rc {
            matrix `nm' = J(`nv', `G', 0)
            matrix `pm' = J(`nv', `G', .)
            matrix `ng' = J(1, `G', 0)
            mata: _dm_missby_m(st_local("vars"), st_local("g"), st_local("touse"), `G', st_local("nm"), st_local("pm"), st_local("ng"))
        }
        else {
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
