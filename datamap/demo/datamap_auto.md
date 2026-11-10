## 1. _demo_auto

- Source: `datamap/demo/_demo_auto.dta`
- Label: 1978 automobile data
- Observations: 74
- Variables: 12
- Sort order: `foreign`
- Dataset notes:
  - From Consumer Reports with permission
- Data signature: `74:12(71728):3831085005:1395876116`
- Disclosure: 0 excluded; cells below 5 suppressed; date-safe off; likely identifiers not excluded: none

### Variables

| Variable | Label | Type | Missing | Values/Statistics |
|---|---|---|---|---|
| `make` | Make and model | str18 | 0 (0.0%) | N=74; 74 distinct; max length 17 |
| `price` | Price | int | 0 (0.0%) | N=74; mean=6,165; SD=2,949; median=5,006; IQR=4,195-6,342; range=3,291-15,906 |
| `mpg` | Mileage (mpg) | int | 0 (0.0%) | 12: suppressed (<5)<br>14: 6 (8.1%)<br>15: suppressed (<5)<br>16: suppressed (<5)<br>17: suppressed (<5)<br>18: 9 (12.2%)<br>19: 8 (10.8%)<br>20: suppressed (<5)<br>21: 5 (6.8%)<br>22: 5 (6.8%)<br>23: suppressed (<5)<br>24: suppressed (<5)<br>25: 5 (6.8%)<br>26: suppressed (<5)<br>28: suppressed (<5)<br>29: suppressed (<5)<br>30: suppressed (<5)<br>31: suppressed (<5)<br>34: suppressed (<5)<br>35: suppressed (<5)<br>41: suppressed (<5) |
| `rep78` | Repair record 1978 | int | 5 (6.8%) | 1: suppressed (<5)<br>2: suppressed (complementary)<br>3: 30 (40.5%)<br>4: 18 (24.3%)<br>5: 11 (14.9%) |
| `headroom` | Headroom (in.) | float | 0 (0.0%) | 1.5: suppressed (<5)<br>2.0: 13 (17.6%)<br>2.5: 14 (18.9%)<br>3.0: 13 (17.6%)<br>3.5: 15 (20.3%)<br>4.0: 10 (13.5%)<br>4.5: suppressed (<5)<br>5.0: suppressed (<5) |
| `trunk` | Trunk space (cu. ft.) | int | 0 (0.0%) | 5: suppressed (<5)<br>6: suppressed (<5)<br>7: suppressed (<5)<br>8: 5 (6.8%)<br>9: suppressed (<5)<br>10: 5 (6.8%)<br>11: 8 (10.8%)<br>12: suppressed (<5)<br>13: suppressed (<5)<br>14: suppressed (<5)<br>15: 5 (6.8%)<br>16: 12 (16.2%)<br>17: 8 (10.8%)<br>18: suppressed (<5)<br>20: 6 (8.1%)<br>21: suppressed (<5)<br>22: suppressed (<5)<br>23: suppressed (<5) |
| `weight` | Weight (lbs.) | int | 0 (0.0%) | N=74; mean=3,019; SD=777; median=3,190; IQR=2,240-3,600; range=1,760-4,840 |
| `length` | Length (in.) | int | 0 (0.0%) | N=74; mean=188; SD=22.27; median=192; IQR=170-204; range=142-233 |
| `turn` | Turn circle (ft.) | int | 0 (0.0%) | 31: suppressed (<5)<br>32: suppressed (<5)<br>33: suppressed (<5)<br>34: 6 (8.1%)<br>35: 6 (8.1%)<br>36: 9 (12.2%)<br>37: suppressed (<5)<br>38: suppressed (<5)<br>39: suppressed (<5)<br>40: 6 (8.1%)<br>41: suppressed (<5)<br>42: 7 (9.5%)<br>43: 12 (16.2%)<br>44: suppressed (<5)<br>45: suppressed (<5)<br>46: suppressed (<5)<br>48: suppressed (<5)<br>51: suppressed (<5) |
| `displacement` | Displacement (cu. in.) | int | 0 (0.0%) | N=74; mean=197; SD=91.84; median=196; IQR=119-250; range=79.00-425.00 |
| `gear_ratio` | Gear ratio | float | 0 (0.0%) | N=74; mean=3.01; SD=0.456; median=2.96; IQR=2.73-3.37; range=2.19-3.89 |
| `foreign` | Car origin | byte | 0 (0.0%) | 0 Domestic: 52 (70.3%)<br>1 Foreign: 22 (29.7%) |

