#!/usr/bin/env Rscript
# crossval_iivw_iptw_oracle.R
# -----------------------------------------------------------------------------
# Independent oracle for the STABILIZED ATE IPTW weight (METHOD_ORACLE_MAP #4).
#
# This is deliberately a *direct* reconstruction of the estimand from base-R
# glm(), not a call into a weighting package, so the comparison shares no code
# and no semantics with iivw. It reproduces exactly the contract implemented in
# iivw_weight.ado (stabilized IPTW, one row per subject):
#
#   logit A ~ treat_cov               (MLE, one row per subject)
#   ps      = fitted Pr(A=1 | L)
#   p_treat = mean(A) over the treatment model's own estimation sample
#   tw      = p_treat / ps                if A == 1
#           = (1 - p_treat) / (1 - ps)    if A == 0
#   weighted treatment coef = coef of A in glm(y ~ A, weights = tw)
#
# Reads : iptw_oracle_data.csv  (id, A, L1, L2, y)  written by the .do file
# Writes: iptw_oracle_R.csv     (id, ps, tw)                 -- per subject
#         iptw_oracle_R_coefs.csv (term, value)              -- scalars/coefs
#
# Class-P tolerances (TOLERANCE_FRAMEWORK.md): nuisance coef/weight 1e-6,
# outcome coef 1e-5. R and Stata are independent optimisers, so this is parity,
# not replay.
# -----------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
qa_dir <- if (length(args) >= 1) args[1] else "."

infile <- file.path(qa_dir, "iptw_oracle_data.csv")
if (!file.exists(infile)) stop(paste("input not found:", infile))
d <- read.csv(infile)

# --- treatment model: logit A ~ L1 + L2, one row per subject ------------------
tm <- glm(A ~ L1 + L2, family = binomial(link = "logit"), data = d)
ps <- as.numeric(predict(tm, type = "response"))

# --- stabilization numerator: marginal prevalence over the model's sample -----
p_treat <- mean(d$A)

# --- stabilized IPTW weights --------------------------------------------------
tw <- ifelse(d$A == 1, p_treat / ps, (1 - p_treat) / (1 - ps))

# --- weighted treatment coefficient (marginal structural mean) ----------------
om <- glm(y ~ A, data = d, weights = tw)

# --- write per-subject weights ------------------------------------------------
write.csv(data.frame(id = d$id, ps = ps, tw = tw),
          file = file.path(qa_dir, "iptw_oracle_R.csv"),
          row.names = FALSE)

# --- write scalars/coefs ------------------------------------------------------
cf <- coef(tm)
oc <- coef(om)
coefs <- data.frame(
  term  = c("tm_cons", "tm_L1", "tm_L2", "p_treat", "wcoef_cons", "wcoef_A", "n"),
  value = c(cf[["(Intercept)"]], cf[["L1"]], cf[["L2"]], p_treat,
            oc[["(Intercept)"]], oc[["A"]], nrow(d))
)
write.csv(coefs, file = file.path(qa_dir, "iptw_oracle_R_coefs.csv"),
          row.names = FALSE)

cat("crossval_iivw_iptw_oracle.R: wrote", nrow(d), "rows;",
    "tm_A_L1=", round(cf[["L1"]], 6), " p_treat=", round(p_treat, 6),
    " wcoef_A=", round(oc[["A"]], 6), "\n")
