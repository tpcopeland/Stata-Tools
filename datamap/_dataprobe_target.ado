*! _dataprobe_target Version 2.0.0  2026/11/10
*! Resolve and validate a dataprobe frame-or-file target before profiling
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// One rule for every dataprobe option that names a frame or a file
// (2.0.0, U3): a target that ends in .dta (or .do, for makespec()) or holds
// a / or \ is a file; any other name is a frame.  Called before the profile
// prints, so a target that cannot be used stops the call before any output.
//
//   mode(read)   compare(), diff(): the frame when one of that name exists,
//                else the file name or name.dta (a 1.x compare(base) that
//                read base.dta keeps working); neither is r(601).  No
//                suboptions.
//   mode(write)  saving(): frame or file, [, replace].  An existing frame or
//                file without replace is r(110) / r(602); the current frame
//                can never be the target.
//   mode(frame)  snapshot(): a frame only, [, replace].
//   mode(spec)   makespec(): as write, and a target ending in .do is a
//                do-file (r(kind) dofile).
//
// r(kind) frame, file or dofile; r(target) the frame name or the path, without
// quotes; r(replace) 0 or 1.
program define _dataprobe_target, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local kind ""
    local tgt ""
    local rep = 0
    capture noisily {
        syntax, SPEC(string) OPTion(name) MODE(name)
        if !inlist("`mode'", "read", "write", "frame", "spec") {
            display as error "_dataprobe_target: mode() must be read, write, frame or spec"
            exit 198
        }
        local s = strtrim(`"`macval(spec)'"')
        local rest ""
        local quoted = (substr(`"`macval(s)'"', 1, 1) == char(34) | ///
            substr(`"`macval(s)'"', 1, 2) == char(96) + char(34))
        if `quoted' {
            // a quoted target is one token: a comma inside it is part of it
            gettoken tgt rest : s
            local rest = strtrim(`"`macval(rest)'"')
            if `"`macval(rest)'"' != "" {
                if substr(`"`macval(rest)'"', 1, 1) != "," {
                    display as error "`option'() accepts one frame name or file, then [, replace]"
                    exit 198
                }
                local rest = strtrim(substr(`"`macval(rest)'"', 2, .))
            }
        }
        else {
            local cp = strpos(`"`macval(s)'"', ",")
            if `cp' {
                local tgt = strtrim(substr(`"`macval(s)'"', 1, `cp' - 1))
                local rest = strtrim(substr(`"`macval(s)'"', `cp' + 1, .))
            }
            else local tgt `"`macval(s)'"'
        }
        // quotes are never part of a target (1.x stripped them too)
        mata: st_local("tgt", strtrim(subinstr(st_local("tgt"), char(34), "")))
        if `"`macval(tgt)'"' == "" {
            display as error "`option'() requires a frame name or a file"
            exit 198
        }
        mata: st_local("_bad", strofreal(strpos(st_local("tgt"), char(96)) > 0 | ///
            strpos(st_local("tgt"), "$") > 0))
        if `_bad' {
            display as error "illegal characters in `option'() target"
            exit 198
        }
        // read: compare() and diff() keep the user's quotes (asis), so a
        // quoted path with a space is one target, as in saving()
        if "`mode'" == "read" {
            if `"`rest'"' != "" | (!`quoted' & strpos(`"`tgt'"', " ")) {
                display as error "`option'() accepts one frame name or one Stata dataset filename"
                exit 198
            }
        }
        else if `"`rest'"' != "" {
            if lower(`"`rest'"') != "replace" {
                display as error `"`option'(): the only suboption is replace; got `rest'"'
                exit 198
            }
            local rep = 1
        }
        local isfile = (substr(`"`tgt'"', -4, 4) == ".dta" | strpos(`"`tgt'"', "/") | ///
            strpos(`"`tgt'"', "\"))
        local isdo = (substr(`"`tgt'"', -3, 3) == ".do")
        if "`mode'" == "spec" & `isdo' local isfile = 1

        if "`mode'" == "read" {
            local isframe = 0
            if !`isfile' {
                capture confirm name `tgt'
                if !_rc {
                    capture frame `tgt': describe, short
                    local isframe = (_rc == 0)
                }
            }
            // the current frame holds the data being profiled (and this
            // call's temporary variables): it is no baseline (2026-11-10;
            // diff(default) listed a tempvar as dropped)
            if `isframe' & "`tgt'" == "`c(frame)'" {
                display as error "`option'(): `tgt' is the current frame; name a baseline frame or file"
                exit 198
            }
            if `isframe' local kind "frame"
            else {
                _dataprobe_tpath `"`tgt'"' `option'
                capture confirm file `"`tgt'"'
                if _rc {
                    capture confirm file `"`tgt'.dta"'
                    if _rc {
                        if `isfile' display as error `"`option'() file `tgt' not found"'
                        else display as error `"`option'(): no frame or file named `tgt'"'
                        exit 601
                    }
                    local tgt `"`tgt'.dta"'
                }
                local kind "file"
            }
        }
        else if "`mode'" == "frame" | !`isfile' {
            if `isfile' {
                display as error "`option'() takes a frame name; saving() writes a file"
                exit 198
            }
            capture confirm name `tgt'
            if _rc {
                display as error "`option'(): `tgt' is not a valid frame name"
                exit 198
            }
            if "`tgt'" == "`c(frame)'" {
                display as error "`option'(): `tgt' is the current frame and cannot be replaced"
                exit 198
            }
            capture frame `tgt': describe, short
            if _rc == 0 & !`rep' {
                display as error "`option'(): frame `tgt' already exists; specify replace"
                exit 110
            }
            local kind "frame"
        }
        else {
            _dataprobe_tpath `"`tgt'"' `option'
            // the folder must exist: a write into a missing folder failed
            // only after the profile had printed (2026-11-10)
            mata: st_local("_dir", pathgetparent(st_local("tgt")))
            if `"`_dir'"' != "" {
                mata: st_local("_dok", strofreal(direxists(st_local("_dir"))))
                if !`_dok' {
                    display as error `"`option'(): folder `_dir' not found"'
                    exit 603
                }
            }
            capture confirm file `"`tgt'"'
            if _rc == 0 & !`rep' {
                display as error `"`option'(): file `tgt' already exists; specify replace"'
                exit 602
            }
            local kind = cond(`isdo' & "`mode'" == "spec", "dofile", "file")
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local kind "`kind'"
    return local target `"`tgt'"'
    return scalar replace = `rep'
end

// shell metacharacters in a file target (the 1.x rule of saving() and
// compare(), as an error before any output)
capture program drop _dataprobe_tpath
program define _dataprobe_tpath, nclass
    args p option
    local bad = 0
    foreach c in ";" "&" "|" ">" "<" {
        if strpos(`"`p'"', "`c'") local bad = 1
    }
    if `bad' {
        display as error "illegal characters in `option'() path"
        exit 198
    }
end
