*! _iivw_require_meta Version 4.1.2  2026/09/04
*! Fail closed when an explicitly named source does not carry a required field
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass (errors, or returns silently)

/*
The resolve contract (Critical Rule 14).

An explicitly supplied source -- a named stored estimate, a named bundle, a
named file -- must be resolved COMPLETELY or fail. Ambient state (dataset
characteristics, the active e(), globals) may fill gaps only for an AMBIENT
request.

Two iivw failures motivated this helper, both found 2026-09-04 and both rc 0:

  IIVW-14a  iivw_diagnose compares three EXPLICITLY named stored estimates on
            e(depvar) and e(cmd) to decide they are the same estimand. Three
            hand-posted estimates carrying neither field compared equal --
            "" == "" -- so the comparability gate passed vacuously. With an
            esample() marker present the command returned decomposable = 1,
            sample_identical = 1 and a printed decomposition, having never
            established that the three coefficients came from the same
            outcome.

  IIVW-14b  iivw resolves its displayed version by reading the *! header of the
            iivw.ado it names through findfile. A header the regex could not
            match left the local at its "unknown" default and the command
            returned r(version) = "unknown" at rc 0, reporting the package as
            present but unidentifiable rather than refusing.

Syntax:
  _iivw_require_meta <provenance> "<label>" "<name>=<value>" ["<name>=<value>" ...]

  <provenance>  explicit | active. Under "active" the program returns without
                checking, so the call site can be unconditional and the
                emptiness fallbacks stay gated on provenance rather than on
                emptiness.
  <label>       what the caller named, used in the error message
                (e.g. "stored estimates 'M_unw'").
  name=value    one double-quoted token per field. The value may contain
                spaces (a varlist); gettoken strips the outer quotes.

Errors 198 naming every field that is empty.
*/

program define _iivw_require_meta
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        gettoken provenance 0 : 0
        if !inlist("`provenance'", "explicit", "active") {
            display as error "_iivw_require_meta: provenance must be explicit or active"
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
                    display as error "_iivw_require_meta: expected name=value, got `pair'"
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
                display as error "_iivw_require_meta: no fields to check"
                exit 198
            }

            local missing_fields = strtrim("`missing_fields'")
            if "`missing_fields'" != "" {
                display as error `"`label' does not supply required metadata: `missing_fields'"'
                display as error "the source was named explicitly, so it must be resolved completely"
                display as error "  refusing to substitute ambient state for the missing field(s)"
                exit 198
            }
        }
    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
