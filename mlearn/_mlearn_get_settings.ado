*! _mlearn_get_settings Version 1.0.0  2026/03/15
*! Retrieve stored metadata from dataset characteristics
*! Author: Timothy P Copeland

* Returns via c_local: _mlearn_trained, _mlearn_method, _mlearn_task,
*   _mlearn_outcome, _mlearn_features, _mlearn_n_features,
*   _mlearn_model_path, _mlearn_seed, _mlearn_N_train, _mlearn_hparams

program define _mlearn_get_settings
    version 16.0
    set varabbrev off
    set more off

    local trained     : char _dta[_mlearn_trained]
    local method      : char _dta[_mlearn_method]
    local task        : char _dta[_mlearn_task]
    local outcome     : char _dta[_mlearn_outcome]
    local features    : char _dta[_mlearn_features]
    local n_features  : char _dta[_mlearn_n_features]
    local model_path  : char _dta[_mlearn_model_path]
    local seed        : char _dta[_mlearn_seed]
    local N_train     : char _dta[_mlearn_N_train]
    local hparams     : char _dta[_mlearn_hparams]

    c_local _mlearn_trained     "`trained'"
    c_local _mlearn_method      "`method'"
    c_local _mlearn_task        "`task'"
    c_local _mlearn_outcome     "`outcome'"
    c_local _mlearn_features    "`features'"
    c_local _mlearn_n_features  "`n_features'"
    c_local _mlearn_model_path  "`model_path'"
    c_local _mlearn_seed        "`seed'"
    c_local _mlearn_N_train     "`N_train'"
    c_local _mlearn_hparams     "`hparams'"
end
