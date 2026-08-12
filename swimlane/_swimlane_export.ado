*! _swimlane_export Version 0.1.0  2026/06/29
*! Export canonical swimlane frames
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Requires: Stata 16.0+

program define _swimlane_export, rclass
    version 16.0

    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _orig_frame = c(frame)
    local _changed_frame = 0
    local _file_open = 0
    local _restore_needed = 0

    capture noisily {
        syntax , CANONframe(name) [SAVEdata(string asis) FRAme(string asis) ///
            EVENTFrame(name)]

        * Parse and validate the output frame before changing frames or writing
        * savedata(), so a protected-name error cannot leave partial output.
        if `"`frame'"' != "" {
            gettoken framename framerest : frame, parse(",")
            local framename = strtrim(`"`framename'"')
            local framename = subinstr(`"`framename'"', char(34), "", .)
            local framerest = strtrim(`"`framerest'"')
            if "`framename'" == "" {
                display as error "frame() requires a frame name"
                exit 198
            }
            capture confirm name `framename'
            if _rc {
                display as error "frame() requires a valid Stata frame name"
                exit 198
            }
            local replace = 0
            if `"`framerest'"' != "" {
                if substr(`"`framerest'"', 1, 1) != "," {
                    display as error "invalid frame() syntax"
                    exit 198
                }
                local frameopts = lower(strtrim(substr(`"`framerest'"', 2, .)))
                if "`frameopts'" != "replace" {
                    display as error "frame() allows only the replace option"
                    exit 198
                }
                local replace = 1
            }
            if "`framename'" == "`_orig_frame'" {
                display as error ///
                    "frame() cannot replace the active input frame"
                exit 198
            }
            if "`eventframe'" != "" & "`framename'" == "`eventframe'" {
                display as error ///
                    "frame() cannot replace the eventframe() source"
                exit 198
            }
            local frame_exists = 0
            capture frame `framename': describe
            if _rc == 0 {
                local frame_exists = 1
                if !`replace' {
                    display as error ///
                        "frame `framename' already exists; specify frame(`framename', replace)"
                    exit 110
                }
            }
        }

        frame change `canonframe'
        local _changed_frame = 1

        local export_cols "lane rank panel id label seg rowtype series start stop xpoint duration ongoing group grouplab series_k sort_key sort_direction sort_missing sort_value label_selected block blocklab block_start"

        if `"`savedata'"' != "" {
            gettoken path rest : savedata, parse(",")
            local path = strtrim(`"`path'"')
            local path = subinstr(`"`path'"', char(34), "", .)
            local rest = strtrim(`"`rest'"')
            if `"`rest'"' != "" {
                display as error "savedata() does not accept trailing options"
                exit 198
            }
            foreach bad in ";" "&" "|" ">" "<" "$" {
                if strpos(`"`path'"', "`bad'") {
                    display as error ///
                        "savedata() path contains unsupported shell metacharacter"
                    exit 198
                }
            }
            if strpos(`"`path'"', char(96)) | strpos(`"`path'"', char(34)) | ///
                strpos(`"`path'"', char(39)) {
                display as error ///
                    "savedata() path contains unsupported quote character"
                exit 198
            }

            local lower_path = lower(`"`path'"')
            preserve
            local _restore_needed = 1
            keep `export_cols'
            sort lane seg rowtype start xpoint

            if substr("`lower_path'", -4, 4) == ".csv" {
                export delimited using "`path'", replace
            }
            else if substr("`lower_path'", -4, 4) == ".dta" {
                save "`path'", replace
            }
            else if substr("`lower_path'", -3, 3) == ".md" {
                tempname fh
                file open `fh' using "`path'", write replace text
                local _file_open = 1
                file write `fh' "| lane | rank | panel | id | label | seg | rowtype | series | start | stop | xpoint | duration | ongoing | group | grouplab | series_k | sort_key | sort_direction | sort_missing | sort_value | label_selected | block | blocklab | block_start |" _n
                file write `fh' "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |" _n
                forvalues i = 1/`=_N' {
                    file write `fh' "|"
                    foreach v of local export_cols {
                        capture confirm string variable `v'
                        if _rc == 0 {
                            local val = `v'[`i']
                        }
                        else {
                            local vfmt : format `v'
                            if regexm("`vfmt'", "^%-?[td]") {
                                local val : display `vfmt' `v'[`i']
                            }
                            else local val : display %12.0g `v'[`i']
                            local val = strtrim("`val'")
                        }
                        local val = subinstr(`"`val'"', "|", "\|", .)
                        local val = subinstr(`"`val'"', char(13), "", .)
                        local val = subinstr(`"`val'"', char(10), "<br>", .)
                        file write `fh' `" `val' |"'
                    }
                    file write `fh' _n
                }
                file close `fh'
                local _file_open = 0
            }
            else {
                display as error "savedata() extension must be .csv, .md, or .dta"
                exit 198
            }
            restore
            local _restore_needed = 0
        }

        if `"`frame'"' != "" {
            if `frame_exists' frame drop `framename'
            frame copy `canonframe' `framename'
        }
    }
    local rc = _rc
    if `_file_open' capture file close `fh'
    if `_restore_needed' capture restore
    if `_changed_frame' capture frame change `_orig_frame'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
