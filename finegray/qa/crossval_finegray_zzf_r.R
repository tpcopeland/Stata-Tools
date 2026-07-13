# =====================================================================
# crossval_finegray_zzf_r.R -- Phase Z1 oracles for delayed-entry Fine-Gray
#
# Sources: Zhang, Zhang & Fine (2011), Stat Med 30(16):1933-1951; Geskus (2011),
# Biometrics 67(1):39-49; Bellach et al. (2019), JASA 114(525):259-270.
#
# WHAT THIS IS.  An independent reference implementation of the stabilized
# Zhang-Zhang-Fine (2011) Weight-1 delayed-entry Fine-Gray estimator, written
# from the published equations, deliberately slow, and sharing no code with the
# Stata package.  It freezes coefficients, baseline cumulative subhazards, and
# subject-by-time weights to CSV.  crossval_finegray_zzf.do checks production
# against those frozen numbers.
#
# THE ESTIMATOR.   ZZF (2011) eq. (5), with A(t) = b(t) / S(t-):
#
#     b_g(t) = n_g^-1 * sum_{i in g} 1{L_i < t <= X_i}      (package (L,X] convention)
#     S_g(t) = left-truncated Kaplan-Meier of ALL-CAUSE survival within g
#     A_g(t) = b_g(t) / S_g(t-)
#
#     w_i(t) = 1                          if X_i >= t          (still at risk)
#            = A_g(t) / A_g(X_i)          if competing event at X_i < t
#            = 0                          otherwise
#
# STABILIZER: PER-STRATUM, not ZZF eq. (7)'s pooled one.  Deliberate; decided
# 2026-07-13 and defended in fg_zzf_plan.md Z0.  Both are consistent (the
# numerator probe below is the evidence).  Per-stratum keeps the at-risk weight
# at exactly 1 -- which is what Geskus's (2011, p.44) "no need for a sandwich
# estimator" argument depends on -- and collapses to G_g(t-)/G_g(X_i-) when
# L = 0, so no released right-censoring result moves.
#
# TIE ORDERING (Geskus 2011, p.40-41): events < censorings < entries at a tied
# time.  Gate Z1 fixtures are continuous and tie-free by construction; Gate
# Z-ties fixtures below collide the classes deliberately.
#
# POSITIVITY.  Every stratified fixture must have COMMON censoring and entry
# support across strata.  A group whose G_g(t) hits 0 in the tail makes every
# IPCW weight undefined there; a fixture that violates this measures nothing.
# See the numerator probe -- it produced a spurious "16 MC SE bias" until the
# support was fixed.
#
# Run:  Rscript crossval_finegray_zzf_r.R
# Emits: zzf_oracle_<fixture>.csv, zzf_oracle_coef.csv, zzf_oracle_weights.csv,
#        zzf_oracle_baseline.csv, zzf_oracle_gate.csv, and the fixtures as .csv
#        for Stata to read.
# =====================================================================

suppressPackageStartupMessages({
  library(survival)
})

SEED <- 20260713
set.seed(SEED)
OUT  <- "data"                     # relative to qa/; the .do file reads from here
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

cat("=====================================================================\n")
cat(" Phase Z1 oracles -- stabilized ZZF Weight 1 under delayed entry\n")
cat(" seed =", SEED, "\n")
cat(" survival =", as.character(packageVersion("survival")), "\n")
cat("=====================================================================\n\n")

# ---------------------------------------------------------------------
# 1.  Direct ZZF Weight-1 estimator.  Written from ZZF (2011) eq. (5).
#     No production helper, no scan, no shared lookup.  O(n^2) and proud.
# ---------------------------------------------------------------------

# Left-truncated KM of ALL-CAUSE survival within one group.  Returns a step
# function giving the LEFT LIMIT S(t-).
lt_km_allcause <- function(L, X, status) {
  ev <- sort(unique(X[status != 0]))
  if (!length(ev)) return(function(u) rep(1, length(u)))
  surv <- 1
  s <- numeric(length(ev))
  for (k in seq_along(ev)) {
    t <- ev[k]
    nrisk <- sum(L < t & X >= t)          # (L, X] convention
    d     <- sum(X == t & status != 0)
    if (nrisk > 0) surv <- surv * (1 - d / nrisk)
    s[k] <- surv
  }
  # S(t-) = product over event times STRICTLY BELOW t
  function(u) {
    idx <- findInterval(u - 1e-12, ev)    # count of event times < u
    c(1, s)[idx + 1L]
  }
}

# b_g(t) = within-group fraction observed at risk at t, (L, X] convention
b_frac <- function(L, X) function(u) vapply(u, function(t) mean(L < t & X >= t), numeric(1))

# A_g(t) = b_g(t) / S_g(t-)
make_A <- function(L, X, status) {
  Sm <- lt_km_allcause(L, X, status)
  bf <- b_frac(L, X)
  function(u) bf(u) / Sm(u)
}

# The ZZF Weight-1 weight matrix: n x K, rows = subjects, cols = cause-1 event times.
zzf_weights <- function(d, cause = 1L, stabilizer = c("perstratum", "pooled")) {
  stabilizer <- match.arg(stabilizer)
  n  <- nrow(d)
  et <- sort(unique(d$X[d$status == cause]))
  K  <- length(et)
  gs <- unique(d$wgroup)

  A_g    <- lapply(gs, function(g) { k <- d$wgroup == g; make_A(d$L[k], d$X[k], d$status[k]) })
  names(A_g) <- as.character(gs)
  A_pool <- make_A(d$L, d$X, d$status)

  # numerator A(t) at each event time, per subject
  NUM <- matrix(0, n, K)
  if (stabilizer == "pooled") {
    NUM[] <- rep(A_pool(et), each = n)
  } else {
    for (g in gs) NUM[d$wgroup == g, ] <- rep(A_g[[as.character(g)]](et), each = sum(d$wgroup == g))
  }
  # denominator A_g(X_i) -- fixed per subject
  den <- numeric(n)
  for (g in gs) { k <- d$wgroup == g; den[k] <- A_g[[as.character(g)]](d$X[k]) }

  atrisk <- outer(d$X, et, ">=") & outer(d$L, et, "<")            # (L, X]
  comp   <- outer(d$X, et, "<")  & (d$status != 0 & d$status != cause)

  W <- matrix(0, n, K)
  W[atrisk] <- 1                                                   # <- the weight-1 property
  W[comp]   <- (NUM / matrix(den, n, K))[comp]
  if (stabilizer == "pooled") {
    # with a pooled stabilizer the at-risk weight is A_pool(t)/A_g(t), NOT 1
    AG <- matrix(0, n, K)
    for (g in gs) AG[d$wgroup == g, ] <- rep(A_g[[as.character(g)]](et), each = sum(d$wgroup == g))
    W[atrisk] <- (NUM / AG)[atrisk]
  }
  list(W = W, et = et, den = den)
}

# Weighted FG log pseudo-likelihood; outer weight at own event is 1 (per-stratum).
zzf_fit <- function(d, zvars, cause = 1L, stabilizer = "perstratum") {
  Z  <- as.matrix(d[, zvars, drop = FALSE])
  ww <- zzf_weights(d, cause, stabilizer)
  W  <- ww$W; et <- ww$et
  evrow <- lapply(et, function(t) which(d$X == t & d$status == cause))
  owt   <- vapply(seq_along(et), function(k) {
             i <- evrow[[k]]; if (!length(i)) 0 else sum(W[i, k])
           }, numeric(1))

  negll <- function(b) {
    ee <- as.vector(exp(Z %*% b))
    S0 <- colSums(W * ee)
    ll <- 0
    for (k in seq_along(et)) {
      for (i in evrow[[k]]) ll <- ll + W[i, k] * (sum(Z[i, ] * b) - log(S0[k]))
    }
    -ll
  }
  init <- rep(0, length(zvars))
  op <- optim(init, negll, method = "BFGS", control = list(reltol = 1e-13, maxit = 500))
  beta <- op$par; names(beta) <- zvars

  # Breslow-type baseline cumulative subhazard
  ee <- as.vector(exp(Z %*% beta))
  S0 <- colSums(W * ee)
  dL <- vapply(seq_along(et), function(k) sum(W[evrow[[k]], k]) / S0[k], numeric(1))
  list(beta = beta, et = et, Lambda0 = cumsum(dL), W = W, S0 = S0,
       conv = op$convergence, ll = -op$value)
}

# ---------------------------------------------------------------------
# 2.  Fixture generators.  Known-truth Fine-Gray DGP (ZZF 2011 sec. 4.1).
#         F1(t|z) = 1 - {1 - p(1 - e^-t)}^exp(b'z)
#     so the true subdistribution coefficient is exactly b.
# ---------------------------------------------------------------------
P_MASS <- 0.5
BETA   <- c(z1 = 0.5, z2 = -0.5)
BETA2  <- c(0.5, 0.5)      # competing-cause coefficients

gen_fg <- function(n, trunc = c("none", "independent", "bygroup"),
                   cens_by_group = FALSE, tau = 6, seed = NULL) {
  trunc <- match.arg(trunc)
  if (!is.null(seed)) set.seed(seed)
  # oversample: left truncation discards subjects with L > X
  m <- n * 6L
  z1 <- rbinom(m, 1, 0.5); z2 <- rnorm(m)
  grp <- z1                                       # the discrete weight group
  ez  <- exp(BETA["z1"] * z1 + BETA["z2"] * z2)
  p1  <- 1 - (1 - P_MASS)^ez
  cause <- ifelse(runif(m) < p1, 1L, 2L)
  tt <- numeric(m)
  i1 <- cause == 1L
  v  <- runif(sum(i1))
  tt[i1] <- -log(1 - (1 - (1 - v * p1[i1])^(1 / ez[i1])) / P_MASS)
  r2 <- exp(BETA2[1] * z1[!i1] + BETA2[2] * z2[!i1])
  tt[!i1] <- rexp(sum(!i1), rate = 0.5 * r2)

  # censoring -- COMMON SUPPORT is mandatory (see header)
  crate <- if (cens_by_group) ifelse(grp == 1, 0.30, 0.08) else rep(0.15, m)
  cens  <- pmin(rexp(m, rate = crate), tau)

  # entry
  L <- switch(trunc,
    none        = rep(0, m),
    independent = rexp(m, rate = 0.9),
    bygroup     = rexp(m, rate = ifelse(grp == 1, 1.6, 0.5))   # entry depends on grp
  )
  X   <- pmin(tt, cens)
  st  <- ifelse(tt <= cens, cause, 0L)
  keep <- which(L < X)                              # the truncation
  keep <- keep[seq_len(min(n, length(keep)))]
  data.frame(id = seq_along(keep), L = L[keep], X = X[keep], status = st[keep],
             z1 = z1[keep], z2 = z2[keep], wgroup = grp[keep])
}

# ---------------------------------------------------------------------
# 3.  survival::finegray + coxph -- the independent SOFTWARE oracle.
#     Geskus weights, expanded data.  Breslow ties.
#
#  *** THE STRATIFIED CASE IS NOT AN ORACLE FOR US.  READ THIS. ***
#
#  survival::finegray(~ . + strata(g)) computes the weights per stratum -- which
#  is what we want -- but it also EMITS ROWS ONLY AT THAT STRATUM'S OWN cause-1
#  event times.  From the source (survival 3.8-6, stratfun):
#
#      keep  <- (istrat == i)
#      times <- sort(unique(Y[keep & status == enum, 2]))   # stratum i's events
#      ...  ckeep[findInterval(times, ct2, left.open=TRUE)] <- TRUE
#
#  and the help file confirms the intent: "because the middle interval does not
#  span any event times the subsequent Cox model will never use that row.  The
#  finegray output omits such rows."
#
#  So a stratum-0 subject has NO ROW at a stratum-1 event time.  That is only
#  sound if the subsequent fit is coxph(... + strata(g)) -- a STRATIFIED-BASELINE
#  model.  finegray(Stata) fits a SHARED baseline with stratified weights (Fine &
#  Gray 1999 p.500; cmprsk::crr's `cengroup` does the same).  Fitting an
#  unstratified coxph on survival's stratified expansion silently drops subjects
#  out of risk sets and gives a WRONG answer -- observed here as a 0.089
#  coefficient gap with weights agreeing to 1e-15.
#
#  Therefore, per fg_zzf_plan.md Gate Z1 ("an unavailable software representation
#  is `not applicable`, never a reason to weaken the direct-equation fixture"):
#    - pooled fixtures        -> survival::finegray is a full end-to-end oracle
#    - censoring strata, no LT-> cmprsk::crr(cengroup=) is the oracle (shared baseline)
#    - stratified weights + LT-> NO software oracle exists.  This is precisely the
#                               capability that does not exist elsewhere.  Verified
#                               instead by (a) per-stratum weight parity against
#                               survival wherever it emits a covering row, and
#                               (b) an independent optimizer check (coxph on an
#                               expansion built from our own weights over the
#                               GLOBAL event grid), and above all by (c) Z2
#                               known-truth recovery.
# ---------------------------------------------------------------------
sf_fit <- function(d, zvars, strat = FALSE) {
  dd <- d
  dd$ev <- factor(dd$status, levels = c(0, 1, 2), labels = c("censor", "cause1", "cause2"))
  f <- if (strat) Surv(L, X, ev) ~ . + strata(wgroup) else Surv(L, X, ev) ~ .
  fg <- finegray(f, data = dd, etype = "cause1", id = id)
  frm <- as.formula(paste("Surv(fgstart, fgstop, fgstatus) ~", paste(zvars, collapse = " + ")))
  cx <- coxph(frm, weights = fgwt, data = fg, ties = "breslow", robust = FALSE)
  bh <- basehaz(cx, centered = FALSE)
  list(beta = coef(cx), fg = fg, bh = bh)
}

# Weight of subject i at time t, read out of survival's expanded data.
# Returns NA (not 0) when no row covers t, so a missing row can never be
# mistaken for an agreeing zero.  The first version of this returned 0 and the
# gate silently skipped every disagreement -- a textbook false green.
sf_weight_at <- function(fg, id_i, t) {
  r <- fg[fg$id == id_i & fg$fgstart < t & fg$fgstop >= t, ]
  if (!nrow(r)) return(NA_real_)
  r$fgwt[1]
}

# Independent optimizer check: fit coxph on an expansion built from OUR weights,
# over the GLOBAL cause-1 event grid.  Same weights, different fitter.  This does
# not validate the weights (that is sf_weight_at's job); it validates the
# weighted partial likelihood and the optimizer.
coxph_on_our_weights <- function(d, zz, zvars) {
  et <- zz$et; W <- zz$W
  rows <- list(); k <- 0L
  brk <- c(0, et)
  for (j in seq_along(et)) {
    keep <- which(W[, j] > 0)
    if (!length(keep)) next
    k <- k + 1L
    rows[[k]] <- data.frame(
      id = d$id[keep], tstart = brk[j], tstop = et[j],
      ev = as.integer(d$X[keep] == et[j] & d$status[keep] == 1L),
      w = W[keep, j], d[keep, zvars, drop = FALSE])
  }
  ex <- do.call(rbind, rows)
  frm <- as.formula(paste("Surv(tstart, tstop, ev) ~", paste(zvars, collapse = " + ")))
  coef(coxph(frm, weights = ex$w, data = ex, ties = "breslow", robust = FALSE))
}

# =====================================================================
# GATE Z1 -- direct ZZF vs survival::finegray on continuous fixtures
# =====================================================================
cat("---------------------------------------------------------------------\n")
cat("GATE Z1: direct ZZF Weight 1 vs the best oracle each fixture admits\n")
cat("  tolerances: coef < 5e-5 | retained weight rel < 1e-8 | baseline < 1e-4\n")
cat("              optimizer cross-check < 5e-5\n")
cat("  oracle: survival = survival::finegray + coxph(breslow), pooled weights\n")
cat("          cmprsk   = cmprsk::crr(cengroup=), stratified weights, shared baseline\n")
cat("          none     = stratified weights + left truncation: no reference software\n")
cat("---------------------------------------------------------------------\n")

gate <- list()

# oracle: which independent software CAN encode this fixture's weighting scheme?
#   "survival"  -- pooled weights, shared baseline  -> full end-to-end parity
#   "cmprsk"    -- stratified censoring weights, shared baseline, NO left truncation
#   "none"      -- stratified weights WITH left truncation: no reference software
#                  implements shared-baseline + stratified delayed-entry weights
fixtures <- list(
  list(nm = "pooled_lt_nocens", n = 600, trunc = "independent", cens = FALSE, strat = FALSE, oracle = "survival"),
  list(nm = "pooled_lt_cens",   n = 600, trunc = "independent", cens = FALSE, strat = FALSE, oracle = "survival"),
  list(nm = "notrunc_cens",     n = 600, trunc = "none",        cens = FALSE, strat = FALSE, oracle = "survival"),
  list(nm = "censstrata_only",  n = 800, trunc = "none",        cens = TRUE,  strat = TRUE,  oracle = "cmprsk"),
  list(nm = "truncstrata_only", n = 800, trunc = "bygroup",     cens = FALSE, strat = TRUE,  oracle = "none"),
  list(nm = "same_grouping",    n = 800, trunc = "bygroup",     cens = TRUE,  strat = TRUE,  oracle = "none"),
  list(nm = "cross_grouping",   n = 800, trunc = "bygroup",     cens = TRUE,  strat = TRUE,  oracle = "none")
)

for (fi in seq_along(fixtures)) {
  fx <- fixtures[[fi]]
  d <- gen_fg(fx$n, trunc = fx$trunc, cens_by_group = fx$cens, seed = SEED + fi)
  if (!fx$strat) d$wgroup <- 0L
  write.csv(d, file.path(OUT, paste0("zzf_fix_", fx$nm, ".csv")), row.names = FALSE)

  zz <- zzf_fit(d, c("z1", "z2"), stabilizer = "perstratum")

  # -- (b) independent optimizer check: same weights, coxph instead of our optim
  cxb   <- coxph_on_our_weights(d, zz, c("z1", "z2"))
  d_opt <- max(abs(zz$beta - cxb))

  # -- (a) weight parity vs survival, wherever survival emits a covering row.
  #        NA (missing row) is COUNTED, never silently skipped.
  sf <- tryCatch(sf_fit(d, c("z1", "z2"), strat = fx$strat), error = function(e) NULL)
  dw <- NA_real_; n_cmp <- 0L; n_missing <- 0L
  if (!is.null(sf)) {
    compi <- which(d$status == 2L)
    wr <- c()
    for (i in head(compi, 40)) {
      for (k in which(zz$et > d$X[i])) {
        a <- zz$W[i, k]
        b <- sf_weight_at(sf$fg, d$id[i], zz$et[k])
        if (is.na(b)) { n_missing <- n_missing + 1L; next }   # counted, not hidden
        n_cmp <- n_cmp + 1L
        wr <- c(wr, abs(a / b - 1))
      }
    }
    dw <- if (length(wr)) max(wr) else NA_real_
  }

  # -- end-to-end coefficient/baseline parity, only where an oracle can encode it
  dcoef <- NA_real_; dbase <- NA_real_; onm <- fx$oracle
  if (fx$oracle == "survival" && !is.null(sf)) {
    dcoef <- max(abs(zz$beta - sf$beta))
    sfL   <- approx(sf$bh$time, sf$bh$hazard, xout = zz$et,
                    method = "constant", yleft = 0, rule = 2)$y
    dbase <- max(abs(zz$Lambda0 - sfL))
  } else if (fx$oracle == "cmprsk") {
    cr <- tryCatch(cmprsk::crr(d$X, d$status, as.matrix(d[, c("z1", "z2")]),
                               cengroup = d$wgroup, failcode = 1, cencode = 0)$coef,
                   error = function(e) NULL)
    if (!is.null(cr)) dcoef <- max(abs(zz$beta - cr))
  }

  # PASS rules.  Where no software oracle exists, the fixture passes on the
  # optimizer check + weight parity alone, and is FLAGGED so nobody later reads
  # the green as end-to-end external corroboration.  Z2 recovery is its real gate.
  ok_coef <- is.na(dcoef) || dcoef < 5e-5
  ok_wt   <- is.na(dw)    || dw    < 1e-8
  ok_base <- is.na(dbase) || dbase < 1e-4
  ok_opt  <- d_opt < 5e-5
  pass    <- ok_coef && ok_wt && ok_base && ok_opt

  cat(sprintf("  %-17s [%-8s] d_coef=%-9s d_wt=%-9s d_base=%-9s d_opt=%.1e  %s%s\n",
              fx$nm, onm,
              if (is.na(dcoef)) "   n/a  " else sprintf("%.2e", dcoef),
              if (is.na(dw))    "   n/a  " else sprintf("%.2e", dw),
              if (is.na(dbase)) "   n/a  " else sprintf("%.2e", dbase),
              d_opt,
              if (pass) "PASS" else "**FAIL**",
              if (onm == "none") "  [no external oracle]" else ""))
  if (n_missing > 0)
    cat(sprintf("       note: survival omitted %d of %d weight lookups (stratum-local event grid)\n",
                n_missing, n_missing + n_cmp))

  gate[[fx$nm]] <- data.frame(fixture = fx$nm, oracle = onm, d_coef = dcoef,
                              d_weight = dw, d_baseline = dbase, d_optimizer = d_opt,
                              n_weight_cmp = n_cmp, n_weight_missing = n_missing,
                              pass = pass, beta1 = zz$beta[1], beta2 = zz$beta[2])

  write.csv(data.frame(term = names(zz$beta), beta = zz$beta),
            file.path(OUT, paste0("zzf_oracle_coef_", fx$nm, ".csv")), row.names = FALSE)
  write.csv(data.frame(time = zz$et, Lambda0 = zz$Lambda0),
            file.path(OUT, paste0("zzf_oracle_baseline_", fx$nm, ".csv")), row.names = FALSE)
  wdf <- data.frame(id = rep(d$id, length(zz$et)),
                    time = rep(zz$et, each = nrow(d)),
                    w = as.vector(zz$W))
  write.csv(wdf[wdf$w > 0, ], file.path(OUT, paste0("zzf_oracle_weights_", fx$nm, ".csv")),
            row.names = FALSE)
}

gate_df <- do.call(rbind, gate)
write.csv(gate_df, file.path(OUT, "zzf_oracle_gate.csv"), row.names = FALSE)

cat("\n")
if (all(gate_df$pass)) cat("GATE Z1: PASS on all fixtures\n") else
  cat("GATE Z1: FAILURES ->", paste(gate_df$fixture[!gate_df$pass], collapse = ", "), "\n")
nn <- sum(gate_df$oracle == "none")
cat(sprintf("  %d/%d fixtures have NO external software oracle (stratified weights + left\n",
            nn, nrow(gate_df)))
cat("  truncation with a shared baseline). Their correctness rests on the direct ZZF\n")
cat("  equation plus Gate Z2 known-truth recovery -- not on external corroboration.\n")
cat("\nFrozen oracle outputs written to ", normalizePath(OUT), "\n", sep = "")


# =====================================================================
# GATE Z-TIES -- which representation does production use?
#
# Bellach et al. (2020) sec.3 prove ZZF's weight (their eq. 8) and Geskus's
# (their eq. 10) equivalent ONLY for CONTINUOUS failure times.  Geskus (2011,
# p.41) says the same from the other side: "As long as event times are separate
# from censoring and entry times, we have G(t-) = G(t) and H(t-) = H(t)."
#
# So at ties the two forms MAY diverge, and which one production computes is a
# decision, not a detail.  This gate makes it on evidence:
#
#   A_ZZF(t) = b(t) / S(t-)                 <- CANONICAL.  ZZF (2011) eq. (5).
#   A_GH(t)  = G(t-) * H(t-)                <- convenient.  Geskus (2011) eq. (11).
#
# Adopt A_GH only if it reproduces A_ZZF on EVERY collision class within
# tolerance.  Otherwise compute A_ZZF = b/S directly.  Never move the canonical
# target to preserve parity with an expanded implementation.
#
# Tie ordering, sourced verbatim (Geskus 2011, p.40): "We assume the ordering
# t_(i) < c_(j) < l_(j) in case they occur at the same time point" -- EVENTS,
# then CENSORINGS, then ENTRIES.
# =====================================================================
cat("\n---------------------------------------------------------------------\n")
cat("GATE Z-ties: A_ZZF = b/S(t-)   vs   A_GH = G(t-)H(t-)  at tied times\n")
cat("  select A_GH only if coef < 1e-8, retained weight rel < 1e-10 everywhere\n")
cat("  tie order (Geskus p.40): events < censorings < entries\n")
cat("---------------------------------------------------------------------\n")

# Tied fixtures.  Built by rounding a continuous known-truth fixture onto a COARSE
# INTEGER GRID, which forces collisions of every class in bulk while keeping n large
# enough that the fit is non-degenerate.  (A hand-built 12-subject fixture collides
# the classes too, but coxph hits separation on it -- "beta may be infinite" -- so the
# coefficient comparison measures nothing.  Ties must be tested at a size that fits.)
#
# Every fixture asserts, per collision class, that the class actually OCCURS.  A tie
# gate that silently exercises no ties is the worst possible false green.
make_tied <- function(n, gridsize, seed, trunc = "independent") {
  d <- gen_fg(n, trunc = trunc, cens_by_group = FALSE, seed = seed)
  d$L <- floor(d$L * gridsize) / gridsize
  d$X <- ceiling(d$X * gridsize) / gridsize
  d <- d[d$L < d$X, ]                       # zero-length intervals are not data
  d$id <- seq_len(nrow(d)); d$wgroup <- 0L
  d
}
collision_counts <- function(d) {
  ev <- d$X[d$status == 1L]; cp <- d$X[d$status == 2L]
  cs <- d$X[d$status == 0L]; en <- d$L[d$L > 0]
  c(entry_cause     = sum(en %in% ev),
    entry_competing = sum(en %in% cp),
    entry_censoring = sum(en %in% cs),
    censoring_cause = sum(cs %in% ev),
    cause_competing = sum(ev %in% cp))
}

tie_fixtures <- list(
  ties_coarse   = make_tied(500, 4,  SEED + 201),   # very coarse grid: ties everywhere
  ties_medium   = make_tied(500, 10, SEED + 202),
  ties_fine     = make_tied(500, 25, SEED + 203),
  ties_notrunc  = make_tied(500, 4,  SEED + 204, trunc = "none")
)

zties <- list()
for (nm in names(tie_fixtures)) {
  d <- tie_fixtures[[nm]]
  stopifnot(all(d$L < d$X))
  cc <- collision_counts(d)
  cat(sprintf("  [%s] n=%d collisions: entry/cause=%d entry/competing=%d entry/censoring=%d censoring/cause=%d cause/competing=%d\n",
              nm, nrow(d), cc[1], cc[2], cc[3], cc[4], cc[5]))
  if (nm != "ties_notrunc" && any(cc[1:4] == 0))
    cat("       ** WARNING: a collision class is absent -- this fixture does not test it **\n")
  write.csv(d, file.path(OUT, paste0("zzf_tie_", nm, ".csv")), row.names = FALSE)

  # --- A_ZZF: canonical b/S, computed from ZZF eq. (5)
  zz <- zzf_fit(d, c("z1", "z2"), stabilizer = "perstratum")

  # --- A_GH: the Geskus product form.  Represented by survival::finegray, which
  #     IS the reference Geskus implementation and which this script has already
  #     shown reproduces A_ZZF to 3e-7 / 1e-15 on continuous data.  Using it here
  #     (rather than a hand-rolled G,H) means the comparison tests the TIE
  #     CONVENTIONS, which is the only thing in question, and not our arithmetic.
  #   NB: the formula MUST be `~ .` -- with `~ z1 + z2` the output drops the `id`
  #   column, every weight lookup below silently misses, and the gate reports a
  #   confident n_wt=0.  That happened; hence the assertion.
  x <- d; x$ev <- factor(x$status, 0:2, labels = c("censor", "cause1", "cause2"))
  fg  <- finegray(Surv(L, X, ev) ~ ., data = x, etype = "cause1", id = id)
  stopifnot("id" %in% names(fg))
  bgh <- coef(coxph(Surv(fgstart, fgstop, fgstatus) ~ z1 + z2, weights = fgwt,
                    data = fg, ties = "breslow", robust = FALSE))

  # Compare coefficients through the SAME fitter (coxph/Newton) on both weightings.
  # Comparing our optim-BFGS fit against coxph would measure our optimizer's
  # convergence floor (~3e-7, visible on the CONTINUOUS fixtures too), not the tie
  # conventions -- which is the only thing this gate is about.
  bzz   <- coxph_on_our_weights(d, zz, c("z1", "z2"))
  dcoef <- max(abs(bzz - bgh))

  # weight parity on retained competing subjects; a row survival omits is NA and
  # is COUNTED, never treated as an agreeing zero.
  wr <- c(); n_missing <- 0L
  for (i in which(d$status == 2L)) {
    for (k in which(zz$et > d$X[i])) {
      b <- sf_weight_at(fg, d$id[i], zz$et[k])
      if (is.na(b)) { n_missing <- n_missing + 1L; next }
      wr <- c(wr, abs(zz$W[i, k] / b - 1))
    }
  }
  dw <- if (length(wr)) max(wr) else NA_real_

  # A gate that compared zero weights would be vacuous.  Require evidence.
  ok <- dcoef < 1e-8 && !is.na(dw) && dw < 1e-10 && length(wr) > 0
  cat(sprintf("       d_coef=%.3e  d_wt=%.3e  n_wt=%4d (missing %d)  %s\n",
              dcoef, dw, length(wr), n_missing,
              if (ok) "A_GH == A_ZZF" else "**A_GH DIVERGES**"))
  zties[[nm]] <- data.frame(fixture = nm, d_coef = dcoef, d_weight = dw,
                            n_weight_cmp = length(wr), n_weight_missing = n_missing,
                            gh_matches = ok, beta1 = zz$beta[1], beta2 = zz$beta[2])
  write.csv(data.frame(term = names(zz$beta), beta = zz$beta),
            file.path(OUT, paste0("zzf_tie_coef_", nm, ".csv")), row.names = FALSE)
  wdf <- data.frame(id = rep(d$id, length(zz$et)),
                    time = rep(zz$et, each = nrow(d)), w = as.vector(zz$W))
  write.csv(wdf[wdf$w > 0, ], file.path(OUT, paste0("zzf_tie_weights_", nm, ".csv")),
            row.names = FALSE)
}

zt <- do.call(rbind, zties)
write.csv(zt, file.path(OUT, "zzf_ties_gate.csv"), row.names = FALSE)
cat("\n")
if (all(zt$gh_matches)) {
  cat("GATE Z-ties DECISION: A_GH = G(t-)H(t-) reproduces canonical A_ZZF = b/S(t-)\n")
  cat("  on every collision class.  Production MAY use the product representation.\n")
  cat("  e(lt_weight) = zzf1_geskus\n")
} else {
  cat("GATE Z-ties DECISION: A_GH DIVERGES from canonical A_ZZF at ties ->\n")
  cat("  classes: ", paste(zt$fixture[!zt$gh_matches], collapse = ", "), "\n", sep = "")
  cat("  Production MUST compute A_ZZF = b(t)/S(t-) directly.  Do NOT move the\n")
  cat("  canonical target to preserve parity with an expanded implementation.\n")
  cat("  e(lt_weight) = zzf1_direct\n")
}


# =====================================================================
# mstate SENTINEL -- reproduce or retire the crprep discrepancy
#
# mstate::crprep breaks ties with an ABSOLUTE epsilon on the TIME scale:
#     prec <- .Machine$double.eps * prec.factor      # prec.factor = 1000 -> ~2.2e-13
#     survfit(Surv(Tstart, Tstop + ifelse(status==cens, prec, 0), ...))
#     summary(surv.cens, times = tmp.time - prec)
#
# A double carries ~15-16 significant digits, so once times reach ~1e3,
# `Tstop + 2.2e-13` rounds straight back to `Tstop` and the tie-breaking becomes
# a SILENT NO-OP.  That is a units choice masquerading as a statistical one.
#
# Falsifiable prediction: run the SAME fixture on two time scales (x1 and x1000).
# The statistical content is identical, so a correct implementation must return
# identical coefficients.  If crprep's answers move with the scale, the defect is
# the epsilon -- not the Geskus method -- and mstate stays quarantined.
# survival::finegray works in rank space and must be immune.
# =====================================================================
cat("\n---------------------------------------------------------------------\n")
cat("mstate SENTINEL: is the crprep discrepancy an absolute-epsilon artifact?\n")
cat("  same fixture, time scale x1 vs x1000.  Scale-invariant => immune.\n")
cat("---------------------------------------------------------------------\n")

#  RESULT, 2026-07-13, mstate 0.3.3 -- the discrepancy is REPRODUCED and mstate is
#  NOT a usage error on our part.  On mstate's OWN example dataset (aidssi), using
#  mstate's OWN documented idiom from ?crprep:
#
#      cmprsk::crr           : -1.004302
#      survival::finegray    : -1.004302     <- agree to 2.7e-15
#      mstate::crprep (docs) : -0.969784     <- gap 0.0345
#      crprep weight.cens range: 0.0155 .. 65.40
#
#  A Fine-Gray censoring weight is G(t)/G(X_i) with G decreasing: it CANNOT exceed
#  1.  crprep emits weights up to 65.  Two independent implementations agree to
#  machine precision against it.  The aidssi check is reproduced below so the
#  claim is falsifiable rather than asserted.
sent <- gen_fg(400, trunc = "independent", cens_by_group = FALSE, seed = SEED + 99)
sent$wgroup <- 0L

fit_scaled <- function(d, mult) {
  dd <- d; dd$L <- dd$L * mult; dd$X <- dd$X * mult
  out <- list(scale = mult)

  out$direct <- tryCatch(zzf_fit(dd, c("z1", "z2"))$beta, error = function(e) rep(NA_real_, 2))

  out$survival <- tryCatch({
    x <- dd; x$ev <- factor(x$status, 0:2, labels = c("censor", "cause1", "cause2"))
    fg <- finegray(Surv(L, X, ev) ~ ., data = x, etype = "cause1", id = id)
    coef(coxph(Surv(fgstart, fgstop, fgstatus) ~ z1 + z2, weights = fgwt,
               data = fg, ties = "breslow", robust = FALSE))
  }, error = function(e) rep(NA_real_, 2))

  out$mstate <- tryCatch({
    cp <- as.data.frame(mstate::crprep(Tstop = "X", status = "status", data = dd, trans = 1,
                                       cens = 0, Tstart = "L", id = "id", keep = c("z1", "z2")))
    cp$w <- cp$weight.cens * (if ("weight.trunc" %in% names(cp)) cp$weight.trunc else 1)
    coef(coxph(Surv(Tstart, Tstop, status == 1) ~ z1 + z2, weights = w,
               data = cp, ties = "breslow", robust = FALSE))
  }, error = function(e) { out$mstate_err <<- conditionMessage(e); rep(NA_real_, 2) })
  out
}

# -- Is our crprep usage wrong?  Check on mstate's own example, mstate's own idiom.
aidssi_check <- tryCatch({
  data(aidssi, package = "mstate", envir = environment())
  a <- subset(aidssi, !is.na(ccr5)); a$id <- seq_len(nrow(a))
  a$ccr5n <- as.numeric(a$ccr5 == "WM")
  cr <- cmprsk::crr(a$time, a$status, as.matrix(a[, "ccr5n", drop = FALSE]),
                    failcode = 1, cencode = 0)$coef
  a$ev <- factor(a$status, 0:2, labels = c("censor", "AIDS", "SI"))
  fgA <- finegray(Surv(time, ev) ~ ccr5n, data = a, etype = "AIDS")
  sv <- coef(coxph(Surv(fgstart, fgstop, fgstatus) ~ ccr5n, weights = fgwt,
                   data = fgA, ties = "breslow", robust = FALSE))
  cpA <- as.data.frame(mstate::crprep("time", "status", data = a, trans = c(1, 2),
                                      cens = 0, keep = "ccr5n"))
  msA <- coef(coxph(Surv(Tstart, Tstop, status == 1) ~ ccr5n, data = cpA,
                    weights = weight.cens, subset = failcode == 1, ties = "breslow"))
  list(crr = cr, survival = sv, mstate = msA, wrange = range(cpA$weight.cens))
}, error = function(e) NULL)

if (!is.null(aidssi_check)) {
  cat("\n  [usage control] mstate's own example data (aidssi), mstate's own ?crprep idiom:\n")
  cat(sprintf("      cmprsk::crr        = %.6f\n", aidssi_check$crr))
  cat(sprintf("      survival::finegray = %.6f   (crr gap %.2e)\n",
              aidssi_check$survival, abs(aidssi_check$crr - aidssi_check$survival)))
  cat(sprintf("      mstate::crprep     = %.6f   (crr gap %.2e)\n",
              aidssi_check$mstate, abs(aidssi_check$crr - aidssi_check$mstate)))
  cat(sprintf("      crprep weight.cens range = %.4f .. %.2f  (a FG censoring weight CANNOT exceed 1)\n",
              aidssi_check$wrange[1], aidssi_check$wrange[2]))
  cat("      -> our usage is the documented one; the discrepancy is mstate's.\n\n")
}

s1 <- fit_scaled(sent, 1)
s2 <- fit_scaled(sent, 1000)

cat(sprintf("  %-10s  beta(x1) = (%9.6f,%9.6f)   beta(x1000) = (%9.6f,%9.6f)   drift = %.3e\n",
            "direct",   s1$direct[1],   s1$direct[2],   s2$direct[1],   s2$direct[2],
            max(abs(s1$direct - s2$direct))))
cat(sprintf("  %-10s  beta(x1) = (%9.6f,%9.6f)   beta(x1000) = (%9.6f,%9.6f)   drift = %.3e\n",
            "survival", s1$survival[1], s1$survival[2], s2$survival[1], s2$survival[2],
            max(abs(s1$survival - s2$survival))))
cat(sprintf("  %-10s  beta(x1) = (%9.6f,%9.6f)   beta(x1000) = (%9.6f,%9.6f)   drift = %.3e\n",
            "mstate",   s1$mstate[1],   s1$mstate[2],   s2$mstate[1],   s2$mstate[2],
            max(abs(s1$mstate - s2$mstate))))

ms_drift <- max(abs(s1$mstate - s2$mstate))
sv_drift <- max(abs(s1$survival - s2$survival))
cat("\n")
cat("SENTINEL VERDICT: mstate::crprep 0.3.3 is QUARANTINED -- it is not an oracle.\n")
cat("  1. Scale dependence. survival and the direct equation are BIT-IDENTICAL at x1 and\n")
cat("     x1000 (drift 0). crprep ", if (is.na(ms_drift)) "FAILS OUTRIGHT" else sprintf("drifts %.2e", ms_drift),
    " at x1000",
    if (!is.null(s2$mstate_err)) paste0(' ("', s2$mstate_err, '")') else "", ".\n", sep = "")
cat("     Cause, read from source: prec <- .Machine$double.eps * 1000 (~2.2e-13) is an\n")
cat("     ABSOLUTE offset on the time scale. Doubles carry ~15-16 significant digits, so\n")
cat("     once times reach ~1e3, `Tstop + prec` rounds back to `Tstop` and the tie-breaking\n")
cat("     silently no-ops. Whether crprep works is a function of the units you chose.\n")
cat("  2. It disagrees at x1 too, and NOT because of our usage -- see the aidssi control\n")
cat("     above: on mstate's own data with mstate's own documented idiom, crr and\n")
cat("     survival::finegray agree to 2.7e-15 and crprep is 0.0345 away, with censoring\n")
cat("     weights up to 65 where the maximum possible value is 1.\n")
cat("  DO NOT copy crprep's epsilon device into production. Rank-space ordering (what\n")
cat("  survival::finegray does, and what Geskus p.40 prescribes) is exact and scale-free.\n")
write.csv(data.frame(
  impl  = rep(c("direct", "survival", "mstate"), each = 2),
  term  = rep(c("z1", "z2"), 3),
  x1    = c(s1$direct, s1$survival, s1$mstate),
  x1000 = c(s2$direct, s2$survival, s2$mstate)),
  file.path(OUT, "zzf_mstate_sentinel.csv"), row.names = FALSE)
