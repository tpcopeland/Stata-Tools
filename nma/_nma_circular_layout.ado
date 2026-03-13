*! _nma_circular_layout Version 1.0.1  2026/02/28
*! Compute circular layout positions for network nodes

program define _nma_circular_layout
    version 16.0
    set varabbrev off

    syntax , k(integer)

    mata: _nma_compute_circular(`k')
end

mata:
void _nma_compute_circular(real scalar k)
{
    real scalar i, angle
    real colvector x, y

    x = J(k, 1, 0)
    y = J(k, 1, 0)

    for (i = 1; i <= k; i++) {
        angle = pi() / 2 - 2 * pi() * (i - 1) / k
        x[i] = cos(angle)
        y[i] = sin(angle)
    }

    st_matrix("_nma_node_x", x)
    st_matrix("_nma_node_y", y)
}
end
