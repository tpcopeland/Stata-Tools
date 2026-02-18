# Stata Date Reference Values

## 2020 Leap Year Reference

| Date | Stata Value | Notes |
|------|-------------|-------|
| Jan 1, 2020 | 21915 | Year start |
| Feb 29, 2020 | 21974 | Leap day |
| Mar 1, 2020 | 21975 | After Feb (leap) |
| Jun 30, 2020 | 22097 | Mid-year |
| Jul 1, 2020 | 22098 | Second half |
| Dec 31, 2020 | 22280 | Year end |
| Jan 1, 2021 | 22281 | Next year |

Days in 2020: 366 (leap year)

## Common Date Calculations

```stata
local days = date2 - date1
local years = (date2 - date1) / 365.25
local new_date = `old_date' + 30
local first = mdy(month(`date'), 1, year(`date'))
```

## Date Validation Patterns

```stata
assert !missing(mydate)
assert mydate >= mdy(1,1,1900) & mydate <= mdy(12,31,2100)
assert start_date <= end_date
```
