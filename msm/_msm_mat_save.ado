*! _msm_mat_save Version 1.2.3  2026/07/17
*! Serialize a matrix into dataset characteristics (dataset-resident artifact)
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
Syntax:
  _msm_mat_save matname , KEY(name) [TOKEN(string)]

Writes matname into dataset characteristics under the given key stem, so the
artifact travels with the .dta instead of living only in the Stata session.
This is what makes a saved/reloaded MSM analysis carry its own coefficients
rather than silently consuming whatever matrix the session happens to hold
(audit finding A01).

Characteristics written:
  _dta[<key>_r]   rows
  _dta[<key>_c]   columns
  _dta[<key>_rn]  rownames
  _dta[<key>_cn]  colnames
  _dta[<key>_re]  roweq
  _dta[<key>_ce]  coleq
  _dta[<key>_id]  optional owning artifact UUID
  _dta[<key>_nk]  number of payload chunks
  _dta[<key>_d1..dN] payload chunks

Values are written with %21x (Stata hexadecimal double). That format
round-trips a double EXACTLY (verified 2026-07-17); a decimal format such as
%20.0g would silently lose low-order bits and make a reloaded fit disagree with
the fit that produced it.

A single characteristic holds at most 67,782 characters (measured 2026-07-17,
Stata 17/MP; the write fails with rc 1004 beyond that). Critically, a failed
`char` write LEAVES THE PREVIOUS VALUE IN PLACE, so an unchecked overflow would
leave a stale payload looking like a fresh one. Every write here is checked, and
the payload is chunked well under the ceiling.

Returns:
  r(nchunks) - number of payload chunks written
  r(len)     - total payload length
*/

program define _msm_mat_save, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        * parse(" ,") is required: gettoken does NOT split on a comma by
        * default, so the matrix name would arrive as "B," and syntax would
        * then read the remainder as a varlist (r 101).
        gettoken _matname 0 : 0, parse(" ,")
        syntax , KEY(name) [TOKEN(string)]

        confirm matrix `_matname'

        * Snapshot the old artifact before touching it. Characteristic writes
        * are not atomic: a failed write retains the prior value, and payload
        * chunks are written before the header. Rollback below makes this helper
        * transactional even when the caller is not inside preserve/restore.
        foreach _suffix in r c rn cn re ce nk id {
            local _old_`_suffix' : char _dta[`key'_`_suffix']
        }
        mata: st_local("_old_chunk_names", invtokens(st_dir("char", "_dta", "`key'_d*")'))
        local _old_chunk_count = 0
        foreach _chunk_name of local _old_chunk_names {
            if regexm("`_chunk_name'", "^`key'_d[0-9]+$") {
                local ++_old_chunk_count
                local _old_chunk_name`_old_chunk_count' "`_chunk_name'"
                local _old_chunk_value`_old_chunk_count' : char _dta[`_chunk_name']
            }
        }

        local _work_rc = 0
        local _nchunks = 0
        local _len = 0
        capture noisily {
            local _r = rowsof(`_matname')
            local _c = colsof(`_matname')

            local _rn : rownames `_matname'
            local _cn : colnames `_matname'
            local _re : roweq `_matname'
            local _ce : coleq `_matname'

        * Chunk width is held well below the 67,782-character ceiling so the
        * `char' command line (payload + command text + macro expansion) cannot
        * approach the limit.
            local _chunk = 40000

            local _serial_ok = 0
            mata: _msm_mat_save_payload("`_matname'", "`key'", `_chunk')
            if `_serial_ok' != 1 {
                display as error "failed to store MSM artifact payload (`key')"
                display as error "the model may be too wide to persist in dataset characteristics"
                exit 1004
            }

        * _msm_mat_save_payload pushes nchunks/len back via st_local.
            char _dta[`key'_r] "`_r'"
            char _dta[`key'_c] "`_c'"
            char _dta[`key'_rn] "`_rn'"
            char _dta[`key'_cn] "`_cn'"
            char _dta[`key'_re] "`_re'"
            char _dta[`key'_ce] "`_ce'"
            char _dta[`key'_nk] "`_nchunks'"
            char _dta[`key'_id] "`token'"

        * Prove every metadata write survived. A char write that overflows fails
        * with rc 1004 and silently retains the prior value.
            foreach _suffix in r c rn cn re ce nk id {
                local _check : char _dta[`key'_`_suffix']
                local _expected `"`_`_suffix''"'
                if "`_suffix'" == "nk" local _expected "`_nchunks'"
                if "`_suffix'" == "id" local _expected `"`token'"'
                if `"`_check'"' != `"`_expected'"' {
                    display as error ///
                        "failed to round-trip MSM artifact metadata (`key'_`_suffix')"
                    exit 1004
                }
            }

            * A narrower replacement must not retain tail chunks from the old
            * payload. They are ignored by the new header but otherwise travel
            * forever with the dataset and can be mistaken for recoverable
            * state after later corruption.
            if `_old_chunk_count' > 0 {
                forvalues _i = 1/`_old_chunk_count' {
                    local _chunk_name "`_old_chunk_name`_i''"
                    if regexm("`_chunk_name'", "^`key'_d([0-9]+)$") {
                        local _chunk_index = real(regexs(1))
                        if `_chunk_index' < 1 | `_chunk_index' > `_nchunks' {
                            char _dta[`_chunk_name']
                        }
                    }
                }
            }
        }
        local _work_rc = _rc

        if `_work_rc' {
            * Remove every chunk from the failed attempt, including chunks past
            * a corrupt/gapped header, then put the exact prior artifact back.
            foreach _suffix in r c rn cn re ce nk id {
                char _dta[`key'_`_suffix']
            }
            mata: st_local("_failed_chunk_names", invtokens(st_dir("char", "_dta", "`key'_d*")'))
            foreach _chunk_name of local _failed_chunk_names {
                if regexm("`_chunk_name'", "^`key'_d[0-9]+$") {
                    char _dta[`_chunk_name']
                }
            }
            foreach _suffix in r c rn cn re ce nk id {
                char _dta[`key'_`_suffix'] `"`_old_`_suffix''"'
            }
            if `_old_chunk_count' > 0 {
                forvalues _i = 1/`_old_chunk_count' {
                    local _chunk_name "`_old_chunk_name`_i''"
                    local _chunk_value `"`_old_chunk_value`_i''"'
                    if `"`_chunk_value'"' != "" {
                        char _dta[`_chunk_name'] `"`_chunk_value'"'
                    }
                }
            }
            exit `_work_rc'
        }

        return scalar nchunks = `_nchunks'
        return scalar len = `_len'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

version 16.0
mata:

void _msm_mat_save_payload(string scalar matname, string scalar key,
                           real scalar chunk)
{
    real matrix      M
    real scalar      i, j, k, nk, L
    string scalar    s, piece, cname
    string colvector parts

    M = st_matrix(matname)

    // Build the payload as a vector of tokens, then concatenate once.
    // Repeated string append in a loop is O(n^2) in Mata and gets slow for a
    // k x k variance matrix.
    parts = J(rows(M) * cols(M), 1, "")
    k = 0
    for (i = 1; i <= rows(M); i++) {
        for (j = 1; j <= cols(M); j++) {
            k++
            parts[k] = strofreal(M[i, j], "%21x")
        }
    }
    s = invtokens(parts', " ")

    L = strlen(s)
    nk = (L == 0 ? 1 : ceil(L / chunk))

    // Verify every chunk survives the write. A char write that overflows fails
    // with rc 1004 and leaves the PREVIOUS value in place, so an unverified
    // write can leave a stale payload wearing a fresh header.
    for (k = 1; k <= nk; k++) {
        piece = substr(s, (k - 1) * chunk + 1, chunk)
        cname = "_dta[" + key + "_d" + strofreal(k) + "]"
        st_global(cname, piece)
        if (st_global(cname) != piece) {
            st_local("_serial_ok", "0")
            return
        }
    }

    // Clear any chunks left over from a previous, longer artifact. Without
    // this, shrinking a model would leave trailing chunks that deserialize
    // into a longer payload than the header advertises.
    k = nk + 1
    while (st_global("_dta[" + key + "_d" + strofreal(k) + "]") != "") {
        st_global("_dta[" + key + "_d" + strofreal(k) + "]", "")
        k++
    }

    st_local("_nchunks", strofreal(nk))
    st_local("_len", strofreal(L))
    st_local("_serial_ok", "1")
}

end
