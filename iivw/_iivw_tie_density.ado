*! _iivw_tie_density Version 3.4.0  2026/08/08
*! Measure tie multiplicity among modeled event times and advise on tie method
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

* Why this exists
* ---------------
* Through 2.4.x every Andersen-Gill fit in this package inherited stcox's
* DEFAULT tie method, which is Breslow. Breslow and Efron agree exactly when no
* two events share a time, and diverge as the tie MULTIPLICITY grows -- the mean
* number of events per distinct event time. Every IIW weight is exp(-xb) from
* that fit, so the divergence is not confined to the visit model: it rescales
* the entire weighted analysis.
*
* MEASURED, not assumed. Known-truth DGP (true gamma = 0.8; 300 subjects; 25
* replications), visit times rounded onto a grid of width g:
*
*   g          events/distinct time   gamma Breslow   gamma Efron   rel. gap
*   (none)                     1.00          0.7687        0.7687       0.0%
*   0.10                      20.00          0.7069        0.7580       6.7%
*   0.25                      45.47          0.6348        0.7412      14.4%
*   0.50                      79.28          0.5385        0.7011      23.2%
*   1.00                     126.48          0.4051        0.6151      34.1%
*   2.00                     180.29          0.2421        0.4565      47.0%
*
* THE OBVIOUS STATISTIC IS THE WRONG ONE. The share of events that are tied
* saturates at 100% under the mildest rounding (g = 0.1 above), so it cannot
* tell a harmless grid from a ruinous one. Multiplicity is monotone in the gap
* and is exactly 1.00 on continuous times, which is why the threshold is set on
* it and why this note cannot fire on data that has no tie problem.
*
* The threshold is 2: at or above it, each distinct event time carries two or
* more events on average, which means time() is a coarse grid rather than a
* continuous measurement. That is the regime the table above covers.
*
* WHAT CHANGED IN 3.0.0. The table above is the reason the default is now
* Efron rather than Breslow. Note that the bias has a DIRECTION: Breslow
* attenuates gamma-hat toward the null, and because the weight is exp(-xb), an
* attenuated gamma-hat compresses the weights toward 1 -- i.e. the old default
* failed toward "no correction applied", which is the one direction a
* correction package must not fail in. The literature agrees and is not
* ambiguous: Hertz-Picciotto & Rockhill (1997, Biometrics 53:1151-1156) find
* Breslow underestimates beta with bias growing in tie load, put Efron's bias
* under 2% at n=25 per group, and conclude in their own words that "although
* the Breslow approximation is the default in many standard software packages,
* the Efron method for handling ties is to be preferred". R's coxph -- and
* therefore IrregLong, the method author's own IIW implementation -- defaults
* to Efron, so Efron is also what reproduces the reference.
*
* 2.4.0 shipped a runtime NOTE instead of changing the default, on the argument
* that a default change silently moves every existing user's numbers. That
* argument was about migration, not correctness, and migration is what a major
* version bump plus a `breslow' escape hatch is for. The note survives, but its
* job is inverted: it now fires only when the user has explicitly asked for
* `breslow' on data where the measurement above says that hurts. See the
* firing condition below.
*
* This is still a NOTE, not an error -- `breslow' is a legitimate request, both
* for reproducing a pre-3.0.0 analysis and for matching another package.
* Compare the end-of-follow-up contract in iivw_weight.ado, which IS a hard
* error because there no safe default exists.

* sortpreserve: egen tag() re-sorts the caller's data, and both call sites sit
* mid-fit -- iivw_weight's is between its stset and its stcox, inside the
* preserve block, and iivw_exogtest's is between its stset and the by() loop.
* Neither caller should have its sort order changed by a measurement that only
* reads. Restoring it here removes the whole question rather than relying on
* each downstream statement to re-sort defensively.
program define _iivw_tie_density, rclass sortpreserve
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , EVent(varname numeric) STOP(varname numeric) ///
        TOUSE(varname numeric) METHod(string) [CMDname(string) NONOTE]

    * method() is REQUIRED and is validated against a closed list, because this
    * helper's whole job is to decide whether to warn about the method in force.
    * A caller that forgot the option, or spelled it, would otherwise silently
    * take the "no warning" branch -- which is the failure that hides exactly the
    * case the note exists for. An advisory that fails closed is worth more than
    * one that defaults to silence. (The gate in this package's own
    * iivw_diagnose shipped INVERTED once; that is the precedent being guarded
    * against here.)
    if !inlist("`method'", "efron", "breslow") {
        display as error ///
            "_iivw_tie_density: method() must be efron or breslow, was `method'"
        error 198
    }

    * Rows that enter the partial likelihood as events. `touse' is the caller's
    * model sample, so a row screened out for a missing covariate -- or a
    * zero-length interval that stset would drop -- is not counted here either.
    *
    * !missing(`stop') is belt and braces. Neither shipped caller can hand us a
    * missing stop time (iivw_weight rejects missing time() outright, and
    * iivw_exogtest's usable marker screens missing start/stop), but a caller
    * that built its marker as `stop > start' would silently include one:
    * missing is GREATER than every number in Stata, so `. > 5' is TRUE. A
    * missing stop would then form its own "distinct event time" and deflate
    * the multiplicity -- the wrong direction, since it would suppress the note.
    tempvar __iivw_ev __iivw_evtag
    quietly gen byte `__iivw_ev' = ///
        (`touse' & `event' == 1 & !missing(`stop'))
    quietly count if `__iivw_ev'
    local __iivw_n_ev = r(N)

    local __iivw_n_evtime = 0
    local __iivw_mult = .
    if `__iivw_n_ev' > 0 {
        quietly egen byte `__iivw_evtag' = tag(`stop') if `__iivw_ev'
        quietly count if `__iivw_evtag' == 1
        local __iivw_n_evtime = r(N)
        if `__iivw_n_evtime' > 0 {
            local __iivw_mult = `__iivw_n_ev' / `__iivw_n_evtime'
        }
    }

    * The threshold. Named once so the note, the return and the QA gate cannot
    * drift apart.
    local __iivw_cut = 2

    * The note fires only when the ATTENUATING method is in force on data that
    * attenuates. Since 3.0.0 that is the non-default path: the user had to type
    * `breslow' to get here. So this is no longer "you may not have noticed the
    * default" -- it is "the choice you made is the one the measurement above
    * argues against, on this dataset." Under the Efron default there is nothing
    * to advise, and the multiplicity is still returned in r() for anyone who
    * wants to gate on it.
    if "`nonote'" == "" & "`method'" == "breslow" & ///
            `__iivw_mult' < . & `__iivw_mult' >= `__iivw_cut' {
        local __iivw_who = cond("`cmdname'" == "", "visit-intensity", "`cmdname'")
        noisily display as text ""
        noisily display as text "note: visit times are heavily tied -- " ///
            as result %6.1f `__iivw_mult' as text " events per distinct event time"
        noisily display as text "  (" as result "`__iivw_n_ev'" as text ///
            " modeled events at " as result "`__iivw_n_evtime'" as text ///
            " distinct times)"
        noisily display as text ""
        noisily display as text "  You asked for " as result "breslow" as text ///
            ", so the `__iivw_who' Cox model is using the"
        noisily display as text "  Breslow method for tied event times. Breslow attenuates the fitted"
        noisily display as text "  coefficient toward the null as tie multiplicity grows, and the"
        noisily display as text "  weights are exp(-xb) from this model, so the attenuation propagates"
        noisily display as text "  to the whole weighted analysis -- in the direction of UNDER-"
        noisily display as text "  correcting for informative observation. On a known-truth check"
        noisily display as text "  with this much tying the two methods differed by tens of percent."
        noisily display as text ""
        noisily display as text "  Efron is the default and the more accurate method here"
        noisily display as text "  (Hertz-Picciotto & Rockhill 1997), and it is what R's coxph() --"
        noisily display as text "  and therefore IrregLong -- uses, so it is also what reproduces a"
        noisily display as text "  reference implementation. Drop " as result "breslow" as text ///
            " unless you are deliberately"
        noisily display as text "  reproducing a pre-3.0.0 result."
    }

    return scalar tie_multiplicity = `__iivw_mult'
    return scalar n_event_times    = `__iivw_n_evtime'
    return scalar n_modeled_events = `__iivw_n_ev'
    return scalar tie_cut          = `__iivw_cut'
    return local  tie_method       "`method'"

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
