## 1. Data in memory

- Source: data in memory
- File: none (not used from or saved to a file)
- Observations: 120
- Variables: 11
- Sort order: `firm`, `year`
- Declared xtset: panel `firm`; time `year` (%ty yearly); delta 1
- Dataset notes:
  - golden note for the state header
- Data signature: `120:11(95270):1879878355:2934536986`
- Disclosure: 0 excluded; cells below 5 suppressed; date-safe off; likely identifiers not excluded: none

### Variables

| Variable | Label | Type | Missing | Values/Statistics |
|---|---|---|---|---|
| `firm` |  | int | 0 (0.0%) | 1: 6 (5.0%)<br>2: 6 (5.0%)<br>3: 6 (5.0%)<br>4: 6 (5.0%)<br>5: 6 (5.0%)<br>6: 6 (5.0%)<br>7: 6 (5.0%)<br>8: 6 (5.0%)<br>9: 6 (5.0%)<br>10: 6 (5.0%)<br>11: 6 (5.0%)<br>12: 6 (5.0%)<br>13: 6 (5.0%)<br>14: 6 (5.0%)<br>15: 6 (5.0%)<br>16: 6 (5.0%)<br>17: 6 (5.0%)<br>18: 6 (5.0%)<br>19: 6 (5.0%)<br>20: 6 (5.0%) |
| `year` |  | int %ty yearly | 0 (0.0%) | N=120; range 2000 to 2005 |
| `edu` |  | byte | 33 (27.5%): . 9, .a Refused 18, .b Not asked 6 | 1 Primary: 29 (24.2%)<br>2 Secondary: 29 (24.2%)<br>3 Tertiary: 29 (24.2%) |
| `bmi` |  | double | 0 (0.0%) | 20: 6 (5.0%)<br>20.5: 6 (5.0%)<br>21: 6 (5.0%)<br>21.5: 6 (5.0%)<br>22: 6 (5.0%)<br>22.5: 6 (5.0%)<br>23: 6 (5.0%)<br>23.5: 5 (4.2%)<br>24: 5 (4.2%)<br>24.5: 5 (4.2%)<br>25: 5 (4.2%)<br>25.5: 5 (4.2%)<br>26: 5 (4.2%)<br>26.5: 6 (5.0%)<br>27: 6 (5.0%)<br>27.5: 6 (5.0%)<br>28: 6 (5.0%)<br>28.5: 6 (5.0%)<br>29: 6 (5.0%)<br>999: 12 (10.0%) |
| `income_s` |  | str8 | 0 (0.0%) | N=120; 100 distinct; max length 5; numeric text 98 (81.7%); non-numeric "NA" 14, "na" 8; leading or trailing spaces 10 |
| `dstr` |  | str10 | 0 (0.0%) | N=120; 15 distinct; max length 10; values "2020-03-10" 8, "2020-03-11" 8, "2020-03-12" 8, "2020-03-13" 8, "2020-03-14" 8, others; date-like text (YMD) |
| `sex` |  | str6 | 0 (0.0%) | N=120; 2 distinct; max length 6; values "Female" 60, "Male" 60 |
| `admit` |  | long %td daily | 0 (0.0%) | N=120; range 1960/01/01 to 2090/06/01 |
| `stamp` |  | double %tc datetime | 0 (0.0%) | N=120; range 2015/01/01 to 2015/01/06 |
| `mo` |  | int %tm monthly | 0 (0.0%) | N=120; range 2015m2 to 2025m1 |
| `memo` |  | strL | 0 (0.0%) | N=120; 4 distinct; max length 6; values "memo 0" 30, "memo 1" 30, "memo 2" 30, "memo 3" 30 |

### Flags

No quality flags.

### Candidates (not applied)

- `bmi`: 999: 12 rows
- `admit`: 1960/01/01: 6 rows; after <run date> (run date): 7 rows

### Structure (inferred)

- Name patterns: demographics `sex`

