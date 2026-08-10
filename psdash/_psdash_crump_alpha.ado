*! _psdash_crump_alpha Version 1.6.5  2026/08/10
*! Efficient Crump optimal-trimming grid search
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Internal helper

program define _psdash_crump_alpha, rclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax varname(numeric) [if] [in]
        marksample touse

        quietly count if `touse' & `varlist' > 0 & `varlist' < 1
        if r(N) == 0 {
            return scalar alpha = .
            return scalar objective = .
        }
        else {
            tempname alpha objective
            mata: _psdash_crump_search( ///
                "`varlist'", "`touse'", "`alpha'", "`objective'")
            return scalar alpha = scalar(`alpha')
            return scalar objective = scalar(`objective')
        }
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end

mata:
real scalar _psdash_crump_lower(real colvector x, real scalar value)
{
    real scalar lo, hi, mid
    lo = 1
    hi = rows(x) + 1
    while (lo < hi) {
        mid = floor((lo + hi) / 2)
        if (mid <= rows(x) && x[mid] < value) lo = mid + 1
        else hi = mid
    }
    return(lo)
}

real scalar _psdash_crump_upper(real colvector x, real scalar value)
{
    real scalar lo, hi, mid
    lo = 1
    hi = rows(x) + 1
    while (lo < hi) {
        mid = floor((lo + hi) / 2)
        if (mid <= rows(x) && x[mid] <= value) lo = mid + 1
        else hi = mid
    }
    return(lo - 1)
}

void _psdash_crump_consider(
    real colvector p,
    real colvector cumulative,
    real scalar alpha,
    real scalar best_alpha,
    real scalar best_diff)
{
    real scalar first, last, total, rhs, lhs, diff
    first = _psdash_crump_lower(p, alpha)
    last = _psdash_crump_upper(p, 1 - alpha)
    if (first > last || first > rows(p) || last < 1) return

    total = cumulative[last]
    if (first > 1) total = total - cumulative[first - 1]
    rhs = 2 * total / (last - first + 1)
    lhs = 1 / (alpha * (1 - alpha))
    diff = abs(lhs - rhs)
    if (missing(best_diff) || diff < best_diff) {
        best_diff = diff
        best_alpha = alpha
    }
}

void _psdash_crump_search(
    string scalar psvar,
    string scalar touse,
    string scalar alpha_name,
    string scalar objective_name)
{
    real colvector p, inverse_variance, cumulative
    real scalar i, alpha, best_alpha, best_diff, lo, hi, has_boundary

    p = st_data(., psvar, touse)
    has_boundary = any((p :== 0) :| (p :== 1))
    p = select(p, p :> 0 :& p :< 1)
    p = sort(p, 1)
    inverse_variance = 1 :/ (p :* (1 :- p))

    /* Crump et al. (2009), Corollary 1: when the full-sample bound
       already satisfies the optimality inequality, A* is the full
       covariate space and the corresponding trimming threshold is zero.
       Exact boundary scores make that inverse-variance bound undefined,
       so they can only be assessed by a positive trimming threshold. */
    if (!has_boundary &
        max(inverse_variance) <= 2 * mean(inverse_variance)) {
        st_numscalar(alpha_name, 0)
        st_numscalar(objective_name, 0)
        return
    }

    cumulative = J(rows(p), 1, 0)
    cumulative[1] = inverse_variance[1]
    for (i = 2; i <= rows(p); i++) {
        cumulative[i] = cumulative[i - 1] + inverse_variance[i]
    }

    best_alpha = 0
    best_diff = .
    for (i = 1; i <= 49; i++) {
        alpha = i / 100
        _psdash_crump_consider(
            p, cumulative, alpha, best_alpha, best_diff)
    }

    if (best_alpha > 0) {
        lo = max((1, round(100 * (best_alpha - .01))))
        hi = min((49, round(100 * (best_alpha + .01))))
        for (i = lo * 10; i <= hi * 10; i++) {
            alpha = i / 1000
            _psdash_crump_consider(
                p, cumulative, alpha, best_alpha, best_diff)
        }
    }

    st_numscalar(alpha_name, best_alpha)
    st_numscalar(objective_name, best_diff)
}
end
