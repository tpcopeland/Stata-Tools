# ---------------------------------------------------------------------
# crossval_nuisance_r.R -- oracle side of the FG (1999) eq. (7)-(8) crossval.
#
# PURPOSE.  Regenerate qa/data/*.csv and qa/data/reference_answers.csv, the
# parity fixtures and reference variances that test_finegray_nuisance.do
# asserts against.  Shipping the generator keeps the reference REPRODUCIBLE
# inside this repository: without it the CSVs would be numbers of unknown
# provenance that no one could re-derive.
#
# WHAT THE ORACLE IS.  fg_sandwich_hand() below implements Fine & Gray (1999)
# eq. (7)-(8) (sec. 4, pp. 500-501) directly from the formulae.  It calls no
# estimation library -- given (X, eps, Z, beta) it computes eta, psi, Omega
# and both sandwiches from scratch.  It is validated here, at generation time,
# against cmprsk::crr, whose Fortran variance routine `crrvv' is by R. J. Gray,
# the paper's second author.  The script ABORTS if that agreement is not
# reached, so a drifted oracle cannot silently emit a reference.
#
# The formulae and the three conventions that silently break them are
# documented in _finegray_mata.ado above _finegray_psi_residuals().
#
# Usage (from finegray/qa):
#   Rscript crossval_nuisance_r.R
#
# Requires: R with survival and cmprsk (see qa/_r_environment.txt).
# ---------------------------------------------------------------------

suppressMessages({library(survival); library(cmprsk)})

# ---------------------------------------------------------------------------
# ORACLE TOOLCHAIN BANNER (added 2026-09-02).  run_all.sh records "R_version"
# in the receipt, but it does that by asking Rscript at RECEIPT time -- after
# every oracle has already run, and saying nothing at all about which package
# versions produced the numbers.  A crossval whose oracle silently moved from
# one package release to another is exactly the drift a cross-validation exists
# to catch, so every crossval_*_r.R prints its own R and package versions to
# stdout, where the suite's .do file echoes them into the run log.
.fg_banner <- function(pkgs) {
    cat(sprintf("R_ENV: script=%s R=%s platform=%s\n",
                "crossval_nuisance_r.R", as.character(getRversion()), R.version$platform))
    for (p in pkgs) {
        v <- tryCatch(as.character(utils::packageVersion(p)),
                      error = function(e) "NOT-INSTALLED")
        cat(sprintf("R_ENV: package %s = %s\n", p, v))
    }
}
.fg_banner(c("survival", "cmprsk"))

# Censoring KM at t-, matching cmprsk.R:69-82 exactly.
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
# estimated WITHIN each group, so the censoring martingale, Y_g and the
# retained-competing sums are per group:
#
#   q_g(t) = sum_{s>=t, s ANY cause-1 event time} d_s
#              [S1_2^g(s,t) - xbar(s) S0_2^g(s,t)] / S0(s)
#     Only the INNER sums (the retained competing subjects, whose weights
#     carry Ghat_g) are group-restricted.  The outer sum runs over every
#     cause-1 event: a group-g subject retained after a competing event sits
#     in the shared risk set of every later cause-1 event, whichever group
#     that event's subject belongs to, so Ghat_g's influence reaches them all.
#     S0(s) and xbar(s) stay GLOBAL.
#   Y_g(u) = #{j : g(j)=g, X_j >= u}
#   psi_i  = 1{eps_i=0} q_{g(i)}(X_i)/Y_{g(i)}(X_i)
#            - sum_{u <= X_i} dNc_g(u) q_g(u)/Y_g(u)^2
#
# HISTORY (2026-09-12, finegray 1.3.3).  Until 1.3.3 this oracle -- and the
# package -- restricted the OUTER sum to cause-1 events from group g as well,
# reproducing cmprsk::crr's crrvv (crr.f:379 accumulates `qu(k, icg(j1))`,
# the group of the EVENT subject j1, from `ss3(k, icg(j1))` only, discarding
# the other groups' slices it has just computed).  A censoring group holding
# competing events but no cause-1 events then contributed an identically
# zero psi, while perturbing its censoring KM visibly moved the fitted score.
# The oracle agreed with crr at 1e-8 on every multi-group fixture and was
# structurally blind to the omission.  It is therefore no longer pinned to
# crr on multi-group fixtures; there it is pinned to a NUMERICAL DERIVATIVE
# of the score (fg_numeric_q below), with the within-group form kept only to
# show that the difference from crr is exactly the cross-group terms.
#
fg_sandwich_hand <- function(X, eps, Z, beta, cg = NULL, crr_form = FALSE) {
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
    if (crr_form) {
      # crr's within-group form, kept ONLY for the crr-difference check
      ftg  <- sort(unique(X[eps == 1 & ing]))
      dkg  <- as.vector(table(factor(X[eps == 1 & ing], levels = ftg)))
      kidx <- match(ftg, ft)
    } else {
      ftg  <- ft                                   # EVERY cause-1 event time
      dkg  <- dk
      kidx <- seq_len(m)
    }
    for (a in seq_len(nu)) {
      pre <- which(X < ut[a] & eps == 2 & ing)     # group-restricted: carries Ghat_g
      sel <- which(ftg >= ut[a])
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
# NUMERICAL DERIVATIVE OF THE SCORE (added 2026-09-12).  q_g(u) is, by
# definition, dU / d lambda_g(u): the response of the score to a unit
# censoring-hazard increment of group g at u, which scales Ghat_g(t) by
# exp(-lambda) for every t >= u.  So q_g(u) can be obtained with no psi
# machinery at all: rebuild the weights from a scaled Ghat_g, re-evaluate the
# score at the fitted beta, and take a central difference.  It shares the
# estimating equation with the oracle (that IS what the psi term is about)
# and nothing else.  Applied with the same I(X_j < u <= t_k) tie convention
# as eq. (7)-(8) and crr: G at subject times X_j >= u and at event times
# t_k >= u are scaled.  On distinct times that is the unique derivative.
# Returns the max relative difference between the oracle's q and the
# numerical one over every (censoring time, group) cell that carries dNc.
fg_numeric_q_check <- function(h, beta, eps_fd = 1e-5) {
  X <- h$X; eps <- h$eps; Z <- h$Z; cg <- h$cg; ut <- h$times
  n <- length(X); p <- ncol(Z); ug <- sort(unique(cg))
  ev  <- exp(as.vector(Z %*% beta))
  ft  <- sort(unique(X[eps == 1])); m <- length(ft)
  G0  <- h$G
  Gev0 <- matrix(1, m, length(ug))
  for (g in ug) {
    s <- which(cg == g)
    Gev0[, g] <- ghat_minus(X[s], eps[s], ft)
  }
  score <- function(G, Gev) {
    rmat <- matrix(0, n, m)
    for (k in seq_len(m))
      rmat[, k] <- ifelse(X >= ft[k], 1, ifelse(eps == 2, Gev[k, cg] / G, 0))
    W    <- rmat * ev
    S0   <- colSums(W)
    xbar <- (t(W) %*% Z) / S0
    ki   <- match(X[eps == 1], ft)
    colSums(Z[eps == 1, , drop = FALSE] - xbar[ki, , drop = FALSE])
  }
  worst <- 0; qmax <- max(abs(h$q))
  for (g in ug) {
    ing <- cg == g
    for (a in seq_along(ut)) {
      u <- ut[a]
      if (!any(ing & eps == 0 & X == u)) next     # only cells carrying dNc_g
      Gp <- G0; Gm <- G0; Gvp <- Gev0; Gvm <- Gev0
      sj <- ing & X >= u; sk <- ft >= u
      Gp[sj] <- Gp[sj] * exp(-eps_fd); Gm[sj] <- Gm[sj] * exp(eps_fd)
      Gvp[sk, g] <- Gvp[sk, g] * exp(-eps_fd); Gvm[sk, g] <- Gvm[sk, g] * exp(eps_fd)
      qn <- (score(Gp, Gvp) - score(Gm, Gvm)) / (2 * eps_fd)
      worst <- max(worst, max(abs(qn - h$q[a, , g])) / qmax)
    }
  }
  worst
}

# ---------------------------------------------------------------------
# Fixtures.  Each is chosen to be able to FAIL for a specific reason:
#   f1  n=20, integer times, ONE cause-1 event per time -- hand-checkable,
#       and deliberately blind to tie multiplicity (see f4)
#   f2  n=40, strictly distinct times -- isolates ties out entirely
#   f4  n=60, up to 5 tied cause-1 events per time -- the Breslow
#       multiplicity regression fixture
#   f5  n=120, 3 censoring strata + heavy ties -- the per-stratum q
#       regression fixture
#   pbc n=416, 5 covariates -- realistic, multivariate, mildly tied
# ---------------------------------------------------------------------
OUT <- "data"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

set.seed(11)
F2 <- data.frame(X = round(sort(runif(40, .5, 20)) + seq_len(40) * 1e-3, 4),
                 eps = rep(c(1,2,1,0,1,1,2,0), 5), Z = rbinom(40, 1, .5))
set.seed(7)
F4 <- data.frame(X = sort(sample(1:25, 60, replace = TRUE)),
                 eps = rep(c(1,2,1,0,1,1), 10))
F4$Z <- rbinom(60, 1, .5); F4$Z2 <- round(rnorm(60), 3)
set.seed(21)
F5 <- data.frame(X = sample(1:18, 120, TRUE), eps = sample(c(1,1,2,0), 120, TRUE))
F5$Z  <- rbinom(120, 1, .5)
F5$Z2 <- round(rnorm(120), 2)
F5$cg <- sample(1:3, 120, TRUE)

data(pbc, package = "survival")
pb <- pbc[!is.na(pbc$protime), ]
PBC <- data.frame(
  X = pb$time,
  eps = ifelse(pb$status == 2, 1, ifelse(pb$status == 1, 2, 0)),
  Z = log(pb$bili), Z2 = log(pb$protime), Z3 = log(pb$albumin),
  Z4 = pb$age, Z5 = pb$edema)

FIX <- list(
  f1 = data.frame(
    X   = c(1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,10,11,12),
    eps = c(1,0,1,2,1,0,2,1,0,1,1,2,0,1,2,1,0,1, 2, 0),
    Z   = c(0,1,1,0,0,1,1,0,1,0,1,1,0,1,0,1,1,0, 1, 0)),
  f2 = F2, f4 = F4, f5 = F5, pbc = PBC)

# Oracle cache (added 2026-09-04): this script is a pure function of its
# inputs, so its output is cached and only recomputed when an input changes.
# See _fg_oracle_cache.R for the key and the fail-closed rules.
source(file.path(dirname(sub("^--file=", "", grep("^--file=",
       commandArgs(FALSE), value = TRUE)[1])), "_fg_oracle_cache.R"))
.fgc <- fg_oracle_cache_begin("nuisance",
        outputs = c(file.path(OUT, paste0(names(FIX), ".csv")),
                    file.path(OUT, c("reference_answers.csv",
                                     "reference_cov.csv"))),
        packages = c("survival", "cmprsk"))
if (identical(.fgc$state, "hit")) quit(save = "no", status = 0)

TOL <- 1e-8
ref  <- list()
cref <- list()
for (nm in names(FIX)) {
  f  <- FIX[[nm]]
  Zc <- grep("^Z", names(f), value = TRUE)
  Zm <- as.matrix(f[, Zc, drop = FALSE])
  cg <- if ("cg" %in% names(f)) f$cg else rep(1L, nrow(f))
  fit <- if ("cg" %in% names(f))
           crr(f$X, f$eps, Zm, cengroup = cg, failcode = 1, cencode = 0)
         else crr(f$X, f$eps, Zm, failcode = 1, cencode = 0)
  h <- fg_sandwich_hand(f$X, f$eps, Zm, fit$coef, cg = cg)

  # FAIL CLOSED.  If the from-the-formulae oracle no longer reproduces its
  # reference, emit nothing -- a drifted oracle must not quietly become the
  # reference.  ONE censoring group: the reference is crr (R. J. Gray's own
  # crrvv) at 1e-8.  SEVERAL: crr omits the cross-group terms (see the
  # HISTORY note above), so the reference is the numerical derivative of the
  # score; the within-group form must still reproduce crr at 1e-8 (that pins
  # the ties, the KM conventions and the martingale integral), and the full
  # oracle must differ from crr by MORE than the parity tolerance the Stata
  # side applies, or a reversion to crr's form could pass.
  rel <- max(abs(h$var_eta_psi - fit$var)) / max(abs(fit$var))
  ngrp <- length(unique(cg))
  if (ngrp == 1) {
    if (!is.finite(rel) || rel > TOL)
      stop(sprintf("oracle disagrees with cmprsk::crr on %s: rel = %.3e", nm, rel))
    qrel <- NA
  } else {
    hw <- fg_sandwich_hand(f$X, f$eps, Zm, fit$coef, cg = cg, crr_form = TRUE)
    relw <- max(abs(hw$var_eta_psi - fit$var)) / max(abs(fit$var))
    if (!is.finite(relw) || relw > TOL)
      stop(sprintf("within-group form disagrees with cmprsk::crr on %s: rel = %.3e", nm, relw))
    if (!is.finite(rel) || rel < 1e-5)
      stop(sprintf("full oracle does not differ from crr on %s (rel = %.3e): cannot discriminate the cross-group terms", nm, rel))
    qrel <- fg_numeric_q_check(h, fit$coef)
    if (!is.finite(qrel) || qrel > 1e-6)
      stop(sprintf("oracle q disagrees with the numerical score derivative on %s: rel = %.3e", nm, qrel))
  }
  # and the two columns must be distinguishable, or the reference cannot
  # discriminate an implementation that ignores psi
  gap <- max(abs(diag(as.matrix(h$var_eta_psi)) / diag(as.matrix(h$var_eta)) - 1))
  if (gap < 1e-4)
    stop(sprintf("fixture %s cannot discriminate psi (max gap %.2e)", nm, gap))
  # `rel' above is a max over the WHOLE matrix, so the oracle's off-diagonals
  # are already pinned to crr.  The covariances must additionally be able to
  # discriminate psi, or asserting on them proves nothing.
  if (length(Zc) >= 2) {
    ut  <- upper.tri(as.matrix(h$var_eta))
    cgp <- max(abs(as.matrix(h$var_eta_psi)[ut] / as.matrix(h$var_eta)[ut] - 1))
    if (cgp < 1e-4)
      stop(sprintf("fixture %s covariances cannot discriminate psi (max gap %.2e)",
                   nm, cgp))
  }

  write.csv(f, file.path(OUT, paste0(nm, ".csv")), row.names = FALSE)
  for (k in seq_along(Zc))
    ref[[length(ref) + 1]] <- data.frame(
      fixture = nm, term = Zc[k], beta = fit$coef[k],
      var_eta     = as.matrix(h$var_eta)[k, k],
      var_eta_psi = as.matrix(h$var_eta_psi)[k, k],
      var_crr     = fit$var[k, k],
      n_ties_ev   = max(table(f$X[f$eps == 1])),
      n_cengroup  = length(unique(cg)))

  # OFF-DIAGONALS.  psi's effect is concentrated in the COVARIANCES, not the
  # variances: on a p=2 fixture the off-diagonal moves ~1.6% where the
  # diagonals move -0.07% and +0.38%.  A psi defect confined to the
  # cross-product assembly -- a transposition, a wrong outer-product order --
  # therefore reproduces every variance and corrupts every multi-coefficient
  # Wald test, `test', and `lincom'.  Emit the covariances so the Stata side
  # can assert on the entry the user's inference actually depends on.
  if (length(Zc) >= 2)
    for (a in seq_len(length(Zc) - 1))
      for (b in seq(a + 1, length(Zc)))
        cref[[length(cref) + 1]] <- data.frame(
          fixture = nm, term_i = Zc[a], term_j = Zc[b],
          cov_eta     = as.matrix(h$var_eta)[a, b],
          cov_eta_psi = as.matrix(h$var_eta_psi)[a, b],
          cov_crr     = fit$var[a, b],
          n_cengroup  = ngrp)
  cat(sprintf("%-4s n=%-4d p=%d ties=%d groups=%d  rel_vs_crr=%.2e  psi_gap=%.2e  q_vs_numeric=%s\n",
              nm, nrow(f), length(Zc), max(table(f$X[f$eps == 1])),
              length(unique(cg)), rel, gap,
              if (is.na(qrel)) "n/a" else sprintf("%.2e", qrel)))
}
ref <- do.call(rbind, ref)
write.csv(ref, file.path(OUT, "reference_answers.csv"), row.names = FALSE)
cat("\nwrote", nrow(ref), "reference rows to", file.path(OUT, "reference_answers.csv"), "\n")

cref <- do.call(rbind, cref)
write.csv(cref, file.path(OUT, "reference_cov.csv"), row.names = FALSE)
fg_oracle_cache_end(.fgc)
cat("wrote", nrow(cref), "covariance rows to", file.path(OUT, "reference_cov.csv"), "\n")

# The measured psi effect, as a RANGE over every reference variance.  The help
# file and README quote this; printing it here means the quoted numbers have a
# generator rather than being remembered from one fixture.
pe <- 100 * (ref$var_eta_psi / ref$var_eta - 1)
se <- 100 * (sqrt(ref$var_eta_psi) / sqrt(ref$var_eta) - 1)
cat(sprintf("psi effect on VARIANCE: %+.2f%% to %+.2f%%\n", min(pe), max(pe)))
cat(sprintf("psi effect on SE      : %+.2f%% to %+.2f%%\n", min(se), max(se)))
cat("OK\n")
