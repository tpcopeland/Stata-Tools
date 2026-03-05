#!/usr/bin/env Rscript
# xval_irreglong.R - Generate IrregLong reference weights for cross-validation
#
# Replicates the IrregLong Phenobarb vignette and exports:
#   1. Prepared dataset (phenobarb_prepared.csv)
#   2. Cox model coefficients (phenobarb_cox_coefs.csv)
#   3. IIW weights per observation (phenobarb_weights.csv)
#
# Usage: Rscript iivw/qa/xval_irreglong.R

library(IrregLong)
library(nlme)
library(survival)

cat("=== IrregLong Phenobarb Cross-Validation ===\n")
cat("IrregLong version:", as.character(packageVersion("IrregLong")), "\n\n")

outdir <- "iivw/qa"

# =============================================================================
# 1. Load and prepare Phenobarb data (following vignette exactly)
# =============================================================================

data(Phenobarb)
Phenobarb$event <- 1 - as.numeric(is.na(Phenobarb$conc))
data <- Phenobarb
data <- data[data$event == 1, ]
data$id <- as.numeric(data$Subject)
data <- data[data$time < 16 * 24, ]
data <- data[order(data$id, data$time), ]
data$Apgar <- as.numeric(data$Apgar)

cat("Phenobarb prepared: N =", nrow(data), "observations,",
    length(unique(data$id)), "subjects\n")

# =============================================================================
# 2. Compute IIW weights using iiw.weights()
# =============================================================================

# Following the vignette: simplified model after backward elimination
# Covariates: binned lagged concentration
i <- iiw.weights(
    Surv(time.lag, time, event) ~ I(conc.lag > 0 & conc.lag <= 20) +
                                   I(conc.lag > 20 & conc.lag <= 30) +
                                   I(conc.lag > 30) +
                                   cluster(Subject),
    id = "Subject",
    time = "time",
    event = "event",
    data = data,
    invariant = c("Subject", "Wt"),
    lagvars = c("time", "conc"),
    maxfu = 16 * 24,
    lagfirst = c(0, 0),
    first = FALSE
)

# Extract weights
data$iiw_weight <- i$iiw.weight

# Cox model coefficients
cox_coefs <- coef(i$m)
cat("\nCox model coefficients:\n")
print(cox_coefs)

# Also compute with first=TRUE for alternative comparison
i_first <- iiw.weights(
    Surv(time.lag, time, event) ~ I(conc.lag > 0 & conc.lag <= 20) +
                                   I(conc.lag > 20 & conc.lag <= 30) +
                                   I(conc.lag > 30) +
                                   cluster(Subject),
    id = "Subject",
    time = "time",
    event = "event",
    data = data,
    invariant = c("Subject", "Wt"),
    lagvars = c("time", "conc"),
    maxfu = 16 * 24,
    lagfirst = c(0, 0),
    first = TRUE
)
data$iiw_weight_first1 <- i_first$iiw.weight

cat("\nWeight summary (first=FALSE):\n")
print(summary(data$iiw_weight))
cat("\nWeight summary (first=TRUE):\n")
print(summary(data$iiw_weight_first1))

# =============================================================================
# 3. Export: prepared data with weights
# =============================================================================

# Create lagged variables matching what IrregLong used internally
data_sorted <- data[order(data$id, data$time), ]
data_sorted$time_lag <- ave(data_sorted$time, data_sorted$id,
    FUN = function(x) c(0, x[-length(x)]))
data_sorted$conc_lag <- ave(data_sorted$conc, data_sorted$id,
    FUN = function(x) c(0, x[-length(x)]))

# Observation number within subject
data_sorted$visit_n <- ave(rep(1, nrow(data_sorted)), data_sorted$id,
    FUN = cumsum)

# Export dataset
export_cols <- c("id", "time", "time_lag", "conc", "conc_lag", "Wt",
                 "Apgar", "event", "visit_n", "iiw_weight", "iiw_weight_first1")
write.csv(data_sorted[, export_cols],
    file = file.path(outdir, "phenobarb_prepared.csv"),
    row.names = FALSE)

# Export Cox coefficients
coef_df <- data.frame(
    term = names(cox_coefs),
    estimate = as.numeric(cox_coefs)
)
write.csv(coef_df,
    file = file.path(outdir, "phenobarb_cox_coefs.csv"),
    row.names = FALSE)

# Also export the full Cox data (with censoring rows) for diagnostics
cox_data <- i$datacox
write.csv(cox_data[, c("Subject", "time", "time.lag", "conc", "conc.lag",
                        "event", "Wt")],
    file = file.path(outdir, "phenobarb_cox_data.csv"),
    row.names = FALSE)

cat("\nExported:\n")
cat("  ", file.path(outdir, "phenobarb_prepared.csv"), "\n")
cat("  ", file.path(outdir, "phenobarb_cox_coefs.csv"), "\n")
cat("  ", file.path(outdir, "phenobarb_cox_data.csv"), "\n")

# =============================================================================
# 4. Also compute weights manually for verification
# =============================================================================

cat("\n=== Manual weight verification ===\n")
# The Cox data includes censoring rows at maxfu
# Fit Cox on full data (with censoring)
m_manual <- coxph(
    Surv(time.lag, time, event) ~ I(conc.lag > 0 & conc.lag <= 20) +
                                   I(conc.lag > 20 & conc.lag <= 30) +
                                   I(conc.lag > 30),
    data = cox_data
)
cat("Manual Cox coefs (should match):\n")
print(coef(m_manual))

# Predict on observed data only
obs_data <- cox_data[cox_data$event == 1, ]
xb <- predict(m_manual, newdata = obs_data, type = "lp")
manual_weights <- exp(-xb)
cat("\nManual weight summary (exp(-xb)):\n")
print(summary(manual_weights))

cat("\n=== Cross-validation data ready ===\n")
