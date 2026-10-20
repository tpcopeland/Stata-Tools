*! _datamap_stage Version 1.10.3  2026/10/20
*! Staged report output: check the destination, copy the stage on success
*! Author: Timothy P Copeland, Karolinska Institutet

// A report is written to a tempfile stage and copied over its destination
// only once every dataset was documented, so a failure part-way through
// leaves the previous good file in place rather than a truncated one.
//   _datamap_stage check "dest"          before writing: a destination that
//                                        does not exist yet is created and
//                                        removed, so an unwritable path
//                                        fails before any dataset is read
//   _datamap_stage commit "stage" "dest" after success: copy the stage over
program define _datamap_stage, nclass
    version 16.0
    gettoken sub 0 : 0
    if "`sub'" == "check" {
        gettoken dest : 0
        capture confirm file `"`dest'"'
        if _rc {
            tempname fh
            quietly file open `fh' using `"`dest'"', write text replace
            file close `fh'
            capture erase `"`dest'"'
        }
    }
    else if "`sub'" == "commit" {
        gettoken stage 0 : 0
        gettoken dest : 0
        quietly copy `"`stage'"' `"`dest'"', replace
    }
    else {
        display as error "_datamap_stage: unknown subcommand `sub'"
        exit 198
    }
end
