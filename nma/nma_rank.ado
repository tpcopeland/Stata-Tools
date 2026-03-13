*! nma_rank Version 1.0.2  2026/03/13
*! Treatment rankings (SUCRA) for network meta-analysis
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  nma_rank [, best(min|max) reps(integer 10000) seed(integer)
      plot cumulative saving(filename) replace]

Description:
  Computes treatment rankings via Monte Carlo simulation from the
  posterior distribution of treatment effects. Produces SUCRA scores
  and cumulative rankograms.

See help nma_rank for complete documentation
*/

program define nma_rank, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    set varabbrev off

    syntax [, BEST(string) REPS(integer 10000) SEED(integer -1) ///
        PLOT CUMulative SCHeme(string) SAVing(string) REPLACE ///
        TItle(string)]

    * =======================================================================
    * CHECK PREREQUISITES
    * =======================================================================

    _nma_check_setup
    _nma_check_fitted
    _nma_get_settings

    local ref         "`_nma_ref'"
    local treatments  "`_nma_treatments'"
    local n_treatments = `_nma_n_treatments'
    local k = `n_treatments'
    local ref_code    : char _dta[_nma_ref_code]

    if "`best'" == "" local best "max"
    if !inlist("`best'", "min", "max") {
        display as error "best() must be min or max"
        exit 198
    }
    if "`scheme'" == "" local scheme "white_tableau"

    _nma_display_header, command("nma_rank") ///
        description("Treatment rankings (SUCRA)")

    * =======================================================================
    * MONTE CARLO SIMULATION
    * =======================================================================

    tempname b V
    matrix `b' = e(b)
    matrix `V' = e(V)

    if `seed' >= 0 {
        set seed `seed'
    }

    * Simulate from N(beta, Vbeta) in Mata
    mata: _nma_rank_simulate("`b'", "`V'", `reps', `k', "`best'", ///
        `ref_code')

    * Mata stores results in:
    *   _nma_sucra (k x 1)
    *   _nma_meanrank (k x 1)
    *   _nma_rankprob (k x k) — row i, col r = P(treatment i ranks r-th)

    * =======================================================================
    * DISPLAY
    * =======================================================================

    display as text "{hline 50}"
    display as text %~20s "Treatment" _col(25) %~10s "SUCRA" _col(38) %~10s "Mean Rank"
    display as text "{hline 50}"

    forvalues i = 1/`k' {
        local lbl : char _dta[_nma_trt_`i']
        local sucra = _nma_sucra[`i', 1]
        local mrank = _nma_meanrank[`i', 1]
        display as result %-20s "`lbl'" ///
            _col(25) %8.1f `=`sucra' * 100' "%" ///
            _col(40) %6.1f `mrank'
    }
    display as text "{hline 50}"
    if "`best'" == "max" {
        display as text "SUCRA: 100% = always best, 0% = always worst"
        display as text "Best = highest effect (e.g., most effective treatment)"
    }
    else {
        display as text "SUCRA: 100% = always best, 0% = always worst"
        display as text "Best = lowest effect (e.g., fewest side effects)"
    }

    * =======================================================================
    * CUMULATIVE RANKOGRAM PLOT
    * =======================================================================

    if "`plot'" != "" {
        * Save labels before preserve (clear wipes _dta chars)
        forvalues _t = 1/`k' {
            local _trtlbl_`_t' : char _dta[_nma_trt_`_t']
        }
        preserve

        quietly {
            clear
            set obs `=`k' * `k''
            gen int treatment = .
            gen int rank = .
            gen double cumprob = .
            gen str80 trt_label = ""
        }

        local row = 0
        forvalues i = 1/`k' {
            local lbl "`_trtlbl_`i''"
            local cumul = 0
            forvalues r = 1/`k' {
                local ++row
                local cumul = `cumul' + _nma_rankprob[`i', `r']
                quietly replace treatment = `i' in `row'
                quietly replace rank = `r' in `row'
                if "`cumulative'" != "" {
                    quietly replace cumprob = `cumul' in `row'
                }
                else {
                    quietly replace cumprob = _nma_rankprob[`i', `r'] in `row'
                }
                quietly replace trt_label = "`lbl'" in `row'
            }
        }

        if "`title'" == "" {
            if "`cumulative'" != "" {
                local title "Cumulative Ranking Probabilities (SUCRA)"
            }
            else {
                local title "Ranking Probabilities"
            }
        }

        local ylab "Probability"
        if "`cumulative'" != "" local ylab "Cumulative Probability"

        * Build separate line commands per treatment
        local plots ""
        forvalues i = 1/`k' {
            local plots "`plots' (line cumprob rank if treatment == `i', sort)"
        }

        * Legend labels
        local legend_labels ""
        forvalues i = 1/`k' {
            local lbl "`_trtlbl_`i''"
            local legend_labels `"`legend_labels' `i' "`lbl'""'
        }

        * Construct saving() option for twoway
        local save_opt ""
        if "`saving'" != "" {
            local save_opt `"saving("`saving'", `replace')"'
        }

        twoway `plots', ///
            xlabel(1(1)`k') ylabel(0(0.2)1) ///
            xtitle("Rank") ytitle("`ylab'") ///
            title("`title'") ///
            legend(order(`legend_labels') cols(2) size(small)) ///
            scheme(`scheme') ///
            `save_opt'

        restore
    }

    * =======================================================================
    * RETURNS
    * =======================================================================

    * Copy before returning (return matrix moves, not copies)
    tempname sucra_copy mrank_copy rprob_copy
    matrix `sucra_copy' = _nma_sucra
    matrix `mrank_copy' = _nma_meanrank
    matrix `rprob_copy' = _nma_rankprob
    return matrix sucra = `sucra_copy'
    return matrix meanrank = `mrank_copy'
    return matrix rankprob = `rprob_copy'
    return scalar reps = `reps'
    return local best "`best'"

    set varabbrev `_varabbrev'
end

* =========================================================================
* Mata: Monte Carlo ranking simulation
* =========================================================================
mata:
void _nma_rank_simulate(
    string scalar b_name,
    string scalar V_name,
    real scalar reps,
    real scalar k,
    string scalar best,
    real scalar ref_code)
{
    real rowvector b, eff_r
    real matrix V, draws, effects, L, rankprob, ranks
    real scalar p, i, r, col, rnk, cumul, sucra_sum
    real colvector sucra, meanrank, rank_r, order_r

    b = st_matrix(b_name)
    V = st_matrix(V_name)
    p = cols(b)

    /* Generate multivariate normal draws */
    L = cholesky(V)
    if (hasmissing(L)) L = cholesky(V + 0.0001 * I(p))

    draws = J(reps, p, 0)
    for (i = 1; i <= reps; i++) {
        draws[i, .] = b + (L * rnormal(p, 1, 0, 1))'
    }

    /* Expand to full k treatments (including reference = 0) */
    effects = J(reps, k, 0)
    col = 0
    for (i = 1; i <= k; i++) {
        if (i != ref_code) {
            col++
            effects[., i] = draws[., col]
        }
        /* reference treatment has effect = 0 by definition */
    }

    /* Rank treatments for each draw */
    rankprob = J(k, k, 0)
    meanrank = J(k, 1, 0)

    for (r = 1; r <= reps; r++) {
        eff_r = effects[r, .]

        /* Rank: 1 = best */
        if (best == "max") {
            /* Descending: highest effect = rank 1 */
            order_r = order(eff_r', -1)
        }
        else {
            /* Ascending: lowest effect = rank 1 */
            order_r = order(eff_r', 1)
        }

        /* Assign ranks */
        rank_r = J(k, 1, 0)
        for (i = 1; i <= k; i++) {
            rank_r[order_r[i]] = i
        }

        for (i = 1; i <= k; i++) {
            rnk = rank_r[i]
            rankprob[i, rnk] = rankprob[i, rnk] + 1
            meanrank[i] = meanrank[i] + rnk
        }
    }

    rankprob = rankprob / reps
    meanrank = meanrank / reps

    /* SUCRA = (1/(k-1)) * sum_{r=1}^{k-1} P(rank <= r) */
    /* P(rank <= r) is the cumulative probability, not the raw probability */
    sucra = J(k, 1, 0)
    for (i = 1; i <= k; i++) {
        cumul = 0
        sucra_sum = 0
        for (r = 1; r <= k - 1; r++) {
            cumul = cumul + rankprob[i, r]
            sucra_sum = sucra_sum + cumul
        }
        sucra[i] = sucra_sum / (k - 1)
    }

    st_matrix("_nma_sucra", sucra)
    st_matrix("_nma_meanrank", meanrank)
    st_matrix("_nma_rankprob", rankprob)
}
end
