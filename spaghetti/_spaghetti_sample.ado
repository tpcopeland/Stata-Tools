*! _spaghetti_sample Version 1.0.0  2026/03/15
*! Random ID sampling for spaghetti plots
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet

program define _spaghetti_sample
    version 16.0
    syntax , id(varname) n(integer) [seed(integer -1)]

    if `seed' >= 0 {
        set seed `seed'
    }

    * Count unique individuals
    tempvar _tag
    bysort `id': gen byte `_tag' = (_n == 1)
    quietly count if `_tag'
    local n_ids = r(N)

    if `n' >= `n_ids' {
        display as text "(sample(`n') >= individuals (`n_ids'); keeping all)"
        drop `_tag'
        c_local n_sampled `n_ids'
        exit
    }

    * Random sample: assign uniform to first row per individual
    tempvar _rand _sel _keep
    gen double `_rand' = runiform() if `_tag'
    sort `_rand'
    gen byte `_sel' = (_n <= `n') & `_tag'

    * Propagate selection to all rows per individual
    bysort `id': egen byte `_keep' = max(`_sel')
    keep if `_keep'
    drop `_tag' `_rand' `_sel' `_keep'

    c_local n_sampled `n'
end
