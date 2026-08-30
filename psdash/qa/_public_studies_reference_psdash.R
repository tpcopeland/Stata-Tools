#!/usr/bin/env Rscript

# Public-study reference generator for crossval_public_studies.do.
# Data sources are cobalt::lalonde (NSW job-training benchmark) and
# MASS::birthwt (low-birth-weight study). cobalt computes the balance oracle;
# base R independently computes propensity scores, support, AUC, and ESS.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
    stop("usage: _public_studies_reference_psdash.R output-directory")
}
if (!requireNamespace("cobalt", quietly = TRUE) ||
    !requireNamespace("MASS", quietly = TRUE)) {
    quit(status = 77L)
}

outdir <- normalizePath(args[[1L]], mustWork = FALSE)
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
rows <- list()

add_metric <- function(key, value) {
    rows[[length(rows) + 1L]] <<- data.frame(
        key = key,
        value = sprintf("%.17g", as.numeric(value)),
        stringsAsFactors = FALSE
    )
}

ess <- function(weight) {
    sum(weight)^2 / sum(weight^2)
}

auc_pairwise <- function(treat, score) {
    treated <- score[treat == 1L]
    control <- score[treat == 0L]
    comparisons <- outer(treated, control, "-")
    (sum(comparisons > 0) + 0.5 * sum(comparisons == 0)) /
        length(comparisons)
}

add_core_metrics <- function(prefix, data, ps, weight) {
    treat <- data$treat
    treated <- treat == 1L
    control <- treat == 0L
    lower <- max(min(ps[treated]), min(ps[control]))
    upper <- min(max(ps[treated]), max(ps[control]))
    outside <- ps < lower | ps > upper
    trimmed <- ps < 0.1 | ps > 0.9

    add_metric(paste0(prefix, "_N"), nrow(data))
    add_metric(paste0(prefix, "_Nt"), sum(treated))
    add_metric(paste0(prefix, "_Nc"), sum(control))
    add_metric(paste0(prefix, "_mt"), mean(ps[treated]))
    add_metric(paste0(prefix, "_mc"), mean(ps[control]))
    add_metric(paste0(prefix, "_lo"), lower)
    add_metric(paste0(prefix, "_hi"), upper)
    add_metric(paste0(prefix, "_nout"), sum(outside))
    add_metric(paste0(prefix, "_noutt"), sum(outside & treated))
    add_metric(paste0(prefix, "_noutc"), sum(outside & control))
    add_metric(paste0(prefix, "_pout"), 100 * mean(outside))
    add_metric(paste0(prefix, "_auc"), auc_pairwise(treat, ps))
    add_metric(paste0(prefix, "_ntrim"), sum(trimmed))
    add_metric(paste0(prefix, "_ptrim"), 100 * mean(trimmed))

    add_metric(paste0(prefix, "_wm"), mean(weight))
    add_metric(paste0(prefix, "_wsd"), stats::sd(weight))
    add_metric(paste0(prefix, "_wcv"), stats::sd(weight) / mean(weight))
    add_metric(paste0(prefix, "_wmin"), min(weight))
    add_metric(paste0(prefix, "_wmax"), max(weight))
    add_metric(paste0(prefix, "_ess"), ess(weight))
    add_metric(paste0(prefix, "_esst"), ess(weight[treated]))
    add_metric(paste0(prefix, "_essc"), ess(weight[control]))
    add_metric(paste0(prefix, "_next"), sum(weight > 10))
}

add_balance_metrics <- function(prefix, data, weight, covariates, keys) {
    formula <- stats::reformulate(covariates, response = "treat")
    result <- cobalt::bal.tab(
        formula,
        data = data,
        weights = weight,
        s.d.denom = "pooled",
        binary = "std",
        continuous = "std",
        disp.v.ratio = TRUE,
        disp.ks = TRUE,
        un = TRUE
    )
    balance <- result$Balance

    add_metric(paste0(prefix, "_b_msr"), max(abs(balance[, "Diff.Un"])))
    add_metric(paste0(prefix, "_b_msa"), max(abs(balance[, "Diff.Adj"])))
    add_metric(paste0(prefix, "_b_mkr"), max(balance[, "KS.Un"]))
    add_metric(paste0(prefix, "_b_mka"), max(balance[, "KS.Adj"]))
    add_metric(paste0(prefix, "_b_nimb"), sum(abs(balance[, "Diff.Adj"]) > 0.1))

    for (i in seq_along(covariates)) {
        variable <- covariates[[i]]
        key <- keys[[i]]
        add_metric(paste0(prefix, "_b_", key, "_sr"), balance[variable, "Diff.Un"])
        add_metric(paste0(prefix, "_b_", key, "_sa"), balance[variable, "Diff.Adj"])
        add_metric(paste0(prefix, "_b_", key, "_kr"), balance[variable, "KS.Un"])
        add_metric(paste0(prefix, "_b_", key, "_ka"), balance[variable, "KS.Adj"])
        if (!is.na(balance[variable, "V.Ratio.Un"])) {
            add_metric(paste0(prefix, "_b_", key, "_vr"), balance[variable, "V.Ratio.Un"])
            add_metric(paste0(prefix, "_b_", key, "_va"), balance[variable, "V.Ratio.Adj"])
        }
    }
}

# National Supported Work job-training benchmark, as distributed by cobalt.
utils::data("lalonde", package = "cobalt", envir = environment())
lalonde$black <- as.integer(lalonde$race == "black")
lalonde$hispan <- as.integer(lalonde$race == "hispan")
lalonde$white <- as.integer(lalonde$race == "white")
lalonde_model <- stats::glm(
    treat ~ age + educ + race + married + nodegree + re74 + re75,
    data = lalonde,
    family = stats::binomial()
)
lalonde$ps <- stats::fitted(lalonde_model)
lalonde$w_att <- ifelse(lalonde$treat == 1L, 1, lalonde$ps / (1 - lalonde$ps))
lalonde_covars <- c("age", "educ", "married", "nodegree", "black", "hispan", "re74", "re75")
add_core_metrics("la", lalonde, lalonde$ps, lalonde$w_att)
add_balance_metrics(
    "la", lalonde, lalonde$w_att, lalonde_covars,
    c("age", "educ", "mar", "nodeg", "black", "hisp", "re74", "re75")
)
utils::write.csv(
    lalonde[c("treat", "age", "educ", "married", "nodegree", "black", "hispan", "white", "re74", "re75", "ps", "w_att")],
    file.path(outdir, "public_lalonde.csv"), row.names = FALSE, quote = FALSE
)

# Hosmer-Lemeshow low-birth-weight study data, distributed with MASS.
birthwt <- MASS::birthwt
birthwt$treat <- as.integer(birthwt$smoke)
birthwt$race2 <- as.integer(birthwt$race == 2L)
birthwt$race3 <- as.integer(birthwt$race == 3L)
birthwt_model <- stats::glm(
    treat ~ age + lwt + factor(race) + ptl + ht + ui + ftv,
    data = birthwt,
    family = stats::binomial()
)
birthwt$ps <- stats::fitted(birthwt_model)
birthwt$w_ate <- ifelse(birthwt$treat == 1L, 1 / birthwt$ps, 1 / (1 - birthwt$ps))
birthwt_covars <- c("age", "lwt", "race2", "race3", "ptl", "ht", "ui", "ftv")
add_core_metrics("bw", birthwt, birthwt$ps, birthwt$w_ate)
add_balance_metrics(
    "bw", birthwt, birthwt$w_ate, birthwt_covars,
    c("age", "lwt", "race2", "race3", "ptl", "ht", "ui", "ftv")
)
utils::write.csv(
    birthwt[c("treat", "age", "lwt", "race2", "race3", "ptl", "ht", "ui", "ftv", "ps", "w_ate")],
    file.path(outdir, "public_birthwt.csv"), row.names = FALSE, quote = FALSE
)

utils::write.csv(
    do.call(rbind, rows), file.path(outdir, "public_study_metrics.csv"),
    row.names = FALSE, quote = FALSE
)
