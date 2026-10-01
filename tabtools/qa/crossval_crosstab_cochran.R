# crossval_crosstab_cochran.R  2026/10/01
# Author: Timothy P Copeland, Karolinska Institutet
# Native stats::prop.trend.test oracle; no tabtools formula implementation.
# API fetched 2026-10-01:
# https://stat.ethz.ch/R-manual/R-devel/library/stats/html/prop.trend.test.html
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L)
cases <- list(
  rising = list(score=c(0,2,4), events=c(1,5,9), trials=c(10,10,10)),
  falling = list(score=c(0,2,4), events=c(9,5,1), trials=c(10,10,10)),
  flat = list(score=c(0,2,4), events=c(1,2,3), trials=c(10,20,30)),
  fractional = list(score=c(0,.25,1), events=c(2,4,11), trials=c(11,17,23))
)
rows <- lapply(seq_along(cases), function(i) {
  a <- cases[[i]]
  native <- stats::prop.trend.test(a$events, a$trials, score=a$score)
  # Sign comes from association of score and observed proportion. Native R
  # supplies the magnitude (its chi-square statistic), not a reimplemented z.
  direction <- sign(sum(a$trials * (a$score-weighted.mean(a$score,a$trials)) *
                        (a$events/a$trials-sum(a$events)/sum(a$trials))))
  data.frame(case=i, score=a$score, events=a$events, trials=a$trials,
             z=direction*sqrt(unname(native$statistic)),
             chi2=unname(native$statistic), p=native$p.value)
})
options(digits=17)
write.csv(do.call(rbind,rows), args[[1]], row.names=FALSE, quote=FALSE)
cat("PASS native R prop.trend.test: 4 fixtures\n")
