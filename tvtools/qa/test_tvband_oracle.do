* Seed: 26082402. 200 randomized calendar-band coverage checks.
clear all
version 16.0
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap
set seed 26082402
forvalues rep = 1/200 {
    clear
    set obs 7
    gen long id = _n
    gen double start = mdy(1,1,2000) + floor(runiform()*4000)
    gen double stop = start + floor(runiform()*1000)
    gen str12 _tvband_shadow = "keep_" + string(_n)
    format start stop %td
    tvband, id(id) start(start) stop(stop) type(calendar) width(1) generate(band)
    bysort id (start): assert _n == 1 | start == stop[_n-1] + 1
    bysort id: gen double total = sum(stop-start+1)
    by id: assert total[_N] == stop[_N] - start[1] + 1
    assert _tvband_shadow == "keep_" + string(id)
}
display as result "RESULT: PASS tvtools tvband randomized oracle (200 reps)"
