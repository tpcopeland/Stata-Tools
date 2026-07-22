*! _tvtools_interval_union Version 1.8.0  2026/07/22
*! Clipped running-maximum interval union, gap, and overlap engine
*! Author: Timothy P Copeland, Karolinska Institutet
*! Part of the tvtools package

/*
One engine for every question that depends on how a person's closed
[start, stop] intervals occupy the calendar: covered days, gap count,
overlap count, and the denominators the diagnostics report.

Summing stop-start+1 across rows answers none of these once rows overlap:
overlapping episodes double-count the shared days, which is how tvexpose
came to report 105% coverage on a two-episode fixture whose union is
exactly the full 20-day window. Comparing each row only with its immediate
predecessor is equally wrong, because a long outer episode makes every
nested row look like a fresh segment.

The engine sorts within person, carries the running maximum stop seen so
far, and opens a new segment only when a row starts more than one day
after that maximum. Under the closed-interval contract:

    overlap  <=>  start <= running maximum prior stop
    gap      <=>  start >  running maximum prior stop + 1

Covered days are then summed over segments, never over rows, so a day
covered by any number of episodes counts exactly once.

Syntax:
    _tvtools_interval_union, ID(varname) START(varname) STOP(varname) ///
        [ CLIPLow(varname) CLIPHigh(varname)                          ///
          UNIONDays(name) NSEGments(name) NGAps(name) NOVerlaps(name) ]

    cliplow()/cliphigh()  clip every interval to this window before the
                          union; rows falling entirely outside are ignored
    uniondays()   new variable: covered days for this person (constant by id)
    nsegments()   new variable: number of maximal covered runs
    ngaps()       new variable: nsegments - 1
    noverlaps()   new variable: rows whose start <= prior running max stop

Returns:
    r(union_days)  total covered days summed over persons
    r(n_gaps)      total gaps summed over persons
    r(n_overlaps)  total overlapping rows
*/

program define _tvtools_interval_union, rclass
    version 16.0
    local orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , ID(varname) START(varname numeric) STOP(varname numeric) ///
            [ CLIPLow(varname numeric) CLIPHigh(varname numeric) ///
              UNIONDays(name) NSEGments(name) NGAps(name) NOVerlaps(name) ]

        tempvar s0 e0 keep rmax prior newseg segid segstart segstop segdays
        tempvar ovl segtag

        * --- Clip to the requested window --------------------------------
        quietly generate double `s0' = `start'
        quietly generate double `e0' = `stop'
        if "`cliplow'" != ""  quietly replace `s0' = max(`s0', `cliplow')
        if "`cliphigh'" != "" quietly replace `e0' = min(`e0', `cliphigh')

        * A row clipped out of existence contributes nothing; it must not
        * open a segment or register as an overlap.
        quietly generate byte `keep' = !missing(`s0', `e0') & `s0' <= `e0'

        * --- Running maximum prior stop, within person -------------------
        sort `id' `keep' `s0' `e0'
        quietly generate double `rmax' = .
        quietly by `id' `keep': replace `rmax' = `e0' if _n == 1 & `keep'
        quietly by `id' `keep': replace `rmax' = max(`rmax'[_n-1], `e0') ///
            if _n > 1 & `keep'
        quietly by `id' `keep': generate double `prior' = `rmax'[_n-1] if _n > 1 & `keep'

        * --- Segment boundaries ------------------------------------------
        quietly generate byte `newseg' = `keep' & (missing(`prior') | `s0' > `prior' + 1)
        quietly by `id' `keep': generate long `segid' = sum(`newseg')

        * --- Overlaps ------------------------------------------------------
        quietly generate byte `ovl' = `keep' & !missing(`prior') & `s0' <= `prior'

        * --- Covered days, summed over segments not rows -----------------
        quietly bysort `id' `segid' (`s0' `e0'): generate double `segstart' = `s0'[1] if `keep'
        quietly bysort `id' `segid': egen double `segstop' = max(`e0') if `keep'
        quietly generate double `segdays' = `segstop' - `segstart' + 1 if `keep'
        quietly bysort `id' `segid': generate byte `segtag' = (_n == 1) & `keep'

        * --- Emit the requested per-person variables ----------------------
        if "`uniondays'" != "" {
            capture drop `uniondays'
            quietly bysort `id': egen double `uniondays' = total(cond(`segtag', `segdays', 0))
            label variable `uniondays' "Covered days (interval union)"
        }
        if "`nsegments'" != "" {
            capture drop `nsegments'
            quietly bysort `id': egen double `nsegments' = total(`newseg')
            label variable `nsegments' "Maximal covered runs"
        }
        if "`ngaps'" != "" {
            capture drop `ngaps'
            quietly bysort `id': egen double `ngaps' = total(`newseg')
            quietly replace `ngaps' = max(`ngaps' - 1, 0)
            label variable `ngaps' "Gaps in coverage"
        }
        if "`noverlaps'" != "" {
            capture drop `noverlaps'
            quietly bysort `id': egen double `noverlaps' = total(`ovl')
            label variable `noverlaps' "Overlapping rows"
        }

        quietly summarize `segdays' if `segtag', meanonly
        local _union_total = cond(r(N) == 0, 0, r(sum))
        quietly count if `newseg'
        local _nseg_total = r(N)
        quietly count if `ovl'
        local _novl_total = r(N)

        * Gaps are counted per person, so subtract one segment per person
        * that has any covered row at all.
        tempvar anykeep idtag
        quietly bysort `id': egen byte `anykeep' = max(`keep')
        quietly bysort `id': generate byte `idtag' = (_n == 1) & `anykeep'
        quietly count if `idtag'
        local _npersons = r(N)

        return scalar union_days = `_union_total'
        return scalar n_segments = `_nseg_total'
        return scalar n_gaps     = `_nseg_total' - `_npersons'
        return scalar n_overlaps = `_novl_total'
    }
    local rc = _rc
    set varabbrev `orig_varabbrev'
    if `rc' exit `rc'
end
