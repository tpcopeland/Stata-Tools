| Run | Dataset | Check | Observed | Expectation and source | Disposition | Date | PI consulted |
|---|---|---|---|---|---|---|---|
| g1 | alpha | rule(big): <5 fail against x <= 18 | <5 fail | x <= 18; source: | open (invariant failed; allowed: code fixed; accepted: <reason> (PI consulted)) | DATE | required if accepted |
| g1 | alpha | stat(mean x): mean 10.5 against [0, 5] | mean 10.5 | [0, 5]; source: | open (band warned; allowed: code fixed; accepted: <reason>; expectation revised pre hoc; expectation revised post hoc) | DATE |  |
| g1 | alpha | review(low): <5 rows against x < 3 | <5 rows | x < 3; source: | open (review item; allowed: accepted: <reason>; code fixed) | DATE |  |
| g1 | beta | all gates passed: isid | 0 violations in 1 gate entries | as declared | clean | DATE |  |
