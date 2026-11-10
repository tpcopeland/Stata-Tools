## 1. test_cohort

- Source: <normalized>
- Label: Test cohort dataset
- Observations: 100
- Variables: 8
- Dataset notes:
  - This is a synthetic test dataset
- Data signature: `100:8(64926):392615947:797463798`
- Disclosure: 0 excluded; cells below 5 suppressed; date-safe off; likely identifiers not excluded: `id`

### Variables

| Variable | Label | Type | Missing | Values/Statistics |
|---|---|---|---|---|
| `id` | Unique identifier | double | 0 (0.0%) | N=100; mean=50.50; SD=29.01; median=50.50; IQR=25.50-75.50; range=1.00-100.00 |
| `age` | Age in years | double | 0 (0.0%) | N=100; mean=48.85; SD=18.39; median=46.00; IQR=32.00-65.00; range=20.00-79.00 |
| `sex` | Sex of participant | byte | 0 (0.0%) | 0 Female: 46 (46.0%)<br>1 Male: 54 (54.0%) |
| `bmi` | Body mass index | double | 0 (0.0%) | N=100; mean=25.19; SD=4.40; median=24.67; IQR=21.04-29.12; range=18.61-32.95 |
| `region` | Geographic region | byte | 0 (0.0%) | 1 North: 23 (23.0%)<br>2 South: 31 (31.0%)<br>3 East: 24 (24.0%)<br>4 West: 22 (22.0%) |
| `entry_date` | Study entry date | double %td daily | 0 (0.0%) | N=100; range 2020/01/03 to 2020/12/25 |
| `exit_date` | Study exit date | double %td daily | 0 (0.0%) | N=100; range 2020/02/23 to 2021/11/09 |
| `name` | Participant name | str20 | 0 (0.0%) | N=100; 100 distinct; max length 9 |

