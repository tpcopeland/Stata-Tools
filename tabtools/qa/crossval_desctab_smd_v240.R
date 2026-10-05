# crossval_desctab_smd_v240.R - cobalt oracle for table1_tc smdtype()
#
# Usage: Rscript crossval_desctab_smd_v240.R IN.csv OUT.csv
# IN.csv has columns arm, age, sex (0/1), grp (string), w (weight > 0).
# OUT.csv rows: stat,var,value, with
#   pop_un   cobalt 4.6.3 bal.tab(pairwise = FALSE, s.d.denom = "all"),
#            max over the "All vs. g" contrasts of |Diff.Un|: the population
#            standardized bias of McCaffrey et al. (2013) eq. 5 (sec. 4.2
#            max over groups). grp: max over groups and factor levels.
#   pop_wt   the same with weights = w, |Diff.Adj|: group means weighted,
#            the all-sample SD unweighted (s.d.denom uses s.weights only).
#   max_un   bal.tab(pairwise = TRUE, s.d.denom = "pooled"), max over pairs
#            of |Diff.Un|: every pair over sqrt(mean of all K variances).
#            age and sex only (cobalt splits a factor into levels).
# binary = "std", continuous = "std" throughout.

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2)
suppressMessages(library(cobalt))
stopifnot(packageVersion("cobalt") >= "4.6.3")
d <- read.csv(args[1], stringsAsFactors = FALSE)
d$arm <- factor(d$arm)
d$grp <- factor(d$grp)

rows <- list()
add <- function(stat, var, value) rows[[length(rows) + 1L]] <<-
  data.frame(stat = stat, var = var, value = sprintf("%.17g", value))

pick <- function(bal, col, var) {
  # bal: list of per-contrast Balance frames; rows named age, sex, grp_<lev>
  vals <- unlist(lapply(bal, function(b) {
    rn <- rownames(b)
    keep <- if (var == "grp") startsWith(rn, "grp_") else rn == var
    abs(b[keep, col])
  }))
  max(vals)
}

b0 <- bal.tab(arm ~ age + sex + grp, data = d, estimand = "ATE", pairwise = FALSE,
              s.d.denom = "all", binary = "std", continuous = "std", quick = FALSE)
pb <- lapply(b0$Pair.Balance, `[[`, "Balance")
for (v in c("age", "sex", "grp")) add("pop_un", v, pick(pb, "Diff.Un", v))

b1 <- bal.tab(arm ~ age + sex + grp, data = d, estimand = "ATE", pairwise = FALSE,
              s.d.denom = "all", binary = "std", continuous = "std",
              weights = d$w, method = "weighting", quick = FALSE)
pb <- lapply(b1$Pair.Balance, `[[`, "Balance")
for (v in c("age", "sex", "grp")) add("pop_wt", v, pick(pb, "Diff.Adj", v))

b2 <- bal.tab(arm ~ age + sex, data = d, estimand = "ATE", pairwise = TRUE,
              s.d.denom = "pooled", binary = "std", continuous = "std", quick = FALSE)
pb <- lapply(b2$Pair.Balance, `[[`, "Balance")
for (v in c("age", "sex")) add("max_un", v, pick(pb, "Diff.Un", v))

write.csv(do.call(rbind, rows), args[2], row.names = FALSE, quote = FALSE)
