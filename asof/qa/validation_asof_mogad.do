clear all
set processors 1
set varabbrev off
version 16.0

capture log close _all
log using "validation_asof_mogad.log", replace text nomsg
global ASOF_QA_STATUS "fail"

do "_asof_qa_common.do"
quietly _asof_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# All eleven MOGAD extraction sites are expressible as single calls
local ++test_count
capture noisily {
    tempfile eq5d visits bouts visual

    clear
    input long id double eq5d_dt eq5d_uk eq5d_se eq_vas
    1  90 .80 .78 75
    1 110 .76 .74 70
    1 140 .71 .69 65
    end
    format %td eq5d_dt
    save `eq5d'

    clear
    input long id double visit_dt edss edss_cat va_visit
    1  70 1 1 .8
    1  90 2 1 .7
    1 110 3 2 .6
    1 145 4 2 .5
    end
    format %td visit_dt
    save `visits'

    clear
    input long id double bout_dt byte(type_on_flag type_myelit_flag type_brainstem_flag type_area_postrema_flag type_narcolepsy_flag)
    1  60 1 0 0 1 0
    1 120 0 1 1 0 0
    end
    format %td bout_dt
    save `bouts'

    clear
    input long id double visit_date visual_left visual_right
    1  70 .8 .7
    1 100 .6 .5
    1 120 .4 .3
    end
    format %td visit_date
    save `visual'

    clear
    input long id double(indexdt onsetdt study_start followupdt)
    1 100 80 50 150
    end
    format %td indexdt onsetdt study_start followupdt

    * Combined 1208-1237: EDSS at/near index.
    asof edss using `visits', id(id) date(visit_dt) anchor(indexdt) ///
        range(study_start followupdt) direction(both) select(nearest) ///
        generate(edss_at_near_index)
    assert edss_at_near_index == 2

    * Combined 1326-1348: EQ-5D at index.
    asof eq5d_uk eq5d_se eq_vas using `eq5d', id(id) date(eq5d_dt) ///
        anchor(indexdt) range(study_start followupdt) direction(both) ///
        select(nearest) suffix(_index) datename(eq5d_dt_index)
    assert abs(eq5d_uk_index - .80) < 1e-6
    assert abs(eq5d_se_index - .78) < 1e-6
    assert eq_vas_index == 75 & eq5d_dt_index == 90

    * Combined 1350-1367: EQ-5D at last available.
    asof eq5d_uk eq5d_se eq_vas using `eq5d', id(id) date(eq5d_dt) ///
        anchor(followupdt) range(study_start followupdt) ///
        direction(onorbefore) select(last) suffix(_last) ///
        datename(eq5d_dt_last)
    assert abs(eq5d_uk_last - .71) < 1e-6
    assert abs(eq5d_se_last - .69) < 1e-6
    assert eq_vas_last == 65 & eq5d_dt_last == 140

    * Combined 1369-1391: EDSS at index.
    asof edss edss_cat using `visits', id(id) date(visit_dt) ///
        anchor(indexdt) range(study_start followupdt) direction(both) ///
        select(nearest) suffix(_index) datename(edss_dt_index)
    assert edss_index == 2 & edss_cat_index == 1 & edss_dt_index == 90

    * Combined 1393-1414: visual acuity at index.
    asof va_visit using `visits', id(id) date(visit_dt) anchor(indexdt) ///
        range(study_start followupdt) direction(both) select(nearest) ///
        generate(va_index) datename(va_dt_index)
    assert abs(va_index - .7) < 1e-6 & va_dt_index == 90

    * Combined 1416-1433: EDSS at last available.
    asof edss edss_cat using `visits', id(id) date(visit_dt) ///
        anchor(followupdt) range(study_start followupdt) ///
        direction(onorbefore) select(last) suffix(_last) ///
        datename(edss_dt_last)
    assert edss_last == 4 & edss_cat_last == 2 & edss_dt_last == 145

    * Combined 1435-1451: visual acuity at last available.
    asof va_visit using `visits', id(id) date(visit_dt) anchor(followupdt) ///
        range(study_start followupdt) direction(onorbefore) select(last) ///
        generate(va_last) datename(va_dt_last)
    assert abs(va_last - .5) < 1e-6 & va_dt_last == 145

    * Combined 1505-1520: closest EDSS at or before index.
    asof edss using `visits', id(id) date(visit_dt) anchor(indexdt) ///
        direction(onorbefore) select(nearest) generate(edss_pre_index)
    assert edss_pre_index == 2

    * Combined 1522-1535: closest visual acuity at or before index.
    asof va_visit using `visits', id(id) date(visit_dt) anchor(indexdt) ///
        direction(onorbefore) select(nearest) generate(va_pre_index)
    assert abs(va_pre_index - .7) < 1e-6

    * Combined 1307-1321: symptoms at first bout.
    asof type_on_flag type_myelit_flag type_brainstem_flag ///
        type_area_postrema_flag type_narcolepsy_flag using `bouts', ///
        id(id) date(bout_dt) anchor(indexdt) direction(both) ///
        select(first) prefix(initial_) require(bout_dt)
    assert initial_type_on_flag == 1
    assert initial_type_myelit_flag == 0
    assert initial_type_area_postrema_flag == 1

    * Cleaning 1444-1471: first through onset+30 and last overall.
    asof visual_left visual_right using `visual', id(id) date(visit_date) ///
        anchor(onsetdt) window(. 30) direction(both) select(first) ///
        suffix(_index)
    asof visual_left visual_right using `visual', id(id) date(visit_date) ///
        anchor(onsetdt) direction(both) select(last) suffix(_last)
    assert abs(visual_left_index - .8) < 1e-6
    assert abs(visual_right_index - .7) < 1e-6
    assert abs(visual_left_last - .4) < 1e-6
    assert abs(visual_right_last - .3) < 1e-6
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: validation_asof_mogad tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
log close _all
