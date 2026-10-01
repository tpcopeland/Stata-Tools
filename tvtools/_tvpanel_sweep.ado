*! _tvpanel_sweep Version 1.17.7  2026/10/01
*! Active class and per-class cumulative exposure on a tvpanel grid in one sweep
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: utility (called internally by tvpanel)

/*
One pass per person over the panel grid, replacing a point-in-interval pair
join for the active class and a grid x class joinby, pair join, and reshape
for cumulative exposure.

Active class at a period start p: among episodes with start <= p <= stop, the
latest start wins and ties go to the highest class. Episodes enter a max-heap
keyed on (start, class) once started; stopped episodes are removed lazily when
they reach the root, which is valid because p only increases within a person.

Cumulative class-c days as of p: days of the person's class-c episode union
strictly before p. Each class keeps a pointer into its sorted union intervals:
completed intervals (stop < p) add their full length, and the interval in
progress (start < p <= stop) adds p - start.

Inputs (all numeric, sorted by the caller):
  current frame  id pstart          sorted by id, then ascending pstart
  eframe         id start stop cls  sorted by id start
  uframe         id cls start stop  sorted by id cls start (cumulative only)
Outputs written to the current frame: active (missing when no episode covers
p) followed by one days column per class in classes() order.
*/

version 16.0

capture mata: mata drop _tvp_sweep_core()
capture mata: mata drop _tvp_heap_gt()

* Compile under strict declarations and restore the caller setting on error too.
local _tvp_compile_strict = c(matastrict)
capture noisily mata:
mata set matastrict on

real scalar _tvp_heap_gt(real matrix E, real scalar a, real scalar b)
{
    if (E[a, 2] > E[b, 2]) return(1)
    if (E[a, 2] < E[b, 2]) return(0)
    return(E[a, 4] > E[b, 4])
}

void _tvp_sweep_core(string scalar gvars, string scalar ovars,
                     string scalar eframe, string scalar evars,
                     string scalar uframe, string scalar uvars,
                     real rowvector classes)
{
    string scalar cur
    real matrix G, E, U, O
    real colvector heap
    real rowvector cptr, cend, csum
    real scalar n, ne, nu, nc, i, ge, gi, id, ep, eb, ee, ea, up, cc
    real scalar hn, h, parent, left, right, best, swap, p, c, k

    cur = st_framecurrent()
    G = st_data(., tokens(gvars))
    st_framecurrent(eframe)
    E = st_data(., tokens(evars))
    st_framecurrent(cur)
    nc = cols(classes)
    if (nc > 0) {
        st_framecurrent(uframe)
        U = st_data(., tokens(uvars))
        st_framecurrent(cur)
    }
    else U = J(0, 4, .)

    n = rows(G)
    ne = rows(E)
    nu = rows(U)
    O = J(n, 1 + nc, 0)
    O[., 1] = J(n, 1, .)
    heap = J(max((ne, 1)), 1, .)
    ep = 1
    up = 1

    // Mata's logical operators do not short-circuit. Keep every bounds guard
    // outside the expression that performs the guarded subscript.
    i = 1
    while (i <= n) {
        id = G[i, 1]
        ge = i
        while (ge < n) {
            if (G[ge + 1, 1] == id) ge++
            else break
        }

        while (ep <= ne) {
            if (E[ep, 1] < id) ep++
            else break
        }
        eb = ep
        while (ep <= ne) {
            if (E[ep, 1] == id) ep++
            else break
        }
        ee = ep - 1

        cptr = J(1, nc, 0)
        cend = J(1, nc, -1)
        csum = J(1, nc, 0)
        if (nc > 0) {
            while (up <= nu) {
                if (U[up, 1] < id) up++
                else break
            }
            cc = 1
            while (up <= nu) {
                if (U[up, 1] != id) break
                while (cc <= nc) {
                    if (classes[cc] < U[up, 2]) cc++
                    else break
                }
                if (cc > nc) {
                    errprintf("_tvpanel_sweep: union class %g not in classes()\n", U[up, 2])
                    exit(498)
                }
                if (classes[cc] != U[up, 2]) {
                    errprintf("_tvpanel_sweep: union class %g not in classes()\n", U[up, 2])
                    exit(498)
                }
                if (cptr[cc] == 0) cptr[cc] = up
                cend[cc] = up
                up++
            }
        }

        hn = 0
        ea = eb
        for (gi = i; gi <= ge; gi++) {
            p = G[gi, 2]

            while (ea <= ee) {
                if (E[ea, 2] > p) break
                hn++
                heap[hn] = ea
                h = hn
                while (h > 1) {
                    parent = floor(h / 2)
                    if (!_tvp_heap_gt(E, heap[h], heap[parent])) break
                    swap = heap[parent]
                    heap[parent] = heap[h]
                    heap[h] = swap
                    h = parent
                }
                ea++
            }

            while (hn > 0) {
                if (E[heap[1], 3] >= p) break
                heap[1] = heap[hn]
                hn--
                h = 1
                while (1) {
                    left = 2 * h
                    right = left + 1
                    best = h
                    if (left <= hn) {
                        if (_tvp_heap_gt(E, heap[left], heap[best])) best = left
                    }
                    if (right <= hn) {
                        if (_tvp_heap_gt(E, heap[right], heap[best])) best = right
                    }
                    if (best == h) break
                    swap = heap[h]
                    heap[h] = heap[best]
                    heap[best] = swap
                    h = best
                }
            }
            if (hn > 0) O[gi, 1] = E[heap[1], 4]

            for (c = 1; c <= nc; c++) {
                k = cptr[c]
                if (k == 0) continue
                while (k <= cend[c]) {
                    if (U[k, 4] >= p) break
                    csum[c] = csum[c] + U[k, 4] - U[k, 3] + 1
                    k++
                }
                cptr[c] = k
                O[gi, 1 + c] = csum[c]
                if (k <= cend[c]) {
                    if (U[k, 3] < p) O[gi, 1 + c] = csum[c] + p - U[k, 3]
                }
            }
        }
        i = ge + 1
    }

    st_store(., tokens(ovars), O)
}
end
local _tvp_compile_rc = _rc
mata: mata set matastrict `_tvp_compile_strict'
if `_tvp_compile_rc' exit `_tvp_compile_rc'

// Usage (current frame holds the grid, sorted by id pstart):
//   _tvpanel_sweep, id(v) pstart(v) active(v) eframe(f) evars(id start stop cls)
//       [days(varlist) uframe(f) uvars(id cls start stop) classes(numlist)]
capture program drop _tvpanel_sweep
program define _tvpanel_sweep
    version 16.0
    syntax , ID(varname numeric) PSTART(varname numeric) ///
        ACTIVE(varname numeric) EFRAME(name) EVARS(string) ///
        [DAYS(varlist numeric) UFRAME(name) UVARS(string) CLASSES(numlist)]

    local nd : word count `days'
    local nc : word count `classes'
    if `nd' != `nc' {
        display as error "_tvpanel_sweep: days() and classes() differ in length"
        exit 198
    }
    if `nc' > 0 & ("`uframe'" == "" | "`uvars'" == "") {
        display as error "_tvpanel_sweep: classes() requires uframe() and uvars()"
        exit 198
    }
    local cvec "J(1, 0, .)"
    if `nc' > 0 local cvec "(`=subinstr(trim("`classes'"), " ", ", ", .)')"
    mata: _tvp_sweep_core("`id' `pstart'", "`active' `days'", ///
        "`eframe'", "`evars'", "`uframe'", "`uvars'", `cvec')
end
