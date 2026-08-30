#!/usr/bin/env Rscript
#
# crossval_public_studies_r.R
# Regenerate public-study fixtures and crrSC::crrs reference results.
#
# Sources:
#   Zhou et al. (2011), Biometrics 67:661-670, section 7
#   crrSC 1.1.2 datasets bce and center
#
# Usage:
#   Rscript crossval_public_studies_r.R <data_csv> <oracle_csv>

suppressPackageStartupMessages(library(crrSC))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
    stop("usage: crossval_public_studies_r.R <data_csv> <oracle_csv>")
}
data_file <- args[1L]
oracle_file <- args[2L]

data(bce, package = "crrSC")
data(center, package = "crrSC")

bce_x <- data.frame(
    dataset = "bce",
    time = bce$time,
    status = bce$type,
    stratum = bce$trt,
    x1 = log(bce$nnodes),
    x2 = bce$tsize,
    x3 = bce$age
)
center_x <- data.frame(
    dataset = "center",
    time = center$ftime,
    status = center$fstatus,
    stratum = center$id,
    x1 = center$fm,
    x2 = center$cells,
    x3 = NA_real_
)
study_data <- rbind(bce_x, center_x)

fit_bce_1 <- crrs(
    ftime = bce_x$time,
    fstatus = bce_x$status,
    cov1 = as.matrix(bce_x[, c("x1", "x2", "x3")]),
    strata = bce_x$stratum,
    ctype = 1L
)
fit_bce_2 <- crrs(
    ftime = bce_x$time,
    fstatus = bce_x$status,
    cov1 = as.matrix(bce_x[, c("x1", "x2", "x3")]),
    strata = bce_x$stratum,
    ctype = 2L
)
fit_center_2 <- crrs(
    ftime = center_x$time,
    fstatus = center_x$status,
    cov1 = as.matrix(center_x[, c("x1", "x2")]),
    strata = center_x$stratum,
    ctype = 2L
)
fit_center_cluster <- crrc(
    ftime = center_x$time,
    fstatus = center_x$status,
    cov1 = as.matrix(center_x[, c("x1", "x2")]),
    cluster = center_x$stratum
)

fits <- list(
    bce_1 = list(dataset = "bce", ctype = 1L, fit = fit_bce_1,
                 vars = c("x1", "x2", "x3"), data = bce_x),
    bce_2 = list(dataset = "bce", ctype = 2L, fit = fit_bce_2,
                 vars = c("x1", "x2", "x3"), data = bce_x),
    center_2 = list(dataset = "center", ctype = 2L, fit = fit_center_2,
                    vars = c("x1", "x2"), data = center_x),
    center_cluster = list(dataset = "center", ctype = 3L,
                          fit = fit_center_cluster,
                          vars = c("x1", "x2"), data = center_x)
)

rows <- list()
add <- function(dataset, ctype, quantity, row, col, value) {
    rows[[length(rows) + 1L]] <<- data.frame(
        dataset = dataset,
        ctype = ctype,
        quantity = quantity,
        row = row,
        col = col,
        value = as.numeric(value),
        stringsAsFactors = FALSE
    )
}

for (item in fits) {
    f <- item$fit
    d <- item$data
    if (!isTRUE(f$converged) || any(!is.finite(f$coef))) {
        stop(sprintf("crrs failed for %s ctype=%d", item$dataset, item$ctype))
    }
    for (j in seq_along(item$vars)) {
        add(item$dataset, item$ctype, "coef", item$vars[j], "", f$coef[j])
    }
    if (item$ctype %in% c(1L, 3L)) {
        if (any(!is.finite(f$var)) || any(diag(f$var) <= 0)) {
            stop("crrs returned an invalid regular-strata covariance matrix")
        }
        for (j in seq_along(item$vars)) {
            for (k in seq_along(item$vars)) {
                add(item$dataset, item$ctype, "vcov", item$vars[j],
                    item$vars[k], f$var[j, k])
            }
        }
    }
    used <- complete.cases(d[, c("time", "status", "stratum", item$vars)])
    add(item$dataset, item$ctype, "meta", "n_total", "", nrow(d))
    add(item$dataset, item$ctype, "meta", "n_used", "", sum(used))
    add(item$dataset, item$ctype, "meta", "n_strata", "",
        length(unique(d$stratum[used])))
    add(item$dataset, item$ctype, "meta", "n_fail", "",
        sum(d$status[used] == 1L))
    add(item$dataset, item$ctype, "meta", "n_compete", "",
        sum(d$status[used] == 2L))
    add(item$dataset, item$ctype, "meta", "converged", "", 1)
}

oracle <- do.call(rbind, rows)
write.csv(study_data, data_file, row.names = FALSE, na = "")
write.csv(oracle, oracle_file, row.names = FALSE)
