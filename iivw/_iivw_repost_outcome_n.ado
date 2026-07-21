*! _iivw_repost_outcome_n Version 2.1.0  2026/07/21
*! Restores the user-facing estimation sample after a refit bootstrap, whose
*! e(sample) is deliberately the visit panel rather than the outcome sample.
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: eclass

* Why this exists
* ---------------
* The refit bootstrap has two samples. Its replicates must be drawn from the
* VISIT PANEL, because that is the data the visit-intensity model was fitted
* on and each draw re-fits it; but the outcome equation is evaluated on the
* OUTCOME sample, which is smaller whenever a visit has a missing outcome, a
* missing outcome covariate, or falls outside the user's if/in.
*
* bootstrap resamples whatever e(sample) the observed evaluation posts, so
* _iivw_bs_refit posts the panel frame there -- that is the mechanism that
* gets monitoring-only rows into the draws at all (see its novarlist note).
* The cost is that bootstrap then reports the panel row count as e(N) and
* leaves e(sample) marking rows the outcome model never used.
*
* Left alone that is an rc=0-but-wrong result: `e(N)' would overstate the
* outcome sample, and any post-estimation command keying on `e(sample)' -- a
* predict, a margins, a downstream iivw_diagnose comparability check -- would
* silently run over visits that contributed no outcome. So the internal frame
* is reverted to the user-facing one here, once the resampling is finished and
* the frame has done its job. The coefficient vector and the bootstrap
* variance are untouched: only the sample marker and N are restored.
*
* e(N_clust) is deliberately NOT rewritten -- it truthfully reports what
* bootstrap resampled. Because that makes e(N) and e(N_clust) describe two
* different samples, this program also posts the frame row count and the
* outcome sample's own cluster count so the two can be reconciled. See the
* note at the posting site.

program define _iivw_repost_outcome_n, eclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    * syntax, not gettoken: gettoken does NOT split on a comma, so
    * `gettoken touse 0 : 0' on "`touse', frame(...) cluster(...)" hands back
    * a token with the comma still attached and leaves the option list without
    * its leading comma -- which syntax then reads as a varlist and rejects
    * with r(101), from inside the eclass helper, after bootstrap has already
    * finished. Caught 2026-07-21 by the B6 assertion below.
    syntax varname [, FRAME(varname) CLuster(varname)]
    local touse "`varlist'"

    quietly count if `touse'
    local _n_outcome = r(N)

    * -------------------------------------------------------------------------
    * e(N) and e(N_clust) would otherwise describe DIFFERENT samples.
    *
    * bootstrap sets e(N_clust) to the number of clusters it resampled, which is
    * the count in the PANEL FRAME -- correct, and the number the "Replications
    * based on N clusters" header line is about. Reposting e(N) to the outcome
    * row count leaves those two scalars side by side in one output table
    * describing two different populations.
    *
    * That is not hypothetical. With 20 subjects contributing monitoring visits
    * but no recorded outcome, a probe on 2026-07-21 reported e(N)=376 (outcome
    * rows, spanning 100 subjects) directly beneath e(N_clust)=120. A reader --
    * or a downstream command computing a cluster-count degrees of freedom --
    * has no way to see that the 120 is not the 376's cluster count.
    *
    * The repair is to make the distinction visible rather than to fake
    * agreement. e(N_clust) is LEFT ALONE, because it truthfully reports the
    * resampling unit count; the outcome sample's own cluster count is posted
    * beside it, and the frame's row count is kept so the two samples can always
    * be reconciled after the fact.
    * -------------------------------------------------------------------------
    local _frame_n = .
    if "`frame'" != "" {
        quietly count if `frame'
        local _frame_n = r(N)
    }
    local _out_nclust = .
    if "`cluster'" != "" {
        tempvar _ocl
        quietly egen long `_ocl' = group(`cluster') if `touse'
        quietly summarize `_ocl', meanonly
        local _out_nclust = cond(r(N) == 0, 0, r(max))
    }

    ereturn repost, esample(`touse')
    ereturn scalar N = `_n_outcome'
    if `_frame_n'    < . ereturn scalar iivw_bs_frame_N     = `_frame_n'
    if `_out_nclust' < . ereturn scalar iivw_outcome_nclust = `_out_nclust'

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
