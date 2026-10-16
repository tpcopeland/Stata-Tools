# crossval_iivw_bootstrap_survival.R
#
# Reference for iivw_fit's refit subject bootstrap (the default vce). The
# bootstrap RNG differs between Stata and R, so parity is on IDENTICAL
# resamples: the Stata suite records which subject each bootstrap draw picked
# (the cluster ids Stata's own bootstrap prefix resamples), and this script
# refits the WHOLE pipeline on each of those resamples from the raw rows:
#
#   survival::coxph visit model (Andersen-Gill counting process, Efron ties)
#     -> IIW weight exp(-gamma'Z) / mean over modeled events, 1 at study entry
#   glm(a ~ k1) propensity on one row per subject -> stabilized IPTW weight
#   geepack::geeglm independence GEE of y on (a, z1, t), id = resampled subject
#
# Nothing of iivw's weights, scores or replicate estimates is read here. The
# resampled subjects are renamed (a subject drawn twice becomes two clusters
# with identical visit times, so the Cox risk sets contain exact ties; that is
# why the visit model uses ties = "efron", iivw's default).
#
# Usage: Rscript crossval_iivw_bootstrap_survival.R --indir=DIR --outdir=DIR --maxfu=7

suppressPackageStartupMessages({
  library(survival)
  library(geepack)
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
for (p in c("survival", "geepack"))
  cat(sprintf("REFERENCE: %s %s\n", p, as.character(utils::packageVersion(p))))

arms <- list(
  iiw    = list(viscov = c("z1", "zl"),      tw = FALSE),
  iptw   = list(viscov = NULL,               tw = TRUE),
  fiptiw = list(viscov = c("z1", "zl", "a"), tw = TRUE)
)

# one full pipeline pass on a panel with columns id (subject), t, y, a, z1, zl, k1
pipeline <- function(d, cfg) {
  d <- d[order(d$id, d$t), ]
  d$uid <- match(d$id, unique(d$id))
  d$entry <- as.integer(!duplicated(d$uid))
  d$last <- as.integer(!duplicated(d$uid, fromLast = TRUE))
  d$start <- ave(d$t, d$uid, FUN = function(x) c(NA, head(x, -1)))
  d$stop <- d$t
  d$ev <- 1L - d$entry
  iw <- rep(1, nrow(d))
  if (length(cfg$viscov) > 0) {
    need <- d$last == 1 & d$t < maxfu
    cr <- d[need, ]
    cr$start <- cr$t; cr$stop <- maxfu; cr$ev <- 0L; cr$entry <- 0L
    cd <- rbind(d[d$entry == 0, ], cr)
    f <- as.formula(paste("Surv(start, stop, ev) ~", paste(cfg$viscov, collapse = "+")))
    fit <- coxph(f, data = cd, ties = "efron",
                 control = coxph.control(eps = 1e-12, iter.max = 50))
    gam <- unname(coef(fit))
    e <- exp(-as.vector(as.matrix(d[, cfg$viscov, drop = FALSE]) %*% gam))
    evr <- d$ev == 1
    iw[evr] <- e[evr] / mean(e[evr])
  }
  tw <- rep(1, nrow(d))
  if (cfg$tw) {
    sub <- d[d$entry == 1, ]
    lg <- glm(a ~ k1, data = sub, family = binomial())
    p <- mean(sub$a)
    ps <- predict(lg, newdata = d, type = "response")
    tw <- ifelse(d$a == 1, p / ps, (1 - p) / (1 - ps))
  }
  d$w <- iw * tw
  g <- geeglm(y ~ a + z1 + t, id = uid, weights = w, data = d,
              family = gaussian(), corstr = "independence")
  unname(coef(g)[c("a", "z1", "t", "(Intercept)")])
}

dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
out <- list()
for (nm in names(arms)) {
  panel <- read.csv(file.path(indir, paste0("panel_", nm, ".csv")))
  draws <- read.csv(file.path(indir, paste0("draws_", nm, ".csv")))
  cat("arm", nm, ": ", length(unique(draws$rep)), "replicates\n")
  obs <- pipeline(panel, arms[[nm]])
  out[[length(out) + 1]] <- data.frame(arm = nm, rep = 0, b1 = obs[1], b2 = obs[2],
                                       b3 = obs[3], b4 = obs[4])
  for (r in sort(unique(draws$rep))) {
    dr <- draws[draws$rep == r, ]
    dr <- dr[order(dr$nid), ]
    pieces <- lapply(seq_len(nrow(dr)), function(k) {
      x <- panel[panel$id == dr$id[k], ]
      x$id <- dr$nid[k]
      x
    })
    d <- do.call(rbind, pieces)
    b <- tryCatch(pipeline(d, arms[[nm]]), error = function(e) rep(NA_real_, 4))
    out[[length(out) + 1]] <- data.frame(arm = nm, rep = r, b1 = b[1], b2 = b[2],
                                         b3 = b[3], b4 = b[4])
  }
}
write.csv(do.call(rbind, out), file.path(outdir, "bootstrap_ref.csv"), row.names = FALSE)
vers <- data.frame(package = c("R", "survival", "geepack"),
                   version = c(paste(R.version$major, R.version$minor, sep = "."),
                               as.character(packageVersion("survival")),
                               as.character(packageVersion("geepack"))))
write.csv(vers, file.path(outdir, "crossval_iivw_bootstrap_survival_versions.csv"),
          row.names = FALSE, quote = TRUE)
cat("done\n")
