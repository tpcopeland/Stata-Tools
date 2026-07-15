# Data Dictionary

## Table of Contents

1. [ Demo Auto](#1--demo-auto)
2. [Notes](#notes)
3. [Change Log](#change-log)


## 1.  Demo Auto

**Filename:** `_demo_auto.dta`  
**Source path:** `datamap/demo/_demo_auto.dta`  
**Description:** Dataset containing 12 variables and 74 observations.  
**Observations:** 74  
**Variables in file:** 12  
**Variables documented:** 12  
**File size:** 12,765 bytes  

### Variables

| Variable | Label | Type | Missing | Statistics/Values |
|---|---|---|---|---|
| `make` | Make and model | String | 0 (0.0%) | N=74; 74 unique values |
| `price` | Price | Numeric | 0 (0.0%) | N=74<br>Median=5,006; IQR=4,195-6,342<br>Mean=6,165 (SD=2,949)<br>Range=3,291-15,906 |
| `mpg` | Mileage (mpg) | Numeric | 0 (0.0%) | Unique=21<br>12 (suppressed <5)<br>14 (6; 8.1%)<br>15 (suppressed <5)<br>16 (suppressed <5)<br>17 (suppressed <5)<br>18 (9; 12.2%)<br>19 (8; 10.8%)<br>20 (suppressed <5)<br>21 (5; 6.8%)<br>22 (5; 6.8%)<br>23 (suppressed <5)<br>24 (suppressed <5)<br>25 (5; 6.8%)<br>26 (suppressed <5)<br>28 (suppressed <5)<br>29 (suppressed <5)<br>30 (suppressed <5)<br>31 (suppressed <5)<br>34 (suppressed <5)<br>35 (suppressed <5)<br>41 (suppressed <5) |
| `rep78` | Repair record 1978 | Numeric | 5 (6.8%) | Unique=5<br>1 (suppressed <5)<br>2 (8; 11.6%)<br>3 (30; 43.5%)<br>4 (18; 26.1%)<br>5 (11; 15.9%) |
| `headroom` | Headroom (in.) | Numeric | 0 (0.0%) | Unique=8<br>1.5 (suppressed <5)<br>2 (13; 17.6%)<br>2.5 (14; 18.9%)<br>3 (13; 17.6%)<br>3.5 (15; 20.3%)<br>4 (10; 13.5%)<br>4.5 (suppressed <5)<br>5 (suppressed <5) |
| `trunk` | Trunk space (cu. ft.) | Numeric | 0 (0.0%) | Unique=18<br>5 (suppressed <5)<br>6 (suppressed <5)<br>7 (suppressed <5)<br>8 (5; 6.8%)<br>9 (suppressed <5)<br>10 (5; 6.8%)<br>11 (8; 10.8%)<br>12 (suppressed <5)<br>13 (suppressed <5)<br>14 (suppressed <5)<br>15 (5; 6.8%)<br>16 (12; 16.2%)<br>17 (8; 10.8%)<br>18 (suppressed <5)<br>20 (6; 8.1%)<br>21 (suppressed <5)<br>22 (suppressed <5)<br>23 (suppressed <5) |
| `weight` | Weight (lbs.) | Numeric | 0 (0.0%) | N=74<br>Median=3,190; IQR=2,240-3,600<br>Mean=3,019 (SD=777)<br>Range=1,760-4,840 |
| `length` | Length (in.) | Numeric | 0 (0.0%) | N=74<br>Median=192; IQR=170-204<br>Mean=188 (SD=22.27)<br>Range=142-233 |
| `turn` | Turn circle (ft.) | Numeric | 0 (0.0%) | Unique=18<br>31 (suppressed <5)<br>32 (suppressed <5)<br>33 (suppressed <5)<br>34 (6; 8.1%)<br>35 (6; 8.1%)<br>36 (9; 12.2%)<br>37 (suppressed <5)<br>38 (suppressed <5)<br>39 (suppressed <5)<br>40 (6; 8.1%)<br>41 (suppressed <5)<br>42 (7; 9.5%)<br>43 (12; 16.2%)<br>44 (suppressed <5)<br>45 (suppressed <5)<br>46 (suppressed <5)<br>48 (suppressed <5)<br>51 (suppressed <5) |
| `displacement` | Displacement (cu. in.) | Numeric | 0 (0.0%) | N=74<br>Median=196; IQR=119-250<br>Mean=197 (SD=91.84)<br>Range=79.00-425 |
| `gear_ratio` | Gear ratio | Numeric | 0 (0.0%) | N=74<br>Median=2.96; IQR=2.73-3.37<br>Mean=3.01 (SD=0.456)<br>Range=2.19-3.89 |
| `foreign` | Car origin | Numeric | 0 (0.0%) | Unique=2<br>0 Domestic (52; 70.3%)<br>1 Foreign (22; 29.7%) |


## Notes

- All date variables are displayed using %tdCCYY/NN/DD format
- Missing values coded as . (numeric missing) or empty string


## Change Log

*No changes recorded.*


**Last Updated:** 15 Jul 2026
