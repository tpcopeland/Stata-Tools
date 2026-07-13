*! _finegray_mata Version 1.1.4  2026/07/10
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

* Loading guard
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
    real colvector t0)
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
    if (n_trunc > 0) {
        printf("{txt}note: G(t) truncated to 1e-10 for %g observations;" +
            " inference may be sensitive\n", n_trunc)
    }

    return(G)
}

/* KM of censoring distribution, optionally stratified by byg */
real colvector _finegray_km_censor(
    real colvector t,
    real colvector delta,
    real scalar censval,
    real colvector event_type,
    real colvector byg_id,
    real colvector t0)
{
    real scalar n, g, nlev
    real colvector G, levels, sel

    n = rows(t)
    G = J(n, 1, 1)

    levels = uniqrows(byg_id)
    nlev = rows(levels)
    if (nlev > 1) {
        for (g = 1; g <= nlev; g++) {
            sel = selectindex(byg_id :== levels[g])
            G[sel] = _finegray_km_censor_single(t[sel], delta[sel],
                censval, event_type[sel], t0[sel])
        }
        return(G)
    }

    G = _finegray_km_censor_single(t, delta, censval, event_type, t0)
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

               r(u) = #{ l_i <= u }  -  #{ x_i < u }

           both of which are monotone in u.  O(n log n) for the sorts, O(n) here. */
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
            /* exits with x_i < u */
            while (pt <= rows(ts_)) {
                if (ts_[pt] < u) pt++
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

     numerator    A_g(t_k) for each cause-`cause' event time t_k and each stratum
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
    real colvector ord, row_id, cmass
    real matrix Aev, SUF
    string scalar warnstr

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
        /* Mata's | does NOT short-circuit, so `rows(et) == 0 | t[r] != et[rows(et)]`
           still evaluates et[0] on the first event and aborts with 3301. */
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

    /* cmass[g] = does stratum g hold any competing-event subject at all?
       Used to decide which numerator cells the scan can ever consult. */
    cmass = J(nj, 1, 0)
    for (i = 1; i <= n; i++) if (is_compete[i]) cmass[gidx[i]] = 1

    /* Suffix maxima, ONCE per stratum: SUF[k, g] = max A_g over et[k..K].
       Each retained subject then reads its largest possible weight in O(1).
       Doing this per subject instead would be O(n*K) -- the very expansion the
       unexpanded scan exists to avoid. */
    SUF = J(K, nj, .)
    for (g = 1; g <= nj; g++) {
        if (!cmass[g]) continue

        SUF[K, g] = Aev[K, g]
        for (k = K - 1; k >= 1; k--) SUF[k, g] = max((Aev[k, g], SUF[k + 1, g]))

        /* Numerator cells consulted in stratum g. */
        for (k = 1; k <= K; k++) {
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
           & does NOT short-circuit, so the bound test must be its own statement --
           `k <= K & et[k] <= t[r]` would evaluate et[K+1] and abort. */
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
       st_local writes into the calling ado's scope -- unlike st_global, which
       would need a name Stata accepts (a global may not begin with an underscore:
       `global _finegray_warnstrata ""` is r(198)) and would clobber a same-named
       global belonging to the user. */
    st_local("_fg_warnstrata", warnstr)
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
    real colvector tg_id)
{
    real scalar n, p, i, use_cluster
    real colvector clev, sel
    real matrix scores, meat, clust_scores

    n = rows(t)
    p = cols(Z)

    scores = _finegray_score_residuals(t, delta, cause, censval, event_type,
        Z, beta, G, byg_id, t0, tg_id)

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

    G = _finegray_km_censor(t, delta, censval, event_type, byg_id, t0)

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
    real scalar adjust)
{
    real colvector t, delta, event_type, G, byg_id, t0, tg_id
    real matrix Z, V, bh
    real colvector beta, beta_new, score_vec, step, clust_id
    real matrix info_mat, info_inv
    real scalar n, p, ll, ll_new, ll_0, converged, iter
    real scalar step_scale, halving, max_halvings, chi2, df_m
    real scalar decrement, accepted, n_clust, rank_V
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

           Near the optimum the decrement is ~2*(ll_max - ll), so `decrement <
           tol` means the likelihood is within tol/2 of its maximum. */
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
            Z, beta, G, byg_id, info_inv, clust_str, clust_id, t0, tg_id)

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

    /* Compute baseline hazard */
    bh = _finegray_basehazard(t, delta, cause, censval, event_type,
        Z, beta, G, byg_id, t0, tg_id)

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
    st_matrix("_finegray_basehaz", bh)
    st_matrixcolstripe("_finegray_basehaz", (J(2,1,""), ("time" \ "cumhazard")))
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

    n = rows(Z)
    p = cols(Z)

    G = _finegray_km_censor(t, delta, censval, event_type, byg_id, t0)
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
    string scalar cifvar,
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
    st_store(sel, cifvar, out[., 1])
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

/* Step function lookup via binary search: O(n log n_bh) instead of O(n * n_bh).
   For each observation in the touse sample, finds the largest basehaz time <= t
   and assigns the corresponding cumulative hazard to H0var. */
void _finegray_step_lookup(
    string scalar bh_matname,
    string scalar tvar,
    string scalar H0var,
    string scalar tousevar)
{
    real matrix bh
    real colvector times, H0, touse_vec, sel
    real scalar i, lo, hi, mid, n_bh, n_sel

    bh = st_matrix(bh_matname)
    n_bh = rows(bh)

    touse_vec = st_data(., tousevar)
    sel = selectindex(touse_vec)
    n_sel = length(sel)

    times = st_data(sel, tvar)
    H0 = J(n_sel, 1, 0)

    for (i = 1; i <= n_sel; i++) {
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

end
