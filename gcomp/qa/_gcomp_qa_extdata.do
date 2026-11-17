* _gcomp_qa_extdata.do -- locate third-party QA source data that the repository does not distribute
* Usage (from gcomp/qa):
*   run "`c(pwd)'/_gcomp_qa_extdata.do"
*   _gcomp_qa_extfile <set> <file>, len(#) crc(#) [url(string)]
* Resolution order:
*   1. env       $STATA_QA_DATA/gcomp/<set>/<file>, a local directory of third-party QA
*                source data laid out <package>/<set>/<file>; not distributed with the repository
*   2. download  url() copied into a fixed name under c(tmpdir) (fetching a public source
*                at test time is not redistribution)
*   3. otherwise error 601, naming both routes: a suite that needs the data fails rather
*                than passing without it
* Whatever is found is verified against the recorded byte length and Stata checksum CRC;
* a mismatch is error 459, so a downloaded file is byte-identical to the original or the
* suite does not run.
* Returns: r(path), r(source) env | download

version 16.0

capture program drop _gcomp_qa_extfile
program define _gcomp_qa_extfile, rclass
    version 16.0
    syntax anything(name=args id="set file"), LEN(real) CRC(real) [URL(string)]
    gettoken set rest : args
    gettoken file rest : rest
    if `"`set'"' == "" | `"`file'"' == "" | `"`rest'"' != "" {
        display as error "_gcomp_qa_extfile: need exactly <set> <file>"
        exit 198
    }

    local found ""
    local source ""

    * 1. local source-data directory
    local root : environment STATA_QA_DATA
    if `"`root'"' != "" {
        local cand `"`root'/gcomp/`set'/`file'"'
        capture confirm file `"`cand'"'
        if !_rc {
            local found `"`cand'"'
            local source "env"
        }
    }

    * 2. public URL, fixed name under c(tmpdir)
    if `"`found'"' == "" & `"`url'"' != "" {
        local cand `"`c(tmpdir)'/gcomp_qa_ext_`set'_`file'"'
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

    if `"`found'"' == "" {
        display as error "_gcomp_qa_extfile: third-party QA data `set'/`file' is not available"
        display as error "  the repository does not distribute it (see qa/data/`set'/SOURCE.md); either"
        display as error "  set STATA_QA_DATA to a directory holding gcomp/`set'/`file', or"
        if `"`url'"' != "" display as error `"  allow the test-time download from `url'"'
        else display as error "  obtain it from the source recorded in SOURCE.md"
        exit 601
    }

    * verify byte length and CRC of whatever was found
    quietly checksum `"`found'"'
    local got_len = r(filelen)
    local got_crc = r(checksum)
    if `got_len' != `len' | `got_crc' != `crc' {
        display as error "_gcomp_qa_extfile: `file' (source `source') fails its integrity check"
        display as error "  path     `found'"
        display as error "  length   " %12.0f `got_len' " (expected " %12.0f `len' ")"
        display as error "  checksum " %12.0f `got_crc' " (expected " %12.0f `crc' ")"
        display as error "  the file is not the recorded original; the source data changed or the copy is corrupt"
        exit 459
    }
    display as text "  third-party QA data `set'/`file': source `source'"
    return local path `"`found'"'
    return local source "`source'"
end
