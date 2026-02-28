*! _nma_node_sizes Version 1.0.3  2026/02/28
*! Compute relative node sizes for network plot

program define _nma_node_sizes
    version 16.0
    set varabbrev off
    set more off

    syntax , k(integer) adj_matrix(string) [sizeby(string)]

    if "`sizeby'" == "" local sizeby "studies"

    tempname sizes
    matrix `sizes' = J(`k', 1, 0)

    if "`sizeby'" == "studies" {
        forvalues i = 1/`k' {
            local total = 0
            forvalues j = 1/`k' {
                local total = `total' + `adj_matrix'[`i', `j']
            }
            matrix `sizes'[`i', 1] = `total' / 2
        }
    }

    * Normalize to [2, 7] range
    mata: st_matrix("`sizes'", _nma_normalize_sizes(st_matrix("`sizes'")))
    matrix _nma_node_sizes = `sizes'
end

mata:
real matrix _nma_normalize_sizes(real matrix sizes)
{
    real scalar mn, mx, rng
    mn = min(sizes)
    mx = max(sizes)
    rng = mx - mn
    if (rng == 0) return(J(rows(sizes), 1, 4))
    return(2 :+ 5 * (sizes :- mn) / rng)
}
end
