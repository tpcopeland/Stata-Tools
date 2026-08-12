#!/usr/bin/env Rscript

# pygrid cross-validation companion
# Author: Timothy P Copeland, Karolinska Institutet
# Purpose: Generate independent interval splits with survival::survSplit.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
    stop("usage: crossval_pygrid.R input.csv output.csv")
}

if (!requireNamespace("survival", quietly = TRUE)) {
    stop("R package survival is required")
}
suppressPackageStartupMessages(library(survival))

source <- utils::read.csv(args[[1]], stringsAsFactors = FALSE)
source$stop_plus <- source$window_end + 1
source$status <- 1L

split <- survSplit(
    Surv(window_start, stop_plus, status) ~ id,
    data = source,
    cut = c(18628, 18993, 19359),
    start = "period_start",
    end = "stop_plus",
    episode = "episode"
)

result <- data.frame(
    id = split$id,
    period = as.integer(format(as.Date(split$period_start, origin = "1960-01-01"), "%Y")),
    period_start = split$period_start,
    period_stop = split$stop_plus - 1,
    person_days = split$stop_plus - split$period_start
)
result <- result[order(result$id, result$period_start), ]
utils::write.csv(result, args[[2]], row.names = FALSE, quote = FALSE)
