*! _datamap_collect_link Version 2.0.0  2026/11/10
*! The key flag of each variable and the value-label definitions of a dataset
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

// _datamap_collect_link, varframe(v) vfirst(#) vlast(#) [exact(names)
//     dsframe(d) dsindex(#) labels excluded(names)]
//
// With the dataset in the current frame (datamap 2.0.0 Phase 3, F1 and I2,
// 2026-11-10):
//
// (1) key: for rows vfirst..vlast of the variables frame
//     (_datamap_post_metadata_rows), 1 when the variable's values identify
//     the observations, 0 when they do not, . when not determined.  Missing
//     values count as values, as -merge- counts them: two observations
//     with . (or two blanks) are a duplicate, . and .a are not.  Decided
//     from the frame's own counts (unique, unique_capped, missing, N) when
//     they settle it (with the distinct missing codes counted when two or
//     more missing values could each be a value of their own); otherwise
//     counted exactly (Mata, uniqrows, or one
//     pass over adjacent values when the data are sorted by the variable)
//     for the variables named in exact() -- datamap passes the names shared
//     by two or more input datasets (the linkage block) and the likely
//     identifiers -- and left . for the rest, so wide data pay nothing.
//     An excluded variable gets . (no statistic for it).  A dataset with
//     no observations: 1.
// (2) labels (with dsframe() dsindex()): the dataset's value labels and
//     their definitions into its datasets-frame row, vl_names (names,
//     space-separated) and vl_defs (each definition as value=text lines,
//     values in %21x, the definitions joined by char(29) in vl_names'
//     order).  A label attached only to excluded variables (excluded())
//     is left out: the classifier withholds an excluded variable's coding.
//     The linkage block compares the definitions of same-name labels
//     across datasets (_datamap_md_document).

capture mata: mata drop _datamap_lk_keys()
capture mata: mata drop _datamap_lk_exact()
capture mata: mata drop _datamap_lk_labels()
mata:
// (1); runs with the variables frame current, src the dataset's frame
void _datamap_lk_keys(string scalar src, real scalar vf, real scalar vl,
	string rowvector ex, string scalar sorted1)
{
	string matrix S
	real matrix D
	real colvector key, x
	real scalar i, N, nm, u, cp, isstr
	string scalar cur

	if (vf < 1 | vl < vf) return
	S = st_sdata((vf::vl), ("variable", "class", "storage_type"))
	D = st_data((vf::vl), ("N", "missing", "unique", "unique_capped"))
	key = J(rows(S), 1, .)
	cur = st_framecurrent()
	for (i = 1; i <= rows(S); i++) {
		if (S[i, 2] == "excluded") continue
		N = D[i, 1]
		nm = D[i, 2]
		u = D[i, 3]
		cp = D[i, 4]
		isstr = (substr(S[i, 3], 1, 3) == "str")
		if (missing(N)) continue
		if (N == 0) {
			key[i] = 1
			continue
		}
		// two blanks are one value twice
		if (isstr & nm >= 2) {
			key[i] = 0
			continue
		}
		if (!missing(u) & cp == 0 & !missing(nm)) {
			// u counts the distinct nonmissing values; at most nm more
			if (u + nm < N) {
				key[i] = 0
				continue
			}
			if (nm <= 1) {
				key[i] = (u + nm == N)
				continue
			}
			// u + nm == N with two or more missing: unique exactly when
			// the missing codes differ (. .a .b), counted over them alone
			if (!isstr) {
				st_framecurrent(src)
				x = st_data(., S[i, 1])
				st_framecurrent(cur)
				x = select(x, x :>= .)
				key[i] = (rows(uniqrows(x)) == rows(x))
				continue
			}
		}
		if (sum(ex :== S[i, 1]) == 0) continue
		st_framecurrent(src)
		key[i] = _datamap_lk_exact(S[i, 1], isstr, S[i, 1] == sorted1)
		st_framecurrent(cur)
	}
	st_store((vf::vl), "key", key)
}
// 1 when variable v of the current frame has no repeated value (missing
// values count as values); sorted: the data are sorted by v
real scalar _datamap_lk_exact(string scalar v, real scalar isstr, real scalar sorted)
{
	real colvector x
	string colvector s
	real scalar n
	n = st_nobs()
	if (n <= 1) return(1)
	if (isstr) {
		s = st_sdata(., v)
		if (sorted) return(sum(s[|2 \ n|] :== s[|1 \ n - 1|]) == 0)
		return(rows(uniqrows(s)) == n)
	}
	x = st_data(., v)
	if (sorted) return(sum(x[|2 \ n|] :== x[|1 \ n - 1|]) == 0)
	return(rows(uniqrows(x)) == n)
}
// (2); runs with the dataset's frame current, dsf the datasets frame
void _datamap_lk_labels(string scalar dsf, real scalar dsx, string rowvector ex)
{
	string rowvector nm, keep
	string colvector txt
	real colvector val
	string scalar defs, d, cur, lab
	real scalar j, k, inc, onex, nk
	real rowvector att

	stata("quietly label dir")
	nm = tokens(st_global("r(names)"))
	// a label is kept unless every variable carrying it is excluded
	keep = J(1, 0, "")
	defs = ""
	nk = 0
	for (j = 1; j <= cols(nm); j++) {
		inc = 1
		onex = 0
		att = J(1, 0, .)
		for (k = 1; k <= st_nvar(); k++) {
			lab = st_varvaluelabel(k)
			if (lab != nm[j]) continue
			if (sum(ex :== st_varname(k))) onex = 1
			else att = att, k
		}
		if (onex & cols(att) == 0) inc = 0
		if (!inc) continue
		st_vlload(nm[j], val, txt)
		d = (rows(val) ? invtokens((strofreal(val, "%21x") :+ "=" :+ txt)', char(10)) : "")
		keep = keep, nm[j]
		// a separator before every definition but the first kept
		defs = defs + (nk ? char(29) : "") + d
		nk++
	}
	cur = st_framecurrent()
	st_framecurrent(dsf)
	st_sstore(dsx, "vl_names", invtokens(keep))
	st_sstore(dsx, "vl_defs", defs)
	st_framecurrent(cur)
}
end

program define _datamap_collect_link, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , VARFrame(name) VFIRST(integer) VLAST(integer) ///
            [EXACT(string) DSFrame(name) DSINDEX(integer 0) LABels ///
            EXCLuded(string)]
        local _src = c(frame)
        local _s1 : sortedby
        gettoken _s1 : _s1
        frame `varframe': mata: _datamap_lk_keys("`_src'", `vfirst', `vlast', ///
            tokens(st_local("exact")), st_local("_s1"))
        if "`labels'" != "" {
            if "`dsframe'" == "" | `dsindex' < 1 {
                noisily display as error "_datamap_collect_link: labels requires dsframe() and dsindex()"
                exit 198
            }
            mata: _datamap_lk_labels("`dsframe'", `dsindex', tokens(st_local("excluded")))
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
