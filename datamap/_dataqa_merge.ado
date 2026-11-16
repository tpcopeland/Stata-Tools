*! _dataqa_merge Version 2.1.0  2026/11/16
*! dataqa merge: fold per-worker ledger shards into one QA ledger
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// 2.1.0 (F12).
//   dataqa merge, into(ledger) [from(dir | pattern) run(label) replace]
//
// Shards are the files jobs set with dataqa set worker() write in place of
// the ledger (_dataqa_shardpath): <stem>.shard-<id>.dta.  Without from() the
// shards of into() are read from into()'s directory; from(dir) reads them
// from dir; any other from() is a file pattern (* and ?) whose every match
// must be a shard.  Every shard is checked before anything is written:
//   - its variables are exactly the ledger columns plus worker, of the
//     ledger's types (r(610) naming the file and variable otherwise);
//   - its worker column is one valid id on every row, the id its file name
//     carries (*.shard-<id>.dta; r(610)), so a copied or renamed shard
//     cannot pass as another worker's;
//   - no two shards hold the same worker id (r(459)), and the ledger holds
//     no row of that worker in a run of the shard, which would mean the
//     shard was merged before (r(459); replace drops those rows first);
//   - a variable the ledger and a shard share has the same type, string or
//     numeric (r(610)).
// Each shard's line names its worker and the runs it holds, so a stale
// shard of an earlier run is seen; run() folds in only that run's rows
// (the others are counted as left out, a shard with none is skipped).
// A shard with no rows is skipped with a note (r(2000) when all are).
// The ledger's rows come first, then each shard in worker-id order (sorted
// as text), each shard's rows in the order the worker wrote them.  seq is
// renumbered per run so that, within a run, the calls follow that order:
// a shard's calls take the numbers after the largest seq the run already
// has, in their own order; dataqa report, assert, export and compare
// (latest call per gate) then read the merged run as one run, except that
// a call supersedes only rows of its own worker (_dataqa_latest): when two
// workers ran the same gate both rows stand, and a failure in either counts.  The merged
// ledger is built and checked in a frame and written by one save; a
// failure leaves into() as it was.  A ledger written by 2.0.0 (no phase or
// worker column) can be the target: its rows read as phase "" and worker "".
program define _dataqa_merge, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _m_made = 0
    local _s_made = 0
    tempname M S
    tempfile part
    capture noisily {
        syntax , INTO(string) [FROM(string) RUN(string) REPLACE]
        local _rungiven = (`"`macval(run)'"' != "")
        mata: st_local("into", strtrim(subinstr(st_local("into"), char(34), "")))
        mata: st_local("from", strtrim(subinstr(st_local("from"), char(34), "")))
        if `"`into'"' == "" {
            display as error "dataqa merge: into() names the ledger the shards are folded into"
            exit 198
        }
        _datamap_validate_path `"`into'"', option(into())
        mata: st_local("_ext", pathsuffix(st_local("into")))
        if `"`_ext'"' == "" local into `"`into'.dta"'
        mata: st_local("_ishow", _dataqa_mshow(st_local("into")))
        // the shard file list
        _dataqa_shardpath `"`into'"', worker(x)
        local stem `"`r(stem)'"'
        local filt 1
        if `"`from'"' == "" {
            mata: _dataqa_msplit(st_local("into"))
            local glob `"`stem'.shard-*.dta"'
        }
        else {
            _datamap_validate_path `"`from'"', option(from())
            mata: st_local("_isdir", strofreal(direxists(st_local("from"))))
            if `_isdir' {
                local sdir `"`from'"'
                local glob `"`stem'.shard-*.dta"'
            }
            else {
                mata: _dataqa_msplit(st_local("from")); st_local("glob", pathbasename(st_local("from")))
                local filt 0
            }
        }
        if `"`sdir'"' == "" local sdir "."
        local cand : dir `"`sdir'"' files `"`glob'"', respectcase
        local nf = 0
        foreach f of local cand {
            // the shard name rule: <stem>.shard-<id>.dta, nothing else (a
            // flow file <stem>.shard-<id>.flow.dta is not a shard)
            if `filt' {
                mata: st_local("_ok", strofreal(_dataqa_mname(st_local("f"), st_local("stem"))))
                if !`_ok' continue
            }
            local ++nf
            local f`nf' `"`sdir'/`f'"'
            local b`nf' `"`f'"'
        }
        if `nf' == 0 {
            display as error `"dataqa merge: no shard files of `macval(_ishow)' found"'
            exit 601
        }
        // the ledger columns a shard holds, with their kind (s string, n numeric)
        local cols "run:s stamp:s seq:n dataset:s scope:s family:s label:s variable:s grp:s kind:s status:s observed:s observed_num:n expected:s n_scope:n version:s signature:s masked:n mincell:n minshown:n obs_masked:n message:s phase:s worker:s"
        local nmcols ""
        foreach c of local cols {
            gettoken nm : c, parse(":")
            local nmcols "`nmcols' `nm'"
        }
        frame create `S'
        local _s_made = 1
        local wlist ""
        local nskip = 0
        local nk = 0
        forvalues i = 1/`nf' {
            mata: st_local("_fshow", _dataqa_mshow(st_local("f`i'")))
            // a shard with no rows (a worker's run cleared with replace and
            // not rewritten) holds nothing to merge: skipped with a note
            quietly describe using `"`f`i''"'
            if r(N) == 0 {
                display as text `"  note: `macval(_fshow)' has no rows; skipped"'
                local ++nskip
                continue
            }
            local ++nk
            local f`nk' `"`f`i''"'
            local b`nk' `"`b`i''"'
            frame `S' {
                quietly use `"`f`nk''"', clear
                foreach c of local cols {
                    gettoken nm kd : c, parse(":")
                    local kd = substr("`kd'", 2, 1)
                    capture confirm variable `nm', exact
                    if _rc {
                        display as error `"dataqa merge: `macval(_fshow)' is not a ledger shard (no variable `nm')"'
                        exit 610
                    }
                    if "`kd'" == "s" capture confirm string variable `nm', exact
                    else capture confirm numeric variable `nm', exact
                    if _rc {
                        display as error `"dataqa merge: `macval(_fshow)' is not a ledger shard (`nm' is not `=cond("`kd'" == "s", "a string", "a numeric")' variable)"'
                        exit 610
                    }
                }
                quietly ds
                local have `r(varlist)'
                local extra : list have - nmcols
                if "`extra'" != "" {
                    gettoken x1 : extra
                    display as error `"dataqa merge: `macval(_fshow)' is not a ledger shard (variable `x1' is not a ledger column)"'
                    exit 610
                }
                mata: st_local("w`nk'", _dataqa_mworker())
                if "`w`nk''" == "" {
                    display as error `"dataqa merge: `macval(_fshow)' is not a ledger shard (worker is not one valid id on every row)"'
                    exit 610
                }
                // the file name carries the id its rows hold: a shard
                // copied or renamed to another worker's name is refused
                mata: st_local("_nid", _dataqa_mnameid(st_local("b`nk'")))
                if "`_nid'" != "`w`nk''" {
                    if "`_nid'" == "" display as error `"dataqa merge: `macval(_fshow)' is not named as a shard (*.shard-{it:id}.dta)"'
                    else display as error `"dataqa merge: `macval(_fshow)' is named for worker `_nid' but its rows are worker `w`nk''"'
                    exit 610
                }
                // the runs the shard holds, shown so stale shards are seen;
                // with run() only that run's rows are folded in
                mata: st_local("_runs", _dataqa_mruns()); st_local("_nrun", strofreal(_dataqa_mnrun(st_local("run"))))
                local _nall = _N
                if `_rungiven' {
                    local _nout = `_nall' - `_nrun'
                    display as text "  worker `w`nk'': " as result "`_nrun'" as text " row(s) of the run, " ///
                        as result "`_nout'" as text " of other runs left out (runs: " as result `"`macval(_runs)'"' as text ")"
                }
                else display as text "  worker `w`nk'': " as result "`_nall'" as text " row(s) of run(s) " as result `"`macval(_runs)'"'
                if `_rungiven' {
                    if `_nrun' < `_nall' mata: st_dropobsif(st_sdata(., "run") :!= st_local("run"))
                    tempfile _p`nk'
                    quietly save `"`_p`nk''"'
                    local f`nk' `"`_p`nk''"'
                }
            }
            if `_rungiven' & `_nrun' == 0 {
                local --nk
                local ++nskip
                continue
            }
            if `: list posof "`w`nk''" in wlist' {
                display as error `"dataqa merge: two shards hold worker `w`nk''; `macval(_fshow)' duplicates another shard"'
                exit 459
            }
            local wlist "`wlist' `w`nk''"
        }
        if `nk' == 0 {
            if `_rungiven' display as error `"dataqa merge: no shard of `macval(_ishow)' holds rows of the run given in run(); nothing to merge"'
            else display as error `"dataqa merge: every shard of `macval(_ishow)' is empty; nothing to merge"'
            exit 2000
        }
        local nf = `nk'

        // worker-id order (as text)
        mata: st_local("_order", _dataqa_morder(tokens(st_local("wlist"))))
        // the target ledger
        frame create `M'
        local _m_made = 1
        local n_replaced = 0
        local exists = 0
        capture confirm file `"`into'"'
        if !_rc local exists = 1
        if `exists' {
            frame `M' {
                quietly use `"`into'"', clear
                foreach v in run seq dataset family label status observed observed_num kind {
                    capture confirm variable `v', exact
                    if _rc {
                        display as error `"dataqa merge: `macval(_ishow)' is not a dataprobe ledger (no variable `v')"'
                        exit 610
                    }
                }
                foreach c of local cols {
                    gettoken nm kd : c, parse(":")
                    local kd = substr("`kd'", 2, 1)
                    capture confirm variable `nm', exact
                    if _rc continue
                    if "`kd'" == "s" capture confirm string variable `nm', exact
                    else capture confirm numeric variable `nm', exact
                    if _rc {
                        display as error `"dataqa merge: `macval(_ishow)' and the shards differ in the type of `nm'; the schemas do not match"'
                        exit 610
                    }
                }
            }
        }
        local N0 = 0
        frame `M': local N0 = _N
        // rows of a shard's worker and run already in the ledger: merged before
        foreach i of local _order {
            frame `S' {
                quietly use `"`f`i''"', clear
            }
            frame `M' {
                capture confirm variable worker, exact
                if !_rc & _N > 0 {
                    mata: st_local("_dup", strofreal(_dataqa_mprior(st_local("S"), "`w`i''", 0)))
                    if `_dup' > 0 {
                        if "`replace'" == "" {
                            display as error `"dataqa merge: `macval(_ishow)' already holds `_dup' row(s) of worker `w`i'' in a run of its shard; the shard was merged before (add replace to replace those rows)"'
                            exit 459
                        }
                        mata: st_local("_dup", strofreal(_dataqa_mprior(st_local("S"), "`w`i''", 1)))
                        local n_replaced = `n_replaced' + `_dup'
                    }
                }
            }
        }
        // fold each shard in, worker by worker
        local n_added = 0
        foreach i of local _order {
            frame `S' {
                quietly use `"`f`i''"', clear
                local n_added = `n_added' + _N
                quietly generate byte _dqm_new = 1
                quietly save `"`part'"', replace
            }
            frame `M' {
                capture confirm variable _dqm_new, exact
                if _rc quietly generate byte _dqm_new = 0
                quietly append using `"`part'"'
                quietly replace _dqm_new = 0 if missing(_dqm_new)
                mata: _dataqa_mreseq()
                quietly replace _dqm_new = 0
            }
        }
        frame `M' {
            quietly drop _dqm_new
            foreach v in phase worker {
                capture confirm variable `v', exact
                if !_rc quietly replace `v' = "" if missing(`v')
            }
            if `exists' quietly save `"`into'"', replace
            else quietly save `"`into'"'
            local NT = _N
        }
        local wshow ""
        foreach i of local _order {
            local wshow "`wshow' `w`i''"
        }
        local wshow = strtrim("`wshow'")
        display as text "dataqa merge: " as result "`nf'" as text " shard(s) of worker(s) " ///
            as result "`wshow'" as text " folded into " as result `"`macval(_ishow)'"' ///
            as text ": " as result "`n_added'" as text " row(s) added" ///
            _c
        if `n_replaced' display as text ", " as result "`n_replaced'" as text " row(s) of earlier merges replaced" _c
        display ""
        return local into `"`into'"'
        return local workers "`wshow'"
        return scalar n_shards = `nf'
        return scalar n_skipped = `nskip'
        return scalar n_added = `n_added'
        return scalar n_replaced = `n_replaced'
        return scalar N = `NT'
    }
    local rc = _rc
    if `_s_made' capture frame drop `S'
    if `_m_made' capture frame drop `M'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture mata: mata drop _dataqa_mshow()
capture mata: mata drop _dataqa_msplit()
capture mata: mata drop _dataqa_mname()
capture mata: mata drop _dataqa_mworker()
capture mata: mata drop _dataqa_morder()
capture mata: mata drop _dataqa_mprior()
capture mata: mata drop _dataqa_mreseq()
capture mata: mata drop _dataqa_mnameid()
capture mata: mata drop _dataqa_mruns()
capture mata: mata drop _dataqa_mnrun()
mata:
// a file name as SMCL-inert text (as dataqa's _dataqa_show)
string scalar _dataqa_mshow(string scalar s)
{
	string scalar out
	out = subinstr(s, "{", "{c -(}")
	out = subinstr(out, char(96), "{char 96}")
	out = subinstr(out, char(34), "{char 34}")
	out = subinstr(out, char(36), "{char 36}")
	return(out)
}
// the directory of path f in local sdir
void _dataqa_msplit(string scalar f)
{
	string scalar d, b
	pathsplit(f, d, b)
	st_local("sdir", d)
}
// 1 when f is <stem>.shard-<id>.dta with a valid id
real scalar _dataqa_mname(string scalar f, string scalar stem)
{
	string scalar pre, w
	pre = stem + ".shard-"
	if (substr(f, 1, strlen(pre)) != pre) return(0)
	if (substr(f, -4, 4) != ".dta") return(0)
	w = substr(f, strlen(pre) + 1, strlen(f) - strlen(pre) - 4)
	if (strlen(w) < 1 | strlen(w) > 32) return(0)
	return(regexm(w, "^[A-Za-z0-9_-]+$"))
}
// the worker id a shard's file name carries, <anything>.shard-<id>.dta,
// "" when the name is not a shard's
string scalar _dataqa_mnameid(string scalar b)
{
	string scalar w
	real scalar p
	if (substr(b, -4, 4) != ".dta") return("")
	p = strrpos(b, ".shard-")
	if (p == 0) return("")
	w = substr(b, p + 7, strlen(b) - p - 6 - 4)
	if (strlen(w) < 1 | strlen(w) > 32) return("")
	if (!regexm(w, "^[A-Za-z0-9_-]+$")) return("")
	return(w)
}
// the distinct runs of the shard in memory, as SMCL-inert text ("" shown
// as (none)), space separated
string scalar _dataqa_mruns()
{
	string colvector u
	string scalar out
	real scalar i
	u = uniqrows(st_sdata(., "run"))
	out = ""
	for (i = 1; i <= rows(u); i++) out = out + (i > 1 ? " " : "") + (u[i] == "" ? "(none)" : _dataqa_mshow(u[i]))
	return(out)
}
// rows of the shard in memory whose run is r
real scalar _dataqa_mnrun(string scalar r)
{
	return(sum(st_sdata(., "run") :== r))
}
// the one worker id of the shard in memory, "" when it is not one valid id
// on every row (or the shard has no rows)
string scalar _dataqa_mworker()
{
	string colvector w
	w = st_sdata(., "worker")
	if (rows(w) == 0) return("")
	if (any(w :!= w[1])) return("")
	if (strlen(w[1]) < 1 | strlen(w[1]) > 32) return("")
	if (!regexm(w[1], "^[A-Za-z0-9_-]+$")) return("")
	return(w[1])
}
// shard indices 1..n in worker-id order
string scalar _dataqa_morder(string rowvector w)
{
	real colvector o
	real scalar i
	string scalar out
	o = order(w', 1)
	out = ""
	for (i = 1; i <= rows(o); i++) out = out + (i > 1 ? " " : "") + strofreal(o[i])
	return(out)
}
// rows of the ledger in memory with worker w and a run the shard in frame
// sf holds; with drop, those rows are dropped.  Returns their number.
real scalar _dataqa_mprior(string scalar sf, string scalar w, real scalar drop)
{
	string scalar cur
	string colvector sr, lr, lw
	real colvector hit
	real scalar i
	transmorphic A
	cur = st_framecurrent()
	st_framecurrent(sf)
	sr = st_sdata(., "run")
	st_framecurrent(cur)
	A = asarray_create()
	for (i = 1; i <= rows(sr); i++) asarray(A, sr[i], 1)
	lr = st_sdata(., "run")
	lw = st_sdata(., "worker")
	hit = J(rows(lr), 1, 0)
	for (i = 1; i <= rows(lr); i++) hit[i] = (lw[i] == w & asarray_contains(A, lr[i]))
	if (drop & sum(hit)) st_dropobsif(hit)
	return(sum(hit))
}
// seq of the rows marked _dqm_new: per run, the run's largest seq among
// the other rows plus the dense rank of the row's own seq in its shard
void _dataqa_mreseq()
{
	string colvector r, kr
	real colvector s, nw, ns, u
	real scalar i, j, base
	transmorphic B, R, Q
	r = st_sdata(., "run")
	s = st_data(., "seq")
	nw = st_data(., "_dqm_new")
	B = asarray_create()
	R = asarray_create()
	Q = asarray_create()
	asarray_notfound(B, 0)
	for (i = 1; i <= rows(r); i++) {
		if (missing(s[i])) continue
		if (!nw[i]) {
			if (s[i] > asarray(B, r[i])) asarray(B, r[i], s[i])
		}
		else {
			if (asarray_contains(R, r[i])) asarray(R, r[i], asarray(R, r[i]) \ s[i])
			else asarray(R, r[i], s[i])
		}
	}
	kr = asarray_keys(R)
	for (i = 1; i <= rows(kr); i++) {
		u = uniqrows(asarray(R, kr[i]))
		base = asarray(B, kr[i])
		for (j = 1; j <= rows(u); j++) asarray(Q, kr[i] + char(0) + strofreal(u[j], "%20.0f"), base + j)
	}
	ns = s
	for (i = 1; i <= rows(r); i++) {
		if (!nw[i] | missing(s[i])) continue
		ns[i] = asarray(Q, r[i] + char(0) + strofreal(s[i], "%20.0f"))
	}
	st_store(., "seq", ns)
}
end
