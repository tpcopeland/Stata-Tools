* _psdash_qa_extdata.do -- locate third-party QA source data that the repository does not distribute
* Usage (from psdash/qa):
*   run "`c(pwd)'/_psdash_qa_extdata.do"
*   _psdash_qa_extfile <set> <file>, len(#) crc(#) [url(string) regen(string)]
* Resolution order:
*   1. env        $STATA_QA_DATA/psdash/<set>/<file>, a local directory of third-party QA
*                 source data laid out <package>/<set>/<file>; not distributed with the repository
*   2. download   url() copied into a fixed name under c(tmpdir) (fetching a public source
*                 at test time is not redistribution)
*   3. regenerated  regen() names an R script that is run as: Rscript <script> <outdir>,
*                 when Rscript and twang 2.6.2 are installed; it must write <file> into <outdir>
*   4. unavailable  r(path) empty
* Whatever is found is verified against the recorded byte length and Stata checksum CRC;
* a mismatch is error 459, so a downloaded or regenerated file is byte-identical to the
* original or the suite does not run.
* Returns: r(path), r(source) env | download | regenerated | unavailable,
*          r(regen_dir) (regenerated only: the directory holding every file the script wrote)

version 16.0

capture program drop _psdash_qa_extfile
program define _psdash_qa_extfile, rclass
    version 16.0
    syntax anything(name=args id="set file"), LEN(real) CRC(real) [URL(string) REGEN(string)]
    gettoken set rest : args
    gettoken file rest : rest
    if `"`set'"' == "" | `"`file'"' == "" | `"`rest'"' != "" {
        display as error "_psdash_qa_extfile: need exactly <set> <file>"
        exit 198
    }

    local found ""
    local source ""
    local regen_dir ""

    * 1. local source-data directory
    local root : environment STATA_QA_DATA
    if `"`root'"' != "" {
        local cand `"`root'/psdash/`set'/`file'"'
        capture confirm file `"`cand'"'
        if !_rc {
            local found `"`cand'"'
            local source "env"
        }
    }

    * 2. public URL, fixed name under c(tmpdir)
    if `"`found'"' == "" & `"`url'"' != "" {
        local cand `"`c(tmpdir)'/psdash_qa_ext_`file'"'
        capture erase `"`cand'"'
        capture copy `"`url'"' `"`cand'"', replace
        if _rc {
            capture erase `"`cand'"'
        }
        else {
            local found `"`cand'"'
            local source "download"
        }
    }

    * 3. regenerate with R (twang 2.6.2 pinned: another version may move the GBM fit)
    if `"`found'"' == "" & `"`regen'"' != "" {
        capture confirm file `"`regen'"'
        if !_rc {
            tempfile ok1 ok2
            capture erase `"`ok1'"'
            shell Rscript -e "quit(status=ifelse(requireNamespace('twang', quietly=TRUE) && as.character(packageVersion('twang')) == '2.6.2', 0, 1))" > /dev/null 2>&1 && touch "`ok1'"
            capture confirm file `"`ok1'"'
            if !_rc {
                local rdir `"`c(tmpdir)'/psdash_qa_ext_regen_`set'"'
                capture shell rm -rf "`rdir'"
                capture mkdir `"`rdir'"'
                capture erase `"`ok2'"'
                shell Rscript "`regen'" "`rdir'" > "`rdir'/regen.log" 2>&1 && touch "`ok2'"
                capture confirm file `"`ok2'"'
                if !_rc {
                    capture confirm file `"`rdir'/`file'"'
                    if !_rc {
                        local found `"`rdir'/`file'"'
                        local source "regenerated"
                        local regen_dir `"`rdir'"'
                    }
                }
            }
        }
    }

    if `"`found'"' == "" {
        return local path ""
        return local source "unavailable"
        exit
    }

    * verify byte length and CRC of whatever was found
    quietly checksum `"`found'"'
    local got_len = r(filelen)
    local got_crc = r(checksum)
    if `got_len' != `len' | `got_crc' != `crc' {
        display as error "_psdash_qa_extfile: `file' (source `source') fails its integrity check"
        display as error "  path     `found'"
        display as error "  length   " %12.0f `got_len' " (expected " %12.0f `len' ")"
        display as error "  checksum " %12.0f `got_crc' " (expected " %12.0f `crc' ")"
        display as error "  the file is not the recorded original; the source data changed or the copy is corrupt"
        exit 459
    }
    return local path `"`found'"'
    return local source "`source'"
    if `"`regen_dir'"' != "" return local regen_dir `"`regen_dir'"'
end
