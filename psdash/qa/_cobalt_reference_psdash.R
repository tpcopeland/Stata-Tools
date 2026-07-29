#!/usr/bin/env Rscript

# Independent balance reference for crossval_cobalt.do.
# cobalt::bal.tab() is the external implementation; this script only reshapes
# its reported balance table into a two-column machine-readable file.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
    stop("usage: _cobalt_reference_psdash.R input.csv output.csv")
}
if (!requireNamespace("cobalt", quietly = TRUE)) {
    quit(status = 77L)
}

data <- utils::read.csv(args[[1L]], check.names = FALSE)
rows <- list()

add_metric <- function(key, value) {
    rows[[length(rows) + 1L]] <<- data.frame(
        metric = key,
        value = sprintf("%.17g", as.numeric(value)),
        stringsAsFactors = FALSE
    )
}

for (comparison in c(1L, 2L)) {
    pair <- data[data$treat %in% c(0L, comparison), , drop = FALSE]
    pair$treat_pair <- as.integer(pair$treat == comparison)
    result <- cobalt::bal.tab(
        treat_pair ~ x1 + x2,
        data = pair,
        weights = pair$wt,
        s.d.denom = "pooled",
        binary = "std",
        continuous = "std",
        disp.v.ratio = TRUE,
        disp.ks = TRUE,
        un = TRUE
    )
    balance <- result$Balance

    for (variable in c("x1", "x2")) {
        add_metric(sprintf("p%d_%s_smd_raw", comparison, variable),
                   balance[variable, "Diff.Un"])
        add_metric(sprintf("p%d_%s_ks_raw", comparison, variable),
                   balance[variable, "KS.Un"])
        add_metric(sprintf("p%d_%s_smd_adj", comparison, variable),
                   balance[variable, "Diff.Adj"])
        add_metric(sprintf("p%d_%s_ks_adj", comparison, variable),
                   balance[variable, "KS.Adj"])
    }
    add_metric(sprintf("p%d_x1_vr_raw", comparison),
               balance["x1", "V.Ratio.Un"])
    add_metric(sprintf("p%d_x1_vr_adj", comparison),
               balance["x1", "V.Ratio.Adj"])
}

utils::write.csv(do.call(rbind, rows), args[[2L]], row.names = FALSE, quote = FALSE)
