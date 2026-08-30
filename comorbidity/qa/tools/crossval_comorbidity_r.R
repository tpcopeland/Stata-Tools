#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) {
    stop("usage: crossval_comorbidity_r.R INPUT.dta OUTPUT.dta")
}

suppressPackageStartupMessages(library(comorbidity))
suppressPackageStartupMessages(library(haven))

expected_comorbidity_version <- package_version("1.1.0")
loaded_comorbidity_version <- packageVersion("comorbidity")
if (loaded_comorbidity_version != expected_comorbidity_version) {
    stop(
        "cross-validation requires R comorbidity 1.1.0; loaded ",
        as.character(loaded_comorbidity_version)
    )
}

input <- read_dta(args[[1]])
code_columns <- grep("^dx[0-9]+$", names(input), value = TRUE)
if (!"pid" %in% names(input) || length(code_columns) == 0) {
    stop("exchange data must contain pid and dx# columns")
}

long <- do.call(
    rbind,
    lapply(code_columns, function(column) {
        data.frame(pid = input$pid, code = input[[column]], stringsAsFactors = FALSE)
    })
)
long <- long[!is.na(long$code) & nzchar(long$code), , drop = FALSE]
if (nrow(long) == 0) {
    stop("exchange data contain no nonmissing diagnosis codes")
}

charlson <- comorbidity(
    long, id = "pid", code = "code", map = "charlson_icd10_quan", assign0 = TRUE
)
elixhauser <- comorbidity(
    long, id = "pid", code = "code", map = "elixhauser_icd10_quan", assign0 = TRUE
)

charlson_names <- c(
    mi = "mi", chf = "chf", pvd = "pvd", cvd = "cevd", dementia = "dementia",
    copd = "cpd", rheumatic = "rheumd", peptic = "pud", liver_mild = "mld",
    dm_uncomp = "diab", dm_comp = "diabwc", hemiplegia = "hp", renal = "rend",
    cancer = "canc", liver_severe = "msld", metastatic = "metacanc", hiv = "aids"
)
elixhauser_names <- c(
    chf = "chf", arrhythmia = "carit", valvular = "valv", pulmonary_circ = "pcd",
    pvd = "pvd", htn_uncomp = "hypunc", htn_comp = "hypc", paralysis = "para",
    neuro_other = "ond", copd = "cpd", dm_uncomp = "diabunc", dm_comp = "diabc",
    hypothyroid = "hypothy", renal = "rf", liver = "ld", pud = "pud", hiv = "aids",
    lymphoma = "lymph", metastatic = "metacanc", solid_tumor = "solidtum",
    rheumatoid = "rheumd", coagulopathy = "coag", obesity = "obes", weight_loss = "wloss",
    fluid_electrolyte = "fed", blood_loss_anemia = "blane", deficiency_anemia = "dane",
    alcohol = "alcohol", drug = "drug", psychoses = "psycho", depression = "depre"
)

out <- data.frame(pid = charlson$pid)
for (stata_name in names(charlson_names)) {
    out[[paste0("r_ch_", stata_name)]] <- as.numeric(charlson[[charlson_names[[stata_name]]]])
}
for (stata_name in names(elixhauser_names)) {
    out[[paste0("r_el_", stata_name)]] <- as.numeric(elixhauser[[elixhauser_names[[stata_name]]]])
}
out$r_charlson_original <- as.numeric(score(charlson, weights = "charlson", assign0 = TRUE))
out$r_charlson_quan <- as.numeric(score(charlson, weights = "quan", assign0 = TRUE))
out$r_elixhauser_vw <- as.numeric(score(elixhauser, weights = "vw", assign0 = TRUE))

if (anyNA(out)) {
    stop("R reference produced missing indicators or scores")
}
write_dta(out, args[[2]], version = 14)
