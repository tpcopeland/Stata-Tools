*! _dataqa_shardpath Version 2.1.0  2026/11/16
*! The per-worker shard file that stands in for a QA ledger (dataqa set worker())
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// 2.1.0 (F12).  A Stata job run with dataqa set worker(id) never writes the
// shared ledger: every ledger write of that session (dataprobe ledger(), the
// session ledger, error rows, dataqa flow report) goes to the shard
//     <dir>/<stem>.shard-<id>.dta
// where <stem> is the ledger's file name with a final .dta removed and <dir>
// is sharddir() when given, else the ledger's own directory.  Jobs with
// different ids therefore never open the same file.  dataqa merge folds the
// shards into the ledger.  The id is a file-name token: 1 to 32 characters,
// each a letter, digit, underscore or hyphen.
//
//   _dataqa_shardpath "ledger", worker(id) [sharddir(dir)]
//       r(file)  the shard path   r(stem)  <stem>   r(worker)  id
program define _dataqa_shardpath, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax anything(name=file id="ledger") , WORKER(string) [SHARDdir(string)]
        mata: st_local("ok", strofreal(_dataqa_wtoken(st_local("worker"))))
        if !`ok' {
            display as error "worker() must be 1 to 32 letters, digits, underscores or hyphens"
            exit 198
        }
        mata: _dataqa_shardname(st_local("file"), st_local("worker"), st_local("sharddir"))
        return local file `"`_sf'"'
        return local stem `"`_ss'"'
        return local worker "`worker'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture mata: mata drop _dataqa_wtoken()
capture mata: mata drop _dataqa_shardname()
mata:
// 1 when s is a worker id: 1-32 of [A-Za-z0-9_-]
real scalar _dataqa_wtoken(string scalar s)
{
	if (strlen(s) < 1 | strlen(s) > 32) return(0)
	return(regexm(s, "^[A-Za-z0-9_-]+$"))
}
// the shard of ledger f for worker w, in directory d (else f's directory):
// sets _sf (path) and _ss (stem)
void _dataqa_shardname(string scalar f, string scalar w, string scalar d)
{
	string scalar dir, base, stem
	// the path as passed, without its quotes, plain or compound
	if (substr(f, 1, 2) == char(96) + char(34) & substr(f, -2, 2) == char(34) + char(39)) f = substr(f, 3, strlen(f) - 4)
	f = subinstr(f, char(34), "")
	pathsplit(f, dir, base)
	stem = base
	if (strlower(substr(stem, -4, 4)) == ".dta" & strlen(stem) > 4) stem = substr(stem, 1, strlen(stem) - 4)
	if (substr(d, 1, 2) == char(96) + char(34) & substr(d, -2, 2) == char(34) + char(39)) d = substr(d, 3, strlen(d) - 4)
	d = subinstr(d, char(34), "")
	if (d != "") dir = d
	st_local("_ss", stem)
	if (dir != "" & substr(dir, -1, 1) != "/" & substr(dir, -1, 1) != char(92)) dir = dir + "/"
	st_local("_sf", dir + stem + ".shard-" + w + ".dta")
}
end
