# crossval_tabtools_companion.R
# Companion R script for tabtools cross-validation
# Run this first, then run crossval_tabtools.do in Stata
#
# Independently computes all manual statistical formulas used in tabtools:
#   1. Correlation p-values (t-approximation)
#   2. Diagnostic accuracy (Se, Sp, PPV, NPV, Acc, LR+, LR-, DOR, J)
#   3. Diagnostic CIs (log method for LR/DOR)
#   4. Bayesian PPV/NPV with external prevalence
#   5. SMD for continuous variables (pooled SD, equal and unequal weighting)
#   6. SMD for categorical variables (Yang & Dalton)
#   7. ESS (Kish's formula)
#   8. AIC/BIC from log-likelihood
#   9. ICC (linear and binary)
#  10. MOR (Median Odds Ratio)
#  11. RMST SE and CI (Greenwood-based)
#  12. IRR and CI (log method)
#  13. Survival difference SE
#
# Generated: 2026-04-01

cat("=== tabtools Cross-Validation Companion (R) ===\n\n")

results <- list()

# ============================================================
# SECTION 1: Correlation p-values (t-approximation)
# ============================================================
# Formula: t = r * sqrt((n-2) / (1-r^2)), p = 2*pt(-|t|, n-2)

cat("Section 1: Correlation p-values\n")

# Use auto dataset values (Stata sysuse auto: price, mpg, weight; N=74)
# We'll use known correlation values and N to compute p-values
# These exact r and N values will be extracted from Stata's pwcorr

# Test with known values: r=0.7, n=50
r_test <- 0.7
n_test <- 50
t_stat <- r_test * sqrt((n_test - 2) / (1 - r_test^2))
p_val <- 2 * pt(-abs(t_stat), df = n_test - 2)

results$corr_t_stat <- t_stat
results$corr_p_val <- p_val
results$corr_r <- r_test
results$corr_n <- n_test

cat(sprintf("  r=%.4f, n=%d: t=%.10f, p=%.10e\n", r_test, n_test, t_stat, p_val))

# Second test: r=-0.4558, n=74 (approx price-mpg from auto)
r_test2 <- -0.4686
n_test2 <- 74
t_stat2 <- r_test2 * sqrt((n_test2 - 2) / (1 - r_test2^2))
p_val2 <- 2 * pt(-abs(t_stat2), df = n_test2 - 2)

results$corr_t_stat2 <- t_stat2
results$corr_p_val2 <- p_val2
results$corr_r2 <- r_test2
results$corr_n2 <- n_test2

cat(sprintf("  r=%.4f, n=%d: t=%.10f, p=%.10e\n", r_test2, n_test2, t_stat2, p_val2))

# Third test: r=0.95, n=30 (strong correlation, small sample)
r_test3 <- 0.95
n_test3 <- 30
t_stat3 <- r_test3 * sqrt((n_test3 - 2) / (1 - r_test3^2))
p_val3 <- 2 * pt(-abs(t_stat3), df = n_test3 - 2)

results$corr_t_stat3 <- t_stat3
results$corr_p_val3 <- p_val3

cat(sprintf("  r=%.4f, n=%d: t=%.10f, p=%.10e\n", r_test3, n_test3, t_stat3, p_val3))

# ============================================================
# SECTION 2: Diagnostic accuracy from known 2x2 table
# ============================================================
# TP=80, FP=10, FN=20, TN=90

cat("\nSection 2: Diagnostic accuracy\n")

TP <- 80; FP <- 10; FN <- 20; TN <- 90
total <- TP + FP + FN + TN

Se <- TP / (TP + FN)
Sp <- TN / (TN + FP)
PPV <- TP / (TP + FP)
NPV <- TN / (TN + FN)
Acc <- (TP + TN) / total
LRp <- Se / (1 - Sp)
LRn <- (1 - Se) / Sp
DOR <- (TP * TN) / (FP * FN)
J <- Se + Sp - 1

results$diag_Se <- Se
results$diag_Sp <- Sp
results$diag_PPV <- PPV
results$diag_NPV <- NPV
results$diag_Acc <- Acc
results$diag_LRp <- LRp
results$diag_LRn <- LRn
results$diag_DOR <- DOR
results$diag_J <- J

cat(sprintf("  Se=%.6f, Sp=%.6f, PPV=%.6f, NPV=%.6f\n", Se, Sp, PPV, NPV))
cat(sprintf("  Acc=%.6f, LR+=%.6f, LR-=%.6f, DOR=%.6f, J=%.6f\n", Acc, LRp, LRn, DOR, J))

# LR+ CI (log method)
se_ln_lrp <- sqrt(1/TP - 1/(TP+FN) + 1/FP - 1/(FP+TN))
LRp_lo <- exp(log(LRp) - 1.96 * se_ln_lrp)
LRp_hi <- exp(log(LRp) + 1.96 * se_ln_lrp)

# LR- CI (log method)
se_ln_lrn <- sqrt(1/FN - 1/(TP+FN) + 1/TN - 1/(FP+TN))
LRn_lo <- exp(log(LRn) - 1.96 * se_ln_lrn)
LRn_hi <- exp(log(LRn) + 1.96 * se_ln_lrn)

# DOR CI (Woolf's method)
se_ln_dor <- sqrt(1/TP + 1/FP + 1/FN + 1/TN)
DOR_lo <- exp(log(DOR) - 1.96 * se_ln_dor)
DOR_hi <- exp(log(DOR) + 1.96 * se_ln_dor)

results$diag_LRp_lo <- LRp_lo
results$diag_LRp_hi <- LRp_hi
results$diag_LRn_lo <- LRn_lo
results$diag_LRn_hi <- LRn_hi
results$diag_DOR_lo <- DOR_lo
results$diag_DOR_hi <- DOR_hi
results$diag_se_ln_lrp <- se_ln_lrp
results$diag_se_ln_lrn <- se_ln_lrn
results$diag_se_ln_dor <- se_ln_dor

cat(sprintf("  LR+ CI: (%.6f, %.6f), SE(ln)=%.6f\n", LRp_lo, LRp_hi, se_ln_lrp))
cat(sprintf("  LR- CI: (%.6f, %.6f), SE(ln)=%.6f\n", LRn_lo, LRn_hi, se_ln_lrn))
cat(sprintf("  DOR CI: (%.6f, %.6f), SE(ln)=%.6f\n", DOR_lo, DOR_hi, se_ln_dor))

# Second 2x2 table: TP=45, FP=5, FN=15, TN=135
TP2 <- 45; FP2 <- 5; FN2 <- 15; TN2 <- 135
total2 <- TP2 + FP2 + FN2 + TN2

results$diag2_Se <- TP2 / (TP2 + FN2)
results$diag2_Sp <- TN2 / (TN2 + FP2)
results$diag2_PPV <- TP2 / (TP2 + FP2)
results$diag2_NPV <- TN2 / (TN2 + FN2)
results$diag2_Acc <- (TP2 + TN2) / total2
results$diag2_LRp <- results$diag2_Se / (1 - results$diag2_Sp)
results$diag2_LRn <- (1 - results$diag2_Se) / results$diag2_Sp
results$diag2_DOR <- (TP2 * TN2) / (FP2 * FN2)
results$diag2_J <- results$diag2_Se + results$diag2_Sp - 1

se_ln_lrp2 <- sqrt(1/TP2 - 1/(TP2+FN2) + 1/FP2 - 1/(FP2+TN2))
results$diag2_LRp_lo <- exp(log(results$diag2_LRp) - 1.96 * se_ln_lrp2)
results$diag2_LRp_hi <- exp(log(results$diag2_LRp) + 1.96 * se_ln_lrp2)
se_ln_lrn2 <- sqrt(1/FN2 - 1/(TP2+FN2) + 1/TN2 - 1/(FP2+TN2))
results$diag2_LRn_lo <- exp(log(results$diag2_LRn) - 1.96 * se_ln_lrn2)
results$diag2_LRn_hi <- exp(log(results$diag2_LRn) + 1.96 * se_ln_lrn2)
se_ln_dor2 <- sqrt(1/TP2 + 1/FP2 + 1/FN2 + 1/TN2)
results$diag2_DOR_lo <- exp(log(results$diag2_DOR) - 1.96 * se_ln_dor2)
results$diag2_DOR_hi <- exp(log(results$diag2_DOR) + 1.96 * se_ln_dor2)

cat(sprintf("  Table 2: Se=%.6f, Sp=%.6f, DOR=%.6f\n",
    results$diag2_Se, results$diag2_Sp, results$diag2_DOR))

# ============================================================
# SECTION 3: Bayesian PPV/NPV with external prevalence
# ============================================================
# Using Se/Sp from table 1, prevalence = 0.05

cat("\nSection 3: Bayesian PPV/NPV\n")

prev <- 0.05
bayes_PPV <- (Se * prev) / (Se * prev + (1 - Sp) * (1 - prev))
bayes_NPV <- (Sp * (1 - prev)) / ((1 - Se) * prev + Sp * (1 - prev))

results$bayes_PPV <- bayes_PPV
results$bayes_NPV <- bayes_NPV
results$bayes_prev <- prev

cat(sprintf("  prevalence=%.2f: PPV=%.6f, NPV=%.6f\n", prev, bayes_PPV, bayes_NPV))

# Second prevalence: 0.30
prev2 <- 0.30
bayes_PPV2 <- (Se * prev2) / (Se * prev2 + (1 - Sp) * (1 - prev2))
bayes_NPV2 <- (Sp * (1 - prev2)) / ((1 - Se) * prev2 + Sp * (1 - prev2))

results$bayes_PPV2 <- bayes_PPV2
results$bayes_NPV2 <- bayes_NPV2
results$bayes_prev2 <- prev2

cat(sprintf("  prevalence=%.2f: PPV=%.6f, NPV=%.6f\n", prev2, bayes_PPV2, bayes_NPV2))

# ============================================================
# SECTION 4: SMD for continuous variables
# ============================================================
# Two formulas: equal-weight pooled SD and unequal (sample-size weighted)

cat("\nSection 4: SMD (continuous)\n")

set.seed(42)
n1 <- 40; n2 <- 60
x1 <- rnorm(n1, mean = 10, sd = 3)
x2 <- rnorm(n2, mean = 12, sd = 4)

m1 <- mean(x1); m2 <- mean(x2)
s1 <- sd(x1); s2 <- sd(x2)

# Unequal-weight pooled SD (Stata default for unweighted)
poolsd_unequal <- sqrt(((n1 - 1) * s1^2 + (n2 - 1) * s2^2) / (n1 + n2 - 2))
smd_unequal <- (m1 - m2) / poolsd_unequal

# Equal-weight pooled SD (Stata weighted path)
poolsd_equal <- sqrt((s1^2 + s2^2) / 2)
smd_equal <- (m1 - m2) / poolsd_equal

results$smd_m1 <- m1
results$smd_m2 <- m2
results$smd_s1 <- s1
results$smd_s2 <- s2
results$smd_n1 <- n1
results$smd_n2 <- n2
results$smd_poolsd_unequal <- poolsd_unequal
results$smd_unequal <- smd_unequal
results$smd_poolsd_equal <- poolsd_equal
results$smd_equal <- smd_equal

cat(sprintf("  m1=%.6f, s1=%.6f, n1=%d\n", m1, s1, n1))
cat(sprintf("  m2=%.6f, s2=%.6f, n2=%d\n", m2, s2, n2))
cat(sprintf("  Pooled SD (unequal): %.6f, SMD=%.6f\n", poolsd_unequal, smd_unequal))
cat(sprintf("  Pooled SD (equal):   %.6f, SMD=%.6f\n", poolsd_equal, smd_equal))

# Save the generated data for Stata to use
smd_data <- data.frame(
    id = 1:(n1 + n2),
    group = c(rep(1, n1), rep(2, n2)),
    x = c(x1, x2)
)
write.csv(smd_data, "data/crossval_smd_data.csv", row.names = FALSE)

# ============================================================
# SECTION 5: SMD for categorical variables (Yang & Dalton)
# ============================================================
# Formula: sqrt(sum_k ((p1k - p2k) / sqrt(pavg_k * (1 - pavg_k)))^2)

cat("\nSection 5: SMD (categorical, Yang & Dalton)\n")

# Three-category variable
p1 <- c(0.30, 0.50, 0.20)  # Group 1 proportions
p2 <- c(0.45, 0.35, 0.20)  # Group 2 proportions
pavg <- (p1 + p2) / 2
denom <- sqrt(pavg * (1 - pavg))
ssq <- sum(((p1 - p2) / denom)^2)
smd_cat <- sqrt(ssq)

results$smd_cat <- smd_cat

cat(sprintf("  p1=(%.2f,%.2f,%.2f), p2=(%.2f,%.2f,%.2f)\n",
    p1[1], p1[2], p1[3], p2[1], p2[2], p2[3]))
cat(sprintf("  SMD (Yang & Dalton) = %.6f\n", smd_cat))

# Generate categorical data matching these proportions for Stata
set.seed(123)
n_cat1 <- 200; n_cat2 <- 200
cat1 <- sample(1:3, n_cat1, replace = TRUE, prob = p1)
cat2 <- sample(1:3, n_cat2, replace = TRUE, prob = p2)

# Recalculate SMD from actual generated data
p1_actual <- table(factor(cat1, levels = 1:3)) / n_cat1
p2_actual <- table(factor(cat2, levels = 1:3)) / n_cat2
pavg_actual <- (p1_actual + p2_actual) / 2
denom_actual <- sqrt(pavg_actual * (1 - pavg_actual))
ssq_actual <- sum(((p1_actual - p2_actual) / denom_actual)^2)
smd_cat_actual <- sqrt(ssq_actual)

results$smd_cat_actual <- smd_cat_actual

cat_data <- data.frame(
    id = 1:(n_cat1 + n_cat2),
    group = c(rep(1, n_cat1), rep(2, n_cat2)),
    category = c(cat1, cat2)
)
write.csv(cat_data, "data/crossval_cat_smd_data.csv", row.names = FALSE)
cat(sprintf("  From generated data: SMD = %.6f\n", smd_cat_actual))

# ============================================================
# SECTION 6: ESS (Kish's effective sample size)
# ============================================================
# Formula: ESS = (sum(w))^2 / sum(w^2)

cat("\nSection 6: ESS (Kish's formula)\n")

set.seed(99)
weights <- runif(100, 0.5, 3.0)
ess <- (sum(weights))^2 / sum(weights^2)

results$ess <- ess
results$ess_n <- length(weights)
results$ess_sum_w <- sum(weights)
results$ess_sum_w2 <- sum(weights^2)

cat(sprintf("  n=%d, sum(w)=%.6f, sum(w^2)=%.6f\n",
    length(weights), sum(weights), sum(weights^2)))
cat(sprintf("  ESS = %.6f\n", ess))

# Save weights for Stata
ess_data <- data.frame(id = 1:100, wt = weights)
write.csv(ess_data, "data/crossval_ess_data.csv", row.names = FALSE)

# ============================================================
# SECTION 7: AIC and BIC from log-likelihood
# ============================================================
# AIC = -2*LL + 2*k
# BIC = -2*LL + k*ln(N)

cat("\nSection 7: AIC/BIC\n")

# Test with known values
ll <- -250.5
k <- 5
N_obs <- 200

aic <- -2 * ll + 2 * k
bic <- -2 * ll + k * log(N_obs)

results$aic <- aic
results$bic <- bic
results$aic_ll <- ll
results$aic_k <- k
results$aic_N <- N_obs

cat(sprintf("  LL=%.1f, k=%d, N=%d\n", ll, k, N_obs))
cat(sprintf("  AIC = %.6f\n", aic))
cat(sprintf("  BIC = %.6f\n", bic))

# Second set
ll2 <- -180.3
k2 <- 8
N_obs2 <- 500

aic2 <- -2 * ll2 + 2 * k2
bic2 <- -2 * ll2 + k2 * log(N_obs2)

results$aic2 <- aic2
results$bic2 <- bic2

cat(sprintf("  LL=%.1f, k=%d, N=%d: AIC=%.6f, BIC=%.6f\n", ll2, k2, N_obs2, aic2, bic2))

# ============================================================
# SECTION 8: ICC (Intraclass Correlation Coefficient)
# ============================================================
# Linear: ICC = var_re / (var_re + var_resid)
# Binary: ICC = var_re / (var_re + pi^2/3)

cat("\nSection 8: ICC\n")

# Linear ICC
var_re <- 2.5
var_resid <- 7.5
icc_linear <- var_re / (var_re + var_resid)

results$icc_linear <- icc_linear
results$icc_var_re <- var_re
results$icc_var_resid <- var_resid

cat(sprintf("  Linear: var_re=%.1f, var_resid=%.1f, ICC=%.6f\n",
    var_re, var_resid, icc_linear))

# Binary ICC (melogit)
var_re_bin <- 1.2
icc_binary <- var_re_bin / (var_re_bin + pi^2/3)

results$icc_binary <- icc_binary
results$icc_var_re_bin <- var_re_bin

cat(sprintf("  Binary: var_re=%.1f, var_resid=pi^2/3=%.6f, ICC=%.6f\n",
    var_re_bin, pi^2/3, icc_binary))

# Variance from log-SD (back-transformation)
log_sd <- 0.8
var_from_logsd <- exp(2 * log_sd)
results$var_from_logsd <- var_from_logsd
results$logsd_input <- log_sd

cat(sprintf("  Back-transform: log(sd)=%.1f -> var=%.6f\n", log_sd, var_from_logsd))

# ============================================================
# SECTION 9: MOR (Median Odds Ratio)
# ============================================================
# MOR = exp(sqrt(2 * var_re) * qnorm(0.75))

cat("\nSection 9: MOR\n")

var_re_mor <- 0.5
mor <- exp(sqrt(2 * var_re_mor) * qnorm(0.75))

results$mor <- mor
results$mor_var <- var_re_mor

cat(sprintf("  var_re=%.1f: MOR=%.6f\n", var_re_mor, mor))

# Second test: larger variance
var_re_mor2 <- 1.5
mor2 <- exp(sqrt(2 * var_re_mor2) * qnorm(0.75))

results$mor2 <- mor2
results$mor_var2 <- var_re_mor2

cat(sprintf("  var_re=%.1f: MOR=%.6f\n", var_re_mor2, mor2))

# MOR CI transformation (from variance CI bounds)
ci_lo_var <- 0.3
ci_hi_var <- 0.8
mor_ci_lo <- exp(sqrt(2 * ci_lo_var) * qnorm(0.75))
mor_ci_hi <- exp(sqrt(2 * ci_hi_var) * qnorm(0.75))

results$mor_ci_lo <- mor_ci_lo
results$mor_ci_hi <- mor_ci_hi

cat(sprintf("  MOR CI from var (%.1f, %.1f): (%.6f, %.6f)\n",
    ci_lo_var, ci_hi_var, mor_ci_lo, mor_ci_hi))

# ============================================================
# SECTION 10: IRR and CI (log method)
# ============================================================
# IRR = rate_exp / rate_ref
# SE(ln(IRR)) = sqrt(1/d_exp + 1/d_ref)
# CI = exp(ln(IRR) +/- 1.96 * SE)

cat("\nSection 10: IRR\n")

d_ref <- 50; py_ref <- 10000
d_exp <- 30; py_exp <- 8000
pyscale <- 1000

rate_ref <- d_ref / py_ref * pyscale
rate_exp <- d_exp / py_exp * pyscale
irr <- rate_exp / rate_ref
se_ln_irr <- sqrt(1/d_exp + 1/d_ref)
irr_lo <- exp(log(irr) - 1.96 * se_ln_irr)
irr_hi <- exp(log(irr) + 1.96 * se_ln_irr)

results$irr <- irr
results$irr_lo <- irr_lo
results$irr_hi <- irr_hi
results$irr_rate_ref <- rate_ref
results$irr_rate_exp <- rate_exp
results$irr_se_ln <- se_ln_irr

cat(sprintf("  rate_ref=%.4f, rate_exp=%.4f per %d\n", rate_ref, rate_exp, pyscale))
cat(sprintf("  IRR=%.6f, SE(ln)=%.6f\n", irr, se_ln_irr))
cat(sprintf("  IRR CI: (%.6f, %.6f)\n", irr_lo, irr_hi))

# Second test
d_ref2 <- 100; py_ref2 <- 50000
d_exp2 <- 75; py_exp2 <- 30000

rate_ref2 <- d_ref2 / py_ref2 * pyscale
rate_exp2 <- d_exp2 / py_exp2 * pyscale
irr2 <- rate_exp2 / rate_ref2
se_ln_irr2 <- sqrt(1/d_exp2 + 1/d_ref2)
irr2_lo <- exp(log(irr2) - 1.96 * se_ln_irr2)
irr2_hi <- exp(log(irr2) + 1.96 * se_ln_irr2)

results$irr2 <- irr2
results$irr2_lo <- irr2_lo
results$irr2_hi <- irr2_hi

cat(sprintf("  Test 2: IRR=%.6f, CI=(%.6f, %.6f)\n", irr2, irr2_lo, irr2_hi))

# ============================================================
# SECTION 11: Survival difference SE
# ============================================================
# SE(d) = sqrt(SE1^2 + SE2^2)

cat("\nSection 11: Survival difference SE\n")

se1 <- 0.035
se2 <- 0.042
s1_surv <- 0.82
s2_surv <- 0.71
diff_pct <- (s1_surv - s2_surv) * 100
se_diff <- sqrt(se1^2 + se2^2) * 100
diff_lo <- diff_pct - 1.96 * se_diff
diff_hi <- diff_pct + 1.96 * se_diff

results$surv_diff_pct <- diff_pct
results$surv_se_diff <- se_diff
results$surv_diff_lo <- diff_lo
results$surv_diff_hi <- diff_hi

cat(sprintf("  S1=%.2f (SE=%.3f), S2=%.2f (SE=%.3f)\n", s1_surv, se1, s2_surv, se2))
cat(sprintf("  Diff=%.1f%%, SE=%.6f, CI=(%.6f, %.6f)\n",
    diff_pct, se_diff, diff_lo, diff_hi))

# ============================================================
# SECTION 12: RMST SE (Greenwood-based) and CI
# ============================================================
# Using a simple known survival curve to verify the Greenwood RMST variance
# SE(RMST) = sqrt(sum of Greenwood variance terms)
# CI = RMST +/- z_0.975 * SE

cat("\nSection 12: RMST SE and CI\n")

# Construct a simple survival curve with known event times
# Event times: 5, 10, 15, 20, 25
# At risk:     20, 18, 15, 12, 8
# Events:       2,  3,  3,  4,  3
# S(t):       0.9, 0.75, 0.6, 0.4, 0.25

event_times <- c(5, 10, 15, 20, 25)
n_risk <- c(20, 18, 15, 12, 8)
d_events <- c(2, 3, 3, 4, 3)
tau <- 30

# Survival function
surv <- cumprod(1 - d_events / n_risk)
cat(sprintf("  S(t): %s\n", paste(sprintf("%.4f", surv), collapse = ", ")))

# RMST = integral of S(t) from 0 to tau
# Areas: S(t_j-1) * (t_j - t_j-1) for each interval, plus tail
t_prev <- c(0, event_times)
t_next <- c(event_times, tau)
surv_prev <- c(1, surv)

areas <- surv_prev * (t_next - t_prev)
rmst <- sum(areas)
results$rmst <- rmst

cat(sprintf("  RMST (tau=%d) = %.6f\n", tau, rmst))

# Greenwood RMST variance
# tail_area[j] = sum of areas from t_j to tau (reverse cumulative)
# Each interval's area: S(t_j) * (t_{j+1} - t_j) for intervals after event time j
# But the tail area includes the S(t_j)*(next_event - t_j) plus all subsequent areas

# The areas after each event time (inclusive of that interval onwards to tau)
# For event at t_j, the tail area is the area from t_j to tau
tail_areas <- numeric(length(event_times))
for (j in seq_along(event_times)) {
    # Area from event_times[j] to tau
    # This includes: S(t_j)*(t_{j+1} - t_j) + S(t_{j+1})*(t_{j+2} - t_{j+1}) + ...
    remaining_t <- c(event_times[j:length(event_times)], tau)
    remaining_s <- surv[j:length(surv)]
    # intervals from t_j to end
    tail_areas[j] <- sum(remaining_s * diff(remaining_t))
}

gw_terms <- (d_events / (n_risk * (n_risk - d_events))) * tail_areas^2
rmst_se <- sqrt(sum(gw_terms))
rmst_lb <- rmst - qnorm(0.975) * rmst_se
rmst_ub <- rmst + qnorm(0.975) * rmst_se

results$rmst_se <- rmst_se
results$rmst_lb <- rmst_lb
results$rmst_ub <- rmst_ub

cat(sprintf("  RMST SE = %.6f\n", rmst_se))
cat(sprintf("  RMST CI: (%.6f, %.6f)\n", rmst_lb, rmst_ub))

# ============================================================
# SECTION 13: z-to-p conversion (ranksum)
# ============================================================
# p = 2 * pnorm(-|z|)

cat("\nSection 13: z-to-p conversion\n")

z_vals <- c(1.96, 2.576, 0.5, 3.0, -1.645)
p_vals <- 2 * pnorm(-abs(z_vals))

results$z_to_p_z1 <- z_vals[1]
results$z_to_p_p1 <- p_vals[1]
results$z_to_p_z2 <- z_vals[2]
results$z_to_p_p2 <- p_vals[2]
results$z_to_p_z3 <- z_vals[3]
results$z_to_p_p3 <- p_vals[3]
results$z_to_p_z4 <- z_vals[4]
results$z_to_p_p4 <- p_vals[4]
results$z_to_p_z5 <- z_vals[5]
results$z_to_p_p5 <- p_vals[5]

for (i in seq_along(z_vals)) {
    cat(sprintf("  z=%.3f: p=%.10e\n", z_vals[i], p_vals[i]))
}

# ============================================================
# SECTION 14: Multi-level ICC, MOR boundaries, ICC binary extra
# ============================================================
# CV15: Multi-level ICC — sum all RE variances over total variance
# CV16: MOR boundary cases and monotonicity
# CV17: ICC binary — additional test case with different variance

cat("\nSection 14: Multi-level ICC, MOR boundaries, ICC binary extra\n")

# CV15: Multi-level ICC (3-level model: obs within classes within schools)
var1      <- 0.49    # class-level variance (e.g., lns1_1_1 -> log(0.7) -> var=0.49)
var2      <- 0.25    # school-level variance (e.g., lns2_1_1 -> log(0.5) -> var=0.25)
var_resid <- 1.00    # residual variance
icc_multilevel <- (var1 + var2) / (var1 + var2 + var_resid)

results$icc_ml_var1      <- var1
results$icc_ml_var2      <- var2
results$icc_ml_var_resid <- var_resid
results$icc_ml           <- icc_multilevel

cat(sprintf("  Multi-level ICC (var1=%.2f, var2=%.2f, resid=%.2f): %.10f\n",
    var1, var2, var_resid, icc_multilevel))

# CV16: MOR boundary values
# var=0 -> MOR should equal 1 (no between-group variance)
var_zero <- 0.0
mor_zero <- exp(sqrt(2 * var_zero) * qnorm(0.75))
results$mor_bnd_zero <- mor_zero
cat(sprintf("  MOR(var=0): %.10f  (expected 1.0)\n", mor_zero))

# var=0.1 (small positive)
var_small <- 0.1
mor_small <- exp(sqrt(2 * var_small) * qnorm(0.75))
results$mor_bnd_small <- mor_small
cat(sprintf("  MOR(var=0.1): %.10f\n", mor_small))

# var=2.0 (large) — MOR grows unboundedly
var_large <- 2.0
mor_large <- exp(sqrt(2 * var_large) * qnorm(0.75))
results$mor_bnd_large <- mor_large
cat(sprintf("  MOR(var=2.0): %.10f\n", mor_large))

# Verify monotonicity: MOR(0) < MOR(0.1) < MOR(2.0)
stopifnot(mor_zero < mor_small)
stopifnot(mor_small < mor_large)

# CV17: ICC binary — additional test case (var_re = 0.25)
var_binary_extra <- 0.25
icc_binary_extra <- var_binary_extra / (var_binary_extra + pi^2/3)
results$icc_bin_extra_var <- var_binary_extra
results$icc_bin_extra     <- icc_binary_extra
cat(sprintf("  ICC binary (var=0.25): %.10f\n", icc_binary_extra))

# Single-level ICC (continuous model: var_re=1.0, var_resid=2.0)
var_re_single   <- 1.0
var_res_single  <- 2.0
icc_single      <- var_re_single / (var_re_single + var_res_single)
results$icc_single_var_re  <- var_re_single
results$icc_single_var_res <- var_res_single
results$icc_single         <- icc_single
cat(sprintf("  ICC single-level (var_re=1.0, var_resid=2.0): %.10f\n", icc_single))

# ============================================================
# Export all results to CSV
# ============================================================

cat("\nExporting results...\n")

# Convert results list to a two-column data frame
results_df <- data.frame(
    metric = names(results),
    value = as.numeric(results),
    stringsAsFactors = FALSE
)

write.csv(results_df, "data/crossval_tabtools_r_results.csv", row.names = FALSE)

cat(sprintf("\nDone. %d metrics saved to data/crossval_tabtools_r_results.csv\n",
    nrow(results_df)))
cat("Now run crossval_tabtools.do in Stata.\n")
