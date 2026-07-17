*! _msm_mat_clear Version 1.2.3  2026/07/17
*! Remove a serialized matrix artifact from dataset characteristics
*! Author: Timothy P Copeland
*! Program class: nclass

/*
Syntax:
  _msm_mat_clear , KEY(name)

Removes every characteristic written by _msm_mat_save under the given key stem,
including all payload chunks. Leaving a stale chunk behind would let a later
_msm_mat_load reassemble a payload from a previous model.
*/

program define _msm_mat_clear
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax , KEY(name)

        foreach _suffix in r c rn cn re ce nk id {
            char _dta[`key'_`_suffix']
        }

        * Enumerate characteristics instead of trusting either the header or
        * a run of empty chunk numbers. A corrupt artifact can be gapped (for
        * example, d1 followed by d100); a sentinel scan would leave its tail.
        mata: st_local("_chunk_names", invtokens(st_dir("char", "_dta", "`key'_d*")'))
        foreach _chunk_name of local _chunk_names {
            if regexm("`_chunk_name'", "^`key'_d[0-9]+$") {
                char _dta[`_chunk_name']
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
