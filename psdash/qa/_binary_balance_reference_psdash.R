#!/usr/bin/env Rscript

# Independent binary-balance reference for crossval_binary_balance_cobalt.do.
# cobalt::bal.tab() is the maintained external implementation; this script only
# reshapes its balance table into a long key,value csv.
#
# usage: _binary_balance_reference_psdash.R output.csv label1 input1.csv [label2 input2.csv ...]
# Each input csv has column `treat` (0/1), one column per covariate, and one
# weight column `wt`. Keys written: <label>_<covariate>_<metric> with metric in
#   mt_raw mc_raw smd_raw ks_raw  mt_adj mc_adj smd_adj ks_adj   (all covariates)
#   vr_raw vr_adj                                                 (covariates with
#                                      more than two distinct values only)
# VR is skipped for two-level covariates: cobalt does not report it for them
# and psdash documents it as determined by the SMD.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3L || length(args) %% 2L != 1L) {
    stop("usage: _binary_balance_reference_psdash.R output.csv label input.csv ...")
}
if (!requireNamespace("cobalt", quietly = TRUE)) {
    quit(status = 77L)
}

rows <- list()
add_metric <- function(key, value) {
    value <- as.numeric(value)
    if (length(value) != 1L || !is.finite(value)) {
        stop(sprintf("non-finite cobalt value for %s", key))
    }
    rows[[length(rows) + 1L]] <<- data.frame(
        metric = key,
        value = sprintf("%.17g", value),
        stringsAsFactors = FALSE
    )
}

pairs <- args[-1L]
for (i in seq(1L, length(pairs), by = 2L)) {
    label <- pairs[[i]]
    data <- utils::read.csv(pairs[[i + 1L]], check.names = FALSE)
    covs <- setdiff(names(data), c("treat", "wt"))
    fml <- stats::as.formula(paste("treat ~", paste(covs, collapse = " + ")))
    result <- cobalt::bal.tab(
        fml,
        data = data,
        weights = data$wt,
        s.d.denom = "pooled",
        binary = "std",
        continuous = "std",
        disp.means = TRUE,
        disp.v.ratio = TRUE,
        disp.ks = TRUE,
        un = TRUE
    )
    bal <- result$Balance
    for (v in covs) {
        if (!(v %in% rownames(bal))) stop(sprintf("cobalt row missing for %s", v))
        add_metric(sprintf("%s_%s_mt_raw", label, v), bal[v, "M.1.Un"])
        add_metric(sprintf("%s_%s_mc_raw", label, v), bal[v, "M.0.Un"])
        add_metric(sprintf("%s_%s_smd_raw", label, v), bal[v, "Diff.Un"])
        add_metric(sprintf("%s_%s_ks_raw", label, v), bal[v, "KS.Un"])
        add_metric(sprintf("%s_%s_mt_adj", label, v), bal[v, "M.1.Adj"])
        add_metric(sprintf("%s_%s_mc_adj", label, v), bal[v, "M.0.Adj"])
        add_metric(sprintf("%s_%s_smd_adj", label, v), bal[v, "Diff.Adj"])
        add_metric(sprintf("%s_%s_ks_adj", label, v), bal[v, "KS.Adj"])
        if (length(unique(data[[v]])) > 2L) {
            add_metric(sprintf("%s_%s_vr_raw", label, v), bal[v, "V.Ratio.Un"])
            add_metric(sprintf("%s_%s_vr_adj", label, v), bal[v, "V.Ratio.Adj"])
        }
    }
}

utils::write.csv(do.call(rbind, rows), args[[1L]], row.names = FALSE, quote = FALSE)
