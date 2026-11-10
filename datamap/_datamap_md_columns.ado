*! _datamap_md_columns Version 2.0.0  2026/11/10
*! Validate and expand datamap's columns() and compact choices
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// _datamap_md_columns [, columns(list) compact]
// r(columns): the table's columns, in order, as canonical names:
//   default   variable label type missing values
//   compact   variable type label missing unique
//   columns() the fields given, in the order given, each once; a field is a
//             canonical name or an alias (datadict's names included):
//             variable (name var), label (varlabel), type (storage
//             storagetype), class (classification), format (displayformat),
//             vallabel (valuelabel value_label), missing (miss), values
//             (stats statistics notesvalues valuesnotes), notes (varnotes),
//             chars (characteristics char), unique (distinct), position (pos)
// compact and columns() together are refused: both name the column set.
program define _datamap_md_columns, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [, COLumns(string asis) COMpact]

        local columns = subinstr(`"`macval(columns)'"', char(34), "", .)
        if `"`columns'"' != "" & "`compact'" != "" {
            noisily display as error "specify columns() or compact, not both"
            exit 198
        }
        local cols ""
        if "`compact'" != "" local cols "variable type label missing unique"
        else if `"`columns'"' == "" local cols "variable label type missing values"
        else {
            local cleaned = subinstr(`"`columns'"', ",", " ", .)
            local cleaned = subinstr(`"`cleaned'"', "|", " ", .)
            foreach raw in `cleaned' {
                local col = lower(strtrim(`"`raw'"'))
                if inlist(`"`col'"', "name", "var", "variable") local col "variable"
                else if inlist(`"`col'"', "label", "varlabel") local col "label"
                else if inlist(`"`col'"', "type", "storage", "storagetype") local col "type"
                else if inlist(`"`col'"', "class", "classification") local col "class"
                else if inlist(`"`col'"', "format", "displayformat") local col "format"
                else if inlist(`"`col'"', "vallabel", "valuelabel", "value_label") local col "vallabel"
                else if inlist(`"`col'"', "missing", "miss") local col "missing"
                else if inlist(`"`col'"', "values", "stats", "statistics", "notesvalues", "valuesnotes") local col "values"
                else if inlist(`"`col'"', "notes", "varnotes") local col "notes"
                else if inlist(`"`col'"', "chars", "characteristics", "char") local col "chars"
                else if inlist(`"`col'"', "unique", "distinct") local col "unique"
                else if inlist(`"`col'"', "position", "pos") local col "position"
                else {
                    noisily display as error `"invalid columns() field: `raw'"'
                    noisily display as error "allowed fields: variable label type class format vallabel missing values notes chars unique position"
                    exit 198
                }
                local cols "`cols' `col'"
            }
            local cols : list uniq cols
            if "`cols'" == "" {
                noisily display as error "columns() names no field"
                exit 198
            }
        }
        return local columns "`cols'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
