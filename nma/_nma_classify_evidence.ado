*! _nma_classify_evidence Version 1.0.1  2026/02/28
*! Classify pairwise comparisons as direct/indirect/mixed

program define _nma_classify_evidence
    version 16.0
    set varabbrev off

    syntax , k(integer) adj_matrix(string)

    mata: _nma_classify_evidence_mata("`adj_matrix'", `k')
end

mata:
void _nma_classify_evidence_mata(string scalar adj_name, real scalar k)
{
    real matrix adj, evidence, reach, adj_temp, reach_temp
    real scalar i, j, m, ii, jj, has_direct, has_indirect

    adj = st_matrix(adj_name)

    /* Compute reachability via Floyd-Warshall */
    reach = adj
    for (m = 1; m <= k; m++) {
        for (i = 1; i <= k; i++) {
            for (j = 1; j <= k; j++) {
                if (reach[i, m] > 0 & reach[m, j] > 0) {
                    reach[i, j] = 1
                }
            }
        }
    }

    evidence = J(k, k, 0)
    for (i = 1; i <= k; i++) {
        for (j = i + 1; j <= k; j++) {
            has_direct = (adj[i, j] > 0)

            /* Indirect: reachable excluding direct i-j edge */
            has_indirect = 0
            if (reach[i, j] > 0) {
                adj_temp = adj
                adj_temp[i, j] = 0
                adj_temp[j, i] = 0
                reach_temp = adj_temp
                for (m = 1; m <= k; m++) {
                    for (ii = 1; ii <= k; ii++) {
                        for (jj = 1; jj <= k; jj++) {
                            if (reach_temp[ii, m] > 0 & reach_temp[m, jj] > 0) {
                                reach_temp[ii, jj] = 1
                            }
                        }
                    }
                }
                has_indirect = (reach_temp[i, j] > 0)
            }

            if (has_direct & has_indirect) {
                evidence[i, j] = 3
                evidence[j, i] = 3
            }
            else if (has_direct & !has_indirect) {
                evidence[i, j] = 1
                evidence[j, i] = 1
            }
            else if (!has_direct & has_indirect) {
                evidence[i, j] = 2
                evidence[j, i] = 2
            }
        }
    }

    st_matrix("_nma_evidence", evidence)
}
end
