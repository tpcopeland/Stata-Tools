*! _asof_mata Version 0.1.0  2026/08/12
*! Mata engine for the asof join
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: internal Mata source (loaded by _asof_join)

version 16.0
capture mata: mata drop _asof_lower()
capture mata: mata drop _asof_upper()
capture mata: mata drop _asof_choose()
capture mata: mata drop _asof_scan_num()
capture mata: mata drop _asof_scan_str()
capture mata: mata drop _asof_scan()
capture mata: mata drop _asof_mata_present()

mata:
        real scalar _asof_lower(
            real colvector d,
            real scalar a,
            real scalar b,
            real scalar x,
            real scalar strict)
        {
            real scalar lo, hi, mid

            lo = a
            hi = b + 1
            while (lo < hi) {
                mid = floor((lo + hi) / 2)
                if (d[mid] < x | (strict & d[mid] == x)) lo = mid + 1
                else hi = mid
            }
            return(lo)
        }

        real scalar _asof_upper(
            real colvector d,
            real scalar a,
            real scalar b,
            real scalar x,
            real scalar strict)
        {
            real scalar lo, hi, mid

            lo = a
            hi = b + 1
            while (lo < hi) {
                mid = floor((lo + hi) / 2)
                if (d[mid] < x | (!strict & d[mid] == x)) lo = mid + 1
                else hi = mid
            }
            return(lo - 1)
        }

        real rowvector _asof_choose(
            real colvector d,
            real colvector ord,
            real scalar L,
            real scalar U,
            real scalar anchor,
            string scalar select_rule,
            string scalar tie_rule)
        {
            real scalar p, q, r, leftdate, rightdate, dl, dr, mindist
            real scalar c1, c2, ncan, pick, err
            real colvector candidates, candidate_ord

            err = 0
            candidates = J(0, 1, .)

            if (select_rule == "first") {
                q = _asof_upper(d, L, U, d[L], 0)
                candidates = (L::q)
            }
            else if (select_rule == "last") {
                q = _asof_lower(d, L, U, d[U], 0)
                candidates = (q::U)
            }
            else {
                p = _asof_lower(d, L, U, anchor, 0)
                dl = .
                dr = .
                if (p <= U) dr = abs(d[p] - anchor)
                if (p > L) dl = abs(d[p - 1] - anchor)
                mindist = min((dl, dr))

                if (dl == mindist) {
                    leftdate = d[p - 1]
                    q = _asof_lower(d, L, U, leftdate, 0)
                    r = _asof_upper(d, L, U, leftdate, 0)
                    candidates = candidates \ (q::r)
                }
                if (dr == mindist) {
                    rightdate = d[p]
                    q = _asof_lower(d, L, U, rightdate, 0)
                    r = _asof_upper(d, L, U, rightdate, 0)
                    candidates = candidates \ (q::r)
                }
            }

            ncan = rows(candidates)
            if (ncan == 1) return((candidates[1], 0, 0))
            if (tie_rule == "error") return((., 1, 459))

            candidate_ord = ord[candidates]
            if (tie_rule == "first") {
                c1 = min(candidate_ord)
                pick = candidates[selectindex(candidate_ord :== c1)[1]]
            }
            else if (tie_rule == "last") {
                c1 = max(candidate_ord)
                pick = candidates[selectindex(candidate_ord :== c1)[1]]
            }
            else if (tie_rule == "before") {
                c1 = min(d[candidates])
                c2 = min(select(candidate_ord, d[candidates] :== c1))
                pick = candidates[selectindex((d[candidates] :== c1) :&
                    (candidate_ord :== c2))[1]]
            }
            else {
                c1 = max(d[candidates])
                c2 = min(select(candidate_ord, d[candidates] :== c1))
                pick = candidates[selectindex((d[candidates] :== c1) :&
                    (candidate_ord :== c2))[1]]
            }
            return((pick, 1, err))
        }

        real rowvector _asof_scan_num(
            real colvector kid,
            real colvector anchor,
            real colvector rlo,
            real colvector rhi,
            real colvector eid,
            real colvector edate,
            real colvector eorder,
            string scalar direction,
            string scalar select_rule,
            string scalar tie_rule,
            real scalar winlo,
            real scalar winhi,
            real scalar scale,
            real colvector picks)
        {
            real scalar K, E, i, ie, e, ee, j, L, U, haslo, hashi
            real scalar lob, hib, lostrict, histrict, bound, strict
            real scalar nties, err, neligible
            real rowvector chosen
            real colvector diff, active

            K = rows(kid)
            E = rows(eid)
            diff = J(E + 1, 1, 0)
            nties = 0
            err = 0
            i = 1
            e = 1

            while (i <= K) {
                ie = i
                while (ie < K) {
                    if (kid[ie + 1] != kid[i]) break
                    ie++
                }

                while (e <= E) {
                    if (eid[e] >= kid[i]) break
                    e++
                }
                if (e > E) {
                    i = ie + 1
                    continue
                }
                if (eid[e] != kid[i]) {
                    i = ie + 1
                    continue
                }
                ee = e
                while (ee < E) {
                    if (eid[ee + 1] != eid[e]) break
                    ee++
                }

                for (j = i; j <= ie; j++) {
                    haslo = 0
                    hashi = 0
                    lostrict = 0
                    histrict = 0
                    lob = .
                    hib = .

                    if (!missing(winlo)) {
                        lob = anchor[j] + winlo * scale
                        haslo = 1
                    }
                    if (!missing(winhi)) {
                        hib = anchor[j] + winhi * scale
                        hashi = 1
                    }
                    if (!missing(rlo[j])) {
                        bound = rlo[j]
                        if (!haslo | bound > lob) {
                            lob = bound
                            lostrict = 0
                            haslo = 1
                        }
                    }
                    if (!missing(rhi[j])) {
                        bound = rhi[j]
                        if (!hashi | bound < hib) {
                            hib = bound
                            histrict = 0
                            hashi = 1
                        }
                    }

                    if (direction == "before" | direction == "onorbefore") {
                        bound = anchor[j]
                        strict = (direction == "before")
                        if (!hashi | bound < hib) {
                            hib = bound
                            histrict = strict
                            hashi = 1
                        }
                        else if (bound == hib) histrict = histrict | strict
                    }
                    else if (direction == "after" | direction == "onorafter") {
                        bound = anchor[j]
                        strict = (direction == "after")
                        if (!haslo | bound > lob) {
                            lob = bound
                            lostrict = strict
                            haslo = 1
                        }
                        else if (bound == lob) lostrict = lostrict | strict
                    }

                    L = e
                    U = ee
                    if (haslo) L = _asof_lower(edate, e, ee, lob, lostrict)
                    if (hashi) U = _asof_upper(edate, e, ee, hib, histrict)
                    if (L > U | L > ee | U < e) continue

                    diff[L] = diff[L] + 1
                    diff[U + 1] = diff[U + 1] - 1
                    chosen = _asof_choose(edate, eorder, L, U, anchor[j],
                        select_rule, tie_rule)
                    if (chosen[2]) nties++
                    if (chosen[3]) {
                        err = chosen[3]
                        break
                    }
                    picks[j] = chosen[1]
                }
                if (err) break
                e = ee + 1
                i = ie + 1
            }

            if (E == 0) neligible = 0
            else {
                active = runningsum(diff[1..E])
                neligible = sum(active :> 0)
            }
            return((neligible, nties, err))
        }

        real rowvector _asof_scan_str(
            string colvector kid,
            real colvector anchor,
            real colvector rlo,
            real colvector rhi,
            string colvector eid,
            real colvector edate,
            real colvector eorder,
            string scalar direction,
            string scalar select_rule,
            string scalar tie_rule,
            real scalar winlo,
            real scalar winhi,
            real scalar scale,
            real colvector picks)
        {
            real scalar K, E, i, ie, e, ee, j, L, U, haslo, hashi
            real scalar lob, hib, lostrict, histrict, bound, strict
            real scalar nties, err, neligible
            real rowvector chosen
            real colvector diff, active

            K = rows(kid)
            E = rows(eid)
            diff = J(E + 1, 1, 0)
            nties = 0
            err = 0
            i = 1
            e = 1

            while (i <= K) {
                ie = i
                while (ie < K) {
                    if (kid[ie + 1] != kid[i]) break
                    ie++
                }

                while (e <= E) {
                    if (eid[e] >= kid[i]) break
                    e++
                }
                if (e > E) {
                    i = ie + 1
                    continue
                }
                if (eid[e] != kid[i]) {
                    i = ie + 1
                    continue
                }
                ee = e
                while (ee < E) {
                    if (eid[ee + 1] != eid[e]) break
                    ee++
                }

                for (j = i; j <= ie; j++) {
                    haslo = 0
                    hashi = 0
                    lostrict = 0
                    histrict = 0
                    lob = .
                    hib = .

                    if (!missing(winlo)) {
                        lob = anchor[j] + winlo * scale
                        haslo = 1
                    }
                    if (!missing(winhi)) {
                        hib = anchor[j] + winhi * scale
                        hashi = 1
                    }
                    if (!missing(rlo[j])) {
                        bound = rlo[j]
                        if (!haslo | bound > lob) {
                            lob = bound
                            lostrict = 0
                            haslo = 1
                        }
                    }
                    if (!missing(rhi[j])) {
                        bound = rhi[j]
                        if (!hashi | bound < hib) {
                            hib = bound
                            histrict = 0
                            hashi = 1
                        }
                    }

                    if (direction == "before" | direction == "onorbefore") {
                        bound = anchor[j]
                        strict = (direction == "before")
                        if (!hashi | bound < hib) {
                            hib = bound
                            histrict = strict
                            hashi = 1
                        }
                        else if (bound == hib) histrict = histrict | strict
                    }
                    else if (direction == "after" | direction == "onorafter") {
                        bound = anchor[j]
                        strict = (direction == "after")
                        if (!haslo | bound > lob) {
                            lob = bound
                            lostrict = strict
                            haslo = 1
                        }
                        else if (bound == lob) lostrict = lostrict | strict
                    }

                    L = e
                    U = ee
                    if (haslo) L = _asof_lower(edate, e, ee, lob, lostrict)
                    if (hashi) U = _asof_upper(edate, e, ee, hib, histrict)
                    if (L > U | L > ee | U < e) continue

                    diff[L] = diff[L] + 1
                    diff[U + 1] = diff[U + 1] - 1
                    chosen = _asof_choose(edate, eorder, L, U, anchor[j],
                        select_rule, tie_rule)
                    if (chosen[2]) nties++
                    if (chosen[3]) {
                        err = chosen[3]
                        break
                    }
                    picks[j] = chosen[1]
                }
                if (err) break
                e = ee + 1
                i = ie + 1
            }

            if (E == 0) neligible = 0
            else {
                active = runningsum(diff[1..E])
                neligible = sum(active :> 0)
            }
            return((neligible, nties, err))
        }

        real rowvector _asof_scan(
            string scalar keyframe,
            string scalar eventframe,
            string scalar id,
            string scalar anchorvar,
            string scalar rlovar,
            string scalar rhivar,
            string scalar datevar,
            string scalar ordervar,
            string scalar pickvar,
            string scalar idtype,
            string scalar direction,
            string scalar select_rule,
            string scalar tie_rule,
            real scalar winlo,
            real scalar winhi,
            real scalar scale)
        {
            string scalar original
            real colvector anchor, rlo, rhi, edate, eorder, picks, kidnum, eidnum
            string colvector kidstr, eidstr
            real rowvector stats

            original = st_framecurrent()
            st_framecurrent(keyframe)
            anchor = st_data(., anchorvar)
            if (rlovar == "") rlo = J(rows(anchor), 1, .)
            else rlo = st_data(., rlovar)
            if (rhivar == "") rhi = J(rows(anchor), 1, .)
            else rhi = st_data(., rhivar)
            if (idtype == "numeric") kidnum = st_data(., id)
            else kidstr = st_sdata(., id)

            st_framecurrent(eventframe)
            edate = st_data(., datevar)
            eorder = st_data(., ordervar)
            if (idtype == "numeric") eidnum = st_data(., id)
            else eidstr = st_sdata(., id)

            picks = J(rows(anchor), 1, .)
            if (idtype == "numeric") {
                stats = _asof_scan_num(kidnum, anchor, rlo, rhi, eidnum,
                    edate, eorder, direction, select_rule, tie_rule,
                    winlo, winhi, scale, picks)
            }
            else {
                stats = _asof_scan_str(kidstr, anchor, rlo, rhi, eidstr,
                    edate, eorder, direction, select_rule, tie_rule,
                    winlo, winhi, scale, picks)
            }

            st_framecurrent(keyframe)
            st_store(., pickvar, picks)
            st_framecurrent(original)
            return(stats)
        }

void _asof_mata_present() {}

end
