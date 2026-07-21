# ---------------------------------------------------------------------
# crossval_gof_r.R -- oracle side of the Li/Scheike/Zhang (2015) GOF crossval.
#
# PURPOSE.  Regenerate qa/data/gof-*.csv (the fixtures), reference_beta.csv,
# reference_proc.csv and reference_gof.csv, which crossval_gof.do asserts the
# Mata implementation against.  Shipping the generator keeps the reference
# REPRODUCIBLE inside this repository: without it the CSVs would be numbers of
# unknown provenance that no one could re-derive.
#
# THIS IS AN ORACLE, NOT A MIRROR.  Every term is computed from the formulae in
# the paper (pp. 201-202, 215-216), and the script is anchored two ways:
#
#   1. fg_sandwich_hand() reproduces cmprsk::crr's variance to 0 ulp, asserted
#      per fixture.  crr's Fortran variance routine `crrvv' is by R. J. Gray,
#      the Fine-Gray paper's second author.
#   2. Exact algebraic IDENTITIES that need no external library at all:
#        proportionality at t = t_max:  W_i(t_max) = 0 for every subject i
#        functional form / link at x = x_max (f == 1):  W_i(x_max) = 0
#      Both are asserted below.  They catch errors in C(.), Omega^-1, tie
#      multiplicity and term 3 simultaneously, and are strictly stronger than
#      the usual colSums(eta) ~ 0 check.
#
# crskdiag -- the authors' OWN R package -- is deliberately NOT the oracle.  Its
# censoring Kaplan-Meier is identically 1 on continuous data, and its default
# minor_included = 1 adds a defective nuisance term that feeds the test process
# itself rather than only the variance; on grid-snapped data its beta differs
# from crr's by up to 3.4% because it breaks censoring/event ties differently.
# Do not assert numeric parity against it.
#
# THE STANDARDIZING FACTOR is {I^-1_jj}^(1/2) -- the SQUARE ROOT of the jth
# diagonal of the INVERSE INFORMATION, not e(V), which is a sandwich.  The main
# text gives it with the square root (p.201, p.202 twice); the Appendix (p.215)
# drops it and is wrong.  It CANCELS in every per-covariate p-value and does NOT
# cancel in the overall statistic, so a bug in it is invisible in three of the
# four tests.  That is why reference_gof.csv carries the overall row.
#
# TIE MULTIPLICITY: every sum over event times carries d_k, the number of tied
# cause-1 events at that time.  Looping over distinct event TIMES instead of
# event SUBJECTS is invisible on one-event-per-time fixtures and ~167% wrong
# with ties -- see the gof-c comment below.
#
# Usage (from finegray/qa):
#   Rscript crossval_gof_r.R
#
# Requires: R with survival and cmprsk (see qa/_r_environment.txt).
# ---------------------------------------------------------------------

suppressMessages({library(survival); library(cmprsk)})

HERE <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) ".")
if (is.na(HERE) || is.null(HERE)) HERE <- "."
OUT <- file.path(HERE, "data")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

TOL_IDENT <- 1e-8

# ---- extracted verbatim from _take_action/finegray/R/00_common.R ----
ghat_minus <- function(X, eps, at) {
  cen <- as.integer(eps == 0)
  u   <- survfit(Surv(X, cen) ~ 1)
  approx(c(min(0, u$time) - 10 * .Machine$double.eps,
           c(u$time, max(u$time) * (1 + 10 * .Machine$double.eps))),
         c(1, u$surv, 0),
         xout = at * (1 - 100 * .Machine$double.eps),
         method = "constant", f = 0, rule = 2)$y
}

#
# CENSORING GROUPS (`cg`, = finegray's byg_id / cmprsk's cengroup).  Ghat is
# estimated WITHIN each group, so per crr.f lines 353-395 the whole psi
# machinery is per-group:
#
#   q_g(t) = sum_{s>=t, s an event time FROM GROUP g} d_s^g
#              [S1_2^g(s,t) - xbar(s) S0_2^g(s,t)] / S0(s)
#     BOTH sums are group-restricted.  crr.f:379 accumulates into
#     `qu(k, icg(j1))` -- the group of the EVENT subject j1 -- so a cause-1
#     event in group A contributes only to q_A, using only group-A competing
#     subjects.  S0(s) and xbar(s) stay GLOBAL (`xb(j1,0)`, `xb(j1,k)`).
#     Restricting only the inner sums is wrong and shows up as ~1e-3 relative
#     error the moment there is more than one censoring group.
#   Y_g(u) = #{j : g(j)=g, X_j >= u}
#   psi_i  = 1{eps_i=0} q_{g(i)}(X_i)/Y_{g(i)}(X_i)
#            - sum_{u <= X_i} dNc_g(u) q_g(u)/Y_g(u)^2
#
fg_sandwich_hand <- function(X, eps, Z, beta, cg = NULL) {
  Z <- as.matrix(Z); n <- length(X); p <- ncol(Z)
  if (is.null(cg)) cg <- rep(1L, n)
  o <- order(X); X <- X[o]; eps <- eps[o]; Z <- Z[o, , drop = FALSE]
  cg <- as.integer(factor(cg[o]))
  ug <- sort(unique(cg))

  # Ghat estimated within censoring group
  G <- numeric(n)
  for (g in ug) {
    s <- which(cg == g)
    G[s] <- ghat_minus(X[s], eps[s], X[s])
  }
  ev  <- exp(as.vector(Z %*% beta))
  ft  <- sort(unique(X[eps == 1]))
  m   <- length(ft)
  # Gev[k, g] = Ghat_g(ft[k]-).  Each group's KM must be evaluated at EVERY
  # event time, not only at that group's own rows, because a competing-event
  # subject in group g is carried forward past event times contributed by
  # other groups.
  Gev <- matrix(1, m, length(ug))
  for (g in ug) {
    s <- which(cg == g)
    Gev[, g] <- ghat_minus(X[s], eps[s], ft)
  }

  # TIE MULTIPLICITY (Breslow).  crr.f loops over event SUBJECTS, not distinct
  # event times, so a time carrying d tied cause-1 events contributes d times
  # to Omega, to eta's dLambda term, and to q.  Omitting this is invisible on
  # any fixture with one event per time and catastrophic (>100%) with ties.
  dk <- as.vector(table(factor(X[eps == 1], levels = ft)))

  rmat <- matrix(0, n, m)
  for (k in seq_len(m))
    rmat[, k] <- ifelse(X >= ft[k], 1, ifelse(eps == 2, Gev[k, cg] / G, 0))

  W    <- rmat * ev
  S0   <- colSums(W)
  xbar <- (t(W) %*% Z) / S0

  Omega <- matrix(0, p, p)
  for (k in seq_len(m)) {
    Zc    <- sweep(Z, 2, xbar[k, ], "-")
    Omega <- Omega + dk[k] * (t(Zc) %*% (Zc * W[, k])) / S0[k]
  }

  eta <- matrix(0, n, p)
  ki  <- match(X, ft)
  for (i in seq_len(n)) {
    if (eps[i] == 1) eta[i, ] <- Z[i, ] - xbar[ki[i], ]
    eta[i, ] <- eta[i, ] -
      colSums((matrix(Z[i, ], m, p, byrow = TRUE) - xbar) * (W[i, ] * dk / S0))
  }

  # q, Y and psi are all per censoring group.
  ut  <- sort(unique(X))
  nu  <- length(ut)
  qa  <- array(0, c(nu, p, length(ug)))
  Yg  <- matrix(0, nu, length(ug))
  psi <- matrix(0, n, p)
  ai  <- match(X, ut)

  for (g in ug) {
    ing <- cg == g
    Yg[, g] <- sapply(ut, function(t0) sum(X >= t0 & ing))
    ftg  <- sort(unique(X[eps == 1 & ing]))        # event times FROM group g
    dkg  <- as.vector(table(factor(X[eps == 1 & ing], levels = ftg)))
    kidx <- match(ftg, ft)                         # -> position on the global grid
    for (a in seq_len(nu)) {
      pre <- which(X < ut[a] & eps == 2 & ing)     # group-restricted
      sel <- which(ftg >= ut[a])                   # group-restricted
      if (!length(pre) || !length(sel)) next
      acc <- numeric(p)
      for (jj in sel) {
        k   <- kidx[jj]                            # S0/xbar are GLOBAL
        w2  <- ev[pre] * Gev[k, g] / G[pre]
        acc <- acc + dkg[jj] * (colSums(Z[pre, , drop = FALSE] * w2) -
                                xbar[k, ] * sum(w2)) / S0[k]
      }
      qa[a, , g] <- acc
    }
    dNcg  <- sapply(ut, function(t0) sum(X == t0 & eps == 0 & ing))
    Ysafe <- ifelse(Yg[, g] > 0, Yg[, g], 1)
    qg    <- matrix(qa[, , g], nrow = nu, ncol = p)
    cumdL <- matrix(apply(qg / Ysafe^2 * dNcg, 2, cumsum), ncol = p)
    for (i in which(ing)) {
      psi[i, ] <- -cumdL[ai[i], ]
      if (eps[i] == 0)
        psi[i, ] <- psi[i, ] + qa[ai[i], , g] / Ysafe[ai[i]]
    }
  }

  Oi <- solve(Omega)
  list(eta = eta, psi = psi, Omega = Omega, G = G, q = qa, Y = Yg, cg = cg,
       times = ut, X = X, eps = eps, Z = Z,
       score = colSums(eta),
       var_eta     = Oi %*% crossprod(eta)       %*% Oi,
       var_eta_psi = Oi %*% crossprod(eta + psi) %*% Oi)
}

# ---------------------------------------------------------------------------
# Shared risk-set scaffolding, built once per fit.
# ---------------------------------------------------------------------------
scaffold <- function(h, beta) {
  X <- h$X; eps <- h$eps; Z <- h$Z; G <- h$G
  n <- length(X); p <- ncol(Z)
  ev <- exp(as.vector(Z %*% beta))
  ft <- sort(unique(X[eps == 1])); m <- length(ft)
  dk <- as.vector(table(factor(X[eps == 1], levels = ft)))
  Gev <- ghat_minus(X, eps, ft)
  rmat <- matrix(0, n, m)
  for (k in seq_len(m))
    rmat[, k] <- ifelse(X >= ft[k], 1, ifelse(eps == 2, Gev[k] / G, 0))
  W <- rmat * ev
  S0 <- colSums(W)
  xbar <- (t(W) %*% Z) / S0
  dN <- matrix(0, n, m); ki <- match(X, ft)
  for (i in seq_len(n)) if (eps[i] == 1) dN[i, ki[i]] <- 1
  dM <- dN - sweep(W, 2, dk / S0, "*")          # n x m, w_i dM_i at each event time
  ut <- sort(unique(X)); nu <- length(ut); ai <- match(X, ut)
  Y <- sapply(ut, function(t0) sum(X >= t0))
  Ysafe <- ifelse(Y > 0, Y, 1)
  dNc <- sapply(ut, function(t0) sum(X == t0 & eps == 0))
  list(X = X, eps = eps, Z = Z, G = G, n = n, p = p, ev = ev, ft = ft, m = m,
       dk = dk, Gev = Gev, W = W, S0 = S0, xbar = xbar, dM = dM,
       ut = ut, nu = nu, ai = ai, Y = Y, Ysafe = Ysafe, dNc = dNc,
       Omega = h$Omega, Oi = solve(h$Omega), eta = h$eta, psi = h$psi, beta = beta)
}

# ---------------------------------------------------------------------------
# Term 3, both axes.  Factorised so it is O(nu*ngrid) rather than O(nu*ngrid*m).
#
#   w2_l(s) = ev_l * Ghat(s)/Ghat(X_l) = c_l * Gev[s],   c_l = ev_l / G_l
#
# so the inner bracket separates:
#
#   q(u, grid) = A_u(grid) * P1(u)  -  C_u * P2(u, grid)
#     A_u(grid) = sum_{X_l<u, eps_l=2} c_l f(grid, Z_l)     (cumulative in u)
#     C_u       = sum_{X_l<u, eps_l=2} c_l
#     P1(u)     = sum_{s>=u} Gev_s d_s / S0_s               (reverse cumsum)
#     P2(u,g)   = sum_{s>=u} Gev_s d_s gbar(s,g) / S0_s     (reverse cumsum per g)
#
# This is also the shape the Mata should follow -- the naive triple loop is
# ~1e4x slower and is what forced the paper's authors into C++.
# ---------------------------------------------------------------------------
term3_from_q <- function(sc, qmat) {
  # qmat: nu x ngrid, q(ut[a], grid)
  cumdL <- apply(qmat / sc$Ysafe^2 * sc$dNc, 2, cumsum)
  if (sc$nu == 1) cumdL <- matrix(cumdL, 1, ncol(qmat))
  T3 <- -cumdL[sc$ai, , drop = FALSE]
  cen <- sc$eps == 0
  T3[cen, ] <- T3[cen, ] + qmat[sc$ai[cen], , drop = FALSE] / sc$Ysafe[sc$ai[cen]]
  T3
}

# ---- proportionality, covariate j (indexed by TIME) ----
proc_prop <- function(sc, j) {
  n <- sc$n; m <- sc$m; p <- sc$p
  incr1 <- sweep(-outer(rep(1, n), sc$xbar[, j]), 1, sc$Z[, j], "+") * sc$dM
  W1 <- if (m == 1) matrix(incr1, n, 1) else t(apply(incr1, 1, cumsum))

  Cinc <- matrix(0, m, p)
  for (k in seq_len(m)) {
    Zc <- sweep(sc$Z, 2, sc$xbar[k, ], "-")
    Cinc[k, ] <- -(sc$dk[k] / sc$S0[k]) * colSums(sc$Z[, j] * sc$W[, k] * Zc)
  }
  Ct <- if (m == 1) matrix(Cinc, 1, p) else apply(Cinc, 2, cumsum)
  W2 <- ((sc$eta + sc$psi) %*% sc$Oi) %*% t(Ct)

  # q_j(u, t): A_u = sum_pre c_l Z_lj, gbar(s) = xbar_j(s)
  cl <- sc$ev / sc$G
  pre <- sc$eps == 2
  Au <- Cu <- numeric(sc$nu)
  for (a in seq_len(sc$nu)) {
    s <- pre & sc$X < sc$ut[a]
    Cu[a] <- sum(cl[s]); Au[a] <- sum(cl[s] * sc$Z[s, j])
  }
  base <- sc$Gev * sc$dk / sc$S0
  # cap the s-sum at t (column K) AND require s >= u  ->  cumulative in K, tail in u
  kge <- outer(sc$ut, sc$ft, "<=")                       # nu x m, s >= u
  M1 <- t(apply(sweep(kge, 2, base, "*"), 1, cumsum))
  M2 <- t(apply(sweep(kge, 2, base * sc$xbar[, j], "*"), 1, cumsum))
  if (sc$m == 1) { M1 <- matrix(M1, sc$nu, 1); M2 <- matrix(M2, sc$nu, 1) }
  qmat <- Au * M1 - Cu * M2
  list(W1 = W1, W2 = W2, T3 = term3_from_q(sc, qmat), grid = sc$ft,
       obs = colSums(W1))
}

# ---- functional form / link (indexed by a COVARIATE VALUE, t integrated out) ----
# fvar: the variable whose values index the grid (Z[,j], or bhat'Z for the link).
proc_xaxis <- function(sc, fvar) {
  n <- sc$n; m <- sc$m; p <- sc$p
  grid <- sort(unique(fvar)); ng <- length(grid)
  F <- outer(fvar, grid, "<=") * 1.0                     # n x ng, 1{fvar_l <= x}

  # gbar(u, x) = s0(u)^-1 sum_l 1{fvar_l<=x} w_l Y_l e^{b'Z_l}
  gbar <- sweep(t(sc$W) %*% F, 1, sc$S0, "/")            # m x ng

  # term 1: sum over ALL event times of {F_i(x) - gbar(u,x)} * w_i dM_i(u).
  # F_i(x) does not depend on u, so its part is (sum_u w_i dM_i(u)) * F_i(x);
  # gbar does, so its part contracts dM against gbar over the event grid.
  W1 <- outer(rowSums(sc$dM), rep(1, ng)) * F - sc$dM %*% gbar

  # C(x) = -sum_k (d_k/S0_k) sum_l 1{fvar_l<=x} W_lk (Z_l - xbar_k)     (p x ng)
  Cx <- matrix(0, p, ng)
  for (k in seq_len(m)) {
    Zc <- sweep(sc$Z, 2, sc$xbar[k, ], "-")              # n x p
    Cx <- Cx - (sc$dk[k] / sc$S0[k]) * (t(Zc * sc$W[, k]) %*% F)
  }
  W2 <- ((sc$eta + sc$psi) %*% sc$Oi) %*% Cx

  # q(u, x) with the s-sum run to infinity: A_u(x) = sum_pre c_l F_l(x)
  cl <- sc$ev / sc$G
  pre <- sc$eps == 2
  Au <- matrix(0, sc$nu, ng); Cu <- numeric(sc$nu)
  for (a in seq_len(sc$nu)) {
    s <- pre & sc$X < sc$ut[a]
    Cu[a] <- sum(cl[s])
    if (any(s)) Au[a, ] <- colSums(cl[s] * F[s, , drop = FALSE])
  }
  base <- sc$Gev * sc$dk / sc$S0                          # length m
  kge <- outer(sc$ut, sc$ft, "<=")                        # nu x m
  P1 <- as.vector(kge %*% base)                           # nu
  P2 <- kge %*% (base * gbar)                             # nu x ng
  qmat <- Au * P1 - Cu * P2
  # The observed process is sum_i F_i(x) * (sum_u w_i dM_i(u)).  It equals
  # colSums(W1) because colSums(dM) is EXACTLY 0 at every event time
  # (d_u - S0_u * d_u/S0_u), which kills W1's gbar part in aggregate.  Asserted.
  stopifnot(max(abs(colSums(sc$dM))) < 1e-8 * max(abs(sc$dM)))
  list(W1 = W1, W2 = W2, T3 = term3_from_q(sc, qmat), grid = grid,
       obs = colSums(F * rowSums(sc$dM)))
}

mult_boot <- function(Wmat, obs, scale, K = 1000, seed = 11) {
  set.seed(seed)
  sup_obs <- max(abs(obs * scale))
  b <- replicate(K, max(abs(as.vector(rnorm(nrow(Wmat)) %*% Wmat) * scale)))
  list(sup = sup_obs, p = mean(b >= sup_obs))
}

# ---------------------------------------------------------------------------
# What Stata is checked against, and why it is not the p-value.
#
# p depends on the RNG stream, so R and Stata CANNOT agree on it to 1e-10 --
# and a check that compares p across languages would only ever be asserting
# "both drew 1000 normals", which is not the thing being ported.  The parts
# that ARE deterministic are exported instead:
#
#   obs        the observed process on the grid                (checks terms 1)
#   wv         V0' W  for a FIXED, non-random V0_i = sin(i)    (checks 1+2+3)
#
# wv is the multiplier bootstrap with the randomness removed: it contracts the
# FULL n x ngrid influence matrix down one axis with a vector Stata can
# reproduce exactly.  If any of the three terms, the tie multiplicity, or the
# term-3 factorisation is wrong, wv moves and obs may not -- terms 2 and 3 sum
# to zero across subjects at the identity points but not pointwise, so obs
# alone is blind to them.  That blindness is the whole reason this exists.
# ---------------------------------------------------------------------------
V0 <- function(n) sin(seq_len(n))

emit <- function(bag, fixture, test, term, grid, obs, Wf, scale) {
  bag[[length(bag) + 1]] <- data.frame(
    fixture = fixture, test = test, term = term, k = seq_along(grid),
    grid = grid, obs = obs, scale = scale,
    wv = as.vector(V0(nrow(Wf)) %*% Wf))
  bag
}

# ===========================================================================
# gof-c EXISTS TO EXERCISE TIED EVENT TIMES, and it was added because the
# port passed without it.
#
# Breslow tie multiplicity -- a time carrying d tied cause-1 events must
# contribute d times -- is the single most consequential detail in this build
# (~167% wrong when dropped).  gof-a and gof-b draw continuous exponential
# times, so every d_k is 1 and REPLACING THE WHOLE TIE COUNT WITH A CONSTANT 1
# CHANGES NOTHING: mutating the Mata that way left the check green at 4.5e-15,
# i.e. the check could not see the defect it most needed to see.
#
# gof-c snaps times onto a coarse grid so the tie axis is actually loaded.  The
# fixture asserts its own tie multiplicity below -- a fixture that silently
# stopped producing ties would restore the blind spot without any test failing.
FIX <- list(
  list(nm = "gof-a", n = 300, cens = 4.0, beta = c(0.5, -0.3), p1 = 0.6, seed = 5051, rnd = 0),
  list(nm = "gof-b", n = 250, cens = 2.0, beta = c(0.4,  0.6), p1 = 0.5, seed = 5052, rnd = 0),
  list(nm = "gof-c", n = 280, cens = 3.0, beta = c(0.5, -0.4), p1 = 0.6, seed = 5053, rnd = 0.1)
)

sim2 <- function(n, cens, beta, p1, seed, rnd = 0) {
  set.seed(seed)
  Z <- cbind(rnorm(n), rbinom(n, 1, 0.5))
  lp <- as.vector(Z %*% beta)
  u <- runif(n)
  cause <- ifelse(u <= p1 * exp(lp) / (1 + p1 * (exp(lp) - 1)), 1, 2)
  t <- rexp(n, rate = ifelse(cause == 1, 0.5, 0.8))
  C <- runif(n, 0, cens); e <- t <= C
  cause[!e] <- 0; t <- pmin(t, C)
  if (rnd > 0) t <- pmax(rnd, round(t / rnd) * rnd)
  data.frame(t = t, cause = cause, Z1 = Z[, 1], Z2 = Z[, 2])
}

allrows <- list(); k_row <- 0
proc_bag <- list(); beta_bag <- list()
for (f in FIX) {
  cat("=====================================================================\n")
  cat("fixture:", f$nm, "\n")
  d <- sim2(f$n, f$cens, f$beta, f$p1, f$seed, f$rnd)
  Zm <- as.matrix(d[, c("Z1", "Z2")])
  maxtie <- max(table(d$t[d$cause == 1]))
  cat(sprintf("  n=%d  cens=%.0f%%  cause1=%d  cause2=%d  max tie mult=%d\n",
              nrow(d), 100 * mean(d$cause == 0), sum(d$cause == 1),
              sum(d$cause == 2), maxtie))
  # A fixture that stopped producing ties would silently restore the blind spot
  # the mutation test exposed, so it is asserted rather than assumed.
  if (f$rnd > 0) stopifnot(maxtie >= 5)

  fit <- crr(d$t, d$cause, Zm, failcode = 1, cencode = 0)
  h <- fg_sandwich_hand(d$t, d$cause, Zm, fit$coef)
  stopifnot(max(abs(h$var_eta_psi / fit$var - 1)) < 1e-10)
  cat("  [ok] fg_sandwich_hand reproduces crr$var\n")
  # scaffold works on the SORTED data fg_sandwich_hand returned
  sc <- scaffold(h, fit$coef)
  SI <- sc$Oi
  sqSI <- sqrt(diag(SI))

  # Stata must run the processes at R's beta, not at its own fit.  finegray and
  # crr agree to ~1e-9 on beta, which is far LOOSER than the 1e-10 the process
  # check is asserting -- so refitting in Stata would make a correct port fail
  # for a reason that has nothing to do with the port.
  beta_bag[[length(beta_bag) + 1]] <- data.frame(
    fixture = f$nm, term = seq_len(sc$p), beta = as.vector(fit$coef),
    sqSI = sqSI)

  # ---- proportionality, both covariates ----
  Uall <- matrix(0, sc$m, sc$p)
  for (j in seq_len(sc$p)) {
    pr <- proc_prop(sc, j)
    Wf <- pr$W1 + pr$W2 + pr$T3
    e1 <- max(abs(pr$W1[, sc$m] - sc$eta[, j]))
    e2 <- max(abs(pr$W1[, sc$m] + pr$W2[, sc$m] + sc$psi[, j]))
    e3 <- max(abs(Wf[, sc$m]))
    scl <- max(abs(sc$eta[, j]))
    cat(sprintf("  prop j=%d  identities: term1=eta %.2e  +term2=-psi %.2e  W(tmax)=0 %.2e\n",
                j, e1, e2, e3))
    stopifnot(e1 / scl < TOL_IDENT, e2 / scl < TOL_IDENT, e3 / scl < TOL_IDENT)
    Uall[, j] <- pr$obs
    proc_bag <- emit(proc_bag, f$nm, "prop", j, pr$grid, pr$obs, Wf, sqSI[j])
    bb <- mult_boot(Wf, pr$obs, sqSI[j], K = 1000, seed = 300 + j)
    cat(sprintf("            sup=%.6f  p=%.3f\n", bb$sup, bb$p))
    k_row <- k_row + 1
    allrows[[k_row]] <- data.frame(fixture = f$nm, test = "prop", term = j,
                                   ngrid = sc$m, sup = bb$sup, p = bb$p,
                                   scale = sqSI[j])
  }
  # overall proportionality -- the ONLY place the standardizing factor does not cancel
  sup_ov <- max(rowSums(abs(sweep(Uall, 2, sqSI, "*"))))
  cat(sprintf("  prop OVERALL sup=%.6f  (uses sqSI=%s -- does NOT cancel)\n",
              sup_ov, paste(sprintf("%.5f", sqSI), collapse = ",")))
  k_row <- k_row + 1
  allrows[[k_row]] <- data.frame(fixture = f$nm, test = "prop_overall", term = 0,
                                 ngrid = sc$m, sup = sup_ov, p = NA, scale = NA)

  # ---- functional form, each covariate ----
  for (j in seq_len(sc$p)) {
    px <- proc_xaxis(sc, sc$Z[, j])
    Wf <- px$W1 + px$W2 + px$T3
    ng <- length(px$grid)
    e <- max(abs(Wf[, ng])); scl <- max(abs(sc$eta[, j]))
    cat(sprintf("  func j=%d  ngrid=%3d  identity W(xmax)=0 %.2e  (t1=%.2e t2=%.2e t3=%.2e)\n",
                j, ng, e, max(abs(px$W1[, ng])), max(abs(px$W2[, ng])),
                max(abs(px$T3[, ng]))))
    stopifnot(e / scl < TOL_IDENT)
    proc_bag <- emit(proc_bag, f$nm, "func", j, px$grid, px$obs, Wf, 1)
    bb <- mult_boot(Wf, px$obs, 1, K = 1000, seed = 400 + j)
    cat(sprintf("            sup=%.6f  p=%.3f\n", bb$sup, bb$p))
    k_row <- k_row + 1
    allrows[[k_row]] <- data.frame(fixture = f$nm, test = "func", term = j,
                                   ngrid = ng, sup = bb$sup, p = bb$p, scale = 1)
  }

  # ---- link function ----
  lp <- as.vector(sc$Z %*% sc$beta)
  px <- proc_xaxis(sc, lp)
  Wf <- px$W1 + px$W2 + px$T3
  ng <- length(px$grid)
  e <- max(abs(Wf[, ng]))
  cat(sprintf("  link      ngrid=%3d  identity W(xmax)=0 %.2e\n", ng, e))
  stopifnot(e / max(abs(sc$eta)) < TOL_IDENT)
  proc_bag <- emit(proc_bag, f$nm, "link", 0, px$grid, px$obs, Wf, 1)
  bb <- mult_boot(Wf, px$obs, 1, K = 1000, seed = 500)
  cat(sprintf("            sup=%.6f  p=%.3f\n", bb$sup, bb$p))
  k_row <- k_row + 1
  allrows[[k_row]] <- data.frame(fixture = f$nm, test = "link", term = 0,
                                 ngrid = ng, sup = bb$sup, p = bb$p, scale = 1)

  # export the fixture itself so Stata reads the SAME data
  write.csv(d, file.path(OUT, paste0(f$nm, ".csv")), row.names = FALSE)
  cat("\n")
}

ref <- do.call(rbind, allrows)
write.csv(ref, file.path(OUT, "reference_gof.csv"), row.names = FALSE)
cat("wrote", nrow(ref), "reference rows to", file.path(OUT, "reference_gof.csv"), "\n")
print(ref, row.names = FALSE)

pb <- do.call(rbind, proc_bag)
write.csv(pb, file.path(OUT, "reference_proc.csv"), row.names = FALSE)
bb <- do.call(rbind, beta_bag)
write.csv(bb, file.path(OUT, "reference_beta.csv"), row.names = FALSE)
cat(sprintf("\nwrote %d process rows and %d beta rows\n", nrow(pb), nrow(bb)))
cat("\nOK\n")

# ===========================================================================
# SECOND PASS: score the beta Stata actually converged to.
#
# WHY THIS EXISTS.  The obvious cross-check -- "finegray's beta agrees with
# crr's" -- is the WRONG assertion, and asserting it fails a correct port.
# Measured on these three fixtures, evaluating the oracle's own score
# colSums(eta) (which is 0 at the solution and belongs to neither package):
#
#     fixture   |U| at crr's beta   |U| at finegray's beta
#     gof-a           1.3e-09              4.1e-14
#     gof-b           5.4e-05              1.9e-11
#     gof-c           3.1e-08              9.3e-15
#
# finegray solves the estimating equation BETTER than crr does, by four to six
# orders of magnitude.  On gof-b, where the last cause-1 event lands at the very
# end of follow-up and Ghat(t-) has fallen to 0.02 -- so the IPCW weights are
# amplified ~50x -- crr stops at |U| = 5.4e-05 and the two betas part company at
# 9e-06 relative.  Pinning finegray to crr's beta would therefore hold the
# package to a less-converged reference and would break whenever crr's
# convergence happened to be poor on some future fixture.
#
# So the assertion is on the SCORE, not on agreement with crr: whatever beta
# finegray reports must solve the oracle's estimating equation.  That is a
# stronger claim and an independent one -- fg_sandwich_hand() computes eta from
# the formulae and calls no estimation library.
#
# This pass runs only when crossval_gof.do has written data/stata_beta.csv, so
# a first-pass generation (fixtures + references) is unaffected.
# ===========================================================================
sb_path <- file.path(OUT, "stata_beta.csv")
if (file.exists(sb_path)) {
  sb <- read.csv(sb_path, stringsAsFactors = FALSE)
  rows <- list()
  for (f in FIX) {
    d  <- sim2(f$n, f$cens, f$beta, f$p1, f$seed, f$rnd)
    Zm <- as.matrix(d[, c("Z1", "Z2")])
    fit <- crr(d$t, d$cause, Zm, failcode = 1, cencode = 0)
    bs  <- as.numeric(sb[sb$fixture == f$nm, c("b1", "b2")])
    stopifnot(length(bs) == 2, !any(is.na(bs)))
    hC <- fg_sandwich_hand(d$t, d$cause, Zm, fit$coef)
    hS <- fg_sandwich_hand(d$t, d$cause, Zm, bs)
    scl <- max(abs(hC$eta))
    u_crr   <- max(abs(colSums(hC$eta))) / scl
    u_stata <- max(abs(colSums(hS$eta))) / scl
    cat(sprintf("score %s: |U(crr)|=%.3e  |U(stata)|=%.3e  (eta scale %.2e)\n",
                f$nm, u_crr, u_stata, scl))
    rows[[length(rows) + 1]] <- data.frame(
      fixture = f$nm, u_crr = u_crr, u_stata = u_stata,
      gmin = min(ghat_minus(d$t, d$cause, sort(d$t[d$cause == 1]))))
  }
  write.csv(do.call(rbind, rows), file.path(OUT, "reference_score.csv"),
            row.names = FALSE)
  cat("wrote data/reference_score.csv\n")
}
