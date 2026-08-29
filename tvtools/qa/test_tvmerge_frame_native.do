*! test_tvmerge_frame_native.do
*! Contract pins for tvmerge's frame-native source acquisition (1.9.1).
*!
*! Until 1.9.1 tvmerge read every source file three times -- once to validate,
*! once for flow accounting, and once during the merge -- and wrote every
*! frames() input to a tempfile so it could be read back through that same
*! file path. Sources are now materialised once, each into its own scratch
*! frame, and a frames() input is never serialised.
*!
*! Axes probed, and why each one is here:
*!   F1-F4   file and frames() inputs agree, for two and three sources. This is
*!           the property the refactor exists to preserve.
*!   F5-F7   the scratch frames do not leak. This is new state that the
*!           refactor introduced; nothing in the pre-1.9.1 suite could see a
*!           leaked frame, and a leak is silent until a later frame name
*!           collides or memory runs out.
*!   F8-F10  a user-owned input frame is read, never mutated -- values,
*!           variable list, and sort order all survive.
*!   F11     r(datasets) reports the frame names for a frames() input. It used
*!           to report internal tempfile paths that changed every run, while
*!           tvmerge.sthlp documents it as "list of datasets merged".
*!   F12-F16 the negative paths still fail the released way, still leave the
*!           caller's data intact, and still leak no frames.
*!   F17     flow accounting is unchanged now that persons-in is counted from
*!           the union of the loaded frames instead of a tempfile append.

clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_tvmerge_frame_native.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

global TFN_PASS = 0
global TFN_FAIL = 0
global TFN_FAILED ""
local test_count = 0

display as result "tvtools QA: tvmerge frame-native sources -- $S_DATE $S_TIME"

capture program drop _tfn_check
program define _tfn_check
    args ok label detail
    if `ok' {
        global TFN_PASS = $TFN_PASS + 1
        display as result "  PASS `label'"
    }
    else {
        global TFN_FAIL = $TFN_FAIL + 1
        global TFN_FAILED "$TFN_FAILED `label'"
        display as error "  FAIL `label': `detail'"
    }
end

* Count frames other than the ones this suite owns. A scratch frame left behind
* by tvmerge shows up here and nowhere else.
capture program drop _tfn_nframes
program define _tfn_nframes, rclass
    version 16.0
    quietly frames dir
    local all `r(frames)'
    local mine "default srcA srcB srcC fout keepme"
    local extra : list all - mine
    return local extra "`extra'"
    return scalar n = `: word count `extra''
end

tempfile fA fB fC
local wd "`c(pwd)'"

* Deterministic sources; every tie carries an explicit original-row tie-break.
clear
quietly set obs 12
quietly generate long pid = ceil(_n / 3)
quietly bysort pid: generate int seq = _n
quietly generate int a_start = 21915 + (seq - 1) * 40
quietly generate int a_stop  = a_start + 29
quietly generate byte drugA  = mod(pid + seq, 3)
format a_start a_stop %tdCCYY/NN/DD
quietly drop seq
quietly save "`fA'", replace

clear
quietly set obs 16
quietly generate long pid = ceil(_n / 4)
quietly bysort pid: generate int seq = _n
quietly generate int b_start = 21930 + (seq - 1) * 30
quietly generate int b_stop  = b_start + 24
quietly generate byte drugB  = mod(seq, 2)
format b_start b_stop %tdCCYY/NN/DD
quietly drop seq
quietly save "`fB'", replace

clear
quietly set obs 8
quietly generate long pid = ceil(_n / 2)
quietly bysort pid: generate int seq = _n
quietly generate int c_start = 21946 + (seq - 1) * 70
quietly generate int c_stop  = c_start + 19
quietly generate byte drugC  = seq
format c_start c_stop %tdCCYY/NN/DD
quietly drop seq
quietly save "`fC'", replace


**# ===== F1-F2: two sources, file input vs frames() input =====
local ++test_count
clear
quietly tvmerge "`fA'" "`fB'", id(pid) start(a_start b_start) ///
    stop(a_stop b_stop) exposure(drugA drugB)
tempfile viafile
quietly save "`viafile'", replace
local n_file = _N
local r_file = r(N)

capture frame drop srcA
capture frame drop srcB
frame create srcA
frame srcA: use "`fA'", clear
frame create srcB
frame srcB: use "`fB'", clear
clear
quietly tvmerge, frames(srcA srcB) id(pid) start(a_start b_start) ///
    stop(a_stop b_stop) exposure(drugA drugB)
local n_frames = _N
capture _tvtools_qa_assert_cf_all_exact using "`viafile'"
local cfrc = _rc
local ok = (`cfrc' == 0 & `n_file' == `n_frames')
_tfn_check `ok' "F1 frames() input reproduces the file-input result exactly" ///
    "cf rc=`cfrc' N file=`n_file' frames=`n_frames'"

local ++test_count
local ok = (`n_frames' > 0)
_tfn_check `ok' "F2 the frames() merge actually produced rows" ///
    "N=`n_frames'"


**# ===== F3-F4: three sources, both input modes =====
local ++test_count
clear
quietly tvmerge "`fA'" "`fB'" "`fC'", id(pid) ///
    start(a_start b_start c_start) stop(a_stop b_stop c_stop) ///
    exposure(drugA drugB drugC)
tempfile viafile3
quietly save "`viafile3'", replace
local n_file3 = _N

capture frame drop srcC
frame create srcC
frame srcC: use "`fC'", clear
clear
quietly tvmerge, frames(srcA srcB srcC) id(pid) ///
    start(a_start b_start c_start) stop(a_stop b_stop c_stop) ///
    exposure(drugA drugB drugC)
local n_frames3 = _N
capture _tvtools_qa_assert_cf_all_exact using "`viafile3'"
local cfrc3 = _rc
local ok = (`cfrc3' == 0 & `n_file3' == `n_frames3')
_tfn_check `ok' "F3 three-source frames() matches three-source file input" ///
    "cf rc=`cfrc3' N file=`n_file3' frames=`n_frames3'"

local ++test_count
local ok = (`n_file3' > 0)
_tfn_check `ok' "F4 the three-source merge produced rows" "N=`n_file3'"


**# ===== F5-F7: scratch frames do not leak =====
* Sources now live in tempnamed frames for the whole command. If one survives
* the call, nothing else in the suite would notice.
local ++test_count
clear
quietly tvmerge "`fA'" "`fB'", id(pid) start(a_start b_start) ///
    stop(a_stop b_stop) exposure(drugA drugB)
_tfn_nframes
local extra_file = r(n)
local extra_names "`r(extra)'"
local ok = (`extra_file' == 0)
_tfn_check `ok' "F5 file input leaves no frame behind on success" ///
    "`extra_file' extra frame(s): `extra_names'"

local ++test_count
clear
quietly tvmerge, frames(srcA srcB) id(pid) start(a_start b_start) ///
    stop(a_stop b_stop) exposure(drugA drugB)
_tfn_nframes
local extra_frames = r(n)
local extra_names2 "`r(extra)'"
local ok = (`extra_frames' == 0)
_tfn_check `ok' "F6 frames() input leaves no frame behind on success" ///
    "`extra_frames' extra frame(s): `extra_names2'"

local ++test_count
clear
quietly set obs 5
quietly generate double caller_marker = 17
capture noisily tvmerge "`fA'" "`wd'/no_such_source.dta", id(pid) ///
    start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB)
local errrc = _rc
_tfn_nframes
local extra_err = r(n)
local extra_names3 "`r(extra)'"
local ok = (`extra_err' == 0 & `errrc' == 601)
_tfn_check `ok' "F7 a failed merge leaves no frame behind" ///
    "rc=`errrc' `extra_err' extra frame(s): `extra_names3'"


**# ===== F8-F10: a user-owned input frame is never mutated =====
* The command copies the frame rather than referencing it, because per-source
* preprocessing renames and drops variables.
local ++test_count
capture frame drop srcA
capture frame drop srcB
frame create srcA
frame srcA: use "`fA'", clear
frame srcA: sort pid a_start
frame create srcB
frame srcB: use "`fB'", clear
frame srcA: quietly save "`wd'/_tfn_srcA_before.dta", replace
frame srcB: quietly save "`wd'/_tfn_srcB_before.dta", replace
clear
quietly tvmerge, frames(srcA srcB) id(pid) start(a_start b_start) ///
    stop(a_stop b_stop) exposure(drugA drugB)
frame change srcA
capture _tvtools_qa_assert_cf_all_exact using "`wd'/_tfn_srcA_before.dta"
local cfa = _rc
local sorta : sortedby
frame change default
local ok = (`cfa' == 0)
_tfn_check `ok' "F8 the first input frame's data is unchanged" "cf rc=`cfa'"

local ++test_count
frame change srcB
capture _tvtools_qa_assert_cf_all_exact using "`wd'/_tfn_srcB_before.dta"
local cfb = _rc
frame change default
local ok = (`cfb' == 0)
_tfn_check `ok' "F9 the second input frame's data is unchanged" "cf rc=`cfb'"

local ++test_count
local ok = ("`sorta'" == "pid a_start")
_tfn_check `ok' "F10 the input frame keeps its sort order" ///
    "sortedby is [`sorta'], expected [pid a_start]"
capture erase "`wd'/_tfn_srcA_before.dta"
capture erase "`wd'/_tfn_srcB_before.dta"


**# ===== F11: r(datasets) names the frames, not internal tempfiles =====
* tvmerge.sthlp documents r(datasets) as "list of datasets merged". Before
* 1.9.1 a frames() call returned the tempfile paths the frames had been
* serialised through: different on every run, and useful to nobody.
local ++test_count
clear
quietly tvmerge, frames(srcA srcB) id(pid) start(a_start b_start) ///
    stop(a_stop b_stop) exposure(drugA drugB)
local ds "`r(datasets)'"
local ds = trim("`ds'")
local has_tmp = 0
foreach tok of local ds {
    if regexm("`tok'", "St[0-9]+\.[0-9]+") local has_tmp = 1
}
local ok = ("`ds'" == "srcA srcB" & !`has_tmp')
_tfn_check `ok' "F11 r(datasets) reports the frame names for a frames() input" ///
    "r(datasets)=[`ds'] tempfile_paths=`has_tmp'"


**# ===== F12-F16: negative paths keep their released behaviour =====
local ++test_count
clear
quietly set obs 3
quietly generate double caller_marker = 99
capture noisily tvmerge "`fA'" "`wd'/absent_file.dta", id(pid) ///
    start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB)
local rc601 = _rc
capture confirm variable caller_marker
local caller_ok = (_rc == 0)
quietly count
local caller_n = r(N)
local ok = (`rc601' == 601 & `caller_ok' & `caller_n' == 3)
_tfn_check `ok' "F12 a missing source file still exits r(601), caller intact" ///
    "rc=`rc601' caller_var=`caller_ok' N=`caller_n'"

local ++test_count
tempname fh
file open `fh' using "`wd'/_tfn_notdta.dta", write replace text
file write `fh' "not a Stata dataset" _n
file close `fh'
clear
quietly set obs 3
quietly generate double caller_marker = 98
capture noisily tvmerge "`fA'" "`wd'/_tfn_notdta.dta", id(pid) ///
    start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB)
local rc610 = _rc
capture confirm variable caller_marker
local caller_ok2 = (_rc == 0)
local ok = (`rc610' == 610 & `caller_ok2')
_tfn_check `ok' "F13 an unreadable source still exits r(610), caller intact" ///
    "rc=`rc610' caller_var=`caller_ok2'"
capture erase "`wd'/_tfn_notdta.dta"

local ++test_count
clear
quietly set obs 3
quietly generate double caller_marker = 97
capture noisily tvmerge, frames(srcA nosuchframe) id(pid) ///
    start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB)
local rcfr = _rc
capture confirm variable caller_marker
local caller_ok3 = (_rc == 0)
_tfn_nframes
local extra_fr = r(n)
local ok = (`rcfr' == 111 & `caller_ok3' & `extra_fr' == 0)
_tfn_check `ok' "F14 a missing input frame exits r(111) and leaks nothing" ///
    "rc=`rcfr' caller_var=`caller_ok3' extra_frames=`extra_fr'"

local ++test_count
clear
capture noisily tvmerge "`fA'" "`fB'", frames(srcA srcB) id(pid) ///
    start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB)
local rcboth = _rc
local ok = (`rcboth' == 198)
_tfn_check `ok' "F15 supplying both file paths and frames() still exits r(198)" ///
    "rc=`rcboth'"

* A strL ID is refused from a frame input just as it is from a file.
local ++test_count
capture frame drop srcC
frame create srcC
frame srcC: use "`fA'", clear
frame srcC: quietly generate strL lid = "P" + string(pid)
clear
quietly set obs 3
quietly generate double caller_marker = 96
capture noisily tvmerge, frames(srcC srcB) id(lid) ///
    start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB)
local rcstrl = _rc
capture confirm variable caller_marker
local caller_ok4 = (_rc == 0)
_tfn_nframes
local extra_strl = r(n)
local ok = (`rcstrl' == 109 & `caller_ok4' & `extra_strl' == 0)
_tfn_check `ok' "F16 a strL ID in a frame input exits r(109) and leaks nothing" ///
    "rc=`rcstrl' caller_var=`caller_ok4' extra_frames=`extra_strl'"


**# ===== F17: flow accounting is unchanged =====
* persons in is now counted from the union of the loaded source frames instead
* of a re-read and appended tempfile. The number must not move.
local ++test_count
capture frame drop srcC
clear
quietly tvmerge "`fA'" "`fB'", id(pid) start(a_start b_start) ///
    stop(a_stop b_stop) exposure(drugA drugB) flow
matrix _fl = r(flow)
local pin = _fl[1,1]
local rin = _fl[2,1]
* fA has 4 persons over 12 rows, fB has 4 persons over 16 rows; the union of
* ids is 4 persons and the record count is the sum, 28.
local ok = (`pin' == 4 & `rin' == 28)
_tfn_check `ok' "F17 flow persons-in and records-in match the source union" ///
    "persons_in=`pin' (expected 4) records_in=`rin' (expected 28)"


**# Summary
capture frame drop srcA
capture frame drop srcB
capture frame drop srcC
local pass_count = $TFN_PASS
local fail_count = $TFN_FAIL
display "RESULT: test_tvmerge_frame_native tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "tvmerge frame-native failures:$TFN_FAILED"
    exit 1
}
