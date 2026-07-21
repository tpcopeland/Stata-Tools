*! _finegray_mata Version 1.2.0  2026/07/20
*! Mata forward-backward scan engine for Fine-Gray regression
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: internal (stores results in Stata matrices)

/*
Internal command: Fits Fine-Gray subdistribution hazard model using
the forward-backward scan algorithm (Kawaguchi et al. 2021).
Called by finegray. Not intended for direct user invocation.

Algorithm: O(np) per Newton-Raphson iteration
  1. KM censoring distribution G(t) (supports left truncation)
  2. Incremental risk-set tracking with entry-time pointer
  3. Backward scan: weighted sums for competing-event subjects
  4. Combine at cause-event times for score/Hessian
  5. Newton-Raphson with step halving

Key detail: processes observations in time-point groups to correctly
handle tied events (Breslow method) and prevent double-counting of
competing events at tied cause-event times.

Left truncation: subjects enter the risk set at _t0 and exit at _t.
The entry-time pointer advances through subjects sorted by _t0,
adding them to the active risk set as event times are processed.
When all _t0 == 0, this degenerates to the original full-cumsum
algorithm.
*/

* Loading guard.
*
* The sentinel MUST be a Mata function, not this Stata program.  `mata clear'
* (and `mata: mata clear') drops every Mata function while leaving Stata programs
* untouched -- so a Stata-program sentinel still answers "loaded" when the engine
* is in fact gone, the reload never fires, and the next Mata call dies with
* r(3499) "function not found".  Every caller therefore probes
* _finegray_mata_ok() (defined in the Mata block below) and reloads this file if
* the probe errors.  The program below is kept only as a human-facing marker.
capture program drop _finegray_mata_loaded
program define _finegray_mata_loaded
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        display as text "_finegray_mata is loaded"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

mata:
mata set matastrict on

/* The real load sentinel: a Mata function, so that `mata clear' -- which wipes
   Mata but not Stata programs -- makes the probe fail and the caller reload. */
void _finegray_mata_ok() {}

/* Single-stratum KM of censoring distribution (with left truncation).
   Returns the POST-JUMP survivor at each observation time, i.e. the ordinary
   right-continuous KM step values.  Consumers that need the IPCW weight take
   the left limit G(t-) via _finegray_G_at_times/_finegray_G_minus; keeping the
   raw step values here is what lets that lookup be exact at, between, and
   beyond observation times. */
real colvector _finegray_km_censor_single(
    real colvector t,
    real colvector delta,
    real scalar censval,
    real colvector event_type,
    real colvector t0,
    | real scalar n_trunc_out)
{
    real colvector row_id
    real scalar n, i, j, surv, n_risk_at_t, n_cens_at_t, cur_time, ep
    real colvector G, ord, entry_ord

    n = rows(t)
    G = J(n, 1, 1)
    /* Deterministic tie-break by row index.  Mata's order() resolves ties
       using Stata's sort seed, which ADVANCES on every sort, so a tied key
       (every t0 == 0 when there is no delayed entry) yields a different
       permutation on each call -- and the risk-set scan then accumulates in
       a different floating-point order.  Without this the same command on
       the same data is not bit-reproducible. */
    row_id = (1::n)
    ord = order((t, row_id), (1, 2))
    entry_ord = order((t0, row_id), (1, 2))

    surv = 1
    ep = 1  /* entry pointer */
    n_risk_at_t = 0

    /* For LT-KM we need to count the risk set dynamically.
       Stata survival intervals are (t0, t], so the risk set at time t is the
       subjects with t0 < t AND _t >= t: a subject entering at exactly t is not
       yet at risk for an event at t.
       Process entry events (sorted by t0) and exit events (sorted by _t)
       simultaneously via a two-pointer merge. */

    i = 1
    while (i <= n) {
        cur_time = t[ord[i]]

        /* Add entries: subjects with t0 < cur_time */
        while (ep <= n) {
            if (t0[entry_ord[ep]] >= cur_time) break
            /* Only count if subject is still alive (t >= cur_time) */
            if (t[entry_ord[ep]] >= cur_time) {
                n_risk_at_t++
            }
            ep++
        }

        /* Count censoring events in this time group */
        n_cens_at_t = 0
        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            if (event_type[ord[j]] == censval & delta[ord[j]] == 0) {
                n_cens_at_t++
            }
            j++
        }

        if (n_cens_at_t > 0 & n_risk_at_t > 0) {
            surv = surv * (1 - n_cens_at_t / n_risk_at_t)
        }

        /* Assign G to all obs at this time, then remove them from risk set */
        while (i < j) {
            G[ord[i]] = surv
            n_risk_at_t--
            i++
        }
    }

    real scalar n_trunc
    n_trunc = 0
    for (i = 1; i <= n; i++) {
        if (G[i] < 1e-10) {
            G[i] = 1e-10
            n_trunc++
        }
    }
    /* This function never prints.  A stratified sweep calls it once per
       stratum, so a note emitted here would fire once PER STRATUM; the
       decision to print, and the aggregation across strata, belong to
       _finegray_km_censor.  Report the count back by reference instead. */
    if (args() >= 6) n_trunc_out = n_trunc

    return(G)
}

/* KM of censoring distribution, optionally stratified by byg */
real colvector _finegray_km_censor(
    real colvector t,
    real colvector delta,
    real scalar censval,
    real colvector event_type,
    real colvector byg_id,
    real colvector t0,
    | real scalar quiet)
{
    real scalar n, g, nlev, n_trunc, n_trunc_tot
    real colvector G, levels, sel

    /* quiet suppresses the G-truncation note.  The fit prints it once (the
       data characteristic is the user's to act on); post-estimation commands
       recompute G for the influence function and must NOT reprint it, or a
       fit-time warning appears attributed to predict/cif.  Omitted => 0. */
    if (args() < 7) quiet = 0
    n_trunc_tot = 0

    n = rows(t)
    G = J(n, 1, 1)

    levels = uniqrows(byg_id)
    nlev = rows(levels)
    if (nlev > 1) {
        for (g = 1; g <= nlev; g++) {
            sel = selectindex(byg_id :== levels[g])
            G[sel] = _finegray_km_censor_single(t[sel], delta[sel],
                censval, event_type[sel], t0[sel], n_trunc)
            n_trunc_tot = n_trunc_tot + n_trunc
        }
    }
    else {
        G = _finegray_km_censor_single(t, delta, censval, event_type, t0,
            n_trunc)
        n_trunc_tot = n_trunc
    }

    /* One note per sweep, counting every stratum.  Truncation is a property of
       the censoring KM as a whole; the per-stratum breakdown is not something
       the user acts on differently, and printing it per stratum buried the
       message under its own repeats. */
    if (n_trunc_tot > 0 & !quiet) {
        printf("{txt}note: G(t) truncated to 1e-10 for %g observations;" +
            " inference may be sensitive\n", n_trunc_tot)
    }

    return(G)
}

/* Map each observation to its censoring-distribution group. */
real colvector _finegray_group_index(
    real colvector byg_id,
    real colvector levels)
{
    real scalar g
    real colvector gidx, sel

    gidx = J(rows(byg_id), 1, .)
    for (g = 1; g <= rows(levels); g++) {
        sel = selectindex(byg_id :== levels[g])
        gidx[sel] = J(rows(sel), 1, g)
    }
    return(gidx)
}

/* Evaluate every stratum-specific censoring KM at arbitrary target times, as
   the LEFT LIMIT G_g(target_t-).  G carries the post-jump survivor at each
   observation time, so accumulating only the jumps at times strictly BELOW the
   target yields the left limit -- for a target that is itself an observation
   time as well as for one between (or beyond) observation times.

   The left limit is the convention both reference implementations use:
   cmprsk::crr evaluates the censoring KM at ftime*(1 - 100*eps) and stcrreg
   does the same.  A subject whose time coincides with a censoring event must
   NOT absorb that time's KM jump.

   Fine-Gray IPCW weights for a retained competing-event subject use the
   numerator from THAT SUBJECT'S censoring stratum, not the stratum of the
   cause event currently being processed. */
real matrix _finegray_G_at_times(
    real colvector t,
    real colvector G,
    real colvector byg_id,
    real colvector target_t)
{
    real scalar g, i, p, lastg
    real colvector levels, sel, gord, tord
    real matrix out

    levels = uniqrows(byg_id)
    out = J(rows(target_t), rows(levels), 1)
    tord = order(target_t, 1)

    for (g = 1; g <= rows(levels); g++) {
        sel = selectindex(byg_id :== levels[g])
        gord = sel[order(t[sel], 1)]
        p = 1
        lastg = 1
        for (i = 1; i <= rows(tord); i++) {
            while (p <= rows(gord)) {
                if (t[gord[p]] < target_t[tord[i]]) {
                    lastg = G[gord[p]]
                    p++
                }
                else break
            }
            out[tord[i], g] = lastg
        }
    }
    return(out)
}

/* Left-limit censoring survivor G(T_i-) for each observation, read from that
   observation's OWN censoring stratum.  This is the IPCW denominator used to
   weight a competing-event subject back into the subdistribution risk set. */
real colvector _finegray_G_minus(
    real colvector gidx,
    real matrix Gt)
{
    real scalar i, n
    real colvector out

    n = rows(gidx)
    out = J(n, 1, 1)
    for (i = 1; i <= n; i++) out[i] = Gt[i, gidx[i]]
    return(out)
}

/* ------------------------------------------------------------------------
   DELAYED ENTRY: the entry distribution H, and the combined weight A = G*H.

   Stabilized Zhang-Zhang-Fine Weight 1 is  w_i(t) = A(t-) / A(X_i-)  with

       A(t) = b(t) / S(t-)                  ZZF (2011) eq. (5)   [canonical]
            = P(L < t) * G(t-)              since b(t) = P(L<t) S(t-) G(t-)
            = H(t-) * G(t-)                 Geskus (2011) eq. (11)

   so H estimates P(L < t): the probability of having ENTERED by t.  Gate
   Z-ties established that the two forms agree to machine precision on every
   tie-collision class, which is what authorizes the G*H product form here.

   The product form is not merely convenient -- it is what makes the no-LT
   path BIT-IDENTICAL.  With no delayed entry every l_j = 0, so for any t > 0
   the product below is empty and H == 1, giving A == G exactly.  Computing
   the canonical b/S instead would reach the same limit by a different
   floating-point route and would perturb every released right-censoring
   result in its last digits.

   Sourced formulas (Geskus 2011, sec. 2.1, p.41):

       H(t)  = prod_{l_(j) >  t}  ( 1 - w_j / r(l_(j)) )        eq. (6)
       H(t-) = prod_{l_(j) >= t}  ( 1 - w_j / r(l_(j)) )        left limit
       r(u)  = #{ i : x_i >= u  &  l_i <= u }                   p.40

   H is a REVERSE-time product limit: "L is right truncated by X, this
   statistic is obtained by reversal of time, such that -L is left truncated
   by -X" (p.41).  So H is a product over entry times ABOVE t, and it rises
   to 1 at the right edge.

   TIE CONVENTION.  r(l_(j)) counts the entering subjects themselves (l_i <= u,
   not l_i < u): they are the "events" of the reverse-time process and must be
   in their own risk set.  This differs from the (t0, t] convention used for
   the at-risk set and for G, where an entry at exactly t is NOT yet at risk --
   which is the "events, then censorings, then entries" ordering (Geskus p.40).
   The two conventions are both correct and they are not the same; this is
   verified against the direct b/S oracle in qa/crossval_finegray_zzf.do rather
   than argued.
   ------------------------------------------------------------------------ */

/* Left limit H_g(target-) of the entry distribution, one column per level of
   tg_id, evaluated at arbitrary target times.

   H jumps at ENTRY times, which need not be observation (exit) times.  So --
   unlike G -- H cannot be represented by step values stored at the exit times
   and read back with _finegray_G_at_times: that lookup would attribute an
   entry jump to the last exit time below it.  H is therefore built on its own
   grid of distinct entry times and evaluated directly. */
real matrix _finegray_H_at_times(
    real colvector t,
    real colvector t0,
    real colvector tg_id,
    real colvector target_t)
{
    real scalar g, i, j, k, nlev, nl, u, w_j, r_j, acc
    real colvector levels, sel, l_g, t_g, lt, lord, tord
    real matrix out

    levels = uniqrows(tg_id)
    nlev = rows(levels)
    out = J(rows(target_t), nlev, 1)

    for (g = 1; g <= nlev; g++) {
        sel = selectindex(tg_id :== levels[g])
        l_g = t0[sel]
        t_g = t[sel]

        /* distinct entry times, ascending; entries at 0 never bind because
           H(u-) products run over l_j >= u and every target u is > 0 */
        lt = uniqrows(select(l_g, l_g :> 0))
        nl = rows(lt)
        if (nl == 0) continue          /* no delayed entry in this stratum: H == 1 */

        /* w_j and r_j for EVERY distinct entry time in one ascending pass.
           A nested subject-by-entry-time loop is O(n^2) and would destroy the
           linear-scan property this package exists for.  Two pointers instead:

               r(u) = #{ l_i <= u }  -  #{ x_i <= u }

           both of which are monotone in u.  O(n log n) for the sorts, O(n) here.

           NOTE THE `<=' ON THE EXIT SIDE.  Geskus (2011) fixes the tie ordering as
           t_(i) < c_(j) < l_(j) -- events, then censorings, then ENTRIES (p.40) --
           and states the consequence for the at-risk count directly: "Because we
           assume events to come first, individuals with an event at c_(j) are not
           considered to be at risk in the calculation of r(c_(j))" (p.41).  At an
           ENTRY time u the ordering puts BOTH the events and the censorings at u
           ahead of the entries at u, so every subject exiting at exactly u has
           already left and must NOT be counted in r(u).

           This was `x_i < u', which kept those subjects in the risk set and made
           the estimator depend on whether an entry time exactly COINCIDED with an
           exit time.  Nudging 80 tied entries from 5 to 5+1e-7 -- a change that
           cannot move any risk set -- then moved the coefficient by 5.4e-04.
           The continuous-time crossval fixtures cannot see this (tied entry/exit
           times have probability zero there); test_finegray_ties FG-C03 can, and
           did. */
        real colvector ls, ts_, wv, rv, Hleft
        real scalar pl, pt

        ls = sort(l_g, 1)
        ts_ = sort(t_g, 1)
        wv = J(nl, 1, 0)
        rv = J(nl, 1, 0)
        pl = 1
        pt = 1
        for (j = 1; j <= nl; j++) {
            u = lt[j]
            /* entries with l_i <= u */
            while (pl <= rows(ls)) {
                if (ls[pl] <= u) pl++
                else break
            }
            /* exits with x_i <= u (events and censorings at u precede entries) */
            while (pt <= rows(ts_)) {
                if (ts_[pt] <= u) pt++
                else break
            }
            rv[j] = (pl - 1) - (pt - 1)
            wv[j] = 0
        }
        /* w_j = multiplicity of each distinct entry time */
        pl = 1
        for (j = 1; j <= nl; j++) {
            u = lt[j]
            w_j = 0
            while (pl <= rows(ls)) {
                if (ls[pl] == u) {
                    w_j++
                    pl++
                }
                else if (ls[pl] < u) pl++
                else break
            }
            wv[j] = w_j
        }

        /* Reverse-time accumulation: walk entry times DOWNWARD, so that after
           absorbing all l_j >= u we hold H(u-).  Store the running product
           keyed to each entry time. */
        Hleft = J(nl, 1, 1)
        acc = 1
        for (j = nl; j >= 1; j--) {
            r_j = rv[j]
            w_j = wv[j]
            if (r_j > 0 & w_j > 0) acc = acc * (1 - w_j / r_j)
            Hleft[j] = acc        /* = prod over entry times >= lt[j] */
        }

        /* H(target-) = prod over entry times >= target = Hleft[first lt >= target] */
        tord = order(target_t, 1)
        lord = 1
        for (i = 1; i <= rows(tord); i++) {
            /* advance to the first entry time >= this target */
            while (lord <= nl) {
                if (lt[lord] < target_t[tord[i]]) lord++
                else break
            }
            out[tord[i], g] = (lord <= nl ? Hleft[lord] : 1)
        }
    }
    return(out)
}

/* Combined weight A_j(target-) = G_c(target-) * H_u(target-) for each
   CROSS-CLASSIFIED weight stratum j = (c, u), where c indexes the censoring
   strata (strata()) and u the truncation strata (truncstrata()).

   G is estimated within censoring strata and H within truncation strata; a
   subject's weight uses its own cell of each.  jc/ju map each joint level to
   its censoring and truncation level.  When truncstrata() is absent there is a
   single truncation level with H == 1 and this returns exactly _finegray_G_at_times. */
/* Cross-classified weight strata.  A subject's weight stratum is the pair
   (censoring stratum, truncation stratum) = (strata(), truncstrata()).  Only
   OBSERVED combinations become levels, so the joint count is <= nc*nu and is
   what e(N_weight_strata) reports.

   Outputs (by reference):
     jidx  n x 1   joint weight-stratum index of each subject, 1..nj
     jc    nj x 1  censoring-stratum index of each joint level  (column of Gt)
     ju    nj x 1  truncation-stratum index of each joint level (column of Ht)

   With no truncstrata() there is one truncation level, so jidx/jc reduce to the
   censoring-stratum index and ju is all 1s -- the pre-ZZF behaviour exactly. */
void _finegray_joint_setup(
    real colvector byg_id,
    real colvector tg_id,
    real colvector jidx,
    real colvector jc,
    real colvector ju)
{
    real scalar i, j, nj, n
    real colvector lc, lu, ci, ui, key, ukey

    lc = uniqrows(byg_id)
    lu = uniqrows(tg_id)
    ci = _finegray_group_index(byg_id, lc)
    ui = _finegray_group_index(tg_id, lu)

    n = rows(byg_id)
    key = (ci :- 1) :* rows(lu) :+ ui          /* observed (c,u) codes */
    ukey = uniqrows(key)
    nj = rows(ukey)

    jidx = J(n, 1, .)
    for (j = 1; j <= nj; j++) {
        for (i = 1; i <= n; i++) if (key[i] == ukey[j]) jidx[i] = j
    }
    jc = J(nj, 1, .)
    ju = J(nj, 1, .)
    for (j = 1; j <= nj; j++) {
        jc[j] = floor((ukey[j] - 1) / rows(lu)) + 1
        ju[j] = ukey[j] - (jc[j] - 1) * rows(lu)
    }
}

real matrix _finegray_A_at_times(
    real colvector t,
    real colvector G,
    real colvector byg_id,
    real colvector t0,
    real colvector tg_id,
    real colvector jc,
    real colvector ju,
    real colvector target_t)
{
    real scalar j, nj
    real matrix Gt, Ht, out

    Gt = _finegray_G_at_times(t, G, byg_id, target_t)
    Ht = _finegray_H_at_times(t, t0, tg_id, target_t)

    nj = rows(jc)
    out = J(rows(target_t), nj, 1)
    for (j = 1; j <= nj; j++) out[., j] = Gt[., jc[j]] :* Ht[., ju[j]]
    return(out)
}

/* ZZF (2011) equation (7) uses a POOLED time-side stabilizer and a
   stratum-specific subject-side denominator.  The same algebra applies to the
   package's factorized censoring-by-entry extension when its two grouping
   variables differ.  This differs from the historical symmetric
   A_g(t)/A_g(X_i) implementation only when delayed entry and multiple weight
   strata are both present.  Keeping the predicate explicit preserves the
   released no-entry path bit for bit. */
real scalar _finegray_use_pooled_stabilizer(
    real colvector t0,
    real colvector byg_id,
    real colvector tg_id)
{
    real colvector gidx, jc, ju

    if (sum(t0 :> 0) == 0) return(0)
    _finegray_joint_setup(byg_id, tg_id, gidx, jc, ju)
    return(rows(jc) > 1)
}

/* Pooled A(t-) = G_pool(t-) H_pool(t-), evaluated on target_t.  Bellach et
   al. (2020) establish the continuous-time equivalence to ZZF's b(t)/S(t-);
   the package's tie convention is separately regression-tested. */
real colvector _finegray_A_pool_at_times(
    real colvector t,
    real colvector delta,
    real scalar censval,
    real colvector event_type,
    real colvector t0,
    real colvector target_t)
{
    real colvector one, Gp
    real matrix Gpt, Hpt

    one = J(rows(t), 1, 1)
    /* quiet=1 is mandatory, not cosmetic.  This runs inside _finegray_loglik,
       _finegray_score and the Hessian, i.e. once per Newton iteration and once
       per step halving, so a note here reprints the same fit-time fact dozens
       of times.  The pooled A floor is separately surfaced -- and escalated to
       r(459) when a consulted cell is zero -- by _finegray_positivity_check,
       and the censoring KM's own truncation is reported once by the engine. */
    Gp = _finegray_km_censor(t, delta, censval, event_type, one, t0, 1)
    Gpt = _finegray_G_at_times(t, Gp, one, target_t)
    Hpt = _finegray_H_at_times(t, t0, one, target_t)
    return(Gpt[., 1] :* Hpt[., 1])
}

/* Combined-weight diagnostics, computed ONCE after convergence.
   Posts the e() contract's weight-sensitivity scalars:

     _finegray_nwstrata   number of OBSERVED joint (censoring x truncation) strata
     _finegray_minprob    smallest A actually consulted by the scan
     _finegray_maxwt      largest RETAINED subject-by-cause-time weight
     _finegray_nprobwarn  count of consulted A cells below A_FLOOR (1e-10)
     _finegray_nwtwarn    count of retained weights above WT_CEIL (1e6)
     _finegray_warnstrata joint-group codes contributing a flagged cell/weight

   "CONSULTED" is the load-bearing word.  A stratum's A(t) may collapse toward
   zero in a tail where that stratum carries no competing-event mass at all; such
   a cell never enters the likelihood, and counting it would raise an alarm about
   a number the estimator never divides by.  The cells the scan actually uses are:

     numerator    A_g(t_k) for each cause-of-interest event time t_k and each stratum
                  g holding at least one competing-event subject with X_i < t_k
     denominator  A_g(X_i-) for each competing-event subject i that is retained,
                  i.e. that some cause event outlives

   max weight is computed WITHOUT expanding the n x K weight matrix.  A_g is a
   step function of time, so for subject i in stratum g

       max_{t_k > X_i} A_g(t_k) / A_g(X_i-)

   needs only a SUFFIX MAXIMUM of A_g over the cause-event times -- O(n + K) per
   stratum, not O(n*K).  (With no delayed entry H == 1, A = G is nonincreasing and
   every weight is <= 1; under left truncation H rises, so A need not be monotone
   and weights above 1 are legitimate.  That is exactly why this diagnostic exists
   only on the ZZF branch.) */
/* HARD POSITIVITY CHECK for the delayed-entry weights.

   A retained competing-event subject i is divided by its own stratum's
   A_g(X_i-): its numerator is A_g(t-) on the one-stratum branch and
   the pooled A(t-) under equation 7.  If A_g(X_i-) is ZERO, that weight is
   undefined -- and Mata returns
   MISSING for x/0 rather than infinity, so the damage surfaces far downstream as
   "the null log pseudo-likelihood is not finite" / r(430) "convergence not
   achieved".  That message blames the optimizer for what is actually a
   positivity violation in the data, and it names no stratum, so the user has
   nothing to act on.

   How it happens: a subject exits from a competing event so early that almost
   nobody in its weight stratum has entered yet, so H_g -- the entry-distribution
   product limit, estimated WITHIN the stratum -- is still 0 there.  Splitting the
   sample into more weight strata makes this MORE likely, because each H_g is then
   estimated from fewer subjects.  Observed live: n = 8,000 with 50 truncation
   strata gave 39 competing subjects with A(X_i-) exactly 0 (bit-exact, not merely
   small) in a stratum holding 168 subjects -- eight times the >=20-subject support
   boundary.  THE SIZE BOUNDARY DOES NOT PROTECT AGAINST THIS: it bounds how many
   subjects a stratum holds, not whether A stays away from zero where the scan
   actually divides by it.

   We refuse rather than drop the offending subjects: silently dropping them would
   change the estimand without saying so, which is the failure class this package
   treats as worst.

   This CANNOT fire on the no-LT branch, so released behaviour stays bit-identical:
   there H == 1, so A == G, and G(X_i-) > 0 necessarily -- subject i is itself at
   risk throughout [0, X_i), so the censoring KM's at-risk count never reaches 0
   before X_i and no factor of the product can vanish. */
real scalar _finegray_positivity_check(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real colvector G,
    real colvector byg_id,
    real colvector t0,
    real colvector tg_id)
{
    real scalar n, nj, i, j, k, g, npos, ep, cur_time, last_cause
    real colvector is_cause, is_compete, gidx, jc, ju, flagged, Apool
    real colvector row_id, ord, entry_ord, riskn
    real matrix Aden
    string scalar badstr

    n = rows(t)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)

    _finegray_joint_setup(byg_id, tg_id, gidx, jc, ju)
    nj = rows(jc)

    /* Under the equation-7 pooled-stabilizer form, every genuinely at-risk
       subject is divided by its group's A_g(t-), not just retained
       competing-event subjects by A_g(X_i-).  Check exactly those consulted
       denominator cells.  Inactive groups are deliberately ignored: 0/A_g
       never enters the scan. */
    if (_finegray_use_pooled_stabilizer(t0, byg_id, tg_id)) {
        Aden = _finegray_A_at_times(t, G, byg_id, t0, tg_id, jc, ju, t)
        Apool = _finegray_A_pool_at_times(t, delta, censval, event_type, t0, t)
        row_id = (1::n)
        ord = order((t, row_id), (1, 2))
        entry_ord = order((t0, row_id), (1, 2))
        riskn = J(nj, 1, 0)
        flagged = J(nj, 1, 0)
        last_cause = max(select(t, is_cause))
        npos = 0
        ep = 1
        i = 1
        while (i <= n) {
            cur_time = t[ord[i]]
            while (ep <= n) {
                if (t0[entry_ord[ep]] >= cur_time) break
                k = entry_ord[ep]
                if (t[k] >= cur_time) riskn[gidx[k]] = riskn[gidx[k]] + 1
                ep++
            }
            j = i
            while (j <= n) {
                if (t[ord[j]] != cur_time) break
                j++
            }
            for (k = i; k < j; k++) {
                if (!is_cause[ord[k]]) continue
                if (Apool[ord[k]] <= 0) {
                    npos++
                    for (g = 1; g <= nj; g++) {
                        if (riskn[g] > 0) flagged[g] = 1
                    }
                }
                for (g = 1; g <= nj; g++) {
                    if (riskn[g] <= 0) continue
                    if (Aden[ord[k], g] > 0) continue
                    npos++
                    flagged[g] = 1
                }
            }
            for (k = i; k < j; k++) {
                g = gidx[ord[k]]
                riskn[g] = riskn[g] - 1
            }
            i = j
        }
        for (i = 1; i <= n; i++) {
            if (!is_compete[i] | t[i] >= last_cause) continue
            if (Aden[i, gidx[i]] > 0) continue
            npos++
            flagged[gidx[i]] = 1
        }
        badstr = ""
        for (i = 1; i <= nj; i++) {
            if (!flagged[i]) continue
            if (badstr == "") badstr = strofreal(i)
            else              badstr = badstr + " " + strofreal(i)
        }
        st_local("_fg_posstrata", badstr)
        return(npos)
    }

    /* A_g(X_i-) in subject i's OWN joint group: the weight's denominator. */
    Aden = _finegray_G_minus(gidx,
        _finegray_A_at_times(t, G, byg_id, t0, tg_id, jc, ju, t))

    /* EXACTLY zero, not "below A_FLOOR".  Those are different failures and must
       stay different, or one silently eats the other:

         A == 0          the weight is UNDEFINED (Mata gives missing for x/0).
                         Nothing downstream can recover.  Hard r(459).
         0 < A < A_FLOOR the weight is defined but enormous.  The estimate is
                         computable and may be worth inspecting, so this is what
                         e(N_prob_warn)/e(N_weight_warn) are FOR.

       An earlier version of this check errored on `A <= A_FLOOR', which used the
       SAME 1e-10 threshold as the low-A warning -- so the fit aborted before the
       warning could ever fire, and the denominator half of the documented warning
       contract was unreachable dead code.  A warning you cannot reach is not a
       warning; it is a comment. */
    npos = 0
    flagged = J(nj, 1, 0)
    for (i = 1; i <= n; i++) {
        if (!is_compete[i]) continue
        if (Aden[i] > 0) continue
        npos++
        flagged[gidx[i]] = 1
    }

    badstr = ""
    for (i = 1; i <= nj; i++) {
        if (!flagged[i]) continue
        if (badstr == "") badstr = strofreal(i)
        else              badstr = badstr + " " + strofreal(i)
    }
    st_local("_fg_posstrata", badstr)

    return(npos)
}

void _finegray_weight_diag_zzf(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real colvector G,
    real colvector byg_id,
    real colvector t0,
    real colvector tg_id)
{
    real scalar A_FLOOR, WT_CEIL, n, nj, K, i, j, k, g, ep, cur_time
    real scalar minprob, maxwt, nprobwarn, nwtwarn, a, w, p
    real colvector is_cause, is_compete, gidx, jc, ju, row_id, ord, entry_ord
    real colvector et, Pev, Pmax, Aden, riskn, flagged
    real matrix Aev, active
    string scalar warnstr

    A_FLOOR = 1e-10
    WT_CEIL = 1e6
    n = rows(t)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)
    _finegray_joint_setup(byg_id, tg_id, gidx, jc, ju)
    nj = rows(jc)
    row_id = (1::n)
    ord = order((t, row_id), (1, 2))
    entry_ord = order((t0, row_id), (1, 2))

    et = J(0, 1, .)
    for (i = 1; i <= n; i++) {
        if (!is_cause[ord[i]]) continue
        if (rows(et) == 0) et = t[ord[i]]
        else if (t[ord[i]] != et[rows(et)]) et = et \ t[ord[i]]
    }
    K = rows(et)
    if (K == 0) {
        st_matrix("_finegray_nwstrata", nj)
        st_matrix("_finegray_minprob", .)
        st_matrix("_finegray_maxwt", .)
        st_matrix("_finegray_nprobwarn", 0)
        st_matrix("_finegray_nwtwarn", 0)
        st_local("_fg_warnstrata", "")
        return
    }

    Aev = _finegray_A_at_times(t, G, byg_id, t0, tg_id, jc, ju, et)
    Pev = _finegray_A_pool_at_times(t, delta, censval, event_type, t0, et)
    Aden = _finegray_G_minus(gidx,
        _finegray_A_at_times(t, G, byg_id, t0, tg_id, jc, ju, t))
    active = J(K, nj, 0)
    riskn = J(nj, 1, 0)
    ep = 1
    k = 1
    i = 1
    while (i <= n) {
        cur_time = t[ord[i]]
        while (ep <= n) {
            if (t0[entry_ord[ep]] >= cur_time) break
            j = entry_ord[ep]
            if (t[j] >= cur_time) riskn[gidx[j]] = riskn[gidx[j]] + 1
            ep++
        }
        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }
        if (k <= K) {
            if (et[k] == cur_time) {
                active[k, .] = riskn'
                k++
            }
        }
        for (g = i; g < j; g++) {
            riskn[gidx[ord[g]]] = riskn[gidx[ord[g]]] - 1
        }
        i = j
    }

    Pmax = J(K, 1, .)
    Pmax[K] = Pev[K]
    for (k = K - 1; k >= 1; k--) Pmax[k] = max((Pev[k], Pmax[k + 1]))
    minprob = .
    maxwt = .
    nprobwarn = 0
    nwtwarn = 0
    flagged = J(nj, 1, 0)
    for (k = 1; k <= K; k++) {
        p = Pev[k]
        if (p < minprob) minprob = p
        if (p < A_FLOOR) {
            nprobwarn++
            for (g = 1; g <= nj; g++) {
                if (active[k, g] > 0) flagged[g] = 1
            }
        }
        for (g = 1; g <= nj; g++) {
            if (active[k, g] <= 0) continue
            a = Aev[k, g]
            if (a < minprob) minprob = a
            if (a < A_FLOOR) {
                nprobwarn++
                flagged[g] = 1
            }
            if (a <= 0) continue
            w = p / a
            if (maxwt >= . | w > maxwt) maxwt = w
            if (w > WT_CEIL) {
                nwtwarn++
                flagged[g] = 1
            }
        }
    }

    k = 1
    for (i = 1; i <= n; i++) {
        j = ord[i]
        while (k <= K) {
            if (et[k] > t[j]) break
            k++
        }
        if (!is_compete[j] | k > K) continue
        g = gidx[j]
        a = Aden[j]
        if (a < minprob) minprob = a
        if (a < A_FLOOR) {
            nprobwarn++
            flagged[g] = 1
        }
        if (a <= 0) continue
        w = Pmax[k] / a
        if (maxwt >= . | w > maxwt) maxwt = w
        if (w > WT_CEIL) {
            nwtwarn++
            flagged[g] = 1
        }
    }

    warnstr = ""
    for (g = 1; g <= nj; g++) {
        if (!flagged[g]) continue
        warnstr = warnstr + (warnstr == "" ? "" : " ") + strofreal(g)
    }
    st_matrix("_finegray_nwstrata", nj)
    st_matrix("_finegray_minprob", minprob)
    st_matrix("_finegray_maxwt", maxwt)
    st_matrix("_finegray_nprobwarn", nprobwarn)
    st_matrix("_finegray_nwtwarn", nwtwarn)
    st_local("_fg_warnstrata", warnstr)
}

void _finegray_weight_diag(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real colvector G,
    real colvector byg_id,
    real colvector t0,
    real colvector tg_id)
{
    real scalar A_FLOOR, WT_CEIL
    real scalar n, nj, K, i, k, g, r, minprob, maxwt, nprobwarn, nwtwarn, w, a
    real colvector is_cause, is_compete, gidx, jc, ju, et, Aden, flagged
    real colvector ord, row_id, cmin
    real matrix Aev, SUF
    string scalar warnstr

    if (_finegray_use_pooled_stabilizer(t0, byg_id, tg_id)) {
        _finegray_weight_diag_zzf(t, delta, cause, censval, event_type,
            G, byg_id, t0, tg_id)
        return
    }

    A_FLOOR = 1e-10
    WT_CEIL = 1e6

    n = rows(t)
    is_cause   = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)

    _finegray_joint_setup(byg_id, tg_id, gidx, jc, ju)
    nj = rows(jc)

    /* Cause-event times, ascending and unique. */
    row_id = (1::n)
    ord = order((t, row_id), (1, 2))
    et = J(0, 1, .)
    for (i = 1; i <= n; i++) {
        r = ord[i]
        if (!is_cause[r]) continue
        /* Mata's | does NOT short-circuit, so a combined test of the form
           "rows(et) == 0 | t[r] != et[rows(et)]" still evaluates et[0] on the
           first event and aborts with 3301.  Keep the bound test separate. */
        if (rows(et) == 0) {
            et = t[r]
            continue
        }
        if (t[r] != et[rows(et)]) et = et \ t[r]
    }
    K = rows(et)

    minprob   = .
    maxwt     = .
    nprobwarn = 0
    nwtwarn   = 0
    flagged   = J(nj, 1, 0)

    if (K == 0) {
        st_matrix("_finegray_nwstrata", nj)
        st_matrix("_finegray_minprob", .)
        st_matrix("_finegray_maxwt", .)
        st_matrix("_finegray_nprobwarn", 0)
        st_matrix("_finegray_nwtwarn", 0)
        st_local("_fg_warnstrata", "")
        return
    }

    /* A at the cause-event times (K x nj) and each subject's own denominator. */
    Aev  = _finegray_A_at_times(t, G, byg_id, t0, tg_id, jc, ju, et)
    Aden = _finegray_G_minus(gidx, _finegray_A_at_times(t, G, byg_id, t0, tg_id,
                                                        jc, ju, t))

    /* cmin[g] = the EARLIEST competing exit in stratum g (missing if g holds no
       competing-event subject at all).  A numerator cell A_g(t_k) is consulted by
       the scan only once some competing subject in g has already exited, because
       until then the backward accumulator for g is exactly zero and Gt[., g] is
       multiplied by nothing.  Scanning every k instead would let a stratum whose A
       collapses in a tail it carries no competing mass into raise an alarm about a
       number the estimator never divides by. */
    cmin = J(nj, 1, .)
    for (i = 1; i <= n; i++) {
        if (!is_compete[i]) continue
        g = gidx[i]
        /* Missing is the LARGEST value in Mata, so the initial . needs no special
           case: the first competing exit in g always compares less than it. */
        if (t[i] < cmin[g]) cmin[g] = t[i]
    }

    /* Suffix maxima, ONCE per stratum: SUF[k, g] = max A_g over et[k..K].
       Each retained subject then reads its largest possible weight in O(1).
       Doing this per subject instead would be O(n*K) -- the very expansion the
       unexpanded scan exists to avoid. */
    SUF = J(K, nj, .)
    for (g = 1; g <= nj; g++) {
        if (cmin[g] >= .) continue          /* no competing mass: nothing consulted */

        SUF[K, g] = Aev[K, g]
        for (k = K - 1; k >= 1; k--) SUF[k, g] = max((Aev[k, g], SUF[k + 1, g]))

        /* Numerator cells consulted in stratum g: event times strictly after the
           earliest competing exit in g.  This restriction is the code, not just
           the comment -- an unrestricted k = 1..K loop counts cells the scan
           never reaches. */
        for (k = 1; k <= K; k++) {
            if (et[k] <= cmin[g]) continue
            a = Aev[k, g]
            if (a >= .) continue
            if (a < minprob) minprob = a
            if (a < A_FLOOR) {
                nprobwarn++
                flagged[g] = 1
            }
        }
    }

    /* Denominators and retained weights.  Walk subjects in ASCENDING time so the
       pointer k -- the first cause-event time strictly after the current exit --
       only ever moves forward: O(n + K), not O(n*K). */
    k = 1
    for (i = 1; i <= n; i++) {
        r = ord[i]

        /* Advance to the first cause-event time strictly after this exit.  Mata's
           & does NOT short-circuit, so the bound test must be its own statement:
           a combined "k <= K & et[k] <= t[r]" evaluates et[K+1] and aborts. */
        while (k <= K) {
            if (et[k] > t[r]) break
            k++
        }

        if (!is_compete[r]) continue

        /* No cause event outlives this subject: it is never weighted into any
           risk set, so its A(X_i-) is not consulted and must not raise an alarm. */
        if (k > K) continue

        g = gidx[r]
        a = Aden[r]
        if (a >= .) continue

        if (a < minprob) minprob = a
        if (a < A_FLOOR) {
            nprobwarn++
            flagged[g] = 1
        }
        if (a <= 0) continue

        w = SUF[k, g] / a
        if (maxwt >= . | w > maxwt) maxwt = w
        if (w > WT_CEIL) {
            nwtwarn++
            flagged[g] = 1
        }
    }

    warnstr = ""
    for (g = 1; g <= nj; g++) {
        if (!flagged[g]) continue
        warnstr = warnstr + (warnstr == "" ? "" : " ") + strofreal(g)
    }

    st_matrix("_finegray_nwstrata", nj)
    st_matrix("_finegray_minprob", minprob)
    st_matrix("_finegray_maxwt", maxwt)
    st_matrix("_finegray_nprobwarn", nprobwarn)
    st_matrix("_finegray_nwtwarn", nwtwarn)

    /* The flagged group codes are a STRING, so they cannot ride back in a matrix.
       st_local writes into the calling ado's scope.  st_global would not work
       here: a Stata macro of that kind may not begin with an underscore (the
       assignment is rejected with r(198)), and any name that IS accepted could
       collide with one the user already set. */
    st_local("_fg_warnstrata", warnstr)
}

/* Canonical stratified ZZF equation (7): pooled A(t) stabilizer,
   stratum-specific A_g(.) denominators.  Risk-set sums are maintained on the
   denominator scale; the pooled factor cancels from S1/S0 but remains as the
   outer cause-event weight in the estimating equation. */
real scalar _finegray_loglik_zzf_strat(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real matrix Z,
    real colvector beta,
    real colvector G,
    real colvector byg_id,
    real colvector t0,
    real colvector tg_id)
{
    real colvector row_id, eta, expeta, is_cause, is_compete, ord, entry_ord
    real colvector gidx, Gminus, jc, ju, Apool, riskn
    real scalar n, i, j, k, idx, cur_time, ep, g, ng, coreS0, ew, ll
    real rowvector risk0, bwd0
    real matrix Aden

    n = rows(t)
    eta = Z * beta
    expeta = exp(eta)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)
    row_id = (1::n)
    ord = order((t, row_id), (1, 2))
    entry_ord = order((t0, row_id), (1, 2))
    _finegray_joint_setup(byg_id, tg_id, gidx, jc, ju)
    ng = rows(jc)
    Aden = _finegray_A_at_times(t, G, byg_id, t0, tg_id, jc, ju, t)
    Gminus = _finegray_G_minus(gidx, Aden)
    Apool = _finegray_A_pool_at_times(t, delta, censval, event_type, t0, t)

    risk0 = J(1, ng, 0)
    /* Activity is combinatorial, not numerical.  Entry and exit traverse
       different orders, so a weighted sum can retain a tiny positive residue
       after its last subject exits; riskn prevents that empty stratum from
       consulting A_g(t). */
    riskn = J(ng, 1, 0)
    bwd0 = J(1, ng, 0)
    ep = 1
    ll = 0
    i = 1
    while (i <= n) {
        cur_time = t[ord[i]]
        while (ep <= n) {
            if (t0[entry_ord[ep]] >= cur_time) break
            idx = entry_ord[ep]
            if (t[idx] >= cur_time) {
                g = gidx[idx]
                risk0[g] = risk0[g] + expeta[idx]
                riskn[g] = riskn[g] + 1
            }
            ep++
        }
        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_cause[idx]) {
                coreS0 = bwd0 * J(ng, 1, 1)
                for (g = 1; g <= ng; g++) {
                    if (riskn[g] > 0) coreS0 = coreS0 + risk0[g] / Aden[idx, g]
                }
                ew = Apool[idx] / Aden[idx, gidx[idx]]
                ll = ll + ew * (eta[idx] - log(Apool[idx] * coreS0))
            }
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_compete[idx]) {
                g = gidx[idx]
                bwd0[g] = bwd0[g] + expeta[idx] / Gminus[idx]
            }
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            g = gidx[idx]
            risk0[g] = risk0[g] - expeta[idx]
            riskn[g] = riskn[g] - 1
        }
        i = j
    }
    return(ll)
}

void _finegray_score_info_zzf_strat(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real matrix Z,
    real colvector beta,
    real colvector G,
    real colvector byg_id,
    real colvector score,
    real matrix info,
    real colvector t0,
    real colvector tg_id)
{
    real colvector row_id, eta, expeta, is_cause, is_compete, ord, entry_ord
    real colvector gidx, Gminus, jc, ju, Apool, riskn
    real scalar n, p, i, j, k, idx, cur_time, ep, g, ng, coreS0, ew
    real rowvector risk0, bwd0, coreS1, zbar
    real matrix risk1, bwd1, risk2, bwd2, coreS2, Aden

    n = rows(t)
    p = cols(Z)
    eta = Z * beta
    expeta = exp(eta)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)
    row_id = (1::n)
    ord = order((t, row_id), (1, 2))
    entry_ord = order((t0, row_id), (1, 2))
    _finegray_joint_setup(byg_id, tg_id, gidx, jc, ju)
    ng = rows(jc)
    Aden = _finegray_A_at_times(t, G, byg_id, t0, tg_id, jc, ju, t)
    Gminus = _finegray_G_minus(gidx, Aden)
    Apool = _finegray_A_pool_at_times(t, delta, censval, event_type, t0, t)

    risk0 = J(1, ng, 0)
    riskn = J(ng, 1, 0)
    risk1 = J(ng, p, 0)
    risk2 = J(ng, p * p, 0)
    bwd0 = J(1, ng, 0)
    bwd1 = J(ng, p, 0)
    bwd2 = J(ng, p * p, 0)
    score = J(p, 1, 0)
    info = J(p, p, 0)
    ep = 1
    i = 1
    while (i <= n) {
        cur_time = t[ord[i]]
        while (ep <= n) {
            if (t0[entry_ord[ep]] >= cur_time) break
            idx = entry_ord[ep]
            if (t[idx] >= cur_time) {
                g = gidx[idx]
                risk0[g] = risk0[g] + expeta[idx]
                riskn[g] = riskn[g] + 1
                risk1[g, .] = risk1[g, .] + expeta[idx] * Z[idx, .]
                risk2[g, .] = risk2[g, .] +
                    vec(expeta[idx] * (Z[idx, .]' * Z[idx, .]))'
            }
            ep++
        }
        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_cause[idx]) {
                coreS0 = 0
                coreS1 = J(1, p, 0)
                coreS2 = J(p, p, 0)
                for (g = 1; g <= ng; g++) {
                    coreS0 = coreS0 + bwd0[g]
                    coreS1 = coreS1 + bwd1[g, .]
                    coreS2 = coreS2 + rowshape(bwd2[g, .], p)
                    if (riskn[g] > 0) {
                        coreS0 = coreS0 + risk0[g] / Aden[idx, g]
                        coreS1 = coreS1 + risk1[g, .] / Aden[idx, g]
                        coreS2 = coreS2 + rowshape(risk2[g, .], p) / Aden[idx, g]
                    }
                }
                zbar = coreS1 / coreS0
                ew = Apool[idx] / Aden[idx, gidx[idx]]
                score = score + ew * (Z[idx, .] - zbar)'
                info = info + ew * (coreS2 / coreS0 - zbar' * zbar)
            }
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_compete[idx]) {
                g = gidx[idx]
                bwd0[g] = bwd0[g] + expeta[idx] / Gminus[idx]
                bwd1[g, .] = bwd1[g, .] + expeta[idx] / Gminus[idx] * Z[idx, .]
                bwd2[g, .] = bwd2[g, .] +
                    vec(expeta[idx] / Gminus[idx] * (Z[idx, .]' * Z[idx, .]))'
            }
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            g = gidx[idx]
            risk0[g] = risk0[g] - expeta[idx]
            riskn[g] = riskn[g] - 1
            risk1[g, .] = risk1[g, .] - expeta[idx] * Z[idx, .]
            risk2[g, .] = risk2[g, .] -
                vec(expeta[idx] * (Z[idx, .]' * Z[idx, .]))'
        }
        i = j
    }
}

real matrix _finegray_scores_zzf_strat(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real matrix Z,
    real colvector beta,
    real colvector G,
    real colvector byg_id,
    real colvector t0,
    real colvector tg_id)
{
    real colvector row_id, eta, expeta, is_cause, is_compete, ord, entry_ord
    real colvector gidx, Gminus, jc, ju, Apool, entry_rinv, exit_rinv, exit_cinv
    real colvector riskn
    real scalar n, p, i, j, k, idx, cur_time, ep, g, ng, coreS0, ew, run_cinv
    real rowvector risk0, bwd0, coreS1, zbar, run_cz
    real matrix risk1, bwd1, Aden, scores, run_rz, entry_rz, exit_rz, exit_cz
    real rowvector run_rinv

    n = rows(t)
    p = cols(Z)
    eta = Z * beta
    expeta = exp(eta)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)
    row_id = (1::n)
    ord = order((t, row_id), (1, 2))
    entry_ord = order((t0, row_id), (1, 2))
    _finegray_joint_setup(byg_id, tg_id, gidx, jc, ju)
    ng = rows(jc)
    Aden = _finegray_A_at_times(t, G, byg_id, t0, tg_id, jc, ju, t)
    Gminus = _finegray_G_minus(gidx, Aden)
    Apool = _finegray_A_pool_at_times(t, delta, censval, event_type, t0, t)

    risk0 = J(1, ng, 0)
    riskn = J(ng, 1, 0)
    risk1 = J(ng, p, 0)
    bwd0 = J(1, ng, 0)
    bwd1 = J(ng, p, 0)
    scores = J(n, p, 0)
    run_rinv = J(1, ng, 0)
    run_rz = J(ng, p, 0)
    entry_rinv = J(n, 1, 0)
    entry_rz = J(n, p, 0)
    exit_rinv = J(n, 1, 0)
    exit_rz = J(n, p, 0)
    run_cinv = 0
    run_cz = J(1, p, 0)
    exit_cinv = J(n, 1, 0)
    exit_cz = J(n, p, 0)
    ep = 1
    i = 1
    while (i <= n) {
        cur_time = t[ord[i]]
        while (ep <= n) {
            if (t0[entry_ord[ep]] >= cur_time) break
            idx = entry_ord[ep]
            if (t[idx] >= cur_time) {
                g = gidx[idx]
                risk0[g] = risk0[g] + expeta[idx]
                riskn[g] = riskn[g] + 1
                risk1[g, .] = risk1[g, .] + expeta[idx] * Z[idx, .]
                entry_rinv[idx] = run_rinv[g]
                entry_rz[idx, .] = run_rz[g, .]
            }
            ep++
        }
        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_cause[idx]) {
                coreS0 = 0
                coreS1 = J(1, p, 0)
                for (g = 1; g <= ng; g++) {
                    coreS0 = coreS0 + bwd0[g]
                    coreS1 = coreS1 + bwd1[g, .]
                    if (riskn[g] > 0) {
                        coreS0 = coreS0 + risk0[g] / Aden[idx, g]
                        coreS1 = coreS1 + risk1[g, .] / Aden[idx, g]
                    }
                }
                zbar = coreS1 / coreS0
                ew = Apool[idx] / Aden[idx, gidx[idx]]
                scores[idx, .] = scores[idx, .] + ew * (Z[idx, .] - zbar)
                run_cinv = run_cinv + ew / coreS0
                run_cz = run_cz + ew * zbar / coreS0
                for (g = 1; g <= ng; g++) {
                    /* A stratum with no natural at-risk subject contributes
                       exactly zero here.  Its A_g(t) may also be zero: touching
                       1/A_g(t) would manufacture missing score rows from a cell
                       the estimating equation never consults. */
                    if (riskn[g] <= 0) continue
                    run_rinv[g] = run_rinv[g] + ew / (Aden[idx, g] * coreS0)
                    run_rz[g, .] = run_rz[g, .] +
                        ew * zbar / (Aden[idx, g] * coreS0)
                }
            }
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            g = gidx[idx]
            exit_rinv[idx] = run_rinv[g]
            exit_rz[idx, .] = run_rz[g, .]
            exit_cinv[idx] = run_cinv
            exit_cz[idx, .] = run_cz
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_compete[idx]) {
                g = gidx[idx]
                bwd0[g] = bwd0[g] + expeta[idx] / Gminus[idx]
                bwd1[g, .] = bwd1[g, .] + expeta[idx] / Gminus[idx] * Z[idx, .]
            }
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            g = gidx[idx]
            risk0[g] = risk0[g] - expeta[idx]
            riskn[g] = riskn[g] - 1
            risk1[g, .] = risk1[g, .] - expeta[idx] * Z[idx, .]
        }
        i = j
    }

    for (i = 1; i <= n; i++) {
        scores[i, .] = scores[i, .] - expeta[i] *
            (Z[i, .] * (exit_rinv[i] - entry_rinv[i]) -
             (exit_rz[i, .] - entry_rz[i, .]))
        if (is_compete[i]) {
            scores[i, .] = scores[i, .] - expeta[i] / Gminus[i] *
                (Z[i, .] * (run_cinv - exit_cinv[i]) -
                 (run_cz - exit_cz[i, .]))
        }
    }
    return(scores)
}

/* Log pseudo-likelihood via incremental risk-set scan with Breslow ties.
   Supports left truncation via entry-time pointer. */
real scalar _finegray_loglik(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real matrix Z,
    real colvector beta,
    real colvector G,
    real colvector byg_id,
    real colvector t0,
    real colvector tg_id)
{
    real colvector row_id
    real scalar n, p, i, j, k, ll, idx, cur_time, g, ng
    real scalar risk_S0, ep
    real colvector eta, expeta, is_cause, is_compete, ord, entry_ord
    real colvector levels, gidx, Gminus, jc, ju
    real rowvector raw_bwd
    real matrix Gt

    if (_finegray_use_pooled_stabilizer(t0, byg_id, tg_id)) {
        return(_finegray_loglik_zzf_strat(t, delta, cause, censval,
            event_type, Z, beta, G, byg_id, t0, tg_id))
    }

    n = rows(t)
    p = cols(Z)

    eta = Z * beta
    expeta = exp(eta)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)

    /* Deterministic tie-break by row index.  Mata's order() resolves ties
       using Stata's sort seed, which ADVANCES on every sort, so a tied key
       (every t0 == 0 when there is no delayed entry) yields a different
       permutation on each call -- and the risk-set scan then accumulates in
       a different floating-point order.  Without this the same command on
       the same data is not bit-reproducible. */
    row_id = (1::n)
    ord = order((t, row_id), (1, 2))
    entry_ord = order((t0, row_id), (1, 2))
    levels = uniqrows(byg_id)
    /* ZZF: the weight is now A = G(t-)H(t-) on CROSS-CLASSIFIED strata.  With no
       delayed entry H == 1 and this is bit-identical to the former G-only path. */
    _finegray_joint_setup(byg_id, tg_id, gidx, jc, ju)
    ng = rows(jc)
    Gt = _finegray_A_at_times(t, G, byg_id, t0, tg_id, jc, ju, t)
    Gminus = _finegray_G_minus(gidx, Gt)

    /* Incremental risk-set tracking */
    risk_S0 = 0
    ep = 1
    ll = 0
    raw_bwd = J(1, ng, 0)
    i = 1

    while (i <= n) {
        cur_time = t[ord[i]]

        /* Add entries: subjects with t0 < cur_time AND t >= cur_time */
        while (ep <= n) {
            if (t0[entry_ord[ep]] >= cur_time) break
            if (t[entry_ord[ep]] >= cur_time) {
                risk_S0 = risk_S0 + expeta[entry_ord[ep]]
            }
            ep++
        }

        /* Find end of this time group */
        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }

        /* Process all cause events at this time (Breslow) */
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_cause[idx]) {
                ll = ll + eta[idx] - log(risk_S0 + Gt[idx, .] * raw_bwd')
            }
        }

        /* AFTER processing cause events, add competing events to backward */
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_compete[idx]) {
                g = gidx[idx]
                raw_bwd[g] = raw_bwd[g] + expeta[idx] / Gminus[idx]
            }
        }

        /* Remove exiting subjects from risk set */
        for (k = i; k < j; k++) {
            risk_S0 = risk_S0 - expeta[ord[k]]
        }

        i = j
    }

    return(ll)
}

/* Score vector and observed information via incremental risk-set scan.
   Supports left truncation. */
void _finegray_score_info(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real matrix Z,
    real colvector beta,
    real colvector G,
    real colvector byg_id,
    real colvector score,
    real matrix info,
    real colvector t0,
    real colvector tg_id)
{
    real colvector row_id
    real scalar n, p, i, j, k, idx, S0_total, cur_time
    real scalar risk_S0, ep, g, ng
    real colvector eta, expeta, is_cause, is_compete, ord, entry_ord
    real colvector levels, gidx, Gminus, jc, ju
    real matrix bwd_s1_raw, bwd_s2_raw, S2_total, risk_S2, Gt
    real rowvector bwd_s0_raw, S1_total, z_bar, risk_S1

    if (_finegray_use_pooled_stabilizer(t0, byg_id, tg_id)) {
        _finegray_score_info_zzf_strat(t, delta, cause, censval,
            event_type, Z, beta, G, byg_id, score, info, t0, tg_id)
        return
    }

    n = rows(t)
    p = cols(Z)

    eta = Z * beta
    expeta = exp(eta)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)

    /* Deterministic tie-break by row index.  Mata's order() resolves ties
       using Stata's sort seed, which ADVANCES on every sort, so a tied key
       (every t0 == 0 when there is no delayed entry) yields a different
       permutation on each call -- and the risk-set scan then accumulates in
       a different floating-point order.  Without this the same command on
       the same data is not bit-reproducible. */
    row_id = (1::n)
    ord = order((t, row_id), (1, 2))
    entry_ord = order((t0, row_id), (1, 2))
    levels = uniqrows(byg_id)
    /* ZZF: the weight is now A = G(t-)H(t-) on CROSS-CLASSIFIED strata.  With no
       delayed entry H == 1 and this is bit-identical to the former G-only path. */
    _finegray_joint_setup(byg_id, tg_id, gidx, jc, ju)
    ng = rows(jc)
    Gt = _finegray_A_at_times(t, G, byg_id, t0, tg_id, jc, ju, t)
    Gminus = _finegray_G_minus(gidx, Gt)

    /* Incremental risk-set sums */
    risk_S0 = 0
    risk_S1 = J(1, p, 0)
    risk_S2 = J(p, p, 0)
    ep = 1

    score = J(p, 1, 0)
    info = J(p, p, 0)
    bwd_s0_raw = J(1, ng, 0)
    bwd_s1_raw = J(ng, p, 0)
    bwd_s2_raw = J(ng, p * p, 0)

    i = 1
    while (i <= n) {
        cur_time = t[ord[i]]

        /* Add entries: (t0, t] means t0 < cur_time */
        while (ep <= n) {
            if (t0[entry_ord[ep]] >= cur_time) break
            idx = entry_ord[ep]
            if (t[idx] >= cur_time) {
                risk_S0 = risk_S0 + expeta[idx]
                risk_S1 = risk_S1 + expeta[idx] * Z[idx, .]
                risk_S2 = risk_S2 + expeta[idx] * (Z[idx, .]' * Z[idx, .])
            }
            ep++
        }

        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }

        /* Process cause events at this time */
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_cause[idx]) {
                S0_total = risk_S0 + Gt[idx, .] * bwd_s0_raw'
                S1_total = risk_S1 + Gt[idx, .] * bwd_s1_raw
                S2_total = risk_S2
                for (g = 1; g <= ng; g++) {
                    S2_total = S2_total + Gt[idx, g] *
                        rowshape(bwd_s2_raw[g, .], p)
                }

                z_bar = S1_total / S0_total

                score = score + (Z[idx, .] - z_bar)'
                info = info + S2_total / S0_total - z_bar' * z_bar
            }
        }

        /* Add competing events to backward */
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_compete[idx]) {
                g = gidx[idx]
                bwd_s0_raw[g] = bwd_s0_raw[g] + expeta[idx] / Gminus[idx]
                bwd_s1_raw[g, .] = bwd_s1_raw[g, .] +
                    expeta[idx] / Gminus[idx] * Z[idx, .]
                bwd_s2_raw[g, .] = bwd_s2_raw[g, .] +
                    vec(expeta[idx] / Gminus[idx] *
                    (Z[idx, .]' * Z[idx, .]))'
            }
        }

        /* Remove exiting subjects */
        for (k = i; k < j; k++) {
            idx = ord[k]
            risk_S0 = risk_S0 - expeta[idx]
            risk_S1 = risk_S1 - expeta[idx] * Z[idx, .]
            risk_S2 = risk_S2 - expeta[idx] * (Z[idx, .]' * Z[idx, .])
        }

        i = j
    }
}

/* Per-subject score (efficient-score) residuals for the Fine-Gray model,
   including the IPCW at-risk correction for competing-event subjects.
   Returns an n x p matrix whose rows are the U_i; sum_i U_i U_i' is the meat
   of the sandwich.  Extracted so both the robust variance and the CIF
   influence-function variance use one definition (coefficient SEs unchanged).

   Left truncation: subject i's natural at-risk window is [t0_i, T_i], so the
   at-risk contribution sums only over cause-event times inside that window.
   The cumulative sums are captured twice per subject: at entry (events with
   T_m < t0_i, recorded when the entry pointer admits the subject) and at exit
   (events with T_m <= T_i); the difference is the window sum. */
real matrix _finegray_score_residuals(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real matrix Z,
    real colvector beta,
    real colvector G,
    real colvector byg_id,
    real colvector t0,
    real colvector tg_id)
{
    real colvector row_id
    real scalar n, p, i, j, k, idx, running_invS0
    real scalar S0_t, cur_time, risk_S0, ep, g, ng
    real colvector eta, expeta, is_cause, is_compete, ord, entry_ord
    real colvector cum_invS0, cum_ginvS0, entry_invS0, levels, gidx, Gminus, jc, ju
    real matrix scores, cum_zbars, cum_gzbars, entry_zbars, Gt
    real matrix bwd_s1_raw, running_gzbars
    real rowvector bwd_s0_raw, running_zbar_sum, z_bar_t, S1_t, risk_S1
    real rowvector running_ginvS0, total_ginvS0, total_gzbars

    if (_finegray_use_pooled_stabilizer(t0, byg_id, tg_id)) {
        return(_finegray_scores_zzf_strat(t, delta, cause,
            censval, event_type, Z, beta, G, byg_id, t0, tg_id))
    }

    n = rows(t)
    p = cols(Z)

    eta = Z * beta
    expeta = exp(eta)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)

    /* Deterministic tie-break by row index.  Mata's order() resolves ties
       using Stata's sort seed, which ADVANCES on every sort, so a tied key
       (every t0 == 0 when there is no delayed entry) yields a different
       permutation on each call -- and the risk-set scan then accumulates in
       a different floating-point order.  Without this the same command on
       the same data is not bit-reproducible. */
    row_id = (1::n)
    ord = order((t, row_id), (1, 2))
    entry_ord = order((t0, row_id), (1, 2))
    levels = uniqrows(byg_id)
    /* ZZF: the weight is now A = G(t-)H(t-) on CROSS-CLASSIFIED strata.  With no
       delayed entry H == 1 and this is bit-identical to the former G-only path. */
    _finegray_joint_setup(byg_id, tg_id, gidx, jc, ju)
    ng = rows(jc)
    Gt = _finegray_A_at_times(t, G, byg_id, t0, tg_id, jc, ju, t)
    Gminus = _finegray_G_minus(gidx, Gt)

    risk_S0 = 0
    risk_S1 = J(1, p, 0)
    ep = 1

    scores = J(n, p, 0)
    bwd_s0_raw = J(1, ng, 0)
    bwd_s1_raw = J(ng, p, 0)
    cum_zbars = J(n, p, 0)
    cum_invS0 = J(n, 1, 0)
    entry_invS0 = J(n, 1, 0)
    entry_zbars = J(n, p, 0)
    running_invS0 = 0
    running_zbar_sum = J(1, p, 0)

    cum_ginvS0 = J(n, 1, 0)
    cum_gzbars = J(n, p, 0)
    running_ginvS0 = J(1, ng, 0)
    running_gzbars = J(ng, p, 0)

    i = 1
    while (i <= n) {
        cur_time = t[ord[i]]

        while (ep <= n) {
            if (t0[entry_ord[ep]] >= cur_time) break
            idx = entry_ord[ep]
            if (t[idx] >= cur_time) {
                risk_S0 = risk_S0 + expeta[idx]
                risk_S1 = risk_S1 + expeta[idx] * Z[idx, .]
                /* cur_time is the first observation time strictly after
                   t0[idx], so the running sums at admission are exactly the
                   sums over cause-event times T_m <= t0[idx] -- the events the
                   subject's (t0, t] window must EXCLUDE. */
                entry_invS0[idx] = running_invS0
                entry_zbars[idx, .] = running_zbar_sum
            }
            ep++
        }

        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }

        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_cause[idx]) {
                S0_t = risk_S0 + Gt[idx, .] * bwd_s0_raw'
                S1_t = risk_S1 + Gt[idx, .] * bwd_s1_raw
                z_bar_t = S1_t / S0_t

                scores[idx, .] = Z[idx, .] - z_bar_t
                running_invS0 = running_invS0 + 1 / S0_t
                running_zbar_sum = running_zbar_sum + z_bar_t / S0_t
                for (g = 1; g <= ng; g++) {
                    running_ginvS0[g] = running_ginvS0[g] +
                        Gt[idx, g] / S0_t
                    running_gzbars[g, .] = running_gzbars[g, .] +
                        Gt[idx, g] * z_bar_t / S0_t
                }
            }
        }

        for (k = i; k < j; k++) {
            idx = ord[k]
            cum_invS0[idx] = running_invS0
            cum_zbars[idx, .] = running_zbar_sum
            g = gidx[idx]
            cum_ginvS0[idx] = running_ginvS0[g]
            cum_gzbars[idx, .] = running_gzbars[g, .]
        }

        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_compete[idx]) {
                g = gidx[idx]
                bwd_s0_raw[g] = bwd_s0_raw[g] + expeta[idx] / Gminus[idx]
                bwd_s1_raw[g, .] = bwd_s1_raw[g, .] +
                    expeta[idx] / Gminus[idx] * Z[idx, .]
            }
        }

        for (k = i; k < j; k++) {
            idx = ord[k]
            risk_S0 = risk_S0 - expeta[idx]
            risk_S1 = risk_S1 - expeta[idx] * Z[idx, .]
        }

        i = j
    }

    /* Subtract the at-risk contribution for all subjects, restricted to each
       subject's own risk window (t0_i, T_i] (entry-to-exit difference) */
    for (i = 1; i <= n; i++) {
        scores[i, .] = scores[i, .] - expeta[i] *
            (Z[i, .] * (cum_invS0[i] - entry_invS0[i]) -
             (cum_zbars[i, .] - entry_zbars[i, .]))
    }

    /* IPCW at-risk correction for competing-event subjects */
    total_ginvS0 = running_ginvS0
    for (i = 1; i <= n; i++) {
        if (is_compete[i]) {
            g = gidx[i]
            total_gzbars = running_gzbars[g, .]
            scores[i, .] = scores[i, .] -
                (expeta[i] / Gminus[i]) *
                (Z[i, .] * (total_ginvS0[g] - cum_ginvS0[i]) -
                 (total_gzbars - cum_gzbars[i, .]))
        }
    }

    return(scores)
}

/* ------------------------------------------------------------------------
   psi_i -- Fine & Gray (1999) eq. (7)-(8), p.500.

   eta_i (above) is the score's i.i.d. contribution treating the censoring
   survivor G as KNOWN.  psi_i is the SECOND term: the contribution from
   having ESTIMATED G by Kaplan-Meier.  The full sandwich meat is
   sum_i (eta_i + psi_i)^{(x)2}; using eta alone understates or overstates
   the variance by about a percent (measured: -1.28% to +1.42% across the
   qa/data/ parity fixtures; the covariances move more than the variances).
   The range is printed by qa/crossval_nuisance_r.R -- do not quote it from
   memory, and do not confuse it with crskdiag's psi effect, which is a
   different and defective quantity.  See FG 1999 sec. 4, pp.500-501.

       psi_i = integral_0^{X_i} { q_g(u) / Y_g(u) } dMc_i(u)
             = 1{eps_i = 0} q_g(X_i)/Y_g(X_i)
               - sum_{u <= X_i} dNc_g(u) q_g(u) / Y_g(u)^2

   with g = i's censoring stratum, Y_g(u) = #{j in g : X_j >= u}, and

       q_g(t) = sum_{s >= t, s an event time FROM GROUP g} d_s^g
                  [ S1_2^g(s,t) - zbar(s) S0_2^g(s,t) ] / S0(s)
       S0_2^g(s,t) = sum_{X_j < t, eps_j = 2, g(j) = g}
                        exp(eta_j) Ghat_g(s-)/Ghat_g(X_j-)

   THREE THINGS THAT ARE EASY TO GET WRONG, each verified against
   cmprsk's Fortran crrvv (written by R.J. Gray, FG's second author) and
   proven by fixtures in qa/:

   1. BOTH sums in q are group-restricted.  crr.f:379 accumulates into
      qu(., icg(j1)) -- the group of the EVENT subject -- so a cause-1 event
      in group A contributes only to q_A.  S0(s) and zbar(s) stay GLOBAL.
      Restricting only the inner competing-event sum passes every
      single-stratum fixture and fails at ~1e-3 with strata().
   2. TIE MULTIPLICITY.  A time carrying d tied cause-1 events contributes
      d times (Breslow); crr.f loops over event SUBJECTS, not distinct event
      times.  Dropping it is invisible without tied events and >100% wrong
      with them.
   3. Ghat is the LEFT limit Ghat(t-) throughout, which is what
      _finegray_G_at_times already returns (it advances on strict <).

   RIGHT CENSORING ONLY.  Li/Scheike/Zhang (2015) and FG (1999) eq. (7)-(8)
   are both derived without entry times; the delayed-entry analogue is the
   ZZF (2011) Appendix B term, which we do not hold.  The caller must not
   reach here with t0 > 0; this function errors rather than returning a
   quantity whose derivation does not cover the data.

   Complexity is O(n * p * ng), not O(n^2): q factorises as
   q_g(t) = B1_g(t) C0_g(t) - B0_g(t) C1_g(t), where B is a forward running
   sum over competing events and C a reverse running sum over event times.
   ------------------------------------------------------------------------ */
real matrix _finegray_psi_residuals(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real matrix Z,
    real colvector beta,
    real colvector G,
    real colvector byg_id,
    real colvector t0)
{
    real scalar n, p, ng, i, j, k, g, idx, it, nt, S0_t, cur_time
    real scalar risk_S0, cS0, dNc_g
    real colvector row_id, ord, gidx, levels, eta, expeta
    real colvector is_cause, is_compete, is_cens, Gminus, Yg, S0arr, bwd_s0
    real matrix Gt, psi, Zbar, Dg, Gg, C0, C1, cumL, bwd_s1, qg
    real rowvector risk_S1, S1_t, z_bar_t, c1row, qrow

    n = rows(t)
    p = cols(Z)

    if (colmax(t0) > 0) {
        errprintf("finegray: psi (FG 1999 eq. 7-8) is derived for right ")
        errprintf("censoring only;\n")
        errprintf("       it is not defined under delayed entry\n")
        exit(198)
    }

    eta = Z * beta
    expeta = exp(eta)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :&
        (delta :== 1)
    is_cens = (delta :== 0) :| (event_type :== censval)

    row_id = (1::n)
    ord = order((t, row_id), (1, 2))
    levels = uniqrows(byg_id)
    ng = rows(levels)
    gidx = _finegray_group_index(byg_id, levels)
    Gt = _finegray_G_at_times(t, G, byg_id, t)
    Gminus = _finegray_G_minus(gidx, Gt)

    /* ---- pass A: per distinct time, collect S0, zbar, event counts, Ghat */
    nt = 0
    i = 1
    while (i <= n) {
        cur_time = t[ord[i]]
        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }
        nt++
        i = j
    }

    S0arr = J(nt, 1, 0)
    Zbar = J(nt, p, 0)
    Dg = J(nt, ng, 0)
    Gg = J(nt, ng, 1)

    risk_S0 = colsum(expeta)
    risk_S1 = colsum(expeta :* Z)
    bwd_s0 = J(ng, 1, 0)
    bwd_s1 = J(ng, p, 0)

    it = 0
    i = 1
    while (i <= n) {
        cur_time = t[ord[i]]
        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }
        it++

        for (g = 1; g <= ng; g++) Gg[it, g] = Gt[ord[i], g]

        S0_t = risk_S0 + Gg[it, .] * bwd_s0
        S1_t = risk_S1 + Gg[it, .] * bwd_s1
        if (S0_t > 0) {
            z_bar_t = S1_t / S0_t
            S0arr[it] = S0_t
            Zbar[it, .] = z_bar_t
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_cause[idx]) Dg[it, gidx[idx]] = Dg[it, gidx[idx]] + 1
        }

        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_compete[idx]) {
                g = gidx[idx]
                bwd_s0[g] = bwd_s0[g] + expeta[idx] / Gminus[idx]
                bwd_s1[g, .] = bwd_s1[g, .] +
                    expeta[idx] / Gminus[idx] * Z[idx, .]
            }
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            risk_S0 = risk_S0 - expeta[idx]
            risk_S1 = risk_S1 - expeta[idx] * Z[idx, .]
        }
        i = j
    }

    /* ---- pass B: reverse cumulative C0_g, C1_g over group-g event times */
    C0 = J(nt, ng, 0)
    C1 = J(nt, ng * p, 0)
    for (it = nt; it >= 1; it--) {
        if (it < nt) {
            C0[it, .] = C0[it + 1, .]
            C1[it, .] = C1[it + 1, .]
        }
        if (S0arr[it] <= 0) continue
        for (g = 1; g <= ng; g++) {
            if (Dg[it, g] == 0) continue
            cS0 = Dg[it, g] * Gg[it, g] / S0arr[it]
            C0[it, g] = C0[it, g] + cS0
            C1[it, ((g - 1) * p + 1)..(g * p)] =
                C1[it, ((g - 1) * p + 1)..(g * p)] + cS0 * Zbar[it, .]
        }
    }

    /* ---- pass C: forward, form q_g(t) and accumulate psi */
    psi = J(n, p, 0)
    cumL = J(ng, p, 0)
    qg = J(ng, p, 0)
    Yg = J(ng, 1, 0)
    for (i = 1; i <= n; i++) Yg[gidx[i]] = Yg[gidx[i]] + 1

    bwd_s0 = J(ng, 1, 0)
    bwd_s1 = J(ng, p, 0)

    it = 0
    i = 1
    while (i <= n) {
        cur_time = t[ord[i]]
        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }
        it++

        for (g = 1; g <= ng; g++) {
            c1row = C1[it, ((g - 1) * p + 1)..(g * p)]
            qg[g, .] = bwd_s1[g, .] * C0[it, g] - bwd_s0[g] * c1row
        }

        for (g = 1; g <= ng; g++) {
            dNc_g = 0
            for (k = i; k < j; k++) {
                idx = ord[k]
                if (is_cens[idx] & gidx[idx] == g) dNc_g = dNc_g + 1
            }
            if (dNc_g > 0 & Yg[g] > 0)
                cumL[g, .] = cumL[g, .] +
                    dNc_g * qg[g, .] / (Yg[g] * Yg[g])
        }

        for (k = i; k < j; k++) {
            idx = ord[k]
            g = gidx[idx]
            psi[idx, .] = -cumL[g, .]
            if (is_cens[idx] & Yg[g] > 0)
                psi[idx, .] = psi[idx, .] + qg[g, .] / Yg[g]
        }

        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_compete[idx]) {
                g = gidx[idx]
                bwd_s0[g] = bwd_s0[g] + expeta[idx] / Gminus[idx]
                bwd_s1[g, .] = bwd_s1[g, .] +
                    expeta[idx] / Gminus[idx] * Z[idx, .]
            }
        }
        for (k = i; k < j; k++) Yg[gidx[ord[k]]] = Yg[gidx[ord[k]]] - 1

        i = j
    }

    return(psi)
}

/* Robust (sandwich) variance estimator with left truncation support */
real matrix _finegray_robust_var(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real matrix Z,
    real colvector beta,
    real colvector G,
    real colvector byg_id,
    real matrix info_inv,
    string scalar clust_var,
    real colvector clust_id,
    real colvector t0,
    real colvector tg_id,
    | real scalar nuisance)
{
    real scalar n, p, i, use_cluster
    real colvector clev, sel
    real matrix scores, meat, clust_scores

    if (args() < 15) nuisance = 0

    n = rows(t)
    p = cols(Z)

    scores = _finegray_score_residuals(t, delta, cause, censval, event_type,
        Z, beta, G, byg_id, t0, tg_id)

    /* FG (1999) eq. (7)-(8): add the influence contribution from having
       ESTIMATED G.  The caller guarantees right censoring only -- the psi
       derivation does not cover delayed entry -- and _finegray_psi_residuals
       errors rather than silently returning an ungrounded quantity if that
       guarantee is broken. */
    if (nuisance) {
        scores = scores + _finegray_psi_residuals(t, delta, cause, censval,
            event_type, Z, beta, G, byg_id, t0)
    }

    use_cluster = (clust_var != "" & rows(clust_id) == n)
    if (use_cluster) {
        clev = uniqrows(clust_id)
        clust_scores = J(rows(clev), p, 0)
        for (i = 1; i <= rows(clev); i++) {
            sel = selectindex(clust_id :== clev[i])
            clust_scores[i, .] = colsum(scores[sel, .])
        }
        meat = clust_scores' * clust_scores
    }
    else {
        meat = scores' * scores
    }

    return(info_inv * meat * info_inv)
}

/* Canonical stratified ZZF Breslow baseline.  The pooled stabilizer cancels
   between the weighted event count and weighted risk set, leaving one
   stratum-specific event denominator outside the denominator-scale risk sum. */
real matrix _finegray_basehaz_zzf(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real matrix Z,
    real colvector beta,
    real colvector G,
    real colvector byg_id,
    real colvector t0,
    real colvector tg_id)
{
    real colvector row_id, eta, expeta, is_cause, is_compete, ord, entry_ord
    real colvector gidx, Gminus, jc, ju, riskn
    real scalar n, i, j, k, idx, cur_time, ep, g, ng, coreS0
    real scalar cum_bh, ev_idx, n_events, has_cause
    real rowvector risk0, bwd0
    real matrix Aden, result

    n = rows(t)
    eta = Z * beta
    expeta = exp(eta)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)
    row_id = (1::n)
    ord = order((t, row_id), (1, 2))
    entry_ord = order((t0, row_id), (1, 2))
    _finegray_joint_setup(byg_id, tg_id, gidx, jc, ju)
    ng = rows(jc)
    Aden = _finegray_A_at_times(t, G, byg_id, t0, tg_id, jc, ju, t)
    Gminus = _finegray_G_minus(gidx, Aden)

    risk0 = J(1, ng, 0)
    riskn = J(ng, 1, 0)
    bwd0 = J(1, ng, 0)
    n_events = sum(is_cause)
    result = J(n_events, 2, .)
    cum_bh = 0
    ev_idx = 0
    ep = 1
    i = 1
    while (i <= n) {
        cur_time = t[ord[i]]
        while (ep <= n) {
            if (t0[entry_ord[ep]] >= cur_time) break
            idx = entry_ord[ep]
            if (t[idx] >= cur_time) {
                g = gidx[idx]
                risk0[g] = risk0[g] + expeta[idx]
                riskn[g] = riskn[g] + 1
            }
            ep++
        }
        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }
        has_cause = 0
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_cause[idx]) {
                coreS0 = bwd0 * J(ng, 1, 1)
                for (g = 1; g <= ng; g++) {
                    if (riskn[g] > 0) coreS0 = coreS0 + risk0[g] / Aden[idx, g]
                }
                cum_bh = cum_bh +
                    1 / (Aden[idx, gidx[idx]] * coreS0)
                has_cause = 1
            }
        }
        if (has_cause) {
            ev_idx++
            result[ev_idx, 1] = cur_time
            result[ev_idx, 2] = cum_bh
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_compete[idx]) {
                g = gidx[idx]
                bwd0[g] = bwd0[g] + expeta[idx] / Gminus[idx]
            }
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            g = gidx[idx]
            risk0[g] = risk0[g] - expeta[idx]
            riskn[g] = riskn[g] - 1
        }
        i = j
    }
    if (ev_idx < 1) return(J(0, 2, .))
    if (ev_idx < rows(result)) result = result[(1..ev_idx), .]
    return(result)
}

/* Compute baseline cumulative subhazard (with left truncation) */
real matrix _finegray_basehazard(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real matrix Z,
    real colvector beta,
    real colvector G,
    real colvector byg_id,
    real colvector t0,
    real colvector tg_id)
{
    real colvector row_id
    real scalar n, p, i, j, k, idx, cum_bh, g, ng
    real scalar n_events, ev_idx, S0_t, cur_time, risk_S0, ep, has_cause
    real colvector eta, expeta, is_cause, is_compete, ord, entry_ord
    real colvector levels, gidx, Gminus, jc, ju
    real rowvector bwd_s0_raw
    real matrix result, Gt

    if (_finegray_use_pooled_stabilizer(t0, byg_id, tg_id)) {
        return(_finegray_basehaz_zzf(t, delta, cause, censval, event_type,
            Z, beta, G, byg_id, t0, tg_id))
    }

    n = rows(t)
    p = cols(Z)

    eta = Z * beta
    expeta = exp(eta)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)

    /* Deterministic tie-break by row index.  Mata's order() resolves ties
       using Stata's sort seed, which ADVANCES on every sort, so a tied key
       (every t0 == 0 when there is no delayed entry) yields a different
       permutation on each call -- and the risk-set scan then accumulates in
       a different floating-point order.  Without this the same command on
       the same data is not bit-reproducible. */
    row_id = (1::n)
    ord = order((t, row_id), (1, 2))
    entry_ord = order((t0, row_id), (1, 2))
    levels = uniqrows(byg_id)
    /* ZZF: the weight is now A = G(t-)H(t-) on CROSS-CLASSIFIED strata.  With no
       delayed entry H == 1 and this is bit-identical to the former G-only path. */
    _finegray_joint_setup(byg_id, tg_id, gidx, jc, ju)
    ng = rows(jc)
    Gt = _finegray_A_at_times(t, G, byg_id, t0, tg_id, jc, ju, t)
    Gminus = _finegray_G_minus(gidx, Gt)

    risk_S0 = 0
    ep = 1

    n_events = sum(is_cause)
    result = J(n_events, 2, .)

    bwd_s0_raw = J(1, ng, 0)
    cum_bh = 0
    ev_idx = 0

    i = 1
    while (i <= n) {
        cur_time = t[ord[i]]

        /* Add entries: (t0, t] means t0 < cur_time */
        while (ep <= n) {
            if (t0[entry_ord[ep]] >= cur_time) break
            idx = entry_ord[ep]
            if (t[idx] >= cur_time) {
                risk_S0 = risk_S0 + expeta[idx]
            }
            ep++
        }

        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }

        /* Process cause events - accumulate baseline hazard.
           The cumulative subhazard is a step function of TIME, so it must have
           one row per unique cause-event time, not one per event.  Tied events
           all see the same risk set and hence the same S0, so Breslow adds
           d/S0(t) once for the d events at t -- but emitting a row per event
           left e(basehaz) multi-valued at t (50 tied events -> 50 rows, 1
           unique time), which every step-function lookup downstream then had to
           tolerate. Accumulate across the tie group, then emit a single row. */
        has_cause = 0
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_cause[idx]) {
                S0_t = risk_S0 + Gt[idx, .] * bwd_s0_raw'
                cum_bh = cum_bh + 1 / S0_t
                has_cause = 1
            }
        }
        if (has_cause) {
            ev_idx++
            result[ev_idx, 1] = cur_time
            result[ev_idx, 2] = cum_bh
        }

        /* Add competing events to backward */
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_compete[idx]) {
                g = gidx[idx]
                bwd_s0_raw[g] = bwd_s0_raw[g] + expeta[idx] / Gminus[idx]
            }
        }

        /* Remove exiting subjects */
        for (k = i; k < j; k++) {
            risk_S0 = risk_S0 - expeta[ord[k]]
        }

        i = j
    }

    /* result was sized for the worst case (every cause event at its own time);
       with ties it holds fewer rows.  Trim, or the trailing rows stay missing
       and every consumer sees a step function with a missing tail. */
    if (ev_idx < 1) return(J(0, 2, .))
    if (ev_idx < rows(result)) result = result[(1..ev_idx), .]

    return(result)
}

/* Canonical stratified ZZF Schoenfeld contributions. */
real matrix _finegray_schoenfeld_zzf(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real matrix Z,
    real colvector beta,
    real colvector G,
    real colvector byg_id,
    real scalar do_scale,
    real colvector t0,
    real colvector tg_id)
{
    real colvector row_id, eta, expeta, is_cause, is_compete, ord, entry_ord
    real colvector gidx, Gminus, jc, ju, Apool, score_vec, riskn
    real scalar n, p, i, j, k, idx, cur_time, ep, g, ng, coreS0, ew, ev
    real rowvector risk0, bwd0, coreS1, zbar
    real matrix risk1, bwd1, Aden, result, info_mat, info_inv

    n = rows(t)
    p = cols(Z)
    eta = Z * beta
    expeta = exp(eta)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)
    row_id = (1::n)
    ord = order((t, row_id), (1, 2))
    entry_ord = order((t0, row_id), (1, 2))
    _finegray_joint_setup(byg_id, tg_id, gidx, jc, ju)
    ng = rows(jc)
    Aden = _finegray_A_at_times(t, G, byg_id, t0, tg_id, jc, ju, t)
    Gminus = _finegray_G_minus(gidx, Aden)
    Apool = _finegray_A_pool_at_times(t, delta, censval, event_type, t0, t)

    risk0 = J(1, ng, 0)
    riskn = J(ng, 1, 0)
    risk1 = J(ng, p, 0)
    bwd0 = J(1, ng, 0)
    bwd1 = J(ng, p, 0)
    result = J(sum(is_cause), p + 1, .)
    ev = 0
    ep = 1
    i = 1
    while (i <= n) {
        cur_time = t[ord[i]]
        while (ep <= n) {
            if (t0[entry_ord[ep]] >= cur_time) break
            idx = entry_ord[ep]
            if (t[idx] >= cur_time) {
                g = gidx[idx]
                risk0[g] = risk0[g] + expeta[idx]
                riskn[g] = riskn[g] + 1
                risk1[g, .] = risk1[g, .] + expeta[idx] * Z[idx, .]
            }
            ep++
        }
        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_cause[idx]) {
                coreS0 = 0
                coreS1 = J(1, p, 0)
                for (g = 1; g <= ng; g++) {
                    coreS0 = coreS0 + bwd0[g]
                    coreS1 = coreS1 + bwd1[g, .]
                    if (riskn[g] > 0) {
                        coreS0 = coreS0 + risk0[g] / Aden[idx, g]
                        coreS1 = coreS1 + risk1[g, .] / Aden[idx, g]
                    }
                }
                zbar = coreS1 / coreS0
                ew = Apool[idx] / Aden[idx, gidx[idx]]
                ev++
                result[ev, 1] = t[idx]
                result[ev, 2..p+1] = ew * (Z[idx, .] - zbar)
            }
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_compete[idx]) {
                g = gidx[idx]
                bwd0[g] = bwd0[g] + expeta[idx] / Gminus[idx]
                bwd1[g, .] = bwd1[g, .] +
                    expeta[idx] / Gminus[idx] * Z[idx, .]
            }
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            g = gidx[idx]
            risk0[g] = risk0[g] - expeta[idx]
            riskn[g] = riskn[g] - 1
            risk1[g, .] = risk1[g, .] - expeta[idx] * Z[idx, .]
        }
        i = j
    }
    if (do_scale & ev > 0) {
        _finegray_score_info_zzf_strat(t, delta, cause, censval,
            event_type, Z, beta, G, byg_id, score_vec, info_mat, t0, tg_id)
        info_inv = invsym(info_mat)
        if (missing(info_inv[1, 1])) info_inv = invsym(info_mat + 1e-6 * I(p))
        for (k = 1; k <= p; k++) {
            result[., k + 1] = result[., k + 1] * info_inv[k, k]
        }
    }
    return(result)
}

/* Schoenfeld residuals at each cause-event time (with left truncation).
   Returns n_fail x (p+1) matrix: [time, resid_1, ..., resid_p]
   Optionally scales by diag(info_inv) for Grambsch-Therneau test. */
real matrix _finegray_schoenfeld(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real matrix Z,
    real colvector beta,
    real colvector G,
    real colvector byg_id,
    real scalar do_scale,
    real colvector t0,
    real colvector tg_id)
{
    real scalar n, p, i, j, k, idx, S0_total, cur_time
    real scalar ev_idx, n_events, risk_S0, ep, g, ng
    real colvector eta, expeta, is_cause, is_compete, ord, entry_ord, score_vec
    real colvector row_id, levels, gidx, Gminus, jc, ju
    real matrix result, info_mat, risk_S1_mat, bwd_s1_raw, Gt
    real rowvector bwd_s0_raw, S1_total, z_bar, risk_S1

    if (_finegray_use_pooled_stabilizer(t0, byg_id, tg_id)) {
        return(_finegray_schoenfeld_zzf(t, delta, cause, censval,
            event_type, Z, beta, G, byg_id, do_scale, t0, tg_id))
    }

    n = rows(t)
    p = cols(Z)

    eta = Z * beta
    expeta = exp(eta)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)

    /* Stable sort by t, breaking ties by row index.  Mata's order() is not
       stable -- it resolves ties from Stata's sort seed, which ADVANCES on
       every sort -- so tied event times otherwise get an arbitrary ordering
       that may not match finegray_predict's assignment sort (_t _obs_id).
       NOTE the key spec is (1, 2): "column 1, then column 2".  (1, 1) means
       "column 1, then column 1", which never consults row_id and leaves the
       ties randomized. */
    row_id = (1::n)
    ord = order((t, row_id), (1, 2))
    entry_ord = order((t0, row_id), (1, 2))
    levels = uniqrows(byg_id)
    /* ZZF: the weight is now A = G(t-)H(t-) on CROSS-CLASSIFIED strata.  With no
       delayed entry H == 1 and this is bit-identical to the former G-only path. */
    _finegray_joint_setup(byg_id, tg_id, gidx, jc, ju)
    ng = rows(jc)
    Gt = _finegray_A_at_times(t, G, byg_id, t0, tg_id, jc, ju, t)
    Gminus = _finegray_G_minus(gidx, Gt)

    risk_S0 = 0
    risk_S1 = J(1, p, 0)
    ep = 1

    n_events = sum(is_cause)
    result = J(n_events, p + 1, .)

    bwd_s0_raw = J(1, ng, 0)
    bwd_s1_raw = J(ng, p, 0)
    ev_idx = 0

    i = 1
    while (i <= n) {
        cur_time = t[ord[i]]

        /* Add entries: (t0, t] means t0 < cur_time */
        while (ep <= n) {
            if (t0[entry_ord[ep]] >= cur_time) break
            idx = entry_ord[ep]
            if (t[idx] >= cur_time) {
                risk_S0 = risk_S0 + expeta[idx]
                risk_S1 = risk_S1 + expeta[idx] * Z[idx, .]
            }
            ep++
        }

        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }

        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_cause[idx]) {
                S0_total = risk_S0 + Gt[idx, .] * bwd_s0_raw'
                S1_total = risk_S1 + Gt[idx, .] * bwd_s1_raw
                z_bar = S1_total / S0_total

                ev_idx++
                result[ev_idx, 1] = t[idx]
                result[ev_idx, 2..p+1] = Z[idx, .] - z_bar
            }
        }

        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_compete[idx]) {
                g = gidx[idx]
                bwd_s0_raw[g] = bwd_s0_raw[g] + expeta[idx] / Gminus[idx]
                bwd_s1_raw[g, .] = bwd_s1_raw[g, .] +
                    expeta[idx] / Gminus[idx] * Z[idx, .]
            }
        }

        /* Remove exiting subjects */
        for (k = i; k < j; k++) {
            idx = ord[k]
            risk_S0 = risk_S0 - expeta[idx]
            risk_S1 = risk_S1 - expeta[idx] * Z[idx, .]
        }

        i = j
    }

    /* Grambsch-Therneau scaling: multiply by diag(V) */
    if (do_scale & n_events > 0) {
        _finegray_score_info(t, delta, cause, censval, event_type,
            Z, beta, G, byg_id, score_vec, info_mat, t0, tg_id)
        real matrix info_inv
        info_inv = invsym(info_mat)
        if (missing(info_inv[1,1])) {
            info_inv = invsym(info_mat + 1e-6 * I(p))
        }
        for (k = 1; k <= p; k++) {
            result[., k+1] = result[., k+1] * info_inv[k, k]
        }
    }

    return(result)
}

/* Compute Schoenfeld residuals from stored e() results and post to Stata.
   t0var names the entry-time variable ("_t0", or the persisted subject entry
   variable when the fit reduced multiple records per subject). */
void _finegray_schoenfeld_compute(
    string scalar varlist_str,
    string scalar events_str,
    real scalar cause,
    real scalar censval,
    string scalar byg_str,
    string scalar tg_str,
    real scalar do_scale,
    string scalar t0var)
{
    real colvector t, delta, event_type, G, byg_id, beta, t0, tg_id
    real matrix Z, sch
    string rowvector vars
    real scalar p

    vars = tokens(varlist_str)
    p = length(vars)

    Z = st_data(., vars)
    t = st_data(., "_t")
    delta = st_data(., "_d")
    event_type = st_data(., events_str)
    t0 = st_data(., t0var)

    beta = st_matrix("e(b)")'

    if (byg_str != "") {
        byg_id = st_data(., byg_str)
    }
    else {
        byg_id = J(rows(t), 1, 1)
    }
    /* truncstrata(): the entry-distribution H is estimated within these groups.
       Absent => a single group => H == 1 => A == G => pre-ZZF behaviour. */
    if (tg_str != "") {
        tg_id = st_data(., tg_str)
    }
    else {
        tg_id = J(rows(t), 1, 1)
    }

    /* post-estimation recompute: quiet=1, the fit already printed any note */
    G = _finegray_km_censor(t, delta, censval, event_type, byg_id, t0, 1)

    sch = _finegray_schoenfeld(t, delta, cause, censval, event_type,
        Z, beta, G, byg_id, do_scale, t0, tg_id)

    st_matrix("_finegray_schoenfeld", sch)
}

/* Abort on a rank-deficient information matrix, naming the offending terms.

   invsym() returns a GENERALIZED inverse for a rank-deficient matrix, with no
   missing values anywhere -- invsym((1,1\1,1))[1,1] is not missing.  So a
   missing() test cannot detect rank deficiency, and without this guard the
   optimizer chases floating-point noise along a flat direction and fabricates
   a coefficient (with SE 0 and converged=1) for a parameter the subdistribution
   likelihood cannot identify at all.

   _rmcoll in finegray.ado already rejects columns that are collinear in the
   FULL sample.  This catches the weaker condition that actually matters: a
   column can be globally full rank yet enter no cause-event risk set (e.g. it
   is nonzero only for subjects censored before the first cause event), leaving
   its direction flat in the likelihood. */
void _finegray_rank_fail(
    real matrix info_mat,
    string rowvector vars,
    real scalar p)
{
    real scalar k, dmax
    real colvector d
    string scalar bad

    d = diagonal(info_mat)
    dmax = colmax(d)
    bad = ""
    for (k = 1; k <= p; k++) {
        if (dmax <= 0 | d[k] <= 1e-9 * dmax) bad = bad + " " + vars[k]
    }

    errprintf("finegray: the information matrix is not full rank\n")
    if (bad != "") {
        errprintf("term(s) contributing no information at any cause-event ")
        errprintf("risk set:%s\n", bad)
        errprintf("their coefficients are not identified by the ")
        errprintf("subdistribution likelihood\n")
    }
    else {
        errprintf("the covariates are collinear within the cause-event ")
        errprintf("risk sets\n")
    }
    errprintf("remove or recode the offending term(s) and fit the model again\n")
    exit(error(459))
}

/* Main engine: Newton-Raphson with step halving */
void _finegray_engine(
    string scalar varlist_str,
    string scalar events_str,
    real scalar cause,
    real scalar censval,
    string scalar byg_str,
    string scalar tg_str,
    string scalar vce_type,
    string scalar clust_str,
    real scalar max_iter,
    real scalar tol,
    real scalar show_log,
    real scalar adjust,
    real scalar want_bh,
    real scalar nuisance)
{
    real colvector t, delta, event_type, G, byg_id, t0, tg_id
    real matrix Z, V, bh
    real colvector beta, beta_new, score_vec, step, clust_id
    real matrix info_mat, info_inv
    real scalar n, p, ll, ll_new, ll_0, converged, iter
    real scalar step_scale, halving, max_halvings, chi2, df_m
    real scalar decrement, accepted, n_clust, rank_V, npos
    string rowvector vars

    /* Read data */
    vars = tokens(varlist_str)
    p = length(vars)

    Z = st_data(., vars)
    t = st_data(., "_t")
    delta = st_data(., "_d")
    event_type = st_data(., events_str)
    t0 = st_data(., "_t0")
    n = rows(t)

    /* Read byg variable if specified */
    if (byg_str != "") {
        byg_id = st_data(., byg_str)
    }
    else {
        byg_id = J(n, 1, 1)
    }
    if (tg_str != "") {
        tg_id = st_data(., tg_str)
    }
    else {
        tg_id = J(n, 1, 1)
    }

    /* Compute censoring distribution */
    G = _finegray_km_censor(t, delta, censval, event_type, byg_id, t0)

    /* Positivity BEFORE the fit.  A(t) is a function of the data alone -- it does
       not depend on beta -- so a degenerate weight is knowable before a single
       Newton step, and reporting it as "convergence not achieved" 200 iterations
       later is a diagnosis of the wrong thing. */
    npos = _finegray_positivity_check(t, delta, cause, censval, event_type,
        G, byg_id, t0, tg_id)
    if (npos > 0) {
        errprintf("finegray: positivity violation in the delayed-entry weights\n")
        errprintf("  %g consulted joint-stratum denominator cell(s) are zero\n", npos)
        errprintf("  a configured ZZF Weight-1 risk contribution is therefore undefined\n")
        errprintf("  this can occur at an event time or at a retained competing exit\n")
        errprintf("  before enough subjects in that stratum have entered\n")
        errprintf("  affected weight strata: %s\n", st_local("_fg_posstrata"))
        errprintf("  use coarser strata()/truncstrata(), or a later time origin\n")
        exit(error(459))
    }

    /* Starting values: zeros */
    beta = J(p, 1, 0)

    /* Null log-likelihood (beta = 0).  The Fine-Gray partial likelihood has no
       identifiable intercept, so this is the beta=0 null, not a constant-only
       fit. */
    ll_0 = _finegray_loglik(t, delta, cause, censval, event_type, Z,
        J(p, 1, 0), G, byg_id, t0, tg_id)
    if (ll_0 >= .) {
        errprintf("finegray: the null log pseudo-likelihood is not finite\n")
        exit(error(430))
    }
    ll = ll_0

    if (show_log) {
        printf("{txt}Iteration 0: log pseudo-likelihood = {res}%12.6f\n", ll)
    }

    converged = 0
    max_halvings = 20

    for (iter = 1; iter <= max_iter; iter++) {
        /* Score and information */
        _finegray_score_info(t, delta, cause, censval, event_type,
            Z, beta, G, byg_id, score_vec, info_mat, t0, tg_id)

        if (hasmissing(info_mat) | hasmissing(score_vec)) {
            errprintf("finegray: the score or information matrix is not ")
            errprintf("finite at iteration %g\n", iter)
            exit(error(430))
        }
        if (rank(info_mat) < p) _finegray_rank_fail(info_mat, vars, p)

        info_inv = invsym(info_mat)
        if (missing(info_inv[1,1])) {
            errprintf("finegray: the information matrix is singular\n")
            exit(error(498))
        }

        step = info_inv * score_vec

        /* Convergence on the NEWTON DECREMENT, score' inv(I) score.  This is
           invariant under any linear reparameterization of Z -- in particular
           under rescaling a covariate -- so x and 1e6*x converge at the same
           point and to the same likelihood.  A raw step-size test (|step| <
           sqrt(tol)) is NOT scale free: it is stated on the coefficient scale,
           so rescaling x by 1e6 shrinks beta by 1e6 and the test fires
           immediately, stranding the fit at a worse optimum while still
           reporting converged=1.

           Near the optimum the decrement is ~2*(ll_max - ll), so a decrement
           below tol means the likelihood is within tol/2 of its maximum. */
        decrement = score_vec' * step
        if (decrement < 0) decrement = 0    /* info is PSD; absorb fp noise */

        if (decrement < tol) {
            beta = beta + step
            converged = 1
            break
        }

        /* Step halving.  `accepted' records whether the loop exited with an
           improving beta_new, so the step actually taken is always the one the
           likelihood was evaluated at (testing step_scale after the loop reads
           the NEXT halving, not the accepted one). */
        step_scale = 1
        accepted = 0
        for (halving = 1; halving <= max_halvings; halving++) {
            beta_new = beta + step_scale * step
            ll_new = _finegray_loglik(t, delta, cause, censval,
                event_type, Z, beta_new, G, byg_id, t0, tg_id)

            /* Mata returns exp(overflow) as missing, and (. > x) is TRUE, so a
               bare `ll_new > ll' would accept a missing likelihood as an
               improvement.  Require finiteness explicitly. */
            if (ll_new < . & ll_new > ll) {
                accepted = 1
                break
            }
            step_scale = step_scale / 2
        }

        if (!accepted) {
            /* No improving step at any scale down to 2^-max_halvings, while the
               decrement still predicts an improvement of decrement/2 >= tol/2.
               The line search is stuck; this is not convergence. */
            if (show_log) {
                printf("{txt}Iteration %g: step halving failed;" +
                    " no improving step found\n", iter)
            }
            break
        }

        beta = beta_new
        ll = ll_new

        if (show_log) {
            printf("{txt}Iteration %g: log pseudo-likelihood = {res}%12.6f\n",
                iter, ll)
        }
    }

    /* Nonconvergence is NOT an error here: results are posted with
       converged = 0, matching stcrreg, so a partial fit can still be inspected.
       finegray.ado prints the warning ABOVE the coefficient table (where it
       cannot be scrolled past), and every post-estimation command refuses to
       consume a fit with e(converged) != 1 -- which is where the real hazard
       lived, since finegray_cif/finegray_predict/finegray_phtest read e(b)
       without ever asking whether it converged. */

    /* Recompute the log-likelihood at the ACCEPTED beta.  Every break path
       above must leave e(ll) paired with e(b): the decrement path takes a final
       step after its last likelihood evaluation, so reporting the pre-step ll
       there would post a stale value (with tolerance(1) it posted e(ll) ==
       e(ll_0) exactly while beta was nonzero). */
    ll = _finegray_loglik(t, delta, cause, censval, event_type, Z, beta, G,
        byg_id, t0, tg_id)
    if (ll >= .) {
        errprintf("finegray: the log pseudo-likelihood is not finite at the ")
        errprintf("solution\n")
        exit(error(430))
    }

    /* Final information for variance */
    _finegray_score_info(t, delta, cause, censval, event_type,
        Z, beta, G, byg_id, score_vec, info_mat, t0, tg_id)
    if (hasmissing(info_mat)) {
        errprintf("finegray: the information matrix is not finite at the ")
        errprintf("solution\n")
        exit(error(430))
    }
    if (rank(info_mat) < p) _finegray_rank_fail(info_mat, vars, p)
    info_inv = invsym(info_mat)
    if (missing(info_inv[1,1])) {
        errprintf("finegray: the information matrix is singular at the ")
        errprintf("solution\n")
        exit(error(498))
    }

    /* Variance estimation */
    n_clust = .
    if (vce_type == "robust" | vce_type == "cluster") {
        if (vce_type == "cluster") {
            clust_id = st_data(., clust_str)
            n_clust = rows(uniqrows(clust_id))

            /* The cluster-robust meat is a sum of g outer products of cluster
               score totals which themselves sum to (approximately) zero at the
               solution, so its rank is at most g-1.  With g <= p the sandwich
               is singular in at least p-g+1 directions and any SE printed for
               those directions is an artefact of invsym()'s g-inverse, not an
               estimate: g=1 previously reported SE = 1.4e-11, and g=2 with p=3
               reported three SEs from a rank-1 variance.  The finite-sample
               factor g/(g-1) is undefined at g=1 as well.  Refuse rather than
               post fabricated precision. */
            if (n_clust < 2) {
                errprintf("finegray: cluster(%s) identifies %g cluster in the ",
                    clust_str, n_clust)
                errprintf("estimation sample\n")
                errprintf("clustered standard errors require at least 2 ")
                errprintf("clusters\n")
                exit(error(459))
            }
            if (n_clust <= p) {
                errprintf("finegray: cluster(%s) identifies %g clusters for ",
                    clust_str, n_clust)
                errprintf("%g coefficients\n", p)
                errprintf("the clustered variance matrix has rank at most %g, ",
                    n_clust - 1)
                errprintf("so it cannot support %g standard errors\n", p)
                errprintf("use more clusters, or fit fewer covariates\n")
                exit(error(459))
            }
        }
        else {
            clust_id = J(n, 1, .)
        }
        V = _finegray_robust_var(t, delta, cause, censval, event_type,
            Z, beta, G, byg_id, info_inv, clust_str, clust_id, t0, tg_id,
            nuisance)

        /* Finite-sample adjustment, on by default and suppressed by noadjust.
           This is StataCorp's stcrreg contract exactly: g/(g-1) when clustered,
           N/(N-1) otherwise.  Without it finegray reproduced stcrreg's
           `noadjust' variance while presenting it as the default. */
        if (adjust) {
            if (vce_type == "cluster") V = V * (n_clust / (n_clust - 1))
            else                       V = V * (n / (n - 1))
        }
    }
    else {
        V = info_inv
    }

    if (hasmissing(V)) {
        errprintf("finegray: the variance matrix is not finite\n")
        errprintf("the estimated weights or score contributions are numerically unstable\n")
        errprintf("inspect the weight warnings and use coarser strata()/truncstrata()\n")
        exit(error(430))
    }

    /* Compute the baseline hazard ALWAYS -- the scan is linear -- and cache it in
       MATA, which is free.  What is not free is handing its K ~ n/2 rows to Stata
       as a matrix: that is O(K^2) and was the package's whole superlinearity (see
       the note above _finegray_bh_rebuild), so the Stata matrix stays opt-in.
       Postestimation reads the cache, which is what lets `predict, cif' work on
       NEW data after the estimation sample has been dropped. */
    bh = _finegray_basehazard(t, delta, cause, censval, event_type,
        Z, beta, G, byg_id, t0, tg_id)
    _finegray_bh_store(bh)

    /* Model chi2 degrees of freedom.  Counting positive diagonal entries is
       not the rank: a cluster-robust V can have p positive variances and still
       be singular (2 clusters / 3 coefficients gave df_m = 3 against a rank-1
       V, so the Wald test was referred to a chi2(3) it does not follow).  Use
       the numerical rank, and report it as e(rank) -- the stcrreg contract. */
    rank_V = rank(V)
    df_m = rank_V
    chi2 = beta' * invsym(V) * beta

    /* Combined-weight sensitivity diagnostics (the e() weight contract). */
    _finegray_weight_diag(t, delta, cause, censval, event_type,
        G, byg_id, t0, tg_id)

    /* Post results to Stata matrices */
    st_matrix("_finegray_b", beta')
    st_matrix("_finegray_V", V)
    st_matrix("_finegray_rank", rank_V)
    if (n_clust < .) st_matrix("_finegray_nclust", n_clust)
    if (want_bh) {
        st_matrix("_finegray_basehaz", bh)
        st_matrixcolstripe("_finegray_basehaz",
            (J(2,1,""), ("time" \ "cumhazard")))
    }
    st_matrix("_finegray_ll", ll)
    st_matrix("_finegray_ll_0", ll_0)
    st_matrix("_finegray_chi2", chi2)
    st_matrix("_finegray_df_m", df_m)
    st_matrix("_finegray_conv", converged)
}

/* Influence-function variance of the predicted CIF.

   For each evaluation point (t*, z*) returns CIF(t*|z*) and its standard error
   via per-subject influence functions:

     CIF = 1 - exp(-L0(t*) r),   r = exp(z*'b)
     psi_i(CIF) = factor * ( q_i(t*) + PSIb_i' (b(t*) + L0(t*) z*) )
     factor = r exp(-L0 r),  PSIb_i = info_inv U_i  (U_i = score residual)

   with the Breslow baseline cumulative subhazard L0 and its influence pieces:
     q_i(t*)  = [1/S0(T_i) if i is a cause event <= t*]
                - expeta_i * sum_{cause T_m<=t*} Y^FG_i(T_m)/S0(T_m)^2
     b(t*)    = - sum_{cause T_m<=t*} zbar(T_m)/S0(T_m)
   Y^FG_i(T_m) is i's IPCW weight in the subdistribution risk set at T_m
   (1 if genuinely at risk; G(T_m)/G(T_i) if a past competing event; else 0),
   matching the weights the engine uses to build S0.

   Var(CIF) = sum_i psi_i^2 (cluster-summed when clust_str given). This is the
   influence-function (sandwich) variance treating the IPCW censoring weights as
   known; it is accurate under light-to-moderate censoring but mildly
   anti-conservative under heavy censoring, where the bootstrap option of
   finegray_cif / finegray_predict gives the exact band.

   Core routine: given the estimation design (Z, t, t0, delta, event_type, beta,
   byg_id, clust_id) and a k x (1+p) matrix of evaluation points E (col 1 = time,
   cols 2.. = covariate profile), returns a k x 2 matrix (CIF, SE). The two
   public entry points (_st for a Stata matrix of points, _predict for one point
   per observation) both delegate here so the influence-function logic lives in
   one place. */
/* Influence-function CIF for the stratified ZZF equation-7 form.  This is the
   denominator-scale analogue of _finegray_cif_core(): each event contributes
   dL = 1/(A_event*C), an at-risk subject in group g contributes
   1/(A_event*A_g*C^2), and a retained competing subject contributes
   1/(A_event*A_i*C^2).  The IPCW product-limit weights are treated as known,
   matching the package's documented analytic variance contract. */
real matrix _finegray_cif_core_zzf(
    real matrix Z,
    real colvector t,
    real colvector t0,
    real colvector delta,
    real colvector event_type,
    real colvector beta,
    real colvector byg_id,
    real colvector tg_id,
    real colvector clust_id,
    real scalar has_clust,
    real scalar cause,
    real scalar censval,
    real matrix E)
{
    real colvector row_id, G, eta, expeta, is_cause, is_compete, ord, entry_ord
    real colvector gidx, Gminus, jc, ju, score_vec, riskn
    real colvector Tm, dLm, obsm, cumL, Aevent, Ccomp
    real colvector own, sub, q, psi, cle, clt0, hi, lo, Ccs, clev, sel
    real matrix info_mat, info_inv, scores, PSIb, Aden, zbarm, Rm, Rcs, out
    real matrix risk1, bwd1
    real rowvector risk0, bwd0, coreS1, zbar, zstar, bvec
    real scalar n, p, ng, M, ev, i, j, k, idx, ep, g, cur_time, coreS0
    real scalar ii, mp, ne, e, tstar, mstar, m, L0, rstar, cif, factor, V

    n = rows(Z)
    p = cols(Z)
    /* post-estimation recompute: quiet=1, the fit already printed any note */
    G = _finegray_km_censor(t, delta, censval, event_type, byg_id, t0, 1)
    _finegray_joint_setup(byg_id, tg_id, gidx, jc, ju)
    ng = rows(jc)
    Aden = _finegray_A_at_times(t, G, byg_id, t0, tg_id, jc, ju, t)
    Gminus = _finegray_G_minus(gidx, Aden)

    _finegray_score_info_zzf_strat(t, delta, cause, censval, event_type,
        Z, beta, G, byg_id, score_vec, info_mat, t0, tg_id)
    info_inv = invsym(info_mat)
    if (missing(info_inv[1, 1])) info_inv = invsym(info_mat + 1e-6 * I(p))
    scores = _finegray_scores_zzf_strat(t, delta, cause, censval,
        event_type, Z, beta, G, byg_id, t0, tg_id)
    PSIb = scores * info_inv

    eta = Z * beta
    expeta = exp(eta)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)
    row_id = (1::n)
    ord = order((t, row_id), (1, 2))
    entry_ord = order((t0, row_id), (1, 2))

    M = sum(is_cause)
    Tm = J(M, 1, .)
    dLm = J(M, 1, .)
    obsm = J(M, 1, .)
    Aevent = J(M, 1, .)
    Ccomp = J(M, 1, .)
    zbarm = J(M, p, .)
    Rm = J(M, ng, 0)
    risk0 = J(1, ng, 0)
    riskn = J(ng, 1, 0)
    risk1 = J(ng, p, 0)
    bwd0 = J(1, ng, 0)
    bwd1 = J(ng, p, 0)
    ev = 0
    ep = 1
    i = 1
    while (i <= n) {
        cur_time = t[ord[i]]
        while (ep <= n) {
            if (t0[entry_ord[ep]] >= cur_time) break
            idx = entry_ord[ep]
            if (t[idx] >= cur_time) {
                g = gidx[idx]
                risk0[g] = risk0[g] + expeta[idx]
                riskn[g] = riskn[g] + 1
                risk1[g, .] = risk1[g, .] + expeta[idx] * Z[idx, .]
            }
            ep++
        }
        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_cause[idx]) {
                coreS0 = 0
                coreS1 = J(1, p, 0)
                for (g = 1; g <= ng; g++) {
                    coreS0 = coreS0 + bwd0[g]
                    coreS1 = coreS1 + bwd1[g, .]
                    if (riskn[g] > 0) {
                        coreS0 = coreS0 + risk0[g] / Aden[idx, g]
                        coreS1 = coreS1 + risk1[g, .] / Aden[idx, g]
                    }
                }
                zbar = coreS1 / coreS0
                ev++
                Tm[ev] = t[idx]
                obsm[ev] = idx
                Aevent[ev] = Aden[idx, gidx[idx]]
                dLm[ev] = 1 / (Aevent[ev] * coreS0)
                Ccomp[ev] = 1 / (Aevent[ev] * coreS0 ^ 2)
                zbarm[ev, .] = zbar
                for (g = 1; g <= ng; g++) {
                    if (riskn[g] > 0) {
                        Rm[ev, g] = 1 /
                            (Aevent[ev] * Aden[idx, g] * coreS0 ^ 2)
                    }
                }
            }
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_compete[idx]) {
                g = gidx[idx]
                bwd0[g] = bwd0[g] + expeta[idx] / Gminus[idx]
                bwd1[g, .] = bwd1[g, .] +
                    expeta[idx] / Gminus[idx] * Z[idx, .]
            }
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            g = gidx[idx]
            risk0[g] = risk0[g] - expeta[idx]
            riskn[g] = riskn[g] - 1
            risk1[g, .] = risk1[g, .] - expeta[idx] * Z[idx, .]
        }
        i = j
    }

    cumL = runningsum(dLm)
    Ccs = 0 \ runningsum(Ccomp)
    Rcs = J(M + 1, ng, 0)
    for (g = 1; g <= ng; g++) {
        Rcs[|2, g \ M + 1, g|] = runningsum(Rm[., g])
    }

    cle = J(n, 1, 0)
    clt0 = J(n, 1, 0)
    mp = 0
    for (ii = 1; ii <= n; ii++) {
        idx = ord[ii]
        while (mp < M) {
            if (Tm[mp + 1] <= t[idx]) mp++
            else break
        }
        cle[idx] = mp
    }
    mp = 0
    for (ii = 1; ii <= n; ii++) {
        idx = entry_ord[ii]
        while (mp < M) {
            if (Tm[mp + 1] <= t0[idx]) mp++
            else break
        }
        clt0[idx] = mp
    }

    ne = rows(E)
    out = J(ne, 2, 0)
    for (e = 1; e <= ne; e++) {
        tstar = E[e, 1]
        zstar = E[e, (2..p + 1)]
        mstar = colsum(Tm :<= tstar)
        if (mstar == 0) {
            out[e, 1] = 0
            out[e, 2] = 0
            continue
        }
        L0 = cumL[mstar]
        bvec = -colsum(zbarm[(1..mstar), .] :*
            (dLm[(1..mstar)] * J(1, p, 1)))
        rstar = exp(zstar * beta)
        cif = 1 - exp(-L0 * rstar)
        factor = rstar * exp(-L0 * rstar)

        own = J(n, 1, 0)
        for (m = 1; m <= mstar; m++) {
            own[obsm[m]] = own[obsm[m]] + dLm[m]
        }
        hi = (cle :> mstar) :* mstar :+ (cle :<= mstar) :* cle
        lo = (clt0 :> hi) :* hi :+ (clt0 :<= hi) :* clt0
        sub = J(n, 1, 0)
        for (i = 1; i <= n; i++) {
            g = gidx[i]
            sub[i] = Rcs[hi[i] + 1, g] - Rcs[lo[i] + 1, g]
            if (is_compete[i]) {
                sub[i] = sub[i] +
                    (Ccs[mstar + 1] - Ccs[hi[i] + 1]) / Gminus[i]
            }
        }
        q = own - expeta :* sub
        psi = factor :* (q + PSIb * (bvec + L0 * zstar)')

        if (has_clust) {
            clev = uniqrows(clust_id)
            V = 0
            for (k = 1; k <= rows(clev); k++) {
                sel = selectindex(clust_id :== clev[k])
                V = V + colsum(psi[sel]) ^ 2
            }
        }
        else V = colsum(psi :^ 2)
        out[e, 1] = cif
        out[e, 2] = sqrt(V)
    }
    return(out)
}

real matrix _finegray_cif_core(
    real matrix Z,
    real colvector t,
    real colvector t0,
    real colvector delta,
    real colvector event_type,
    real colvector beta,
    real colvector byg_id,
    real colvector tg_id,
    real colvector clust_id,
    real scalar has_clust,
    real scalar cause,
    real scalar censval,
    real matrix E)
{
    real colvector row_id
    real colvector G, eta, expeta, is_cause, is_compete, ord, entry_ord
    real colvector Tm, S0m, obsm, cum_invS0, own, sub, q, psi, score_vec
    real colvector clev, sel, levels, gidx, Gminus, jc, ju
    real colvector cle, clt0, Acs, invS0, invS0sq, hi, lo
    real matrix info_mat, info_inv, scores, PSIb, zbarm, out, Gt, Gm
    real matrix bwd_s1_raw, Bcs, GmInvS0sq
    real rowvector risk_S1, bwd_s0_raw, zstar, bvec, S1_t, Bmstar
    real scalar n, p, i, j, k, idx, ep, cur_time, risk_S0, S0_t
    real scalar M, ev, ne, e, tstar, mstar, m, L0, rstar, cif, factor, V
    real scalar mp, ii, g, ng

    if (_finegray_use_pooled_stabilizer(t0, byg_id, tg_id)) {
        return(_finegray_cif_core_zzf(Z, t, t0, delta, event_type, beta,
            byg_id, tg_id, clust_id, has_clust, cause, censval, E))
    }

    n = rows(Z)
    p = cols(Z)

    /* post-estimation recompute: quiet=1, the fit already printed any note */
    G = _finegray_km_censor(t, delta, censval, event_type, byg_id, t0, 1)
    levels = uniqrows(byg_id)
    /* ZZF: the weight is now A = G(t-)H(t-) on CROSS-CLASSIFIED strata.  With no
       delayed entry H == 1 and this is bit-identical to the former G-only path. */
    _finegray_joint_setup(byg_id, tg_id, gidx, jc, ju)
    ng = rows(jc)
    Gt = _finegray_A_at_times(t, G, byg_id, t0, tg_id, jc, ju, t)
    Gminus = _finegray_G_minus(gidx, Gt)

    _finegray_score_info(t, delta, cause, censval, event_type, Z, beta, G,
        byg_id, score_vec, info_mat, t0, tg_id)
    info_inv = invsym(info_mat)
    if (missing(info_inv[1, 1])) info_inv = invsym(info_mat + 1e-6 * I(p))

    scores = _finegray_score_residuals(t, delta, cause, censval, event_type,
        Z, beta, G, byg_id, t0, tg_id)
    PSIb = scores * info_inv

    eta = Z * beta
    expeta = exp(eta)
    is_cause = (event_type :== cause) :& (delta :== 1)
    is_compete = (event_type :!= cause) :& (event_type :!= censval) :& (delta :== 1)
    /* Deterministic tie-break by row index.  Mata's order() resolves ties
       using Stata's sort seed, which ADVANCES on every sort, so a tied key
       (every t0 == 0 when there is no delayed entry) yields a different
       permutation on each call -- and the risk-set scan then accumulates in
       a different floating-point order.  Without this the same command on
       the same data is not bit-reproducible. */
    row_id = (1::n)
    ord = order((t, row_id), (1, 2))
    entry_ord = order((t0, row_id), (1, 2))

    /* Event scan: per cause-event arrays in ascending time */
    M = sum(is_cause)
    Tm = J(M, 1, .); S0m = J(M, 1, .); Gm = J(M, ng, .); obsm = J(M, 1, .)
    zbarm = J(M, p, .)
    risk_S0 = 0; risk_S1 = J(1, p, 0); ep = 1
    bwd_s0_raw = J(1, ng, 0); bwd_s1_raw = J(ng, p, 0); ev = 0; i = 1
    while (i <= n) {
        cur_time = t[ord[i]]
        /* Add entries: (t0, t] means t0 < cur_time */
        while (ep <= n) {
            if (t0[entry_ord[ep]] >= cur_time) break
            idx = entry_ord[ep]
            if (t[idx] >= cur_time) {
                risk_S0 = risk_S0 + expeta[idx]
                risk_S1 = risk_S1 + expeta[idx] * Z[idx, .]
            }
            ep++
        }
        j = i
        while (j <= n) {
            if (t[ord[j]] != cur_time) break
            j++
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_cause[idx]) {
                S0_t = risk_S0 + Gt[idx, .] * bwd_s0_raw'
                S1_t = risk_S1 + Gt[idx, .] * bwd_s1_raw
                ev++
                Tm[ev] = t[idx]; S0m[ev] = S0_t
                Gm[ev, .] = Gt[idx, .]; obsm[ev] = idx
                zbarm[ev, .] = S1_t / S0_t
            }
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            if (is_compete[idx]) {
                g = gidx[idx]
                bwd_s0_raw[g] = bwd_s0_raw[g] + expeta[idx] / Gminus[idx]
                bwd_s1_raw[g, .] = bwd_s1_raw[g, .] +
                    expeta[idx] / Gminus[idx] * Z[idx, .]
            }
        }
        for (k = i; k < j; k++) {
            idx = ord[k]
            risk_S0 = risk_S0 - expeta[idx]
            risk_S1 = risk_S1 - expeta[idx] * Z[idx, .]
        }
        i = j
    }
    cum_invS0 = runningsum(1 :/ S0m)

    /* --- Prefix-sum scaffolding for the influence-function `sub' term ------
       The original per-eval-point loop over the cause events accumulated, for
       each observation i,
         sub_i = sum_{m<=mstar} [ 1{t0_i<Tm[m]<=t_i}                        (at-risk)
                                  + is_compete_i * 1{t_i<Tm[m]} * Gm[m]/G_i ] (fictitious)
                                 / S0m[m]^2,
       an O(M*n) inner loop per point. The two indicator families are step
       functions of the sorted cause-event times (Tm ascending), so cumulative
       sums over m collapse each observation's contribution to O(1):
         at-risk term    = A[hi_i] - A[lo_i],       A[k] = sum_{m<=k} 1/S0m^2
         fictitious term = (B[mstar]-B[hi_i])/G_i,  B[k] = sum_{m<=k} Gm/S0m^2
       with hi_i = #{m<=mstar : Tm[m]<=t_i}  and  lo_i = #{m<=mstar : Tm[m]<=t0_i}.
       The risk window is (t0_i, T_i] -- half-open at entry -- so lo_i counts
       events AT t0_i as excluded, matching the engine's (t0, t] risk sets.
       cle/clt0 (counts of cause events at/below each observation's exit/entry)
       are eval-point independent, so they are built once via two-pointer merges
       over the ascending Tm array. This makes the whole variance O(n log n). */
    invS0     = 1 :/ S0m
    invS0sq   = 1 :/ (S0m :^ 2)
    GmInvS0sq = Gm :/ ((S0m :^ 2) * J(1, ng, 1))
    Acs = 0 \ runningsum(invS0sq)          /* Acs[k+1] = sum_{m<=k} 1/S0m^2 */
    /* One censoring-KM column per group.  runningsum() takes a vector only, so
       accumulate column by column -- Gm is M x ng whenever bygroup() strata are
       in play (ng > 1) and a whole-matrix call would exit 3201. */
    Bcs = J(M + 1, ng, 0)
    for (g = 1; g <= ng; g++) {
        Bcs[|2, g \ M + 1, g|] = runningsum(GmInvS0sq[., g])
    }

    cle  = J(n, 1, 0)                       /* #{cause events with Tm <= t_i}  */
    clt0 = J(n, 1, 0)                       /* #{cause events with Tm <= t0_i} */
    mp = 0
    for (ii = 1; ii <= n; ii++) {
        idx = ord[ii]
        /* Mata & is not short-circuit: guard Tm[mp+1] with a nested test */
        while (mp < M) {
            if (Tm[mp + 1] <= t[idx]) mp++
            else break
        }
        cle[idx] = mp
    }
    mp = 0
    for (ii = 1; ii <= n; ii++) {
        idx = entry_ord[ii]
        while (mp < M) {
            if (Tm[mp + 1] <= t0[idx]) mp++
            else break
        }
        clt0[idx] = mp
    }

    ne = rows(E)
    out = J(ne, 2, 0)
    for (e = 1; e <= ne; e++) {
        tstar = E[e, 1]
        zstar = E[e, (2..p + 1)]
        mstar = colsum(Tm :<= tstar)
        if (mstar == 0) {
            out[e, 1] = 0; out[e, 2] = 0
            continue
        }
        L0 = cum_invS0[mstar]
        bvec = -colsum(zbarm[(1..mstar), .] :/ S0m[(1..mstar)])
        rstar = exp(zstar * beta)
        cif = 1 - exp(-L0 * rstar)
        factor = rstar * exp(-L0 * rstar)

        own = J(n, 1, 0)
        for (m = 1; m <= mstar; m++) own[obsm[m]] = invS0[m]

        /* hi_i = #{m<=mstar : Tm[m]<=t_i}; lo_i = #{m<=mstar : Tm[m]<=t0_i} */
        hi = (cle :> mstar) :* mstar :+ (cle :<= mstar) :* cle
        lo = (clt0 :> hi) :* hi :+ (clt0 :<= hi) :* clt0
        Bmstar = Bcs[mstar + 1, .]
        sub = Acs[hi :+ 1] - Acs[lo :+ 1]
        for (i = 1; i <= n; i++) {
            if (is_compete[i]) {
                g = gidx[i]
                sub[i] = sub[i] +
                    (Bmstar[g] - Bcs[hi[i] + 1, g]) / Gminus[i]
            }
        }
        q = own - expeta :* sub
        psi = factor :* (q + PSIb * (bvec + L0 * zstar)')

        if (has_clust) {
            clev = uniqrows(clust_id)
            V = 0
            for (k = 1; k <= rows(clev); k++) {
                sel = selectindex(clust_id :== clev[k])
                V = V + colsum(psi[sel]) ^ 2
            }
        }
        else V = colsum(psi :^ 2)

        out[e, 1] = cif
        out[e, 2] = sqrt(V)
    }
    return(out)
}

/* Read estimation design + a Stata matrix of evaluation points; post CIF/SE. */
void _finegray_cif_var_st(
    string scalar zvars,
    string scalar events_str,
    real scalar cause,
    real scalar censval,
    string scalar byg_str,
    string scalar tg_str,
    string scalar clust_str,
    string scalar tousevar,
    string scalar evalmat,
    string scalar outmat,
    string scalar t0var)
{
    real matrix Z, E, out
    real colvector t, t0, delta, event_type, beta, byg_id, tg_id, clust_id
    real scalar n, has_clust

    Z = st_data(., tokens(zvars), tousevar)
    t = st_data(., "_t", tousevar)
    t0 = st_data(., t0var, tousevar)
    delta = st_data(., "_d", tousevar)
    event_type = st_data(., events_str, tousevar)
    n = rows(Z)
    beta = st_matrix("e(b)")'
    if (byg_str != "") byg_id = st_data(., byg_str, tousevar)
    else byg_id = J(n, 1, 1)
    if (tg_str != "") tg_id = st_data(., tg_str, tousevar)
    else tg_id = J(n, 1, 1)
    has_clust = (clust_str != "")
    if (has_clust) clust_id = st_data(., clust_str, tousevar)
    else clust_id = J(n, 1, .)

    E = st_matrix(evalmat)
    out = _finegray_cif_core(Z, t, t0, delta, event_type, beta, byg_id, tg_id,
        clust_id, has_clust, cause, censval, E)
    st_matrix(outmat, out)
}

/* Per-observation CIF + SE: evaluate at each eval-sample observation's own time
   (tvar) and covariate profile, storing into cifvar and sevar. The estimation
   design is read from est_touse (e(sample)); the evaluation points from
   eval_touse (predict's if/in sample). */
void _finegray_cif_predict(
    string scalar zvars,
    string scalar events_str,
    real scalar cause,
    real scalar censval,
    string scalar byg_str,
    string scalar tg_str,
    string scalar clust_str,
    string scalar est_touse,
    string scalar eval_touse,
    string scalar tvar,
    string scalar sevar,
    string scalar t0var)
{
    real matrix Z, Zev, E, out
    real colvector t, t0, delta, event_type, beta, byg_id, tg_id, clust_id
    real colvector etouse, sel, tev
    real scalar n, has_clust

    Z = st_data(., tokens(zvars), est_touse)
    t = st_data(., "_t", est_touse)
    t0 = st_data(., t0var, est_touse)
    delta = st_data(., "_d", est_touse)
    event_type = st_data(., events_str, est_touse)
    n = rows(Z)
    beta = st_matrix("e(b)")'
    if (byg_str != "") byg_id = st_data(., byg_str, est_touse)
    else byg_id = J(n, 1, 1)
    if (tg_str != "") tg_id = st_data(., tg_str, est_touse)
    else tg_id = J(n, 1, 1)
    has_clust = (clust_str != "")
    if (has_clust) clust_id = st_data(., clust_str, est_touse)
    else clust_id = J(n, 1, .)

    etouse = st_data(., eval_touse)
    sel = selectindex(etouse :!= 0)
    tev = st_data(sel, tvar)
    Zev = st_data(sel, tokens(zvars))
    E = (tev, Zev)

    out = _finegray_cif_core(Z, t, t0, delta, event_type, beta, byg_id, tg_id,
        clust_id, has_clust, cause, censval, E)
    /* out[.,1] is the CIF; the analytic point CIF is taken from the step-lookup
       path in finegray_predict, so only the influence-function SE is stored. */
    st_store(sel, sevar, out[., 2])
}

/* Bootstrap helper: CIF at a grid of times for one covariate profile, from the
   currently posted e(b)/e(basehaz). Returns an ng x 1 matrix. Used by
   finegray_cif's bootstrap band (one call per replication). */
void _finegray_boot_cif(string scalar zmat, string scalar gmat, string scalar omat)
{
    real rowvector zr
    real colvector beta, gg, cif
    real matrix bh
    real scalar p, ng, i, k, nb, xb, h, ti
    zr = st_matrix(zmat)
    beta = st_matrix("e(b)")'
    p = rows(beta)
    xb = 0
    for (k = 1; k <= p; k++) xb = xb + zr[k] * beta[k]
    bh = st_matrix("e(basehaz)")
    nb = rows(bh)
    gg = st_matrix(gmat)
    ng = rows(gg)
    cif = J(ng, 1, 0)
    for (i = 1; i <= ng; i++) {
        ti = gg[i]
        h = 0
        for (k = 1; k <= nb; k++) {
            if (bh[k, 1] <= ti) h = bh[k, 2]
            else break
        }
        cif[i] = 1 - exp(-h * exp(xb))
    }
    st_matrix(omat, cif)
}

/* Bootstrap helper: per-observation CIF at each eval observation's own time
   (tvar) from the currently posted e(b)/e(basehaz), accumulated into the
   running sum (sumv) and sum-of-squares (ssv) variables. Used by
   finegray_predict's bootstrap CI (one call per replication). */
void _finegray_boot_cif_obs(
    string scalar zvars,
    string scalar tvar,
    string scalar touse,
    string scalar sumv,
    string scalar ssv)
{
    real matrix Z, bh
    real colvector beta, tt, xb, cif, sumc, ssc, tousev, sel
    real scalar nb, n, i, k, h, ti
    beta = st_matrix("e(b)")'
    bh = st_matrix("e(basehaz)")
    nb = rows(bh)
    tousev = st_data(., touse)
    sel = selectindex(tousev :!= 0)
    Z = st_data(sel, tokens(zvars))
    tt = st_data(sel, tvar)
    n = rows(Z)
    xb = Z * beta
    cif = J(n, 1, 0)
    for (i = 1; i <= n; i++) {
        ti = tt[i]
        h = 0
        for (k = 1; k <= nb; k++) {
            if (bh[k, 1] <= ti) h = bh[k, 2]
            else break
        }
        cif[i] = 1 - exp(-h * exp(xb[i]))
    }
    sumc = st_data(sel, sumv)
    ssc = st_data(sel, ssv)
    st_store(sel, sumv, sumc :+ cif)
    st_store(sel, ssv, ssc :+ cif :^ 2)
}

/* ------------------------------------------------------------------------
   Baseline cumulative subhazard WITHOUT a K-row Stata matrix.

   The baseline has one row per distinct cause-event time, so K ~ n/2.  Creating
   a Stata matrix with K rows is O(K^2) -- Stata builds one dimension name per
   row, and the cost is per NAME, not per element, so it hits st_matrix(), mkmat,
   a plain copy and a transpose alike (6.5 s at K = 40,000, 38.6 s at K = 95,600).
   That round trip, not the forward-backward scan, was this package's entire
   superlinearity: ablating it moved the runtime slope from 1.65 to 1.05.

   Postestimation needs the baseline's VALUES, not a Stata matrix.  So rebuild it
   in Mata in one linear pass from the estimation sample and e(b).  It re-runs the
   same _finegray_basehazard() the fit ran, so it recovers the SAME curve.

   Caveat, documented deliberately: the rebuild is not BIT-identical to the cached
   curve -- ~1 ulp (measured 3.8e-15 on a CIF).  _finegray_basehazard breaks tied
   event times by row index, and the rebuild reads rows in current data order while
   the fit read them in its own sorted order, so tied contributions accumulate in a
   different rounding order.  Both paths are individually deterministic and 1 ulp is
   far below any reported precision, so this is a reproducibility footnote, not a
   bug -- but it is why a CIF can change in its last bit depending on whether the
   Mata cache was warm (a bootstrap in the same session bumps the seq and forces the
   rebuild).  To get the fit-time curve exactly, fit with basehaz: e(basehaz) is
   read directly and no rebuild happens.
   ------------------------------------------------------------------------ */
real matrix _finegray_bh_rebuild(
    string scalar zvars,
    string scalar events_str,
    real scalar cause,
    real scalar censval,
    string scalar byg_str,
    string scalar tg_str,
    string scalar tousevar,
    string scalar t0var)
{
    real matrix Z
    real colvector t, t0, delta, event_type, beta, byg_id, tg_id, G
    real scalar n

    Z = st_data(., tokens(zvars), tousevar)
    t = st_data(., "_t", tousevar)
    t0 = st_data(., t0var, tousevar)
    delta = st_data(., "_d", tousevar)
    event_type = st_data(., events_str, tousevar)
    n = rows(Z)
    beta = st_matrix("e(b)")'
    if (byg_str != "") byg_id = st_data(., byg_str, tousevar)
    else               byg_id = J(n, 1, 1)
    if (tg_str != "")  tg_id = st_data(., tg_str, tousevar)
    else               tg_id = J(n, 1, 1)

    /* post-estimation recompute: quiet=1, the fit already printed any note */
    G = _finegray_km_censor(t, delta, censval, event_type, byg_id, t0, 1)
    return(_finegray_basehazard(t, delta, cause, censval, event_type, Z, beta,
        G, byg_id, t0, tg_id))
}

/* ------------------------------------------------------------------------
   The baseline cache: the curve kept in MATA, where it is free.

   A Stata matrix costs O(K^2) to create because of its dimension-name stripe.
   A MATA matrix has no stripe -- it is just numbers -- so holding the same K x 2
   curve in Mata costs nothing.  That is the whole trick: the baseline lives in
   Mata across commands, and only becomes a Stata matrix if the user asks for
   e(basehaz).

   This cache exists because postestimation cannot always rebuild.  `predict, cif'
   on NEW data is a documented workflow: the user drops the estimation data, types
   a fresh covariate profile, and predicts.  The estimation sample is then gone,
   so there is nothing to rebuild the baseline FROM -- and the old code only
   worked because it read a Stata matrix out of e(), which survives `drop _all'.

   The cache is keyed by a per-fit sequence number, posted as e(bh_seq).  A stale
   cache is the silent-wrong-answer failure mode here (predicting from the
   PREVIOUS fit's baseline at rc 0), so a consumer must present the seq it expects
   and gets nothing back unless it matches.  `mata clear' / `discard' wipe the
   cache, which is safe: the consumer then falls back to rebuilding, or errors.
   ------------------------------------------------------------------------ */
void _finegray_bh_store(real matrix bh)
{
    external real matrix    _finegray_bh_cache
    external real scalar    _finegray_bh_seq

    if (_finegray_bh_seq == J(1,1,.) | _finegray_bh_seq >= .) _finegray_bh_seq = 0
    _finegray_bh_cache = bh
    _finegray_bh_seq   = _finegray_bh_seq + 1
    st_local("_fg_bh_seq", strofreal(_finegray_bh_seq, "%18.0g"))
}

/* Does the cache hold the curve for THIS fit?  Sets the caller's local to 1/0. */
void _finegray_bh_have(real scalar seq, string scalar lname)
{
    external real matrix _finegray_bh_cache
    external real scalar _finegray_bh_seq
    real scalar ok

    ok = 0
    if (_finegray_bh_seq < . & _finegray_bh_seq == seq) {
        if (rows(_finegray_bh_cache) > 0) ok = 1
    }
    st_local(lname, strofreal(ok))
}

/* Snapshot / restore the single-slot baseline cache around a side computation.
   The cache holds ONE fit's curve, keyed by _finegray_bh_seq.  finegray_predict's
   bootstrap refits each call finegray again -- every refit overwrites the cache
   with its own baseline and bumps the seq -- so after the bootstrap the global
   cache belongs to the LAST resample while the restored e(bh_seq) still names the
   ORIGINAL fit.  A subsequent `predict, cif' on NEW data then finds a seq
   mismatch, tries to rebuild from an estimation sample the user has since
   dropped, and errors r(459).  The bootstrap SE itself is unaffected -- it reads
   e(basehaz) on each refit, never this cache -- so stashing the cache before the
   loop and restoring it after leaves the fit's baseline resolvable afterward at
   zero cost to the SE.  Copying externals is O(K); it does NOT build a Stata
   matrix (that would reintroduce the O(K^2) cost the cache exists to avoid). */
void _finegray_bh_stash()
{
    external real matrix _finegray_bh_cache, _finegray_bh_cache_stash
    external real scalar _finegray_bh_seq,   _finegray_bh_seq_stash

    _finegray_bh_cache_stash = _finegray_bh_cache
    _finegray_bh_seq_stash   = _finegray_bh_seq
}
void _finegray_bh_unstash()
{
    external real matrix _finegray_bh_cache, _finegray_bh_cache_stash
    external real scalar _finegray_bh_seq,   _finegray_bh_seq_stash

    _finegray_bh_cache = _finegray_bh_cache_stash
    _finegray_bh_seq   = _finegray_bh_seq_stash
}

/* Step lookup against the cached curve.  Refuses a mismatched seq rather than
   answering from another fit's baseline. */
void _finegray_step_lookup_cached(
    real scalar seq,
    string scalar tvar,
    string scalar H0var,
    string scalar tousevar)
{
    external real matrix _finegray_bh_cache
    external real scalar _finegray_bh_seq
    real colvector touse_vec, sel, times, H0

    if (_finegray_bh_seq >= . | _finegray_bh_seq != seq) {
        errprintf("finegray: cached baseline does not belong to the active fit\n")
        exit(error(459))
    }
    touse_vec = st_data(., tousevar)
    sel = selectindex(touse_vec)
    if (length(sel) == 0) return
    times = st_data(sel, tvar)
    H0 = _finegray_step_core(_finegray_bh_cache, times)
    st_store(sel, H0var, H0)
}

/* The thinned grid, taken from the cached curve (finegray_cif's curve mode). */
void _finegray_bh_grid_cached(real scalar seq, real scalar maxpts,
    string scalar outmat)
{
    external real matrix _finegray_bh_cache
    external real scalar _finegray_bh_seq
    real colvector idx
    real scalar nbh, step, r, last

    if (_finegray_bh_seq >= . | _finegray_bh_seq != seq) {
        errprintf("finegray: cached baseline does not belong to the active fit\n")
        exit(error(459))
    }
    nbh = rows(_finegray_bh_cache)
    st_local("_fg_nbh", strofreal(nbh))
    if (nbh == 0) return

    step = ceil(nbh / maxpts)
    idx = J(0, 1, .)
    last = 0
    for (r = 1; r <= nbh; r = r + step) {
        idx = idx \ r
        last = r
    }
    if (last < nbh) idx = idx \ nbh
    st_matrix(outmat, _finegray_bh_cache[idx, 1])
}

/* Shared binary-search step lookup: largest baseline time <= each element of
   times, returning its cumulative subhazard (0 before the first event time). */
real colvector _finegray_step_core(real matrix bh, real colvector times)
{
    real colvector H0
    real scalar i, lo, hi, mid, n_bh, n

    n_bh = rows(bh)
    n = rows(times)
    H0 = J(n, 1, 0)
    for (i = 1; i <= n; i++) {
        if (times[i] >= .) continue
        lo = 1
        hi = n_bh
        while (lo <= hi) {
            mid = trunc((lo + hi) / 2)
            if (bh[mid, 1] <= times[i]) lo = mid + 1
            else hi = mid - 1
        }
        if (hi >= 1) H0[i] = bh[hi, 2]
    }
    return(H0)
}

/* Step lookup with the baseline rebuilt in Mata -- the path taken when the user
   did not ask for e(basehaz).  Same values as _finegray_step_lookup(); it just
   never routes the curve through a Stata matrix. */
void _finegray_step_lookup_direct(
    string scalar zvars,
    string scalar events_str,
    real scalar cause,
    real scalar censval,
    string scalar byg_str,
    string scalar tg_str,
    string scalar est_touse,
    string scalar t0var,
    string scalar tvar,
    string scalar H0var,
    string scalar eval_touse)
{
    real matrix bh
    real colvector touse_vec, sel, times, H0

    bh = _finegray_bh_rebuild(zvars, events_str, cause, censval, byg_str,
        tg_str, est_touse, t0var)
    touse_vec = st_data(., eval_touse)
    sel = selectindex(touse_vec)
    if (length(sel) == 0) return
    times = st_data(sel, tvar)
    H0 = _finegray_step_core(bh, times)
    st_store(sel, H0var, H0)
}

/* The THINNED baseline time grid for finegray_cif's curve mode.  Posts at most
   maxpts+1 rows, so the Stata matrix it creates is small and its O(rows^2) cost
   is nil -- the point of the exercise is never to hand Stata the full K rows.
   The thinning indices reproduce the former Stata-side loop exactly (stride, then
   always close on the last row), so the grid is unchanged to the last bit. */
void _finegray_bh_grid(
    string scalar zvars,
    string scalar events_str,
    real scalar cause,
    real scalar censval,
    string scalar byg_str,
    string scalar tg_str,
    string scalar est_touse,
    string scalar t0var,
    real scalar maxpts,
    string scalar outmat)
{
    real matrix bh
    real colvector idx
    real scalar nbh, step, r, last

    bh = _finegray_bh_rebuild(zvars, events_str, cause, censval, byg_str,
        tg_str, est_touse, t0var)
    nbh = rows(bh)
    st_local("_fg_nbh", strofreal(nbh))
    if (nbh == 0) return

    step = ceil(nbh / maxpts)
    idx = J(0, 1, .)
    last = 0
    for (r = 1; r <= nbh; r = r + step) {
        idx = idx \ r
        last = r
    }
    if (last < nbh) idx = idx \ nbh
    st_matrix(outmat, bh[idx, 1])
}

/* Step function lookup via binary search: O(n log n_bh) instead of O(n * n_bh).
   For each observation in the touse sample, finds the largest basehaz time <= t
   and assigns the corresponding cumulative hazard to H0var.  Used when the user
   asked for e(basehaz) and the matrix therefore exists; st_matrix() READS an e()
   matrix for free, it is only CREATING one that is quadratic. */
void _finegray_step_lookup(
    string scalar bh_matname,
    string scalar tvar,
    string scalar H0var,
    string scalar tousevar)
{
    real matrix bh
    real colvector times, H0, touse_vec, sel

    bh = st_matrix(bh_matname)
    touse_vec = st_data(., tousevar)
    sel = selectindex(touse_vec)
    if (length(sel) == 0) return
    times = st_data(sel, tvar)
    H0 = _finegray_step_core(bh, times)
    st_store(sel, H0var, H0)
}

/* Assign Schoenfeld residuals from matrix to variables via index lookup.
   O(N) instead of O(N * n_fail) from forvalues replace-if loops.
   ccvar holds cumulative cause-event index (1..n_fail) for cause events,
   missing for non-events. varnames are the target variable names. */
void _finegray_assign_schoenfeld_vars(
    string scalar matname,
    string scalar ccvar,
    string rowvector varnames,
    real scalar p)
{
    real matrix sch
    real colvector cc, vals
    real scalar i, n, col

    sch = st_matrix(matname)
    cc = st_data(., ccvar)
    n = rows(cc)

    for (col = 1; col <= p; col++) {
        vals = J(n, 1, .)
        for (i = 1; i <= n; i++) {
            if (cc[i] < . & cc[i] >= 1) {
                vals[i] = sch[cc[i], col + 1]
            }
        }
        st_store(., varnames[col], vals)
    }
}

/* ========================================================================
   LI, SCHEIKE & ZHANG (2015) CUMULATIVE-RESIDUAL GOODNESS OF FIT
   Lifetime Data Anal 21(2):197-217.  Appendix eq. (17), pp.215-216.

   Four statistics, all suprema of a cumulative sum of weighted martingale
   residuals whose null distribution comes from a Lin-Wei-Ying multiplier
   bootstrap rather than from a table:

     proportionality  B^(p)_j(t) = {I^-1_jj}^(1/2) U_j(bhat,t)
     overall prop     sup_t sum_j |{I^-1_jj}^(1/2) U_j(bhat,t)|
     functional form  B^(f)_j(z) = sum_i int 1{Z_ij <= z} w_i dM_i
     link function    B^(l)(x)   = sum_i int 1{bhat'Z_i <= x} w_i dM_i

   THE INFLUENCE MATRIX HAS THREE TERMS, NOT TWO.  eq. (17):

     term 1   int_0^t {f - g} w dM^1_i
     term 2   C'(b0,t,x) Omega^-1 (eta_i + psi_i)
     term 3   -q^(f)_i(t,x)

   crskdiag -- the paper's own companion package -- simulates only terms 1
   and 2 (src/diag.cc:138).  Gate L2 established numerically that term 3
   exists to CANCEL the psi that term 2 introduces: with a correct psi,
   dropping term 3 moves p by ~0.0005, but crskdiag's default
   (minor_included = 1) adds a DEFECTIVE psi with no cancelling term 3 and
   moves the edge sd from 4e-16 to 3.3e-01.  We implement all three.
   See _take_action/finegray/FINDINGS.md sections 9 and 10.

   FOUR THINGS THAT ARE EASY TO GET WRONG
   --------------------------------------
   1. The standardizing factor is {I^-1_jj}^(1/2) -- the SQUARE ROOT of the
      jth diagonal of the INVERSE INFORMATION, not a sandwich SE.  It comes
      from _finegray_score_info, never from e(V).  The paper's own Appendix
      (p.215) drops the sqrt and contradicts its main text (p.201, p.202
      twice); the main text wins.  Reading e(V) or dropping the sqrt gives
      plausible numbers that CANCEL in all three per-covariate tests and are
      wrong only in the overall statistic -- so it is checked there.
   2. Term 2 always uses eta_i + psi_i, whether or not the fit used
      `nuisance'.  psi here is a property of eq. (17), not of e(V); gating
      it on the variance option would silently change the test by option.
   3. Breslow tie multiplicity: a time carrying d tied cause-1 events
      contributes d times.  Looping over distinct event TIMES instead of
      event SUBJECTS is invisible on one-event-per-time fixtures and ~167%
      wrong with ties.
   4. Term 3 must be FACTORISED.  The literal definition is a triple loop
      over (subject, grid point, event time); it is what forced the paper's
      authors into C++.  Because w2_l(s) = ev_l Ghat(s)/Ghat(X_l) separates
      as c_l * Gev[s], the inner bracket collapses to

        q(u, grid) = A_u(grid) * P1(u) - C_u * P2(u, grid)

      turning O(n * ngrid * m) into O(n * ngrid).  The factorisation is
      validated against a literal triple loop in
      _take_action/finegray/R/10_gate_L3_naive_check.R -- NOT against the
      fast path in R/09, which shares the same algebra and would share a bug.

   RIGHT CENSORING, ONE CENSORING STRATUM.  The paper has no entry time
   anywhere -- not section 2, not the Appendix, not the simulations, not
   either data example -- and its Ghat_c is the MARGINAL Kaplan-Meier.  Both
   are refused here rather than extrapolated.  The ado-level gates in
   finegray_gof.ado are the user-facing message; these are the backstop that
   makes a bypass impossible rather than merely unlikely.

   FREE SELF-CHECK.  W_i(t_max) = 0 exactly, for every subject, in all four
   tests: at the right edge the three terms collapse to eta_i, -(eta+psi)_i
   and +psi_i.  It catches errors in C(.), Omega^-1, tie multiplicity and
   term 3 simultaneously, costs nothing, and is strictly stronger than the
   usual colSums(eta) ~ 0.  _finegray_gof_edge() returns it.
   ======================================================================== */

struct _finegray_gof_sc {
    real matrix    Z, W, xbar, dM, eta, psi, Oi
    real colvector X, ev, Gmin, S0, dk, ft, Gev, ut, ai, Ysafe, dNc
    real colvector iscens, iscomp, rowsdM
    real scalar    n, p, m, nu
}

/* Position of each value on a sorted grid; 0 if absent.  Exact equality is
   the right test because the grids are built from these very values. */
real colvector _finegray_gof_pos(real colvector vals, real colvector grid)
{
    real scalar i, lo, hi, mid, n, g
    real colvector out

    n = rows(vals)
    g = rows(grid)
    out = J(n, 1, 0)
    for (i = 1; i <= n; i++) {
        lo = 1
        hi = g
        while (lo <= hi) {
            mid = floor((lo + hi) / 2)
            if (grid[mid] < vals[i]) lo = mid + 1
            else if (grid[mid] > vals[i]) hi = mid - 1
            else {
                out[i] = mid
                break
            }
        }
    }
    return(out)
}

/* Risk-set scaffolding shared by all four statistics, built once per fit. */
struct _finegray_gof_sc scalar _finegray_gof_scaffold(
    real colvector t,
    real colvector delta,
    real scalar cause,
    real scalar censval,
    real colvector event_type,
    real matrix Z,
    real colvector beta,
    real colvector G,
    real colvector byg_id,
    real colvector t0,
    real colvector tg_id)
{
    struct _finegray_gof_sc scalar sc
    real colvector levels, gidx, is_cause, ki, Y, cnt, score
    real matrix info
    real scalar k, i

    sc.n = rows(t)
    sc.p = cols(Z)

    if (colmax(t0) > 0) {
        errprintf("finegray_gof: the Li/Scheike/Zhang (2015) residual process ")
        errprintf("is derived for\n")
        errprintf("       right censoring only; it is not defined under ")
        errprintf("delayed entry\n")
        exit(198)
    }
    levels = uniqrows(byg_id)
    if (rows(levels) > 1) {
        errprintf("finegray_gof: the test is built on the MARGINAL censoring ")
        errprintf("Kaplan-Meier;\n")
        errprintf("       it is not defined with stratified censoring weights\n")
        exit(198)
    }
    gidx = _finegray_group_index(byg_id, levels)

    sc.Z = Z
    sc.X = t
    sc.ev = exp(Z * beta)
    is_cause = (event_type :== cause) :& (delta :== 1)
    sc.iscomp = (event_type :!= cause) :& (event_type :!= censval) :&
        (delta :== 1)
    sc.iscens = (delta :== 0) :| (event_type :== censval)

    /* Ghat(X_i-) per subject, and Ghat(ft_k-) on the cause-event grid.
       _finegray_G_at_times advances on strict <, so both are LEFT limits --
       the convention cmprsk::crr and stcrreg both use. */
    sc.Gmin = _finegray_G_minus(gidx, _finegray_G_at_times(t, G, byg_id, t))
    sc.ft = uniqrows(select(t, is_cause))
    sc.m = rows(sc.ft)
    sc.Gev = _finegray_G_at_times(t, G, byg_id, sc.ft)[., 1]

    ki = _finegray_gof_pos(t, sc.ft)
    sc.dk = J(sc.m, 1, 0)
    for (i = 1; i <= sc.n; i++)
        if (is_cause[i]) sc.dk[ki[i]] = sc.dk[ki[i]] + 1

    /* Subdistribution at-risk weight: 1 while still at risk, Ghat(s-)/Ghat(X-)
       once a competing event has occurred, 0 after censoring. */
    sc.W = J(sc.n, sc.m, 0)
    for (k = 1; k <= sc.m; k++)
        sc.W[., k] = ((t :>= sc.ft[k]) :+
            ((t :< sc.ft[k]) :& sc.iscomp) :* (sc.Gev[k] :/ sc.Gmin)) :* sc.ev

    sc.S0 = colsum(sc.W)'
    sc.xbar = (sc.W' * Z) :/ sc.S0

    sc.dM = -sc.W :* (sc.dk :/ sc.S0)'
    for (i = 1; i <= sc.n; i++)
        if (is_cause[i]) sc.dM[i, ki[i]] = sc.dM[i, ki[i]] + 1
    sc.rowsdM = rowsum(sc.dM)

    sc.ut = uniqrows(t)
    sc.nu = rows(sc.ut)
    sc.ai = _finegray_gof_pos(t, sc.ut)
    cnt = J(sc.nu, 1, 0)
    sc.dNc = J(sc.nu, 1, 0)
    for (i = 1; i <= sc.n; i++) {
        cnt[sc.ai[i]] = cnt[sc.ai[i]] + 1
        if (sc.iscens[i]) sc.dNc[sc.ai[i]] = sc.dNc[sc.ai[i]] + 1
    }
    /* Y(u) = #{X >= u}: n minus the number strictly below u. */
    Y = sc.n :- (runningsum(cnt) - cnt)
    sc.Ysafe = Y :+ (Y :== 0)

    sc.eta = _finegray_score_residuals(t, delta, cause, censval, event_type,
        Z, beta, G, byg_id, t0, tg_id)
    sc.psi = _finegray_psi_residuals(t, delta, cause, censval, event_type,
        Z, beta, G, byg_id, t0)
    _finegray_score_info(t, delta, cause, censval, event_type, Z, beta, G,
        byg_id, score, info, t0, tg_id)
    sc.Oi = invsym(info)

    return(sc)
}

/* Standardizing factors {I^-1_jj}^(1/2), one per covariate. */
real colvector _finegray_gof_scale(struct _finegray_gof_sc scalar sc)
{
    return(sqrt(diagonal(sc.Oi)))
}

/* term 3 = -int_0^{X_i} {q(u,.)/Y(u)} dM^c_i(u), given q on the u-grid. */
real matrix _finegray_gof_term3(
    struct _finegray_gof_sc scalar sc,
    real matrix qmat)
{
    real matrix cumdL, T3
    real scalar a, i, ng

    ng = cols(qmat)
    cumdL = qmat :* (sc.dNc :/ (sc.Ysafe :^ 2))
    for (a = 2; a <= sc.nu; a++) cumdL[a, .] = cumdL[a, .] + cumdL[a - 1, .]

    T3 = J(sc.n, ng, 0)
    for (i = 1; i <= sc.n; i++) {
        T3[i, .] = -cumdL[sc.ai[i], .]
        if (sc.iscens[i])
            T3[i, .] = T3[i, .] + qmat[sc.ai[i], .] :/ sc.Ysafe[sc.ai[i]]
    }
    return(T3)
}

/* Proportionality process for covariate j, indexed by TIME (f = Z_j fixed,
   the cumulative sum run along the event grid).  Returns the n x m influence
   matrix; obs receives the observed process. */
real matrix _finegray_gof_prop(
    struct _finegray_gof_sc scalar sc,
    real scalar j,
    real colvector obs)
{
    real matrix W1, Cinc, Ct, W2, qmat, Zc
    real colvector cl, accA, accC, Au, Cu, base, base2, cum1, cum2, row
    real scalar k, i, a, s0a, off1, off2

    /* NOTE the explicit J(n,1,1) * rowvector.  Mata's c-conformability does
       NOT broadcast an n x 1 against a 1 x m the way R and NumPy do: a colon
       operator accepts a column vector with matching ROWS or a row vector
       with matching COLUMNS, never the outer combination of the two.  The R
       reference this was ported from relies on that broadcast throughout, so
       every such site had to be expanded by hand. */
    W1 = (sc.Z[., j] :- J(sc.n, 1, 1) * sc.xbar[., j]') :* sc.dM
    for (k = 2; k <= sc.m; k++) W1[., k] = W1[., k] + W1[., k - 1]
    obs = colsum(W1)'

    Cinc = J(sc.m, sc.p, 0)
    for (k = 1; k <= sc.m; k++) {
        Zc = sc.Z :- sc.xbar[k, .]
        Cinc[k, .] = -(sc.dk[k] / sc.S0[k]) *
            colsum(sc.Z[., j] :* sc.W[., k] :* Zc)
    }
    Ct = Cinc
    for (k = 2; k <= sc.m; k++) Ct[k, .] = Ct[k, .] + Ct[k - 1, .]
    W2 = ((sc.eta + sc.psi) * sc.Oi) * Ct'

    /* q_j(u,t) via the factorisation: A_u and C_u are running sums over
       competing-event subjects with X < u; the s-sums are running sums over
       the event grid, capped at t and tailed at u. */
    cl = sc.ev :/ sc.Gmin
    accA = J(sc.nu, 1, 0)
    accC = J(sc.nu, 1, 0)
    for (i = 1; i <= sc.n; i++) {
        if (sc.iscomp[i]) {
            accA[sc.ai[i]] = accA[sc.ai[i]] + cl[i] * sc.Z[i, j]
            accC[sc.ai[i]] = accC[sc.ai[i]] + cl[i]
        }
    }
    Au = runningsum(accA) - accA
    Cu = runningsum(accC) - accC

    base = sc.Gev :* sc.dk :/ sc.S0
    base2 = base :* sc.xbar[., j]
    cum1 = runningsum(base)
    cum2 = runningsum(base2)

    qmat = J(sc.nu, sc.m, 0)
    s0a = 1
    for (a = 1; a <= sc.nu; a++) {
        while (s0a <= sc.m) {
            if (sc.ft[s0a] >= sc.ut[a]) break
            s0a++
        }
        if (s0a > sc.m) break
        off1 = (s0a > 1 ? cum1[s0a - 1] : 0)
        off2 = (s0a > 1 ? cum2[s0a - 1] : 0)
        /* Built full-length and then zeroed below s0a rather than assigned
           into a slice: a colvector subscripted by a rowvector index range
           does NOT keep its orientation, and the mismatch surfaces as a
           conformability error far from the subscript that caused it. */
        row = Au[a] :* (cum1 :- off1) - Cu[a] :* (cum2 :- off2)
        if (s0a > 1) row[|1 \ s0a - 1|] = J(s0a - 1, 1, 0)
        qmat[a, .] = row'
    }

    return(W1 + W2 + _finegray_gof_term3(sc, qmat))
}

/* Functional-form / link process, indexed by a COVARIATE VALUE with the time
   integral run to infinity.  fvar is Z_j for functional form and bhat'Z for
   the link.  grid and obs are set on return. */
real matrix _finegray_gof_xaxis(
    struct _finegray_gof_sc scalar sc,
    real colvector fvar,
    real colvector grid,
    real colvector obs)
{
    real matrix gbar, W1, Cx, W2, Au, P2, qmat, cumG, pre, ZA
    real colvector cl, Cu, base, P1, cum1, a_i, ford, cntg, lastpos, r0, rs
    real scalar k, i, a, ng, s0a

    grid = uniqrows(fvar)
    ng = rows(grid)

    /* THE INDICATOR MATRIX F = 1{fvar_i <= x} IS NEVER MATERIALISED.
       It is n x ngrid, and for the link test ngrid = n, so at n = 4000 F alone
       is 128 MB -- on top of the n x ngrid process matrix that genuinely has
       to exist.  Every place the R reference writes an F product, the same
       quantity is a PREFIX SUM over subjects sorted by fvar, because
       1{fvar_i <= grid_r} is exactly "i comes at or before rank r".  That
       replaces an O(m*n*ngrid) contraction with an O(n*m) running sum.

       r0[i] is subject i's own position on the grid, so the columns where the
       indicator is 1 are exactly r0[i]..ngrid -- a contiguous slice, which is
       why the accumulations below are range assignments rather than products
       against a dense 0/1 matrix. */
    r0 = _finegray_gof_pos(fvar, grid)
    ford = order(fvar, 1)
    cntg = J(ng, 1, 0)
    for (i = 1; i <= sc.n; i++) cntg[r0[i]] = cntg[r0[i]] + 1
    lastpos = runningsum(cntg)

    pre = sc.W[ford, .]
    for (i = 2; i <= sc.n; i++) pre[i, .] = pre[i, .] + pre[i - 1, .]
    gbar = pre[lastpos, .]' :/ sc.S0

    /* 1{fvar_i <= x} does not depend on u, so its part of term 1 is the
       subject's total dM times the indicator; gbar does depend on u and is
       contracted against dM over the event grid. */
    W1 = -(sc.dM * gbar)
    for (i = 1; i <= sc.n; i++)
        W1[|i, r0[i] \ i, ng|] = W1[|i, r0[i] \ i, ng|] :+ sc.rowsdM[i]
    rs = sc.rowsdM[ford]
    obs = runningsum(rs)[lastpos]

    /* C(x) FACTORISED OUT OF ITS EVENT-TIME LOOP.  Written literally,
          C(x) = -sum_k (d_k/S0_k) (Z - xbar_k)' diag(W[.,k]) F
       is m separate p x n by n x ngrid products: O(m*n*ngrid*p), the single
       cubic term in this routine and measured at 40x per doubling of n.
       Expanding the bracket lets both halves collapse to ONE product each:

          sum_k c_k (Z:*W[.,k])' F = (Z :* a)' F,   a_i = sum_k c_k W[i,k]
          -sum_k c_k xbar_k' (W[.,k]' F)            = (xbar :* d)' gbar

       using W[.,k]'F = S0_k gbar[k,.] and c_k = -d_k/S0_k.  The first is then
       another prefix sum; the second is a single m-length contraction. */
    a_i = -(sc.W * (sc.dk :/ sc.S0))
    ZA = sc.Z :* a_i
    pre = ZA[ford, .]
    for (i = 2; i <= sc.n; i++) pre[i, .] = pre[i, .] + pre[i - 1, .]
    Cx = pre[lastpos, .]' + (sc.xbar :* sc.dk)' * gbar
    W2 = ((sc.eta + sc.psi) * sc.Oi) * Cx

    cl = sc.ev :/ sc.Gmin
    Au = J(sc.nu, ng, 0)
    Cu = J(sc.nu, 1, 0)
    for (i = 1; i <= sc.n; i++) {
        if (sc.iscomp[i]) {
            Au[|sc.ai[i], r0[i] \ sc.ai[i], ng|] =
                Au[|sc.ai[i], r0[i] \ sc.ai[i], ng|] :+ cl[i]
            Cu[sc.ai[i]] = Cu[sc.ai[i]] + cl[i]
        }
    }
    for (a = 2; a <= sc.nu; a++) Au[a, .] = Au[a, .] + Au[a - 1, .]
    for (a = sc.nu; a >= 2; a--) Au[a, .] = Au[a - 1, .]
    Au[1, .] = J(1, ng, 0)
    Cu = runningsum(Cu) - Cu

    base = sc.Gev :* sc.dk :/ sc.S0
    cum1 = runningsum(base)
    cumG = base :* gbar
    for (k = 2; k <= sc.m; k++) cumG[k, .] = cumG[k, .] + cumG[k - 1, .]

    P1 = J(sc.nu, 1, 0)
    P2 = J(sc.nu, ng, 0)
    s0a = 1
    for (a = 1; a <= sc.nu; a++) {
        while (s0a <= sc.m) {
            if (sc.ft[s0a] >= sc.ut[a]) break
            s0a++
        }
        if (s0a > sc.m) break
        P1[a] = cum1[sc.m] - (s0a > 1 ? cum1[s0a - 1] : 0)
        P2[a, .] = cumG[sc.m, .] -
            (s0a > 1 ? cumG[s0a - 1, .] : J(1, ng, 0))
    }
    qmat = Au :* P1 - Cu :* P2

    return(W1 + W2 + _finegray_gof_term3(sc, qmat))
}

/* max_i |W_i(edge)| -- the free self-check.  Must be ~0 relative to the
   scale of eta.  Nonzero means C(.), Omega^-1, tie multiplicity or term 3
   is wrong, and it says so before any p-value is computed. */
real scalar _finegray_gof_edge(real matrix Wp)
{
    return(max(abs(Wp[., cols(Wp)])))
}

/* Multiplier-bootstrap block size.  A function rather than a literal so the
   two bootstrap routines cannot drift apart: they must consume the RNG
   stream identically or the overall statistic stops being comparable with
   the per-covariate ones computed from the same seed. */
real scalar _finegray_gof_bs()
{
    return(64)
}

/* Lin-Wei-Ying multiplier bootstrap.  Only the V_i ~ N(0,1) are redrawn:
   Wp is computed ONCE and nothing is refitted per replication.  The caller
   sets the seed, so `set seed' governs reproducibility uniformly.

   p is counted with >= : a simulated supremum that TIES the observed one
   counts toward the p-value.  p can be exactly 0 and must be displayed as
   < 1/K rather than as a bare 0.000. */
real rowvector _finegray_gof_boot(
    real matrix Wp,
    real colvector obs,
    real scalar scale,
    real scalar K)
{
    real scalar sup_obs, cnt, k, n, b0, nb
    real matrix B

    sup_obs = max(abs(obs :* scale))
    cnt = 0
    n = rows(Wp)
    /* Drawn in blocks rather than one replication at a time.  Each
       replication is a 1 x n by n x ngrid product -- a rank-1 update that
       leaves most of the matrix-multiply throughput on the floor.  Blocking
       turns K of those into K/BS real matrix products at identical flop count
       and ~3x the speed.  BS is a fixed constant, not tuned per call, because
       Mata fills a drawn matrix in a set order: changing the block size
       changes which draw lands where and therefore changes the p-value for a
       given seed.  Same seed, same block size, same answer. */
    for (b0 = 1; b0 <= K; b0 = b0 + _finegray_gof_bs()) {
        nb = min((_finegray_gof_bs(), K - b0 + 1))
        B = rnormal(nb, n, 0, 1) * Wp
        for (k = 1; k <= nb; k++)
            if (max(abs(B[k, .] :* scale)) >= sup_obs) cnt++
    }
    return((sup_obs, cnt / K))
}

/* Overall proportionality: sup_t sum_j |{I^-1_jj}^(1/2) U_j(t)|.  All p
   processes are driven by the SAME V draw within a replication -- they are
   not independent tests being combined, they are one statistic.

   This is the only test in which the standardizing factor does not cancel,
   so it is the only place a bug in that factor is visible. */
/* Driver called by finegray_gof.ado.  Reads the estimation sample, builds the
   scaffolding once, runs whichever tests were requested, and hands results
   back as Stata matrices.

   The caller has already refused delayed entry, stratified censoring weights
   and clustering; the scaffold refuses the first two again rather than trust
   that, because a refusal that exists only in the ado is one `capture' away
   from being bypassed.

   funcidx carries the COLUMN POSITIONS in Z of the covariates named in
   funcform(), not their names: the design matrix here may be a reconstructed
   factor-variable expansion whose column names no longer match anything the
   user typed. */
void _finegray_gof_run(
    string scalar covvars,
    string scalar evvar,
    real scalar cause,
    real scalar censval,
    string scalar t0var,
    real scalar do_prop,
    real rowvector funcidx,
    real scalar do_link,
    real scalar K)
{
    struct _finegray_gof_sc scalar sc
    real colvector t, d, ct, t0, one, G, beta, obs, grid, scl
    real matrix Z, Wp, U, pres, fres, Wall
    real scalar n, p, j, nf, i

    t  = st_data(., "_t")
    d  = st_data(., "_d")
    ct = st_data(., evvar)
    Z  = st_data(., covvars)
    n  = rows(t)
    p  = cols(Z)
    t0 = (t0var == "" ? J(n, 1, 0) : st_data(., t0var))
    one = J(n, 1, 1)
    beta = st_matrix("_finegray_gof_b")'

    G  = _finegray_km_censor(t, d, censval, ct, one, t0, 1)
    sc = _finegray_gof_scaffold(t, d, cause, censval, ct, Z, beta, G, one,
                                t0, one)
    scl = _finegray_gof_scale(sc)
    st_matrix("_finegray_gof_scale", scl')

    if (do_prop) {
        pres = J(p, 2, 0)
        U = J(sc.m, p, 0)
        /* All p processes are retained, stacked side by side, because the
           OVERALL statistic needs every one of them driven by the SAME
           multiplier draw within a replication -- it is a single statistic,
           not p separate tests combined afterwards.  Stacked into one
           n x (m*p) matrix rather than a pointer array: `&(f(...))' takes the
           address of a temporary, and the obvious fix of assigning to a named
           variable first makes every pointer alias that one variable, so each
           iteration would silently overwrite the last.
           Cost is n*m*p doubles -- ~200 MB at n=4000, m=1278, p=5. */
        Wall = J(n, 0, 0)
        for (j = 1; j <= p; j++) {
            Wp = _finegray_gof_prop(sc, j, obs)
            Wall = Wall, Wp
            U[., j] = obs
            pres[j, .] = _finegray_gof_boot(Wp, obs, scl[j], K)
        }
        st_matrix("_finegray_gof_prop_res", pres)
        st_matrix("_finegray_gof_overall",
                  _finegray_gof_boot_overall(Wall, U, scl, K))
    }

    nf = cols(funcidx)
    if (nf > 0 & funcidx[1] > 0) {
        fres = J(nf, 2, 0)
        for (i = 1; i <= nf; i++) {
            j = funcidx[i]
            Wp = _finegray_gof_xaxis(sc, Z[., j], grid, obs)
            fres[i, .] = _finegray_gof_boot(Wp, obs, 1, K)
        }
        st_matrix("_finegray_gof_func_res", fres)
    }

    if (do_link) {
        Wp = _finegray_gof_xaxis(sc, Z * beta, grid, obs)
        st_matrix("_finegray_gof_link_res", _finegray_gof_boot(Wp, obs, 1, K))
    }
}

real rowvector _finegray_gof_boot_overall(
    real matrix Wall,
    real matrix U,
    real colvector scale,
    real scalar K)
{
    real scalar sup_obs, cnt, k, j, p, n, m, b0, nb
    real matrix acc, V, B

    p = cols(U)
    m = rows(U)
    n = rows(Wall)
    sup_obs = max(rowsum(abs(U :* scale')))
    cnt = 0
    for (b0 = 1; b0 <= K; b0 = b0 + _finegray_gof_bs()) {
        nb = min((_finegray_gof_bs(), K - b0 + 1))
        V = rnormal(nb, n, 0, 1)
        B = V * Wall
        acc = J(nb, m, 0)
        for (j = 1; j <= p; j++)
            acc = acc +
                abs(B[|1, (j - 1) * m + 1 \ nb, j * m|] :* scale[j])
        for (k = 1; k <= nb; k++)
            if (max(acc[k, .]) >= sup_obs) cnt++
    }
    return((sup_obs, cnt / K))
}

end
