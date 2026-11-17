# _multigroup_reference_twang.R -- regenerate the twang mnps AOD fit used by
# crossval_multigroup_published_twang.do and write the frozen fixture plus the
# summary(mnps.AOD) quantities.
# Usage: Rscript _multigroup_reference_twang.R <outdir>
# The fit follows Burgette, Griffin and McCaffrey, "Propensity scores for
# multiple treatments: a tutorial for the mnps function in the twang package",
# sec. 2 (mnps call with es.mean and ks.mean stopping rules, n.trees = 3000).
args <- commandArgs(trailingOnly = TRUE)
outdir <- if (length(args) >= 1) args[1] else "."
suppressMessages(library(twang))
data(AOD)
set.seed(1)
m <- mnps(treat ~ illact + crimjust + subprob + subdep + white, data = AOD,
          estimand = "ATE", verbose = FALSE,
          stop.method = c("es.mean", "ks.mean"), n.trees = 3000)
AOD$w_es <- get.weights(m, stop.method = "es.mean")
AOD$w_ks <- get.weights(m, stop.method = "ks.mean")
AOD$tnum <- as.integer(AOD$treat) - 1L
keep <- c("treat", "tnum", "illact", "crimjust", "subprob", "subdep", "white",
          "w_es", "w_ks")
write.csv(AOD[, keep], file.path(outdir, "aod_twang_ate_weights.csv"),
          row.names = FALSE)
s <- summary(m)
comp <- s$comp
vals <- c(
  twang_version = as.character(packageVersion("twang")),
  msd_unw = comp$max.std.eff.sz[1], msd_es = comp$max.std.eff.sz[2],
  msd_ks = comp$max.std.eff.sz[3],
  mks_unw = comp$max.ks[1], mks_es = comp$max.ks[2], mks_ks = comp$max.ks[3]
)
write.csv(data.frame(key = names(vals), value = unname(vals)),
          file.path(outdir, "twang_summary_regen.csv"), row.names = FALSE)
