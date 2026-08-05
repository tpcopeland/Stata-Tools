#!/usr/bin/env Rscript

# oracle_fml_totalerror.R -- author-reference oracle for qba_misclass, totalerror
#
# Transcribes the reference algorithms published by the authors of
#   Fox MP, MacLehose RF, Lash TL. SAS and R code for probabilistic
#   quantitative bias analysis for misclassified binary variables and binary
#   unmeasured confounders. Int J Epidemiol. 2023;52(5):1624-1633.
# from their "Short code" page:
#   - "exposure misclass summary 2025_01_05.R"  (pba.summary.exp.rr)
#   - "outcome misclass summary CASE CONTROL 2023_01_25.R"
#       (pba.summary.dis.cactrl)
# with the dplyr filter chain rewritten in base R and the systematic-error arm
# added to the case-control function (the published version returns only the
# total-error arm). Nothing else is changed: the draws, the predictive-value
# and binomial reallocation steps, the bias-adjusted standard errors, and the
# nonpositive-cell exclusion are as published.
#
# This is an INDEPENDENT implementation of the method, not a wrapper around
# qba: it shares no code and no nuisance parameter with the package.
#
# Base R only. Usage: oracle_fml_totalerror.R <output_csv> [seed] [sims] [sentinel]

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
    stop("usage: oracle_fml_totalerror.R <output_csv> [seed] [sims]", call. = FALSE)
}
out_csv <- args[1]
seed <- if (length(args) >= 2) as.integer(args[2]) else 20260726L
sims <- if (length(args) >= 3) as.numeric(args[3]) else 1e6
sentinel <- if (length(args) >= 4) args[4] else ""
set.seed(seed)

rows <- data.frame(name = character(), value = numeric())
put <- function(name, value) {
    rows <<- rbind(rows, data.frame(name = name, value = as.numeric(value)))
}
put_q <- function(prefix, x) {
    q <- quantile(x, c(0.025, 0.5, 0.975))
    put(paste0(prefix, "_p025"), q[1])
    put(paste0(prefix, "_p50"), q[2])
    put(paste0(prefix, "_p975"), q[3])
}

# Exposure misclassification, nondifferential, risk ratio.
# pba.summary.exp.rr with type = "nondiff".
pba_exp_rr <- function(a, b, c, d, se.a, se.b, sp.a, sp.b, niter) {
    n_case <- a + b
    n_ctrl <- c + d

    se1 <- rbeta(niter, se.a, se.b)
    se0 <- se1
    sp1 <- rbeta(niter, sp.a, sp.b)
    sp0 <- sp1

    ac <- (a - n_case * (1 - sp1)) / (se1 - (1 - sp1))
    bc <- n_case - ac
    cc <- (c - n_ctrl * (1 - sp0)) / (se0 - (1 - sp0))
    dc <- n_ctrl - cc

    PrevE_cases <- rbeta(niter, ac, bc)
    PrevE_controls <- rbeta(niter, cc, dc)

    PPV_case <- (se1 * PrevE_cases) /
        ((se1 * PrevE_cases) + (1 - sp1) * (1 - PrevE_cases))
    PPV_control <- (se0 * PrevE_controls) /
        ((se0 * PrevE_controls) + (1 - sp0) * (1 - PrevE_controls))
    NPV_case <- (sp1 * (1 - PrevE_cases)) /
        ((1 - se1) * PrevE_cases + sp1 * (1 - PrevE_cases))
    NPV_control <- (sp0 * (1 - PrevE_controls)) /
        ((1 - se0) * PrevE_controls + sp0 * (1 - PrevE_controls))

    ab <- rbinom(niter, a, PPV_case) + rbinom(niter, b, 1 - NPV_case)
    bb <- n_case - ab
    cb <- rbinom(niter, c, PPV_control) + rbinom(niter, d, 1 - NPV_control)
    db <- n_ctrl - cb

    rr_bb <- (ab / (ab + cb)) / (bb / (bb + db))
    se_bb <- sqrt(1 / ab + 1 / bb - 1 / (ab + cb) - 1 / (bb + db))
    z <- rnorm(niter)
    rr_bb_cb <- exp(log(rr_bb) - (z * se_bb))

    se_re_only <- sqrt(1 / a + 1 / b - 1 / (a + c) - 1 / (b + d))
    z <- rnorm(niter)
    rr_re_only <- exp(log((a / (a + c)) / (b / (b + d))) - z * se_re_only)

    rr_syst <- (ac / (ac + cc)) / (bc / (bc + dc))

    keep <- ac > 0 & bc > 0 & cc > 0 & dc > 0 &
        ab > 0 & bb > 0 & cb > 0 & db > 0
    keep[is.na(keep)] <- FALSE

    list(total = rr_bb_cb[keep], syst = rr_syst[keep], re = rr_re_only,
         impossible = niter - sum(keep))
}

# Outcome misclassification in a case-control study, odds ratio.
# pba.summary.dis.cactrl, plus the systematic-error arm.
pba_out_cc <- function(a, b, c, d, se.a, se.b, sp.min, sp.max,
                       fcase, fctrl, niter) {
    a <- a / fcase
    b <- b / fcase
    c <- c / fctrl
    d <- d / fctrl

    n_exp <- a + c
    n_unexp <- b + d

    se1 <- rbeta(niter, se.a, se.b)
    se0 <- se1
    sp1 <- runif(niter, sp.min, sp.max)
    sp0 <- sp1

    ac <- (a - n_exp * (1 - sp1)) / (se1 - (1 - sp1))
    cc <- n_exp - ac
    bc <- (b - n_unexp * (1 - sp0)) / (se0 - (1 - sp0))
    dc <- n_unexp - bc

    PrevE_d <- rbeta(niter, ac, cc)
    PrevUE_d <- rbeta(niter, bc, dc)

    PPV_exp <- (se1 * PrevE_d) / ((se1 * PrevE_d) + (1 - sp1) * (1 - PrevE_d))
    PPV_unexp <- (se0 * PrevUE_d) /
        ((se0 * PrevUE_d) + (1 - sp0) * (1 - PrevUE_d))
    NPV_exp <- (sp1 * (1 - PrevE_d)) /
        ((1 - se1) * PrevE_d + sp1 * (1 - PrevE_d))
    NPV_unexp <- (sp0 * (1 - PrevUE_d)) /
        ((1 - se0) * PrevUE_d + sp0 * (1 - PrevUE_d))

    ab <- rbinom(niter, a, PPV_exp) + rbinom(niter, c, 1 - NPV_exp)
    cb <- n_exp - ab
    bb <- rbinom(niter, b, PPV_unexp) + rbinom(niter, d, 1 - NPV_unexp)
    db <- n_unexp - bb

    or_bb <- (ab * db) / (cb * bb)
    se_bb <- sqrt(1 / ab + 1 / bb + 1 / cb + 1 / db)
    z <- rnorm(niter)
    or_bb_cb <- exp(log(or_bb) - (z * se_bb))

    or_syst <- (ac * dc) / (bc * cc)

    keep <- ac > 0 & bc > 0 & cc > 0 & dc > 0 &
        ab > 0 & bb > 0 & cb > 0 & db > 0
    keep[is.na(keep)] <- FALSE

    list(total = or_bb_cb[keep], syst = or_syst[keep],
         impossible = niter - sum(keep),
         adj_a = a, adj_b = b, adj_c = c, adj_d = d)
}

# Case 1: the authors' worked exposure-misclassification summary example.
e <- pba_exp_rr(a = 215, b = 1449, c = 668, d = 4296,
                se.a = 50.6, se.b = 14.3, sp.a = 70, sp.b = 1, niter = sims)
put_q("exp_syst", e$syst)
put_q("exp_total", e$total)
put_q("exp_re", e$re)
put("exp_impossible_frac", e$impossible / sims)

# Case 2: the authors' worked case-control outcome-misclassification example.
o <- pba_out_cc(a = 387, b = 1642, c = 685, d = 3365,
                se.a = 35, se.b = 3, sp.min = .96, sp.max = 1,
                fcase = 1, fctrl = .1, niter = sims)
put_q("cc_syst", o$syst)
put_q("cc_total", o$total)
put("cc_impossible_frac", o$impossible / sims)
put("cc_adj_a", o$adj_a)
put("cc_adj_b", o$adj_b)
put("cc_adj_c", o$adj_c)
put("cc_adj_d", o$adj_d)

write.csv(rows, file = out_csv, row.names = FALSE)
if (nzchar(sentinel)) {
    writeLines("ok", sentinel)
}
