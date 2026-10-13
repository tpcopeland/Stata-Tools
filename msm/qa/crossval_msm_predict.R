#!/usr/bin/env Rscript
# Independent R reference for crossval_msm_predict.do.
#
# Re-derives, from the person-period rows and msm's exported weight, every step
# msm_predict depends on after weighting:
#   1. the fitted risk set (alive and uncensored through the previous interval,
#      uncensored in the current one, outcome observed);
#   2. the weighted pooled logistic outcome model (stats::glm) and its
#      id-clustered sandwich covariance (sandwich::vcovCL, HC0 with G/(G-1));
#   3. the static-regime treatment-history terms;
#   4. g-formula standardization over the baseline reference population:
#      risk_a(t) = 1 - mean_i prod_{s=baseline..t} {1 - expit(x_i(a, s)' b)};
#   5. Monte Carlo percentile intervals from N(b, V) coefficient draws.
#
# Usage:
#   Rscript crossval_msm_predict.R in.dta out.dta period_spec covs history \
#           knots times samples seed
#   period_spec: linear | quadratic | cubic | ns
#   covs, history, knots, times: space-separated lists or "none"

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 9L) stop("usage: crossval_msm_predict.R in out spec covs history knots times samples seed")

suppressPackageStartupMessages(library(haven))
suppressPackageStartupMessages(library(sandwich))
suppressPackageStartupMessages(library(splines))

split_arg <- function(x) if (x == "none" || x == "") character(0) else strsplit(x, " +")[[1]]

in_file <- args[[1]]; out_file <- args[[2]]; spec <- args[[3]]
covs <- split_arg(args[[4]]); history <- split_arg(args[[5]])
knots <- as.numeric(split_arg(args[[6]])); times <- as.numeric(split_arg(args[[7]]))
n_samples <- as.integer(args[[8]]); seed <- as.integer(args[[9]])

d <- as.data.frame(read_dta(in_file))
d <- d[order(d$id, d$period), ]

lag_by_id <- function(x, id) ave(x, id, FUN = function(v) c(0, head(v, -1)))
prior_sum <- function(x, id) ave(x, id, FUN = function(v) cumsum(c(0, head(v, -1))))

# 1. Fitted risk set, derived from the raw indicators.
cens <- if ("censor" %in% names(d)) d$censor else rep(0, nrow(d))
cens[is.na(cens)] <- 0
d$prior_event <- prior_sum(ifelse(is.na(d$outcome), 0, d$outcome), d$id)
d$prior_cens <- prior_sum(cens, d$id)
d$r_fit <- as.integer(d$prior_event == 0 & d$prior_cens == 0 & cens == 0 &
                      !is.na(d$outcome) & !is.na(d$weight))

# 3. History terms on observed data.
d$h_lag1 <- lag_by_id(d$treatment, d$id)
d$h_cum <- prior_sum(d$treatment, d$id)

hist_terms <- c(lag1 = "h_lag1", cumulative = "h_cum")[history]
if (any(is.na(hist_terms))) stop("unsupported history term")

period_terms <- switch(spec,
    linear = "period",
    quadratic = "period + I(period^2)",
    cubic = "period + I(period^2) + I(period^3)",
    ns = sprintf("ns(period, knots = c(%s), Boundary.knots = c(%s, %s))",
                 paste(knots[-c(1, length(knots))], collapse = ", "),
                 knots[1], knots[length(knots)]),
    stop("unsupported period_spec"))
rhs <- paste(c("treatment", unname(hist_terms), period_terms, covs), collapse = " + ")
fml <- as.formula(paste("outcome ~", rhs))

fd <- d[d$r_fit == 1, ]
fit <- glm(fml, data = fd, weights = weight, family = quasibinomial(),
           control = glm.control(epsilon = 1e-12, maxit = 100))
b <- coef(fit)
if (any(is.na(b))) stop("aliased coefficient in R fit")
V <- vcovCL(fit, cluster = fd$id, type = "HC0", cadjust = TRUE)

# 4. Standardization over baseline rows of the fitted sample.
baseline <- min(fd$period)
ref <- fd[fd$period == baseline, ]
ref <- ref[!duplicated(ref$id), ]
n_ref <- nrow(ref)

design_at <- function(a, s) {
    nd <- ref
    nd$treatment <- a
    nd$period <- s
    elapsed <- s - baseline
    nd$h_lag1 <- if (elapsed > 0) a else 0
    nd$h_cum <- a * max(0, elapsed)
    model.matrix(delete.response(terms(fit)), data = nd)
}

steps <- baseline:max(times)
designs <- list(
    "0" = lapply(steps, function(s) design_at(0, s)),
    "1" = lapply(steps, function(s) design_at(1, s)))

# beta: k x m matrix of coefficient vectors (one column per draw); returns an
# m x length(times) matrix of standardized risks.
risk_curve <- function(beta, a) {
    S <- matrix(1, n_ref, ncol(beta))
    out <- NULL
    for (j in seq_along(steps)) {
        S <- S * (1 - plogis(designs[[as.character(a)]][[j]] %*% beta))
        if (steps[j] %in% times) out <- cbind(out, 1 - colMeans(S))
    }
    out
}

r0 <- drop(risk_curve(matrix(b), 0))
r1 <- drop(risk_curve(matrix(b), 1))

# 5. Monte Carlo percentile intervals (Stata's ceil(n*p) order statistic).
set.seed(seed)
ev <- eigen((V + t(V)) / 2, symmetric = TRUE)
L <- pmax(ev$values, 0)
Fac <- ev$vectors %*% diag(sqrt(L), length(L)) %*% t(ev$vectors)
Z <- matrix(rnorm(n_samples * length(b)), n_samples)
B <- sweep(Z %*% t(Fac), 2, b, "+")
mc0 <- risk_curve(t(B), 0)
mc1 <- risk_curve(t(B), 1)
pct <- function(v, p) sort(v)[min(length(v), max(1, ceiling(length(v) * p)))]
ci <- function(M, p) apply(M, 2, pct, p = p)

out <- data.frame(
    time = times, r_never = r0, r_always = r1, r_rd = r1 - r0,
    r_lo_never = ci(mc0, 0.025), r_hi_never = ci(mc0, 0.975),
    r_lo_always = ci(mc1, 0.025), r_hi_always = ci(mc1, 0.975),
    r_lo_rd = ci(mc1 - mc0, 0.025), r_hi_rd = ci(mc1 - mc0, 0.975),
    r_n_ref = n_ref, r_n_fit = nrow(fd), r_baseline = baseline,
    r_b_treat = unname(b["treatment"]),
    r_se_treat = sqrt(V["treatment", "treatment"])
)
write_dta(out, out_file, version = 15)
write_dta(d[, c("id", "period", "r_fit")], sub("\\.dta$", "_rows.dta", out_file), version = 15)
cat("MSM_PREDICT_REFERENCE_COMPLETE\n")
