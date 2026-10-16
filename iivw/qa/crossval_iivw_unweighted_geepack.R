#!/usr/bin/env Rscript
# crossval_iivw_unweighted_geepack.R
#
# Reference for `iivw_fit, unweighted`: geepack::geeglm with an independence
# working correlation and the sandwich ("san.se") variance, fitted to datasets
# that the Stata suite exports. Usage: --indir=<dir with ds_*.csv> --outdir=<dir>
#   --versions=<csv path>
# Each ds_<name>.csv has columns id, t, x, y, ybin, ycnt. Output: ref_<name>.csv
# with one row per (family, term): family, term, est, se_san, G, N.
suppressPackageStartupMessages(library(geepack))
for (p in c("geepack"))
    cat(sprintf("REFERENCE: %s %s\n", p, as.character(utils::packageVersion(p))))
args <- commandArgs(trailingOnly = TRUE)
get <- function(k) sub(paste0("^--", k, "="), "", grep(paste0("^--", k, "="), args, value = TRUE)[1])
indir <- get("indir"); outdir <- get("outdir"); vers <- get("versions")

fams <- list(gaussian = list(f = gaussian(), resp = "y"),
             binomial = list(f = binomial(link = "logit"), resp = "ybin"),
             poisson  = list(f = poisson(link = "log"), resp = "ycnt"))
for (fn in list.files(indir, pattern = "^ds_.*\\.csv$")) {
    nm <- sub("\\.csv$", "", sub("^ds_", "", fn))
    d <- read.csv(file.path(indir, fn))
    d <- d[order(d$id, d$t), ]            # geeglm needs rows grouped by id
    out <- NULL
    for (fam in names(fams)) {
        fit <- geeglm(as.formula(paste(fams[[fam]]$resp, "~ x + t")), id = id,
                      data = d, family = fams[[fam]]$f,
                      corstr = "independence", std.err = "san.se",
                      control = geese.control(epsilon = 1e-10, maxit = 100))
        s <- coef(summary(fit))
        out <- rbind(out, data.frame(family = fam, term = rownames(s),
            est = s[, "Estimate"], se_san = s[, "Std.err"],
            G = length(unique(d$id)), N = nrow(d)))
    }
    write.csv(out, file.path(outdir, paste0("ref_", nm, ".csv")), row.names = FALSE)
}
vr <- data.frame(package = c("R", "geepack"),
                 version = c(paste(R.version$major, R.version$minor, sep = "."),
                             as.character(utils::packageVersion("geepack"))))
write.csv(vr, vers, row.names = FALSE, quote = TRUE)
cat("done\n")
