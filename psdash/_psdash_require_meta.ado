*! _psdash_require_meta Version 1.7.1  2026/09/04
*! Fail closed when an explicitly named source does not carry a required field
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass (errors, or returns silently)

/*
The resolve contract.

An explicitly supplied source -- a named option, a verified producer
contract, a named frame -- must be resolved COMPLETELY or fail. Ambient state (dataset
characteristics, the active e(), globals) may fill gaps only for an AMBIENT
request. The failure this guards is psdash audit finding PSDASH-02: when
_psdash_detect had not verified the iivw producer contract, psdash_weights
read the raw _dta[_iivw_*] characteristics anyway and diagnosed a stale,
unsigned weight variable at rc 0.

Syntax:
  _psdash_require_meta <provenance> "<label>" "<name>=<value>" ["<name>=<value>" ...]

  <provenance>  explicit | active. Under "active" the program returns without
                checking, so the call site can be unconditional and the
                emptiness fallbacks stay gated on provenance rather than on
                emptiness.
  <label>       what the caller named, used in the error message
                (e.g. "iivwcomponent(treatment)").
  name=value    one double-quoted token per field. The value may contain
                spaces (a variable list); gettoken strips the outer quotes.

Errors 198 naming every field that is empty.
*/

program define _psdash_require_meta
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        gettoken provenance 0 : 0
        if !inlist("`provenance'", "explicit", "active") {
            display as error "_psdash_require_meta: provenance must be explicit or active"
            exit 198
        }
        gettoken label 0 : 0

        if "`provenance'" == "explicit" {
            local missing_fields ""
            local n_fields = 0
            while `"`0'"' != "" {
                gettoken pair 0 : 0
                local eq = strpos(`"`pair'"', "=")
                if `eq' == 0 {
                    display as error "_psdash_require_meta: expected name=value, got `pair'"
                    exit 198
                }
                local fname = substr(`"`pair'"', 1, `eq' - 1)
                local fvalue = substr(`"`pair'"', `eq' + 1, .)
                local ++n_fields
                if strtrim(`"`fvalue'"') == "" {
                    local missing_fields "`missing_fields' `fname'"
                }
            }
            if `n_fields' == 0 {
                display as error "_psdash_require_meta: no fields to check"
                exit 198
            }

            local missing_fields = strtrim("`missing_fields'")
            if "`missing_fields'" != "" {
                display as error `"`label' does not supply required metadata: `missing_fields'"'
                display as error "the source was named explicitly, so it must be resolved completely"
                display as error "  refusing to substitute unverified dataset characteristics"
                exit 198
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
