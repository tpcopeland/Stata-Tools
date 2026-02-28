*! _nma_validate_network Version 1.0.1  2026/02/28
*! Check network connectivity via BFS

program define _nma_validate_network
    version 16.0
    set varabbrev off
    set more off

    syntax , treatments(string) adj_matrix(string)

    local k : word count `treatments'

    mata: _nma_bfs_components("`adj_matrix'", `k')

    local n_comp = `_nma_n_components'
    local connected = (`n_comp' == 1)

    if !`connected' {
        local comp_desc ""
        forvalues c = 1/`n_comp' {
            local members ""
            local idx_list "`_nma_component_`c''"
            foreach idx of local idx_list {
                local trt : word `idx' of `treatments'
                local members "`members' `trt'"
            }
            local members = strtrim("`members'")
            if `c' > 1 local comp_desc "`comp_desc'; "
            local comp_desc "`comp_desc'{`members'}"
        }
    }

    c_local _nma_connected `connected'
    c_local _nma_n_components `n_comp'
    if !`connected' {
        c_local _nma_components "`comp_desc'"
    }
end

mata:
void _nma_bfs_components(string scalar adj_name, real scalar k)
{
    real matrix adj
    real colvector visited, queue
    real scalar n_comp, i, j, qhead, qtail, cur
    string scalar comp_str

    adj = st_matrix(adj_name)
    visited = J(k, 1, 0)
    n_comp = 0

    for (i = 1; i <= k; i++) {
        if (visited[i] == 0) {
            n_comp++
            queue = J(k, 1, 0)
            queue[1] = i
            qhead = 1
            visited[i] = n_comp
            qtail = 1

            while (qhead <= qtail) {
                cur = queue[qhead]
                qhead++
                for (j = 1; j <= k; j++) {
                    if (adj[cur, j] > 0 & visited[j] == 0) {
                        visited[j] = n_comp
                        qtail++
                        queue[qtail] = j
                    }
                }
            }

            comp_str = ""
            for (j = 1; j <= k; j++) {
                if (visited[j] == n_comp) {
                    if (comp_str != "") comp_str = comp_str + " "
                    comp_str = comp_str + strofreal(j)
                }
            }
            st_local("_nma_component_" + strofreal(n_comp), comp_str)
        }
    }
    st_local("_nma_n_components", strofreal(n_comp))
}
end
