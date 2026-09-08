# test_finegray_oracles.R -- frozen-reference identity and fail-closed checks.
# Author: Timothy P Copeland, Karolinska Institutet
args <- commandArgs(trailingOnly = FALSE)
qa <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", args, value=TRUE)[1])))
source(file.path(qa, "_fg_oracle_cache.R"))
work <- tempfile("finegray-oracle-test-")
dir.create(work)
old_refresh <- Sys.getenv("FG_ORACLE_REFRESH", unset=NA_character_)
Sys.unsetenv("FG_ORACLE_REFRESH")
pass <- 0L
fail <- 0L
check <- function(label, body) {
    tryCatch({ force(body); pass <<- pass + 1L; cat("PASS:", label, "\n") },
             error=function(e) { fail <<- fail + 1L; cat("FAIL:", label, conditionMessage(e), "\n") })
}
reject <- function(body) {
    err <- tryCatch({ force(body); NULL }, error=identity)
    stopifnot(inherits(err, "error"), grepl("FROZEN ORACLE", conditionMessage(err)))
}
# Check every retained real R reference before changing the test's root.
check("all retained references restore byte-exactly", {
    entries <- list.files(file.path(qa, "oracles"), pattern="key.txt", recursive=TRUE, full.names=TRUE)
    stopifnot(length(entries) >= 15L)
    for (kf in entries) {
        root <- dirname(kf)
        idx <- read.csv(file.path(root,"index.csv"))
        out <- file.path(work, basename(dirname(root)), basename(root), idx$restored_as)
        stopifnot(.fg_cache_restore(root, paste(readLines(kf),collapse="\n"), out),
                  identical(unname(tools::md5sum(out)), idx$md5))
    }
})
script <- file.path(work,"generator.R")
writeLines("# frozen generator",script)
.fg_script_path <- function() script
input <- file.path(work,"St111.csv")
writeLines(c("x","1","2"),input)
output <- file.path(work,"output.csv")
computed <- 0L
compute <- function() { computed <<- computed + 1L; writeLines(c("answer","42"),output) }
check("missing reference refuses computation", {
    reject(fg_oracle_cache("toy",output,compute,key_files=input))
    stopifnot(computed == 0L)
})
check("explicit refresh creates a reference", {
    Sys.setenv(FG_ORACLE_REFRESH="1")
    fg_oracle_cache("toy",output,compute,key_files=input)
    Sys.unsetenv("FG_ORACLE_REFRESH")
    stopifnot(computed == 1L, identical(readLines(output),c("answer","42")))
})
check("renamed temporary input restores without computing", {
    input2 <- file.path(work,"St999.csv")
    stopifnot(file.copy(input,input2))
    unlink(output)
    fg_oracle_cache("toy",output,compute,key_files=input2)
    stopifnot(computed == 1L, identical(readLines(output),c("answer","42")))
})
key <- .fg_cache_key(input,list(),character())
root <- .fg_cache_root("toy",key)
check("replay package versions do not change reference identity", {
    stopifnot(identical(key,.fg_cache_key(input,list(),"not_installed_package")))
})
check("changed input refuses computation", {
    writeLines(c("x","3"),input)
    reject(fg_oracle_cache("toy",output,compute,key_files=input))
    writeLines(c("x","1","2"),input)
    stopifnot(computed == 1L)
})
check("changed generator refuses computation", {
    writeLines("# changed generator",script)
    reject(fg_oracle_cache("toy",output,compute,key_files=input))
    writeLines("# frozen generator",script)
})
idx <- read.csv(file.path(root,"index.csv"))
blob <- file.path(root,idx$blob[1])
original <- readBin(blob,"raw",n=file.info(blob)$size)
check("corrupt blob refuses computation and preserves output", {
    writeLines("corrupt",blob)
    before <- readLines(output)
    reject(fg_oracle_cache("toy",output,compute,key_files=input))
    stopifnot(identical(before,readLines(output)),computed == 1L)
    writeBin(original,blob)
})
check("missing blob refuses computation", {
    unlink(blob)
    reject(fg_oracle_cache("toy",output,compute,key_files=input))
    writeBin(original,blob)
})
check("corrupt manifest refuses computation", {
    write("corrupt",file.path(root,"index.csv"),append=TRUE)
    reject(fg_oracle_cache("toy",output,compute,key_files=input))
    stopifnot(computed == 1L)
})
unlink(work,recursive=TRUE)
if (is.na(old_refresh)) Sys.unsetenv("FG_ORACLE_REFRESH") else Sys.setenv(FG_ORACLE_REFRESH=old_refresh)
cat(sprintf("RESULT: test_finegray_oracles tests=%d pass=%d fail=%d\n",pass+fail,pass,fail))
quit(save="no",status=as.integer(fail > 0L))
