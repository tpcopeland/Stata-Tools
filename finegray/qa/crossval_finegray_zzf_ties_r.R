#!/usr/bin/env Rscript
#
# crossval_finegray_zzf_ties_r.R -- oracle side of the TIED delayed-entry
# cross-validation (crossval_finegray_zzf_ties.do).
#
# WHY THIS FILE EXISTS.  Bellach et al. (2020) prove the product form
# G(t-)H(t-) and Zhang, Zhang and Fine's b(t)/S(t-) equivalent for CONTINUOUS
# failure times only.  At ties they agree only under one tie ordering (Geskus
# 2011, p.40: events, then censorings, then entries), and through finegray
# 1.3.4 the engine's censoring product-limit used another.  The R-only Gate
# Z-ties in crossval_finegray_zzf_r.R showed that survival::finegray follows
# the ordering; nothing ever compared the STATA engine on tied data, and the
# 2026-09-13 clarity audit found it 1.2e-3 off the published coefficient on a
# fixture with five event/censoring collisions.  This oracle is the missing
# half: Stata builds fixtures whose entry, event and censoring times collide in
# every class, and this script returns the published-weight answer for each.
#
# THE REFERENCE.  zzf_fit / zzf_weights from the frozen crossval_finegray_zzf_r.R
# construct ZZF's canonical b_g(t)/S_g(t-) directly -- no censoring product
# limit, no entry product limit, no tie convention to choose -- so they are
# independent of the thing under test.  Coefficients are reported from
# coxph(ties = "breslow") run on that weight matrix (a Newton fitter at its
# fixed point, like the engine, rather than optim's ~3e-7 BFGS floor), and the
# log pseudo-likelihood and Breslow baseline are evaluated at that
# coefficient.  On the pooled fixtures survival::finegray + coxph is reported
# as well: reference software, a second opinion on the same target.
#
# Usage (from finegray/qa, via the .do file):
#   Rscript crossval_finegray_zzf_ties_r.R <input_csv> <output_csv> <baseline_csv>
#
# input_csv:    fixture,id,g,L,X,status,z1,z2   (written by Stata)
# output_csv:   fixture,spec,quantity,variable,value
#               quantity codes: b (coef), bs (coef via survival::finegray),
#               sn (NaN weights survival::finegray produced), ll, mw (largest
#               retained weight), nc (retained cells);
#               variable is z1/z2 or a (whole fit) -- short so the Stata
#               side can key locals on fixture_spec_quantity_variable
# baseline_csv: fixture,spec,time,Lambda0

suppressPackageStartupMessages(library(survival))

.fg_banner <- function(pkgs) {
    cat(sprintf("R_ENV: script=%s R=%s platform=%s\n",
                "crossval_finegray_zzf_ties_r.R", as.character(getRversion()),
                R.version$platform))
    for (p in pkgs) {
        v <- tryCatch(as.character(utils::packageVersion(p)),
                      error = function(e) "NOT-INSTALLED")
        cat(sprintf("R_ENV: package %s = %s\n", p, v))
    }
}
.fg_banner(c("survival"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3)
    stop("Usage: Rscript crossval_finegray_zzf_ties_r.R <input_csv> <output_csv> <baseline_csv>")
input_file    <- args[1]
output_file   <- args[2]
baseline_file <- args[3]

qa_dir <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
ORACLE <- file.path(qa_dir, "crossval_finegray_zzf_r.R")
if (!file.exists(ORACLE)) stop("cannot find ", ORACLE)

# Frozen-reference contract: keyed on this script, the canonical oracle it
# sources, and the fixture CSV.  A miss without FG_ORACLE_REFRESH=1 is an
# error, never a silent refit (see _fg_oracle_cache.R).
source(file.path(qa_dir, "_fg_oracle_cache.R"))
.fgc <- fg_oracle_cache_begin("finegray_zzf_ties",
                              outputs = c(output_file, baseline_file),
                              key_files = c(input_file, ORACLE),
                              packages = c("survival"))
if (identical(.fgc$state, "hit")) quit(save = "no", status = 0)

# Load ONLY the function and constant definitions out of the canonical oracle,
# never its fixture-writing body (same loader as crossval_finegray_zzf_beta_r.R).
local({
    exprs <- parse(ORACLE)
    for (e in exprs) {
        if (!is.call(e) || !identical(e[[1]], as.name("<-"))) next
        nm <- e[[2]]; rhs <- e[[3]]
        is_fun   <- is.call(rhs) && identical(rhs[[1]], as.name("function"))
        is_const <- is.name(nm) && grepl("^[A-Z0-9_]+$", as.character(nm))
        if (is_fun || is_const) eval(e, envir = globalenv())
    }
})
stopifnot(is.function(zzf_weights), is.function(zzf_fit_weights),
          is.function(coxph_on_our_weights))

df <- read.csv(input_file, stringsAsFactors = FALSE)
stopifnot(all(c("fixture", "id", "g", "L", "X", "status", "z1", "z2") %in% names(df)))
zvars <- c("z1", "z2")

results <- list()
add <- function(fx, spec, qty, var, val) {
    results[[length(results) + 1L]] <<- data.frame(
        fixture = fx, spec = spec, quantity = qty, variable = var, value = val,
        stringsAsFactors = FALSE)
}
baselines <- list()

# Every fixture is fitted twice: pooled weight (wgroup constant) and, when it
# carries two groups, the ZZF eq. (6) stratified weight (pooled stabilizer,
# stratum-specific denominator; stabilizer = "pooled" in zzf_weights).
for (fx in unique(df$fixture)) {
    d0 <- df[df$fixture == fx, , drop = FALSE]
    d0 <- d0[order(d0$id), ]
    stopifnot(all(d0$L < d0$X))
    specs <- list(pooled = rep(0L, nrow(d0)))
    if (length(unique(d0$g)) > 1) specs$strata <- as.integer(d0$g)
    for (spec in names(specs)) {
        d <- d0
        d$wgroup <- specs[[spec]]
        ww <- zzf_weights(d, cause = 1L, stabilizer = "pooled")
        beta <- coxph_on_our_weights(d, ww, zvars)
        # log pseudo-likelihood and Breslow baseline AT the coxph coefficient
        Z <- as.matrix(d[, zvars, drop = FALSE])
        ee <- as.vector(exp(Z %*% beta))
        S0 <- colSums(ww$W * ee)
        evrow <- lapply(ww$et, function(t) which(d$X == t & d$status == 1L))
        ll <- 0
        for (k in seq_along(ww$et))
            for (i in evrow[[k]]) ll <- ll + ww$W[i, k] * (sum(Z[i, ] * beta) - log(S0[k]))
        dL <- vapply(seq_along(ww$et), function(k) sum(ww$W[evrow[[k]], k]) / S0[k], numeric(1))
        comp <- outer(d$X, ww$et, "<") & (d$status == 2L)
        for (j in seq_along(zvars)) add(fx, spec, "b", zvars[j], unname(beta[j]))
        add(fx, spec, "ll", "a", ll)
        add(fx, spec, "mw", "a",
            if (any(comp)) max(ww$W[comp]) else NA_real_)
        add(fx, spec, "nc", "a", sum(comp & ww$W > 0))
        baselines[[length(baselines) + 1L]] <- data.frame(
            fixture = fx, spec = spec, time = ww$et, Lambda0 = cumsum(dL),
            stringsAsFactors = FALSE)

        if (spec == "pooled") {
            # reference software on the same target
            x <- d
            x$ev <- factor(x$status, 0:2, labels = c("censor", "cause1", "cause2"))
            fg <- survival::finegray(Surv(L, X, ev) ~ ., data = x, etype = "cause1", id = id)
            stopifnot("id" %in% names(fg))
            # Across an observation gap survival::finegray's own product-limit
            # collapses (0/0) and it returns NaN weights, which coxph then drops
            # silently -- on the gap_pooled fixture 1918 of 2518 expanded rows.
            # Its coefficient is then not a reference for anything; the count
            # goes out as "sn" so the Stata side can refuse to compare against
            # it and say why.  The canonical b/S form is finite there and IS the
            # target (Zhang, Zhang and Fine 2011; He and Yang 1998, Thm 2.2).
            add(fx, spec, "sn", "a", sum(is.na(fg$fgwt)))
            bsf <- coef(coxph(Surv(fgstart, fgstop, fgstatus) ~ z1 + z2, weights = fgwt,
                              data = fg, ties = "breslow", robust = FALSE))
            for (j in seq_along(zvars)) add(fx, spec, "bs", zvars[j], unname(bsf[j]))
        }
        cat(sprintf("  %-18s %-7s beta = %s\n", fx, spec,
                    paste(sprintf("%.12f", beta), collapse = " ")))
    }
}

out <- do.call(rbind, results)
write.csv(out, file = output_file, row.names = FALSE)
bl <- do.call(rbind, baselines)
write.csv(bl, file = baseline_file, row.names = FALSE)
fg_oracle_cache_end(.fgc)
cat(sprintf("wrote %d result rows and %d baseline rows\n", nrow(out), nrow(bl)))
