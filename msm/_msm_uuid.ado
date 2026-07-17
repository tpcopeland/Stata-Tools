*! _msm_uuid Version 1.2.3  2026/07/17
*! Mint a session-unique artifact identifier for MSM pipeline stages
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
Mints an identifier unique across concurrent Stata sessions and across repeated
calls within one session.

Components:
  date + time  - separates sessions started at different moments
  pid          - separates concurrent Stata processes. Taken from Stata's own
                 temporary-file path, whose basename is St<pid>.<seq>.
                 NOTE: <seq> is NOT a usable uniqueness source. Temporary files are
                 program-scoped, so <seq> resets on every program entry and two
                 successive mints returned an identical name (verified
                 2026-07-17). The pid component is the only stable part.
  counter      - separates mints within one session/second.

Deliberately does NOT touch the RNG. runiform() here would perturb the caller's
random-number stream and make deterministic analyses depend on how many
artifacts had been minted.

Returns:
  r(uuid) - the minted identifier
*/

program define _msm_uuid, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        tempfile _msm_uuid_src

        * Normalize separators so the basename split works on every platform.
        local _raw = subinstr(`"`_msm_uuid_src'"', "\", "/", .)
        local _pos = strrpos("`_raw'", "/")
        if `_pos' > 0 {
            local _base = substr("`_raw'", `_pos' + 1, .)
        }
        else {
            local _base "`_raw'"
        }

        * Keep only the St<pid> stem; the trailing .<seq> is not unique.
        local _dot = strpos("`_base'", ".")
        if `_dot' > 0 {
            local _pid = substr("`_base'", 1, `_dot' - 1)
        }
        else {
            local _pid "`_base'"
        }
        local _pid = subinstr("`_pid'", " ", "", .)

        * In-session counter. Stata globals survive `clear all` (verified by the
        * independent-review regression IR1), so the sequence remains monotone
        * across ordinary session resets. Date+time+pid separate processes.
        * NOTE: the name has no leading underscore on purpose. Stata rejects
        * `global _name = 0` with r(198) (verified 2026-07-17), so the usual
        * _msm_ prefix cannot be used for a global.
        if "${MSM_UUID_SEQ}" == "" {
            global MSM_UUID_SEQ = 0
        }
        global MSM_UUID_SEQ = ${MSM_UUID_SEQ} + 1

        local _date = subinstr("`c(current_date)'", " ", "", .)
        local _time = subinstr("`c(current_time)'", ":", "", .)

        return local uuid "msm_`_date'_`_time'_`_pid'_${MSM_UUID_SEQ}"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
