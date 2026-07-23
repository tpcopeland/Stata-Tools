*! _msm_mat_load Version 1.2.4  2026/07/23
*! Rebuild a matrix from dataset characteristics written by _msm_mat_save
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Syntax:
  _msm_mat_load matname , KEY(name)

Rebuilds matname from the characteristics written by _msm_mat_save. The matrix
is reconstructed from the dataset in memory, so a reloaded .dta carries its own
coefficients rather than inheriting whatever the session holds (audit A01).

Refuses to build a partial matrix. Every failure path leaves matname
non-existent rather than half-formed: a caller that checks only for existence
must not be handed a truncated artifact.

IMPLEMENTATION NOTE: this program branches on a status local rather than
exiting early. `exit 0` inside `capture noisily { }` terminates the program
outright and SKIPS the cleanup zone -- an earlier draft leaked `set varabbrev
off` into the caller's session on the ordinary "no artifact" path (verified
2026-07-17). No early exit may appear inside the captured block.

Returns:
  r(ok)   - 1 if the matrix was rebuilt, 0 otherwise
  r(why)  - when r(ok)==0, a short reason token: none | header | payload | dims
*/

program define _msm_mat_load, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        * parse(" ,") is required: gettoken does NOT split on a comma by
        * default, so the matrix name would arrive as "B," and syntax would
        * then read the remainder as a varlist (r 101).
        gettoken _matname 0 : 0, parse(" ,")
        syntax , KEY(name)

        capture matrix drop `_matname'

        local _ok = 0
        local _why ""

        local _r : char _dta[`key'_r]
        local _c : char _dta[`key'_c]
        local _nk : char _dta[`key'_nk]
        local _rn : char _dta[`key'_rn]
        local _cn : char _dta[`key'_cn]
        local _re : char _dta[`key'_re]
        local _ce : char _dta[`key'_ce]
        local _id : char _dta[`key'_id]
        local _d1 : char _dta[`key'_d1]

        if "`_r'" == "" & "`_c'" == "" & "`_nk'" == "" & ///
            "`_rn'" == "" & "`_cn'" == "" & "`_re'" == "" & ///
            "`_ce'" == "" & "`_d1'" == "" & "`_id'" == "" {
            * No artifact at all.
            local _why "none"
        }
        else if "`_r'" == "" | "`_c'" == "" | "`_nk'" == "" | ///
            "`_rn'" == "" | "`_cn'" == "" | "`_re'" == "" | ///
            "`_ce'" == "" {
            * Present but incomplete: corrupt, never merely absent.
            local _why "header"
        }
        else {
            * Never interpolate untrusted characteristic text into Mata. The
            * verifier's contract is to report corrupt artifacts, not error on
            * strings such as _r="bogus" or pathological dimensions.
            local _load_ok = 0
            local _rnum = real("`_r'")
            local _cnum = real("`_c'")
            local _nknum = real("`_nk'")
            local _header_bad = missing(`_rnum') | missing(`_cnum') | ///
                missing(`_nknum') | `_rnum' < 1 | `_cnum' < 1 | `_nknum' < 1 | ///
                `_rnum' != floor(`_rnum') | `_cnum' != floor(`_cnum') | ///
                `_nknum' != floor(`_nknum') | `_rnum' > 11000 | ///
                `_cnum' > 11000 | `_nknum' > 100000 | ///
                (`_rnum' * `_cnum') > 20000000

            if `_header_bad' {
                local _why "header"
            }
            else {
                capture mata: _msm_mat_load_payload("`_matname'", "`key'", ///
                    `_rnum', `_cnum', `_nknum')
                if _rc local _load_ok = 0
            }

            if "`_why'" == "" & `_load_ok' != 1 {
                capture matrix drop `_matname'
                local _why "payload"
            }
            else if "`_why'" == "" {
                * Reapply names. Dimensions that survive without names are
                * exactly the artifact the audit says must be rejected: the
                * coefficient order is what binds a number to a term.
                local _name_rc = 0
                capture matrix rownames `_matname' = `_rn'
                if _rc local _name_rc = _rc
                if `_name_rc' == 0 {
                    capture matrix colnames `_matname' = `_cn'
                    if _rc local _name_rc = _rc
                }

                if `_name_rc' != 0 {
                    capture matrix drop `_matname'
                    local _why "dims"
                }
                else {
                    capture matrix roweq `_matname' = `_re'
                    if _rc local _name_rc = _rc
                    if `_name_rc' == 0 {
                        capture matrix coleq `_matname' = `_ce'
                        if _rc local _name_rc = _rc
                    }
                    if `_name_rc' != 0 {
                        capture matrix drop `_matname'
                        local _why "dims"
                    }
                    else if rowsof(`_matname') != `_rnum' | ///
                        colsof(`_matname') != `_cnum' {
                        capture matrix drop `_matname'
                        local _why "dims"
                    }
                    else {
                        local _ok = 1
                    }
                }
            }
        }

        return scalar ok = `_ok'
        return local why "`_why'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 16.0
mata:

void _msm_mat_load_payload(string scalar matname, string scalar key,
                           real scalar r, real scalar c, real scalar nk)
{
    real matrix      M
    real scalar      i, j, k, n
    string scalar    s, piece
    string rowvector toks

    // Reassemble the chunked payload in order.
    s = ""
    for (k = 1; k <= nk; k++) {
        piece = st_global("_dta[" + key + "_d" + strofreal(k) + "]")
        if (piece == "") {
            st_local("_load_ok", "0")
            return
        }
        s = s + piece
    }

    toks = tokens(s)
    n = cols(toks)

    // The payload must hold exactly the number of cells the header
    // advertises. A short payload silently reshaped would produce a matrix of
    // the right size holding the wrong numbers.
    if (n != r * c) {
        st_local("_load_ok", "0")
        return
    }

    M = J(r, c, .)
    k = 0
    for (i = 1; i <= r; i++) {
        for (j = 1; j <= c; j++) {
            k++
            // strtoreal() parses %21x hexadecimal doubles exactly
            // (verified 2026-07-17).
            M[i, j] = strtoreal(toks[k])
            // A token that is not a number yields . from strtoreal; that means
            // a corrupt payload, not a legitimately missing cell.
            if (M[i, j] >= . & toks[k] != ".") {
                st_local("_load_ok", "0")
                return
            }
        }
    }

    st_matrix(matname, M)
    st_local("_load_ok", "1")
}

end
