#!/usr/bin/env Rscript
# generate_r_benchmarks.R
# Generate cross-validation benchmarks for gcomp using R mediation package
#
# DGP: Binary exposure mediation with one confounder
#   C ~ Normal(50, 10)
#   X ~ Bernoulli(invlogit(-2 + 0.02*C))
#   M ~ Bernoulli(invlogit(-1 + 0.8*X + 0.01*C))
#   Y ~ Bernoulli(invlogit(-3 + 0.5*M + 0.3*X + 0.02*C))
#
# This matches the Example 1 in the gcomp README.

library(mediation)

# ── V1: Known DGP — analytical ground truth ──────────────────────────

set.seed(12345)
N <- 100000

# Generate large population to compute "true" potential outcome means
C <- rnorm(N, 50, 10)

# Probabilities under each potential outcome scenario
p_M1_X1 <- plogis(-1 + 0.8 * 1 + 0.01 * C)  # P(M=1 | X=1, C)
p_M1_X0 <- plogis(-1 + 0.8 * 0 + 0.01 * C)  # P(M=1 | X=0, C)

# E[Y | M=m, X=x, C] = invlogit(-3 + 0.5*m + 0.3*x + 0.02*C)
p_Y_M1_X1 <- plogis(-3 + 0.5 * 1 + 0.3 * 1 + 0.02 * C)
p_Y_M0_X1 <- plogis(-3 + 0.5 * 0 + 0.3 * 1 + 0.02 * C)
p_Y_M1_X0 <- plogis(-3 + 0.5 * 1 + 0.3 * 0 + 0.02 * C)
p_Y_M0_X0 <- plogis(-3 + 0.5 * 0 + 0.3 * 0 + 0.02 * C)

# Potential outcome means (by law of iterated expectations over M)
# E[Y(x, M(x'))] = E_C[ P(Y=1|M=1,x,C)*P(M=1|x',C) + P(Y=1|M=0,x,C)*P(M=0|x',C) ]
EY_1_M1 <- mean(p_Y_M1_X1 * p_M1_X1 + p_Y_M0_X1 * (1 - p_M1_X1))  # E[Y(1, M(1))]
EY_0_M0 <- mean(p_Y_M1_X0 * p_M1_X0 + p_Y_M0_X0 * (1 - p_M1_X0))  # E[Y(0, M(0))]
EY_1_M0 <- mean(p_Y_M1_X1 * p_M1_X0 + p_Y_M0_X1 * (1 - p_M1_X0))  # E[Y(1, M(0))]

true_TCE <- EY_1_M1 - EY_0_M0
true_NDE <- EY_1_M0 - EY_0_M0
true_NIE <- true_TCE - true_NDE
true_PM  <- true_NIE / true_TCE

cat("=== Analytical Ground Truth (N=100,000 MC integration) ===\n")
cat(sprintf("E[Y(1,M(1))] = %.6f\n", EY_1_M1))
cat(sprintf("E[Y(0,M(0))] = %.6f\n", EY_0_M0))
cat(sprintf("E[Y(1,M(0))] = %.6f\n", EY_1_M0))
cat(sprintf("True TCE = %.6f\n", true_TCE))
cat(sprintf("True NDE = %.6f\n", true_NDE))
cat(sprintf("True NIE = %.6f\n", true_NIE))
cat(sprintf("True PM  = %.6f\n", true_PM))

# ── V2: Generate cross-validation dataset (N=5000) ──────────────────

set.seed(42)
N2 <- 5000

C2 <- rnorm(N2, 50, 10)
X2 <- rbinom(N2, 1, plogis(-2 + 0.02 * C2))
M2 <- rbinom(N2, 1, plogis(-1 + 0.8 * X2 + 0.01 * C2))
Y2 <- rbinom(N2, 1, plogis(-3 + 0.5 * M2 + 0.3 * X2 + 0.02 * C2))

df <- data.frame(c = C2, x = X2, m = M2, y = Y2)
write.csv(df, "crossval_data.csv", row.names = FALSE)

cat(sprintf("\nDataset: N=%d, mean(X)=%.3f, mean(M)=%.3f, mean(Y)=%.3f\n",
            N2, mean(X2), mean(M2), mean(Y2)))

# ── V2: R mediation package estimates ────────────────────────────────

# Fit models (same specification as gcomp)
med.fit <- glm(m ~ x + c, data = df, family = binomial(link = "logit"))
out.fit <- glm(y ~ m + x + c, data = df, family = binomial(link = "logit"))

cat("\n=== R Model Coefficients ===\n")
cat("Mediator model (M ~ X + C):\n")
print(coef(med.fit))
cat("\nOutcome model (Y ~ M + X + C):\n")
print(coef(out.fit))

# Run mediation analysis
set.seed(12345)
med.out <- mediate(med.fit, out.fit, treat = "x", mediator = "m",
                   sims = 5000, boot = FALSE)

cat("\n=== R mediation Package Results ===\n")
cat(sprintf("ACME (NIE)     = %.6f  (95%% CI: %.6f, %.6f)\n",
            med.out$d0, med.out$d0.ci[1], med.out$d0.ci[2]))
cat(sprintf("ADE  (NDE)     = %.6f  (95%% CI: %.6f, %.6f)\n",
            med.out$z0, med.out$z0.ci[1], med.out$z0.ci[2]))
cat(sprintf("Total Effect   = %.6f  (95%% CI: %.6f, %.6f)\n",
            med.out$tau.coef, med.out$tau.ci[1], med.out$tau.ci[2]))
cat(sprintf("Prop. Mediated = %.6f  (95%% CI: %.6f, %.6f)\n",
            med.out$n0, med.out$n0.ci[1], med.out$n0.ci[2]))

# Save benchmark results
benchmarks <- data.frame(
  metric = c("true_tce", "true_nde", "true_nie", "true_pm",
             "r_tce", "r_nde", "r_nie", "r_pm",
             "r_tce_ci_lo", "r_tce_ci_hi",
             "r_nde_ci_lo", "r_nde_ci_hi",
             "r_nie_ci_lo", "r_nie_ci_hi"),
  value = c(true_TCE, true_NDE, true_NIE, true_PM,
            med.out$tau.coef, med.out$z0, med.out$d0, med.out$n0,
            med.out$tau.ci[1], med.out$tau.ci[2],
            med.out$z0.ci[1], med.out$z0.ci[2],
            med.out$d0.ci[1], med.out$d0.ci[2])
)
write.csv(benchmarks, "r_benchmarks.csv", row.names = FALSE)

cat("\nBenchmarks saved to r_benchmarks.csv\n")
cat("Dataset saved to crossval_data.csv\n")
