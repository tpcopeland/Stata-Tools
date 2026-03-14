*! _qba_distributions Version 1.0.0  2026/03/13
*! Internal helper: random draws from distributions for probabilistic QBA
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet

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

Usage:
  _qba_draw_one, dist("trapezoidal 0.7 0.8 0.9 1.0") gen(varname) n(#)
  _qba_parse_dist, dist("trapezoidal 0.7 0.8 0.9 1.0")
*/

* Parse a distribution specification string
capture program drop _qba_parse_dist
program define _qba_parse_dist, rclass
    version 16.0
    set varabbrev off
    syntax , DIst(string)

    local dist = strtrim("`dist'")
    gettoken dtype params : dist
    local dtype = strlower("`dtype'")

    if !inlist("`dtype'", "trapezoidal", "triangular", "uniform", "beta", "logit-normal", "constant") {
        display as error "unknown distribution type: `dtype'"
        display as error "allowed: trapezoidal, triangular, uniform, beta, logit-normal, constant"
        exit 198
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
end

* Draw n random values from a specified distribution into a variable
capture program drop _qba_draw_one
program define _qba_draw_one
    version 16.0
    set varabbrev off
    syntax , DIst(string) GEN(name) N(integer)

    _qba_parse_dist, dist("`dist'")
    local dtype "`r(dtype)'"
    local params "`r(params)'"

    if "`dtype'" == "constant" {
        local val : word 1 of `params'
        quietly gen double `gen' = `val' in 1/`n'
    }
    else if "`dtype'" == "uniform" {
        local lo : word 1 of `params'
        local hi : word 2 of `params'
        quietly gen double `gen' = `lo' + (`hi' - `lo') * runiform() in 1/`n'
    }
    else if "`dtype'" == "beta" {
        local a : word 1 of `params'
        local b : word 2 of `params'
        quietly gen double `gen' = rbeta(`a', `b') in 1/`n'
    }
    else if "`dtype'" == "logit-normal" {
        local mu : word 1 of `params'
        local sd : word 2 of `params'
        quietly gen double `gen' = invlogit(`mu' + `sd' * rnormal()) in 1/`n'
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
            tempvar u
            quietly gen double `u' = runiform() in 1/`n'
            quietly gen double `gen' = `lo' + sqrt(`u' * `range' * (`mode' - `lo')) ///
                if `u' <= `fc' in 1/`n'
            quietly replace `gen' = `hi' - sqrt((1 - `u') * `range' * (`hi' - `mode')) ///
                if `u' > `fc' in 1/`n'
        }
    }
    else if "`dtype'" == "trapezoidal" {
        local a : word 1 of `params'
        local b : word 2 of `params'
        local c : word 3 of `params'
        local d : word 4 of `params'
        * Trapezoidal via inverse CDF
        * Area segments: triangle left, rectangle middle, triangle right
        local h = 2 / (`d' + `c' - `a' - `b')
        local area1 = 0.5 * (`b' - `a') * `h'
        local area2 = (`c' - `b') * `h'
        local area3 = 0.5 * (`d' - `c') * `h'
        tempvar u
        quietly gen double `u' = runiform() in 1/`n'
        quietly gen double `gen' = . in 1/`n'
        * Region 1: rising edge [a, b]
        quietly replace `gen' = `a' + sqrt(`u' * (`b' - `a') * (`d' + `c' - `a' - `b')) ///
            if `u' <= `area1' in 1/`n'
        * Region 2: flat top [b, c]
        quietly replace `gen' = `b' + (`u' - `area1') * (`d' + `c' - `a' - `b') / 2 ///
            if `u' > `area1' & `u' <= (`area1' + `area2') in 1/`n'
        * Region 3: falling edge [c, d]
        quietly replace `gen' = `d' - sqrt((1 - `u') * (`d' - `c') * (`d' + `c' - `a' - `b')) ///
            if `u' > (`area1' + `area2') in 1/`n'
    }
end

* Convenience: draw and return a single scalar (for simple mode testing)
capture program drop _qba_draw_scalar
program define _qba_draw_scalar, rclass
    version 16.0
    set varabbrev off
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
end
