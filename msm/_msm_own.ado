*! _msm_own Version 1.2.3  2026/07/17
*! Ownership registry for MSM-generated variables
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
Syntax:
  _msm_own claim varlist , TOKen(string)
  _msm_own dropowned varlist
  _msm_own require_free varlist
  _msm_own owned varname
  _msm_own inventory

Establishes which variables the package created, so it never deletes a user's
data (audit finding A05). Before this, msm_prepare unconditionally dropped
_msm_weight, _msm_esample, and the wildcard _msm_per_ns*, destroying
identically-named user variables it had not created.

OWNERSHIP MODEL: the token is stored as a characteristic ON EACH VARIABLE
(char <var>[_msm_owner]), not only in a central list. A variable characteristic
travels with the variable through save/use and rename, so ownership cannot
drift out of sync with a separate inventory, and a variable arriving from
elsewhere cannot inherit ownership by name alone. The central inventory
(_dta[_msm_owned]) is kept as a convenience index only; the per-variable
characteristic is authoritative. A nonempty characteristic is not enough: its
token must equal a live stage UUID on this dataset. This prevents an imported,
user-authored, or stale characteristic from authorizing deletion.

Subcommands:
  claim        - mark varlist as package-created and record the minting stage
  dropowned    - drop ONLY those of varlist the package owns; leave the rest
  require_free - error 110 if any of varlist exists but is not owned
  owned        - r(owned) = 1/0 for a single variable
  inventory    - r(vars) = owned variables that currently exist

Returns:
  r(owned)   - (owned)     1 if the variable carries a valid ownership token
  r(dropped) - (dropowned) variables actually dropped
  r(kept)    - (dropowned) variables left alone because they are not owned
  r(vars)    - (inventory) owned variables present in the dataset
*/

program define _msm_own, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        * parse(" ,") is required: gettoken does not split on a comma, so the
        * subcommand would arrive with a trailing comma attached.
        gettoken _sub 0 : 0, parse(" ,")

        if !inlist("`_sub'", "claim", "dropowned", "require_free", "owned", "inventory") {
            display as error "invalid _msm_own subcommand: `_sub'"
            exit 198
        }

        * Tokens currently capable of proving package ownership. Stage UUIDs
        * are dataset-resident and travel with the variables they authorize.
        local _valid_tokens ""
        foreach _key in _msm_prep_uuid _msm_weight_uuid _msm_fit_uuid ///
            _msm_pred_uuid _msm_bal_uuid _msm_diag_uuid _msm_sens_uuid {
            local _stage_token : char _dta[`_key']
            if "`_stage_token'" != "" {
                local _valid_tokens "`_valid_tokens' `_stage_token'"
            }
        }
        local _valid_tokens : list uniq _valid_tokens

        if "`_sub'" == "claim" {
            syntax varlist , TOKen(string)
            foreach _v of local varlist {
                char `_v'[_msm_owner] "`token'"
            }
            local _inv : char _dta[_msm_owned]
            local _inv : list _inv | varlist
            char _dta[_msm_owned] "`_inv'"
        }
        else if "`_sub'" == "owned" {
            syntax varname
            local _tok : char `varlist'[_msm_owner]
            local _valid = 0
            foreach _stage_token of local _valid_tokens {
                if "`_tok'" == "`_stage_token'" local _valid = 1
            }
            return scalar owned = `_valid'
        }
        else if "`_sub'" == "dropowned" {
            * Deliberately not `syntax varlist': the names are reserved
            * artifact names that may legitimately not exist yet, and a
            * varlist would error on the absent ones.
            local _names "`0'"
            local _dropped ""
            local _kept ""
            foreach _v of local _names {
                capture confirm variable `_v'
                if _rc == 0 {
                    local _tok : char `_v'[_msm_owner]
                    local _valid = 0
                    foreach _stage_token of local _valid_tokens {
                        if "`_tok'" == "`_stage_token'" local _valid = 1
                    }
                    if `_valid' {
                        drop `_v'
                        local _dropped "`_dropped' `_v'"
                    }
                    else {
                        * Present but not ours: a user variable that happens to
                        * collide with a reserved name. Never delete it.
                        local _kept "`_kept' `_v'"
                    }
                }
            }
            local _dropped : list retokenize _dropped
            local _kept : list retokenize _kept

            * Keep the inventory index consistent with what was removed.
            local _inv : char _dta[_msm_owned]
            local _inv : list _inv - _dropped
            char _dta[_msm_owned] "`_inv'"

            return local dropped "`_dropped'"
            return local kept "`_kept'"
        }
        else if "`_sub'" == "require_free" {
            local _names "`0'"
            local _blocked ""
            foreach _v of local _names {
                capture confirm variable `_v'
                if _rc == 0 {
                    local _tok : char `_v'[_msm_owner]
                    local _valid = 0
                    foreach _stage_token of local _valid_tokens {
                        if "`_tok'" == "`_stage_token'" local _valid = 1
                    }
                    if !`_valid' {
                        local _blocked "`_blocked' `_v'"
                    }
                }
            }
            local _blocked : list retokenize _blocked
            if "`_blocked'" != "" {
                display as error "reserved MSM variable name(s) already in use: `_blocked'"
                display as error ""
                display as error "These names are reserved for msm-generated artifacts, and msm did"
                display as error "not create the variable(s) above, so it will not overwrite them."
                display as error "Rename or drop them and re-run. For example:"
                gettoken _first : _blocked
                display as error "  {cmd:rename `_first' my_`_first'}"
                exit 110
            }
            return local blocked ""
        }
        else if "`_sub'" == "inventory" {
            local _inv : char _dta[_msm_owned]
            local _present ""
            foreach _v of local _inv {
                capture confirm variable `_v'
                if _rc == 0 {
                    local _tok : char `_v'[_msm_owner]
                    local _valid = 0
                    foreach _stage_token of local _valid_tokens {
                        if "`_tok'" == "`_stage_token'" local _valid = 1
                    }
                    if `_valid' {
                        local _present "`_present' `_v'"
                    }
                }
            }
            local _present : list retokenize _present
            char _dta[_msm_owned] "`_present'"
            return local vars "`_present'"
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
