## Contents

1. [g9_person](#1-g9_person)
2. [g9_rx](#2-g9_rx)
3. [Linkage](#linkage)

## 1. g9_person

- Source: <normalized>
- Observations: 12
- Variables: 3
- Data signature: `12:3(40355):1317366635:4140428468`
- Disclosure: 0 excluded; cells below 5 suppressed; date-safe off; likely identifiers not excluded: `id`

### Variables

| Variable | Label | Type | Missing | Values/Statistics |
|---|---|---|---|---|
| `id` |  | long | 0 (0.0%) | 1: suppressed (<5)<br>2: suppressed (<5)<br>3: suppressed (<5)<br>4: suppressed (<5)<br>5: suppressed (<5)<br>6: suppressed (<5)<br>7: suppressed (<5)<br>8: suppressed (<5)<br>9: suppressed (<5)<br>10: suppressed (<5)<br>11: suppressed (<5)<br>12: suppressed (<5) |
| `sex` |  | byte | 0 (0.0%) | 1 Male: 6 (50.0%)<br>2 Female: 6 (50.0%) |
| `grp` |  | byte | 0 (0.0%) | 1 a: suppressed (<5)<br>2 b: suppressed (<5)<br>3 c: suppressed (<5) |

## 2. g9_rx

- Source: <normalized>
- Observations: 36
- Variables: 4
- Data signature: `36:4(76080):503302923:1138140488`
- Disclosure: 0 excluded; cells below 5 suppressed; date-safe off; likely identifiers not excluded: `id`

### Variables

| Variable | Label | Type | Missing | Values/Statistics |
|---|---|---|---|---|
| `id` |  | str6 | 0 (0.0%) | N=36; 12 distinct; max length 2; all numeric text |
| `sex` |  | byte | 0 (0.0%) | 1 Female: 18 (50.0%)<br>2 Male: 18 (50.0%) |
| `grp` |  | byte | 0 (0.0%) | 1 a: 12 (33.3%)<br>2 b: 12 (33.3%)<br>3 c: 12 (33.3%) |
| `drug` |  | int | 0 (0.0%) | 0: 5 (13.9%)<br>1: 6 (16.7%)<br>2: 5 (13.9%)<br>3: 5 (13.9%)<br>4: 5 (13.9%)<br>5: 5 (13.9%)<br>6: 5 (13.9%) |

## Linkage

Variable names in two or more datasets. Unique: the values identify the observations, missing values counted as values, as `merge` counts them. Merge: the type a merge on that variable alone implies (master first).

| Variable | Datasets | Type | Unique | Merge | Flags |
|---|---|---|---|---|---|
| `id` | g9_person, g9_rx | g9_person long; g9_rx str6 | g9_person yes; g9_rx no | cannot merge: numeric and string | type conflict: numeric in g9_person; string in g9_rx |
| `sex` | g9_person, g9_rx | byte | no in both | g9_person m:m g9_rx |  |
| `grp` | g9_person, g9_rx | byte | no in both | g9_person m:m g9_rx |  |

Value labels with the same name and different definitions (`merge` keeps the master's):

- `sexl`: 2 definitions (g9_person | g9_rx)

