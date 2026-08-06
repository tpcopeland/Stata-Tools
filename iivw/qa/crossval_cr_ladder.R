# =============================================================================
# crossval_cr_ladder.R - clubSandwich reference for the CR variance ladder
# =============================================================================
# Independent reference for qa/_iivw_cr_ladder.do. Reads a Stata dataset (or a
# CSV) holding
#   y, x, w, id
# fits the same weighted linear model Stata fits (`glm y x [pw=w]' at gaussian
# identity is WLS), and returns the CR0 / CR1 / CR1S / CR2 / CR3 standard errors
# of the coefficient on x under clubSandwich's default target and
# inverse_var = FALSE -- the configuration the Stata transcription claims to
# reproduce.
#
# This is a REFERENCE, not a copy: nothing here is transcribed from the Stata
# side. If the two disagree, the Stata side is wrong.
#
# THE HANDOFF IS BINARY .dta, NOT CSV, AND THAT IS DELIBERATE. The first version
# of this pair went through CSV and the two implementations agreed to only ~3e-9
# -- entirely a text round-trip artifact, since on natively generated data they
# agree to ~5e-16. A tolerance loosened to accommodate that would have been wide
# enough to hide a real error in the CR2 adjustment. Values are written back at
# 17 significant digits for the same reason.
#
# Usage: Rscript crossval_cr_ladder.R <in.dta|in.csv> <out.csv>
# =============================================================================

suppressPackageStartupMessages(library(clubSandwich))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) stop("usage: crossval_cr_ladder.R <in.dta|in.csv> <out.csv>")
infile <- args[1]
outfile <- args[2]

if (grepl("\\.csv$", infile, ignore.case = TRUE)) {
    d <- read.csv(infile)
} else {
    suppressPackageStartupMessages(library(haven))
    d <- as.data.frame(read_dta(infile))
}
for (v in c("y", "x", "w", "id")) {
    if (!v %in% names(d)) stop(paste("input lacks column", v))
    d[[v]] <- as.numeric(d[[v]])
}

fit <- lm(y ~ x, weights = w, data = d)

types <- c("CR0", "CR1", "CR1S", "CR2", "CR3")
se <- vapply(types, function(ty) {
    V <- vcovCR(fit, cluster = d$id, type = ty)
    sqrt(V["x", "x"])
}, numeric(1))

out <- data.frame(
    type = c("b", types),
    value = sprintf("%.17g", c(unname(coef(fit)["x"]), unname(se))),
    stringsAsFactors = FALSE
)

write.csv(out, outfile, row.names = FALSE, quote = FALSE)

cat("clubSandwich", as.character(packageVersion("clubSandwich")),
    " R ", R.version$major, ".", R.version$minor, "\n", sep = "")
cat("nobs=", nrow(d), " nclust=", length(unique(d$id)), "\n", sep = "")
print(out)
