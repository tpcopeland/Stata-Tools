*! _tte_memory_estimate Version 1.0.2  2026/02/28
*! Estimate memory for expansion
*! Author: Timothy P Copeland

* Returns via c_local: _tte_est_bytes, _tte_est_rows, _tte_use_chunked

program define _tte_memory_estimate
    version 16.0
    set varabbrev off
    set more off

    syntax , n_eligible(integer) n_followup(integer) n_vars(integer) ///
        [clone threshold(real 2)]

    * Bytes per row: ~8 bytes per variable (double) + overhead
    local bytes_per_row = `n_vars' * 8 + 50

    * Expansion factor: each eligible period creates followup rows
    * With clone: double (treatment + control arm)
    local mult = 1
    if "`clone'" != "" local mult = 2

    local est_rows = `n_eligible' * `n_followup' * `mult'
    local est_bytes = `est_rows' * `bytes_per_row'
    local est_gb = `est_bytes' / (1024 * 1024 * 1024)

    * Threshold in GB
    local use_chunked = 0
    if `est_gb' > `threshold' {
        local use_chunked = 1
    }

    c_local _tte_est_bytes `est_bytes'
    c_local _tte_est_rows `est_rows'
    c_local _tte_use_chunked `use_chunked'
end
