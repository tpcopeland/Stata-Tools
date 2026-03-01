#!/usr/bin/env Rscript
# Cross-Validation: R netmeta benchmarks for Stata nma
# Generates treatment effect estimates for two published NMA datasets
#
# Datasets:
#   1. Senn et al. (2013) — Glucose-lowering drugs, 26 studies, 10 treatments
#      Continuous outcome (HbA1c mean difference), pre-computed contrasts
#   2. Dogliotti et al. (2014) — Anticoagulants in AF, 20 studies, 8 treatments
#      Binary outcome (stroke events), arm-level data
#
# Usage: Rscript 01_r_netmeta.R
#   (run from nma/qa/ directory, or from any location)
#
# Output: r_results/senn2013_benchmarks.csv, r_results/dogliotti2014_benchmarks.csv
#
# Requires: install.packages("netmeta")

library(netmeta)

# Paths
args <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("--file=", "", args[grep("--file=", args)])
if (length(script_arg) > 0) {
    base_dir <- dirname(normalizePath(script_arg))
} else {
    base_dir <- getwd()
}
results_dir <- file.path(base_dir, "r_results")
dir.create(results_dir, showWarnings = FALSE, recursive = TRUE)

cat("R netmeta Cross-Validation Benchmarks\n")
cat("======================================\n\n")

# =========================================================================
# DATASET 1: Senn 2013 — Glucose-lowering drugs (HbA1c MD)
# =========================================================================
# Data from: Senn S, Gavini F, Magrez D, Scheen A (2013).
# "Issues in performing a network meta-analysis."
# Statistical Methods in Medical Research, 22(2), 169-189.

cat("Dataset 1: Senn 2013 — Glucose-lowering drugs\n")
cat("----------------------------------------------\n")

senn <- data.frame(
    study = c("DeFronzo1995", "Lewin2007", "Willms1999a", "Davidson2007",
              "Wolffenbuttel1999", "Kipnes2001", "Kerenyi2004", "Hanefeld2004",
              "Derosa2004", "Baksi2004", "Rosenstock2008", "Zhu2003",
              "Yang2003", "Vongthavaravat02", "Oyama2008", "Costa1997",
              "Hermansen2007", "Garber2008", "Alex1998", "Johnston1994",
              "Johnston1998a", "Kim2007", "Johnston1998b", "GonzalezOrtiz04",
              "Stucci1996", "Moulin2006", "Willms1999b", "Willms1999c"),
    treat1 = c("Metformin", "Metformin", "Metformin", "Rosiglitazone",
               "Rosiglitazone", "Pioglitazone", "Rosiglitazone", "Pioglitazone",
               "Pioglitazone", "Rosiglitazone", "Rosiglitazone", "Rosiglitazone",
               "Rosiglitazone", "Rosiglitazone", "Acarbose", "Acarbose",
               "Sitagliptin", "Vildagliptin", "Metformin", "Miglitol",
               "Miglitol", "Rosiglitazone", "Miglitol", "Metformin",
               "Benfluorex", "Benfluorex", "Metformin", "Acarbose"),
    treat2 = c("Placebo", "Placebo", "Acarbose", "Placebo",
               "Placebo", "Placebo", "Placebo", "Metformin",
               "Rosiglitazone", "Placebo", "Placebo", "Placebo",
               "Metformin", "Sulfonylurea", "Sulfonylurea", "Placebo",
               "Placebo", "Placebo", "Sulfonylurea", "Placebo",
               "Placebo", "Metformin", "Placebo", "Placebo",
               "Placebo", "Placebo", "Placebo", "Placebo"),
    te = c(-1.90, -0.82, -0.20, -1.34, -1.10, -1.30, -0.77, 0.16,
           0.10, -1.30, -1.09, -1.50, -0.14, -1.20, -0.40, -0.80,
           -0.57, -0.70, -0.37, -0.74, -1.41, 0.00, -0.68, -0.40,
           -0.23, -1.01, -1.20, -1.00),
    se_te = c(0.1414, 0.0992, 0.3579, 0.1435, 0.1141, 0.1268, 0.1078,
              0.0849, 0.1831, 0.1014, 0.2263, 0.1624, 0.2239, 0.1436,
              0.1549, 0.1432, 0.1291, 0.1273, 0.1184, 0.1839, 0.2235,
              0.2339, 0.2828, 0.4356, 0.3467, 0.1366, 0.3758, 0.4669),
    stringsAsFactors = FALSE
)

nm_senn <- netmeta(
    TE = senn$te, seTE = senn$se_te,
    treat1 = senn$treat1, treat2 = senn$treat2,
    studlab = senn$study,
    sm = "MD", reference.group = "Placebo",
    method.tau = "REML",
    random = TRUE, fixed = FALSE
)

cat(sprintf("  tau2 = %.4f\n", nm_senn$tau^2))
cat("  Treatment effects vs Placebo (random-effects REML):\n")

senn_trts <- sort(setdiff(unique(c(senn$treat1, senn$treat2)), "Placebo"))
senn_results <- data.frame(
    treatment = character(),
    estimate = numeric(),
    stringsAsFactors = FALSE
)

for (trt in senn_trts) {
    # netmeta stores results as treat1 vs treat2 in TE.random matrix
    est <- nm_senn$TE.random[trt, "Placebo"]
    cat(sprintf("    %-15s  %9.4f\n", trt, est))
    senn_results <- rbind(senn_results, data.frame(
        treatment = trt,
        estimate = est,
        abs_estimate = abs(est),
        stringsAsFactors = FALSE
    ))
}

senn_results <- rbind(senn_results, data.frame(
    treatment = "tau2",
    estimate = nm_senn$tau^2,
    abs_estimate = nm_senn$tau^2,
    stringsAsFactors = FALSE
))

write.csv(senn_results, file.path(results_dir, "senn2013_benchmarks.csv"),
    row.names = FALSE)
cat("  Saved r_results/senn2013_benchmarks.csv\n\n")

# =========================================================================
# DATASET 2: Dogliotti 2014 — Anticoagulants in AF
# =========================================================================
# Data from: Dogliotti A, Parati G, Mancia G (2014).
# "Therapies for preventing stroke in atrial fibrillation."
# Arm-level data (events/totals), converted to pairwise contrasts by netmeta.

cat("Dataset 2: Dogliotti 2014 — Anticoagulants in AF\n")
cat("-------------------------------------------------\n")

dog <- data.frame(
    study = c("AFASAK_I_1989", "AFASAK_I_1989", "AFASAK_I_1989",
              "BAATAF_1990", "BAATAF_1990",
              "CAFA_1991", "CAFA_1991",
              "SPAF_I_1991", "SPAF_I_1991", "SPAF_I_1991",
              "SPINAF_1992", "SPINAF_1992",
              "EAFT_1993", "EAFT_1993", "EAFT_1993",
              "SPAF_II_1994", "SPAF_II_1994",
              "AFASAK_II_1998", "AFASAK_II_1998",
              "PATAF_1999", "PATAF_1999",
              "LASAF_1999", "LASAF_1999",
              "ACTIVE_W_2006", "ACTIVE_W_2006",
              "JAST_2006", "JAST_2006",
              "ACTIVE_A_2006", "ACTIVE_A_2006",
              "Chinese_ATAFS_2006", "Chinese_ATAFS_2006",
              "BAFTA_2007", "BAFTA_2007",
              "WASPO_2007", "WASPO_2007",
              "RE_LY_2009", "RE_LY_2009", "RE_LY_2009",
              "ROCKET_2011", "ROCKET_2011",
              "ARISTOTLE_2011", "ARISTOTLE_2011",
              "AVERROES_2011", "AVERROES_2011"),
    treatment = c("VKA", "ASA", "Placebo",
                  "VKA", "Placebo",
                  "VKA", "Placebo",
                  "VKA", "ASA", "Placebo",
                  "VKA", "Placebo",
                  "VKA", "ASA", "Placebo",
                  "VKA", "ASA",
                  "VKA", "ASA",
                  "VKA", "ASA",
                  "ASA", "Placebo",
                  "VKA", "ASA_Clop",
                  "ASA", "Placebo",
                  "ASA_Clop", "ASA",
                  "VKA", "ASA",
                  "VKA", "ASA",
                  "VKA", "ASA",
                  "Dab110", "Dab150", "VKA",
                  "Rivarox", "VKA",
                  "Apixaban", "VKA",
                  "Apixaban", "ASA"),
    events = c(9, 16, 19,
               3, 13,
               6, 9,
               8, 24, 42,
               7, 23,
               20, 88, 90,
               39, 42,
               10, 9,
               3, 22,
               5, 3,
               59, 100,
               17, 18,
               296, 408,
               9, 17,
               21, 44,
               0, 0,
               171, 122, 185,
               188, 240,
               197, 248,
               49, 105),
    total = c(335, 336, 336,
              212, 208,
              187, 191,
              210, 552, 568,
              260, 265,
              225, 404, 378,
              555, 545,
              170, 169,
              131, 319,
              194, 91,
              3371, 3335,
              426, 445,
              3772, 3782,
              335, 369,
              488, 485,
              36, 39,
              6015, 6076, 6022,
              7081, 7090,
              9120, 9081,
              2808, 2791),
    stringsAsFactors = FALSE
)

# netmeta pairwise conversion from arm-level data
pw_dog <- pairwise(
    treat = treatment, event = events, n = total,
    studlab = study, data = dog, sm = "OR"
)

nm_dog <- netmeta(
    TE = pw_dog$TE, seTE = pw_dog$seTE,
    treat1 = pw_dog$treat1, treat2 = pw_dog$treat2,
    studlab = pw_dog$studlab,
    sm = "OR", reference.group = "Placebo",
    method.tau = "REML",
    random = TRUE, fixed = FALSE
)

cat(sprintf("  tau2 = %.4f\n", nm_dog$tau^2))
cat("  Treatment effects vs Placebo (logOR, random-effects REML):\n")

dog_trts <- sort(setdiff(unique(dog$treatment), "Placebo"))
dog_results <- data.frame(
    treatment = character(),
    estimate = numeric(),
    stringsAsFactors = FALSE
)

for (trt in dog_trts) {
    est <- nm_dog$TE.random[trt, "Placebo"]
    cat(sprintf("    %-15s  %9.4f\n", trt, est))
    dog_results <- rbind(dog_results, data.frame(
        treatment = trt,
        estimate = est,
        abs_estimate = abs(est),
        stringsAsFactors = FALSE
    ))
}

dog_results <- rbind(dog_results, data.frame(
    treatment = "tau2",
    estimate = nm_dog$tau^2,
    abs_estimate = nm_dog$tau^2,
    stringsAsFactors = FALSE
))

write.csv(dog_results, file.path(results_dir, "dogliotti2014_benchmarks.csv"),
    row.names = FALSE)
cat("  Saved r_results/dogliotti2014_benchmarks.csv\n\n")

# =========================================================================
# SUMMARY — values to use in crossval_nma_vs_r.do
# =========================================================================

cat("=======================================================================\n")
cat("Benchmark values for crossval_nma_vs_r.do\n")
cat("=======================================================================\n\n")

cat("* Senn 2013 — MD vs Placebo (REML random-effects)\n")
for (i in seq_len(nrow(senn_results))) {
    trt <- senn_results$treatment[i]
    val <- senn_results$abs_estimate[i]
    # Format as Stata local
    trt_clean <- gsub(" ", "", trt)
    cat(sprintf("local r_s_%-15s = %.4f\n", trt_clean, val))
}

cat("\n* Dogliotti 2014 — logOR vs Placebo (REML random-effects)\n")
for (i in seq_len(nrow(dog_results))) {
    trt <- dog_results$treatment[i]
    val <- dog_results$abs_estimate[i]
    trt_clean <- gsub(" ", "", trt)
    cat(sprintf("local r_d_%-15s = %.4f\n", trt_clean, val))
}

cat("\nDone.\n")
