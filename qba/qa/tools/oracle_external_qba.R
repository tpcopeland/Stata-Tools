#!/usr/bin/env Rscript

# oracle_external_qba.R -- external episensr oracle for qba cross-validation
#
# Sources are examples documented in episensr 2.1.0 help/vignettes:
# - misclass(): Fink and Lash 2003 smoking/pregnancy and breast cancer;
#   AMI death and sex outcome-misclassification example.
# - selection(): Stang et al. 2006 uveal melanoma/mobile phone example.
# - confounders(): Tyndall et al. 1996 HIV/circumcision example.
# - confounders_evalue(): Victoria et al. 1987 breast-feeding RR example.
# - vignette "Multiple Bias Modeling": Chien et al. antidepressant use and
#   breast cancer, chained through misclass(), selection(), confounders().

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
    stop("usage: oracle_external_qba.R <output_csv>", call. = FALSE)
}

suppressPackageStartupMessages(library(episensr))

rows <- data.frame(name = character(), value = numeric())

put <- function(name, value) {
    rows <<- rbind(rows, data.frame(name = name, value = as.numeric(value)))
}

put_cells <- function(prefix, mat) {
    put(paste0(prefix, "_a"), mat[1, 1])
    put(paste0(prefix, "_b"), mat[1, 2])
    put(paste0(prefix, "_c"), mat[2, 1])
    put(paste0(prefix, "_d"), mat[2, 2])
}

# Misclassification, exposure: Fink and Lash example from episensr::misclass().
mis_fink <- misclass(
    matrix(c(215, 1449, 668, 4296), nrow = 2, byrow = TRUE),
    type = "exposure",
    bias_parms = c(.78, .78, .99, .99)
)
put_cells("mis_fink", mis_fink$corr_data)
put("mis_fink_rr", mis_fink$adj_measures[1, 1])
put("mis_fink_or", mis_fink$adj_measures[2, 1])

# Misclassification, outcome: AMI death/sex example from episensr::misclass().
mis_ami <- misclass(
    matrix(c(4558, 3428, 46305, 46085), nrow = 2, byrow = TRUE),
    type = "outcome",
    bias_parms = c(.53, .53, .99, .99)
)
put_cells("mis_ami", mis_ami$corr_data)
put("mis_ami_rr", mis_ami$adj_measures[1, 1])
put("mis_ami_or", mis_ami$adj_measures[2, 1])

# Selection: Stang et al. uveal melanoma/mobile phone example.
sel_stang <- selection(
    matrix(c(136, 107, 297, 165), nrow = 2, byrow = TRUE),
    bias_parms = c(.94, .85, .64, .25)
)
put_cells("sel_stang", sel_stang$corr_data)
put("sel_stang_rr", sel_stang$adj_measures[1, 1])
put("sel_stang_or", sel_stang$adj_measures[2, 1])
put("sel_stang_bf", sel_stang$selbias_or)

# Unmeasured confounding: Tyndall HIV/circumcision example.
conf_tyndall <- confounders(
    matrix(c(105, 85, 527, 93), nrow = 2, byrow = TRUE),
    type = "RR",
    bias_parms = c(.63, .8, .05)
)
put("conf_tyndall_observed_rr", conf_tyndall$obs_measures[1, 1])
put("conf_tyndall_corrected_rr", conf_tyndall$adj_measures[1, 1])
put("conf_tyndall_bf", conf_tyndall$adj_measures[1, 2])

# E-value: Victoria et al. breast-feeding RR example.
eval_victoria <- confounders_evalue(est = 3.9, type = "RR")
put("evalue_victoria_point", eval_victoria[2, 1])

# Multi-bias chain: Chien antidepressant/breast cancer example from the
# episensr "Multiple Bias Modeling" vignette.
chien <- matrix(c(118, 832, 103, 884), nrow = 2, byrow = TRUE)
multi_mis <- misclass(
    chien,
    type = "exposure",
    bias_parms = c(24 / (24 + 19), 18 / (18 + 13),
                   144 / (144 + 2), 130 / (130 + 4))
)
multi_sel <- selection(
    multi_mis$corr_data,
    bias_parms = c(.734, .605, .816, .756)
)
multi_conf <- confounders(
    multi_sel$corr_data,
    type = "OR",
    bias_parms = c(.8, .299, .436)
)
put_cells("multi_chien_after_misclass", multi_mis$corr_data)
put_cells("multi_chien_after_selection", multi_sel$corr_data)
put("multi_chien_selection_or", multi_sel$adj_measures[2, 1])
put("multi_chien_final_or", multi_conf$adj_measures[1, 1])
put("multi_chien_bf", multi_conf$adj_measures[1, 2])

write.csv(rows, args[1], row.names = FALSE)
