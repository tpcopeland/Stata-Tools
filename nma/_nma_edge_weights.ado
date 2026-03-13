*! _nma_edge_weights Version 1.0.3  2026/02/28
*! Compute edge line widths for network plot

program define _nma_edge_weights
    version 16.0
    set varabbrev off

    syntax , k(integer) adj_matrix(string) [weightby(string)]

    if "`weightby'" == "" local weightby "studies"

    mata: st_matrix("_nma_edge_weights", ///
        _nma_normalize_edges(st_matrix("`adj_matrix'"), `k'))
end

mata:
real matrix _nma_normalize_edges(real matrix adj, real scalar k)
{
    real matrix weights
    real scalar mx
    weights = adj
    mx = max(adj)
    if (mx == 0) return(J(k, k, 1))
    return(0.15 :+ 0.85 * weights / mx)
}
end
