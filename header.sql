-------------------------!-------------------!---------------------------------------------------
-------------------------!-------------------!---------------------------------------------------
-------------------------!--Package Header --!---------------------------------------------------
-------------------------!-------------------!---------------------------------------------------
-------------------------!-------------------!---------------------------------------------------
CREATE
OR REPLACE PACKAGE "AAA_CAP_MODEL_HEDAYAT" IS
  /* define global types*/
  TYPE history_record_type IS RECORD(
    dat_start DATE,
    dat_end DATE,
    module NUMBER);

  /* define global variables*/
  history_record_global history_record_type;
  code_run_global_variable VARCHAR2(13);
  code_run_tot_global_variable VARCHAR2(15);
  
  /*declare functions and procedures*/
  PROCEDURE FILL_BAS_RUN_HISTORIES_PRC (
    p_date_start IN DATE,
    P_date_end IN DATE,
    p_description IN VARCHAR2
  );

  --! main procedure
  PROCEDURE run_model_manual_prc(
    p_flg_run_service IN NUMBER);

END "AAA_CAP_MODEL_HEDAYAT";

/