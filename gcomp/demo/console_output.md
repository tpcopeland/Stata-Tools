---
title: "console_output"
---

## Binary-exposure mediation (OBE)

```stata
. quietly {
```

```stata
. noisily gcomp y m x c, outcome(y) mediation obe
>     exposure(x) mediator(m)
>     commands(m: logit, y: logit)
>     equations(m: x c, y: m x c)
>     base_confs(c) sim(500) samples(50) seed(42)
```

```
G-computation procedure using Monte Carlo simulation: mediation


   Outcome variable: y
   Exposure variable(s): x
   Mediator variable(s): m
   Size of MC sample: 500
   No. of bootstrap samples: 50


   A summary of the specified parametric models:

   (for simulation under different interventions)

      Variable | Command | Prediction equation
   ------------+---------+-------------------------------------------------------
             m | logit   |  x c
             y | logit   |  m x c
   ------------------------------------------------------------------------------


   No. of subjects = 1000

                                              |-PROGRESS-|
   Preparing dataset for MC simulations:      |----------|

                                              |-PROGRESS-|
   Fitting parametric models and simulating:  |----------|

                                              |-PROGRESS-|
   Estimating direct/indirect effects:        |----------|


   Bootstrapping:
(running _gcomp_bootstrap on estimation sample)

Bootstrap replications (50)
----+--- 1 ---+--- 2 ---+--- 3 ---+--- 4 ---+--- 5
..................................................    50

G-computation formula estimates of the total causal effect and the natural direct/indirect effects

    Note: The total causal effect (TCE) is a comparison between the
          mean potential outcome if, contrary to fact, all subjects were
          exposed, and the mean potential outcome if all subjects were
          unexposed. Writing X for the exposure, M for the mediator(s),
          and Y for the outcome and 0 for the baseline, then:

                  TCE=E[Y]-E[Y]

          The natural direct effect (NDE) is a comparison between the
          mean of two potential outcomes. The first is the potential
          outcome if, contrary to fact, all subjects were exposed, and
          subjects' mediator(s) were set to their potential value(s)
          under no exposure. The second is the potential outcome if,
          contrary to fact, all subjects were unexposed. That is:

                  NDE=E[Y]-E[Y]

          The natural indirect effect (NIE) is the difference between
          the TCE and the NDE. That is:

              NIE=TCE-NDE=E[Y]-E[Y]

          The proportion mediated (PM) is the NIE divided by
          the TCE.



 -------------------------------------------------------------------------------------
              |  G-computation      Bootstrap                         Normal-based
              |  estimate (MD)      Std. Err.      z    P>|z|     [95% Conf. Interval]
 -------------+-----------------------------------------------------------------------
       TCE    |        .056           .035098    1.6    0.111    -.0127909    .1247909
       NDE    |        .018          .0329626     .55   0.585    -.0466054    .0826054
       NIE    |        .038          .0253395    1.5    0.134    -.0116646    .0876646
       PM     |    .6785714           1.64664     .41   0.680    -2.548783    3.905926
 -------------------------------------------------------------------------------------

```

## Controlled direct effect (CDE)

```stata
. noisily gcomp y m x c, outcome(y) mediation obe
>     exposure(x) mediator(m)
>     commands(m: logit, y: logit)
>     equations(m: x c, y: m x c)
>     base_confs(c) control(0) sim(500) samples(50) seed(42)
```

```
G-computation procedure using Monte Carlo simulation: mediation


   Outcome variable: y
   Exposure variable(s): x
   Mediator variable(s): m
   Size of MC sample: 500
   No. of bootstrap samples: 50


   A summary of the specified parametric models:

   (for simulation under different interventions)

      Variable | Command | Prediction equation
   ------------+---------+-------------------------------------------------------
             m | logit   |  x c
             y | logit   |  m x c
   ------------------------------------------------------------------------------


   No. of subjects = 1000

                                              |-PROGRESS-|
   Preparing dataset for MC simulations:      |----------|

                                              |-PROGRESS-|
   Fitting parametric models and simulating:  |----------|

                                              |-PROGRESS-|
   Estimating direct/indirect effects:        |----------|


   Bootstrapping:
(running _gcomp_bootstrap on estimation sample)

Bootstrap replications (50)
----+--- 1 ---+--- 2 ---+--- 3 ---+--- 4 ---+--- 5
.............................................x....    50

G-computation formula estimates of the total causal effect, the natural direct/indirect effects,
and the controlled direct effect

    Note: The total causal effect (TCE) is a comparison between the
          mean potential outcome if, contrary to fact, all subjects were
          exposed, and the mean potential outcome if all subjects were
          unexposed. Writing X for the exposure, M for the mediator(s),
          and Y for the outcome and 0 for the baseline, then:

                  TCE=E[Y]-E[Y]

          The natural direct effect (NDE) is a comparison between the
          mean of two potential outcomes. The first is the potential
          outcome if, contrary to fact, all subjects were exposed, and
          subjects' mediator(s) were set to their potential value(s)
          under no exposure. The second is the potential outcome if,
          contrary to fact, all subjects were unexposed. That is:

                  NDE=E[Y]-E[Y]

          The natural indirect effect (NIE) is the difference between
          the TCE and the NDE. That is:

              NIE=TCE-NDE=E[Y]-E[Y]

          The proportion mediated (PM) is the NIE divided by
          the TCE.

          The controlled direct effect (CDE) is a comparison between
          the mean potential outcome when all subjects were exposed
          and the mean potential outcome when all subjects were
          unexposed; and, in addition, in both cases, the mediator(s)
          were set to their control value(s). Write m for the control
          value(s) of the mediator(s), then:

                  CDE=E-E



         Control value(s):
              m=0

 -------------------------------------------------------------------------------------
              |  G-computation      Bootstrap                         Normal-based
              |  estimate (MD)      Std. Err.      z    P>|z|     [95% Conf. Interval]
 -------------+-----------------------------------------------------------------------
       TCE    |        .014          .0368658     .38   0.704    -.0582557    .0862557
       NDE    |         .02          .0336395     .59   0.552    -.0459322    .0859322
       NIE    |       -.006          .0243236    -.25   0.805    -.0536733    .0416733
       PM     |   -.4285714           1.17437    -.36   0.715    -2.730295    1.873152
       CDE    |       -.016          .0314072    -.51   0.610    -.0775571    .0455571
 -------------------------------------------------------------------------------------

```

## Categorical-exposure mediation (OCE)

```stata
. quietly {
```

```stata
. noisily gcomp y m x c, outcome(y) mediation oce
>     exposure(x) mediator(m)
>     commands(m: logit, y: logit)
>     equations(m: x c, y: m x c)
>     base_confs(c) sim(500) samples(50) seed(42)
```

```
G-computation procedure using Monte Carlo simulation: mediation

Warning: Option baseline() has not been specified, and therefore the baseline will be assumed to be 0.

   Outcome variable: y
   Exposure variable(s): x
   Mediator variable(s): m
   Size of MC sample: 500
   No. of bootstrap samples: 50


   A summary of the specified parametric models:

   (for simulation under different interventions)

      Variable | Command | Prediction equation
   ------------+---------+-------------------------------------------------------
             m | logit   |  x c
             y | logit   |  m x c
   ------------------------------------------------------------------------------


   No. of subjects = 1000

                                              |-PROGRESS-|
   Preparing dataset for MC simulations:      |----------|

                                              |-PROGRESS-|
   Fitting parametric models and simulating:  |----------|

                                              |-PROGRESS-|
   Estimating direct/indirect effects:        |----------|


   Bootstrapping:
(running _gcomp_bootstrap on estimation sample)

Bootstrap replications (50)
----+--- 1 ---+--- 2 ---+--- 3 ---+--- 4 ---+--- 5
..................................................    50

G-computation formula estimates of the total causal effect and the natural direct/indirect effects

    Note: The total causal effect (TCE(k)), comparing level k
          of the exposure against the baseline, is a comparison
          between the mean potential outcome if, contrary to fact,
          all subjects were exposed at level k, and the mean
          potential outcome if all subjects received the baseline
          level of exposure. Writing X for the exposure, M for the
          mediator(s), Y for the outcome, and 0 for the baseline:

                  TCE(k)=E[Y]-E[Y]

          The natural direct effect (NDE(k)) is a comparison between the
          mean of two potential outcomes. The first is the potential
          outcome if, contrary to fact, all subjects received exposure
          k, and subjects' mediator(s) were set to their potential
          value(s) under baseline exposure. The second is the potential
          outcome if, contrary to fact, all subjects experienced the
          baseline exposure. That is:

                  NDE(k)=E[Y]-E[Y]

          The natural indirect effect (NIE(k)) is the difference between
          the TCE(k) and the NDE(k). That is:

              NIE(k)=TCE(k)-NDE(k)=E[Y]-E[Y]

          The proportion mediated (PM(k)) is the NIE(k) divided by
          the TCE(k).


         Baseline value(s):
              x=0

 -------------------------------------------------------------------------------------
              |  G-computation      Bootstrap                         Normal-based
              |  estimate (MD)      Std. Err.      z    P>|z|     [95% Conf. Interval]
 -------------+-----------------------------------------------------------------------
    TCE(1)    |       -.054         .0347287    -1.55   0.120     -.122067     .014067
    TCE(2)    |       -.092         .0302558    -3.04   0.002    -.1513002   -.0326998
 -------------+-----------------------------------------------------------------------
    NDE(1)    |       -.052         .0321308    -1.62   0.106    -.1149751    .0109751
    NDE(2)    |       -.104         .0367025    -2.83   0.005    -.1759355   -.0320645
 -------------+-----------------------------------------------------------------------
    NIE(1)    |       -.002         .0311316     -.06   0.949    -.0630168    .0590168
    NIE(2)    |        .012         .0305374      .39   0.694    -.0478522    .0718522
 -------------+-----------------------------------------------------------------------
    PM(1)     |     .037037         .6929801      .05   0.957    -1.321179    1.395253
    PM(2)     |   -.1304348         .2787365     -.47   0.640    -.6767484    .4158788
 -------------------------------------------------------------------------------------

```

## Time-varying confounding

```stata
. quietly {
```

```stata
. noisily gcomp outcome L0 A L Alag Llag id time, outcome(outcome)
>     idvar(id) tvar(time)
>     varyingcovariates(L) fixedcovariates(L0)
>     laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1)
>     commands(A: logit, outcome: logit, L: regress)
>     equations(A: L0 L, outcome: Alag Llag L0, L: Alag Llag L0)
>     intvars(A) interventions(A=1, A=0)
>     sim(120) samples(5) seed(20260421) eofu
```

```
G-computation procedure using Monte Carlo simulation: time-varying confounding


   Outcome variable: outcome
   Intervention variable(s): A
   Outcome type: binary, measured at end of follow-up
   Size of MC sample: 120
   No. of bootstrap samples: 5


   A summary of the specified parametric models:

   (for simulation under different interventions)

      Variable | Command | Prediction equation
   ------------+---------+-------------------------------------------------------
             L | regress |  Alag Llag L0
             A | logit   |  L0 L
       outcome | logit   |  Alag Llag L0
   ------------------------------------------------------------------------------


   Warning: 240 observations of the outcome variable are being ignored because they were recorded before the end of foll
```

```stata
> ow-up
```

```
   No. of subjects = 120

                                              |-PROGRESS-|
   Preparing dataset for MC simulations:      |----------|

                                              |-PROGRESS-|
   Fitting parametric models and simulating:  |----------|
                                              |-PROGRESS-|
   Estimating mean potential outcomes:        |----------|
----------|


   Bootstrapping:
(running _gcomp_bootstrap on estimation sample)

Bootstrap replications (5)
----+--- 1 ---+--- 2 ---+--- 3 ---+--- 4 ---+--- 5
.....

G-computation formula estimates of the expected values of the potential outcome under each of the specified intervention
```

```stata
> s
```

```
   and under no intervention (i.e. as simulated under the observational regime). For comparison, the mean outcome in the
   observed data is also shown.

         Specified interventions:
              Intervention 1: A=1
              Intervention 2: A=0

 ----------------------------------------------------------------------------------
              |  G-computation
              |   estimate of    Bootstrap                         Normal-based
      outcome |     mean PO      Std. Err.      z    P>|z|     [95% Conf. Interval]
 -------------+--------------------------------------------------------------------
      Int. 1  |    .1416667      .0560258     2.53   0.011     .0318581    .2514752
      Int. 2  |    .1916667      .0625278     3.07   0.002     .0691145    .3142188
 -------------+--------------------------------------------------------------------
 Obs. regime  |
   simulated  |    .1666667      .0314024     5.31   0.000     .1051191    .2282143
    observed  |    .1583333
 ----------------------------------------------------------------------------------

```
