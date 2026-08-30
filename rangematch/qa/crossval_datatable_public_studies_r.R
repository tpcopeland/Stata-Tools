# crossval_datatable_public_studies_r.R - public-data overlap oracles
#
# Uses data.table::foverlaps(), an implementation independent of rangematch,
# on two public longitudinal study datasets distributed with R: ChickWeight
# and survival::pbcseq. Every expected pair is computed at runtime.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
    stop("usage: Rscript crossval_datatable_public_studies_r.R OUTDIR")
}

outdir <- args[[1L]]
if (!dir.exists(outdir)) {
    stop("output directory does not exist: ", outdir)
}
if (!requireNamespace("data.table", quietly = TRUE)) {
    stop("R package data.table is required")
}
if (!requireNamespace("survival", quietly = TRUE)) {
    stop("R package survival is required")
}

library(data.table)

write_dt <- function(x, name) {
    write.csv(as.data.frame(x), file.path(outdir, name), row.names = FALSE,
              na = "")
}

# ChickWeight: each recorded weight is a point observation matched to an early,
# middle, or late growth window within the exact Chick x Diet group.
chick <- as.data.table(as.data.frame(datasets::ChickWeight))
chick[, `:=`(
    using_id = .I,
    chick = as.integer(as.character(Chick)),
    diet = as.integer(as.character(Diet)),
    time = as.integer(Time)
)]
chick_using <- chick[, .(using_id, chick, diet, time, weight)]

chick_master <- unique(chick_using[, .(chick, diet)])[
    , .(phase = 1:3,
        phase_lo = c(0L, 5L, 13L),
        phase_hi = c(4L, 12L, 21L)),
    by = .(chick, diet)
]
chick_master[, master_id := .I]
chick_master <- rbind(
    chick_master,
    data.table(chick = 999L, diet = 1L, phase = 1L,
               phase_lo = 0L, phase_hi = 21L,
               master_id = nrow(chick_master) + 1L)
)
setcolorder(chick_master,
            c("master_id", "chick", "diet", "phase", "phase_lo", "phase_hi"))

chick_x <- copy(chick_using)[, `:=`(point_lo = time, point_hi = time)]
chick_y <- copy(chick_master)
setkey(chick_y, chick, diet, phase_lo, phase_hi)
chick_hits <- foverlaps(
    chick_x, chick_y,
    by.x = c("chick", "diet", "point_lo", "point_hi"),
    by.y = c("chick", "diet", "phase_lo", "phase_hi"),
    type = "any", nomatch = NULL, which = TRUE
)
chick_expected <- data.table(
    master_id = chick_y$master_id[chick_hits$yid],
    using_id = chick_x$using_id[chick_hits$xid]
)
setorder(chick_expected, master_id, using_id)

write_dt(chick_master, "chick_master.csv")
write_dt(chick_using, "chick_using.csv")
write_dt(chick_expected, "chick_expected.csv")

# pbcseq: reproduce the start/stop construction in the dataset's official help
# example, then overlap those visit spells with fixed follow-up windows. The
# first 40 randomized patients retain irregular visit spacing, ties at adjacent
# spell endpoints, short follow-up, and long spells spanning multiple windows.
pbc <- as.data.table(survival::pbcseq)
pbc <- pbc[id <= 40L]
setorder(pbc, id, day)
pbc[, using_id := .I]
pbc[, spell_lo := fifelse(seq_len(.N) == 1L, 0, day), by = id]
pbc[, spell_hi := shift(day, type = "lead"), by = id]
pbc[is.na(spell_hi), spell_hi := futime]
if (pbc[spell_lo > spell_hi, .N] > 0L) {
    stop("pbcseq produced an inverted visit spell")
}
pbc_using <- pbc[, .(using_id, id, spell_lo, spell_hi, bili, albumin)]

pbc_master <- unique(pbc_using[, .(id)])[
    , .(window = 1:4,
        window_lo = c(0L, 366L, 1096L, 1826L),
        window_hi = c(365L, 1095L, 1825L, 3650L)),
    by = id
]
pbc_master[, master_id := .I]
pbc_master <- rbind(
    pbc_master,
    data.table(id = 999L, window = 1L, window_lo = 0L,
               window_hi = 365L, master_id = nrow(pbc_master) + 1L)
)
setcolorder(pbc_master,
            c("master_id", "id", "window", "window_lo", "window_hi"))

pbc_x <- copy(pbc_using)
pbc_y <- copy(pbc_master)
setkey(pbc_y, id, window_lo, window_hi)
pbc_hits <- foverlaps(
    pbc_x, pbc_y,
    by.x = c("id", "spell_lo", "spell_hi"),
    by.y = c("id", "window_lo", "window_hi"),
    type = "any", nomatch = NULL, which = TRUE
)
pbc_expected <- data.table(
    master_id = pbc_y$master_id[pbc_hits$yid],
    using_id = pbc_x$using_id[pbc_hits$xid]
)
setorder(pbc_expected, master_id, using_id)

write_dt(pbc_master, "pbc_master.csv")
write_dt(pbc_using, "pbc_using.csv")
write_dt(pbc_expected, "pbc_expected.csv")
writeLines("ok", file.path(outdir, "R_OK"))
