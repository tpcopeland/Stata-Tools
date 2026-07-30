*! _tvexpose_eligible Version 1.10.0  2026/07/30
*! Decide whether a tvexpose call may use the categorical fast path
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

* Option-only half of the tvexpose fast-path eligibility predicate.
*
* This program looks at nothing but the parsed option values: it never reads
* the caller's data and never touches the using file. That is deliberate.
* Dispatch order requires every option-only refusal to happen BEFORE any data
* are loaded or mutated, so that an ineligible call pays no fast-path cost at
* all and can enter the unchanged legacy path untouched.
*
* The data-level half of the predicate -- whole-number category codes, no
* reference-coded source row, and no within-person overlap after clipping --
* is evaluated by tvexpose itself once the source is in memory, because it
* cannot be decided from options.
*
* Returns:
*   r(eligible)  1 or 0
*   r(reason)    "" when eligible; otherwise the first blocking condition

program define _tvexpose_eligible, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    * hasstop() defaults to 0 -- "no stop() bound" -- so a caller that forgets
    * to pass it fails CLOSED, onto the legacy path, rather than open.
    syntax , EXPtype(string) [ ///
        HASstop(integer 0) ///
        FLAGS(string) ///
        MERGEdays(integer 0) ///
        LAGdays(integer 0) ///
        WASHoutdays(integer 0) ///
        FILLgapdays(integer 0) ///
        CARRYforwarddays(integer 0) ///
        GRACEon(integer 0) ///
        REFerence(string) ]

    * The authoritative vocabulary of option families that keep a call OFF the
    * fast path. The caller passes the names of the options it actually saw;
    * an unrecognised name is an error rather than a silent pass, so a typo or
    * a stale name in the caller cannot quietly make an excluded call look
    * eligible. Extending tvexpose's syntax without extending this list is
    * caught by the option-coverage check in qa/test_tvexpose_fastpath.do.
    local _blocking "pointtime evertreated currentformer duration dose dosecuts"
    local _blocking "`_blocking' continuousunit expandunit bytype"
    local _blocking "`_blocking' recency recencyunit grace window"
    local _blocking "`_blocking' switching switchingdetail statetime"
    local _blocking "`_blocking' priority split layer combine keepvars"
    local _blocking "`_blocking' check gaps overlaps summarize validate"
    local _blocking "`_blocking' flow dropinvalid verbose saveas"

    local reason ""
    foreach f of local flags {
        local _known : list f in _blocking
        if !`_known' {
            noisily display as error ///
                "_tvexpose_eligible: '`f'' is not a recognised blocking option name"
            exit 198
        }
        if "`reason'" == "" local reason "option `f'"
    }

    * stop() is required and pointtime is excluded: the first fast path covers
    * interval episodes only.
    if "`reason'" == "" & `hasstop' == 0 local reason "no stop() bound"

    * Only the default categorical time-varying mode.
    if "`reason'" == "" & "`exptype'" != "timevarying" ///
        local reason "exposure mode `exptype'"

    * Every data-cleaning knob must be at its default. Each of these rewrites
    * the episode geometry before construction, which the fast builder does
    * not reproduce.
    if "`reason'" == "" & `mergedays'        != 0 local reason "merge()"
    if "`reason'" == "" & `lagdays'          != 0 local reason "lag()"
    if "`reason'" == "" & `washoutdays'      != 0 local reason "washout()"
    if "`reason'" == "" & `fillgapdays'      != 0 local reason "fillgaps()"
    if "`reason'" == "" & `carryforwarddays' != 0 local reason "carryforward()"
    if "`reason'" == "" & `graceon'          != 0 local reason "grace()"

    * A non-integer reference cannot be carried into a value label: Stata
    * refuses `label define ... 1.5 "..."' with r(198). Keeping such codes on
    * the legacy path preserves whatever the released command does with them
    * rather than inventing a new answer.
    if "`reason'" == "" & "`reference'" != "" {
        capture confirm number `reference'
        if _rc                                       local reason "reference() is not a number"
        else if `reference' != floor(`reference')    local reason "reference() is not a whole number"
        else if missing(`reference')                 local reason "reference() is missing"
    }

    return local reason "`reason'"
    return scalar eligible = ("`reason'" == "")

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
