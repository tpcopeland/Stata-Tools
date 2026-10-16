#!/usr/bin/env Rscript
# validation_iivw_exogtest_calibration_holm.R
#
# Reference Holm adjustment for validation_iivw_exogtest_calibration.do.
# Reads --outdir=PATH/holm_in.csv (one row per exogeneity run: kind, id, m, p1..p6,
# with p_k blank beyond m) and writes holm_ref.csv with R's stats::p.adjust(method =
# "holm") applied to each row's m raw p-values, plus min(adjusted).
# Also writes holm_versions.csv and the sentinel holm.ok (written last).
args <- commandArgs(trailingOnly = FALSE)
a <- grep("^--outdir=", args, value = TRUE)
if (length(a) != 1L) stop("requires exactly one --outdir=PATH argument")
outdir <- normalizePath(sub("^--outdir=", "", a), mustWork = TRUE)
cat(sprintf("REFERENCE: stats (R) %s p.adjust\n", as.character(getRversion())))
d <- read.csv(file.path(outdir, "holm_in.csv"), na.strings = c("", "NA", "."))
pc <- paste0("p", 1:6)
adj <- matrix(NA_real_, nrow(d), 6)
mn <- numeric(nrow(d))
for (i in seq_len(nrow(d))) {
    m <- d$m[i]
    p <- unlist(d[i, pc[seq_len(m)]], use.names = FALSE)
    if (anyNA(p)) stop("missing raw p within m on row ", i)
    q <- p.adjust(p, method = "holm")
    adj[i, seq_len(m)] <- q
    mn[i] <- min(q)
}
out <- data.frame(kind = d$kind, id = d$id, m = d$m, a1 = adj[, 1], a2 = adj[, 2],
                  a3 = adj[, 3], a4 = adj[, 4], a5 = adj[, 5], a6 = adj[, 6],
                  r_min_adj = mn)
write.csv(out, file.path(outdir, "holm_ref.csv"), row.names = FALSE, na = "")
write.csv(data.frame(package = "R", version = as.character(getRversion())),
          file.path(outdir, "holm_versions.csv"), row.names = FALSE)
file.create(file.path(outdir, "holm.ok"))
