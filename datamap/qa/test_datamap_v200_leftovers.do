*! test_datamap_v200_leftovers.do Version 1.0.0  2026/11/10
*! datamap 2.0.0 Phase 4 leftovers: the maskrare byfreq by() run time, the
*! dataprobe target messages, the multi-statistic [excluded] cell and the
*! Linkage names of a file listed twice
*! Author: Timothy P Copeland, Karolinska Institutet
*
*   T1  dataprobe, maskrare byfreq by(g) with a by() group under 5 rows beside
*       a 1,200-value identifier finishes within 60 seconds (the linked-count
*       audit tried L tries per count, L^2 per table: minutes before
*       2026-11-10, on 1.10.6 too); the same under safe; the small group
*       is pooled and has no byfreq table
*   T2  dataprobe targets: the same-frame message has no stray apostrophe;
*       diff() and compare() naming the current frame stop rc 198 before any
*       output (diff(default) listed a tempvar as dropped); makespec() and
*       saving() into a missing folder stop rc 603 before any output
*       (makespec() failed only after the profile had printed)
*   T3  groupstat() with several statistics: an excluded variable's cell
*       reads [excl.] inside its 10-wide column ([excluded] ran into the
*       next cell)
*   T4  datamap Linkage: a file listed twice in filelist() is named by its
*       path and section number each time, and two files of one name in two
*       folders by their paths (the last of a pair read as a bare name)
*   T5  directory() and recursive document datasets in name order (2026-11-10:
*       file-system order put rx before person on tmpfs, so the section
*       numbers and the Linkage row differed from one machine to the next)
* Logs are read through Mata (_v2l_slurp), never a Stata macro reader.
version 16.0
clear all
set processors 1
set linesize 255
capture log close _all
log using "test_datamap_v200_leftovers.log", replace text name(main)
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
tempfile base
local work "`base'_v200lwork"
capture mkdir "`work'"
capture mkdir "`work'/plus"
capture mkdir "`work'/personal"
capture mkdir "`work'/run"
mata: assert(direxists(st_local("work") + "/plus") & direxists(st_local("work") + "/run"))
local oldplus : sysdir PLUS
local oldpersonal : sysdir PERSONAL
sysdir set PLUS "`work'/plus"
sysdir set PERSONAL "`work'/personal"
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace
discard
local tests = 0
local pass = 0
local fail = 0
local cwd0 "`c(pwd)'"
macro drop DATAMAP_DQ

capture mata: mata drop _v2l_slurp()
capture mata: mata drop _v2l_in()
mata:
void _v2l_slurp(string scalar path, string scalar dst)
{
	real scalar fh
	string scalar s, l
	fh = fopen(path, "r")
	s = ""
	while ((l = fget(fh)) != J(0, 0, "")) s = s + l + char(10)
	fclose(fh)
	st_local(dst, s)
}
// local t holds needle when want is 1, does not when 0
void _v2l_in(string scalar needle, real scalar want)
{
	if ((strpos(st_local("t"), needle) > 0) != want) {
		errprintf("text check failed (want %g): %s\n", want, needle)
		exit(9)
	}
}
end

**# T1 maskrare byfreq by() with a small group beside an identifier
capture noisily {
    quietly cd "`work'/run"
    clear
    set obs 1200
    generate str7 pnr_str = "P" + string(100000 + _n, "%06.0f")
    generate byte sex = 1 + mod(_n, 2)
    label define t1sex 1 "Male" 2 "Female"
    label values sex t1sex
    generate byte grp = 1 + mod(_n, 3)
    replace grp = 9 in 1/3
    label define t1grp 1 "A" 2 "B" 3 "C" 9 "RARENINE"
    label values grp t1grp
    foreach o in "maskrare" "safe" {
        timer clear 71
        timer on 71
        capture log close t1
        log using t1.log, replace text name(t1)
        dataprobe pnr_str sex grp, `o' byfreq by(grp)
        local m = r(masked)
        log close t1
        timer off 71
        quietly timer list 71
        local secs = r(t71)
        display "T1 `o': `secs' s"
        assert `secs' < 60
        assert `m' == 1
        mata: _v2l_slurp("t1.log", "t")
        mata: _v2l_in("GROUPWISE FREQUENCIES", 1)
        mata: _v2l_in("by group RARENINE", 0)
        mata: _v2l_in("by group C:", 1)
        mata: _v2l_in("ran out of budget", 0)
    }
}
local rc = _rc
capture log close t1
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: T1 maskrare byfreq by() with a group under 5 rows finishes in time (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: T1 maskrare byfreq by() with a group under 5 rows finishes in time"
}

**# T2 dataprobe target messages, before any output
capture noisily {
    quietly cd "`work'/run"
    capture mkdir t2
    quietly cd t2
    capture erase x.do
    sysuse auto, clear
    foreach call in "snapshot(sn2) saving(sn2)|198|saving() and snapshot() name the same frame sn2" ///
        "diff(default)|198|diff(): default is the current frame; name a baseline frame or file" ///
        "compare(default)|198|compare(): default is the current frame; name a baseline frame or file" ///
        "makespec(nofolder_t2/x.do)|603|makespec(): folder nofolder_t2 not found" ///
        "makespec(nofolder_t2/x.dta)|603|makespec(): folder nofolder_t2 not found" ///
        "saving(nofolder_t2/x.dta)|603|saving(): folder nofolder_t2 not found" {
        gettoken o rest : call, parse("|")
        gettoken bar rest : rest, parse("|")
        gettoken wrc rest : rest, parse("|")
        local msg = substr(`"`rest'"', 2, .)
        capture log close t2
        log using t2.log, replace text name(t2)
        capture noisily dataprobe price mpg, `o'
        local crc = _rc
        log close t2
        if `crc' != `wrc' {
            display as error "`o': rc `crc', want `wrc'"
            exit 9
        }
        mata: _v2l_slurp("t2.log", "t")
        * the whole message line: nothing after it (sn2' had an apostrophe)
        mata: _v2l_in(char(10) + st_local("msg") + char(10), 1)
        mata: _v2l_in("QUICK REFERENCE", 0)
        mata: _v2l_in(" obs, ", 0)
        mata: _v2l_in("__0", 0)
    }
    * the folder check leaves no folder behind, and a target in an existing
    * folder still works
    mata: assert(!direxists("nofolder_t2"))
    quietly dataprobe price mpg, makespec(./x.do)
    confirm file x.do
    * diff() from another frame may name default
    frame create t2other
    frame t2other {
        sysuse auto, clear
        quietly dataprobe price mpg, diff(default)
        assert r(diff_changed) == 0
    }
    frame drop t2other
}
local rc = _rc
capture log close t2
capture frame drop t2other
capture frame drop sn2
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: T2 dataprobe target messages, before any output (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: T2 dataprobe target messages, before any output"
}

**# T3 groupstat() with several statistics: [excl.] in its column
capture noisily {
    quietly cd "`work'/run"
    sysuse auto, clear
    capture log close t3
    log using t3.log, replace text name(t3)
    dataprobe price mpg foreign, gatesonly groupstat(mean median n: price, by(foreign)) exclude(price)
    log close t3
    mata: _v2l_slurp("t3.log", "t")
    mata: _v2l_in("  Group                 mean    median         n", 1)
    mata: _v2l_in("  Domestic           [excl.]   [excl.]   [excl.]", 1)
    mata: _v2l_in("  pooled             [excl.]   [excl.]   [excl.]", 1)
    mata: _v2l_in("][", 0)
    * the one-statistic table keeps [excluded] (13-wide cells)
    capture log close t3
    log using t3b.log, replace text name(t3)
    dataprobe price mpg foreign, gatesonly groupstat(mean price, by(foreign)) exclude(price)
    log close t3
    mata: _v2l_slurp("t3b.log", "t")
    mata: _v2l_in("[excluded]", 1)
    mata: _v2l_in("[excl.]", 0)
}
local rc = _rc
capture log close t3
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: T3 groupstat() several statistics: [excl.] in its column (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: T3 groupstat() several statistics: [excl.] in its column"
}

**# T4 Linkage names: a file listed twice, one name in two folders
capture noisily {
    quietly cd "`work'/run"
    capture mkdir t4a
    capture mkdir t4b
    clear
    set obs 10
    generate long id = _n
    quietly save t4a/f, replace
    replace id = ceil(_n / 2)
    quietly save t4b/f, replace
    capture erase t4.md
    datamap, filelist(t4a/f t4b/f t4a/f) output(t4.md)
    mata: _v2l_slurp("t4.md", "t")
    mata: _v2l_in("| " + char(96) + "id" + char(96) + " | t4a/f.dta (section 1), t4b/f.dta, t4a/f.dta (section 3) | long | t4a/f.dta (section 1) yes; t4b/f.dta no; t4a/f.dta (section 3) yes | t4a/f.dta (section 1) 1:m t4b/f.dta; t4a/f.dta (section 1) 1:1 t4a/f.dta (section 3); t4b/f.dta m:1 t4a/f.dta (section 3) |  |", 1)
    * the file is documented twice, as before
    mata: _v2l_in("## 1. f" + char(10), 1)
    mata: _v2l_in("## 3. f" + char(10), 1)
    * two names in two folders: both by their paths
    capture erase t4c.md
    datamap, filelist(t4a/f t4b/f) output(t4c.md)
    mata: _v2l_slurp("t4c.md", "t")
    mata: _v2l_in("| " + char(96) + "id" + char(96) + " | t4a/f.dta, t4b/f.dta | long | t4a/f.dta yes; t4b/f.dta no | t4a/f.dta 1:m t4b/f.dta |  |", 1)
    mata: _v2l_in("(section", 0)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: T4 Linkage names of a file listed twice and of one name in two folders (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: T4 Linkage names of a file listed twice and of one name in two folders"
}

**# T5 directory(): datasets in name order, not file-system order
capture noisily {
    quietly cd "`work'/run"
    capture mkdir t5d
    capture mkdir t5d/zsub
    capture mkdir t5d/asub
    clear
    set obs 6
    generate long id = _n
    forvalues i = 12(-1)1 {
        local nm = "f" + string(`i', "%02.0f")
        quietly save "t5d/`nm'", replace
    }
    quietly save t5d/zsub/z1, replace
    quietly save t5d/asub/a1, replace
    capture erase t5.md
    datamap, directory(t5d) output(t5.md) compact
    mata: _v2l_slurp("t5.md", "t")
    forvalues i = 1/12 {
        local nm = "f" + string(`i', "%02.0f")
        mata: _v2l_in("## `i'. `nm'" + char(10), 1)
    }
    * recursive: the folder's files, then subfolders in name order
    capture erase t5r.md
    datamap, directory(t5d) recursive output(t5r.md) compact
    mata: _v2l_slurp("t5r.md", "t")
    mata: _v2l_in("## 1. f01" + char(10), 1)
    mata: _v2l_in("## 13. a1" + char(10), 1)
    mata: _v2l_in("## 14. z1" + char(10), 1)
}
local rc = _rc
quietly cd "`cwd0'"
local ++tests
if `rc' {
    local ++fail
    display as error "FAIL: T5 directory() documents datasets in name order (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: T5 directory() documents datasets in name order"
}

macro drop DATAMAP_DQ
sysdir set PLUS "`oldplus'"
sysdir set PERSONAL "`oldpersonal'"
display "RESULT: test_datamap_v200_leftovers tests=`tests' pass=`pass' fail=`fail'"
log close main
if `fail' exit 1
