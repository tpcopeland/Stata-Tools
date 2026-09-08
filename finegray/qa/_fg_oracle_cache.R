# _fg_oracle_cache.R -- frozen R references for finegray QA.
# Routine runs only restore checked fixtures in qa/oracles; a missing,
# changed or corrupt reference is an error, never permission to fit R models.
# FG_ORACLE_REFRESH=1 explicitly regenerates references with the current R
# toolchain. Review numerical changes and provenance before accepting them.
# Input content and generator source determine identity; temporary filenames
# and the replay machine's R/package versions do not move frozen numbers.

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

.fg_cache_dir <- function() {
    file.path(dirname(.fg_script_path()), "oracles")
}

.fg_cache_root <- function(name, key) {
    sp <- .fg_script_path()
    if (is.na(sp) || is.na(key)) return(NA_character_)
    file.path(.fg_cache_dir(), name, substr(.fg_key_hash(key), 1, 16))
}

.fg_cache_key <- function(key_files, key_values, packages) {
    sp <- .fg_script_path()
    if (is.na(sp)) return(NA_character_)
    files <- unique(c(sp, key_files))
    md5 <- tools::md5sum(files)
    if (any(is.na(md5))) return(NA_character_)          # an input we cannot hash
    parts <- c(
        sprintf("file[%d]=%s", seq_along(files), unname(md5)),
        if (length(key_values))
            sprintf("val[%s]=%s", names(key_values),
                    vapply(key_values, function(v) paste(format(v, digits = 17),
                                                         collapse = ","), character(1)))
    )
    paste(parts, collapse = "\n")
}

# TRUE only for a complete, uncorrupted, exactly-keyed cache. Every early
# return leaves the outputs untouched, so a partial cache cannot produce a
# partial oracle -- the caller fails without fitting a model.
.fg_cache_restore <- function(root, key, outputs, out_dir = NA_character_) {
    kf <- file.path(root, "key.txt"); ix <- file.path(root, "index.csv")
    if (!file.exists(kf) || !file.exists(ix)) return(FALSE)
    if (!identical(readLines(kf, warn = FALSE), strsplit(key, "\n")[[1]])) return(FALSE)
    seal <- file.path(root, "index.md5")
    if (!file.exists(seal) ||
        !identical(readLines(seal, warn = FALSE), unname(tools::md5sum(ix))))
        return(FALSE)
    idx <- tryCatch(utils::read.csv(ix, stringsAsFactors = FALSE),
                    error = function(e) NULL)
    if (is.null(idx)) return(FALSE)
    if (is.na(out_dir) && nrow(idx) != length(outputs)) return(FALSE)
    if (!is.na(out_dir) && nrow(idx) == 0L) return(FALSE)
    if (!all(c("blob", "md5", "restored_as") %in% names(idx))) return(FALSE)
    if (anyNA(idx) || anyDuplicated(idx$blob) || anyDuplicated(idx$restored_as) ||
        any(!nzchar(idx$blob)) || any(!nzchar(idx$restored_as)) ||
        any(grepl("[/\\\\]", c(idx$blob, idx$restored_as))) ||
        any(c(idx$blob, idx$restored_as) %in% c(".", ".."))) return(FALSE)
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
    writeLines(unname(tools::md5sum(file.path(tmp, "index.csv"))),
               file.path(tmp, "index.md5"))
    writeLines(capture.output(sessionInfo()), file.path(tmp, "PROVENANCE.txt"))
    writeLines(strsplit(key, "\n")[[1]], file.path(tmp, "key.txt"))
    unlink(root, recursive = TRUE)
    ok <- file.rename(tmp, root)
    if (!ok) unlink(tmp, recursive = TRUE)
    if (!ok) stop("could not store frozen oracle")
    invisible(ok)
}

# The one entry point.  `compute` must create every path in `outputs`.
fg_oracle_cache <- function(name, outputs, compute,
                            key_files = character(0),
                            key_values = list(),
                            packages = character(0)) {
    h <- fg_oracle_cache_begin(name, outputs, key_files, key_values, packages)
    if (identical(h$state, "hit")) return(invisible("hit"))
    compute()
    fg_oracle_cache_end(h)
    invisible("refreshed")
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
    if (is.na(root) || is.na(key)) stop("cannot identify frozen oracle inputs")
    refresh <- identical(Sys.getenv("FG_ORACLE_REFRESH"), "1")
    on <- TRUE
    h <- list(name = name, root = root, key = key, outputs = outputs, on = on,
              out_dir = out_dir, out_pattern = out_pattern)
    if (!refresh && .fg_cache_restore(root, key, outputs, out_dir)) {
        cat(sprintf("FROZEN ORACLE HIT [%s]: %d artifact(s) restored from %s, computation skipped\n",
                    name, if (is.na(out_dir)) length(outputs)
                          else length(list.files(out_dir, pattern = out_pattern)),
                    root))
        h$state <- "hit"
        return(h)
    }
    if (!refresh)
        stop("FROZEN ORACLE missing, changed or corrupt: ", name,
             "; no R model was fitted. Restore qa/oracles or explicitly regenerate",
             " with FG_ORACLE_REFRESH=1 and review the reference changes.")
    cat(sprintf("ORACLE REFRESH [%s]: explicit regeneration requested\n", name))
    h$state <- "refresh"
    h
}

fg_oracle_cache_end <- function(h) {
    if (!isTRUE(h$on)) return(invisible(FALSE))
    if (!is.na(h$out_dir))
        h$outputs <- file.path(h$out_dir,
                               list.files(h$out_dir, pattern = h$out_pattern))
    if (!length(h$outputs) || !all(file.exists(h$outputs))) {
        stop("oracle refresh did not produce all outputs: ", h$name)
    }
    ok <- isTRUE(.fg_cache_store(h$root, h$key, h$outputs))
    cat(sprintf("ORACLE CACHE %s [%s]\n",
                if (ok) "STORED" else "NOT STORED", h$name))
    if (!ok) stop("could not store frozen oracle")
    invisible(ok)
}
