# Reusable Test Helper Programs

## Floating Point Comparison

```stata
capture program drop _assert_equal
program define _assert_equal
    args actual expected tolerance
    if "`tolerance'" == "" local tolerance = 0.0001
    local diff = abs(`actual' - `expected')
    if `diff' > `tolerance' {
        display as error "Expected: `expected', Got: `actual' (diff: `diff')"
        exit 9
    }
end

* Usage
_assert_equal `result' 3.14159 0.001
```

## Row-by-Row Validation

```stata
capture program drop _validate_rows
program define _validate_rows
    syntax varname, expected(string) [tolerance(real 0.0001)]
    local values `expected'
    local row = 1
    foreach val of local values {
        local actual = `varlist'[`row']
        if abs(`actual' - `val') > `tolerance' {
            display as error "Row `row': expected `val', got `actual'"
            exit 9
        }
        local ++row
    }
    display as result "All `=`row'-1' rows validated"
end

* Usage
_validate_rows result, expected(100 400 900)
```

## Test Counter Helper

```stata
capture program drop _test_result
program define _test_result
    args passed test_name pass_count fail_count
    if `passed' {
        display as result "  PASS: `test_name'"
        c_local `pass_count' = ``pass_count'' + 1
    }
    else {
        display as error "  FAIL: `test_name'"
        c_local `fail_count' = ``fail_count'' + 1
    }
end

* Usage
capture noisily {
    mycommand x
    assert r(N) > 0
}
_test_result `=_rc==0' "Basic functionality" pass_count fail_count
```
