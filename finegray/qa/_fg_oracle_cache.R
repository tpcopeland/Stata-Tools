# ---------------------------------------------------------------------------
# _fg_oracle_cache.R -- content-keyed cache for the crossval R oracles.
#
# WHY.  Every crossval_*_r.R in this suite is a PURE FUNCTION of its inputs.
# Four of them simulate under a fixed seed (crossval_finegray_r.R 20260902,
# crossval_finegray_zzf_r.R 20260713, crossval_nuisance_r.R 11/7/21,
# crossval_finegray_zzf_beta_r.R 20260713 + rep); the other seven make no RNG
# call at all and simply fit a model to a CSV the .do file exported.  Either
# way the same inputs give byte-identical output on every run, forever.
# Measured 2026-09-04 on the full lane: crossval_finegray_zzf costs 2153 s --
# 98.5% of all crossval time -- and the other ten together cost ~56 s.  Every
# second of that is spent recomputing a constant.
#
# WHY THE CACHE LIVES INSIDE THE R SCRIPTS AND NOT AROUND Rscript.
# crossval_finegray_zzf.do's FG-02 contract exists because "an ignored data/
# cache from a prior good run still present" plus "a broken or missing Rscript"
# once let a suite consume a stale oracle and report a green 102/102.  A cache
# that let a .do file SKIP R would rebuild that hole exactly.  This one cannot:
# R still runs, still deletes whatever stale artifacts it deleted before, still
# writes every output, and still exits with a real status the .do's sentinel
# reads.  Only the expensive computation is skipped, and only on an exact key
# match.  No .do file changes.
#
# THE KEY IS EVERY INPUT THAT CAN MOVE A NUMBER
#   * the calling script's own md5, plus any oracle/definition file it sources;
#   * the md5 of every INPUT data file -- these arrive on paths in c(tmpdir)
#     that change every run, so the cache keys on their CONTENT, never on a
#     path;
#   * any scalar parameters the caller names (N, REPS, tolerances);
#   * the R version, the platform, and the version of every package named --
#     an oracle that silently moved from one package release to another is the
#     exact drift a cross-validation exists to catch, and a cache keyed without
#     it would HIDE that drift, which is worse than slow.
# Any key mismatch, any missing cached blob, any md5 that disagrees with the
# stored index, and the real computation runs.
#
# ESCAPE HATCH.  FG_ORACLE_NOCACHE=1 forces recomputation of every oracle.
#
# OUTPUT PATHS ARE NOT PART OF THE KEY.  The .do files hand these scripts an
# output path under c(tmpdir) that differs on every run, so blobs are cached by
# POSITION in the outputs vector and restored to whatever paths this run asked
# for.  The recorded basenames are for humans reading the index only.
# ---------------------------------------------------------------------------

.fg_script_path <- function() {
    a <- commandArgs(trailingOnly = FALSE)
    m <- grep("^--file=", a, value = TRUE)
    if (!length(m)) return(NA_character_)
    normalizePath(sub("^--file=", "", m[1]), mustWork = FALSE)
}

# Hash of the key text, used to ADDRESS the cache entry.  Several .do files
# invoke the same oracle script more than once with different inputs
# (crossval_tvc.do, crossval_finegray.do and crossval_predict_phtest.do each
# call theirs twice).  With one directory per script the second store would
# clobber the first and both invocations would miss forever, so every distinct
# input set gets its own entry and they coexist.  key.txt inside the entry is
# still compared in full on restore: the hash addresses, it never authorises.
.fg_key_hash <- function(key) {
    tf <- tempfile(); on.exit(unlink(tf), add = TRUE)
    writeLines(strsplit(key, "\n")[[1]], tf)
    unname(tools::md5sum(tf))
}

.fg_cache_root <- function(name, key) {
    sp <- .fg_script_path()
    if (is.na(sp) || is.na(key)) return(NA_character_)
    file.path(dirname(sp), ".oracle_cache", name, substr(.fg_key_hash(key), 1, 16))
}

.fg_cache_key <- function(key_files, key_values, packages) {
    sp <- .fg_script_path()
    if (is.na(sp)) return(NA_character_)
    files <- unique(c(sp, key_files))
    md5 <- tools::md5sum(files)
    if (any(is.na(md5))) return(NA_character_)          # an input we cannot hash
    parts <- c(
        sprintf("file[%s]=%s", basename(files), unname(md5)),
        if (length(key_values))
            sprintf("val[%s]=%s", names(key_values),
                    vapply(key_values, function(v) paste(format(v, digits = 17),
                                                         collapse = ","), character(1))),
        sprintf("R=%s", as.character(getRversion())),
        sprintf("platform=%s", R.version$platform),
        if (length(packages))
            vapply(packages, function(p)
                sprintf("pkg[%s]=%s", p,
                        tryCatch(as.character(utils::packageVersion(p)),
                                 error = function(e) "NOT-INSTALLED")), character(1))
    )
    paste(parts, collapse = "\n")
}

# TRUE only for a complete, uncorrupted, exactly-keyed cache. Every early
# return leaves the outputs untouched, so a partial cache cannot produce a
# partial oracle -- it produces a recomputation.
.fg_cache_restore <- function(root, key, outputs, out_dir = NA_character_) {
    kf <- file.path(root, "key.txt"); ix <- file.path(root, "index.csv")
    if (!file.exists(kf) || !file.exists(ix)) return(FALSE)
    if (!identical(readLines(kf, warn = FALSE), strsplit(key, "\n")[[1]])) return(FALSE)
    idx <- utils::read.csv(ix, stringsAsFactors = FALSE)
    if (is.na(out_dir) && nrow(idx) != length(outputs)) return(FALSE)
    if (!is.na(out_dir) && nrow(idx) == 0L) return(FALSE)
    if (!all(c("blob", "md5", "restored_as") %in% names(idx))) return(FALSE)
    src <- file.path(root, idx$blob)
    if (!all(file.exists(src))) return(FALSE)
    if (!identical(unname(tools::md5sum(src)), idx$md5)) return(FALSE)
    # Glob mode (outputs = NA, out_dir given): the caller could not name its
    # outputs up front because how many there are depends on a parameter --
    # the ZZF generator writes 5 arms x REPS datasets plus baselines. Restore
    # them under the basenames the store recorded.
    if (is.character(out_dir) && length(out_dir) == 1L && !is.na(out_dir)) {
        dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
        dest <- file.path(out_dir, idx$restored_as)
    } else {
        dest <- outputs
    }
    for (d in unique(dirname(dest)))
        dir.create(d, recursive = TRUE, showWarnings = FALSE)
    if (!all(file.copy(src, dest, overwrite = TRUE))) return(FALSE)
    all(file.exists(dest))
}

# Written to a sibling temp directory and renamed into place, so an interrupted
# store cannot leave a half-written cache a later run reads as a hit.
.fg_cache_store <- function(root, key, outputs) {
    if (!all(file.exists(outputs))) return(invisible(FALSE))
    tmp <- paste0(root, ".tmp", Sys.getpid())
    unlink(tmp, recursive = TRUE)
    dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
    blobs <- sprintf("%03d_%s", seq_along(outputs), basename(outputs))
    if (!all(file.copy(outputs, file.path(tmp, blobs)))) {
        unlink(tmp, recursive = TRUE); return(invisible(FALSE))
    }
    utils::write.csv(
        data.frame(blob = blobs,
                   md5 = unname(tools::md5sum(file.path(tmp, blobs))),
                   restored_as = basename(outputs)),
        file.path(tmp, "index.csv"), row.names = FALSE)
    writeLines(strsplit(key, "\n")[[1]], file.path(tmp, "key.txt"))
    unlink(root, recursive = TRUE)
    ok <- file.rename(tmp, root)
    if (!ok) unlink(tmp, recursive = TRUE)
    invisible(ok)
}

# The one entry point.  `compute` must create every path in `outputs`.
fg_oracle_cache <- function(name, outputs, compute,
                            key_files = character(0),
                            key_values = list(),
                            packages = character(0)) {
    key  <- .fg_cache_key(key_files, key_values, packages)
    root <- .fg_cache_root(name, key)
    on   <- !nzchar(Sys.getenv("FG_ORACLE_NOCACHE")) &&
            !is.na(root) && !is.na(key)
    if (on && .fg_cache_restore(root, key, outputs)) {
        cat(sprintf("ORACLE CACHE HIT [%s]: %d artifact(s) restored, computation skipped\n",
                    name, length(outputs)))
        return(invisible("hit"))
    }
    cat(sprintf("ORACLE CACHE %s [%s]: computing\n",
                if (on) "MISS" else "DISABLED", name))
    compute()
    if (!all(file.exists(outputs)))
        stop("oracle computation did not produce: ",
             paste(outputs[!file.exists(outputs)], collapse = ", "))
    if (on) {
        cat(sprintf("ORACLE CACHE %s [%s]\n",
                    if (isTRUE(.fg_cache_store(root, key, outputs)))
                        "STORED" else "NOT STORED (next run recomputes)", name))
    }
    invisible(if (on) "miss" else "disabled")
}

# ---------------------------------------------------------------------------
# EARLY-EXIT API.  Most crossval_*_r.R files compute across hundreds of
# top-level lines, several using `<<-` into an accumulator.  Wrapping those
# bodies in a closure would mean mass re-indentation and a real risk of
# changing what `<<-` binds to -- a silent, numeric-valued bug in an oracle,
# which is the worst possible place for one.  So the cache is applied as two
# statements instead: begin() before the body (exit the script on a hit) and
# end() after the last write.  The body itself is never touched.
#
#   .fgc <- fg_oracle_cache_begin("tvc", outputs = output_csv,
#                                 key_files = input_csv,
#                                 packages = c("cmprsk", "survival"))
#   if (identical(.fgc$state, "hit")) quit(save = "no", status = 0)
#   ... existing body, unchanged ...
#   fg_oracle_cache_end(.fgc)
# ---------------------------------------------------------------------------

fg_oracle_cache_begin <- function(name, outputs = NA_character_,
                                  key_files = character(0),
                                  key_values = list(),
                                  packages = character(0),
                                  out_dir = NA_character_,
                                  out_pattern = NA_character_) {
    key  <- .fg_cache_key(key_files, key_values, packages)
    root <- .fg_cache_root(name, key)
    on   <- !nzchar(Sys.getenv("FG_ORACLE_NOCACHE")) && !is.na(root) && !is.na(key)
    h <- list(name = name, root = root, key = key, outputs = outputs, on = on,
              out_dir = out_dir, out_pattern = out_pattern)
    if (on && .fg_cache_restore(root, key, outputs, out_dir)) {
        cat(sprintf("ORACLE CACHE HIT [%s]: %d artifact(s) restored, computation skipped\n",
                    name, if (is.na(out_dir)) length(outputs)
                          else length(list.files(out_dir, pattern = out_pattern))))
        h$state <- "hit"
        return(h)
    }
    cat(sprintf("ORACLE CACHE %s [%s]: computing\n",
                if (on) "MISS" else "DISABLED", name))
    h$state <- if (on) "miss" else "disabled"
    h
}

fg_oracle_cache_end <- function(h) {
    if (!isTRUE(h$on)) return(invisible(FALSE))
    if (!is.na(h$out_dir))
        h$outputs <- file.path(h$out_dir,
                               list.files(h$out_dir, pattern = h$out_pattern))
    if (!length(h$outputs) || !all(file.exists(h$outputs))) {
        cat(sprintf("ORACLE CACHE NOT STORED [%s]: expected output missing\n", h$name))
        return(invisible(FALSE))
    }
    ok <- isTRUE(.fg_cache_store(h$root, h$key, h$outputs))
    cat(sprintf("ORACLE CACHE %s [%s]\n",
                if (ok) "STORED" else "NOT STORED (next run recomputes)", h$name))
    invisible(ok)
}
