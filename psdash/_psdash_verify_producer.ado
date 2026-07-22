*! _psdash_verify_producer Version 1.5.0  2026/07/22
*! Call a producer package's own validity/signature guard before trusting its
*! post-estimation contract; fail closed on stale, unsigned, or unverifiable state
*! Author: Timothy P Copeland, Karolinska Institutet
*! Internal helper

* RB-07: psdash auto-detects fitted iivw/msm/tte/tmle/ltmle analyses from the
* dataset characteristics they stamp. The characteristics alone prove nothing --
* they can be hand-written, or left behind after rows were dropped, a covariate
* edited, or the weight column overwritten. Each producer ships a guard that
* re-derives its fingerprint and rejects stale or unsigned state (audit C1/C2:
* _iivw_check_weighted rejected with r(459) the very state psdash accepted with
* r(0)). This helper runs that guard and fails closed:
*   - guard passes            -> return (psdash proceeds with a verified contract)
*   - guard rejects (rc != 0) -> re-run it noisily and propagate its rc
*   - guard not installed (rc 199) -> refuse; the metadata cannot be verified
* Only rc 199 (command unrecognized) means "producer not installed". A guard that
* itself exits 111/198/459/498 is a genuine REJECTION and must be propagated, not
* mistaken for an absent producer.

program define _psdash_verify_producer
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken source rest : 0, parse(":")
        gettoken colon guardcmd : rest, parse(":")
        local source = strtrim("`source'")
        local guardcmd = strtrim(`"`guardcmd'"')

        if "`source'" == "" | `"`guardcmd'"' == "" {
            display as error "_psdash_verify_producer: usage is <source> : <guard command>"
            exit 198
        }

        capture `guardcmd'
        local _grc = _rc

        if `_grc' == 199 {
            display as error "cannot verify the `source' analysis contract"
            display as error "  this dataset carries `source' contract metadata, but the `source'"
            display as error "  package is not installed, so its validity guard cannot confirm the"
            display as error "  metadata still describes the data in memory. psdash will not present"
            display as error "  diagnostics for an unverifiable upstream analysis."
            display as error "  Install `source', or run psdash with an explicit treatment and"
            display as error "  propensity score variable."
            exit 459
        }
        if `_grc' {
            * The guard ran and rejected the state. Re-run it so the user sees the
            * producer's own diagnostic message, then fail closed with its rc.
            capture noisily `guardcmd'
            exit _rc
        }

        _psdash_contract_info `source'
        local _version_field "`r(version_field)'"
        local _min_version "`r(min_version)'"
        local _max_version "`r(max_version)'"
        local _found_version ""
        if inlist("`source'", "tmle", "ltmle") {
            local _found_version "`e(contract_version)'"
        }
        if "`_found_version'" == "" {
            local _found_version : char _dta[`_version_field']
        }
        local _found_num = real("`_found_version'")
        if "`_found_version'" == "" | missing(`_found_num') | ///
                `_found_num' < real("`_min_version'") | ///
                `_found_num' > real("`_max_version'") {
            local _found_label "`_found_version'"
            if "`_found_label'" == "" local _found_label "<missing>"
            display as error "unsupported `source' analysis contract"
            display as error "  this psdash release supports `source' contract versions `_min_version' to `_max_version';"
            display as error "  found `_found_label'."
            display as error "  Update psdash or specify treatment and propensity-score variables explicitly."
            exit 459
        }
        * _psdash_contract_info is r-class; do not leak its implementation
        * metadata through the caller's return surface.
        return clear
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' exit `rc'
end
