# crossval_iivw_stacked_geex.R
#
# Reference for iivw_fit, vce(stacked): the stacked M-estimation sandwich of
# Saul & Hudgens (2020, J Stat Softw 92(2), eq. 1-2 and 4), assembled by geex.
#
# Everything the sandwich needs is written here as an estimating function of one
# independent subject; geex (not iivw's formula) differentiates the stacked
# system for A and sums the outer products for B. Nothing below is taken from
# iivw's weights, scores or information matrices: the R side refits the Cox
# visit model, the propensity logit and the weighted outcome regression from the
# raw panel and uses iivw's output only as the thing to be compared against.
#
# Conventions matched to iivw (each one a deliberate choice, named in the suite):
#   * Visit model: Andersen-Gill counting process. Under baseline(entry) the
#     first visit is study entry; events are visits 2..J; risk intervals are
#     (t_{j-1}, t_j] with the covariates of row j; a terminal censoring interval
#     (t_J, maxfu] with the covariates carried forward from row J.
#   * Ties: visit times are continuous in the fixtures, so Breslow, Efron and
#     the exact partial likelihood have the same score. The script asserts that
#     no two event times coincide and that coxph(ties="efron") and
#     coxph(ties="breslow") agree, so the tie convention cannot matter.
#   * IIW weight: exp(delta'S - gamma'Z) / c at modeled events, c the mean of
#     the numerator over modeled events, and exactly 1 at the entry row.
#   * IPTW weight: p/e(K) for A=1, (1-p)/(1-e(K)) for A=0, e from a logit on one
#     row per subject, p = mean(A) over those subjects.
#   * FIPTIW weight: IIW x IPTW (the visit model also contains A).
#   * Outcome: weighted least squares of y on (A, z1, t, 1), independence GEE.
#
# Two stackings are produced for the outcome-block covariance:
#   "closure" - the mean-1 divisor c is a DETERMINISTIC function of gamma (and
#               delta), exactly how iivw_weight differentiates it
#               (d log w / d gamma = -(Z - weight-weighted mean Z)). Comparable
#               to iivw to numerical precision.
#   "param"   - c is a parameter with its own estimating equation
#               sum(exp(..) - c) = 0, so its sampling noise propagates too.
#               This is the full M-estimator of the weight as shipped; it is
#               reported, and the suite states what it does and does not equal.
# For the stabilized arm a third stacking adds delta (numerator Cox) as an
# estimated parameter; iivw leaves delta fixed (Buzkova & Lumley 2007, p.9-11).
#
# Provenance: one REFERENCE line per reference package, read from the installed
# copy at run time (the devkit receipt records it next to the numbers).
for (p in c("survival", "geex"))
  cat(sprintf("REFERENCE: %s %s\n", p, as.character(utils::packageVersion(p))))

# Usage: Rscript crossval_iivw_stacked_geex.R --indir=DIR --outdir=DIR

suppressPackageStartupMessages({
  library(survival)
  library(geex)
})

args <- commandArgs(trailingOnly = TRUE)
getarg <- function(nm) {
  hit <- grep(paste0("^--", nm, "="), args, value = TRUE)
  if (length(hit) != 1) stop("missing --", nm)
  sub(paste0("^--", nm, "="), "", hit)
}
indir <- getarg("indir")
outdir <- getarg("outdir")
maxfu <- as.numeric(getarg("maxfu"))

# arm table: name, visit covariates, stabilization covariates, treatment weight
arms <- list(
  iiw      = list(viscov = c("z1", "zl"),      stab = NULL,   tw = FALSE),
  iiwstab  = list(viscov = c("z1", "zl"),      stab = "z1",   tw = FALSE),
  iptw     = list(viscov = NULL,               stab = NULL,   tw = TRUE),
  fiptiw   = list(viscov = c("z1", "zl", "a"), stab = NULL,   tw = TRUE)
)

# Cox score contributions, one row per subject, at gamma, for covariate matrix
# Zc over the Andersen-Gill rows cr (start, stop, event). Breslow/no-ties form:
#   psi_i = sum_{events of i} (Z - zbar(t)) - sum_{rows of i} int Y e^{g'Z}
#           (Z - zbar(s)) dLambda0(s),  dLambda0(s) = 1/S0(s) at each event time.
# Summed over subjects this is the partial-likelihood score at any gamma.
cox_rows_score <- function(Z, start, stop, ev, uid, m, gam) {
  # Same quantity as the dense at-risk-matrix form, evaluated with sorted
  # cumulative sums: row l is at risk at event time s iff start_l < s <= stop_l.
  q <- ncol(Z)
  r <- as.vector(exp(Z %*% gam))
  Zr <- Z * r
  E <- which(ev == 1)
  s <- stop[E]
  os <- order(s); sE <- s[os]
  ost <- order(stop); stop_s <- stop[ost]
  osa <- order(start); start_s <- start[osa]
  cnt_stop <- findInterval(s, stop_s, left.open = TRUE)    # rows with stop < s
  cnt_start <- findInterval(s, start_s, left.open = TRUE)  # rows with start < s
  cum <- function(x, o) rbind(0, apply(as.matrix(x), 2, function(v) cumsum(v[o])))
  r0 <- sum(r)
  # rows at risk = (stop >= s) minus (start >= s): totals less those below s
  A0 <- r0 - cum(r, ost)[cnt_stop + 1, 1]
  B0 <- r0 - cum(r, osa)[cnt_start + 1, 1]
  S0 <- A0 - B0
  rz <- colSums(Zr)
  A1 <- sweep(-cum(Zr, ost)[cnt_stop + 1, , drop = FALSE], 2, rz, "+")
  B1 <- sweep(-cum(Zr, osa)[cnt_start + 1, , drop = FALSE], 2, rz, "+")
  S1 <- A1 - B1
  zbar <- S1 / S0
  evpart <- matrix(0, nrow(Z), q)
  evpart[E, ] <- Z[E, , drop = FALSE] - zbar
  h0 <- 1 / S0
  h1 <- zbar / S0
  # cumulative over event times in ascending order; H(x) = sum over s_k <= x
  H0 <- c(0, cumsum(h0[os]))
  H1 <- rbind(0, apply(h1, 2, function(v) cumsum(v[os])))
  ia <- findInterval(stop, sE)
  ib <- findInterval(start, sE)
  w0 <- H0[ia + 1] - H0[ib + 1]
  w1 <- H1[ia + 1, , drop = FALSE] - H1[ib + 1, , drop = FALSE]
  comp <- r * (Z * w0 - w1)
  rowpsi <- evpart - comp
  out <- matrix(0, m, q)
  for (k in seq_len(q)) out[, k] <- as.vector(rowsum(rowpsi[, k], uid, reorder = FALSE)[as.character(seq_len(m)), ])
  out
}

run_arm <- function(nm) {
  cfg <- arms[[nm]]
  d <- read.csv(file.path(indir, paste0("panel_", nm, ".csv")))
  d <- d[order(d$id, d$t), ]
  d$uid <- match(d$id, unique(d$id))
  m <- max(d$uid)
  d$entry <- as.integer(!duplicated(d$uid))
  d$nvis <- ave(d$t, d$uid, FUN = length)
  d$last <- as.integer(!duplicated(d$uid, fromLast = TRUE))
  d$start <- ave(d$t, d$uid, FUN = function(x) c(NA, head(x, -1)))
  d$stop <- d$t
  d$ev <- 1L - d$entry
  d$cens <- 0L
  # terminal censoring rows: copy of the last visit row, interval (t_J, maxfu]
  need <- d$last == 1 & d$t < maxfu
  cr <- d[need, ]
  cr$start <- cr$t; cr$stop <- maxfu; cr$ev <- 0L; cr$cens <- 1L; cr$entry <- 0L
  cr$y <- NA_real_
  ext <- rbind(d, cr)
  ext <- ext[order(ext$uid, ext$cens, ext$stop), ]
  rownames(ext) <- NULL
  ext$out <- 1 - ext$cens           # outcome rows: every visit row
  ext$first <- as.integer(!duplicated(ext$uid))  # the logit row, once per subject
  ext$cons <- 1
  viscov <- cfg$viscov; stab <- cfg$stab
  hascox <- length(viscov) > 0
  hasstab <- length(stab) > 0
  xcols <- c("a", "z1", "t", "cons")
  nx <- length(xcols)

  # ---- independent point estimates ---------------------------------------
  coxrows <- ext$entry == 0
  gam <- delta <- numeric(0)
  if (hascox) {
    cd <- ext[coxrows, ]
    stopifnot(!anyDuplicated(cd$stop[cd$ev == 1]))   # continuous time: no ties
    fb <- coxph(as.formula(paste("Surv(start, stop, ev) ~", paste(viscov, collapse = "+"))),
                data = cd, ties = "breslow", control = coxph.control(eps = 1e-12, iter.max = 50))
    fe <- coxph(as.formula(paste("Surv(start, stop, ev) ~", paste(viscov, collapse = "+"))),
                data = cd, ties = "efron", control = coxph.control(eps = 1e-12, iter.max = 50))
    stopifnot(max(abs(coef(fb) - coef(fe))) < 1e-9)
    gam <- unname(coef(fb))
    if (hasstab) {
      sb <- coxph(as.formula(paste("Surv(start, stop, ev) ~", paste(stab, collapse = "+"))),
                  data = cd, ties = "breslow", control = coxph.control(eps = 1e-12, iter.max = 50))
      delta <- unname(coef(sb))
    }
  }
  # raw numerator/denominator and the weights
  Zall <- if (hascox) as.matrix(ext[, viscov, drop = FALSE]) else NULL
  Sall <- if (hasstab) as.matrix(ext[, stab, drop = FALSE]) else NULL
  rawfun <- function(gam, delta, rows) {
    lp <- -as.vector(Zall[rows, , drop = FALSE] %*% gam)
    if (hasstab) lp <- lp + as.vector(Sall[rows, , drop = FALSE] %*% delta)
    exp(lp)
  }
  evrows <- which(ext$ev == 1)
  cval <- 1
  iw <- rep(1, nrow(ext))
  if (hascox) {
    e <- rawfun(gam, delta, evrows)
    cval <- mean(e)
    iw[evrows] <- e / cval
  }
  alpha <- numeric(0); pval <- NA_real_
  tw <- rep(1, nrow(ext))
  if (cfg$tw) {
    sub <- ext[ext$first == 1, ]
    lg <- glm(a ~ k1, data = sub, family = binomial())
    alpha <- unname(coef(lg))  # (k1, cons) order below
    alpha <- c(alpha[2], alpha[1])
    pval <- mean(sub$a)
    ps <- plogis(alpha[1] * ext$k1 + alpha[2])
    tw <- ifelse(ext$a == 1, pval / ps, (1 - pval) / (1 - ps))
  }
  w <- iw * tw
  ow <- ext$out == 1
  fitw <- lm(y ~ a + z1 + t, data = ext[ow, ], weights = w[ow])
  beta <- unname(coef(fitw)[c("a", "z1", "t", "(Intercept)")])

  # ---- the stacked estimating function ------------------------------------
  build <- function(mode) {
    # mode: "closure" (c deterministic), "param" (c estimated),
    #       "delta" (closure c, delta estimated)
    estc <- mode == "param" && hascox
    estd <- mode == "delta" && hasstab
    pos <- list(); k <- 0
    add <- function(nm, n) { pos[[nm]] <<- k + seq_len(n); k <<- k + n }
    add("beta", nx)
    if (hascox) add("gam", length(viscov))
    if (estd) add("delta", length(stab))
    if (estc) add("c", 1)
    if (cfg$tw) { add("alpha", 2); add("p", 1) }
    npar <- k
    theta0 <- numeric(npar)
    theta0[pos$beta] <- beta
    if (hascox) theta0[pos$gam] <- gam
    if (estd) theta0[pos$delta] <- delta
    if (estc) theta0[pos$c] <- cval
    if (cfg$tw) { theta0[pos$alpha] <- alpha; theta0[pos$p] <- pval }

    cache <- new.env()
    glob <- function(theta) {
      key <- paste(format(theta, digits = 17), collapse = "|")
      if (!is.null(cache$key) && identical(cache$key, key)) return(cache$val)
      g <- if (hascox) theta[pos$gam] else numeric(0)
      dl <- if (estd) theta[pos$delta] else delta
      val <- list()
      if (hascox) {
        val$cox <- cox_rows_score(Zall[coxrows, , drop = FALSE], ext$start[coxrows],
                                  ext$stop[coxrows], ext$ev[coxrows], ext$uid[coxrows], m, g)
        if (estd) {
          Sc <- as.matrix(ext[coxrows, stab, drop = FALSE])
          val$coxd <- cox_rows_score(Sc, ext$start[coxrows], ext$stop[coxrows],
                                     ext$ev[coxrows], ext$uid[coxrows], m, dl)
        }
        val$cclos <- mean(rawfun(g, dl, evrows))
      }
      cache$key <- key; cache$val <- val
      val
    }
    estFUN <- function(data) {
      i <- data$uid[1]
      Xm <- as.matrix(data[, xcols, drop = FALSE])
      yv <- data$y
      ow_i <- data$out == 1
      Zi <- if (hascox) as.matrix(data[, viscov, drop = FALSE]) else NULL
      Si <- if (hasstab) as.matrix(data[, stab, drop = FALSE]) else NULL
      isev <- data$ev == 1
      k1i <- data$k1; ai <- data$a
      f1 <- which(data$first == 1)
      function(theta) {
        G <- glob(theta)
        b <- theta[pos$beta]
        # IIW part
        iwi <- rep(1, nrow(data))
        if (hascox) {
          g <- theta[pos$gam]
          dl <- if (estd) theta[pos$delta] else delta
          lp <- -as.vector(Zi %*% g)
          if (hasstab) lp <- lp + as.vector(Si %*% dl)
          cc <- if (estc) theta[pos$c] else G$cclos
          iwi[isev] <- exp(lp[isev]) / cc
        }
        twi <- rep(1, nrow(data))
        if (cfg$tw) {
          al <- theta[pos$alpha]; p <- theta[pos$p]
          ps <- plogis(al[1] * k1i + al[2])
          twi <- ifelse(ai == 1, p / ps, (1 - p) / (1 - ps))
        }
        wi <- iwi * twi
        res <- numeric(length(theta))
        r <- ifelse(ow_i, yv - as.vector(Xm %*% b), 0)
        res[pos$beta] <- colSums(Xm[ow_i, , drop = FALSE] * (wi * r)[ow_i])
        if (hascox) res[pos$gam] <- G$cox[i, ]
        if (estd) res[pos$delta] <- G$coxd[i, ]
        if (estc) {
          if (any(isev)) res[pos$c] <- sum(exp(lp[isev]) - theta[pos$c])
        }
        if (cfg$tw) {
          if (length(f1) == 1) {
            kk <- k1i[f1]; aa <- ai[f1]
            ee <- plogis(al[1] * kk + al[2])
            res[pos$alpha] <- c((aa - ee) * kk, aa - ee)
            res[pos$p] <- aa - p
          }
        }
        res
      }
    }
    fit <- m_estimate(estFUN = estFUN, data = ext, units = "uid",
                      roots = theta0, compute_roots = FALSE)
    # estimating equations must be solved at the independently fitted roots
    S <- Reduce(`+`, lapply(split(ext, ext$uid), function(di) estFUN(di)(theta0)))
    V <- vcov(fit)
    list(V = V[pos$beta, pos$beta], resid = max(abs(S)) / m, pos = pos, theta0 = theta0)
  }

  out <- list()
  out$closure <- build("closure")
  if (hascox) out$param <- build("param")
  if (hasstab) out$delta <- build("delta")

  # independent check on the hand-built Cox score: coxph's own score residuals
  chk <- NA_real_
  if (hascox) {
    sc <- residuals(fb, type = "score", collapse = cd$uid)
    mine <- cox_rows_score(Zall[coxrows, , drop = FALSE], ext$start[coxrows], ext$stop[coxrows],
                           ext$ev[coxrows], ext$uid[coxrows], m, gam)
    chk <- max(abs(as.matrix(sc)[as.character(seq_len(m)), , drop = FALSE] - mine))
  }
  list(nm = nm, m = m, beta = beta, gam = gam, w = w, ext = ext, out = out, coxchk = chk,
       ow = ow, cval = cval)
}

dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
rows <- list(); wrows <- list(); chkrows <- list()
for (nm in names(arms)) {
  r <- run_arm(nm)
  ext <- r$ext
  wdf <- data.frame(arm = nm, id = ext$id[r$ow], seq = ext$seq[r$ow], w = r$w[r$ow])
  wrows[[nm]] <- wdf
  rows[[length(rows) + 1]] <- data.frame(arm = nm, kind = "beta", i = 1:4, j = 0, value = r$beta)
  rows[[length(rows) + 1]] <- data.frame(arm = nm, kind = "m", i = 0, j = 0, value = r$m)
  rows[[length(rows) + 1]] <- data.frame(arm = nm, kind = "coxchk", i = 0, j = 0, value = r$coxchk)
  for (st in names(r$out)) {
    V <- r$out[[st]]$V
    for (a in 1:4) for (b in 1:4)
      rows[[length(rows) + 1]] <- data.frame(arm = nm, kind = paste0("V_", st), i = a, j = b, value = V[a, b])
    rows[[length(rows) + 1]] <- data.frame(arm = nm, kind = paste0("resid_", st), i = 0, j = 0, value = r$out[[st]]$resid)
  }
}
write.csv(do.call(rbind, rows), file.path(outdir, "stacked_geex_ref.csv"), row.names = FALSE, na = "")
write.csv(do.call(rbind, wrows), file.path(outdir, "stacked_geex_weights.csv"), row.names = FALSE)
vers <- data.frame(package = c("R", "survival", "geex"),
                   version = c(paste(R.version$major, R.version$minor, sep = "."),
                               as.character(packageVersion("survival")),
                               as.character(packageVersion("geex"))))
write.csv(vers, file.path(outdir, "crossval_iivw_stacked_geex_versions.csv"), row.names = FALSE, quote = TRUE)
cat("done\n")
