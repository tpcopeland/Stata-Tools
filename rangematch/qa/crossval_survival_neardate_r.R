# crossval_survival_neardate_r.R - R oracle for rangematch nearest-date QA
#
# Reproduces the public example in survival::neardate documentation. The
# companion writes both input tables and independently computed row indices;
# the Stata suite consumes these files and compares row-level matches.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
    stop("usage: Rscript crossval_survival_neardate_r.R OUTDIR")
}

outdir <- args[[1L]]
if (!dir.exists(outdir)) {
    stop("output directory does not exist: ", outdir)
}
if (!requireNamespace("survival", quietly = TRUE)) {
    stop("R package survival is required")
}

# Official survival::neardate example data. Cholesterol is omitted because the
# matching contract depends only on subject identifiers and observation dates.
index <- data.frame(
    master_id = seq_len(10L),
    id = seq_len(10L),
    event_date = as.Date(sprintf("2011-%d-05", seq_len(10L)))
)

ref_month <- c(1, 4, 5, 1, 3, 6, 9, 2, 7, 8, 12, 4, 6, 7, 10, 12, 3)
reference <- data.frame(
    using_id = seq_along(ref_month),
    id = c(1, 1, 1, 2, 2, 4, 4, 5, 5, 5, 6, 8, 8, 9, 10, 10, 12),
    event_date = as.Date(sprintf("2011-%d-01", ref_month))
)

after <- survival::neardate(
    index$id, reference$id, index$event_date, reference$event_date,
    best = "after"
)
prior <- survival::neardate(
    index$id, reference$id, index$event_date, reference$event_date,
    best = "prior"
)
prior21 <- prior
too_old <- !is.na(prior21) &
    as.numeric(index$event_date - reference$event_date[prior21]) > 21
prior21[too_old] <- NA_integer_

expected <- data.frame(
    master_id = index$master_id,
    after_using_id = after,
    prior_using_id = prior,
    prior21_using_id = prior21
)

write.csv(index, file.path(outdir, "neardate_master.csv"), row.names = FALSE,
          na = "")
write.csv(reference, file.path(outdir, "neardate_using.csv"), row.names = FALSE,
          na = "")
write.csv(expected, file.path(outdir, "neardate_expected.csv"), row.names = FALSE,
          na = "")
writeLines("ok", file.path(outdir, "R_OK"))
