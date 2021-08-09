PROCEDURE fill_sop_og_periods_prc (
  p_module IN NUMBER )IS 
BEGIN
  INSERT INTO
    lmp_bas_model_run_stats (
      bas_model_run_stat_id,
      cod_run_mosta,
      num_step_mosta,
      des_step_mosta,
      sta_step_mosta,
      dat_start_mosta,
      num_module_mosta
    )
  VALUES
    (
      lmp_bas_model_run_stats_seq.nextval,
      APP_LMP_CAP_HEDAYAT_PKG.code_run_global_variable,
      1,
      'آماده سازي داده با شماره اجراي جديد',
      'در حال اجرا',
      SYSDATE,
      p_module
    );

END;