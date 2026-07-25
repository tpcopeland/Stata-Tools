*! _iivw_tie_density Version 2.4.0  2026/07/25
*! Measure tie multiplicity among modeled event times and advise on efron
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

* Why this exists
* ---------------
* Every Andersen-Gill fit in this package inherits stcox's DEFAULT tie method,
* which is Breslow. Breslow and Efron agree exactly when no two events share a
* time, and diverge as the tie MULTIPLICITY grows -- the mean number of events
* per distinct event time. Every IIW weight is exp(-xb) from that fit, so the
* divergence is not confined to the visit model: it rescales the entire
* weighted analysis.
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
* This is a NOTE, not an error. Breslow is a defensible default, `efron' is
* documented, and changing the default would silently move every existing
* user's numbers. What was missing was any runtime signal that the choice
* mattered for THIS dataset -- the user previously had to read a help-file
* paragraph and self-diagnose. Compare the end-of-follow-up contract in
* iivw_weight.ado, which IS a hard error because there no safe default exists.

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
        TOUSE(varname numeric) [CMDname(string) NONOTE]

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

    if "`nonote'" == "" & `__iivw_mult' < . & `__iivw_mult' >= `__iivw_cut' {
        local __iivw_who = cond("`cmdname'" == "", "visit-intensity", "`cmdname'")
        noisily display as text ""
        noisily display as text "note: visit times are heavily tied -- " ///
            as result %6.1f `__iivw_mult' as text " events per distinct event time"
        noisily display as text "  (" as result "`__iivw_n_ev'" as text ///
            " modeled events at " as result "`__iivw_n_evtime'" as text ///
            " distinct times)"
        noisily display as text ""
        noisily display as text "  The `__iivw_who' Cox model is using the Breslow method for tied"
        noisily display as text "  event times, which is stcox's default. Breslow attenuates the"
        noisily display as text "  fitted coefficient as tie multiplicity grows, and the weights are"
        noisily display as text "  exp(-xb) from this model, so the attenuation propagates to the"
        noisily display as text "  whole weighted analysis. On a known-truth check with this much"
        noisily display as text "  tying the two methods differed by tens of percent."
        noisily display as text ""
        noisily display as text "  Efron is the more accurate method here, and it is what R's"
        noisily display as text "  coxph() -- and therefore IrregLong -- uses by default, so it is"
        noisily display as text "  also what reproduces a reference implementation."
        noisily display as text "  Add " as result "efron" as text " to use it."
    }

    return scalar tie_multiplicity = `__iivw_mult'
    return scalar n_event_times    = `__iivw_n_evtime'
    return scalar n_modeled_events = `__iivw_n_ev'
    return scalar tie_cut          = `__iivw_cut'

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
