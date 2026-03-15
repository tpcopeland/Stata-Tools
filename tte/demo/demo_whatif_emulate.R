#!/usr/bin/env Rscript
# ==============================================================================
# demo_whatif_emulate.R — What If Programs 17.2 and 17.3 in R
#
# Replicates:
#   Hernan MA, Robins JM. Causal Inference: What If. 2020.
#   Chapter 17: Causal survival analysis (NHEFS dataset).
#
# Program 17.2: Unweighted pooled logistic hazards model
# Program 17.3: IP-weighted pooled logistic + standardized survival curves
#
# Companion scripts:
#   demo_whatif.do                    — Stata
#   demo_whatif_trialemulation.R      — R (TrialEmulation)
#
# Requirements: data.table, sandwich, ggplot2
# Data: NHEFS (1,629 smokers, 120-month follow-up)
#
# Usage:
#   Rscript demo/demo_whatif.R         # from emulate package root
# ==============================================================================

cat("==============================================================================\n")
cat("What If Replication: NHEFS Smoking Cessation & Survival\n")
cat("Hernan MA, Robins JM. Programs 17.2 and 17.3\n")
cat("==============================================================================\n\n")

library(data.table)
library(ggplot2)

output_dir <- file.path(getwd(), "demo_output_emulate")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# DATA PREPARATION: Person-month dataset
# ==============================================================================

cat("DATA PREPARATION\n")
cat(strrep("-", 70), "\n")

# Try bundled NHEFS first (emulate package), then Stata-Tools copy
nhefs_path <- system.file("extdata", "nhefs.csv", package = "emulate")
if (nhefs_path == "" || !file.exists(nhefs_path)) {
  nhefs_dta <- "~/Stata-Tools/tte/qa/data/nhefs.dta"
  if (file.exists(nhefs_dta)) {
    d_raw <- haven::read_dta(nhefs_dta)
    setDT(d_raw)
  } else {
    nhefs_url <- "https://cdn1.sph.harvard.edu/wp-content/uploads/sites/1268/2012/10/nhefs.csv"
    nhefs_path <- file.path(output_dir, "nhefs.csv")
    if (!file.exists(nhefs_path)) download.file(nhefs_url, nhefs_path, quiet = TRUE)
    d_raw <- fread(nhefs_path)
  }
} else {
  d_raw <- fread(nhefs_path)
}

key_vars <- c("qsmk", "death", "age", "sex", "race", "wt71",
              "smokeintensity", "smokeyrs", "exercise", "active", "education")
d_raw <- d_raw[complete.cases(d_raw[, ..key_vars])]

cat(sprintf("  Subjects:      %d\n", nrow(d_raw)))
cat(sprintf("  Deaths:        %d (%.1f%%)\n",
            sum(d_raw$death), 100 * mean(d_raw$death)))

# Survival time in months
d_raw[, survtime := 120L]
d_raw[death == 1 & !is.na(yrdth) & !is.na(modth),
      survtime := as.integer((yrdth - 83) * 12 + modth)]

# Expand to person-month
d_pm <- d_raw[rep(seq_len(.N), survtime)]
d_pm[, time := seq_len(.N) - 1L, by = seqn]
d_pm[, event := as.integer(death == 1 & seq_len(.N) == .N), by = seqn]
d_pm[, timesq := time * time]

cat(sprintf("  Person-months: %s\n\n", format(nrow(d_pm), big.mark = ",")))

# ==============================================================================
# PROGRAM 17.2: Unweighted (crude) pooled logistic
# ==============================================================================

cat("PROGRAM 17.2: Unweighted (crude) pooled logistic\n")
cat(strrep("-", 70), "\n")

crude_fit <- glm(event ~ qsmk * (time + timesq),
                 data = d_pm, family = binomial())

crude_coef <- coef(crude_fit)["qsmk"]
crude_or <- exp(crude_coef)
cat(sprintf("  Crude OR for qsmk: %.4f\n", crude_or))

# Standardized survival curves (crude)
baseline_pm <- d_pm[time == 0]
grid_crude <- CJ(seqn = baseline_pm$seqn, time = 0:119, qsmk = 0:1)
grid_crude[, timesq := time * time]
grid_crude[, p_event := predict(crude_fit, newdata = grid_crude, type = "response")]
grid_crude[, p_surv_k := 1 - p_event]
setorder(grid_crude, seqn, qsmk, time)
grid_crude[, cum_surv := cumprod(p_surv_k), by = .(seqn, qsmk)]

surv_crude <- grid_crude[time == 119, .(surv = mean(cum_surv)), by = qsmk]
cat(sprintf("\n  10-year survival (crude):\n"))
cat(sprintf("    Continue smoking: %.4f\n", surv_crude[qsmk == 0, surv]))
cat(sprintf("    Quit smoking:     %.4f\n", surv_crude[qsmk == 1, surv]))
cat(sprintf("    Difference:       %.4f\n\n",
            surv_crude[qsmk == 1, surv] - surv_crude[qsmk == 0, surv]))

# Plot
surv_crude_t <- grid_crude[, .(surv = mean(cum_surv)), by = .(qsmk, time)]
surv_crude_t[, arm := factor(qsmk, labels = c("Continue smoking (A=0)",
                                                "Quit smoking (A=1)"))]

p_crude <- ggplot(surv_crude_t, aes(x = time, y = surv, color = arm)) +
  geom_line(linewidth = 0.8) +
  scale_x_continuous(breaks = seq(0, 120, 12)) +
  scale_y_continuous(limits = c(0.6, 1.0), breaks = seq(0.6, 1.0, 0.1)) +
  labs(x = "Months of follow-up", y = "Survival probability",
       title = "Crude survival curves (Program 17.2)", color = NULL) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(file.path(output_dir, "survival_curves_crude.png"),
       p_crude, width = 8, height = 5, dpi = 150)

# ==============================================================================
# PROGRAM 17.3: IP-weighted pooled logistic
# ==============================================================================

cat("PROGRAM 17.3: IP-weighted pooled logistic\n")
cat(strrep("-", 70), "\n")

# Stabilized IP weights (exact textbook specification)
baseline <- d_pm[time == 0]
denom_fit <- glm(qsmk ~ sex + race + age + I(age^2) +
                   factor(education) +
                   smokeintensity + I(smokeintensity^2) +
                   smokeyrs + I(smokeyrs^2) +
                   factor(exercise) + factor(active) +
                   wt71 + I(wt71^2),
                 data = baseline, family = binomial())
p_denom <- predict(denom_fit, type = "response")
p_numer <- mean(baseline$qsmk)

baseline[, sw := ifelse(qsmk == 1,
                        p_numer / p_denom,
                        (1 - p_numer) / (1 - p_denom))]
cat(sprintf("  Stabilized IP weights:\n"))
cat(sprintf("    Mean: %.4f  SD: %.4f  Min: %.4f  Max: %.4f\n",
            mean(baseline$sw), sd(baseline$sw),
            min(baseline$sw), max(baseline$sw)))

d_pm <- merge(d_pm, baseline[, .(seqn, sw)], by = "seqn", all.x = TRUE)

# IP-weighted pooled logistic
cat("\n  Fitting IP-weighted pooled logistic model...\n")
ipw_fit <- glm(event ~ qsmk * (time + timesq),
               data = d_pm, family = binomial(),
               weights = sw)

V_robust <- sandwich::vcovCL(ipw_fit, cluster = d_pm$seqn)
ipw_coef <- coef(ipw_fit)["qsmk"]
ipw_se <- sqrt(V_robust["qsmk", "qsmk"])
ipw_or <- exp(ipw_coef)

cat(sprintf("\n  Treatment coefficient: %8.4f\n", ipw_coef))
cat(sprintf("  Robust SE:             %8.4f\n", ipw_se))
cat(sprintf("  OR:                    %8.4f\n", ipw_or))

# Standardized survival curves
grid_ipw <- CJ(seqn = baseline$seqn, time = 0:119, qsmk = 0:1)
grid_ipw[, timesq := time * time]
grid_ipw[, p_event := predict(ipw_fit, newdata = grid_ipw, type = "response")]
grid_ipw[, p_surv_k := 1 - p_event]
setorder(grid_ipw, seqn, qsmk, time)
grid_ipw[, cum_surv := cumprod(p_surv_k), by = .(seqn, qsmk)]

surv_ipw <- grid_ipw[time == 119, .(surv = mean(cum_surv)), by = qsmk]
surv_0 <- surv_ipw[qsmk == 0, surv]
surv_1 <- surv_ipw[qsmk == 1, surv]

cat(sprintf("\n  10-year standardized survival (month 119):\n"))
cat(sprintf("    Continue smoking (A=0): %.4f\n", surv_0))
cat(sprintf("    Quit smoking (A=1):     %.4f\n", surv_1))
cat(sprintf("    Survival difference:    %.4f\n", surv_1 - surv_0))
cat("    (Positive = quitting prolongs survival)\n")

# Plot (Figure 17.6)
surv_ipw_t <- grid_ipw[, .(surv = mean(cum_surv)), by = .(qsmk, time)]
surv_ipw_t[, arm := factor(qsmk, labels = c("Continue smoking (A=0)",
                                              "Quit smoking (A=1)"))]

p_ipw <- ggplot(surv_ipw_t, aes(x = time, y = surv, color = arm)) +
  geom_line(linewidth = 0.8) +
  scale_x_continuous(breaks = seq(0, 120, 12)) +
  scale_y_continuous(limits = c(0.6, 1.0), breaks = seq(0.6, 1.0, 0.1)) +
  labs(x = "Months of follow-up", y = "Survival probability",
       title = "IP-weighted survival curves (What If Figure 17.6)",
       color = NULL) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(file.path(output_dir, "survival_curves_ipweighted.png"),
       p_ipw, width = 8, height = 5, dpi = 150)

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n")
cat(strrep("=", 69), "\n")
cat("SUMMARY\n")
cat(strrep("-", 69), "\n")
cat(sprintf("%-35s %12s %10s\n", "", "Coefficient", "OR"))
cat(strrep("-", 57), "\n")
cat(sprintf("%-35s %12.4f %10.4f\n", "Program 17.2 (crude)", crude_coef, crude_or))
cat(sprintf("%-35s %12.4f %10.4f\n", "Program 17.3 (IP-weighted)", ipw_coef, ipw_or))
cat(strrep("-", 57), "\n\n")

cat(sprintf("%-35s %12s %10s %12s\n", "", "Continue", "Quit", "Diff"))
cat(strrep("-", 69), "\n")
cat(sprintf("%-35s %12.4f %10.4f %12.4f\n", "10-yr survival (crude)",
            surv_crude[qsmk == 0, surv], surv_crude[qsmk == 1, surv],
            surv_crude[qsmk == 1, surv] - surv_crude[qsmk == 0, surv]))
cat(sprintf("%-35s %12.4f %10.4f %12.4f\n", "10-yr survival (IP-weighted)",
            surv_0, surv_1, surv_1 - surv_0))
cat(strrep("=", 69), "\n")

# Save comparison
comparison <- data.frame(
  Method = c("Program_17.2_crude", "Program_17.3_IPweighted"),
  Coefficient = c(crude_coef, ipw_coef),
  OR = c(crude_or, ipw_or),
  Survival_A0 = c(surv_crude[qsmk == 0, surv], surv_0),
  Survival_A1 = c(surv_crude[qsmk == 1, surv], surv_1),
  stringsAsFactors = FALSE
)
write.csv(comparison, file.path(output_dir, "comparison.csv"), row.names = FALSE)

cat(sprintf("\nOutput: %s\n", output_dir))
