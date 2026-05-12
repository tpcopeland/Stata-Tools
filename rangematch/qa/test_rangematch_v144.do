capture ado uninstall rangematch
clear all
version 17.0

local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
    local qa_dir "`cwd'"
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
}
else {
    local pkg_dir "`cwd'"
    local qa_dir "`pkg_dir'/qa"
}

quietly net install rangematch, from("`pkg_dir'") replace

**# Automatic sweep backend for monotone default joins

tempfile using_sweep
clear
input int uid byte group double keyval
1 1 1
2 1 2
3 1 3
4 2 1
5 2 2
6 2 3
end
save "`using_sweep'", replace

clear
input int id byte group double(lo hi)
1 1 1 1
2 1 1 2
3 1 2 3
4 2 1 2
end

rangematch keyval lo hi using "`using_sweep'", ///
    by(group) keepusing(uid) unmatched(none) nosort

assert "`r(backend)'" == "sweep"
assert r(N_pairs) == 7
assert r(N_matched_pairs) == 7
assert r(N_unmatched) == 0
assert uid[1] == 1
assert uid[2] == 1
assert uid[3] == 2
assert uid[4] == 2
assert uid[5] == 3
assert uid[6] == 4
assert uid[7] == 5

**# Sweep handles unmatched master rows and count mode

clear
input int id byte group double(lo hi)
1 1 1 1
2 1 1 2
3 1 2 3
4 2 1 2
5 2 10 11
end

rangematch keyval lo hi using "`using_sweep'", ///
    by(group) keepusing(uid) count

assert "`r(backend)'" == "sweep"
assert r(N_pairs) == 8
assert r(N_matched_pairs) == 7
assert r(N_unmatched) == 1

capture noisily rangematch keyval lo hi using "`using_sweep'", ///
    by(group) keepusing(uid) count assert(match)
assert _rc == 9
assert _N == 5

clear
input int id byte group double(lo hi)
1 1 1 1
2 1 1 2
3 1 2 3
4 2 1 2
5 2 10 11
end

rangematch keyval lo hi using "`using_sweep'", ///
    by(group) keepusing(uid) nosort

assert "`r(backend)'" == "sweep"
assert r(N_pairs) == 8
assert r(N_unmatched) == 1
assert id[8] == 5
assert missing(uid[8])

**# Nonmonotone intervals fall back to binary backend

clear
input int id byte group double(lo hi)
1 1 2 3
2 1 1 2
end

rangematch keyval lo hi using "`using_sweep'", ///
    by(group) keepusing(uid) unmatched(none) nosort

assert "`r(backend)'" == "binary"
assert r(N_pairs) == 4
sort id uid
assert id[1] == 1 & uid[1] == 2
assert id[2] == 1 & uid[2] == 3
assert id[3] == 2 & uid[3] == 1
assert id[4] == 2 & uid[4] == 2

**# Stats and using-side assertions are sweep-eligible when monotone

clear
input int id byte group double(lo hi)
1 1 1 1
2 1 1 2
3 1 2 3
4 2 1 2
end

rangematch keyval lo hi using "`using_sweep'", ///
    by(group) keepusing(uid) unmatched(none) stats

assert "`r(backend)'" == "sweep"
assert r(N_pairs) == 7
assert r(N_matched_using) == 5

clear
input int id byte group double(lo hi)
1 1 1 1
2 1 1 2
3 1 2 3
4 2 1 2
end

capture noisily rangematch keyval lo hi using "`using_sweep'", ///
    by(group) keepusing(uid) unmatched(none) assert(using)
assert _rc == 9
assert _N == 4

display as result "ALL RANGEMATCH 1.4.4 REGRESSION TESTS PASSED"
