*! _qba_distributions Version 1.1.1  2026/08/05
*! Internal helper: random draws from distributions for probabilistic QBA
*! Author: Timothy P Copeland, Karolinska Institutet

/*
Internal programs for drawing random values from distributions used
in probabilistic bias analysis.

Supported distributions:
  trapezoidal min mode1 mode2 max
  triangular min mode max
  uniform min max
  beta a b
  logit-normal mean sd
  constant value

Every distribution is drawn by inverse CDF from a uniform variate. The
u() option supplies that variate instead of generating it, which is what
lets a caller induce dependence between two bias parameters by feeding
correlated uniforms (Gaussian copula; Fox, MacLehose & Lash 2023 draw
case and non-case sensitivities this way).

Usage:
  _qba_draw_one, dist("trapezoidal 0.7 0.8 0.9 1.0") gen(varname) n(#)
  _qba_draw_one, dist("beta 50.6 14.3") gen(varname) n(#) u(uvarname)
  _qba_parse_dist, dist("trapezoidal 0.7 0.8 0.9 1.0")
*/

* Parse a distribution specification string
capture program drop _qba_parse_dist
program define _qba_parse_dist, rclass
    version 16.0
    local _saved_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , DIst(string)

    local dist = strtrim("`dist'")
    gettoken dtype params : dist
    local params = strtrim("`params'")
    local dtype = strlower("`dtype'")

    if !inlist("`dtype'", "trapezoidal", "triangular", "uniform", "beta", "logit-normal", "constant") {
        display as error "unknown distribution type: `dtype'"
        display as error "allowed: trapezoidal, triangular, uniform, beta, logit-normal, constant"
        exit 198
    }

    foreach _p of local params {
        capture confirm number `_p'
        if _rc {
            display as error "distribution parameters must be numeric"
            exit 198
        }
    }

    if "`dtype'" == "trapezoidal" {
        local nparams : word count `params'
        if `nparams' != 4 {
            display as error "trapezoidal requires 4 parameters: min mode1 mode2 max"
            exit 198
        }
        local p1 : word 1 of `params'
        local p2 : word 2 of `params'
        local p3 : word 3 of `params'
        local p4 : word 4 of `params'
        if `p1' > `p2' | `p2' > `p3' | `p3' > `p4' {
            display as error "trapezoidal requires min <= mode1 <= mode2 <= max"
            exit 198
        }
    }
    else if "`dtype'" == "triangular" {
        local nparams : word count `params'
        if `nparams' != 3 {
            display as error "triangular requires 3 parameters: min mode max"
            exit 198
        }
        local p1 : word 1 of `params'
        local p2 : word 2 of `params'
        local p3 : word 3 of `params'
        if `p1' > `p2' | `p2' > `p3' {
            display as error "triangular requires min <= mode <= max"
            exit 198
        }
    }
    else if "`dtype'" == "uniform" {
        local nparams : word count `params'
        if `nparams' != 2 {
            display as error "uniform requires 2 parameters: min max"
            exit 198
        }
        local p1 : word 1 of `params'
        local p2 : word 2 of `params'
        if `p1' >= `p2' {
            display as error "uniform requires min < max"
            exit 198
        }
    }
    else if "`dtype'" == "beta" {
        local nparams : word count `params'
        if `nparams' != 2 {
            display as error "beta requires 2 parameters: shape1 shape2"
            exit 198
        }
        local p1 : word 1 of `params'
        local p2 : word 2 of `params'
        if `p1' <= 0 | `p2' <= 0 {
            display as error "beta shape parameters must be > 0"
            exit 198
        }
    }
    else if "`dtype'" == "logit-normal" {
        local nparams : word count `params'
        if `nparams' != 2 {
            display as error "logit-normal requires 2 parameters: mean sd"
            exit 198
        }
        local p1 : word 1 of `params'
        local p2 : word 2 of `params'
        if `p2' <= 0 {
            display as error "logit-normal sd must be > 0"
            exit 198
        }
    }
    else if "`dtype'" == "constant" {
        local nparams : word count `params'
        if `nparams' != 1 {
            display as error "constant requires 1 parameter: value"
            exit 198
        }
        local p1 : word 1 of `params'
    }

    return local dtype "`dtype'"
    return local params "`params'"

    }
    local rc = _rc
    set varabbrev `_saved_varabbrev'
    if `rc' exit `rc'
end

* Draw n random values from a specified distribution into a variable
capture program drop _qba_draw_one
program define _qba_draw_one
    version 16.0
    local _saved_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , DIst(string) GEN(name) N(integer) [U(varname numeric)]

    _qba_parse_dist, dist("`dist'")
    local dtype "`r(dtype)'"
    local params "`r(params)'"

    * When u() is supplied every distribution is inverted from that variate,
    * so correlated uniforms carry their dependence through to the parameter.
    * Without u() the original direct-generator calls are kept verbatim: they
    * define the seeded RNG stream that existing known-answer QA pins.
    if "`dtype'" == "constant" {
        local val : word 1 of `params'
        quietly gen double `gen' = `val' in 1/`n'
    }
    else if "`dtype'" == "uniform" {
        local lo : word 1 of `params'
        local hi : word 2 of `params'
        if "`u'" != "" {
            quietly gen double `gen' = `lo' + (`hi' - `lo') * `u' in 1/`n'
        }
        else {
            quietly gen double `gen' = `lo' + (`hi' - `lo') * runiform() in 1/`n'
        }
    }
    else if "`dtype'" == "beta" {
        local a : word 1 of `params'
        local b : word 2 of `params'
        if "`u'" != "" {
            quietly gen double `gen' = invibeta(`a', `b', `u') in 1/`n'
        }
        else {
            quietly gen double `gen' = rbeta(`a', `b') in 1/`n'
        }
    }
    else if "`dtype'" == "logit-normal" {
        local mu : word 1 of `params'
        local sd : word 2 of `params'
        if "`u'" != "" {
            quietly gen double `gen' = invlogit(`mu' + `sd' * invnormal(`u')) in 1/`n'
        }
        else {
            quietly gen double `gen' = invlogit(`mu' + `sd' * rnormal()) in 1/`n'
        }
    }
    else if "`dtype'" == "triangular" {
        local lo : word 1 of `params'
        local mode : word 2 of `params'
        local hi : word 3 of `params'
        local range = `hi' - `lo'
        if `range' == 0 {
            quietly gen double `gen' = `lo' in 1/`n'
        }
        else {
            local fc = (`mode' - `lo') / `range'
            if "`u'" != "" {
                local uvar "`u'"
            }
            else {
                tempvar uvar
                quietly gen double `uvar' = runiform() in 1/`n'
            }
            quietly gen double `gen' = `lo' + sqrt(`uvar' * `range' * (`mode' - `lo')) ///
                if `uvar' <= `fc' in 1/`n'
            quietly replace `gen' = `hi' - sqrt((1 - `uvar') * `range' * (`hi' - `mode')) ///
                if `uvar' > `fc' in 1/`n'
        }
    }
    else if "`dtype'" == "trapezoidal" {
        local a : word 1 of `params'
        local b : word 2 of `params'
        local c : word 3 of `params'
        local d : word 4 of `params'
        * Degenerate case: all params equal or span is zero
        if `d' + `c' - `a' - `b' == 0 {
            quietly gen double `gen' = (`a' + `d') / 2 in 1/`n'
        }
        else {
        * Trapezoidal via inverse CDF
        * Area segments: triangle left, rectangle middle, triangle right
        local h = 2 / (`d' + `c' - `a' - `b')
        local area1 = 0.5 * (`b' - `a') * `h'
        local area2 = (`c' - `b') * `h'
        if "`u'" != "" {
            local uvar "`u'"
        }
        else {
            tempvar uvar
            quietly gen double `uvar' = runiform() in 1/`n'
        }
        quietly gen double `gen' = . in 1/`n'
        * Region 1: rising edge [a, b]
        quietly replace `gen' = `a' + sqrt(`uvar' * (`b' - `a') * (`d' + `c' - `a' - `b')) ///
            if `uvar' <= `area1' in 1/`n'
        * Region 2: flat top [b, c]
        quietly replace `gen' = `b' + (`uvar' - `area1') * (`d' + `c' - `a' - `b') / 2 ///
            if `uvar' > `area1' & `uvar' <= (`area1' + `area2') in 1/`n'
        * Region 3: falling edge [c, d]
        quietly replace `gen' = `d' - sqrt((1 - `uvar') * (`d' - `c') * (`d' + `c' - `a' - `b')) ///
            if `uvar' > (`area1' + `area2') in 1/`n'
        }
    }

    }
    local rc = _rc
    set varabbrev `_saved_varabbrev'
    if `rc' exit `rc'
end

* Convenience: draw and return a single scalar (for simple mode testing)
capture program drop _qba_draw_scalar
program define _qba_draw_scalar, rclass
    version 16.0
    local _saved_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , DIst(string)

    _qba_parse_dist, dist("`dist'")
    local dtype "`r(dtype)'"
    local params "`r(params)'"

    if "`dtype'" == "constant" {
        local val : word 1 of `params'
        return scalar value = `val'
    }
    else {
        preserve
        quietly clear
        quietly set obs 1
        _qba_draw_one, dist("`dist'") gen(_val) n(1)
        local val = _val[1]
        restore
        return scalar value = `val'
    }

    }
    local rc = _rc
    set varabbrev `_saved_varabbrev'
    if `rc' exit `rc'
end
