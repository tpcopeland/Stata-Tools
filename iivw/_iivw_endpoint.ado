*! _iivw_endpoint Version 4.3.6  2026/10/09
*! End-of-follow-up policy shared by every command that builds the
*! Andersen-Gill visit risk set: the exact maxfu() scalar token, and each
*! subject's effective end of follow-up compared with its last visit.
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (sortpreserve)
*
* Subcommands
*
*   _iivw_endpoint token <string>
*       Validates ONE finite number (decimal, scientific, or %21x hex) and
*       returns r(token), a decimal rendering that reads back as exactly the
*       same double, plus r(value). A numlist() parser cannot be used for
*       maxfu(): it shortens its tokens to 13 significant digits, so a
*       boundary typed (or replayed from the stored contract) at full double
*       precision reached the comparison as a different number.
*
*   _iivw_endpoint build , id() time() generate() [censor()|maxfu()] [touse()]
*       Generates double `generate' = the subject's effective end of
*       follow-up on every touse row (missing elsewhere), and returns
*         r(n_after)     touse rows whose visit time is later than it
*         r(n_after_id)  subjects with such a row
*         r(n_resolved)  subjects whose end and last visit were differently
*                        encoded but agree at the coarser storage precision,
*                        and are treated as the same instant
*         r(precision)   "float" or "exact"
*       It raises 198 itself when a float-resolved end would drop a gap that
*       holds a recorded visit (see the policy below), so every caller --
*       including one that calls it under quietly -- refuses the same data.
*       It does not raise the ordering error itself: callers word that
*       message for their own option. A terminal at-risk interval is then
*       appended exactly when `generate' > the subject's last visit time.
*
* The policy
*
* Endpoints are compared EXACTLY as encoded. The 1e-6 relative tolerance this
* replaces was scaled by the absolute clock value, so on a clock with a large
* origin (calendar seconds, a date in days) it swallowed real intervals of
* substantial length, and its floor of 1 swallowed every interval shorter than
* 1e-6 on a small time unit. Both changed the Cox fit and the weights for data
* that differed from the unshifted data only by a change of origin or unit.
*
* The one place exact comparison is wrong is a float-stored value. A float
* holds ~7 significant digits, so float(d/365.25) and double(d/365.25) are two
* encodings of one instant that differ by up to half a float ulp. Comparison
* is therefore made at the COARSER of the two storage precisions:
*
*   time() float      Every event time is float-representable, so the clock
*                     resolves nothing finer. The end of follow-up is rounded
*                     to float before it is compared or used as the end of the
*                     terminal interval. No float event time lies strictly
*                     between an endpoint and its float rounding, so this
*                     cannot change which subjects are at risk at any event --
*                     except to put a subject followed to maxfu(.2) at risk at
*                     an event recorded at float(.2), which is the intent.
*   censor() float,   A censor value that differs from the last visit but
*   time() not float  equals it after float rounding is the same instant at
*                     censor()'s own resolution: the effective end becomes
*                     the last visit (no terminal interval, no ordering
*                     error). A note reports how many subjects this touched.
*                     REFUSED (198) instead when the end lies above the last
*                     visit and any recorded visit of any subject falls in
*                     (last visit, end]: dropping that gap would take the
*                     subject out of a real event's risk set, which the
*                     coarser precision cannot justify.
*   otherwise         Exact. Every positive encoded interval is kept.
*
* maxfu() is a double token, so it is only ever rounded under a float time().
* A note, not a refusal, for the float case: rejecting it would turn the
* commonest real source of the pair -- `gen' instead of `gen double' on the
* same day counts -- back into a hard error (qa/test_iivw_v343_regressions).

program define _iivw_endpoint, rclass sortpreserve
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    gettoken __iivw_sub 0 : 0, parse(" ,")

    if "`__iivw_sub'" == "token" {
        local __iivw_tok = strtrim(`"`0'"')
        local __iivw_ok = 0
        if `"`__iivw_tok'"' != "" & !strpos(`"`__iivw_tok'"', " ") {
            capture confirm number `__iivw_tok'
            if _rc == 0 {
                if !missing(real("`__iivw_tok'")) local __iivw_ok = 1
            }
        }
        if !`__iivw_ok' {
            display as error "maxfu() must contain one finite numeric value"
            error 198
        }
        * Held in a scalar: `local x = exp' would itself round the value to
        * the macro's display precision before any comparison below.
        tempname __iivw_v
        scalar `__iivw_v' = real("`__iivw_tok'")
        * The shortest of these renderings that reads back as the same double.
        * 17 significant digits always round-trip an IEEE double; %21x is the
        * last resort and is exact by construction.
        local __iivw_out = strtrim(string(`__iivw_v', "%21.15g"))
        if real("`__iivw_out'") != `__iivw_v' {
            local __iivw_out = strtrim(string(`__iivw_v', "%24.17g"))
        }
        if real("`__iivw_out'") != `__iivw_v' {
            local __iivw_out = strtrim(string(`__iivw_v', "%21x"))
        }
        return local token "`__iivw_out'"
        return scalar value = `__iivw_v'
    }
    else if "`__iivw_sub'" == "build" {
        syntax , ID(varname) TIME(varname numeric) GENerate(name) ///
            [CENSor(varname numeric) MAXfu(string) TOUSE(varname numeric)]

        if ("`censor'" == "") == ("`maxfu'" == "") {
            display as error "_iivw_endpoint build: specify exactly one of censor() and maxfu()"
            error 198
        }
        confirm new variable `generate'

        tempvar __iivw_use __iivw_raw __iivw_last
        if "`touse'" != "" {
            quietly gen byte `__iivw_use' = `touse' != 0 & !missing(`touse')
        }
        else {
            quietly gen byte `__iivw_use' = 1
        }

        local __iivw_ttype : type `time'
        local __iivw_ftime = "`__iivw_ttype'" == "float"
        local __iivw_fend = 0
        if "`censor'" != "" {
            local __iivw_ctype : type `censor'
            local __iivw_fend = "`__iivw_ctype'" == "float"
            quietly gen double `__iivw_raw' = `censor' if `__iivw_use'
        }
        else {
            quietly gen double `__iivw_raw' = `maxfu' if `__iivw_use'
        }

        * stata-dev-ignore: unchecked-commit — generate() is the caller's tempvar, not a user-visible column; every caller counts r(n_after) and builds its own risk set from it
        quietly gen double `generate' = `__iivw_raw'
        if `__iivw_ftime' {
            quietly replace `generate' = float(`generate')
        }

        quietly bysort `__iivw_use' `id': egen double `__iivw_last' = ///
            max(`time') if `__iivw_use'

        local __iivw_n_resolved = 0
        if `__iivw_ftime' | `__iivw_fend' {
            * Same instant at the coarser precision, differently encoded.
            * Under a float time() the rounding above already made these
            * equal; under a float censor() the end is moved onto the visit.
            tempvar __iivw_res __iivw_tag
            quietly gen byte `__iivw_res' = `__iivw_use' & ///
                `__iivw_raw' != `__iivw_last' & ///
                float(`__iivw_raw') == float(`__iivw_last') & ///
                !missing(`__iivw_raw', `__iivw_last')
            quietly replace `generate' = `__iivw_last' if `__iivw_res'
            quietly egen byte `__iivw_tag' = tag(`id') if `__iivw_res'
            quietly count if `__iivw_tag' == 1
            local __iivw_n_resolved = r(N)

            * A resolved end LATER than the last visit drops the encoded gap
            * (last visit, end]. That is harmless only while no recorded
            * visit of any subject falls inside it: such a visit is another
            * subject's event, and dropping the gap removes this subject from
            * that event's risk set. Then the two encodings are not the same
            * instant for this analysis and the coarser precision cannot say
            * which is right, so the run is refused. Under a float time() the
            * check cannot fire (no float lies strictly between a float and
            * a value that rounds to it) but it is applied uniformly. Every
            * selected visit row is treated as a potential event time, which
            * is conservative for a non-modeled study-entry visit.
            tempvar __iivw_gap
            quietly gen byte `__iivw_gap' = `__iivw_tag' == 1 & ///
                `__iivw_raw' > `__iivw_last'
            local __iivw_n_gap_events = 0
            quietly count if `__iivw_gap'
            if r(N) > 0 {
                mata: _iivw_endpoint_gap_events("`time'", "`__iivw_use'", ///
                    "`__iivw_last'", "`__iivw_raw'", "`__iivw_gap'")
            }
            if `__iivw_n_gap_events' > 0 {
                noisily display as error "`__iivw_n_gap_events' subject(s) have an end of follow-up that differs from their last visit"
                noisily display as error "  by less than float precision, with another subject's visit between the two"
                noisily display as error "  At float resolution they would be one instant; at the stored precision the"
                noisily display as error "  gap holds a visit, so whether the subject is in that visit's risk set"
                noisily display as error "  cannot be decided. Store censor() and time() at the same precision"
                noisily display as error "  (both double, rebuilt from the original dates) and rerun."
                error 198
            }
        }

        tempvar __iivw_aft __iivw_atag
        quietly gen byte `__iivw_aft' = `__iivw_use' & `time' > `generate' & ///
            !missing(`time', `generate')
        quietly count if `__iivw_aft'
        local __iivw_n_after = r(N)
        quietly egen byte `__iivw_atag' = tag(`id') if `__iivw_aft'
        quietly count if `__iivw_atag' == 1
        local __iivw_n_after_id = r(N)

        if `__iivw_n_resolved' > 0 {
            local __iivw_which = cond(`__iivw_ftime', "time()", "censor()")
            display as text "note: `__iivw_n_resolved' subject(s) end follow-up at their last visit " ///
                "to `__iivw_which''s float precision"
            display as text "  their end of follow-up differs from the last visit by less than float"
            display as text "  precision and no recorded visit lies between the two; no terminal"
            display as text "  interval is added"
        }

        return scalar n_after    = `__iivw_n_after'
        return scalar n_after_id = `__iivw_n_after_id'
        return scalar n_resolved = `__iivw_n_resolved'
        return local precision = cond(`__iivw_ftime' | `__iivw_fend', "float", "exact")
    }
    else {
        display as error "_iivw_endpoint: subcommand must be token or build"
        error 198
    }

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end

* Number of flagged subjects (gapvar == 1, one row each) whose open-closed gap
* (lo, hi] contains at least one visit time among the use rows. Binary search
* on the sorted visit times; returned in the caller's local
* __iivw_n_gap_events.
capture mata: mata drop _iivw_endpoint_gap_events()
mata:
void _iivw_endpoint_gap_events(
    string scalar tname,
    string scalar usename,
    string scalar loname,
    string scalar hiname,
    string scalar gapname)
{
    real colvector t, lo, hi
    real scalar i, n, a, b, m

    t  = sort(st_data(., tname, usename), 1)
    lo = st_data(., loname, gapname)
    hi = st_data(., hiname, gapname)
    n = 0
    for (i = 1; i <= rows(lo); i++) {
        a = 1
        b = rows(t) + 1
        while (a < b) {
            m = floor((a + b) / 2)
            if (t[m] > lo[i]) b = m
            else a = m + 1
        }
        if (a <= rows(t)) {
            if (t[a] <= hi[i]) n++
        }
    }
    st_local("__iivw_n_gap_events", strofreal(n))
}
end
