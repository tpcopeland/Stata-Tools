*! _dataqa_unmerged Version 2.1.0  2026/11/16
*! Worker shards of a QA ledger that hold rows the ledger does not
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (internal helper)

// 2.1.0 (final review M2).
//   _dataqa_unmerged, file(ledger) [run(label)]
//
// A job run with dataqa set worker(id) writes its ledger rows to the shard
// <stem>.shard-<id>.dta (_dataqa_shardpath), and dataqa merge folds the
// shards into the ledger.  Until then the ledger alone does not hold the
// run: a worker's failed gate or error row would be missed by a dataqa
// assert, report or export of the ledger.  This helper finds the shards of
// the ledger in its own directory (the <stem>.shard-<id>.dta naming that
// merge reads by default; a <stem>.shard-<id>.flow.dta flow file is not a
// shard) and counts, per shard, its rows of run() (of every run when run()
// is empty) that the ledger does not hold.
//
// A shard row is held when the ledger has a row of the same worker equal
// to it in every column the shard has, seq aside (merge renumbers seq and
// changes nothing else); rows are matched one to one, so a shard row
// written twice needs two ledger rows.  A merged shard therefore counts as
// merged for as long as the ledger keeps its rows, and counts again when
// its worker writes new rows (a rerun) or the ledger loses them (dataqa set
// replace): merge never deletes or marks a shard, the comparison is made
// on the content every time.  A file that has the shard name but cannot be
// read as a shard (no run or worker column) counts as unmerged, with all
// its rows: assert must not pass over a file it cannot read.
//
// In a dataqa set worker() session the helper does nothing (r(n_shards) 0):
// a worker reads its own shard, as designed.  Shards written to another
// directory with sharddir() are not seen here (the main session has no
// sharddir(); dataqa set refuses it without worker()); merge them with
// dataqa merge, from().
//
// Returns r(n_shards) (shards holding unmerged rows), r(n_rows) (those
// rows), r(workers) (their ids, as the file names carry them, sorted).
program define _dataqa_unmerged, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _l_made = 0
    local _s_made = 0
    local nsh = 0
    local nrows = 0
    local wl ""
    tempname L S
    capture noisily {
        syntax , FILE(string) [RUN(string)]
        _datamap_dqdefaults
        local _wk "`r(worker)'"
        if "`_wk'" == "" {
            // the shard file names of this ledger in its directory
            _dataqa_shardpath `"`file'"', worker(x)
            local stem `"`r(stem)'"'
            mata: _dataqa_umdir(st_local("file"))
            if `"`sdir'"' == "" local sdir "."
            local cand : dir `"`sdir'"' files `"`stem'.shard-*.dta"', respectcase
            local nf = 0
            foreach f of local cand {
                mata: st_local("_ok", strofreal(_dataqa_umname(st_local("f"), st_local("stem"))))
                if !`_ok' continue
                local ++nf
                local f`nf' `"`sdir'/`f'"'
                mata: st_local("w`nf'", _dataqa_umid(st_local("f"), st_local("stem")))
            }
            if `nf' > 0 {
                // the ledger's rows of the run, as the asserting call reads
                // them before any phase() selection
                frame create `L'
                local _l_made = 1
                local _lhas = 0
                capture confirm file `"`file'"'
                if !_rc {
                    frame `L' {
                        quietly use `"`file'"', clear
                        capture confirm string variable run, exact
                        if !_rc & `"`macval(run)'"' != "" {
                            mata: st_dropobsif(st_sdata(., "run") :!= st_local("run"))
                        }
                        capture confirm string variable worker, exact
                        if !_rc local _lhas = 1
                    }
                }
                frame create `S'
                local _s_made = 1
                forvalues i = 1/`nf' {
                    local _miss = 0
                    frame `S' {
                        capture quietly use `"`f`i''"', clear
                        if _rc local _miss = -1
                        else {
                            capture confirm string variable run, exact
                            local _r1 = _rc
                            capture confirm string variable worker, exact
                            if _rc | `_r1' local _miss = -1
                        }
                        if `_miss' == 0 & `"`macval(run)'"' != "" {
                            mata: st_dropobsif(st_sdata(., "run") :!= st_local("run"))
                        }
                        if `_miss' == -1 {
                            // not readable as a shard: every row counts
                            capture describe using `"`f`i''"', short
                            local _miss = cond(_rc, 1, max(r(N), 1))
                        }
                        else if _N > 0 {
                            if `_lhas' mata: st_local("_miss", strofreal(_dataqa_umcount(st_local("L"))))
                            else local _miss = _N
                        }
                    }
                    if `_miss' > 0 {
                        local ++nsh
                        local nrows = `nrows' + `_miss'
                        local wl "`wl' `w`i''"
                    }
                }
            }
        }
    }
    local rc = _rc
    if `_s_made' capture frame drop `S'
    if `_l_made' capture frame drop `L'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return scalar n_shards = `nsh'
    return scalar n_rows = `nrows'
    local wl : list sort wl
    return local workers "`wl'"
end

capture mata: mata drop _dataqa_umdir()
capture mata: mata drop _dataqa_umname()
capture mata: mata drop _dataqa_umid()
capture mata: mata drop _dataqa_umcount()
capture mata: mata drop _dataqa_umkeys()
mata:
// the directory of path f in local sdir
void _dataqa_umdir(string scalar f)
{
	string scalar d, b
	pathsplit(f, d, b)
	st_local("sdir", d)
}
// the id part of <stem>.shard-<id>.dta, "" when f is not of that form
string scalar _dataqa_umid(string scalar f, string scalar stem)
{
	string scalar pre
	pre = stem + ".shard-"
	if (substr(f, 1, strlen(pre)) != pre) return("")
	if (substr(f, -4, 4) != ".dta") return("")
	return(substr(f, strlen(pre) + 1, strlen(f) - strlen(pre) - 4))
}
// 1 when f is <stem>.shard-<id>.dta with a valid id (dataqa merge's rule)
real scalar _dataqa_umname(string scalar f, string scalar stem)
{
	string scalar w
	w = _dataqa_umid(f, stem)
	if (strlen(w) < 1 | strlen(w) > 32) return(0)
	return(regexm(w, "^[A-Za-z0-9_-]+$"))
}
// one text key per row of the current frame over the columns c: a string
// as it is, a number as its exact %21x text, a column of the other kind in
// one frame than the other gives a key that matches nothing
string colvector _dataqa_umkeys(string rowvector c)
{
	string colvector k
	real scalar j
	// no rows (a ledger with no row of the run): no keys; st_data() of
	// zero rows does not conform to the column of keys
	if (st_nobs() == 0) return(J(0, 1, ""))
	k = J(st_nobs(), 1, "")
	for (j = 1; j <= cols(c); j++) {
		if (st_isstrvar(c[j])) k = k :+ char(31) :+ "s" :+ st_sdata(., c[j])
		else k = k :+ char(31) :+ "n" :+ strofreal(st_data(., c[j]), "%21x")
	}
	return(k)
}
// rows of the shard in the current frame that frame lf (the ledger) does
// not hold: matched one to one on every shard column but seq, which must
// be a ledger column too (a column the ledger lacks holds nothing)
real scalar _dataqa_umcount(string scalar lf)
{
	string scalar cur
	string rowvector cl
	string colvector sk, lk
	real scalar i, n, miss, j
	transmorphic A
	cur = st_framecurrent()
	cl = J(1, 0, "")
	for (j = 1; j <= st_nvar(); j++) {
		if (st_varname(j) != "seq") cl = cl, st_varname(j)
	}
	sk = _dataqa_umkeys(cl)
	n = rows(sk)
	st_framecurrent(lf)
	for (j = 1; j <= cols(cl); j++) {
		if (_st_varindex(cl[j]) >= .) {
			st_framecurrent(cur)
			return(n)
		}
	}
	lk = _dataqa_umkeys(cl)
	st_framecurrent(cur)
	A = asarray_create()
	asarray_notfound(A, 0)
	for (i = 1; i <= rows(lk); i++) asarray(A, lk[i], asarray(A, lk[i]) + 1)
	miss = 0
	for (i = 1; i <= n; i++) {
		if (asarray(A, sk[i]) > 0) asarray(A, sk[i], asarray(A, sk[i]) - 1)
		else miss++
	}
	return(miss)
}
end
