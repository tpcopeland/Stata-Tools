* test_rangematch_by.do — Tests for by() option

capture ado uninstall rangematch
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
adopath ++ "`pkg_dir'"

tempfile by_master by_using by_master_str by_using_str ///
    by_master_unmatch by_using_unmatch by_master_multi by_using_multi

* -----------------------------------------------------------------------
* Test 1: Numeric by-variable
* -----------------------------------------------------------------------
clear
input int(id group) double(lo hi)
1 1 1 5
2 1 10 20
3 2 1 5
end
save "`by_master'", replace

clear
input int(uid group) double keyval
1 1 3
2 1 15
3 2 3
4 2 100
end
save "`by_using'", replace

use "`by_master'", clear
rangematch keyval lo hi ///
    using "`by_using'", by(group)

* group=1: id=1(lo=1,hi=5) matches uid=1(keyval=3)
*           id=2(lo=10,hi=20) matches uid=2(keyval=15)
* group=2: id=3(lo=1,hi=5) matches uid=3(keyval=3)
*           uid=4(keyval=100) doesn't match any master row in group 2
assert r(N_pairs) == 3
assert r(N_unmatched) == 0

sort group id keyval
assert id[1] == 1 & keyval[1] == 3 & group[1] == 1
assert id[2] == 2 & keyval[2] == 15 & group[2] == 1
assert id[3] == 3 & keyval[3] == 3 & group[3] == 2

display as result "PASS: Test 1 — numeric by-variable"

* -----------------------------------------------------------------------
* Test 2: String by-variable
* -----------------------------------------------------------------------
clear
input int id str1 site double(lo hi)
1 "A" 1 5
2 "A" 10 20
3 "B" 1 5
end
save "`by_master_str'", replace

clear
input int uid str1 site double keyval
1 "A" 3
2 "A" 15
3 "B" 3
4 "B" 100
end
save "`by_using_str'", replace

use "`by_master_str'", clear
rangematch keyval lo hi ///
    using "`by_using_str'", by(site)

assert r(N_pairs) == 3
assert r(N_unmatched) == 0

sort site id keyval
assert id[1] == 1 & keyval[1] == 3 & site[1] == "A"
assert id[2] == 2 & keyval[2] == 15 & site[2] == "A"
assert id[3] == 3 & keyval[3] == 3 & site[3] == "B"

display as result "PASS: Test 2 — string by-variable"

* -----------------------------------------------------------------------
* Test 3: by() with unmatched groups
* -----------------------------------------------------------------------
* Master has group=3 but using doesn't
clear
input int(id group) double(lo hi)
1 1 1 5
2 3 1 5
end
save "`by_master_unmatch'", replace

clear
input int(uid group) double keyval
1 1 3
2 2 3
end
save "`by_using_unmatch'", replace

use "`by_master_unmatch'", clear
rangematch keyval lo hi ///
    using "`by_using_unmatch'", by(group)

* group=1: id=1 matches uid=1
* group=3: id=2 has no using rows → unmatched
assert r(N_pairs) == 2
assert r(N_unmatched) == 1

display as result "PASS: Test 3 — by() with unmatched groups"

* -----------------------------------------------------------------------
* Test 4: Multiple by-variables
* -----------------------------------------------------------------------
clear
input int(id g1 g2) double(lo hi)
1 1 1 1 5
2 1 2 1 5
3 2 1 1 5
end
save "`by_master_multi'", replace

clear
input int(uid g1 g2) double keyval
1 1 1 3
2 1 2 3
3 2 1 3
4 2 2 3
end
save "`by_using_multi'", replace

use "`by_master_multi'", clear
rangematch keyval lo hi ///
    using "`by_using_multi'", by(g1 g2)

* Each master row should match exactly one using row in its group
assert r(N_pairs) == 3
assert r(N_unmatched) == 0

sort g1 g2 id
assert id[1] == 1 & uid[1] == 1
assert id[2] == 2 & uid[2] == 2
assert id[3] == 3 & uid[3] == 3

display as result "PASS: Test 4 — multiple by-variables"

display as result _newline "ALL BY-GROUP TESTS PASSED"
