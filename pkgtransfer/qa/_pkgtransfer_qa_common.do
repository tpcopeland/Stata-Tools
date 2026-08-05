/*
    File:    _pkgtransfer_qa_common.do
    Purpose: Build and remove an isolated PLUS fixture for pkgtransfer QA
    Author:  Timothy P Copeland, Karolinska Institutet
    Date:    2026-08-05
*/

* qa-hygiene: no-package-code
version 16.0

capture program drop _pkgtransfer_qa_setup
program define _pkgtransfer_qa_setup, rclass
    version 16.0
    syntax, PKGDIR(string)

    local original_plus "`c(sysdir_plus)'"
    tempfile qa_marker
    local root "`qa_marker'_root"
    local work "`root'/work"
    local plus "`root'/plus"

    foreach dir in ///
        `"`root'"' ///
        `"`work'"' ///
        `"`plus'"' ///
        `"`plus'/a"' ///
        `"`plus'/f"' ///
        `"`plus'/p"' {
        mkdir `"`dir'"'
    }

    copy `"`pkgdir'/pkgtransfer.ado"' ///
        `"`plus'/p/pkgtransfer.ado"', replace
    copy `"`pkgdir'/pkgtransfer.sthlp"' ///
        `"`plus'/p/pkgtransfer.sthlp"', replace

    tempname tracker
    file open `tracker' using `"`plus'/stata.trk"', write text replace
    file write `tracker' "S https://example.org/alpha" _n
    file write `tracker' "N alpha.pkg" _n
    file write `tracker' "d alpha fixture" _n
    file write `tracker' "f a/alpha.ado" _n
    file write `tracker' "e" _n
    file write `tracker' "S http://fmwww.bc.edu/repec/bocode/f" _n
    file write `tracker' "N fre.pkg" _n
    file write `tracker' "d fre fixture" _n
    file write `tracker' "f f/fre.ado" _n
    file write `tracker' "e" _n
    file write `tracker' "S `pkgdir'" _n
    file write `tracker' "N pkgtransfer.pkg" _n
    file write `tracker' "d pkgtransfer fixture" _n
    file write `tracker' "f p/pkgtransfer.ado" _n
    file write `tracker' "f p/pkgtransfer.sthlp" _n
    file write `tracker' "e" _n
    file close `tracker'

    sysdir set PLUS `"`plus'"'

    return local original_plus `"`original_plus'"'
    return local root `"`root'"'
    return local work `"`work'"'
    return local plus `"`plus'"'
end

capture program drop _pkgtransfer_qa_cleanup
program define _pkgtransfer_qa_cleanup
    version 16.0
    syntax, ROOT(string) ORIGINALPLUS(string)

    sysdir set PLUS `"`originalplus'"'
    if `"`c(sysdir_plus)'"' != `"`originalplus'"' {
        exit 9
    }

    local level1 : dir `"`root'"' dirs "*", respectcase
    foreach d1 of local level1 {
        local path1 `"`root'/`d1'"'
        local level2 : dir `"`path1'"' dirs "*", respectcase
        foreach d2 of local level2 {
            local path2 `"`path1'/`d2'"'
            local level3 : dir `"`path2'"' dirs "*", respectcase
            foreach d3 of local level3 {
                local path3 `"`path2'/`d3'"'
                local files3 : dir `"`path3'"' files "*", respectcase
                foreach f of local files3 {
                    erase `"`path3'/`f'"'
                }
                rmdir `"`path3'"'
            }
            local files2 : dir `"`path2'"' files "*", respectcase
            foreach f of local files2 {
                erase `"`path2'/`f'"'
            }
            rmdir `"`path2'"'
        }
        local files1 : dir `"`path1'"' files "*", respectcase
        foreach f of local files1 {
            erase `"`path1'/`f'"'
        }
        rmdir `"`path1'"'
    }
    local rootfiles : dir `"`root'"' files "*", respectcase
    foreach f of local rootfiles {
        erase `"`root'/`f'"'
    }
    rmdir `"`root'"'
end
