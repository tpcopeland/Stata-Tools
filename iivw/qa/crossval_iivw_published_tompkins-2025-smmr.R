#!/usr/bin/env Rscript
# crossval_iivw_published_tompkins-2025-smmr.R
#
# Reference implementation for crossval_iivw_published_tompkins-2025-smmr.do:
# the AUTHORS' OWN public simulation DGP and IIW estimator (Tompkins, Dubin,
# Wallace, SMMR 2025), fetched at run time from the commit-pinned URL below and
# checked against a SHA-256 before it is executed. Simulation II of the paper
# (continuous outcome, time-invariant treatment, randomized, tau = 7).
#
#   args: --outdir=PATH --reps=R --n=N
# Writes under outdir: auth_v_<r>.csv (visit rows), auth_s_<r>.csv (subjects),
# auth_res.csv (authors' beta1 for Naive / D / Z / D+Z), auth_versions.csv,
# auth.ok (sentinel, last).

suppressPackageStartupMessages({
    library(dplyr)
    library(survival)
    library(geepack)
})

url <- "https://raw.githubusercontent.com/grcetmpk/FIPTIW/f46e49328cbbc2a749a62f665fd7c2abb95103d4/FIPTIW_timevarW_functions.R"
want <- "63ffb447ff56bc22b4068bce7828036dd78423a918e58412823aaf2bd5c8c7b8"
cat(sprintf("REFERENCE: %s fetched %s\n", url, format(Sys.Date(), "%Y-%m-%d")))
for (p in c("survival", "geepack", "dplyr"))
    cat(sprintf("REFERENCE: %s %s\n", p, as.character(utils::packageVersion(p))))

args <- commandArgs(trailingOnly = TRUE)
get <- function(k) sub(paste0("^--", k, "="), "", grep(paste0("^--", k, "="), args, value = TRUE))
outdir <- get("outdir"); R <- as.integer(get("reps")); n <- as.integer(get("n"))
stopifnot(length(outdir) == 1, dir.exists(outdir), !is.na(R), !is.na(n))

src <- file.path(outdir, "FIPTIW_timevarW_functions.R")
status <- utils::download.file(url, src, quiet = TRUE, mode = "wb")
stopifnot(status == 0)
got <- digest_sha256 <- tryCatch(
    system2("sha256sum", src, stdout = TRUE), error = function(e) stop("sha256sum missing"))
got <- strsplit(got, " ")[[1]][1]
if (got != want) stop(sprintf("fetched file SHA-256 %s != pinned %s", got, want))

# Only the data generator is needed: from `expit` to the end of
# gendata_FIPTIW_continuous (lines 40-258 of the pinned file).
lines <- readLines(src)
stopifnot(startsWith(lines[40], "expit <- function"),
          startsWith(lines[259], "gendata_FIPTIW_binary <- function"))
eval(parse(text = lines[40:258]))

set.seed(20261015)
res <- NULL
for (r in seq_len(R)) {
    sd <- gendata_FIPTIW_continuous(n, 0.5, 0, 1, 0.5, 0, 0.6, 0, 0, 7,
                                    censinform = FALSE)$simdata
    obs <- sd %>% filter(!is.na(y))
    # authors' Simulation II estimator (simulateOneVarSel): stabilized IIW from a
    # Cox model on the full 0.01 grid, independent GEE with offset 2 - t
    delta <- coxph(Surv(time.lag, time, observed) ~ D - 1, data = sd)$coef
    fit1 <- function(cols) {
        f <- as.formula(paste("Surv(time.lag, time, observed) ~", paste(cols, collapse = " + "), "- 1"))
        g <- coxph(f, data = sd)$coef
        w <- exp(cbind(obs$D) %*% delta) / exp(as.matrix(obs[, cols, drop = FALSE]) %*% g)
        m <- geeglm(y ~ D + offset(2 - time) - 1, data = obs, family = gaussian,
                    id = id, weights = as.numeric(w))
        unname(coef(m)[1])
    }
    b_naive <- unname(coef(geeglm(y ~ D + offset(2 - time) - 1, data = obs,
                                  family = gaussian, id = id))[1])
    res <- rbind(res, data.frame(rep = r, b_naive = b_naive, b_D = fit1("D"),
                                 b_Z = fit1("Z"), b_DZ = fit1(c("D", "Z"))))
    write.csv(data.frame(rep = r, id = obs$id, t = obs$time, D = obs$D, Z = obs$Z,
                         y = obs$y, C = obs$censortime),
              file.path(outdir, sprintf("auth_v_%d.csv", r)), row.names = FALSE)
    subj <- sd %>% group_by(id) %>%
        summarise(D = first(D), Z = first(Z), C = first(censortime), .groups = "drop")
    write.csv(subj, file.path(outdir, sprintf("auth_s_%d.csv", r)), row.names = FALSE)
}
write.csv(res, file.path(outdir, "auth_res.csv"), row.names = FALSE)
write.csv(data.frame(item = c("R", "survival", "geepack", "dplyr", "funcs_sha256"),
                     version = c(as.character(getRversion()),
                                 as.character(packageVersion("survival")),
                                 as.character(packageVersion("geepack")),
                                 as.character(packageVersion("dplyr")), want)),
          file.path(outdir, "auth_versions.csv"), row.names = FALSE)
writeLines("ok", file.path(outdir, "auth.ok"))
